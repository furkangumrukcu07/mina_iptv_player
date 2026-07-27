import 'dart:io';

import 'package:flutter/foundation.dart';

import 'device_layout_defaults.dart';

/// Oynatma için cihaz güç sınıfı (düşük / orta / yüksek).
///
/// RAM + çekirdek sayısı + SoC ipuçlarından türetilir. Better Player (Exo) tampon
/// profilleri ve MediaKit (mpv) framedrop/thread/cache değerleri bu sınıfa göre
/// seçilir. Amaç: düşük segmentte takılmayı (stall) azaltmak, yüksek segmentte
/// daha hızlı başlangıç/zap ve daha pürüzsüz seek sağlamak.
enum DevicePlaybackSegment {
  /// Eski TV kutusu, ≤4 çekirdek veya &lt; 3 GiB RAM; zorlu SoC (Amlogic/MTK TV vb.).
  low,

  /// Orta segment telefon/tablet (3–6 GiB RAM) ve genel cihazlar.
  mid,

  /// Amiral gemi: ≥ 6 GiB RAM ve ≥ 8 çekirdek.
  high,
}

/// Android: Amlogic / Meson tabanlı kutularda MediaKit (mpv) için donanım ve tampon yolu.
///
/// Native [Build] alanları bir kez okunur; sonuç önbelleğe alınır.
class AndroidPlaybackSocHints {
  AndroidPlaybackSocHints._();

  static bool? _amlogicLike;
  static bool? _allwinnerLike;
  static bool? _rockchipLike;
  static bool? _genericBudgetBoxLike;
  static bool? _budgetTvBoxSocNative;
  static bool? _lowEndSmartTvLike;
  static bool? _capableTwoGiBTvBox;
  static bool? _weakMpvDevice;
  static bool? _androidTv;
  static bool? _playbackChallengedTv;
  static bool? _xiaomiFamily;
  static String? _buildModel;
  static int? _totalRamBytes;
  static int? _availableProcessors;
  static DevicePlaybackSegment _segment = DevicePlaybackSegment.mid;
  static Future<void>? _loading;

  /// 3 GiB — düşük segment RAM eşiği (altı = `low`).
  static const int _segmentLowRamBytes = 3 * 1024 * 1024 * 1024;

  /// 6 GiB — yüksek segment RAM eşiği (≥ ve ≥8 çekirdek = `high`).
  static const int _segmentHighRamBytes = 6 * 1024 * 1024 * 1024;

  /// Cihaz oynatma güç sınıfı. [ensureLoaded] sonrası kesindir; öncesinde [mid].
  static DevicePlaybackSegment get playbackSegment => _segment;

  /// Çekirdek sayısı (Android native; aksi halde [Platform.numberOfProcessors]).
  static int get availableProcessors =>
      _availableProcessors ?? Platform.numberOfProcessors;

  /// [totalRamBytes] + [availableProcessors] + zayıf-cihaz/TV ipuçlarından segment.
  static DevicePlaybackSegment _deriveSegment({
    required int? ramBytes,
    required int? cores,
    required bool weakMpv,
    required bool playbackChallengedTv,
  }) {
    final c = cores ?? Platform.numberOfProcessors;
    if (weakMpv ||
        playbackChallengedTv ||
        (cores != null && c <= 4) ||
        (ramBytes != null && ramBytes < _segmentLowRamBytes)) {
      return DevicePlaybackSegment.low;
    }
    if (ramBytes != null && ramBytes >= _segmentHighRamBytes && c >= 8) {
      return DevicePlaybackSegment.high;
    }
    return DevicePlaybackSegment.mid;
  }

  static DevicePlaybackSegment _deriveSegmentNonAndroid() {
    final c = Platform.numberOfProcessors;
    if (c >= 8) return DevicePlaybackSegment.high;
    if (c <= 2) return DevicePlaybackSegment.low;
    return DevicePlaybackSegment.mid;
  }

