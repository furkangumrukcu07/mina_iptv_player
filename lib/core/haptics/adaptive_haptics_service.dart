import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../layout/app_layout_mode.dart';
import '../services/app_settings_service.dart';

/// Mobil modda liste kaydırma ve seçimlerde hafif titreşim.
///
/// Samsung One UI ve benzeri OEM'lerde Flutter'ın varsayılan
/// `HapticFeedback.selectionClick()` çağrısı (Android'de
/// `View.performHapticFeedback(CLOCK_TICK)`) çoğu zaman no-op'a düşüyor:
/// kullanıcı sistem dokunma geri bildirimini açık tutsa bile titreşim
/// üretilmiyor. Bu sınıf Android'de doğrudan native `Vibrator`/`VibratorManager`
/// API'sini tetikleyen bir MethodChannel kullanır (vendor mapping'i atlanır);
/// köprü kullanılamıyorsa Flutter'ın daha güvenilir `lightImpact` sabitine
/// (`VIRTUAL_KEY`) düşer.
class AdaptiveHapticsService extends GetxService {
  static const _androidHapticsChannel = MethodChannel('mina.device/haptics');

  DateTime? _lastScrollHapticAt;
  DateTime? _lastSelectionAt;
  double _lastScrollPixels = 0;

  /// Daha seyrek ve hafif kaydırma titreşimi.
  static const _scrollMinInterval = Duration(milliseconds: 118);
  static const _scrollMinPixelDelta = 58.0;
  static const _selectionMinInterval = Duration(milliseconds: 95);

  /// Android'de native köprü kullanılabilir mi (lazy probe, tek seferlik).
  bool? _androidNativeHapticsAvailable;
  Future<void>? _androidProbe;

  bool get _active {
    if (kIsWeb) return false;
    if (!Get.isRegistered<AppSettingsService>()) return false;
    final app = Get.find<AppSettingsService>();
    return app.adaptiveHapticsEnabled.value &&
        app.layoutMode.value == AppLayoutMode.mobile;
  }

  @override
  void onInit() {
    super.onInit();
    // Köprüyü erken doldur (ilk kaydırmada platform call gecikmesi olmasın).
    if (!kIsWeb && !kIsWasm && Platform.isAndroid) {
      _androidProbe = _probeAndroidHaptics();
      unawaited(_androidProbe);
    }
  }

  Future<void> _probeAndroidHaptics() async {
    try {
      final ok = await _androidHapticsChannel.invokeMethod<bool>('hasVibrator');
      _androidNativeHapticsAvailable = ok ?? false;
    } catch (_) {
      _androidNativeHapticsAvailable = false;
    }
  }

  bool get _isAndroid {
    if (kIsWeb || kIsWasm) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Dokunma / liste öğesi seçimi.
  void selection() {
    if (!_active) return;
    final now = DateTime.now();
    if (_lastSelectionAt != null &&
        now.difference(_lastSelectionAt!) < _selectionMinInterval) {
      return;
    }
    _lastSelectionAt = now;
    _emit('selection');
  }

  /// [ScrollNotification] — uygulama kökündeki dinleyiciden çağrılır.
  void onScrollNotification(ScrollNotification notification) {
    if (!_active) return;

    if (notification is ScrollStartNotification) {
      _lastScrollPixels = notification.metrics.pixels;
      return;
    }
    if (notification is! ScrollUpdateNotification) return;

    // Yalnızca parmakla sürüklerken; atalet kaydırmasında titreşim yok.
    if (notification.dragDetails == null) return;

    final delta = notification.scrollDelta;
    if (delta == null || delta.abs() < 1.2) return;

    final now = DateTime.now();
    final pixels = notification.metrics.pixels;
    if (_lastScrollHapticAt != null &&
        now.difference(_lastScrollHapticAt!) < _scrollMinInterval) {
      return;
    }
    if ((pixels - _lastScrollPixels).abs() < _scrollMinPixelDelta) return;

    _lastScrollHapticAt = now;
    _lastScrollPixels = pixels;
    _emit('tick');
  }

  /// Tek noktadan titreşim çıkışı: önce Android native köprü, yoksa Flutter
  /// `HapticFeedback` (Samsung'da daha güvenilir olan `lightImpact`'e map'lenir).
  void _emit(String kind) {
    if (_isAndroid && _androidNativeHapticsAvailable != false) {
      // Native probe henüz dönmediyse bile çağrıyı dener; başarısız olursa
      // Flutter fallback'i bir sonraki çağrıdan itibaren devreye girer.
      unawaited(_invokeAndroid(kind));
      return;
    }
    _flutterFallback(kind);
  }

  Future<void> _invokeAndroid(String kind) async {
    try {
      final ok = await _androidHapticsChannel.invokeMethod<bool>(kind);
      if (ok == true) return;
      _androidNativeHapticsAvailable = false;
      _flutterFallback(kind);
    } on PlatformException catch (_) {
      _androidNativeHapticsAvailable = false;
      _flutterFallback(kind);
    } on MissingPluginException catch (_) {
      _androidNativeHapticsAvailable = false;
      _flutterFallback(kind);
    } catch (_) {
      _androidNativeHapticsAvailable = false;
      _flutterFallback(kind);
    }
  }

  /// Flutter `HapticFeedback` fallback: Samsung One UI gibi cihazlarda
  /// `selectionClick` (CLOCK_TICK) no-op'a düşebildiği için `lightImpact`
  /// (VIRTUAL_KEY) tercih ediliyor — vendor mapping'lerinde çok daha tutarlı.
  void _flutterFallback(String kind) {
    try {
      switch (kind) {
        case 'heavy':
          HapticFeedback.mediumImpact();
          break;
        case 'medium':
          HapticFeedback.mediumImpact();
          break;
        case 'selection':
        case 'tick':
        default:
          HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint('mina_iptv: adaptive haptic fallback skipped: $e');
      }
    }
  }

  /// Dokunma geri çağrısını titreşimle sarar.
  VoidCallback? wrapTap(VoidCallback? onTap) {
    if (onTap == null) return null;
    return () {
      selection();
      onTap();
    };
  }
}
