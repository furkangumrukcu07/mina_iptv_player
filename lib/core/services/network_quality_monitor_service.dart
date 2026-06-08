import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';
import 'app_settings_service.dart';
import 'toast_service.dart';

/// **Akıllı CDN / Proxy Seçici — Smart Route Optimization.**
///
/// Kullanıcının yüklediği M3U/Xtream listeleri çoğunlukla yurt dışı kaynaklı
/// CDN'lerden (Cloudflare, OVH, Hetzner …) beslenir. Türk ISS'lerinin
/// (Türk Telekom, Turkcell Superonline, Vodafone Net …) yurt dışı çıkışlarında
/// özellikle akşam saatlerinde **peering darboğazı** yaşanır; paket kaybı
/// (packet loss) ve gecikme dalgalanması (jitter) artar.
///
/// Bu servis arka planda hafif TCP socket "ping" leri atar (gerçek ICMP
/// Flutter'da root + native gerektirir; TCP RTT canlı yayın akışını birebir
/// temsil ettiği için daha güvenilir bir proxy ölçüm). 5 ardışık denemenin
/// **packet loss** + **jitter** + **avg latency** istatistiğini çıkarır ve
/// kullanıcının seçtiği [AppSettingsService.smartRouteAutoBufferEnabled]
/// açıkken canlı tamponu **dinamik olarak yukarı çeker** (örn. 3 sn → 8 sn);
/// ağ toparlanırsa tampon kullanıcının manuel değerine **geri döner**.
///
/// Toast bildirimi: ilk algılamada *"Bağlantınızda dalgalanma var, tampon
/// profili otomatik optimize edildi"* glass toast'u tetiklenir; aynı seansta
/// yeniden gösterilmez.
class NetworkQualityMonitorService extends GetxService {
  // ---------------------------------------------------------------------------
  // Public reaktif durum.
  // ---------------------------------------------------------------------------

  /// Şu anki ölçüm dilimine ait kalite seviyesi. UI rozeti bu değeri okur.
  final quality = NetworkQuality.unknown.obs;

  /// Son ölçüm dilimindeki ortalama RTT (ms). UI alt satırına yazılır.
  final lastAverageLatencyMs = RxnDouble();

  /// Son ölçümdeki jitter (RTT standart sapması, ms).
  final lastJitterMs = RxnDouble();

  /// Son ölçümdeki paket kaybı oranı (0.0 – 1.0).
  final lastPacketLoss = RxnDouble();

  /// Son başarılı ölçüm zaman damgası (epoch ms). UI "12 sn önce" gibi
  /// göreceli bir bilgiye dönüştürmek için kullanır.
  final lastProbeAtMs = 0.obs;

  /// Auto-buffer şu an aktif mi (yani biz tamponu yükselttik mi)? `true` ise
  /// `setLiveBufferSeconds`'a kullanıcı niyetiyle değil servis tarafından
  /// yazıldığı için ağ toparlanınca geri çekilir.
  final autoBufferActive = false.obs;

  // ---------------------------------------------------------------------------
  // Sabitler — denemeler, eşikler, döngü süreleri.
  // ---------------------------------------------------------------------------

  /// Her döngüde host başına atılan TCP probe sayısı. 5 ölçüm; jitter ve
  /// packet-loss istatistiğini güvenilir çıkarmak için minimum.
  static const int _probesPerCycle = 5;

  /// Probe başına timeout. >2.0 sn → kayıp sayılır.
  static const Duration _probeTimeout = Duration(seconds: 2);

  /// Probe'lar arasındaki kısa boşluk (network burst yaratmamak için).
  static const Duration _interProbeGap = Duration(milliseconds: 220);

  /// Döngüler arasındaki normal bekleme. 60 sn → akşam saatleri profili.
  static const Duration _cyclePeriod = Duration(seconds: 60);

  /// Bağlantı kalitesi `unstable`/`poor` ise döngü daha sık çalışır
  /// (10 sn) — toparlanma anını yakalamak için.
  static const Duration _cyclePeriodDegraded = Duration(seconds: 10);

