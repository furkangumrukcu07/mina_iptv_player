import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:get/get.dart' hide Response;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/player/audio_codec_playback_hint.dart';
import '../../core/player/better_player_iptv_config.dart';
import '../../core/player/media_kit_mpv_crispy_config.dart';
import '../../core/player/media_kit_mpv_low_power_display.dart';
import '../../core/player/media_kit_subtitle_font.dart';
import '../../core/player/subtitle_font_family.dart';
import '../../core/player/exo_native_track_option.dart';
import '../../core/player/vod_subtitle_discovery.dart';
import '../../core/player/iptv_playback_defaults.dart';
import '../../core/player/playback_engine_kind.dart';
import '../../core/player/video_player_engine.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/player/playback_orientation_manager.dart';
import '../../core/platform/android_playback_soc_hints.dart';
import '../../core/home/home_layout_style.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/showcase_in_app_pip_service.dart';
import '../../core/services/equalizer_service.dart';
import '../../core/services/external_player_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/live_hls_stream_profile_service.dart';
import '../../core/services/mina_analytics_service.dart';
import '../../core/services/mina_stream_cutter_service.dart';
import '../../core/home/recommended_films_catalog.dart';
import '../../core/home/series_name_grouping.dart';
import '../../core/services/movie_service.dart';
import '../../core/services/playback_progress_write_queue_service.dart';
import '../../core/utils/turkish_title_utils.dart';
import '../../domain/entities/movie_model.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/playlist_data_source.dart';
import '../../core/services/playlist_category_hide.dart';
import '../../core/services/system_volume_service.dart';
import '../../core/services/toast_service.dart';
import '../../core/services/network_reachability.dart';
import '../../core/services/watch_progress_service.dart';
import '../../services/user_history_service.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../domain/entities/playlist_source.dart';
import '../../data/remote/stalker_api.dart';
import '../../core/services/active_playlist_service.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../channels/channels_controller.dart';
import '../tv_shell/tv_shell_controller.dart';
import '../../core/tv/tv_shell_section.dart';
import 'player_route_args.dart';
import 'series_player_panel_data.dart';
import 'widgets/tv_better_player_controls.dart';
import 'widgets/vod_resume_dialog.dart';

part 'controllers/player_playback_controller.dart';
part 'controllers/player_ui_controller.dart';
part 'controllers/player_navigation_controller.dart';

const MethodChannel _androidPipChannel = MethodChannel('mina.player/pip');
const MethodChannel _activityLifecycleChannel =
    MethodChannel('mina.app/activity_lifecycle');

/// Tek GetX kaydı; mantık [PlayerPlaybackController], [PlayerUiController] ve
/// [PlayerNavigationController] extension dosyalarında ayrılmıştır.
class PlayerController extends GetxController with WidgetsBindingObserver {
  PlayerController({
    required Channel channel,
    List<Channel>? movieBrowseTape,
    List<SeriesItem>? seriesBrowseTape,
    SeriesItem? playingSeriesInTape,
    List<SeriesEpisodeOption>? episodeBrowseTape,
    List<PlayerBrowseCategoryTape<Channel>>? movieBrowseCategoryTapes,
    List<PlayerBrowseCategoryTape<SeriesItem>>? seriesBrowseCategoryTapes,
    this.showcaseInAppPipHandoff = false,
    this.showcasePipRestoreEngine,
    this.reopenFromInAppPip = false,
    String? initialAudioCodecHint,
  })  : _currentAudioCodecHint = initialAudioCodecHint,
        channel = channel.obs,
        _movieBrowseTape = movieBrowseTape != null
            ? List<Channel>.from(movieBrowseTape)
            : null,
        _seriesBrowseTape = seriesBrowseTape != null
            ? List<SeriesItem>.from(seriesBrowseTape)
            : null,
        _playingSeriesInTape = playingSeriesInTape,
        _episodeBrowseTape = episodeBrowseTape != null
            ? List<SeriesEpisodeOption>.from(episodeBrowseTape)
            : null,
        _movieBrowseCategoryTapes = movieBrowseCategoryTapes != null &&
                movieBrowseCategoryTapes.isNotEmpty
            ? List<PlayerBrowseCategoryTape<Channel>>.from(
                movieBrowseCategoryTapes,
              )
            : null,
        _seriesBrowseCategoryTapes = seriesBrowseCategoryTapes != null &&
                seriesBrowseCategoryTapes.isNotEmpty
            ? List<PlayerBrowseCategoryTape<SeriesItem>>.from(
                seriesBrowseCategoryTapes,
              )
            : null;

  /// [PlayerScreenArgs] ile açıldıysa geri dönüşte gözat listesi restore edilir.
  /// Vitrin ana ekranından doğrudan açıldı; çıkışta dock mini oynatıcı handoff.
  final bool showcaseInAppPipHandoff;

  /// PiP balonundan tam ekrana dönüşte handoff motoru (rota açılışında sabitlenir).
  final PlaybackEngineKind? showcasePipRestoreEngine;

  /// PiP önizlemeden tam ekrana dönüş — [_boot] ile yeniden başlatma yapılmaz.
  final bool reopenFromInAppPip;

  bool _pipReopenHandled = false;

  bool get isReopeningFromInAppPipPending =>
      reopenFromInAppPip && !_pipReopenHandled;

  bool get isReopeningFromInAppPip =>
      isReopeningFromInAppPipPending ||
      showcasePipRestoreEngine != null ||
      _showcasePipRestoreEngine != null;

  /// O an oynayan akışın Xtream ses kodeği ipucu (ör. `ac3`, `eac3`, `dts`).
  /// Açılışta [PlayerScreenArgs.audioCodecHint] ile gelir; kanal/bölüm
  /// değişiminde [_refreshAudioCodecHintForCurrent] ile güncellenir.
  String? _currentAudioCodecHint;

  final Rx<Channel> channel;

  /// Gözat (film): sıradaki filme geçiş.
  final List<Channel>? _movieBrowseTape;

  /// TV hızlı ray: kategori sekmeleri (birden fazlaysa sol/sağ ile geçiş).
  final List<PlayerBrowseCategoryTape<Channel>>? _movieBrowseCategoryTapes;

  /// Gözat (dizi): sıradaki dizinin ilk bölümüne geçiş.
  final List<SeriesItem>? _seriesBrowseTape;

  final List<PlayerBrowseCategoryTape<SeriesItem>>? _seriesBrowseCategoryTapes;

  SeriesItem? _playingSeriesInTape;

  SeriesItem? _dbResolvedSeries;

  /// Aynı dizide Xtream bölüm sırası (gözat panelinden).
  final List<SeriesEpisodeOption>? _episodeBrowseTape;

  /// Dikey modda OSD'nin altında gösterilen "Dizi" sekmesi için
  /// OMDB/TMDB üzerinden zenginleştirilmiş dizi metası (özet, IMDb,
  /// oyuncular...). Async yüklenir; null iken sekme iskelet gösterir.
  final Rxn<SeriesPlayerPanelData> seriesPanelData =
      Rxn<SeriesPlayerPanelData>();

  bool _seriesPanelDataLoaded = false;

  /// HTTP 404 / bulunamadı — ağ kesintisi değil; yeniden deneme yapılmaz.
  static bool _isNotFoundStyleError(String msg) {
    if (msg.isEmpty) return false;
    final l = msg.toLowerCase();
    return l.contains('404') ||
        l.contains('response code: 404') ||
        l.contains('status code: 404') ||
        l.contains('http 404') ||
        l.contains('http_404') ||
        (l.contains('not found') &&
            (l.contains('http') || l.contains('404') || l.contains('url'))) ||
        l.contains('content not found') ||
        l.contains('file not found');
  }

