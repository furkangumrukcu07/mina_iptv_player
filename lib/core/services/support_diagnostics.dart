import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_settings_service.dart';

/// Sorun bildirimi e-postasına eklenecek otomatik tanı metni (kişisel veri içermez).
final class SupportDiagnostics {
  SupportDiagnostics._();

  static Future<String> buildSupportAppendix() async {
    final lines = <String>[];

    try {
      final pkg = await PackageInfo.fromPlatform();
      lines.add('App: ${pkg.appName} ${pkg.version} (${pkg.buildNumber})');
      lines.add('Package: ${pkg.packageName}');
    } catch (_) {
      lines.add('App: (package info unavailable)');
    }

    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final w = await plugin.webBrowserInfo;
        lines.add('Browser: ${w.browserName.name} ${w.userAgent ?? ""}'.trim());
        if ((w.vendor ?? '').isNotEmpty) {
          lines.add('Vendor: ${w.vendor}');
        }
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final a = await plugin.androidInfo;
            lines.add('Device: ${a.manufacturer} ${a.model}');
            lines.add('Android: ${a.version.release} (SDK ${a.version.sdkInt})');
            if (a.supportedAbis.isNotEmpty) {
              lines.add('ABIs: ${a.supportedAbis.join(", ")}');
            }
            break;
          case TargetPlatform.iOS:
            final i = await plugin.iosInfo;
            lines.add('Device: ${i.model} (${i.name})');
            lines.add('iOS: ${i.systemVersion}');
            break;
          default:
            final di = await plugin.deviceInfo;
            lines.add('Device: ${di.data}');
        }
      }
    } catch (_) {
      lines.add('Device: (unavailable)');
    }

    try {
      if (Get.isRegistered<AppSettingsService>()) {
        final app = Get.find<AppSettingsService>();
        lines.add('Layout: ${app.layoutMode.value.name}');
        lines.add('UI language: ${app.languageCode.value}');
      }
    } catch (_) {}

    lines.add(
      'buildMode: ${kReleaseMode ? "release" : kDebugMode ? "debug" : "profile"}',
    );

    return lines.join('\n');
  }
}
