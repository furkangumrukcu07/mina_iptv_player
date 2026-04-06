import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_locale.dart';
import '../layout/app_layout_mode.dart';
import '../routes/app_routes.dart';
import '../../ui/glass_overlays.dart';

/// Uygulama tercihleri (SharedPreferences).
class AppSettingsService extends GetxService {
  static const _kBg = 'mina_settings_bg_playback';
  static const _kLang = 'mina_settings_language';
  static const _kXmltv = 'mina_settings_xmltv_url';
  static const _kBuffer = 'mina_settings_live_buffer_sec';

  /// Kayıt yoksa veya sıfırlamada kullanılan canlı yayın tamponu (saniye).
  static const defaultLiveBufferSeconds = 3;
  static const _kTheme = 'mina_settings_theme_label';
  static const _kLayout = 'mina_settings_layout_mode';
  static const _kReduceBlur = 'mina_settings_reduce_blur';
  static const _kLaunchOnBoot = 'mina_settings_launch_on_boot';
  static const _kAlarmSet = 'mina_settings_alarm_set';
  static const _kAlarmH = 'mina_settings_alarm_h';
  static const _kAlarmM = 'mina_settings_alarm_m';
  static const _kCustomBgPath = 'mina_settings_custom_bg_path';
  static const _kLastLiveCat = 'mina_last_live_cat';
  static const _kLastLiveCh = 'mina_last_live_ch';
  static const _kLastFilmsCat = 'mina_last_films_cat';
  static const _kLastFilmsVod = 'mina_last_films_vod';
  static const _kLastSeriesCat = 'mina_last_series_cat';
  static const _kLastSeriesId = 'mina_last_series_id';
  static const _kLastFavCat = 'mina_last_fav_cat';
  static const _kLastFavSel = 'mina_last_fav_sel';
  static const _kAutoRefresh = 'mina_settings_auto_refresh_days';
  static const _kLastRefresh = 'mina_settings_last_refresh_time';

  /// Android: yazılım (Google OMX) video kod çözücü önceliği.
  static const _kPreferSoftwareDecoder =
      'mina_settings_prefer_software_decoder';

  /// İkinci oynatıcı (media_kit / libmpv).
  static const _kUseMediaKit = 'mina_settings_use_media_kit';
  static const _kUseVlcLegacy = 'mina_settings_use_vlc';

  /// Liste detayında canlı/film/dizi yayın önizlemesi (sessiz küçük oynatıcı).
  static const _kStreamPreview = 'mina_settings_stream_preview';
  static const _kSleepEnd = 'mina_settings_sleep_timer_end_ms';

  final backgroundPlayback = false.obs;
  final languageCode = 'tr'.obs;
  final xmltvUrl = ''.obs;
  final liveBufferSeconds = defaultLiveBufferSeconds.obs;
  final themeLabel = 'Varsayılan'.obs;
  final layoutMode = AppLayoutMode.tv.obs;

  /// [MediaQuery.textScaler] için; kök `GetMaterialApp` builder'da [ValueListenableBuilder] ile dinlenir.
  final layoutTextScaleNotifier = ValueNotifier<double>(1.2);

  final reduceBlur = false.obs;
  final launchOnBoot = false.obs;
  final useMediaKit = false.obs;
  final alarmHour = Rxn<int>();
  final alarmMinute = Rxn<int>();
  final alarmEnabled = false.obs;
  final customBackgroundPath = Rxn<String>();
  final lastLiveCategoryId = Rxn<int>();
  final lastLiveChannelId = Rxn<int>();
  final lastFilmsCategoryKey = Rxn<int>();
  final lastFilmsVodId = Rxn<int>();
  final lastSeriesCategoryKey = Rxn<int>();
  final lastSeriesId = Rxn<int>();
  final lastFavoritesCategoryKey = Rxn<int>();
  final lastFavoritesSelection = ''.obs;
  final autoRefreshDays = 0.obs; // 0: Kapalı, 3: 3 Gün, 7: 1 Hafta
  final lastRefreshTime = 0.obs; // epoch ms

