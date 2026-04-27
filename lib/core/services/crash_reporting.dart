import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Üretimde crash / native hata raporu için Sentry.
///
/// **Kurulum:** Sentry projesi oluştur → Client Keys (DSN) kopyala → release derlemesinde:
/// `flutter build apk --release --dart-define=SENTRY_DSN=https://xxxx@xxx.ingest.sentry.io/xxx`
///
/// DSN yoksa SDK başlatılmaz (MASAÜSTÜ / iç test için ek işlem gerekmez).
bool get isSentryConfigured =>
    const String.fromEnvironment('SENTRY_DSN', defaultValue: '').trim().isNotEmpty;

/// [appRunner] içinde `runApp` çağrılmalıdır.
Future<void> maybeInitSentry(Future<void> Function() appRunner) async {
  final dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '').trim();
  if (dsn.isEmpty) {
    await appRunner();
    return;
  }

  PackageInfo? pkg;
  try {
    pkg = await PackageInfo.fromPlatform();
  } catch (_) {}

  await SentryFlutter.init(
    (options) {
      options.dsn = dsn;
      options.environment = kReleaseMode ? 'production' : 'development';
      options.tracesSampleRate = kReleaseMode ? 0.12 : 1.0;
      options.attachScreenshot = false;
      options.captureFailedRequests = false;
      options.enableAutoPerformanceTracing = false;
      if (pkg != null) {
        options.release =
            '${pkg.packageName}@${pkg.version}+${pkg.buildNumber}';
      }
    },
    appRunner: appRunner,
  );
}
