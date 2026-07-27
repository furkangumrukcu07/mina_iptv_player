import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Hiz testi sonuç modeli
class SpeedTestResult {
  final double downloadSpeed; // Mbps
  final double uploadSpeed; // Mbps
  final double latency; // ms
  final DateTime timestamp;

  SpeedTestResult({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.latency,
    required this.timestamp,
  });

  /// Hiz analiz sonucu
  SpeedTestAnalysis get analysis {
    if (downloadSpeed < 5.0) {
      return SpeedTestAnalysis.verySlow;
    } else if (downloadSpeed < 12.0) {
      return SpeedTestAnalysis.borderline;
    } else {
      return SpeedTestAnalysis.excellent;
    }
  }

  /// Analiz mesajini getir
  String get analysisMessage {
    switch (analysis) {
      case SpeedTestAnalysis.verySlow:
        return 'settings.speed_test.message.very_slow'.tr;
      case SpeedTestAnalysis.borderline:
        return 'settings.speed_test.message.borderline'.tr;
      case SpeedTestAnalysis.excellent:
        return 'settings.speed_test.message.excellent'.tr;
    }
  }

  /// Analiz rengini getir
  String get analysisColor {
    switch (analysis) {
      case SpeedTestAnalysis.verySlow:
        return '#FF5252'; // Kirmizi
      case SpeedTestAnalysis.borderline:
        return '#FFC107'; // Sari
      case SpeedTestAnalysis.excellent:
        return '#4CAF50'; // Yesil
    }
  }
}

/// Hiz testi analiz seviyeleri
enum SpeedTestAnalysis {
  verySlow,
  borderline,
  excellent,
}

/// Hiz testi servisi
class SpeedTestService extends GetxService {
  static SpeedTestService get to => Get.find();

  final RxBool _isTesting = false.obs;
  final RxDouble _currentSpeed = 0.0.obs;
  final Rx<SpeedTestResult?> _lastResult = Rx<SpeedTestResult?>(null);
  final RxString _errorMessage = ''.obs;

  /// Test durumunu izle
  bool get isTesting => _isTesting.value;
  
  /// Anlik hizi izle
  double get currentSpeed => _currentSpeed.value;
  
  /// Sonucu izle
  SpeedTestResult? get lastResult => _lastResult.value;
  
  /// Hata mesajini izle
  String get errorMessage => _errorMessage.value;

  /// Anlik hizi stream olarak getir
  Stream<double> get speedStream => _currentSpeed.stream;

  /// Internet baglantisini kontrol et
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Hiz testini baslat
  Future<SpeedTestResult?> startSpeedTest() async {
    if (_isTesting.value) return null;

    // Internet baglantisini kontrol et
    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      _errorMessage.value = 'settings.speed_test.error.no_internet'.tr;
      return null;
    }

    _isTesting.value = true;
    _errorMessage.value = '';
    _currentSpeed.value = 0.0;

    try {
      // Mock speed test implementation
      _isTesting.value = true;
      
      // Simulate progress updates
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!_isTesting.value) break;
        
        // Simulate increasing speed
        final mockSpeed = (i / 100.0) * 25.0 + (math.Random().nextDouble() * 10);
        _currentSpeed.value = mockSpeed;
      }
      
      // Generate final result
      final finalSpeed = 20.0 + math.Random().nextDouble() * 30.0; // 20-50 Mbps
      
      // Sonucu olustur
      final result = SpeedTestResult(
        downloadSpeed: finalSpeed,
        uploadSpeed: 0.0, // Simdilik sadece download
        latency: 0.0, // Simdilik latency olcmuyor
        timestamp: DateTime.now(),
      );

      _lastResult.value = result;
      return result;

    } catch (e) {
      _errorMessage.value = 'settings.speed_test.error.test_failed'.trParams({'error': e.toString()});
      if (kDebugMode) debugPrint('Speed test error: $e');
      return null;
    } finally {
      _isTesting.value = false;
      _currentSpeed.value = 0.0;
    }
  }

  /// Testi iptal et
  void cancelTest() {
    if (_isTesting.value) {
      _isTesting.value = false;
      _currentSpeed.value = 0.0;
    }
  }

  /// Sonucu temizle
  void clearResult() {
    _lastResult.value = null;
    _errorMessage.value = '';
  }

  @override
  void onClose() {
    cancelTest();
    super.onClose();
  }
}