  /// HTTP 401/403 — sunucu reddi. HLS↔TS swap veya decoder retry uygun değil.
  static bool _isHttpForbiddenOrUnauthorizedError(String msg) {
    if (msg.isEmpty) return false;
    final l = msg.toLowerCase();
    if (l.contains('response code: 403') ||
        l.contains('response code: 401') ||
        l.contains('status code: 403') ||
        l.contains('status code: 401') ||
        l.contains('http 403') ||
        l.contains('http 401') ||
        l.contains('http_403') ||
        l.contains('http_401')) {
      return true;
    }
    if (l.contains('invalidresponsecodeexception') &&
        (l.contains('403') || l.contains('401'))) {
      return true;
    }
    return false;
  }

  /// Canlı progressive MPEG-TS: Exo [TsExtractor.seek] IllegalStateException.
  /// Ağ veya donanım kod çözücü hatası değildir.
  static bool _isExoTsExtractorSeekFailure(String msg) {
    if (msg.isEmpty) return false;
    final l = msg.toLowerCase();
    if (l.contains('tsextractor')) return true;
    if (l.contains('bundledextractorsadapter') && l.contains('seek')) {
      return true;
    }
    if (l.contains('unexpectedloaderexception') &&
        l.contains('illegalstateexception')) {
      return true;
    }
    return false;
  }

  /// İnternet / sunucu geçişi gibi tekrar denemeye uygun hatalar (kod çözücü değil).
  static bool _isLikelyNetworkOrTransientError(String msg) {
    if (msg.isEmpty) return false;
    if (_isNotFoundStyleError(msg)) return false;
    if (_isExoTsExtractorSeekFailure(msg)) return false;
    if (_isPlaybackDecoderFailure(msg)) return false;
    final l = msg.toLowerCase();
    if (l.contains('unsupported') && l.contains('format')) return false;
    if (l.contains('drm')) return false;
    // Flutter köprüsü: ağ / kaynak hataları bazen yalnızca PlatformException metniyle gelir.
    if (l.contains('platformexception') &&
        !l.contains('mediacodec') &&
        !l.contains('decoder') &&
        !l.contains('illegalstate')) {
      return true;
    }
    return l.contains('timeout') ||
        l.contains('timed out') ||
        l.contains('bağlantı') ||
        l.contains('baglanti') ||
        l.contains('connection') ||
        l.contains('network') ||
        l.contains('unreachable') ||
        l.contains('host lookup') ||
        l.contains('no address') ||
        l.contains('failed host') ||
        l.contains('connection reset') ||
        l.contains('connection refused') ||
        l.contains('broken pipe') ||
        l.contains('enetunreach') ||
        l.contains('econnrefused') ||
        l.contains('socket') ||
        (l.contains('ssl') && l.contains('handshake')) ||
        l.contains('ioexception') ||
        l.contains('i/o error') ||
        l.contains('io error') ||
        l.contains('502') ||
        l.contains('503') ||
        l.contains('504') ||
        l.contains('408') ||
        l.contains('failed to connect') ||
        l.contains('unable to connect') ||
        l.contains('no route') ||
        l.contains('cleartext') ||
        l.contains('err_timed_out') ||
        l.contains('network_error') ||
        l.contains('offline') ||
        l.contains('end of input') ||
        // ExoPlayer köprüsü çoğu zaman yalnızca "Source error" / "source error null" döner;
        // uzun canlı yayında segment/HTTP kopması böyle görünür (eski TV kutuları sık).
        l.contains('source error') ||
        l.contains('unexpected end of stream') ||
        l.contains('connection closed') ||
        (l.contains('http') && l.contains('50'));
  }

  /// "Source error" / `null` gibi belirsiz Exo metinlerinde TS↔m3u8 denemesi (tam kod çözücü hatası değilse).
  static bool _shouldTryXtreamFormatSwapOnSourceError(String msg) {
    if (msg.isEmpty) return false;
    if (_isNotFoundStyleError(msg)) return false;
    // 403/401 → TS'ye düşme; TsExtractor.seek → aynı TS döngüsü.
    if (_isHttpForbiddenOrUnauthorizedError(msg)) return false;
    if (_isExoTsExtractorSeekFailure(msg)) return false;
    final l = msg.toLowerCase();
    if (l.contains('mediacodec') ||
        l.contains('codecexception') ||
        (l.contains('video/mp2t') && l.contains('renderer'))) {
      return false;
    }
    if (l.contains('unsupported') && l.contains('format')) return false;
    if (l.contains('source error') && l.contains('null')) return true;
    if (l.contains('source error') && l.length < 160) return true;
    if (l.contains('exoplaybackexception') &&
        (l.contains('source') ||
            l.contains('unexpected') ||
            l.contains('ioexception'))) {
      return true;
    }
    if (l.contains('platformexception') &&
        (l.contains('source') ||
            l.contains('video') ||
            l.contains('playback'))) {
      return true;
    }
    return false;
  }

  /// ExoPlayer / video_player bazen `PlatformException(VideoError, ...)` döndürür;
  /// metin biçimi cihaza göre değişebilir.
  static bool _isPlaybackDecoderFailure(String msg) {
    if (msg.isEmpty) return false;
    final l = msg.toLowerCase();
    return l.contains('mediacodec') ||
        l.contains('mediacodecvideorenderer') ||
        l.contains('codecexception') ||
        l.contains('exoplaybackexception') ||
        l.contains('decoder initialization failed') ||
        l.contains('decoder failed') ||
        (l.contains('videoerror') && l.contains('renderer')) ||
        (l.contains('platformexception') &&
            l.contains('video') &&
            l.contains('mediacodec')) ||
        (l.contains('video/mp2t') && l.contains('renderer'));
  }

  /// Canlı Better hatası kaynak/ağ kökenli mi? (MediaKit yerine swap/yeniden bağlan.)
  static bool _isLikelyLiveSourceOrNetworkExoError(String msg) {
    if (msg.isEmpty) return false;
    final l = msg.toLowerCase();
    if (_isNotFoundStyleError(msg)) return false;
    // Açık kod çözücü/renderer imzası → kaynak sayma.
    if (l.contains('mediacodec') ||
        l.contains('codecexception') ||
        l.contains('decoder initialization failed') ||
        l.contains('decoder failed') ||
        (l.contains('videoerror') && l.contains('renderer')) ||
        (l.contains('video/mp2t') && l.contains('renderer'))) {
      return false;
    }
    if (l.contains('source error') ||
        l.contains('source_error') ||
        l.contains('sourcenotfound') ||
        l.contains('behind live window') ||
        l.contains('timeout') ||
        l.contains('timed out') ||
        l.contains('connection') ||
        l.contains('network') ||
        l.contains('socket') ||
        l.contains('unreachable') ||
        l.contains('failed to connect') ||
        l.contains('unable to connect') ||
        l.contains('cleartext') ||
        l.contains('http') ||
        (l.contains('ssl') && !l.contains('handshake failed'))) {
      return true;
    }
    if (l.contains('exoplaybackexception') &&
        (l.contains('source') ||
            l.contains('unexpected') ||
            l.contains('response code'))) {
      return true;
    }
    return false;
  }

  /// VOD’da Exo’nun seçtiği / bildirdiği parça AC3/DTS vb. olabilir; cihaz çözemezse sessiz kalır.
  static bool _riskyVodAudioCodecSnippet(String raw) {
    final s = raw.toLowerCase();
    return s.contains('ac3') ||
        s.contains('ac-3') ||
        s.contains('eac3') ||
        s.contains('dts') ||
        s.contains('truehd');
  }

