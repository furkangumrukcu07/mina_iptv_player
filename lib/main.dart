import 'dart:async' show unawaited;

import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'core/services/firebase_bootstrap.dart';
import 'core/services/mina_push_service.dart';
import 'core/services/opensubtitles_service.dart';
import 'core/services/crash_reporting.dart';
import 'core/services/integrity_service.dart';
import 'core/services/parental_control_service.dart';
import 'core/services/system_volume_service.dart';
import 'core/epg/global_epg_service.dart';
import 'core/epg/home_epg_catalog_cache.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_performance.dart';
import 'core/theme/app_scroll_physics.dart';
import 'core/theme/app_theme.dart';
import 'ui/adaptive_haptic_scroll_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await maybeInitSentry(() async {
    await Future.wait<void>([
      initializeDateFormatting('tr_TR'),
      initializeDateFormatting('en_US'),
      initializeDateFormatting('fr_FR'),
      initializeDateFormatting('ar_SA'),
      initializeDateFormatting('zh_CN'),
      initializeDateFormatting('ru_RU'),
      initializeDateFormatting('ko_KR'),
      initializeDateFormatting('he_IL'),
      initializeDateFormatting('da_DK'),
      initializeDateFormatting('sv_SE'),
      initializeDateFormatting('hi_IN'),
      initializeDateFormatting('th_TH'),
      initializeDateFormatting('it_IT'),
      initializeDateFormatting('pt_PT'),
      initializeDateFormatting('id_ID'),
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

    // Firebase'i korumalı başlat: yapılandırma yoksa sessizce atlanır,
    // uygulama normal akışına devam eder (çökmez).
    await initFirebaseGuarded();

    // FCM arka plan mesaj handler'ı runApp'ten ÖNCE kaydedilmeli. Firebase
    // hazır değilse atlanır.
    if (gFirebaseReady) {
      FirebaseMessaging.onBackgroundMessage(minaFirebaseBackgroundHandler);
    }

    final settings = AppSettingsService();
    await settings.ensureLoaded();
    // Düşük Donanımlı Cihaz Modu açıksa Flutter image cache limitlerini hemen
    // düşür (poster/logo decode baskısını azaltır, OOM riskini düşürür).
    AppPerformance.applyImageCacheLimits(settings.lowEndDeviceMode.value);
    Get.put<AppSettingsService>(settings, permanent: true);
    Get.put(OpenSubtitlesService(), permanent: true);
    final parental = ParentalControlService();
    Get.put<ParentalControlService>(parental, permanent: true);
    await parental.refreshPinState();

    Get.put<SystemVolumeService>(SystemVolumeService(), permanent: true);

    Get.put<GlobalEpgService>(GlobalEpgService(), permanent: true);
    Get.put<HomeEpgCatalogCache>(HomeEpgCatalogCache(), permanent: true);
    await AndroidPlaybackSocHints.ensureLoaded();
    Get.updateLocale(
      materialLocaleFromLanguageCode(settings.languageCode.value),
    );

    await settings.syncSystemChromeWithLayout();

    runApp(const MinaIptvApp(initialRoute: AppRoutes.splash));
  });
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
      settings.appFontFamilyKey.value;
      settings.layoutMode.value;
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
        Locale('ja', 'JP'),
        Locale('es', 'ES'),
        Locale('ko', 'KR'),
        Locale('he', 'IL'),
        Locale('da', 'DK'),
        Locale('sv', 'SE'),
        Locale('hi', 'IN'),
        Locale('th', 'TH'),
        Locale('it', 'IT'),
        Locale('pt', 'PT'),
        Locale('id', 'ID'),
      ],
      theme: AppTheme.materialThemeForLabel(
        settings.themeLabel.value,
        appFontFamilyKey: settings.appFontFamilyKey.value,
      ),
      scrollBehavior: const MinaScrollBehavior(),
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
              child: AdaptiveHapticScrollScope(child: wrapped),
            );
          },
        );
      },
    );
    });
  }
}
