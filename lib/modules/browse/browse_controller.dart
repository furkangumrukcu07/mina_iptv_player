import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/error/app_exception.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/iptv_precache_service.dart';
import '../../core/services/playlist_cache_service.dart';
import 'package:better_player_plus/better_player_plus.dart';
import '../../core/player/better_player_iptv_config.dart';
import '../../core/player/iptv_playback_defaults.dart';
import '../../domain/entities/channel.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../domain/entities/vod.dart';
import 'browse_mode.dart';
import '../player/player_route_args.dart';
import '../../ui/glass_overlays.dart';

const int kAllCategories = -7999;

const int kFavAll = -8000;
const int kFavChannels = -8001;
const int kFavFilms = -8002;
const int kFavSeries = -8003;

/// Öğe üzerinde sabit kalınca (5 sn) önizleme başlar.
const Duration kBrowsePreviewFocusHoldDelay = Duration(seconds: 5);

class BrowseRow {
  const BrowseRow({
    required this.listIndex,
    required this.title,
    this.channel,
    this.vod,
    this.series,
  });

  final int listIndex;
  final String title;
  final Channel? channel;
  final VodItem? vod;
  final SeriesItem? series;

  String? get imageUrl =>
      channel?.logoUrl ?? vod?.posterUrl ?? series?.posterUrl;

  /// Xtream dizilerinde `streamUrl` yok; oynatma `get_series_info` ile çözülür.
  bool get canPlay => playerChannel != null || series != null;

  Channel? get playerChannel {
    final c = channel;
    if (c != null) return c;
    final v = vod;
    if (v != null) {
      return Channel(
        id: v.id,
        name: v.name,
        streamUrl: v.streamUrl,
        categoryId: v.categoryId,
        logoUrl: v.posterUrl,
      );
    }
    final s = series;
    if (s != null && s.streamUrl != null) {
      return Channel(
        id: s.id,
        name: s.name,
        streamUrl: s.streamUrl!,
        categoryId: s.categoryId,
        logoUrl: s.posterUrl,
      );
    }
    return null;
  }
}

class BrowseController extends GetxController {
  bool _effectiveRemoteNav() {
    final m = _app.layoutMode.value;
    if (m.usesRemoteNavigationStyle) return true;
    if (m != AppLayoutMode.mobile) return false;
    final ctx = Get.context;
    if (ctx == null) return false;
    final s = MediaQuery.sizeOf(ctx);
    return s.width >= s.height;
  }

  late final BrowseMode mode;

  final _cache = Get.find<PlaylistCacheService>();
  final _fav = Get.find<FavoritesService>();
  final _app = Get.find<AppSettingsService>();
  final _playlist = Get.find<PlaylistRepository>();

  final selectedCategoryKey = kAllCategories.obs;
  final searchQuery = ''.obs;
  final selectedRow = Rxn<BrowseRow>();

  final now = DateTime.now().obs;
  Timer? _clock;
  Timer? _precacheDebounce;
  Timer? _previewDebounce;

  final searchController = TextEditingController();

  final categoryFocusNode = FocusNode();
  final listFocusNode = FocusNode();

  /// TV üst çubuk: kumanda ile arama / ayarlar odakları.
  final browseBarSearchFocusNode = FocusNode(debugLabel: 'browseBarSearch');
  final browseBarSettingsFocusNode = FocusNode(debugLabel: 'browseBarSettings');

  /// TV yatay: kategori seçildikten sonra oklarla sol sütuna dönmesin; Geri ile kalkar.
  final tvTrapFocusInBrowseList = false.obs;

  /// TV: sağ ok ile açılmadan üçüncü (detay) sütun odak almasın.
  final tvBrowseDetailUnlocked = false.obs;

  final browseStaticDetailFocusNode =
      FocusNode(debugLabel: 'browseDetailStatic');
  final browseSeriesDetailFocusNode =
      FocusNode(debugLabel: 'browseDetailSeries');
  final browseStaticPreviewFocusNode =
      FocusNode(debugLabel: 'browsePreviewStatic');
  final browseSeriesPreviewFocusNode =
      FocusNode(debugLabel: 'browsePreviewSeries');
  final browseStaticPlayFocusNode = FocusNode(debugLabel: 'browsePlayStatic');
  final browseSeriesPlayFocusNode = FocusNode(debugLabel: 'browsePlaySeries');

