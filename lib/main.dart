import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_kit/media_kit.dart';

import 'core/bindings/initial_binding.dart';
import 'core/platform/android_playback_soc_hints.dart';
import 'core/i18n/app_locale.dart';
import 'core/i18n/app_translations.dart';
import 'core/services/app_settings_service.dart';
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

  final settings = AppSettingsService();
  await settings.ensureLoaded();
  Get.put<AppSettingsService>(settings, permanent: true);
  if (Platform.isAndroid) {
    unawaited(AndroidPlaybackSocHints.ensureLoaded());
  }
  Get.updateLocale(
    materialLocaleFromLanguageCode(settings.languageCode.value),
  );

  await settings.syncSystemChromeWithLayout();
  runApp(const MinaIptvApp());
}

class MinaIptvApp extends StatelessWidget {
  const MinaIptvApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return GetMaterialApp(
      title: 'Mina IPTV Player',
      debugShowCheckedModeBanner: false,
      translations: AppTranslations(),
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
      theme: AppTheme.dark,
      initialBinding: InitialBinding(),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.routes,
      defaultTransition: Transition.fadeIn,
      builder: (context, child) {
        final wrapped = child ?? const SizedBox.shrink();
        return ValueListenableBuilder<double>(
          valueListenable: settings.layoutTextScaleNotifier,
          builder: (context, factor, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(factor),
              ),
              child: child!,
            );
          },
          child: wrapped,
        );
      },
    );
  }
}
