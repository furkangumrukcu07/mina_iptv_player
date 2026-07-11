import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/home/film_dizi_catalog.dart';
import '../../core/perf/browse_catalog_index.dart';
import '../../core/home/film_dizi_detail_args.dart';
import '../../core/home/film_dizi_vod_meta.dart';
import '../../core/home/recommended_films_catalog.dart';
import '../../core/home/series_episode_loader.dart';
import '../../core/home/series_name_grouping.dart';
import '../../core/home/tv_home_layout_mode.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/download_service.dart';
import '../../core/services/external_player_service.dart';
import '../../core/services/movie_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/playlist_category_hide.dart';
import '../../core/services/playlist_data_source.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_performance.dart';
import '../../core/tv/tv_shell_list_window.dart';
import '../../core/tv/tv_shell_section.dart';
import '../../core/tv/tv_shell_vod_sort.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/movie_model.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../domain/entities/vod.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../../ui/tv_dpad_focus.dart' show scheduleTvFocusRestore;
import '../../ui/exit_confirm_dialog.dart';
import '../player/player_navigation.dart';
import '../player/player_route_args.dart';
import '../channels/channels_controller.dart';
import '../home/home_controller.dart';
import '../home/home_card_counts.dart';
import '../../core/services/active_playlist_service.dart';
import '../settings/settings_controller.dart';
import 'widgets/tv_shell_rail.dart' show kTvShellRailCollapsedWidth;

/// TV ana kabuğu: sol menü + dinamik sağ panel.
class TvShellController extends GetxController {
  /// Daraltılmış sol menü — yalnızca ikonlar ([TvShellRail] ile uyumlu).
  static const double railCollapsedWidth = kTvShellRailCollapsedWidth;

  final selectedSection = TvShellSection.live.obs;
  final railExpanded = false.obs;
  final phase = TvShellPhase.liveContent.obs;

  final _cache = Get.find<PlaylistCacheService>();
  final _app = Get.find<AppSettingsService>();

  Worker? _playlistBootWorker;
  Worker? _playlistWorker;
  Worker? _tvHomeLayoutWorker;
  bool _liveBootScheduled = false;

  late final Map<TvShellSection, FocusNode> railFocusNodes = {
    for (final s in TvShellSection.values)
      s: FocusNode(debugLabel: 'tvShellRail_$s'),
  };

  final categoryPanelFocusNode = FocusNode(debugLabel: 'tvShellCategories');
  void Function(int? categoryId)? _categoryRowFocusHandler;
  void Function()? _categoryRowClearFocusHandler;
  int _categoryFocusSeq = 0;
  final liveChannelsFocusNode = FocusNode(debugLabel: 'tvShellLiveChannels');
  final vodBrowseFocusNode = FocusNode(debugLabel: 'tvShellVodBrowse');
  final vodContentFocusNode = FocusNode(debugLabel: 'tvShellVodContent');
  final vodSortToolbarFocusNode = FocusNode(debugLabel: 'tvShellVodSort');
  final vodSearchToolbarFocusNode = FocusNode(debugLabel: 'tvShellVodSearch');
  final playlistsPanelFocusNode = FocusNode(debugLabel: 'tvShellPlaylists');
  final continueWatchingPanelFocusNode = FocusNode(debugLabel: 'tvShellContinueWatching');

  int _liveCategoriesMemoRev = -1;
  List<({int? id, String name, int count, IconData? icon})>? _liveCategoriesMemo;
  void Function()? _playlistsRowFocusHandler;
  void Function()? _continueWatchingFocusHandler;
  void Function()? _settingsFirstTileFocusHandler;
  void Function()? _settingsLeaveHandler;
  void Function(int index)? _settingsReturnFocusHandler;
  int? _settingsPendingReturnFocusIndex;
  void Function()? _vodDetailPlayFocusHandler;
  void Function()? _vodPosterStripFocusHandler;
  void Function(int index)? _vodBrowsePosterFocusHandler;
  void Function()? _vodBrowsePosterClearFocusHandler;
  TvShellSection? _vodBrowsePosterFocusOwner;
  TvShellSection? _vodBrowsePosterClearFocusOwner;
  int? _pendingVodBrowsePosterFocusIndex;

  /// Film/dizi önizleme poster şeridinde bir kart odakta mı?
  final vodBrowsePosterHasFocus = false.obs;

  /// Filmler önizleme / içerik listesi yenilendiğinde artar.
  final vodItemsRevision = 0.obs;

  /// Film/dizi kategori rozet sayıları yenilendiğinde artar (DB destekli listeler).
  final categoryCountsRevision = 0.obs;
  int? _categoryCountsScopeKey;
  Map<int, int> _vodCountsByCategory = const {};
  Map<int, int> _seriesCountsByCategory = const {};
  int _categoryCountsLoadGen = 0;
  final vodPreviewCategoryId = Rxn<int>();
  final vodContentCategoryId = Rxn<int>();
  final vodFocusedIndex = 0.obs;
  final vodOmdbDetail = Rxn<MovieModel>();
  final vodXtreamFields = Rxn<Map<String, String>>();
  final vodOmdbLoading = false.obs;
  /// [vodOmdbDetail]'in ait olduğu VOD/dizi kimliği (0 = bağlı değil).
  final vodOmdbItemId = 0.obs;
  final vodContentPinned = false.obs;
  final vodFocusedTrailers = <FilmDiziTrailer>[].obs;
  final vodTrailersLoading = false.obs;

  List<VodItem> _vodPreviewItems = const [];
  List<VodItem> _vodContentItems = const [];
  List<VodItem> _vodContentSource = const [];
  List<SeriesItem> _seriesPreviewItems = const [];
  List<SeriesItem> _seriesContentItems = const [];
  List<SeriesItem> _seriesContentSource = const [];
  final vodSortMode = TvShellVodSortMode.alphabetical.obs;
  final seriesSortMode = TvShellVodSortMode.alphabetical.obs;
  final vodSortMenuOpen = false.obs;
  int _vodSortRandomSeed = 0;
  int _seriesSortRandomSeed = 0;
  final seriesEpisodes = <SeriesEpisodeOption>[].obs;
  final seriesEpisodesLoading = false.obs;
  final seriesSelectedSeason = Rxn<int>();
  final seriesFocusedEpisodeIndex = 0.obs;
  final seriesXtreamMeta = Rxn<XtreamSeriesBrowseDetail>();
  Timer? _vodOmdbDebounce;
  int _vodLoadGen = 0;
  int _lastBackCoalesceMs = 0;
  int _lastBackHandledMs = 0;
  int _liveBrowseChannelFocusSeq = 0;

  /// Kullanıcı kanal listesinde gezinince otomatik odak yeniden denemesini iptal et.
  void cancelLiveBrowseAutoFocusRetry() {
    _liveBrowseChannelFocusSeq++;
  }
  /// Detaydan (pinned) listeye dönüşten hemen sonra ikinci Geri/PopScope
  /// kategorilere atlama.
  int _vodDetailUnpinBackGuardMs = 0;
  /// Oynatıcıdan dönüşten hemen sonra sızan Geri tuşu kategorilere atlama.
  int _vodPlayerReturnGuardMs = 0;
  /// Oynatıcıdan dönüşte yalnızca bir Geri basışını yut (çift tetikleme).
  bool _absorbNextBackAfterPlayerReturn = false;
  int _vodTrailersLoadGen = 0;
  int? _vodTrailersVodId;
  int _seriesEpisodesLoadGen = 0;
  int? _seriesEpisodesSeriesId;

  int? _vodPreviewCategoryKey;
  int _vodPreviewNextOffset = 0;
  bool _vodPreviewHasMore = false;
  bool _vodPreviewLoadingMore = false;

  int? _vodContentListCategoryKey;
  int _vodContentNextOffset = 0;
  bool _vodContentHasMore = false;
  bool _vodContentLoadingMore = false;
  List<VodItem>? _vodMemPool;
  int? _vodMemPoolCategoryKey;

  int? _seriesPreviewCategoryKey;
  int _seriesPreviewNextOffset = 0;
  bool _seriesPreviewHasMore = false;
  bool _seriesPreviewLoadingMore = false;

  int? _seriesContentListCategoryKey;
  int _seriesContentNextOffset = 0;
  bool _seriesContentHasMore = false;
  bool _seriesContentLoadingMore = false;
  List<SeriesItem>? _seriesMemGroupedPool;
  int? _seriesMemPoolCategoryKey;

  ChannelsController? _channels;
  ChannelsController get channels {
    _channels ??= Get.find<ChannelsController>();
    return _channels!;
  }

