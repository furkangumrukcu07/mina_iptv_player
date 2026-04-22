import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n/app_locale.dart';
import '../layout/app_layout_mode.dart';
import '../theme/glass_appearance.dart';
import '../platform/device_layout_defaults.dart';
import '../routes/app_routes.dart';
import '../player/adaptive_stream_quality_ceiling.dart';
import '../player/playback_orientation_manager.dart';
import '../epg/catch_up_url_template.dart';
import '../../domain/entities/playlist_source.dart';
import '../../ui/glass_overlays.dart';

/// Uygulama tercihleri (SharedPreferences).
class AppSettingsService extends GetxService with WidgetsBindingObserver {
  /// Telefon/tablet el modu: sensörle dikey ↔ yatay; kilit takılı kalmaması için açık tutulur.
  static const List<DeviceOrientation> sensorHandheldOrientations =
      <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static const _kBg = 'mina_settings_bg_playback';
  static const _kLang = 'mina_settings_language';
  static const _kXmltv = 'mina_settings_xmltv_url';
  static const _kBuffer = 'mina_settings_live_buffer_sec';

  /// Kayıt yoksa veya sıfırlamada kullanılan canlı yayın tamponu (saniye).
  static const defaultLiveBufferSeconds = 3;
  static const _kTheme = 'mina_settings_theme_label';
  static const _kLayout = 'mina_settings_layout_mode';
  /// Eski sürümde telefonda yanlış kaydedilen `tv` düzenini bir kez düzelt.
  static const _kLayoutPhoneTvFix = 'mina_settings_layout_phone_tv_fix_applied';
  static const _kReduceBlur = 'mina_settings_reduce_blur';
  static const _kLaunchOnBoot = 'mina_settings_launch_on_boot';
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
  /// MediaKit Android: `true` → `hwdec=mediacodec`, `false` → `mediacodec-copy`.
  static const _kMediaKitLowPowerHwdec =
      'mina_settings_media_kit_low_power_hwdec';

  /// Liste detayında canlı/film/dizi yayın önizlemesi (sessiz küçük oynatıcı).
  static const _kStreamPreview = 'mina_settings_stream_preview';
  /// Android telefon: ana ekrana dönünce Picture-in-Picture (sürüklenebilir mini pencere).
  static const _kMiniPlayerHome = 'mina_settings_mini_player_home';
  static const _kSleepEnd = 'mina_settings_sleep_timer_end_ms';

  /// Gömülü altyazı punto (pt): ExoPlayer/Better Player + isteğe bağlı MediaKit (mpv sub-scale).
  static const _kSubtitleFontPt = 'mina_settings_subtitle_font_pt';

  /// HLS/DASH çoklu varyant üst çözünürlük (720 / 1080 / 4K / otomatik).
  static const _kAdaptiveQualityCeiling =
      'mina_settings_adaptive_quality_ceiling';

  /// Xtream EPG catch-up URL şablonu (panel biçimi).
  static const _kCatchUpPreset = 'mina_settings_catch_up_preset';
  static const _kCatchUpCustomTemplate =
      'mina_settings_catch_up_custom_template';

  /// Xtream sunucu+hesap anahtarına göre gizlenen kategori kimlikleri (JSON).
  static const _kXtreamHidden = 'mina_xtream_hidden_categories_v1';

  /// M3U / yerel liste: kaynak URL’sine göre gizlenen kategori adları (normalize edilmiş, JSON).
  static const _kM3uHidden = 'mina_m3u_hidden_categories_v1';

  /// Xtream: panelin döndürdüğü XMLTV EPG URL’sini yükleme; yalnızca `get_all_live_epg`.
  static const _kXtreamSkipPanelXmltv =
      'mina_settings_xtream_skip_panel_xmltv_epg';

