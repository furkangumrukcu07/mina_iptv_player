import 'dart:io';

import 'device_layout_defaults.dart';

/// Android: Amlogic / Meson tabanlı kutularda MediaKit (mpv) için donanım ve tampon yolu.
///
/// Native [Build] alanları bir kez okunur; sonuç önbelleğe alınır.
class AndroidPlaybackSocHints {
  AndroidPlaybackSocHints._();

  static bool? _amlogicLike;
  static Future<void>? _loading;

  /// [ensureLoaded] tamamlanmadan [false] döner.
  static bool get amlogicLike => _amlogicLike ?? false;

  static Future<void> ensureLoaded() async {
    if (!Platform.isAndroid) {
      _amlogicLike ??= false;
      return;
    }
    if (_amlogicLike != null) return;
    _loading ??= _load();
    await _loading;
  }

  static Future<void> _load() async {
    try {
      final raw =
          await kMinaDeviceLayoutChannel.invokeMethod<dynamic>('mediaKitSoCProfile');
      if (raw is Map) {
        final v = raw['amlogicLike'];
        _amlogicLike = v == true;
        return;
      }
    } on Exception {
      // ignore
    }
    _amlogicLike = false;
  }
}
