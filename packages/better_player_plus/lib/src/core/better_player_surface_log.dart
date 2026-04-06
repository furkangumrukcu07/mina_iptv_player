// ignore_for_file: avoid_classes_with_only_static_members — yapılandırılabilir yüzey/texture izleme köprüsü

import 'package:flutter/foundation.dart';

/// Hızlı kanal değişiminde [Texture] / platform yüzey ömrünü izlemek için.
/// Filtre: `adb logcat -s BetterPlayerSurface` (Android) veya IDE’de `[BetterPlayerSurface]`.
///
/// Release’de de görmek için uygulama başında:
/// `BetterPlayerSurfaceLog.enabled = true;`
abstract final class BetterPlayerSurfaceLog {
  static const String prefix = '[BetterPlayerSurface]';

  /// Profil / debug varsayılanı açık; release’de sızıntı aramak için elle açılabilir.
  static bool enabled = !kReleaseMode;

  static void _emit(String message) {
    if (!enabled) {
      return;
    }
    debugPrint('$prefix $message');
  }

  static void textureCreate(int? textureId) {
    _emit('Dart VideoPlayerController: create completed textureId=$textureId');
  }

  static void texturePlatformDisposeCall(int? textureId) {
    _emit('Dart: invoking platform dispose textureId=$textureId');
  }

  static void texturePlatformDisposeDone(int? textureId) {
    _emit('Dart: platform dispose finished textureId=$textureId');
  }

  static void setDataSourceSameTexture(int? textureId) {
    _emit(
      'Dart: setDataSource (same Flutter textureId, native SurfaceProducer retained) textureId=$textureId',
    );
  }
}
