import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'device_memory_service.dart';
import 'firebase_bootstrap.dart';

/// Tüm yakalanmayan Dart hatalarını (Exception & StackTrace) Firestore
/// üzerindeki "app_crashes" koleksiyonuna anlık yazar.
class FirestoreCrashReporter {
  /// Global Flutter hata yakalayıcısını başlatır. main.dart içindeki
  /// runZonedGuarded ve FlutterError.onError metodlarına bağlanır.
  static void initGlobalErrorCatchers() {
    // UI hataları (Örn: Widget çökmeleri)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _reportToFirestore(
        details.exceptionAsString(),
        details.stack.toString(),
        isFatal: true,
      );
    };

    // UI Dışı Asenkron hatalar (Örn: Future, Timer çökmeleri)
    PlatformDispatcher.instance.onError = (error, stack) {
      _reportToFirestore(
        error.toString(),
        stack.toString(),
        isFatal: true,
      );
      return true;
    };
  }

  /// Belirli bir try-catch bloğundan gelen spesifik hataları kaydeder
  static Future<void> logException(dynamic error, dynamic stackTrace, {String context = ''}) async {
    await _reportToFirestore(
      '$context: ${error.toString()}',
      stackTrace?.toString() ?? '',
      isFatal: false,
    );
  }

  static Future<void> _reportToFirestore(String error, String stack, {required bool isFatal}) async {
    if (!gFirebaseReady) return;

    try {
      // RAM okuması yapıldıysa al, yoksa bilinmiyor
      String ramInfo = 'Unknown';
      if (Get.isRegistered<DeviceMemoryService>()) {
        final mem = Get.find<DeviceMemoryService>().totalMemoryMb;
        if (mem > 0) ramInfo = '$mem MB';
      }

      final timestamp = DateTime.now();
      final collection = FirebaseFirestore.instance.collection('app_crashes');
      
      await collection.add({
        'error_message': error,
        'stack_trace': stack,
        'is_fatal': isFatal,
        'timestamp': FieldValue.serverTimestamp(),
        'date_string': DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp),
        'device_ram': ramInfo,
        'platform': defaultTargetPlatform.name,
      });
      if (kDebugMode) debugPrint('[CrashReporter] Crash logged to Firestore.');
    } catch (e) {
      if (kDebugMode) debugPrint('[CrashReporter] Failed to write crash to Firestore: $e');
    }
  }
}
