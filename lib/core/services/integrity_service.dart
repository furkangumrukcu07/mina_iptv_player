import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_play_integrity_wrapper/flutter_play_integrity_wrapper.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_install_source_service.dart';

/// [FlutterPlayIntegrityWrapper.verifyTokenOnDevice] için; sunucu tarafı doğrulama önerilir.
/// Anahtar APK içinde görünür — yalnızca bilinçli kullanım. Boşsa bütünlük adımı atlanır (fail-open).
///
/// Mağaza AAB/APK: `tool/secrets/play_integrity.env` içine `PLAY_INTEGRITY_API_KEY=...` yazın;
/// `android/app/build.gradle.kts` Gradle derlemesinde bunu dart-define olarak enjekte eder
/// (`flutter build`, Android Studio). Dosya git’e eklenmez (.gitignore).
/// Elle derleme: `--dart-define=PLAY_INTEGRITY_API_KEY=...`
const String kPlayIntegrityApiKey = String.fromEnvironment(
  'PLAY_INTEGRITY_API_KEY',
  defaultValue: '',
);

/// Release APK/AAB testinde log görmek için: `--dart-define=INTEGRITY_DEBUG_LOG=true`
/// (`adb logcat | grep IntegrityService` veya Android Studio Logcat).
const bool kIntegrityDebugLog = bool.fromEnvironment(
  'INTEGRITY_DEBUG_LOG',
  defaultValue: false,
);

/// Geçici tanı: `true` iken release Android Integrity adımı hiç çalışmaz (sorun ayrımı için).
/// Deneme bittikten sonra `false` yapın veya kaldırın.
const bool kTemporarilyDisablePlayIntegrity = false;

void _integrityVlog(String message) {
  if (kIntegrityDebugLog) {
    if (kDebugMode) debugPrint('IntegrityService: $message');
  }
}

/// Play Integrity: token isteği + (isteğe bağlı) cihaz üzerinde decode.
/// Yalnızca [kReleaseMode] ve Android’de çalışır; hata veya eksik yapılandırmada uygulamayı kilitlemez.
class IntegrityService extends GetxService {
  static bool _loggedNonRelease = false;

  /// Google Cloud Console → Proje ayarları → **Proje numarası** (Project number).
  /// Farklı bir proje için: `--dart-define=INTEGRITY_CLOUD_PROJECT_NUMBER=...`
  static const String cloudProjectNumber = String.fromEnvironment(
    'INTEGRITY_CLOUD_PROJECT_NUMBER',
    defaultValue: '211496466896',
  );

  final FlutterPlayIntegrityWrapper _playIntegrity = FlutterPlayIntegrityWrapper();
  bool _scheduled = false;
  bool _completed = false;