  /// 2 GiB — Better Player önbellek / başlangıç çözünürlük kısıtı için.
  static const int lowRamThresholdBytes = 2 * 1024 * 1024 * 1024;

  /// Pazarlama «1 GiB» sınıfı: [ActivityManager] totalMem genelde ~0,9–1,4 GiB.
  static const int oneGiBRamClassMaxBytes = 1536 * 1024 * 1024;

  /// Toplam fiziksel RAM (byte). Yalnızca Android’de ve [ensureLoaded] sonrası dolu.
  static int? get totalRamBytes => _totalRamBytes;

  /// Toplam RAM biliniyorsa ve [maxBytes]’tan küçükse `true`. Bilinmiyorsa `false` (kısıtlama uygulanmaz).
  static bool isTotalRamBelowBytes(int maxBytes) {
    final b = _totalRamBytes;
    if (b == null) return false;
    return b < maxBytes;
  }

  /// ~1 GiB RAM cihaz profili (720p tavan, dar mpv tamponu, `hls-bitrate=min`).
  static bool get oneGiBRamClass =>
      isTotalRamBelowBytes(oneGiBRamClassMaxBytes);

  /// 2 GiB pazarlama sınıfı (≥ 2 GiB ve < 3 GiB totalMem).
  static bool get twoGiBRamClass {
    final ram = _totalRamBytes;
    if (ram == null) return false;
    const giB = 1024 * 1024 * 1024;
    return ram >= 2 * giB && ram < 3 * giB;
  }

  /// 2 GiB + ucuz kutu yonga seti (Allwinner/Rockchip/X96/T95 vb.).
  static bool get budgetTwoGiBRamClass =>
      twoGiBRamClass && budgetTvBoxSoc;

  /// Chromecast 4K, Mi Box S, Onn 4K, Mecool KM2 — 2 GiB ama güçlü kod çözücü.
  static bool get capableTwoGiBTvBox => _capableTwoGiBTvBox ?? false;

  /// TCL / Philips / Toshiba / Hisense / Vestel Android TV (MTK/Realtek, ≤4 GiB).
  static bool get lowEndSmartTvLike => _lowEndSmartTvLike ?? false;

  /// Better/Exo **canlı** tampon segmenti — RAM + SoC (2 GiB capable → mid).
  static DevicePlaybackSegment exoLivePlaybackSegment() {
    if (oneGiBRamClass) return DevicePlaybackSegment.low;
    if (twoGiBRamClass && !budgetTvBoxSoc) {
      return DevicePlaybackSegment.mid;
    }
    return playbackSegment;
  }

  /// Better/Exo **VOD** tampon segmenti — 2 GiB capable challenged TV → mid.
  static DevicePlaybackSegment exoVodPlaybackSegment() {
    if (oneGiBRamClass) return DevicePlaybackSegment.low;
    if (playbackSegment == DevicePlaybackSegment.low &&
        capableChallengedTvForVod) {
      return DevicePlaybackSegment.mid;
    }
    if (twoGiBRamClass && !budgetTvBoxSoc) {
      return DevicePlaybackSegment.mid;
    }
    return playbackSegment;
  }

  /// MediaKit VOD demuxer ileri tamponu (MiB). RAM bilinmiyorsa temkinli 24.
  static int vodDemuxerForwardMiB() {
    final ramB = _totalRamBytes;
    const giB = 1024 * 1024 * 1024;
    if (ramB == null) return 24;
    if (ramB >= 4 * giB) return 96;
    if (ramB >= 3 * giB) return 64;
    if (ramB >= 2 * giB) return budgetTvBoxSoc ? 16 : 24;
    if (ramB < oneGiBRamClassMaxBytes) return 12;
    return 16;
  }

