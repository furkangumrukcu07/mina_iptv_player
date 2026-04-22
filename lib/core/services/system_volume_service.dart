import 'package:flutter/foundation.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:get/get.dart';

/// Sistem ses seviyesini yöneten servis.
/// Hem Better Player hem de MediaKit için ortak ses kontrolü sunar.
class SystemVolumeService extends GetxService {
  static SystemVolumeService get to => Get.find();

  /// Sistem ses seviyesini 0.0 - 1.0 araliginda tutar.
  final RxDouble _systemVolume = 0.5.obs;

  /// Sistem ses seviyesini ValueNotifier olarak expose eder.
  final ValueNotifier<double> _volumeNotifier = ValueNotifier<double>(0.5);
  ValueNotifier<double> get volumeNotifier => _volumeNotifier;

  /// Mevcut sistem ses seviyesi (0.0 - 1.0).
  double get currentVolume => _systemVolume.value;

  
  @override
  Future<void> onInit() async {
    super.onInit();

    // Mobilde uygulama içi ses ayarında sistem ses HUD'unu gösterme.
    // (TV’de zaten kullanılmıyor; Android/iOS’ta desteklenir.)
    try {
      VolumeController().showSystemUI = false;
    } catch (_) {}
    
    // Mevcut sistem ses seviyesini al
    try {
      final volumeController = VolumeController();
      final initialVolume = await volumeController.getVolume();
      _systemVolume.value = initialVolume.clamp(0.0, 1.0);
      _volumeNotifier.value = _systemVolume.value;
    } catch (e) {
      if (kDebugMode) {
        print('SystemVolumeService: Initial volume fetch failed: $e');
      }
      // Hata durumunda varsayilan deger
      _systemVolume.value = 0.5;
      _volumeNotifier.value = 0.5;
    }
  }

  @override
  void onClose() {
    // Uygulama kapanırken varsayılana döndür (diğer uygulamalar etkilenmesin).
    try {
      VolumeController().showSystemUI = true;
    } catch (_) {}
    _volumeNotifier.dispose();
    super.onClose();
  }

  /// Sistem ses seviyesini ayarlar (0.0 - 1.0).
  Future<void> setVolume(double value) async {
    // Uygulama ses seviyesi 0.0-1.5 aralığında, sistem sesi 0.0-1.0 aralığında
    // Kullanıcı 100% ses seviyesini istediğinde, uygulamanın %100'ı sistemin %100'üne eşitle
    final clampedValue = value.clamp(0.0, 1.0);
    final scaledValue = clampedValue; // 1:1 scaling - %100 = %100
    
    try {
      final volumeController = VolumeController();
      // Sistem ses seviyesini ayarla (showUI parametresi desteklenmiyor)
      volumeController.setVolume(scaledValue);
      _systemVolume.value = scaledValue;
      _volumeNotifier.value = scaledValue;
    } catch (e) {
      if (kDebugMode) {
        print('SystemVolumeService: Set volume failed: $e');
      }
    }
  }

  /// Sistem ses seviyesini artirir.
  Future<void> increaseVolume(double delta) async {
    final newValue = (_systemVolume.value + delta).clamp(0.0, 1.0);
    await setVolume(newValue);
  }

  /// Sistem ses seviyesini azaltir.
  Future<void> decreaseVolume(double delta) async {
    final newValue = (_systemVolume.value - delta).clamp(0.0, 1.0);
    await setVolume(newValue);
  }

  /// Sesi kapatir (0.0).
  Future<void> mute() async {
    await setVolume(0.0);
  }

  /// Sesi %100 yapar (1.0).
  Future<void> unmute() async {
    await setVolume(1.0);
  }
}
