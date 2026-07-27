import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';

class _DnsCacheEntry {
  final List<InternetAddress> addresses;
  final DateTime resolvedAt;

  _DnsCacheEntry(this.addresses, this.resolvedAt);

  bool get isExpired =>
      DateTime.now().difference(resolvedAt) > const Duration(minutes: 5);
}

/// Odakta seçilen kaynak için DNS çözümü + (HTTP/S) hızlı TCP/HEAD; kanal değişiminde
/// el sıkışmasını cihaz açısında hafifletmeye yardımcı olur.
///
/// ANR (Application Not Responding) oluşmasını engellemek için DNS önbellekleme,
/// eşzamanlı istek sınırlama (LIFO kuyruğu) ve mükerrer DNS sorgularını birleştirme
/// özellikleri eklenmiştir.
class IptvPrecacheService extends GetxService {
  final Map<String, _DnsCacheEntry> _dnsCache = {};
  final Map<String, Future<List<InternetAddress>>> _activeLookups = {};

  int _activeJobsCount = 0;
  static const int _maxConcurrentJobs = 2;
  String? _nextUrlToPrecache;

  /// [streamUrl] için isim çöz ve mümkünse soket/HEAD üzerinden ön bağlantı dene.
  Future<void> precacheStreamUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;

    if (_activeJobsCount >= _maxConcurrentJobs) {
      // Çok fazla aktif iş varsa, en son istenen URL'yi sıraya alıp eskileri eliyoruz (LIFO)
      _nextUrlToPrecache = u;
      return;
    }

    await _runPrecacheJob(u);
  }

  Future<void> _runPrecacheJob(String url) async {
    _activeJobsCount++;
    try {
      await _precacheWorker(url);
    } finally {
      _activeJobsCount--;
      // Sırada bekleyen en güncel bir URL varsa onu çalıştır
      if (_nextUrlToPrecache != null) {
        final nextUrl = _nextUrlToPrecache!;
        _nextUrlToPrecache = null;
        unawaited(Future.microtask(() => _runPrecacheJob(nextUrl)));
      }
    }
  }

  Future<void> _precacheWorker(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final host = uri.host;
    if (host.isEmpty) return;
    if (host == '127.0.0.1' || host == 'localhost' || host == '::1') {
      return;
    }

    // DNS Çözümleme (Önbellek ve Birleştirme kullanan mekanizma)
    final addresses = await _resolveHost(host);
    if (addresses.isEmpty) return;

    final resolvedAddress = addresses.first;
    final sch = uri.scheme.toLowerCase();
    if (sch == 'http' || sch == 'https') {
      final port = uri.hasPort
          ? uri.port
          : (sch == 'https' ? 443 : 80);

      // 1. TCP bağlantı ısındırma - Çözülmüş IP adresini doğrudan kullanarak DNS sorgusunu engeller
      try {
        final s = await Socket.connect(
          resolvedAddress,
          port,
          timeout: const Duration(milliseconds: 1500),
        );
        unawaited(s.close());
      } catch (_) {}

      // 2. HTTP/HTTPS bağlantı ısındırma - IP üzerinden bağlantı kurup DNS sorgusunu engeller
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 1500);

      // IP ile bağlanacağımız için SSL sertifika doğrulamasını esnetiyoruz
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;

      try {
        String ipAddress = resolvedAddress.address;
        if (resolvedAddress.type == InternetAddressType.IPv6) {
          ipAddress = '[$ipAddress]';
        }
        final ipUri = uri.replace(host: ipAddress);
        final req = await client.headUrl(ipUri);
        req.headers.set('Host', host); // Orijinal host başlığını koru
        final res = await req.close();
        await res.drain();
      } catch (_) {}
      client.close(force: true);
    }
  }

  Future<List<InternetAddress>> _resolveHost(String host) {
    // 1. Önbellek kontrolü
    final cached = _dnsCache[host];
    if (cached != null && !cached.isExpired) {
      return Future.value(cached.addresses);
    }

    // 2. Aynı host için halihazırda devam eden bir DNS sorgusu var mı?
    final active = _activeLookups[host];
    if (active != null) {
      return active;
    }

    // 3. Yeni DNS sorgusu başlat (getaddrinfo çağrısı)
    final lookupFuture = InternetAddress.lookup(host)
        .timeout(const Duration(milliseconds: 1500), onTimeout: () => [])
        .then((addresses) {
      if (addresses.isNotEmpty) {
        _dnsCache[host] = _DnsCacheEntry(addresses, DateTime.now());
      }
      return addresses;
    }).catchError((_) {
      return <InternetAddress>[];
    }).whenComplete(() {
      _activeLookups.remove(host);
    });

    _activeLookups[host] = lookupFuture;
    return lookupFuture;
  }
}