  final backgroundPlayback = false.obs;
  final languageCode = 'tr'.obs;
  final xmltvUrl = ''.obs;
  final liveBufferSeconds = defaultLiveBufferSeconds.obs;
  final themeLabel = GlassThemeLabels.glassGri.obs;
  final layoutMode = AppLayoutMode.mobile.obs;

  /// Mobil oynatıcıda OSD «dikey» ile kullanıcı dikeye sabitledi; yatay OSD «yatay» ile kalkar.
  final mobilePlaybackPortraitUserLocked = false.obs;

  /// [MediaQuery.textScaler] için; kök `GetMaterialApp` builder'da [ValueListenableBuilder] ile dinlenir.
  final layoutTextScaleNotifier = ValueNotifier<double>(1.2);

  /// Ağır blur ve animasyonları kısaltır / kapatır ([MediaQuery.disableAnimations]).
  final reduceBlur = true.obs;
  final launchOnBoot = false.obs;
  /// Varsayılan açık; ilk kurulumda prefs yoksa [ensureLoaded] `true` yazar.
  final useMediaKit = false.obs;
  /// Zayıf GPU’lu eski TV kutuları için tam donanım çözüm (mpv `hwdec=mediacodec`).
  final mediaKitLowPowerHwdec = false.obs;
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

  /// Canlı / film / dizi listelerinde küçük yayın önizlemesi; varsayılan açık ([ensureLoaded] `?? true`).
  final streamPreviewEnabled = true.obs;
  
  /// OSD paneli otomatik gizlenme süresi (TV modu için)
  final tvOsdAutoHideDuration = 5.obs; // 5 saniye

  /// Android: yayın sırasında ana ekrana geçince PiP (Better/Exo). MediaKit’te kullanılmaz.
  final miniPlayerOnHome = false.obs;

  /// Uyku zamanlayıcısı bitişi (epoch ms); null = kapalı.
  final sleepTimerEndMs = Rxn<int>();

  /// Altyazı yazı boyutu (Better Player, pt).
  final subtitleFontPt = 14.0.obs;

  /// Canlı / VOD HLS master’da en yüksek hangi varyantın seçileceği üst sınırı.
  final adaptiveStreamQualityCeiling =
      AdaptiveStreamQualityCeiling.auto.obs;

  /// Xtream: EPG’den catch-up URL’si için panel şablonu (kapalı / hazır / özel).
  final catchUpUrlPreset = CatchUpUrlPreset.off.obs;

  /// [CatchUpUrlPreset.custom] için tam şablon metni.
  final catchUpCustomTemplate = ''.obs;

  /// Gizlenen Xtream kategorileri güncellenince listeler yenilensin diye artırılır.
  final xtreamHideRevision = 0.obs;

  /// `true` → Xtream panel XMLTV EPG atlanır; yalnızca API (`get_all_live_epg`).
  final xtreamSkipPanelXmltvEpg = false.obs;

  Map<String, Map<String, List<int>>> _xtreamHiddenBySource = {};
  Map<String, Map<String, List<String>>> _m3uHiddenBySource = {};