  /// Canlı MediaKit mpv tampon kademesi — RAM’e göre (1 GiB / 2 GiB / varsayılan).
  static MediaKitLiveMpvBufferStep liveMpvBufferStep(int step) {
    final s = step.clamp(0, 2);
    final ram = _totalRamBytes;
    const giB = 1024 * 1024 * 1024;

    if (ram != null && ram < oneGiBRamClassMaxBytes) {
      switch (s) {
        case 0:
          return MediaKitLiveMpvBufferStep(
            cacheSizeKiB: 2048,
            demuxerMaxBytes: 2 * 1024 * 1024,
            demuxerMaxBackBytes: 1024 * 1024,
          );
        case 1:
          return MediaKitLiveMpvBufferStep(
            cacheSizeKiB: 8192,
            demuxerMaxBytes: 8 * 1024 * 1024,
            demuxerMaxBackBytes: 4 * 1024 * 1024,
          );
        default:
          return MediaKitLiveMpvBufferStep(
            cacheSizeKiB: 16384,
            demuxerMaxBytes: 12 * 1024 * 1024,
            demuxerMaxBackBytes: 6 * 1024 * 1024,
          );
      }
    }

    if (ram != null && ram >= 2 * giB && ram < 3 * giB) {
      // 2 GiB kutular (X96/T95/H618/KM2 Plus): dar tampon — RAM sınırlı (donma/GC önleme).
      if (budgetTvBoxSoc) {
        switch (s) {
          case 0:
            return MediaKitLiveMpvBufferStep(
              cacheSizeKiB: 2048,
              demuxerMaxBytes: 2 * 1024 * 1024,
              demuxerMaxBackBytes: 1024 * 1024,
            );
          case 1:
            return MediaKitLiveMpvBufferStep(
              cacheSizeKiB: 8192,
              demuxerMaxBytes: 10 * 1024 * 1024,
              demuxerMaxBackBytes: 4 * 1024 * 1024,
            );
          default:
            return MediaKitLiveMpvBufferStep(
              cacheSizeKiB: 16384,
              demuxerMaxBytes: 14 * 1024 * 1024,
              demuxerMaxBackBytes: 8 * 1024 * 1024,
            );
        }
      }
      // Düşük segment smart TV (TCL/Philips/Toshiba MTK): dengeli tampon.
      if (lowEndSmartTvLike) {
        switch (s) {
          case 0:
            return MediaKitLiveMpvBufferStep(
              cacheSizeKiB: 4096,
              demuxerMaxBytes: 4 * 1024 * 1024,
              demuxerMaxBackBytes: 2 * 1024 * 1024,
            );
          case 1:
            return MediaKitLiveMpvBufferStep(
              cacheSizeKiB: 12288,
              demuxerMaxBytes: 12 * 1024 * 1024,
              demuxerMaxBackBytes: 6 * 1024 * 1024,
            );
          default:
            return MediaKitLiveMpvBufferStep(
              cacheSizeKiB: 20480,
              demuxerMaxBytes: 16 * 1024 * 1024,
              demuxerMaxBackBytes: 8 * 1024 * 1024,
            );
        }
      }
      switch (s) {
        case 0:
          return MediaKitLiveMpvBufferStep(
            cacheSizeKiB: 4096,
            demuxerMaxBytes: 4 * 1024 * 1024,
            demuxerMaxBackBytes: 2 * 1024 * 1024,
          );
        case 1:
          return MediaKitLiveMpvBufferStep(
            cacheSizeKiB: 12288,
            demuxerMaxBytes: 12 * 1024 * 1024,
            demuxerMaxBackBytes: 6 * 1024 * 1024,
          );
        default:
          return MediaKitLiveMpvBufferStep(
            cacheSizeKiB: 20480,
            demuxerMaxBytes: 16 * 1024 * 1024,
            demuxerMaxBackBytes: 8 * 1024 * 1024,
          );
      }
    }

    switch (s) {
      case 0:
        // Telefon/tablet (≥3 GiB): eski 512 KiB + 768 KB demuxer canlı HLS'de
        // readahead=30 ile çakışıp açılmama / siyah ekran yapıyordu.
        return MediaKitLiveMpvBufferStep(
          cacheSizeKiB: 4096,
          demuxerMaxBytes: 4 * 1024 * 1024,
          demuxerMaxBackBytes: 2 * 1024 * 1024,
        );
      case 1:
        return MediaKitLiveMpvBufferStep(
          cacheSizeKiB: 16384,
          demuxerMaxBytes: 16 * 1024 * 1024,
          demuxerMaxBackBytes: 8 * 1024 * 1024,
        );
      default:
        return MediaKitLiveMpvBufferStep(
          cacheSizeKiB: 65536,
          demuxerMaxBytes: 64 * 1024 * 1024,
          demuxerMaxBackBytes: 32 * 1024 * 1024,
        );
    }
  }