  /// Android ExoPlayer: `true` = yazılım kod çözücü önce (TS uyumluluğu); varsayılan donanım.
  final preferSoftwareVideoDecoder = false.obs;

  /// Canlı / film / dizi listelerinde küçük yayın önizlemesi.
  final streamPreviewEnabled = true.obs;

  /// Uyku zamanlayıcısı bitişi (epoch ms); null = kapalı.
  final sleepTimerEndMs = Rxn<int>();

  Timer? _sleepTimer;

  /// Canlı / film / dizi liste detayında küçük önizleme (TV ve telefonda tercihe bağlı).
  bool get streamPreviewActive => streamPreviewEnabled.value;

  bool _loaded = false;

  void _syncLayoutTextScale() {
    final v = layoutMode.value.textScaleFactor;
    if (layoutTextScaleNotifier.value != v) {
      layoutTextScaleNotifier.value = v;
    }
  }

  @override
  void onInit() {
    super.onInit();
    ensureLoaded();
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    backgroundPlayback.value = p.getBool(_kBg) ?? false;
    final savedLang = p.getString(_kLang);
    if (savedLang != null && savedLang.isNotEmpty) {
      languageCode.value = savedLang;
    } else {
      final device = WidgetsBinding.instance.platformDispatcher.locale;
      languageCode.value = languageCodeFromDeviceLocale(device);
      await p.setString(_kLang, languageCode.value);
    }
    xmltvUrl.value = p.getString(_kXmltv) ?? '';
    liveBufferSeconds.value = p.getInt(_kBuffer) ?? defaultLiveBufferSeconds;
    themeLabel.value = p.getString(_kTheme) ?? 'Varsayılan';
    reduceBlur.value = p.getBool(_kReduceBlur) ?? true;
    launchOnBoot.value = p.getBool(_kLaunchOnBoot) ?? false;

    final rawLayout = p.getString(_kLayout);
    if (rawLayout == null) {
      // Cihaz tipine göre varsayılan mod belirle
      final shortestSide = WidgetsBinding.instance.platformDispatcher.views
              .first.physicalSize.shortestSide /
          WidgetsBinding
              .instance.platformDispatcher.views.first.devicePixelRatio;

      if (shortestSide >= 600) {
        // Tablet veya TV (600dp+ genellikle tablet/büyük ekran eşiğidir)
        layoutMode.value = AppLayoutMode.tv;
      } else {
        // Telefon
        layoutMode.value = AppLayoutMode.mobile;
      }
    } else {
      layoutMode.value =
          AppLayoutMode.tryParseName(rawLayout) ?? AppLayoutMode.tv;
    }
    await _applyLayoutMode(layoutMode.value);
    _syncLayoutTextScale();

    alarmEnabled.value = p.getBool(_kAlarmSet) ?? false;
    final h = p.getInt(_kAlarmH);
    final m = p.getInt(_kAlarmM);
    if (alarmEnabled.value && h != null && m != null) {
      alarmHour.value = h;
      alarmMinute.value = m;
    } else {
      alarmHour.value = null;
      alarmMinute.value = null;
    }

    final bgPath = p.getString(_kCustomBgPath);
    customBackgroundPath.value =
        (bgPath == null || bgPath.trim().isEmpty) ? null : bgPath.trim();

    final liveCat = p.getInt(_kLastLiveCat);
    lastLiveCategoryId.value =
        (liveCat == null || liveCat < 0) ? null : liveCat;
    lastLiveChannelId.value = p.getInt(_kLastLiveCh);

    lastFilmsCategoryKey.value = p.getInt(_kLastFilmsCat);
    lastFilmsVodId.value = p.getInt(_kLastFilmsVod);

    lastSeriesCategoryKey.value = p.getInt(_kLastSeriesCat);
    lastSeriesId.value = p.getInt(_kLastSeriesId);

    lastFavoritesCategoryKey.value = p.getInt(_kLastFavCat);
    lastFavoritesSelection.value = p.getString(_kLastFavSel) ?? '';
    autoRefreshDays.value = p.getInt(_kAutoRefresh) ?? 0;
    lastRefreshTime.value = p.getInt(_kLastRefresh) ?? 0;

    preferSoftwareVideoDecoder.value =
        p.getBool(_kPreferSoftwareDecoder) ?? false;

    var mk = p.getBool(_kUseMediaKit);
    if (mk == null) {
      final legacy = p.getBool(_kUseVlcLegacy);
      mk = legacy ?? false;
      await p.setBool(_kUseMediaKit, mk);
      if (legacy != null) {
        await p.remove(_kUseVlcLegacy);
      }
    }
    useMediaKit.value = mk;

    streamPreviewEnabled.value = p.getBool(_kStreamPreview) ?? true;

    final sleepEnd = p.getInt(_kSleepEnd);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (sleepEnd != null && sleepEnd > nowMs) {
      sleepTimerEndMs.value = sleepEnd;
    } else if (sleepEnd != null) {
      await p.remove(_kSleepEnd);
      sleepTimerEndMs.value = null;
    }

    _loaded = true;
    rescheduleSleepTimer();
  }