  /// [setSubtitleFontPt] çağrılınca tetiklenir — oynatıcı anında güncellemesi (GetX [ever] yedeği).
  VoidCallback? onSubtitleFontPtApplied;

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
    WidgetsBinding.instance.addObserver(this);
    ensureLoaded();
  }

  /// Cihaz döndüğünde [OrientationBuilder] bazen bir kare gecikir; burada hemen sensör + chrome senkronu.
  @override
  void didChangeMetrics() {
    if (kIsWeb) return;
    if (layoutMode.value == AppLayoutMode.mobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(syncMobileHandheldChromeToCurrentOrientation());
      });
    } else if (layoutMode.value == AppLayoutMode.tablet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(syncTabletHandheldChromeToCurrentOrientation());
      });
    }
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    // Eski sürümlerde özel arka plan yolu; READ_MEDIA kaldırıldı, anahtarı temizle.
    if (p.containsKey('mina_settings_custom_bg_path')) {
      await p.remove('mina_settings_custom_bg_path');
    }
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
    final savedTheme = p.getString(_kTheme);
    if (savedTheme == null || savedTheme.isEmpty) {
      themeLabel.value = GlassThemeLabels.koyuCam;
      await p.setString(_kTheme, GlassThemeLabels.koyuCam);
    } else if (savedTheme == 'Yeşil Cam' ||
        savedTheme == 'Kırmızı Cam' ||
        savedTheme == 'Mavi Cam' ||
        savedTheme == 'Mor Cam') {
      themeLabel.value = GlassThemeLabels.varsayilan;
      await p.setString(_kTheme, GlassThemeLabels.varsayilan);
    } else {
      themeLabel.value = savedTheme;
    }
    reduceBlur.value = p.getBool(_kReduceBlur) ?? true;
    if (p.containsKey('mina_settings_low_performance_mode')) {
      await p.remove('mina_settings_low_performance_mode');
    }
    launchOnBoot.value = p.getBool(_kLaunchOnBoot) ?? false;

    final rawLayout = p.getString(_kLayout);
    if (rawLayout == null) {
      layoutMode.value = await resolveDefaultLayoutMode();
      await p.setString(_kLayout, layoutMode.value.name);
    } else {
      final parsed = AppLayoutMode.tryParseName(rawLayout);
      if (parsed != null) {
        layoutMode.value = parsed;
        final fixDone = p.getBool(_kLayoutPhoneTvFix) ?? false;
        if (!fixDone &&
            parsed == AppLayoutMode.tv &&
            !(await nativeAndroidTv())) {
          final views = WidgetsBinding.instance.platformDispatcher.views;
          if (views.isNotEmpty) {
            final view = views.first;
            final dpr = view.devicePixelRatio;
            if (dpr > 0) {
              final dip = view.physicalSize.shortestSide / dpr;
              if (dip > 0 && dip < 600) {
                layoutMode.value = AppLayoutMode.mobile;
                await p.setString(_kLayout, AppLayoutMode.mobile.name);
              }
            }
          }
          await p.setBool(_kLayoutPhoneTvFix, true);
        }
      } else {
        layoutMode.value = await resolveDefaultLayoutMode();
        await p.setString(_kLayout, layoutMode.value.name);
      }
    }
    await _applyLayoutMode(layoutMode.value);
    _syncLayoutTextScale();

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
      // İlk kurulum: film/dizi için varsayılan Exo (Better); donanım hatasında MediaKit’e düşülür.
      mk = false;
      await p.setBool(_kUseMediaKit, false);
      final legacy = p.getBool(_kUseVlcLegacy);
      if (legacy != null) {
        await p.remove(_kUseVlcLegacy);
      }
    }
    useMediaKit.value = mk;
    
    // OSD otomatik gizlenme süresini yükle
    tvOsdAutoHideDuration.value = p.getInt('mina_settings_tv_osd_auto_hide_duration') ?? 5;

    mediaKitLowPowerHwdec.value =
        p.getBool(_kMediaKitLowPowerHwdec) ?? false;

    streamPreviewEnabled.value = p.getBool(_kStreamPreview) ?? true;

    miniPlayerOnHome.value = p.getBool(_kMiniPlayerHome) ?? false;

    final sleepEnd = p.getInt(_kSleepEnd);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (sleepEnd != null && sleepEnd > nowMs) {
      sleepTimerEndMs.value = sleepEnd;
    } else if (sleepEnd != null) {
      await p.remove(_kSleepEnd);
      sleepTimerEndMs.value = null;
    }

    final subPt = p.getDouble(_kSubtitleFontPt);
    if (subPt != null && subPt >= 10 && subPt <= 40) {
      subtitleFontPt.value = subPt;
    }

    adaptiveStreamQualityCeiling.value = AdaptiveStreamQualityCeiling.fromStorage(
      p.getString(_kAdaptiveQualityCeiling),
    );

    catchUpUrlPreset.value =
        CatchUpUrlPreset.fromStorage(p.getString(_kCatchUpPreset));
    catchUpCustomTemplate.value = p.getString(_kCatchUpCustomTemplate) ?? '';

    xtreamSkipPanelXmltvEpg.value =
        p.getBool(_kXtreamSkipPanelXmltv) ?? false;

    _loadXtreamHiddenFromPrefs(p);
    _loadM3uHiddenFromPrefs(p);

    _loaded = true;
    rescheduleSleepTimer();
  }

  /// [XtreamSource] için kalıcı tercih anahtarı (MD5).
  static String xtreamPreferenceKey(XtreamSource source) {
    final raw =
        '${source.baseUrl.trim().toLowerCase()}|${source.username.trim().toLowerCase()}';
    return md5.convert(utf8.encode(raw)).toString();
  }

  /// M3U / dosya / HTTP playlist kaynağı için gizleme anahtarı (MD5).
  /// Kategori kimlikleri parse sırasına bağlı olduğundan M3U’da gizleme [normalizePlaylistCategoryName] ile yapılır.
  static String m3uPreferenceKey(String sourceUrl) =>
      md5.convert(utf8.encode(sourceUrl.trim().toLowerCase())).toString();

  static String normalizePlaylistCategoryName(String name) =>
      name.trim().toLowerCase();

  void _loadXtreamHiddenFromPrefs(SharedPreferences p) {
    _xtreamHiddenBySource = {};
    final raw = p.getString(_kXtreamHidden);
    if (raw == null || raw.isEmpty) return;
    try {
      final dec = json.decode(raw);
      if (dec is! Map) return;
      dec.forEach((k, v) {
        if (k is! String || v is! Map) return;
        final vm = Map<String, dynamic>.from(v);
        _xtreamHiddenBySource[k] = {
          'live': _intListFromJson(vm['live']),
          'vod': _intListFromJson(vm['vod']),
          'series': _intListFromJson(vm['series']),
        };
      });
    } catch (_) {}
  }

  static List<int> _intListFromJson(dynamic v) {
    if (v is! List) return [];
    return v
        .map((e) => int.tryParse(e.toString()) ?? 0)
        .where((i) => i > 0)
        .toList();
  }

  static List<String> _stringListFromJson(dynamic v) {
    if (v is! List) return [];
    return v
        .map((e) => e?.toString().trim().toLowerCase() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _loadM3uHiddenFromPrefs(SharedPreferences p) {
    _m3uHiddenBySource = {};
    final raw = p.getString(_kM3uHidden);
    if (raw == null || raw.isEmpty) return;
    try {
      final dec = json.decode(raw);
      if (dec is! Map) return;
      dec.forEach((k, v) {
        if (k is! String || v is! Map) return;
        final vm = Map<String, dynamic>.from(v);
        _m3uHiddenBySource[k] = {
          'live': _stringListFromJson(vm['live']),
          'vod': _stringListFromJson(vm['vod']),
          'series': _stringListFromJson(vm['series']),
        };
      });
    } catch (_) {}
  }

  Set<int> xtreamHiddenLiveIds(String key) {
    xtreamHideRevision.value;
    return Set<int>.from(_xtreamHiddenBySource[key]?['live'] ?? const <int>[]);
  }

  Set<int> xtreamHiddenVodIds(String key) {
    xtreamHideRevision.value;
    return Set<int>.from(_xtreamHiddenBySource[key]?['vod'] ?? const <int>[]);
  }

  Set<int> xtreamHiddenSeriesIds(String key) {
    xtreamHideRevision.value;
    return Set<int>.from(
        _xtreamHiddenBySource[key]?['series'] ?? const <int>[]);
  }

  Set<String> m3uHiddenLiveNames(String key) {
    xtreamHideRevision.value;
    return Set<String>.from(
        _m3uHiddenBySource[key]?['live'] ?? const <String>[]);
  }

  Set<String> m3uHiddenVodNames(String key) {
    xtreamHideRevision.value;
    return Set<String>.from(
        _m3uHiddenBySource[key]?['vod'] ?? const <String>[]);
  }

  Set<String> m3uHiddenSeriesNames(String key) {
    xtreamHideRevision.value;
    return Set<String>.from(
        _m3uHiddenBySource[key]?['series'] ?? const <String>[]);
  }

  Future<void> saveXtreamHiddenCategories(
    String key, {
    required Set<int> live,
    required Set<int> vod,
    required Set<int> series,
  }) async {
    _xtreamHiddenBySource[key] = {
      'live': (live.toList()..sort()),
      'vod': (vod.toList()..sort()),
      'series': (series.toList()..sort()),
    };
    final p = await SharedPreferences.getInstance();
    await p.setString(_kXtreamHidden, json.encode(_xtreamHiddenBySource));
    xtreamHideRevision.value++;
  }

  Future<void> saveM3uHiddenCategories(
    String key, {
    required Set<String> live,
    required Set<String> vod,
    required Set<String> series,
  }) async {
    _m3uHiddenBySource[key] = {
      'live': (live.toList()..sort()),
      'vod': (vod.toList()..sort()),
      'series': (series.toList()..sort()),
    };
    final p = await SharedPreferences.getInstance();
    await p.setString(_kM3uHidden, json.encode(_m3uHiddenBySource));
    xtreamHideRevision.value++;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
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

  String get subtitleFontPtLabel =>
      'settings.tile.subtitleOptions.sub'.trParams({
        'pt': subtitleFontPt.value.round().toString(),
      });

  Future<void> setSubtitleFontPt(double pt) async {
    final v = pt.clamp(10.0, 40.0);
    subtitleFontPt.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kSubtitleFontPt, v);
    onSubtitleFontPtApplied?.call();
  }

  String get adaptiveStreamQualityCeilingSubtitle {
    switch (adaptiveStreamQualityCeiling.value) {
      case AdaptiveStreamQualityCeiling.auto:
        return 'settings.adaptiveQuality.shortAuto'.tr;
      case AdaptiveStreamQualityCeiling.p720:
        return 'settings.adaptiveQuality.short720'.tr;
      case AdaptiveStreamQualityCeiling.p1080:
        return 'settings.adaptiveQuality.short1080'.tr;
      case AdaptiveStreamQualityCeiling.p4k:
        return 'settings.adaptiveQuality.short4k'.tr;
    }
  }

  Future<void> setAdaptiveStreamQualityCeiling(
    AdaptiveStreamQualityCeiling value,
  ) async {
    adaptiveStreamQualityCeiling.value = value;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAdaptiveQualityCeiling, value.storageValue);
  }

  /// [CatchUpUrlBuilder] için geçerli şablon; kapalıysa boş.
  String get catchUpTemplateEffective {
    switch (catchUpUrlPreset.value) {
      case CatchUpUrlPreset.off:
        return '';
      case CatchUpUrlPreset.xtreamTimeshiftPath:
        return CatchUpUrlDefaults.xtreamTimeshiftPath;
      case CatchUpUrlPreset.timeshiftPhpQuery:
        return CatchUpUrlDefaults.timeshiftPhpQuery;
      case CatchUpUrlPreset.custom:
        final c = catchUpCustomTemplate.value.trim();
        return c.isNotEmpty ? c : CatchUpUrlDefaults.xtreamTimeshiftPath;
    }
  }

  String get catchUpUrlPresetSubtitle {
    switch (catchUpUrlPreset.value) {
      case CatchUpUrlPreset.off:
        return 'settings.catchUp.shortOff'.tr;
      case CatchUpUrlPreset.xtreamTimeshiftPath:
        return 'settings.catchUp.shortXtreamPath'.tr;
      case CatchUpUrlPreset.timeshiftPhpQuery:
        return 'settings.catchUp.shortPhp'.tr;
      case CatchUpUrlPreset.custom:
        return 'settings.catchUp.shortCustom'.tr;
    }
  }

  Future<void> setCatchUpUrlPreset(CatchUpUrlPreset value) async {
    catchUpUrlPreset.value = value;
    final p = await SharedPreferences.getInstance();
    if (value == CatchUpUrlPreset.off) {
      await p.remove(_kCatchUpPreset);
    } else {
      await p.setString(_kCatchUpPreset, value.storageValue);
    }
  }

  Future<void> setCatchUpCustomTemplate(String value) async {
    catchUpCustomTemplate.value = value;
    final p = await SharedPreferences.getInstance();
    final t = value.trim();
    if (t.isEmpty) {
      await p.remove(_kCatchUpCustomTemplate);
    } else {
      await p.setString(_kCatchUpCustomTemplate, t);
    }
  }

  /// iOS: dokunulmaz (immersive). Android telefon + mobil düzen: gerçek durum çubuğu (edge-to-edge).
  Future<void> syncSystemChromeWithLayout() async {
    if (layoutMode.value == AppLayoutMode.mobile) {
      await syncMobileHandheldChromeToCurrentOrientation();
      return;
    }
    if (layoutMode.value == AppLayoutMode.tablet) {
      await syncTabletHandheldChromeToCurrentOrientation();
      return;
    }
    await _applySystemChromeForLayout(layoutMode.value);
  }

  /// Telefon düzeni: yatayda tam ekran (durum çubuğu gizli), dikeyde edge-to-edge + çubuk.
  Future<void> syncMobileHandheldChromeToCurrentOrientation() async {
    if (kIsWeb) return;
    if (layoutMode.value != AppLayoutMode.mobile) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (mobilePlaybackPortraitUserLocked.value) {
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await applyMobilePlayerOrientationChrome(landscapePlayback: false);
      return;
    }
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final ps = views.first.physicalSize;
    if (ps.width <= 0 || ps.height <= 0) return;
    final landscape = ps.width > ps.height;
    await SystemChrome.setPreferredOrientations(sensorHandheldOrientations);
    await applyMobilePlayerOrientationChrome(landscapePlayback: landscape);
  }

  /// Tablet düzeni: sensörle yatay/dikey; mobil ile aynı kilitleme mantığı.
  Future<void> syncTabletHandheldChromeToCurrentOrientation() async {
    if (kIsWeb) return;
    if (layoutMode.value != AppLayoutMode.tablet) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final ps = views.first.physicalSize;
    if (ps.width <= 0 || ps.height <= 0) return;
    final landscape = ps.width > ps.height;
    await SystemChrome.setPreferredOrientations(sensorHandheldOrientations);
    await _applyTabletHandheldChrome(landscapeWide: landscape);
  }

  Future<void> _applyTabletHandheldChrome({required bool landscapeWide}) async {
    if (kIsWeb) return;
    if (layoutMode.value != AppLayoutMode.tablet) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (landscapeWide) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        statusBarBrightness: Brightness.dark,
      ));
      return;
    }
    await _applySystemChromeForLayout(AppLayoutMode.tablet);
  }

  /// Dikey OSD’den yatay: yatay yönlere kilitler; telefon dikeyde tutulsa da sistem yataya döner.
  Future<void> requestMobileHandheldLandscapePlayback() async {
    await PlaybackOrientationManager.forceLandscapeMobilePlayback();
  }

  /// Mobil oynatıcı OSD’den dikey: dikeye sabitler (fiziksel yatayda bile UI dikey kalır).
  /// Yatay dönmek için OSD’den [requestMobileHandheldLandscapePlayback] veya oynatıcıdan çıkış.
  Future<void> requestMobileHandheldPortraitPlayback() async {
    await PlaybackOrientationManager.forcePortraitMobilePlayback();
  }

  /// Oynatıcı kapanırken dikey kilidi kaldır (ana ekranda yatayda takılı kalmasın).
  Future<void> clearMobilePlaybackPortraitLockForLeavingPlayer() async {
    if (!mobilePlaybackPortraitUserLocked.value) return;
    mobilePlaybackPortraitUserLocked.value = false;
    await syncMobileHandheldChromeToCurrentOrientation();
  }

  /// Tablet oynatıcı: yatayda tam ekran, dikeyde normal (sensörle dönüş).
  Future<void> applyTabletPlayerOrientationChrome({
    required bool landscapePlayback,
  }) async {
    await _applyTabletHandheldChrome(landscapeWide: landscapePlayback);
  }

  /// Mobil düzen: yatay oynatıcıda tam ekran (durum/pil çubuğu yok); dikeyde normal (Android’de edge-to-edge + çubuk).
  Future<void> applyMobilePlayerOrientationChrome({
    required bool landscapePlayback,
  }) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (layoutMode.value != AppLayoutMode.mobile) return;
    if (landscapePlayback) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemStatusBarContrastEnforced: false,
        statusBarBrightness: Brightness.dark,
      ));
      return;
    }
    await _applySystemChromeForLayout(AppLayoutMode.mobile);
  }

  Future<void> _applySystemChromeForLayout(AppLayoutMode mode) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (mode == AppLayoutMode.tv) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
        ));
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
        ));
      }
      return;
    }
    if (mode == AppLayoutMode.tv) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ));
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _applyLayoutMode(AppLayoutMode mode) async {
    if (mode == AppLayoutMode.mobile) {
      await syncMobileHandheldChromeToCurrentOrientation();
      return;
    }
    if (mode == AppLayoutMode.tablet) {
      await syncTabletHandheldChromeToCurrentOrientation();
      return;
    }
    await _applySystemChromeForLayout(mode);
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  String get languageLabel => switch (languageCode.value) {
        'tr' => 'common.lang.tr'.tr,
        'en' => 'common.lang.en'.tr,
        'fr' => 'common.lang.fr'.tr,
        'ar' => 'common.lang.ar'.tr,
        'zh' => 'common.lang.zh'.tr,
        'ru' => 'common.lang.ru'.tr,
        _ => 'common.lang.en'.tr,
      };

  String get layoutLabel => layoutMode.value.title;

  String get xmltvSubtitle {
    final u = xmltvUrl.value.trim();
    if (u.isEmpty) return '—';
    if (u.length <= 32) return u;
    return '${u.substring(0, 14)}…${u.substring(u.length - 14)}';
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

  Future<void> setMiniPlayerOnHome(bool v) async {
    miniPlayerOnHome.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMiniPlayerHome, v);
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

  Future<void> setXtreamSkipPanelXmltvEpg(bool v) async {
    xtreamSkipPanelXmltvEpg.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kXtreamSkipPanelXmltv, v);
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

  Future<void> setMediaKitLowPowerHwdec(bool v) async {
    mediaKitLowPowerHwdec.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMediaKitLowPowerHwdec, v);
  }

  /// MediaKit (Android) `hwdec` mpv değeri.
  String get mediaKitHwdecMpvValue =>
      mediaKitLowPowerHwdec.value ? 'mediacodec' : 'mediacodec-copy';

  /// OSD otomatik gizlenme süresini kaydet
  Future<void> setTvOsdAutoHideDuration(int seconds) async {
    tvOsdAutoHideDuration.value = seconds;
    final p = await SharedPreferences.getInstance();
    await p.setInt('mina_settings_tv_osd_auto_hide_duration', seconds);
  }

  /// Amlogic / Meson kutularda `mediacodec-copy` sık kasıyor; doğrudan `mediacodec` kullanılır.
  String resolveMediaKitHwdecMpvValue({bool amlogicLike = false}) {
    if (amlogicLike) return 'mediacodec';
    return mediaKitHwdecMpvValue;
  }

  String get mediaKitHwdecModeSubtitle => mediaKitLowPowerHwdec.value
      ? 'settings.tile.mediaKitHwdec.subLowPower'.tr
      : 'settings.tile.mediaKitHwdec.subBalanced'.tr;

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

  Future<void> resetToDefaults() async {
    backgroundPlayback.value = false;
    final device = WidgetsBinding.instance.platformDispatcher.locale;
    languageCode.value = languageCodeFromDeviceLocale(device);
    xmltvUrl.value = '';
    liveBufferSeconds.value = defaultLiveBufferSeconds;
    themeLabel.value = GlassThemeLabels.varsayilan;
    layoutMode.value = await resolveDefaultLayoutMode();
    _syncLayoutTextScale();
    await _applyLayoutMode(layoutMode.value);
    reduceBlur.value = true;
    launchOnBoot.value = false;
    sleepTimerEndMs.value = null;
    _sleepTimer?.cancel();
    _sleepTimer = null;
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
    mediaKitLowPowerHwdec.value = false;
    streamPreviewEnabled.value = true;
    miniPlayerOnHome.value = false;
    adaptiveStreamQualityCeiling.value = AdaptiveStreamQualityCeiling.auto;
    catchUpUrlPreset.value = CatchUpUrlPreset.off;
    catchUpCustomTemplate.value = '';
    xtreamSkipPanelXmltvEpg.value = false;
    _xtreamHiddenBySource = {};
    _m3uHiddenBySource = {};
    xtreamHideRevision.value++;
    final p = await SharedPreferences.getInstance();
    await p.remove('mina_settings_alarm_set');
    await p.remove('mina_settings_alarm_h');
    await p.remove('mina_settings_alarm_m');
    await p.remove('mina_settings_custom_bg_path');
    await p.remove(_kBg);
    await p.setString(_kLang, languageCode.value);
    await p.remove(_kXmltv);
    await p.setInt(_kBuffer, defaultLiveBufferSeconds);
    await p.remove(_kTheme);
    await p.remove(_kLayout);
    await p.remove(_kLayoutPhoneTvFix);
    await p.setBool(_kReduceBlur, true);
    await p.remove('mina_settings_low_performance_mode');
    await p.remove(_kLaunchOnBoot);
    await p.remove(_kLastLiveCat);
    await p.remove(_kLastLiveCh);
    await p.remove(_kLastFilmsCat);
    await p.remove(_kLastFilmsVod);
    await p.remove(_kLastSeriesCat);
    await p.remove(_kLastSeriesId);
    await p.remove(_kLastFavCat);
    await p.remove(_kLastFavSel);
    await p.setBool(_kPreferSoftwareDecoder, false);
    await p.setBool(_kUseMediaKit, false);
    await p.setBool(_kMediaKitLowPowerHwdec, false);
    await p.setBool(_kStreamPreview, true);
    
    // OSD otomatik gizlenme süresini varsayılana ayarla
    await p.setInt('mina_settings_tv_osd_auto_hide_duration', 30);
    await p.remove(_kUseVlcLegacy);
    await p.remove(_kMiniPlayerHome);
    await p.remove(_kSleepEnd);
    await p.remove(_kAdaptiveQualityCeiling);
    await p.remove(_kCatchUpPreset);
    await p.remove(_kCatchUpCustomTemplate);
    await p.remove(_kXtreamHidden);
    await p.remove(_kM3uHidden);
    await p.remove(_kXtreamSkipPanelXmltv);
    await p.setString(_kLayout, layoutMode.value.name);
    await p.setBool(_kLayoutPhoneTvFix, true);
  }
}
