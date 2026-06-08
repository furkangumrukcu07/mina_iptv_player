import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/error/app_exception.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/perf/browse_catalog_index.dart';
import '../../core/perf/browse_films_filter_isolate.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/iptv_precache_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/playlist_category_hide.dart';
import '../../core/utils/adult_content_filter.dart';
import '../../core/services/movie_service.dart';
import '../../core/utils/imdb_from_url.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/entities/movie_model.dart';
import 'package:better_player_plus/better_player_plus.dart';
import '../../core/player/better_player_iptv_config.dart';
import '../../core/player/iptv_playback_defaults.dart';
import '../../domain/entities/channel.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../ui/glass_tv_shell.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/vod.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../data/local/vod_xtream_info_cache_store.dart';
import '../../services/user_history_service.dart';
import 'browse_mode.dart';
import '../player/player_route_args.dart';
import '../../ui/glass_overlays.dart';

const int kAllCategories = -7999;
const int kRecentVodCategory = -7998;
const int kRecentSeriesCategory = -7997;

/// Kullanıcının izleme geçmişinden derlenen, ana ekrandaki Filmler kartının
/// içinde "Tümü"nün hemen altında listelenen sanal kategori. Geçmişte film
/// (VOD) varsa görünür; aksi hâlde gizlenir.
const int kWatchedVodCategory = -7996;

/// Aynı yapı diziler için.
const int kWatchedSeriesCategory = -7995;

/// Browse (Filmler/Diziler) içinde "Favoriler" sanal kategorisi: kullanıcının
/// favorilerine eklediği film/diziler. "Son eklenenler"in hemen altında görünür;
/// favori yoksa gizlenir.
const int kFavVodCategory = -7994;
const int kFavSeriesCategory = -7993;

const int kFavAll = -8000;
const int kFavChannels = -8001;
const int kFavFilms = -8002;
const int kFavSeries = -8003;

/// Öğe üzerinde sabit kalınca (2 sn) önizleme başlar.
const Duration kBrowsePreviewFocusHoldDelay = Duration(seconds: 2);

/// Bazı paneller `get_series` içinde her bölümü ayrı `series_id` ile listeler (`… S01-E01`).
/// [get_series_info] o zaman tek bölüm döner; liste ile detayı hizalamak için dizi kök adı gerekir.
String? _seriesBaseTitleIfEpisodeStyled(String name) {
  final t = _collapseSeriesTitleSpaces(name.trim());
  if (t.isEmpty) return null;
  final stripped = _stripTrailingSeriesEpisodeMarkers(t);
  if (stripped.isEmpty || stripped == t) return null;
  return stripped;
}

bool _seriesSameMergedShow(SeriesItem o, String baseLower, int categoryId) {
  if (o.categoryId != categoryId) return false;
  final styled = _seriesBaseTitleIfEpisodeStyled(o.name);
  if (styled != null) {
    return styled.toLowerCase() == baseLower;
  }
  return o.name.trim().toLowerCase() == baseLower;
}

String _collapseSeriesTitleSpaces(String s) =>
    s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// M3U dosya adları: `Dizi.S01E02`, `Dizi S01E02`, `Dizi 1x02` vb. sonekleri kaldırır.
String _stripTrailingSeriesEpisodeMarkers(String input) {
  var s = _collapseSeriesTitleSpaces(input);
  if (s.isEmpty) return s;
  final patterns = <RegExp>[
    RegExp(r'\s+S\d{1,2}\s*[-–]\s*E\d{1,4}\s*$', caseSensitive: false),
    RegExp(r'\s+S\d{1,2}\s*[-–]?\s*E\d{1,4}\s*$', caseSensitive: false),
    RegExp(r'[.\s_-]+S\d{1,2}\s*[-–]?\s*E\d{1,4}\s*$', caseSensitive: false),
    RegExp(r'\s+\d{1,2}x\d{1,4}\s*$', caseSensitive: false),
    RegExp(r'[.\s_-]+\d{1,2}x\d{1,4}\s*$', caseSensitive: false),
  ];
  var changed = true;
  while (changed && s.isNotEmpty) {
    changed = false;
    for (final re in patterns) {
      final ns = s.replaceFirst(re, '').trim();
      if (ns != s && ns.isNotEmpty) {
        s = ns;
        changed = true;
        break;
      }
    }
  }
  return s.trim();
}

/// İsimden sezon/bölüm (M3U satırı); bulunamazsa `(1, 0)` — sıralama için `channel.id` kullanılır.
({int season, int episode}) _parseSeasonEpisodeFromSeriesTitle(String rawName) {
  final s = rawName.trim();
  if (s.isEmpty) return (season: 1, episode: 0);
  final reSe = RegExp(
    r'S(\d{1,2})\s*[-–]?\s*E(\d{1,4})\b',
    caseSensitive: false,
  );
  RegExpMatch? lastSe;
  for (final m in reSe.allMatches(s)) {
    lastSe = m;
  }
  if (lastSe != null) {
    final sn = int.tryParse(lastSe.group(1) ?? '') ?? 1;
    final en = int.tryParse(lastSe.group(2) ?? '') ?? 0;
    return (season: sn, episode: en);
  }
  final reX = RegExp(r'(\d{1,2})x(\d{1,4})\s*$', caseSensitive: false);
  final mx = reX.firstMatch(s);
  if (mx != null) {
    final sn = int.tryParse(mx.group(1) ?? '') ?? 1;
    final en = int.tryParse(mx.group(2) ?? '') ?? 0;
    return (season: sn, episode: en);
  }
  return (season: 1, episode: 0);
}

void _takeSeriesEpisodeBySlot(
  Map<String, SeriesEpisodeOption> byEpisodeSlot,
  SeriesEpisodeOption e,
) {
  final k = e.episodeNumber > 0
      ? '${e.season}|${e.episodeNumber}'
      : '${e.season}|0|${e.channel.id}';
  final cur = byEpisodeSlot[k];
  if (cur == null) {
    byEpisodeSlot[k] = e;
    return;
  }
  if (e.channel.id != cur.channel.id) {
    final prefer = (e.channel.id > cur.channel.id && e.channel.id > 0)
        ? e
        : (cur.channel.id <= 0 ? e : cur);
    byEpisodeSlot[k] = prefer;
  } else if (e.displayTitle.length > cur.displayTitle.length) {
    byEpisodeSlot[k] = e;
  }
}

List<SeriesEpisodeOption> _buildM3uSeriesEpisodeOptions(
    List<SeriesItem> items) {
  final byEpisodeSlot = <String, SeriesEpisodeOption>{};
  for (final s in items) {
    final url = s.streamUrl?.trim();
    if (url == null || url.isEmpty) continue;
    final pe = _parseSeasonEpisodeFromSeriesTitle(s.name);
    final ch = Channel(
      id: s.id,
      name: s.name,
      streamUrl: url,
      categoryId: s.categoryId,
      logoUrl: s.posterUrl,
      sortOrder: 0,
    );
    _takeSeriesEpisodeBySlot(
      byEpisodeSlot,
      SeriesEpisodeOption(
        channel: ch,
        season: pe.season,
        episodeNumber: pe.episode,
        displayTitle: s.name,
      ),
    );
  }
  final list = byEpisodeSlot.values.toList()
    ..sort((a, b) {
      final c = a.season.compareTo(b.season);
      if (c != 0) return c;
      final d = a.episodeNumber.compareTo(b.episodeNumber);
      if (d != 0) return d;
      return a.channel.id.compareTo(b.channel.id);
    });
  return list;
}

/// Liste gruplama anahtarı: bölüm sonekleri silinir, Türkçe karakterler eşlenir.
String _seriesCanonicalNameKey(String rawName) {
  var t = rawName.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return '';
  t = _stripTrailingSeriesEpisodeMarkers(t);
  if (t.isEmpty) return '';
  var k = t.replaceAll('İ', 'I').replaceAll('ı', 'i').toLowerCase();
  k = k
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll('ı', 'i')
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('û', 'u');
  return k;
}

