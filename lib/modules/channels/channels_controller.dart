import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/player/playback_engine_kind.dart';
import '../../core/home/tv_home_layout_mode.dart';
import '../../core/player/media_kit_lock.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/active_playlist_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_deferred_load_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/epg/catch_up_url_template.dart';
import '../../data/remote/xtream_api.dart';
import '../../domain/entities/epg_entities.dart';
import '../../domain/entities/playlist_source.dart';
import '../../data/remote/m3u_xtream_sniffer.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/iptv_precache_service.dart';
import '../../core/services/live_hls_stream_profile_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/playlist_category_hide.dart';
import '../../core/services/playlist_data_source.dart';
import '../../data/local/playlist_sqlite_store.dart';
import '../../core/services/search_history_service.dart';
import '../../core/theme/app_performance.dart';
import '../../core/tv/tv_shell_list_window.dart';
import '../../core/perf/browse_catalog_index.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/player/better_player_iptv_config.dart'
    show
        IptvBetterPlayerConfig,
        iptvApplyBetterPlayerLowRam720CapIfNeeded,
        iptvBetterPlayerDataSource;
import '../../core/player/iptv_playback_defaults.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../player/player_controller.dart';
import '../../services/user_history_service.dart';
import '../../ui/glass_tv_shell.dart';


part 'parts/channels_loading.dart';
part 'parts/channels_navigation.dart';

/// Sanal "Favoriler" kategorisi için sentinel kimliği. Gerçek M3U/Xtream
/// kategorileri her zaman > 0 olduğundan negatif sabit çatışma yaratmaz.
/// Aynı sabit `_PortraitLiveTvPanel`'da da kullanılır.
const int kFavoritesVirtualCategoryId = -1;

/// Sanal "Son İzlenenler" kategorisi — kullanıcının son 20 farklı canlı
/// kanalını listeler. Yalnızca [UserHistoryService] içinde `kind == live`
/// kayıt varsa görünür; aksi halde kategori UI'da gizlenir.
const int kRecentlyWatchedVirtualCategoryId = -2;

/// TV kabuğu açılışında kanal geri yüklemesi [bootTvShellLivePreview] ile yapılır.
bool channelsTvShellBootPending = false;

/// "Son İzlenenler" sanal kategorisinde gösterilecek azami canlı kanal
/// sayısı (en yeni → en eski).
const int kRecentlyWatchedLiveLimit = 20;

/// RAM'de tam kanal listesi senkron taraması yapılmadan önceki üst sınır.
const int kRamFullScanChannelCap = 1500;

