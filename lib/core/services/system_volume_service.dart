import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';

import '../../modules/player/widgets/player_glass_level_overlay.dart';

/// Sistem ses seviyesini yöneten servis.
/// Fiziksel ses tuşlarını dinler, sistem ses seviyesini değiştirir ve
/// sistem ses barını gizleyerek yerine özel cam temalı OSD gösterir.
class SystemVolumeService extends GetxService with WidgetsBindingObserver {
  static SystemVolumeService get to => Get.find();

  /// Mevcut sistem ses seviyesi (0.0 - 1.0).
  final RxDouble _systemVolume = 0.5.obs;
  double get currentVolume => _systemVolume.value;

  /// OSD gösterim durumu.
  final RxBool _showOsd = false.obs;
  Timer? _osdTimer;

  /// Global OSD Overlay Entry.
  OverlayEntry? _overlayEntry;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _initialize();

    // Global tuş yakalayıcıyı ekle
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  Future<void> _initialize() async {
    // 1. Sistem ses barını gizle
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
    } catch (e) {
      debugPrint('SystemVolumeService: Failed to hide system UI: $e');
    }

    // 2. Mevcut ses seviyesini al
    try {
      final volume = await FlutterVolumeController.getVolume();
      if (volume != null) {
        _systemVolume.value = volume.clamp(0.0, 1.0);
      }
    } catch (e) {
      debugPrint('SystemVolumeService: Failed to get initial volume: $e');
    }

    // 3. Ses değişikliklerini dinle
    FlutterVolumeController.addListener((volume) {
      // Ses seviyesi değiştiğinde (fiziksel tuşlar dahil)
      _systemVolume.value = volume.clamp(0.0, 1.0);
      _triggerOsd();
    });
  }

  /// Global tuş yakalayıcı: Fiziksel ses tuşlarını yakalayıp tüketir (consume).
  /// Bu sayede Android/iOS tarafında sistem ses barının çıkması engellenir.
  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.audioVolumeUp) {
      increaseVolume(0.05);
      return true; // Event'i tüket, sistem barını engelle
    } else if (key == LogicalKeyboardKey.audioVolumeDown) {
      decreaseVolume(0.05);
      return true; // Event'i tüket, sistem barını engelle
    }

    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Uygulama öne geldiğinde sistem sesini tekrar senkronize et ve UI'ı gizle
      _syncVolumeAndHideUi();
    }
  }

  Future<void> _syncVolumeAndHideUi() async {
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
      final oldVolume = _systemVolume.value;
      final volume = await FlutterVolumeController.getVolume();
      if (volume != null) {
        final newVolume = volume.clamp(0.0, 1.0);
        _systemVolume.value = newVolume;

        // Eğer ses seviyesi uygulama dışındayken değişmişse OSD'yi göster
        if ((oldVolume - newVolume).abs() > 0.01) {
          _triggerOsd();
        }
      }
    } catch (e) {
      debugPrint('SystemVolumeService: Sync failed: $e');
    }
  }

  void _triggerOsd() {
    _showOsd.value = true;
    _osdTimer?.cancel();

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: (context) => Obx(() => IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _showOsd.value ? 1.0 : 0.0,
                child: PlayerGlassLevelOverlay(
                  visible: _showOsd.value,
                  icon: playerVolumeIconFor(_systemVolume.value),
                  value01: _systemVolume.value,
                ),
              ),
            )),
      );

      final overlay =
          Get.overlayContext != null ? Overlay.of(Get.overlayContext!) : null;

      if (overlay != null) {
        overlay.insert(_overlayEntry!);
      } else {
        _overlayEntry = null;
      }
    }

    _osdTimer = Timer(const Duration(milliseconds: 2000), () {
      _showOsd.value = false;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!_showOsd.value) {
          if (_overlayEntry?.mounted ?? false) {
            _overlayEntry?.remove();
          }
          _overlayEntry = null;
        }
      });
    });
  }

  @override
  void onClose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    WidgetsBinding.instance.removeObserver(this);
    FlutterVolumeController.removeListener();
    // Uygulama kapanırken sistem barını geri aç
    FlutterVolumeController.updateShowSystemUI(true);
    _osdTimer?.cancel();
    if (_overlayEntry?.mounted ?? false) {
      _overlayEntry?.remove();
    }
    super.onClose();
  }

  /// Sistem ses seviyesini ayarlar (0.0 - 1.0).
  Future<void> setVolume(double value) async {
    final clampedValue = value.clamp(0.0, 1.0);
    try {
      // Her ses değişiminde UI gizleme komutunu tekrar gönder (bazı Android'lerde sıfırlanabiliyor)
      await FlutterVolumeController.updateShowSystemUI(false);
      await FlutterVolumeController.setVolume(clampedValue);
      _systemVolume.value = clampedValue;
    } catch (e) {
      debugPrint('SystemVolumeService: Set volume failed: $e');
    }
  }

  /// Sistem ses seviyesini artırır.
  Future<void> increaseVolume(double delta) async {
    final newValue = (_systemVolume.value + delta).clamp(0.0, 1.0);
    await setVolume(newValue);
  }

  /// Sistem ses seviyesini azaltır.
  Future<void> decreaseVolume(double delta) async {
    final newValue = (_systemVolume.value - delta).clamp(0.0, 1.0);
    await setVolume(newValue);
  }

  /// Sesi kapatır (0.0).
  Future<void> mute() async {
    await setVolume(0.0);
  }

  /// Sesi %100 yapar (1.0).
  Future<void> unmute() async {
    await setVolume(1.0);
  }
}