  @override
  void onInit() {
    super.onInit();
    _ensureChildControllers();
    _tvHomeLayoutWorker = ever(_app.tvHomeLayoutMode, _onTvHomeLayoutModeChanged);
    _playlistWorker = ever(_cache.result, (_) {
      if (selectedSection.value == TvShellSection.movies ||
          selectedSection.value == TvShellSection.series) {
        unawaited(ensureCategoryCountsFresh());
      }
    });
    if (_app.usesTvShellHome) {
      _scheduleTvLiveBoot();
    } else {
      railExpanded.value = true;
      phase.value = TvShellPhase.categories;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (railFocusNodes[TvShellSection.live]!.canRequestFocus) {
          railFocusNodes[TvShellSection.live]!.requestFocus();
        }
      });
    }
  }

  void _onTvHomeLayoutModeChanged(TvHomeLayoutMode mode) {
    if (!_app.usesTvShellHome && mode != TvHomeLayoutMode.shell) return;
    if (mode == TvHomeLayoutMode.shell || _app.androidTvShellLayoutLocked.value) {
      _activateTvShellHome();
    } else {
      _deactivateTvShellHome();
    }
  }

  void _activateTvShellHome() {
    selectedSection.value = TvShellSection.live;
    phase.value = TvShellPhase.liveContent;
    railExpanded.value = false;
    channels.tvShellLiveActive.value = true;
    channels.tvShellLiveBrowseActive.value = false;
    if (_cache.result.value != null) {
      unawaited(channels.bootTvShellLivePreview());
    }
  }

  void _deactivateTvShellHome() {
    channels.tvShellLiveActive.value = false;
    channels.tvShellLiveBrowseActive.value = false;
    channels.clearStreamPreview();
  }

  void _scheduleTvLiveBoot() {
    if (_liveBootScheduled) return;
    _liveBootScheduled = true;
    channelsTvShellBootPending = true;
    selectedSection.value = TvShellSection.live;
    phase.value = TvShellPhase.liveContent;
    railExpanded.value = false;
    channels.tvShellLiveActive.value = true;

    void tryBoot() {
      if (_cache.result.value == null) return;
      if (channels.suppressTvShellPlaylistBoot) return;
      unawaited(channels.bootTvShellLivePreview());
    }

    tryBoot();
    _playlistBootWorker?.dispose();
    _playlistBootWorker = ever(_cache.result, (_) => tryBoot());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLiveFocusIfRemote();
    });
  }

  @override
  void onClose() {
    _playlistBootWorker?.dispose();
    _playlistWorker?.dispose();
    _tvHomeLayoutWorker?.dispose();
    channels.tvShellLiveActive.value = false;
    channels.tvShellLiveBrowseActive.value = false;
    channels.clearStreamPreview();
    _vodOmdbDebounce?.cancel();
    for (final n in railFocusNodes.values) {
      n.dispose();
    }
    categoryPanelFocusNode.dispose();
    liveChannelsFocusNode.dispose();
    vodBrowseFocusNode.dispose();
    vodContentFocusNode.dispose();
    vodSortToolbarFocusNode.dispose();
    vodSearchToolbarFocusNode.dispose();
    playlistsPanelFocusNode.dispose();
    continueWatchingPanelFocusNode.dispose();
    super.onClose();
  }

  List<VodItem> get vodPreviewItems => _vodPreviewItems;
  List<VodItem> get vodContentItems => _vodContentItems;
  List<SeriesItem> get seriesPreviewItems => _seriesPreviewItems;
  List<SeriesItem> get seriesContentItems => _seriesContentItems;

  TvShellVodSortMode get activeVodSortMode =>
      _isSeriesSection ? seriesSortMode.value : vodSortMode.value;

  void openVodSortMenu() => vodSortMenuOpen.value = true;

  void closeVodSortMenu() {
    if (!vodSortMenuOpen.value) return;
    vodSortMenuOpen.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vodContentPinned.value) {
        _requestVodDetailFocusIfRemote();
      } else {
        _requestVodPosterStripFocusIfRemote();
      }
    });
  }

  void openVodSearch(BuildContext context) {
    closeVodSortMenu();
    openSearch(context);
  }

  void setVodSortMode(TvShellVodSortMode mode) {
    if (_isSeriesSection) {
      if (mode == TvShellVodSortMode.random) _seriesSortRandomSeed++;
      seriesSortMode.value = mode;
      _applySeriesSort();
      if (mode == TvShellVodSortMode.rating && _seriesContentSource.isNotEmpty) {
        unawaited(_enrichSeriesRatingsForSort());
      }
    } else {
      if (mode == TvShellVodSortMode.random) _vodSortRandomSeed++;
      vodSortMode.value = mode;
      _applyVodSort();
      if (mode == TvShellVodSortMode.rating && _vodContentSource.isNotEmpty) {
        unawaited(() async {
          await RecommendedFilmsRatingCache.enrichRatings(
            _vodContentSource,
            limit: 80,
          );
          if (vodSortMode.value == TvShellVodSortMode.rating) {
            _applyVodSort();
            vodItemsRevision.value++;
          }
        }());
      }
    }
    vodSortMenuOpen.value = false;
    vodFocusedIndex.value = 0;
    vodItemsRevision.value++;
    _refreshFocusedOmdbAfterSort();
    if (vodContentPinned.value) {
      _requestVodDetailFocusIfRemote();
    } else {
      _requestVodPosterStripFocusIfRemote();
    }
  }

  void _applyVodSort() {
    _vodContentItems = sortTvShellVodItems(
      _vodContentSource,
      vodSortMode.value,
      randomSeed: _vodSortRandomSeed,
    );
  }

  void _applySeriesSort() {
    _seriesContentItems = sortTvShellSeriesItems(
      _seriesContentSource,
      seriesSortMode.value,
      randomSeed: _seriesSortRandomSeed,
    );
  }

  void _refreshFocusedOmdbAfterSort() {
    if (phase.value != TvShellPhase.vodContent) return;
    if (_isSeriesSection) {
      if (_seriesContentItems.isEmpty) return;
      _scheduleSeriesOmdb(_seriesContentItems.first);
    } else {
      if (_vodContentItems.isEmpty) return;
      _scheduleVodOmdb(_vodContentItems.first);
    }
  }

  Future<void> _enrichSeriesRatingsForSort() async {
    if (!Get.isRegistered<MovieService>()) return;
    final ms = Get.find<MovieService>();
    if (!MovieService.omdbApiAvailable) return;
    var done = 0;
    for (final s in _seriesContentSource) {
      if (done >= 48) break;
      if (RecommendedFilmsRatingCache.ratingForContentId(s.id) > 0) {
        continue;
      }
      try {
        final info = await ms.getMovieWithFallback(
          name: s.name,
          isSeries: true,
        );
        final r = double.tryParse(
              info.imdbRating?.replaceAll(',', '.') ?? '',
            ) ??
            0;
        if (r > 0) {
          await RecommendedFilmsRatingCache.put(s.id, r, notify: false);
          done++;
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    if (_isSeriesSection && seriesSortMode.value == TvShellVodSortMode.rating) {
      _applySeriesSort();
      vodItemsRevision.value++;
    }
  }

  bool get _isSeriesSection =>
      selectedSection.value == TvShellSection.series;

  List<int> get seriesSeasons {
    final seasons = seriesEpisodes.map((e) => e.season).toSet().toList()
      ..sort();
    return seasons;
  }

  List<SeriesEpisodeOption> get seriesEpisodesInSeason {
    final season = seriesSelectedSeason.value;
    if (season == null) return seriesEpisodes.toList();
    return seriesEpisodes.where((e) => e.season == season).toList();
  }

  SeriesEpisodeOption? get focusedSeriesEpisode {
    final list = seriesEpisodesInSeason;
    final idx = seriesFocusedEpisodeIndex.value;
    if (idx < 0 || idx >= list.length) return null;
    return list[idx];
  }

  String? get vodPreviewCategoryName => _vodCategoryName(vodPreviewCategoryId.value);
  String? get vodContentCategoryName => _vodCategoryName(vodContentCategoryId.value);

  void _ensureChildControllers() {
    if (!Get.isRegistered<ChannelsController>()) {
      Get.lazyPut<ChannelsController>(ChannelsController.new, fenix: true);
    }
    if (!Get.isRegistered<SettingsController>()) {
      Get.put<SettingsController>(SettingsController());
    }
  }

  /// Listeler panelinden playlist seçildi — yalnızca seçilen liste aktif olur.
  Future<void> onPlaylistSlotChosen(int slot, {BuildContext? context}) async {
    if (!Get.isRegistered<ActivePlaylistService>()) return;
    final active = Get.find<ActivePlaylistService>();
    if (active.activeSlot.value == slot && _cache.result.value != null) {
      return;
    }
    channels.suppressTvShellPlaylistBoot = true;
    try {
      final ok = await active.selectSlot(slot);
      if (!ok) return;
      _categoryCountsScopeKey = null;
      _clearVodState();
      phase.value = TvShellPhase.categories;
      channels.clearStreamPreview();
      channels.tvShellLiveActive.value = false;
      channels.tvShellLiveBrowseActive.value = false;
      await channels.reloadForActivePlaylistSwitch();
      unawaited(ensureCategoryCountsFresh());
      vodItemsRevision.value++;
      categoryCountsRevision.value++;
    } finally {
      channels.suppressTvShellPlaylistBoot = false;
    }
  }

  M3uResult? get data => _cache.result.value;

  bool _usesRemoteNav([BuildContext? context]) {
    final ctx = context ?? Get.context;
    if (ctx == null) return true;
    return remoteNavForScreenLayout(ctx, _app.layoutMode.value);
  }

  bool get _vodListTvLite => AppPerformance.isTvLite(_app);

  bool get _vodListTvLayout => _app.layoutMode.value == AppLayoutMode.tv;

  int get _vodPreviewPageSize => TvShellListWindow.previewPageSizeOf(
        tvLite: _vodListTvLite,
        tvLayout: _vodListTvLayout,
      );

  int get _vodContentPageSize => TvShellListWindow.contentPageSizeOf(
        tvLite: _vodListTvLite,
        tvLayout: _vodListTvLayout,
      );

  int get _vodLoadMoreLead => TvShellListWindow.loadMoreLeadOf(
        tvLite: _vodListTvLite,
        tvLayout: _vodListTvLayout,
      );

  int get _vodMaxContentItems => TvShellListWindow.maxContentItemsOf(
        tvLite: _vodListTvLite,
        tvLayout: _vodListTvLayout,
      );

  void registerCategoryRowFocusHandler(void Function(int? categoryId)? handler) {
    _categoryRowFocusHandler = handler;
  }

  void registerCategoryRowClearFocusHandler(void Function()? handler) {
    _categoryRowClearFocusHandler = handler;
  }

  void _clearCategoryRowFocus() {
    _categoryRowClearFocusHandler?.call();
  }

  /// Bölüm değişiminde yalnızca güncel seçim için kategori satırına odakla.
  void _scheduleCategoryFocus(TvShellSection section, int? categoryId) {
    final seq = ++_categoryFocusSeq;
    void attempt(int n) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (seq != _categoryFocusSeq) return;
        if (selectedSection.value != section) return;
        if (_categoryRowFocusHandler != null) {
          focusCategoryRow(categoryId);
          return;
        }
        if (n < 24) attempt(n + 1);
      });
    }

    attempt(0);
  }

  void registerVodDetailPlayFocusHandler(void Function()? handler) {
    _vodDetailPlayFocusHandler = handler;
  }

  void registerVodPosterStripFocusHandler(void Function()? handler) {
    _vodPosterStripFocusHandler = handler;
  }

  void registerVodBrowsePosterFocusHandler(
    TvShellSection section,
    void Function(int index)? handler,
  ) {
    if (handler == null) {
      if (_vodBrowsePosterFocusOwner == section) {
        _vodBrowsePosterFocusOwner = null;
        _vodBrowsePosterFocusHandler = null;
      }
      return;
    }
    _vodBrowsePosterFocusOwner = section;
    _vodBrowsePosterFocusHandler = handler;
    final pending = _pendingVodBrowsePosterFocusIndex;
    if (pending != null) {
      _pendingVodBrowsePosterFocusIndex = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handler(pending);
      });
    }
  }

  void registerVodBrowsePosterClearFocusHandler(
    TvShellSection section,
    void Function()? handler,
  ) {
    if (handler == null) {
      if (_vodBrowsePosterClearFocusOwner == section) {
        _vodBrowsePosterClearFocusOwner = null;
        _vodBrowsePosterClearFocusHandler = null;
      }
      return;
    }
    _vodBrowsePosterClearFocusOwner = section;
    _vodBrowsePosterClearFocusHandler = handler;
  }

  void clearVodBrowsePosterFocus() {
    vodBrowsePosterHasFocus.value = false;
    _vodBrowsePosterClearFocusHandler?.call();
  }

  void focusVodBrowsePosterAt(int index, {BuildContext? context}) {
    if (!_usesRemoteNav(context)) return;
    final section = selectedSection.value;
    if (section != TvShellSection.movies &&
        section != TvShellSection.series) {
      return;
    }
    vodFocusedIndex.value = index;
    vodBrowseFocusNode.unfocus();
    final handler = _vodBrowsePosterFocusHandler;
    if (handler != null && _vodBrowsePosterFocusOwner == section) {
      _pendingVodBrowsePosterFocusIndex = null;
      handler(index);
      return;
    }
    _pendingVodBrowsePosterFocusIndex = index;
    _retryPendingVodBrowsePosterFocus(0);
  }

  void _retryPendingVodBrowsePosterFocus(int attempt) {
    if (_pendingVodBrowsePosterFocusIndex == null) return;
    if (attempt > 32) {
      _pendingVodBrowsePosterFocusIndex = null;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final idx = _pendingVodBrowsePosterFocusIndex;
      if (idx == null) return;
      final section = selectedSection.value;
      final handler = _vodBrowsePosterFocusHandler;
      if (handler != null && _vodBrowsePosterFocusOwner == section) {
        _pendingVodBrowsePosterFocusIndex = null;
        handler(idx);
        return;
      }
      _retryPendingVodBrowsePosterFocus(attempt + 1);
    });
  }

  void focusCategoryRow(int? categoryId) {
    liveChannelsFocusNode.unfocus();
    categoryPanelFocusNode.unfocus();
    vodBrowseFocusNode.unfocus();
    vodContentFocusNode.unfocus();
    for (final node in railFocusNodes.values) {
      node.unfocus();
    }
    if (_categoryRowFocusHandler != null) {
      _categoryRowFocusHandler!(categoryId);
      return;
    }
    scheduleTvFocusRestore(categoryPanelFocusNode, maxAttempts: 16);
  }

  /// Canlı TV kanal listesinden sol: kategori paneli monte olana kadar odak dene.
  void focusLiveCategoryFromChannels(int? categoryId) {
    liveChannelsFocusNode.unfocus();
    for (final node in railFocusNodes.values) {
      node.unfocus();
    }
    railExpanded.value = false;
    void attempt(int n) {
      if (n > 32) {
        focusCategoryRow(categoryId);
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_categoryRowFocusHandler != null) {
          _categoryRowFocusHandler!(categoryId);
          return;
        }
        attempt(n + 1);
      });
    }

    attempt(0);
  }

  void registerPlaylistsRowFocusHandler(void Function()? handler) {
    _playlistsRowFocusHandler = handler;
  }

  void registerSettingsFirstTileFocusHandler(void Function()? handler) {
    _settingsFirstTileFocusHandler = handler;
  }

  void registerSettingsLeaveHandler(void Function()? handler) {
    _settingsLeaveHandler = handler;
  }

  void registerSettingsReturnFocusHandler(void Function(int index)? handler) {
    _settingsReturnFocusHandler = handler;
  }

  /// Ayarlar alt sayfasına girmeden önce: geri dönüşte bu karoya odaklan.
  void rememberSettingsReturnFocus(int shellDpadIndex) {
    _settingsPendingReturnFocusIndex = shellDpadIndex;
  }

  void restoreSettingsReturnFocus() {
    final idx = _settingsPendingReturnFocusIndex;
    _settingsPendingReturnFocusIndex = null;
    if (idx == null) return;
    _retrySettingsTileFocus(idx, 0);
  }

  void _retrySettingsTileFocus(int index, int attempt) {
    if (attempt > 32) return;
    if (_settingsReturnFocusHandler != null) {
      _settingsReturnFocusHandler!(index);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retrySettingsTileFocus(index, attempt + 1);
    });
  }

  void focusSettingsFirstTile([BuildContext? context]) {
    if (!_usesRemoteNav(context)) return;
    _retrySettingsFirstTileFocus(0);
  }

  /// Rail'den sağ ok: ayar paneli açıkken ilk ayar karosuna odak.
  void enterSettingsPanel({BuildContext? context}) {
    if (!_usesRemoteNav(context)) return;
    selectedSection.value = TvShellSection.settings;
    phase.value = TvShellPhase.categories;
    railExpanded.value = true;
    _clearVodState();
    _retrySettingsFirstTileFocus(0);
  }

  void _retrySettingsFirstTileFocus(int attempt) {
    if (attempt > 32) return;
    if (_settingsFirstTileFocusHandler != null) {
      _settingsFirstTileFocusHandler!();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_settingsFirstTileFocusHandler != null) {
        _settingsFirstTileFocusHandler!();
        return;
      }
      _retrySettingsFirstTileFocus(attempt + 1);
    });
  }

  void onLeftFromSettingsPanel() {
    _settingsLeaveHandler?.call();
    railExpanded.value = true;
    selectedSection.value = TvShellSection.settings;
    final node = railFocusNodes[TvShellSection.settings];
    if (node != null) {
      scheduleTvFocusRestore(node, maxAttempts: 24);
    }
  }

  void focusPlaylistsFirstRow({BuildContext? context}) {
    if (!_usesRemoteNav(context)) return;
    if (_playlistsRowFocusHandler != null) {
      _playlistsRowFocusHandler!();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_playlistsRowFocusHandler != null) {
        _playlistsRowFocusHandler!();
      }
    });
  }

  void onLeftFromPlaylistsPanel() {
    railExpanded.value = true;
    phase.value = TvShellPhase.categories;
    final node = railFocusNodes[TvShellSection.playlists];
    if (node != null) scheduleTvFocusRestore(node);
  }

  void registerContinueWatchingFocusHandler(void Function()? handler) {
    _continueWatchingFocusHandler = handler;
  }

  void focusContinueWatchingFirst({BuildContext? context}) {
    if (context != null && !_usesRemoteNav(context)) return;
    if (_continueWatchingFocusHandler != null) {
      _continueWatchingFocusHandler!();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_continueWatchingFocusHandler != null) {
        _continueWatchingFocusHandler!();
      }
    });
  }

  void onLeftFromContinueWatchingPanel() {
    railExpanded.value = true;
    phase.value = TvShellPhase.categories;
    final node = railFocusNodes[TvShellSection.continueWatching];
    if (node != null) scheduleTvFocusRestore(node);
  }

  int? _firstCategoryIdForSection(TvShellSection section) {
    final cats = categoriesForSection(section);
    return cats.isNotEmpty ? cats.first.id : null;
  }

  void _requestCategoryFocusIfRemote(
    BuildContext? context, {
    int? categoryId,
  }) {
    if (!_usesRemoteNav(context)) return;
    focusCategoryRow(categoryId ?? _firstCategoryIdForSection(selectedSection.value));
  }

  void _requestRailFocusIfRemote(TvShellSection section, [BuildContext? context]) {
    if (!_usesRemoteNav(context)) return;
    final node = railFocusNodes[section];
    if (node != null) scheduleTvFocusRestore(node);
  }

  void _requestLiveFocusIfRemote([BuildContext? context]) {
    if (!_usesRemoteNav(context)) return;
    scheduleTvFocusRestore(liveChannelsFocusNode);
  }

  void _requestVodBrowseFocusIfRemote([BuildContext? context]) {
    if (!_usesRemoteNav(context)) return;
    scheduleTvFocusRestore(vodBrowseFocusNode);
  }

  /// Canlı TV önizleme: kategori → kanal listesi, ilk kanal odak.
  void focusLiveBrowseChannels({BuildContext? context, int? categoryId}) {
    if (selectedSection.value != TvShellSection.live) return;
    if (phase.value != TvShellPhase.categories) return;
    final seq = ++_liveBrowseChannelFocusSeq;
    channels.tvShellLiveBrowseActive.value = true;
    channels.tvShellLiveActive.value = false;
    channels.tvShellLiveBrowsingChannels.value = true;
    if (categoryId != null) {
      channels.syncTvCategoryFocusFromRow(categoryId);
    }
    unawaited(
      channels.ensureBrowseCategoryReady().then((_) {
        if (isClosed || seq != _liveBrowseChannelFocusSeq) return;
        _clearCategoryRowFocus();
        categoryPanelFocusNode.unfocus();
        liveChannelsFocusNode.unfocus();
        _retryFocusLiveBrowseChannelRow(
          0,
          context: context,
          seq: seq,
        );
      }),
    );
  }

  void _retryFocusLiveBrowseChannelRow(
    int index, {
    BuildContext? context,
    required int seq,
    int attempt = 0,
  }) {
    if (isClosed || seq != _liveBrowseChannelFocusSeq) return;
    if (attempt > 32) return;
    final list = channels.filteredChannels;
    if (list.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _retryFocusLiveBrowseChannelRow(
          index,
          context: context,
          seq: seq,
          attempt: attempt + 1,
        );
      });
      return;
    }
    focusLiveChannelRow(index, context: context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed || seq != _liveBrowseChannelFocusSeq) return;
      if (channels.tvShellChannelRowHasFocus.value) return;
      _retryFocusLiveBrowseChannelRow(
        index,
        context: context,
        seq: seq,
        attempt: attempt + 1,
      );
    });
  }

  /// Film/dizi önizleme: kategori → poster şeridi, ilk poster odak.
  void focusVodBrowsePoster({BuildContext? context}) {
    if (phase.value != TvShellPhase.categories) return;
    final section = selectedSection.value;
    if (section != TvShellSection.movies &&
        section != TvShellSection.series) {
      return;
    }
    _clearCategoryRowFocus();
    categoryPanelFocusNode.unfocus();
    focusVodBrowsePosterAt(0, context: context);
  }

  /// Önizleme poster şeridinden sol/geri: ilgili kategoriye odak.
  void onLeftFromVodBrowse() {
    if (phase.value != TvShellPhase.categories) return;
    final section = selectedSection.value;
    if (section != TvShellSection.movies &&
        section != TvShellSection.series) {
      return;
    }
    clearVodBrowsePosterFocus();
    vodBrowseFocusNode.unfocus();
    railExpanded.value = false;
    focusCategoryRow(vodPreviewCategoryId.value);
  }

  void expandRail() {
    railExpanded.value = true;
  }

  void collapseRail() {
    railExpanded.value = false;
  }

  void openSearch(BuildContext context) {
    if (!Get.isRegistered<HomeController>()) return;
    Get.find<HomeController>().showGlobalSearch(context);
  }

  void openMinaWrapper() {
    if (!_app.minaWrappedEnabled.value) return;
    Get.toNamed(AppRoutes.minaAnalytics);
  }

  void openEpgMix() {
    Get.toNamed(AppRoutes.epgMix);
  }

  void selectRailSection(TvShellSection section, {BuildContext? context}) {
    selectedSection.value = section;
    if (section != TvShellSection.live) {
      channels.tvShellLiveActive.value = false;
      channels.tvShellLiveBrowseActive.value = false;
      channels.clearStreamPreview();
    }
    if (section == TvShellSection.search) {
      if (context != null) openSearch(context);
      return;
    }
    if (section == TvShellSection.settings) {
      phase.value = TvShellPhase.categories;
      railExpanded.value = true;
      _clearVodState();
      focusSettingsFirstTile(context);
      return;
    }
    if (section == TvShellSection.playlists) {
      phase.value = TvShellPhase.categories;
      railExpanded.value = false;
      _clearVodState();
      if (Get.isRegistered<ActivePlaylistService>()) {
        unawaited(Get.find<ActivePlaylistService>().refreshAvailable());
      }
      focusPlaylistsFirstRow(context: context);
      return;
    }
    if (section == TvShellSection.continueWatching) {
      phase.value = TvShellPhase.categories;
      railExpanded.value = false;
      _clearVodState();
      focusContinueWatchingFirst(context: context);
      return;
    }
    phase.value = TvShellPhase.categories;
    if (section == TvShellSection.movies ||
        section == TvShellSection.series ||
        section == TvShellSection.live) {
      railExpanded.value = false;
      ++_vodLoadGen;
      _clearCategoryRowFocus();
      if (section == TvShellSection.movies ||
          section == TvShellSection.series) {
        vodContentCategoryId.value = null;
        final firstVodId =
            _firstCategoryIdForSection(section) ?? kAllCategories;
        vodPreviewCategoryId.value = firstVodId;
        _scheduleCategoryFocus(section, firstVodId);
        unawaited(ensureCategoryCountsFresh());
        if (section == TvShellSection.movies) {
          unawaited(_loadVodPreview(firstVodId));
        } else {
          unawaited(_loadSeriesPreview(firstVodId));
        }
      } else {
        _clearVodState();
        channels.tvShellLiveActive.value = false;
        channels.tvShellLiveBrowseActive.value = true;
        final firstLiveId = _firstCategoryIdForSection(TvShellSection.live);
        channels.selectedCategoryId.value = firstLiveId;
        unawaited(_app.setLastLiveCategoryId(firstLiveId));
        _scheduleCategoryFocus(section, firstLiveId);
        unawaited(channels.applyTvShellLiveBrowseCategory(firstLiveId));
      }
    } else {
      railExpanded.value = true;
      _clearVodState();
      _requestCategoryFocusIfRemote(context);
    }
  }

  void onMovieCategoryPreview(int? categoryId) {
    if (selectedSection.value != TvShellSection.movies) return;
    if (phase.value != TvShellPhase.categories) return;
    if (vodPreviewCategoryId.value == categoryId) return;
    vodPreviewCategoryId.value = categoryId;
    unawaited(_loadVodPreview(categoryId));
  }

  void onLiveCategoryPreview(int? categoryId) {
    if (selectedSection.value != TvShellSection.live) return;
    if (phase.value != TvShellPhase.categories) return;
    channels.tvShellLiveBrowseActive.value = true;
    channels.selectCategoryTvBrowse(categoryId);
  }

  void onMovieCategoryChosen(int? categoryId, {BuildContext? context}) {
    if (selectedSection.value != TvShellSection.movies) return;
    vodContentCategoryId.value = categoryId;
    vodPreviewCategoryId.value = categoryId;
    vodFocusedIndex.value = 0;
    vodContentPinned.value = false;
    vodFocusedTrailers.clear();
    _vodTrailersVodId = null;
    phase.value = TvShellPhase.vodContent;
    unawaited(_loadVodContent(categoryId));
    _requestVodContentFocusIfRemote(context);
  }

  void onSeriesCategoryPreview(int? categoryId) {
    if (selectedSection.value != TvShellSection.series) return;
    if (phase.value != TvShellPhase.categories) return;
    if (vodPreviewCategoryId.value == categoryId) return;
    vodPreviewCategoryId.value = categoryId;
    unawaited(_loadSeriesPreview(categoryId));
  }

  void onSeriesCategoryChosen(int? categoryId, {BuildContext? context}) {
    if (selectedSection.value != TvShellSection.series) return;
    vodContentCategoryId.value = categoryId;
    vodPreviewCategoryId.value = categoryId;
    vodFocusedIndex.value = 0;
    vodContentPinned.value = false;
    _clearSeriesEpisodeState();
    phase.value = TvShellPhase.vodContent;
    unawaited(_loadSeriesContent(categoryId));
    _requestVodContentFocusIfRemote(context);
  }

  VodItem? get focusedVodContentItem {
    final idx = vodFocusedIndex.value;
    if (idx < 0 || idx >= _vodContentItems.length) return null;
    return _vodContentItems[idx];
  }

  SeriesItem? get focusedSeriesContentItem {
    final idx = vodFocusedIndex.value;
    if (idx < 0 || idx >= _seriesContentItems.length) return null;
    return _seriesContentItems[idx];
  }

  void enterVodFilmDetail() {
    if (focusedVodContentItem == null) return;
    vodContentPinned.value = true;
    unawaited(_loadVodTrailersForFocused());
  }

  void enterSeriesDetail() {
    if (focusedSeriesContentItem == null) return;
    vodContentPinned.value = true;
    _scheduleSeriesOmdb(focusedSeriesContentItem!);
    unawaited(_loadSeriesEpisodesForFocused());
  }

  /// Birleşik aramadan dizi seçildiğinde TV sinema detayına geç (browse değil).
  Future<void> openSeriesFromSearch(SeriesItem series) async {
    selectedSection.value = TvShellSection.series;
    channels.tvShellLiveActive.value = false;
    channels.tvShellLiveBrowseActive.value = false;
    channels.clearStreamPreview();
    closeVodSortMenu();

    final categoryId = series.categoryId;
    vodContentCategoryId.value = categoryId;
    vodPreviewCategoryId.value = categoryId;
    vodContentPinned.value = false;
    _clearSeriesEpisodeState();
    phase.value = TvShellPhase.vodContent;
    railExpanded.value = false;

    await _loadSeriesContent(categoryId);

    var idx = _indexOfSeriesInContentList(series);
    if (idx < 0) {
      _seriesContentSource = [
        series,
        ..._seriesContentSource.where((s) => s.id != series.id),
      ];
      _applySeriesSort();
      idx = _indexOfSeriesInContentList(series);
      if (idx < 0) {
        _seriesContentItems = [
          series,
          ..._seriesContentItems.where((s) => s.id != series.id),
        ];
        idx = 0;
      }
    }

    vodFocusedIndex.value = idx;
    vodItemsRevision.value++;
    vodContentPinned.value = true;
    final focused = _seriesContentItems[idx];
    _scheduleSeriesOmdb(focused);
    await _loadSeriesEpisodesForFocused();
    _scheduleCategoryFocus(TvShellSection.series, categoryId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      _requestVodDetailFocusIfRemote();
    });
  }

  int _indexOfSeriesInContentList(SeriesItem target) {
    final targetKey = SeriesNameGrouping.canonicalKey(target.name);
    for (var i = 0; i < _seriesContentItems.length; i++) {
      final item = _seriesContentItems[i];
      if (item.id == target.id) return i;
      if (targetKey.isNotEmpty &&
          SeriesNameGrouping.canonicalKey(item.name) == targetKey) {
        return i;
      }
    }
    return -1;
  }
  /// Birleşik aramadan film seçildiğinde TV sinema detayına geç (browse değil).
  Future<void> openVodFromSearch(VodItem vod) async {
    selectedSection.value = TvShellSection.movies;
    channels.tvShellLiveActive.value = false;
    channels.tvShellLiveBrowseActive.value = false;
    channels.clearStreamPreview();
    closeVodSortMenu();

    final categoryId = vod.categoryId;
    vodContentCategoryId.value = categoryId;
    vodPreviewCategoryId.value = categoryId;
    vodContentPinned.value = false;
    vodFocusedTrailers.clear();
    _vodTrailersVodId = null;
    phase.value = TvShellPhase.vodContent;
    railExpanded.value = false;

    await _loadVodContent(categoryId);

    var idx = _indexOfVodInContentList(vod);
    if (idx < 0) {
      _vodContentSource = [
        vod,
        ..._vodContentSource.where((v) => v.id != vod.id),
      ];
      _applyVodSort();
      idx = _indexOfVodInContentList(vod);
      if (idx < 0) {
        _vodContentItems = [
          vod,
          ..._vodContentItems.where((v) => v.id != vod.id),
        ];
        idx = 0;
      }
    }

    vodFocusedIndex.value = idx;
    vodItemsRevision.value++;
    vodContentPinned.value = true;
    final focused = _vodContentItems[idx];
    _scheduleVodOmdb(focused);
    _scheduleCategoryFocus(TvShellSection.movies, categoryId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      _requestVodDetailFocusIfRemote();
    });
  }

  int _indexOfVodInContentList(VodItem target) {
    for (var i = 0; i < _vodContentItems.length; i++) {
      final item = _vodContentItems[i];
      if (item.id == target.id) return i;
    }
    return -1;
  }

  void exitVodFilmDetail() {
    if (!vodContentPinned.value) return;
    vodContentPinned.value = false;
    _vodDetailUnpinBackGuardMs = DateTime.now().millisecondsSinceEpoch;
    vodFocusedTrailers.clear();
    _vodTrailersVodId = null;
    vodTrailersLoading.value = false;
    _clearSeriesEpisodeState();
    _requestVodPosterStripFocusIfRemote();
  }

  /// Tam ekran oynatıcıdan dönünce sinema detayına (pinned) geri dön;
  /// kategori paneline veya poster listesine atlama.
  void restoreVodCinemaListAfterPlayerPop() {
    _restoreVodDetailAfterPlayerPop();
  }

  void _restoreVodDetailAfterPlayerPop() {
    final section = selectedSection.value;
    if (section != TvShellSection.movies &&
        section != TvShellSection.series) {
      return;
    }

    if (phase.value != TvShellPhase.vodContent) {
      phase.value = TvShellPhase.vodContent;
      railExpanded.value = false;
      final catId = vodContentCategoryId.value ?? vodPreviewCategoryId.value;
      if (catId != null) {
        vodPreviewCategoryId.value = catId;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    _vodDetailUnpinBackGuardMs = now;
    _vodPlayerReturnGuardMs = now;
    _absorbNextBackAfterPlayerReturn = true;

    if (!vodContentPinned.value) {
      final hasContent = _isSeriesSection
          ? focusedSeriesContentItem != null
          : focusedVodContentItem != null;
      if (hasContent) {
        vodContentPinned.value = true;
        if (_isSeriesSection && seriesEpisodes.isEmpty) {
          unawaited(_loadSeriesEpisodesForFocused());
        }
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestVodDetailFocusIfRemote();
    });
  }

  void setSeriesSelectedSeason(int season) {
    if (seriesSelectedSeason.value == season) return;
    seriesSelectedSeason.value = season;
    seriesFocusedEpisodeIndex.value = 0;
  }

  void setSeriesFocusedEpisodeIndex(int index) {
    if (seriesFocusedEpisodeIndex.value == index) return;
    seriesFocusedEpisodeIndex.value = index;
  }

  void setVodFocusedIndex(int index) {
    if (vodFocusedIndex.value == index) return;
    if (phase.value == TvShellPhase.vodContent && vodContentPinned.value) {
      return;
    }
    vodFocusedIndex.value = index;
    if (_isSeriesSection) {
      final items = phase.value == TvShellPhase.vodContent
          ? _seriesContentItems
          : _seriesPreviewItems;
      if (index >= 0 && index < items.length) {
        _scheduleSeriesOmdb(items[index]);
      }
      _maybeLoadMoreSeriesAtIndex(index);
    } else {
      final items = phase.value == TvShellPhase.vodContent
          ? _vodContentItems
          : _vodPreviewItems;
      if (index >= 0 && index < items.length) {
        _scheduleVodOmdb(items[index]);
      }
      _maybeLoadMoreVodAtIndex(index);
    }
  }

  /// Odaklanan öğe ile eşleşmeyen eski OMDB önbelleğini kullanma.
  MovieModel? omdbDetailForItemId(int? itemId) {
    if (itemId == null || itemId == 0 || vodOmdbItemId.value != itemId) {
      return null;
    }
    return vodOmdbDetail.value;
  }

  /// Dokunmatik kaydırma sonuna yaklaşınca sonraki sayfayı yükle.
  void onVodListNearScrollEnd() {
    if (_isSeriesSection) {
      final len = phase.value == TvShellPhase.vodContent
          ? _seriesContentItems.length
          : _seriesPreviewItems.length;
      if (len == 0) return;
      unawaited(_maybeLoadMoreSeriesAtIndex(len - 1, force: true));
    } else {
      final len = phase.value == TvShellPhase.vodContent
          ? _vodContentItems.length
          : _vodPreviewItems.length;
      if (len == 0) return;
      unawaited(_maybeLoadMoreVodAtIndex(len - 1, force: true));
    }
  }

  void onLeftFromVodContent() {
    if (vodContentPinned.value) {
      exitVodFilmDetail();
      return;
    }
    final catId = vodContentCategoryId.value ?? vodPreviewCategoryId.value;
    vodContentFocusNode.unfocus();
    phase.value = TvShellPhase.categories;
    vodContentCategoryId.value = null;
    if (catId != null) {
      vodPreviewCategoryId.value = catId;
    }
    railExpanded.value = false;
    unawaited(
      _isSeriesSection
          ? _loadSeriesPreview(vodPreviewCategoryId.value ?? kAllCategories)
          : _loadVodPreview(vodPreviewCategoryId.value ?? kAllCategories),
    );
    _scheduleCategoryFocus(selectedSection.value, catId);
  }

  void onCategoryChosen(int? categoryId, {BuildContext? context}) {
    if (selectedSection.value != TvShellSection.live) return;
    railExpanded.value = false;
    channels.tvShellLiveBrowseActive.value = false;
    channels.tvShellLiveActive.value = true;
    phase.value = TvShellPhase.liveContent;
    final remote = _usesRemoteNav(context);
    final resume = channels.selectedCategoryId.value == categoryId &&
        channels.selectedChannel.value != null;
    channels.selectCategory(
      categoryId,
      moveFocusToChannels: remote,
      resumeChannelSelection: resume,
    );
    if (!remote) {
      _requestLiveFocusIfRemote(context);
    }
  }

  /// Tam canlı TV panelinde ilk kanal satırına odak (kategori seçimi sonrası).
  void focusLiveChannelRow(int index, {BuildContext? context}) {
    if (!_usesRemoteNav(context)) return;
    liveChannelsFocusNode.unfocus();
    channels.focusTvShellChannelRow(index);
  }

  void onLeftFromCategories() {
    railExpanded.value = true;
    phase.value = TvShellPhase.categories;
    _clearCategoryRowFocus();
    liveChannelsFocusNode.unfocus();
    vodBrowseFocusNode.unfocus();
    categoryPanelFocusNode.unfocus();
    final s = selectedSection.value;
    final node = railFocusNodes[s];
    if (node != null) {
      if (node.canRequestFocus) {
        node.requestFocus();
      }
      if (!node.hasFocus) {
        scheduleTvFocusRestore(node, maxAttempts: 16);
      }
    }
  }

  void onLeftFromLiveContent() {
    final catId = channels.selectedCategoryId.value;
    channels.clearTvShellChannelRowFocus();
    liveChannelsFocusNode.unfocus();
    for (final node in railFocusNodes.values) {
      node.unfocus();
    }
    railExpanded.value = false;
    channels.tvShellLiveActive.value = false;
    channels.tvShellLiveBrowseActive.value = true;
    channels.clearStreamPreview();
    phase.value = TvShellPhase.categories;
    focusLiveCategoryFromChannels(catId);
  }

  /// Önizleme modunda kanal listesinden sol/geri: seçili kategoriye odak.
  void onLeftFromLiveBrowse() {
    if (phase.value != TvShellPhase.categories) return;
    if (selectedSection.value != TvShellSection.live) return;
    channels.tvShellLiveBrowsingChannels.value = false;
    channels.clearTvShellChannelRowFocus();
    liveChannelsFocusNode.unfocus();
    railExpanded.value = false;
    focusLiveCategoryFromChannels(channels.selectedCategoryId.value);
  }

  /// TV ana ekranında geri: Android TV'de doğrudan çık, diğerlerinde onay diyaloğu.
  void _requestTvShellExit() {
    if (_app.androidTvShellLayoutLocked.value) {
      ExitConfirmDialog.exitAppImmediately();
    } else {
      ExitConfirmDialog.showIfNeeded();
    }
  }

  void onBack() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Aynı fiziksel Geri: PopScope + Shortcuts çift tetiklemesini birleştir.
    if (now - _lastBackCoalesceMs < 100) return;
    _lastBackCoalesceMs = now;

    // Açık popup / alt sayfa: önce onu kapat; TV kabuğu gezinmesine düşme.
    if (Get.isDialogOpen == true) {
      Get.back<void>();
      return;
    }
    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }

    // Ana ekran / rail: doğrudan çıkış (onay veya Android TV'de anında kapat).
    if (phase.value == TvShellPhase.liveContent ||
        phase.value == TvShellPhase.rail) {
      _requestTvShellExit();
      return;
    }

    if (now - _lastBackHandledMs < 450) return;
    _lastBackHandledMs = now;

    switch (phase.value) {
      case TvShellPhase.vodContent:
        if (vodSortMenuOpen.value) {
          closeVodSortMenu();
          return;
        }
        if (_absorbNextBackAfterPlayerReturn) {
          _absorbNextBackAfterPlayerReturn = false;
          return;
        }
        if (vodContentPinned.value) {
          exitVodFilmDetail();
        } else {
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          if (nowMs - _vodDetailUnpinBackGuardMs < 120) return;
          onLeftFromVodContent();
        }
        return;
      case TvShellPhase.liveContent:
        // Üstte debounce'suz ele alınır.
        return;
      case TvShellPhase.categories:
        if (selectedSection.value == TvShellSection.live &&
            channels.tvShellChannelRowHasFocus.value) {
          onLeftFromLiveBrowse();
          return;
        }
        if ((selectedSection.value == TvShellSection.movies ||
                selectedSection.value == TvShellSection.series) &&
            vodBrowsePosterHasFocus.value) {
          onLeftFromVodBrowse();
          return;
        }
        if (selectedSection.value == TvShellSection.playlists) {
          onLeftFromPlaylistsPanel();
          return;
        }
        if (selectedSection.value == TvShellSection.settings) {
          onLeftFromSettingsPanel();
          return;
        }
        if (_absorbNextBackAfterPlayerReturn) {
          _absorbNextBackAfterPlayerReturn = false;
          return;
        }
        if (now - _vodPlayerReturnGuardMs < 180) {
          final s = selectedSection.value;
          if (s == TvShellSection.movies || s == TvShellSection.series) {
            _restoreVodDetailAfterPlayerPop();
            return;
          }
        }
        if (!railExpanded.value) {
          railExpanded.value = true;
          final node = railFocusNodes[selectedSection.value];
          if (node != null) scheduleTvFocusRestore(node);
        } else {
          _requestTvShellExit();
        }
        return;
      case TvShellPhase.rail:
        // [onBack] başında debounce'suz ele alınır.
        return;
    }
  }

  /// Film/dizi kategori satırlarındaki rozet sayıları — DB destekliyse ucuz COUNT.
  Future<void> ensureCategoryCountsFresh() async {
    final d = data;
    if (d == null) {
      if (_categoryCountsScopeKey != null) {
        _categoryCountsScopeKey = null;
        _vodCountsByCategory = const {};
        _seriesCountsByCategory = const {};
        categoryCountsRevision.value++;
      }
      return;
    }
    final scope = homeCardCountsScopeKey(d, _app, _cache);
    if (_categoryCountsScopeKey == scope) return;

    _categoryCountsScopeKey = scope;
    final ds = Get.isRegistered<PlaylistDataSource>()
        ? Get.find<PlaylistDataSource>()
        : null;
    if (ds != null && ds.isDbBacked) {
      final gen = ++_categoryCountsLoadGen;
      final vodCounts = await ds.vodCountsByCategory();
      final seriesCounts = await ds.seriesCountsByCategory();
      if (gen != _categoryCountsLoadGen) return;
      if (_categoryCountsScopeKey != scope) return;
      _vodCountsByCategory = vodCounts;
      _seriesCountsByCategory = seriesCounts;
      categoryCountsRevision.value++;
      return;
    }
    _vodCountsByCategory = _vodCountsInMemory(d);
    _seriesCountsByCategory = _seriesCountsInMemory(d);
    categoryCountsRevision.value++;
  }

  Map<int, int> _vodCountsInMemory(M3uResult d) {
    if (d.vod.isEmpty) return const {};
    final m = <int, int>{};
    for (final v in d.vod) {
      if (PlaylistCategoryHide.vodItemHidden(_app, _cache, d, v)) continue;
      m[v.categoryId] = (m[v.categoryId] ?? 0) + 1;
    }
    return m;
  }

  Map<int, int> _seriesCountsInMemory(M3uResult d) {
    if (d.series.isEmpty) return const {};
    final m = <int, int>{};
    for (final s in d.series) {
      if (PlaylistCategoryHide.seriesItemHidden(_app, _cache, d, s)) continue;
      m[s.categoryId] = (m[s.categoryId] ?? 0) + 1;
    }
    return m;
  }

  int _vodCategoryCount(M3uResult d, int categoryId) {
    categoryCountsRevision.value;
    if (_vodCountsByCategory.isNotEmpty) {
      return _vodCountsByCategory[categoryId] ?? 0;
    }
    if (d.vod.isNotEmpty) {
      var n = 0;
      for (final v in d.vod) {
        if (v.categoryId == categoryId &&
            !PlaylistCategoryHide.vodItemHidden(_app, _cache, d, v)) {
          n++;
        }
      }
      return n;
    }
    return BrowseCatalogIndex.of(d).vodByCategory[categoryId]?.length ?? 0;
  }

  int _seriesCategoryCount(M3uResult d, int categoryId) {
    categoryCountsRevision.value;
    if (_seriesCountsByCategory.isNotEmpty) {
      return _seriesCountsByCategory[categoryId] ?? 0;
    }
    if (d.series.isNotEmpty) {
      var n = 0;
      for (final s in d.series) {
        if (s.categoryId == categoryId &&
            !PlaylistCategoryHide.seriesItemHidden(_app, _cache, d, s)) {
          n++;
        }
      }
      return n;
    }
    return BrowseCatalogIndex.of(d).seriesByCategory[categoryId]?.length ?? 0;
  }

  int _visibleVodTotal(M3uResult d, List<VodCategory> ordered) {
    categoryCountsRevision.value;
    if (_vodCountsByCategory.isNotEmpty) {
      var total = 0;
      for (final c in ordered) {
        total += _vodCountsByCategory[c.id] ?? 0;
      }
      return total;
    }
    if (d.vod.isNotEmpty) return d.vod.length;
    final idx = BrowseCatalogIndex.of(d);
    var total = 0;
    for (final c in ordered) {
      total += idx.vodByCategory[c.id]?.length ?? 0;
    }
    return total;
  }

  int _visibleSeriesTotal(M3uResult d, List<SeriesCategory> ordered) {
    categoryCountsRevision.value;
    if (_seriesCountsByCategory.isNotEmpty) {
      var total = 0;
      for (final c in ordered) {
        total += _seriesCountsByCategory[c.id] ?? 0;
      }
      return total;
    }
    if (d.series.isNotEmpty) return d.series.length;
    final idx = BrowseCatalogIndex.of(d);
    var total = 0;
    for (final c in ordered) {
      total += idx.seriesByCategory[c.id]?.length ?? 0;
    }
    return total;
  }

  List<({int? id, String name, int count, IconData? icon})> categoriesForSection(
    TvShellSection section,
  ) {
    final d = data;
    if (d == null) return const [];

    return switch (section) {
      TvShellSection.live => () {
          final ch = channels;
          final memoRev = Object.hash(
            ch.playlistRevision.value,
            _cache.layoutRevision.value,
            _app.xtreamHideRevision.value,
            ch.selectedCategoryId.value,
          );
          if (_liveCategoriesMemoRev == memoRev && _liveCategoriesMemo != null) {
            return _liveCategoriesMemo!;
          }
          final counts = ch.categoryCountSnapshot();
          final rows = <({int? id, String name, int count, IconData? icon})>[
            (
              id: null,
              name: 'channels.allChannels'.tr,
              count: counts.allVisibleCount,
              icon: Icons.grid_view_rounded,
            ),
            (
              id: kFavoritesVirtualCategoryId,
              name: 'channels.favoritesCategory'.tr,
              count: counts.favoritesVisibleCount,
              icon: Icons.bookmark_rounded,
            ),
            if (ch.hasRecentlyWatchedLiveChannels)
              (
                id: kRecentlyWatchedVirtualCategoryId,
                name: 'channels.recentlyWatchedCategory'.tr,
                count: counts.recentlyWatchedVisibleCount,
                icon: Icons.history_rounded,
              ),
          ];
          for (final c in ch.categories) {
            rows.add((
              id: c.id,
              name: c.name,
              count: counts.categoryCounts[c.id] ?? 0,
              icon: null,
            ));
          }
          _liveCategoriesMemoRev = memoRev;
          _liveCategoriesMemo = rows;
          return rows;
        }(),
      TvShellSection.movies => _vodCategories(d, films: true),
      TvShellSection.series => _vodCategories(d, films: false),
      _ => const [],
    };
  }

  List<({int? id, String name, int count, IconData? icon})> _vodCategories(
    M3uResult d, {
    required bool films,
  }) {
    final fav = Get.isRegistered<FavoritesService>()
        ? Get.find<FavoritesService>()
        : null;
    if (films) {
      final visible = d.vodCategories
          .where((c) =>
              !PlaylistCategoryHide.vodCategoryHidden(_app, _cache, d, c.id))
          .toList();
      final ordered =
          PlaylistCategoryHide.orderVodCategories(_app, _cache, visible);
      final favCount = fav?.vodIds.length ?? 0;
      final last50Count = _last50VodCategoryCount(d);
      final top50Count = _top50VodCategoryCount(d);
      final totalAll = _visibleVodTotal(d, ordered);
      return [
        (
          id: kRecentVodCategory,
          name: 'recommendedFilms.last50Films'.tr,
          count: last50Count,
          icon: Icons.new_releases_rounded,
        ),
        (
          id: kFavVodCategory,
          name: 'tvShell.category.favFilms'.tr,
          count: favCount,
          icon: Icons.bookmark_rounded,
        ),
        (
          id: kTvShellTop50VodCategory,
          name: 'tvShell.category.popular50Films'.tr,
          count: top50Count,
          icon: Icons.star_rounded,
        ),
        (
          id: kAllCategories,
          name: 'tvShell.category.allFilms'.tr,
          count: totalAll,
          icon: Icons.movie_rounded,
        ),
        ...ordered.map(
          (c) => (
            id: c.id,
            name: c.name,
            count: _vodCategoryCount(d, c.id),
            icon: null,
          ),
        ),
      ];
    }
    final visible = d.seriesCategories
        .where((c) =>
            !PlaylistCategoryHide.seriesCategoryHidden(_app, _cache, d, c.id))
        .toList();
    final ordered =
        PlaylistCategoryHide.orderSeriesCategories(_app, _cache, visible);
    final favCount = fav?.seriesIds.length ?? 0;
    final last50Count = _last50SeriesCategoryCount(d);
    final top50Count = _top50SeriesCategoryCount(d);
    final totalAll = _visibleSeriesTotal(d, ordered);
    return [
      (
        id: kRecentSeriesCategory,
        name: 'recommendedFilms.last50Series'.tr,
        count: last50Count,
        icon: Icons.new_releases_rounded,
      ),
      (
        id: kFavSeriesCategory,
        name: 'tvShell.category.favSeries'.tr,
        count: favCount,
        icon: Icons.bookmark_rounded,
      ),
      (
        id: kTvShellTop50SeriesCategory,
        name: 'tvShell.category.popular50Series'.tr,
        count: top50Count,
        icon: Icons.star_rounded,
      ),
      (
        id: kAllCategories,
        name: 'tvShell.category.allSeries'.tr,
        count: totalAll,
        icon: Icons.video_library_rounded,
      ),
      ...ordered.map(
        (c) => (
          id: c.id,
          name: c.name,
          count: _seriesCategoryCount(d, c.id),
          icon: null,
        ),
      ),
    ];
  }

  int _last50VodCategoryCount(M3uResult d) {
    final fromMeta = d.recentVodIds.length;
    if (fromMeta > 0) {
      return fromMeta.clamp(0, FilmDiziCatalog.last50Limit);
    }
    return FilmDiziCatalog.last50Films(d).length;
  }

  int _last50SeriesCategoryCount(M3uResult d) {
    final fromMeta = d.recentSeriesIds.length;
    if (fromMeta > 0) {
      return fromMeta.clamp(0, FilmDiziCatalog.last50Limit);
    }
    return FilmDiziCatalog.last50Series(d).length;
  }

  int _top50VodCategoryCount(M3uResult d) {
    final visible = FilmDiziCatalog.visibleVods(d).length;
    if (visible == 0) return FilmDiziCatalog.last50Limit;
    return visible.clamp(0, FilmDiziCatalog.last50Limit);
  }

  int _top50SeriesCategoryCount(M3uResult d) {
    final visible = FilmDiziCatalog.visibleSeries(d).length;
    if (visible == 0) return FilmDiziCatalog.last50Limit;
    return visible.clamp(0, FilmDiziCatalog.last50Limit);
  }

  bool get showsCategoryPanel {
    if (phase.value != TvShellPhase.categories) return false;
    final s = selectedSection.value;
    return s == TvShellSection.live ||
        s == TvShellSection.movies ||
        s == TvShellSection.series;
  }

  bool get showsRail => phase.value != TvShellPhase.vodContent;

  bool get showsLiveContent =>
      selectedSection.value == TvShellSection.live &&
      phase.value == TvShellPhase.liveContent;

  bool get showsLiveBrowsePanel =>
      selectedSection.value == TvShellSection.live &&
      phase.value == TvShellPhase.categories;

  bool get showsMoviesBrowsePanel =>
      selectedSection.value == TvShellSection.movies &&
      phase.value == TvShellPhase.categories;

  bool get showsMoviesContentPanel =>
      selectedSection.value == TvShellSection.movies &&
      phase.value == TvShellPhase.vodContent;

  bool get showsSeriesBrowsePanel =>
      selectedSection.value == TvShellSection.series &&
      phase.value == TvShellPhase.categories;

  bool get showsSeriesContentPanel =>
      selectedSection.value == TvShellSection.series &&
      phase.value == TvShellPhase.vodContent;

  bool get showsSettingsPanel =>
      selectedSection.value == TvShellSection.settings;

  bool get showsPlaylistsPanel =>
      selectedSection.value == TvShellSection.playlists;

  /// [TvShellPanelTransition] anahtarı — panel değişiminde animasyon.
  String get panelTransitionKey {
    final section = selectedSection.value;
    final p = phase.value;
    if (section == TvShellSection.settings) return 'settings';
    if (section == TvShellSection.playlists) return 'playlists';
    if (p == TvShellPhase.vodContent) {
      return 'vod_${section.name}';
    }
    if (p == TvShellPhase.liveContent) return 'live_full';
    if (p == TvShellPhase.categories) {
      return 'browse_${section.name}';
    }
    return 'rail_${section.name}';
  }

  void _requestVodContentFocusIfRemote([BuildContext? context]) {
    if (!_usesRemoteNav(context)) return;
    scheduleTvFocusRestore(vodContentFocusNode);
  }

  void _requestVodPosterStripFocusIfRemote([BuildContext? context]) {
    if (!_usesRemoteNav(context)) return;
    if (_vodPosterStripFocusHandler != null) {
      _vodPosterStripFocusHandler!();
      return;
    }
    _requestVodContentFocusIfRemote(context);
  }

  void _requestVodDetailFocusIfRemote([BuildContext? context]) {
    if (!_usesRemoteNav(context)) return;
    if (_vodDetailPlayFocusHandler != null) {
      _vodDetailPlayFocusHandler!();
      return;
    }
    scheduleTvFocusRestore(vodContentFocusNode, maxAttempts: 16);
  }

  void _clearVodState() {
    _vodOmdbDebounce?.cancel();
    vodPreviewCategoryId.value = null;
    vodContentCategoryId.value = null;
    _vodPreviewItems = const [];
    _vodContentItems = const [];
    _vodContentSource = const [];
    _seriesPreviewItems = const [];
    _seriesContentItems = const [];
    _seriesContentSource = const [];
    vodSortMenuOpen.value = false;
    vodFocusedIndex.value = 0;
    vodOmdbDetail.value = null;
    vodOmdbItemId.value = 0;
    vodXtreamFields.value = null;
    vodOmdbLoading.value = false;
    vodContentPinned.value = false;
    vodFocusedTrailers.clear();
    _vodTrailersVodId = null;
    vodTrailersLoading.value = false;
    _clearSeriesEpisodeState();
    _resetVodPagingState();
    vodItemsRevision.value++;
  }

  void _resetVodPagingState() {
    _vodPreviewCategoryKey = null;
    _vodPreviewNextOffset = 0;
    _vodPreviewHasMore = false;
    _vodPreviewLoadingMore = false;
    _vodContentListCategoryKey = null;
    _vodContentNextOffset = 0;
    _vodContentHasMore = false;
    _vodContentLoadingMore = false;
    _vodMemPool = null;
    _vodMemPoolCategoryKey = null;
    _seriesPreviewCategoryKey = null;
    _seriesPreviewNextOffset = 0;
    _seriesPreviewHasMore = false;
    _seriesPreviewLoadingMore = false;
    _seriesContentListCategoryKey = null;
    _seriesContentNextOffset = 0;
    _seriesContentHasMore = false;
    _seriesContentLoadingMore = false;
    _seriesMemGroupedPool = null;
    _seriesMemPoolCategoryKey = null;
  }

  void _clearSeriesEpisodeState() {
    _seriesEpisodesLoadGen++;
    seriesEpisodes.clear();
    seriesEpisodesLoading.value = false;
    seriesSelectedSeason.value = null;
    seriesFocusedEpisodeIndex.value = 0;
    seriesXtreamMeta.value = null;
    _seriesEpisodesSeriesId = null;
  }

  List<Channel> _vodContentTape() => [
        for (final v in _vodContentItems)
          Channel(
            id: v.id,
            name: v.name,
            streamUrl: v.streamUrl,
            categoryId: v.categoryId,
            logoUrl: v.posterUrl,
          ),
      ];

  Future<void> playFocusedVodFilm() async {
    final vod = focusedVodContentItem;
    if (vod == null) return;
    await openPlayerRoute(
      PlayerScreenArgs(
        channel: Channel(
          id: vod.id,
          name: vod.name,
          streamUrl: vod.streamUrl,
          categoryId: vod.categoryId,
          logoUrl: vod.posterUrl,
        ),
        movieBrowseTape: _vodContentTape(),
      ),
    );
  }

  Future<void> openFocusedExternalPlayer() async {
    final vod = focusedVodContentItem;
    if (vod == null) return;
    if (!Get.isRegistered<ExternalPlayerService>()) return;
    final ext = Get.find<ExternalPlayerService>();
    if (!ext.isPlatformSupported) {
      Get.snackbar('', 'externalPlayer.picker.unsupported'.tr);
      return;
    }
    final settings = Get.find<AppSettingsService>();
    final ok = await ext.launch(
      vod.streamUrl,
      appId: settings.externalPlayerId.value ?? ExternalPlayerService.chooserId,
      title: vod.name,
    );
    if (!ok) {
      Get.snackbar('', 'externalPlayer.error.launchFailed'.tr);
    }
  }

  void toggleFocusedFavorite() {
    final vod = focusedVodContentItem;
    if (vod == null) return;
    Get.find<FavoritesService>().toggleVod(vod.id);
  }

  bool get isFocusedFavorite {
    final vod = focusedVodContentItem;
    if (vod == null) return false;
    return Get.find<FavoritesService>().hasVod(vod.id);
  }

  void toggleFocusedSeriesFavorite() {
    final series = focusedSeriesContentItem;
    if (series == null) return;
    Get.find<FavoritesService>().toggleSeries(series.id);
  }

  bool get isFocusedSeriesFavorite {
    final series = focusedSeriesContentItem;
    if (series == null) return false;
    return Get.find<FavoritesService>().hasSeries(series.id);
  }

  Future<void> downloadFocusedVodFilm() async {
    final vod = focusedVodContentItem;
    if (vod == null) return;
    await Get.find<DownloadService>().enqueueFilm(vod);
  }

  String get focusedVodDownloadItemId {
    final vod = focusedVodContentItem;
    if (vod == null) return '';
    return 'vod_${vod.id}';
  }

  Future<void> openFocusedTrailer() async {
    if (vodFocusedTrailers.isEmpty) {
      await _loadVodTrailersForFocused();
    }
    if (vodFocusedTrailers.isEmpty) {
      Get.snackbar('', 'browse.vod.trailerMissing'.tr);
      return;
    }
    final uri = Uri.tryParse(vodFocusedTrailers.first.watchUrl);
    if (uri == null) {
      Get.snackbar('', 'browse.vod.trailerOpenFail'.tr);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      Get.snackbar('', 'browse.vod.trailerOpenFail'.tr);
    }
  }

  Future<void> _loadVodTrailersForFocused() async {
    final vod = focusedVodContentItem;
    if (vod == null) return;
    if (_vodTrailersVodId == vod.id && vodFocusedTrailers.isNotEmpty) return;
    if (!Get.isRegistered<MovieService>()) return;
    final gen = ++_vodTrailersLoadGen;
    vodTrailersLoading.value = true;
    try {
      final ms = Get.find<MovieService>();
      final list = await ms.fetchTrailers(
        name: vod.name,
        isSeries: false,
        xtreamTrailerUrl: vod.trailerUrl,
      );
      if (gen != _vodTrailersLoadGen || focusedVodContentItem?.id != vod.id) {
        return;
      }
      final seen = <String>{};
      vodFocusedTrailers.assignAll([
        for (final t in list)
          if (seen.add(t.youtubeVideoId ?? t.watchUrl)) t,
      ]);
      _vodTrailersVodId = vod.id;
    } catch (_) {
      if (gen == _vodTrailersLoadGen) vodFocusedTrailers.clear();
    } finally {
      if (gen == _vodTrailersLoadGen) vodTrailersLoading.value = false;
    }
  }

  String? _vodCategoryName(int? categoryId) {
    final isSeries = _isSeriesSection;
    if (categoryId == null || categoryId == kAllCategories) {
      return isSeries
          ? 'tvShell.category.allSeries'.tr
          : 'tvShell.category.allFilms'.tr;
    }
    if (isSeries) {
      final virtual = switch (categoryId) {
        kFavSeriesCategory => 'tvShell.category.favSeries'.tr,
        kRecentSeriesCategory => 'recommendedFilms.last50Series'.tr,
        kTvShellTop50SeriesCategory => 'tvShell.category.popular50Series'.tr,
        _ => null,
      };
      if (virtual != null) return virtual;
      final d = data;
      if (d == null) return null;
      for (final c in d.seriesCategories) {
        if (c.id == categoryId) return c.name;
      }
      return null;
    }
    final virtual = switch (categoryId) {
      kFavVodCategory => 'tvShell.category.favFilms'.tr,
      kRecentVodCategory => 'recommendedFilms.last50Films'.tr,
      kTvShellTop50VodCategory => 'tvShell.category.popular50Films'.tr,
      _ => null,
    };
    if (virtual != null) return virtual;
    final d = data;
    if (d == null) return null;
    for (final c in d.vodCategories) {
      if (c.id == categoryId) return c.name;
    }
    return null;
  }

  bool _isVirtualVodCategory(int? categoryId, {required bool films}) {
    if (categoryId == null) return false;
    if (films) {
      return categoryId == kFavVodCategory ||
          categoryId == kRecentVodCategory ||
          categoryId == kTvShellTop50VodCategory;
    }
    return categoryId == kFavSeriesCategory ||
        categoryId == kRecentSeriesCategory ||
        categoryId == kTvShellTop50SeriesCategory;
  }

  int? _resolveVodCategoryFilter(int? categoryId) {
    if (categoryId == null || categoryId == kAllCategories) return null;
    if (_isVirtualVodCategory(
      categoryId,
      films: selectedSection.value == TvShellSection.movies,
    )) {
      return null;
    }
    return categoryId;
  }

  bool _vodCategoryFitsOneShot(int? categoryId) =>
      categoryId == kRecentVodCategory ||
      categoryId == kTvShellTop50VodCategory;

  bool _seriesCategoryFitsOneShot(int? categoryId) =>
      categoryId == kRecentSeriesCategory ||
      categoryId == kTvShellTop50SeriesCategory;

  Future<void> _loadVodPreview(int? categoryId) async {
    final gen = ++_vodLoadGen;
    _vodPreviewCategoryKey = categoryId;
    _vodPreviewNextOffset = 0;
    _vodPreviewHasMore = false;
    if (_vodMemPoolCategoryKey != categoryId) {
      _vodMemPool = null;
      _vodMemPoolCategoryKey = null;
    }
    final page = await _fetchVodPage(
      categoryId: categoryId,
      offset: 0,
      limit: _vodPreviewPageSize,
    );
    if (gen != _vodLoadGen) return;
    _vodPreviewItems = page.items;
    _vodPreviewNextOffset = page.items.length;
    _vodPreviewHasMore = page.hasMore;
    vodFocusedIndex.value = 0;
    vodItemsRevision.value++;
    if (page.items.isNotEmpty) {
      _scheduleVodOmdb(page.items.first);
      unawaited(
        RecommendedFilmsRatingCache.enrichRatings(page.items, limit: 20),
      );
    } else {
      vodOmdbDetail.value = null;
    vodOmdbItemId.value = 0;
      vodOmdbLoading.value = false;
    }
  }

  Future<void> _loadVodContent(int? categoryId) async {
    final gen = ++_vodLoadGen;
    _vodContentListCategoryKey = categoryId;
    _vodContentNextOffset = 0;
    _vodContentHasMore = false;
    if (_vodMemPoolCategoryKey != categoryId) {
      _vodMemPool = null;
      _vodMemPoolCategoryKey = null;
    }
    final page = await _fetchVodPage(
      categoryId: categoryId,
      offset: 0,
      limit: _vodContentPageSize,
    );
    if (gen != _vodLoadGen) return;
    _vodContentSource = page.items;
    _vodContentNextOffset = page.items.length;
    _vodContentHasMore = page.hasMore;
    _applyVodSort();
    vodFocusedIndex.value = 0;
    vodItemsRevision.value++;
    if (page.items.isNotEmpty) {
      _scheduleVodOmdb(page.items.first);
      unawaited(
        RecommendedFilmsRatingCache.enrichRatings(page.items, limit: 28),
      );
    }
  }

  Future<void> _maybeLoadMoreVodAtIndex(int index, {bool force = false}) async {
    final isContent = phase.value == TvShellPhase.vodContent;
    final items = isContent ? _vodContentItems : _vodPreviewItems;
    if (items.isEmpty) return;
    final hasMore = isContent ? _vodContentHasMore : _vodPreviewHasMore;
    if (!hasMore) return;
    final loadingMore =
        isContent ? _vodContentLoadingMore : _vodPreviewLoadingMore;
    if (loadingMore) return;
    if (!force &&
        index < items.length - _vodLoadMoreLead) {
      return;
    }
    if (isContent) {
      if (_vodContentSource.length >= _vodMaxContentItems) {
        _vodContentHasMore = false;
        return;
      }
      await _appendVodContentPage();
    } else {
      await _appendVodPreviewPage();
    }
  }

  Future<void> _appendVodPreviewPage() async {
    if (!_vodPreviewHasMore || _vodPreviewLoadingMore) return;
    final categoryId = _vodPreviewCategoryKey;
    if (categoryId == null) return;
    _vodPreviewLoadingMore = true;
    final gen = _vodLoadGen;
    try {
      final page = await _fetchVodPage(
        categoryId: categoryId,
        offset: _vodPreviewNextOffset,
        limit: _vodPreviewPageSize,
      );
      if (gen != _vodLoadGen) return;
      if (page.items.isEmpty) {
        _vodPreviewHasMore = false;
        return;
      }
      _vodPreviewItems = [..._vodPreviewItems, ...page.items];
      _vodPreviewNextOffset += page.items.length;
      _vodPreviewHasMore = page.hasMore;
      vodItemsRevision.value++;
      unawaited(
        RecommendedFilmsRatingCache.enrichRatings(page.items, limit: 16),
      );
    } finally {
      _vodPreviewLoadingMore = false;
    }
  }

  Future<void> _appendVodContentPage() async {
    if (!_vodContentHasMore || _vodContentLoadingMore) return;
    final categoryId = _vodContentListCategoryKey;
    if (categoryId == null) return;
    if (_vodContentSource.length >= _vodMaxContentItems) {
      _vodContentHasMore = false;
      return;
    }
    _vodContentLoadingMore = true;
    final gen = _vodLoadGen;
    try {
      final page = await _fetchVodPage(
        categoryId: categoryId,
        offset: _vodContentNextOffset,
        limit: _vodContentPageSize,
      );
      if (gen != _vodLoadGen) return;
      if (page.items.isEmpty) {
        _vodContentHasMore = false;
        return;
      }
      _vodContentSource = [..._vodContentSource, ...page.items];
      _vodContentNextOffset += page.items.length;
      _vodContentHasMore =
          page.hasMore &&
          _vodContentSource.length < _vodMaxContentItems;
      _applyVodSort();
      vodItemsRevision.value++;
      unawaited(
        RecommendedFilmsRatingCache.enrichRatings(page.items, limit: 20),
      );
    } finally {
      _vodContentLoadingMore = false;
    }
  }

  Future<({List<VodItem> items, bool hasMore})> _fetchVodPage({
    required int? categoryId,
    required int offset,
    required int limit,
  }) async {
    final d = data;
    if (d == null) return (items: const <VodItem>[], hasMore: false);
    final ds = Get.isRegistered<PlaylistDataSource>()
        ? Get.find<PlaylistDataSource>()
        : null;

    if (_vodCategoryFitsOneShot(categoryId) && offset == 0) {
      final all = switch (categoryId) {
        kRecentVodCategory => await _fetchLast50VodItems(d, ds),
        kTvShellTop50VodCategory => await _fetchTop50VodItems(d, ds),
        _ => const <VodItem>[],
      };
      return (items: all, hasMore: false);
    }

    if (categoryId == kFavVodCategory) {
      return _fetchFavoriteVodPage(d, ds, offset: offset, limit: limit);
    }

    final filter = _resolveVodCategoryFilter(categoryId);
    if (ds != null && ds.isDbBacked) {
      final raw = await ds.vodPage(
        categoryId: filter,
        offset: offset,
        limit: limit,
      );
      return (items: raw, hasMore: raw.length >= limit);
    }

    final pool = _vodMemPoolFor(d, categoryId);
    final slice = pool.skip(offset).take(limit).toList();
    return (
      items: slice,
      hasMore: offset + slice.length < pool.length,
    );
  }

  List<VodItem> _vodMemPoolFor(M3uResult d, int? categoryId) {
    if (_vodMemPoolCategoryKey == categoryId && _vodMemPool != null) {
      return _vodMemPool!;
    }
    final filter = _resolveVodCategoryFilter(categoryId);
    final visible = FilmDiziCatalog.visibleVods(d);
    final pool = filter == null
        ? visible
        : visible.where((v) => v.categoryId == filter).toList();
    _vodMemPool = pool;
    _vodMemPoolCategoryKey = categoryId;
    return pool;
  }

  Future<({List<VodItem> items, bool hasMore})> _fetchFavoriteVodPage(
    M3uResult d,
    PlaylistDataSource? ds, {
    required int offset,
    required int limit,
  }) async {
    if (ds != null && ds.isDbBacked) {
      final fav = Get.find<FavoritesService>();
      final ids = fav.vodIds;
      if (offset >= ids.length) {
        return (items: const <VodItem>[], hasMore: false);
      }
      final chunk = ids.skip(offset).take(limit);
      final out = <VodItem>[];
      for (final id in chunk) {
        final v = await ds.vodById(id);
        if (v != null) out.add(v);
      }
      final next = offset + limit;
      return (items: out, hasMore: next < ids.length);
    }
    final all = FilmDiziCatalog.favoriteFilms(d);
    final slice = all.skip(offset).take(limit).toList();
    return (
      items: slice,
      hasMore: offset + slice.length < all.length,
    );
  }

  Future<List<VodItem>> _fetchLast50VodItems(
    M3uResult d,
    PlaylistDataSource? ds,
  ) async {
    if (ds != null && ds.isDbBacked) {
      return FilmDiziCatalog.last50FilmsFromDb(d, ds);
    }
    return FilmDiziCatalog.last50Films(d);
  }

  Future<List<VodItem>> _fetchTop50VodItems(
    M3uResult d,
    PlaylistDataSource? ds,
  ) async {
    var items = RecommendedFilmsCatalog.allItemsForCategory(
      d,
      RecommendedFilmsCategory.topRated,
    );
    if (items.isEmpty && ds != null) {
      items = await ds.vodPage(limit: 360);
      items.sort(
        (a, b) => RecommendedFilmsRatingCache.effectiveRating(b)
            .compareTo(RecommendedFilmsRatingCache.effectiveRating(a)),
      );
    }
    final top = items.take(FilmDiziCatalog.last50Limit).toList();
    unawaited(RecommendedFilmsRatingCache.enrichRatings(top, limit: 50));
    return top;
  }

  void _scheduleVodOmdb(VodItem vod) {
    _vodOmdbDebounce?.cancel();
    if (vodOmdbItemId.value != vod.id) {
      vodOmdbDetail.value = null;
      vodXtreamFields.value = null;
      vodOmdbItemId.value = vod.id;
    }
    _vodOmdbDebounce = Timer(const Duration(milliseconds: 350), () {
      if (vodOmdbItemId.value != vod.id) return;
      vodOmdbLoading.value = true;
      unawaited(_fetchVodOmdb(vod));
    });
  }

  Future<void> _loadSeriesPreview(int? categoryId) async {
    final gen = ++_vodLoadGen;
    _seriesPreviewCategoryKey = categoryId;
    _seriesPreviewNextOffset = 0;
    _seriesPreviewHasMore = false;
    if (_seriesMemPoolCategoryKey != categoryId) {
      _seriesMemGroupedPool = null;
      _seriesMemPoolCategoryKey = null;
    }
    final page = await _fetchSeriesPage(
      categoryId: categoryId,
      offset: 0,
      limit: _vodPreviewPageSize,
    );
    if (gen != _vodLoadGen) return;
    _seriesPreviewItems = page.items;
    _seriesPreviewNextOffset = page.items.length;
    _seriesPreviewHasMore = page.hasMore;
    vodFocusedIndex.value = 0;
    vodItemsRevision.value++;
    if (page.items.isNotEmpty) {
      _scheduleSeriesOmdb(page.items.first);
    } else {
      vodOmdbDetail.value = null;
    vodOmdbItemId.value = 0;
      vodOmdbLoading.value = false;
    }
  }

  Future<void> _loadSeriesContent(int? categoryId) async {
    final gen = ++_vodLoadGen;
    _seriesContentListCategoryKey = categoryId;
    _seriesContentNextOffset = 0;
    _seriesContentHasMore = false;
    if (_seriesMemPoolCategoryKey != categoryId) {
      _seriesMemGroupedPool = null;
      _seriesMemPoolCategoryKey = null;
    }
    final page = await _fetchSeriesPage(
      categoryId: categoryId,
      offset: 0,
      limit: _vodContentPageSize,
    );
    if (gen != _vodLoadGen) return;
    _seriesContentSource = page.items;
    _seriesContentNextOffset = page.items.length;
    _seriesContentHasMore = page.hasMore;
    _applySeriesSort();
    vodFocusedIndex.value = 0;
    vodItemsRevision.value++;
    if (page.items.isNotEmpty) {
      _scheduleSeriesOmdb(page.items.first);
    } else {
      vodOmdbDetail.value = null;
    vodOmdbItemId.value = 0;
      vodOmdbLoading.value = false;
    }
  }

  Future<void> _maybeLoadMoreSeriesAtIndex(int index, {bool force = false}) async {
    final isContent = phase.value == TvShellPhase.vodContent;
    final items = isContent ? _seriesContentItems : _seriesPreviewItems;
    if (items.isEmpty) return;
    final hasMore = isContent ? _seriesContentHasMore : _seriesPreviewHasMore;
    if (!hasMore) return;
    final loadingMore =
        isContent ? _seriesContentLoadingMore : _seriesPreviewLoadingMore;
    if (loadingMore) return;
    if (!force &&
        index < items.length - _vodLoadMoreLead) {
      return;
    }
    if (isContent) {
      if (_seriesContentSource.length >= _vodMaxContentItems) {
        _seriesContentHasMore = false;
        return;
      }
      await _appendSeriesContentPage();
    } else {
      await _appendSeriesPreviewPage();
    }
  }

  Future<void> _appendSeriesPreviewPage() async {
    if (!_seriesPreviewHasMore || _seriesPreviewLoadingMore) return;
    final categoryId = _seriesPreviewCategoryKey;
    if (categoryId == null) return;
    _seriesPreviewLoadingMore = true;
    final gen = _vodLoadGen;
    try {
      final page = await _fetchSeriesPage(
        categoryId: categoryId,
        offset: _seriesPreviewNextOffset,
        limit: _vodPreviewPageSize,
      );
      if (gen != _vodLoadGen) return;
      if (page.items.isEmpty) {
        _seriesPreviewHasMore = false;
        return;
      }
      _seriesPreviewItems = [..._seriesPreviewItems, ...page.items];
      _seriesPreviewNextOffset += page.items.length;
      _seriesPreviewHasMore = page.hasMore;
      vodItemsRevision.value++;
    } finally {
      _seriesPreviewLoadingMore = false;
    }
  }

  Future<void> _appendSeriesContentPage() async {
    if (!_seriesContentHasMore || _seriesContentLoadingMore) return;
    final categoryId = _seriesContentListCategoryKey;
    if (categoryId == null) return;
    if (_seriesContentSource.length >= _vodMaxContentItems) {
      _seriesContentHasMore = false;
      return;
    }
    _seriesContentLoadingMore = true;
    final gen = _vodLoadGen;
    try {
      final page = await _fetchSeriesPage(
        categoryId: categoryId,
        offset: _seriesContentNextOffset,
        limit: _vodContentPageSize,
      );
      if (gen != _vodLoadGen) return;
      if (page.items.isEmpty) {
        _seriesContentHasMore = false;
        return;
      }
      _seriesContentSource = [..._seriesContentSource, ...page.items];
      _seriesContentNextOffset += page.items.length;
      _seriesContentHasMore =
          page.hasMore &&
          _seriesContentSource.length < _vodMaxContentItems;
      _applySeriesSort();
      vodItemsRevision.value++;
    } finally {
      _seriesContentLoadingMore = false;
    }
  }

  Future<({List<SeriesItem> items, bool hasMore})> _fetchSeriesPage({
    required int? categoryId,
    required int offset,
    required int limit,
  }) async {
    final d = data;
    if (d == null) return (items: const <SeriesItem>[], hasMore: false);
    final ds = Get.isRegistered<PlaylistDataSource>()
        ? Get.find<PlaylistDataSource>()
        : null;

    if (_seriesCategoryFitsOneShot(categoryId) && offset == 0) {
      final all = switch (categoryId) {
        kRecentSeriesCategory => await _fetchLast50SeriesItems(d, ds),
        kTvShellTop50SeriesCategory => await _fetchTop50SeriesItems(d, ds),
        _ => const <SeriesItem>[],
      };
      return (items: all, hasMore: false);
    }

    if (categoryId == kFavSeriesCategory) {
      return _fetchFavoriteSeriesPage(d, ds, offset: offset, limit: limit);
    }

    final filter = _resolveVodCategoryFilter(categoryId);
    if (ds != null && ds.isDbBacked) {
      final raw = await ds.seriesPage(
        categoryId: filter,
        offset: offset,
        limit: limit,
      );
      return (items: raw, hasMore: raw.length >= limit);
    }

    final pool = _seriesMemGroupedPoolFor(d, categoryId);
    final slice = pool.skip(offset).take(limit).toList();
    return (
      items: slice,
      hasMore: offset + slice.length < pool.length,
    );
  }

  List<SeriesItem> _seriesMemGroupedPoolFor(M3uResult d, int? categoryId) {
    if (_seriesMemPoolCategoryKey == categoryId &&
        _seriesMemGroupedPool != null) {
      return _seriesMemGroupedPool!;
    }
    final filter = _resolveVodCategoryFilter(categoryId);
    final visible = FilmDiziCatalog.visibleSeries(d);
    final raw = filter == null
        ? visible
        : visible.where((s) => s.categoryId == filter).toList();
    final groups = SeriesNameGrouping.group(raw);
    final pool = groups.map(SeriesNameGrouping.representative).toList();
    _seriesMemGroupedPool = pool;
    _seriesMemPoolCategoryKey = categoryId;
    return pool;
  }

  Future<({List<SeriesItem> items, bool hasMore})> _fetchFavoriteSeriesPage(
    M3uResult d,
    PlaylistDataSource? ds, {
    required int offset,
    required int limit,
  }) async {
    if (ds != null && ds.isDbBacked) {
      final fav = Get.find<FavoritesService>();
      final ids = fav.seriesIds;
      if (offset >= ids.length) {
        return (items: const <SeriesItem>[], hasMore: false);
      }
      final chunk = ids.skip(offset).take(limit);
      final out = <SeriesItem>[];
      for (final id in chunk) {
        final s = await ds.seriesById(id);
        if (s != null) out.add(s);
      }
      final next = offset + limit;
      return (items: out, hasMore: next < ids.length);
    }
    final all = FilmDiziCatalog.favoriteSeries(d);
    final slice = all.skip(offset).take(limit).toList();
    return (
      items: slice,
      hasMore: offset + slice.length < all.length,
    );
  }

  Future<List<SeriesItem>> _fetchLast50SeriesItems(
    M3uResult d,
    PlaylistDataSource? ds,
  ) async {
    if (ds != null && ds.isDbBacked) {
      return FilmDiziCatalog.last50SeriesFromDb(d, ds);
    }
    return FilmDiziCatalog.last50Series(d);
  }

  Future<List<SeriesItem>> _fetchTop50SeriesItems(
    M3uResult d,
    PlaylistDataSource? ds,
  ) async {
    List<SeriesItem> pool;
    if (ds != null && ds.isDbBacked) {
      pool = await ds.seriesPage(limit: 600);
    } else {
      pool = FilmDiziCatalog.visibleSeries(d);
    }
    final top = _top50SeriesFromPool(pool);
    unawaited(RecommendedFilmsRatingCache.enrichRatings(
      top
          .map(
            (s) => VodItem(
              id: s.id,
              name: s.name,
              streamUrl: s.streamUrl ?? '',
              categoryId: s.categoryId,
              posterUrl: s.posterUrl,
            ),
          )
          .toList(),
      limit: 50,
    ));
    return top;
  }

  List<SeriesItem> _top50SeriesFromPool(List<SeriesItem> pool) {
    final groups = SeriesNameGrouping.group(pool);
    final reps = groups.map(SeriesNameGrouping.representative).toList();
    reps.sort((a, b) {
      final cmp = RecommendedFilmsRatingCache.ratingForContentId(b.id)
          .compareTo(RecommendedFilmsRatingCache.ratingForContentId(a.id));
      if (cmp != 0) return cmp;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return reps.take(FilmDiziCatalog.last50Limit).toList();
  }

  void _scheduleSeriesOmdb(SeriesItem series) {
    _vodOmdbDebounce?.cancel();
    if (vodOmdbItemId.value != series.id) {
      vodOmdbDetail.value = null;
      vodOmdbItemId.value = series.id;
    }
    _vodOmdbDebounce = Timer(const Duration(milliseconds: 350), () {
      if (vodOmdbItemId.value != series.id) return;
      vodOmdbLoading.value = true;
      unawaited(_fetchSeriesOmdb(series));
    });
  }

  Future<void> _fetchSeriesOmdb(SeriesItem series) async {
    if (!Get.isRegistered<MovieService>()) {
      vodOmdbLoading.value = false;
      return;
    }
    try {
      final xtream = seriesXtreamMeta.value;
      final result = await FilmDiziVodMetaLoader.loadSeries(
        series,
        xtreamPlot: xtream?.seriesPlot,
        xtreamGenre: xtream?.genre,
        xtreamRating: xtream?.imdbRating,
      );
      final items = phase.value == TvShellPhase.vodContent
          ? _seriesContentItems
          : _seriesPreviewItems;
      final idx = vodFocusedIndex.value;
      if (idx < 0 || idx >= items.length || items[idx].id != series.id) return;
      vodOmdbDetail.value = result;
    } catch (_) {
    } finally {
      final items = phase.value == TvShellPhase.vodContent
          ? _seriesContentItems
          : _seriesPreviewItems;
      final idx = vodFocusedIndex.value;
      if (idx >= 0 &&
          idx < items.length &&
          items[idx].id == series.id &&
          vodOmdbLoading.value) {
        vodOmdbLoading.value = false;
      }
    }
  }

  Future<void> _loadSeriesEpisodesForFocused() async {
    final series = focusedSeriesContentItem;
    if (series == null) return;
    if (_seriesEpisodesSeriesId == series.id && seriesEpisodes.isNotEmpty) {
      return;
    }
    final gen = ++_seriesEpisodesLoadGen;
    seriesEpisodesLoading.value = true;
    seriesEpisodes.clear();
    seriesSelectedSeason.value = null;
    seriesFocusedEpisodeIndex.value = 0;
    seriesXtreamMeta.value = null;
    try {
      final d = data;
      final args = FilmDiziSeriesDetailArgs.fromSeries(
        series,
        playlistData: d,
      );
      final loaded = await SeriesEpisodeLoader.load(
        series: args.series,
        playlist: Get.find<PlaylistRepository>(),
        playlistData: d,
        seriesCluster: args.seriesCluster,
        displayTitle: args.displayTitle,
      );
      if (gen != _seriesEpisodesLoadGen) return;
      if (focusedSeriesContentItem?.id != series.id) return;
      seriesEpisodes.assignAll(loaded.episodes);
      seriesXtreamMeta.value = loaded.xtreamMeta;
      _seriesEpisodesSeriesId = series.id;
      final seasons = seriesEpisodes.map((e) => e.season).toSet().toList()
        ..sort();
      if (seasons.isNotEmpty) {
        seriesSelectedSeason.value = seasons.first;
        seriesFocusedEpisodeIndex.value = 0;
      }
    } finally {
      if (gen == _seriesEpisodesLoadGen) {
        seriesEpisodesLoading.value = false;
      }
    }
  }

  Future<void> playFocusedSeriesEpisode() async {
    final ep = focusedSeriesEpisode;
    final series = focusedSeriesContentItem;
    if (ep == null || series == null) return;
    await openPlayerRoute(
      PlayerScreenArgs(
        channel: ep.channel,
        episodeBrowseTape: seriesEpisodesInSeason,
        playingSeriesInTape: series,
        audioCodecHint: ep.audioCodec,
      ),
    );
  }

  Future<void> _fetchVodOmdb(VodItem vod) async {
    if (!Get.isRegistered<MovieService>()) {
      vodOmdbLoading.value = false;
      return;
    }
    try {
      final loaded = await FilmDiziVodMetaLoader.load(vod);
      final items = phase.value == TvShellPhase.vodContent
          ? _vodContentItems
          : _vodPreviewItems;
      final idx = vodFocusedIndex.value;
      if (idx < 0 || idx >= items.length || items[idx].id != vod.id) return;
      vodXtreamFields.value = loaded.xtream;
      vodOmdbDetail.value = loaded.meta;
      unawaited(RecommendedFilmsRatingCache.enrichRatings([vod], limit: 1));
    } catch (_) {
    } finally {
      final items = phase.value == TvShellPhase.vodContent
          ? _vodContentItems
          : _vodPreviewItems;
      final idx = vodFocusedIndex.value;
      if (idx >= 0 &&
          idx < items.length &&
          items[idx].id == vod.id &&
          vodOmdbLoading.value) {
        vodOmdbLoading.value = false;
      }
    }
  }
}

// Browse sanal kategori sabitleri (browse_controller ile uyumlu).
const int kAllCategories = -7999;
const int kRecentVodCategory = -7998;
const int kRecentSeriesCategory = -7997;
const int kFavVodCategory = -7994;
const int kFavSeriesCategory = -7993;
const int kTvShellTop50VodCategory = -7992;
const int kTvShellTop50SeriesCategory = -7991;