class ChannelsController extends GetxController {
  /// DB'den tek seferde çekilecek kanal sayfası boyutu.
  static const int _kDbChannelPageSize = 2000;

static const int _kVisibleChannelWindowSize = 250;

static const int _kVisibleChannelWindowSizeLowEnd = 100;

static const int kChannelListFastBatch = 50;

static const int _kChannelListFastBatch = kChannelListFastBatch;

static const int _kVisibleChannelExpandLead = 20;

static const int _kVisibleChannelSearchCap = 500;

static const _previewFocusHoldDelay = Duration(seconds: 2);

/// TV / kumanda: D-pad ile listede hızlı gezerken her satırda ağır
  /// ExoPlayer kurup yıkmak (ve ağ ısıtması) zayıf TV box'ı çok yorar. Bu yüzden
  /// önizleme yalnızca kullanıcı bir kanalda gerçekten "durunca" başlar — bekleme
  /// dokunmatik moda göre belirgin biçimde uzun tutulur.
  static const _previewFocusHoldDelayTv = Duration(milliseconds: 3500);

/// Ön bağlantı (DNS/soket/HEAD) ısıtması beklemesi — TV'de hızlı gezinmede
  /// ağ yığınını boğmamak için durulma süresi uzun, dokunmatikte kısa.
  static const _precacheDelay = Duration(milliseconds: 400);

static const _precacheDelayTv = Duration(milliseconds: 1500);

final _cache = Get.find<PlaylistCacheService>();

final _ds = Get.find<PlaylistDataSource>();

final _fav = Get.find<FavoritesService>();

final _app = Get.find<AppSettingsService>();

final selectedCategoryId = Rxn<int>();

final selectedChannel = Rxn<Channel>();

final searchQuery = ''.obs;

final effectiveSearchQuery = ''.obs;

final now = DateTime.now().obs;

final archiveDayOffset = 0.obs;

void setArchiveDay(int offset) {
  archiveDayOffset.value = offset;
}

Future<void> playCatchUp(Channel ch, EpgProgramme p) async {
  final activePl = Get.find<ActivePlaylistService>();
  final source = activePl.activeInfo?.source;
  XtreamSource? xtream;
  
  if (source is XtreamSource) {
    xtream = source;
  } else if (source is M3uSource) {
    // If it's M3U but has Xtream credentials in the URL
    xtream = M3uXtreamSniffer.toXtreamSource(source.url);
  }
  
  if (xtream == null) return;
  final configured = _app.catchUpTemplateEffective;
  final template = configured.isNotEmpty
      ? configured
      : CatchUpUrlDefaults.xtreamTimeshiftPath;
  final epgService = Get.find<EpgService>();
  final api = XtreamApi(
    baseUrl: xtream.baseUrl,
    username: xtream.username,
    password: xtream.password,
  );
  final url = epgService.buildCatchUpPlaybackUrl(
    api: api,
    channel: ch,
    programme: p,
    template: template,
  );
  if (url == null || url.isEmpty) return;
  
  final virtual = Channel(
    id: ch.id,
    name: '${ch.name} — ${p.title}',
    streamUrl: url,
    categoryId: ch.categoryId,
    logoUrl: ch.logoUrl,
    epgChannelId: ch.epgChannelId,
    sortOrder: ch.sortOrder,
  );
  Get.toNamed(
    AppRoutes.player,
    arguments: virtual,
  );
}

/// "Listeler" barından farklı bir listeye geçildiğinde artar — kategori
  /// paneli ve kanal listesi `Obx`'lerini yeniden çizmek için.
  final playlistRevision = 0.obs;

/// TV kabuğu canlı panelinde sesli önizleme.
  final tvShellLiveActive = false.obs;

/// Kategori paneli açıkken sağdaki dar canlı TV önizlemesi.
  final tvShellLiveBrowseActive = false.obs;

Timer? _clock;

Timer? _precacheDebounce;

Timer? _previewDebounce;

Timer? _previewAutoDisposeTimer;

Timer? _tvCategoryChannelsApplyDebounce;

int _tvCategoryChannelsApplyGen = 0;

Worker? _searchDebounceWorker;

Worker? _cacheWorker;

Worker? _hideAdultWorker;

Worker? _playerActiveWorker;

int? _visibleChannelsCacheKey;

List<Channel>? _visibleChannelsCache;

int? _filteredChannelsCacheKey;

List<Channel>? _filteredChannelsCache;

int _dbVisibleLoadGen = 0;

bool _visibleChannelsDbHasMore = false;

int _visibleChannelsDbNextOffset = 0;

int? _visibleChannelsWindowCategoryId;

String _visibleChannelsWindowSearch = '';

int _visibleChannelsWindowTargetCap = _kVisibleChannelWindowSize;

/// Bellek modunda kategori kanal kimlikleri (hafif) + görünür pencere.
  List<int>? _memChannelIdPool;

int? _memChannelIdPoolKey;

int _memChannelWindowEnd = 0;

int _dbCategoryCountLoadGen = 0;

int _moveFocusToChannelsGen = 0;

int _previewLoadGeneration = 0;

int? _lastPreviewedChannelId;

final searchController = TextEditingController();

BetterPlayerController? previewController;

Player? previewPlayerMediaKit;

VideoController? previewVideoMediaKit;

Channel? previewedChannel;

final isPreviewLoading = false.obs;

/// TV / yatay: ilk kategori satırı (ekrana girişte kumanda odağı).
  final categoryFocusNode = FocusNode(debugLabel: 'liveCategoriesFirst');

/// TV / yatay: "Listeler" barı odak düğümü (kategorilerin üstünde).
  final listsBarFocusNode = FocusNode(debugLabel: 'liveListsBar');

/// TV: kategori seçilince odak buraya taşınır (browse ile aynı desen).
  final channelsListFocusNode = FocusNode(debugLabel: 'liveChannelsList');

/// TV üst çubuk: arama / ayarlar (browse ile aynı desen).
  final channelsBarSearchFocusNode = FocusNode(debugLabel: 'channelsBarSearch');

final channelsBarSettingsFocusNode =
      FocusNode(debugLabel: 'channelsBarSettings');

final channelsBarEpgTimelineFocusNode =
      FocusNode(debugLabel: 'channelsBarEpgTimeline');

/// TV yatay: kategori seçildikten sonra oklarla sol sütuna dönmesin; Geri ile kalkar.
  final tvTrapFocusInChannelList = false.obs;

/// TV: sağ ok ile açılmadan üçüncü (detay) sütun odak almasın.
  final tvDetailColumnUnlocked = false.obs;

/// TV: detay sütunu — [unlockTvDetailColumn] sonrası ilk odak.
  final detailPanelFocusNode = FocusNode(debugLabel: 'liveDetailPanel');

/// TV: detay sütununda "Tam ekran" düğümü — görünür odak çerçevesi.
  final detailFullscreenFocusNode =
      FocusNode(debugLabel: 'liveDetailFullscreen');

/// TV: detay önizleme alanı — yukarı: arama; aşağı: tam ekran düğmesi.
  final detailPreviewFocusNode = FocusNode(debugLabel: 'liveDetailPreview');

/// TV kanal listesi [ListView] kaydırması — satır hizalı `jumpTo` için.
  ScrollController? _tvChannelListScroll;

void Function(int rowIndex)? _tvShellChannelRowFocusHandler;

void Function()? _tvShellChannelRowClearFocusHandler;

int? _pendingTvShellChannelFocusIndex;

/// TV kabuğu canlı kanal listesinde bir satır odakta mı?
  final tvShellChannelRowHasFocus = false.obs;

/// Browse modunda kategori → kanal listesi: odak kanallardayken kategori
  /// paneli odak çalmamalı (satırlar arası geçişte anlık odak kaybı).
  final tvShellLiveBrowsingChannels = false.obs;

/// Mobil portre kategori listesi kaydırması — seçili satırı görünür tutmak için.
  ScrollController? _categoryListScroll;

/// Mobil portre [TabController] — oynatıcıdan dönüşte sekme sıfırlanmasın diye
  /// StatefulWidget içinde tutulur; geri adımı buradan okunur.
  TabController? _portraitTabController;

/// Çift KeyDown / hızlı tekrarın aynı karede iki satır atlamasını önler.
  int? _lastTvChannelNudgeMs;

M3uResult? _data;

/// Son senkronize edilen aktif playlist kapsamı ([PlaylistCacheService.dbSourceKey]
/// veya bellek kimliği). Slim meta aynı referans kalsa bile slot değişimini
/// yakalamak için [_onActivePlaylistChanged] bu anahtarı da izler.
String? _syncedPlaylistScopeKey;

/// TV Listeler panelinden geçişte [_scheduleTvLiveBoot] otomatik önizleme
/// başlatmasın — [reloadForActivePlaylistSwitch] tamamlanana kadar.
bool suppressTvShellPlaylistBoot = false;

/// [Get.arguments] ile `{'openSearch': true}` gelince ilk karede arama popup’ı.
  bool _pendingOpenSearch = false;

/// Ana ekrandan canlı TV: ilk kategori satırı + ilk kanal seçimi ve kategori odağı.
  bool _resetLiveSelectionFromHome = false;

/// Ana ekran (Vitrin) «Favori Kanallar → Tümünü gör»: girişte sanal
  /// «Favoriler» kategorisini seç.
  bool _selectFavoritesFromHome = false;

/// Ana ekran birleşik arama: doğrudan kanal seçimi.
  int? _routePickChannelId;

String? _routeInitialSearch;

/// Ana ekran birleşik arama: filtre + isteğe bağlı kategori; son kayıt geri yüklemesini atla.
  bool _routeHomeUnifiedSearch = false;

int? _routeHomeUnifiedChannelCategoryId;

@override
  void onInit() {
    super.onInit();
    final value = _cache.result.value;
    if (value == null) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.playlist));
      return;
    }
    _data = value;
    _syncedPlaylistScopeKey = _playlistScopeKey(_cache);
    if (_app.layoutMode.value == AppLayoutMode.tv &&
        Get.isRegistered<EpgDeferredLoadService>()) {
      unawaited(Get.find<EpgDeferredLoadService>().ensureTvLazyLoad());
    }
    _invalidateChannelListCaches();
    // "Listeler" barından liste değişince önbellek güncellenir; _data'yı
    // tazele + paneli yeniden çiz.
    _cacheWorker = ever<M3uResult?>(_cache.result, _onActivePlaylistChanged);
    _hideAdultWorker = ever<int>(_app.xtreamHideRevision, (_) {
      _invalidateChannelListCaches();
      playlistRevision.value++;
    });
    ever<int>(_cache.layoutRevision, (_) {
      _invalidateChannelListCaches();
      playlistRevision.value++;
    });
    effectiveSearchQuery.value = searchQuery.value;
    _searchDebounceWorker = debounce<String>(
      searchQuery,
      (value) {
        final normalized = value.trim().toLowerCase();
        if (effectiveSearchQuery.value == normalized) return;
        effectiveSearchQuery.value = normalized;
        _invalidateChannelListCaches();
        _ensureSelectionInList();
      },
      time: const Duration(milliseconds: 180),
    );
    final a = Get.arguments;
    _pendingOpenSearch = a == true ||
        (a is Map && (a['openSearch'] == true || a['openSearch'] == 'true'));
    _resetLiveSelectionFromHome = a is Map &&
        (a['resetLiveSelection'] == true || a['resetLiveSelection'] == 'true');
    _selectFavoritesFromHome = a is Map &&
        (a['selectFavorites'] == true || a['selectFavorites'] == 'true');
    if (a is Map) {
      final id = a['pickChannelId'];
      if (id != null) {
        _routePickChannelId = int.tryParse(id.toString());
        if (_routePickChannelId != null && _routePickChannelId! <= 0) {
          _routePickChannelId = null;
        }
      }
      final ins = a['initialSearch'];
      if (ins is String) _routeInitialSearch = ins;
      _routeHomeUnifiedSearch = a['fromHomeUnifiedSearch'] == true ||
          a['fromHomeUnifiedSearch'] == 'true';
      final ilc = a['initialLiveCategoryId'];
      if (ilc != null) {
        final parsed = int.tryParse(ilc.toString());
        if (parsed != null && parsed > 0) {
          _routeHomeUnifiedChannelCategoryId = parsed;
        }
      }
    }
    channelsListFocusNode.addListener(_onChannelsListFocusChanged);
    _startScreenClock();
    _playerActiveWorker = ever<bool>(
      Get.find<AppSettingsService>().playerScreenActive,
      _onPlayerScreenActiveChanged,
    );
    if (_dbBacked) {
      unawaited(_reloadDbCategoryCountsNow());
    }
    Future.microtask(_restoreLastSelection);

    // Uygulama arka plana alındığında önizleme player'ını durdur
    _appLifecycleListener = AppLifecycleListener(
      onStateChange: _handleAppLifecycleStateChanged,
    );
  }