  final _settings = Get.find<AppSettingsService>();

  /// libmpv `volume` / `volume-max` üst sınırı. 100 = sistem 100% (boost
  /// yok). Üst sınır 200 → kullanıcı Ayarlar > Oynatma Ayarları > Ses
  /// Yükseltici ile %200'e kadar açabilir. Düşük kazanç algılayan
  /// dinleyiciler için varsayılan logical 1.0 = mpv 130 (hafif boost ile
  /// ExoPlayer'a yakın algılanan ses) korunur.
  static const double _kMediaKitVolumePropertyMax = 200.0;

  /// Logical volume = 1.0 iken libmpv `volume` özelliği için temel kazanç.
  /// 130 değerini koruyoruz: önceki sürümlerle aynı algılanan ses; boost
  /// kapalıyken (maxPercent = 100) davranış değişmez.
  static const double _kMediaKitVolumeBaseAt1x = 130.0;

  BetterPlayerController? better;

  /// [better] düz alan olduğu için GetX dinlemez; [PlayerView] Obx bu sayacı okuyarak
  /// yüzey atanınca/çekilince yeniden kurar (aksi halde «oynatıcı hazır değil» yanlış pozitif).
  final betterSurfaceEpoch = 0.obs;

  Player? _mediaKitPlayer;

  bool get mediaKitPlaybackAttached => _mediaKitPlayer != null;

  PlaybackEngineKind? _showcasePipRestoreEngine;

  VideoController? _showcasePipMediaKitVideo;

  StreamSubscription<String?>? _mediaKitErrorSub;

  final List<StreamSubscription<dynamic>> _mediaKitDimSubs = [];

  /// [attachMediaKitPlayer] ile Obx yenilemesi (MediaKit OSD widget’ı için).
  final mediaKitAttachEpoch = 0.obs;

  /// OSD çözünürlük rozeti için Obx tetikleyici.
  final osdQualityStamp = 0.obs;

  int _lastOsdQualitySignature = -1;

  final Rxn<String> error = Rxn<String>();

  final isBusy = true.obs;

  /// 1.0 = tam parlak; sistem parlaklığı değil — yalnızca video üstü karartma katmanı.
  final inAppPlaybackBrightness = 1.0.obs;

  /// Dikey sürükleme hassasiyeti. Mutlak model: seviye = başlangıç +
  /// (-Δy / ekran yüksekliği) × gain. Standart oynatıcı davranışına yakın —
  /// ekranın ~%75'i kadar kaydırma ≈ uçtan uca parlaklık/ses. Eskiden 2.5 idi
  /// (ekranın ~%40'ı = tam aralık); küçük parmak titremesi bile büyük
  /// değişime yol açıp dengesiz/aşırı hassas hissettiriyordu.
  static const double verticalPlaybackGestureGain = 1.3;

  // ANR Düzeltme: Başlık normalizasyon fonksiyonları (seriesTitleForPanel,
  // searchTitleForResolve vb.) her kanal değişiminde aynı RegExp'i yeniden
  // oluşturuyordu. Dart release build'de bu bytecode interpreter'ı tetikler
  // → CPU-yoğun ANR. Tüm pattern'ler tek seferlik derlenir.
  static final _reBracketOrParen = RegExp(r'[\[\(].*?[\]\)]');
  static final _reSeasonEpisode =
      RegExp(r'\bS\d{1,2}\s?E\d{1,3}\b', caseSensitive: false);
  static final _reYear = RegExp(r'\b(19|20)\d{2}\b');
  static final _reMultiSpace = RegExp(r'\s{2,}');
  static final _reDashSep = RegExp(r'\s[-–—]\s');
  static final _reWhiteSpace = RegExp(r'\s+');

  /// Better yüzeyi yok + hata yok + meşgul değil: en fazla bu kadar otomatik [_boot].
  static const int maxOrphanBetterSurfaceRetries = 2;

  /// TV kutularda Exo yüzeyi geç hazırlanır; daha fazla deneme + [ensureOrphanBetterBootRetry] gecikmesi.
  static const int maxOrphanBetterSurfaceRetriesTv = 6;

  int _orphanBetterBootRev = 0;

  bool _orphanBetterBootInFlight = false;

  /// Yetim Better yüzeyi için yapılan otomatik yeniden deneme sayısı ([PlayerView] gösterimi).
  final orphanBetterSurfaceRecoveryAttempts = 0.obs;

  /// Canlı→canlı kanal değişiminde orta yükleme + logo katmanını gösterme (OSD satırı güncellenir).
  final RxBool suppressLiveZapLoadingUi = false.obs;

  /// TV cam OSD görünür mü; kanal değişiminde `isBusy` iken üst üste korunur.
  final RxBool tvOsdVisible = true.obs;

  /// VOD sarma çubuğu sürükleniyor mu? Sürükleme sürerken OSD/kontroller
  /// otomatik gizlenmemeli (zaman baloncuğu ve çubuk görünür kalmalı).
  final RxBool vodScrubbing = false.obs;

  /// TV: hızlı kanal şeridi açıkken OSD kapansa bile ana oynatıcı odağı şeridi ele geçirmesin.
  final RxBool liveChannelStripOverlayOpen = false.obs;

  /// TV: VOD gözat — aynı kategorideki film/dizi sağ ray (yayın durmaz).
  final RxBool vodBrowseRailOpen = false.obs;

  /// TV VOD rayında çoklu kategori sekmesi için indeks.
  final RxInt vodBrowseRailCategoryIndex = 0.obs;

  /// TV canlı hızlı ray: kategori sekmesi indeksi.
  final RxInt liveStripCategoryIndex = 0.obs;

  /// TV: oynatıcı üstü tek kanal EPG zaman çizelgesi (yayın durmaz).
  final RxBool liveSingleChannelEpgOpen = false.obs;

  /// Dikey canlı TV paneli sekme isteği: 0=kategoriler, 1=kanallar, 2=EPG.
  /// Aynı sekmeye tekrar basıldığında [portraitLivePanelTabPulse] artar.
  final RxInt portraitLivePanelTabRequest = 1.obs;

  final RxInt portraitLivePanelTabPulse = 0.obs;

  static const int portraitLiveTabCategories = 0;

  static const int portraitLiveTabChannels = 1;

  static const int portraitLiveTabEpg = 2;

  /// TV OSD dur/durdur: uzun OK ile hızlı kanal şeridi; [PlayerView] atar.
  VoidCallback? onRequestLiveChannelStripFromTvOsd;

  /// Hızlı kanal şeridinden bir kanal seçildikten sonra, kullanıcı işlem
  /// yapmazsa şerit bu süre sonunda otomatik kapanır.
  static const Duration _liveStripAutoCloseDelay = Duration(seconds: 3);

  Timer? _liveStripAutoCloseTimer;

  /// Şeridi kapatma isteği; [PlayerView] atar (OSD/kapanış mantığı orada).
  void Function()? onRequestCloseLiveChannelStrip;

  /// TV OSD: uzun OK ile VOD kategori rayı; [PlayerView] atar.
  VoidCallback? onRequestVodBrowseRailFromTvOsd;

// liveChannelStripCategoryTapes() önbelleği: aynı playlist verisi + gizleme
  // durumu için tam tarama bir kez yapılır. Overlay/tab/shift gibi çağrılar
  // önbellekten döner.
  List<PlayerBrowseCategoryTape<Channel>>? _liveStripTapesCache;

  Object? _liveStripTapesData;

  int _liveStripTapesHideRev = -1;

  bool _liveStripTapesReviewMode = false;

  List<Channel>? _liveCatZapCache;

