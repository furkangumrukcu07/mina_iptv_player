import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/home_card_frame_style.dart';
import '../home/home_card_swipe_effect.dart';
import '../home/home_category_card_id.dart';
import '../i18n/app_locale.dart';
import '../layout/app_layout_mode.dart';
import 'mina_analytics_service.dart';
import '../theme/app_performance.dart';
import '../theme/glass_appearance.dart';
import '../platform/device_layout_defaults.dart';
import '../routes/app_routes.dart';
import '../player/adaptive_stream_quality_ceiling.dart';
import '../player/subtitle_appearance.dart';
import '../player/subtitle_font_family.dart';
import '../player/playback_orientation_manager.dart';
import '../player/iptv_playback_defaults.dart';
import '../player/playback_user_agent.dart';
import '../epg/catch_up_url_template.dart';
import '../epg/iptv_org_epg.dart';
import '../epg/global_epg_service.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';
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
  /// Son başarılı M3U XMLTV (varsayılan iptv-org dahil) ağ çekim zamanı.
  static const _kLastM3uEpgFetchMs = 'mina_last_m3u_epg_fetch_ms_v1';

  /// [GlobalEpgService] ülke rehberi SQLite indirmesi için son başarılı çekim (ms epoch).
  static const _kLastGlobalEpgFetchMs = 'mina_last_global_epg_fetch_ms_v1';
  static const _kBuffer = 'mina_settings_live_buffer_sec';

  /// Kayıt yoksa veya sıfırlamada kullanılan canlı yayın tamponu (saniye).
  /// Düşük gecikme için varsayılan 2 sn (IPTV canlı yayın standardı).
  static const defaultLiveBufferSeconds = 2;

  /// Eski varsayılan (3 sn) → yeni varsayılan (2 sn) tek seferlik geçiş için
  /// önceki varsayılan değer; yalnızca buna dokunmamış kullanıcılar düşürülür.
  static const _legacyDefaultLiveBufferSeconds = 3;
  static const _kBufferDefault2Migrated =
      'mina_settings_buffer_default2_migrated_v1';
  static const _kTheme = 'mina_settings_theme_label';
  static const _kLayout = 'mina_settings_layout_mode';

  static const _kReduceBlur = 'mina_settings_reduce_blur';
  static const _kLowEndDeviceMode = 'mina_settings_low_end_device_mode';
  static const _kLowEndSuggestDismissed =
      'mina_settings_low_end_suggest_dismissed';
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
  static const _kCloudAutoBackupDays = 'mina_settings_cloud_auto_backup_days';
  static const _kLastCloudBackup = 'mina_settings_last_cloud_backup_time';

  /// Google ile oturum açma teşvik popup'ı bir kez gösterildi mi? (Giriş
  /// yapmamış kullanıcıya ana ekranda yalnızca bir kerelik sunulur.)
  static const _kGoogleSignInPromptShown =
      'mina_settings_google_signin_prompt_shown_v1';

  /// Android: yazılım (Google OMX) video kod çözücü önceliği.
  static const _kPreferSoftwareDecoder =
      'mina_settings_prefer_software_decoder';

  /// Ayarlar > Oynatıcı > "Yayın Formatı". Canlı Xtream yayınları için taşıma
  /// biçimi tercihi. `auto` (varsayılan) yüklenen panelin URL'sindeki `output`
  /// ipucundan otomatik karar verir (`output=ts` → MPEG-TS; m3u8/yok → HLS).
  /// `hls` her zaman m3u8 manifest — kararlı, çoklu kalite (HD/FHD) menüsü
  /// mümkün. `ts` her zaman saf MPEG-TS — hızlı açılış, düşük gecikme. Hangi
  /// mod olursa olsun uyumsuz panelde oynatıcı otomatik diğer biçime düşer
  /// (mevcut ts↔m3u8 yedek zinciri).
  static const _kLiveStreamFormat = 'mina_settings_live_stream_format_v1';

  /// `auto` modunda yüklenen son panelden çözülen biçim (`hls`/`ts`); kalıcı.
  static const _kLiveStreamFormatAuto =
      'mina_settings_live_stream_format_auto_v1';

  /// [liveStreamFormat] için "Otomatik" değeri (varsayılan; URL'den karar verir).
  static const String liveStreamFormatAuto = 'auto';

  /// [liveStreamFormat] için "HLS / m3u8 (kararlı)" değeri.
  static const String liveStreamFormatHls = 'hls';

  /// [liveStreamFormat] için "MPEG-TS / .ts (hızlı)" değeri.
  static const String liveStreamFormatTs = 'ts';

  /// İkinci oynatıcı (media_kit / libmpv).
  static const _kUseMediaKit = 'mina_settings_use_media_kit';
  static const _kLiveUseMediaKit = 'mina_settings_live_use_media_kit';
  static const _kUseVlcLegacy = 'mina_settings_use_vlc';

  /// Kullanıcı video motorunu **bilinçli** olarak seçti mi? `false` iken
  /// Remote Config `varsayilan_video_motoru` varsayılanı uygulanır; kullanıcı
  /// Ayarlar'dan motoru değiştirince `true` olur ve uzaktan varsayılan artık
  /// onun seçimini ezmez.
  static const _kEngineUserChosen = 'mina_settings_engine_user_chosen_v1';

  // ---------------------------------------------------------------------------
  // Harici Oynatıcı: kullanıcı `Ayarlar > Oynatma > Harici Oynatıcı` ile
  // yüklü VLC, MX Player, Just Player vb. uygulamaya akışı yönlendirebilir.
  // Sentinel `__chooser__`: her oynatma öncesi sistem seçici diyaloğu çıksın.
  // ---------------------------------------------------------------------------
  static const _kExternalPlayerEnabled = 'mina_settings_external_player_enabled';
  static const _kExternalPlayerId = 'mina_settings_external_player_id';
  static const _kExternalPlayerLabel = 'mina_settings_external_player_label';

  /// MediaKit Android: `true` → `hwdec=mediacodec`, `false` → `mediacodec-copy`.
  static const _kMediaKitLowPowerHwdec =
      'mina_settings_media_kit_low_power_hwdec';

  /// Liste detayında canlı/film/dizi yayın önizlemesi (sessiz küçük oynatıcı).
  static const _kStreamPreview = 'mina_settings_stream_preview';
  static const _kIgnoreSsl = 'mina_settings_ignore_ssl';
  static const _kUpcomingMatches = 'mina_settings_upcoming_matches';
  static const _kMixedLiveTv = 'mina_settings_mixed_live_tv';
  static const _kAiRecommendations = 'mina_settings_ai_recommendations';

  /// Bir kerelik TV varsayılanları migration'ı. Bayrak yazılı değilse
  /// `ensureLoaded()` veya TV layout'una geçişte ana ekran şeritleri
  /// "AI önerileri + Sıradaki maçlar" varsayılanına zorlanır
  /// (TopRated / Mixed Live TV kapanır). Bayrak yazıldıktan sonra
  /// kullanıcının manuel seçimleri korunur.
  static const _kTvHomeStripsDefaultV1 =
      'mina_tv_home_strips_default_v1';

  /// Bir kerelik TV performans varsayılanı (V2): TV layout'unda ana ekranda
  /// «Günün Sözü» (haftalık marquee) ve «Mina AI Önerileri» şeritleri
  /// varsayılan olarak KAPALI gelir (eski TV box'larda decode/blur/animasyon
  /// yükünü azaltmak için). Bayrak yazıldıktan sonra kullanıcı bunları
  /// elle açabilir; mobil/tablet layout'unda hiçbir şey yapılmaz.
  static const _kTvHomeLightDefaultV2 =
      'mina_tv_home_light_default_v2';

  /// Bir kerelik TV varsayılanı (V3): TV layout'unda ana ekranda «Mina AI
  /// Önerileri» ve «Karışık Canlı TV» şeritleri varsayılan AÇIK gelir.
  /// Önceki V1/V2 bunları kapatıyordu; bu bayrak ile eski TV kullanıcılarında
  /// da bir kez açılır. Yazıldıktan sonra kullanıcının manuel seçimi korunur.
  /// Mobil/tablet layout'unda hiçbir şey yapılmaz.
  static const _kTvHomeRichDefaultV3 =
      'mina_tv_home_rich_default_v3';

  /// Bir kerelik TV varsayılan tema: eski TV varsayılanı «Flat Black» →
  /// «Amoled Black». Bayrak yazıldıktan sonra kullanıcının seçtiği tema korunur.
  static const _kTvAmoledThemeDefaultV1 =
      'mina_tv_amoled_theme_default_v1';

  /// Bir kerelik TV ana ekran kart düzeni migration'ı. Bayrak yoksa TV
  /// layout'unda kullanıcının kayıtlı kart sırasına `recommendedFilms`
  /// (Film & Dizi) kartı `series`'in arkasına eklenir, gizlenmiş ise
  /// gizli setten çıkarılır ve Film & Dizi modu `both`'a çekilir. Bayrak
  /// yazıldıktan sonra kullanıcı manuel düzenini koruyabilir.
  static const _kTvHomeFilmDiziCardMigratedV1 =
      'mina_tv_home_film_dizi_card_migrated_v1';

  /// Bir kerelik TV ana ekran düzeni V3. TV layout'unda:
  ///   * «Film & Dizi» (recommendedFilms) kartı gizlenir → Film & Dizi modu
  ///     `classic` (yalnız Filmler + Diziler kartları).
  ///   * Kart sırası: Canlı TV · Filmler · Diziler · Favoriler · EPG Mix.
  ///   * «Günün Sözü» şeridi varsayılan AÇIK.
  ///   * «IMDb puanına göre filmler» (TopRated) şeridi AÇIK.
  ///   * «Sıradaki Maçlar» şeridi AÇIK.
  /// Bayrak yazıldıktan sonra kullanıcı kendi düzenini koruyabilir.
  static const _kTvHomeLayoutV3 = 'mina_tv_home_layout_v3';
  static const _kDailyQuote = 'mina_settings_daily_quote';
  static const _kContinueWatching = 'mina_settings_continue_watching';
  static const _kMinaWrappedEnabled = 'mina_settings_mina_wrapped_enabled';
  static const _kStripLiveChannelPrefix = 'mina_settings_strip_live_ch_prefix';
  static const _kAdaptiveHaptics = 'mina_settings_adaptive_haptics';
  static const _kSmartStreamCutter = 'mina_settings_smart_stream_cutter';

  /// Ses yükseltici (Audio Boost): kullanıcı ses seviyesini sistem 100%'ünün
  /// üzerine, %200'e kadar çıkarabilir. Değer yüzde olarak tutulur (100..200);
  /// 100 = devre dışı, libmpv `volume` özelliğinin üst sınırı ile uygulanır.
  static const _kVolumeBoostMaxPercent =
      'mina_settings_volume_boost_max_percent_v1';

  /// Ana ekran kart boyut ölçeği — bütün kategori kartları + alt
  /// şeritler (Continue Watching / AI / Top Rated / Mixed Live …) için
  /// global lineer çarpan. Aralık 0.80 (küçük) – 1.20 (büyük), default 1.0.
  static const _kHomeCardScale = 'mina_settings_home_card_scale_v1';

  /// Film & Dizi modu — modern (sadece Film&Dizi kartı), klasik (ayrı
  /// Filmler + Diziler) veya her ikisi. Kurulum sihirbazından ve
  /// Ayarlar > Ana Ekran > Film & Dizi modu ekranından değiştirilebilir.
  static const _kHomeFilmDiziMode = 'mina_settings_home_film_dizi_mode_v1';

  /// Ana ekran portrait carousel'inde kategori kartlarını sağa/sola
  /// sürüklerken uygulanan geçiş efekti (default / blur / glassShimmer /
  /// frostedSwap / tintSweep / rubberBand). Ayarlar > Ana Ekran > Sürükleme
  /// Efekti ekranından seçilir.
  static const _kHomeCardSwipeEffect = 'mina_settings_home_card_swipe_effect';

  /// Ana ekran kartlarına uygulanacak dış çerçeve stili (classic /
  /// neonGlow / embossed / boldOutline). Ayarlar > Ana Ekran > Çerçeve
  /// Stili ekranından seçilir; kartların kendi cam dekorasyonu korunur.
  static const _kHomeCardFrameStyle = 'mina_settings_home_card_frame_style';

  /// «+18 / Erişkin içerik» ana ekran şeritlerinden gizlensin mi.
  static const _kHideAdultContent = 'mina_settings_hide_adult_content_v1';

  /// Smart Route — Akıllı CDN/Proxy yönlendirici. Arka planda IPTV
  /// sunucularının TCP RTT/jitter/packet-loss istatistiğini periyodik
  /// olarak ölçer; ağ dalgalanırsa kullanıcıyı bilgilendirir ve (alt
  /// toggle açıksa) canlı tamponu otomatik yukarı çeker.
  static const _kSmartRouteEnabled = 'mina_settings_smart_route_v1';

  /// Canlı TV (dikey mod): "Detay" sekmesini gizle; kanal seçilince doğrudan
  /// tam ekran yayın açılır. Yalnızca portre düzeni etkiler.
  static const _kHideLivePortraitDetailTab =
      'mina_settings_hide_live_portrait_detail_tab_v1';

  /// Smart Route auto-buffer: ağ kötüleşince `liveBufferSeconds` değerini
  /// dinamik yukarı çek. Kullanıcı bunu kapatırsa servis yalnız uyarı
  /// gösterir, tampona dokunmaz.
  static const _kSmartRouteAutoBuffer = 'mina_settings_smart_route_auto_buf_v1';

  /// Ana ekran kategori kartları sırası (live, films, …).
  static const _kHomeCategoryCardOrder =
      'mina_settings_home_category_card_order_v1';

  /// Kullanıcının ana ekran düzen editöründen manuel olarak gizlediği
  /// kategori kartları (storage key listesi). Boş set = hiçbir kart gizli
  /// değil (varsayılan). Bilinmeyen anahtarlar yüklemede atlanır.
  static const _kHomeCategoryCardHidden =
      'mina_settings_home_category_card_hidden_v1';

  /// Kullanıcının seçtiği User-Agent preset id'si
  /// ([kPlaybackUserAgentPresets]). [kPlaybackUserAgentCustomId] iken
  /// [_kPlaybackUserAgentCustomValue] kullanılır.
  static const _kPlaybackUserAgentId = 'mina_settings_playback_ua_id_v1';

  /// `Özel` preset seçildiğinde kullanıcının elle girdiği UA string'i.
  static const _kPlaybackUserAgentCustomValue =
      'mina_settings_playback_ua_custom_v1';

  /// Kaldırıldı: ana sayfa spor EPG şeridi. Sıfırlamada prefs’ten silinir.
  static const _kLegacySportEpgStrip = 'mina_settings_sport_epg_strip_enabled';

  /// Android telefon: ana ekrana dönünce Picture-in-Picture (sürüklenebilir mini pencere).
  static const _kMiniPlayerHome = 'mina_settings_mini_player_home';
  static const _kSleepEnd = 'mina_settings_sleep_timer_end_ms';

  /// Gömülü altyazı punto (pt): ExoPlayer/Better Player + isteğe bağlı MediaKit (mpv sub-scale).
  static const _kSubtitleFontPt = 'mina_settings_subtitle_font_pt';
  static const _kSubtitleFontFamily = 'mina_settings_subtitle_font_family';
  static const _kSubtitleColorArgb = 'mina_settings_subtitle_color_argb';
  static const _kSubtitleColorKey = 'mina_settings_subtitle_color_key';
  static const _kSubtitleOutline = 'mina_settings_subtitle_outline';
  static const _kAppFontFamily = 'mina_settings_app_font_family';
  static const _kVodSubtitleAutoEnabled =
      'mina_settings_vod_subtitle_auto_enabled';
  static const _kVodPreferredSubtitleToken =
      'mina_settings_vod_preferred_subtitle_token';

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

  /// Canlı kanal gizleme + kategori içi sıra (JSON, kaynak anahtarı başına).
  static const _kLiveChannelLayout = 'mina_live_channel_layout_v1';

  /// Kullanıcının sürükleyerek belirlediği kategori sıralaması (JSON, kaynak
  /// anahtarı başına). Xtream'de kimlik = kategori id'si (string), M3U'da
  /// kimlik = normalize edilmiş [group-title] adı.
  static const _kCategoryOrder = 'mina_category_order_v1';

  /// Son gösterilen Play Store değerlendirme uyarısı [PackageInfo.buildNumber] (Android).
  static const _kPlayRateLastPromptBuild = 'mina_play_rate_last_prompt_build';

  /// Kullanıcı Play Store’da değerlendirdi (CTA).
  static const _kPlayRateUserRated = 'mina_play_rate_user_rated_v1';

  /// Son gösterim günü (YYYYMMDD, yerel saat).
  static const _kPlayRateLastPromptDay = 'mina_play_rate_last_prompt_day_v1';

  /// Yerel EPG anlık görüntüsü bu kadar gün “taze” sayılır; sonra yeniden indirilir.
  static const _kEpgDiskCacheRefreshDays =
      'mina_settings_epg_disk_cache_refresh_days';

  static const _kEpgTimeFormat24h = 'mina_settings_epg_time_format_24h_v1';
  static const _kEpgTimezoneOffsetMinutes =
      'mina_settings_epg_timezone_offset_min_v1';

  /// Ayarlar > EPG > EPG Kapat anahtarı. Kapalıyken EpgService /
  /// GlobalEpgService ağ indirmeleri ve disk yüklemeleri yapılmaz; UI'da EPG
  /// satırları, "şu an yayında" rozetleri ve EPG zaman çizelgeleri gizlenir.
  /// EPG yeniden açıldığında planlı yenileme akışı normale döner.
  static const _kEpgEnabled = 'mina_settings_epg_enabled_v1';

  /// Varsayılan: 1 gün (kullanıcı 2–5 güne çıkarabilir).
  static const int defaultEpgDiskCacheRefreshDays = 1;

  /// Ayarlar > EPG > EPG Kaynağı tercihi (yalnızca Xtream kullanıcısı için).
  /// `auto` (varsayılan) Xtream + GitHub yedek birlikte; `xtreamOnly` yalnız
  /// Xtream sunucusu; `githubOnly` yalnız GitHub (iptv-org / globetvapp).
  static const _kXtreamEpgSourceMode = 'mina_settings_xtream_epg_source_mode_v1';

  static const _kSetupCompleted = 'mina_setup_wizard_completed_v1';

  /// Sihirbaz eklendikten sonra: daha önce listesi vardı, [readSource] ile tek sefer
  /// "tamamlandı" kabul; yeni taze kurulumlarda sihirbaz açılır.
  static const _kSetupLegacyPlaylistMigrated =
      'mina_setup_legacy_user_with_playlist_v1';

  final backgroundPlayback = false.obs;
  final languageCode = 'tr'.obs;
  final xmltvUrl = ''.obs;

  /// [effectiveM3uXmltvUrl] için son başarılı indirme (ms epoch).
  final lastM3uEpgFetchMs = 0.obs;

  /// iptv-org tabanlı global EPG SQLite güncellemesi için son başarılı indirme.
  final lastGlobalEpgFetchMs = 0.obs;
  final liveBufferSeconds = defaultLiveBufferSeconds.obs;
  final themeLabel = GlassThemeLabels.glassGri.obs;
  final layoutMode = AppLayoutMode.mobile.obs;

  /// Mobil oynatıcıda OSD «dikey» ile kullanıcı dikeye sabitledi; yatay OSD «yatay» ile kalkar.
  final mobilePlaybackPortraitUserLocked = false.obs;

  /// Mobil oynatıcıda OSD «yatay» ile kullanıcı yataya sabitledi; dikey OSD «dikey» ile kalkar.
  final mobilePlaybackLandscapeUserLocked = false.obs;

  /// [MediaQuery.textScaler] için; kök `GetMaterialApp` builder'da [ValueListenableBuilder] ile dinlenir.
  final layoutTextScaleNotifier = ValueNotifier<double>(1.2);

  /// Ağır blur ve animasyonları kısaltır / kapatır ([MediaQuery.disableAnimations]).
  final reduceBlur = true.obs;

  /// **Düşük Donanımlı Cihaz Modu** (2 GB RAM ve altı için). Açıkken:
  /// gerçek zamanlı blur/gölge kapanır, görsel decode boyutu ve image cache
  /// limiti düşürülür, liste önizlemesi (stream preview) devre dışı kalır,
  /// açılışta ön-yüklenen poster/logo sayısı azalır. [AppPerformance] bu
  /// bayrağı tüketir.
  final lowEndDeviceMode = false.obs;

  /// Düşük donanım modu önerisi (ana ekrandaki uyarı) kullanıcı tarafından
  /// kapatıldı mı? Kapatılınca bir daha gösterilmez; mod açılırsa zaten gerek
  /// kalmaz. [DevicePerformanceAdvisor] bu bayrağı tüketir.
  final lowEndSuggestionDismissed = false.obs;
  final launchOnBoot = false.obs;

  /// **Film/Dizi (VOD)** oynatma motoru tercihi: `true` → MediaKit (mpv),
  /// `false` → Better Player (Exo). Sorun olursa oynatıcı, yalnız o yayın için
  /// diğer motora otomatik geçer (fallback).
  final useMediaKit = false.obs;

  /// **Canlı Yayın** oynatma motoru tercihi: `true` → MediaKit (mpv),
  /// `false` → Better Player (Exo). Sorun olursa yalnız o yayın için diğer
  /// motora otomatik geçilir (fallback).
  final liveUseMediaKit = false.obs;

  /// Kullanıcı motoru bilinçli seçti mi? [ensureLoaded]'da yüklenir.
  bool _engineUserChosen = false;

  /// Harici Oynatıcı özelliği aktif mi? Açıksa Mina, oynatma sırasında akışı
  /// dahili oynatıcı yerine kullanıcının seçtiği uygulamada (VLC, MX Player
  /// vb.) açar.
  final externalPlayerEnabled = false.obs;

  /// Seçili harici oynatıcının kalıcı kimliği. Android'de paket adı, iOS'ta
  /// scheme tanımı. `__chooser__` sentinel değeri "her seferinde sistem
  /// seçicisini göster" anlamına gelir.
  final externalPlayerId = RxnString();

  /// UI'da göstermek için seçili harici oynatıcının kullanıcı dostu ismi
  /// ("VLC", "MX Player", …). [externalPlayerId] ile birlikte yazılır.
  final externalPlayerLabel = RxnString();

  /// Sihirbazı geçen kullanıcı / kurulum bitti; [ensureLoaded] prefs yükler.
  final isSetupCompleted = false.obs;

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
  final autoRefreshDays = 7.obs; // 0: Kapalı, 3: 3 Gün, 7: 1 Hafta (varsayılan)
  final lastRefreshTime = 0.obs; // epoch ms

  /// Google buluta otomatik yedekleme aralığı (gün). 0: Kapalı, 1: Günlük,
  /// 7: Haftalık. Yalnızca Google ile oturum açıldıysa anlamlı.
  final cloudAutoBackupDays = 0.obs;
  final lastCloudBackupTime = 0.obs; // epoch ms

  /// Google oturum açma teşvik popup'ı daha önce gösterildi mi?
  bool _googleSignInPromptShown = false;
  bool get googleSignInPromptShown => _googleSignInPromptShown;

  /// Popup'ı "gösterildi" olarak işaretler (bir daha çıkmaz).
  Future<void> markGoogleSignInPromptShown() async {
    if (_googleSignInPromptShown) return;
    _googleSignInPromptShown = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kGoogleSignInPromptShown, true);
  }

  /// Android ExoPlayer: `true` = yazılım kod çözücü önce (TS uyumluluğu); varsayılan donanım.
  final preferSoftwareVideoDecoder = false.obs;

  /// Canlı yayın taşıma biçimi modu: [liveStreamFormatAuto] (varsayılan),
  /// [liveStreamFormatHls] veya [liveStreamFormatTs]. Oynatma anında canlı
  /// Xtream URL'sine uygulanır; playlist yeniden yüklenmeden geçerli olur.
  final liveStreamFormat = liveStreamFormatAuto.obs;

  /// `auto` modunda yüklenen son panelden çözülen biçim (`hls`/`ts`).
  final liveStreamFormatAutoResolved = liveStreamFormatHls.obs;

  /// Geçerli (etkin) canlı biçim.
  ///
  /// Kullanıcı manuel HLS/TS seçtiyse ona dokunulmaz. `auto` (varsayılan) modda
  /// TÜM cihazlarda **HLS** ile başlanır (LG/webOS dahil çoğu panelde en kararlı
  /// ve OSD çoklu kalite menüsünü doldurur). HLS açılmazsa oynatıcı hata kurtarma
  /// zinciri (`_tryScheduleXtreamOutputFormatSwapRetry`) otomatik **MPEG-TS**'e
  /// düşer. Bu yüzden `auto` artık URL ipucundan TS'e çözülmez.
  String get effectiveLiveStreamFormat {
    final mode = liveStreamFormat.value;
    if (mode == liveStreamFormatTs) return liveStreamFormatTs;
    if (mode == liveStreamFormatHls) return liveStreamFormatHls;
    // auto → varsayılan HLS (açılmazsa oynatıcı TS'e fallback yapar).
    return liveStreamFormatHls;
  }

  /// Etkin biçimin MPEG-TS (hızlı) olup olmadığı (oynatıcı bunu okur).
  bool get prefersTsLiveStreamFormat =>
      effectiveLiveStreamFormat == liveStreamFormatTs;

  /// IPTV oynatıcı için seçilen User-Agent preset id'si.
  /// [kPlaybackUserAgentDefaultId] varsayılan; [kPlaybackUserAgentCustomId]
  /// olduğunda [playbackUserAgentCustomValue] kullanılır.
  final playbackUserAgentId = kPlaybackUserAgentDefaultId.obs;

  /// Kullanıcının "Özel" UA için elle girdiği string (boşsa varsayılana döner).
  final playbackUserAgentCustomValue = ''.obs;

  /// Aktif olarak istek başlıklarına eklenen User-Agent string'i.
  String get effectivePlaybackUserAgent {
    if (playbackUserAgentId.value == kPlaybackUserAgentCustomId) {
      final custom = playbackUserAgentCustomValue.value.trim();
      if (custom.isNotEmpty) return custom;
    }
    return playbackUserAgentPresetById(playbackUserAgentId.value).userAgent;
  }

  /// Canlı / film / dizi listelerinde küçük yayın önizlemesi; varsayılan açık ([ensureLoaded] `?? true`).
  final streamPreviewEnabled = true.obs;

  /// «SSL/TLS sertifika doğrulamasını yoksay» — IPTV'de meşhur seçenek.
  /// Geçersiz/self-signed sertifikalı panellerde playlist/EPG/poster indirme ve
  /// MediaKit oynatma istekleri açıkken sertifikayı doğrulamadan kabul eder.
  /// Varsayılan kapalı (güvenlik). Açıkken global [HttpOverrides] + mpv
  /// `tls-verify=no` uygulanır.
  final ignoreSslCertificate = false.obs;

  /// Ana ekranda «Sıradaki Maçlar» şeridi; varsayılan açık.
  final upcomingMatchesEnabled = true.obs;

  /// Ana ekranda «Karışık Canlı TV» şeridi; varsayılan açık.
  final mixedLiveTvEnabled = true.obs;

  /// Ana ekranda «Mina AI: Senin İçin Önerilenler» şeridi; varsayılan açık.
  /// Kullanıcı geçmiş izleme alışkanlıklarına göre kişiselleştirilmiş 10
  /// karma (canlı / film / dizi) öneri üretilir.
  final isAiRecommendationEnabled = true.obs;

  /// Ana ekranda haftanın gününe göre değişen «Günün Sözü» (haftalık kayan
  /// yazı) şeridi; varsayılan açık. Kapatıldığında ana ekrandaki şerit ve
  /// çevresindeki boşluk tamamen kaldırılır.
  final dailyQuoteEnabled = true.obs;

  /// Ana ekranda «İzlemeye Devam Et» şeridi; varsayılan açık. Yarıda kalmış
  /// film ve dizileri, en son izlenenden başlayarak gösterir.
  final continueWatchingEnabled = true.obs;

  /// **Mina Wrapped & İzleme Analitiği** master switch. Kapatıldığında:
  ///
  /// * Ayarlar → Ana Ekran Ayarları'ndaki *Mina Wrapped* tile'ı gizlenir.
  /// * [MinaAnalyticsService] tick toplamayı durdurur (mevcut veriler
  ///   korunur; tekrar açılınca toplama kaldığı yerden devam eder).
  ///
  /// **Varsayılan kapalı** — gizlilik dostu davranış: kullanıcı bilinçli
  /// olarak açana kadar hiçbir izleme verisi toplanmaz. Kurulum sihirbazının
  /// kişiselleştirme adımı bu switch'i ön plana çıkarır.
  final minaWrappedEnabled = false.obs;

  /// Ana ekran kart boyut ölçeği. 1.0 = standart; 0.80 → ~%20 küçük,
  /// 1.20 → ~%20 büyük. Hem üst kategori kartları (Canlı/Filmler/Diziler…)
  /// hem alt şeritler (Continue Watching / AI Recommendations / Top Rated
  /// / Mixed Live) bu değeri lineer çarpan olarak okur. Varsayılan değer
  /// [homeCardScaleDefault] (1.00) — yeni kurulumlar kartları tam %100
  /// boyutta gösterir; kullanıcı slider'ı küçültüp büyütebilir.
  final homeCardScale = homeCardScaleDefault.obs;

  /// Yeni kurulumlarda ve `resetToDefaults` sonrası kullanılan başlangıç
  /// değeri. Kullanıcı slider'ı küçültüp büyütebilir; eski kullanıcıların
  /// kaydedilmiş tercihi korunur (yalnızca yeni kullanıcılar / reset).
  static const double homeCardScaleDefault = 1.00;

  /// Slider için minimum/maksimum sınırlar.
  static const homeCardScaleMin = 0.80;
  static const homeCardScaleMax = 1.20;

  /// Ana ekran Film & Dizi modu. Varsayılan `both` — kullanıcı kurulum
  /// sihirbazında veya ayarlar üzerinden değiştirir.
  final homeFilmDiziMode = HomeFilmDiziMode.both.obs;

  /// Portrait carousel'de kategori kartları arasında sürüklerken uygulanan
  /// geçiş efekti. Varsayılan `rubberBand` (elastik snap-back + overshoot).
  /// Düşük performans modunda UI tarafı bu değeri görmezden gelip
  /// `defaultStack`'e düşebilir.
  final homeCardSwipeEffect = HomeCardSwipeEffect.rubberBand.obs;

  /// Ana ekran kartlarının dış çerçeve stili. Varsayılan `classic` —
  /// kartların mevcut cam görünümü hiç değişmez. Diğer 3 stil (neonGlow,
  /// embossed, boldOutline) `HomeCardFrame` wrapper'ı üzerinden kartların
  /// üzerine overlay olarak uygulanır; iç dekorasyon bozulmaz.
  final homeCardFrameStyle = HomeCardFrameStyle.classic.obs;

  /// Canlı TV listelerinde TR:/BR:/EN: vb. ülke öneklerini gizle.
  final stripLiveChannelCountryPrefix = false.obs;

  /// «+18 / Erişkin İçerik Gizle» — ana ekran şeritlerinde (Senin İçin
  /// Önerilenler, Karışık Canlı, İzlemeye Devam Et) +18 kategori veya
  /// öğe adı taşıyan içerikler gizlenir. Listelerin (Canlı / Filmler /
  /// Diziler) ana sayfada görünmesini engellemek için
  /// [PlaylistCategoryHide.liveChannelHiddenForHome] vb. helper'lar bu
  /// bayrağı okur.
  final hideAdultContentEnabled = false.obs;

  /// **Remote Config `inceleme_modu_aktif`** — mağaza inceleme modu. Sunucudan
  /// `true` gelirse +18 içerik, kullanıcının ayarından bağımsız olarak zorla
  /// gizlenir. Kalıcı değildir; her açılışta Remote Config'ten yenilenir.
  final reviewModeActive = false.obs;

  /// +18 içerik fiilen gizlensin mi? Kullanıcı ayarı **veya** uzaktan inceleme
  /// modu açıksa `true`. İçerik filtreleri bunu okur.
  bool get effectiveHideAdultContent =>
      hideAdultContentEnabled.value || reviewModeActive.value;

  /// Smart Route — Akıllı CDN / Proxy seçici özelliği aktif mi.
  /// Varsayılan açık (yurt dışı CDN'lerden Türkiye'ye akşam peering
  /// darboğazları sık görülüyor; arka plan ölçümü çok hafif).
  final smartRouteEnabled = true.obs;

  /// Canlı TV dikey modda "Detay" sekmesini gizle (kanal seçince direkt oynat).
  final hideLivePortraitDetailTab = false.obs;

  /// Smart Route auto-buffer alt anahtarı. Açıkken servis ağ kötüleşince
  /// canlı tamponu yukarı çeker; kapatılırsa yalnız toast bildirimi.
  final smartRouteAutoBufferEnabled = true.obs;

  /// Mobil mod: liste kaydırma ve seçimlerde hafif titreşim.
  final adaptiveHapticsEnabled = true.obs;

  /// Akıllı Jenerik Atlatıcı (Smart Stream Cutter): Xtream dizilerinde
  /// kullanıcının ilk bölümlerdeki manuel ileri sarma davranışını
  /// öğrenip sonraki bölümlerde otomatik "Jeneriği Atla" cam butonu
  /// gösterir. Varsayılan açık; kullanıcı isterse Oynatma Ayarları
  /// veya kurulum sihirbazından kapatabilir.
  final smartStreamCutterEnabled = true.obs;

  /// Ses yükseltici üst sınırı yüzde olarak (100..200). 100 = kapalı
  /// (sistem ses seviyesi normaldir). 125/150/175/200 → oynatıcı ek
  /// kazanç uygular (MediaKit/libmpv `volume` özelliği). BetterPlayer
  /// motoru aktifken yalnızca 100% mümkün — boost yok sayılır.
  static const List<int> volumeBoostMaxPercentOptions = [
    100,
    125,
    150,
    175,
    200,
  ];
  static const int defaultVolumeBoostMaxPercent = 100;
  final volumeBoostMaxPercent = defaultVolumeBoostMaxPercent.obs;

  static int normalizeVolumeBoostMaxPercent(int? raw) {
    if (raw == null) return defaultVolumeBoostMaxPercent;
    if (volumeBoostMaxPercentOptions.contains(raw)) return raw;
    var best = defaultVolumeBoostMaxPercent;
    var bestDiff = 1 << 30;
    for (final o in volumeBoostMaxPercentOptions) {
      final d = (raw - o).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = o;
      }
    }
    return best;
  }

  /// Ana ekran büyük kartların soldan sağa / kaydırma sırası.
  final homeCategoryCardOrder =
      List<HomeCategoryCardId>.from(HomeCategoryCardId.defaultOrder).obs;

  /// Kullanıcının düzen editöründen manuel olarak gizlediği ana ekran
  /// kategori kartları. Layout/FilmDiziMode tabanlı (otomatik) gizlemeden
  /// **bağımsız**: bu sette bulunan ID'ler hiçbir layout'ta görünmez.
  /// Editör ekranı bu kartları "soluk" gösterir, ana ekran ise tamamen
  /// listeden çıkarır. Boş set = varsayılan davranış.
  final homeCategoryCardHidden = <HomeCategoryCardId>{}.obs;

  /// [homeCategoryCardOrder] veya [homeCategoryCardHidden] değişince ana
  /// sayfa yeniden kurulsun.
  final homeCategoryCardOrderRevision = 0.obs;

  /// Oynatıcı OSD otomatik gizlenme süresi (TV/tablet kumanda + dikey el modu).
  static const String _kTvOsdAutoHideDuration =
      'mina_settings_tv_osd_auto_hide_duration';

  /// Varsayılan 7 sn; [tvOsdAutoHideSecondsOptions] ile sınırlı.
  static const int defaultTvOsdAutoHideSeconds = 7;

  static const List<int> tvOsdAutoHideSecondsOptions = [3, 5, 7, 10, 15, 20];

  static int normalizeTvOsdAutoHideSeconds(int? raw) {
    if (raw == null) return defaultTvOsdAutoHideSeconds;
    if (tvOsdAutoHideSecondsOptions.contains(raw)) return raw;
    var best = tvOsdAutoHideSecondsOptions.first;
    var bestDiff = 999;
    for (final o in tvOsdAutoHideSecondsOptions) {
      final d = (raw - o).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = o;
      }
    }
    return best;
  }

  final tvOsdAutoHideDuration = defaultTvOsdAutoHideSeconds.obs;

  /// Yatay (landscape) modda OSD kapsülünün arka plan saydamlığı (0–100).
  /// 100 → tam opak (varsayılan), 0 → tamamen şeffaf. Butonlar / ikonlar /
  /// metinler bu ayardan etkilenmez; sadece cam kapsülün arkası, kenarlığı
  /// ve gölgesi azalır.
  static const String _kOsdLandscapeBackgroundOpacity =
      'mina_settings_osd_landscape_bg_opacity';
  static const int defaultOsdLandscapeBackgroundOpacity = 100;
  final osdLandscapeBackgroundOpacity =
      defaultOsdLandscapeBackgroundOpacity.obs;

  /// Yatay (tam ekran) video izlerken sağ üstte gerçek saat + batarya yüzdesi
  /// gösteren cam durum çubuğu. Tam ekranda sistem saat/batarya gizlendiği için
  /// opsiyonel olarak sunulur; varsayılan kapalı.
  static const String _kLandscapeStatusBar =
      'mina_settings_landscape_status_bar';
  final landscapeStatusBarEnabled = false.obs;

  /// 0..100 aralığına kırp; yanlış değerleri varsayılana çevir.
  static int normalizeOsdBackgroundOpacity(int? raw) {
    if (raw == null) return defaultOsdLandscapeBackgroundOpacity;
    if (raw < 0) return 0;
    if (raw > 100) return 100;
    return raw;
  }

  /// Android: yayın sırasında ana ekrana geçince PiP (Better/Exo). MediaKit’te kullanılmaz.
  final miniPlayerOnHome = false.obs;

  /// Uyku zamanlayıcısı bitişi (epoch ms); null = kapalı.
  final sleepTimerEndMs = Rxn<int>();

  /// Altyazı yazı boyutu (Better Player, pt).
  final subtitleFontPt = 14.0.obs;
  final subtitleFontFamilyKey = kDefaultSubtitleFontFamilyKey.obs;
  final subtitleColorKey = kSubtitleColorOptions.first.key.obs;
  final subtitleOutlineEnabled = true.obs;
  final appFontFamilyKey = kDefaultAppFontFamilyKey.obs;
  /// Film/Dizi açıldığında altyazıyı otomatik aç. Varsayılan **kapalı** —
  /// kullanıcı OSD üzerinden manuel olarak seçer.
  final vodSubtitleAutoEnabled = false.obs;
  final vodPreferredSubtitleToken = ''.obs;

  /// Canlı / VOD HLS master’da en yüksek hangi varyantın seçileceği üst sınırı.
  final adaptiveStreamQualityCeiling = AdaptiveStreamQualityCeiling.auto.obs;

  /// Xtream: EPG’den catch-up URL’si için panel şablonu (kapalı / hazır / özel).
  final catchUpUrlPreset = CatchUpUrlPreset.off.obs;

  /// [CatchUpUrlPreset.custom] için tam şablon metni.
  final catchUpCustomTemplate = ''.obs;

  /// Gizlenen Xtream kategorileri güncellenince listeler yenilensin diye artırılır.
  final xtreamHideRevision = 0.obs;

  /// Canlı kanal düzeni kaydı; önbellek yeniden uygulansın diye.
  final playlistLayoutRevision = 0.obs;

  /// Tam EPG’nin yerel disk önbelleği kaç gün geçerli kalsın (1–5).
  final epgDiskCacheRefreshDays = defaultEpgDiskCacheRefreshDays.obs;

  /// `true` → 24 saat; `false` → 12 saat (AM/PM).
  final epgTimeFormat24h = true.obs;

  /// EPG gösterim ofseti (dakika, -12h … +14h).
  final epgTimezoneOffsetMinutes = 0.obs;

  /// Ayarlar > EPG > Anahtar — false ise tüm EPG iş akışları (yenileme,
  /// indirme, disk önbelleği) atlanır ve UI'lar EPG bilgisi olmadan render
  /// edilir.
  final epgEnabled = true.obs;

  /// Xtream kullanıcısı için EPG kaynak tercihi. UI bağı: Ayarlar > EPG > EPG Kaynağı.
  final xtreamEpgSourceMode = XtreamEpgSourceMode.auto.obs;

  Map<String, Map<String, List<int>>> _xtreamHiddenBySource = {};
  Map<String, Map<String, List<String>>> _m3uHiddenBySource = {};
  Map<String, Map<String, dynamic>> _liveChannelLayoutBySource = {};

  /// `sourceKey -> { 'live'|'vod'|'series' : [kimlik, ...] }`. Kimlik Xtream'de
  /// kategori id'si (string), M3U'da normalize ad.
  Map<String, Map<String, List<String>>> _categoryOrderBySource = {};

  // Hot-path allocation azaltma: hidden set'leri tekrar tekrar `Set.from(...)`
  // ile üretmek yerine cache'le. `xtreamHideRevision` değiştiğinde otomatik
  // invalidate edilir (bkz. getter'lar).
  int _hiddenSetsCachedRevision = -1;
  final Map<String, Set<int>> _xtreamHiddenLiveCache = <String, Set<int>>{};
  final Map<String, Set<int>> _xtreamHiddenVodCache = <String, Set<int>>{};
  final Map<String, Set<int>> _xtreamHiddenSeriesCache = <String, Set<int>>{};
  final Map<String, Set<String>> _m3uHiddenLiveCache = <String, Set<String>>{};
  final Map<String, Set<String>> _m3uHiddenVodCache = <String, Set<String>>{};
  final Map<String, Set<String>> _m3uHiddenSeriesCache = <String, Set<String>>{};

  void _ensureHiddenSetsCacheFresh() {
    final rev = xtreamHideRevision.value;
    if (_hiddenSetsCachedRevision == rev) return;
    _hiddenSetsCachedRevision = rev;
    _xtreamHiddenLiveCache.clear();
    _xtreamHiddenVodCache.clear();
    _xtreamHiddenSeriesCache.clear();
    _m3uHiddenLiveCache.clear();
    _m3uHiddenVodCache.clear();
    _m3uHiddenSeriesCache.clear();
  }

  /// Play Store puanlama diyaloğu bu derleme için zaten gösterildiyse [buildNumber] burada tutulur.
  int playStoreRateLastPromptBuild = 0;

  bool playStoreRateUserRated = false;

  /// Son gösterim [playStoreRateDayYmd] (YYYYMMDD).
  int playStoreRateLastPromptDay = 0;

  /// [setSubtitleFontPt] çağrılınca tetiklenir — oynatıcı anında güncellemesi (GetX [ever] yedeği).
  VoidCallback? onSubtitleFontPtApplied;

  Timer? _sleepTimer;

  /// Canlı / film / dizi liste detayında küçük önizleme (TV ve telefonda tercihe bağlı).
  /// Düşük Donanımlı Cihaz Modu açıkken ikinci bir decoder örneği RAM'i ikiye
  /// katladığı için önizleme tamamen kapatılır.
  bool get streamPreviewActive =>
      streamPreviewEnabled.value && !lowEndDeviceMode.value;

  bool _loaded = false;
  int _layoutCoercePostFrameTries = 0;

  /// TV kayıtlı ama ekran telefon genişliğinde: `mobile`e çek (başta views boş olabildiği için post-frame tekrar).
  Future<void> _coerceHandheldTvToMobileIfNeeded(SharedPreferences p) async {
    if (layoutMode.value != AppLayoutMode.tv) return;
    final dip = readShortestSideDips();
    if (dip <= 0) {
      if (_layoutCoercePostFrameTries < 6) {
        _layoutCoercePostFrameTries++;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_coerceHandheldTvToMobileIfNeeded(p));
        });
      }
      return;
    }
    if (dip >= kLayoutHandheldMaxShortestDip) return;
    final longDip = readLongestSideDips();
    // 1080p TV: kısa kenar ~540 dp; yine de geniş panel — mobil yapma
    if (longDip >= 900) return;
    layoutMode.value = AppLayoutMode.mobile;
    await p.setString(_kLayout, AppLayoutMode.mobile.name);
    await _applyLayoutMode(layoutMode.value);
  }

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
    // Xtream panel XMLTV atlama bayrağı kaldırıldı (yalnızca JSON EPG).
    if (p.containsKey('mina_settings_xtream_skip_panel_xmltv_epg')) {
      await p.remove('mina_settings_xtream_skip_panel_xmltv_epg');
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
    lastM3uEpgFetchMs.value = p.getInt(_kLastM3uEpgFetchMs) ?? 0;
    lastGlobalEpgFetchMs.value = p.getInt(_kLastGlobalEpgFetchMs) ?? 0;
    liveBufferSeconds.value = p.getInt(_kBuffer) ?? defaultLiveBufferSeconds;
    // Düşük gecikme varsayılanı 3→2 sn tek seferlik geçiş: yalnızca eski
    // varsayılanda (3) kalan veya hiç ayarlamamış kullanıcılar 2'ye düşürülür;
    // manuel farklı değer (ör. 1, 5, 10) seçenlerin tercihi korunur.
    if (!(p.getBool(_kBufferDefault2Migrated) ?? false)) {
      final stored = p.getInt(_kBuffer);
      if (stored == null || stored == _legacyDefaultLiveBufferSeconds) {
        liveBufferSeconds.value = defaultLiveBufferSeconds;
        await p.setInt(_kBuffer, defaultLiveBufferSeconds);
      }
      await p.setBool(_kBufferDefault2Migrated, true);
    }
    var epgCacheDays = p.getInt(_kEpgDiskCacheRefreshDays);
    if (epgCacheDays == null || epgCacheDays < 1 || epgCacheDays > 5) {
      epgCacheDays = defaultEpgDiskCacheRefreshDays;
      await p.setInt(_kEpgDiskCacheRefreshDays, epgCacheDays);
    }
    epgDiskCacheRefreshDays.value = epgCacheDays;
    epgTimeFormat24h.value = p.getBool(_kEpgTimeFormat24h) ?? true;
    epgTimezoneOffsetMinutes.value =
        (p.getInt(_kEpgTimezoneOffsetMinutes) ?? 0).clamp(-720, 840);
    epgEnabled.value = p.getBool(_kEpgEnabled) ?? true;
    xtreamEpgSourceMode.value =
        XtreamEpgSourceMode.fromStorageKey(p.getString(_kXtreamEpgSourceMode));
    final rawLayoutForTheme = p.getString(_kLayout);
    final savedTheme = p.getString(_kTheme);
    if (savedTheme == null || savedTheme.isEmpty) {
      final layoutForTheme = rawLayoutForTheme != null
          ? (AppLayoutMode.tryParseName(rawLayoutForTheme) ??
              await resolveDefaultLayoutMode())
          : await resolveDefaultLayoutMode();
      final initial = _defaultThemeLabelForLayout(layoutForTheme);
      themeLabel.value = initial;
      await p.setString(_kTheme, initial);
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
    lowEndDeviceMode.value = p.getBool(_kLowEndDeviceMode) ?? false;
    lowEndSuggestionDismissed.value =
        p.getBool(_kLowEndSuggestDismissed) ?? false;
    launchOnBoot.value = p.getBool(_kLaunchOnBoot) ?? false;

    final rawLayout = p.getString(_kLayout);
    if (rawLayout == null) {
      layoutMode.value = await resolveDefaultLayoutMode();
      await p.setString(_kLayout, layoutMode.value.name);
    } else {
      final parsed = AppLayoutMode.tryParseName(rawLayout);
      if (parsed != null) {
        layoutMode.value = parsed;
        _layoutCoercePostFrameTries = 0;
        await _coerceHandheldTvToMobileIfNeeded(p);
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
    if (p.containsKey(_kAutoRefresh)) {
      autoRefreshDays.value = p.getInt(_kAutoRefresh) ?? 7;
    } else {
      autoRefreshDays.value = 7;
      unawaited(p.setInt(_kAutoRefresh, 7));
    }
    lastRefreshTime.value = p.getInt(_kLastRefresh) ?? 0;

    final cloudDays = p.getInt(_kCloudAutoBackupDays) ?? 0;
    cloudAutoBackupDays.value =
        (cloudDays == 1 || cloudDays == 7) ? cloudDays : 0;
    lastCloudBackupTime.value = p.getInt(_kLastCloudBackup) ?? 0;
    _googleSignInPromptShown = p.getBool(_kGoogleSignInPromptShown) ?? false;

    preferSoftwareVideoDecoder.value =
        p.getBool(_kPreferSoftwareDecoder) ?? false;

    final fmt = p.getString(_kLiveStreamFormat);
    liveStreamFormat.value = (fmt == liveStreamFormatTs ||
            fmt == liveStreamFormatHls ||
            fmt == liveStreamFormatAuto)
        ? fmt!
        : liveStreamFormatAuto;
    final fmtAuto = p.getString(_kLiveStreamFormatAuto);
    liveStreamFormatAutoResolved.value =
        fmtAuto == liveStreamFormatTs ? liveStreamFormatTs : liveStreamFormatHls;

    // User-Agent tercihi — boşsa varsayılan preset.
    final uaId = p.getString(_kPlaybackUserAgentId);
    playbackUserAgentId.value =
        (uaId == null || uaId.isEmpty) ? kPlaybackUserAgentDefaultId : uaId;
    playbackUserAgentCustomValue.value =
        p.getString(_kPlaybackUserAgentCustomValue) ?? '';
    // `IptvPlaybackDefaults` static; circular import'tan kaçınmak için
    // override hook üzerinden senkronize edilir.
    IptvPlaybackDefaults.setOverrideUserAgent(effectivePlaybackUserAgent);

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
    _engineUserChosen = p.getBool(_kEngineUserChosen) ?? false;

    // Canlı yayın motoru: yeni anahtar yoksa eski tek-motor davranışına göre
    // varsayılan Better (false). Kullanıcı eski sürümde MediaKit seçtiyse de
    // canlı her zaman Better ile başladığı için canlı varsayılanı false bırak.
    final liveMk = p.getBool(_kLiveUseMediaKit);
    if (liveMk == null) {
      liveUseMediaKit.value = false;
      await p.setBool(_kLiveUseMediaKit, false);
    } else {
      liveUseMediaKit.value = liveMk;
    }

    externalPlayerEnabled.value =
        p.getBool(_kExternalPlayerEnabled) ?? false;
    externalPlayerId.value = p.getString(_kExternalPlayerId);
    externalPlayerLabel.value = p.getString(_kExternalPlayerLabel);

    tvOsdAutoHideDuration.value =
        normalizeTvOsdAutoHideSeconds(p.getInt(_kTvOsdAutoHideDuration));

    osdLandscapeBackgroundOpacity.value = normalizeOsdBackgroundOpacity(
      p.getInt(_kOsdLandscapeBackgroundOpacity),
    );
    landscapeStatusBarEnabled.value = p.getBool(_kLandscapeStatusBar) ?? false;

    isSetupCompleted.value = p.getBool(_kSetupCompleted) ?? false;

    mediaKitLowPowerHwdec.value = p.getBool(_kMediaKitLowPowerHwdec) ?? false;

    streamPreviewEnabled.value = p.getBool(_kStreamPreview) ?? true;
    ignoreSslCertificate.value = p.getBool(_kIgnoreSsl) ?? false;
    _applyHttpSslPolicy();
    upcomingMatchesEnabled.value = p.getBool(_kUpcomingMatches) ?? true;
    mixedLiveTvEnabled.value = p.getBool(_kMixedLiveTv) ?? true;
    final rawScale = p.getDouble(_kHomeCardScale) ?? homeCardScaleDefault;
    // 2.10.27 öncesinde varsayılan 0.95 idi; slider'a hiç dokunmadan eski
    // varsayılana takılı kalmış kullanıcıları yeni %100 varsayılanına taşı.
    // Kullanıcı manuel olarak farklı bir değer seçtiyse (0.94 veya tam 1.0
    // dahil) o değer korunur — yalnızca tam 0.95 eşiği migrate edilir.
    final migratedScale =
        (rawScale - 0.95).abs() < 0.001 ? homeCardScaleDefault : rawScale;
    homeCardScale.value =
        migratedScale.clamp(homeCardScaleMin, homeCardScaleMax).toDouble();
    if (migratedScale != rawScale) {
      // Sessizce yeni varsayılana yaz; sonraki açılışlarda da %100 olur.
      unawaited(p.setDouble(_kHomeCardScale, homeCardScaleDefault));
    }
    // Film & Dizi modu — storage'da değer yoksa **cihaz tipine göre**
    // varsayılan: mobil/tablet → `modern`, TV → `classic`. Kullanıcı manuel
    // değiştirirse seçim korunur (`setHomeFilmDiziMode` ile yazılır).
    final rawFilmDizi = p.getString(_kHomeFilmDiziMode);
    if (rawFilmDizi == null) {
      homeFilmDiziMode.value = _defaultHomeFilmDiziModeForLayout(
        layoutMode.value,
      );
    } else {
      homeFilmDiziMode.value = HomeFilmDiziMode.fromStorageKey(rawFilmDizi);
    }
    homeCardSwipeEffect.value =
        HomeCardSwipeEffect.fromStorageKey(p.getString(_kHomeCardSwipeEffect));
    homeCardFrameStyle.value =
        HomeCardFrameStyle.fromStorageKey(p.getString(_kHomeCardFrameStyle));
    isAiRecommendationEnabled.value =
        p.getBool(_kAiRecommendations) ?? true;
    dailyQuoteEnabled.value = p.getBool(_kDailyQuote) ?? true;
    continueWatchingEnabled.value = p.getBool(_kContinueWatching) ?? true;
    minaWrappedEnabled.value = p.getBool(_kMinaWrappedEnabled) ?? false;
    stripLiveChannelCountryPrefix.value =
        p.getBool(_kStripLiveChannelPrefix) ?? false;
    hideAdultContentEnabled.value = p.getBool(_kHideAdultContent) ?? false;
    smartRouteEnabled.value = p.getBool(_kSmartRouteEnabled) ?? true;
    hideLivePortraitDetailTab.value =
        p.getBool(_kHideLivePortraitDetailTab) ?? false;
    smartRouteAutoBufferEnabled.value =
        p.getBool(_kSmartRouteAutoBuffer) ?? true;
    var adaptiveHaptics = p.getBool(_kAdaptiveHaptics);
    if (adaptiveHaptics == null) {
      adaptiveHaptics = true;
      await p.setBool(_kAdaptiveHaptics, true);
    }
    adaptiveHapticsEnabled.value = adaptiveHaptics;
    smartStreamCutterEnabled.value =
        p.getBool(_kSmartStreamCutter) ?? true;
    volumeBoostMaxPercent.value = normalizeVolumeBoostMaxPercent(
      p.getInt(_kVolumeBoostMaxPercent),
    );

    homeCategoryCardOrder.assignAll(
      HomeCategoryCardId.normalizeOrder(p.getStringList(_kHomeCategoryCardOrder)),
    );

    final hiddenRaw = p.getStringList(_kHomeCategoryCardHidden);
    if (hiddenRaw != null && hiddenRaw.isNotEmpty) {
      final parsed = <HomeCategoryCardId>{};
      for (final key in hiddenRaw) {
        final id = HomeCategoryCardId.tryParseStorageKey(key);
        if (id != null) parsed.add(id);
      }
      homeCategoryCardHidden
        ..clear()
        ..addAll(parsed);
    } else {
      homeCategoryCardHidden.clear();
    }

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
    final subFamily = p.getString(_kSubtitleFontFamily)?.trim() ?? '';
    if (isValidSubtitleFontFamilyKey(subFamily)) {
      subtitleFontFamilyKey.value = subFamily;
    } else {
      subtitleFontFamilyKey.value = kDefaultSubtitleFontFamilyKey;
      await p.setString(_kSubtitleFontFamily, kDefaultSubtitleFontFamilyKey);
    }
    final colorKey = p.getString(_kSubtitleColorKey)?.trim() ?? '';
    if (isValidSubtitleColorKey(colorKey)) {
      subtitleColorKey.value = colorKey;
    }
    final argb = p.getInt(_kSubtitleColorArgb);
    if (argb != null) {
      subtitleColorKey.value = _nearestColorKey(colorFromArgb(argb));
    }
    subtitleOutlineEnabled.value = p.getBool(_kSubtitleOutline) ?? true;
    final appFont = p.getString(_kAppFontFamily)?.trim() ?? '';
    if (isValidAppFontFamilyKey(appFont)) {
      appFontFamilyKey.value = appFont;
    } else {
      appFontFamilyKey.value = kDefaultAppFontFamilyKey;
      await p.setString(_kAppFontFamily, kDefaultAppFontFamilyKey);
    }
    vodSubtitleAutoEnabled.value = p.getBool(_kVodSubtitleAutoEnabled) ?? false;
    vodPreferredSubtitleToken.value =
        p.getString(_kVodPreferredSubtitleToken)?.trim() ?? '';

    adaptiveStreamQualityCeiling.value =
        AdaptiveStreamQualityCeiling.fromStorage(
      p.getString(_kAdaptiveQualityCeiling),
    );

    catchUpUrlPreset.value =
        CatchUpUrlPreset.fromStorage(p.getString(_kCatchUpPreset));
    catchUpCustomTemplate.value = p.getString(_kCatchUpCustomTemplate) ?? '';

    _loadXtreamHiddenFromPrefs(p);
    _loadM3uHiddenFromPrefs(p);
    _loadLiveChannelLayoutFromPrefs(p);
    _loadCategoryOrderFromPrefs(p);

    playStoreRateLastPromptBuild = p.getInt(_kPlayRateLastPromptBuild) ?? 0;
    playStoreRateUserRated = p.getBool(_kPlayRateUserRated) ?? false;
    playStoreRateLastPromptDay = p.getInt(_kPlayRateLastPromptDay) ?? 0;

    // TV layout'unda yeni varsayılan: ana ekranda yalnızca AI Önerileri ve
    // Sıradaki Maçlar şeritleri görünür. Mevcut kullanıcılarda bir kerelik
    // bayrak ile zorla uygulanır; sonraki açılışlarda kullanıcı manuel
    // değişiklikleri korunur.
    await _applyTvHomeStripsDefaultsIfNeeded(p);

    // TV performans varsayılanı (V2): marquee + AI önerileri kapalı gelir.
    await _applyTvHomeLightDefaultsIfNeeded(p);

    // TV varsayılanı (V3): AI önerileri + karışık canlı TV açık gelir.
    await _applyTvHomeRichDefaultsIfNeeded(p);

    await _applyTvAmoledThemeDefaultIfNeeded(p);

    // TV ana ekran kart düzenine «Film & Dizi» kartı eklemesini bir kerelik
    // migration olarak uygula (zaten varsa veya gizliyse normalize edilir).
    await _applyTvHomeFilmDiziCardMigrationIfNeeded(p);

    // TV ana ekran düzeni V3 — Film & Dizi kartı gizli (classic), kart sırası
    // Canlı·Film·Dizi·Favoriler·EPG Mix, Günün Sözü + IMDb filmleri + Sıradaki
    // Maçlar açık. V1/V2 sonrası çalışır ve onların değerlerini geçersiz kılar.
    await _applyTvHomeLayoutV3IfNeeded(p);

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

  void _loadLiveChannelLayoutFromPrefs(SharedPreferences p) {
    _liveChannelLayoutBySource = {};
    final raw = p.getString(_kLiveChannelLayout);
    if (raw == null || raw.isEmpty) return;
    try {
      final dec = json.decode(raw);
      if (dec is! Map) return;
      dec.forEach((k, v) {
        if (k is! String || v is! Map) return;
        _liveChannelLayoutBySource[k] = Map<String, dynamic>.from(v);
      });
    } catch (_) {}
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
    _ensureHiddenSetsCacheFresh();
    final cached = _xtreamHiddenLiveCache[key];
    if (cached != null) return cached;
    final set = Set<int>.from(
        _xtreamHiddenBySource[key]?['live'] ?? const <int>[]);
    _xtreamHiddenLiveCache[key] = set;
    return set;
  }

  Set<int> xtreamHiddenVodIds(String key) {
    xtreamHideRevision.value;
    _ensureHiddenSetsCacheFresh();
    final cached = _xtreamHiddenVodCache[key];
    if (cached != null) return cached;
    final set = Set<int>.from(
        _xtreamHiddenBySource[key]?['vod'] ?? const <int>[]);
    _xtreamHiddenVodCache[key] = set;
    return set;
  }

  Set<int> xtreamHiddenSeriesIds(String key) {
    xtreamHideRevision.value;
    _ensureHiddenSetsCacheFresh();
    final cached = _xtreamHiddenSeriesCache[key];
    if (cached != null) return cached;
    final set = Set<int>.from(
        _xtreamHiddenBySource[key]?['series'] ?? const <int>[]);
    _xtreamHiddenSeriesCache[key] = set;
    return set;
  }

  Set<String> m3uHiddenLiveNames(String key) {
    xtreamHideRevision.value;
    _ensureHiddenSetsCacheFresh();
    final cached = _m3uHiddenLiveCache[key];
    if (cached != null) return cached;
    final set = Set<String>.from(
        _m3uHiddenBySource[key]?['live'] ?? const <String>[]);
    _m3uHiddenLiveCache[key] = set;
    return set;
  }

  Set<String> m3uHiddenVodNames(String key) {
    xtreamHideRevision.value;
    _ensureHiddenSetsCacheFresh();
    final cached = _m3uHiddenVodCache[key];
    if (cached != null) return cached;
    final set = Set<String>.from(
        _m3uHiddenBySource[key]?['vod'] ?? const <String>[]);
    _m3uHiddenVodCache[key] = set;
    return set;
  }

  Set<String> m3uHiddenSeriesNames(String key) {
    xtreamHideRevision.value;
    _ensureHiddenSetsCacheFresh();
    final cached = _m3uHiddenSeriesCache[key];
    if (cached != null) return cached;
    final set = Set<String>.from(
        _m3uHiddenBySource[key]?['series'] ?? const <String>[]);
    _m3uHiddenSeriesCache[key] = set;
    return set;
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

  void _loadCategoryOrderFromPrefs(SharedPreferences p) {
    _categoryOrderBySource = {};
    final raw = p.getString(_kCategoryOrder);
    if (raw == null || raw.isEmpty) return;
    try {
      final dec = json.decode(raw);
      if (dec is! Map) return;
      dec.forEach((k, v) {
        if (k is! String || v is! Map) return;
        final vm = Map<String, dynamic>.from(v);
        _categoryOrderBySource[k] = {
          'live': _orderListFromJson(vm['live']),
          'vod': _orderListFromJson(vm['vod']),
          'series': _orderListFromJson(vm['series']),
        };
      });
    } catch (_) {}
  }

  static List<String> _orderListFromJson(dynamic v) {
    if (v is! List) return [];
    return v
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Kullanıcının kaydettiği kategori sırası (kimlik listesi). Boşsa kaynak
  /// parse sırası kullanılır. `type`: `live` | `vod` | `series`.
  List<String> categoryOrder(String key, String type) {
    xtreamHideRevision.value;
    return List<String>.from(
      _categoryOrderBySource[key]?[type] ?? const <String>[],
    );
  }

  Future<void> saveCategoryOrder(
    String key, {
    required String type,
    required List<String> order,
  }) async {
    final existing = _categoryOrderBySource[key] ??
        <String, List<String>>{
          'live': <String>[],
          'vod': <String>[],
          'series': <String>[],
        };
    existing[type] = List<String>.from(order);
    _categoryOrderBySource[key] = existing;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCategoryOrder, json.encode(_categoryOrderBySource));
    xtreamHideRevision.value++;
  }

  /// [items] listesini kullanıcının kaydettiği [savedOrder] kimlik sırasına
  /// göre yeniden dizer. Kayıtlı sırada bulunanlar başa (o sırayla), kayıtta
  /// olmayan yeni öğeler orijinal sıralarını koruyarak sona eklenir.
  static List<T> applyCategoryOrder<T>(
    List<T> items,
    List<String> savedOrder,
    String Function(T) identity,
  ) {
    if (savedOrder.isEmpty || items.isEmpty) return items;
    final rank = <String, int>{};
    for (var i = 0; i < savedOrder.length; i++) {
      rank.putIfAbsent(savedOrder[i], () => i);
    }
    final indexed = <({int orig, T value})>[
      for (var i = 0; i < items.length; i++) (orig: i, value: items[i]),
    ];
    indexed.sort((a, b) {
      final ra = rank[identity(a.value)];
      final rb = rank[identity(b.value)];
      if (ra != null && rb != null) return ra.compareTo(rb);
      if (ra != null) return -1;
      if (rb != null) return 1;
      return a.orig.compareTo(b.orig);
    });
    return [for (final e in indexed) e.value];
  }

  Set<int> liveChannelHiddenIds(String key) {
    playlistLayoutRevision.value;
    return Set<int>.from(_intListFromJson(_liveChannelLayoutBySource[key]?['hidden']));
  }

  Map<int, List<int>> liveChannelOrderByCategory(String key) {
    playlistLayoutRevision.value;
    final o = _liveChannelLayoutBySource[key]?['order'];
    if (o is! Map) return {};
    final out = <int, List<int>>{};
    o.forEach((k, v) {
      final id = int.tryParse(k.toString());
      if (id == null) return;
      if (v is List) {
        out[id] = v
            .map((e) => int.tryParse(e.toString()))
            .whereType<int>()
            .toList();
      }
    });
    return out;
  }

  Future<void> saveLiveChannelLayout(
    String key, {
    required Set<int> hiddenIds,
    required Map<int, List<int>> orderByCategoryId,
  }) async {
    final orderJson = <String, dynamic>{};
    for (final e in orderByCategoryId.entries) {
      orderJson['${e.key}'] = List<int>.from(e.value);
    }
    _liveChannelLayoutBySource[key] = {
      'hidden': (hiddenIds.toList()..sort()),
      'order': orderJson,
    };
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _kLiveChannelLayout, json.encode(_liveChannelLayoutBySource));
    playlistLayoutRevision.value++;
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
        Get.until(
            (route) => route.settings.name == AppRoutes.home || route.isFirst);
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
    final end =
        DateTime.now().add(Duration(minutes: minutes)).millisecondsSinceEpoch;
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

  Color get subtitleFontColor =>
      subtitleColorOptionForKey(subtitleColorKey.value).color;

  String get subtitleFontPtLabel =>
      'settings.tile.subtitleOptions.sub'.trParams({
        'pt': subtitleFontPt.value.round().toString(),
      });

  String get subtitleFontFamilyLabel =>
      subtitleFontFamilyOptionForKey(subtitleFontFamilyKey.value).preview;

  String get subtitleOptionsSummary {
    final color = subtitleColorOptionForKey(subtitleColorKey.value).labelKey.tr;
    return 'settings.tile.subtitleOptions.summary'.trParams({
      'pt': subtitleFontPt.value.round().toString(),
      'color': color,
      'font': subtitleFontFamilyLabel,
    });
  }

  static String _nearestColorKey(Color c) {
    var best = kSubtitleColorOptions.first.key;
    var bestD = double.infinity;
    for (final o in kSubtitleColorOptions) {
      final d = _colorDistance(o.color, c);
      if (d < bestD) {
        bestD = d;
        best = o.key;
      }
    }
    return best;
  }

  static double _colorDistance(Color a, Color b) {
    final dr = a.r - b.r;
    final dg = a.g - b.g;
    final db = a.b - b.b;
    return dr * dr + dg * dg + db * db;
  }

  String get appFontFamilyLabel => appFontFamilyPreviewFor(appFontFamilyKey.value);

  Future<void> setSubtitleFontPt(double pt) async {
    final v = pt.clamp(10.0, 40.0);
    subtitleFontPt.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kSubtitleFontPt, v);
    onSubtitleFontPtApplied?.call();
  }

  Future<void> setSubtitleFontFamilyKey(String key) async {
    final next = isValidSubtitleFontFamilyKey(key)
        ? key
        : kDefaultSubtitleFontFamilyKey;
    subtitleFontFamilyKey.value = next;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSubtitleFontFamily, next);
    onSubtitleFontPtApplied?.call();
  }

  Future<void> setSubtitleColorKey(String key) async {
    final next =
        isValidSubtitleColorKey(key) ? key : kSubtitleColorOptions.first.key;
    subtitleColorKey.value = next;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSubtitleColorKey, next);
    await p.setInt(
      _kSubtitleColorArgb,
      colorToArgb(subtitleColorOptionForKey(next).color),
    );
    onSubtitleFontPtApplied?.call();
  }

  Future<void> setSubtitleOutlineEnabled(bool enabled) async {
    subtitleOutlineEnabled.value = enabled;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSubtitleOutline, enabled);
    onSubtitleFontPtApplied?.call();
  }

  Future<void> setAppFontFamilyKey(String key) async {
    final next = isValidAppFontFamilyKey(key) ? key : kDefaultAppFontFamilyKey;
    appFontFamilyKey.value = next;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAppFontFamily, next);
  }

  Future<void> setVodPreferredSubtitleToken(String? token) async {
    final normalized = (token ?? '').trim().toLowerCase();
    vodPreferredSubtitleToken.value = normalized;
    final p = await SharedPreferences.getInstance();
    if (normalized.isEmpty) {
      await p.remove(_kVodPreferredSubtitleToken);
    } else {
      await p.setString(_kVodPreferredSubtitleToken, normalized);
    }
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
    if (mobilePlaybackLandscapeUserLocked.value) {
      await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await applyMobilePlayerOrientationChrome(landscapePlayback: true);
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

  /// Oynatıcı kapanırken yön kilitlerini kaldır ve sistem chrome'unu sıfırla
  /// (yatay tam ekrandan çıkınca ana menüde siyah ekran / takılı yön kalmasın).
  Future<void> clearMobilePlaybackPortraitLockForLeavingPlayer() async {
    if (kIsWeb) return;
    if (layoutMode.value != AppLayoutMode.mobile &&
        layoutMode.value != AppLayoutMode.tablet) {
      return;
    }
    mobilePlaybackPortraitUserLocked.value = false;
    mobilePlaybackLandscapeUserLocked.value = false;
    if (layoutMode.value == AppLayoutMode.mobile) {
      await syncMobileHandheldChromeToCurrentOrientation();
    } else {
      await syncTabletHandheldChromeToCurrentOrientation();
    }
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
        'ja' => 'common.lang.ja'.tr,
        'es' => 'common.lang.es'.tr,
        'ko' => 'common.lang.ko'.tr,
        'he' => 'common.lang.he'.tr,
        'da' => 'common.lang.da'.tr,
        'sv' => 'common.lang.sv'.tr,
        'hi' => 'common.lang.hi'.tr,
        'th' => 'common.lang.th'.tr,
        'it' => 'common.lang.it'.tr,
        'pt' => 'common.lang.pt'.tr,
        'id' => 'common.lang.id'.tr,
        _ => 'common.lang.en'.tr,
      };

  String get layoutLabel => layoutMode.value.title;

  /// Özel XMLTV yoksa iptv-org varsayılan rozeti; varsa kısaltılmış URL.
  String get xmltvSubtitle {
    final u = xmltvUrl.value.trim();
    if (u.isEmpty) return 'settings.m3uEpg.defaultBadge'.tr;
    if (u.length <= 32) return u;
    return '${u.substring(0, 14)}…${u.substring(u.length - 14)}';
  }

  /// Boşsa iptv-org topluluk rehberi (`guide.xml`), aksi halde kullanıcının girdiği adres.
  String get effectiveM3uXmltvUrl {
    final c = xmltvUrl.value.trim();
    if (c.isNotEmpty) return c;
    return IptvOrgEpg.defaultWorldGuideUrl;
  }
  /// M3U XMLTV indirmesi için URL listesi: özel tek adres veya varsayılan iptv-org adayları.
  List<String> get m3uEpgFetchUrls {
    final explicit = xmltvUrl.value.trim();
    if (explicit.isNotEmpty) return [explicit];

    // Ülke tespiti yapılmışsa GitHub'daki ilgili ülke EPG'sini en başa ekle
    final detectedCountry = Get.isRegistered<GlobalEpgService>()
        ? Get.find<GlobalEpgService>().activeCountries.firstOrNull
        : null;

    return IptvOrgEpg.defaultGuideCandidates(languageCode: detectedCountry);
  }

  /// XMLTV ağ indirmesi: [epgDiskCacheRefreshDays] ile aynı pencere (varsayılan 1 gün).
  bool get isM3uEpgNetworkRefreshDue {
    final last = lastM3uEpgFetchMs.value;
    if (last <= 0) return true;
    final age = DateTime.now().millisecondsSinceEpoch - last;
    return age > epgDiskCacheTtlMs;
  }

  /// [GlobalEpgService] için ağ indirmesi; TTL [epgDiskCacheTtlMs]. Veri yoksa her zaman true.
  bool shouldRefreshGlobalEpgFromNetwork({required bool hasPersistedSqliteData}) {
    if (!hasPersistedSqliteData) return true;
    final last = lastGlobalEpgFetchMs.value;
    if (last <= 0) {
      // Eski kurulum: SQLite dolu ama zaman damgası yok — her açılışta yeniden indirme.
      return false;
    }
    final age = DateTime.now().millisecondsSinceEpoch - last;
    return age > epgDiskCacheTtlMs;
  }

  Future<void> markM3uEpgFetchedOk() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    lastM3uEpgFetchMs.value = now;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastM3uEpgFetchMs, now);
  }

  Future<void> markGlobalEpgFetchedOk() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    lastGlobalEpgFetchMs.value = now;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastGlobalEpgFetchMs, now);
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

  /// Yerel EPG anlık görüntüsü için maksimum önbellek yaşı (1–4 gün).
  int get epgDiskCacheTtlMs {
    final d = epgDiskCacheRefreshDays.value.clamp(1, 4);
    return Duration(days: d).inMilliseconds;
  }

  Future<void> setEpgDiskCacheRefreshDays(int days) async {
    final d = days.clamp(1, 5);
    epgDiskCacheRefreshDays.value = d;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kEpgDiskCacheRefreshDays, d);
  }

  Future<void> setXtreamEpgSourceMode(XtreamEpgSourceMode mode) async {
    if (xtreamEpgSourceMode.value == mode) return;
    xtreamEpgSourceMode.value = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kXtreamEpgSourceMode, mode.storageKey);
  }

  Future<void> setEpgTimeFormat24h(bool use24Hour) async {
    epgTimeFormat24h.value = use24Hour;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEpgTimeFormat24h, use24Hour);
  }

  Future<void> setEpgTimezoneOffsetMinutes(int minutes) async {
    final m = minutes.clamp(-720, 840);
    epgTimezoneOffsetMinutes.value = m;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kEpgTimezoneOffsetMinutes, m);
  }

  /// EPG'yi tamamen aç/kapat. Kapatıldığı anda mevcut [EpgService] /
  /// [GlobalEpgService] yenileme döngüleri sonraki çağrılarında durur; UI'da
  /// EPG bilgisi gösteren satırlar reactive olarak gizlenir.
  Future<void> setEpgEnabled(bool enabled) async {
    if (epgEnabled.value == enabled) return;
    epgEnabled.value = enabled;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEpgEnabled, enabled);
  }

  String get epgTimeFormatSubtitle =>
      epgTimeFormat24h.value
          ? 'settings.epg.timeFormat24'.tr
          : 'settings.epg.timeFormat12'.tr;

  String get epgTimezoneOffsetSubtitle {
    final m = epgTimezoneOffsetMinutes.value;
    if (m == 0) return 'settings.epg.offset.zero'.tr;
    final sign = m > 0 ? '+' : '';
    final h = m.abs() ~/ 60;
    final min = m.abs() % 60;
    if (min == 0) return 'UTC$sign$h';
    return 'UTC$sign${h}h ${min}m';
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
    // Layout TV'ye ilk geçişte ana ekran şerit varsayılanlarını uygula
    // (mobil/tablet → TV geçişinde de tek seferlik zorlama).
    await _applyTvHomeStripsDefaultsIfNeeded(p);
    await _applyTvHomeLightDefaultsIfNeeded(p);
    await _applyTvHomeRichDefaultsIfNeeded(p);
    await _applyTvAmoledThemeDefaultIfNeeded(p);
    await _applyTvHomeFilmDiziCardMigrationIfNeeded(p);
    await _applyTvHomeLayoutV3IfNeeded(p);
  }

  /// TV ana ekranı için **bir kerelik** varsayılan şerit kümesi:
  /// yalnızca AI Önerileri + Sıradaki Maçlar açık; Mixed Live TV
  /// kapalı. Bayrak yazıldıktan sonra çalışmaz; kullanıcı manuel değişiklik
  /// yaptıysa o değer korunur. Mobil/tablet layout'unda hiçbir şey yapmaz.
  Future<void> _applyTvHomeStripsDefaultsIfNeeded(
      SharedPreferences p) async {
    final already = p.getBool(_kTvHomeStripsDefaultV1) ?? false;
    if (already) return;
    if (layoutMode.value != AppLayoutMode.tv) return;
    isAiRecommendationEnabled.value = true;
    upcomingMatchesEnabled.value = true;
    mixedLiveTvEnabled.value = false;
    await p.setBool(_kAiRecommendations, true);
    await p.setBool(_kUpcomingMatches, true);
    await p.setBool(_kMixedLiveTv, false);
    await p.setBool(_kTvHomeStripsDefaultV1, true);
  }

  /// Yerleşim moduna göre ilk kurulum / fabrika sıfırı tema etiketi.
  static String _defaultThemeLabelForLayout(AppLayoutMode mode) {
    if (mode == AppLayoutMode.tv) return GlassThemeLabels.amoledBlack;
    return GlassThemeLabels.koyuCam;
  }

  /// TV: eski varsayılan «Flat Black» → «Amoled Black» (bir kerelik).
  Future<void> _applyTvAmoledThemeDefaultIfNeeded(SharedPreferences p) async {
    final already = p.getBool(_kTvAmoledThemeDefaultV1) ?? false;
    if (already) return;
    if (layoutMode.value != AppLayoutMode.tv) return;
    if (themeLabel.value == GlassThemeLabels.flatBlack) {
      themeLabel.value = GlassThemeLabels.amoledBlack;
      await p.setString(_kTheme, GlassThemeLabels.amoledBlack);
    }
    await p.setBool(_kTvAmoledThemeDefaultV1, true);
  }

  /// TV performans varsayılanı (**bir kerelik**, V2): TV layout'unda ana
  /// ekrandaki «Günün Sözü» (haftalık marquee) ve «Mina AI Önerileri»
  /// şeritlerini kapatır. Eski TV box'larda bu iki şerit ek decode / blur /
  /// animasyon yükü getiriyor; varsayılan kapalı gelir. Bayrak yazıldıktan
  /// sonra kullanıcı dilerse ayarlardan açabilir. Mobil/tablet'e dokunmaz.
  Future<void> _applyTvHomeLightDefaultsIfNeeded(SharedPreferences p) async {
    final already = p.getBool(_kTvHomeLightDefaultV2) ?? false;
    if (already) return;
    if (layoutMode.value != AppLayoutMode.tv) return;
    dailyQuoteEnabled.value = false;
    isAiRecommendationEnabled.value = false;
    await p.setBool(_kDailyQuote, false);
    await p.setBool(_kAiRecommendations, false);
    await p.setBool(_kTvHomeLightDefaultV2, true);
  }

  /// TV varsayılanı (**bir kerelik**, V3): TV layout'unda «Mina AI Önerileri»
  /// ve «Karışık Canlı TV» şeritlerini AÇIK yapar (V1/V2 bunları kapatmıştı).
  /// V2'den SONRA çalışmalı ki onun yazdığı kapalı değeri ezsin. Bayrak
  /// yazıldıktan sonra kullanıcının manuel seçimi korunur; mobil/tablet'e dokunmaz.
  Future<void> _applyTvHomeRichDefaultsIfNeeded(SharedPreferences p) async {
    final already = p.getBool(_kTvHomeRichDefaultV3) ?? false;
    if (already) return;
    if (layoutMode.value != AppLayoutMode.tv) return;
    isAiRecommendationEnabled.value = true;
    mixedLiveTvEnabled.value = true;
    await p.setBool(_kAiRecommendations, true);
    await p.setBool(_kMixedLiveTv, true);
    await p.setBool(_kTvHomeRichDefaultV3, true);
  }

  /// TV ana ekran kart düzenine bir kerelik «Film & Dizi» kartı ekleme
  /// migration'ı. Mobil/tablet'te dokunulmaz. TV'de:
  ///   * Kayıtlı sırada `recommendedFilms` yoksa, `series` kartının hemen
  ///     arkasına eklenir; series yoksa films arkasına; o da yoksa sona.
  ///   * Gizli setten (homeCategoryCardHidden) çıkarılır — daha önce TV'de
  ///     gizli olduğu için kullanıcılar onu manuel "gizli" işaretlemiş
  ///     olabilir; varsayılan açılışta görünür kalsın.
  ///   * Film & Dizi modu o anda `classic` ise `both`'a çevrilir; aksi
  ///     halde dokunulmaz (kullanıcı `modern` veya `both` seçtiyse zaten
  ///     recommendedFilms görünür).
  Future<void> _applyTvHomeFilmDiziCardMigrationIfNeeded(
      SharedPreferences p) async {
    final already = p.getBool(_kTvHomeFilmDiziCardMigratedV1) ?? false;
    if (already) return;
    if (layoutMode.value != AppLayoutMode.tv) {
      // Mobil/tablet'te bayrağı **yazma** — kullanıcı sonradan TV'ye geçerse
      // migration o zaman tetiklensin.
      return;
    }
    final order = homeCategoryCardOrder.toList();
    if (!order.contains(HomeCategoryCardId.recommendedFilms)) {
      var idx = order.indexOf(HomeCategoryCardId.series);
      if (idx < 0) idx = order.indexOf(HomeCategoryCardId.films);
      if (idx < 0) {
        order.add(HomeCategoryCardId.recommendedFilms);
      } else {
        order.insert(idx + 1, HomeCategoryCardId.recommendedFilms);
      }
      homeCategoryCardOrder
        ..clear()
        ..addAll(order);
      await p.setStringList(
        _kHomeCategoryCardOrder,
        order.map((e) => e.storageKey).toList(),
      );
    }
    if (homeCategoryCardHidden.contains(HomeCategoryCardId.recommendedFilms)) {
      homeCategoryCardHidden.remove(HomeCategoryCardId.recommendedFilms);
      await p.setStringList(
        _kHomeCategoryCardHidden,
        homeCategoryCardHidden.map((e) => e.storageKey).toList(),
      );
    }
    if (homeFilmDiziMode.value == HomeFilmDiziMode.classic) {
      homeFilmDiziMode.value = HomeFilmDiziMode.both;
      await p.setString(_kHomeFilmDiziMode, HomeFilmDiziMode.both.storageKey);
    }
    homeCategoryCardOrderRevision.value++;
    await p.setBool(_kTvHomeFilmDiziCardMigratedV1, true);
  }

  /// TV ana ekran düzeni V3 (bir kerelik). Yalnız TV layout'unda:
  ///   * Film & Dizi modu `classic` → «Film & Dizi» kartı gizli, Filmler +
  ///     Diziler kartları görünür.
  ///   * Kart sırası: Canlı TV · Filmler · Diziler · Favoriler · EPG Mix.
  ///   * «Günün Sözü» şeridi açık.
  ///   * «Sıradaki Maçlar» şeridi açık.
  /// V1/V2 migration'larından SONRA çalıştığından onların ters değerlerini
  /// (dailyQuote=false, mod=both) geçersiz kılar.
  Future<void> _applyTvHomeLayoutV3IfNeeded(SharedPreferences p) async {
    final already = p.getBool(_kTvHomeLayoutV3) ?? false;
    if (already) return;
    if (layoutMode.value != AppLayoutMode.tv) {
      // Mobil/tablet'te bayrağı yazma — kullanıcı sonradan TV'ye geçerse
      // migration o zaman tetiklensin.
      return;
    }

    // Film & Dizi kartını gizle (classic).
    homeFilmDiziMode.value = HomeFilmDiziMode.classic;
    await p.setString(_kHomeFilmDiziMode, HomeFilmDiziMode.classic.storageKey);

    // Kart sırası: Canlı · Film · Dizi · Favoriler · EPG Mix (+ gizli F&D sona).
    final order = HomeCategoryCardId.normalizeOrder(
      HomeCategoryCardId.tvDefaultOrder.map((e) => e.storageKey),
    );
    homeCategoryCardOrder
      ..clear()
      ..addAll(order);
    await p.setStringList(
      _kHomeCategoryCardOrder,
      order.map((e) => e.storageKey).toList(),
    );

    // «Film & Dizi» kartını gizli setten çıkar (classic zaten gizler; düzen
    // editöründe soluk görünmesin diye temizle).
    if (homeCategoryCardHidden.isNotEmpty) {
      homeCategoryCardHidden.clear();
      await p.setStringList(_kHomeCategoryCardHidden, const <String>[]);
    }

    // Şerit varsayılanları: Günün Sözü + Sıradaki Maçlar açık.
    dailyQuoteEnabled.value = true;
    upcomingMatchesEnabled.value = true;
    await p.setBool(_kDailyQuote, true);
    await p.setBool(_kUpcomingMatches, true);

    homeCategoryCardOrderRevision.value++;
    await p.setBool(_kTvHomeLayoutV3, true);
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

  /// Düşük Donanımlı Cihaz Modu'nu değiştirir. Image cache limiti anında
  /// uygulanır; blur/gölge/önizleme reaktif olarak ilgili widget'larda yeniden
  /// çizilir.
  Future<void> setLowEndDeviceMode(bool v) async {
    lowEndDeviceMode.value = v;
    AppPerformance.applyImageCacheLimits(v);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLowEndDeviceMode, v);
  }

  /// Ana ekrandaki «düşük donanım moduna geç» uyarısı kapatıldı olarak
  /// işaretlenir; bir daha gösterilmez.
  Future<void> setLowEndSuggestionDismissed(bool v) async {
    lowEndSuggestionDismissed.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLowEndSuggestDismissed, v);
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

  /// Google buluta otomatik yedekleme aralığı (0: kapalı, 1: günlük, 7: haftalık).
  Future<void> setCloudAutoBackupDays(int days) async {
    final v = (days == 1 || days == 7) ? days : 0;
    cloudAutoBackupDays.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kCloudAutoBackupDays, v);
  }

  Future<void> updateLastCloudBackupTime() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    lastCloudBackupTime.value = now;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLastCloudBackup, now);
  }

  /// Bulut verisi silindiğinde son yedek zamanını sıfırlar (artık bulutta
  /// yedek olmadığını yansıtır).
  Future<void> resetLastCloudBackupTime() async {
    lastCloudBackupTime.value = 0;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kLastCloudBackup);
  }

  /// Otomatik bulut yedeği zamanı geldi mi? (aralık açık + süre dolmuş)
  bool shouldAutoBackupCloud() {
    if (cloudAutoBackupDays.value <= 0) return false;
    if (lastCloudBackupTime.value <= 0) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastCloudBackupTime.value);
    final diff = DateTime.now().difference(last).inDays;
    return diff >= cloudAutoBackupDays.value;
  }

  Future<void> setStreamPreviewEnabled(bool v) async {
    streamPreviewEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kStreamPreview, v);
  }

  /// «SSL/TLS doğrulamasını yoksay» ayarını değiştirir. Dart tarafı global
  /// [HttpOverrides] anında uygulanır; MediaKit (mpv) `tls-verify` ise bir
  /// sonraki yayın açılışında [PlayerController.applyMediaKitLibmpvPlaybackOptions]
  /// içinde okunur.
  Future<void> setIgnoreSslCertificate(bool v) async {
    ignoreSslCertificate.value = v;
    _applyHttpSslPolicy();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kIgnoreSsl, v);
  }

  /// `ignoreSslCertificate` değerine göre global [HttpOverrides]'ı kurar veya
  /// kaldırır. Kapalıyken `null` atanarak Dart varsayılan (sertifika doğrulayan)
  /// davranışına dönülür.
  void _applyHttpSslPolicy() {
    HttpOverrides.global =
        ignoreSslCertificate.value ? _MinaTrustAllHttpOverrides() : null;
  }

  Future<void> setUpcomingMatchesEnabled(bool v) async {
    upcomingMatchesEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kUpcomingMatches, v);
  }

  Future<void> setMixedLiveTvEnabled(bool v) async {
    mixedLiveTvEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMixedLiveTv, v);
  }

  /// «Günün Sözü» (haftalık kayan yazı) görünürlüğünü ayarlar. UI tarafı
  /// `dailyQuoteEnabled.value` üzerinden reactive okur; kapatıldığında ana
  /// ekrandaki şerit ve çevresindeki dikey boşluk tamamen kaldırılır.
  Future<void> setDailyQuoteEnabled(bool v) async {
    dailyQuoteEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDailyQuote, v);
  }

  /// «İzlemeye Devam Et» şeridi görünürlüğünü ayarlar. UI tarafı
  /// `continueWatchingEnabled.value` üzerinden reactive okur; kapatıldığında
  /// ana ekrandaki şerit ve çevresindeki boşluk tamamen kaldırılır.
  Future<void> setContinueWatchingEnabled(bool v) async {
    continueWatchingEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kContinueWatching, v);
  }

  /// **Mina Wrapped & İzleme Analitiği** master switch. Kapatıldığında
  /// Ana Ekran Ayarları'ndaki tile gizlenir ve `MinaAnalyticsService`
  /// tick toplamayı durdurur. Mevcut veriler **silinmez**; kullanıcı
  /// dilerse içeriden ayrıca "verileri sıfırla" tuşunu kullanabilir.
  Future<void> setMinaWrappedEnabled(bool v) async {
    minaWrappedEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMinaWrappedEnabled, v);
    // Servis kayıtlıysa collection enabled bayrağını da hizala — toplama
    // anlık olarak durur/başlar.
    try {
      if (Get.isRegistered<MinaAnalyticsService>()) {
        await Get.find<MinaAnalyticsService>().setEnabled(v);
      }
    } catch (_) {}
  }

  /// Ana ekran kart boyut ölçeğini yazar. UI tarafı `homeCardScale.value`
  /// üzerinden reactive okur; ek bir cache invalidation gerekmez (boyut
  /// LayoutBuilder + Obx üzerinden yeniden hesaplanır).
  Future<void> setHomeCardScale(double v) async {
    final clamped = v.clamp(homeCardScaleMin, homeCardScaleMax).toDouble();
    if ((homeCardScale.value - clamped).abs() < 0.005) return;
    homeCardScale.value = clamped;
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kHomeCardScale, clamped);
  }

  /// Film & Dizi modunu değiştirir; ana ekran kart sırası otomatik filtrelenir
  /// ([homeCategoryCardOrderRevision] arttırılmaz çünkü order'ın kendisi
  /// değişmiyor — sadece görünürlük). `home_view.dart` `Obx` üzerinden bu
  /// `Rx` değerini okuyarak yeniden render eder.
  Future<void> setHomeFilmDiziMode(HomeFilmDiziMode mode) async {
    if (homeFilmDiziMode.value == mode) return;
    homeFilmDiziMode.value = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHomeFilmDiziMode, mode.storageKey);
  }

  /// **Cihaz tipine göre Film & Dizi modu varsayılanı.**
  /// * Mobil + Tablet → `modern` (tek "Film & Dizi" kartı — Netflix tarzı).
  /// * TV → `classic` (ayrı "Filmler" ve "Diziler" kartları — uzaktan
  ///   kumanda ile gezinmesi kolay).
  /// `both` artık varsayılan değildir; sadece kullanıcı manuel seçerse
  /// görünür kalır.
  static HomeFilmDiziMode _defaultHomeFilmDiziModeForLayout(
    AppLayoutMode mode,
  ) {
    // TV: «Film & Dizi» kartı gizli → classic (yalnız Filmler + Diziler).
    // Mobil/tablet: modern (tek Film & Dizi kartı).
    return mode == AppLayoutMode.tv
        ? HomeFilmDiziMode.classic
        : HomeFilmDiziMode.modern;
  }

  /// Portrait carousel sürükleme efektini değiştirir. UI tarafı
  /// `homeCardSwipeEffect.value` üzerinden reactive okur; PageView yeniden
  /// build'lemeden anında geçiş efekti değişir.
  Future<void> setHomeCardSwipeEffect(HomeCardSwipeEffect effect) async {
    if (homeCardSwipeEffect.value == effect) return;
    homeCardSwipeEffect.value = effect;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHomeCardSwipeEffect, effect.storageKey);
  }

  /// Ana ekran kart çerçeve stilini değiştirir. UI tarafı
  /// `homeCardFrameStyle.value` üzerinden reactive okur; bütün kart
  /// gruplarına (kategori kartları, Mina AI, yüksek
  /// puanlı filmler) anında uygulanır.
  Future<void> setHomeCardFrameStyle(HomeCardFrameStyle style) async {
    if (homeCardFrameStyle.value == style) return;
    homeCardFrameStyle.value = style;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kHomeCardFrameStyle, style.storageKey);
  }

  Future<void> setAiRecommendationEnabled(bool v) async {
    isAiRecommendationEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAiRecommendations, v);
  }

  Future<void> setStripLiveChannelCountryPrefix(bool v) async {
    stripLiveChannelCountryPrefix.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kStripLiveChannelPrefix, v);
  }

  Future<void> setAdaptiveHapticsEnabled(bool v) async {
    adaptiveHapticsEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAdaptiveHaptics, v);
  }

  Future<void> setSmartStreamCutterEnabled(bool v) async {
    smartStreamCutterEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSmartStreamCutter, v);
  }

  /// Ses yükseltici üst sınırını yazar. Yalnızca [volumeBoostMaxPercentOptions]
  /// içindeki değerler kabul edilir; başka bir değer en yakına çekilir.
  Future<void> setVolumeBoostMaxPercent(int raw) async {
    final v = normalizeVolumeBoostMaxPercent(raw);
    if (volumeBoostMaxPercent.value == v) return;
    volumeBoostMaxPercent.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kVolumeBoostMaxPercent, v);
  }

  /// «+18 içerikleri gizle» bayrağını yazar ve ana ekran şeritlerinin
  /// yeniden hesaplaması için gizleme revizyonunu artırır. Mixed live
  /// strip ve diğer reactive katmanlar [xtreamHideRevision] üzerinden
  /// bu değişimi yakalar.
  Future<void> setHideAdultContentEnabled(bool v) async {
    if (hideAdultContentEnabled.value == v) return;
    hideAdultContentEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kHideAdultContent, v);
    xtreamHideRevision.value += 1;
  }

  /// Smart Route — Akıllı CDN / Proxy seçici özelliğini açar/kapatır.
  /// Kapatıldığında [NetworkQualityMonitorService] döngüsünü sonlandırır
  /// ve daha önce kendi uyguladığı auto-buffer override'ını geri alır.
  Future<void> setSmartRouteEnabled(bool v) async {
    if (smartRouteEnabled.value == v) return;
    smartRouteEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSmartRouteEnabled, v);
  }

  Future<void> setHideLivePortraitDetailTab(bool v) async {
    if (hideLivePortraitDetailTab.value == v) return;
    hideLivePortraitDetailTab.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kHideLivePortraitDetailTab, v);
  }

  /// Smart Route auto-buffer alt toggle. Kapatılırsa servis bağlantı
  /// dalgalanmasını yine raporlar ama tampona dokunmaz.
  Future<void> setSmartRouteAutoBufferEnabled(bool v) async {
    if (smartRouteAutoBufferEnabled.value == v) return;
    smartRouteAutoBufferEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSmartRouteAutoBuffer, v);
  }

  Future<void> setHomeCategoryCardOrder(List<HomeCategoryCardId> order) async {
    final normalized =
        HomeCategoryCardId.normalizeOrder(order.map((e) => e.storageKey));
    homeCategoryCardOrder.assignAll(normalized);
    homeCategoryCardOrderRevision.value++;
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _kHomeCategoryCardOrder,
      normalized.map((e) => e.storageKey).toList(),
    );
  }

  /// Kullanıcının ana ekran düzen editöründen manuel olarak gizlemek
  /// istediği kart ID'lerini yazar. Set yeni kopya olarak persist edilir;
  /// boş set = hiçbir kart manuel gizli değil. Revizyon arttırılarak ana
  /// ekran [HomeView] yeniden kurulur.
  Future<void> setHomeCategoryCardHidden(
    Set<HomeCategoryCardId> hidden,
  ) async {
    homeCategoryCardHidden
      ..clear()
      ..addAll(hidden);
    homeCategoryCardOrderRevision.value++;
    final p = await SharedPreferences.getInstance();
    if (hidden.isEmpty) {
      await p.remove(_kHomeCategoryCardHidden);
    } else {
      await p.setStringList(
        _kHomeCategoryCardHidden,
        hidden.map((e) => e.storageKey).toList(),
      );
    }
  }

  /// Play Store değerlendirme diyaloğu gösterildikten sonra çağrılır (aynı sürümde tekrar gösterme).
  Future<void> setPlayStoreRatePromptShownForBuild(int build) async {
    if (build <= playStoreRateLastPromptBuild) return;
    playStoreRateLastPromptBuild = build;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kPlayRateLastPromptBuild, build);
  }

  static int playStoreRateDayYmd([DateTime? when]) {
    final d = when ?? DateTime.now();
    return d.year * 10000 + d.month * 100 + d.day;
  }

  /// Play Store’dan yükleyen, henüz puanlamayan kullanıcıya günde en fazla bir kez.
  bool shouldShowPlayStoreRatePrompt() {
    if (playStoreRateUserRated) return false;
    return playStoreRateLastPromptDay < playStoreRateDayYmd();
  }

  Future<void> setPlayStoreRatePromptShownToday() async {
    final day = playStoreRateDayYmd();
    if (playStoreRateLastPromptDay >= day) return;
    playStoreRateLastPromptDay = day;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kPlayRateLastPromptDay, day);
  }

  Future<void> setPlayStoreRateUserRated() async {
    if (playStoreRateUserRated) return;
    playStoreRateUserRated = true;
    playStoreRateLastPromptDay = playStoreRateDayYmd();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPlayRateUserRated, true);
    await p.setInt(_kPlayRateLastPromptDay, playStoreRateLastPromptDay);
  }

  Future<void> setPreferSoftwareVideoDecoder(bool v) async {
    preferSoftwareVideoDecoder.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPreferSoftwareDecoder, v);
  }

  /// Canlı yayın biçimi modunu ayarlar ([liveStreamFormatAuto] /
  /// [liveStreamFormatHls] / [liveStreamFormatTs]). Bilinmeyen değer Otomatik'e
  /// (varsayılan) düşer.
  Future<void> setLiveStreamFormat(String value) async {
    final next = (value == liveStreamFormatTs ||
            value == liveStreamFormatHls ||
            value == liveStreamFormatAuto)
        ? value
        : liveStreamFormatAuto;
    if (liveStreamFormat.value == next) return;
    liveStreamFormat.value = next;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLiveStreamFormat, next);
  }

  /// `auto` modu için: yüklenen panelin URL'sindeki `output` ipucundan çözülen
  /// biçimi ([liveStreamFormatHls]/[liveStreamFormatTs]) kaydeder. Kullanıcı
  /// modu manuel (`hls`/`ts`) seçtiyse etkin değeri değiştirmez ama bir sonraki
  /// "Otomatik"e dönüşte kullanılmak üzere yine de saklanır.
  Future<void> applyAutoDetectedLiveStreamFormat(String hint) async {
    final resolved =
        hint == liveStreamFormatTs ? liveStreamFormatTs : liveStreamFormatHls;
    if (liveStreamFormatAutoResolved.value == resolved) return;
    liveStreamFormatAutoResolved.value = resolved;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLiveStreamFormatAuto, resolved);
  }

  /// User-Agent preseti seçer. [id] geçerli bir preset id'si veya
  /// [kPlaybackUserAgentCustomId] olmalıdır; bilinmeyen değer varsayılana
  /// düşer.
  Future<void> setPlaybackUserAgentPreset(String id) async {
    final normalized = id.trim();
    final isCustom = normalized == kPlaybackUserAgentCustomId;
    final isKnown =
        kPlaybackUserAgentPresets.any((p) => p.id == normalized);
    final next = (isCustom || isKnown) ? normalized : kPlaybackUserAgentDefaultId;
    playbackUserAgentId.value = next;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPlaybackUserAgentId, next);
    IptvPlaybackDefaults.setOverrideUserAgent(effectivePlaybackUserAgent);
  }

  /// `Özel` UA için kullanıcı string'ini kaydeder ve presetı `custom` yapar.
  Future<void> setPlaybackUserAgentCustomValue(String value) async {
    final t = value.trim();
    playbackUserAgentCustomValue.value = t;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPlaybackUserAgentCustomValue, t);
    if (t.isNotEmpty) {
      playbackUserAgentId.value = kPlaybackUserAgentCustomId;
      await p.setString(_kPlaybackUserAgentId, kPlaybackUserAgentCustomId);
    }
    IptvPlaybackDefaults.setOverrideUserAgent(effectivePlaybackUserAgent);
  }

  /// Film/Dizi (VOD) motoru tercihini ayarla.
  Future<void> setUseMediaKit(bool v) async {
    useMediaKit.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kUseMediaKit, v);
    await _markEngineUserChosen(p);
  }

  /// Canlı yayın motoru tercihini ayarla.
  Future<void> setLiveUseMediaKit(bool v) async {
    liveUseMediaKit.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLiveUseMediaKit, v);
    await _markEngineUserChosen(p);
  }

  Future<void> _markEngineUserChosen(SharedPreferences p) async {
    if (_engineUserChosen) return;
    _engineUserChosen = true;
    await p.setBool(_kEngineUserChosen, true);
  }

  /// **Remote Config `varsayilan_video_motoru`** uygula. Kullanıcı motoru
  /// bilinçli seçmediyse ([_engineUserChosen] false) uzaktan gelen varsayılanı
  /// hem VOD hem canlı için uygular. [preferMediaKit] `true` → MediaKit,
  /// `false` → Better Player (Exo). Kullanıcı daha önce seçim yaptıysa no-op.
  Future<void> applyRemoteDefaultVideoEngine(bool preferMediaKit) async {
    if (_engineUserChosen) return;
    if (useMediaKit.value == preferMediaKit &&
        liveUseMediaKit.value == preferMediaKit) {
      return;
    }
    useMediaKit.value = preferMediaKit;
    liveUseMediaKit.value = preferMediaKit;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kUseMediaKit, preferMediaKit);
    await p.setBool(_kLiveUseMediaKit, preferMediaKit);
    // Not: _kEngineUserChosen yazılmaz — bu uzaktan varsayılan, kullanıcı
    // seçimi değil.
  }

  /// Harici Oynatıcı'yı toggle eder. Kapatılırsa tercih kimliği saklı kalır
  /// (kullanıcı tekrar açtığında aynı oynatıcıya geri dönsün).
  Future<void> setExternalPlayerEnabled(bool v) async {
    externalPlayerEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kExternalPlayerEnabled, v);
  }

  /// Aktif harici oynatıcıyı yazar. [id] `null` veya boşsa kayıt silinir
  /// (sistem seçicisi davranışına dön). [label] kullanıcı arayüzünde
  /// gösterilen "VLC" / "MX Player" benzeri etiket.
  Future<void> setExternalPlayer({
    required String? id,
    required String? label,
  }) async {
    externalPlayerId.value = id;
    externalPlayerLabel.value = label;
    final p = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await p.remove(_kExternalPlayerId);
    } else {
      await p.setString(_kExternalPlayerId, id);
    }
    if (label == null || label.isEmpty) {
      await p.remove(_kExternalPlayerLabel);
    } else {
      await p.setString(_kExternalPlayerLabel, label);
    }
  }

  Future<void> setSetupCompleted(bool v) async {
    isSetupCompleted.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSetupCompleted, v);
  }

  /// Profil değişimi sonrası: TÜM reaktif ayarları diskten yeniden okur.
  /// `ensureLoaded` içindeki tek-seferlik migrasyonlar kendi bayraklarıyla
  /// korunduğundan `_loaded` sıfırlayıp tekrar çağırmak güvenlidir. `.tr`
  /// çevirisinin yenilenmesi için ayrıca [Get.updateLocale] tetiklenir;
  /// tema/font/layout kökteki `Obx` ile zaten reaktif yenilenir.
  Future<void> reloadAllFromPrefs() async {
    _loaded = false;
    await ensureLoaded();
    try {
      Get.updateLocale(materialLocaleFromLanguageCode(languageCode.value));
    } catch (_) {}
  }

  /// Bulut geri yüklemesi (AuthService) SharedPreferences'ı üzerine yazdıktan
  /// sonra çağrılır: bellekteki çekirdek görünür ayarları (dil, tema, font)
  /// diskten tekrar okuyup reaktif olarak günceller. Mevcut setter'lar
  /// kullanıldığı için locale/tema yan etkileri de doğru tetiklenir.
  Future<void> reloadCoreFromPrefs() async {
    final p = await SharedPreferences.getInstance();

    final lang = p.getString(_kLang);
    if (lang != null && lang.isNotEmpty && lang != languageCode.value) {
      await setLanguageCode(lang);
    }

    final theme = p.getString(_kTheme);
    if (theme != null && theme.isNotEmpty && theme != themeLabel.value) {
      await setThemeLabel(theme);
    }

    final font = p.getString(_kAppFontFamily)?.trim() ?? '';
    if (isValidAppFontFamilyKey(font) && font != appFontFamilyKey.value) {
      await setAppFontFamilyKey(font);
    }
  }

  /// Sihirbaz açıkken, geçerli cihazda yalnızca bir kez: kayıtlı liste varken
  /// sihirbazsız kullanıcıları tamamlanmış say (uygulama güncellemesi senaryosu).
  Future<void> maybeMarkLegacyUserCompleteIfHasPlaylist(
    PlaylistRepository repo,
  ) async {
    if (isSetupCompleted.value) return;
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_kSetupLegacyPlaylistMigrated) ?? false) return;
    final src = await repo.readSource();
    if (src == null) return;
    await p.setBool(_kSetupLegacyPlaylistMigrated, true);
    await setSetupCompleted(true);
  }

  Future<void> setMediaKitLowPowerHwdec(bool v) async {
    mediaKitLowPowerHwdec.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kMediaKitLowPowerHwdec, v);
  }

  /// MediaKit (Android) `hwdec` mpv değeri.
  String get mediaKitHwdecMpvValue =>
      mediaKitLowPowerHwdec.value ? 'mediacodec' : 'mediacodec-copy';

  /// OSD otomatik gizlenme süresini kaydet (5 / 7 / 10 / 15 / 20 sn).
  Future<void> setTvOsdAutoHideDuration(int seconds) async {
    final v = normalizeTvOsdAutoHideSeconds(seconds);
    tvOsdAutoHideDuration.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kTvOsdAutoHideDuration, v);
  }

  /// Yatay OSD arka plan saydamlığını kaydet (0–100, 100 = opak).
  Future<void> setOsdLandscapeBackgroundOpacity(int value) async {
    final v = normalizeOsdBackgroundOpacity(value);
    osdLandscapeBackgroundOpacity.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kOsdLandscapeBackgroundOpacity, v);
  }

  Future<void> setLandscapeStatusBarEnabled(bool v) async {
    landscapeStatusBarEnabled.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLandscapeStatusBar, v);
  }

  /// Amlogic / TCL–MediaTek–Realtek TV’lerde `mediacodec-copy` sık bozulur; `mediacodec`.
  String resolveMediaKitHwdecMpvValue({
    bool amlogicLike = false,
    bool playbackChallengedTv = false,
  }) {
    if (amlogicLike || playbackChallengedTv) return 'mediacodec';
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
    lastM3uEpgFetchMs.value = 0;
    lastGlobalEpgFetchMs.value = 0;
    liveBufferSeconds.value = defaultLiveBufferSeconds;
    smartRouteEnabled.value = true;
    hideLivePortraitDetailTab.value = false;
    smartRouteAutoBufferEnabled.value = true;
    epgDiskCacheRefreshDays.value = defaultEpgDiskCacheRefreshDays;
    epgEnabled.value = true;
    layoutMode.value = await resolveDefaultLayoutMode();
    themeLabel.value = layoutMode.value == AppLayoutMode.tv
        ? GlassThemeLabels.amoledBlack
        : GlassThemeLabels.varsayilan;
    _syncLayoutTextScale();
    await _applyLayoutMode(layoutMode.value);
    reduceBlur.value = true;
    lowEndDeviceMode.value = false;
    lowEndSuggestionDismissed.value = false;
    AppPerformance.applyImageCacheLimits(false);
    homeCardScale.value = homeCardScaleDefault;
    homeFilmDiziMode.value = _defaultHomeFilmDiziModeForLayout(layoutMode.value);
    homeCardSwipeEffect.value = HomeCardSwipeEffect.rubberBand;
    homeCardFrameStyle.value = HomeCardFrameStyle.classic;
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
    liveStreamFormat.value = liveStreamFormatAuto;
    liveStreamFormatAutoResolved.value = liveStreamFormatHls;
    useMediaKit.value = false;
    liveUseMediaKit.value = false;
    mediaKitLowPowerHwdec.value = false;
    streamPreviewEnabled.value = true;
    ignoreSslCertificate.value = false;
    _applyHttpSslPolicy();
    upcomingMatchesEnabled.value = true;
    mixedLiveTvEnabled.value = true;
    isAiRecommendationEnabled.value = true;
    dailyQuoteEnabled.value = true;
    stripLiveChannelCountryPrefix.value = false;
    hideAdultContentEnabled.value = false;
    adaptiveHapticsEnabled.value = true;
    smartStreamCutterEnabled.value = true;
    volumeBoostMaxPercent.value = defaultVolumeBoostMaxPercent;
    homeCategoryCardOrder.assignAll(
      layoutMode.value == AppLayoutMode.tv
          ? HomeCategoryCardId.tvDefaultOrder
          : HomeCategoryCardId.defaultOrder,
    );
    homeCategoryCardHidden.clear();
    homeCategoryCardOrderRevision.value++;
    tvOsdAutoHideDuration.value = defaultTvOsdAutoHideSeconds;
    miniPlayerOnHome.value = false;
    subtitleFontPt.value = 14.0;
    subtitleFontFamilyKey.value = kDefaultSubtitleFontFamilyKey;
    appFontFamilyKey.value = kDefaultAppFontFamilyKey;
    vodSubtitleAutoEnabled.value = false;
    vodPreferredSubtitleToken.value = '';
    adaptiveStreamQualityCeiling.value = AdaptiveStreamQualityCeiling.auto;
    catchUpUrlPreset.value = CatchUpUrlPreset.off;
    catchUpCustomTemplate.value = '';
    _xtreamHiddenBySource = {};
    _m3uHiddenBySource = {};
    _liveChannelLayoutBySource = {};
    _categoryOrderBySource = {};
    xtreamHideRevision.value++;
    playlistLayoutRevision.value++;
    playStoreRateLastPromptBuild = 0;
    playStoreRateUserRated = false;
    playStoreRateLastPromptDay = 0;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kPlayRateLastPromptBuild);
    await p.remove(_kPlayRateUserRated);
    await p.remove(_kPlayRateLastPromptDay);
    await p.remove('mina_settings_alarm_set');
    await p.remove('mina_settings_alarm_h');
    await p.remove('mina_settings_alarm_m');
    await p.remove('mina_settings_custom_bg_path');
    await p.remove(_kBg);
    await p.setString(_kLang, languageCode.value);
    await p.remove(_kXmltv);
    await p.remove(_kLastM3uEpgFetchMs);
    await p.remove(_kLastGlobalEpgFetchMs);
    await p.setInt(_kBuffer, defaultLiveBufferSeconds);
    await p.setInt(
      _kEpgDiskCacheRefreshDays,
      defaultEpgDiskCacheRefreshDays,
    );
    await p.remove(_kEpgEnabled);
    await p.remove(_kLayout);
    await p.setBool(_kReduceBlur, true);
    await p.remove('mina_settings_low_performance_mode');
    await p.setBool(_kLowEndDeviceMode, false);
    await p.remove(_kLowEndSuggestDismissed);
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
    await p.remove(_kLiveStreamFormat);
    await p.remove(_kLiveStreamFormatAuto);
    await p.remove(_kPlaybackUserAgentId);
    await p.remove(_kPlaybackUserAgentCustomValue);
    playbackUserAgentId.value = kPlaybackUserAgentDefaultId;
    playbackUserAgentCustomValue.value = '';
    IptvPlaybackDefaults.setOverrideUserAgent(effectivePlaybackUserAgent);
    await p.setBool(_kUseMediaKit, false);
    await p.setBool(_kLiveUseMediaKit, false);
    await p.setBool(_kMediaKitLowPowerHwdec, false);
    await p.setBool(_kStreamPreview, true);
    await p.setBool(_kIgnoreSsl, false);
    await p.setBool(_kUpcomingMatches, true);
    final tvLayout = layoutMode.value == AppLayoutMode.tv;
    // TV dâhil tüm layout'larda AI önerileri + karışık canlı TV açık gelir.
    await p.setBool(_kMixedLiveTv, true);
    await p.setBool(_kAiRecommendations, true);
    isAiRecommendationEnabled.value = true;
    mixedLiveTvEnabled.value = true;
    // TV layout için bayrağı **silmeden** koruruz; reset sırasında zaten
    // doğru varsayılanlar (yukarıdaki değerler) yazıldı. Mobil/tablet'e
    // tam reset durumunda kullanıcı sonradan TV'ye geçerse migration
    // tetiklenebilsin diye bayrağı kaldırıyoruz.
    if (tvLayout) {
      await p.setBool(_kTvHomeStripsDefaultV1, true);
      await p.setBool(_kTvHomeLightDefaultV2, true);
      await p.setBool(_kTvHomeRichDefaultV3, true);
      await p.setBool(_kTvHomeFilmDiziCardMigratedV1, true);
      await p.setBool(_kTvAmoledThemeDefaultV1, true);
      await p.setBool(_kTvHomeLayoutV3, true);
      // V3 düzeni: Film & Dizi kartı gizli (classic) + TV kart sırası.
      await p.setString(
        _kHomeFilmDiziMode,
        HomeFilmDiziMode.classic.storageKey,
      );
      await p.setStringList(
        _kHomeCategoryCardOrder,
        HomeCategoryCardId.tvDefaultOrder
            .map((e) => e.storageKey)
            .toList(),
      );
    } else {
      await p.remove(_kTvHomeStripsDefaultV1);
      await p.remove(_kTvHomeLightDefaultV2);
      await p.remove(_kTvHomeRichDefaultV3);
      await p.remove(_kTvHomeFilmDiziCardMigratedV1);
      await p.remove(_kTvAmoledThemeDefaultV1);
      await p.remove(_kTvHomeLayoutV3);
    }
    await p.setString(_kTheme, themeLabel.value);
    // Günün Sözü tüm cihazlarda (TV dâhil) varsayılan açık.
    await p.setBool(_kDailyQuote, true);
    dailyQuoteEnabled.value = true;
    await p.setBool(_kMinaWrappedEnabled, false);
    await p.remove(_kHomeCardSwipeEffect);
    await p.remove(_kHomeCardFrameStyle);
    await p.remove(_kLegacySportEpgStrip);

    await p.setInt(_kTvOsdAutoHideDuration, defaultTvOsdAutoHideSeconds);
    await p.remove(_kUseVlcLegacy);
    await p.remove(_kMiniPlayerHome);
    await p.remove(_kSleepEnd);
    await p.remove(_kSubtitleFontPt);
    await p.remove(_kSubtitleFontFamily);
    await p.remove(_kSubtitleColorArgb);
    await p.remove(_kSubtitleColorKey);
    await p.remove(_kSubtitleOutline);
    subtitleColorKey.value = kSubtitleColorOptions.first.key;
    subtitleOutlineEnabled.value = true;
    await p.remove(_kAppFontFamily);
    await p.setBool(_kVodSubtitleAutoEnabled, true);
    await p.remove(_kVodPreferredSubtitleToken);
    await p.remove(_kAdaptiveQualityCeiling);
    await p.remove(_kCatchUpPreset);
    await p.remove(_kCatchUpCustomTemplate);
    await p.remove(_kXtreamHidden);
    await p.remove(_kM3uHidden);
    await p.remove(_kLiveChannelLayout);
    await p.remove(_kCategoryOrder);
    await p.remove(_kHomeCategoryCardOrder);
    await p.remove(_kHomeCategoryCardHidden);
    await p.remove('mina_settings_xtream_skip_panel_xmltv_epg');
    await p.remove(_kXtreamEpgSourceMode);
    xtreamEpgSourceMode.value = XtreamEpgSourceMode.auto;
    await p.setString(_kLayout, layoutMode.value.name);
  }
}