AppLifecycleListener? _appLifecycleListener;

void _handleAppLifecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Uygulama arka plana alındı, önizleme player'ını durdur
      clearStreamPreview();
    }
  }

@override
  void onReady() {
    super.onReady();
    now.value = DateTime.now();
    if (_pendingOpenSearch) {
      _pendingOpenSearch = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isClosed) return;
        openChannelSearchPopup();
      });
    }
  }

@override
  void onClose() {
    stopTvChannelListVerticalHold();
    _invalidateChannelListCaches();
    _clock?.cancel();
    _playerActiveWorker?.dispose();
    _precacheDebounce?.cancel();
    _previewDebounce?.cancel();
    _previewAutoDisposeTimer?.cancel();
    _tvCategoryChannelsApplyDebounce?.cancel();
    _searchDebounceWorker?.dispose();
    _cacheWorker?.dispose();
    _hideAdultWorker?.dispose();
    _appLifecycleListener?.dispose();
    clearStreamPreview();
    searchController.dispose();
    channelsListFocusNode.removeListener(_onChannelsListFocusChanged);
    categoryFocusNode.dispose();
    listsBarFocusNode.dispose();
    channelsListFocusNode.dispose();
    channelsBarSearchFocusNode.dispose();
    channelsBarSettingsFocusNode.dispose();
    channelsBarEpgTimelineFocusNode.dispose();
    detailPanelFocusNode.dispose();
    detailFullscreenFocusNode.dispose();
    detailPreviewFocusNode.dispose();
    super.onClose();
  }