  /// Otomatik tampon devreye girdiğinde uygulanan minimum hedef değer (sn).
  /// Kullanıcının mevcut ayarı bundan büyükse zaten dokunulmaz.
  static const int _autoBufferTargetSec = 8;

  /// Dalgalanma toparlanıp kullanıcı ayarına dönmek için **en az** ne kadar
  /// "iyi/mükemmel" ölçüm üst üste gelmeli? — flapping engellemek için 3.
  static const int _recoveryGoodCycles = 3;

  // ---------------------------------------------------------------------------
  // İç durum.
  // ---------------------------------------------------------------------------

  Timer? _timer;
  bool _busy = false;

  /// Kullanıcının auto-buffer **öncesi** ayarladığı tampon değeri. Geri
  /// dönüşte buraya yazılır.
  int? _userBufferBeforeOverride;

  /// Üst üste iyi kalite döngüsü sayacı — recovery için.
  int _goodStreak = 0;

  /// Bu seansta zaten toast gösterildi mi? Yeniden tetikleme yapmayız.
  bool _toastShownThisSession = false;

  /// Servis hayata her başlatıldığında ölçümleri sıfırlayan, kaynaklar
  /// değiştiğinde re-binding'e izin veren işaret.
  final _ready = Completer<void>();

  // ---------------------------------------------------------------------------
  // Lifecycle.
  // ---------------------------------------------------------------------------

  @override
  void onInit() {
    super.onInit();
    // Ayar değişimlerini dinle — kullanıcı toggle'ı kapatırsa hemen dur.
    final settings = Get.find<AppSettingsService>();
    ever<bool>(settings.smartRouteEnabled, (enabled) {
      if (enabled) {
        _start();
      } else {
        _stop();
        _revertAutoBufferIfActive();
      }
    });

    // Kullanıcı `autoBuffer` toggle'ını kapatırsa ve şu an override aktifse
    // hemen kullanıcı değerine geri dön.
    ever<bool>(settings.smartRouteAutoBufferEnabled, (enabled) {
      if (!enabled) _revertAutoBufferIfActive();
    });
  }

  /// Bootstrap akışından çağrılır — playlist yüklendikten ve `AppSettings`
  /// hazır olduktan sonra. Tek seferlik tetikleyici.
  void bootstrap() {
    if (_ready.isCompleted) return;
    _ready.complete();
    final settings = Get.find<AppSettingsService>();
    if (settings.smartRouteEnabled.value) _start();
  }

