import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../services/license_device_service.dart';

class DeviceInfoUtil {
  DeviceInfoUtil._();

  /// Retrieves a persistent hardware identifier for the device if available.
  /// 
  /// On Android, this returns the Android ID (`androidInfo.id`), which survives
  /// uninstalls and app data clears (only resets on factory reset).
  /// 
  /// On iOS, this returns the `identifierForVendor`, which survives until all
  /// apps from the same vendor are uninstalled.
  /// 
  /// If fetching fails, or on unsupported platforms, it falls back to the
  /// securely generated UUID from `LicenseDeviceService.getOrCreateDeviceId()`.
  static Future<String> getHardwareDeviceId() async {
    try {
      final plugin = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final id = info.id.trim();
        if (id.isNotEmpty && id != 'unknown') {
          return 'android_$id';
        }
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final id = info.identifierForVendor?.trim() ?? '';
        if (id.isNotEmpty && id != 'unknown') {
          return 'ios_$id';
        }
      } else if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        final id = info.systemGUID?.trim() ?? '';
        if (id.isNotEmpty && id != 'unknown') {
          return 'macos_$id';
        }
      } else if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        final id = info.deviceId.trim();
        if (id.isNotEmpty && id != 'unknown') {
          return 'win_$id';
        }
      }
    } catch (e) {
      debugPrint('[DeviceInfoUtil] error fetching hardware ID: $e');
    }

    // Fallback: Generate or retrieve the secure storage UUID
    final secureId = await LicenseDeviceService.getOrCreateDeviceId();
    return 'fallback_$secureId';
  }

  static String getDeviceOS() {
    if (kIsWeb) return 'Web';
    return Platform.operatingSystem;
  }

  static Future<String> getDeviceName() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final info = await plugin.webBrowserInfo;
        return info.userAgent ?? 'Web Browser';
      } else if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return info.name;
      } else if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        return info.computerName;
      } else if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        return info.computerName;
      }
    } catch (e) {
      debugPrint('[DeviceInfoUtil] error fetching device name: $e');
    }
    return 'Unknown Device';
  }
}