  int? _liveCatZapCacheCatId;

  int _liveCatZapLoadGen = 0;

  int _liveStripDbLoadGen = 0;

  /// DB destekli kanal şeridi/listeleri async dolduğunda artar; reaktif
  /// (Obx) tüketiciler (dikey canlı panel kanal listesi) yeniden çizer.
  final RxInt liveStripTapesRevision = 0.obs;

  static const int _kPlayerDbChannelPageSize = 2000;

  /// Ayarlarda MediaKit kapalıyken, bu oturumda yedek motora geçildi mi (otomatik veya OSD).
  final RxBool mediaKitFallbackSession = false.obs;

  /// OSD ile Better’a geçildi (ayar MediaKit olsa bile bu oturumda Exo kullanılır).
  final RxBool betterOsdOverride = false.obs;

  /// Kumanda ile hızlı kanal değişiminde kısa duraklamadan sonra biriken adımlar tek [zapTo].
  Timer? _zapRelativeDebounceTimer;

  int _zapRelativePendingDelta = 0;

  /// Kumandadan sayı tuşları (0–9) ile doğrudan kanal numarasına geçiş:
  /// kullanıcı yazdıkça biriken rakamlar; boşsa giriş kutusu gizli. Numara,
  /// canlı kanallar ekranındaki gibi geçerli kategorideki **1 tabanlı** sıra.
  final RxString tvChannelNumberEntry = ''.obs;

  Timer? _channelNumberCommitTimer;

  static const int _channelNumberMaxDigits = 4;

  static const Duration _channelNumberCommitDelay =
      Duration(milliseconds: 2200);

  static const Duration _zapDebounceLive = Duration(milliseconds: 200);

  static const Duration _zapDebounceDefault = Duration(milliseconds: 500);

  /// Hızlı [zapTo] / [_boot] üst üste bindiğinde eski Exo [setupDataSource] tamamlanınca
  /// yanlış kanal veya sessiz oynatıcı bırakılmasını engeller.
  int _playbackGeneration = 0;

  /// [_prepareLeavePlayerRoute] ana ekrana dönmeden motorları kesti; [onClose] tekrar dispose etmez.
  bool _playbackEnginesHaltedForRouteExit = false;

  /// Canlı ABR: düşük → (2s) tercih edilen üst tavan; Exo + MediaKit ortak [Timer].
  Timer? _liveZapAbrRampTimer;

  int? _mediaKitZapAbrTargetGen;

  /// --- UNIFIED TIMERS (Performance Optimization) ---

  /// UI ile ilgili tüm timer'larý birleþtirir (OSD, countdown, focus)
  Timer? _uiTimer;

  /// Að ve canlý yayýn izleme için birleþik timer
  Timer? _networkTimer;

  /// Ýlerleme ve VOD autoplay için birleþik timer
  Timer? _progressTimer;

  int _vodResumeSession = 0;

  /// VOD «kaldığın yerden devam» diyaloğu açık — oynatıcı odağını kesmek için.
  final RxBool vodResumeDialogOpen = false.obs;

  /// Gözat VOD: sonraki içerik geri sayımı (5…1); null = kapalı.
  final Rxn<int> vodAutoplayCountdown = Rxn<int>();

  final vodAutoplayNextTitle = ''.obs;

  final vodAutoplayNextIsEpisode = false.obs;

  /// TV OSD kumanda odağını yeniden ver (ör. VOD devam diyaloğu kapandıktan sonra).
  final RxInt tvOsdKeyFocusBump = 0.obs;

  /// OSD’den Better ↔ MediaKit geçişinde diyalog yerine bu konuma sar.
  Duration? _resumeAtAfterOsdEngineSwitch;

  Timer? _watchProgressTimer;

  int? _lastWatchProgressSavedChannelId;

  int? _lastWatchProgressSavedPosMs;

  int? _lastWatchProgressSavedDurationMs;

  static const Duration _watchProgressSaveInterval = Duration(seconds: 12);

  static const int _watchProgressMinDeltaMs = 15000;

// AI öneri motoru için izleme alışkanlığı kayıtları (UserHistoryService).
  // Aynı tick ile sayım yapılır; playback aktifse her [_historyTickSecs] s
  // birikir, 120 sn eşik aşıldığında bir kez kayıt edilir, sonrasında
  // periyodik olarak güncellenir.
  Timer? _userHistoryTickTimer;

  static const int _historyTickSecs = 15;

  int _userHistoryWatchedSec = 0;

  bool _userHistoryRecorded = false;

  int _userHistoryLastReportedSec = 0;

  String? _userHistorySig;

  Timer? _vodEndAutoplayMonitor;

  Timer? _vodAutoplayCountdownTimer;

  /// --- UNIFIED TIMER STATE TRACKING ---

  /// UI timer state tracking
  DateTime? _tvOsdAutoHideAt;

  DateTime? _vodAutoplayCountdownStartedAt;

  bool _vodNearEndLatched = false;

  int? _vodAutoplaySuppressChannelId;

  static const Duration _tvOsdHideAfterPlayback = Duration(seconds: 4);

  /// [PlayerView] dikey modda OSD zamanlayıcısı için (el/tablet dikey).
  bool _playbackPortraitForAutoHide = false;

  /// Ağ kesintisi / geçici kaynak hatalarında aynı yayına yeniden bağlanma.
  Timer? _networkAutoResumeTimer;

  int _networkResumeAttempt = 0;

  /// Better/Exo veri kaynağı oluşturulurken **fiilen uygulanan** canlı tampon
  /// (sn). Smart Route override'ı değiştiğinde, hedef tampon ile bu değer
  /// karşılaştırılıp gerekiyorsa aktif yayın yeniden uygulanır. `-1` = henüz
  /// uygulanmadı.
  int _appliedExoLiveBufferSeconds = -1;

  /// Zap / kanal değişiminde uzun segment HLS tamponunu atla (hızlı açılış).
  bool _preferFastLiveStartBuffer = false;

  /// Kademeli tampon takılması kurtarma aşaması (0 = henüz yok).
  int _liveStallRecoveryStage = 0;

  /// Canlı Better/Exo: ağ stresinde otomatik tampon yükseltme (sn).
  static const int liveAutoBufferBoostMinSec = 6;
  static const int liveAutoBufferBoostStepSec = 4;
  static const int liveAutoBufferBoostMaxSec = 10;
  static const Duration liveAutoBufferHealthyRevertAfter =
      Duration(seconds: 90);

  DateTime? _liveAutoBufferHealthySince;

  /// Oynatma sırasında otomatik tampon override değişimini izleyen worker.
  Worker? _liveBufferOverrideWorker;

  /// Canlı «keep-alive»: durma/EOF/sessiz takılma kullanıcı duraklatması
  /// değilse, ısrarlı (artan beklemeli, üst sınırda sonsuza dek) yeniden
  /// bağlanma zinciri bu bayrakla işaretlenir. Armed iken
  /// [_performNetworkResume] kanalı asla terk etmez (sonraki kanala zap yok);
  /// yayın geri gelene (ör. bağlantı limiti boşalana) kadar **aynı** yayını
  /// dener. Sağlıklı oynatma, kullanıcı duraklatması veya kanal değişiminde
  /// sıfırlanır.
  bool _liveKeepAliveArmed = false;

  /// Canlı + geçici ağ: Exo anlık [hasError] gürültüsünde hemen kurtarma / OSD tetikleme.
  Timer? _liveTransientErrorEmitTimer;

  DateTime? _liveTvBufferingSince;

  int _liveTvStallRecoveryAttempts = 0;