  @override
  void onClose() {
    _stop();
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // Zamanlayıcı.
  // ---------------------------------------------------------------------------

  void _start() {
    _stop();
    // Hemen bir ölçüm at; UI rozeti boş kalmasın.
    _scheduleOneShot(const Duration(milliseconds: 1200));
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _scheduleOneShot(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _runCycle);
  }

  // ---------------------------------------------------------------------------
  // Ölçüm döngüsü.
  // ---------------------------------------------------------------------------

  Future<void> _runCycle() async {
    if (_busy) return;
    _busy = true;
    try {
      final hosts = await _collectHosts();
      if (hosts.isEmpty) {
        // Henüz kaynak yok — yumuşak retry.
        _scheduleOneShot(const Duration(seconds: 20));
        return;
      }
      // Birden çok host varsa **en yavaş**'ı raporlamak yerine aktif
      // birincil slot'u (ilk host) baz alırız; pratikte VOD/Live aynı CDN'den
      // gelir ve kullanıcı tek bir akışı izler.
      final host = hosts.first;

      final samples = <double>[];
      int losses = 0;
      for (var i = 0; i < _probesPerCycle; i++) {
        final ms = await _probeOnce(host.host, host.port);
        if (ms == null) {
          losses++;
        } else {
          samples.add(ms);
        }
        if (i < _probesPerCycle - 1) {
          await Future<void>.delayed(_interProbeGap);
        }
      }

      final stats = _NetStats.fromSamples(samples, losses, _probesPerCycle);
      _applyStats(stats);
    } catch (e) {
      debugPrint('mina_iptv: net quality cycle error: $e');
    } finally {
      _busy = false;
      // Bir sonraki döngüye geç — kalite kötüyse daha sık.
      final next = (quality.value == NetworkQuality.unstable ||
              quality.value == NetworkQuality.poor)
          ? _cyclePeriodDegraded
          : _cyclePeriod;
      _scheduleOneShot(next);
    }
  }

  // ---------------------------------------------------------------------------
  // Host çıkarımı — aktif playlist slotlarından (Xtream baseUrl + M3U URL).
  // ---------------------------------------------------------------------------

  Future<List<_HostPort>> _collectHosts() async {
    try {
      final repo = Get.find<PlaylistRepository>();
      final all = await repo.readAllSources();
      final out = <_HostPort>[];
      for (final entry in all) {
        final src = entry.source;
        final url = switch (src) {
          XtreamSource(:final baseUrl) => baseUrl,
          M3uSource(:final url) => url,
        };
        final parsed = _parseHostPort(url);
        if (parsed != null) out.add(parsed);
      }
      // Aynı host'u tekrar ölçmemek için dedup.
      final seen = <String>{};
      return out
          .where((e) => seen.add('${e.host}:${e.port}'))
          .toList(growable: false);
    } catch (e) {
      debugPrint('mina_iptv: net quality host collect: $e');
      return const [];
    }
  }

  _HostPort? _parseHostPort(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    // Sentinel ("mina://local-m3u…") dosya tabanlı playlist — ağ probu yok.
    if (trimmed.startsWith('mina://')) return null;
    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      return null;
    }
    if (uri.host.isEmpty) return null;
    final port = uri.hasPort
        ? uri.port
        : (uri.scheme == 'https' ? 443 : 80);
    return _HostPort(uri.host, port);
  }

  // ---------------------------------------------------------------------------
  // Tek probe — TCP connect timing.
  // ---------------------------------------------------------------------------

  Future<double?> _probeOnce(String host, int port) async {
    final sw = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: _probeTimeout);
      sw.stop();
      return sw.elapsedMicroseconds / 1000.0;
    } catch (_) {
      return null;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
      socket?.destroy();
    }
  }

  // ---------------------------------------------------------------------------
  // İstatistik → kalite + reaksiyon.
  // ---------------------------------------------------------------------------

  void _applyStats(_NetStats stats) {
    lastAverageLatencyMs.value = stats.avgMs;
    lastJitterMs.value = stats.jitterMs;
    lastPacketLoss.value = stats.lossRatio;
    lastProbeAtMs.value = DateTime.now().millisecondsSinceEpoch;
    final newQuality = stats.classify();
    quality.value = newQuality;

    final settings = Get.find<AppSettingsService>();
    if (!settings.smartRouteEnabled.value) return;

    final isBad = newQuality == NetworkQuality.unstable ||
        newQuality == NetworkQuality.poor;

    if (isBad) {
      _goodStreak = 0;
      if (settings.smartRouteAutoBufferEnabled.value) {
        _engageAutoBuffer();
      }
      _maybeShowToast(newQuality);
    } else if (newQuality == NetworkQuality.good ||
        newQuality == NetworkQuality.excellent) {
      _goodStreak += 1;
      if (_goodStreak >= _recoveryGoodCycles) {
        _revertAutoBufferIfActive();
        _toastShownThisSession = false; // tekrar dalgalanırsa uyar
      }
    }
  }

  void _engageAutoBuffer() {
    final settings = Get.find<AppSettingsService>();
    final current = settings.liveBufferSeconds.value;
    if (autoBufferActive.value) {
      // Zaten devredeyiz — tekrar yazmaya gerek yok.
      return;
    }
    if (current >= _autoBufferTargetSec) {
      // Kullanıcı zaten yeterince yüksek — biz dokunmuyoruz, sadece işaret
      // koymuyoruz; toast yine de gösterilir.
      return;
    }
    _userBufferBeforeOverride = current;
    autoBufferActive.value = true;
    // Kullanıcı setter'ı asenkron; await edilmesi gerekmez (Rx zaten anlık
    // güncellenir, persist arkada yazılır).
    unawaited(settings.setLiveBufferSeconds(_autoBufferTargetSec));
    debugPrint(
      'mina_iptv: smart route auto-buffer ENGAGED '
      '($current sn → $_autoBufferTargetSec sn)',
    );
  }

  void _revertAutoBufferIfActive() {
    if (!autoBufferActive.value) return;
    final prev = _userBufferBeforeOverride;
    autoBufferActive.value = false;
    _userBufferBeforeOverride = null;
    if (prev != null) {
      unawaited(
        Get.find<AppSettingsService>().setLiveBufferSeconds(prev),
      );
      debugPrint('mina_iptv: smart route auto-buffer REVERTED → $prev sn');
    }
  }

  void _maybeShowToast(NetworkQuality q) {
    if (_toastShownThisSession) return;
    _toastShownThisSession = true;
    if (!Get.isRegistered<ToastService>()) return;
    final settings = Get.find<AppSettingsService>();
    final auto = settings.smartRouteAutoBufferEnabled.value;
    final title = 'smartRoute.notify.title'.tr;
    final body = auto
        ? 'smartRoute.notify.body.auto'.trParams({
            'from': '${_userBufferBeforeOverride ?? settings.liveBufferSeconds.value}',
            'to': '$_autoBufferTargetSec',
          })
        : 'smartRoute.notify.body.advise'.tr;
    Get.find<ToastService>().show(body, title: title);
  }
}

