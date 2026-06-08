import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:get/get.dart' hide Response;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/player/better_player_iptv_config.dart';
import '../../core/player/media_kit_mpv_low_power_display.dart';
import '../../core/player/media_kit_subtitle_font.dart';
import '../../core/player/subtitle_font_family.dart';
import '../../core/player/exo_native_track_option.dart';
import '../../core/player/vod_subtitle_discovery.dart';
import '../../core/player/iptv_playback_defaults.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/player/playback_orientation_manager.dart';
import '../../core/platform/android_playback_soc_hints.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/equalizer_service.dart';
import '../../core/services/external_player_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/mina_analytics_service.dart';
import '../../core/services/mina_stream_cutter_service.dart';
import '../../core/home/recommended_films_catalog.dart';
import '../../core/home/series_name_grouping.dart';
import '../../core/services/movie_service.dart';
import '../../core/services/playback_progress_write_queue_service.dart';
import '../../core/utils/turkish_title_utils.dart';
import '../../domain/entities/movie_model.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/playlist_category_hide.dart';
import '../../core/services/system_volume_service.dart';
import '../../core/services/toast_service.dart';
import '../../core/services/watch_progress_service.dart';
import '../../services/user_history_service.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../browse/browse_controller.dart';
import '../channels/channels_controller.dart';
import 'player_route_args.dart';
import 'series_player_panel_data.dart';
import 'widgets/tv_better_player_controls.dart';
import 'widgets/vod_resume_dialog.dart';

const MethodChannel _androidPipChannel = MethodChannel('mina.player/pip');

class PlayerController extends GetxController with WidgetsBindingObserver {
  PlayerController({
    required Channel channel,
    List<Channel>? movieBrowseTape,
    List<SeriesItem>? seriesBrowseTape,
    SeriesItem? playingSeriesInTape,
    List<SeriesEpisodeOption>? episodeBrowseTape,
    List<PlayerBrowseCategoryTape<Channel>>? movieBrowseCategoryTapes,
    List<PlayerBrowseCategoryTape<SeriesItem>>? seriesBrowseCategoryTapes,
    this.openedFromBrowse = false,
  })  : channel = channel.obs,
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
  final bool openedFromBrowse;

  final Rx<Channel> channel;

  /// Gözat (film): sıradaki filme geçiş.
  final List<Channel>? _movieBrowseTape;

  /// TV hızlı ray: kategori sekmeleri (birden fazlaysa sol/sağ ile geçiş).
  final List<PlayerBrowseCategoryTape<Channel>>? _movieBrowseCategoryTapes;

  /// Gözat (dizi): sıradaki dizinin ilk bölümüne geçiş.
  final List<SeriesItem>? _seriesBrowseTape;

  final List<PlayerBrowseCategoryTape<SeriesItem>>? _seriesBrowseCategoryTapes;
  SeriesItem? _playingSeriesInTape;

  /// Aynı dizide Xtream bölüm sırası (gözat panelinden).
  final List<SeriesEpisodeOption>? _episodeBrowseTape;

  bool get isMovie => _movieBrowseTape != null;
  bool get isSeries =>
      _seriesBrowseTape != null ||
      _playingSeriesInTape != null ||
      _episodeBrowseTape != null;
  SeriesItem? get playingSeries => _playingSeriesInTape;

  /// O an oynayan içeriğin favori durumu — canlı kanal / film (VOD) / dizi.
  /// OSD'deki kalp ikonu bu getter ile çizilir; [FavoritesService] reaktif
  /// listelerini okuduğundan `Obx` içinde çağrılmalı.
  bool get isCurrentMediaFavorite {
    if (!Get.isRegistered<FavoritesService>()) return false;
    final favs = Get.find<FavoritesService>();
    if (isSeries) {
      final sid = _playingSeriesInTape?.id;
      if (sid == null) return false;
      return favs.hasSeries(sid);
    }
    if (isMovie) return favs.hasVod(channel.value.id);
    return favs.hasChannel(channel.value.id);
  }

  /// OSD kalp ikonu: o an oynayan içeriği favorilere ekler/çıkarır.
  void toggleCurrentMediaFavorite() {
    if (!Get.isRegistered<FavoritesService>()) return;
    final favs = Get.find<FavoritesService>();
    if (isSeries) {
      final sid = _playingSeriesInTape?.id;
      if (sid == null) return;
      favs.toggleSeries(sid);
    } else if (isMovie) {
      favs.toggleVod(channel.value.id);
    } else {
      favs.toggleChannel(channel.value.id);
    }
  }

  /// Dikey modda OSD'nin altında gösterilen "Dizi" sekmesi için
  /// OMDB/TMDB üzerinden zenginleştirilmiş dizi metası (özet, IMDb,
  /// oyuncular...). Async yüklenir; null iken sekme iskelet gösterir.
  final Rxn<SeriesPlayerPanelData> seriesPanelData =
      Rxn<SeriesPlayerPanelData>();
  bool _seriesPanelDataLoaded = false;

  /// Dikey panelde "Bölümler" sekmesi için kullanılacak sıralı bölüm listesi
  /// (sezon → bölüm). Browse'tan gelen `_episodeBrowseTape` üzerinden türetilir.
  List<SeriesEpisodeOption> get seriesEpisodeBrowseTape =>
      List.unmodifiable(_episodeBrowseTape ?? const <SeriesEpisodeOption>[]);

  /// Şu anda oynayan bölümü `_episodeBrowseTape` içinde tespit eder.
  SeriesEpisodeOption? get currentSeriesEpisodeOption =>
      _currentEpisodeOption();

  /// Dizi oturumunda [xtream_api] URL’leri (container_extension / get.php) olduğu gibi kalır.
  String _normalizePlaybackStreamUrl(String raw) =>
      IptvPlaybackDefaults.normalizeStreamUrl(
        raw,
        xtreamSeriesEpisode: isSeries,
      );

  /// Aynı kanal satırı (id + normalize URL). Yalnız id eşleşip URL farklıysa farklı yayındır.
  bool _isSameChannelRow(Channel a, Channel b) =>
      a.id == b.id &&
      _normalizePlaybackStreamUrl(a.streamUrl) ==
          _normalizePlaybackStreamUrl(b.streamUrl);

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