  /// MediaKit canlı `.ts` takılırsa HLS'e geçiş zamanlayıcısı.
  Timer? _mediaKitLiveTsHlsWatchdog;

  Timer? _betterBufferingRecoveryTimer;

  DateTime? _lastBetterBufferingRecoveryAt;

  int? _betterBufferingListenerBoundTo;

  DateTime? _liveUnhealthySince;

  bool _liveAutoBufferGuardActive = false;
  bool _liveAutoNextWatchdogActive = false;

  static const Duration _liveAutoNextAfterUnhealthy = Duration(seconds: 38);

  static const Duration _liveAutoNextPollInterval = Duration(seconds: 3);

  /// Canlı yayın sessizce durduğunda (Better/MediaKit) aynı kanalı yeniden
  /// başlatmadan önce bekleme — kısa ağ dalgalanmalarını kesmez.
  static const Duration _liveRestartAfterIdle = Duration(seconds: 4);

  static const Duration _liveMinPlaybackBeforeRestart = Duration(seconds: 4);

  static const Duration _liveRestartDebounce = Duration(seconds: 3);

  static const Duration _liveTvStallPollInterval = Duration(seconds: 2);

  final isFading = false.obs;

  final decoderFallbackStep = 0.obs;

  final videoFit = BoxFit.fill.obs;

  /// Ağ kurtarma / motor yeniden boot eşzamanlılığı (paralel Exo sızıntısını önler).
  bool _networkResumeInFlight = false;

  /// [restartCurrentStream] cascade döngüsünü engelleyen debounce timer.
  /// Hata olayı yığılmasında (stall/watchdog/network) kısa aralıklı
  /// çoklu restartları tek bir yeniden bağlanmaya indirger.
  Timer? _restartDebounceTimer;

  /// [restartCurrentStream] zaten çalışıyor mu (çift tetikleme koruması).
  bool _restartInFlight = false;

  /// Canlıda kullanıcı OSD’den duraklattıysa [play] yalnızca devam ettirir; yayın kesildiyse tam yeniden yükleme yapılır.
  bool _userPausedLive = false;

  /// Kullanıcı OSD'den bilinçli pause yaptı → vitrin PiP handoff yok.
  bool _showcaseInAppPipUserPaused = false;

  /// Exo [STATE_ENDED] / sahte «bitti» (ör. HLS kayan pencere) sonrası yeniden bağlanma debounce.
  DateTime? _liveSpuriousStopLastRecovery;

  /// [_syncLiveAutoNextWatchdog] bir «durdu» epizodunda yalnızca bir kez erken
  /// keep-alive tetiklesin (4 sn).
  bool _liveIdleRestartTriggered = false;

  bool _forceSoftwareVideoDecoder = false;

  /// Son [iptvBetterPlayerDataSource] oluşturma: yazılım video kod çözücü istendi mi (Exo).
  bool _lastBootUsedSoftwareVideoDecoder = false;

  /// Better/Exo bir kodek/donanım kod çözücü hatasından MediaKit'e düştüğünde
  /// (veya Rockchip gibi bilinen zayıf cihaz/zorlu TV box'ta) bu oturumda mpv
  /// `hwdec=no` (yazılımsal çözüm) ile başlatılır. Yalnızca o yayın için; kanal
  /// değişiminde sıfırlanır. `false` iken mevcut güvenli `mediacodec` /
  /// `mediacodec-copy` mantığı korunur.
  bool _mediaKitFallbackForceSoftwareDecode = false;

  /// Canlı MediaKit: ses var görüntü yok → bir kez yazılım kod çözücüye düş.
  bool _mediaKitBlackScreenRecoveryUsed = false;

  Timer? _mediaKitBlackScreenWatchdog;

  /// MediaKit canlı: pozisyon 10 sn ilerlemezse yeniden bağlan (Crispy watchdog).
  Timer? _mediaKitLiveStallWatchdog;

  /// MediaKit: Aşırı kare düşüşü (stutter/jank) izleme bekçisi.
  Timer? _mediaKitFrameDropWatchdog;
  int _mediaKitLastDropCount = 0;
  int _mediaKitStutterTicks = 0;
  DateTime? _mediaKitFrameDropWatchdogArmedAt;

  /// BetterPlayer (ExoPlayer): Pozisyon donması izleme bekçisi.
  Timer? _betterPlaybackWatchdog;
  Duration _betterLastKnownPosition = Duration.zero;
  int _betterStutterTicks = 0;
  DateTime? _betterPlaybackWatchdogArmedAt;

  Duration _mediaKitLastKnownPosition = Duration.zero;

  int _mediaKitStallTicks = 0;

  static const int _kMediaKitStallThresholdTicks = 3;

  static const Duration _kMediaKitStallWatchdogInterval = Duration(seconds: 2);

  /// Hızlı canlı zap sonrası yalnızca Exo (Better) için yazılım kod çözücü.
  bool _preferExoSoftwareForFastZap = false;

  /// Canlı UHD/4K HLS: runtime geniş Exo tampon profili.
  bool _liveUhdBufferActive = false;
  bool _liveUhdBufferPromotionInFlight = false;

  /// Bir sonraki canlı kanal ön-yükleme (zap hızlandırma).
  Timer? _livePreloadTimer;
  String? _livePreloadScheduledUrl;

  /// Canlı oynatma kuruldu — tam URL yeniden açmayı sınırlamak için.
  bool _livePlaybackEstablished = false;
  StreamSubscription<VideoEvent>? _exoStallEventSub;
  bool _conservativeRecoverInFlight = false;
  DateTime? _liveSoftRecoverLastAt;

  /// Kanal önbelleği MPEG-TS ise bir sonraki [_boot]'ta .m3u8'e çevrilmesin.
  bool _cachedTsFormatForBoot = false;

  /// MediaKit/mpv yazılım kod çözücü (`hwdec=no`) — ayar, önbellek (software),
  /// Exo'dan düşüş veya bilinen sorunlu cihaz. Hızlı zap burada **yok** (siyah/gri ekran yapıyordu).
  bool get mediaKitShouldUseSoftwareDecode =>
      _settings.preferSoftwareVideoDecoder.value ||
      _forceSoftwareVideoDecoder ||
      _mediaKitFallbackForceSoftwareDecode ||
      (Platform.isAndroid && AndroidPlaybackSocHints.isSamsungSmT530);

  /// Canlı yayın MediaKit/mpv ile açılamadığında ~768 KB düşük gecikme zap
  /// buffer'ı kademeli olarak büyütülür (0 → ~16 MB → ~64 MB). Yalnızca canlı;
  /// kanal değişiminde sıfırlanır. VOD buffer mantığı bundan etkilenmez.
  int _mediaKitLiveBufferEscalationStep = 0;

  static const int _kMediaKitLiveBufferEscalationMax = 2;

  /// Donanım hatası → yazılım ile yeniden [ _boot ] planlandı (çift tetiklemeyi önler).
  bool _exoSoftwareDecoderRetryPending = false;

  /// [unawaited] VOD sessiz ses → MediaKit geçişinde çift [_performMediaKitFallbackBoot] önlemi.
  bool _vodSilentAudioMediaKitFallbackInFlight = false;

  /// Yayın koptuğunda [BetterPlayerController.retryDataSource] ile hafif yeniden deneme (Exo).
  int _betterPlayerLightRetryWave = 0;

  /// Kanal değişimi sırasında OSD'yi gizlemeyi engellemek için bayrak
  bool _isChangingChannel = false;

  /// Android: sistem PiP / [onPause] girişi ile [pause] yarışmasını kısa süre engellemek için.
  bool _suppressPauseForAndroidMiniPip = false;

  Timer? _androidPipFallbackPauseTimer;