  /// [GetMaterialApp.builder] içinden bir kez çağrılır; ilk frame sonrası kontrol planlanır.
  void scheduleReleaseCheckIfNeeded(BuildContext appContext) {
    if (_scheduled || _completed) return;
    if (kTemporarilyDisablePlayIntegrity) {
      if (kDebugMode) debugPrint(
        'IntegrityService: atlandı — kTemporarilyDisablePlayIntegrity=true',
      );
      _completed = true;
      return;
    }
    if (!kReleaseMode) {
      if (kIntegrityDebugLog && !_loggedNonRelease) {
        _loggedNonRelease = true;
        _integrityVlog(
          'atlandı — yalnızca release’te çalışır. Dene: flutter run --release '
          'veya release APK + INTEGRITY_DEBUG_LOG=true',
        );
      }
      return;
    }
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (cloudProjectNumber.trim().isEmpty ||
        kPlayIntegrityApiKey.trim().isEmpty) {
      if (kDebugMode) debugPrint(
        'IntegrityService: atlandı — PLAY_INTEGRITY_API_KEY dart-define ile '
        'verilmeli (Play Integrity API etkin API anahtarı).',
      );
      _completed = true;
      return;
    }
    _scheduled = true;
    _integrityVlog(
      'kontrol planlandı (project=${cloudProjectNumber.trim()}, paket sonradan loglanır)',
    );
    // Play Integrity'nin native `requestIntegrityToken` çağrısı Android platform
    // ana iş parçacığını birkaç saniye meşgul edebiliyor; splash sırasında
    // çalışırsa playlist/EPG disk okumalarının (path_provider, secure storage,
    // shared_preferences — hepsi method channel) yanıtlarını kuyruğa sokup
    // açılışı uzatıyor. Bu yüzden kontrolü ana ekran tamamen oturduktan SONRAYA
    // erteliyoruz. Bu yalnızca "mağazadan kurulum öner" amaçlı bir kapı
    // olduğundan gecikmesinin UX'e etkisi yok.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(_releaseGateStartupDelay, () {
        if (!appContext.mounted) return;
        unawaited(_runAndroidReleaseGate(appContext));
      });
    });
  }

  /// Bütünlük kontrolünün açılıştan ne kadar sonra çalışacağı. Splash + ilk
  /// ana ekran yükünün bitmesini garanti edecek kadar uzun seçildi.
  static const Duration _releaseGateStartupDelay = Duration(seconds: 12);

  Future<void> _runAndroidReleaseGate(BuildContext appContext) async {
    if (_completed) return;
    _completed = true;
    try {
      _integrityVlog('token isteniyor…');
      final token = await _playIntegrity.requestIntegrityToken(
        cloudProjectNumber: cloudProjectNumber.trim(),
      );
      if (token == null || token.isEmpty) {
        _integrityVlog('token boş — Play Integrity / ağ / yapılandırma');
        return;
      }
      _integrityVlog('token alındı (${token.length} karakter), decode ediliyor…');

      final pkg = Get.find<AppInstallSourceService>().packageInfo?.packageName ??
          (await PackageInfo.fromPlatform()).packageName;
      _integrityVlog('packageName=$pkg');

      final decoded = await _playIntegrity.verifyTokenOnDevice(
        token: token,
        packageName: pkg,
        apiKey: kPlayIntegrityApiKey.trim(),
      );

      final verdict = _readAppLicensingVerdict(decoded);
      _integrityVlog(
        'appLicensingVerdict=${verdict ?? "(yok — accountDetails yok veya alan yok, diyalog yok)"}',
      );
      // Alan yok → değerlendirme yapılamadı; yanlış pozitif riskiyle diyalog göstermiyoruz.
      if (verdict == null) return;
      // Play dokümantasyonu: LICENSED dışındaki tüm değerler (UNLICENSED, UNEVALUATED, …).
      if (verdict == 'LICENSED') {
        _integrityVlog('LICENSED — mağaza uyarı diyalogu gösterilmiyor');
        return;
      }

      _integrityVlog('LICENSED değil ($verdict) — diyalog gösteriliyor');
      if (!appContext.mounted) return;
      await _showStoreSuggestionDialog(appContext, pkg);
    } catch (e, st) {
      if (kDebugMode) debugPrint('IntegrityService: $e\n$st');
    }
  }

  /// [decodeIntegrityToken] yanıtındaki `accountDetails.appLicensingVerdict`.
  static String? _readAppLicensingVerdict(Map<String, dynamic> decoded) {
    final acc = decoded['accountDetails'];
    if (acc is! Map) return null;
    final raw = acc['appLicensingVerdict'];
    return raw is String ? raw : null;
  }

  Future<void> _showStoreSuggestionDialog(BuildContext context, String packageName) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          title: Text('integrity.dialog.title'.tr),
          content: Text('integrity.dialog.body'.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('integrity.dialog.later'.tr),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                unawaited(_openPlayListing(packageName));
              },
              child: Text('integrity.dialog.openPlay'.tr),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openPlayListing(String packageName) async {
    final market = Uri.parse('market://details?id=$packageName');
    final https = Uri.parse(
      'https://play.google.com/store/apps/details?id=$packageName',
    );
    try {
      if (await canLaunchUrl(market)) {
        await launchUrl(market, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    try {
      await launchUrl(https, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