  BetterPlayerController? previewController;
  final isPreviewLoading = false.obs;

  final seriesEpisodesLoading = false.obs;
  final seriesEpisodesError = ''.obs;
  final seriesEpisodeOptions = <SeriesEpisodeOption>[].obs;
  final selectedSeriesSeason = Rxn<int>();
  final selectedSeriesEpisode = Rxn<SeriesEpisodeOption>();

  M3uResult? _data;

  M3uResult? get snapshot => _data;

  String get screenTitle => switch (mode) {
        BrowseMode.films => 'browse.films'.tr,
        BrowseMode.series => 'browse.series'.tr,
        BrowseMode.favorites => 'browse.favorites'.tr,
      };

  String get searchHint => switch (mode) {
        BrowseMode.films => 'search.film'.tr,
        BrowseMode.series => 'search.series'.tr,
        BrowseMode.favorites => 'search.favorite'.tr,
      };

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    mode = arg is BrowseMode ? arg : BrowseMode.films;

    final value = _cache.result.value;
    if (value == null) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.playlist));
      return;
    }
    _data = value;
    listFocusNode.addListener(_onBrowseListFocusChanged);

    if (mode == BrowseMode.favorites) {
      selectedCategoryKey.value = kFavAll;
    } else {
      selectedCategoryKey.value = kAllCategories;
    }

    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      now.value = DateTime.now();
    });
    Future.microtask(_restoreLastSelection);
  }

  void _onBrowseListFocusChanged() {
    if (!listFocusNode.hasFocus) return;
    if (!_effectiveRemoteNav()) return;
    tvTrapFocusInBrowseList.value = true;
  }

  @override
  void onReady() {
    super.onReady();
    now.value = DateTime.now();
  }

  @override
  void onClose() {
    _clock?.cancel();
    _precacheDebounce?.cancel();
    _previewDebounce?.cancel();
    searchController.dispose();
    listFocusNode.removeListener(_onBrowseListFocusChanged);
    categoryFocusNode.dispose();
    listFocusNode.dispose();
    browseBarSearchFocusNode.dispose();
    browseBarSettingsFocusNode.dispose();
    browseStaticDetailFocusNode.dispose();
    browseSeriesDetailFocusNode.dispose();
    browseStaticPreviewFocusNode.dispose();
    browseSeriesPreviewFocusNode.dispose();
    browseStaticPlayFocusNode.dispose();
    browseSeriesPlayFocusNode.dispose();
    previewController?.dispose(forceDispose: true);
    super.onClose();
  }

  List<({int key, String name, int count})> get leftCategories {
    final d = _data!;
    return switch (mode) {
      BrowseMode.films => [
          (key: kAllCategories, name: 'Tüm filmler', count: d.vod.length),
          ...d.vodCategories.map(
            (c) => (
              key: c.id,
              name: c.name,
              count: d.vod.where((v) => v.categoryId == c.id).length,
            ),
          ),
        ],
      BrowseMode.series => [
          (key: kAllCategories, name: 'Tüm diziler', count: d.series.length),
          ...d.seriesCategories.map(
            (c) => (
              key: c.id,
              name: c.name,
              count: d.series.where((s) => s.categoryId == c.id).length,
            ),
          ),
        ],
      BrowseMode.favorites => [
          (key: kFavAll, name: 'Tümü', count: _fav.totalCount),
          (key: kFavChannels, name: 'Kanallar', count: _fav.channelIds.length),
          (key: kFavFilms, name: 'Filmler', count: _fav.vodIds.length),
          (key: kFavSeries, name: 'Diziler', count: _fav.seriesIds.length),
        ],
    };
  }

  bool categorySelected(int key) => selectedCategoryKey.value == key;

  void selectCategoryKey(int key, {bool moveFocus = false}) {
    tvBrowseDetailUnlocked.value = false;
    selectedCategoryKey.value = key;
    if (mode == BrowseMode.films) {
      unawaited(_app.setLastFilmsSelection(
        categoryKey: key,
      ));
    } else if (mode == BrowseMode.series) {
      unawaited(_app.setLastSeriesSelection(
        categoryKey: key,
      ));
    } else {
      unawaited(_app.setLastFavoritesSelection(
        categoryKey: key,
        selection: _app.lastFavoritesSelection.value,
      ));
    }
    _ensureSelection();
    if (moveFocus) {
      final list = filteredRows;
      if (list.isNotEmpty) {
        _applyBrowseRowSelection(list.first);
      }
      tvTrapFocusInBrowseList.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (listFocusNode.canRequestFocus) {
          listFocusNode.requestFocus();
        }
        _scheduleScrollBrowseListToFocusedRow();
      });
    }
  }

  void releaseTvBrowseListFocusToCategories() {
    tvTrapFocusInBrowseList.value = false;
    tvBrowseDetailUnlocked.value = false;
    final row = selectedRow.value;
    if (row != null && mode != BrowseMode.favorites) {
      if (row.vod != null) {
        selectedCategoryKey.value = row.vod!.categoryId;
        unawaited(_app.setLastFilmsSelection(
          categoryKey: row.vod!.categoryId,
          vodId: row.vod!.id,
        ));
      } else if (row.series != null) {
        selectedCategoryKey.value = row.series!.categoryId;
        unawaited(_app.setLastSeriesSelection(
          categoryKey: row.series!.categoryId,
          seriesId: row.series!.id,
        ));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (categoryFocusNode.canRequestFocus) {
        categoryFocusNode.requestFocus();
      }
    });
  }

  bool get tvBrowseThirdColumnIsSeriesPanel {
    final row = selectedRow.value;
    return row?.series != null &&
        (mode == BrowseMode.series || mode == BrowseMode.favorites);
  }

  void _pumpFocusToBrowsePreview() {
    if (!_effectiveRemoteNav()) return;
    if (!tvBrowseDetailUnlocked.value) return;
    listFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!tvBrowseDetailUnlocked.value) return;
      final node = tvBrowseThirdColumnIsSeriesPanel
          ? browseSeriesPreviewFocusNode
          : browseStaticPreviewFocusNode;
      if (node.canRequestFocus) {
        node.requestFocus();
      }
    });
  }

  /// Detay açıkken sağ ok: sadece önizleme odak (unlock tekrarlanmasın).
  void focusBrowseDetailPreview() {
    if (!_effectiveRemoteNav()) return;
    if (!tvBrowseDetailUnlocked.value) return;
    _pumpFocusToBrowsePreview();
  }

  void unlockBrowseDetailColumn() {
    tvBrowseDetailUnlocked.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pumpFocusToBrowsePreview();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pumpFocusToBrowsePreview();
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (!tvBrowseDetailUnlocked.value) return;
          final pv = tvBrowseThirdColumnIsSeriesPanel
              ? browseSeriesPreviewFocusNode
              : browseStaticPreviewFocusNode;
          if (!pv.hasFocus) {
            _pumpFocusToBrowsePreview();
          }
        });
      });
    });
  }

  /// TV Bölge D → C: üst çubuktan aşağı — detay/önizleme alanı (Kullanıcı isteği: kategorilere kayma).
  void focusTvDownFromTopBar() {
    if (!_effectiveRemoteNav()) return;
    tvTrapFocusInBrowseList.value = true;
    unlockBrowseDetailColumn();
  }

  /// TV Bölge B: orta liste içinde yalnızca dikey gezinme.
  void tvNudgeBrowseListRow(int delta) {
    if (!_effectiveRemoteNav()) return;
    if (delta == 0) return;
    final list = filteredRows;
    if (list.isEmpty) return;
    final cur = selectedRow.value;
    var i = 0;
    if (cur != null) {
      final idx = list.indexWhere((r) => _sameRow(r, cur));
      i = idx >= 0 ? idx : 0;
    }
    final next = (i + delta).clamp(0, list.length - 1);
    if (next == i) return;
    focusBrowseRow(list[next]);
  }

  void lockBrowseDetailColumn() {
    tvBrowseDetailUnlocked.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (listFocusNode.canRequestFocus) {
        listFocusNode.requestFocus();
      }
    });
  }

  /// Oynatıcıdan dönünce orta listeye sabitle; detayı kilitle.
  void restoreBrowseListFocusAfterPlayerPop() {
    tvTrapFocusInBrowseList.value = true;
    tvBrowseDetailUnlocked.value = false;

    void requestListFocus() {
      if (listFocusNode.canRequestFocus) {
        listFocusNode.requestFocus();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = listFocusNode.context;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.35,
          duration: Duration.zero,
          curve: Curves.linear,
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => requestListFocus());
    });
  }

  void onSearchChanged(String v) {
    searchQuery.value = v;
    _ensureSelection();
  }

  static bool _sameRow(BrowseRow a, BrowseRow b) {
    return a.channel?.id == b.channel?.id &&
        a.vod?.id == b.vod?.id &&
        a.series?.id == b.series?.id;
  }

  List<BrowseRow> get filteredRows {
    final d = _data!;
    final q = searchQuery.value.trim().toLowerCase();

    List<BrowseRow> numberRows(List<BrowseRow> raw) => [
          for (var i = 0; i < raw.length; i++)
            BrowseRow(
              listIndex: i + 1,
              title: raw[i].title,
              channel: raw[i].channel,
              vod: raw[i].vod,
              series: raw[i].series,
            ),
        ];

    if (mode == BrowseMode.films) {
      final key = selectedCategoryKey.value;
      var list = key == kAllCategories
          ? List<VodItem>.from(d.vod)
          : d.vod.where((v) => v.categoryId == key).toList();
      if (q.isNotEmpty) {
        list = list.where((v) => v.name.toLowerCase().contains(q)).toList();
      }
      return numberRows([
        for (final v in list) BrowseRow(listIndex: 0, title: v.name, vod: v),
      ]);
    }

    if (mode == BrowseMode.series) {
      final key = selectedCategoryKey.value;
      var list = key == kAllCategories
          ? List<SeriesItem>.from(d.series)
          : d.series.where((s) => s.categoryId == key).toList();
      if (q.isNotEmpty) {
        list = list.where((s) => s.name.toLowerCase().contains(q)).toList();
      }
      return numberRows([
        for (final s in list) BrowseRow(listIndex: 0, title: s.name, series: s),
      ]);
    }

    final fk = selectedCategoryKey.value;
    final raw = <BrowseRow>[];

    void tryChannel(int id) {
      final m = d.channels.where((e) => e.id == id);
      if (m.isEmpty) return;
      final c = m.first;
      if (q.isEmpty || c.name.toLowerCase().contains(q)) {
        raw.add(BrowseRow(listIndex: 0, title: c.name, channel: c));
      }
    }

    void tryVod(int id) {
      final m = d.vod.where((e) => e.id == id);
      if (m.isEmpty) return;
      final v = m.first;
      if (q.isEmpty || v.name.toLowerCase().contains(q)) {
        raw.add(BrowseRow(listIndex: 0, title: v.name, vod: v));
      }
    }

    void trySeries(int id) {
      final m = d.series.where((e) => e.id == id);
      if (m.isEmpty) return;
      final s = m.first;
      if (q.isEmpty || s.name.toLowerCase().contains(q)) {
        raw.add(BrowseRow(listIndex: 0, title: s.name, series: s));
      }
    }

    if (fk == kFavAll || fk == kFavChannels) {
      for (final id in _fav.channelIds) {
        tryChannel(id);
      }
    }
    if (fk == kFavAll || fk == kFavFilms) {
      for (final id in _fav.vodIds) {
        tryVod(id);
      }
    }
    if (fk == kFavAll || fk == kFavSeries) {
      for (final id in _fav.seriesIds) {
        trySeries(id);
      }
    }

    return numberRows(raw);
  }

  void _ensureSelection() {
    final list = filteredRows;
    if (list.isEmpty) {
      selectedRow.value = null;
      return;
    }
    final cur = selectedRow.value;
    if (cur == null) {
      selectedRow.value = list.first;
      return;
    }
    final still = list.where((r) => _sameRow(r, cur)).toList();
    if (still.isEmpty) {
      selectedRow.value = list.first;
    } else {
      selectedRow.value = still.first;
    }
  }

  /// TV: oklarla gezinirken seçimi güncelle; [selectRow] oynatıcı açmaz.
  void focusBrowseRow(BrowseRow row) {
    if (selectedRow.value != null && _sameRow(selectedRow.value!, row)) return;
    _applyBrowseRowSelection(row);
  }

  void _applyBrowseRowSelection(BrowseRow row) {
    selectedRow.value = row;
    if (mode == BrowseMode.films && row.vod != null) {
      unawaited(_app.setLastFilmsSelection(
        categoryKey: selectedCategoryKey.value,
        vodId: row.vod!.id,
      ));
    } else if (mode == BrowseMode.series && row.series != null) {
      unawaited(_app.setLastSeriesSelection(
        categoryKey: selectedCategoryKey.value,
        seriesId: row.series!.id,
      ));
    } else if (mode == BrowseMode.favorites) {
      final sel = row.channel != null
          ? 'ch:${row.channel!.id}'
          : row.vod != null
              ? 'vod:${row.vod!.id}'
              : row.series != null
                  ? 'ser:${row.series!.id}'
                  : '';
      unawaited(_app.setLastFavoritesSelection(
        categoryKey: selectedCategoryKey.value,
        selection: sel,
      ));
    }

    final seriesSide = row.series != null &&
        (mode == BrowseMode.series || mode == BrowseMode.favorites);
    if (seriesSide) {
      unawaited(_stopPreview());
      unawaited(_loadSeriesEpisodes(row.series!));
    } else {
      _clearSeriesEpisodes();
    }

    final ch = row.playerChannel;
    if (!seriesSide && ch != null) {
      _schedulePrecache(ch.streamUrl);
      _schedulePreview(ch);
    } else if (!seriesSide) {
      _stopPreview();
    }
    _reattachSharedListFocusAfterRebuild();
  }

  void selectRow(BrowseRow row) {
    if (_app.layoutMode.value == AppLayoutMode.tv) {
      if (!row.canPlay) return;
      _applyBrowseRowSelection(row);
      unawaited(openRowPlayer(row));
      return;
    }
    if (selectedRow.value != null && _sameRow(selectedRow.value!, row)) {
      unawaited(openRowPlayer(row));
      return;
    }
    _applyBrowseRowSelection(row);
  }

  void _reattachSharedListFocusAfterRebuild() {
    if (!_effectiveRemoteNav()) return;
    if (!tvTrapFocusInBrowseList.value) return;
    if (tvBrowseDetailUnlocked.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!listFocusNode.canRequestFocus) return;
      listFocusNode.requestFocus();
      _scheduleScrollBrowseListToFocusedRow();
    });
  }

  void _scheduleScrollBrowseListToFocusedRow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = listFocusNode.context;
        if (ctx == null || !ctx.mounted) return;
        Scrollable.ensureVisible(
          ctx,
          duration: Duration.zero,
          curve: Curves.linear,
          alignment: 0.22,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      });
    });
  }

  void _scheduleSeriesDetailPreview() {
    final ep = selectedSeriesEpisode.value;
    if (ep != null) {
      _schedulePrecache(ep.channel.streamUrl);
      _schedulePreview(ep.channel);
    } else {
      unawaited(_stopPreview());
    }
  }

  void _clearSeriesEpisodes() {
    seriesEpisodeOptions.clear();
    seriesEpisodesError.value = '';
    selectedSeriesSeason.value = null;
    selectedSeriesEpisode.value = null;
    seriesEpisodesLoading.value = false;
  }

  Future<void> _loadSeriesEpisodes(SeriesItem s) async {
    seriesEpisodesLoading.value = true;
    seriesEpisodesError.value = '';
    seriesEpisodeOptions.clear();
    selectedSeriesEpisode.value = null;
    selectedSeriesSeason.value = null;
    try {
      final list = await _playlist.resolveXtreamSeriesEpisodes(
        seriesId: s.id,
        seriesName: s.name,
        posterUrl: s.posterUrl,
        categoryId: s.categoryId,
      );
      if (list.isNotEmpty) {
        seriesEpisodeOptions.assignAll(list);
        final seasons = list.map((e) => e.season).toSet().toList()..sort();
        selectedSeriesSeason.value = seasons.isNotEmpty ? seasons.first : 1;
        final ss = selectedSeriesSeason.value ?? 1;
        SeriesEpisodeOption? pick;
        for (final e in list) {
          if (e.season == ss) {
            pick = e;
            break;
          }
        }
        selectedSeriesEpisode.value = pick ?? list.first;
      } else {
        final url = s.streamUrl?.trim();
        if (url != null && url.isNotEmpty) {
          final ch = Channel(
            id: s.id,
            name: s.name,
            streamUrl: url,
            categoryId: s.categoryId,
            logoUrl: s.posterUrl,
            sortOrder: 0,
          );
          final opt = SeriesEpisodeOption(
            channel: ch,
            season: 1,
            episodeNumber: 1,
            displayTitle: s.name,
          );
          seriesEpisodeOptions.add(opt);
          selectedSeriesSeason.value = 1;
          selectedSeriesEpisode.value = opt;
        } else {
          seriesEpisodesError.value = 'Bölüm listesi alınamadı.';
        }
      }
    } catch (_) {
      seriesEpisodesError.value = 'Bölümler yüklenemedi.';
    } finally {
      seriesEpisodesLoading.value = false;
      _scheduleSeriesDetailPreview();
    }
  }

  void selectSeriesSeason(int season) {
    selectedSeriesSeason.value = season;
    final list = seriesEpisodeOptions.where((e) => e.season == season).toList();
    if (list.isNotEmpty) {
      selectedSeriesEpisode.value = list.first;
    }
    _scheduleSeriesDetailPreview();
  }

  void selectSeriesEpisodeOption(SeriesEpisodeOption opt) {
    selectedSeriesEpisode.value = opt;
    selectedSeriesSeason.value = opt.season;
    _scheduleSeriesDetailPreview();
  }

  void _schedulePrecache(String streamUrl) {
    _precacheDebounce?.cancel();
    _precacheDebounce = Timer(const Duration(milliseconds: 1500), () {
      if (!Get.isRegistered<IptvPrecacheService>()) return;
      unawaited(Get.find<IptvPrecacheService>().precacheStreamUrl(streamUrl));
    });
  }

  void _schedulePreview(Channel channel) {
    _previewDebounce?.cancel();
    if (!_app.streamPreviewActive) {
      clearStreamPreview();
      return;
    }
    _previewDebounce = Timer(kBrowsePreviewFocusHoldDelay, () {
      if (!_app.streamPreviewActive) return;
      _startPreview(channel);
    });
  }

  void clearStreamPreview() {
    _previewDebounce?.cancel();
    _previewDebounce = null;
    try {
      final old = previewController;
      previewController = null;
      if (old != null) {
        old.pause();
        old.dispose(forceDispose: true);
      }
    } catch (_) {}
    isPreviewLoading.value = false;
    update(['preview']);
  }

  Future<void> _stopPreview() async {
    try {
      final old = previewController;
      previewController = null;
      if (old != null) {
        old.pause();
        old.dispose(forceDispose: true);
      }
      update(['preview']);
    } catch (_) {}
  }

  Future<void> _startPreview(Channel channel) async {
    if (!_app.streamPreviewActive) {
      clearStreamPreview();
      return;
    }
    await _stopPreview();

    isPreviewLoading.value = true;
    update(['preview']);

    try {
      final streamUrl =
          IptvPlaybackDefaults.normalizeStreamUrl(channel.streamUrl);
      if (streamUrl.isEmpty) {
        isPreviewLoading.value = false;
        update(['preview']);
        return;
      }

      final cfg = BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
        ),
        handleLifecycle: false,
        autoDispose: false,
        fullScreenByDefault: false,
        allowedScreenSleep: false,
      );

      final ds = iptvBetterPlayerDataSource(
        streamUrl,
        liveStream: IptvPlaybackDefaults.isLikelyLiveStream(streamUrl),
        preferSoftwareVideoDecoder:
            false, // VOD için her zaman donanım dekoderi
        useAsmsAudioTracks: null, // Otomatik seçime (Adaptive tespiti) bırak
      );

      final ctrl = BetterPlayerController(cfg);
      await ctrl.setupDataSource(ds);
      ctrl.setVolume(0);
      previewController = ctrl;
      isPreviewLoading.value = false;
      update(['preview']);
    } catch (e) {
      isPreviewLoading.value = false;
      update(['preview']);
    }
  }

  bool rowSelected(BrowseRow row) {
    final cur = selectedRow.value;
    if (cur == null) return false;
    return _sameRow(row, cur);
  }

  bool isFavorite(BrowseRow row) {
    if (row.channel != null) return _fav.hasChannel(row.channel!.id);
    if (row.vod != null) return _fav.hasVod(row.vod!.id);
    if (row.series != null) return _fav.hasSeries(row.series!.id);
    return false;
  }

  void toggleFavorite(BrowseRow row) {
    if (row.channel != null) {
      _fav.toggleChannel(row.channel!.id);
    } else if (row.vod != null) {
      _fav.toggleVod(row.vod!.id);
    } else if (row.series != null) {
      _fav.toggleSeries(row.series!.id);
    }
    if (mode == BrowseMode.favorites) {
      Future.microtask(_ensureSelection);
    }
  }

  void _restoreLastSelection() {
    final d = _data;
    if (d == null) {
      _ensureSelection();
      return;
    }

    if (mode == BrowseMode.films) {
      final cat = _app.lastFilmsCategoryKey.value;
      final vodId = _app.lastFilmsVodId.value;
      if (cat != null) {
        selectedCategoryKey.value = cat;
      }
      if (vodId != null && vodId > 0) {
        VodItem? found;
        for (final v in d.vod) {
          if (v.id == vodId) {
            found = v;
            break;
          }
        }
        if (found != null) {
          selectedCategoryKey.value = cat ?? found.categoryId;
          final row = BrowseRow(listIndex: 0, title: found.name, vod: found);
          if (_app.layoutMode.value == AppLayoutMode.tv) {
            _applyBrowseRowSelection(row);
          } else {
            selectRow(row);
          }
          return;
        }
      }
      _ensureSelection();
      return;
    }

    if (mode == BrowseMode.series) {
      final cat = _app.lastSeriesCategoryKey.value;
      final sid = _app.lastSeriesId.value;
      if (cat != null) {
        selectedCategoryKey.value = cat;
      }
      if (sid != null && sid > 0) {
        SeriesItem? found;
        for (final s in d.series) {
          if (s.id == sid) {
            found = s;
            break;
          }
        }
        if (found != null) {
          selectedCategoryKey.value = cat ?? found.categoryId;
          final row = BrowseRow(listIndex: 0, title: found.name, series: found);
          if (_app.layoutMode.value == AppLayoutMode.tv) {
            _applyBrowseRowSelection(row);
          } else {
            selectRow(row);
          }
          return;
        }
      }
      _ensureSelection();
      return;
    }

    final cat = _app.lastFavoritesCategoryKey.value;
    final sel = _app.lastFavoritesSelection.value;
    if (cat != null) {
      selectedCategoryKey.value = cat;
    }
    if (sel.isNotEmpty) {
      final parts = sel.split(':');
      if (parts.length == 2) {
        final kind = parts[0];
        final id = int.tryParse(parts[1]);
        if (id != null) {
          if (kind == 'ch') {
            for (final c in d.channels) {
              if (c.id == id) {
                final row = BrowseRow(listIndex: 0, title: c.name, channel: c);
                if (_app.layoutMode.value == AppLayoutMode.tv) {
                  _applyBrowseRowSelection(row);
                } else {
                  selectRow(row);
                }
                return;
              }
            }
          } else if (kind == 'vod') {
            for (final v in d.vod) {
              if (v.id == id) {
                final row = BrowseRow(listIndex: 0, title: v.name, vod: v);
                if (_app.layoutMode.value == AppLayoutMode.tv) {
                  _applyBrowseRowSelection(row);
                } else {
                  selectRow(row);
                }
                return;
              }
            }
          } else if (kind == 'ser') {
            for (final s in d.series) {
              if (s.id == id) {
                final row = BrowseRow(listIndex: 0, title: s.name, series: s);
                if (_app.layoutMode.value == AppLayoutMode.tv) {
                  _applyBrowseRowSelection(row);
                } else {
                  selectRow(row);
                }
                return;
              }
            }
          }
        }
      }
    }

    _ensureSelection();
  }

  Future<void> openSelectedPlayer() async {
    final row = selectedRow.value;
    if (row == null) return;
    final seriesSide = row.series != null &&
        (mode == BrowseMode.series || mode == BrowseMode.favorites);
    if (seriesSide) {
      final ep = selectedSeriesEpisode.value ??
          (seriesEpisodeOptions.isNotEmpty ? seriesEpisodeOptions.first : null);
      if (ep != null) {
        _previewDebounce?.cancel();
        await _stopPreview();
        _openPlayerRoute(selectedRow.value!, ep.channel);
        return;
      }
    }
    await openRowPlayer(row);
  }

  Future<void> openRowPlayer(BrowseRow row) async {
    var ch = row.playerChannel;
    if (ch == null && row.series != null) {
      Get.dialog(
        Center(
          child: GlassPopupPanel(
            padding: const EdgeInsets.all(28),
            child: const CircularProgressIndicator(),
          ),
        ),
        barrierDismissible: false,
        barrierColor: Colors.black54,
      );
      try {
        ch = await _playlist.resolveXtreamSeriesFirstEpisode(
          seriesId: row.series!.id,
          seriesName: row.series!.name,
          posterUrl: row.series!.posterUrl,
          categoryId: row.series!.categoryId,
        );
      } on AppException catch (e) {
        if (Get.isDialogOpen == true) Get.back();
        GlassSnackbar.show(
          'Dizi',
          e.message,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      } catch (_) {
        if (Get.isDialogOpen == true) Get.back();
        GlassSnackbar.show(
          'Dizi',
          'Bölümler yüklenemedi.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      if (Get.isDialogOpen == true) Get.back();
      if (ch == null) {
        GlassSnackbar.show(
          'Dizi',
          'Bölüm bulunamadı veya kaynak Xtream değil.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    } else if (ch == null) {
      return;
    }
    _previewDebounce?.cancel();
    await _stopPreview();
    _openPlayerRoute(row, ch);
  }

  /// TV’de liste odak düğümü üst rotada kalmasın (kanallar ekranı ile aynı düzeltme).
  void _openPlayerRoute(BrowseRow contextRow, Channel ch) {
    List<Channel>? movieTape;
    List<SeriesItem>? seriesTape;
    SeriesItem? playingSeries;

    if (mode == BrowseMode.films && contextRow.vod != null) {
      movieTape = [
        for (final r in filteredRows)
          if (r.vod != null && r.playerChannel != null) r.playerChannel!,
      ];
    } else if (mode == BrowseMode.series && contextRow.series != null) {
      seriesTape = [
        for (final r in filteredRows)
          if (r.series != null) r.series!,
      ];
      playingSeries = contextRow.series;
    } else if (mode == BrowseMode.favorites) {
      if (contextRow.vod != null) {
        movieTape = [
          for (final r in filteredRows)
            if (r.vod != null && r.playerChannel != null) r.playerChannel!,
        ];
      } else if (contextRow.series != null) {
        seriesTape = [
          for (final r in filteredRows)
            if (r.series != null) r.series!,
        ];
        playingSeries = contextRow.series;
      }
    }

    final args = PlayerScreenArgs(
      channel: ch,
      movieBrowseTape: movieTape,
      seriesBrowseTape: seriesTape,
      playingSeriesInTape: playingSeries,
    );

    FocusManager.instance.primaryFocus?.unfocus();
    Future<void>.microtask(
      () => Get.toNamed(AppRoutes.player, arguments: args),
    );
  }

  void changePlaylist() {
    Get.offNamed(AppRoutes.playlist);
  }

  void goBack() => Get.back();

  /// TV: üst çubuk geri — kategori tuzağındaysa önce sol sütuna dön.
  void onTopBarBack() {
    if (_effectiveRemoteNav() && tvTrapFocusInBrowseList.value) {
      releaseTvBrowseListFocusToCategories();
    } else {
      goBack();
    }
  }
}
