import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import '../platform/android_playback_soc_hints.dart';
import 'app_settings_service.dart';

/// 2 GB ve altı RAM'li cihazlarda, kullanıcı «Düşük Donanımlı Cihaz Modu»nu
/// açmamışsa ve uygulama gözle görülür kare düşüşü (jank) yaşıyorsa ana ekranda
/// **bir kez** moda geçme uyarısı tetikler.
///
/// Jank, üretilen karelerin `build + raster` süresiyle ölçülür; boştaki kareler
/// (idle) sayılmaz. Eşiği aşan ağır kare birikince [shouldSuggestLowEndMode]
/// true olur; ana ekran bunu dinleyip popup gösterir. Kullanıcı modu açar veya
/// uyarıyı kapatırsa izleme durur ve bir daha tetiklenmez.
class DevicePerformanceAdvisor extends GetxService {
  DevicePerformanceAdvisor(this._settings);

  final AppSettingsService _settings;

  /// Ana ekranın dinlediği bayrak; true olunca uyarı popup'ı gösterilir.
  final shouldSuggestLowEndMode = false.obs;

  /// 60 fps bütçesi ~16,7 ms; 32 ms üstü iş yapan kareyi «ağır jank» sayarız.
  static const int _jankFrameMs = 32;

  /// Bu kadar ağır jank karesi birikince cihaz «performans sorunlu» kabul edilir.
  static const int _jankFrameThreshold = 45;

  /// İlk açılış jank'ını saymamak için ölçüm başlangıç gecikmesi (ms).
  static const int _warmupMs = 4000;

  int _jankFrames = 0;
  bool _monitoring = false;
  bool _resolved = false;
  int _startMs = 0;
  TimingsCallback? _cb;

  bool get _isLowRamDevice {
    if (kIsWeb || !Platform.isAndroid) return false;
    return AndroidPlaybackSocHints.isTotalRamBelowBytes(
          AndroidPlaybackSocHints.lowRamThresholdBytes,
        ) ||
        AndroidPlaybackSocHints.weakMpvDevice;
  }

  /// Öneri gösterilmeye uygun mu? Düşük RAM + mod kapalı + uyarı kapatılmamış.
  bool get _eligible =>
      _isLowRamDevice &&
      !_settings.lowEndDeviceMode.value &&
      !_settings.lowEndSuggestionDismissed.value;

  @override
  void onInit() {
    super.onInit();
    if (!_eligible) return;
    _startMonitoring();
    // Kullanıcı modu açar / öneriyi kapatırsa izlemeyi durdur.
    ever<bool>(_settings.lowEndDeviceMode, (v) {
      if (v) _stopMonitoring();
    });
    ever<bool>(_settings.lowEndSuggestionDismissed, (v) {
      if (v) _stopMonitoring();
    });
  }

  void _startMonitoring() {
    if (_monitoring || _resolved) return;
    _monitoring = true;
    _startMs = DateTime.now().millisecondsSinceEpoch;
    final cb = _onFrameTimings;
    _cb = cb;
    SchedulerBinding.instance.addTimingsCallback(cb);
  }

  void _stopMonitoring() {
    if (!_monitoring) return;
    _monitoring = false;
    final cb = _cb;
    if (cb != null) {
      SchedulerBinding.instance.removeTimingsCallback(cb);
      _cb = null;
    }
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (_resolved) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _startMs < _warmupMs) return;
    for (final t in timings) {
      final workMs =
          (t.buildDuration + t.rasterDuration).inMilliseconds;
      if (workMs >= _jankFrameMs) {
        _jankFrames++;
      }
    }
    if (_jankFrames >= _jankFrameThreshold) {
      _resolved = true;
      _stopMonitoring();
      if (_eligible) {
        shouldSuggestLowEndMode.value = true;
      }
    }
  }

  @override
  void onClose() {
    _stopMonitoring();
    super.onClose();
  }
}