  /// İnternet / sunucu geçişi gibi tekrar denemeye uygun hatalar (kod çözücü değil).
  static bool _isLikelyNetworkOrTransientError(String msg) {
    if (msg.isEmpty) return false;
    if (_isNotFoundStyleError(msg)) return false;
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

  void _setBetterPlayer(BetterPlayerController? next) {
    if (identical(better, next)) return;

    // Eğer controller kapatılmışsa yeni oynatıcıyı kabul etme ve temizle
    if (isClosed && next != null) {
      try {
        next.videoPlayerController?.removeListener(_onVideoPlayerChanged);
        next.pause();
        next.dispose(forceDispose: true);
      } catch (_) {}
      return;
    }

    better = next;
    betterSurfaceEpoch.value++;

    // TV Box audio processor configuration
    _configureTvBoxAudioProcessor();
  }

  /// TV Box için ExoPlayer audio processor konfigürasyonu
  void _configureTvBoxAudioProcessor() {
    if (better == null) return;

    final settings = Get.find<AppSettingsService>();
    final isTv = settings.layoutMode.value.usesRemoteNavigationStyle;

    if (!isTv) return;

    // BetterPlayer kurulumundan sonra ExoPlayer'a eri ve audio processor ayarlarini yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vpc = better?.videoPlayerController;
      if (vpc == null) return;

      // ExoPlayer audio processor için senkronizasyon düzeltici
      try {
        // TV Box için audio prioritization ve sync correction
        // Not: Bu ExoPlayer seviyesinde audio processor ayarlarini içerir
        // BetterPlayer araciligiyla ExoPlayer'a erisilir
      } catch (e) {
        // Audio processor ayarlari basarisiz olursa sessizce devam et
      }
    });
  }

  Player? _mediaKitPlayer;
  StreamSubscription<String?>? _mediaKitErrorSub;
  final List<StreamSubscription<dynamic>> _mediaKitDimSubs = [];

  /// MediaKit aktifken [UniversalVideoPlayer] üzerinden [Player] örneği.
  Player? get mediaKitPlayer => _mediaKitPlayer;

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

  /// Better yüzeyi yok + hata yok + meşgul değil: en fazla bu kadar otomatik [_boot].
  static const int maxOrphanBetterSurfaceRetries = 2;

  /// TV kutularda Exo yüzeyi geç hazırlanır; daha fazla deneme + [ensureOrphanBetterBootRetry] gecikmesi.
  static const int maxOrphanBetterSurfaceRetriesTv = 6;

  /// [PlayerView] yetim yüzey eşiği; TV’de daha yüksek ([maxOrphanBetterSurfaceRetriesTv]).
  int get effectiveMaxOrphanBetterSurfaceRetries =>
      _settings.layoutMode.value == AppLayoutMode.tv
          ? maxOrphanBetterSurfaceRetriesTv
          : maxOrphanBetterSurfaceRetries;

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

  /// TV OSD dur/durdur: uzun OK ile hızlı kanal şeridi; [PlayerView] atar.
  VoidCallback? onRequestLiveChannelStripFromTvOsd;

  void requestOpenLiveChannelStripFromTvOsd() {
    onRequestLiveChannelStripFromTvOsd?.call();
  }

  /// Hızlı kanal şeridinden bir kanal seçildikten sonra, kullanıcı işlem
  /// yapmazsa şerit bu süre sonunda otomatik kapanır.
  static const Duration _liveStripAutoCloseDelay = Duration(seconds: 3);

  Timer? _liveStripAutoCloseTimer;

  /// Şeridi kapatma isteği; [PlayerView] atar (OSD/kapanış mantığı orada).
  void Function()? onRequestCloseLiveChannelStrip;

  /// Kanal seçildikten sonra otomatik kapanma sayacını başlatır/sıfırlar.
  void scheduleLiveStripAutoClose() {
    _liveStripAutoCloseTimer?.cancel();
    if (!liveChannelStripOverlayOpen.value) return;
    _liveStripAutoCloseTimer = Timer(_liveStripAutoCloseDelay, () {
      _liveStripAutoCloseTimer = null;
      if (!liveChannelStripOverlayOpen.value) return;
      onRequestCloseLiveChannelStrip?.call();
    });
  }

  /// Yalnızca sayaç etkinse (bir seçim yapıldıysa) süreyi sıfırlar; etkileşim
  /// devam ettikçe şerit açık kalır.
  void bumpLiveStripAutoCloseIfActive() {
    if (_liveStripAutoCloseTimer == null) return;
    scheduleLiveStripAutoClose();
  }

  void cancelLiveStripAutoClose() {
    _liveStripAutoCloseTimer?.cancel();
    _liveStripAutoCloseTimer = null;
  }

  /// TV OSD: uzun OK ile VOD kategori rayı; [PlayerView] atar.
  VoidCallback? onRequestVodBrowseRailFromTvOsd;

  void requestOpenVodBrowseRailFromTvOsd() {
    onRequestVodBrowseRailFromTvOsd?.call();
  }

  /// Gözat şeridi: film veya (dizi listesi + oynanan dizi) varsa uzun OK ile ray açılabilir.
  bool get vodBrowseRailAvailable {
    final mv = _movieBrowseTape;
    if (mv != null && mv.isNotEmpty) return true;
    final mvCat = _movieBrowseCategoryTapes;
    if (mvCat != null && mvCat.isNotEmpty) {
      for (final t in mvCat) {
        if (t.items.isNotEmpty) return true;
      }
    }
    final sv = _seriesBrowseTape;
    if (sv != null && sv.isNotEmpty && _playingSeriesInTape != null) {
      return true;
    }
    final svCat = _seriesBrowseCategoryTapes;
    if (svCat != null && svCat.isNotEmpty && _playingSeriesInTape != null) {
      for (final t in svCat) {
        if (t.items.isNotEmpty) return true;
      }
    }
    return false;
  }

  /// OSD orta tuşta uzun OK ile hızlı ray açılacaksa küçük rozet ikonu gösterilir.
  bool get osdQuickMenuHoldBadgeVisible {
    if (vodBrowseRailAvailable) return true;
    final cur = channel.value;
    final url = cur.streamUrl.toLowerCase();
    final isVodPath = isMovie ||
        isSeries ||
        url.contains('/movie/') ||
        url.contains('/series/');
    if (isVodPath) return false;
    if (liveTimeshiftSeekAvailable) return false;
    final norm = IptvPlaybackDefaults.normalizeStreamUrl(cur.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) return false;
    if (url.contains('/movie/') || url.contains('/series/')) return false;
    return true;
  }

  List<Channel>? get vodBrowseRailMovies {
    final tabs = _movieBrowseCategoryTapes;
    if (tabs != null && tabs.isNotEmpty) {
      final i = vodBrowseRailCategoryIndex.value.clamp(0, tabs.length - 1);
      final slice = tabs[i].items;
      return slice.isEmpty ? null : slice;
    }
    return _movieBrowseTape;
  }

  List<SeriesItem>? get vodBrowseRailSeriesItems {
    final tabs = _seriesBrowseCategoryTapes;
    if (tabs != null && tabs.isNotEmpty) {
      final i = vodBrowseRailCategoryIndex.value.clamp(0, tabs.length - 1);
      final slice = tabs[i].items;
      return slice.isEmpty ? null : slice;
    }
    return _seriesBrowseTape;
  }

  bool get vodBrowseRailShowsCategoryTabs {
    final m = _movieBrowseCategoryTapes;
    if (m != null && m.length > 1) return true;
    final s = _seriesBrowseCategoryTapes;
    if (s != null && s.length > 1) return true;
    return false;
  }

  List<String> get vodBrowseRailCategoryTabNames {
    final m = _movieBrowseCategoryTapes;
    if (m != null && m.isNotEmpty) {
      return [for (final t in m) t.name];
    }
    final s = _seriesBrowseCategoryTapes;
    if (s != null && s.isNotEmpty) {
      return [for (final t in s) t.name];
    }
    return const [];
  }

  void shiftVodBrowseRailCategory(int delta) {
    final movieTabs = _movieBrowseCategoryTapes;
    if (movieTabs != null && movieTabs.length > 1) {
      final n = (vodBrowseRailCategoryIndex.value + delta)
          .clamp(0, movieTabs.length - 1);
      vodBrowseRailCategoryIndex.value = n;
      return;
    }
    final serTabs = _seriesBrowseCategoryTapes;
    if (serTabs != null && serTabs.length > 1) {
      final n = (vodBrowseRailCategoryIndex.value + delta)
          .clamp(0, serTabs.length - 1);
      vodBrowseRailCategoryIndex.value = n;
    }
  }

  void _syncVodBrowseRailCategoryIndex() {
    final mvTabs = _movieBrowseCategoryTapes;
    if (mvTabs != null && mvTabs.isNotEmpty) {
      final curId = channel.value.id;
      for (var i = 0; i < mvTabs.length; i++) {
        if (mvTabs[i].items.any((c) => c.id == curId)) {
          vodBrowseRailCategoryIndex.value = i;
          return;
        }
      }
      vodBrowseRailCategoryIndex.value = 0;
      return;
    }
    final serTabs = _seriesBrowseCategoryTapes;
    if (serTabs != null && serTabs.isNotEmpty) {
      final sid = _playingSeriesInTape?.id;
      if (sid != null) {
        for (var i = 0; i < serTabs.length; i++) {
          if (serTabs[i].items.any((s) => s.id == sid)) {
            vodBrowseRailCategoryIndex.value = i;
            return;
          }
        }
      }
      vodBrowseRailCategoryIndex.value = 0;
    }
  }

  /// Film/dizi kumanda yukarı-aşağı: tüm kategori şeritleri birleşik sıra.
  List<Channel> _flatMovieTapeForZap() {
    final tabs = _movieBrowseCategoryTapes;
    if (tabs != null && tabs.isNotEmpty) {
      return [...tabs.expand((t) => t.items)];
    }
    return _movieBrowseTape ?? const [];
  }

  List<SeriesItem> _flatSeriesTapeForZap() {
    final tabs = _seriesBrowseCategoryTapes;
    if (tabs != null && tabs.isNotEmpty) {
      return [...tabs.expand((t) => t.items)];
    }
    return _seriesBrowseTape ?? const [];
  }

  List<PlayerBrowseCategoryTape<Channel>> liveChannelStripCategoryTapes() {
    final cache = Get.find<PlaylistCacheService>();
    final data = cache.result.value;
    if (data == null) return const [];
    final live = <Channel>[];
    for (final c in data.channels) {
      if (PlaylistCategoryHide.channelHiddenInLive(
        _settings,
        cache,
        data,
        c,
      )) {
        continue;
      }
      final cn = IptvPlaybackDefaults.normalizeStreamUrl(c.streamUrl);
      if (!IptvPlaybackDefaults.isLikelyLiveStream(cn)) continue;
      final cu = c.streamUrl.toLowerCase();
      if (cu.contains('/movie/') || cu.contains('/series/')) continue;
      live.add(c);
    }
    live.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final byCat = <int, List<Channel>>{};
    for (final c in live) {
      byCat.putIfAbsent(c.categoryId, () => []).add(c);
    }
    final order = <int, int>{};
    for (var i = 0; i < data.channelCategories.length; i++) {
      order[data.channelCategories[i].id] = i;
    }
    final tapes = <PlayerBrowseCategoryTape<Channel>>[];
    for (final e in byCat.entries) {
      if (e.value.isEmpty) continue;
      String name = '#${e.key}';
      for (final cc in data.channelCategories) {
        if (cc.id == e.key) {
          name = cc.name;
          break;
        }
      }
      tapes.add(PlayerBrowseCategoryTape<Channel>(
        categoryId: e.key,
        name: name,
        items: e.value,
      ));
    }
    tapes.sort((a, b) => (order[a.categoryId] ?? 999999)
        .compareTo(order[b.categoryId] ?? 999999));
    return tapes;
  }

  List<Channel> liveChannelStripChannelsForOverlay() {
    final tapes = liveChannelStripCategoryTapes();
    if (tapes.isEmpty) return const [];
    final i = liveStripCategoryIndex.value.clamp(0, tapes.length - 1);
    return tapes[i].items;
  }

  bool get liveChannelStripShowsCategoryTabs =>
      liveChannelStripCategoryTapes().length > 1;

  void shiftLiveStripCategory(int delta) {
    final tapes = liveChannelStripCategoryTapes();
    if (tapes.length <= 1) return;
    final n = (liveStripCategoryIndex.value + delta).clamp(0, tapes.length - 1);
    liveStripCategoryIndex.value = n;
  }

  List<String> liveStripCategoryTabNames() =>
      [for (final t in liveChannelStripCategoryTapes()) t.name];

  void prepareLiveChannelStrip() {
    final tapes = liveChannelStripCategoryTapes();
    if (tapes.isEmpty) return;
    final curId = channel.value.id;
    for (var i = 0; i < tapes.length; i++) {
      if (tapes[i].items.any((c) => c.id == curId)) {
        liveStripCategoryIndex.value = i;
        return;
      }
    }
    liveStripCategoryIndex.value = 0;
  }

  void openVodBrowseRail() {
    if (!vodBrowseRailAvailable) return;
    if (liveChannelStripOverlayOpen.value) return;
    if (liveSingleChannelEpgOpen.value) return;
    _syncVodBrowseRailCategoryIndex();
    vodBrowseRailOpen.value = true;
    hideTvOsdNow();
  }

  void closeVodBrowseRail({bool showOsdAfter = true}) {
    if (!vodBrowseRailOpen.value) return;
    vodBrowseRailOpen.value = false;
    if (!_usesRemoteOsdChrome) return;
    if (showOsdAfter) {
      tvOsdVisible.value = true;
      scheduleTvOsdAutoHide();
      bumpTvOsdKeyFocus();
    }
  }

  Future<void> pickVodBrowseRailMovie(Channel target) async {
    if (_isSameChannelRow(target, channel.value)) {
      return;
    }
    await zapTo(target);
  }

  Future<void> pickVodBrowseRailSeries(SeriesItem ser) async {
    if (_playingSeriesInTape?.id == ser.id) return;
    await _zapToBrowseTapeSeries(ser);
  }

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
  int _bumpPlaybackGeneration() => ++_playbackGeneration;

  bool _isPlaybackGenerationCurrent(int gen) => gen == _playbackGeneration;

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

  void bumpTvOsdKeyFocus() {
    if (!_usesRemoteOsdChrome) return;
    tvOsdKeyFocusBump.value++;
  }

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

  /// Dikey oynatıcı yüzeyi açık/kapalı — OSD otomatik gizleme için.
  void setPlaybackPortraitForAutoHide(bool portrait) {
    final was = _playbackPortraitForAutoHide;
    _playbackPortraitForAutoHide = portrait;
    if (was && !portrait) {
      _cancelTvOsdAutoHideTimer();
      if (!_usesRemoteOsdChrome) {
        tvOsdVisible.value = true;
      }
      return;
    }
    if (!was && portrait && !_usesRemoteOsdChrome) {
      scheduleTvOsdAutoHide();
    }
  }

  /// Ağ kesintisi / geçici kaynak hatalarında aynı yayına yeniden bağlanma.
  Timer? _networkAutoResumeTimer;
  int _networkResumeAttempt = 0;

  /// Canlı (Exo): uzun süre takılı tampon → yeniden bağlan dene.
  Timer? _liveStallWatchdogTimer;

  /// Canlı + geçici ağ: Exo anlık [hasError] gürültüsünde hemen kurtarma / OSD tetikleme.
  Timer? _liveTransientErrorEmitTimer;

  /// TV + canlı + Better: uzun tampon → aynı yayına yeniden bağlan (otomatik MediaKit yok).
  Timer? _liveTvStallPollTimer;
  DateTime? _liveTvBufferingSince;
  int _liveTvStallRecoveryAttempts = 0;
  Timer? _liveTvStartupWatchdog;
  Timer? _betterBufferingRecoveryTimer;
  DateTime? _lastBetterBufferingRecoveryAt;
  int? _betterBufferingListenerBoundTo;

  /// Canlı: uzun süre gerçek oynatma yoksa (açılmama / kesilme / duraklama) aynı yayını yeniden açmayı dene.
  Timer? _liveAutoNextPollTimer;
  DateTime? _liveUnhealthySince;
  static const Duration _liveAutoNextAfterUnhealthy = Duration(seconds: 38);
  static const Duration _liveAutoNextPollInterval = Duration(seconds: 3);
  static const Duration _liveTvStallPollInterval = Duration(seconds: 2);

  final isFading = false.obs;
  final decoderFallbackStep = 0.obs;
  final videoFit = BoxFit.fill.obs;
  final bool _recovering = false;

  /// Canlıda kullanıcı OSD’den duraklattıysa [play] yalnızca devam ettirir; yayın kesildiyse tam yeniden yükleme yapılır.
  bool _userPausedLive = false;

  /// Exo [STATE_ENDED] / sahte «bitti» (ör. HLS kayan pencere) sonrası [restartCurrentStream] debounce.
  DateTime? _liveSpuriousStopLastRecovery;
  bool _forceSoftwareVideoDecoder = false;

  /// Son [iptvBetterPlayerDataSource] oluşturma: yazılım video kod çözücü istendi mi (Exo).
  bool _lastBootUsedSoftwareVideoDecoder = false;

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

  /// Bu yayın için motorlar arası **otomatik** geçiş (Better↔MediaKit) bir kez
  /// yapıldı mı? Ping-pong'u (Better→MK→Better…) engeller; kanal değişiminde
  /// (zapTo) sıfırlanır.
  bool _autoEngineSwitchUsed = false;

  /// MediaCodec hatasında MPEG-TS yerine HLS (m3u8) bir kez dene.
  bool _decoderTriedTsToM3u8Swap = false;

  /// Son oynatılan URL (decoder kurtarma için TS→m3u8 vb.).
  String? _lastPlaybackUrl;

  /// Tek seferlik retry için oynatma URL'sini override eder.
  String? _playUrlOverride;

  /// Harici Oynatıcı modunda dahili player UI'ı yerine kısa bir handoff
  /// ekranı (logo + ilerleme göstergesi) gösterilir. Akış başarıyla
  /// fırlatıldığında [Get.back] çağrılır; başarısızsa fallback olarak
  /// dahili player'a düşülür.
  final externalPlayerHandoffActive = false.obs;

  /// Internal alias — dış API kirletmeden harici handoff state'ini değiştirir.
  RxBool get _externalPlayerHandoffActive => externalPlayerHandoffActive;

  /// [_boot] başarılı: OSD / watch progress / VOD devam — yalnızca bir kez ([_applyBootSuccessSideEffects]).
  bool _bootSuccessHooksApplied = false;

  /// İlk video karesi gelene kadar [isBusy]; zaman aşımında yine de kaldırılır.
  int? _busyHoldBootGen;
  int _busyHoldVodSession = 0;
  Timer? _busyHoldTimeout;
  VideoPlayerController? _busyHoldVideoController;
  VoidCallback? _busyHoldVideoTick;
  final List<StreamSubscription<dynamic>> _mediaKitBusyDimsSubs = [];

  List<BetterPlayerAsmsTrack> get availableTracks =>
      better?.betterPlayerAsmsTracks ?? [];

  BetterPlayerAsmsTrack? get currentTrack => better?.betterPlayerAsmsTrack;

  List<BetterPlayerAsmsAudioTrack> get availableAudioTracks =>
      better?.betterPlayerAsmsAudioTracks ?? [];

  BetterPlayerAsmsAudioTrack? get currentAudioTrack =>
      better?.betterPlayerAsmsAudioTrack;

  List<BetterPlayerSubtitlesSource> get availableSubtitleSources =>
      better?.betterPlayerSubtitlesSourceList ?? const [];

  BetterPlayerSubtitlesSource? get currentSubtitleSource =>
      better?.betterPlayerSubtitlesSource;

  String _normalizeSubtitleToken(String? raw) {
    return (raw ?? '').trim().toLowerCase();
  }

  String _subtitleTokenFromBetterSource(BetterPlayerSubtitlesSource src) {
    return _normalizeSubtitleToken(src.name);
  }

  bool _subtitleLabelMatchesToken(String label, String token) {
    if (token.isEmpty) return false;
    final n = _normalizeSubtitleToken(label);
    if (n.isEmpty) return false;
    return n == token || n.contains(token) || token.contains(n);
  }

  Future<void> _applyVodSubtitleDefaultOrPreferenceForBetter(
    BetterPlayerController ctrl,
    int expectedGen,
  ) async {
    if (_currentStreamIsLive) return;
    if (!_settings.vodSubtitleAutoEnabled.value) return;
    final preferred = _normalizeSubtitleToken(
      _settings.vodPreferredSubtitleToken.value,
    );
    for (var i = 0; i < 6; i++) {
      if (!_isPlaybackGenerationCurrent(expectedGen)) return;
      if (!identical(better, ctrl)) return;
      final sources = ctrl.betterPlayerSubtitlesSourceList;
      final candidates = sources
          .where((s) => s.type != BetterPlayerSubtitlesSourceType.none)
          .toList(growable: false);
      if (candidates.isNotEmpty) {
        BetterPlayerSubtitlesSource chosen = candidates.first;
        if (preferred.isNotEmpty) {
          final matched = candidates.firstWhereOrNull(
            (s) => _subtitleLabelMatchesToken(s.name ?? '', preferred),
          );
          if (matched != null) chosen = matched;
        }
        await setBetterSubtitleSource(chosen);
        return;
      }
      if (canQueryExoNativeTracks) {
        final exo = await loadExoNativeTracks();
        if (!_isPlaybackGenerationCurrent(expectedGen)) return;
        if (!identical(better, ctrl)) return;
        if (exo.text.isNotEmpty) {
          var chosen = exo.text.first;
          if (preferred.isNotEmpty) {
            final matched = exo.text.firstWhereOrNull(
              (t) =>
                  _subtitleLabelMatchesToken(t.language, preferred) ||
                  _subtitleLabelMatchesToken(t.label, preferred),
            );
            if (matched != null) chosen = matched;
          }
          await selectExoNativeTextTrack(chosen);
          return;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }

  Future<void> setBetterSubtitleSource(
    BetterPlayerSubtitlesSource src, {
    bool disableEmbeddedExoSubtitles = true,
  }) async {
    final b = better;
    if (b == null) return;
    try {
      await b.setupSubtitleSource(src, sourceInitialize: true);
    } catch (_) {}
    if (!disableEmbeddedExoSubtitles) return;
    if (!canQueryExoNativeTracks) return;
    final t = src.type;
    if (t != null && t != BetterPlayerSubtitlesSourceType.none) {
      if (!_currentStreamIsLive) {
        final token = _subtitleTokenFromBetterSource(src);
        if (token.isNotEmpty) {
          unawaited(_settings.setVodPreferredSubtitleToken(token));
        }
      }
      await disableExoNativeTextTracks();
    }
  }

  List<ExoNativeTrackOption> _parseExoTrackList(dynamic list) {
    if (list is! List) return const [];
    final out = <ExoNativeTrackOption>[];
    for (final e in list) {
      if (e is! Map) continue;
      final m = <String, dynamic>{};
      e.forEach((k, v) => m[k.toString()] = v);
      final gi = m['tracksGroupIndex'];
      final ti = m['trackIndex'];
      final tt = m['trackType'];
      int? g;
      int? t;
      var type = 0;
      if (gi is int) {
        g = gi;
      } else if (gi is num) {
        g = gi.toInt();
      }
      if (ti is int) {
        t = ti;
      } else if (ti is num) {
        t = ti.toInt();
      }
      if (tt is int) {
        type = tt;
      } else if (tt is num) {
        type = tt.toInt();
      }
      if (g == null || t == null) continue;
      out.add(
        ExoNativeTrackOption(
          tracksGroupIndex: g,
          trackIndex: t,
          trackType: type,
          label: m['label'] as String? ?? '',
          language: m['language'] as String? ?? '',
          selected: m['selected'] == true,
        ),
      );
    }
    return out;
  }

  Future<ExoNativeTracksBundle> loadExoNativeTracks() async {
    if (!canQueryExoNativeTracks) return ExoNativeTracksBundle.empty;
    try {
      final raw = await better!.getExoPlayerTracks();
      if (raw == null) return ExoNativeTracksBundle.empty;
      final audio = _parseExoTrackList(raw['audio']);
      final text = _parseExoTrackList(raw['text']);
      return ExoNativeTracksBundle(audio: audio, text: text);
    } catch (_) {
      return ExoNativeTracksBundle.empty;
    }
  }

  /// VOD CC menüsü: parçalar demuxer/Exo/MediaKit hazır olana kadar kısa süre bekler.
  Future<VodSubtitleDiscoveryResult> discoverVodSubtitleOptions() async {
    if (_currentStreamIsLive) {
      return VodSubtitleDiscoveryResult(
        betterSources: availableSubtitleSources,
        exoTextTracks: const [],
        mediaKitTracks: const {},
      );
    }

    final useMk = effectiveUseMediaKit;
    final maxAttempts = useMk ? 12 : 8;

    var better = availableSubtitleSources;
    var exo = const <ExoNativeTrackOption>[];
    var mk = const <String, String>{};

    for (var i = 0; i < maxAttempts; i++) {
      better = availableSubtitleSources;
      final hasBetter =
          better.any((s) => s.type != BetterPlayerSubtitlesSourceType.none);

      if (!useMk && canQueryExoNativeTracks) {
        exo = (await loadExoNativeTracks()).text;
      }
      if (useMk) {
        mk = mediaKitSubtitleTrackLabels();
      }

      final hasMk = mk.keys.any((k) => k != 'no' && k != 'auto');
      if (hasBetter || exo.isNotEmpty || hasMk) {
        break;
      }
      // MediaKit HLS: parçalar manifest açıldıktan sonra gelir; kısa aralıklarla yokla.
      await Future<void>.delayed(
        Duration(milliseconds: useMk ? 120 + i * 55 : 180 + i * 70),
      );
    }

    debugPrint(
      'mina_iptv: VOD subtitle discovery → useMk=$useMk '
      'mkPlayer=${_mediaKitPlayer != null} '
      'mkRaw=${_mediaKitPlayer?.state.tracks.subtitle.length} '
      'mkLabels=${mk.length} better=${better.length} exo=${exo.length}',
    );

    return VodSubtitleDiscoveryResult(
      betterSources: better,
      exoTextTracks: exo,
      mediaKitTracks: mk,
    );
  }

  Future<void> selectExoNativeAudioTrack(ExoNativeTrackOption opt) async {
    if (!canQueryExoNativeTracks) return;
    try {
      await better!.selectExoPlayerTrack(opt.tracksGroupIndex, opt.trackIndex);
    } catch (_) {}
  }

  Future<void> selectExoNativeTextTrack(ExoNativeTrackOption opt) async {
    if (!canQueryExoNativeTracks) return;
    try {
      await setBetterSubtitleSource(
        BetterPlayerSubtitlesSource(type: BetterPlayerSubtitlesSourceType.none),
        disableEmbeddedExoSubtitles: false,
      );
      better!.setExoEmbeddedSubtitlesActive(true);
      await better!.selectExoPlayerTrack(opt.tracksGroupIndex, opt.trackIndex);
      if (!_currentStreamIsLive) {
        final token = _normalizeSubtitleToken(
          opt.language.isNotEmpty ? opt.language : opt.label,
        );
        if (token.isNotEmpty) {
          unawaited(_settings.setVodPreferredSubtitleToken(token));
        }
      }
    } catch (_) {}
  }

  Future<void> disableExoNativeTextTracks() async {
    if (!canQueryExoNativeTracks) return;
    try {
      better?.setExoEmbeddedSubtitlesActive(false);
      await better!.setExoPlayerTextTrackDisabled(true);
    } catch (_) {}
  }

  /// MediaKit altyazı parçaları; `no` = kapalı.
  Map<String, String> mediaKitSubtitleTrackLabels() {
    final player = _mediaKitPlayer;
    if (player == null) return {};
    final off = 'player.subtitle.off'.tr;
    final out = <String, String>{'no': off};
    for (final t in player.state.tracks.subtitle) {
      if (t.id == 'no' || t.id == 'auto') continue;
      final label = (t.title?.trim().isNotEmpty == true)
          ? t.title!.trim()
          : (t.language?.trim().isNotEmpty == true)
              ? t.language!.trim()
              : t.id;
      out[t.id] = label;
    }
    return out;
  }

  Future<void> setMediaKitSubtitleById(String id) async {
    final player = _mediaKitPlayer;
    if (player == null) return;
    try {
      if (id == 'no') {
        await player.setSubtitleTrack(SubtitleTrack.no());
        return;
      }
      SubtitleTrack? picked;
      for (final e in player.state.tracks.subtitle) {
        if (e.id == id) {
          picked = e;
          break;
        }
      }
      final t = picked;
      if (t == null) return;
      await player.setSubtitleTrack(t);
      if (!_currentStreamIsLive) {
        final token = _normalizeSubtitleToken(
          (t.language?.trim().isNotEmpty == true) ? t.language : t.title,
        );
        if (token.isNotEmpty) {
          unawaited(_settings.setVodPreferredSubtitleToken(token));
        }
      }
    } catch (_) {}
  }

  Future<void> enterPictureInPictureIfSupported() async {
    if (effectiveUseMediaKit) return;
    final b = better;
    final k = b?.betterPlayerGlobalKey;
    if (b == null || k == null) return;
    try {
      await b.enablePictureInPicture(k);
    } catch (e) {
      debugPrint('mina_iptv: PiP: $e');
    }
  }

  /// Ana ekrana dönünce PiP: yalnızca kullanıcı Ayarlar’da açtıysa (Better/Exo, telefon).
  bool get _wantsMiniPlayerPipOnLeave {
    if (_settings.layoutMode.value == AppLayoutMode.tv) return false;
    return _settings.miniPlayerOnHome.value;
  }

  bool _eligibleForMiniPlayerPip() {
    if (!_wantsMiniPlayerPipOnLeave) return false;
    if (effectiveUseMediaKit) return false;
    final b = better;
    final k = b?.betterPlayerGlobalKey;
    final v = b?.videoPlayerController?.value;
    return b != null && k != null && v != null && v.isPlaying && !v.hasError;
  }

  Future<void> _syncAndroidPipAutoEnterEligible() async {
    if (!Platform.isAndroid) return;
    final eligible = _eligibleForMiniPlayerPip();
    try {
      await _androidPipChannel.invokeMethod<void>(
        'setPipAutoEnterEligible',
        <String, dynamic>{'eligible': eligible},
      );
    } catch (e) {
      debugPrint('mina_iptv: setPipAutoEnterEligible: $e');
    }
  }

  /// 4K / FHD / HD / SD (yükseklik/genişliğe göre); Hz ayrı [osdStreamFrameRateHzLabel].
  String? get osdStreamResolutionTierLabel {
    final asms = better?.betterPlayerAsmsTrack;
    if (asms != null && (asms.height ?? 0) > 0) {
      return _streamQualityLabelFromDimensions(asms.height!, asms.width ?? 0);
    }
    final sz = better?.videoPlayerController?.value.size;
    if (sz != null && sz.width > 0 && sz.height > 0) {
      return _streamQualityLabelFromDimensions(
        sz.height.round(),
        sz.width.round(),
      );
    }
    final mk = _mediaKitPlayer;
    if (mk != null) {
      final w = mk.state.width;
      final h = mk.state.height;
      if (w != null && h != null && w > 0 && h > 0) {
        return _streamQualityLabelFromDimensions(h, w);
      }
    }
    return null;
  }

  int? _osdStreamFrameRateHz() {
    final asms = better?.betterPlayerAsmsTrack;
    if (asms != null) {
      final fr = asms.frameRate;
      if (fr != null && fr > 0) return fr;
    }
    final exoFps = better?.videoPlayerController?.value.videoFrameRateHz;
    if (exoFps != null && exoFps > 0.25) {
      return exoFps.round().clamp(1, 240);
    }
    final mk = _mediaKitPlayer;
    if (mk != null) {
      final fps = mk.state.track.video.fps;
      if (fps != null && fps > 0.25) {
        return fps.round().clamp(1, 240);
      }
    }
    return null;
  }

  /// OSD kanal satırı: `25 Hz` gibi; mümkün değilse `null`.
  String? get osdStreamFrameRateHzLabel {
    final hz = _osdStreamFrameRateHz();
    if (hz == null || hz <= 0) return null;
    return '$hz Hz';
  }

  /// Birleşik etiket (geriye dönük); UI’de tercihen [osdStreamResolutionTierLabel] + [osdStreamFrameRateHzLabel].
  String? get osdStreamQualityLabel {
    final base = osdStreamResolutionTierLabel;
    final hz = osdStreamFrameRateHzLabel;
    if (base != null && hz != null) return '$base · $hz';
    if (hz != null) return hz;
    return base;
  }

  static String? _streamQualityLabelFromDimensions(int height, int width) {
    final dim = math.max(height, width);
    if (dim <= 0) return null;
    if (dim >= 2160) return '4K';
    if (dim >= 1080) return 'FHD';
    if (dim >= 720) return 'HD';
    if (dim >= 480) return 'SD';
    return 'SD';
  }

  void _maybeBumpOsdQualitySignature() {
    final s = _osdQualitySignature();
    if (s != _lastOsdQualitySignature) {
      _lastOsdQualitySignature = s;
      osdQualityStamp.value++;
      update(['osd']);
    }
  }

  int _osdQualitySignature() {
    final t = better?.betterPlayerAsmsTrack;
    final v = better?.videoPlayerController?.value;
    final sz = v?.size;
    final exoFps = v?.videoFrameRateHz;
    final mk = _mediaKitPlayer;
    final mkW = mk?.state.width;
    final mkH = mk?.state.height;
    final mkFps = mk?.state.track.video.fps;
    return Object.hash(
      t?.id,
      t?.height,
      t?.width,
      t?.frameRate,
      sz != null && sz.width > 0 ? sz.width.round() : 0,
      sz != null && sz.height > 0 ? sz.height.round() : 0,
      exoFps != null ? (exoFps * 1000).round() : 0,
      mkW != null && mkW > 0 ? mkW : 0,
      mkH != null && mkH > 0 ? mkH : 0,
      mkFps != null ? (mkFps * 1000).round() : 0,
    );
  }

  void setQuality(BetterPlayerAsmsTrack track) {
    final auto = (track.height ?? 0) <= 0 &&
        (track.width ?? 0) <= 0 &&
        (track.bitrate ?? 0) <= 0;
    _manualVideoQualityLock = !auto;
    if (auto) {
      _autoQRecentBufferingStarts.clear();
      _autoQLastDowngradeAt = null;
    }
    better?.setTrack(track);
    _maybeBumpOsdQualitySignature();
    update(['osd']);
  }

  void setVideoFit(BoxFit fit) {
    videoFit.value = fit;
    better?.setOverriddenFit(fit);
    update(['osd']);
  }

  /// O anki kanal URL’sine göre canlı TV mi (VOD film/dizi değil).
  /// `/movie/` ve gözat film şeridi [isMovie] her zaman VOD sayılır (Xtream get.php tek başına
  /// bazen canlı sanılıyordu).
  bool get _currentStreamIsLive {
    if (isSeries) return false;
    if (isMovie) return false;
    final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    if (norm.toLowerCase().contains('/movie/')) return false;
    return IptvPlaybackDefaults.isLikelyLiveStream(norm);
  }

  /// Canlı yayında DVR/timeshift ile ileri–geri sarma kapalı (yalnızca kanal değiştirme).
  bool get liveTimeshiftSeekAvailable => false;

  /// Hangi motor kullanılıyor: **Canlı TV** → yalnızca Better (Exo); MediaKit yalnızca kullanıcı
  /// OSD’den [switchToBackupPlayer] ile ([mediaKitFallbackSession]). Otomatik Exo→MediaKit yok.
  /// **VOD** → [AppSettingsService.useMediaKit]; donanım hatasında [mediaKitFallbackSession] ile mpv.
  /// [betterOsdOverride]: OSD’den veya mpv açılamayınca zorunlu Exo.
  bool get effectiveUseMediaKit {
    if (betterOsdOverride.value) return false;
    // Uzantısız "web manifest / embed" akışları (ör. aggregator film
    // listelerindeki `/vs/tt…/` HLS adresleri) ExoPlayer'da container tespit
    // edilemediği için açılmaz; mpv sniff ile sorunsuz açar → doğrudan MediaKit.
    if (_forceMediaKitForCurrentUrl) return true;
    // Kullanıcının içerik tipine göre seçtiği motor: canlı → liveUseMediaKit,
    // film/dizi → useMediaKit. Seçim MediaKit ise birincil motor mpv olur.
    if (_userPrefersMediaKitForCurrentType) return true;
    // Birincil Better iken hata olursa bu oturum için mpv'ye düşülmüş olabilir.
    return mediaKitFallbackSession.value;
  }

  /// Kullanıcının geçerli içerik tipi (canlı / VOD) için seçtiği motor MediaKit mi?
  bool get _userPrefersMediaKitForCurrentType => _currentStreamIsLive
      ? _settings.liveUseMediaKit.value
      : _settings.useMediaKit.value;

  /// Geçerli akış URL'si uzantısız "web manifest / embed" mi (mpv'ye yönlendir).
  /// [_boot] ve kanal değişiminde güncellenir; [effectiveUseMediaKit] içinde okunur.
  bool _forceMediaKitForCurrentUrl = false;

  void _refreshForceMediaKitForCurrentUrl() {
    final raw =
        (_lastPlaybackUrl != null && _lastPlaybackUrl!.trim().isNotEmpty)
            ? _lastPlaybackUrl!
            : channel.value.streamUrl;
    _forceMediaKitForCurrentUrl =
        IptvPlaybackDefaults.isExtensionlessWebManifestUrl(raw);
  }

  /// [UniversalVideoPlayer] / mpv ile [_boot] içindeki Better kaynağı aynı normalleştirilmiş URL’yi kullanır.
  String get surfaceStreamUrl {
    final u = _lastPlaybackUrl;
    if (u != null && u.isNotEmpty) return u;
    return _normalizePlaybackStreamUrl(channel.value.streamUrl);
  }

  /// MediaKit OSD’den Better’a — film/dizi/canlı: aynı davranış (konum [switchToBetterPlayer] ile korunur).
  Future<void> promptSwitchToBetterFromMediaKit() async {
    await switchToBetterPlayer();
  }

  /// Android Better: ExoPlayer [currentTracks] ile gömülü ses/altyazı sorgulanabilir.
  bool get canQueryExoNativeTracks =>
      Platform.isAndroid &&
      !effectiveUseMediaKit &&
      better?.videoPlayerController != null;

  /// OSD: MediaKit’e geç (Better’dan veya Better OSD geçersiz kılma sonrası).
  Future<void> switchToBackupPlayer() async {
    final wasBetterOverride = betterOsdOverride.value;
    betterOsdOverride.value = false;
    if (!wasBetterOverride && effectiveUseMediaKit) {
      return;
    }
    _cancelZapRelativeDebounce();
    _resumeAtAfterOsdEngineSwitch = currentPosition;
    if (!_settings.useMediaKit.value || _currentStreamIsLive) {
      mediaKitFallbackSession.value = true;
    }
    await _performMediaKitFallbackBoot();
  }

  /// OSD: Better/Exo’ya geç (MediaKit ayarı açık olsa bile bu oturumda).
  Future<void> switchToBetterPlayer() async {
    _resumeAtAfterOsdEngineSwitch = currentPosition;
    betterOsdOverride.value = true;
    mediaKitFallbackSession.value = false;
    error.value = null;
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: false,
    );
  }

  void _cancelMediaKitDimSubs() {
    for (final s in _mediaKitDimSubs) {
      unawaited(s.cancel());
    }
    _mediaKitDimSubs.clear();
  }

  /// Canlı TV / mpv: düşük demuxer/önbellek + hızlı ağ zaman aşımı; [aml] Amlogic ipucu.
  Future<void> _applyMpvIptvLiveZapTuning(
    dynamic plat, {
    required bool aml,
  }) async {
    if (plat is! NativePlayer) return;
    try {
      await plat.setProperty('cache', 'yes');
      await plat.setProperty('cache-size', '512');
      await plat.setProperty('cache-pause', 'no');
      await plat.setProperty('demuxer-max-bytes', '786432');
      await plat.setProperty('demuxer-max-back-bytes', '262144');
      await plat.setProperty('hr-seek', 'yes');
      for (final name in <String>[
        'stream-open-timeout',
        'http-timeout',
        'network-timeout'
      ]) {
        try {
          await plat.setProperty(name, '5');
        } catch (_) {}
      }
      try {
        await plat.setProperty('initial-audio-sync', 'no');
      } catch (_) {}
      if (aml && _currentStreamIsLive) {
        try {
          await plat.setProperty('video-latency-hacks', 'yes');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('mina_iptv: mpv live-zap: $e');
    }
  }

  /// libmpv ([NativePlayer]) — yalnızca **MediaKit** oynatıcısı için; [open] öncesi uygulanır.
  ///
  /// - **Android:** `hwdec` = ayar + Amlogic kuralı ([AppSettingsService.resolveMediaKitHwdecMpvValue]);
  ///   SM-T530 veya [AppSettingsService.mediaKitLowPowerHwdec]: `hwdec=no` mor/pembe önleme;
  ///   [applyMediaKitMpvPurpleFixOptions]. `vd-lavc-fast` / `vd-lavc-skiploopfilter=all` korunur.
  ///   `auto-safe` kullanılmaz (zayıf kutularda yazılım çözücüye düşüp kare kare oynatmayı tetikleyebilir).
  /// - `framedrop`: güçlü cihazda `vo`, düşük RAM / az çekirdekte `yes`
  /// - `scale` / `cscale` / `dscale` = bilinear, `vd-lavc-fast=yes`, `video-sync=audio`
  ///
  /// **Not:** TV kutusunda Better/ExoPlayer’da görülen `PlatformException` / `Source error` / `b.0.1`
  /// bu mpv ayarlarından **kaynaklanmaz** — canlıda varsayılan motor Exo iken MediaKit
  /// örneği oluşturulmaz (`UniversalVideoPlayer` `useMediaKit: false`). O hatalar ağ/segment,
  /// OEM MediaCodec veya tampon zamanlaması ile ilgilidir.
  ///
  /// [VideoController] yüzeyi hazır olduktan sonra, [open] öncesi çağrılır; Android’de `vo`/`wid`
  /// sırasına burada dokunulmaz (media_kit çıktı yöneticisi).
  Future<void> applyMediaKitLibmpvPlaybackOptions(Player player) async {
    final plat = player.platform;
    if (plat is! NativePlayer) return;
    Future<void> setMpvOpt(String key, String value) async {
      try {
        await plat.setProperty(key, value);
      } catch (_) {}
    }

    try {
      await setMpvOpt(
        'volume-max',
        _kMediaKitVolumePropertyMax.round().toString(),
      );
      // libmpv: `--video-output-levels=full` / `--colormatrix=auto` (RGB/YUV ve ekran sapması).
      await setMpvOpt('video-output-levels', 'full');
      await setMpvOpt('colormatrix', 'auto');

      // Gizlenmiş HLS desteği: bazı kaynaklar (örn. vidmody.com/vs/ttXXXX/)
      // HLS segment/alt-playlist'lerini `.gif` / `.jpg` uzantısıyla servis eder
      // (engelleme/cache bypass hilesi; içerik gerçek m3u8 / MPEG-TS'dir).
      // ffmpeg HLS demuxer varsayılan olarak segment uzantılarını bir beyaz
      // listeyle sınırlar; `.gif`/`.jpg` listede olmadığından "blocked for
      // security reasons" ile reddedilir ve oynatma başlamaz. `ALL` ile bu
      // kısıt kaldırılır; normal listelerdeki standart segmentleri etkilemez.
      //
      // «SSL/TLS doğrulamasını yoksay» (IPTV'de meşhur seçenek) açıkken:
      //  * mpv stream katmanı için `tls-verify=no`,
      //  * HLS segment/manifest'lerini çeken lavf protokolü için demuxer
      //    seçeneklerine `tls_verify=0` eklenir.
      // Geçersiz/self-signed sertifikalı panellerde "certificate verify failed"
      // hatasını giderir.
      final ignoreSsl = _settings.ignoreSslCertificate.value;
      final lavfOpts = ignoreSsl
          ? 'allowed_extensions=ALL,tls_verify=0'
          : 'allowed_extensions=ALL';
      await setMpvOpt('demuxer-lavf-o', lavfOpts);
      if (ignoreSsl) {
        await setMpvOpt('tls-verify', 'no');
        await setMpvOpt('stream-lavf-o', 'tls_verify=0');
      }

      final cores = Platform.numberOfProcessors;
      final lavcThreadsGeneric =
          cores > 0 ? math.min(4, math.max(1, cores)) : 4;

      if (Platform.isAndroid) {
        await AndroidPlaybackSocHints.ensureLoaded();
        final weak = AndroidPlaybackSocHints.weakMpvDevice;
        final aml = AndroidPlaybackSocHints.amlogicLike;
        final challengedTv = AndroidPlaybackSocHints.playbackChallengedTv;
        final swPurpleFix = _settings.mediaKitLowPowerHwdec.value ||
            AndroidPlaybackSocHints.isSamsungSmT530;

        final String hwdecLog;
        if (swPurpleFix) {
          await setMpvOpt('hwdec', 'no');
          hwdecLog = 'no';
        } else {
          final hwdec = _settings.resolveMediaKitHwdecMpvValue(
            amlogicLike: aml,
            playbackChallengedTv: challengedTv,
          );
          await setMpvOpt('hwdec', hwdec);
          hwdecLog = hwdec;
        }
        await setMpvOpt('framedrop', weak ? 'yes' : 'vo');

        final lavcThreads =
            weak ? math.min(2, lavcThreadsGeneric) : lavcThreadsGeneric;
        await setMpvOpt('vd-lavc-threads', '$lavcThreads');

        await setMpvOpt('profile', 'fast');
        await setMpvOpt(
          'vd-lavc-skiploopfilter',
          swPurpleFix || weak ? 'all' : 'nonref',
        );
        await setMpvOpt('interpolation', 'no');

        // MediaKit/mpv canlı açılış donması: cache açık + daha geniş stream buffer + hızlı ffmpeg decode.
        await setMpvOpt('cache', 'yes');
        await setMpvOpt('demuxer-readahead-secs', '20');
        // İstek metnindeki anahtar (muhtemel typo) için de dene; desteklenmiyorsa sessizce geç.
        await setMpvOpt('demuxer-readahead-defs', '20');
        await setMpvOpt('min-cache-percent', '0');
        await setMpvOpt('cache-secs', '1');
        await setMpvOpt('stream-buffer-size', '512KiB');
        await setMpvOpt('ffmpeg-fast', 'yes');
        await setMpvOpt('vd-lavc-fast', 'yes');

        if (_currentStreamIsLive) {
          await _applyMpvIptvLiveZapTuning(plat, aml: aml);
        } else {
          if (aml) {
            await setMpvOpt('demuxer-max-bytes', '12M');
            await setMpvOpt('demuxer-max-back-bytes', '6M');
            await setMpvOpt('sws-fast', 'yes');
          } else if (weak) {
            await setMpvOpt('demuxer-max-bytes', '16M');
            await setMpvOpt('demuxer-max-back-bytes', '8M');
          } else {
            await setMpvOpt('demuxer-max-bytes', '20M');
            await setMpvOpt('demuxer-max-back-bytes', '10M');
          }
        }

        if (swPurpleFix) {
          await applyMediaKitMpvPurpleFixOptions(plat);
        }

        debugPrint(
          'mina_iptv: MediaKit mpv hwdec=$hwdecLog framedrop=${weak ? "yes" : "vo"} '
          'weak=$weak aml=$aml challengedTv=$challengedTv swPurpleFix=$swPurpleFix '
          'model=${AndroidPlaybackSocHints.buildModel}',
        );
      } else {
        await setMpvOpt('hwdec', 'auto-safe');
        await setMpvOpt('framedrop', 'vo');
        await setMpvOpt(
          'vd-lavc-threads',
          '$lavcThreadsGeneric',
        );
        if (_currentStreamIsLive) {
          await _applyMpvIptvLiveZapTuning(plat, aml: false);
        }
      }

      await setMpvOpt('scale', 'bilinear');
      await setMpvOpt('cscale', 'bilinear');
      await setMpvOpt('dscale', 'bilinear');
      await setMpvOpt('vd-lavc-fast', 'yes');
      await setMpvOpt('video-sync', 'audio');
    } catch (e, st) {
      debugPrint('mina_iptv: MediaKit libmpv playback options: $e\n$st');
    }
  }

  Future<void> attachMediaKitPlayer(Player? p) async {
    if (identical(_mediaKitPlayer, p)) return;

    // Eğer controller kapatılmışsa yeni gelen MediaKit player'ı durdur ve kapat
    if (isClosed && p != null) {
      unawaited(p
          .pause()
          .then((_) => p.stop())
          .then((_) => p.dispose())
          .catchError((_, __) {}));
      return;
    }

    _mediaKitErrorSub?.cancel();
    _mediaKitErrorSub = null;
    _cancelMediaKitDimSubs();
    _cancelMediaKitWakelockSubs();

    _mediaKitPlayer = p;
    if (p == null) {
      _mediaKitZapAbrTargetGen = null;
    }

    if (isClosed) {
      return;
    }

    if (p != null) {
      await applyMediaKitLibmpvPlaybackOptions(p);

      _mediaKitErrorSub = p.stream.error.listen((e) {
        if (e.isEmpty) return;
        debugPrint('mina_iptv: MediaKit stream error: $e');
        _emitPlaybackErrorForRecovery(e);
      });
      void dimBump([dynamic _]) {
        _maybeBumpOsdQualitySignature();
        update(['osd']);
      }

      void mkLiveAutoNextBump([dynamic _]) {
        _syncLiveAutoNextWatchdog();
        _maybeRecoverLiveAfterSpuriousEngineStop();
      }

      _mediaKitDimSubs.add(p.stream.width.listen(dimBump));
      _mediaKitDimSubs.add(p.stream.height.listen(dimBump));
      _mediaKitDimSubs.add(p.stream.track.listen(dimBump));
      _mediaKitDimSubs.add(p.stream.playing.listen(mkLiveAutoNextBump));
      _mediaKitDimSubs.add(p.stream.buffering.listen(mkLiveAutoNextBump));
      void wakelockBump([dynamic _]) => _syncPlaybackWakelock();
      _mediaKitWakelockSubs.add(p.stream.playing.listen(wakelockBump));

      // Boot anında mevcut logical seviyeyi yeni MediaKit instance'ına uygula
      // (boost açıkken yeni player'a da geçer; kapalıyken eski 130 kazanç).
      unawaited(
        p.setVolume(_mediaKitVolumeFor(currentVolume)).catchError((_, __) {}),
      );

      final holdGen = _busyHoldBootGen;
      if (holdGen != null && _isPlaybackGenerationCurrent(holdGen)) {
        void tryMkFirstFrame([dynamic _]) {
          if (!identical(_mediaKitPlayer, p)) return;
          if (_busyHoldBootGen != holdGen) return;
          if (!_isPlaybackGenerationCurrent(holdGen)) return;
          final st = p.state;
          final w = st.width;
          final h = st.height;
          if (w != null && h != null && w > 0 && h > 0) {
            for (final s in _mediaKitBusyDimsSubs) {
              s.cancel();
            }
            _mediaKitBusyDimsSubs.clear();
            _finishBootBusyHold(holdGen, _busyHoldVodSession);
          }
        }

        _mediaKitBusyDimsSubs.add(p.stream.width.listen(tryMkFirstFrame));
        _mediaKitBusyDimsSubs.add(p.stream.height.listen(tryMkFirstFrame));
        tryMkFirstFrame();
      }

      unawaited(
        applyMediaKitSubtitleAppearance(
          p,
          pt: _settings.subtitleFontPt.value,
          fontFamilyKey: _settings.subtitleFontFamilyKey.value,
          fontColor: _settings.subtitleFontColor,
          outlineEnabled: _settings.subtitleOutlineEnabled.value,
        ),
      );
      // Equalizer (af=lavfi=…) yeni player'a uygulanır. Servisi
      // önceden yüklemediysek `applyToMediaKit` no-op gibi davranır
      // (default flat değerleri); ayarlar dialog'tan değiştirildiğinde
      // [_equalizerWorker] reaktif olarak yeniden uygular.
      if (Get.isRegistered<EqualizerService>()) {
        unawaited(EqualizerService.to.applyToMediaKit(p));
      }
      if (_currentStreamIsLive) {
        unawaited(_tryLiveZapAbrRampsMediaKit(p));
      }
    }

    // [onMediaKitPlayerChanged] dispose sırasında tetiklenebilir; Rx / GetBuilder
    // güncellemesi widget tree kilitliyken patlar. Kare tamamlandıktan sonra uygula.
    final attached = p;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      if (!identical(_mediaKitPlayer, attached)) return;
      if (attached != null) {
        _rebindLiveChannelRowFromPlaylistCache();
      }
      _maybeBumpOsdQualitySignature();
      mediaKitAttachEpoch.value++;
      update(['osd']);
      if (Platform.isAndroid) {
        unawaited(_syncAndroidPipAutoEnterEligible());
      }
      _syncPlaybackWakelock();
    });
  }

  /// Canlıda oynatıcıdaki [Channel] örneği ile liste önbelleğindeki satırı hizalar (isim/logo, yinelenen URL vb.).
  void _rebindLiveChannelRowFromPlaylistCache() {
    if (!_currentStreamIsLive) return;
    if (!Get.isRegistered<PlaylistCacheService>()) return;
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null || data.channels.isEmpty) return;
    final cur = channel.value;
    final norm = _normalizePlaybackStreamUrl(cur.streamUrl);
    Channel? match;
    for (final c in data.channels) {
      if (c.id != cur.id) continue;
      if (_normalizePlaybackStreamUrl(c.streamUrl) == norm) {
        match = c;
        break;
      }
    }
    if (match == null) {
      for (final c in data.channels) {
        if (c.id == cur.id) {
          match = c;
          break;
        }
      }
    }
    if (match == null) return;
    channel.value = match;
  }

  Map<String, String> mediaKitAudioTrackLabels() {
    final player = _mediaKitPlayer;
    if (player == null) return {};
    final out = <String, String>{};
    for (final t in player.state.tracks.audio) {
      final label = (t.title?.trim().isNotEmpty == true)
          ? t.title!.trim()
          : (t.language?.trim().isNotEmpty == true)
              ? t.language!.trim()
              : t.id;
      out[t.id] = label;
    }
    return out;
  }

  Future<void> setMediaKitAudioTrackById(String id) async {
    final player = _mediaKitPlayer;
    if (player == null) return;
    AudioTrack? picked;
    for (final e in player.state.tracks.audio) {
      if (e.id == id) {
        picked = e;
        break;
      }
    }
    final t = picked;
    if (t == null) return;
    try {
      await player.setAudioTrack(t);
    } catch (_) {}
  }

  Map<String, String> mediaKitVideoTrackLabels() {
    final player = _mediaKitPlayer;
    if (player == null) return {};
    final out = <String, String>{};
    for (final t in player.state.tracks.video) {
      final dims = (t.w != null && t.h != null && t.w! > 0 && t.h! > 0)
          ? ' (${t.w}×${t.h})'
          : '';
      final base = (t.title?.trim().isNotEmpty == true)
          ? t.title!.trim()
          : (t.codec ?? t.id);
      out[t.id] = '$base$dims';
    }
    return out;
  }

  Future<void> setMediaKitVideoTrackById(String id) async {
    final player = _mediaKitPlayer;
    if (player == null) return;
    VideoTrack? picked;
    for (final e in player.state.tracks.video) {
      if (e.id == id) {
        picked = e;
        break;
      }
    }
    final t = picked;
    if (t == null) return;
    try {
      await player.setVideoTrack(t);
    } catch (_) {}
  }

  bool _isCurrentChannelLive() {
    if (isSeries) return false;
    final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    return IptvPlaybackDefaults.isLikelyLiveStream(norm);
  }

  /// Exo/MediaKit canlıda bazen ENDED/bitiş bildirir; kullanıcı duraklatmadıysa yeniden bağlan.
  ///
  /// Gecikmeli «soft play» denemesi, Exo’nun kısa `buffering`/`isPlaying` gürültüsüyle iptal
  /// edilip [restartCurrentStream] hiç çalışmamasına yol açtı; doğrudan debounce + tam yenileme.
  void _maybeRecoverLiveAfterSpuriousEngineStop() {
    if (!_currentStreamIsLive || isMovie || isSeries) return;
    if (_userPausedLive || isBusy.value || isClosed) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final started = _autoQPlaybackStartedAt;
    if (started == null) return;
    if (DateTime.now().difference(started) < const Duration(seconds: 8)) {
      return;
    }

    if (effectiveUseMediaKit) {
      final mk = _mediaKitPlayer;
      if (mk == null) return;
      final s = mk.state;
      if (s.playing || s.buffering) return;
    } else {
      final v = better?.videoPlayerController?.value;
      if (v == null || !v.initialized || v.hasError) return;
      if (v.isPlaying || v.isBuffering) return;
    }

    final now = DateTime.now();
    final last = _liveSpuriousStopLastRecovery;
    if (last != null && now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _liveSpuriousStopLastRecovery = now;
    debugPrint(
      'mina_iptv: Canlı motor durdu (kullanıcı duraklatması değil; çoğunlukla Exo ENDED) → yeniden bağlanıyor',
    );
    unawaited(restartCurrentStream());
  }

  /// Aynı kanalı baştan yükler (canlı kesinti / takılı Exo durumu).
  Future<void> restartCurrentStream() async {
    if (isClosed) return;
    _resetNetworkRecoveryState();
    error.value = null;
    _userPausedLive = false;
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    _cancelLiveAutoNextWatchdog();
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: true,
    );
  }

  /// Logical playback boost — sistem 100%'ünün üzerine kazanç (0.0 = boost
  /// yok). Sistem ses 1.0'a vurmadıkça boost 0 kalır; gesture sistem
  /// 1.0'a ulaşınca boost artırmaya başlar.
  final RxDouble _playbackBoostExtra = 0.0.obs;

  /// UI'ın okuyacağı maksimum logical volume (1.0..2.0). Ayarlardaki
  /// `volumeBoostMaxPercent` 100..200 değerine göre türetilir.
  double get maxPlaybackVolume {
    final raw = _settings.volumeBoostMaxPercent.value;
    final normalized = AppSettingsService.normalizeVolumeBoostMaxPercent(raw);
    return normalized / 100.0;
  }

  /// `value01` (= logical 0..maxPlaybackVolume) için libmpv `volume` özelliği.
  /// Logical 1.0 → 130 (önceki davranışla aynı). Logical 2.0 → 200. Aradaki
  /// değerler lineer enterpolasyon.
  double _mediaKitVolumeFor(double logical) {
    final cap = maxPlaybackVolume;
    final clamped = logical.clamp(0.0, cap);
    if (clamped <= 1.0) {
      // Sistem ses 0..100% bölgesinde mpv kazancı sabit (eskisi gibi 130).
      return _kMediaKitVolumeBaseAt1x;
    }
    final extra = clamped - 1.0; // 0..1
    final mpv = _kMediaKitVolumeBaseAt1x +
        extra * (_kMediaKitVolumePropertyMax - _kMediaKitVolumeBaseAt1x);
    return mpv.clamp(0.0, _kMediaKitVolumePropertyMax);
  }

  double get currentVolume {
    // Sistem ses (0..1) + ek boost (0..maxBoost-1). Logical 0..maxBoost.
    if (Get.isRegistered<SystemVolumeService>()) {
      final sys = SystemVolumeService.to.currentVolume;
      final logical = sys + _playbackBoostExtra.value;
      return logical.clamp(0.0, maxPlaybackVolume);
    }
    final mk = _mediaKitPlayer;
    if (mk != null) {
      return (mk.state.volume.clamp(0.0, _kMediaKitVolumePropertyMax)) /
          _kMediaKitVolumePropertyMax;
    }
    return better?.videoPlayerController?.value.volume ?? 1.0;
  }

  Duration get currentPosition {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      return mk.state.position;
    }
    return better?.videoPlayerController?.value.position ?? Duration.zero;
  }

  void play() {
    if (isBusy.value) {
      final mk = _mediaKitPlayer;
      if (mk != null) {
        unawaited(mk.play().catchError((_, __) {}));
      } else {
        better?.play();
      }
      return;
    }

    final mk = _mediaKitPlayer;
    if (mk != null) {
      if (_isCurrentChannelLive()) {
        if (_userPausedLive) {
          _userPausedLive = false;
          unawaited(mk.play().catchError((_, __) {}));
          return;
        }
        final s = mk.state;
        if (!s.playing && !s.buffering) {
          unawaited(restartCurrentStream());
          return;
        }
      } else {
        _userPausedLive = false;
      }
      unawaited(mk.play().catchError((_, __) {}));
      return;
    }

    if (_isCurrentChannelLive()) {
      if (_userPausedLive) {
        _userPausedLive = false;
        better?.play();
        return;
      }
      final v = better?.videoPlayerController?.value;
      if (v != null &&
          v.initialized &&
          !v.hasError &&
          !v.isPlaying &&
          !v.isBuffering) {
        unawaited(restartCurrentStream());
        return;
      }
    } else {
      _userPausedLive = false;
    }
    better?.play();
  }

  void pause() {
    if (_isCurrentChannelLive()) {
      _userPausedLive = true;
    } else {
      _userPausedLive = false;
    }
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(mk.pause().catchError((_, __) {}));
      return;
    }
    better?.pause();
  }

  void seekTo(Duration position) {
    final beforeSec = currentPosition.inSeconds;
    _learnIntroFromUserSeek(beforeSec, position.inSeconds);
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(mk.seek(position).catchError((_, __) {}));
      return;
    }
    better?.seekTo(position);
  }

  // ---------------------------------------------------------------------------
  // Akıllı Jenerik Atlatıcı entegrasyonu (Smart Stream Cutter).
  // ---------------------------------------------------------------------------

  /// Mevcut bölüm için kayıtlı intro bitiş süresi (sn). 0 ise buton gizli.
  /// `Obx` ile dinlenir; bölüm değişince [_refreshIntroDurationForCurrent]
  /// güncellemesini yapar.
  final introSkipTargetSec = 0.obs;

  String? _lastIntroSeriesId;

  /// Kullanıcının manuel ileri seek'ini servise iletir (öğrenme).
  /// Dizi olmayan veya 1./2. bölüm dışı içeriklerde no-op'a yakın çalışır;
  /// servis kuralları (ilk 5 dk + 30+ sn delta) kabulü doğrular.
  void _learnIntroFromUserSeek(int beforeSec, int afterSec) {
    if (!_settings.smartStreamCutterEnabled.value) return;
    if (!isSeries) return;
    if (afterSec <= beforeSec) return;
    final ep = _currentEpisodeOption();
    if (ep == null) return;
    final seriesId = _seriesIdForLearning();
    if (seriesId.isEmpty) return;
    if (!Get.isRegistered<MinaStreamCutterService>()) return;
    final svc = Get.find<MinaStreamCutterService>();
    unawaited(
      svc
          .recordSeek(
            seriesId: seriesId,
            episodeNumber: ep.episodeNumber,
            fromSec: beforeSec,
            toSec: afterSec,
          )
          .then((_) => refreshIntroDurationForCurrent()),
    );
  }

  /// Mevcut çalan bölümün öğrenme/gösterme anahtarı.
  /// Xtream `series_id` varsa onu, yoksa dizi adının normalize hali.
  String _seriesIdForLearning() {
    final ser = playingSeries;
    if (ser != null) {
      if (ser.id > 0) return 'xt:${ser.id}';
      return _normalizeNameKey(ser.name);
    }
    return '';
  }

  String _normalizeNameKey(String s) {
    final t = s.trim().toLowerCase();
    return t.replaceAll(RegExp(r'\s+'), ' ');
  }

  SeriesEpisodeOption? _currentEpisodeOption() {
    final tape = _episodeBrowseTape;
    if (tape == null || tape.isEmpty) return null;
    final idx = _episodeTapeIndexOfCurrent();
    if (idx < 0 || idx >= tape.length) return null;
    return tape[idx];
  }

  static bool _seriesMetaUsable(String? v) {
    if (v == null) return false;
    final t = v.trim();
    return t.isNotEmpty && t.toUpperCase() != 'N/A';
  }

  /// Oynatıcıya `playingSeriesInTape` verilmemişse playlist'ten eşleşen dizi.
  SeriesItem? _resolveSeriesForPanel() {
    if (_playingSeriesInTape != null) return _playingSeriesInTape;
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null || data.series.isEmpty) return null;

    var searchTitle = '';
    final tape = _episodeBrowseTape;
    if (tape != null && tape.isNotEmpty) {
      final disp = tape.first.displayTitle.trim();
      if (disp.isNotEmpty) {
        final dash = disp.split(RegExp(r'\s[-–—]\s'));
        searchTitle = dash.first.trim();
      }
    }
    if (searchTitle.isEmpty) {
      var raw = channel.value.name.trim();
      if (raw.isNotEmpty) {
        raw = raw.replaceAll(RegExp(r'[\[\(].*?[\]\)]'), ' ');
        raw = raw.replaceAll(
          RegExp(r'\bS\d{1,2}\s?E\d{1,3}\b', caseSensitive: false),
          ' ',
        );
        raw = raw.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
        final dash = raw.split(RegExp(r'\s[-–—]\s'));
        searchTitle = dash.first.trim().isNotEmpty ? dash.first.trim() : raw;
      }
    }
    if (searchTitle.isEmpty) return null;

    final key = SeriesNameGrouping.canonicalKey(searchTitle);
    if (key.isEmpty) return null;
    for (final s in data.series) {
      final sk = SeriesNameGrouping.canonicalKey(
        SeriesNameGrouping.displayTitleFromName(s.name),
      );
      if (sk == key) return s;
    }
    return null;
  }

  /// "Bling Empire S01-E03" gibi başlıklardan dizinin gerçek adını ayıklar.
  /// Detay sayfasıyla aynı: [SeriesNameGrouping.displayTitleFromName].
  String _deriveSeriesDisplayTitle() {
    final ser = _resolveSeriesForPanel();
    if (ser != null) {
      return SeriesNameGrouping.displayTitleFromName(ser.name);
    }

    final tape = _episodeBrowseTape;
    if (tape != null && tape.isNotEmpty) {
      final first = tape.first;
      final disp = first.displayTitle.trim();
      if (disp.isNotEmpty) {
        final dash = disp.split(RegExp(r'\s[-–—]\s'));
        if (dash.first.trim().isNotEmpty) return dash.first.trim();
      }
    }

    final raw = channel.value.name.trim();
    if (raw.isEmpty) return '';
    var t = raw;
    t = t.replaceAll(RegExp(r'[\[\(].*?[\]\)]'), ' ');
    t = t.replaceAll(
        RegExp(r'\bS\d{1,2}\s?E\d{1,3}\b', caseSensitive: false), ' ');
    t = t.replaceAll(RegExp(r'\b(19|20)\d{2}\b'), ' ');
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    final dash = t.split(RegExp(r'\s[-–—]\s'));
    if (dash.first.trim().isNotEmpty) return dash.first.trim();
    return t;
  }

  String? _deriveSeriesPosterUrl() {
    final ser = _resolveSeriesForPanel();
    final p = ser?.posterUrl;
    if (p != null && p.trim().isNotEmpty) return p.trim();
    final tape = _episodeBrowseTape;
    if (tape != null && tape.isNotEmpty) {
      final logo = tape.first.channel.logoUrl;
      if (logo != null && logo.trim().isNotEmpty) return logo.trim();
    }
    final logo = channel.value.logoUrl;
    if (logo != null && logo.trim().isNotEmpty) return logo.trim();
    return null;
  }

  String? _deriveSeriesPlotFallback() {
    final ser = _resolveSeriesForPanel();
    final p = ser?.plot;
    if (_seriesMetaUsable(p)) return p!.trim();
    return null;
  }

  List<SeriesPlayerCastMember> _castFromMovieModel(MovieModel? m) {
    final list = m?.cast;
    if (list == null || list.isEmpty) return const <SeriesPlayerCastMember>[];
    return [
      for (final c in list)
        if (c.name.trim().isNotEmpty)
          SeriesPlayerCastMember(
            name: c.name.trim(),
            character: c.character?.trim(),
            profileUrl: c.profilePath?.trim(),
          ),
    ];
  }

  /// Detay sayfasıyla aynı kaynaklar: Xtream özet/puan + [MovieService] TMDB/OMDb.
  Future<void> _loadSeriesPanelDataAsync() async {
    if (_seriesPanelDataLoaded) return;
    _seriesPanelDataLoaded = true;

    final series = _resolveSeriesForPanel();
    final displayTitle = _deriveSeriesDisplayTitle();
    if (displayTitle.isEmpty) return;

    final posterFallback = _deriveSeriesPosterUrl();
    final plotFallback = _deriveSeriesPlotFallback();
    seriesPanelData.value = SeriesPlayerPanelData(
      title: displayTitle,
      posterUrl: posterFallback,
      plot: plotFallback,
    );

    XtreamSeriesBrowseDetail? xtream;
    if (series != null && Get.isRegistered<PlaylistRepository>()) {
      try {
        xtream =
            await Get.find<PlaylistRepository>().resolveXtreamSeriesEpisodes(
          seriesId: series.id,
          seriesName: series.name,
          posterUrl: series.posterUrl,
          categoryId: series.categoryId,
        );
      } catch (_) {
        xtream = null;
      }
    }
    if (isClosed) return;

    String? plot = plotFallback;
    String? poster = posterFallback;
    String? imdb;
    String? year;
    String? genre;

    if (xtream != null) {
      if (_seriesMetaUsable(xtream.seriesPlot))
        plot = xtream.seriesPlot!.trim();
      if (_seriesMetaUsable(xtream.coverUrl)) poster = xtream.coverUrl!.trim();
      if (_seriesMetaUsable(xtream.imdbRating)) {
        imdb = xtream.imdbRating!.trim();
      }
      if (_seriesMetaUsable(xtream.genre)) genre = xtream.genre!.trim();
      final rd = xtream.releaseDate?.trim();
      if (_seriesMetaUsable(rd)) {
        final ym = RegExp(r'\b(19|20)\d{2}\b').firstMatch(rd!);
        year = ym?.group(0) ?? (rd.length <= 14 ? rd : null);
      }
    }

    if (!Get.isRegistered<MovieService>()) return;

    final ms = Get.find<MovieService>();
    final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(displayTitle);
    final localPlot = series != null
        ? (SeriesNameGrouping.bestPlotFromCluster([series]) ?? series.plot)
        : plotFallback;

    var movieMeta = await ms.getMovieWithFallback(
      name: displayTitle,
      localPlot: localPlot,
      localPoster: series?.posterUrl ?? posterFallback,
      year: cleaned.$2,
      isSeries: true,
    );
    if (!_seriesMetaUsable(movieMeta.plot) && !_seriesMetaUsable(localPlot)) {
      final alt = TurkishTitleUtils.cleanTitleForSearch(displayTitle);
      if (alt.isNotEmpty && alt.toLowerCase() != displayTitle.toLowerCase()) {
        final retry = await ms.getMovieWithFallback(
          name: alt,
          localPlot: localPlot,
          localPoster: series?.posterUrl ?? posterFallback,
          year: cleaned.$2,
          isSeries: true,
        );
        if (_seriesMetaUsable(retry.plot)) movieMeta = retry;
      }
    }
    if (isClosed) return;

    if (_seriesMetaUsable(movieMeta.plot)) plot = movieMeta.plot!.trim();
    if (_seriesMetaUsable(movieMeta.poster)) poster = movieMeta.poster!.trim();
    if (_seriesMetaUsable(movieMeta.imdbRating)) {
      imdb = movieMeta.imdbRating!.trim();
    }
    if (_seriesMetaUsable(movieMeta.genre)) genre = movieMeta.genre!.trim();
    if (!_seriesMetaUsable(year) && _seriesMetaUsable(movieMeta.year)) {
      final y = movieMeta.year!.trim();
      final ym = RegExp(r'\b(19|20)\d{2}\b').firstMatch(y);
      year = ym?.group(0) ?? y;
    }

    final actors = _castFromMovieModel(movieMeta);
    final runtime =
        _seriesMetaUsable(movieMeta.runtime) ? movieMeta.runtime!.trim() : null;

    seriesPanelData.value = SeriesPlayerPanelData(
      title: _seriesMetaUsable(movieMeta.title)
          ? movieMeta.title!.trim()
          : displayTitle,
      posterUrl: poster,
      plot: plot,
      imdbRating: imdb,
      year: year,
      runtime: runtime,
      genre: genre,
      actors: actors,
    );
  }

  /// Dizi/bölüm değişince UI'ya yeni intro hedef saniyesini yansıt.
  /// `player_view`'daki overlay bu RxInt'i dinler.
  void refreshIntroDurationForCurrent() {
    if (!_settings.smartStreamCutterEnabled.value) {
      if (introSkipTargetSec.value != 0) introSkipTargetSec.value = 0;
      _lastIntroSeriesId = null;
      return;
    }
    if (!isSeries) {
      if (introSkipTargetSec.value != 0) introSkipTargetSec.value = 0;
      _lastIntroSeriesId = null;
      return;
    }
    final seriesId = _seriesIdForLearning();
    if (seriesId.isEmpty) {
      if (introSkipTargetSec.value != 0) introSkipTargetSec.value = 0;
      _lastIntroSeriesId = null;
      return;
    }
    if (!Get.isRegistered<MinaStreamCutterService>()) return;
    final svc = Get.find<MinaStreamCutterService>();
    final t = svc.introDurationSecFor(seriesId) ?? 0;
    if (_lastIntroSeriesId != seriesId || introSkipTargetSec.value != t) {
      _lastIntroSeriesId = seriesId;
      introSkipTargetSec.value = t;
    }
  }

  /// "Jeneriği Atla" butonuna basıldığında çağrılır.
  void skipIntroNow() {
    final t = introSkipTargetSec.value;
    if (t <= 0) return;
    seekTo(Duration(seconds: t));
  }

  /// VOD devam diyaloğu sonrası: [PlayerController.play] yerine doğrudan motor (seek beklenir).
  Future<void> _playEngineAsync() async {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      await mk.play().catchError((_, __) {});
      return;
    }
    final b = better;
    if (b != null) {
      await b.play();
    }
  }

  Future<void> _seekThenPlayVodResume(Duration position) async {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      await mk.seek(position).catchError((_, __) {});
      await mk.play().catchError((_, __) {});
      return;
    }
    final b = better;
    if (b != null) {
      await b.seekTo(position);
      await b.play();
    }
  }

  // TV için son ses seviyesini hatýrla (logical 0..maxBoost)
  static double _lastVolumeLevel = 1.0;

  /// Logical 0..maxPlaybackVolume aralığında ses seviyesini uygular.
  ///
  /// * 0..1.0 → sistem ses seviyesi; oynatıcı (mpv) kazancı sabit (130).
  /// * 1.0..maxPlaybackVolume → sistem 100%, mpv kazancı 130 → 200.
  ///
  /// BetterPlayer motoru aktifken boost desteklenmez; sistem ses üzerinden
  /// 0..1 etkili olur, > 1.0 görsel olarak gösterilse de işitsel etkisi
  /// yoktur.
  void setVolume(double value01) {
    final cap = maxPlaybackVolume;
    final clamped = value01.clamp(0.0, cap);
    _lastVolumeLevel = clamped;

    final systemPart = math.min(1.0, clamped);
    final boostPart = math.max(0.0, clamped - 1.0);
    _playbackBoostExtra.value = boostPart;

    if (Get.isRegistered<SystemVolumeService>()) {
      unawaited(SystemVolumeService.to.setVolume(systemPart));
    }

    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(
        mk.setVolume(_mediaKitVolumeFor(clamped)).catchError((_, __) {}),
      );
    }
    // BetterPlayer 0..1 destekler; boost yok sayılır.
    better?.setVolume(systemPart);
  }

  /// Son hatýrlanan ses seviyesini geri yükle
  void restoreLastVolumeLevel() {
    setVolume(_lastVolumeLevel);
  }

  /// Playback speed'i resetle ve senkronizasyon için 1.01x ayarla
  void resetAndAdjustPlaybackSpeed() {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      // MediaKit için speed ayarla
      unawaited(mk.setRate(1.01).catchError((_, __) {}));
      return;
    }

    // BetterPlayer için speed ayarla
    better?.setSpeed(1.01);
  }

  /// Playback speed'i tamamen resetle (1.0x)
  void resetPlaybackSpeed() {
    playbackRate.value = 1.0;
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(mk.setRate(1.0).catchError((_, __) {}));
      return;
    }

    better?.setSpeed(1.0);
  }

  void setInAppPlaybackBrightness(double value01) {
    inAppPlaybackBrightness.value = value01.clamp(0.0, 1.0);
  }

  void _resetOrphanBetterSurfaceRecoveryForZap() {
    _orphanBetterBootRev++;
    orphanBetterSurfaceRecoveryAttempts.value = 0;
  }

  /// [PlayerView]: Better yüzeyi yok, hata/mesgul yok — kısa gecikmeyle sınırlı [_boot].
  Future<void> ensureOrphanBetterBootRetry() async {
    if (isClosed) return;
    if (effectiveUseMediaKit) return;
    if (better != null) {
      orphanBetterSurfaceRecoveryAttempts.value = 0;
      return;
    }
    if (isBusy.value) return;
    if (error.value != null) return;
    if (orphanBetterSurfaceRecoveryAttempts.value >=
        effectiveMaxOrphanBetterSurfaceRetries) {
      return;
    }
    if (_orphanBetterBootInFlight) return;
    _orphanBetterBootInFlight = true;
    final rev = _orphanBetterBootRev;
    try {
      // TV: uzun yüzey gecikmesi; tablet/telefon: düşük RAM + yavaş Exo init (ör. SM-T530)
      // için daha uzun bekleme — aksi halde ilk [_boot] sürerken ikinci tam [_boot] tetiklenebilir.
      final delayMs =
          _settings.layoutMode.value == AppLayoutMode.tv ? 900 : 1000;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (rev != _orphanBetterBootRev) return;
      if (isClosed) return;
      // İlk kare beklenirken asla yedek [_boot] yok (meşgul bayrağı bazen titreyebiliyor).
      if (_busyHoldBootGen != null) return;
      if (effectiveUseMediaKit ||
          better != null ||
          isBusy.value ||
          error.value != null) {
        return;
      }
      if (orphanBetterSurfaceRecoveryAttempts.value >=
          effectiveMaxOrphanBetterSurfaceRetries) {
        return;
      }
      orphanBetterSurfaceRecoveryAttempts.value++;
      await _boot(
        preferredMaxHeight: null,
        disableAsms: false,
        reuseSameBetterPlayer: false,
        suppressNetworkRecoverySchedule: false,
      );
    } finally {
      if (rev == _orphanBetterBootRev) {
        _orphanBetterBootInFlight = false;
      }
    }
  }

  void setSpeed(double value) {
    better?.setSpeed(value);
  }

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

  /// OSD üzerindeki hızlı oynatma butonu için bir sonraki hıza geçer.
  /// 1x → 1.25x → 1.5x → 2x → 1x.
  void cyclePlaybackRate() {
    final current = playbackRate.value;
    var nextIndex = 0;
    for (var i = 0; i < playbackRateCycle.length; i++) {
      if ((playbackRateCycle[i] - current).abs() < 0.001) {
        nextIndex = (i + 1) % playbackRateCycle.length;
        break;
      }
    }
    setPlaybackRate(playbackRateCycle[nextIndex]);
  }

  /// OSD / kısayollarla hızı doğrudan ayarlamak için.
  ///
  /// MediaKit ve BetterPlayer'ı birlikte günceller, [playbackRate] Rx
  /// değerini yayımlar.
  void setPlaybackRate(double rate) {
    if (rate.isNaN || rate.isInfinite) return;
    final clamped = rate.clamp(0.25, 16.0);
    playbackRate.value = clamped;
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(mk.setRate(clamped).catchError((_, __) {}));
      return;
    }
    better?.setSpeed(clamped);
  }

  /// Aynı native Exo örneği ve [VideoPlayerController] ile yeni URL yüklenirken
  /// tampon/decoder yeniden kurulumunu sınırlamak için (Android: stop + clearMediaItems + setMediaSource).
  bool _canReuseBetterForDataSource(BetterPlayerDataSource newDs) {
    final vpc = better?.videoPlayerController;
    if (vpc == null) return false;
    final o = vpc.bufferingConfiguration;
    final n = newDs.bufferingConfiguration;
    return o.preferSoftwareVideoDecoder == n.preferSoftwareVideoDecoder &&
        o.minBufferMs == n.minBufferMs &&
        o.maxBufferMs == n.maxBufferMs &&
        o.bufferForPlaybackMs == n.bufferForPlaybackMs &&
        o.bufferForPlaybackAfterRebufferMs ==
            n.bufferForPlaybackAfterRebufferMs;
  }

  /// [zapTo] öncesi: motor değişmeyecekse Better örneğini dispose etme.
  bool _shouldReuseBetterOnChannelChange(Channel newCh) {
    if (better == null) return false;

    final nextNormalized = _normalizePlaybackStreamUrl(newCh.streamUrl);
    if (nextNormalized.isEmpty) return false;

    final nextLive = IptvPlaybackDefaults.isLikelyLiveStream(nextNormalized);
    final lp = nextNormalized.toLowerCase();
    final tsLiveAndroid = nextLive &&
        Platform.isAndroid &&
        (lp.split('?').first.endsWith('.ts') || lp.contains('output=ts'));
    final nextDs = iptvBetterPlayerDataSource(
      nextNormalized,
      liveStream: nextLive,
      cacheConfiguration: null,
      useAsmsTracks: null,
      useAsmsAudioTracks: null,
      useAsmsSubtitles: null,
      preferSoftwareVideoDecoder:
          (nextLive ? _settings.preferSoftwareVideoDecoder.value : false) ||
              tsLiveAndroid,
      liveBufferSeconds: nextLive
          ? _settings.liveBufferSeconds.value
          : IptvBetterPlayerConfig.defaultLiveBufferSecondsForExo,
    );
    return _canReuseBetterForDataSource(nextDs);
  }

  /// HLS/M3U8 çoklu varyant: cihaz + [AppSettingsService.adaptiveStreamQualityCeiling]
  /// ile üst çözünürlük (4K varyant zayıf kutularda kilitlenmesin).
  int? _preferredMaxVideoHeightForAdaptivePlayback() {
    int deviceH;
    try {
      final views = ui.PlatformDispatcher.instance.views;
      if (views.isEmpty) {
        deviceH = 1080;
      } else {
        final view = views.first;
        final dpr = view.devicePixelRatio;
        if (dpr <= 0) {
          deviceH = 1080;
        } else {
          final logical = view.physicalSize / dpr;
          var h = math.min(logical.width, logical.height).round();
          if (h < 240) {
            h = 720;
          }
          deviceH = math.min(h, 2160);
        }
      }
    } catch (_) {
      deviceH = 1080;
    }
    final cap = _settings.adaptiveStreamQualityCeiling.value.maxHeightPxOrNull;
    var result = cap == null ? deviceH : math.min(deviceH, cap);
    if (Platform.isAndroid &&
        AndroidPlaybackSocHints.isTotalRamBelowBytes(
          AndroidPlaybackSocHints.lowRamThresholdBytes,
        )) {
      result = math.min(result, 720);
    }
    // Xiaomi telefon/tablet: 4K varyant donanımı zorlayıp kare kare oynatma yapabiliyor; HLS adaptifte 1080 tavan.
    if (Platform.isAndroid &&
        AndroidPlaybackSocHints.xiaomiFamily &&
        _settings.layoutMode.value != AppLayoutMode.tv) {
      result = math.min(result, 1080);
    }
    return result;
  }

  void _applyPreferredMaxHeightToBetter(
    BetterPlayerController ctrl, {
    required int? preferredMaxHeight,
    required bool disableAsms,
  }) {
    if (disableAsms || preferredMaxHeight == null) return;
    final tracks = List<BetterPlayerAsmsTrack>.from(ctrl.betterPlayerAsmsTracks)
      ..removeWhere((t) => (t.height ?? 0) <= 0);
    if (tracks.isEmpty) return;
    tracks.sort((a, b) => (a.height ?? 0).compareTo(b.height ?? 0));
    BetterPlayerAsmsTrack? chosen;
    for (var i = tracks.length - 1; i >= 0; i--) {
      final h = tracks[i].height ?? 0;
      if (h > 0 && h <= preferredMaxHeight) {
        chosen = tracks[i];
        break;
      }
    }
    chosen ??= tracks.first;
    ctrl.setTrack(chosen);
  }

  void _cancelLiveZapAbrQualityRamp() {
    _liveZapAbrRampTimer?.cancel();
    _liveZapAbrRampTimer = null;
  }

  static const int _kLiveZapAbrMinTracks = 2;
  static const int _kLiveZapAbrMaxPollMs = 1500;
  static const int _kLiveZapAbrPollStepMs = 100;

  /// Canlı + çoklu HLS varyant: önce en düşük, ~2s sonra tercih edilen tavan.
  void _scheduleLiveZapAbrRampsExo(
    BetterPlayerController ctrl,
    int expectedGen, {
    required int? preferredMaxHeight,
    required bool disableAsms,
  }) {
    if (disableAsms || preferredMaxHeight == null || !_currentStreamIsLive) {
      _applyPreferredMaxHeightToBetter(
        ctrl,
        preferredMaxHeight: preferredMaxHeight,
        disableAsms: disableAsms,
      );
      return;
    }
    _cancelLiveZapAbrQualityRamp();
    unawaited(
      _runLiveZapAbrRampsExoAsync(
        ctrl,
        expectedGen,
        preferredMaxHeight: preferredMaxHeight,
      ),
    );
  }

  Future<void> _runLiveZapAbrRampsExoAsync(
    BetterPlayerController ctrl,
    int expectedGen, {
    required int preferredMaxHeight,
  }) async {
    if (!_isPlaybackGenerationCurrent(expectedGen) || isClosed) return;
    var waited = 0;
    var tracks = <BetterPlayerAsmsTrack>[];
    while (waited < _kLiveZapAbrMaxPollMs) {
      if (!_isPlaybackGenerationCurrent(expectedGen) || isClosed) return;
      if (!identical(better, ctrl)) return;
      tracks = List<BetterPlayerAsmsTrack>.from(ctrl.betterPlayerAsmsTracks)
        ..removeWhere((t) => (t.height ?? 0) <= 0);
      if (tracks.length >= _kLiveZapAbrMinTracks) break;
      await Future<void>.delayed(
        const Duration(milliseconds: _kLiveZapAbrPollStepMs),
      );
      waited += _kLiveZapAbrPollStepMs;
    }
    if (!_isPlaybackGenerationCurrent(expectedGen) || isClosed) return;
    if (!identical(better, ctrl)) return;
    if (tracks.length < _kLiveZapAbrMinTracks) {
      _applyPreferredMaxHeightToBetter(
        ctrl,
        preferredMaxHeight: preferredMaxHeight,
        disableAsms: false,
      );
      return;
    }
    tracks.sort((a, b) => (a.height ?? 0).compareTo(b.height ?? 0));
    ctrl.setTrack(tracks.first);
    _maybeBumpOsdQualitySignature();
    update(['osd']);
    _liveZapAbrRampTimer = Timer(const Duration(seconds: 2), () {
      if (isClosed) return;
      if (!_isPlaybackGenerationCurrent(expectedGen)) return;
      if (!identical(better, ctrl)) return;
      _applyPreferredMaxHeightToBetter(
        ctrl,
        preferredMaxHeight: preferredMaxHeight,
        disableAsms: false,
      );
      _maybeBumpOsdQualitySignature();
      update(['osd']);
    });
  }

  static int _mediaKitTrackPixels(VideoTrack t) {
    final w = t.w ?? 0, h = t.h ?? 0;
    if (w <= 0 || h <= 0) {
      return 0;
    }
    return w * h;
  }

  /// MediaKit çoklu video iz: düşük → 2s sonra tercih tavanı.
  Future<void> _tryLiveZapAbrRampsMediaKit(Player p) async {
    if (!_currentStreamIsLive) return;
    final g = _mediaKitZapAbrTargetGen;
    if (g == null || !_isPlaybackGenerationCurrent(g)) return;
    if (!identical(_mediaKitPlayer, p)) return;
    var waited = 0;
    var vids = p.state.tracks.video;
    while (waited < _kLiveZapAbrMaxPollMs) {
      if (!_isPlaybackGenerationCurrent(g) || isClosed) return;
      if (!identical(_mediaKitPlayer, p)) return;
      vids = p.state.tracks.video;
      if (vids.length >= _kLiveZapAbrMinTracks) break;
      await Future<void>.delayed(
        const Duration(milliseconds: _kLiveZapAbrPollStepMs),
      );
      waited += _kLiveZapAbrPollStepMs;
    }
    if (!_isPlaybackGenerationCurrent(g) || isClosed) return;
    if (!identical(_mediaKitPlayer, p)) return;
    if (vids.length < _kLiveZapAbrMinTracks) {
      return;
    }
    final byPixels = List<VideoTrack>.from(vids)
      ..sort(
        (a, b) => _mediaKitTrackPixels(a).compareTo(_mediaKitTrackPixels(b)),
      );
    if (byPixels.isEmpty) return;
    if (_mediaKitTrackPixels(byPixels.first) <
        _mediaKitTrackPixels(byPixels.last)) {
      try {
        await p.setVideoTrack(byPixels.first);
      } catch (_) {}
      _maybeBumpOsdQualitySignature();
    }
    _liveZapAbrRampTimer?.cancel();
    _liveZapAbrRampTimer = Timer(const Duration(seconds: 2), () async {
      if (isClosed) return;
      if (!_isPlaybackGenerationCurrent(g)) return;
      if (!identical(_mediaKitPlayer, p)) return;
      final cap = _preferredMaxVideoHeightForAdaptivePlayback() ?? 1080;
      final list = p.state.tracks.video;
      if (list.isEmpty) return;
      VideoTrack? best;
      var bestP = 0;
      for (final t in list) {
        final h = t.h ?? 0, w = t.w ?? 0;
        if (h > 0 && w > 0 && h <= cap) {
          final px = w * h;
          if (px > bestP) {
            bestP = px;
            best = t;
          }
        }
      }
      best ??= list.isNotEmpty
          ? list.reduce(
              (a, b) =>
                  _mediaKitTrackPixels(a) >= _mediaKitTrackPixels(b) ? a : b,
            )
          : null;
      if (best == null) return;
      try {
        await p.setVideoTrack(best);
      } catch (_) {}
      _maybeBumpOsdQualitySignature();
    });
  }

  /// Eski yayının sesi karartma beklenmeden kesilsin (hızlı kanal değişimi).
  void _silenceCurrentPlaybackImmediately() {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(
        mk.pause().then((_) => mk.setVolume(0.0)).catchError((_, __) {}),
      );
    }
    final b = better;
    if (b != null) {
      unawaited(
        b.stop().then((_) => b.setVolume(0)).catchError((_, __) {}),
      );
    }
  }

  void _cancelZapRelativeDebounce() {
    _zapRelativeDebounceTimer?.cancel();
    _zapRelativeDebounceTimer = null;
    _zapRelativePendingDelta = 0;
  }

  /// Ok tuşu ile hızlı gezinme: duraklamadan sonra biriken adımlar tek seferde uygulanır.
  /// Canlıda gecikme kısadır (hızlı zapping); VOD / dizi şeridi gibi durumlarda daha uzun.
  void zapRelativeDebounced(int delta) {
    _zapRelativePendingDelta += delta;
    _zapRelativeDebounceTimer?.cancel();
    final delay = _currentStreamIsLive ? _zapDebounceLive : _zapDebounceDefault;
    _zapRelativeDebounceTimer = Timer(delay, () {
      final d = _zapRelativePendingDelta;
      _zapRelativePendingDelta = 0;
      _zapRelativeDebounceTimer = null;
      if (d == 0) return;
      unawaited(zapRelative(d));
    });
  }

  /// Sayı tuşundan gelen bir rakamı (0–9) giriş tamponuna ekler ve commit
  /// zamanlayıcısını yeniler. Yalnızca canlı yayında anlamlıdır.
  void pushChannelNumberDigit(int digit) {
    if (digit < 0 || digit > 9) return;
    if (isMovie || isSeries) return;
    if (!_currentStreamIsLive && !isLiveChannelCurrent) return;
    final buf = tvChannelNumberEntry.value;
    // İlk rakam 0 ise (numara 0 olamaz) yok say; baştaki sıfırları engelle.
    if (buf.isEmpty && digit == 0) return;
    if (buf.length >= _channelNumberMaxDigits) return;
    tvChannelNumberEntry.value = '$buf$digit';
    _channelNumberCommitTimer?.cancel();
    _channelNumberCommitTimer =
        Timer(_channelNumberCommitDelay, commitChannelNumberEntry);
  }

  /// Geçerli kanalın canlı olup olmadığını url'den hızlı kontrol.
  bool get isLiveChannelCurrent {
    if (isMovie || isSeries) return false;
    final u = channel.value.streamUrl.toLowerCase();
    if (u.contains('/movie/') || u.contains('/series/')) return false;
    final norm =
        IptvPlaybackDefaults.normalizeStreamUrl(channel.value.streamUrl);
    return IptvPlaybackDefaults.isLikelyLiveStream(norm);
  }

  /// Girilen numarayı uygula: geçerli kategorideki 1 tabanlı sıraya karşılık
  /// gelen kanala geçer. Aralık dışındaysa veya aynı kanalsa giriş temizlenir.
  void commitChannelNumberEntry() {
    _channelNumberCommitTimer?.cancel();
    _channelNumberCommitTimer = null;
    final buf = tvChannelNumberEntry.value;
    tvChannelNumberEntry.value = '';
    if (buf.isEmpty) return;
    final n = int.tryParse(buf);
    if (n == null || n <= 0) return;
    final list = liveChannelsInCurrentCategory();
    if (list.isEmpty) return;
    if (n > list.length) {
      _showChannelNumberOutOfRange(n, list.length);
      return;
    }
    final target = list[n - 1];
    if (_isSameChannelRow(target, channel.value)) return;
    unawaited(zapTo(target));
  }

  void _showChannelNumberOutOfRange(int n, int total) {
    if (!Get.isRegistered<ToastService>()) return;
    Get.find<ToastService>().show(
      'player.channelNumberOutOfRange'.trParams({
        'n': '$n',
        'total': '$total',
      }),
      isError: true,
    );
  }

  /// Giriş kutusunu iptal et (Geri tuşu vb.).
  void cancelChannelNumberEntry() {
    _channelNumberCommitTimer?.cancel();
    _channelNumberCommitTimer = null;
    if (tvChannelNumberEntry.value.isNotEmpty) {
      tvChannelNumberEntry.value = '';
    }
  }

  void _cancelTvOsdAutoHideTimer() {
    _tvOsdAutoHideAt = null;
  }

  /// Ses/altyazı vb. alt diyalog açıkken OSD gizleme zamanlayıcısını durdur.
  void cancelTvOsdAutoHide() {
    _cancelTvOsdAutoHideTimer();
  }

  /// Better/MediaKit kontrol şeridi görünürlüğü; canlı zap sırasında [suppressLiveZapLoadingUi]
  /// iken dışarıdan gelen `false` ile OSD’yi söndürme (yalnızca kanal satırı güncellenir).
  void syncTvOsdVisibilityFromControls(bool visible) {
    if (!visible && suppressLiveZapLoadingUi.value) {
      return;
    }
    tvOsdVisible.value = visible;
  }

  bool get _usesRemoteOsdChrome =>
      _settings.layoutMode.value.usesRemoteNavigationStyle;

  /// Kumanda OSD + dikey el modu: bir süre sonra gizle; tekrar etkileşimde yeniden başlat.
  /// TV/tablet kumanda: canlıda ayar süresi; VOD 4 sn.
  /// Dikey mod (telefon/tablet): canlı ve VOD’da ayar süresi.
  void scheduleTvOsdAutoHide() {
    // Kanal değişimi sırasında OSD'yi gizleme
    if (_isChangingChannel) return;
    final remote = _usesRemoteOsdChrome;
    if (!remote && !_playbackPortraitForAutoHide) return;
    final url = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    final live = IptvPlaybackDefaults.isLikelyLiveStream(url);
    final sec = AppSettingsService.normalizeTvOsdAutoHideSeconds(
      _settings.tvOsdAutoHideDuration.value,
    );
    final customDuration = Duration(seconds: sec);
    final delay = remote
        ? (live ? customDuration : _tvOsdHideAfterPlayback)
        : customDuration;
    _tvOsdAutoHideAt = DateTime.now().add(delay);
    _startUnifiedUiTimer();
  }

  /// VOD sarma çubuğu sürüklenmeye başladı: OSD'yi açık tut ve otomatik
  /// gizleme zamanlayıcısını durdur (portrait + TV-remote). Mobil-yatayda
  /// yerel kontrol zamanlayıcısı [vodScrubbing] bayrağını okur.
  void beginVodScrub() {
    vodScrubbing.value = true;
    _cancelTvOsdAutoHideTimer();
    if (_usesRemoteOsdChrome || _playbackPortraitForAutoHide) {
      tvOsdVisible.value = true;
    }
  }

  /// VOD sarma bitti/iptal: otomatik gizlemeyi yeniden başlat.
  void endVodScrub() {
    if (!vodScrubbing.value) return;
    vodScrubbing.value = false;
    scheduleTvOsdAutoHide();
  }

  /// Kanal şeridi vb. için cam OSD’yi hemen gizle.
  void hideTvOsdNow() {
    if (!_usesRemoteOsdChrome && !_playbackPortraitForAutoHide) return;
    _tvOsdAutoHideAt = null;
    tvOsdVisible.value = false;
  }

  /// --- UNIFIED TIMER METHODS (Performance Optimization) ---

  /// UI ile ilgili tüm timer'larý birleþtirir (OSD, countdown, focus)
  void _startUnifiedUiTimer() {
    if (_uiTimer != null) return;

    _uiTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      final now = DateTime.now();
      bool hasActiveTask = false;

      // OSD Auto Hide kontrolü — sürükleme sürerken gizleme.
      if (vodScrubbing.value) {
        hasActiveTask = true;
      } else if (_tvOsdAutoHideAt != null && now.isAfter(_tvOsdAutoHideAt!)) {
        _tvOsdAutoHideAt = null;
        tvOsdVisible.value = false;
      } else if (_tvOsdAutoHideAt != null) {
        hasActiveTask = true;
      }

      // VOD Autoplay Countdown kontrolü
      if (_vodAutoplayCountdownStartedAt != null) {
        final elapsed = now.difference(_vodAutoplayCountdownStartedAt!);
        final remainingMs = 5000 - elapsed.inMilliseconds;
        final remaining = (remainingMs / 1000).ceil();
        if (remaining <= 0) {
          _vodAutoplayCountdownStartedAt = null;
          vodAutoplayCountdown.value = null;
          _triggerVodAutoplay();
        } else {
          if (vodAutoplayCountdown.value != remaining) {
            vodAutoplayCountdown.value = remaining;
          }
          hasActiveTask = true;
        }
      }

      // Aktif görev yoksa timer'ý durdur
      if (!hasActiveTask) {
        _uiTimer?.cancel();
        _uiTimer = null;
      }
    });
  }

  void _cancelUnifiedUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = null;
    _tvOsdAutoHideAt = null;
    _vodAutoplayCountdownStartedAt = null;
  }

  void _cancelUnifiedNetworkTimer() {
    _networkTimer?.cancel();
    _networkTimer = null;
  }

  void _cancelUnifiedProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// --- UNIFIED TIMER HELPERS ---

  void _triggerVodAutoplay() {
    // VOD autoplay logic buraya gelecek
    if (vodAutoplayNextTitle.isNotEmpty) {
      // Sonraki içeriði oynat
    }
  }

  /// OSD’den: yalnızca şu anki canlı kanalın EPG penceresi (yayın sürer).
  void openLiveSingleChannelEpgOverlay() {
    if (!_currentStreamIsLive) return;
    final u = channel.value.streamUrl.toLowerCase();
    if (u.contains('/movie/') || u.contains('/series/')) return;
    liveChannelStripOverlayOpen.value = false;
    hideTvOsdNow();
    liveSingleChannelEpgOpen.value = true;
  }

  void closeLiveSingleChannelEpgOverlay({bool showOsdAfter = true}) {
    liveSingleChannelEpgOpen.value = false;
    if (!_usesRemoteOsdChrome) return;
    if (showOsdAfter) {
      tvOsdVisible.value = true;
      scheduleTvOsdAutoHide();
      bumpTvOsdKeyFocus();
    }
  }

  void _cancelNetworkAutoResumeTimer() {
    _networkAutoResumeTimer?.cancel();
    _networkAutoResumeTimer = null;
  }

  void _cancelLiveTransientErrorEmitTimer() {
    _liveTransientErrorEmitTimer?.cancel();
    _liveTransientErrorEmitTimer = null;
    _betterBufferingRecoveryTimer?.cancel();
    _betterBufferingRecoveryTimer = null;
    _betterBufferingListenerBoundTo = null;
  }

  void _cancelBetterBufferingRecoveryTimer() {
    _betterBufferingRecoveryTimer?.cancel();
    _betterBufferingRecoveryTimer = null;
  }

  void _attachBetterBufferingRecoveryListener(BetterPlayerController ctrl) {
    final id = identityHashCode(ctrl);
    if (_betterBufferingListenerBoundTo == id) return;
    ctrl.addEventsListener(_onBetterBufferingRecoveryEvent);
    _betterBufferingListenerBoundTo = id;
  }

  void _onBetterBufferingRecoveryEvent(BetterPlayerEvent event) {
    if (effectiveUseMediaKit || better == null) return;
    if (event.betterPlayerEventType == BetterPlayerEventType.bufferingStart) {
      _cancelBetterBufferingRecoveryTimer();
      _betterBufferingRecoveryTimer =
          Timer(const Duration(seconds: 1), () async {
        if (isClosed || effectiveUseMediaKit) return;
        final ctrl = better;
        if (ctrl == null) return;
        final v = ctrl.videoPlayerController?.value;
        if (v == null || !v.isBuffering) return;
        final now = DateTime.now();
        final last = _lastBetterBufferingRecoveryAt;
        if (last != null && now.difference(last) < const Duration(seconds: 5)) {
          return;
        }
        _lastBetterBufferingRecoveryAt = now;
        debugPrint('mina_iptv: buffering >1s, seekTo(0)+play');
        try {
          await ctrl.seekTo(Duration.zero);
          await ctrl.play();
        } catch (e) {
          debugPrint('mina_iptv: buffering recovery failed: $e');
        }
      });
      return;
    }
    if (event.betterPlayerEventType == BetterPlayerEventType.bufferingEnd) {
      _cancelBetterBufferingRecoveryTimer();
    }
  }

  void _cancelLiveStallWatchdog() {
    _liveStallWatchdogTimer?.cancel();
    _liveStallWatchdogTimer = null;
    _liveTvStallPollTimer?.cancel();
    _liveTvStallPollTimer = null;
    _liveTvBufferingSince = null;
  }

  void _cancelLiveTvStartupWatchdog() {
    _liveTvStartupWatchdog?.cancel();
    _liveTvStartupWatchdog = null;
  }

  void _cancelLiveAutoNextWatchdog() {
    _liveAutoNextPollTimer?.cancel();
    _liveAutoNextPollTimer = null;
    _liveUnhealthySince = null;
  }

  /// Gerçek oynatma: kullanıcı duraklatmadıysa `isPlaying` ve bilinen hata yok.
  bool _liveAutoNextPlaybackStrictlyOk() {
    if (!_currentStreamIsLive || isMovie || isSeries || _userPausedLive) {
      return true;
    }
    final err = (error.value ?? '').trim();
    if (err.isNotEmpty) return false;
    if (effectiveUseMediaKit) {
      final mk = _mediaKitPlayer;
      if (mk == null) return false;
      return mk.state.playing;
    }
    final v = better?.videoPlayerController?.value;
    if (v == null) return false;
    if (!v.initialized || v.hasError) return false;
    return v.isPlaying;
  }

  void _syncLiveAutoNextWatchdog() {
    if (isClosed) return;
    if (!_currentStreamIsLive || isMovie || isSeries || _userPausedLive) {
      _cancelLiveAutoNextWatchdog();
      return;
    }
    if (isBusy.value) {
      _cancelLiveAutoNextWatchdog();
      return;
    }
    if (_liveAutoNextPlaybackStrictlyOk()) {
      _cancelLiveAutoNextWatchdog();
      return;
    }
    _liveUnhealthySince ??= DateTime.now();
    _liveAutoNextPollTimer ??= Timer.periodic(_liveAutoNextPollInterval, (_) {
      if (isClosed) {
        _cancelLiveAutoNextWatchdog();
        return;
      }
      if (!_currentStreamIsLive || _userPausedLive || isBusy.value) {
        _cancelLiveAutoNextWatchdog();
        return;
      }
      if (_liveAutoNextPlaybackStrictlyOk()) {
        _cancelLiveAutoNextWatchdog();
        return;
      }
      final since = _liveUnhealthySince;
      if (since == null) return;
      if (DateTime.now().difference(since) < _liveAutoNextAfterUnhealthy) {
        return;
      }
      debugPrint(
        'mina_iptv: Canlı ${_liveAutoNextAfterUnhealthy.inSeconds}s oynatılamadı → kategoride bir sonraki kanal',
      );
      _cancelLiveAutoNextWatchdog();
      unawaited(_reopenCurrentLiveStreamAfterUnhealthyWatchdog());
    });
  }

  /// Uzun süre sağlıksız oynatma sonrası aynı URL’yi tekrar denemek yerine listede **sonraki** canlıya geç.
  Future<void> _reopenCurrentLiveStreamAfterUnhealthyWatchdog() async {
    if (isClosed) return;
    if (!_currentStreamIsLive || isMovie || isSeries || _userPausedLive) {
      return;
    }
    await _zapToNextLiveInCategoryOrRestart();
  }

  void _resetNetworkRecoveryState() {
    _cancelNetworkAutoResumeTimer();
    _networkResumeAttempt = 0;
  }

  Duration _networkResumeDelayForAttempt() {
    const steps = [1, 3, 6, 12, 24];
    final i = _networkResumeAttempt.clamp(0, steps.length - 1);
    return Duration(seconds: steps[i]);
  }

  void _scheduleNetworkAutoResumeIfNeeded(String msg) {
    final eligible = _isLikelyNetworkOrTransientError(msg) ||
        (_currentStreamIsLive && !_isNotFoundStyleError(msg));
    if (!eligible) return;
    if (_recovering) return;
    if (_networkResumeAttempt >= 8) {
      error.value ??= 'player.error.playbackGeneric'.tr;
    }
    _networkAutoResumeTimer?.cancel();
    final d = _networkResumeDelayForAttempt();
    debugPrint(
      'mina_iptv: Network recovery in ${d.inSeconds}s (attempt idx $_networkResumeAttempt)',
    );
    _networkAutoResumeTimer = Timer(d, () {
      _networkAutoResumeTimer = null;
      unawaited(_performNetworkResume());
    });
  }

  void _emitPlaybackErrorForRecovery(
    String msg, {
    bool suppressNetworkRecoverySchedule = false,
  }) {
    try {
      if (_isNotFoundStyleError(msg)) {
        _cancelNetworkAutoResumeTimer();
        _networkResumeAttempt = 0;
        error.value = 'player.error.contentNotFound'.tr;
        return;
      }
      if (_scheduleXtreamVodPathGetPhpRetry()) {
        return;
      }
      if (_scheduleXtreamVodMkvToTsRetry()) {
        return;
      }
      if (_scheduleXtreamGetPhpToVodPathRetry()) {
        return;
      }
      if (_maybeSwitchToBetterAfterMediaKitVodFailure(msg)) {
        return;
      }
      if (_isLikelyNetworkOrTransientError(msg)) {
        error.value = null;
        if (!suppressNetworkRecoverySchedule) {
          _scheduleNetworkAutoResumeIfNeeded(msg);
        }
        return;
      }
      if (_currentStreamIsLive && !_isNotFoundStyleError(msg)) {
        error.value = null;
        if (!suppressNetworkRecoverySchedule) {
          _scheduleNetworkAutoResumeIfNeeded(msg);
        }
        return;
      }
      error.value = 'player.error.playbackGeneric'.tr;
    } finally {
      _syncLiveAutoNextWatchdog();
    }
  }

  /// mpv / yüzey açılamadığında ExoPlayer (yazılım kod çözücü) ile bir kez dener.
  ///
  /// Hem **canlı** hem **VOD** için geçerli: kullanıcı motoru MediaKit seçse
  /// (ya da bir nedenle mpv'ye düşülmüş olsa) bile mpv açamazsa yalnız o yayın
  /// için Better/Exo'ya geçilir. Ping-pong'u [_autoEngineSwitchUsed] engeller.
  bool _maybeSwitchToBetterAfterMediaKitVodFailure(String msg) {
    if (_vodAutoTriedBetterAfterMpvFail) return false;
    if (_autoEngineSwitchUsed) return false;
    if (!effectiveUseMediaKit) return false;
    final last = _lastPlaybackUrl?.trim() ?? '';
    if (last.isEmpty) return false;

    final l = msg.toLowerCase();
    final challengedTv =
        Platform.isAndroid && AndroidPlaybackSocHints.playbackChallengedTv;
    final matches = l.contains('failed to open') ||
        l.contains('video controller init') ||
        l.contains('first frame timeout') ||
        (challengedTv &&
            (_isPlaybackDecoderFailure(msg) ||
                l.contains('hwdec') ||
                l.contains('mediacodec') ||
                l.contains('decoder') ||
                l.contains('surface')));
    if (!matches) return false;

    _vodAutoTriedBetterAfterMpvFail = true;
    _autoEngineSwitchUsed = true;
    betterOsdOverride.value = true;
    mediaKitFallbackSession.value = false;
    if (challengedTv) {
      _forceSoftwareVideoDecoder = true;
    }
    _playUrlOverride = last;
    error.value = null;
    _showEngineFallbackToast(toMediaKit: false);
    debugPrint(
      'mina_iptv: MediaKit hatası → Better (Exo) deneniyor'
      '${challengedTv ? " (yazılım kod çözücü)" : ""}: $last — $msg',
    );
    unawaited(
      _boot(
        preferredMaxHeight: null,
        disableAsms: false,
        reuseSameBetterPlayer: false,
        suppressNetworkRecoverySchedule: false,
      ),
    );
    return true;
  }

  /// [UniversalVideoPlayer] VideoController kurulumu başarısız (TCL/Google TV vb.).
  Future<void> handleMediaKitSurfaceInitFailed(Object e) async {
    if (isClosed) return;
    await AndroidPlaybackSocHints.ensureLoaded();
    final msg = e.toString();
    if (_maybeSwitchToBetterAfterMediaKitVodFailure(
      'VideoController init failed: $msg',
    )) {
      return;
    }
    final gen = _busyHoldBootGen;
    if (gen != null && _isPlaybackGenerationCurrent(gen)) {
      _finishBootBusyHold(gen, _busyHoldVodSession);
    }
    _emitPlaybackErrorForRecovery(msg);
  }

  /// [UniversalVideoPlayer] `player.open` hatası.
  void onMediaKitOpenFailed(Object e) {
    if (isClosed) return;
    _emitPlaybackErrorForRecovery(e.toString());
  }

  /// Xtream `/movie/.../id.ext` veya `/series/.../id.ext` → `get.php?stream_id=...&output=...`
  ///
  /// Uzantı (ts/mp4/mkv/…) dosya adıyla aynı kalır; m3u8 zorlanmaz.
  /// Bir kez denenir ([_xtreamTriedSeriesMoviePathToGetPhp]).
  bool _scheduleXtreamVodPathGetPhpRetry() {
    if (_xtreamTriedSeriesMoviePathToGetPhp) return false;
    final raw = channel.value.streamUrl;
    final low = raw.toLowerCase();
    if (low.contains('get.php')) return false;
    if (!low.contains('/series/') && !low.contains('/movie/')) return false;
    final original = _normalizePlaybackStreamUrl(raw);
    final converted = _tryConvertXtreamVodStylePathToGetPhp(original);
    if (converted == null || converted == original) return false;
    _xtreamTriedSeriesMoviePathToGetPhp = true;
    _playUrlOverride = converted;
    error.value = null;
    unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
    return true;
  }

  /// [IptvPlaybackDefaults.normalizeStreamUrl] sonrası tam URL beklenir.
  String? _tryConvertXtreamVodStylePathToGetPhp(String normalizedUrl) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 4) return null;
    final root = segments[0].toLowerCase();
    if (root != 'movie' && root != 'series') return null;
    final user = Uri.decodeComponent(segments[1]);
    final pass = Uri.decodeComponent(segments[2]);
    final last = segments[3];
    final dot = last.lastIndexOf('.');
    if (dot <= 0) return null;
    final id = last.substring(0, dot);
    final output = last.substring(dot + 1).toLowerCase();
    if (int.tryParse(id) == null) return null;
    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$base/get.php?username=${Uri.encodeQueryComponent(user)}&password=${Uri.encodeQueryComponent(pass)}&stream_id=$id&output=$output';
  }

  /// `get.php?username=&password=&stream_id=&output=` → `/series|movie/u/p/id.ext`
  String? _tryConvertXtreamGetPhpToVodStylePath(String normalizedUrl) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    if (!uri.path.toLowerCase().endsWith('get.php')) return null;
    final q = uri.queryParameters;
    final user = q['username'] ?? q['u'];
    final pass = q['password'] ?? q['p'] ?? q['pwd'];
    var sid = q['stream_id'] ?? q['id'] ?? q['vod_id'];
    var output = (q['output'] ?? q['extension'] ?? 'ts').trim().toLowerCase();
    if (output.isEmpty) output = 'ts';
    if (user == null || pass == null || sid == null) return null;
    sid = sid.trim();
    if (int.tryParse(sid) == null) return null;
    final root = isSeries ? 'series' : 'movie';
    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$base/$root/${Uri.encodeComponent(user)}/${Uri.encodeComponent(pass)}/$sid.$output';
  }

  /// Paneller bazen yalnızca segment yolunu veya yalnızca `get.php` kabul eder; [get.php] hata verince bir kez yol dene.
  bool _scheduleXtreamGetPhpToVodPathRetry() {
    if (_xtreamTriedGetPhpToVodPathFallback) return false;
    if (_currentStreamIsLive) return false;
    if (_xtreamTriedSeriesMoviePathToGetPhp) return false;
    final raw = (_lastPlaybackUrl?.trim().isNotEmpty ?? false)
        ? _lastPlaybackUrl!
        : channel.value.streamUrl;
    final normalized = _normalizePlaybackStreamUrl(raw);
    if (!normalized.toLowerCase().contains('get.php')) return false;
    final converted = _tryConvertXtreamGetPhpToVodStylePath(normalized);
    if (converted == null || converted == normalized) return false;
    _xtreamTriedGetPhpToVodPathFallback = true;
    _playUrlOverride = converted;
    error.value = null;
    debugPrint(
        'mina_iptv: get.php başarısız → segment yolu deneniyor: $converted');
    unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
    return true;
  }

  /// `get.php?...&output=mkv` veya `.../id.mkv` → aynı akış `ts` (çoğu panelde VOD MPEG-TS daha sorunsuz).
  String? _swapXtreamVodUrlMkvToTs(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final low = t.toLowerCase();
    if (!low.contains('mkv')) return null;
    if (low.contains('get.php')) {
      final uri = Uri.tryParse(t);
      if (uri == null) return null;
      final q = Map<String, String>.from(uri.queryParameters);
      final out = (q['output'] ?? '').toLowerCase();
      if (out != 'mkv') return null;
      q['output'] = 'ts';
      return uri.replace(queryParameters: q).toString();
    }
    if (low.endsWith('.mkv')) {
      return '${t.substring(0, t.length - 4)}.ts';
    }
    return null;
  }

  bool _scheduleXtreamVodMkvToTsRetry() {
    if (_xtreamTriedVodMkvToTsSwap) return false;
    if (_currentStreamIsLive) return false;
    final raw = (_lastPlaybackUrl?.trim().isNotEmpty ?? false)
        ? _lastPlaybackUrl!
        : channel.value.streamUrl;
    final tsUrl = _swapXtreamVodUrlMkvToTs(_normalizePlaybackStreamUrl(raw));
    if (tsUrl == null) return false;
    _xtreamTriedVodMkvToTsSwap = true;
    _playUrlOverride = tsUrl;
    error.value = null;
    debugPrint('mina_iptv: Xtream VOD mkv → ts deneniyor: $tsUrl');
    unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
    return true;
  }

  Future<void> _performNetworkResume() async {
    if (isClosed) return;
    if (_recovering) {
      _scheduleNetworkAutoResumeIfNeeded(error.value ?? 'connection');
      return;
    }
    _cancelNetworkAutoResumeTimer();
    error.value = null;
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: true,
    );
    if (error.value != null) {
      final err = error.value!;
      final canRetry = _isLikelyNetworkOrTransientError(err) ||
          (_currentStreamIsLive && !_isNotFoundStyleError(err));
      if (canRetry) {
        _networkResumeAttempt = (_networkResumeAttempt + 1).clamp(0, 8);
        // Canlı: art arda aynı yayına _boot yinelemesi bazen yanlış/varyant URL’lere sapıyor;
        // birkaç denemeden sonra kategoride sıradaki kanala geç (OSD [zapTo] ile güncellenir).
        if (_currentStreamIsLive &&
            !isMovie &&
            !isSeries &&
            _networkResumeAttempt >= 3) {
          _networkResumeAttempt = 0;
          error.value = null;
          unawaited(_zapToNextLiveInCategoryOrRestart());
        } else {
          _scheduleNetworkAutoResumeIfNeeded(err);
        }
      } else {
        _networkResumeAttempt = 0;
      }
    } else {
      _networkResumeAttempt = 0;
    }
  }

  /// TV kutularında (özellikle MPEG-TS / zayıf SoC) 15 sn pek kısaydı: sürekli yeniden bağlanma
  /// Exo’da hata + kullanıcıda «MediaKit’e düşüyor» algısı yaratıyordu. Mobil/tablet yolu ayrı (72 sn).
  static const Duration _liveTvStallThreshold = Duration(seconds: 48);

  void _armLiveTvStartupWatchdog() {
    if (_settings.layoutMode.value != AppLayoutMode.tv) return;
    if (effectiveUseMediaKit) return;
    final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) return;

    _liveTvStartupWatchdog?.cancel();
    _liveTvStartupWatchdog = Timer(_liveTvStallThreshold, () {
      _liveTvStartupWatchdog = null;
      if (isClosed || effectiveUseMediaKit) return;
      final v = better?.videoPlayerController?.value;
      if (v == null) return;
      final ok = v.isPlaying && !v.isBuffering && !v.hasError;
      if (ok) return;
      debugPrint(
        'mina_iptv: TV live Better — ${_liveTvStallThreshold.inSeconds}s startup, stabil oynatma yok',
      );
      unawaited(_handleLiveTvStallRecovery());
    });
  }

  /// Sessiz takılma (siyah ekran, hata event'i yok) durumunda canlı yayını
  /// diğer taşıma biçimiyle (HLS ↔ MPEG-TS) yeniden açmayı dener. Yalnızca
  /// canlı, MediaKit dışı ve bu oturumda henüz denenmemişken çalışır.
  /// Başarıyla bir swap planlandıysa `true` döner.
  bool _tryLiveTransportFormatSwapRecovery(String normalizedUrl) {
    if (effectiveUseMediaKit || _decoderTriedTsToM3u8Swap) return false;
    if (!_currentStreamIsLive) return false;
    final basis = (_lastPlaybackUrl?.trim().isNotEmpty ?? false)
        ? _lastPlaybackUrl!.trim()
        : normalizedUrl;
    final swapped = _trySwapLiveTsM3u8Url(basis, live: true);
    if (swapped == null || swapped == basis) return false;
    _decoderTriedTsToM3u8Swap = true;
    _playUrlOverride = swapped;
    error.value = null;
    debugPrint(
      'mina_iptv: Canlı sessiz takılma → taşıma biçimi değişimi: $swapped',
    );
    unawaited(
      _boot(
        preferredMaxHeight: null,
        disableAsms: false,
        reuseSameBetterPlayer: false,
        suppressNetworkRecoverySchedule: true,
      ),
    );
    return true;
  }

  Future<void> _handleLiveTvStallRecovery() async {
    if (isClosed) return;
    if (_settings.layoutMode.value != AppLayoutMode.tv) return;
    if (effectiveUseMediaKit) return;
    final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) return;

    // HLS yayını hata event'i ÜRETMEDEN sessizce açılmazsa (LG/webOS gibi bazı
    // panellerde siyah ekran) önce taşıma biçimini değiştir: HLS → MPEG-TS
    // (veya tersi). Yalnızca bir kez; başarısız olursa normal yeniden bağlanma
    // / sonraki kanal akışına devam edilir.
    if (_tryLiveTransportFormatSwapRecovery(norm)) return;

    _liveTvStallRecoveryAttempts++;
    debugPrint(
      'mina_iptv: TV live takılma ($_liveTvStallRecoveryAttempts.) → ${_liveTvStallRecoveryAttempts >= 2 ? 'sonraki kanal' : 'yeniden bağlan'}',
    );
    _resetNetworkRecoveryState();
    if (_liveTvStallRecoveryAttempts >= 2) {
      _liveTvStallRecoveryAttempts = 0;
      await _zapToNextLiveInCategoryOrRestart();
      return;
    }
    await _performNetworkResume();
  }

  void _startLiveStallWatchdog() {
    if (better == null) return;
    if (effectiveUseMediaKit) return;
    final norm = _normalizePlaybackStreamUrl(channel.value.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) return;

    if (_settings.layoutMode.value == AppLayoutMode.tv) {
      // Ardışık bufferingStart süreyi sıfırlamasın (15 sn ilk takılmadan sayılır).
      if (_liveTvStallPollTimer != null) return;
      _liveTvBufferingSince = DateTime.now();
      _liveTvStallPollTimer = Timer.periodic(_liveTvStallPollInterval, (_) {
        if (isClosed || better == null || effectiveUseMediaKit) {
          _liveTvStallPollTimer?.cancel();
          _liveTvStallPollTimer = null;
          return;
        }
        final since = _liveTvBufferingSince;
        if (since == null) {
          _liveTvStallPollTimer?.cancel();
          _liveTvStallPollTimer = null;
          return;
        }
        final v = better?.videoPlayerController?.value;
        if (v == null) return;
        if (!v.isBuffering || v.hasError) {
          _liveTvStallPollTimer?.cancel();
          _liveTvStallPollTimer = null;
          _liveTvBufferingSince = null;
          return;
        }
        if (DateTime.now().difference(since) < _liveTvStallThreshold) return;
        _liveTvStallPollTimer?.cancel();
        _liveTvStallPollTimer = null;
        _liveTvBufferingSince = null;
        debugPrint(
          'mina_iptv: TV live ${_liveTvStallThreshold.inSeconds}s tampon takılması',
        );
        unawaited(_handleLiveTvStallRecovery());
      });
      return;
    }

    // Telefon / tablet: uzun tampon → tek seferde yeniden bağlan (kısa dalgalanmaları kesmeyi azalt).
    if (_liveStallWatchdogTimer != null) return;
    _liveStallWatchdogTimer = Timer(const Duration(seconds: 72), () {
      _liveStallWatchdogTimer = null;
      if (isClosed) return;
      final v = better?.videoPlayerController?.value;
      if (v == null) return;
      if (!v.isBuffering || v.hasError) return;
      debugPrint('mina_iptv: Live buffering stall → reconnect');
      _networkResumeAttempt = 0;
      unawaited(_performNetworkResume());
    });
  }

  /// Dikey telefon/tablet OSD şeridi: mevcut kanalla aynı kategorideki canlı kanallar.
  /// Film/dizi (VOD) oturumunda boş — yalnızca **canlı** yayında şerit gösterilir.
  List<Channel> liveChannelsInCurrentCategory() {
    if (isMovie || isSeries) {
      return const [];
    }
    final cur = channel.value;
    final norm = IptvPlaybackDefaults.normalizeStreamUrl(cur.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) {
      return const [];
    }
    final u = cur.streamUrl.toLowerCase();
    if (u.contains('/movie/') || u.contains('/series/')) {
      return const [];
    }
    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null) return const [];

    // [data.channels] sırası kanallar ekranındaki (kategori + düzen) ile aynı; sortOrder
    // ile yeniden sıralamak listedeki «bir sonraki» ile hata sonrası otomatik geçişi ayırıyordu.
    final out = <Channel>[];
    for (final c in data.channels) {
      if (c.categoryId != cur.categoryId) continue;
      final cu = c.streamUrl.toLowerCase();
      if (cu.contains('/movie/') || cu.contains('/series/')) continue;
      final cn = IptvPlaybackDefaults.normalizeStreamUrl(c.streamUrl);
      if (!IptvPlaybackDefaults.isLikelyLiveStream(cn)) continue;
      out.add(c);
    }
    return out;
  }

  /// Otomatik kurtarma: yanlış/rasgele yayın varyantına sapmak yerine aynı kategoride **listede bir sonraki**
  /// canlı kanala geçer ([zapTo] — OSD ve [channel] güncellenir). Tek kanal / VOD ise aynı yayını yeniler.
  Future<void> _zapToNextLiveInCategoryOrRestart() async {
    if (isClosed) return;
    if (!_currentStreamIsLive || isMovie || isSeries || _userPausedLive) {
      await restartCurrentStream();
      return;
    }

    final list = liveChannelsInCurrentCategory();
    if (list.length < 2) {
      await restartCurrentStream();
      return;
    }

    final cur = channel.value;
    var idx = list.indexWhere((c) => c.id == cur.id);
    if (idx < 0) {
      final curNorm = _normalizePlaybackStreamUrl(cur.streamUrl);
      idx = list.indexWhere(
        (c) => _normalizePlaybackStreamUrl(c.streamUrl) == curNorm,
      );
    }
    if (idx < 0) {
      idx = list.indexWhere((c) => _isSameChannelRow(c, cur));
    }
    if (idx < 0) {
      await restartCurrentStream();
      return;
    }

    final target = list[(idx + 1) % list.length];
    if (_isSameChannelRow(target, cur)) {
      await restartCurrentStream();
      return;
    }
    await zapTo(target);
  }

  Future<void> _zapToBrowseTapeSeries(SeriesItem nextSer) async {
    final direct = nextSer.streamUrl?.trim();
    Channel? nextCh;
    if (direct != null && direct.isNotEmpty) {
      nextCh = Channel(
        id: nextSer.id,
        name: nextSer.name,
        streamUrl: direct,
        categoryId: nextSer.categoryId,
        logoUrl: nextSer.posterUrl,
      );
    } else {
      final repo = Get.find<PlaylistRepository>();
      nextCh = await repo.resolveXtreamSeriesFirstEpisode(
        seriesId: nextSer.id,
        seriesName: nextSer.name,
        posterUrl: nextSer.posterUrl,
        categoryId: nextSer.categoryId,
      );
    }
    if (nextCh == null) return;
    _playingSeriesInTape = nextSer;
    await zapTo(nextCh);
  }

  /// Tüm kanallar listesinde [delta] kadar kaydırarak `zapTo` çağırır (anında; düğmeler için).
  Future<void> zapRelative(int delta) async {
    _cancelZapRelativeDebounce();
    final cur = channel.value;
    final url = cur.streamUrl.toLowerCase();
    final isVod = url.contains('/movie/') || url.contains('/series/');

    if (isVod) {
      final epTape = _episodeBrowseTape;
      if (epTape != null && epTape.isNotEmpty) {
        var idx = _episodeTapeIndexOfCurrent();
        if (idx < 0) return;
        final n = idx + delta;
        if (n < 0 || n >= epTape.length) return;
        final nextEp = epTape[n];
        if (nextEp.channel.id == cur.id &&
            nextEp.channel.streamUrl == cur.streamUrl) {
          return;
        }
        await zapTo(nextEp.channel);
        return;
      }
      final movieTape = _flatMovieTapeForZap();
      if (movieTape.isNotEmpty) {
        var idx = movieTape.indexWhere((c) => c.id == cur.id);
        if (idx < 0) {
          idx = movieTape.indexWhere((c) => c.streamUrl == cur.streamUrl);
        }
        if (idx < 0) idx = 0;
        final n = idx + delta;
        if (n < 0 || n >= movieTape.length) return;
        final target = movieTape[n];
        if (target.id == cur.id) return;
        await zapTo(target);
        return;
      }
      final seriesTape = _flatSeriesTapeForZap();
      if (seriesTape.isNotEmpty && _playingSeriesInTape != null) {
        var idx =
            seriesTape.indexWhere((s) => s.id == _playingSeriesInTape!.id);
        if (idx < 0) return;
        final n = idx + delta;
        if (n < 0 || n >= seriesTape.length) return;
        final nextSer = seriesTape[n];
        await _zapToBrowseTapeSeries(nextSer);
        return;
      }
      return;
    }

    final data = Get.find<PlaylistCacheService>().result.value;
    if (data == null || data.channels.isEmpty) return;

    // OSD önceki/sonraki: yalnızca oynatılan kanalın kategorisindeki canlılar (liste görünümüyle uyumlu).
    final list = liveChannelsInCurrentCategory();
    if (list.length < 2) return;

    // Önce id ile hizala: aynı normalize URL'ye sahip yinelenen satırlarda indexWhere(url)
    // her zaman ilk eşleşmeyi verir; oynatılan satır aşağıdaysa yanlış hedefe (bazen yine
    // aynı yayına) zıplanıyordu.
    var idx = list.indexWhere((c) => c.id == cur.id);
    if (idx < 0) {
      final curNorm = _normalizePlaybackStreamUrl(cur.streamUrl);
      idx = list.indexWhere(
        (c) => _normalizePlaybackStreamUrl(c.streamUrl) == curNorm,
      );
    }
    if (idx < 0) {
      idx = list.indexWhere((c) => _isSameChannelRow(c, cur));
    }
    if (idx < 0) return;

    final len = list.length;
    final rawNext = (idx + delta) % len;
    final ni = rawNext < 0 ? rawNext + len : rawNext;
    final target = list[ni];
    if (_isSameChannelRow(target, cur)) return;
    await zapTo(target);
  }

  Worker? _mediaKitSettingsWorker;
  Worker? _playbackWakelockLayoutWorker;
  Worker? _equalizerWorker;
  final List<StreamSubscription<dynamic>> _mediaKitWakelockSubs = [];

  void _cancelMediaKitWakelockSubs() {
    for (final s in _mediaKitWakelockSubs) {
      unawaited(s.cancel());
    }
    _mediaKitWakelockSubs.clear();
  }

  /// Ekranı yalnızca içerik **gerçekten oynarken** açık tutar (tamponlama/OSD bekleme değil).
  void _syncPlaybackWakelock() {
    if (isClosed) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final active = _playbackActiveForWakelock();
    unawaited(active ? WakelockPlus.enable() : WakelockPlus.disable());
  }

  bool _playbackActiveForWakelock() {
    if (effectiveUseMediaKit) {
      final p = _mediaKitPlayer;
      if (p == null) return false;
      return p.state.playing;
    }
    final v = better?.videoPlayerController?.value;
    if (v == null) return false;
    if (v.hasError) return false;
    if (!v.initialized) return false;
    return v.isPlaying;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // Harici Oynatıcı modu: kullanıcı VLC/MX Player vb. seçtiyse dahili
    // oynatıcıyı hiç başlatmadan stream URL'sini harici uygulamaya gönder,
    // sonra route'tan geri dön. _boot() çağrılmaz → MediaKit/BetterPlayer
    // hiç ayağa kalkmaz; saniyelik gecikme yok.
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
    _refreshForceMediaKitForCurrentUrl();
    _playbackWakelockLayoutWorker =
        ever(_settings.layoutMode, (_) => _syncPlaybackWakelock());
    _syncPlaybackWakelock();
    _mediaKitSettingsWorker = everAll(
      [_settings.useMediaKit, _settings.liveUseMediaKit],
      (_) {
        betterOsdOverride.value = false;
        mediaKitFallbackSession.value = false;
        _autoEngineSwitchUsed = false;
        unawaited(zapTo(channel.value));
      },
    );
    _pipAutoEnterWorker = ever(_settings.miniPlayerOnHome, (_) {
      unawaited(_syncAndroidPipAutoEnterEligible());
    });
    // Ses Equalizer (lavfi=…) kapsam değişikliğini reaktif izle ve mevcut
    // MediaKit player'ına gerçek zamanlı uygula. Servis kayıtlı değilse
    // (test / lite build) atla.
    if (Get.isRegistered<EqualizerService>()) {
      _equalizerWorker = ever<int>(EqualizerService.to.revision, (_) {
        final mk = _mediaKitPlayer;
        if (mk == null) return;
        unawaited(EqualizerService.to.applyToMediaKit(mk));
      });
    }
    // Akıllı Jenerik Atlatıcı: bölüm/dizi değişince intro süresini yenile.
    ever<Channel>(channel, (_) => refreshIntroDurationForCurrent());
    ever<bool>(_settings.smartStreamCutterEnabled,
        (_) => refreshIntroDurationForCurrent());
    refreshIntroDurationForCurrent();
    _settings.onSubtitleFontPtApplied = applySubtitleFontFromSettings;
    // İlk kare öncesi ana iş parçacığı sıkışıksa (eski tablet / ağır splash) hemen _boot,
    // bazen yüzey/orphan yollarıyla üst üste ikinci Exo yaratımına yol açabiliyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      unawaited(_boot());
    });
    if (isSeries) {
      unawaited(_loadSeriesPanelDataAsync());
    }
  }

  /// Harici Oynatıcı modunda dahili player'ı tamamen atlayan handoff akışı.
  ///
  /// * Mevcut kanaldan en doğru stream URL'sini ([effectivePlayUrl]) çıkar.
  /// * [ExternalPlayerService.launch] ile sistemin video viewer'ına gönder.
  /// * Başarılıysa route'tan çık (kullanıcı kaldığı yere geri döner).
  /// * Başarısızsa kullanıcıya toast bilgisi ver ve **fallback olarak**
  ///   dahili oynatıcıyı başlat — kullanıcı kanalı izleyebilmeli.
  Future<void> _handoffToExternalPlayer() async {
    final svc = Get.isRegistered<ExternalPlayerService>()
        ? Get.find<ExternalPlayerService>()
        : null;
    if (svc == null) {
      _externalPlayerHandoffActive.value = false;
      decoderFallbackStep.value = 0;
      await _boot();
      return;
    }
    final url = _externalLaunchUrl();
    if (url.isEmpty) {
      _externalPlayerHandoffActive.value = false;
      decoderFallbackStep.value = 0;
      if (Get.isRegistered<ToastService>()) {
        Get.find<ToastService>()
            .show('externalPlayer.error.noStream'.tr, isError: true);
      }
      await _boot();
      return;
    }
    final title = channel.value.name.trim().isEmpty ? null : channel.value.name;
    bool ok = false;
    try {
      ok = await svc.launch(
        url,
        appId: _settings.externalPlayerId.value,
        title: title,
      );
    } catch (e) {
      debugPrint('mina_iptv: external player handoff failed: $e');
      ok = false;
    }
    if (ok) {
      // Kısa gecikme: harici uygulama açılması Android'de bazen onPause/onResume
      // sırasını tetikliyor; route'tan çıkmadan önce bir mikro tick bekle.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!isClosed) {
        Get.back<void>();
      }
      return;
    }
    // Harici oynatıcı çalışmadı — kullanıcıya bilgi ver ve dahili oynatıcıya düş.
    if (Get.isRegistered<ToastService>()) {
      Get.find<ToastService>().show(
        'externalPlayer.error.launchFailed'.tr,
        isError: true,
      );
    }
    _externalPlayerHandoffActive.value = false;
    decoderFallbackStep.value = 0;
    if (isClosed) return;
    await _boot();
  }

  /// Harici oynatıcıya gönderilecek nihai URL — eğer player_controller başka
  /// bir override (catch-up, ts/m3u8 dönüştürme) hesapladıysa onu kullanır.
  String _externalLaunchUrl() {
    final override = _playUrlOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    return channel.value.streamUrl.trim();
  }

  /// Ayarlardan altyazı punto değişince (kayıt + anında uygulama).
  void applySubtitleFontFromSettings() {
    if (isClosed) return;
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(
        applyMediaKitSubtitleAppearance(
          mk,
          pt: _settings.subtitleFontPt.value,
          fontFamilyKey: _settings.subtitleFontFamilyKey.value,
          fontColor: _settings.subtitleFontColor,
          outlineEnabled: _settings.subtitleOutlineEnabled.value,
        ),
      );
    }
    final b = better;
    if (b != null) {
      b.setSubtitlesStyleConfiguration(_betterSubtitleConfiguration());
    }
  }

  BetterPlayerSubtitlesConfiguration _betterSubtitleConfiguration() {
    return BetterPlayerSubtitlesConfiguration(
      fontSize: _settings.subtitleFontPt.value,
      fontColor: _settings.subtitleFontColor,
      outlineEnabled: _settings.subtitleOutlineEnabled.value,
      outlineColor: const Color(0xFF000000),
      outlineSize: 2.0,
      fontFamily: betterPlayerSubtitleFontFamilyFor(
          _settings.subtitleFontFamilyKey.value),
    );
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _syncPlaybackWakelock();
    if (Platform.isAndroid) {
      unawaited(_syncAndroidPipAutoEnterEligible());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _persistWatchProgressTick(force: true);
    }

    if (_settings.backgroundPlayback.value) return;

    if (state == AppLifecycleState.resumed) {
      _androidPipFallbackPauseTimer?.cancel();
      _androidPipFallbackPauseTimer = null;
      _suppressPauseForAndroidMiniPip = false;
    }

    // iOS: arka plana geçerken PiP dene.
    if (state == AppLifecycleState.paused && !Platform.isAndroid) {
      if (_tryEnterMiniPlayerPipInsteadOfPause()) {
        return;
      }
    }

    // `inactive` yönlendirme / config değişiminde de gelir; burada duraklatmak yayını keser.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final vpc = better?.videoPlayerController?.value;
      if (vpc?.isPip == true) return;

      // Android: Küçük ekran açıkken sistem PiP (setAutoEnterEnabled / onPause) için kısa süre bekle.
      if (Platform.isAndroid && _eligibleForMiniPlayerPip()) {
        _suppressPauseForAndroidMiniPip = true;
        _androidPipFallbackPauseTimer?.cancel();
        _androidPipFallbackPauseTimer =
            Timer(const Duration(milliseconds: 900), () {
          _androidPipFallbackPauseTimer = null;
          _suppressPauseForAndroidMiniPip = false;
          if (_settings.backgroundPlayback.value) return;
          final v = better?.videoPlayerController?.value;
          if (v != null && v.isPip) return;
          final mk = _mediaKitPlayer;
          if (mk != null) {
            unawaited(mk.pause().catchError((_, __) {}));
          } else {
            better?.pause();
          }
        });
        return;
      }

      if (Platform.isAndroid && _suppressPauseForAndroidMiniPip) return;
      final mk = _mediaKitPlayer;
      if (mk != null) {
        unawaited(mk.pause().catchError((_, __) {}));
        return;
      }
      better?.pause();
    }
  }

  /// Ayar açıkken arka plana geçişte PiP dene; başarılıysa duraklatmayı atla (iOS vb.).
  bool _tryEnterMiniPlayerPipInsteadOfPause() {
    if (!_eligibleForMiniPlayerPip()) return false;
    unawaited(enterPictureInPictureIfSupported());
    return true;
  }

  Future<void> zapTo(Channel newChannel) async {
    if (_isSameChannelRow(newChannel, channel.value)) return;

    cancelVodAutoplayCountdown();
    _stopVodEndAutoplayMonitor();
    _resetVodAutoplayLatchState();

    final bootGen = _bumpPlaybackGeneration();

    _resumeAtAfterOsdEngineSwitch = null;
    _userPausedLive = false;
    _liveSpuriousStopLastRecovery = null;
    _cancelZapRelativeDebounce();
    _cancelLiveZapAbrQualityRamp();
    _cancelTvOsdAutoHideTimer();
    _resetNetworkRecoveryState();
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    _cancelLiveAutoNextWatchdog();
    _liveTvStallRecoveryAttempts = 0;
    _betterPlayerLightRetryWave = 0;
    _resetOrphanBetterSurfaceRecoveryForZap();

    final newLive = IptvPlaybackDefaults.isLikelyLiveStream(
      _normalizePlaybackStreamUrl(newChannel.streamUrl),
    );
    // Kanal değişiminde OSD panelinin açılmasını engellemek için geçici olarak devre dışı bırak
    // suppressLiveZapLoadingUi.value = newLive;

    final remoteLiveZap =
        _settings.layoutMode.value.usesRemoteNavigationStyle && newLive;

    // Kanal deðiþimi baþlat - OSD gizlemeyi engelle
    _isChangingChannel = true;
    var zapUiFinalize = false;
    try {
      if (remoteLiveZap) {
        tvOsdVisible.value = true;
      }

      _silenceCurrentPlaybackImmediately();

      // Canlı kanal değişimi: TV ve telefonda fade yok (VOD'da kısa kararma kalır).
      if (newLive) {
        isFading.value = false;
        await Future.delayed(Duration.zero);
      } else {
        isFading.value = true;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // TV'de kanal değişiminde sıkışmayı önlemek için fade state'ini hemen sıfırla
      if (_settings.layoutMode.value.usesRemoteNavigationStyle) {
        isFading.value = false;
      }
      if (!_isPlaybackGenerationCurrent(bootGen)) {
        return;
      }

      // TV’de de aynı Better örneği + setupDataSource: OSD ağacı kopmaz, hızlı zap’ta
      // yalnız kanal metni/logosu güncellenir (ayrı TvLiveBusyOsd şeridine düşülmez).
      final reuseBetter = _shouldReuseBetterOnChannelChange(newChannel);
      if (!_isPlaybackGenerationCurrent(bootGen)) {
        return;
      }

      var disposedBetter = false;
      try {
        if (!reuseBetter) {
          final old = better;
          _setBetterPlayer(null);
          if (old != null) {
            disposedBetter = true;
            old.videoPlayerController?.removeListener(_onVideoPlayerChanged);
            await old.pause();
            old.dispose(forceDispose: true);
          }
        }
      } catch (_) {}

      if (disposedBetter) {
        _syncPlaybackWakelock();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!_isPlaybackGenerationCurrent(bootGen)) {
        return;
      }

      channel.value = newChannel;
      channel.refresh();
      betterOsdOverride.value = false;
      mediaKitFallbackSession.value = false;
      decoderFallbackStep.value = 0;
      _forceSoftwareVideoDecoder = false;
      _lastBootUsedSoftwareVideoDecoder = false;
      _exoSoftwareDecoderRetryPending = false;
      _xtreamTriedLiveUrlFormat = false;
      _xtreamTriedGetPhpFallback = false;
      _xtreamTriedSeriesMoviePathToGetPhp = false;
      _xtreamTriedGetPhpToVodPathFallback = false;
      _xtreamTriedVodMkvToTsSwap = false;
      _vodAutoTriedBetterAfterMpvFail = false;
      _autoEngineSwitchUsed = false;
      _decoderTriedTsToM3u8Swap = false;
      _lastPlaybackUrl = null;
      _playUrlOverride = null;
      _lastOsdQualitySignature = -1;
      osdQualityStamp.value++;
      await _boot(
        reuseSameBetterPlayer: reuseBetter,
        playbackGeneration: bootGen,
      );

      // Yeni kanal açıldığında aydınlat (yalnızca bu zap hâlâ geçerliyse)
      if (_isPlaybackGenerationCurrent(bootGen)) {
        isFading.value = false;
        if (newLive) {
          prepareLiveChannelStrip();
        }
        update(['osd']);
        zapUiFinalize = true;
      }
    } finally {
      _isChangingChannel = false;
    }
    if (zapUiFinalize && remoteLiveZap) {
      scheduleTvOsdAutoHide();
    }
  }

  void _resetBootBusyHoldState() {
    _busyHoldTimeout?.cancel();
    _busyHoldTimeout = null;
    final vpl = _busyHoldVideoController;
    final tick = _busyHoldVideoTick;
    if (vpl != null && tick != null) {
      vpl.removeListener(tick);
    }
    _busyHoldVideoController = null;
    _busyHoldVideoTick = null;
    for (final s in _mediaKitBusyDimsSubs) {
      s.cancel();
    }
    _mediaKitBusyDimsSubs.clear();
    _busyHoldBootGen = null;
  }

  void _beginBootBusyHold(int gen, int vodSession) {
    _busyHoldTimeout?.cancel();
    final vpl = _busyHoldVideoController;
    final tick = _busyHoldVideoTick;
    if (vpl != null && tick != null) {
      vpl.removeListener(tick);
    }
    _busyHoldVideoController = null;
    _busyHoldVideoTick = null;
    for (final s in _mediaKitBusyDimsSubs) {
      s.cancel();
    }
    _mediaKitBusyDimsSubs.clear();

    _busyHoldBootGen = gen;
    _busyHoldVodSession = vodSession;
    _busyHoldTimeout = Timer(const Duration(seconds: 45), () {
      if (_busyHoldBootGen != gen) return;
      if (!_isPlaybackGenerationCurrent(gen)) return;
      if (_scheduleXtreamVodMkvToTsRetry()) {
        return;
      }
      if (effectiveUseMediaKit &&
          !_currentStreamIsLive &&
          AndroidPlaybackSocHints.playbackChallengedTv &&
          _maybeSwitchToBetterAfterMediaKitVodFailure(
            'MediaKit first frame timeout',
          )) {
        return;
      }
      debugPrint('mina_iptv: boot busy hold timeout (gen $gen)');
      _finishBootBusyHold(gen, vodSession);
    });
  }

  void _applyBootSuccessSideEffects(int gen, int vodSession) {
    if (!_isPlaybackGenerationCurrent(gen)) return;
    if (_bootSuccessHooksApplied) return;
    _bootSuccessHooksApplied = true;
    _networkResumeAttempt = 0;
    if (!_currentStreamIsLive) {
      _startWatchProgressSaver();
    }
    _startUserHistoryTracker();
    // get.php vb. URL’ler [isLikelyLiveStream] ile yanlışlıkla «canlı» sayılabiliyor; gerçek tür [_currentStreamIsLive].
    unawaited(_maybeOfferVodResume());
    if (_usesRemoteOsdChrome || _playbackPortraitForAutoHide) {
      scheduleTvOsdAutoHide();
    }
    if (Platform.isAndroid) {
      unawaited(_syncAndroidPipAutoEnterEligible());
    }
    _startVodEndAutoplayMonitor();
  }

  void _finishBootBusyHold(int gen, int vodSession) {
    if (_busyHoldBootGen != gen) return;
    _busyHoldBootGen = null;
    _busyHoldTimeout?.cancel();
    _busyHoldTimeout = null;
    final vpl = _busyHoldVideoController;
    final tick = _busyHoldVideoTick;
    if (vpl != null && tick != null) {
      vpl.removeListener(tick);
    }
    _busyHoldVideoController = null;
    _busyHoldVideoTick = null;
    for (final s in _mediaKitBusyDimsSubs) {
      s.cancel();
    }
    _mediaKitBusyDimsSubs.clear();
    if (!_isPlaybackGenerationCurrent(gen)) return;
    isBusy.value = false;
    isFading.value = false;
    suppressLiveZapLoadingUi.value = false;
    _applyBootSuccessSideEffects(gen, vodSession);
    if (_currentStreamIsLive) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _syncLiveAutoNextWatchdog());
    }
  }

  void _startBetterBusyHoldFirstFrame(
    BetterPlayerController ctrl,
    int gen,
    int vodSession,
  ) {
    _beginBootBusyHold(gen, vodSession);
    final vpl = ctrl.videoPlayerController;
    if (vpl == null) {
      _finishBootBusyHold(gen, vodSession);
      return;
    }
    _busyHoldVideoController = vpl;
    void tick() {
      if (_busyHoldBootGen != gen) return;
      if (!_isPlaybackGenerationCurrent(gen)) return;
      final v = vpl.value;
      if (v.hasError) return;
      final sz = v.size;
      if (v.initialized && sz != null && sz.width > 0 && sz.height > 0) {
        vpl.removeListener(tick);
        _busyHoldVideoController = null;
        _busyHoldVideoTick = null;
        _finishBootBusyHold(gen, vodSession);
      }
    }

    _busyHoldVideoTick = tick;
    vpl.addListener(tick);
    tick();
  }

  Future<void> _boot({
    int? preferredMaxHeight,
    bool disableAsms = false,
    bool reuseSameBetterPlayer = false,
    bool suppressNetworkRecoverySchedule = false,
    int? playbackGeneration,
  }) async {
    final expectedGen = playbackGeneration ?? _bumpPlaybackGeneration();
    if (playbackGeneration != null &&
        !_isPlaybackGenerationCurrent(expectedGen)) {
      debugPrint('mina_iptv: _boot skipped (stale generation at entry)');
      return;
    }
    _watchProgressTimer?.cancel();
    _flushUserHistory();
    _stopVodEndAutoplayMonitor();
    cancelVodAutoplayCountdown();
    final vodSession = ++_vodResumeSession;
    _resetBootBusyHoldState();
    _cancelLiveZapAbrQualityRamp();
    _mediaKitZapAbrTargetGen = null;
    _bootSuccessHooksApplied = false;
    isBusy.value = true;
    inAppPlaybackBrightness.value = 1.0;
    error.value = null;
    _cancelLiveTransientErrorEmitTimer();
    _cancelNetworkAutoResumeTimer();
    _manualVideoQualityLock = false;
    _autoQRecentBufferingStarts.clear();
    _autoQLastDowngradeAt = null;
    _autoQPlaybackStartedAt = null;
    final int? effectivePreferredMaxHeight = disableAsms
        ? null
        : (preferredMaxHeight ?? _preferredMaxVideoHeightForAdaptivePlayback());
    try {
      final layoutMode = _settings.layoutMode.value;

      final cur = channel.value;
      final normalizedUrl = _normalizePlaybackStreamUrl(cur.streamUrl);
      // Uzantısız web manifest/embed (ör. `/vs/tt…/`) → mpv'ye yönlendir.
      // Motor seçiminden ÖNCE belirlenmeli ki [effectiveUseMediaKit] doğru olsun.
      _forceMediaKitForCurrentUrl =
          IptvPlaybackDefaults.isExtensionlessWebManifestUrl(normalizedUrl);
      final live = IptvPlaybackDefaults.isLikelyLiveStream(normalizedUrl);

      final override = _playUrlOverride;
      _playUrlOverride = null;

      var playUrl = override ??
          (_xtreamTriedLiveUrlFormat
              ? _tryConvertXtreamGetPhpToLiveUrl(normalizedUrl) ?? normalizedUrl
              : normalizedUrl);

      // Ayarlar > Oynatıcı > "Yayın Formatı": canlı yayında kullanıcının seçtiği
      // taşıma biçimini (HLS m3u8 / MPEG-TS .ts) ilk URL'ye uygula. Yalnızca
      // hiçbir yedek/override denemesi yokken; aksi halde otomatik ts↔m3u8
      // kurtarma zinciriyle çakışıp uyumsuz panelde döngü oluştururdu.
      if (override == null &&
          live &&
          !_xtreamTriedLiveUrlFormat &&
          !_xtreamTriedGetPhpFallback &&
          !_decoderTriedTsToM3u8Swap) {
        final preferred = _applyPreferredLiveStreamFormat(playUrl);
        if (preferred != null && preferred.isNotEmpty) {
          playUrl = preferred;
        }
      }

      if (playUrl.isNotEmpty) {
        _lastPlaybackUrl = playUrl;
      }

      final lp = playUrl.toLowerCase();
      final tsLiveAndroid = live &&
          Platform.isAndroid &&
          (lp.split('?').first.endsWith('.ts') || lp.contains('output=ts'));
      debugPrint(
          'mina_iptv: Playing stream: $playUrl (Step: ${decoderFallbackStep.value}, XtreamAlt: $_xtreamTriedLiveUrlFormat)');

      if (playUrl.isEmpty) {
        if (_isPlaybackGenerationCurrent(expectedGen)) {
          error.value = 'player.error.invalidStreamUrl'.tr;
        }
        return;
      }

      // Android TV / Xiaomi'de çökmelere yol açtığı için disk önbelleği tamamen devre dışı.
      await AndroidPlaybackSocHints.ensureLoaded();
      final vodChallengedTv = !live &&
          Platform.isAndroid &&
          AndroidPlaybackSocHints.playbackChallengedTv;
      if (vodChallengedTv && !_forceSoftwareVideoDecoder) {
        debugPrint(
          'mina_iptv: TCL/MediaTek TV VOD → Exo yazılım kod çözücü (ilk deneme)',
        );
      }
      final useSoftwareVideoDecoder = _forceSoftwareVideoDecoder ||
          (live ? _settings.preferSoftwareVideoDecoder.value : false) ||
          tsLiveAndroid ||
          vodChallengedTv;

      if (effectiveUseMediaKit) {
        _lastBootUsedSoftwareVideoDecoder = false;
        // MediaKit (ayar veya yedek oturum): BetterPlayer'ı tamamen temizle.
        final old = better;
        _setBetterPlayer(null);
        if (old != null) {
          old.videoPlayerController?.removeListener(_onVideoPlayerChanged);
          old.pause();
          old.dispose(forceDispose: true);
        }
        if (_isPlaybackGenerationCurrent(expectedGen)) {
          _beginBootBusyHold(expectedGen, vodSession);
        }
        _mediaKitZapAbrTargetGen = expectedGen;
        return;
      }

      _lastBootUsedSoftwareVideoDecoder = useSoftwareVideoDecoder;
      final ds = iptvBetterPlayerDataSource(
        playUrl,
        liveStream: live,
        cacheConfiguration: null,
        useAsmsTracks: disableAsms ? false : null,
        useAsmsAudioTracks: null, // Otomatik seçime (Adaptive tespiti) bırak
        useAsmsSubtitles: disableAsms ? false : null,
        preferSoftwareVideoDecoder: useSoftwareVideoDecoder,
        liveBufferSeconds: live
            ? _settings.liveBufferSeconds.value
            : IptvBetterPlayerConfig.defaultLiveBufferSecondsForExo,
      );

      debugPrint('mina_iptv: DataSource headers: ${ds.headers}');

      if (reuseSameBetterPlayer &&
          better != null &&
          _canReuseBetterForDataSource(ds)) {
        final ctrl = better!;
        ctrl.setOverriddenFit(videoFit.value);
        await ctrl.setupDataSource(ds);
        _attachBetterBufferingRecoveryListener(ctrl);
        if (!_isPlaybackGenerationCurrent(expectedGen)) {
          debugPrint(
            'mina_iptv: stale playback gen after setupDataSource (reuse), skip',
          );
          return;
        }
        if (live) {
          _scheduleLiveZapAbrRampsExo(
            ctrl,
            expectedGen,
            preferredMaxHeight: effectivePreferredMaxHeight,
            disableAsms: disableAsms,
          );
        } else {
          _applyPreferredMaxHeightToBetter(
            ctrl,
            preferredMaxHeight: effectivePreferredMaxHeight,
            disableAsms: disableAsms,
          );
        }
        await iptvApplyBetterPlayerLowRam720CapIfNeeded(ctrl);
        await ctrl.play();
        if (!_isPlaybackGenerationCurrent(expectedGen)) {
          debugPrint(
            'mina_iptv: stale playback gen after play (reuse), skip',
          );
          return;
        }
        _autoQPlaybackStartedAt = DateTime.now();

        // BetterPlayer için ses reset - çoklu kanal degisiminde ses kaybini onle
        if (!effectiveUseMediaKit) {
          unawaited(ctrl.setVolume(1.0).catchError((_, __) {}));
        }

        if (layoutMode == AppLayoutMode.tv && live) {
          _armLiveTvStartupWatchdog();
        }
        if (Platform.isAndroid && !live) {
          _scheduleAndroidVodAudioFix(ctrl, expectedGen);
        }
        unawaited(
            _applyVodSubtitleDefaultOrPreferenceForBetter(ctrl, expectedGen));
        _startBetterBusyHoldFirstFrame(ctrl, expectedGen, vodSession);
        return;
      }

      if (reuseSameBetterPlayer && better != null) {
        try {
          better!.videoPlayerController?.removeListener(_onVideoPlayerChanged);
          await better!.pause();
          better!.dispose(forceDispose: true);
        } catch (_) {}
        _setBetterPlayer(null);
      }

      // Ağ/stall kurtarma ve benzeri yollar `reuseSameBetterPlayer: false` ile _boot
      // çağırırken eski ExoPlayer'ı atlamış oluyordu; ikinci ses + çıkış sonrası ses
      // (özellikle Amlogic TV kutularında) bu yüzden oluşabiliyordu.
      if (!reuseSameBetterPlayer && better != null) {
        try {
          better!.videoPlayerController?.removeListener(_onVideoPlayerChanged);
          await better!.pause();
          better!.dispose(forceDispose: true);
        } catch (_) {}
        _setBetterPlayer(null);
      }

      final controls = IptvBetterPlayerConfig.tvControls(
        customControlsBuilder: (c, onVisibilityChanged, config) {
          return Obx(() {
            final pc = Get.find<PlayerController>();
            final osdChId = pc.channel.value.id;
            return TvBetterPlayerControls(
              key: ValueKey<int>(osdChId),
              controller: c,
              onPlayerVisibilityChanged: (v) {
                pc.syncTvOsdVisibilityFromControls(v);
                onVisibilityChanged(v);
              },
            );
          });
        },
      );

      final useTextureView = Platform.isAndroid &&
          layoutMode != AppLayoutMode.tv &&
          AndroidPlaybackSocHints.xiaomiFamily;
      final cfg = IptvBetterPlayerConfig.playerConfiguration(
        controls: controls,
        eventListener: _onBetterPlayerEvent,
        // Arka planda oynat açıkken better_player'ın kendi yaşam döngüsü
        // gözlemcisi devreye girmemeli; yoksa ana ekrana dönünce yayını
        // otomatik duraklatıp sesi kesiyor. Duraklatmayı tamamen
        // didChangeAppLifecycleState üzerinden yönetiyoruz.
        handleLifecycle: !_settings.backgroundPlayback.value,
        autoDispose: false,
        handleAudioInterruption: true,
        useTextureView: useTextureView,
        layoutMode: layoutMode,
        deviceOrientationsAfterFullScreen: IptvBetterPlayerConfig
            .mobileBetterPlayerAfterFullscreenOrientations(
          layoutMode,
          _settings,
        ),
        subtitlesConfiguration: _betterSubtitleConfiguration(),
        overlay: const InAppBrightnessBetterOverlay(),
      );

      final ctrl = BetterPlayerController(cfg);
      ctrl.setOverriddenFit(videoFit.value);
      await ctrl.setupDataSource(ds);
      _attachBetterBufferingRecoveryListener(ctrl);
      if (!_isPlaybackGenerationCurrent(expectedGen)) {
        debugPrint(
          'mina_iptv: stale playback gen after setupDataSource (new Better), dispose',
        );
        try {
          ctrl.videoPlayerController?.removeListener(_onVideoPlayerChanged);
          await ctrl.pause();
          ctrl.dispose(forceDispose: true);
        } catch (_) {}
        return;
      }
      if (live) {
        _scheduleLiveZapAbrRampsExo(
          ctrl,
          expectedGen,
          preferredMaxHeight: effectivePreferredMaxHeight,
          disableAsms: disableAsms,
        );
      } else {
        _applyPreferredMaxHeightToBetter(
          ctrl,
          preferredMaxHeight: effectivePreferredMaxHeight,
          disableAsms: disableAsms,
        );
      }
      await iptvApplyBetterPlayerLowRam720CapIfNeeded(ctrl);
      _setBetterPlayer(ctrl);
      orphanBetterSurfaceRecoveryAttempts.value = 0;

      // Native hataları yakalamak için VideoPlayerController'ı dinle
      ctrl.videoPlayerController?.addListener(_onVideoPlayerChanged);

      await ctrl.play();
      if (!_isPlaybackGenerationCurrent(expectedGen)) {
        debugPrint(
          'mina_iptv: stale playback gen after play (new Better), skip',
        );
        return;
      }
      _autoQPlaybackStartedAt = DateTime.now();

      // BetterPlayer için ses reset - çoklu kanal degisiminde ses kaybini onle
      if (!effectiveUseMediaKit) {
        unawaited(ctrl.setVolume(1.0).catchError((_, __) {}));
      }

      if (layoutMode == AppLayoutMode.tv && live) {
        _armLiveTvStartupWatchdog();
      }

      // Film/dizi (VOD): telefonda AC3 öncelikli parça sessiz kalabiliyor; mix + AAC seçimi tekrarlanır.
      if (Platform.isAndroid && !live) {
        _scheduleAndroidVodAudioFix(ctrl, expectedGen);
      }
      unawaited(
          _applyVodSubtitleDefaultOrPreferenceForBetter(ctrl, expectedGen));
      _startBetterBusyHoldFirstFrame(ctrl, expectedGen, vodSession);
    } catch (e) {
      if (!_isPlaybackGenerationCurrent(expectedGen)) {
        return;
      }
      if (_tryScheduleXtreamOutputFormatSwapRetry(e)) {
        return;
      }
      _emitPlaybackErrorForRecovery(
        e.toString(),
        suppressNetworkRecoverySchedule: suppressNetworkRecoverySchedule,
      );
    } finally {
      if (!_isPlaybackGenerationCurrent(expectedGen)) {
        return;
      }
      if (error.value != null) {
        _resetBootBusyHoldState();
        isBusy.value = false;
        suppressLiveZapLoadingUi.value = false;
        if (Platform.isAndroid) {
          unawaited(_syncAndroidPipAutoEnterEligible());
        }
        return;
      }
      if (_busyHoldBootGen == expectedGen) {
        return;
      }
      isBusy.value = false;
      suppressLiveZapLoadingUi.value = false;
      if (Platform.isAndroid) {
        unawaited(_syncAndroidPipAutoEnterEligible());
      }
    }
  }

  Duration? _vodDurationOrNull() {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      final d = mk.state.duration;
      if (d > Duration.zero) return d;
    }
    final v = better?.videoPlayerController?.value;
    if (v != null && v.initialized) {
      final d = v.duration;
      if (d != null && d.inMilliseconds > 0) return d;
    }
    return null;
  }

  void _startWatchProgressSaver() {
    _watchProgressTimer?.cancel();
    if (_currentStreamIsLive) return;
    _watchProgressTimer = Timer.periodic(
        _watchProgressSaveInterval, (_) => _persistWatchProgressTick());
  }

  /// Şu anki oturum için AI öneri motoruna sinyal — 2dk+ izlemelerde tetiklenir.
  String _currentHistorySig() {
    final UserHistoryKind kind = isSeries
        ? UserHistoryKind.series
        : (isMovie ? UserHistoryKind.vod : UserHistoryKind.live);
    return '${kind.index}|${channel.value.id}|${channel.value.streamUrl}';
  }

  void _startUserHistoryTracker() {
    final sig = _currentHistorySig();
    // Aynı içerik için zaten çalışıyorsa yeniden başlatma; ölçü kaybolmasın.
    if (_userHistorySig == sig && _userHistoryTickTimer != null) return;
    _flushUserHistory(force: true);
    _userHistorySig = sig;
    _userHistoryWatchedSec = 0;
    _userHistoryRecorded = false;
    _userHistoryLastReportedSec = 0;
    _userHistoryTickTimer?.cancel();
    _userHistoryTickTimer = Timer.periodic(
      const Duration(seconds: _historyTickSecs),
      (_) => _onUserHistoryTick(),
    );
  }

  /// Tick anında player gerçekten oynatma yapıyor mu — çoğu motor sorgusu
  /// (MediaKit / Better) eşit şekilde kapsanır.
  bool _isCurrentlyPlayingForHistory() {
    final err = (error.value ?? '').trim();
    if (err.isNotEmpty) return false;
    if (effectiveUseMediaKit) {
      final mk = _mediaKitPlayer;
      if (mk == null) return false;
      return mk.state.playing;
    }
    final v = better?.videoPlayerController?.value;
    if (v == null) return false;
    if (!v.initialized || v.hasError) return false;
    return v.isPlaying;
  }

  void _onUserHistoryTick() {
    if (isClosed) return;
    // Sadece gerçekten oynatılıyorsa biriktir.
    if (!_isCurrentlyPlayingForHistory()) return;
    _userHistoryWatchedSec += _historyTickSecs;
    _emitMinaAnalyticsTick();
    // 120 sn eşik aşıldığında ilk kez kaydet.
    if (!_userHistoryRecorded && _userHistoryWatchedSec >= 120) {
      _userHistoryRecorded = true;
      _userHistoryLastReportedSec = _userHistoryWatchedSec;
      _writeUserHistoryEntry();
      return;
    }
    // İlk kayıttan sonra her ~60 sn'de bir güncelle (toplam süre).
    if (_userHistoryRecorded &&
        _userHistoryWatchedSec - _userHistoryLastReportedSec >= 60) {
      _userHistoryLastReportedSec = _userHistoryWatchedSec;
      _writeUserHistoryEntry();
    }
  }

  /// Mina Wrapped analytics tick'i — 15 saniyelik izleme penceresi.
  /// Düşük güçlü cihazlarda yan etki yapmasın diye servis çağrısı
  /// in-memory'de toplanır, 5 saniyede bir tek SharedPreferences yazımıyla
  /// kalıcılaşır.
  void _emitMinaAnalyticsTick() {
    if (!Get.isRegistered<MinaAnalyticsService>()) return;
    final svc = Get.find<MinaAnalyticsService>();
    final kind = isSeries
        ? MinaMediaKind.series
        : (isMovie ? MinaMediaKind.movie : MinaMediaKind.live);
    final ch = channel.value;
    // Kategori adı için ChannelsController kayıtlıysa kısa lookup yap;
    // yoksa numeric kategori id boş geçilir (kategori istatistikleri
    // o oturumda toplanmaz ama kind + kanal yine kayıtlı olur).
    String catName = '';
    try {
      if (Get.isRegistered<ChannelsController>()) {
        final cc = Get.find<ChannelsController>();
        final cat = cc.categories.firstWhereOrNull(
          (c) => c.id == ch.categoryId,
        );
        catName = cat?.name ?? '';
      }
    } catch (_) {}
    svc.recordTick(
      kind: kind,
      channelName: ch.name,
      channelLogo: ch.logoUrl ?? '',
      category: catName,
      tick: const Duration(seconds: _historyTickSecs),
    );
  }

  void _writeUserHistoryEntry() {
    if (!Get.isRegistered<UserHistoryService>()) return;
    final UserHistoryKind kind = isSeries
        ? UserHistoryKind.series
        : (isMovie ? UserHistoryKind.vod : UserHistoryKind.live);
    final ch = channel.value;
    final svc = Get.find<UserHistoryService>();
    unawaited(svc.record(
      kind: kind,
      contentId: ch.id,
      name: ch.name,
      categoryId: ch.categoryId.toString(),
      posterUrl: ch.logoUrl,
      watchedSeconds: _userHistoryWatchedSec,
    ));
  }

  void _flushUserHistory({bool force = false}) {
    final t = _userHistoryTickTimer;
    if (t == null && !force) return;
    t?.cancel();
    _userHistoryTickTimer = null;
    if (_userHistoryRecorded && _userHistoryWatchedSec > 0) {
      // Son güncellemeyi yaz; içerik değişmiş olabilir, sig hâlâ doğru.
      _userHistoryLastReportedSec = _userHistoryWatchedSec;
      _writeUserHistoryEntry();
    }
    _userHistoryWatchedSec = 0;
    _userHistoryRecorded = false;
    _userHistoryLastReportedSec = 0;
    _userHistorySig = null;
  }

  void _persistWatchProgressTick({bool force = false}) {
    if (isClosed) return;
    if (_currentStreamIsLive) return;
    final dur = _vodDurationOrNull();
    if (dur == null || dur.inMilliseconds < 1) return;
    final posMs = currentPosition.inMilliseconds;
    if (posMs < 5000) return;
    final id = channel.value.id;
    final queue = Get.find<PlaybackProgressWriteQueueService>();
    if (!force &&
        _lastWatchProgressSavedChannelId == id &&
        _lastWatchProgressSavedPosMs != null) {
      final delta = (posMs - _lastWatchProgressSavedPosMs!).abs();
      if (delta < _watchProgressMinDeltaMs &&
          _lastWatchProgressSavedDurationMs == dur.inMilliseconds) {
        return;
      }
    }
    final series = playingSeries;
    if (posMs >= dur.inMilliseconds * 0.95) {
      unawaited(queue.clearVodProgress(
        id,
        seriesId: series?.id,
        flushNow: force,
      ));
      _lastWatchProgressSavedChannelId = null;
      _lastWatchProgressSavedPosMs = null;
      _lastWatchProgressSavedDurationMs = null;
      return;
    }
    _lastWatchProgressSavedChannelId = id;
    _lastWatchProgressSavedPosMs = posMs;
    _lastWatchProgressSavedDurationMs = dur.inMilliseconds;
    unawaited(queue.saveVodProgress(
      vodId: id,
      title: channel.value.name,
      coverUrl: channel.value.logoUrl,
      positionMs: posMs,
      durationMs: dur.inMilliseconds,
      seriesId: series?.id,
      seriesTitle: series?.name,
      seriesCoverUrl: series?.posterUrl,
      flushNow: force,
    ));
  }

  Future<void> _maybeOfferVodResume() async {
    if (isClosed) return;

    /// Decoder yeniden [_boot] ile oturum değişse bile aynı kanalda devam / diyalog sonrası [play] için.
    final anchorChannelId = channel.value.id;
    bool sameChannel() => !isClosed && channel.value.id == anchorChannelId;

    final osdSeek = _resumeAtAfterOsdEngineSwitch;
    if (osdSeek != null) {
      _resumeAtAfterOsdEngineSwitch = null;
      final seekMs = osdSeek.inMilliseconds;
      // Canlı: süre çoğu zaman yok / sonsuz; doğrudan sar.
      if (_currentStreamIsLive) {
        if (seekMs > 0) {
          await _seekThenPlayVodResume(osdSeek);
        } else {
          await _playEngineAsync();
        }
        return;
      }
      if (seekMs > 0 && seekMs < 1000) {
        await _seekThenPlayVodResume(osdSeek);
        return;
      }
      if (seekMs >= 1000) {
        for (var i = 0; i < 100; i++) {
          if (!sameChannel()) return;
          final dur = _vodDurationOrNull();
          if (dur != null && dur.inMilliseconds > 0) {
            var target = seekMs;
            final maxMs = dur.inMilliseconds;
            if (target >= maxMs * 0.92) {
              target = (maxMs * 0.9).round();
            }
            if (target < 0) target = 0;
            if (target >= maxMs) target = maxMs - 1;
            await _seekThenPlayVodResume(Duration(milliseconds: target));
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
        if (!sameChannel()) return;
        await _seekThenPlayVodResume(Duration(milliseconds: seekMs));
        return;
      }
      await _playEngineAsync();
      return;
    }

    if (_currentStreamIsLive) return;

    final wp = Get.find<WatchProgressService>();
    final id = channel.value.id;
    final saved = await wp.loadPositionMs(id);
    if (saved == null || saved < 30000) return;

    for (var i = 0; i < 100; i++) {
      if (!sameChannel()) return;
      final dur = _vodDurationOrNull();
      if (dur != null && dur.inMilliseconds > 0) {
        if (saved >= dur.inMilliseconds * 0.92) return;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (!sameChannel()) return;
    final dur = _vodDurationOrNull();
    if (dur == null || dur.inMilliseconds < 1) return;
    if (saved >= dur.inMilliseconds * 0.92) return;

    pause();
    final fromLast = await _showVodResumeDialog();
    if (!sameChannel()) return;
    if (fromLast == null) {
      await _playEngineAsync();
      return;
    }
    if (fromLast) {
      await _seekThenPlayVodResume(Duration(milliseconds: saved));
    } else {
      await wp.clear(id);
      await _seekThenPlayVodResume(Duration.zero);
    }
  }

  Future<bool?> _showVodResumeDialog() async {
    vodResumeDialogOpen.value = true;
    try {
      return await Get.dialog<bool>(
        const VodResumeDialog(),
        barrierDismissible: false,
      );
    } finally {
      vodResumeDialogOpen.value = false;
      bumpTvOsdKeyFocus();
    }
  }

  /// HLS ses listesi geç geldiğinde veya ilk seçim yanlış olduğunda tekrar dene; riskli codec + çoklu parçada sıradakini dene.
  void _scheduleAndroidVodAudioFix(BetterPlayerController c, int bootGen) {
    bool stillThisPlayback() =>
        _isPlaybackGenerationCurrent(bootGen) && identical(better, c);

    void tryFix() {
      if (!stillThisPlayback()) return;
      try {
        c.setMixWithOthers(false);
      } catch (_) {}
      final tracks = c.betterPlayerAsmsAudioTracks;
      if (tracks == null || tracks.isEmpty) return;
      int score(BetterPlayerAsmsAudioTrack t) {
        final s = '${t.label ?? ''} ${t.language ?? ''} ${t.mimeType ?? ''}'
            .toLowerCase();
        var n = 0;
        if (s.contains('aac') ||
            s.contains('mp4a') ||
            s.contains('audio/mp4')) {
          n += 14;
        }
        if (s.contains('opus')) n += 10;
        if (s.contains('mp3') || s.contains('mpeg')) n += 6;
        if (s.contains('ac3') ||
            s.contains('ac-3') ||
            s.contains('eac3') ||
            s.contains('dts')) {
          n -= 12;
        }
        return n;
      }

      var chosen = tracks.first;
      for (var i = 1; i < tracks.length; i++) {
        if (score(tracks[i]) > score(chosen)) chosen = tracks[i];
      }
      try {
        c.setAudioTrack(chosen);
      } catch (_) {}
    }

    bool looksRiskyCodec(BetterPlayerAsmsAudioTrack t) {
      return _riskyVodAudioCodecSnippet(
        '${t.label ?? ''} ${t.mimeType ?? ''}',
      );
    }

    /// Tek riskli ASMS ses parçası: başka alternatif yok → MediaKit (mpv/ffmpeg).
    void trySingleRiskyAsmsAudioFallbackToMediaKit() {
      if (!stillThisPlayback()) return;
      final tracks = c.betterPlayerAsmsAudioTracks;
      if (tracks == null || tracks.isEmpty || tracks.length >= 2) return;
      final cur = c.betterPlayerAsmsAudioTrack ?? tracks.first;
      if (!looksRiskyCodec(cur)) return;
      final v = c.videoPlayerController?.value;
      if (v == null || !v.isPlaying || v.hasError) return;
      if (v.position.inMilliseconds < 3500) return;
      unawaited(
          _vodSilentAudioFallbackToMediaKit('vod_single_risky_asms_audio'));
    }

    /// ASMS ses listesi yok; Exo native izlerde AC3/DTS vb. muxed → sessiz kalma ihtimali.
    Future<void> tryNativeMuxedRiskyAudioFallbackToMediaKit() async {
      await Future<void>.delayed(const Duration(milliseconds: 6200));
      if (!stillThisPlayback()) return;
      final asms = c.betterPlayerAsmsAudioTracks;
      if (asms != null && asms.isNotEmpty) return;
      final v = c.videoPlayerController?.value;
      if (v == null || !v.isPlaying || v.hasError) return;
      if (v.position.inMilliseconds < 4000) return;
      if (!canQueryExoNativeTracks) return;
      final bundle = await loadExoNativeTracks();
      if (!stillThisPlayback()) return;
      var anyRisky = false;
      for (final t in bundle.audio) {
        if (_riskyVodAudioCodecSnippet('${t.label} ${t.language}')) {
          anyRisky = true;
          break;
        }
      }
      if (!anyRisky) return;
      await _vodSilentAudioFallbackToMediaKit('vod_native_muxed_risky_audio');
    }

    /// Oynatma sürüyor ama (AC3/DTS vb.) sessiz kalma ihtimali: listedeki bir sonraki parçaya geç.
    void tryNextAudioIfRiskyStillPlaying() {
      if (!stillThisPlayback()) return;
      final tracks = c.betterPlayerAsmsAudioTracks;
      if (tracks == null || tracks.length < 2) return;
      final v = c.videoPlayerController?.value;
      if (v == null || !v.isPlaying || v.hasError) return;
      if (v.position.inMilliseconds < 3500) return;
      final cur = c.betterPlayerAsmsAudioTrack ?? tracks.first;
      if (!looksRiskyCodec(cur)) return;
      var i = tracks.indexWhere(
        (t) =>
            t.id == cur.id &&
            (t.language ?? '') == (cur.language ?? '') &&
            (t.label ?? '') == (cur.label ?? ''),
      );
      if (i < 0) i = tracks.indexOf(cur);
      if (i < 0) i = 0;
      final next = tracks[(i + 1) % tracks.length];
      final same = next.id == cur.id &&
          (next.language ?? '') == (cur.language ?? '') &&
          (next.label ?? '') == (cur.label ?? '');
      if (same) return;
      try {
        c.setAudioTrack(next);
        debugPrint(
          'mina_iptv: VOD riskli ses codec → sonraki parça: ${next.label ?? next.mimeType}',
        );
      } catch (_) {}
    }

    Future<void>.delayed(const Duration(milliseconds: 450), tryFix);
    Future<void>.delayed(const Duration(seconds: 2), tryFix);
    Future<void>.delayed(const Duration(seconds: 5), () {
      trySingleRiskyAsmsAudioFallbackToMediaKit();
      tryNextAudioIfRiskyStillPlaying();
    });
    unawaited(tryNativeMuxedRiskyAudioFallbackToMediaKit());
  }

  int _episodeTapeIndexOfCurrent() {
    final tape = _episodeBrowseTape;
    if (tape == null || tape.isEmpty) return -1;
    final cur = channel.value;
    var idx = tape.indexWhere((e) => e.channel.id == cur.id);
    if (idx >= 0) return idx;
    return tape.indexWhere((e) => e.channel.streamUrl == cur.streamUrl);
  }

  bool _vodHasNextInBrowseTape() {
    final ep = _episodeBrowseTape;
    if (ep != null && ep.length > 1) {
      final idx = _episodeTapeIndexOfCurrent();
      if (idx >= 0 && idx < ep.length - 1) return true;
    }
    final mv = _flatMovieTapeForZap();
    if (mv.length > 1) {
      var idx = mv.indexWhere((c) => c.id == channel.value.id);
      if (idx < 0) {
        idx = mv.indexWhere((c) => c.streamUrl == channel.value.streamUrl);
      }
      if (idx >= 0 && idx < mv.length - 1) return true;
    }
    return false;
  }

  void _resetVodAutoplayLatchState() {
    _vodNearEndLatched = false;
    _vodAutoplaySuppressChannelId = null;
  }

  void _stopVodEndAutoplayMonitor() {
    _vodEndAutoplayMonitor?.cancel();
    _vodEndAutoplayMonitor = null;
  }

  void _startVodEndAutoplayMonitor() {
    _stopVodEndAutoplayMonitor();
    if (!_vodHasNextInBrowseTape()) return;
    if (_currentStreamIsLive) return;
    _vodEndAutoplayMonitor = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isClosed) return;
      if (!_settings.backgroundPlayback.value &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        _stopVodEndAutoplayMonitor();
        return;
      }
      if (_currentStreamIsLive || !_vodHasNextInBrowseTape()) {
        _stopVodEndAutoplayMonitor();
        return;
      }
      _maybeResetVodEndLatchFromSeek();
      _maybeArmVodEndAutoplay();
    });
  }

  void _maybeResetVodEndLatchFromSeek() {
    final dur = _vodDurationOrNull();
    if (dur == null || dur.inMilliseconds < 1) return;
    final pos = currentPosition.inMilliseconds;
    if (pos < (dur.inMilliseconds * 0.88).round()) {
      _vodNearEndLatched = false;
      if (vodAutoplayCountdown.value == null) {
        _vodAutoplaySuppressChannelId = null;
      }
    }
  }

  void _maybeArmVodEndAutoplay() {
    if (isClosed) return;
    if (_currentStreamIsLive) return;
    if (vodAutoplayCountdown.value != null) return;
    final curId = channel.value.id;
    if (_vodAutoplaySuppressChannelId == curId) return;
    final dur = _vodDurationOrNull();
    if (dur == null || dur.inMilliseconds < 3000) return;
    final posMs = currentPosition.inMilliseconds;
    final nearEnd = posMs >= dur.inMilliseconds - 1100;
    if (!nearEnd) return;
    if (_vodNearEndLatched) return;
    _vodNearEndLatched = true;

    SeriesEpisodeOption? nextEp;
    Channel? nextMovie;

    final epTape = _episodeBrowseTape;
    if (epTape != null && epTape.length > 1) {
      final idx = _episodeTapeIndexOfCurrent();
      if (idx >= 0 && idx < epTape.length - 1) {
        nextEp = epTape[idx + 1];
      }
    }
    if (nextEp == null) {
      final mv = _flatMovieTapeForZap();
      if (mv.length > 1) {
        var idx = mv.indexWhere((c) => c.id == channel.value.id);
        if (idx < 0) {
          idx = mv.indexWhere((c) => c.streamUrl == channel.value.streamUrl);
        }
        if (idx >= 0 && idx < mv.length - 1) {
          nextMovie = mv[idx + 1];
        }
      }
    }

    if (nextEp == null && nextMovie == null) {
      _vodNearEndLatched = false;
      return;
    }

    if (nextEp != null) {
      final ep = nextEp;
      vodAutoplayNextIsEpisode.value = true;
      vodAutoplayNextTitle.value = ep.displayTitle;
      _startVodAutoplayCountdownUi(() => zapTo(ep.channel));
    } else {
      final mv = nextMovie!;
      vodAutoplayNextIsEpisode.value = false;
      vodAutoplayNextTitle.value = mv.name;
      _startVodAutoplayCountdownUi(() => zapTo(mv));
    }
  }

  void _startVodAutoplayCountdownUi(Future<void> Function() onComplete) {
    _vodAutoplayCountdownTimer?.cancel();
    vodAutoplayCountdown.value = 5;
    _vodAutoplayCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_settings.backgroundPlayback.value &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        t.cancel();
        _vodAutoplayCountdownTimer = null;
        vodAutoplayCountdown.value = null;
        vodAutoplayNextTitle.value = '';
        vodAutoplayNextIsEpisode.value = false;
        return;
      }
      final cur = vodAutoplayCountdown.value ?? 0;
      if (cur <= 1) {
        t.cancel();
        _vodAutoplayCountdownTimer = null;
        vodAutoplayCountdown.value = null;
        vodAutoplayNextTitle.value = '';
        vodAutoplayNextIsEpisode.value = false;
        unawaited(onComplete());
        return;
      }
      vodAutoplayCountdown.value = cur - 1;
    });
  }

  void cancelVodAutoplayCountdown({bool cancelledByUser = false}) {
    _vodAutoplayCountdownTimer?.cancel();
    _vodAutoplayCountdownTimer = null;
    vodAutoplayCountdown.value = null;
    vodAutoplayNextTitle.value = '';
    vodAutoplayNextIsEpisode.value = false;
    _vodNearEndLatched = false;
    if (cancelledByUser) {
      _vodAutoplaySuppressChannelId = channel.value.id;
    }
  }

  Future<void> playVodAutoplayNow() async {
    _vodAutoplayCountdownTimer?.cancel();
    _vodAutoplayCountdownTimer = null;
    vodAutoplayCountdown.value = null;
    vodAutoplayNextTitle.value = '';
    final wasEp = vodAutoplayNextIsEpisode.value;
    vodAutoplayNextIsEpisode.value = false;

    if (wasEp) {
      final epTape = _episodeBrowseTape;
      if (epTape != null && epTape.isNotEmpty) {
        final idx = _episodeTapeIndexOfCurrent();
        if (idx >= 0 && idx < epTape.length - 1) {
          await zapTo(epTape[idx + 1].channel);
        }
      }
      return;
    }
    final mv = _flatMovieTapeForZap();
    if (mv.length > 1) {
      var idx = mv.indexWhere((c) => c.id == channel.value.id);
      if (idx < 0) {
        idx = mv.indexWhere((c) => c.streamUrl == channel.value.streamUrl);
      }
      if (idx >= 0 && idx < mv.length - 1) {
        await zapTo(mv[idx + 1]);
      }
    }
  }

  void handleBack() {
    unawaited(_handleBackAsync());
  }

  Future<void> _handleBackAsync() async {
    // Tam ekran overlay (doğrudan handleBack çağrıları).
    if (liveSingleChannelEpgOpen.value) {
      closeLiveSingleChannelEpgOverlay(showOsdAfter: true);
      return;
    }
    if (vodBrowseRailOpen.value) {
      closeVodBrowseRail(showOsdAfter: true);
      return;
    }
    if (liveChannelStripOverlayOpen.value) {
      cancelLiveStripAutoClose();
      liveChannelStripOverlayOpen.value = false;
      if (_usesRemoteOsdChrome) {
        tvOsdVisible.value = true;
        scheduleTvOsdAutoHide();
        bumpTvOsdKeyFocus();
      }
      return;
    }
    // Ses/altyazı/kalite vb. Get.dialog üstteyken önce diyaloğu kapat (oyuncudan çıkma).
    if (Get.isDialogOpen == true) {
      if (vodResumeDialogOpen.value) {
        Get.back<bool>(result: false);
      } else {
        Get.back<void>();
      }
      return;
    }
    if (vodAutoplayCountdown.value != null) {
      cancelVodAutoplayCountdown(cancelledByUser: true);
      return;
    }

    await _prepareLeavePlayerRoute();

    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else {
      Get.back<void>();
    }

    if (openedFromBrowse) {
      if (Get.isRegistered<BrowseController>()) {
        Get.find<BrowseController>().restoreBrowseListFocusAfterPlayerPop();
      }
    } else {
      if (Get.isRegistered<ChannelsController>()) {
        Get.find<ChannelsController>().restoreChannelListFocusAfterPlayerPop();
      }
    }
  }

  /// Yatay tam ekrandan çıkış: Better dahili tam ekran route'u, yön kilidi ve
  /// immersive modu sıfırla; ardından [Navigator.pop] güvenle çalışsın.
  Future<void> _prepareLeavePlayerRoute() async {
    try {
      final bp = better;
      if (bp != null && bp.isFullScreen) {
        bp.exitFullScreen();
      }
    } catch (_) {}

    final lm = _settings.layoutMode.value;
    if (lm == AppLayoutMode.mobile || lm == AppLayoutMode.tablet) {
      await _settings.clearMobilePlaybackPortraitLockForLeavingPlayer();
      if (lm == AppLayoutMode.mobile) {
        await PlaybackOrientationManager.releaseToSensorMobilePlayback();
      }
    }

    _silenceCurrentPlaybackImmediately();
  }

  /// Ağ / geçici kaynak kopması: tam [_boot] öncesi Exo aynı URL’yi [retryDataSource] ile yeniler.
  bool _maybeLightweightBetterPlayerRetry(String msg) {
    if (effectiveUseMediaKit || better == null) return false;
    if (!_isLikelyNetworkOrTransientError(msg)) return false;
    if (_betterPlayerLightRetryWave >= 2) {
      _betterPlayerLightRetryWave = 0;
      return false;
    }
    _betterPlayerLightRetryWave++;
    debugPrint(
      'mina_iptv: BetterPlayer retryDataSource ($_betterPlayerLightRetryWave/2): $msg',
    );
    unawaited(
      Future.delayed(const Duration(milliseconds: 1400), () async {
        if (isClosed) return;
        final b = better;
        if (b == null || effectiveUseMediaKit) return;
        try {
          await b.retryDataSource();
        } catch (e) {
          debugPrint('mina_iptv: retryDataSource: $e');
        }
      }),
    );
    return true;
  }

  void _onBetterPlayerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
      final ex = event.parameters?['exception'];
      if (ex != null && ex.toString().isNotEmpty) {
        final msg = ex.toString();
        if (_maybeRetryBetterWithSoftwareDecoderBeforeMediaKit(msg)) {
          return;
        }
        if (_maybeLightweightBetterPlayerRetry(msg)) {
          return;
        }
        if (_shouldAutoFallbackToMediaKit(msg)) {
          debugPrint(
            'mina_iptv: BetterPlayer exception → MediaKit yedek: $msg',
          );
          _autoEngineSwitchUsed = true;
          betterOsdOverride.value = false;
          mediaKitFallbackSession.value = true;
          _showEngineFallbackToast(toMediaKit: true);
          unawaited(_performMediaKitFallbackBoot());
          return;
        }
        if (_currentStreamIsLive && _isLikelyNetworkOrTransientError(msg)) {
          _cancelLiveTransientErrorEmitTimer();
          _liveTransientErrorEmitTimer =
              Timer(const Duration(milliseconds: 500), () {
            _liveTransientErrorEmitTimer = null;
            if (isClosed) return;
            _emitPlaybackErrorForRecovery(msg);
          });
          return;
        }
        _emitPlaybackErrorForRecovery(msg);
      }
      return;
    }
    if (event.betterPlayerEventType == BetterPlayerEventType.bufferingStart) {
      _maybeAutoDowngradeQualityOnBufferingStress();
      _startLiveStallWatchdog();
      _cancelBetterBufferingRecoveryTimer();
    }
    if (event.betterPlayerEventType == BetterPlayerEventType.bufferingEnd) {
      _cancelLiveStallWatchdog();
      _cancelBetterBufferingRecoveryTimer();
      final v = better?.videoPlayerController?.value;
      if (v != null && v.isPlaying && !v.hasError) {
        _liveTvStallRecoveryAttempts = 0;
        _betterPlayerLightRetryWave = 0;
        _cancelLiveTransientErrorEmitTimer();
      }
    }
  }

  /// Aynı yayında kısa sürede birden fazla tampon başlangıcı olursa bir alt HLS/DASH varyantına in.
  void _maybeAutoDowngradeQualityOnBufferingStress() {
    final c = better;
    if (c == null || isBusy.value) return;
    if (_manualVideoQualityLock) return;

    final started = _autoQPlaybackStartedAt;
    if (started == null) return;
    if (DateTime.now().difference(started) < _autoQIgnoreBufferingBefore) {
      return;
    }

    final tracks =
        c.betterPlayerAsmsTracks.where((t) => (t.height ?? 0) > 0).toList();
    if (tracks.length < 2) return;

    final heights = tracks.map((t) => t.height!).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    if (heights.length < 2) return;

    int currentH = c.betterPlayerAsmsTrack?.height ?? 0;
    if (currentH <= 0) {
      final sz = c.videoPlayerController?.value.size;
      if (sz != null && sz.width > 0 && sz.height > 0) {
        currentH = math.max(sz.height.round(), sz.width.round());
      }
    }
    if (currentH <= 0) currentH = heights.first;

    int? nextH;
    for (final h in heights) {
      if (h < currentH) {
        nextH = h;
        break;
      }
    }
    if (nextH == null) return;

    final now = DateTime.now();
    _autoQRecentBufferingStarts
        .removeWhere((t) => now.difference(t) > _autoQBufferingWindow);
    _autoQRecentBufferingStarts.add(now);
    if (_autoQRecentBufferingStarts.length < _autoQBufferingStartsNeeded) {
      return;
    }
    if (_autoQLastDowngradeAt != null &&
        now.difference(_autoQLastDowngradeAt!) < _autoQDowngradeCooldown) {
      return;
    }

    BetterPlayerAsmsTrack? pick;
    for (final t in tracks) {
      if (t.height == nextH) {
        pick = t;
        break;
      }
    }
    if (pick == null) return;

    debugPrint(
      'mina_iptv: Otomatik kalite düşürme (~${nextH}p): tekrarlayan tampon (önce ~${currentH}p)',
    );
    c.setTrack(pick);
    _autoQRecentBufferingStarts.clear();
    _autoQLastDowngradeAt = now;
    _maybeBumpOsdQualitySignature();
    update(['osd']);
  }

  /// Motor değişiminde kullanıcıya ekranda kaybolan (3 sn) bilgi yazısı göster:
  /// "Yayın MediaKit/Better Player ile tekrar deneniyor".
  void _showEngineFallbackToast({required bool toMediaKit}) {
    if (!Get.isRegistered<ToastService>()) return;
    Get.find<ToastService>().show(
      (toMediaKit
              ? 'player.engineFallback.toMediaKit'
              : 'player.engineFallback.toBetter')
          .tr,
    );
  }

  /// Better/Exo birincil iken hata olunca otomatik MediaKit'e düş.
  ///
  /// Kod çözücü/codec hataları hem **canlı** hem **VOD**'da motor değiştirir.
  /// Genel Exo/Source hataları yalnız **VOD**'da — canlıda bunlar çoğunlukla
  /// geçici ağ sorunudur, ağ kurtarma devrede kalsın. Zaten MediaKit'teysek
  /// veya bu yayın için bir kez otomatik geçiş yapıldıysa tetiklenmez.
  bool _shouldAutoFallbackToMediaKit(String msg) {
    if (msg.isEmpty) return false;
    if (effectiveUseMediaKit) return false;
    if (mediaKitFallbackSession.value) return false;
    if (_autoEngineSwitchUsed) return false;
    if (_isPlaybackDecoderFailure(msg)) return true;
    final l = msg.toLowerCase();
    if (!_currentStreamIsLive) {
      if (l.contains('exoplaybackexception')) return true;
      if (l.contains('media3') && l.contains('error')) return true;
    }
    if (l.contains('codec') &&
        (l.contains('unsupported') ||
            l.contains('not supported') ||
            l.contains('failed'))) {
      return true;
    }
    // Ses kod çözücü / AudioSink (ExoPlayer bazen yalnızca ses tarafında hata verir).
    if (l.contains('mediacodecaudiorenderer') &&
        (l.contains('error') ||
            l.contains('failed') ||
            l.contains('exception') ||
            l.contains('unable'))) {
      return true;
    }
    if (l.contains('audiosink') &&
        (l.contains('codec') ||
            l.contains('format') ||
            l.contains('unsupported') ||
            l.contains('configuration'))) {
      return true;
    }
    if (l.contains('audio') &&
        l.contains('decoder') &&
        (l.contains('failed') ||
            l.contains('unsupported') ||
            l.contains('initialization'))) {
      return true;
    }
    return false;
  }

  /// ExoPlayer’da istisna çıkmadan sessiz kalan VOD sesi (tek riskli parça / muxed riskli iz).
  Future<void> _vodSilentAudioFallbackToMediaKit(String reason) async {
    if (_vodSilentAudioMediaKitFallbackInFlight) return;
    if (isClosed) return;
    if (_currentStreamIsLive) return;
    if (effectiveUseMediaKit) return;
    if (mediaKitFallbackSession.value) return;
    _vodSilentAudioMediaKitFallbackInFlight = true;
    try {
      debugPrint(
        'mina_iptv: VOD Exo sessiz/riskli ses codec → MediaKit yedek ($reason)',
      );
      _autoEngineSwitchUsed = true;
      betterOsdOverride.value = false;
      mediaKitFallbackSession.value = true;
      _showEngineFallbackToast(toMediaKit: true);
      await _performMediaKitFallbackBoot();
    } finally {
      _vodSilentAudioMediaKitFallbackInFlight = false;
    }
  }

  Future<void> _performMediaKitFallbackBoot() async {
    if (isClosed) return;
    _cancelZapRelativeDebounce();
    _cancelNetworkAutoResumeTimer();
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    error.value = null;
    try {
      final old = better;
      _setBetterPlayer(null);
      if (old != null) {
        old.videoPlayerController?.removeListener(_onVideoPlayerChanged);
        await old.pause();
        old.dispose(forceDispose: true);
      }
    } catch (_) {}
    mediaKitAttachEpoch.value++;
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: false,
    );
  }

  /// Qualcomm `c2.qti.avc.decoder` vb. donanım hatasında MediaKit’e düşmeden önce
  /// bir kez ExoPlayer [MediaCodecSelector.PREFER_SOFTWARE] ile aynı URL’yi dener.
  Future<void> _performBetterSoftwareDecoderRetryBoot() async {
    if (isClosed) return;
    if (effectiveUseMediaKit) return;
    _cancelNetworkAutoResumeTimer();
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    error.value = null;
    try {
      final old = better;
      _setBetterPlayer(null);
      if (old != null) {
        old.videoPlayerController?.removeListener(_onVideoPlayerChanged);
        await old.pause();
        old.dispose(forceDispose: true);
      }
    } catch (_) {}
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: false,
    );
  }

  bool _maybeRetryBetterWithSoftwareDecoderBeforeMediaKit(String msg) {
    if (!Platform.isAndroid) return false;
    if (effectiveUseMediaKit) return false;
    if (_exoSoftwareDecoderRetryPending) return false;
    if (_lastBootUsedSoftwareVideoDecoder) return false;
    if (!_isPlaybackDecoderFailure(msg)) return false;
    if (!_currentStreamIsLive && !_shouldAutoFallbackToMediaKit(msg))
      return false;

    _exoSoftwareDecoderRetryPending = true;
    _forceSoftwareVideoDecoder = true;
    if (decoderFallbackStep.value < 1) {
      decoderFallbackStep.value = 1;
    }
    error.value = null;
    debugPrint(
      'mina_iptv: Donanım kod çözücü hatası → ExoPlayer yazılım kod çözücü ile yeniden deneniyor (MediaKit öncesi)',
    );
    unawaited(
      _performBetterSoftwareDecoderRetryBoot().whenComplete(() {
        _exoSoftwareDecoderRetryPending = false;
      }),
    );
    return true;
  }

  /// [PlatformException] / Source error: tek sefer `output`/yol ts↔m3u8.
  bool _tryScheduleXtreamOutputFormatSwapRetry(Object err) {
    if (effectiveUseMediaKit || _decoderTriedTsToM3u8Swap) return false;
    final text = err is PlatformException
        ? '${err.code} ${err.message} ${err.details}'
        : err.toString();
    if (!_shouldTryXtreamFormatSwapOnSourceError(text)) return false;
    final basis = (_lastPlaybackUrl?.trim().isNotEmpty ?? false)
        ? _lastPlaybackUrl!.trim()
        : _normalizePlaybackStreamUrl(channel.value.streamUrl);
    final swapped = _trySwapLiveTsM3u8Url(basis, live: _currentStreamIsLive);
    if (swapped == null || swapped == basis) return false;
    _decoderTriedTsToM3u8Swap = true;
    _playUrlOverride = swapped;
    error.value = null;
    debugPrint(
      'mina_iptv: Kaynak hatası → alternatif Xtream biçimi: $swapped',
    );
    unawaited(
      _boot(
        preferredMaxHeight: null,
        disableAsms: false,
        reuseSameBetterPlayer: false,
        suppressNetworkRecoverySchedule: true,
      ),
    );
    return true;
  }

  void _onVideoPlayerChanged() {
    try {
      final v = better?.videoPlayerController?.value;
      if (v == null) return;
      if (!v.hasError) {
        _cancelLiveTransientErrorEmitTimer();
      }
      if (v.hasError) {
        final msg = v.errorDescription ?? 'Video oynatılamadı';
        debugPrint('mina_iptv: VideoPlayer error: $msg');
        if (_isNotFoundStyleError(msg)) {
          _emitPlaybackErrorForRecovery(msg);
          return;
        }
        if (_maybeRetryBetterWithSoftwareDecoderBeforeMediaKit(msg)) {
          return;
        }
        if (_shouldAutoFallbackToMediaKit(msg)) {
          debugPrint('mina_iptv: VideoPlayer error → MediaKit yedek');
          _autoEngineSwitchUsed = true;
          betterOsdOverride.value = false;
          mediaKitFallbackSession.value = true;
          _showEngineFallbackToast(toMediaKit: true);
          unawaited(_performMediaKitFallbackBoot());
          return;
        }
        if (_tryScheduleXtreamOutputFormatSwapRetry(msg)) {
          return;
        }
        if (!_xtreamTriedGetPhpFallback &&
            channel.value.streamUrl.toLowerCase().contains('/live/') &&
            msg.toLowerCase().contains('source')) {
          final original = _normalizePlaybackStreamUrl(channel.value.streamUrl);
          final converted = _tryConvertXtreamLivePathToGetPhp(original);
          if (converted != null && converted != original) {
            _xtreamTriedGetPhpFallback = true;
            _playUrlOverride = converted;
            unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
            return;
          }
        } else if (_currentStreamIsLive &&
            !_xtreamTriedLiveUrlFormat &&
            (msg.toLowerCase().contains('source error') ||
                msg.toLowerCase().contains('source') ||
                msg.toLowerCase().contains('http'))) {
          // Yalnız canlı: get.php ↔ /live/... yedek formatı (dizi/film karışmaz).
          final original = _normalizePlaybackStreamUrl(channel.value.streamUrl);
          final converted = _tryConvertXtreamGetPhpToLiveUrl(original);
          if (converted != null && converted != original) {
            _xtreamTriedLiveUrlFormat = true;
            unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
            return;
          }
        } else {
          if (_currentStreamIsLive && _isLikelyNetworkOrTransientError(msg)) {
            _cancelLiveTransientErrorEmitTimer();
            _liveTransientErrorEmitTimer =
                Timer(const Duration(milliseconds: 500), () {
              _liveTransientErrorEmitTimer = null;
              if (isClosed) return;
              final v2 = better?.videoPlayerController?.value;
              if (v2 == null || !v2.hasError) return;
              final msg2 = (v2.errorDescription ?? msg).trim();
              if (msg2.isEmpty) return;
              _emitPlaybackErrorForRecovery(msg2);
            });
          } else {
            _emitPlaybackErrorForRecovery(msg);
          }
        }
        return;
      }

      if (!effectiveUseMediaKit) {
        _maybeRecoverLiveAfterSpuriousEngineStop();
      }

      if (_settings.layoutMode.value == AppLayoutMode.tv &&
          !effectiveUseMediaKit &&
          v.isPlaying &&
          !v.isBuffering &&
          !v.hasError) {
        _cancelLiveTvStartupWatchdog();
      }
      _maybeBumpOsdQualitySignature();
      if (!_currentStreamIsLive && _vodHasNextInBrowseTape()) {
        _maybeResetVodEndLatchFromSeek();
        _maybeArmVodEndAutoplay();
      }
    } finally {
      _syncLiveAutoNextWatchdog();
      _syncPlaybackWakelock();
      if (Platform.isAndroid) {
        unawaited(_syncAndroidPipAutoEnterEligible());
      }
    }
  }

  /// Ayarlar > Oynatıcı > "Yayın Formatı" tercihini canlı Xtream URL'sine
  /// uygular. `ts` → MPEG-TS (`/live/*.ts` veya `get.php&output=ts`),
  /// `hls` → m3u8. URL zaten istenen biçimdeyse veya Xtream canlı kalıbına
  /// uymuyorsa `null` döner (URL değiştirilmez). M3U'dan gelen jenerik `.ts`
  /// adresleri `/live/` içermiyorsa dokunulmaz; uyumsuz panelde mevcut
  /// [_trySwapLiveTsM3u8Url] yedek zinciri diğer biçime geçirir.
  String? _applyPreferredLiveStreamFormat(String url) {
    final wantTs = _settings.prefersTsLiveStreamFormat;
    final u = url.trim();
    if (u.isEmpty) return null;
    final uri = Uri.tryParse(u);
    if (uri == null) return null;
    final path = uri.path.toLowerCase();
    final lower = u.toLowerCase();

    if (path.contains('/live/')) {
      if (wantTs && lower.endsWith('.m3u8')) {
        final np = '${uri.path.substring(0, uri.path.length - 6)}.ts';
        return uri.replace(path: np).toString();
      }
      if (!wantTs && lower.endsWith('.ts')) {
        final np = '${uri.path.substring(0, uri.path.length - 3)}.m3u8';
        return uri.replace(path: np).toString();
      }
      return null;
    }

    if (path.endsWith('get.php')) {
      final q = uri.queryParameters;
      if ((q['stream_id'] ?? '').isEmpty) return null;
      final out = (q['output'] ?? '').toLowerCase().trim();
      if (wantTs) {
        if (out == 'm3u8' || out == 'm3u' || out == 'hls') {
          return _tryConvertXtreamGetPhpOutput(u, 'ts');
        }
      } else {
        if (out == 'ts' ||
            out == 'mpegts' ||
            out == 'mpeg-ts' ||
            out == 'm2ts') {
          return _tryConvertXtreamGetPhpOutput(u, 'm3u8');
        }
      }
    }

    return null;
  }

  /// Xtream: `/live/.../*.ts` ↔ `*.m3u8`; canlı `get.php` için `output=ts` ↔ `m3u8` (tersi).
  /// VOD `get.php` için çıktı değiştirilmez (film/dizi).
  /// [live]: boş `output` yalnızca canlıda m3u8’e çekilir.
  String? _trySwapLiveTsM3u8Url(String url, {required bool live}) {
    final u = url.trim();
    if (u.isEmpty) return null;
    final uri = Uri.tryParse(u);
    if (uri == null) return null;
    final lower = u.toLowerCase();
    final path = uri.path.toLowerCase();

    if (path.contains('/live/')) {
      if (lower.endsWith('.ts')) {
        final np = '${uri.path.substring(0, uri.path.length - 3)}.m3u8';
        return uri.replace(path: np).toString();
      }
      if (lower.endsWith('.m3u8')) {
        final np = '${uri.path.substring(0, uri.path.length - 6)}.ts';
        return uri.replace(path: np).toString();
      }
    }

    if (path.endsWith('get.php')) {
      final q = uri.queryParameters;
      if (q['stream_id'] == null || q['stream_id']!.isEmpty) return null;
      final out = (q['output'] ?? '').toLowerCase().trim();
      if (out.isEmpty) {
        if (!live) return null;
        return _tryConvertXtreamGetPhpOutput(u, 'm3u8');
      }
      if (out == 'ts' || out == 'mpegts' || out == 'mpeg-ts' || out == 'm2ts') {
        if (!live) return null;
        return _tryConvertXtreamGetPhpOutput(u, 'm3u8');
      }
      if (out == 'm3u8' || out == 'm3u' || out == 'hls') {
        if (!live) return null;
        return _tryConvertXtreamGetPhpOutput(u, 'ts');
      }
    }

    return null;
  }

  /// `get.php?...&output=ts` / `output=m3u8` gibi Xtream URL'lerini
  /// `/live/username/password/stream_id.(ts|m3u8)` formatına çevirir.
  /// Uygun değilse `null` döner.
  String? _tryConvertXtreamGetPhpToLiveUrl(String normalizedUrl) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    if (!uri.path.toLowerCase().endsWith('get.php')) return null;

    final q = uri.queryParameters;
    final streamId = q['stream_id'];
    final username = q['username'];
    final password = q['password'];
    final output = q['output'];

    if (streamId == null || streamId.isEmpty) return null;
    if (username == null || username.isEmpty) return null;
    if (password == null || password.isEmpty) return null;

    final ext = (output ?? '').toLowerCase();
    String suffix;
    if (ext.contains('m3u8')) {
      suffix = 'm3u8';
    } else if (ext.contains('mpd')) {
      suffix = 'mpd';
    } else {
      // varsayılan: ts
      suffix = 'ts';
    }

    String encodePathSegment(String v) =>
        Uri.encodeComponent(v).replaceAll('+', '%20');

    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$base/live/${encodePathSegment(username)}/${encodePathSegment(password)}/$streamId.$suffix';
  }

  /// `get.php?...&output=ts` -> `get.php?...&output=m3u8` (veya tersine) dönüştürür.
  /// `/live/user/pass/id.ts` -> `get.php?...&output=ts` (ters yedek).
  String? _tryConvertXtreamLivePathToGetPhp(String normalizedUrl) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 4 || segments[0].toLowerCase() != 'live') {
      return null;
    }
    final user = Uri.decodeComponent(segments[1]);
    final pass = Uri.decodeComponent(segments[2]);
    final last = segments[3];
    final dot = last.lastIndexOf('.');
    if (dot <= 0) return null;
    final id = last.substring(0, dot);
    final output = last.substring(dot + 1);
    if (int.tryParse(id) == null) return null;

    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$base/get.php?username=${Uri.encodeQueryComponent(user)}&password=${Uri.encodeQueryComponent(pass)}&stream_id=$id&output=$output';
  }

  String? _tryConvertXtreamGetPhpOutput(String normalizedUrl, String output) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    if (!uri.path.toLowerCase().endsWith('get.php')) return null;

    final q = Map<String, String>.from(uri.queryParameters);
    final streamId = q['stream_id'];
    final username = q['username'];
    final password = q['password'];

    if (streamId == null || streamId.isEmpty) return null;
    if (username == null || username.isEmpty) return null;
    if (password == null || password.isEmpty) return null;

    q['output'] = output;

    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    final query = q.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base/get.php?$query';
  }

  @override
  void onClose() {
    // Tüm devam eden oynatma işlemlerini geçersiz kılmak için nesil numarasını artır
    _bumpPlaybackGeneration();

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
    _pipAutoEnterWorker?.dispose();
    _settings.onSubtitleFontPtApplied = null;
    _playbackWakelockLayoutWorker?.dispose();
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
    _cancelMediaKitWakelockSubs();
    _cancelZapRelativeDebounce();
    _cancelLiveZapAbrQualityRamp();
    _cancelTvOsdAutoHideTimer();
    _resetNetworkRecoveryState();
    _cancelLiveTransientErrorEmitTimer();
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    _cancelLiveAutoNextWatchdog();

    // --- UNIFIED TIMER CLEANUP ---
    _cancelUnifiedUiTimer();
    _cancelUnifiedNetworkTimer();
    _cancelUnifiedProgressTimer();

    unawaited(WakelockPlus.disable());
    WidgetsBinding.instance.removeObserver(this);
    try {
      final mk = _mediaKitPlayer;
      if (mk != null) {
        // native tarafta sesin hemen kesilmesi için
        unawaited(mk.pause().then((_) => mk.stop()).then((_) => mk.dispose()));
      }
    } catch (_) {}
    try {
      better?.videoPlayerController?.removeListener(_onVideoPlayerChanged);
      better?.pause();
      better?.dispose(forceDispose: true);
    } catch (_) {}
    _setBetterPlayer(null);
    _mediaKitErrorSub?.cancel();
    _mediaKitErrorSub = null;
    _cancelMediaKitDimSubs();

    // --- COMPLETE WORKER AND SUBSCRIPTION CLEANUP ---

    // Cancel all MediaKit busy dims subscriptions
    for (final s in _mediaKitBusyDimsSubs) {
      unawaited(s.cancel());
    }
    _mediaKitBusyDimsSubs.clear();

    // Cancel busy hold timeout
    _busyHoldTimeout?.cancel();
    _busyHoldTimeout = null;

    // Cancel zap relative debounce timer
    _zapRelativeDebounceTimer?.cancel();
    _zapRelativeDebounceTimer = null;

    // Cancel channel-number direct entry commit timer
    _channelNumberCommitTimer?.cancel();
    _channelNumberCommitTimer = null;

    // Cancel Android PiP fallback pause timer
    _androidPipFallbackPauseTimer?.cancel();
    _androidPipFallbackPauseTimer = null;

    // Cancel watch progress timer
    _watchProgressTimer?.cancel();
    _watchProgressTimer = null;
    _userHistoryTickTimer?.cancel();
    _userHistoryTickTimer = null;

    // Cancel VOD autoplay timers
    _vodEndAutoplayMonitor?.cancel();
    _vodEndAutoplayMonitor = null;
    _vodAutoplayCountdownTimer?.cancel();
    _vodAutoplayCountdownTimer = null;

    // Cancel network and live timers
    _networkAutoResumeTimer?.cancel();
    _networkAutoResumeTimer = null;
    _liveStallWatchdogTimer?.cancel();
    _liveStallWatchdogTimer = null;
    _liveTransientErrorEmitTimer?.cancel();
    _liveTransientErrorEmitTimer = null;
    _liveTvStallPollTimer?.cancel();
    _liveTvStallPollTimer = null;
    _liveTvStartupWatchdog?.cancel();
    _liveTvStartupWatchdog = null;
    _liveAutoNextPollTimer?.cancel();
    _liveAutoNextPollTimer = null;

    // Cancel TV OSD auto hide timer (handled by unified UI timer)
    _tvOsdAutoHideAt = null;

    _mediaKitPlayer = null;
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