/// Ayarlar > EPG > EPG Kaynağı seçeneği. Yalnızca Xtream kullanıcısı için anlamlı.
///
/// - [auto]: Xtream EPG ve GitHub (iptv-org / globetvapp) yedek birlikte. Xtream
///   panel boş veya yetersiz veri döndürdüğünde GitHub kanal isim eşleştirmesiyle
///   doldurur.
/// - [xtreamOnly]: yalnızca Xtream sunucusu. EPG vermiyorsa boş kalır.
/// - [githubOnly]: yalnızca GitHub yedek (Xtream EPG indirilmez).
enum XtreamEpgSourceMode {
  auto('auto'),
  xtreamOnly('xtream'),
  githubOnly('github');

  const XtreamEpgSourceMode(this.storageKey);

  final String storageKey;

  static XtreamEpgSourceMode fromStorageKey(String? raw) {
    if (raw == null) return XtreamEpgSourceMode.auto;
    for (final m in XtreamEpgSourceMode.values) {
      if (m.storageKey == raw) return m;
    }
    return XtreamEpgSourceMode.auto;
  }
}

/// «SSL/TLS doğrulamasını yoksay» açıkken kurulan global [HttpOverrides].
///
/// IPTV panellerinin büyük kısmı self-signed / süresi geçmiş / hostname'i
/// uyuşmayan sertifikalarla HTTPS sunar; varsayılan Dart [HttpClient] bu
/// sertifikaları reddedince playlist indirme, EPG, posterler ve MediaKit
/// dışı VOD/canlı istekleri "CERTIFICATE_VERIFY_FAILED" ile düşer. Bu override
/// yalnızca kullanıcı ayarı açtığında [HttpOverrides.global] olarak kurulur ve
/// tüm Dart ağ isteklerinde geçersiz sertifikalara izin verir.
class _MinaTrustAllHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}