  @override
  void onClose() {
    _sleepTimer?.cancel();
    super.onClose();
  }

  Future<void> _persistSleepTimer() async {
    final p = await SharedPreferences.getInstance();
    final v = sleepTimerEndMs.value;
    if (v == null || v <= 0) {
      await p.remove(_kSleepEnd);
    } else {
      await p.setInt(_kSleepEnd, v);
    }
  }

  /// Süre dolunca oynatıcıyı kapatır, ana ekrana döner.
  void rescheduleSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    final end = sleepTimerEndMs.value;
    if (end == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (end <= now) {
      sleepTimerEndMs.value = null;
      unawaited(_persistSleepTimer());
      _invokeSleepTimerAction();
      return;
    }
    _sleepTimer = Timer(Duration(milliseconds: end - now), () {
      sleepTimerEndMs.value = null;
      unawaited(_persistSleepTimer());
      _invokeSleepTimerAction();
    });
  }

  void _invokeSleepTimerAction() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    Future.microtask(() {
      try {
        if (Get.currentRoute == AppRoutes.player) {
          Get.back<void>();
        }
        Get.until((route) =>
            route.settings.name == AppRoutes.home || route.isFirst);
      } catch (_) {}
      Get.closeAllSnackbars();
      GlassSnackbar.show(
        'settings.sleepTimer.title'.tr,
        'settings.sleepTimer.fired'.tr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    });
  }

  /// 0 veya negatif: kapatır. Dakika cinsinden geri sayım.
  Future<void> setSleepTimerMinutes(int minutes) async {
    if (minutes <= 0) {
      sleepTimerEndMs.value = null;
      await _persistSleepTimer();
      _sleepTimer?.cancel();
      _sleepTimer = null;
      return;
    }
    final end = DateTime.now()
        .add(Duration(minutes: minutes))
        .millisecondsSinceEpoch;
    sleepTimerEndMs.value = end;
    await _persistSleepTimer();
    rescheduleSleepTimer();
  }

  String get sleepTimerSubtitle {
    final end = sleepTimerEndMs.value;
    if (end == null) return 'settings.sleepTimer.off'.tr;
    final remain = end - DateTime.now().millisecondsSinceEpoch;
    if (remain <= 0) return 'settings.sleepTimer.off'.tr;
    final mins = (remain / 60000).ceil().clamp(1, 9999);
    return 'settings.sleepTimer.remaining'.trParams({'min': '$mins'});
  }