  bool? _lastKnownPipActive;

  /// Android TV kutularında Flutter [AppLifecycleState.resumed] kalırken Activity
  /// arka planda olabilir; native [onPause]/[onStop] ile senkron tutulur.
  bool _nativeActivityBackground = false;

  Worker? _pipAutoEnterWorker;

  /// Kullanıcı OSD'den sabit kalite seçtiyse otomatik düşürmeyi yapma.
  bool _manualVideoQualityLock = false;

  /// Tekrarlayan tamponlamada otomatik kalite düşürme (HLS/DASH çoklu varyant).
  static const Duration _autoQBufferingWindow = Duration(seconds: 22);

  static const int _autoQBufferingStartsNeeded = 3;

  static const Duration _autoQDowngradeCooldown = Duration(seconds: 35);

  static const Duration _autoQIgnoreBufferingBefore = Duration(seconds: 4);

  final List<DateTime> _autoQRecentBufferingStarts = [];

  DateTime? _autoQLastDowngradeAt;

  DateTime? _autoQPlaybackStartedAt;

  /// Xtream panellerinde `get.php?...&output=ts` bazen ExoPlayer/Media3 tarafında
  /// `Source error` üretebiliyor. Bu durumda aynı yayını `live/.../$id.ts`
  /// formatına çevirip bir kez daha deniyoruz.
  bool _xtreamTriedLiveUrlFormat = false;

  /// Birincil URL `/live/...` iken hata olursa bir kez `get.php?...` dene.
  bool _xtreamTriedGetPhpFallback = false;

  /// `/series/...` veya `/movie/...` segment yolu başarısızsa bir kez `get.php?stream_id=...` dene.
  bool _xtreamTriedSeriesMoviePathToGetPhp = false;

  /// `get.php?...` ile oynatma başarısızsa bir kez `/series|movie/.../id.ext` segment yolu dene (ters yön).
  bool _xtreamTriedGetPhpToVodPathFallback = false;

  /// Xtream VOD bazen `mkv` ile açılmaz / ilk kare gelmez; bir kez aynı akışı `ts` ile dene.
  bool _xtreamTriedVodMkvToTsSwap = false;

  /// MediaKit (mpv) `Failed to open` + get.php yedeği de başarısız → Exo bir kez dene.
  bool _vodAutoTriedBetterAfterMpvFail = false;

  /// Canlı MediaKit `.ts` açılamayınca bir kez `.m3u8` dene.
  bool _mediaKitLiveTriedHlsAfterTs = false;

  /// Bu yayın için motorlar arası **otomatik** geçiş (Better↔MediaKit) bir kez
  /// yapıldı mı? Ping-pong'u (Better→MK→Better…) engeller; kanal değişiminde
  /// (zapTo) sıfırlanır.
  bool _autoEngineSwitchUsed = false;

  /// MediaCodec hatasında MPEG-TS yerine HLS (m3u8) bir kez dene.
  bool _decoderTriedTsToM3u8Swap = false;

  /// Canlı TS [TsExtractor.seek] sonrası HLS geri dönüş / MediaKit bir kez denendi.
  bool _liveTsSeekFailureHandled = false;

  /// [_armLiveTvStartupWatchdog] kurulum anı — buffering grace için.
  DateTime? _liveStartupWatchdogArmedAt;

  /// Canlı HTTP 403 sonrası aynı HLS için sınırlı yeniden deneme sayısı.
  int _liveHttpForbiddenRetryCount = 0;

  /// Son oynatılan URL (decoder kurtarma için TS→m3u8 vb.).
  String? _lastPlaybackUrl;

  /// Tek seferlik retry için oynatma URL'sini override eder.
  String? _playUrlOverride;

  /// Harici Oynatıcı modunda dahili player UI'ı yerine kısa bir handoff
  /// ekranı (logo + ilerleme göstergesi) gösterilir. Akış başarıyla
  /// fırlatıldığında [Get.back] çağrılır; başarısızsa fallback olarak
  /// dahili player'a düşülür.
  final externalPlayerHandoffActive = false.obs;

  /// [_boot] başarılı: OSD / watch progress / VOD devam — yalnızca bir kez ([_applyBootSuccessSideEffects]).
  bool _bootSuccessHooksApplied = false;

  /// İlk video karesi gelene kadar [isBusy]; zaman aşımında yine de kaldırılır.
  int? _busyHoldBootGen;

  int _busyHoldVodSession = 0;

  Timer? _busyHoldTimeout;

  VideoPlayerController? _busyHoldVideoController;

  VoidCallback? _busyHoldVideoTick;

  final List<StreamSubscription<dynamic>> _mediaKitBusyDimsSubs = [];

// Son native'e yazılan PiP auto-enter uygunluğu; per-tick çağrıda değer
  // değişmediyse platform kanalını tekrar çağırmamak için guard. [force]
  // lifecycle/boot gibi原生 durumun sıfırlanmış olabileceği yerlerde
  // yeniden uygular.
  bool? _lastPipAutoEnterEligibleApplied;

  /// [_flatMovieTapeForZap] önbelleği — VOD end monitor her sn expand etmesin.
  List<Channel>? _flatMovieZapCache;
  Object? _flatMovieZapCacheTabsKey;

  bool? _vodHasNextCache;
  int? _vodHasNextCacheChannelId;
  Object? _vodHasNextCacheEpKey;
  Object? _vodHasNextCacheMvKey;

  static String? _streamQualityLabelFromDimensions(int height, int width) {
    final dim = math.max(height, width);
    if (dim <= 0) return null;
    if (dim >= 2160) return '4K';
    if (dim >= 1080) return 'FHD';
    if (dim >= 720) return 'HD';
    if (dim >= 480) return 'SD';
    return 'SD';
  }

  /// Geçerli akış URL'si uzantısız "web manifest / embed" mi (mpv'ye yönlendir).
  /// [_boot] ve kanal değişiminde güncellenir; [effectiveUseMediaKit] içinde okunur.
  bool _forceMediaKitForCurrentUrl = false;

  /// Logical playback boost — sistem 100%'ünün üzerine kazanç (0.0 = boost
  /// yok). Sistem ses 1.0'a vurmadıkça boost 0 kalır; gesture sistem
  /// 1.0'a ulaşınca boost artırmaya başlar.
  final RxDouble _playbackBoostExtra = 0.0.obs;

// ---------------------------------------------------------------------------
  // Akıllı Jenerik Atlatıcı entegrasyonu (Smart Stream Cutter).
  // ---------------------------------------------------------------------------

  /// Mevcut bölüm için kayıtlı intro bitiş süresi (sn). 0 ise buton gizli.
  /// `Obx` ile dinlenir; bölüm değişince [_refreshIntroDurationForCurrent]
  /// güncellemesini yapar.
  final introSkipTargetSec = 0.obs;

  String? _lastIntroSeriesId;

  static bool _seriesMetaUsable(String? v) {
    if (v == null) return false;
    final t = v.trim();
    return t.isNotEmpty && t.toUpperCase() != 'N/A';
  }

// TV için son ses seviyesini hatýrla (logical 0..maxBoost)
  static double _lastVolumeLevel = 1.0;

  /// OSD hız butonu için döngü değerleri (1x → 1.25x → 1.5x → 2x → 1x).
  /// Daha önce 2/3/5/10x mevcuttu fakat günlük VOD izleme için çok yüksekti;
  /// kullanıcı isteği üzerine konfor aralığına çekildi. Varsayılan (başlangıç)
  /// değeri `1.0` — `playbackRate` her zaman bu değerle başlar.
  static const List<double> playbackRateCycle = <double>[
    1.0,
    1.25,
    1.5,
    2.0,
  ];

