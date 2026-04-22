import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../layout/app_layout_mode.dart';
import '../services/app_settings_service.dart';

/// Mobil tam ekran oynatıcıda Better Player ve Media Kit için ortak yön kilidi.
///
/// [SystemChrome.setPreferredOrientations] ile OS düzeyinde zorlanır; kullanıcıda
/// «otomatik döndürme» kapalı olsa bile uygulama izin verdiği yönlere geçebilir.
abstract final class PlaybackOrientationManager {
  static bool get _platformOk =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static AppSettingsService? get _app =>
      Get.isRegistered<AppSettingsService>() ? Get.find<AppSettingsService>() : null;

  static bool _mobile(AppSettingsService app) =>
      app.layoutMode.value == AppLayoutMode.mobile;

  /// MediaKit yüzeyi hazır olduktan sonra (Exo ↔ mpv geçişi) mobil chrome’u tazele.
  static Future<void> onMediaKitVideoSurfaceReady() async {
    final app = _app;
    if (!_platformOk || app == null || !_mobile(app)) return;
    await app.syncMobileHandheldChromeToCurrentOrientation();
  }

  /// Yatay izlerken OSD’den dikeye zorla.
  static Future<void> forcePortraitMobilePlayback() async {
    final app = _app;
    if (!_platformOk || app == null || !_mobile(app)) return;
    app.mobilePlaybackPortraitUserLocked.value = true;
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await app.applyMobilePlayerOrientationChrome(landscapePlayback: false);
  }

  /// Dikey izlerken veya dikey kilitten yatay tam ekrana dön.
  static Future<void> forceLandscapeMobilePlayback() async {
    final app = _app;
    if (!_platformOk || app == null || !_mobile(app)) return;
    app.mobilePlaybackPortraitUserLocked.value = false;
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await app.applyMobilePlayerOrientationChrome(landscapePlayback: true);
  }

  /// Tüm yönler (sistem davranışına bırakılır).
  static Future<void> releaseToAllOrientationsMobilePlayback() async {
    final app = _app;
    if (!_platformOk || app == null || !_mobile(app)) return;
    app.mobilePlaybackPortraitUserLocked.value = false;
    await SystemChrome.setPreferredOrientations(
      List<DeviceOrientation>.from(DeviceOrientation.values),
    );
    await app.syncMobileHandheldChromeToCurrentOrientation();
  }

  /// Dikey + yatay (sensörle döndürme; el tipi cihaz varsayılanı).
  static Future<void> releaseToSensorMobilePlayback() async {
    final app = _app;
    if (!_platformOk || app == null || !_mobile(app)) return;
    app.mobilePlaybackPortraitUserLocked.value = false;
    await SystemChrome.setPreferredOrientations(
      AppSettingsService.sensorHandheldOrientations,
    );
    await app.syncMobileHandheldChromeToCurrentOrientation();
  }

  /// Dikey + yatay/// Sensör moduna döner (sistem otomatik döndürmesine izin verir).
  static Future<void> requestMobileHandheldSensorPlayback() async {
    final app = _app;
    if (!_platformOk || app == null || !_mobile(app)) return;
    app.mobilePlaybackPortraitUserLocked.value = false;
    await SystemChrome.setPreferredOrientations(
      AppSettingsService.sensorHandheldOrientations,
    );
    await app.syncMobileHandheldChromeToCurrentOrientation();
  }

  /// Mobil modda zorunlu yatay/dikey geçiþ toggle
  static Future<void> toggleMobileForcedOrientation() async {
    final app = _app;
    if (!_platformOk || app == null || !_mobile(app)) return;
    
    if (app.mobilePlaybackPortraitUserLocked.value) {
      // Portre kilitli -> yataya zorla
      app.mobilePlaybackPortraitUserLocked.value = false;
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Yatay kilitli -> dikeye zorla
      app.mobilePlaybackPortraitUserLocked.value = true;
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }
}