  /// Exo [bufferForPlaybackMs]: güçlü cihazda 2500, aksi halde 5000 ([ensureLoaded] sonrası kesin).
  static int _iptvBufferForPlaybackMs = 5000;

  /// [ensureLoaded] tamamlanmadan [false] döner.
  static bool get amlogicLike => _amlogicLike ?? false;

  /// Allwinner (sunxi / H618 vb.) ucuz 4K TV kutuları. Donanım kod çözücü zayıf;
  /// 2 GiB RAM + 4 çekirdek olsa bile 4K VOD/canlıda takılma yapar.
  static bool get allwinnerLike => _allwinnerLike ?? false;

  /// Rockchip (rk3318 / rk3328 vb.) ucuz TV kutuları — Allwinner ile aynı sınıf.
  static bool get rockchipLike => _rockchipLike ?? false;

  /// Ucuz TV kutusu yonga seti (Allwinner / Rockchip / X96-T95 jenerik). Native
  /// [budgetTvBoxSoc] bayrağı varsa onu kullanır.
  static bool get budgetTvBoxSoc =>
      _budgetTvBoxSocNative ??
      (allwinnerLike || rockchipLike || (_genericBudgetBoxLike ?? false));

  /// Eski tablet / TV box (düşük RAM veya ≤4 çekirdek). MediaKit için framedrop vb. sıkılaştırılır.
  static bool get weakMpvDevice => _weakMpvDevice ?? false;

  /// Leanback / television (Android TV). [ensureLoaded] sonrası güvenilir.
  static bool get androidTv => _androidTv ?? false;

  /// TCL / MediaTek / Realtek / Amlogic Android TV: VOD donanım kod çözücü ve
  /// mpv `mediacodec-copy` sık başarısız — yazılım Exo + `mediacodec` tercih edilir.
  ///
  /// Ayrıca markası/yonga seti tanınmayan ama **zayıf** (≤4 çekirdek veya
  /// < 2.5 GiB RAM) TV kutuları da bu sınıfa girer (ör. Mi Box nesli, "Next Pro"
  /// gibi jenerik kutular). Böylece mpv `hwdec=mediacodec` (doğrudan yüzey,
  /// hafif) + geniş canlı tampon alırlar; `mediacodec-copy` zayıf GPU'larda
  /// kasmaya yol açıyordu.
  static bool get playbackChallengedTv => _playbackChallengedTv ?? false;

