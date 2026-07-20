import 'dart:async' show unawaited;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
import 'core/services/showcase_in_app_pip_service.dart';
import 'core/services/firebase_bootstrap.dart';
import 'core/services/admin_analytics_service.dart';
import 'core/services/mina_push_service.dart';
import 'core/services/mina_secure_storage.dart';
import 'core/services/opensubtitles_service.dart';
import 'core/services/crash_reporting.dart';
import 'core/services/firestore_crash_reporter.dart';
import 'core/services/integrity_service.dart';
import 'core/services/parental_control_service.dart';
import 'core/services/system_volume_service.dart';
import 'core/epg/global_epg_service.dart';
import 'core/epg/home_epg_catalog_cache.dart';
import 'core/routes/app_pages.dart';
import 'core/home/showcase_in_app_pip_overlay_host.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_performance.dart';
import 'core/theme/app_scroll_physics.dart';
import 'core/navigation/page_transition_builder.dart';
import 'core/theme/app_theme.dart';
import 'ui/adaptive_haptic_scroll_scope.dart';
import 'ui/playlist_switch_overlay.dart';
import 'package:workmanager/workmanager.dart';
import 'data/repositories/playlist_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirestoreCrashReporter.initGlobalErrorCatchers();

  // EncryptedSharedPreferences + Keystore soğuk init'i arka planda başlat;
  // UI etkileşiminde ilk containsKey/read ANR üretmesin.
  final secureStorageWarm = MinaSecureStorage.warmUp();
  MediaKit.ensureInitialized();

  Workmanager().initialize(
    callbackDispatcher,
  );

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
    if (gFirebaseReady) {
      AdminAnalyticsService.incrementDailyOpens();
      try {
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          final errorStr = details.exceptionAsString();
          if (details.silent || 
              errorStr.contains('Invalid image data') ||
              errorStr.contains('Failed to load font') ||
              errorStr.contains('Unknown textureId')) {
            // Ignore silent errors, image loading errors, font network errors, and video player texture race conditions.
            return;
          }
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
          originalOnError?.call(details);
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          if (error.toString().contains('Invalid image data')) return true;
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      } catch (_) {}
    }

    // FCM arka plan mesaj handler'ı runApp'ten ÖNCE kaydedilmeli. Firebase
    // hazır değilse atlanır.
    if (gFirebaseReady) {
      FirebaseMessaging.onBackgroundMessage(minaFirebaseBackgroundHandler);
    }

    final settings = AppSettingsService();
    await settings.ensureLoaded();
    // Flutter image cache limitlerini cihaza göre hemen uygula: düşük-donanım
    // modu veya TV düzeni daha düşük tavan alır (poster/logo decode baskısını
    // azaltır, uzun süreli yayında OOM riskini düşürür).
    AppPerformance.applyImageCacheLimitsFor(settings);
    Get.put<AppSettingsService>(settings, permanent: true);
    Get.put(OpenSubtitlesService(), permanent: true);
    final parental = ParentalControlService();
    Get.put<ParentalControlService>(parental, permanent: true);
    await parental.refreshPinState();

    Get.put<SystemVolumeService>(SystemVolumeService(), permanent: true);

    Get.put<GlobalEpgService>(GlobalEpgService(), permanent: true);
    Get.put<HomeEpgCatalogCache>(HomeEpgCatalogCache(), permanent: true);
    await AndroidPlaybackSocHints.ensureLoaded();
    // Google yedeği başka bir cihazda geri yüklendiyse (örn. telefon yedeği TV
    // box'ta), cihaza özel donanım kararlarımızın eski cihaz değerleriyle
    // ezilmemesi için zorlama bayraklarını bu cihaza göre uzlaştır. maybeForce*
    // çağrılarından ÖNCE olmalı.
    await settings.reconcileDeviceLocalHardwareSettings();
    // SoC ipuçları yüklendi: zayıf donanımda (RAM/çekirdek düşük) TV Lite'ı bir
    // kez otomatik aç (kullanıcı sonradan kapatabilir).
    await settings.maybeForceTvLiteForWeakHardware();
    // TV box / düşük donanımlı cihazda canlı yayın biçimini bir kez otomatik
    // MPEG-TS'e zorla (HLS segment/ABR yükü bu cihazlarda takılma yapıyor).
    await settings.maybeForceTsLiveFormatForWeakHardware();
    settings.syncPlaybackUrlNormalizationPolicy();
    await settings.enforceAndroidTvShellLayoutLock();
    Get.updateLocale(
      materialLocaleFromLanguageCode(settings.languageCode.value),
    );

    await settings.syncSystemChromeWithLayout();

    // Keystore ısınması bitmeden playlist/lisans okumaya girme.
    await secureStorageWarm;

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
        Locale('de', 'DE'),
        Locale('fa', 'IR'),
        Locale('pl', 'PL'),
        Locale('nl', 'NL'),
        Locale('uk', 'UA'),
        Locale('vi', 'VN'),
        Locale('el', 'GR'),
        Locale('ro', 'RO'),
        Locale('sq', 'AL'),
      ],
      theme: AppTheme.materialThemeForLabel(
        settings.themeLabel.value,
        appFontFamilyKey: settings.appFontFamilyKey.value,
      ),
      scrollBehavior: const MinaScrollBehavior(),
      initialBinding: InitialBinding(),
      initialRoute: initialRoute,
      getPages: AppPages.routes,
      routingCallback: (routing) {
        if (Get.isRegistered<ShowcaseInAppPipService>()) {
          Get.find<ShowcaseInAppPipService>().bumpRouteEpoch();
        }
      },
      defaultTransition: PageTransitionBuilder.getTransition(),
      customTransition: PageTransitionBuilder.customTransition,
      transitionDuration: PageTransitionBuilder.duration,
      builder: (context, child) {
        Get.find<IntegrityService>().scheduleReleaseCheckIfNeeded(context);
        // Liste geçişi sırasında (canlı TV / film / dizi / Film&Dizi) ekran
        // ortasında yanıp sönen şemsiye göstergesi — tüm içeriğin üzerinde.
        final wrapped = Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const Positioned.fill(child: PlaylistSwitchOverlay()),
            const ShowcaseInAppPipFloatingLayer(),
          ],
        );
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

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await MinaSecureStorage.warmUp();
      final prefs = await SharedPreferences.getInstance();
      final activeSlot = prefs.getInt('mina_active_playlist_slot') ?? 1;

      debugPrint('BackgroundSync: Starting silent sync for slot $activeSlot...');
      final repo = PlaylistRepositoryImpl();
      final result = await repo.loadSlotPlaylist(activeSlot);
      if (result != null) {
        debugPrint('BackgroundSync: Silent sync completed. Channels: ${result.channels.length}');
        return true;
      }
    } catch (e) {
      debugPrint('BackgroundSync: Silent sync failed: $e');
    }
    return false;
  });
}
