import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_kit/media_kit.dart';

import 'core/layout/app_layout_mode.dart';
import 'core/bindings/initial_binding.dart';
import 'core/platform/android_playback_soc_hints.dart';
import 'core/i18n/app_locale.dart';
import 'core/i18n/app_translations.dart';
import 'core/services/app_install_source_service.dart';
import 'core/services/app_settings_service.dart';
import 'core/services/continue_watching_service.dart';
import 'core/services/integrity_service.dart';
import 'core/services/parental_control_service.dart';
import 'core/services/system_volume_service.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await Future.wait<void>([
    initializeDateFormatting('tr_TR'),
    initializeDateFormatting('en_US'),
    initializeDateFormatting('fr_FR'),
    initializeDateFormatting('ar_SA'),
    initializeDateFormatting('zh_CN'),
    initializeDateFormatting('ru_RU'),
  ]);

  final installSource = AppInstallSourceService();
  await installSource.ensureLoaded();
  Get.put<AppInstallSourceService>(installSource, permanent: true);
  Get.put<IntegrityService>(IntegrityService(), permanent: true);
  if (kDebugMode) {
    debugPrint(
      'mina_iptv: installer=${installSource.installerPackageName ?? "(null)"} '
      '→ ${installSource.describeInstaller()}',
    );
  }

  final settings = AppSettingsService();
  await settings.ensureLoaded();
  Get.put<AppSettingsService>(settings, permanent: true);
  final parental = ParentalControlService();
  Get.put<ParentalControlService>(parental, permanent: true);
  await parental.refreshPinState();
  
  // Initialize SystemVolumeService
  await Get.putAsync<SystemVolumeService>(() async {
    final service = SystemVolumeService();
    await service.onInit();
    return service;
  }, permanent: true);
  
  // Initialize ContinueWatchingService
  Get.put<ContinueWatchingService>(ContinueWatchingService(), permanent: true);
  await AndroidPlaybackSocHints.ensureLoaded();
  Get.updateLocale(
    materialLocaleFromLanguageCode(settings.languageCode.value),
  );

  await settings.syncSystemChromeWithLayout();

  // Play politikası: kurulum kaynağına göre uygulamayı kilitleyen / “yalnızca Play’den
  // yükleyin” ekranı göstermek reddedilebilir; her zaman normal giriş.
  runApp(const MinaIptvApp(initialRoute: AppRoutes.splash));
}

class MinaIptvApp extends StatelessWidget {
  const MinaIptvApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return Obx(() {
      settings.languageCode.value;
      settings.themeLabel.value;
      return GetMaterialApp(
      title: 'Mina IPTV Player',
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
      locale: materialLocaleFromLanguageCode(settings.languageCode.value),
      fallbackLocale: const Locale('en', 'US'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('tr', 'TR'),
        Locale('fr', 'FR'),
        Locale('ar', 'SA'),
        Locale('zh', 'CN'),
        Locale('ru', 'RU'),
      ],
      theme: AppTheme.materialThemeForLabel(settings.themeLabel.value),
      initialBinding: InitialBinding(),
      initialRoute: initialRoute,
      getPages: AppPages.routes,
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 80),
      builder: (context, child) {
        Get.find<IntegrityService>().scheduleReleaseCheckIfNeeded(context);
        final wrapped = child ?? const SizedBox.shrink();
        return OrientationBuilder(
          builder: (context, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final lm = settings.layoutMode.value;
              if (lm == AppLayoutMode.mobile) {
                unawaited(
                    settings.syncMobileHandheldChromeToCurrentOrientation());
              } else if (lm == AppLayoutMode.tablet) {
                unawaited(
                    settings.syncTabletHandheldChromeToCurrentOrientation());
              }
            });
            return ValueListenableBuilder<double>(
              valueListenable: settings.layoutTextScaleNotifier,
              builder: (context, factor, child) {
                final mq = MediaQuery.of(context);
                return MediaQuery(
                  data: mq.copyWith(
                    textScaler: TextScaler.linear(factor),
                    disableAnimations: mq.disableAnimations,
                  ),
                  child: child!,
                );
              },
              child: wrapped,
            );
          },
        );
      },
    );
    });
  }
}