// =============================================================================
// Yardımcı tipler.
// =============================================================================

/// Ağ kalite sınıfı. UI rozetinde renk + etiket buradan çıkar.
enum NetworkQuality {
  unknown,
  excellent,
  good,
  unstable,
  poor,
}

class _HostPort {
  const _HostPort(this.host, this.port);
  final String host;
  final int port;
}

class _NetStats {
  const _NetStats({
    required this.avgMs,
    required this.jitterMs,
    required this.lossRatio,
  });

  final double avgMs;
  final double jitterMs;
  final double lossRatio;

  factory _NetStats.fromSamples(
    List<double> samples,
    int losses,
    int total,
  ) {
    if (samples.isEmpty) {
      return _NetStats(
        avgMs: double.infinity,
        jitterMs: double.infinity,
        lossRatio: losses / total,
      );
    }
    final avg = samples.reduce((a, b) => a + b) / samples.length;
    final variance = samples
            .map((v) => math.pow(v - avg, 2).toDouble())
            .reduce((a, b) => a + b) /
        samples.length;
    final jitter = math.sqrt(variance);
    return _NetStats(
      avgMs: avg,
      jitterMs: jitter,
      lossRatio: losses / total,
    );
  }

  /// Eşik tablosu (TCP RTT — TR ISS profili için empirik kalibrasyon):
  ///
  /// |             | avg ms  | jitter ms | loss   |
  /// |-------------|---------|-----------|--------|
  /// | excellent   | < 80    | < 20      | 0%     |
  /// | good        | < 180   | < 60      | ≤ 10%  |
  /// | unstable    | < 350   | < 140     | ≤ 30%  |
  /// | poor        | ≥ 350 ∨ ≥ 140  ∨ > 30%       |
  NetworkQuality classify() {
    if (lossRatio > 0.30 || avgMs == double.infinity) {
      return NetworkQuality.poor;
    }
    if (lossRatio > 0.10 || avgMs >= 350 || jitterMs >= 140) {
      return NetworkQuality.unstable;
    }
    if (avgMs < 80 && jitterMs < 20 && lossRatio == 0) {
      return NetworkQuality.excellent;
    }
    return NetworkQuality.good;
  }
}
