import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// [PackageInfo.installerStore] / kurulum zamanları — `main` içinde [ensureLoaded] çağrılır.
///
/// Android: `initiatingPackageName` / `getInstallerPackageName` (ör. `com.android.vending` = Play).
class AppInstallSourceService extends GetxService {
  PackageInfo? _info;

  PackageInfo? get packageInfo => _info;

  /// Yükleyen uygulama paket adı; `null` veya boş genelde yan yükleme / adb.
  String? get installerPackageName {
    final s = _info?.installerStore?.trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  DateTime? get installTime => _info?.installTime;
  DateTime? get updateTime => _info?.updateTime;

  bool get isInstalledFromGooglePlay =>
      installerPackageName == 'com.android.vending';

  bool get isInstalledFromAmazonAppstore =>
      installerPackageName == 'com.amazon.venezia';

  bool get isLikelySideloaded =>
      installerPackageName == null || installerPackageName!.isEmpty;

  Future<void> ensureLoaded() async {
    if (_info != null) return;
    _info = await PackageInfo.fromPlatform();
  }

  /// Ayarlar / log için kısa özet.
  String describeInstaller() {
    final id = installerPackageName;
    if (id == null) {
      return 'unknown_or_sideload';
    }
    if (isInstalledFromGooglePlay) return 'google_play';
    if (isInstalledFromAmazonAppstore) return 'amazon_appstore';
    return id;
  }
}
