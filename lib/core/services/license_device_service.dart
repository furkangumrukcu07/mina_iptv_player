import 'dart:io';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_bootstrap.dart';
import 'mina_secure_storage.dart';

class LicenseDeviceEntry {
  const LicenseDeviceEntry({
    required this.deviceId,
    required this.label,
    this.registeredAt,
    this.lastSeenAt,
  });

  final String deviceId;
  final String label;
  final String? registeredAt;
  final String? lastSeenAt;

  factory LicenseDeviceEntry.fromMap(Map<String, dynamic> map) {
    return LicenseDeviceEntry(
      deviceId: map['deviceId'] as String? ?? '',
      label: map['label'] as String? ?? 'Cihaz',
      registeredAt: map['registeredAt'] as String?,
      lastSeenAt: map['lastSeenAt'] as String?,
    );
  }
}

class LicenseDeviceService {
  LicenseDeviceService._();

  static const _storageKey = 'mina_license_device_id_v1';
  static const _functionsRegion = 'europe-west1';

  static FlutterSecureStorage get _secureStorage => MinaSecureStorage.instance;

  static FirebaseFunctions? _functions() {
    if (!gFirebaseReady) return null;
    return FirebaseFunctions.instanceFor(region: _functionsRegion);
  }

  static Future<String> getOrCreateDeviceId() async {
    await MinaSecureStorage.ensureReady();
    final prefs = await SharedPreferences.getInstance();

    String? secureId;
    try {
      secureId = await _secureStorage.read(key: _storageKey);
    } catch (e) {
      if (kDebugMode) debugPrint('[LicenseDeviceService] secure read failed: $e');
    }

    final prefsId = prefs.getString(_storageKey);

    // 1. Durum: Secure Storage'da ID var.
    if (secureId != null && secureId.length >= 8) {
      if (prefsId != secureId) {
        // Yedeklemeyi (SharedPreferences) de senkronize et
        await prefs.setString(_storageKey, secureId);
      }
      return secureId;
    }

    // 2. Durum: Secure Storage silinmiş ama SharedPreferences'te duruyor (Yedekten dön!)
    if (prefsId != null && prefsId.length >= 8) {
      try {
        await _secureStorage.write(key: _storageKey, value: prefsId);
      } catch (e) {
        if (kDebugMode) debugPrint('[LicenseDeviceService] secure restore failed: $e');
      }
      return prefsId;
    }

    // 3. Durum: Cihaz tamamen ilk kez açılıyor (veya tüm veriler silinmiş), yeni ID üret.
    // Artık rastgele ID üretmek yerine kalıcı donanım kimliğini (Android ID) kullanıyoruz.
    // Böylece silip yüklemelerde aynı cihaz 3 lisans slotu kaplamayacak!
    final generated = await _generatePersistentHardwareId();
    try {
      await _secureStorage.write(key: _storageKey, value: generated);
    } catch (e) {
      if (kDebugMode) debugPrint('[LicenseDeviceService] secure write failed: $e');
    }
    await prefs.setString(_storageKey, generated);

    return generated;
  }