  /// Piyasadaki en yaygın 4K Android/Google TV ve TV box'lar (Onn 4K, Chromecast
  /// 4K, Mi Box S, Mecool KM2, Fire TV 4K, Nvidia Shield, modern TCL/Sony/
  /// Hisense Google TV) **dört çekirdekli** ve çoğu **2–3 GiB RAM**'dir; donanım
  /// kod çözücüleri yüksek bit hızlı 4K'yı rahat kaldırır. Ancak hepsi dört
  /// çekirdekli olduğundan mevcut "challenged/≤4 çekirdek" kuralıyla zorla `low`
  /// profile düşüyor ve 4K VOD'da demuxer tamponu aç kalıp donuyordu.
  ///
  /// Bu getter, [playbackChallengedTv] sınıfına girse de 4K VOD'u taşıyabilecek
  /// cihazları işaretler: **≥4 çekirdek ve ≥2 GiB RAM**. Yalnızca mpv VOD
  /// ayarlarında (decode thread + framedrop) `mid` gibi davranmak için kullanılır;
  /// cihazın genel güç sınıfı (Exo canlı tamponu, hwdec kuralı) değişmez — canlı
  /// davranışı korunur. Gerçekten zayıf eski yongalar (< 2 GiB, ör. S805/S905W
  /// nesli) `low` kalır. RAM/çekirdek bilinmiyorsa güvenli tarafta `false`.
  static bool get capableChallengedTvForVod {
    if (_capableTwoGiBTvBox == true) return true;
    if (!(_playbackChallengedTv ?? false)) return false;
    // Allwinner H618 / Rockchip rk33xx: 2 GiB + 4 çekirdek olsa bile Chromecast
    // 4K / Mi Box S gibi «yeterli» değil; mpv VOD'u `mid` profile yükseltmek
    // donmayı artırıyordu (Digipoll GO2 vb.).
    if (budgetTvBoxSoc) return false;
    final ram = _totalRamBytes;
    final cores = _availableProcessors;
    if (ram == null || cores == null) return false;
    return ram >= lowRamThresholdBytes && cores >= 4;
  }

  /// Xiaomi / Redmi / POCO / Black Shark. Adaptif tavan ve [useTextureView] ipucu için.
  static bool get xiaomiFamily => _xiaomiFamily ?? false;

  /// Xiaomi telefon/tablet (Mi Box / MITV değil).
  static bool get xiaomiHandheld => xiaomiFamily && !androidTv;

  /// [Build.MODEL] (ör. `SM-T530`). [ensureLoaded] sonrası; aksi `null`.
  static String? get buildModel => _buildModel;

  /// Galaxy Tab 4 10.1 Wi‑Fi — MediaKit’te mor/pembe renk için yazılım çözücü (`hwdec=no`) gerekir.
  static bool get isSamsungSmT530 {
    final m = _buildModel;
    if (m == null) return false;
    return m.trim().toUpperCase() == 'SM-T530';
  }

  /// IPTV Better Player başlangıç tamponu (ms). Android’de RAM+çekirdek; diğer platformlarda çekirdek sayısı.
  static int get iptvBufferForPlaybackMs => _iptvBufferForPlaybackMs;

  static Future<void> ensureLoaded() async {
    if (kIsWeb) {
      _amlogicLike ??= false;
      _allwinnerLike ??= false;
      _rockchipLike ??= false;
      _genericBudgetBoxLike ??= false;
      _budgetTvBoxSocNative ??= false;
      _lowEndSmartTvLike ??= false;
      _capableTwoGiBTvBox ??= false;
      _weakMpvDevice ??= false;
      _androidTv ??= false;
      _playbackChallengedTv ??= false;
      _xiaomiFamily ??= false;
      _buildModel = null;
      _totalRamBytes = null;
      _availableProcessors = null;
      _segment = DevicePlaybackSegment.mid;
      _iptvBufferForPlaybackMs = 5000;
      return;
    }
    if (!Platform.isAndroid) {
      _amlogicLike ??= false;
      _allwinnerLike ??= false;
      _rockchipLike ??= false;
      _genericBudgetBoxLike ??= false;
      _budgetTvBoxSocNative ??= false;
      _lowEndSmartTvLike ??= false;
      _capableTwoGiBTvBox ??= false;
      _weakMpvDevice ??= false;
      _androidTv ??= false;
      _playbackChallengedTv ??= false;
      _xiaomiFamily ??= false;
      _buildModel = null;
      _totalRamBytes = null;
      _availableProcessors = Platform.numberOfProcessors;
      _segment = _deriveSegmentNonAndroid();
      _iptvBufferForPlaybackMs = _bufferForPlaybackMsNonAndroid();
      return;
    }
    if (_amlogicLike != null) return;
    _loading ??= _load();
    await _loading;
  }

  static int _bufferForPlaybackMsNonAndroid() {
    final n = Platform.numberOfProcessors;
    return n >= 6 ? 2500 : 5000;
  }