  /// Aktif oynatma hızı (1.0 = normal). OSD butonu bunu izler.
  final playbackRate = 1.0.obs;

  static const int _kLiveZapAbrMinTracks = 2;

  static const int _kLiveZapAbrMaxPollMs = 1500;

  static const int _kLiveZapAbrPollStepMs = 100;

  static int _mediaKitTrackPixels(VideoTrack t) {
    final w = t.w ?? 0, h = t.h ?? 0;
    if (w <= 0 || h <= 0) {
      return 0;
    }
    return w * h;
  }

  /// TV kutularında kademeli tampon takılması eşikleri (eski tek 48 sn yerine).
  static const Duration _liveTvStallReconnectThreshold = Duration(seconds: 10);
  static const Duration _liveTvStallSwapThreshold = Duration(seconds: 22);
  static const Duration _liveTvStallFullRecoveryThreshold =
      Duration(seconds: 38);

  /// Mobil/tablet kademeli tampon takılması eşikleri (eski tek 72 sn yerine).
  static const Duration _liveMobileStallReconnectThreshold =
      Duration(seconds: 12);
  static const Duration _liveMobileStallSwapThreshold = Duration(seconds: 28);
  static const Duration _liveMobileStallFullRecoveryThreshold =
      Duration(seconds: 40);

  /// Canlı Better/Exo başlangıç eşiği (TV dahil). Bu süre içinde stabil oynatma
  /// başlamazsa hızlı kurtarma (HLS↔TS / MediaKit). HLS tampon doluyorsa
  /// [_liveStartupHlsBufferingDeadline] kadar uzatılır.
  static const Duration _liveStartupSwapThreshold = Duration(seconds: 10);

  /// HLS (.m3u8) ilk kontrol eşiği.
  static const Duration _liveStartupHlsSwapThreshold = Duration(seconds: 10);

  /// HLS hâlâ buffering / initialized iken sabırsız swap yapma — en az bu süre.
  static const Duration _liveStartupHlsBufferingDeadline =
      Duration(seconds: 15);

  /// Better dispose → MediaKit: panel slot + MediaCodec settle.
  static const Duration _betterToMediaKitCooldown =
      Duration(milliseconds: 1200);

  /// Yeni BetterController CREATE öncesi eski oyuncu + MediaCodec settle (Xiaomi).
  static const Duration _betterHardResetSettle = Duration(milliseconds: 300);

  /// Network recovery / light-retry: Exo BUFFERING→READY için alt sınır.
  static const Duration _networkResumeMinDelay = Duration(seconds: 10);

  Worker? _mediaKitSettingsWorker;

  Worker? _playbackWakelockLayoutWorker;

  Worker? _backgroundPlaybackWorker;

  Worker? _playlistCacheWorker;

  Worker? _equalizerWorker;

  final List<StreamSubscription<dynamic>> _mediaKitWakelockSubs = [];

  /// Ekranı yalnızca içerik **gerçekten oynarken** açık tutar (tamponlama/OSD bekleme değil).
  // Son uygulanan wakelock durumu; oynatma sırasında _onVideoPlayerChanged
  // ~500ms'de bir tetiklendiğinden, durum değişmediyse platform kanalını
  // tekrar tekrar çağırmamak için guard. [force] dış reset sonrası
  // (lifecycle/boot) yeniden uygular.
  bool? _lastWakelockApplied;

  /// Vitrin uygulama içi PiP için mevcut oynatma bağlamını dışa aktarır.
  PlayerScreenArgs toPlayerScreenArgs() => PlayerScreenArgs(
        channel: channel.value,
        movieBrowseTape: _movieBrowseTape,
        seriesBrowseTape: _seriesBrowseTape,
        playingSeriesInTape: _playingSeriesInTape,
        episodeBrowseTape: _episodeBrowseTape,
        movieBrowseCategoryTapes: _movieBrowseCategoryTapes,
        seriesBrowseCategoryTapes: _seriesBrowseCategoryTapes,
        audioCodecHint: _currentAudioCodecHint,
        showcaseInAppPipHandoff: showcaseInAppPipHandoff,
      );

