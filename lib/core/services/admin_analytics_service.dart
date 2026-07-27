import 'package:cloud_firestore/cloud_firestore.dart';
import '../util/firestore_timeout.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';

import 'firebase_bootstrap.dart';
import 'device_memory_service.dart';

class AdminAnalyticsService {
  static Future<void> incrementDailyOpens() async {
    if (!gFirebaseReady) return;
    try {
      // ANR Düzeltme: Uygulama açılışında Firestore ve Firebase Analytics aynı
      // anda yüklenip Google Play Services üzerinden Binder IPC'yi kilitliyor.
      // Firestore (gRPC / SQLite) işlemlerini UI çizildikten sonraya erteliyoruz.
      final delayMs = Get.isRegistered<DeviceMemoryService>() 
          ? Get.find<DeviceMemoryService>().recommendedStartupDelayMs 
          : 4000;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docRef = FirebaseFirestore.instance.collection('admin_stats').doc(today);
      await withFirestoreTimeout(docRef.set({
        'opens': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)));
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminAnalytics] incrementDailyOpens error: $e');
    }
  }

  static Future<void> incrementNewUsers() async {
    if (!gFirebaseReady) return;
    try {
      final delayMs = Get.isRegistered<DeviceMemoryService>() 
          ? Get.find<DeviceMemoryService>().recommendedStartupDelayMs 
          : 4000;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docRef = FirebaseFirestore.instance.collection('admin_stats').doc(today);
      await withFirestoreTimeout(docRef.set({
          'new_users': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)));
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminAnalytics] incrementNewUsers error: $e');
    }
  }
}
