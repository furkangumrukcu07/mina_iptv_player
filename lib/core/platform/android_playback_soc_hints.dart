import 'dart:io';

import 'package:flutter/foundation.dart';

import 'device_layout_defaults.dart';

/// Android: Amlogic / Meson tabanlı kutularda MediaKit (mpv) için donanım ve tampon yolu.
///
/// Native [Build] alanları bir kez okunur; sonuç önbelleğe alınır.
class AndroidPlaybackSocHints {
  AndroidPlaybackSocHints._();

  static bool? _amlogicLike;
  static bool? _weakMpvDevice;
  static bool? _androidTv;
  static bool? _xiaomiFamily;
  static String? _buildModel;
  static int? _totalRamBytes;
  static Future<void>? _loading;

  /// 2 GiB — Better Player önbellek / başlangıç çözünürlük kısıtı için.
  static const int lowRamThresholdBytes = 2 * 1024 * 1024 * 1024;

  /// Toplam fiziksel RAM (byte). Yalnızca Android’de ve [ensureLoaded] sonrası dolu.
  static int? get totalRamBytes => _totalRamBytes;

  /// Toplam RAM biliniyorsa ve [maxBytes]’tan küçükse `true`. Bilinmiyorsa `false` (kısıtlama uygulanmaz).
  static bool isTotalRamBelowBytes(int maxBytes) {
    final b = _totalRamBytes;
    if (b == null) return false;
    return b < maxBytes;
  }

  /// Exo [bufferForPlaybackMs]: güçlü cihazda 2500, aksi halde 5000 ([ensureLoaded] sonrası kesin).
  static int _iptvBufferForPlaybackMs = 5000;

  /// [ensureLoaded] tamamlanmadan [false] döner.
  static bool get amlogicLike => _amlogicLike ?? false;

  /// Eski tablet / TV box (düşük RAM veya ≤4 çekirdek). MediaKit için framedrop vb. sıkılaştırılır.
  static bool get weakMpvDevice => _weakMpvDevice ?? false;

  /// Leanback / television (Android TV). [ensureLoaded] sonrası güvenilir.
  static bool get androidTv => _androidTv ?? false;

  /// Xiaomi / Redmi / POCO / Black Shark. Adaptif tavan ve [useTextureView] ipucu için.
  static bool get xiaomiFamily => _xiaomiFamily ?? false;

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
      _weakMpvDevice ??= false;
      _androidTv ??= false;
      _xiaomiFamily ??= false;
      _buildModel = null;
      _totalRamBytes = null;
      _iptvBufferForPlaybackMs = 5000;
      return;
    }
    if (!Platform.isAndroid) {
      _amlogicLike ??= false;
      _weakMpvDevice ??= false;
      _androidTv ??= false;
      _xiaomiFamily ??= false;
      _buildModel = null;
      _totalRamBytes = null;
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
        _weakMpvDevice = raw['weakMpvDevice'] == true;
        _androidTv = raw['isAndroidTv'] == true;
        _xiaomiFamily = raw['xiaomiFamily'] == true;

        final mod = raw['model'];
        _buildModel = mod is String ? mod : null;

        final ram = _parsePositiveInt(raw['totalRamBytes']);
        _totalRamBytes = ram;
        final cores = _parsePositiveInt(raw['availableProcessors']);
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
        return;
      }
    } on Exception {
      // ignore
    }
    _amlogicLike = false;
    _weakMpvDevice = false;
    _androidTv ??= false;
    _xiaomiFamily ??= false;
    _buildModel = null;
    _totalRamBytes = null;
    _iptvBufferForPlaybackMs = 5000;
  }
}