  @override
  void onInit() {
    super.onInit();

    // Eğer showcase PiP'ten geri dönüş değilse ve farklı bir kanal açılıyorsa,
    // arka planda kalmış olan eski oturumu temizle (ses karışmasını önlemek için).
    // NOT: Bu kontrol sadece mobil/tablet modunda PiP aktifse çalışmalı.
    // TV modunda PiP yok, bu yüzden bu kontrol gereksiz ve ANR'a sebep olabilir.
    if (!reopenFromInAppPip && 
        Get.isRegistered<ShowcaseInAppPipService>() &&
        _settings.layoutMode.value != AppLayoutMode.tv) {
      final pip = Get.find<ShowcaseInAppPipService>();
      if (pip.active.value && !pip.isReopeningFromPipBubble) {
        final saved = pip.savedChannel;
        if (saved != null && saved.id != channel.value.id) {
          unawaited(pip.stopAndDispose());
        }
      }
    }

    if (showcasePipRestoreEngine != null) {
      applyShowcasePipRestoreEngine(showcasePipRestoreEngine!);
    }
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) {
      _activityLifecycleChannel.setMethodCallHandler(
        _onNativeActivityLifecycleCall,
      );
    }
    _settings.playerScreenActive.value = true;
    if (_settings.externalPlayerEnabled.value &&
        Get.isRegistered<ExternalPlayerService>() &&
        Get.find<ExternalPlayerService>().isPlatformSupported) {
      _externalPlayerHandoffActive.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isClosed) return;
        unawaited(_handoffToExternalPlayer());
      });
      return;
    }
    decoderFallbackStep.value = 0;
    _applyRememberedVideoFit();
    _refreshForceMediaKitForCurrentUrl();
    _refreshAudioCodecHintForCurrent(fallbackToCurrent: _currentAudioCodecHint);
    _playbackWakelockLayoutWorker =
        ever(_settings.layoutMode, (_) => _syncPlaybackWakelock(force: true));
    _backgroundPlaybackWorker = ever<bool>(
      _settings.backgroundPlayback,
      (_) => _applyBackgroundPlaybackPolicy(),
    );
    if (Get.isRegistered<PlaylistCacheService>()) {
      _playlistCacheWorker = ever<M3uResult?>(
        Get.find<PlaylistCacheService>().result,
        (_) => _applyBackgroundPlaybackPolicy(),
      );
    }
    _syncPlaybackWakelock(force: true);
    _applyBackgroundPlaybackPolicy();
    _mediaKitSettingsWorker = everAll(
      [_settings.livePlaybackEngine, _settings.vodPlaybackEngine],
      (_) {
        betterOsdOverride.value = false;
        mediaKitFallbackSession.value = false;
        _autoEngineSwitchUsed = false;
        _mediaKitLiveTriedHlsAfterTs = false;
        unawaited(zapTo(channel.value));
      },
    );
    _pipAutoEnterWorker = ever(_settings.miniPlayerOnHome, (_) {
      unawaited(_syncAndroidPipAutoEnterEligible(force: true));
    });
    ever(_settings.layoutMode, (_) {
      unawaited(_syncAndroidPipAutoEnterEligible(force: true));
    });
    if (Get.isRegistered<EqualizerService>()) {
      _equalizerWorker = ever<int>(EqualizerService.to.revision, (_) {
        final mk = _mediaKitPlayer;
        if (mk == null) return;
        unawaited(EqualizerService.to.applyToMediaKit(mk));
      });
    }
    _liveBufferOverrideWorker = ever<int>(
      _settings.liveBufferOverrideRev,
      (_) => _onRuntimeLiveBufferOverrideChanged(),
    );
    ever<Channel>(channel, (_) => refreshIntroDurationForCurrent());
    ever<bool>(_settings.smartStreamCutterEnabled,
        (_) => refreshIntroDurationForCurrent());
    refreshIntroDurationForCurrent();
    _settings.onSubtitleFontPtApplied = applySubtitleFontFromSettings;
    unawaited(_tryRestoreFromShowcaseInAppPipOrBoot());
    if (isSeries) {
      unawaited(_loadSeriesPanelDataAsync());
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _syncPlaybackWakelock(force: true);
    if (Platform.isAndroid) {
      unawaited(_syncAndroidPipAutoEnterEligible(force: true));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _persistWatchProgressTick(force: true);
    }

    final bgPlayback = _settings.backgroundPlayback.value;

    if (bgPlayback) {
      if (state == AppLifecycleState.resumed) {
        _nativeActivityBackground = false;
        _applyBackgroundPlaybackPolicy();
        _lastWakelockApplied = null;
        _syncPlaybackWakelock(force: true);
        unawaited(_resumePlaybackAfterBackgroundIfNeeded());
        return;
      }
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.inactive) {
        unawaited(_maintainBackgroundPlayback());
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _nativeActivityBackground = false;
      final inPip = better?.videoPlayerController?.value.isPip == true;
      if (!inPip) {
        _disarmManualPipPauseGuards();
      }
      _lastWakelockApplied = null;
      _lastPipAutoEnterEligibleApplied = null;
      _syncPlaybackWakelock(force: true);
      if (Platform.isAndroid) {
        unawaited(_syncAndroidPipAutoEnterEligible(force: true));
      }
    }

    if (state == AppLifecycleState.paused) {
      if (_tryEnterMiniPlayerPipInsteadOfPause()) {
        return;
      }
    }

    final pauseForBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (_settings.layoutMode.value == AppLayoutMode.tv &&
            state == AppLifecycleState.inactive);
    if (pauseForBackground) {
      final vpc = better?.videoPlayerController?.value;
      if (vpc?.isPip == true) return;
      if (_suppressPauseForAndroidMiniPip) return;

      _pauseForLeavingAppIfBackgroundPlaybackDisabled();
    }
  }

  @override
  void onClose() {
    if (!_playbackEnginesHaltedForRouteExit) {
      _bumpPlaybackGeneration();
    }
    _settings.playerScreenActive.value = false;

    unawaited(
      _settings.clearMobilePlaybackPortraitLockForLeavingPlayer(),
    );
    _orphanBetterBootRev++;
    onRequestLiveChannelStripFromTvOsd = null;
    onRequestVodBrowseRailFromTvOsd = null;
    onRequestCloseLiveChannelStrip = null;
    cancelLiveStripAutoClose();
    cancelVodAutoplayCountdown();
    _stopVodEndAutoplayMonitor();
    _watchProgressTimer?.cancel();
    _watchProgressTimer = null;
    _persistWatchProgressTick(force: true);
    _flushUserHistory(force: true);
    _androidPipFallbackPauseTimer?.cancel();
    _livePreloadTimer?.cancel();
    _livePreloadTimer = null;
    unawaited(_exoStallEventSub?.cancel());
    _exoStallEventSub = null;
    _pipAutoEnterWorker?.dispose();
    _settings.onSubtitleFontPtApplied = null;
    _playbackWakelockLayoutWorker?.dispose();
    _backgroundPlaybackWorker?.dispose();
    _playlistCacheWorker?.dispose();
    if (Platform.isAndroid) {
      unawaited(
        _androidPipChannel.invokeMethod<void>(
          'setPipAutoEnterEligible',
          <String, dynamic>{'eligible': false},
        ),
      );
    }
    _mediaKitSettingsWorker?.dispose();
    _equalizerWorker?.dispose();
    _liveBufferOverrideWorker?.dispose();
    _cancelMediaKitWakelockSubs();
    _cancelZapRelativeDebounce();
    _cancelLiveZapAbrQualityRamp();
    _cancelTvOsdAutoHideTimer();
    _resetNetworkRecoveryState();
    _cancelLiveTransientErrorEmitTimer();
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    _cancelLiveAutoNextWatchdog();
    _cancelLiveAutoBufferGuard();
    _cancelUnifiedUiTimer();
    _cancelUnifiedNetworkTimer();
    _cancelUnifiedProgressTimer();

    unawaited(WakelockPlus.disable());
    if (Platform.isAndroid) {
      _activityLifecycleChannel.setMethodCallHandler(null);
    }
    WidgetsBinding.instance.removeObserver(this);
    if (!_playbackEnginesHaltedForRouteExit) {
      try {
        final mk = _mediaKitPlayer;
        if (mk != null) {
          unawaited(
              mk.pause().then((_) => mk.stop()).then((_) => mk.dispose()));
        }
      } catch (_) {}
      try {
        better?.videoPlayerController?.removeListener(_onVideoPlayerChanged);
        better?.pause();
        better?.dispose(forceDispose: true);
      } catch (_) {}
      _setBetterPlayer(null);
    }
    _mediaKitErrorSub?.cancel();
    _mediaKitErrorSub = null;
    _cancelMediaKitDimSubs();

    for (final s in _mediaKitBusyDimsSubs) {
      unawaited(s.cancel());
    }
    _mediaKitBusyDimsSubs.clear();

    _busyHoldTimeout?.cancel();
    _busyHoldTimeout = null;
    _zapRelativeDebounceTimer?.cancel();
    _zapRelativeDebounceTimer = null;
    _channelNumberCommitTimer?.cancel();
    _channelNumberCommitTimer = null;
    _androidPipFallbackPauseTimer?.cancel();
    _androidPipFallbackPauseTimer = null;
    _watchProgressTimer?.cancel();
    _watchProgressTimer = null;
    _userHistoryTickTimer?.cancel();
    _userHistoryTickTimer = null;
    _vodEndAutoplayMonitor?.cancel();
    _vodEndAutoplayMonitor = null;
    _vodAutoplayCountdownTimer?.cancel();
    _vodAutoplayCountdownTimer = null;
    _networkAutoResumeTimer?.cancel();
    _networkAutoResumeTimer = null;
    _liveTransientErrorEmitTimer?.cancel();
    _liveTransientErrorEmitTimer = null;
    _mediaKitLiveTsHlsWatchdog?.cancel();
    _mediaKitLiveTsHlsWatchdog = null;
    _tvOsdAutoHideAt = null;

    // ANR düzeltmesi — yeni eklenen timer'lar temizle
    _restartDebounceTimer?.cancel();
    _restartDebounceTimer = null;
    _restartInFlight = false;
    _mediaKitBlackScreenWatchdog?.cancel();
    _mediaKitBlackScreenWatchdog = null;

    _mediaKitPlayer = null;
    clearShowcasePipRestoreEngine();
    super.onClose();
  }
}

/// [BetterPlayerConfiguration.overlay]: yalnızca video karartılır; altyazı ve OSD üstte kalır.
class InAppBrightnessBetterOverlay extends StatelessWidget {
  const InAppBrightnessBetterOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = Get.find<PlayerController>();
    return Obx(() {
      final dim = (1.0 - pc.inAppPlaybackBrightness.value).clamp(0.0, 1.0);
      if (dim < 0.003) return const SizedBox.shrink();
      return Positioned.fill(
        child: IgnorePointer(
          child: ColoredBox(
            color: Color.fromRGBO(0, 0, 0, dim),
          ),
        ),
      );
    });
  }
}
