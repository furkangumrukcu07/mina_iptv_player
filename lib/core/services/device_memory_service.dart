import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Cihazın toplam RAM miktarını ölçen ve düşük RAM'li (1-2GB) cihazları
/// tespit eden servis.
class DeviceMemoryService extends GetxService {
  int _totalMemoryMb = -1;

  /// Toplam RAM miktarını megabayt cinsinden döndürür. Okunamazsa -1 döner.
  int get totalMemoryMb => _totalMemoryMb;

  /// Cihazın 2GB veya daha az RAM'e sahip olup olmadığını belirtir.
  bool get isLowMemoryDevice => _totalMemoryMb > 0 && _totalMemoryMb <= 2500; // Bazı 2GB cihazlar 1.8GB vb döner, toleranslı limit.

  /// Gecikmeli başlatılacak ağır servisler için cihaz RAM'ine göre önerilen
  /// bekleme süresini (milisaniye) döner. (Düşük RAM için 15 saniye)
  int get recommendedStartupDelayMs => isLowMemoryDevice ? 15000 : 3500;

  Future<DeviceMemoryService> init() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _totalMemoryMb = await _getAndroidTotalMemoryMb();
    }
    debugPrint('[DeviceMemory] Total RAM: ${_totalMemoryMb > 0 ? "$_totalMemoryMb MB" : "Unknown"} | isLow: $isLowMemoryDevice');
    return this;
  }

  Future<int> _getAndroidTotalMemoryMb() async {
    try {
      final file = File('/proc/meminfo');
      if (!await file.exists()) return -1;
      
      final lines = await file.readAsLines();
      for (final line in lines) {
        if (line.startsWith('MemTotal:')) {
          final match = RegExp(r'\d+').firstMatch(line);
          if (match != null) {
            final kb = int.parse(match.group(0)!);
            return kb ~/ 1024;
          }
        }
      }
    } catch (e) {
      debugPrint('[DeviceMemory] Failed to read /proc/meminfo: $e');
    }
    return -1;
  }
}