  Future<void> _applyLayoutMode(AppLayoutMode mode) async {
    if (mode == AppLayoutMode.tv) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ));
    }
    if (mode == AppLayoutMode.mobile) {
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[]);
      return;
    }
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  String get languageLabel =>
      languageCode.value == 'en' ? 'common.lang.en'.tr : 'common.lang.tr'.tr;

  String get layoutLabel => layoutMode.value.title;

  String get xmltvSubtitle {
    final u = xmltvUrl.value.trim();
    if (u.isEmpty) return '—';
    if (u.length <= 32) return u;
    return '${u.substring(0, 14)}…${u.substring(u.length - 14)}';
  }

  String get alarmSubtitle {
    if (!alarmEnabled.value ||
        alarmHour.value == null ||
        alarmMinute.value == null) {
      return 'settings.alarmNotSet'.tr;
    }
    final h = alarmHour.value!.toString().padLeft(2, '0');
    final m = alarmMinute.value!.toString().padLeft(2, '0');
    return 'settings.alarmDailyAt'.trParams({'time': '$h:$m'});
  }

  String get liveBufferSubtitle {
    final s = liveBufferSeconds.value;
    if (s <= 0) return 'settings.bufferSecondsZero'.tr;
    return 'settings.bufferSeconds'.trParams({'n': '$s'});
  }

  Future<void> setBackgroundPlayback(bool v) async {
    backgroundPlayback.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kBg, v);
  }

  Future<void> setLanguageCode(String code) async {
    languageCode.value = code;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLang, code);
    Get.updateLocale(materialLocaleFromLanguageCode(code));
  }

  Future<void> setXmltvUrl(String url) async {
    xmltvUrl.value = url.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kXmltv, xmltvUrl.value);
  }

  Future<void> setLiveBufferSeconds(int sec) async {
    liveBufferSeconds.value = sec.clamp(0, 120);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kBuffer, liveBufferSeconds.value);
  }

  Future<void> setThemeLabel(String label) async {
    themeLabel.value = label;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, label);
  }

  Future<void> setLayoutMode(AppLayoutMode mode) async {
    layoutMode.value = mode;
    _syncLayoutTextScale();
    await _applyLayoutMode(mode);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLayout, mode.name);
  }

  Future<void> setReduceBlur(bool v) async {
    reduceBlur.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kReduceBlur, v);
  }

  Future<void> setLaunchOnBoot(bool v) async {
    launchOnBoot.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLaunchOnBoot, v);
  }

  Future<void> setCustomBackgroundPath(String? path) async {
    final v = path?.trim();
    customBackgroundPath.value = (v == null || v.isEmpty) ? null : v;
    final p = await SharedPreferences.getInstance();
    if (customBackgroundPath.value == null) {
      await p.remove(_kCustomBgPath);
    } else {
      await p.setString(_kCustomBgPath, customBackgroundPath.value!);
    }
  }

  Future<void> setLastLiveCategoryId(int? id) async {
    lastLiveCategoryId.value = id;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastLiveCat, id ?? -1);
  }

  Future<void> setLastLiveChannelId(int id) async {
    lastLiveChannelId.value = id;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastLiveCh, id);
  }

  Future<void> setLastFilmsSelection({
    required int categoryKey,
    int? vodId,
  }) async {
    lastFilmsCategoryKey.value = categoryKey;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastFilmsCat, categoryKey);
    if (vodId != null && vodId > 0) {
      lastFilmsVodId.value = vodId;
      await p.setInt(_kLastFilmsVod, vodId);
    }
  }

  Future<void> setLastSeriesSelection({
    required int categoryKey,
    int? seriesId,
  }) async {
    lastSeriesCategoryKey.value = categoryKey;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastSeriesCat, categoryKey);
    if (seriesId != null && seriesId > 0) {
      lastSeriesId.value = seriesId;
      await p.setInt(_kLastSeriesId, seriesId);
    }
  }

  Future<void> setLastFavoritesSelection({
    required int categoryKey,
    required String selection,
  }) async {
    lastFavoritesCategoryKey.value = categoryKey;
    lastFavoritesSelection.value = selection;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastFavCat, categoryKey);
    await p.setString(_kLastFavSel, selection);
  }

  Future<void> setAutoRefreshDays(int days) async {
    autoRefreshDays.value = days;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kAutoRefresh, days);
  }

  Future<void> setStreamPreviewEnabled(bool v) async {
    streamPreviewEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kStreamPreview, v);
  }

  Future<void> setPreferSoftwareVideoDecoder(bool v) async {
    preferSoftwareVideoDecoder.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPreferSoftwareDecoder, v);
  }

  Future<void> setUseMediaKit(bool v) async {
    useMediaKit.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kUseMediaKit, v);
  }

  String get videoDecoderModeSubtitle {
    if (preferSoftwareVideoDecoder.value) {
      return 'settings.decoder.software'.tr;
    }
    return 'settings.decoder.hardware'.tr;
  }

  Future<void> updateLastRefreshTime() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    lastRefreshTime.value = now;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastRefresh, now);
  }

  bool shouldRefreshContent() {
    if (autoRefreshDays.value <= 0) return false;
    if (lastRefreshTime.value <= 0) return true;

    final last = DateTime.fromMillisecondsSinceEpoch(lastRefreshTime.value);
    final diff = DateTime.now().difference(last).inDays;
    return diff >= autoRefreshDays.value;
  }

  Future<void> setAlarm({required int hour, required int minute}) async {
    alarmHour.value = hour;
    alarmMinute.value = minute;
    alarmEnabled.value = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAlarmSet, true);
    await p.setInt(_kAlarmH, hour);
    await p.setInt(_kAlarmM, minute);
  }

  Future<void> clearAlarm() async {
    alarmEnabled.value = false;
    alarmHour.value = null;
    alarmMinute.value = null;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAlarmSet, false);
    await p.remove(_kAlarmH);
    await p.remove(_kAlarmM);
  }

  Future<void> resetToDefaults() async {
    backgroundPlayback.value = false;
    final device = WidgetsBinding.instance.platformDispatcher.locale;
    languageCode.value = languageCodeFromDeviceLocale(device);
    xmltvUrl.value = '';
    liveBufferSeconds.value = defaultLiveBufferSeconds;
    themeLabel.value = 'Varsayılan';
    layoutMode.value = AppLayoutMode.tv;
    _syncLayoutTextScale();
    await _applyLayoutMode(layoutMode.value);
    reduceBlur.value = true;
    launchOnBoot.value = false;
    await clearAlarm();
    sleepTimerEndMs.value = null;
    _sleepTimer?.cancel();
    _sleepTimer = null;
    customBackgroundPath.value = null;
    lastLiveCategoryId.value = null;
    lastLiveChannelId.value = null;
    lastFilmsCategoryKey.value = null;
    lastFilmsVodId.value = null;
    lastSeriesCategoryKey.value = null;
    lastSeriesId.value = null;
    lastFavoritesCategoryKey.value = null;
    lastFavoritesSelection.value = '';
    preferSoftwareVideoDecoder.value = false;
    useMediaKit.value = false;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kBg);
    await p.setString(_kLang, languageCode.value);
    await p.remove(_kXmltv);
    await p.setInt(_kBuffer, defaultLiveBufferSeconds);
    await p.remove(_kTheme);
    await p.remove(_kLayout);
    await p.setBool(_kReduceBlur, true);
    await p.remove(_kLaunchOnBoot);
    await p.remove(_kCustomBgPath);
    await p.remove(_kLastLiveCat);
    await p.remove(_kLastLiveCh);
    await p.remove(_kLastFilmsCat);
    await p.remove(_kLastFilmsVod);
    await p.remove(_kLastSeriesCat);
    await p.remove(_kLastSeriesId);
    await p.remove(_kLastFavCat);
    await p.remove(_kLastFavSel);
    await p.setBool(_kPreferSoftwareDecoder, false);
    await p.remove(_kUseMediaKit);
    await p.remove(_kUseVlcLegacy);
    await p.remove(_kSleepEnd);
  }
}