  static int? _parsePositiveInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v >= 0 ? v : null;
    if (v is double) return v >= 0 ? v.round() : null;
    return int.tryParse(v.toString());
  }

  static Future<void> _load() async {
    try {
      final raw =
          await kMinaDeviceLayoutChannel.invokeMethod<dynamic>('mediaKitSoCProfile');
      if (raw is Map) {
        final v = raw['amlogicLike'];
        _amlogicLike = v == true;
        _allwinnerLike = raw['allwinnerLike'] == true;
        _rockchipLike = raw['rockchipLike'] == true;
        _genericBudgetBoxLike = raw['genericBudgetBoxLike'] == true;
        _budgetTvBoxSocNative = raw['budgetTvBoxSoc'] == true;
        _lowEndSmartTvLike = raw['lowEndSmartTvLike'] == true;
        _capableTwoGiBTvBox = raw['capableTwoGiBTvBox'] == true;
        _weakMpvDevice = raw['weakMpvDevice'] == true;
        _androidTv = raw['isAndroidTv'] == true;
        _playbackChallengedTv = raw['playbackChallengedTv'] == true;
        _xiaomiFamily = raw['xiaomiFamily'] == true;

        final mod = raw['model'];
        _buildModel = mod is String ? mod : null;

        final ram = _parsePositiveInt(raw['totalRamBytes']);
        _totalRamBytes = ram;
        final cores = _parsePositiveInt(raw['availableProcessors']);
        _availableProcessors = cores;
        _segment = _deriveSegment(
          ramBytes: ram,
          cores: cores,
          weakMpv: _weakMpvDevice ?? false,
          playbackChallengedTv: _playbackChallengedTv ?? false,
        );
        const fourGiB = 4 * 1024 * 1024 * 1024;
        if (ram != null &&
            cores != null &&
            ram >= fourGiB &&
            cores >= 6) {
          _iptvBufferForPlaybackMs = 2500;
        } else {
          _iptvBufferForPlaybackMs = 5000;
        }
        // Güçlü sayılan TV kutularında bile 1080 canlıda 2,5 s başlangıç tamponu sık yetmez.
        if (_androidTv == true && _iptvBufferForPlaybackMs < 4500) {
          _iptvBufferForPlaybackMs = 4500;
        }
        if (kDebugMode) debugPrint(
          'mina_iptv: playback segment=${_segment.name} '
          'ram=${ram != null ? "${(ram / (1024 * 1024 * 1024)).toStringAsFixed(1)}GiB" : "?"} '
          'cores=${cores ?? "?"} weakMpv=$_weakMpvDevice '
          'oneGiBClass=${ram != null && ram < oneGiBRamClassMaxBytes} '
          'challengedTv=$_playbackChallengedTv '
          'lowEndTv=$_lowEndSmartTvLike capable2G=$_capableTwoGiBTvBox '
          'allwinner=$_allwinnerLike rockchip=$_rockchipLike genericBudget=$_genericBudgetBoxLike',
        );
        return;
      }
    } on Exception {
      // ignore
    }
    _amlogicLike = false;
    _allwinnerLike = false;
    _rockchipLike = false;
    _weakMpvDevice = false;
    _androidTv ??= false;
    _playbackChallengedTv ??= false;
    _xiaomiFamily ??= false;
    _buildModel = null;
    _totalRamBytes = null;
    _availableProcessors = null;
    _segment = DevicePlaybackSegment.mid;
    _iptvBufferForPlaybackMs = 5000;
  }
}

/// Canlı MediaKit (libmpv) tampon kademesi — [AndroidPlaybackSocHints.liveMpvBufferStep].
class MediaKitLiveMpvBufferStep {
  const MediaKitLiveMpvBufferStep({
    required this.cacheSizeKiB,
    required this.demuxerMaxBytes,
    required this.demuxerMaxBackBytes,
  });

  final int cacheSizeKiB;
  final int demuxerMaxBytes;
  final int demuxerMaxBackBytes;
}
