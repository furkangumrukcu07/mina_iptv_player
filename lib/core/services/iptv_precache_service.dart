import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';

/// Odakta seçilen kaynak için DNS çözümü + (HTTP/S) hızlı TCP/HEAD; kanal değişiminde
/// el sıkışmasını cihaz açısında hafifletmeye yardımcı olur.
class IptvPrecacheService extends GetxService {
  /// [streamUrl] için isim çöz ve mümkünse soket/HEAD üzerinden ön bağlantı dene.
  Future<void> precacheStreamUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    final uri = Uri.tryParse(u);
    if (uri == null) return;
    final host = uri.host;
    if (host.isEmpty) return;
    if (host == '127.0.0.1' || host == 'localhost' || host == '::1') {
      return;
    }

    try {
      await InternetAddress.lookup(host)
          .timeout(const Duration(milliseconds: 2000), onTimeout: () => []);
    } catch (_) {}

    final sch = uri.scheme.toLowerCase();
    if (sch == 'http' || sch == 'https') {
      final port = uri.hasPort
          ? uri.port
          : (sch == 'https' ? 443 : 80);
      try {
        final s = await Socket.connect(
          host,
          port,
          timeout: const Duration(milliseconds: 2000),
        );
        unawaited(s.close());
      } catch (_) {}
      final client = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 2000);
      try {
        final req = await client.headUrl(uri);
        final res = await req.close();
        await res.drain();
      } catch (_) {}
      client.close(force: true);
    }
  }
}