  static Future<String> _generatePersistentHardwareId() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final id = info.id.trim();
        if (id.isNotEmpty && id != 'unknown') return 'mina_$id';
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final id = info.identifierForVendor?.trim() ?? '';
        if (id.isNotEmpty && id != 'unknown') return 'mina_$id';
      } else if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        final id = info.systemGUID?.trim() ?? '';
        if (id.isNotEmpty && id != 'unknown') return 'mina_$id';
      } else if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        final id = info.deviceId.trim();
        if (id.isNotEmpty && id != 'unknown') return 'mina_$id';
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[LicenseDeviceService] error fetching hardware ID: $e');
    }
    return _generateRandomDeviceId();
  }

  static String _generateRandomDeviceId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'mina_r_$hex'; // r indicates it was randomly generated due to missing hardware id
  }

  static Future<String> deviceLabel() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await plugin.androidInfo;
        final model = info.model.trim();
        final brand = info.brand.trim();
        if (model.isNotEmpty && brand.isNotEmpty) {
          return '$brand $model'.trim();
        }
        if (model.isNotEmpty) return model;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await plugin.iosInfo;
        final name = info.name.trim();
        if (name.isNotEmpty) return name;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[LicenseDeviceService] device label error: $e');
    }
    return 'Cihaz';
  }

  static Future<LicenseDeviceRegistrationResult> registerCurrentDevice() async {
    final fn = _functions();
    if (fn == null) {
      return const LicenseDeviceRegistrationResult(
        registered: false,
        deviceLimitExceeded: false,
        errorCode: 'firebase_unavailable',
      );
    }

    try {
      final callable = fn.httpsCallable('registerLicenseDevice');
      final result = await callable.call<Map<String, dynamic>>({
        'deviceId': await getOrCreateDeviceId(),
        'deviceLabel': await deviceLabel(),
      });
      final data = Map<String, dynamic>.from(result.data);
      final devices = parseDevices(data['devices']);
      return LicenseDeviceRegistrationResult(
        registered: data['registered'] == true,
        deviceLimitExceeded: false,
        deviceCount: data['deviceCount'] as int? ?? devices.length,
        maxDevices: data['maxDevices'] as int? ?? 3,
        devices: devices,
        currentDeviceId: data['deviceId'] as String?,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted' ||
          e.message == 'DEVICE_LIMIT_EXCEEDED') {
        final details = e.details;
        int maxDevices = 3;
        int deviceCount = 3;
        if (details is Map) {
          maxDevices = details['maxDevices'] as int? ?? maxDevices;
          deviceCount = details['deviceCount'] as int? ?? deviceCount;
        }
        return LicenseDeviceRegistrationResult(
          registered: false,
          deviceLimitExceeded: true,
          deviceCount: deviceCount,
          maxDevices: maxDevices,
        );
      }
      if (kDebugMode) debugPrint(
        '[LicenseDeviceService] register failed: ${e.code} ${e.message}',
      );
      return LicenseDeviceRegistrationResult(
        registered: false,
        deviceLimitExceeded: false,
        errorCode: e.code,
        errorMessage: e.message,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[LicenseDeviceService] register error: $e');
      return LicenseDeviceRegistrationResult(
        registered: false,
        deviceLimitExceeded: false,
        errorCode: 'unknown',
        errorMessage: e.toString(),
      );
    }
  }

  static Future<List<LicenseDeviceEntry>> listDevices() async {
    final fn = _functions();
    if (fn == null) return const [];

    try {
      final callable = fn.httpsCallable('listLicenseDevices');
      final result = await callable.call<Map<String, dynamic>>();
      final data = Map<String, dynamic>.from(result.data);
      return parseDevices(data['devices']);
    } catch (e) {
      if (kDebugMode) debugPrint('[LicenseDeviceService] listDevices error: $e');
      return const [];
    }
  }

  static Future<bool> removeDevice(String deviceId) async {
    final fn = _functions();
    if (fn == null) return false;

    try {
      final callable = fn.httpsCallable('removeLicenseDevice');
      await callable.call<Map<String, dynamic>>({'deviceId': deviceId});
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[LicenseDeviceService] removeDevice error: $e');
      return false;
    }
  }

  static List<LicenseDeviceEntry> parseDevices(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => LicenseDeviceEntry.fromMap(Map<String, dynamic>.from(e)))
        .where((d) => d.deviceId.isNotEmpty)
        .toList(growable: false);
  }
}

class LicenseDeviceRegistrationResult {
  const LicenseDeviceRegistrationResult({
    required this.registered,
    required this.deviceLimitExceeded,
    this.deviceCount = 0,
    this.maxDevices = 3,
    this.devices = const [],
    this.currentDeviceId,
    this.errorCode,
    this.errorMessage,
  });

  final bool registered;
  final bool deviceLimitExceeded;
  final int deviceCount;
  final int maxDevices;
  final List<LicenseDeviceEntry> devices;
  final String? currentDeviceId;
  final String? errorCode;
  final String? errorMessage;
}