/// Aynı oturumda hesaplanmış kategori sayıları (GROUP BY) — kaynak/gizleme/
  /// düzen anahtarına göre. Canlı TV'ye yeniden girişte rozetler "0" yerine
  /// anında doğru değerle gelir; arka planda yine tazelenir.
  static final Map<String,
          ({int allVisibleCount, Map<int, int> categoryCounts})>
      _fastCountsMemo = {}

;

/// Yüklenmekte olan sayım anahtarı — iki aşamalı yayın sırasında yeniden
  /// tetiklemeyi (sonsuz döngü) engeller.
  String? _categoryCountLoadingKey;

int _ramCategoryCountBuildGen = 0;

bool _ramCategoryCountBuildRunning = false;

int _memChannelIdPoolBuildGen = 0;

String? _categoryCountCacheKey;

({
    int allVisibleCount,
    int favoritesVisibleCount,
    int recentlyWatchedVisibleCount,
    Map<int, int> categoryCounts,
  })? _categoryCountCache;

Timer? _tvListVerticalHoldInitial;

Timer? _tvListVerticalHoldPeriodic;

// channelsInSameCategory() önbelleği: detay paneli her build'de aynı
  // kategoriyi sorar. (data kimliği + kategori + gizleme revizyonu) değişmedikçe
  // tam tarama tekrarlanmaz.
  List<Channel>? _sameCatCache;

Object? _sameCatData;

int _sameCatCategoryId = -1 << 30;

int _sameCatHideRev = -1;

bool _sameCatReviewMode = false;

int _dbSameCatLoadGen = 0;
}