/// Isolate üzerinde çalışacak ağır gruplama işlemi.
Future<List<List<SeriesItem>>> _isolateGroupSeries(List<SeriesItem> items) async {
  return compute((List<SeriesItem> list) {
    final map = <String, List<SeriesItem>>{};
    for (final s in list) {
      var key = _seriesCanonicalNameKey(s.name);
      if (key.isEmpty) {
        key = '__id_${s.id}';
      }
      map.putIfAbsent(key, () => []).add(s);
    }
    final groups = map.values.toList();
    for (final g in groups) {
      g.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    groups.sort(
      (a, b) => _seriesGroupListTitle(a)
          .toLowerCase()
          .compareTo(_seriesGroupListTitle(b).toLowerCase()),
    );
    return groups;
  }, items);
}

String _seriesGroupListTitle(List<SeriesItem> group) {
  if (group.length == 1) return group.first.name.trim();
  return group
      .reduce(
        (a, b) => a.name.trim().length <= b.name.trim().length ? a : b,
      )
      .name
      .trim();
}

SeriesItem _seriesGroupRepresentative(List<SeriesItem> group) {
  return group.reduce(
    (a, b) => a.name.trim().length <= b.name.trim().length ? a : b,
  );
}

/// Aynı (normalize) isimdeki tüm [SeriesItem] kayıtlarını birleştirir (Xtream/M3U tekrarları).
/// Liste satırındaki gruptan genişletilmiş küme: tüm playlistte aynı canonical isimdeki kayıtlar
/// (farklı kategori / filtre dışı kalan bölüm satırları dahil).
List<SeriesItem> _expandSeriesClusterForDetailFetch(
  List<SeriesItem> cluster,
  String displayTitle,
  M3uResult? data,
) {
  if (cluster.isEmpty) return cluster;
  final byId = <int, SeriesItem>{for (final s in cluster) s.id: s};
  var pk = _seriesCanonicalNameKey(displayTitle);
  if (pk.isEmpty) {
    pk = _seriesCanonicalNameKey(cluster.first.name);
  }
  if (pk.isEmpty) {
    return byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  if (data == null) {
    return byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  for (final o in data.series) {
    var ok = _seriesCanonicalNameKey(o.name);
    if (ok.isEmpty) {
      ok = '__id_${o.id}';
    }
    if (ok == pk) {
      byId[o.id] = o;
    }
  }
  return byId.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

List<List<SeriesItem>> groupSeriesItemsByNormalizedName(
    List<SeriesItem> items) {
  final map = <String, List<SeriesItem>>{};
  for (final s in items) {
    var key = _seriesCanonicalNameKey(s.name);
    if (key.isEmpty) {
      key = '__id_${s.id}';
    }
    map.putIfAbsent(key, () => []).add(s);
  }
  final groups = map.values.toList();
  for (final g in groups) {
    g.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
  groups.sort(
    (a, b) => _seriesGroupListTitle(a)
        .toLowerCase()
        .compareTo(_seriesGroupListTitle(b).toLowerCase()),
  );
  return groups;
}

List<int> _browseRowSeriesIdentityIds(BrowseRow r) {
  if (r.seriesCluster != null && r.seriesCluster!.isNotEmpty) {
    return r.seriesCluster!.map((e) => e.id).toList()..sort();
  }
  if (r.series != null) return [r.series!.id];
  return [];
}

class BrowseRow {
  const BrowseRow({
    required this.listIndex,
    required this.title,
    this.channel,
    this.vod,
    this.series,
    this.seriesCluster,
  });

  final int listIndex;
  final String title;
  final Channel? channel;
  final VodItem? vod;
  final SeriesItem? series;

  /// Aynı isimle gruplanmış tüm kayıtlar; null veya tek öğe = gruplama yok.
  final List<SeriesItem>? seriesCluster;

  String? get imageUrl {
    final c = channel;
    if (c != null) return c.logoUrl;
    final v = vod;
    if (v != null) return v.posterUrl;
    final cl = seriesCluster;
    if (cl != null) {
      for (final x in cl) {
        final u = x.posterUrl?.trim();
        if (u != null && u.isNotEmpty) return u;
      }
    }
    return series?.posterUrl;
  }

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
  final effectiveSearchQuery = ''.obs;
  final selectedRow = Rxn<BrowseRow>();

  /// "Listeler" barından liste değişince artar — kategori sütunu + ızgara
  /// `Obx`'lerini yeniden çizmek için.
  final playlistRevision = 0.obs;
  Worker? _cacheWorker;
  Worker? _hideAdultWorker;
  final RxInt selectedTabIndex = 0.obs;
  final Rxn<int> animateToTab = Rxn<int>();

  /// Xtream `get_vod_info` ile gelen özet (liste `plot` boşken).
  final vodXtreamInfoPlot = Rxn<String>();

  final detailPosterUrl = Rxn<String>();
  static const String _vodXtreamInfoCachePrefix = 'g4|';
  final Map<String, String> _vodXtreamSynopsisCache = <String, String>{};

  static const String _seriesXtreamInfoCachePrefix = 's4|';
  final Map<String, String> _seriesXtreamSynopsisCache = <String, String>{};

  final now = DateTime.now().obs;
  Timer? _clock;
  Timer? _precacheDebounce;
  Timer? _previewDebounce;
  Timer? _detailPosterDebounce;
  Timer? _seriesEpisodesLoadDebounce;
  int _seriesEpisodesLoadToken = 0;

  final searchController = TextEditingController();

  final categoryFocusNode = FocusNode();

  /// TV / yatay: "Listeler" barı odak düğümü (kategorilerin üstünde).
  final listsBarFocusNode = FocusNode();
  final listFocusNode = FocusNode();

  ScrollController? _tvBrowseListScroll;
  int? _lastTvBrowseNudgeMs;

  /// TV üst çubuk: kumanda ile liste / arama / ayarlar odakları.
  final browseBarPlaylistFocusNode =
      FocusNode(debugLabel: 'browseBarPlaylist');
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

  final allPreGroupedSeries = <List<SeriesItem>>[].obs;
  final isGroupingSeries = false.obs;

  final seriesEpisodesLoading = false.obs;
  final seriesEpisodesError = ''.obs;
  final seriesEpisodeOptions = <SeriesEpisodeOption>[].obs;
  final selectedSeriesSeason = Rxn<int>();
  final selectedSeriesEpisode = Rxn<SeriesEpisodeOption>();

  // Pagination for series lazy loading
  final seriesPageSize = 250;
  final seriesCurrentPage = 1.obs;
  final seriesHasMore = true.obs;

  // Cache for series name normalization to avoid repeated processing
  final Map<String, String> _seriesNameNormalizationCache = {};
  int? _seriesNameCacheDataHash;

  // DEBUG: İstatistik için sayaç
  int _groupSeriesCallCount = 0;

  // Debounce için cache değişkenleri
  List<BrowseRow>? _filteredRowsCache;
  int? _filteredRowsCacheHash;

  // [leftCategories] memoizasyonu. Kategori sayaçları tüm katalogu tarar
  // (her öğe için gizli/+18 filtresi). Kategori paneli Obx'i, kategori
  // seçildiğinde (selectedCategoryKey değişimi) yeniden çalıştığı için bu
  // tarama her geçişte tekrarlanıyordu → 2 sn'lik ana-thread kilitlenmesi.
  // Sonuç yalnızca veri / gizleme / geçmiş / favori / dil değişince değişir;
  // o yüzden bu imzaya göre önbelleğe alınır.
  M3uResult? _leftCategoriesData;
  int? _leftCategoriesSig;
  List<({int key, String name, int count, IconData? icon})>?
      _leftCategoriesCache;
  Worker? _searchDebounceWorker;
  final filmsFilterRevision = 0.obs;
  final isFilteringFilms = false.obs;
  int _filmsFilterJobId = 0;
  int? _pendingFilmsFilterHash;

  Set<int> _hiddenVodCategoryIds(M3uResult d) {
    return {
      for (final c in d.vodCategories)
        if (_vodCategoryHidden(c.id)) c.id,
    };
  }

  // Film filtre isolate'ine gönderilen düz diziler (id / küçük-harf ad /
  // kategori). Eskiden `_runFilmsFilterAsync` her çağrıda (liste geçişi,
  // kategori değişimi, her arama tuşu) bunları ana thread'de `toLowerCase()`
  // ile yeniden kuruyordu — büyük film kataloğunda kasmanın ana kaynağı.
  // Artık veri seti (M3uResult) kimliğine göre, weak-key Expando ile bir kez
  // kurulup önbelleğe alınır; iki liste arasında ileri-geri geçişte her iki
  // listenin projeksiyonu da korunur (yeniden hesaplanmaz).
  static final Expando<_VodFilterProjection> _vodProjectionCache =
      Expando<_VodFilterProjection>('browseVodFilterProjection');

  _VodFilterProjection _ensureVodProjection(M3uResult d) {
    final cached = _vodProjectionCache[d];
    if (cached != null) return cached;
    final n = d.vod.length;
    final ids = List<int>.filled(n, 0);
    final names = List<String>.filled(n, '');
    final cats = List<int>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final v = d.vod[i];
      ids[i] = v.id;
      names[i] = v.name.toLowerCase();
      cats[i] = v.categoryId;
    }
    final proj = _VodFilterProjection(ids: ids, namesLower: names, categoryIds: cats);
    _vodProjectionCache[d] = proj;
    return proj;
  }

  List<BrowseRow> _numberBrowseRows(List<BrowseRow> raw) => [
        for (var i = 0; i < raw.length; i++)
          BrowseRow(
            listIndex: i + 1,
            title: raw[i].title,
            channel: raw[i].channel,
            vod: raw[i].vod,
            series: raw[i].series,
            seriesCluster: raw[i].seriesCluster,
          ),
      ];

  Future<void> _runFilmsFilterAsync(
    int cacheHash,
    M3uResult d,
    String q,
    int key,
    BrowseCatalogIndex idx,
  ) async {
    final jobId = ++_filmsFilterJobId;
    isFilteringFilms.value = true;
    try {
      final proj = _ensureVodProjection(d);
      final input = BrowseFilmsFilterInput(
        vodIds: proj.ids,
        vodNamesLower: proj.namesLower,
        vodCategoryIds: proj.categoryIds,
        categoryKey: key,
        searchQueryLower: q,
        recentVodIds: d.recentVodIds,
        watchedVodIds: _watchedVodIdsOrdered(),
        hiddenCategoryIds: _hiddenVodCategoryIds(d),
        filterAdultItems: _app.effectiveHideAdultContent,
        adultTokens: AdultContentFilter.lowerTokens,
        isAllCategories: key == kAllCategories,
        isRecentCategory: key == kRecentVodCategory,
        isWatchedCategory: key == kWatchedVodCategory,
      );
      final ids = await browseFilmsFilterAsync(input);
      if (jobId != _filmsFilterJobId || !identical(_data, d)) return;

      var list = [
        for (final id in ids)
          if (idx.vodById[id] != null) idx.vodById[id]!,
      ];
      if (key == kRecentVodCategory && q.isEmpty && list.isEmpty) {
        final recent = d.recentVodIds.toSet();
        list = d.vod.where((v) => recent.contains(v.id)).toList();
      }
      list = list.where((v) => !_vodItemHidden(v)).toList();

      final result = _numberBrowseRows([
        for (final v in list) BrowseRow(listIndex: 0, title: v.name, vod: v),
      ]);
      _filteredRowsCache = result;
      _filteredRowsCacheHash = cacheHash;
      _pendingFilmsFilterHash = null;
      filmsFilterRevision.value++;
      _ensureSelection();
    } finally {
      if (jobId == _filmsFilterJobId) {
        isFilteringFilms.value = false;
      }
    }
  }

  void loadMoreSeries() {
    if (!seriesHasMore.value || mode != BrowseMode.series) return;
    seriesCurrentPage.value++;
  }

  void resetSeriesPagination() {
    seriesCurrentPage.value = 1;
    seriesHasMore.value = true;
  }

  /// Get cached normalized series name key
  String _getCachedSeriesNameKey(String rawName) {
    return _seriesNameNormalizationCache.putIfAbsent(
      rawName,
      () => _seriesCanonicalNameKey(rawName),
    );
  }

  /// Build normalization cache when data changes
  void _buildSeriesNameCacheIfNeeded() {
    final d = _data;
    if (d == null) return;

    final dataHash = d.series.length * 17 +
        d.series.fold<int>(0, (sum, s) => sum + s.name.length);
    final isCacheHit = _seriesNameCacheDataHash == dataHash;

    if (isCacheHit) return;

    _seriesNameNormalizationCache.clear();
    for (final s in d.series) {
      _seriesNameNormalizationCache[s.name] = _seriesCanonicalNameKey(s.name);
    }
    _seriesNameCacheDataHash = dataHash;
  }

  Future<void> _preGroupSeries() async {
    final d = _data;
    if (d == null || d.series.isEmpty) return;
    if (allPreGroupedSeries.isNotEmpty && _seriesNameCacheDataHash != null) {
      // Check if data changed
      final dataHash = d.series.length * 17 +
          d.series.fold<int>(0, (sum, s) => sum + s.name.length);
      if (_seriesNameCacheDataHash == dataHash) return;
    }

    isGroupingSeries.value = true;
    try {
      if (kDebugMode) {
        debugPrint(
            'BrowseController: Starting isolate grouping for ${d.series.length} items...');
      }
      final result = await _isolateGroupSeries(d.series);
      allPreGroupedSeries.assignAll(result);
      if (kDebugMode) {
        debugPrint(
            'BrowseController: Isolate grouping finished. ${result.length} groups created.');
      }
    } catch (e) {
      debugPrint('[BrowseController] Grouping error: $e');
    } finally {
      isGroupingSeries.value = false;
      _filteredRowsCache = null;
      _filteredRowsCacheHash = null;
      update();
    }
  }

  /// Cached version of groupSeriesItemsByNormalizedName for better performance
  List<List<SeriesItem>> _groupSeriesItemsCached(List<SeriesItem> items) {
    // DEBUG: İstatistik için sayaç (sadece debug modda)
    _groupSeriesCallCount++;
    if (kDebugMode) {
      debugPrint(
          'BrowseController._groupSeriesItemsCached: call #$_groupSeriesCallCount (${items.length} items)');
    }

    final map = <String, List<SeriesItem>>{};
    for (final s in items) {
      var key = _getCachedSeriesNameKey(s.name);
      if (key.isEmpty) {
        key = '__id_${s.id}';
      }
      map.putIfAbsent(key, () => []).add(s);
    }
    final groups = map.values.toList();
    for (final g in groups) {
      g.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    groups.sort(
      (a, b) => _seriesGroupListTitle(a)
          .toLowerCase()
          .compareTo(_seriesGroupListTitle(b).toLowerCase()),
    );
    return groups;
  }

  /// Xtream `get_series_info` dizi özeti (bölüm özeti yoksa gösterilir).
  final seriesDetailSynopsis = ''.obs;

  /// Xtream `get_series_info` — puan, tarih, tür, kapak (M3U’da OMDB kullanılır).
  final seriesXtreamDetailMeta = Rxn<XtreamSeriesBrowseDetail>();

  /// OMDb'den gelen film/dizi detayları
  final omdbMovieDetail = Rxn<MovieModel>();
  final isOmdbLoading = false.obs;

  bool? _playlistIsXtreamCache;

  Future<bool> isXtreamPlaylist() async {
    if (_playlistIsXtreamCache != null) return _playlistIsXtreamCache!;
    final src = await _playlist.readSource();
    _playlistIsXtreamCache = src is XtreamSource;
    return _playlistIsXtreamCache!;
  }

  void _fetchOmdbInfo(BrowseRow? row) {
    omdbMovieDetail.value = null;
    isOmdbLoading.value = true;
    final name = row?.vod?.name ?? row?.series?.name;
    if (name == null || name.isEmpty) {
      isOmdbLoading.value = false;
      return;
    }

    unawaited(() async {
      try {
        if (row?.series != null && await isXtreamPlaylist()) {
          isOmdbLoading.value = false;
          return;
        }
        final service = Get.find<MovieService>();
        final isSeries = row?.series != null;
        final streamUrl =
            row?.vod?.streamUrl ?? row?.series?.streamUrl ?? '';
        final result = await service.getMovieWithFallback(
          name: name,
          localPlot: row?.vod?.plot ?? row?.series?.plot,
          localPoster: row?.vod?.posterUrl ?? row?.series?.posterUrl,
          isSeries: isSeries,
          imdbIdHint: imdbIdFromStreamUrl(streamUrl),
        );
        if (selectedRow.value?.vod?.id == row?.vod?.id &&
            selectedRow.value?.series?.id == row?.series?.id) {
          omdbMovieDetail.value = result;
        }
      } catch (e) {
        debugPrint('[BrowseController] MovieService fetch error: $e');
      } finally {
        if (selectedRow.value?.vod?.id == row?.vod?.id &&
            selectedRow.value?.series?.id == row?.series?.id) {
          isOmdbLoading.value = false;
        }
      }
    }());
  }

  M3uResult? _data;

  /// [Get.arguments] haritası: ana ekran birleşik aramadan `pickVodId` / `pickSeriesId`
  /// (film: doğrudan oynatma; dizi: ilgili kategoride liste + bölüm seçimi).
  int? _routePickVodId;
  int? _routePickSeriesId;
  String? _routeInitialSearch;
  int? _routeInitialCategoryId;
  bool _landingFromHomeSearch = false;

  M3uResult? get snapshot => _data;

  /// Cached sorted series categories to avoid recalculation
  final _sortedSeriesCategoriesCache = <SeriesCategory>[].obs;
  int? _sortedSeriesCategoriesCacheDataHash;

  /// Get series categories sorted by series_count (ascending).
  /// Categories with >80% of total series or >10000 series are moved to the end.
  List<SeriesCategory> get sortedSeriesCategories {
    final d = _data;
    if (d == null || d.seriesCategories.isEmpty) return [];
    if (d.series.isEmpty) return d.seriesCategories;

    // Check if cache is valid (based on data hash)
    final dataHash = d.series.length + d.seriesCategories.length * 31;
    final isCacheHit = _sortedSeriesCategoriesCacheDataHash == dataHash &&
        _sortedSeriesCategoriesCache.isNotEmpty;

    // DEBUG: Cache hit/miss izleme (sadece debug modda)
    if (kDebugMode) {
      debugPrint(
          'BrowseController.sortedSeriesCategories: cache ${isCacheHit ? "HIT" : "MISS"} (hash: $dataHash, cached: $_sortedSeriesCategoriesCacheDataHash, items: ${d.series.length})');
    }

    if (isCacheHit) {
      return _sortedSeriesCategoriesCache;
    }

    // Calculate series count for each category
    final categoryCounts = <int, int>{};
    for (final series in d.series) {
      categoryCounts[series.categoryId] =
          (categoryCounts[series.categoryId] ?? 0) + 1;
    }

    // Create list with counts
    final categoriesWithCounts = d.seriesCategories.map((cat) {
      return (cat, categoryCounts[cat.id] ?? 0);
    }).toList();

    // Calculate total series
    final totalSeries = d.series.length;
    final eightyPercentThreshold = (totalSeries * 0.8).toInt();

    // Separate large and normal categories
    final largeCategories = <(SeriesCategory, int)>[];
    final normalCategories = <(SeriesCategory, int)>[];

    for (final entry in categoriesWithCounts) {
      final count = entry.$2;
      if (count > eightyPercentThreshold || count > 10000) {
        largeCategories.add(entry);
      } else {
        normalCategories.add(entry);
      }
    }

    // Sort normal categories by count (ascending)
    normalCategories.sort((a, b) => a.$2.compareTo(b.$2));

    // Sort large categories by count (ascending)
    largeCategories.sort((a, b) => a.$2.compareTo(b.$2));

    // Combine and cache
    final result = [
      ...normalCategories.map((e) => e.$1),
      ...largeCategories.map((e) => e.$1),
    ];

    _sortedSeriesCategoriesCache.value = result;
    _sortedSeriesCategoriesCacheDataHash = dataHash;
    return result;
  }

  static int? _parseRouteInt(dynamic v) {
    if (v is int) return v > 0 ? v : null;
    if (v is String) return int.tryParse(v);
    return null;
  }

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
    if (arg is BrowseMode) {
      mode = arg;
    } else if (arg is Map) {
      final m = Map<Object?, Object?>.from(arg);
      final mo = m['mode'];
      mode = mo is BrowseMode ? mo : BrowseMode.films;
      _routePickVodId = _parseRouteInt(m['pickVodId']);
      _routePickSeriesId = _parseRouteInt(m['pickSeriesId']);
      final ins = m['initialSearch'];
      if (ins is String) _routeInitialSearch = ins;
      _routeInitialCategoryId = _parseRouteInt(m['initialCategoryId']);
      _landingFromHomeSearch =
          m['fromHomeSearch'] == true || m['fromHomeSearch'] == 'true';
    } else {
      mode = BrowseMode.films;
    }

    final value = _cache.result.value;
    if (value == null) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.playlist));
      return;
    }
    _data = value;
    BrowseCatalogIndex.invalidate();
    // "Listeler" barından liste değişince önbellek güncellenir.
    _cacheWorker = ever<M3uResult?>(_cache.result, _onActivePlaylistChanged);
    _hideAdultWorker = ever<int>(_app.xtreamHideRevision, (_) {
      _filteredRowsCache = null;
      _filteredRowsCacheHash = null;
      _pendingFilmsFilterHash = null;
      playlistRevision.value++;
    });
    effectiveSearchQuery.value = searchQuery.value;
    _searchDebounceWorker = debounce<String>(
      searchQuery,
      (value) {
        final normalized = value.trim().toLowerCase();
        if (effectiveSearchQuery.value == normalized) return;
        effectiveSearchQuery.value = normalized;
        _ensureSelection();
      },
      time: const Duration(milliseconds: 180),
    );

    // Dizi adı normalizasyon önbelleği yalnızca dizi/favori modunda gerekir.
    // Filmler moduna girerken tüm dizileri regex ile normalize etmek boşuna
    // senkron maliyet (giriş gecikmesi) oluşturuyordu — bu modda atla.
    if (mode == BrowseMode.series || mode == BrowseMode.favorites) {
      _buildSeriesNameCacheIfNeeded();
      unawaited(_preGroupSeries());
    }

    listFocusNode.addListener(_onBrowseListFocusChanged);

    ever(selectedRow, (row) {
      _syncVodXtreamInfoPlot(row);
      _syncSeriesXtreamInfoPlot(row);
      _fetchOmdbInfo(row);
      _scheduleDetailPoster(row);
    });
    Future.microtask(() {
      final row = selectedRow.value;
      _syncVodXtreamInfoPlot(row);
      _syncSeriesXtreamInfoPlot(row);
      _fetchOmdbInfo(row);
      _scheduleDetailPoster(row);
    });

    if (mode == BrowseMode.favorites) {
      selectedCategoryKey.value = kFavAll;
      // Ana ekrandan «Favoriler» kartı tıklandığında kullanıcı önce
      // boş bir kategori listesi görmek yerine doğrudan favori öğeleri
      // görsün. Geri tuşu / sola kaydırma ile «Kategori» sekmesine
      // dönebilir; PopScope tab 1 → tab 0 → çıkış akışını korur.
      selectedTabIndex.value = 1;
    } else if (mode == BrowseMode.series) {
      // Select 2nd category (index 1) from sorted categories for Series to reduce initial load
      final sortedCats = sortedSeriesCategories;
      if (sortedCats.length >= 2) {
        selectedCategoryKey.value = sortedCats[1].id;
        // Request focus on category list for TV mode
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (categoryFocusNode.canRequestFocus) {
            categoryFocusNode.requestFocus();
          }
        });
      } else if (sortedCats.isNotEmpty) {
        selectedCategoryKey.value = sortedCats.first.id;
      } else {
        selectedCategoryKey.value = kAllCategories;
      }
    } else {
      selectedCategoryKey.value = kAllCategories;
    }

    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      now.value = DateTime.now();
    });
    Future.microtask(() {
      if (_routePickVodId != null ||
          _routePickSeriesId != null ||
          (_routeInitialSearch != null &&
              _routeInitialSearch!.trim().isNotEmpty)) {
        _applyRouteSearchIntentFromHome();
      } else {
        _restoreLastSelection();
      }
    });
  }

  /// Aktif playlist (gösterilen liste) değiştiğinde — önbellek yeni slot'un
  /// içeriğiyle güncellenir. `_data`'yı tazele, seçili kategori yeni listede
  /// yoksa "Tümü"ne dön, kategori/ızgara panellerini yeniden çiz.
  void _onActivePlaylistChanged(M3uResult? value) {
    if (value == null) return;
    if (identical(value, _data)) return;
    _data = value;
    BrowseCatalogIndex.invalidate();
    _buildSeriesNameCacheIfNeeded();
    if (mode == BrowseMode.series || mode == BrowseMode.favorites) {
      unawaited(_preGroupSeries());
    }
    // Seçili kategori yeni listede yoksa "Tümü"ne dön.
    final key = selectedCategoryKey.value;
    final isVirtual = key < 0; // kAllCategories / kFav* gibi sanal anahtarlar
    final List<int> catIds = mode == BrowseMode.series
        ? (_data?.seriesCategories.map((c) => c.id).toList() ?? const <int>[])
        : (_data?.vodCategories.map((c) => c.id).toList() ?? const <int>[]);
    final stillExists = isVirtual || catIds.contains(key);
    if (!stillExists) {
      selectedCategoryKey.value = kAllCategories;
    }
    playlistRevision.value++;
    _ensureSelection();
  }

  void _onBrowseListFocusChanged() {
    if (!listFocusNode.hasFocus) return;
    if (!_effectiveRemoteNav()) return;
    tvTrapFocusInBrowseList.value = true;
  }

  void _scheduleDetailPoster(BrowseRow? row) {
    _detailPosterDebounce?.cancel();
    detailPosterUrl.value = null;
    if (row == null) return;
    final url = row.imageUrl?.trim();
    if (url == null || url.isEmpty) return;
    _detailPosterDebounce = Timer(kBrowsePreviewFocusHoldDelay, () {
      final cur = selectedRow.value;
      if (cur == null) return;
      if (!_sameRow(cur, row)) return;
      detailPosterUrl.value = url;
    });
  }

  void _syncVodXtreamInfoPlot(BrowseRow? row) {
    vodXtreamInfoPlot.value = null;
    final v = row?.vod;
    if (v == null) return;

    if (v.plot != null && v.plot!.isNotEmpty) {
      vodXtreamInfoPlot.value = v.plot!;
      return;
    }

    final cacheKey = '$_vodXtreamInfoCachePrefix${v.id}';
    final cached = _vodXtreamSynopsisCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      vodXtreamInfoPlot.value = cached;
      return;
    }

    final accountKey = _cache.xtreamPreferenceKey.value?.trim() ?? '';
    unawaited(() async {
      if (accountKey.isNotEmpty) {
        final disk = await VodXtreamInfoCacheStore.readText(accountKey, v.id);
        if (disk != null && disk.isNotEmpty) {
          if (selectedRow.value?.vod?.id != v.id) return;
          _vodXtreamSynopsisCache[cacheKey] = disk;
          vodXtreamInfoPlot.value = disk;
          return;
        }
      }
      try {
        final fields = await _playlist.loadXtreamVodInfoFields(v.id);
        if (selectedRow.value?.vod?.id != v.id) return;
        if (fields != null && fields.isNotEmpty) {
          final t = _composeVodDetailFromXtreamFields(fields).trim();
          if (t.isNotEmpty) {
            _vodXtreamSynopsisCache[cacheKey] = t;
            vodXtreamInfoPlot.value = t;
            if (accountKey.isNotEmpty) {
              unawaited(VodXtreamInfoCacheStore.writeText(accountKey, v.id, t));
            }
          }
        }
      } catch (_) {}
    }());
  }

  void _syncSeriesXtreamInfoPlot(BrowseRow? row) {
    seriesDetailSynopsis.value = '';
    final s = row?.series;
    if (s == null) return;

    // Check if plot is already in SeriesItem (some servers provide it)
    if (s.plot != null && s.plot!.isNotEmpty) {
      seriesDetailSynopsis.value = s.plot!;
      return; // Prioritize M3U plot data
    }

    final cacheKey = '$_seriesXtreamInfoCachePrefix${s.id}';
    final cached = _seriesXtreamSynopsisCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      seriesDetailSynopsis.value = cached;
      return;
    }

    // Fetch from get_series_info
    unawaited(() async {
      try {
        final detail = await _playlist.resolveXtreamSeriesEpisodes(
          seriesId: s.id,
          seriesName: s.name,
          posterUrl: s.posterUrl,
          categoryId: s.categoryId,
        );
        if (selectedRow.value?.series?.id != s.id) return;
        final plot = detail.seriesPlot?.trim() ?? '';
        if (plot.isNotEmpty) {
          _seriesXtreamSynopsisCache[cacheKey] = plot;
          seriesDetailSynopsis.value = plot;
        }
      } catch (_) {}
    }());
  }

  String _composeVodDetailFromXtreamFields(Map<String, String> m) {
    final parts = <String>[];
    final plot = m['plot']?.trim();
    if (plot != null && plot.isNotEmpty) {
      parts.add(plot);
    }
    void meta(String key, String trKey) {
      final v = m[key]?.trim();
      if (v == null || v.isEmpty) return;
      parts.add(trKey.trParams({'v': v}));
    }

    meta('genre', 'browse.vod.metaLine.genre');
    meta('director', 'browse.vod.metaLine.director');
    meta('cast', 'browse.vod.metaLine.cast');
    meta('release', 'browse.vod.metaLine.release');
    // IMDb / puan üstte rozetle gösteriliyor; metin bloğunda tekrar etmesin.
    final dm = m['duration_minutes']?.trim();
    if (dm != null && dm.isNotEmpty) {
      parts.add('browse.duration.minutes'.trParams({'n': dm}));
    }
    return parts.join('\n\n');
  }

  @override
  void onReady() {
    super.onReady();
    now.value = DateTime.now();
  }

  @override
  void onClose() {
    stopBrowseListVerticalHold();
    _clock?.cancel();
    _precacheDebounce?.cancel();
    _previewDebounce?.cancel();
    _detailPosterDebounce?.cancel();
    _seriesEpisodesLoadDebounce?.cancel();
    _searchDebounceWorker?.dispose();
    _cacheWorker?.dispose();
    _hideAdultWorker?.dispose();
    _seriesEpisodesLoadToken++;
    searchController.dispose();
    listFocusNode.removeListener(_onBrowseListFocusChanged);
    categoryFocusNode.dispose();
    listsBarFocusNode.dispose();
    listFocusNode.dispose();
    browseBarPlaylistFocusNode.dispose();
    browseBarSearchFocusNode.dispose();
    browseBarSettingsFocusNode.dispose();
    browseStaticDetailFocusNode.dispose();
    browseSeriesDetailFocusNode.dispose();
    browseStaticPreviewFocusNode.dispose();
    browseSeriesPreviewFocusNode.dispose();
    browseStaticPlayFocusNode.dispose();
    browseSeriesPlayFocusNode.dispose();
    try {
      final old = previewController;
      previewController = null;
      if (old != null) {
        old.pause();
        old.dispose(forceDispose: true);
      }
    } catch (_) {}
    super.onClose();
  }

  bool _vodCategoryHidden(int categoryId) {
    final d = _data;
    if (d == null) return false;
    return PlaylistCategoryHide.vodCategoryHidden(_app, _cache, d, categoryId);
  }

  bool _seriesCategoryHidden(int categoryId) {
    final d = _data;
    if (d == null) return false;
    return PlaylistCategoryHide.seriesCategoryHidden(
      _app,
      _cache,
      d,
      categoryId,
    );
  }

  bool _vodItemHidden(VodItem v) {
    final d = _data;
    if (d == null) return false;
    return PlaylistCategoryHide.vodItemHidden(_app, _cache, d, v);
  }

  bool _seriesItemHidden(SeriesItem s) {
    final d = _data;
    if (d == null) return false;
    return PlaylistCategoryHide.seriesItemHidden(_app, _cache, d, s);
  }

  bool _channelHidden(Channel c) {
    final d = _data;
    if (d == null) return false;
    return PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, c);
  }

  /// Kullanıcının izleme geçmişine reactive erişim — `Obx` içinde
  /// [leftCategories] çağrıldığında `revision.value` okunarak değişimler
  /// kategorilere ve görsel listelere otomatik yansır.
  int _userHistoryRevisionSafe() {
    if (!Get.isRegistered<UserHistoryService>()) return 0;
    return Get.find<UserHistoryService>().revision.value;
  }

  /// Geçmişten **kronolojik** sırada (en yeni → en eski) film ID listesi.
  /// Aynı içerik birden fazla kez izlendiyse yalnızca en yeni kayıt kalır.
  List<int> _watchedVodIdsOrdered() {
    if (!Get.isRegistered<UserHistoryService>()) return const <int>[];
    final svc = Get.find<UserHistoryService>();
    final entries = svc.snapshotSync()
      ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    final seen = <int>{};
    final out = <int>[];
    for (final e in entries) {
      if (e.kind != UserHistoryKind.vod) continue;
      if (!seen.add(e.contentId)) continue;
      out.add(e.contentId);
    }
    return out;
  }

  /// Aynı yapı dizi geçmişi için.
  List<int> _watchedSeriesIdsOrdered() {
    if (!Get.isRegistered<UserHistoryService>()) return const <int>[];
    final svc = Get.find<UserHistoryService>();
    final entries = svc.snapshotSync()
      ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    final seen = <int>{};
    final out = <int>[];
    for (final e in entries) {
      if (e.kind != UserHistoryKind.series) continue;
      if (!seen.add(e.contentId)) continue;
      out.add(e.contentId);
    }
    return out;
  }

  int _visibleVodCount(M3uResult d, BrowseCatalogIndex idx) {
    var n = 0;
    for (final v in d.vod) {
      if (!_vodItemHidden(v)) n++;
    }
    return n;
  }

  int _visibleSeriesCount(M3uResult d, BrowseCatalogIndex idx) {
    var n = 0;
    for (final s in d.series) {
      if (!_seriesItemHidden(s)) n++;
    }
    return n;
  }

  int _watchedVodVisibleCount(M3uResult d, BrowseCatalogIndex idx) {
    final ids = _watchedVodIdsOrdered();
    if (ids.isEmpty) return 0;
    var n = 0;
    for (final id in ids) {
      final v = idx.vodById[id];
      if (v != null && !_vodItemHidden(v)) n++;
    }
    return n;
  }

  int _watchedSeriesVisibleCount(M3uResult d, BrowseCatalogIndex idx) {
    final ids = _watchedSeriesIdsOrdered();
    if (ids.isEmpty) return 0;
    var n = 0;
    for (final id in ids) {
      final s = idx.seriesById[id];
      if (s != null && !_seriesItemHidden(s)) n++;
    }
    return n;
  }

  /// Mevcut katalogda görünür (gizli olmayan) favori film sayısı.
  int _favVodVisibleCount(M3uResult d, BrowseCatalogIndex idx) {
    var n = 0;
    for (final id in _fav.vodIds) {
      final v = idx.vodById[id];
      if (v != null && !_vodItemHidden(v)) n++;
    }
    return n;
  }

  /// Mevcut katalogda görünür (gizli olmayan) favori dizi sayısı.
  int _favSeriesVisibleCount(M3uResult d, BrowseCatalogIndex idx) {
    var n = 0;
    for (final id in _fav.seriesIds) {
      final s = idx.seriesById[id];
      if (s != null && !_seriesItemHidden(s)) n++;
    }
    return n;
  }

  List<({int key, String name, int count, IconData? icon})> get leftCategories {
    final d = _data!;
    // Reaktif okumalar burada yapılır → bu getter'ı saran Obx, veri/gizleme/
    // geçmiş/favori değişimlerine abone kalır. Sonuç bu imzaya göre önbelleğe
    // alınır; yalnızca selectedCategoryKey değiştiğinde (kategori seçimi) tüm
    // katalog yeniden TARANMAZ.
    final hideRev = _app.xtreamHideRevision.value;
    final histRev = _userHistoryRevisionSafe();
    final favSig = Object.hash(
      Object.hashAll(_fav.vodIds),
      Object.hashAll(_fav.seriesIds),
      _fav.channelIds.length,
    );
    final locale = Get.locale?.toString() ?? '';
    final sig = Object.hash(mode, hideRev, histRev, favSig, locale);
    if (identical(_leftCategoriesData, d) &&
        sig == _leftCategoriesSig &&
        _leftCategoriesCache != null) {
      return _leftCategoriesCache!;
    }
    final result = _computeLeftCategories(d);
    _leftCategoriesData = d;
    _leftCategoriesSig = sig;
    _leftCategoriesCache = result;
    return result;
  }

  List<({int key, String name, int count, IconData? icon})>
      _computeLeftCategories(M3uResult d) {
    final idx = BrowseCatalogIndex.of(d);
    return switch (mode) {
      BrowseMode.films => () {
          final watchedCount = _watchedVodVisibleCount(d, idx);
          return [
          if (d.recentVodIds.isNotEmpty)
            (
              key: kRecentVodCategory,
              name: 'browse.recentAdded'.tr,
              count: d.recentVodIds.length,
              icon: Icons.new_releases_rounded,
            ),
          if (_favVodVisibleCount(d, idx) > 0)
            (
              key: kFavVodCategory,
              name: 'browse.favorites'.tr,
              count: _favVodVisibleCount(d, idx),
              icon: Icons.bookmark_rounded,
            ),
          (
            key: kAllCategories,
            name: 'Tüm filmler',
            count: _visibleVodCount(d, idx),
            icon: null,
          ),
          if (watchedCount > 0)
            (
              key: kWatchedVodCategory,
              name: 'browse.recentlyWatched'.tr,
              count: watchedCount,
              icon: Icons.history_rounded,
            ),
          ...PlaylistCategoryHide.orderVodCategories(
            _app,
            _cache,
            d.vodCategories.where((c) => !_vodCategoryHidden(c.id)).toList(),
          ).map(
                (c) => (
                  key: c.id,
                  name: c.name,
                  count: (idx.vodByCategory[c.id] ?? const [])
                      .where((v) => !_vodItemHidden(v))
                      .length,
                  icon: null,
                ),
              ),
        ];
        }(),
      BrowseMode.series => () {
          final watchedCount = _watchedSeriesVisibleCount(d, idx);
          return [
          if (d.recentSeriesIds.isNotEmpty)
            (
              key: kRecentSeriesCategory,
              name: 'browse.recentAdded'.tr,
              count: d.recentSeriesIds.length,
              icon: Icons.new_releases_rounded,
            ),
          if (_favSeriesVisibleCount(d, idx) > 0)
            (
              key: kFavSeriesCategory,
              name: 'browse.favorites'.tr,
              count: _favSeriesVisibleCount(d, idx),
              icon: Icons.bookmark_rounded,
            ),
          (
            key: kAllCategories,
            name: 'Tüm diziler',
            count: _visibleSeriesCount(d, idx),
            icon: null,
          ),
          if (watchedCount > 0)
            (
              key: kWatchedSeriesCategory,
              name: 'browse.recentlyWatched'.tr,
              count: watchedCount,
              icon: Icons.history_rounded,
            ),
          ...PlaylistCategoryHide.orderSeriesCategories(
            _app,
            _cache,
            d.seriesCategories
                .where((c) => !_seriesCategoryHidden(c.id))
                .toList(),
          ).map(
                (c) => (
                  key: c.id,
                  name: c.name,
                  count: (idx.seriesByCategory[c.id] ?? const [])
                      .where((s) => !_seriesItemHidden(s))
                      .length,
                  icon: null,
                ),
              ),
        ];
        }(),
      BrowseMode.favorites => [
          (key: kFavAll, name: 'Tümü', count: _fav.totalCount, icon: null),
          (
            key: kFavChannels,
            name: 'Kanallar',
            count: _fav.channelIds.length,
            icon: null
          ),
          (
            key: kFavFilms,
            name: 'Filmler',
            count: _fav.vodIds.length,
            icon: null
          ),
          (
            key: kFavSeries,
            name: 'Diziler',
            count: _fav.seriesIds.length,
            icon: null
          ),
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
      resetSeriesPagination();
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

  /// TV: kategori satırına odak gelince tuzak kalkar (mor çerçeve gizlenmesin).
  void syncTvCategoryFocusFromRow(int categoryKey) {
    if (!_effectiveRemoteNav()) return;
    tvTrapFocusInBrowseList.value = false;
    if (selectedCategoryKey.value != categoryKey) {
      selectCategoryKey(categoryKey, moveFocus: false);
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (categoryFocusNode.canRequestFocus) {
          categoryFocusNode.requestFocus();
        }
      });
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

  void attachTvBrowseListScroll(ScrollController controller) {
    _tvBrowseListScroll = controller;
  }

  void detachTvBrowseListScroll(ScrollController controller) {
    if (_tvBrowseListScroll == controller) {
      _tvBrowseListScroll = null;
    }
  }

  bool _throttleTvBrowseNudge() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastTvBrowseNudgeMs != null && now - _lastTvBrowseNudgeMs! < 90) {
      return true;
    }
    _lastTvBrowseNudgeMs = now;
    return false;
  }

  /// TV Bölge B: orta liste içinde yalnızca dikey gezinme.
  void tvNudgeBrowseListRow(int delta) {
    if (!_effectiveRemoteNav()) return;
    if (delta == 0) return;
    if (_throttleTvBrowseNudge()) return;
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

  Timer? _tvBrowseListVerticalHoldInitial;
  Timer? _tvBrowseListVerticalHoldPeriodic;

  /// TV: basılı tutma — tuş inişinde bir satır; sonra ivmesiz ±1 adımlar.
  void beginBrowseListVerticalHold(int delta, Duration interval) {
    if (!_effectiveRemoteNav()) return;
    if (delta == 0) return;
    stopBrowseListVerticalHold();
    _tvBrowseListVerticalHoldInitial =
        Timer(kTvListVerticalHoldPauseBeforeRepeat, () {
      _tvBrowseListVerticalHoldInitial = null;
      if (isClosed) return;
      _tvBrowseListVerticalHoldPeriodic = Timer.periodic(interval, (_) {
        if (isClosed) {
          stopBrowseListVerticalHold();
          return;
        }
        tvNudgeBrowseListRow(delta);
      });
    });
  }

  void stopBrowseListVerticalHold() {
    _tvBrowseListVerticalHoldInitial?.cancel();
    _tvBrowseListVerticalHoldPeriodic?.cancel();
    _tvBrowseListVerticalHoldInitial = null;
    _tvBrowseListVerticalHoldPeriodic = null;
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
    final normalized = v.trim().toLowerCase();
    if (searchQuery.value == normalized) return;
    searchQuery.value = normalized;
  }

  static bool _sameRow(BrowseRow a, BrowseRow b) {
    if (a.channel?.id != b.channel?.id) return false;
    if (a.vod?.id != b.vod?.id) return false;
    if (a.series == null && b.series == null) return true;
    if (a.series == null || b.series == null) return false;
    final idsA = _browseRowSeriesIdentityIds(a);
    final idsB = _browseRowSeriesIdentityIds(b);
    if (idsA.length != idsB.length) return false;
    for (var i = 0; i < idsA.length; i++) {
      if (idsA[i] != idsB[i]) return false;
    }
    return true;
  }

  // DEBUG: İstatistik için sayaç
  int _filteredRowsCallCount = 0;

  List<BrowseRow> get filteredRows {
    _filteredRowsCallCount++;
    final d = _data!;
    final q = effectiveSearchQuery.value;

    // DEBUG: Çağrı sayısını ve modu izle (sadece debug modda)
    if (kDebugMode) {
      debugPrint(
          'BrowseController.filteredRows: call #$_filteredRowsCallCount (mode: $mode, search: "$q", page: ${seriesCurrentPage.value})');
    }

    // Cache key: tüm girdileri birleştir (data, search, page, category, history)
    final cacheHash = Object.hash(
      d.hashCode,
      q.hashCode,
      selectedCategoryKey.value.hashCode,
      seriesCurrentPage.value,
      mode.hashCode,
      _userHistoryRevisionSafe(),
      _app.xtreamHideRevision.value,
      // Favori değişince "Favoriler" kategorisi anında tazelensin.
      Object.hashAll(_fav.vodIds),
      Object.hashAll(_fav.seriesIds),
    );

    // Cache hit kontrolü
    if (_filteredRowsCacheHash == cacheHash && _filteredRowsCache != null) {
      if (kDebugMode) {
        debugPrint(
            'BrowseController.filteredRows: CACHE HIT (hash: $cacheHash)');
      }
      return _filteredRowsCache!;
    }

    if (kDebugMode) {
      debugPrint(
          'BrowseController.filteredRows: CACHE MISS - Computing... (hash: $cacheHash)');
    }

    List<BrowseRow> numberRows(List<BrowseRow> raw) => _numberBrowseRows(raw);

    if (mode == BrowseMode.films) {
      final key = selectedCategoryKey.value;
      final idx = BrowseCatalogIndex.of(d);

      // Favoriler sanal kategorisi: kategori indeksinde olmadığından (büyük
      // katalog async yolundan önce) doğrudan favori listesinden kur.
      if (key == kFavVodCategory) {
        final favIds = _fav.vodIds.toSet();
        var list = [
          for (final v in d.vod)
            if (favIds.contains(v.id) && !_vodItemHidden(v)) v,
        ];
        if (q.isNotEmpty) {
          list = list.where((v) => v.name.toLowerCase().contains(q)).toList();
        }
        final result = numberRows([
          for (final v in list) BrowseRow(listIndex: 0, title: v.name, vod: v),
        ]);
        _filteredRowsCache = result;
        _filteredRowsCacheHash = cacheHash;
        return result;
      }

      if (d.vod.length >= 2500) {
        if (_pendingFilmsFilterHash != cacheHash) {
          _pendingFilmsFilterHash = cacheHash;
          unawaited(_runFilmsFilterAsync(cacheHash, d, q, key, idx));
        }
        if (_filteredRowsCacheHash == cacheHash && _filteredRowsCache != null) {
          return _filteredRowsCache!;
        }
        // Tek kategori seçiliyken indeks zaten küçük — anında göster.
        if (q.isEmpty &&
            key != kAllCategories &&
            key != kRecentVodCategory &&
            key != kWatchedVodCategory) {
          final list = List<VodItem>.from(idx.vodByCategory[key] ?? const [])
              .where((v) => !_vodItemHidden(v))
              .toList();
          return numberRows([
            for (final v in list) BrowseRow(listIndex: 0, title: v.name, vod: v),
          ]);
        }
        return _filteredRowsCache ?? const <BrowseRow>[];
      }

      // Arama varken yalnızca seçili kategoride aramak sonuçları kaçırır; tüm kütüphanede ara.
      List<VodItem> list;
      if (key == kAllCategories || q.isNotEmpty) {
        list = List<VodItem>.from(d.vod);
      } else if (key == kRecentVodCategory && q.isEmpty) {
        final ids = d.recentVodIds.toSet();
        list = d.vod.where((v) => ids.contains(v.id)).toList();
      } else if (key == kWatchedVodCategory && q.isEmpty) {
        final orderedIds = _watchedVodIdsOrdered();
        if (orderedIds.isEmpty) {
          list = const <VodItem>[];
        } else {
          list = [
            for (final id in orderedIds)
              if (idx.vodById[id] != null &&
                  !_vodItemHidden(idx.vodById[id]!))
                idx.vodById[id]!,
          ];
        }
      } else {
        list = List<VodItem>.from(idx.vodByCategory[key] ?? const []);
      }
      if (key == kRecentVodCategory && q.isEmpty && list.isEmpty) {
        final ids = d.recentVodIds.toSet();
        list = d.vod.where((v) => ids.contains(v.id)).toList();
      }
      list = list.where((v) => !_vodItemHidden(v)).toList();
      if (q.isNotEmpty) {
        list = list.where((v) => v.name.toLowerCase().contains(q)).toList();
      }
      final result = numberRows([
        for (final v in list) BrowseRow(listIndex: 0, title: v.name, vod: v),
      ]);
      _filteredRowsCache = result;
      _filteredRowsCacheHash = cacheHash;
      return result;
    }

    if (mode == BrowseMode.series) {
      final key = selectedCategoryKey.value;
      List<List<SeriesItem>> groups;

      // Son İzlenenler — kullanıcının izleme geçmişinden diziler. Kronolojik
      // sırayı korumak için pre-grouped listeyi atlayıp doğrudan history
      // sırasıyla kuruyoruz.
      if (key == kWatchedSeriesCategory && q.isEmpty) {
        final orderedIds = _watchedSeriesIdsOrdered();
        if (orderedIds.isEmpty) {
          groups = const <List<SeriesItem>>[];
        } else {
          final idx = BrowseCatalogIndex.of(d);
          groups = [
            for (final id in orderedIds)
              if (idx.seriesById[id] != null &&
                  !_seriesItemHidden(idx.seriesById[id]!))
                <SeriesItem>[idx.seriesById[id]!],
          ];
        }
      } else if (allPreGroupedSeries.isNotEmpty) {
        // ✅ EN HIZLI YOL: Önceden gruplanmış listeyi filtrele
        final recentSet = key == kRecentSeriesCategory ? d.recentSeriesIds.toSet() : null;
        final favSet =
            key == kFavSeriesCategory ? _fav.seriesIds.toSet() : null;
        groups = allPreGroupedSeries.where((g) {
          final visible = g.where((s) => !_seriesItemHidden(s)).toList();
          if (visible.isEmpty) return false;
          final matchesCategory = key == kAllCategories ||
              (recentSet != null
                  ? visible.any((s) => recentSet.contains(s.id))
                  : favSet != null
                      ? visible.any((s) => favSet.contains(s.id))
                      : visible.any((s) => s.categoryId == key));
          if (!matchesCategory) return false;

          if (q.isEmpty) return true;
          return visible.any((s) => s.name.toLowerCase().contains(q));
        }).map((g) => g.where((s) => !_seriesItemHidden(s)).toList()).toList();
      } else {
        // Gruplama henüz bitmedi veya boş; eski yavaş yönteme fallback (veya boş liste)
        List<SeriesItem> list;
        if (q.isNotEmpty) {
          list = d.series.where((s) => s.name.toLowerCase().contains(q)).toList();
        } else if (key == kRecentSeriesCategory) {
          final idSet = d.recentSeriesIds.toSet();
          list = d.series.where((s) => idSet.contains(s.id)).toList();
        } else if (key == kFavSeriesCategory) {
          final favSet = _fav.seriesIds.toSet();
          list = d.series
              .where((s) => favSet.contains(s.id) && !_seriesItemHidden(s))
              .toList();
        } else if (key == kAllCategories) {
          list = d.series.where((s) => !_seriesItemHidden(s)).toList();
        } else {
          list = d.series
              .where((s) => s.categoryId == key && !_seriesItemHidden(s))
              .toList();
        }
        groups = _groupSeriesItemsCached(list);
      }

      // Pagination: show all items up to current page (infinite scroll)
      final endIndex = seriesCurrentPage.value * seriesPageSize;
      final paginatedGroups = endIndex < groups.length
          ? groups.sublist(0, endIndex)
          : groups;

      seriesHasMore.value = endIndex < groups.length;

      final result = numberRows([
        for (final g in paginatedGroups)
          g.length == 1
              ? BrowseRow(
                  listIndex: 0,
                  title: g.first.name,
                  series: g.first,
                )
              : BrowseRow(
                  listIndex: 0,
                  title: _seriesGroupListTitle(g),
                  series: _seriesGroupRepresentative(g),
                  seriesCluster: List<SeriesItem>.from(g),
                ),
      ]);
      _filteredRowsCache = result;
      _filteredRowsCacheHash = cacheHash;
      return result;
    }

    final fk = selectedCategoryKey.value;
    final raw = <BrowseRow>[];
    final idx = BrowseCatalogIndex.of(d);

    void tryChannel(int id) {
      final c = idx.channelById[id];
      if (c == null || _channelHidden(c)) return;
      if (q.isEmpty || c.name.toLowerCase().contains(q)) {
        raw.add(BrowseRow(listIndex: 0, title: c.name, channel: c));
      }
    }

    void tryVod(int id) {
      final v = idx.vodById[id];
      if (v == null || _vodItemHidden(v)) return;
      if (q.isEmpty || v.name.toLowerCase().contains(q)) {
        raw.add(BrowseRow(listIndex: 0, title: v.name, vod: v));
      }
    }

    void trySeries(int id) {
      final s = idx.seriesById[id];
      if (s == null || _seriesItemHidden(s)) return;
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

    final result = numberRows(raw);
    _filteredRowsCache = result;
    _filteredRowsCacheHash = cacheHash;
    return result;
  }

  void _ensureSelection({bool fromPlaylistRestore = false}) {
    final list = filteredRows;
    if (list.isEmpty) {
      selectedRow.value = null;
      return;
    }
    final cur = selectedRow.value;
    final preferNone =
        fromPlaylistRestore && _app.layoutMode.value != AppLayoutMode.tv;
    if (cur == null) {
      selectedRow.value = preferNone ? null : list.first;
      return;
    }
    final still = list.where((r) => _sameRow(r, cur)).toList();
    if (still.isEmpty) {
      selectedRow.value = preferNone ? null : list.first;
    } else {
      selectedRow.value = still.first;
    }
  }

  /// TV: oklarla gezinirken seçimi güncelle; [selectRow] oynatıcı açmaz.
  ///
  /// Aynı satırda kalınca erken dönüş, paylaşımlı [listFocusNode] + scroll senkronunu
  /// bozabiliyordu (kanallar listesindeki gibi).
  void focusBrowseRow(BrowseRow row) {
    if (selectedRow.value != null && _sameRow(selectedRow.value!, row)) {
      _reattachSharedListFocusAfterRebuild();
      return;
    }
    _applyBrowseRowSelection(row);
  }

  void _applyBrowseRowSelection(BrowseRow row) {
    final ctx = Get.context;
    final portrait = ctx != null &&
        ctx.mounted &&
        MediaQuery.orientationOf(ctx) == Orientation.portrait;
    final q = searchQuery.value.trim();
    if (portrait && q.isNotEmpty) {
      if (mode == BrowseMode.films && row.vod != null) {
        selectedCategoryKey.value = row.vod!.categoryId;
      } else if (mode == BrowseMode.series && row.series != null) {
        selectedCategoryKey.value = row.series!.categoryId;
      } else if (mode == BrowseMode.favorites) {
        if (row.vod != null) {
          selectedCategoryKey.value = kFavFilms;
        } else if (row.series != null) {
          selectedCategoryKey.value = kFavSeries;
        } else if (row.channel != null) {
          selectedCategoryKey.value = kFavChannels;
        }
      }
    }

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
      // Disabled episode loading in browse view to prevent TV Box lag
      // Episodes are loaded when opening full detail screen
      // _scheduleSeriesEpisodesLoad(row);
    } else {
      _seriesEpisodesLoadDebounce?.cancel();
      _seriesEpisodesLoadToken++;
      _clearSeriesEpisodes();
    }

    final ch = row.playerChannel;
    if (!seriesSide && ch != null) {
      _schedulePrecache(ch.streamUrl);
      if (row.channel != null) {
        _schedulePreview(ch);
      } else {
        unawaited(_stopPreview());
      }
    } else if (!seriesSide) {
      _stopPreview();
    }
    _reattachSharedListFocusAfterRebuild();
  }

  void selectRow(BrowseRow row) {
    if (_app.layoutMode.value == AppLayoutMode.tv) {
      if (!row.canPlay) return;
      final seriesListRow = row.series != null &&
          (mode == BrowseMode.series || mode == BrowseMode.favorites);
      _applyBrowseRowSelection(row);
      if (seriesListRow) {
        return;
      }
      unawaited(openRowPlayer(row));
      return;
    }
    if (selectedRow.value != null && _sameRow(selectedRow.value!, row)) {
      final seriesListRow = row.series != null &&
          (mode == BrowseMode.series || mode == BrowseMode.favorites);
      if (seriesListRow) {
        return;
      }
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
      final list = filteredRows;
      final cur = selectedRow.value;
      if (cur != null) {
        final i = list.indexWhere((r) => _sameRow(r, cur));
        final sc = _tvBrowseListScroll;
        if (i >= 0 && sc != null && sc.hasClients) {
          final vp = sc.position.viewportDimension;
          final target = (i * kTvGlassListRowExtent - vp * 0.22)
              .clamp(0.0, sc.position.maxScrollExtent);
          if ((sc.offset - target).abs() > 0.5) {
            sc.jumpTo(target);
            return;
          }
        }
      }
      final ctx = listFocusNode.context;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: Duration.zero,
        curve: Curves.linear,
        alignment: 0.22,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  void _scheduleSeriesDetailPreview() {
    final ep = selectedSeriesEpisode.value;
    if (ep != null) {
      _schedulePrecache(ep.channel.streamUrl);
    }
    unawaited(_stopPreview());
  }

  /// Dikey moda dönünce önizleme yeniden zamanlanır (yatayda kapalı tutuldu).
  void refreshSeriesPreviewAfterOrientationChange() {
    final row = selectedRow.value;
    if (row?.series == null) return;
    _scheduleSeriesDetailPreview();
  }

  /// Dizi paneli: tam ekran özet + tüm bölüm satırları (kumanda ile kapatılabilir).
  void openSeriesEpgDialog() {
    final row = selectedRow.value;
    final series = row?.series;
    if (series == null) return;

    final syn = seriesDetailSynopsis.value.trim();
    final plotFallback = series.plot?.trim() ?? '';
    final bodySyn = syn.isNotEmpty ? syn : plotFallback;
    final eps = List<SeriesEpisodeOption>.from(seriesEpisodeOptions);

    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null) return;

    final app = Get.find<AppSettingsService>();
    final useTvGlass = app.layoutMode.value.usesRemoteNavigationStyle;

    showDialog<void>(
      context: ctx,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final onSurface = theme.colorScheme.onSurface;
        final onMuted = onSurface.withValues(alpha: 0.78);

        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: GlassAlertDialog(
            scrollable: true,
            tvOsdStyle: useTvGlass,
            title: Text(row?.title ?? series.name),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bodySyn.isNotEmpty)
                  Text(
                    bodySyn,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: useTvGlass
                          ? Colors.white.withValues(alpha: 0.82)
                          : onMuted,
                      height: 1.35,
                    ),
                  ),
                if (bodySyn.isNotEmpty && eps.isNotEmpty)
                  const SizedBox(height: 14),
                if (eps.isNotEmpty) ...[
                  Text(
                    'browse.episodes'.tr,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: useTvGlass
                          ? Colors.white.withValues(alpha: 0.95)
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final e in eps) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.displayTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: useTvGlass ? Colors.white : onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (e.plot != null && e.plot!.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                e.plot!.trim(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: useTvGlass
                                      ? Colors.white.withValues(alpha: 0.78)
                                      : onMuted,
                                  height: 1.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
                if (bodySyn.isEmpty && eps.isEmpty)
                  Text(
                    'browse.seriesEpgEmpty'.tr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: useTvGlass
                          ? Colors.white.withValues(alpha: 0.75)
                          : onMuted,
                    ),
                  ),
              ],
            ),
            actions: [
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: GlassDialogActionButton(
                  label: 'common.close'.tr,
                  primary: true,
                  autofocus: true,
                  onDarkSurface: useTvGlass,
                  onPressed: () {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop<void>();
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _clearSeriesEpisodes() {
    seriesEpisodeOptions.clear();
    seriesEpisodesError.value = '';
    selectedSeriesSeason.value = null;
    selectedSeriesEpisode.value = null;
    seriesEpisodesLoading.value = false;
    seriesDetailSynopsis.value = '';
    seriesXtreamDetailMeta.value = null;
  }

  void _applyXtreamSeriesDetailMeta(XtreamSeriesBrowseDetail detail) {
    seriesXtreamDetailMeta.value = detail;
    final plot = detail.seriesPlot?.trim();
    if (plot != null && plot.isNotEmpty) {
      seriesDetailSynopsis.value = plot;
    }
  }

  Future<void> loadSeriesEpisodesForBrowseRow(
    BrowseRow row, {
    required int requestToken,
  }) async {
    if (isClosed || requestToken != _seriesEpisodesLoadToken) return;
    final s = row.series;
    if (s == null) return;
    final c = row.seriesCluster;
    if (c != null && c.length > 1) {
      await _loadSeriesEpisodesMerged(
        c,
        displayTitle: row.title,
        requestToken: requestToken,
      );
    } else {
      await _loadSeriesEpisodes(
        s,
        requestToken: requestToken,
      );
    }
  }

  Future<void> _loadSeriesEpisodes(
    SeriesItem s, {
    required int requestToken,
  }) async {
    if (isClosed || requestToken != _seriesEpisodesLoadToken) return;
    seriesEpisodesLoading.value = true;
    seriesEpisodesError.value = '';
    seriesEpisodeOptions.clear();
    selectedSeriesEpisode.value = null;
    selectedSeriesSeason.value = null;
    try {
      Future<XtreamSeriesBrowseDetail> loadDetail(
        int seriesId,
        String seriesName,
      ) =>
          _playlist.resolveXtreamSeriesEpisodes(
            seriesId: seriesId,
            seriesName: seriesName,
            posterUrl: s.posterUrl,
            categoryId: s.categoryId,
          );

      final detail = await loadDetail(s.id, s.name);
      _applyXtreamSeriesDetailMeta(detail);
      var list = List<SeriesEpisodeOption>.from(detail.episodes);
      var syn = detail.seriesPlot?.trim();
      if (syn == null || syn.isEmpty) {
        syn = s.plot?.trim();
      }
      seriesDetailSynopsis.value =
          (syn != null && syn.isNotEmpty) ? syn : (s.plot?.trim() ?? '');
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
      }

      final base = _seriesBaseTitleIfEpisodeStyled(s.name);
      final baseLower = base?.toLowerCase();
      final maxSiblingFetches =
          _app.layoutMode.value == AppLayoutMode.tv ? 16 : 64;
      if (baseLower != null &&
          list.length <= 1 &&
          _data != null &&
          _data!.series.isNotEmpty) {
        final siblingIds = <int>{};
        for (final o in _data!.series) {
          if (_seriesSameMergedShow(o, baseLower, s.categoryId)) {
            siblingIds.add(o.id);
          }
        }
        if (siblingIds.length > 1) {
          final ids = siblingIds.toList()..sort();
          final capped = ids.length <= maxSiblingFetches
              ? ids
              : ids.sublist(0, maxSiblingFetches);
          final details = <XtreamSeriesBrowseDetail>[detail];
          final otherIds = capped.where((id) => id != s.id).toList();
          if (otherIds.isNotEmpty) {
            details.addAll(
              await Future.wait(
                otherIds.map((id) => loadDetail(id, base!)),
              ),
            );
          }
          if (isClosed || requestToken != _seriesEpisodesLoadToken) return;
          final byStream = <int, SeriesEpisodeOption>{};
          String? mergedPlot;
          for (final d in details) {
            final p = d.seriesPlot?.trim();
            if (p != null && p.isNotEmpty) {
              if (mergedPlot == null || p.length > mergedPlot.length) {
                mergedPlot = p;
              }
            }
            for (final e in d.episodes) {
              byStream[e.channel.id] = e;
            }
          }
          final mergedList = byStream.values.toList()
            ..sort((a, b) {
              final c = a.season.compareTo(b.season);
              if (c != 0) return c;
              return a.episodeNumber.compareTo(b.episodeNumber);
            });
          if (mergedList.length > list.length) {
            list = mergedList;
            if (mergedPlot != null && mergedPlot.isNotEmpty) {
              syn = mergedPlot;
            }
          }
        }
      }

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
        final expanded = _expandSeriesClusterForDetailFetch([s], s.name, _data);
        final m3uList = _buildM3uSeriesEpisodeOptions(expanded);
        if (m3uList.isNotEmpty) {
          seriesEpisodeOptions.assignAll(m3uList);
          final seasons = m3uList.map((e) => e.season).toSet().toList()..sort();
          selectedSeriesSeason.value = seasons.isNotEmpty ? seasons.first : 1;
          final ss = selectedSeriesSeason.value ?? 1;
          SeriesEpisodeOption? pick;
          for (final e in m3uList) {
            if (e.season == ss) {
              pick = e;
              break;
            }
          }
          selectedSeriesEpisode.value = pick ?? m3uList.first;
        } else {
          seriesEpisodesError.value = 'Bölüm listesi alınamadı.';
        }
      }
    } catch (_) {
      if (isClosed || requestToken != _seriesEpisodesLoadToken) return;
      seriesEpisodesError.value = 'Bölümler yüklenemedi.';
    } finally {
      if (!isClosed && requestToken == _seriesEpisodesLoadToken) {
        seriesEpisodesLoading.value = false;
        _scheduleSeriesDetailPreview();
      }
    }
  }

  /// İsimle gruplanmış satır: her `series_id` için bilgi çekilip bölümler birleştirilir.
  Future<void> _loadSeriesEpisodesMerged(
    List<SeriesItem> cluster, {
    required String displayTitle,
    required int requestToken,
  }) async {
    if (cluster.isEmpty) return;
    if (isClosed || requestToken != _seriesEpisodesLoadToken) return;
    seriesEpisodesLoading.value = true;
    seriesEpisodesError.value = '';
    seriesEpisodeOptions.clear();
    selectedSeriesEpisode.value = null;
    selectedSeriesSeason.value = null;
    try {
      final expanded = _expandSeriesClusterForDetailFetch(
        cluster,
        displayTitle,
        _data,
      );
      final rep = _seriesGroupRepresentative(expanded);
      String? fallbackPoster;
      for (final s in expanded) {
        final u = s.posterUrl?.trim();
        if (u != null && u.isNotEmpty) {
          fallbackPoster = u;
          break;
        }
      }

      Future<XtreamSeriesBrowseDetail> loadDetail(SeriesItem item) =>
          _playlist.resolveXtreamSeriesEpisodes(
            seriesId: item.id,
            seriesName: displayTitle,
            posterUrl: item.posterUrl ?? fallbackPoster ?? rep.posterUrl,
            categoryId: item.categoryId,
          );
      void applyEpisodeState(
        List<SeriesEpisodeOption> list, {
        required String synopsis,
      }) {
        seriesDetailSynopsis.value = synopsis;
        if (list.isNotEmpty) {
          final current = selectedSeriesEpisode.value;
          seriesEpisodeOptions.assignAll(list);
          final seasons = list.map((e) => e.season).toSet().toList()..sort();
          selectedSeriesSeason.value = seasons.isNotEmpty ? seasons.first : 1;
          SeriesEpisodeOption? pick;
          if (current != null) {
            pick = list.firstWhereOrNull(
              (e) =>
                  e.channel.id == current.channel.id &&
                  e.season == current.season &&
                  e.episodeNumber == current.episodeNumber,
            );
          }
          pick ??= list.first;
          selectedSeriesEpisode.value = pick;
          return;
        }
        final m3uList = _buildM3uSeriesEpisodeOptions(expanded);
        if (m3uList.isNotEmpty) {
          seriesEpisodeOptions.assignAll(m3uList);
          final seasons = m3uList.map((e) => e.season).toSet().toList()..sort();
          selectedSeriesSeason.value = seasons.isNotEmpty ? seasons.first : 1;
          final ss = selectedSeriesSeason.value ?? 1;
          SeriesEpisodeOption? pick;
          for (final e in m3uList) {
            if (e.season == ss) {
              pick = e;
              break;
            }
          }
          selectedSeriesEpisode.value = pick ?? m3uList.first;
        } else {
          seriesEpisodesError.value = 'Bölüm listesi alınamadı.';
        }
      }

      final maxFetches = _app.layoutMode.value == AppLayoutMode.tv ? 40 : 160;
      final capped = expanded.length <= maxFetches
          ? expanded
          : expanded.sublist(0, maxFetches);
      final byEpisodeSlot = <String, SeriesEpisodeOption>{};
      final synopsisFallback = rep.plot?.trim() ?? '';
      String mergedPlot = synopsisFallback;

      XtreamSeriesBrowseDetail? firstDetail;
      try {
        firstDetail = await loadDetail(rep);
      } catch (_) {}
      if (isClosed || requestToken != _seriesEpisodesLoadToken) return;

      if (firstDetail != null) {
        _applyXtreamSeriesDetailMeta(firstDetail);
        final p = firstDetail.seriesPlot?.trim();
        if (p != null && p.isNotEmpty) {
          mergedPlot = p;
        }
        for (final e in firstDetail.episodes) {
          _takeSeriesEpisodeBySlot(byEpisodeSlot, e);
        }
        final initialList = byEpisodeSlot.values.toList()
          ..sort((a, b) {
            final c = a.season.compareTo(b.season);
            if (c != 0) return c;
            return a.episodeNumber.compareTo(b.episodeNumber);
          });
        applyEpisodeState(initialList, synopsis: mergedPlot);
      }

      final others = capped.where((item) => item.id != rep.id).toList();
      final int batchSize = _app.layoutMode.value == AppLayoutMode.tv ? 4 : 8;
      for (var i = 0; i < others.length; i += batchSize) {
        final end = (i + batchSize).clamp(0, others.length);
        final batch = others.sublist(i, end);
        final details = await Future.wait(
          batch.map((item) async {
            try {
              return await loadDetail(item);
            } catch (_) {
              return const XtreamSeriesBrowseDetail(episodes: []);
            }
          }),
        );
        if (isClosed || requestToken != _seriesEpisodesLoadToken) return;
        for (final d in details) {
          final p = d.seriesPlot?.trim();
          if (p != null && p.isNotEmpty && p.length > mergedPlot.length) {
            mergedPlot = p;
          }
          for (final e in d.episodes) {
            _takeSeriesEpisodeBySlot(byEpisodeSlot, e);
          }
        }
        final mergedList = byEpisodeSlot.values.toList()
          ..sort((a, b) {
            final c = a.season.compareTo(b.season);
            if (c != 0) return c;
            return a.episodeNumber.compareTo(b.episodeNumber);
          });
        applyEpisodeState(mergedList, synopsis: mergedPlot);
      }
    } catch (_) {
      if (isClosed || requestToken != _seriesEpisodesLoadToken) return;
      seriesEpisodesError.value = 'Bölümler yüklenemedi.';
    } finally {
      if (!isClosed && requestToken == _seriesEpisodesLoadToken) {
        seriesEpisodesLoading.value = false;
        _scheduleSeriesDetailPreview();
      }
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
    final prev = selectedSeriesEpisode.value;
    final isSame = prev != null &&
        prev.channel.id == opt.channel.id &&
        prev.season == opt.season &&
        prev.episodeNumber == opt.episodeNumber;
    if (isSame) {
      final ctx = Get.context;
      if (ctx != null &&
          MediaQuery.orientationOf(ctx) == Orientation.portrait) {
        unawaited(openSelectedPlayer());
      }
      return;
    }
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
        autoPlay: false,
        fit: BoxFit.contain,
        controlsConfiguration: const BetterPlayerControlsConfiguration(
          showControls: false,
        ),
        handleLifecycle: false,
        autoDispose: false,
        fullScreenByDefault: false,
        allowedScreenSleep: false,
        muteAudioBeforeDataSource: true,
      );

      final previewLive = IptvPlaybackDefaults.isLikelyLiveStream(streamUrl);
      final ds = iptvBetterPlayerDataSource(
        streamUrl,
        liveStream: previewLive,
        preferSoftwareVideoDecoder:
            false, // VOD için her zaman donanım dekoderi
        useAsmsAudioTracks: null, // Otomatik seçime (Adaptive tespiti) bırak
        liveBufferSeconds: previewLive
            ? _app.liveBufferSeconds.value
            : IptvBetterPlayerConfig.defaultLiveBufferSecondsForExo,
      );

      final ctrl = BetterPlayerController(cfg);
      await ctrl.setupDataSource(ds);
      await iptvApplyBetterPlayerLowRam720CapIfNeeded(ctrl);
      await ctrl.setVolume(0);
      await ctrl.play();
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
    if (row.series != null) {
      final ids =
          row.seriesCluster?.map((e) => e.id).toList() ?? <int>[row.series!.id];
      return _fav.hasAnySeries(ids);
    }
    return false;
  }

  void toggleFavorite(BrowseRow row) {
    if (row.channel != null) {
      _fav.toggleChannel(row.channel!.id);
    } else if (row.vod != null) {
      _fav.toggleVod(row.vod!.id);
    } else if (row.series != null) {
      final ids =
          row.seriesCluster?.map((e) => e.id).toList() ?? <int>[row.series!.id];
      if (ids.length > 1) {
        _fav.toggleSeriesGroup(ids);
      } else {
        _fav.toggleSeries(ids.first);
      }
    }
    if (mode == BrowseMode.favorites) {
      Future.microtask(_ensureSelection);
    }
  }

  Future<void> _applyRouteSearchIntentFromHome() async {
    final d = _data;
    if (d == null) {
      _ensureSelection(fromPlaylistRestore: true);
      return;
    }
    if (_routeInitialCategoryId != null) {
      final cid = _routeInitialCategoryId!;
      _routeInitialCategoryId = null;
      if (mode == BrowseMode.films && !_vodCategoryHidden(cid)) {
        selectedCategoryKey.value = cid;
      } else if (mode == BrowseMode.series && !_seriesCategoryHidden(cid)) {
        selectedCategoryKey.value = cid;
      }
    }
    if (_routeInitialSearch != null && _routeInitialSearch!.trim().isNotEmpty) {
      final t = _routeInitialSearch!.trim();
      searchQuery.value = t;
      searchController.text = t;
    }

    if (mode == BrowseMode.films && _routePickVodId != null) {
      final want = _routePickVodId!;
      for (final v in d.vod) {
        if (v.id == want) {
          selectedCategoryKey.value = v.categoryId;
          var rows = filteredRows;
          var idx = rows.indexWhere((r) => r.vod?.id == v.id);
          if (idx < 0) {
            selectedCategoryKey.value = kAllCategories;
            rows = filteredRows;
            idx = rows.indexWhere((r) => r.vod?.id == v.id);
          }
          final li = idx >= 0 ? idx + 1 : 1;
          final row = BrowseRow(listIndex: li, title: v.name, vod: v);
          _applyBrowseRowSelection(row);
          await _loadSeriesEpisodes(row.series!,
              requestToken: ++_seriesEpisodesLoadToken);
          _routePickVodId = null;
          _routePickSeriesId = null;
          _routeInitialSearch = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (isClosed) return;
            unawaited(openRowPlayer(row));
          });
          return;
        }
      }
    }

    if (mode == BrowseMode.series && _routePickSeriesId != null) {
      final want = _routePickSeriesId!;
      for (final s in d.series) {
        if (s.id == want) {
          selectedCategoryKey.value = s.categoryId;
          var rows = filteredRows;
          var idx = -1;
          for (var i = 0; i < rows.length; i++) {
            final r = rows[i];
            if (r.series == null) continue;
            if (r.seriesCluster != null) {
              if (r.seriesCluster!.any((x) => x.id == s.id)) {
                idx = i;
                break;
              }
            } else if (r.series!.id == s.id) {
              idx = i;
              break;
            }
          }
          if (idx < 0) {
            selectedCategoryKey.value = kAllCategories;
            rows = filteredRows;
            for (var i = 0; i < rows.length; i++) {
              final r = rows[i];
              if (r.series == null) continue;
              if (r.seriesCluster != null) {
                if (r.seriesCluster!.any((x) => x.id == s.id)) {
                  idx = i;
                  break;
                }
              } else if (r.series!.id == s.id) {
                idx = i;
                break;
              }
            }
          }
          final li = idx >= 0 ? idx + 1 : 1;
          final picked = idx >= 0 ? rows[idx] : null;
          final row = picked != null
              ? BrowseRow(
                  listIndex: li,
                  title: picked.title,
                  series: picked.series,
                  seriesCluster: picked.seriesCluster,
                )
              : BrowseRow(listIndex: li, title: s.name, series: s);
          // Ana ekran birleşik arama: diziyi doğrudan oynatma; kategori + liste içinde konumlandır.
          if (_app.layoutMode.value == AppLayoutMode.tv) {
            tvTrapFocusInBrowseList.value = true;
            tvBrowseDetailUnlocked.value = true;
          }
          _applyBrowseRowSelection(row);
          await _loadSeriesEpisodes(row.series!,
              requestToken: ++_seriesEpisodesLoadToken);
          _routePickVodId = null;
          _routePickSeriesId = null;
          _routeInitialSearch = null;

          if (_app.layoutMode.value == AppLayoutMode.tv) {
            tvBrowseDetailUnlocked.value = true;
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (isClosed) return;
            _scheduleScrollBrowseListToFocusedRow();
            if (_app.layoutMode.value == AppLayoutMode.tv &&
                browseSeriesDetailFocusNode.canRequestFocus) {
              browseSeriesDetailFocusNode.requestFocus();
            }
            // Direct navigation to series detail/episodes screen from home search
            // openSeriesEpgDialog();
            selectedTabIndex.value = 2;
          });
          return;
        }
      }
    }

    _routePickVodId = null;
    _routePickSeriesId = null;
    _routeInitialSearch = null;
    if (_landingFromHomeSearch) {
      _landingFromHomeSearch = false;
      _ensureSelection();
      return;
    }
    _restoreLastSelection();
  }

  void _restoreLastSelection() {
    final d = _data;
    if (d == null) {
      _ensureSelection(fromPlaylistRestore: true);
      return;
    }

    if (mode == BrowseMode.films) {
      var cat = _app.lastFilmsCategoryKey.value;
      if (cat != null && cat != kAllCategories && _vodCategoryHidden(cat)) {
        cat = kAllCategories;
      }
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
      _ensureSelection(fromPlaylistRestore: true);
      return;
    }

    if (mode == BrowseMode.series) {
      var cat = _app.lastSeriesCategoryKey.value;
      if (cat != null && cat != kAllCategories && _seriesCategoryHidden(cat)) {
        cat = kAllCategories;
      }
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
          final seriesFound = found;
          selectedCategoryKey.value = cat ?? seriesFound.categoryId;
          final wantId = seriesFound.id;
          BrowseRow? match;
          for (final r in filteredRows) {
            if (r.series == null) continue;
            if (r.seriesCluster != null) {
              if (r.seriesCluster!.any((x) => x.id == wantId)) {
                match = r;
                break;
              }
            } else if (r.series!.id == wantId) {
              match = r;
              break;
            }
          }
          final row = match ??
              BrowseRow(
                  listIndex: 0, title: seriesFound.name, series: seriesFound);
          if (_app.layoutMode.value == AppLayoutMode.tv) {
            _applyBrowseRowSelection(row);
          } else {
            selectRow(row);
          }
          return;
        }
      }
      _ensureSelection(fromPlaylistRestore: true);
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
                BrowseRow? match;
                for (final r in filteredRows) {
                  if (r.series == null) continue;
                  if (r.seriesCluster != null) {
                    if (r.seriesCluster!.any((x) => x.id == s.id)) {
                      match = r;
                      break;
                    }
                  } else if (r.series!.id == s.id) {
                    match = r;
                    break;
                  }
                }
                final row =
                    match ?? BrowseRow(listIndex: 0, title: s.name, series: s);
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

    _ensureSelection(fromPlaylistRestore: true);
  }

  Future<void> _logPlaylistSourceForSeries() async {
    try {
      final src = await _playlist.readSource();
      if (kDebugMode) {
        debugPrint('mina_series_play: playlistSource=${src.runtimeType}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('mina_series_play: readSource error=$e');
      }
    }
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
        if (kDebugMode) {
          debugPrint(
            'mina_series_play: openSelectedPlayer via episode '
            '"${ep.displayTitle}" urlLen=${ep.channel.streamUrl.length}',
          );
        }
        _openPlayerRoute(selectedRow.value!, ep.channel);
        return;
      }
      if (kDebugMode) {
        debugPrint(
          'mina_series_play: openSelectedPlayer no episode '
          '(options=${seriesEpisodeOptions.length}) — fallback openRowPlayer',
        );
      }
    }
    await openRowPlayer(row);
  }

  Future<void> openRowPlayer(BrowseRow row) async {
    var ch = row.playerChannel;
    if (row.series != null) {
      if (kDebugMode) {
        debugPrint(
          'mina_series_play: openRowPlayer series="${row.series!.name}" '
          'id=${row.series!.id} chFromRow=${ch != null} '
          'episodes=${seriesEpisodeOptions.length} '
          'selEp=${selectedSeriesEpisode.value != null}',
        );
      }
      unawaited(_logPlaylistSourceForSeries());
    }
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
        if (kDebugMode) {
          debugPrint(
            'mina_series_play: resolveXtreamSeriesFirstEpisode -> null '
            '(M3U kaynakta dizi URL’si yoksa veya Xtream değilse beklenen)',
          );
        }
        GlassSnackbar.show(
          'Dizi',
          'Bölüm bulunamadı veya kaynak Xtream değil.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      if (kDebugMode) {
        debugPrint(
          'mina_series_play: resolved channel streamUrl len=${ch.streamUrl.length}',
        );
      }
    } else if (ch == null) {
      if (kDebugMode) {
        debugPrint('mina_series_play: no channel and no series — abort');
      }
      return;
    }
    _previewDebounce?.cancel();
    await _stopPreview();
    _openPlayerRoute(row, ch);
  }

  List<PlayerBrowseCategoryTape<Channel>>? _movieBrowseCategoryTapesFromData(
    M3uResult d, {
    required bool favoritesOnly,
  }) {
    var vods = d.vod.where((v) => !_vodItemHidden(v));
    if (favoritesOnly) {
      final ids = _fav.vodIds.toSet();
      vods = vods.where((v) => ids.contains(v.id));
    }
    final byCat = <int, List<VodItem>>{};
    for (final v in vods) {
      byCat.putIfAbsent(v.categoryId, () => []).add(v);
    }
    if (byCat.length <= 1) return null;
    String nameFor(int catId) {
      for (final c in d.vodCategories) {
        if (c.id == catId) return c.name;
      }
      return '#$catId';
    }

    final order = <int, int>{};
    for (var i = 0; i < d.vodCategories.length; i++) {
      order[d.vodCategories[i].id] = i;
    }
    final tapes = <PlayerBrowseCategoryTape<Channel>>[];
    for (final e in byCat.entries) {
      final sorted = List<VodItem>.from(e.value)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      tapes.add(PlayerBrowseCategoryTape(
        categoryId: e.key,
        name: nameFor(e.key),
        items: [
          for (final v in sorted)
            Channel(
              id: v.id,
              name: v.name,
              streamUrl: v.streamUrl,
              categoryId: v.categoryId,
              logoUrl: v.posterUrl,
            ),
        ],
      ));
    }
    tapes.sort((a, b) => (order[a.categoryId] ?? 999999)
        .compareTo(order[b.categoryId] ?? 999999));
    return tapes;
  }

  List<PlayerBrowseCategoryTape<SeriesItem>>?
      _seriesBrowseCategoryTapesFromData(
    M3uResult d, {
    required bool favoritesOnly,
  }) {
    var ser = d.series.where((s) => !_seriesItemHidden(s));
    if (favoritesOnly) {
      final ids = _fav.seriesIds.toSet();
      ser = ser.where((s) => ids.contains(s.id));
    }
    final byCat = <int, List<SeriesItem>>{};
    for (final s in ser) {
      byCat.putIfAbsent(s.categoryId, () => []).add(s);
    }
    if (byCat.length <= 1) return null;
    String nameFor(int catId) {
      for (final c in d.seriesCategories) {
        if (c.id == catId) return c.name;
      }
      return '#$catId';
    }

    final order = <int, int>{};
    for (var i = 0; i < d.seriesCategories.length; i++) {
      order[d.seriesCategories[i].id] = i;
    }
    final tapes = <PlayerBrowseCategoryTape<SeriesItem>>[];
    for (final e in byCat.entries) {
      final sorted = List<SeriesItem>.from(e.value)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      tapes.add(PlayerBrowseCategoryTape(
        categoryId: e.key,
        name: nameFor(e.key),
        items: sorted,
      ));
    }
    tapes.sort((a, b) => (order[a.categoryId] ?? 999999)
        .compareTo(order[b.categoryId] ?? 999999));
    return tapes;
  }

  /// TV’de liste odak düğümü üst rotada kalmasın (kanallar ekranı ile aynı düzeltme).
  void _openPlayerRoute(BrowseRow contextRow, Channel ch) {
    List<Channel>? movieTape;
    List<SeriesItem>? seriesTape;
    SeriesItem? playingSeries;
    List<SeriesEpisodeOption>? episodeTape;
    List<PlayerBrowseCategoryTape<Channel>>? movieCategoryTapes;
    List<PlayerBrowseCategoryTape<SeriesItem>>? seriesCategoryTapes;

    final d = _data;
    final qEmpty = searchQuery.value.trim().isEmpty;
    if (d != null && qEmpty) {
      if (mode == BrowseMode.films && contextRow.vod != null) {
        movieCategoryTapes =
            _movieBrowseCategoryTapesFromData(d, favoritesOnly: false);
      } else if (mode == BrowseMode.series && contextRow.series != null) {
        seriesCategoryTapes =
            _seriesBrowseCategoryTapesFromData(d, favoritesOnly: false);
      } else if (mode == BrowseMode.favorites) {
        if (contextRow.vod != null) {
          movieCategoryTapes =
              _movieBrowseCategoryTapesFromData(d, favoritesOnly: true);
        } else if (contextRow.series != null) {
          seriesCategoryTapes =
              _seriesBrowseCategoryTapesFromData(d, favoritesOnly: true);
        }
      }
    }

    if (mode == BrowseMode.films && contextRow.vod != null) {
      movieTape = [
        for (final r in filteredRows)
          if (r.vod != null && r.playerChannel != null) r.playerChannel!,
      ];
    } else if (mode == BrowseMode.series && contextRow.series != null) {
      seriesTape = <SeriesItem>[
        for (final r in filteredRows)
          if (r.series != null)
            if (r.seriesCluster != null && r.seriesCluster!.length > 1) ...[
              ...List<SeriesItem>.from(r.seriesCluster!)
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                ),
            ] else
              r.series!,
      ];
      playingSeries = contextRow.series;
      if (seriesEpisodeOptions.isNotEmpty) {
        episodeTape = List<SeriesEpisodeOption>.from(seriesEpisodeOptions);
      }
    } else if (mode == BrowseMode.favorites) {
      if (contextRow.vod != null) {
        movieTape = [
          for (final r in filteredRows)
            if (r.vod != null && r.playerChannel != null) r.playerChannel!,
        ];
      } else if (contextRow.series != null) {
        seriesTape = <SeriesItem>[
          for (final r in filteredRows)
            if (r.series != null)
              if (r.seriesCluster != null && r.seriesCluster!.length > 1) ...[
                ...List<SeriesItem>.from(r.seriesCluster!)
                  ..sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  ),
              ] else
                r.series!,
        ];
        playingSeries = contextRow.series;
        if (seriesEpisodeOptions.isNotEmpty) {
          episodeTape = List<SeriesEpisodeOption>.from(seriesEpisodeOptions);
        }
      }
    }

    final args = PlayerScreenArgs(
      channel: ch,
      movieBrowseTape: movieTape,
      seriesBrowseTape: seriesTape,
      playingSeriesInTape: playingSeries,
      episodeBrowseTape: episodeTape,
      movieBrowseCategoryTapes: movieCategoryTapes,
      seriesBrowseCategoryTapes: seriesCategoryTapes,
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

  /// Portre gözat (mobil/tablet): detay → liste → kategoriler → [goBack]. TV düzeninde kullanılmaz.
  void onPortraitBrowseStepBack(BuildContext context) {
    final tc = DefaultTabController.maybeOf(context);
    if (tc == null) {
      goBack();
      return;
    }
    if (tc.index == 1 && searchQuery.value.trim().isNotEmpty) {
      searchQuery.value = '';
      searchController.clear();
      tc.animateTo(0);
      return;
    }
    if (tc.index > 0) {
      tc.animateTo(tc.index - 1);
    } else {
      goBack();
    }
  }

  /// TV: üst çubuk geri — kategori tuzağındaysa önce sol sütuna dön.
  void onTopBarBack() {
    if (_effectiveRemoteNav() && tvTrapFocusInBrowseList.value) {
      releaseTvBrowseListFocusToCategories();
    } else {
      goBack();
    }
  }
}

/// Film filtre isolate'i için veri seti başına bir kez kurulan, küçük-harf
/// adlar dahil düz projeksiyon. Weak-key Expando ile [M3uResult] kimliğine
/// bağlanır; liste geçişlerinde her seferinde yeniden hesaplanmaz.
class _VodFilterProjection {
  const _VodFilterProjection({
    required this.ids,
    required this.namesLower,
    required this.categoryIds,
  });

  final List<int> ids;
  final List<String> namesLower;
  final List<int> categoryIds;
}
