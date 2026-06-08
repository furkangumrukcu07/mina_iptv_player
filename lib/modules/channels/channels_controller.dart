import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_deferred_load_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/iptv_precache_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/playlist_category_hide.dart';
import '../../core/services/search_history_service.dart';
import 'package:better_player_plus/better_player_plus.dart';
import '../../core/player/better_player_iptv_config.dart'
    show
        IptvBetterPlayerConfig,
        iptvApplyBetterPlayerLowRam720CapIfNeeded,
        iptvBetterPlayerDataSource;
import '../../core/player/iptv_playback_defaults.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../services/user_history_service.dart';
import '../../ui/glass_tv_shell.dart';

/// Sanal "Favoriler" kategorisi için sentinel kimliği. Gerçek M3U/Xtream
/// kategorileri her zaman > 0 olduğundan negatif sabit çatışma yaratmaz.
/// Aynı sabit `_PortraitLiveTvPanel`'da da kullanılır.
const int kFavoritesVirtualCategoryId = -1;

/// Sanal "Son İzlenenler" kategorisi — kullanıcının son 20 farklı canlı
/// kanalını listeler. Yalnızca [UserHistoryService] içinde `kind == live`
/// kayıt varsa görünür; aksi halde kategori UI'da gizlenir.
const int kRecentlyWatchedVirtualCategoryId = -2;

/// "Son İzlenenler" sanal kategorisinde gösterilecek azami canlı kanal
/// sayısı (en yeni → en eski).
const int kRecentlyWatchedLiveLimit = 20;

class ChannelsController extends GetxController {
  static const _previewFocusHoldDelay = Duration(seconds: 2);

  bool _effectiveRemoteNav() {
    final m = _app.layoutMode.value;
    if (m.usesRemoteNavigationStyle) return true;
    if (m != AppLayoutMode.mobile) return false;
    final ctx = Get.context;
    if (ctx == null) return false;
    final s = MediaQuery.sizeOf(ctx);
    return s.width >= s.height;
  }

  final _cache = Get.find<PlaylistCacheService>();
  final _fav = Get.find<FavoritesService>();
  final _app = Get.find<AppSettingsService>();

  final selectedCategoryId = Rxn<int>();
  final selectedChannel = Rxn<Channel>();
  final searchQuery = ''.obs;
  final effectiveSearchQuery = ''.obs;

  final now = DateTime.now().obs;

  /// "Listeler" barından farklı bir listeye geçildiğinde artar — kategori
  /// paneli ve kanal listesi `Obx`'lerini yeniden çizmek için.
  final playlistRevision = 0.obs;

  Timer? _clock;
  Timer? _precacheDebounce;
  Timer? _previewDebounce;
  Worker? _searchDebounceWorker;
  Worker? _cacheWorker;
  Worker? _hideAdultWorker;
  int? _visibleChannelsCacheKey;
  List<Channel>? _visibleChannelsCache;
  int? _filteredChannelsCacheKey;
  List<Channel>? _filteredChannelsCache;

  /// Hızlı listede gezinirken eski [setupDataSource]/[play] tamamlanırsa iptal.
  int _previewLoadGeneration = 0;

  final searchController = TextEditingController();

  BetterPlayerController? previewController;
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

  /// Mobil portre kategori listesi kaydırması — seçili satırı görünür tutmak için.
  ScrollController? _categoryListScroll;

  /// Mobil portre [TabController] — oynatıcıdan dönüşte sekme sıfırlanmasın diye
  /// StatefulWidget içinde tutulur; geri adımı buradan okunur.
  TabController? _portraitTabController;

  /// Çift KeyDown / hızlı tekrarın aynı karede iki satır atlamasını önler.
  int? _lastTvChannelNudgeMs;

  M3uResult? _data;

  /// [Get.arguments] ile `{'openSearch': true}` gelince ilk karede arama popup’ı.
  bool _pendingOpenSearch = false;

  /// Ana ekrandan canlı TV: ilk kategori satırı + ilk kanal seçimi ve kategori odağı.
  bool _resetLiveSelectionFromHome = false;

  /// Ana ekran birleşik arama: doğrudan kanal seçimi.
  int? _routePickChannelId;
  String? _routeInitialSearch;

  /// Ana ekran birleşik arama: filtre + isteğe bağlı kategori; son kayıt geri yüklemesini atla.
  bool _routeHomeUnifiedSearch = false;
  int? _routeHomeUnifiedChannelCategoryId;

  M3uResult? get snapshot => _data;

  List<ChannelCategory> get categories {
    final raw = _data?.channelCategories ?? [];
    final visible = raw
        .where((c) => !PlaylistCategoryHide.liveCategoryRowHidden(
              _app,
              _cache,
              c,
            ))
        .toList();
    return PlaylistCategoryHide.orderLiveCategories(_app, _cache, visible);
  }

  @override
  void onInit() {
    super.onInit();
    final value = _cache.result.value;
    if (value == null) {
      Future.microtask(() => Get.offAllNamed(AppRoutes.playlist));
      return;
    }
    _data = value;
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
        (a is Map &&
            (a['openSearch'] == true || a['openSearch'] == 'true'));
    _resetLiveSelectionFromHome = a is Map &&
        (a['resetLiveSelection'] == true || a['resetLiveSelection'] == 'true');
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
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      now.value = DateTime.now();
    });
    Future.microtask(_restoreLastSelection);
  }

  void _onChannelsListFocusChanged() {
    if (!channelsListFocusNode.hasFocus) return;
    if (!_effectiveRemoteNav()) return;
    tvTrapFocusInChannelList.value = true;
  }

  /// Aktif playlist (gösterilen liste) değiştiğinde — önbellek yeni slot'un
  /// içeriğiyle güncellenir. `_data`'yı tazele, kategori/kanal önbelleklerini
  /// boşalt ve panelleri yeniden çiz. Seçili kategori yeni listede yoksa
  /// "Tümü"ne döner.
  void _onActivePlaylistChanged(M3uResult? value) {
    if (value == null) return;
    if (identical(value, _data)) return;
    _data = value;
    _invalidateChannelListCaches();
    final sel = selectedCategoryId.value;
    final stillExists = sel == null ||
        sel == kFavoritesVirtualCategoryId ||
        sel == kRecentlyWatchedVirtualCategoryId ||
        (_data?.channelCategories.any((c) => c.id == sel) ?? false);
    if (!stillExists) {
      selectedCategoryId.value = null;
    }
    playlistRevision.value++;
    _ensureSelectionInList();
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

  /// Üst çubuk ile aynı cam arama diyaloğu (ana ekrandan yönlendirme için).
  void openChannelSearchPopup() {
    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) return;
    unawaited(
      showGlassChannelSearchDialog(
        context: ctx,
        searchController: searchController,
        onSearchChanged: onSearchChanged,
        searchHint: 'channels.search'.tr,
        historyScope: SearchHistoryScope.liveTv,
      ),
    );
  }

  @override
  void onClose() {
    stopTvChannelListVerticalHold();
    _invalidateChannelListCaches();
    _clock?.cancel();
    _precacheDebounce?.cancel();
    _previewDebounce?.cancel();
    _searchDebounceWorker?.dispose();
    _cacheWorker?.dispose();
    _hideAdultWorker?.dispose();
    try {
      final old = previewController;
      previewController = null;
      if (old != null) {
        old.pause();
        old.dispose(forceDispose: true);
      }
    } catch (_) {}
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

  List<Channel> get visibleChannels {
    final base = _data?.channels ?? const <Channel>[];
    final id = selectedCategoryId.value;
    final d = _data;
    if (d == null) return base;
    // Sanal "Favoriler" kategorisi seçildiyse cache anahtarına favori sayısını
    // ekle — favori toggle'ı RxList değişimini panel `Obx`'leri üzerinden de
    // tetikler, ancak cache invalidation kaynak listede uzunluk değişmedikçe
    // tutarsız kalmasın.
    final favLen = id == kFavoritesVirtualCategoryId ? _fav.channelIds.length : 0;
    // "Son İzlenenler" sanal kategorisi seçildiyse cache anahtarına
    // [UserHistoryService.revision] eklenir — yeni izleme kayıt edildiğinde
    // liste senkron olarak tazelenir.
    final histRev = id == kRecentlyWatchedVirtualCategoryId
        ? _userHistoryRevisionSafe()
        : 0;
    final cacheKey = Object.hash(
      d.hashCode,
      d.channels.length,
      id,
      favLen,
      histRev,
      _app.xtreamHideRevision.value,
    );
    if (_visibleChannelsCacheKey == cacheKey && _visibleChannelsCache != null) {
      return _visibleChannelsCache!;
    }
    final List<Channel> result;
    if (id == null) {
      result = base
          .where(
            (c) => !PlaylistCategoryHide.channelHiddenInLive(
              _app,
              _cache,
              d,
              c,
            ),
          )
          .toList();
    } else if (id == kFavoritesVirtualCategoryId) {
      // Sanal "Favoriler" kategorisi — kullanıcının kalp ile eklediği canlı
      // kanallar; gizli kategorideki kanallar yine süzülür.
      result = base
          .where(
            (c) =>
                _fav.hasChannel(c.id) &&
                !PlaylistCategoryHide.channelHiddenInLive(
                  _app,
                  _cache,
                  d,
                  c,
                ),
          )
          .toList();
    } else if (id == kRecentlyWatchedVirtualCategoryId) {
      // Sanal "Son İzlenenler" — UserHistory snapshot'ından son 20 unique
      // canlı kanal; UserHistory sırası (en yeni önce) korunur.
      final orderedIds = _recentlyWatchedLiveChannelIds();
      if (orderedIds.isEmpty) {
        result = const <Channel>[];
      } else {
        final byId = <int, Channel>{
          for (final c in base) c.id: c,
        };
        final out = <Channel>[];
        for (final cid in orderedIds) {
          final ch = byId[cid];
          if (ch == null) continue;
          if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, ch)) {
            continue;
          }
          out.add(ch);
        }
        result = out;
      }
    } else {
      result = base
          .where(
            (c) =>
                c.categoryId == id &&
                !PlaylistCategoryHide.channelHiddenInLive(
                  _app,
                  _cache,
                  d,
                  c,
                ),
          )
          .toList();
    }
    _visibleChannelsCacheKey = cacheKey;
    _visibleChannelsCache = result;
    return result;
  }

  List<Channel> get filteredChannels {
    final list = visibleChannels;
    final q = effectiveSearchQuery.value;
    final cacheKey = Object.hash(_visibleChannelsCacheKey, q);
    if (_filteredChannelsCacheKey == cacheKey &&
        _filteredChannelsCache != null) {
      return _filteredChannelsCache!;
    }
    if (q.isEmpty) {
      _filteredChannelsCacheKey = cacheKey;
      _filteredChannelsCache = list;
      return list;
    }
    final result = list.where((c) => c.name.toLowerCase().contains(q)).toList();
    _filteredChannelsCacheKey = cacheKey;
    _filteredChannelsCache = result;
    return result;
  }

  int countForCategory(int? categoryId) {
    final all = _data?.channels ?? [];
    final d = _data;
    if (d == null) return all.length;
    if (categoryId == null) {
      return all
          .where(
            (c) => !PlaylistCategoryHide.channelHiddenInLive(
              _app,
              _cache,
              d,
              c,
            ),
          )
          .length;
    }
    if (categoryId == kFavoritesVirtualCategoryId) {
      return all
          .where(
            (c) =>
                _fav.hasChannel(c.id) &&
                !PlaylistCategoryHide.channelHiddenInLive(
                  _app,
                  _cache,
                  d,
                  c,
                ),
          )
          .length;
    }
    if (categoryId == kRecentlyWatchedVirtualCategoryId) {
      return _recentlyWatchedVisibleCount();
    }
    return all
        .where(
          (c) =>
              c.categoryId == categoryId &&
              !PlaylistCategoryHide.channelHiddenInLive(
                _app,
                _cache,
                d,
                c,
              ),
        )
        .length;
  }

  /// `UserHistoryService` kayıtlı değilse 0 döner — uygulama erken aşamada
  /// kategori panelini bu metoda göre sayım gösterirken çakışmasın.
  int _userHistoryRevisionSafe() {
    if (!Get.isRegistered<UserHistoryService>()) return 0;
    return Get.find<UserHistoryService>().revision.value;
  }

  /// Son izlenen canlı kanalların ID dizisi (en yeni önce, max 20 unique).
  List<int> _recentlyWatchedLiveChannelIds() {
    if (!Get.isRegistered<UserHistoryService>()) return const <int>[];
    final history = Get.find<UserHistoryService>().snapshotSync();
    if (history.isEmpty) return const <int>[];
    final filtered = history
        .where((e) => e.kind == UserHistoryKind.live)
        .toList(growable: false)
      ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    if (filtered.isEmpty) return const <int>[];
    final out = <int>[];
    final seen = <int>{};
    for (final e in filtered) {
      if (seen.contains(e.contentId)) continue;
      seen.add(e.contentId);
      out.add(e.contentId);
      if (out.length >= kRecentlyWatchedLiveLimit) break;
    }
    return out;
  }

  /// "Son İzlenenler" satırında **fiilen görünür** olacak kanal sayısı —
  /// UserHistory ID'lerinden playlist'te bulunan + gizli olmayanları sayar.
  int _recentlyWatchedVisibleCount() {
    final ids = _recentlyWatchedLiveChannelIds();
    if (ids.isEmpty) return 0;
    final d = _data;
    if (d == null) return 0;
    final byId = <int, Channel>{
      for (final c in d.channels) c.id: c,
    };
    var n = 0;
    for (final cid in ids) {
      final ch = byId[cid];
      if (ch == null) continue;
      if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, ch)) {
        continue;
      }
      n++;
    }
    return n;
  }

  /// Kategori panelinde "Son İzlenenler" satırının görünüp görünmeyeceği —
  /// hiç kayıt yoksa satır gizlenir.
  bool get hasRecentlyWatchedLiveChannels =>
      _recentlyWatchedVisibleCount() > 0;

  void _invalidateChannelListCaches() {
    _visibleChannelsCacheKey = null;
    _visibleChannelsCache = null;
    _filteredChannelsCacheKey = null;
    _filteredChannelsCache = null;
    _categoryCountCacheKey = null;
    _categoryCountCache = null;
  }

  String? _categoryCountCacheKey;
  ({
    int allVisibleCount,
    int favoritesVisibleCount,
    int recentlyWatchedVisibleCount,
    Map<int, int> categoryCounts,
  })? _categoryCountCache;

  String _buildCategoryCountCacheKey() {
    final d = _data;
    if (d == null) return 'null';
    return Object.hash(
      identityHashCode(d),
      _app.xtreamHideRevision.value,
      _cache.layoutRevision.value,
      _fav.channelIds.length,
      _userHistoryRevisionSafe(),
    ).toString();
  }

  ({
    int allVisibleCount,
    int favoritesVisibleCount,
    int recentlyWatchedVisibleCount,
    Map<int, int> categoryCounts,
  }) categoryCountSnapshot() {
    final cacheKey = _buildCategoryCountCacheKey();
    if (_categoryCountCacheKey == cacheKey && _categoryCountCache != null) {
      return _categoryCountCache!;
    }
    final d = _data;
    if (d == null) {
      const empty = (
        allVisibleCount: 0,
        favoritesVisibleCount: 0,
        recentlyWatchedVisibleCount: 0,
        categoryCounts: <int, int>{},
      );
      _categoryCountCacheKey = cacheKey;
      _categoryCountCache = empty;
      return empty;
    }
    final counts = <int, int>{};
    var visibleAll = 0;
    var favCount = 0;
    for (final channel in d.channels) {
      if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, channel)) {
        continue;
      }
      visibleAll++;
      if (_fav.hasChannel(channel.id)) favCount++;
      counts[channel.categoryId] = (counts[channel.categoryId] ?? 0) + 1;
    }
    final snapshot = (
      allVisibleCount: visibleAll,
      favoritesVisibleCount: favCount,
      recentlyWatchedVisibleCount: _recentlyWatchedVisibleCount(),
      categoryCounts: counts,
    );
    _categoryCountCacheKey = cacheKey;
    _categoryCountCache = snapshot;
    return snapshot;
  }

  bool isFavorite(Channel c) => _fav.hasChannel(c.id);

  void toggleFavorite(Channel c) => _fav.toggleChannel(c.id);

  void onSearchChanged(String v) {
    final normalized = v.trim().toLowerCase();
    if (searchQuery.value == normalized) return;
    searchQuery.value = normalized;
    _invalidateChannelListCaches();
  }

  void selectCategory(int? categoryId, {bool moveFocusToChannels = false}) {
    final prevCategory = selectedCategoryId.value;
    _invalidateChannelListCaches();
    selectedCategoryId.value = categoryId;
    unawaited(_app.setLastLiveCategoryId(categoryId));
    tvDetailColumnUnlocked.value = false;
    if (moveFocusToChannels) {
      final list = filteredChannels;
      if (list.isEmpty) {
        selectedChannel.value = null;
      } else {
        final first = list.first;
        selectedChannel.value = first;
        unawaited(_app.setLastLiveChannelId(first.id));
        _schedulePrecache(first.streamUrl);
        _schedulePreview(first);
      }
      tvTrapFocusInChannelList.value = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (channelsListFocusNode.canRequestFocus) {
          channelsListFocusNode.requestFocus();
        }
        _scheduleScrollLiveListToFocusedRow();
      });
    } else {
      // Kategori değişince (ok ile sağa geçerken) her zaman 1. sıradan başla;
      // aynı kategoride sadece odağı kanallara taşıyorsak önceki seçimi koru.
      if (prevCategory != categoryId) {
        final list = filteredChannels;
        if (list.isEmpty) {
          selectedChannel.value = null;
        } else {
          final first = list.first;
          selectedChannel.value = first;
          unawaited(_app.setLastLiveChannelId(first.id));
          _schedulePrecache(first.streamUrl);
          _schedulePreview(first);
        }
      } else {
        _ensureSelectionInList();
      }
    }
  }

  /// TV: kumanda ile kategori satırına gelindiğinde tuzak kalkar; odak çerçevesi görünür.
  void syncTvCategoryFocusFromRow(int? categoryId) {
    if (!_effectiveRemoteNav()) return;
    tvTrapFocusInChannelList.value = false;
    if (selectedCategoryId.value != categoryId) {
      selectCategory(categoryId, moveFocusToChannels: false);
    }
  }

  void releaseTvListFocusToCategories() {
    tvTrapFocusInChannelList.value = false;
    tvDetailColumnUnlocked.value = false;
    final ch = selectedChannel.value;
    if (ch != null) {
      selectedCategoryId.value = ch.categoryId;
      unawaited(_app.setLastLiveCategoryId(ch.categoryId));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // focusNode seçili kategori satırına taşındıktan sonra odak ver.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (categoryFocusNode.canRequestFocus) {
          categoryFocusNode.requestFocus();
        }
      });
    });
  }

  void _pumpFocusToTvPreview() {
    if (!_effectiveRemoteNav()) return;
    if (!tvDetailColumnUnlocked.value) return;
    channelsListFocusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!tvDetailColumnUnlocked.value) return;
      if (detailPreviewFocusNode.canRequestFocus) {
        detailPreviewFocusNode.requestFocus();
      }
    });
  }

  /// Detay zaten açıkken sağ ok: yalnızca önizleme odak (unlock tekrar etme).
  void focusTvDetailPreview() {
    if (!_effectiveRemoteNav()) return;
    if (!tvDetailColumnUnlocked.value) return;
    _pumpFocusToTvPreview();
  }

  void unlockTvDetailColumn() {
    tvDetailColumnUnlocked.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pumpFocusToTvPreview();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pumpFocusToTvPreview();
        Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (!tvDetailColumnUnlocked.value) return;
          if (!detailPreviewFocusNode.hasFocus) {
            _pumpFocusToTvPreview();
          }
        });
      });
    });
  }

  void lockTvDetailColumn() {
    tvDetailColumnUnlocked.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (channelsListFocusNode.canRequestFocus) {
        channelsListFocusNode.requestFocus();
      }
    });
  }

  /// TV Bölge D → C: üst çubuktan aşağı — önizleme alanına (Kullanıcı isteği: sakın kategorilere kayma).
  void focusTvDownFromTopBar() {
    if (!_effectiveRemoteNav()) return;
    tvTrapFocusInChannelList.value = true;
    tvDetailColumnUnlocked.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (detailPreviewFocusNode.canRequestFocus) {
        detailPreviewFocusNode.requestFocus();
      }
    });
  }

  void attachTvChannelListScroll(ScrollController controller) {
    _tvChannelListScroll = controller;
  }

  void detachTvChannelListScroll(ScrollController controller) {
    if (_tvChannelListScroll == controller) {
      _tvChannelListScroll = null;
    }
  }

  void attachCategoryListScroll(ScrollController controller) {
    _categoryListScroll = controller;
  }

  void detachCategoryListScroll(ScrollController controller) {
    if (_categoryListScroll == controller) {
      _categoryListScroll = null;
    }
  }

  void bindPortraitTabController(TabController? controller) {
    _portraitTabController = controller;
  }

  /// Kategori listesinde seçili satırın [ListView.builder] dizinini döndürür.
  int categoryListIndexForSelection() {
    final sel = selectedCategoryId.value;
    final counts = categoryCountSnapshot();
    final showRecentlyWatched = counts.recentlyWatchedVisibleCount > 0;
    final fixedRowCount = showRecentlyWatched ? 3 : 2;
    if (sel == null) return 0;
    if (sel == kFavoritesVirtualCategoryId) return 1;
    if (sel == kRecentlyWatchedVirtualCategoryId && showRecentlyWatched) {
      return 2;
    }
    final cats = categories;
    final catIndex = cats.indexWhere((c) => c.id == sel);
    if (catIndex < 0) return 0;
    return fixedRowCount + catIndex;
  }

  /// Mobil: kategori listesini seçili satıra kaydır (portre geri dönüş / sekme).
  void scrollCategoryListToSelection() {
    final sc = _categoryListScroll;
    if (sc == null || !sc.hasClients) return;
    final index = categoryListIndexForSelection();
    final vp = sc.position.viewportDimension;
    final target = (index * kTvGlassListRowExtent - vp * 0.32)
        .clamp(0.0, sc.position.maxScrollExtent);
    if ((sc.offset - target).abs() > 1) {
      sc.jumpTo(target);
    }
  }

  bool _throttleTvListNudge() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastTvChannelNudgeMs != null &&
        now - _lastTvChannelNudgeMs! < 90) {
      return true;
    }
    _lastTvChannelNudgeMs = now;
    return false;
  }

  /// TV Bölge B: yalnızca kanal listesi içinde dikey hareket (indeks tabanlı).
  void tvNudgeChannelListRow(int delta) {
    if (!_effectiveRemoteNav()) return;
    if (delta == 0) return;
    if (_throttleTvListNudge()) return;
    final list = filteredChannels;
    if (list.isEmpty) return;
    final cur = selectedChannel.value;
    var i = cur != null ? list.indexWhere((c) => c.id == cur.id) : 0;
    if (i < 0) i = 0;
    final next = (i + delta).clamp(0, list.length - 1);
    if (next == i) return;
    focusChannel(list[next]);
  }

  Timer? _tvListVerticalHoldInitial;
  Timer? _tvListVerticalHoldPeriodic;

  /// Basılı tutma: ilk adım tuş inişinde; periyodik adımlar kısa gecikmeden sonra.
  void beginTvChannelListVerticalHold(int delta, Duration interval) {
    if (!_effectiveRemoteNav()) return;
    if (delta == 0) return;
    stopTvChannelListVerticalHold();
    _tvListVerticalHoldInitial =
        Timer(kTvListVerticalHoldPauseBeforeRepeat, () {
      _tvListVerticalHoldInitial = null;
      if (isClosed) return;
      _tvListVerticalHoldPeriodic = Timer.periodic(interval, (_) {
        if (isClosed) {
          stopTvChannelListVerticalHold();
          return;
        }
        final list = filteredChannels;
        if (list.isEmpty) {
          stopTvChannelListVerticalHold();
          return;
        }
        final cur = selectedChannel.value;
        var i = cur != null ? list.indexWhere((c) => c.id == cur.id) : 0;
        if (i < 0) i = 0;
        // Remove boundary stopping - allow continuous scroll even at list edges
        // User should be able to hold arrow key and stay at top/bottom
        tvNudgeChannelListRow(delta);
      });
    });
  }

  void stopTvChannelListVerticalHold() {
    _tvListVerticalHoldInitial?.cancel();
    _tvListVerticalHoldPeriodic?.cancel();
    _tvListVerticalHoldInitial = null;
    _tvListVerticalHoldPeriodic = null;
  }

  /// Kumanda ile listede gezinirken seçimi günceller; aynı kanalı tekrar seçince oynatıcı açılmaz.
  ///
  /// TV’de tek paylaşımlı [channelsListFocusNode] satır değişiminde bazen odağı/scroll’u
  /// yeniden bağlamadan erken dönüş, bir üst kanalı “atlamış” gibi görünüyordu.
  void focusChannel(Channel channel) {
    final same = selectedChannel.value?.id == channel.id;
    if (!same) {
      selectedChannel.value = channel;
      unawaited(_app.setLastLiveCategoryId(selectedCategoryId.value));
      unawaited(_app.setLastLiveChannelId(channel.id));
      _schedulePrecache(channel.streamUrl);
      _schedulePreview(channel);
    }
    _reattachSharedListFocusAfterRebuild();
  }

  /// TV: seçili satırdaki [channelsListFocusNode] yeniden bağlanınca odağı oraya çek (iç Focus ile çakışmasın).
  void _reattachSharedListFocusAfterRebuild() {
    if (!_effectiveRemoteNav()) return;
    if (!tvTrapFocusInChannelList.value) return;
    if (tvDetailColumnUnlocked.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!channelsListFocusNode.canRequestFocus) return;
      channelsListFocusNode.requestFocus();
      _scheduleScrollLiveListToFocusedRow();
    });
  }

  /// Kumanda ile satır değişince [FocusNode] taşınır; odak değişmediği için
  /// [onFocusChange] kaydırmaz — seçili satırı görünür yap.
  void _scheduleScrollLiveListToFocusedRow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final list = filteredChannels;
      final cur = selectedChannel.value;
      if (cur != null) {
        final i = list.indexWhere((c) => c.id == cur.id);
        final sc = _tvChannelListScroll;
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
      final ctx = channelsListFocusNode.context;
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

  void selectChannel(Channel channel) {
    if (_app.layoutMode.value == AppLayoutMode.tv) {
      selectedChannel.value = channel;
      unawaited(_app.setLastLiveCategoryId(selectedCategoryId.value));
      unawaited(_app.setLastLiveChannelId(channel.id));
      _schedulePrecache(channel.streamUrl);
      openChannel(channel);
      return;
    }
    if (selectedChannel.value != null &&
        selectedChannel.value!.id == channel.id) {
      // Çift tıklama: Tam ekrana geç
      openChannel(channel);
      return;
    }
    selectedChannel.value = channel;
    unawaited(_app.setLastLiveCategoryId(selectedCategoryId.value));
    unawaited(_app.setLastLiveChannelId(channel.id));
    _schedulePrecache(channel.streamUrl);
    _schedulePreview(channel);
  }

  void _schedulePrecache(String streamUrl) {
    _precacheDebounce?.cancel();
    _precacheDebounce = Timer(const Duration(milliseconds: 400), () {
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
    _previewDebounce = Timer(_previewFocusHoldDelay, () {
      if (!_app.streamPreviewActive) return;
      _startPreview(channel);
    });
  }

  /// Ayarlardan önizleme kapatılınca veya devre dışıyken oynatıcıyı temizler.
  void clearStreamPreview() {
    _previewDebounce?.cancel();
    _previewDebounce = null;
    _previewLoadGeneration++;
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

  Future<void> _startPreview(Channel channel) async {
    if (!_app.streamPreviewActive) {
      clearStreamPreview();
      return;
    }
    final gen = ++_previewLoadGeneration;

    try {
      final old = previewController;
      previewController = null;
      if (old != null) {
        old.pause();
        old.dispose(forceDispose: true);
      }
    } catch (_) {}

    if (gen != _previewLoadGeneration) return;

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

      if (gen != _previewLoadGeneration) return;

      final live = IptvPlaybackDefaults.isLikelyLiveStream(streamUrl);
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

      final ds = iptvBetterPlayerDataSource(
        streamUrl,
        liveStream: live,
        cacheConfiguration: null,
        preferSoftwareVideoDecoder:
            live && _app.preferSoftwareVideoDecoder.value,
        liveBufferSeconds: live
            ? _app.liveBufferSeconds.value
            : IptvBetterPlayerConfig.defaultLiveBufferSecondsForExo,
      );

      final ctrl = BetterPlayerController(cfg);
      await ctrl.setupDataSource(ds);
      await iptvApplyBetterPlayerLowRam720CapIfNeeded(ctrl);
      if (gen != _previewLoadGeneration) {
        ctrl.dispose(forceDispose: true);
        return;
      }
      await ctrl.setVolume(0);
      if (gen != _previewLoadGeneration) {
        ctrl.dispose(forceDispose: true);
        return;
      }
      await ctrl.play();
      if (gen != _previewLoadGeneration) {
        ctrl.dispose(forceDispose: true);
        return;
      }
      previewController = ctrl;
      isPreviewLoading.value = false;
      update(['preview']);
    } catch (_) {
      isPreviewLoading.value = false;
      update(['preview']);
    }
  }

  void _ensureSelectionInList({bool fromPlaylistRestore = false}) {
    final list = filteredChannels;
    if (list.isEmpty) {
      selectedChannel.value = null;
      return;
    }
    final cur = selectedChannel.value;
    final inList = cur != null && list.any((c) => c.id == cur.id);
    if (inList) return;
    final preferNone = fromPlaylistRestore &&
        _app.layoutMode.value != AppLayoutMode.tv;
    selectedChannel.value = preferNone ? null : list.first;
  }

  void openSelectedPlayer() {
    final c = selectedChannel.value;
    if (c != null) {
      openChannel(c);
    }
  }

  /// Seçili kanalla aynı kategorideki görünür kanallar (gizli kanallar hariç).
  List<Channel> channelsInSameCategory(Channel channel) {
    final d = _data;
    if (d == null) return const [];
    final peers = <Channel>[];
    for (final c in d.channels) {
      if (c.categoryId != channel.categoryId) continue;
      if (PlaylistCategoryHide.channelHiddenInLive(_app, _cache, d, c)) {
        continue;
      }
      peers.add(c);
    }
    peers.sort((a, b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      if (o != 0) return o;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return peers;
  }

  String? categoryNameFor(Channel channel) {
    for (final c in categories) {
      if (c.id == channel.categoryId) return c.name;
    }
    return null;
  }

  /// Detay panelinden kanal seçimi — seçimi günceller ve doğrudan oynatır.
  void playChannelFromDetail(Channel channel) {
    selectedChannel.value = channel;
    if (selectedCategoryId.value != channel.categoryId) {
      selectedCategoryId.value = channel.categoryId;
    }
    unawaited(_app.setLastLiveCategoryId(channel.categoryId));
    unawaited(_app.setLastLiveChannelId(channel.id));
    openChannel(channel);
  }

  void openChannel(Channel channel) {
    _previewDebounce?.cancel();
    _previewLoadGeneration++;
    try {
      final old = previewController;
      previewController = null;
      if (old != null) {
        old.pause();
        old.dispose(forceDispose: true);
      }
      update(['preview']);
    } catch (_) {}

    unawaited(_app.setLastLiveCategoryId(selectedCategoryId.value));
    unawaited(_app.setLastLiveChannelId(channel.id));

    if (Get.isRegistered<IptvPrecacheService>()) {
      unawaited(
        Get.find<IptvPrecacheService>().precacheStreamUrl(channel.streamUrl),
      );
    }
    // TV: liste satırındaki FocusNode (özellikle ilk kanal) üst rotada odakta kalabiliyor;
    // oynatıcıda OSD/kumanda çalışmıyor. Önce bırak, sonra bir tick sonra rota aç.
    FocusManager.instance.primaryFocus?.unfocus();
    Future<void>.microtask(
      () => Get.toNamed(AppRoutes.player, arguments: channel),
    );
  }

  void _restoreLastSelection() {
    final d = _data;
    if (d == null) {
      _ensureSelectionInList(fromPlaylistRestore: true);
      return;
    }

    if (_routePickChannelId != null) {
      final want = _routePickChannelId!;
      Channel? picked;
      for (final c in d.channels) {
        if (c.id == want) {
          picked = c;
          break;
        }
      }
      _routePickChannelId = null;
      if (picked != null) {
        if (_routeInitialSearch != null &&
            _routeInitialSearch!.trim().isNotEmpty) {
          searchQuery.value = _routeInitialSearch!.trim();
          searchController.text = _routeInitialSearch!.trim();
        }
        _routeInitialSearch = null;
        selectedCategoryId.value = null;
        selectedChannel.value = picked;
        unawaited(_app.setLastLiveCategoryId(null));
        unawaited(_app.setLastLiveChannelId(picked.id));
        _schedulePrecache(picked.streamUrl);
        _schedulePreview(picked);
        _ensureSelectionInList(fromPlaylistRestore: false);
        // Ana ekran birleşik arama: seçilen kanalı doğrudan oynat.
        final toPlay = picked;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isClosed) return;
          openChannel(toPlay);
        });
        return;
      }
    } else if (_routeInitialSearch != null &&
        _routeInitialSearch!.trim().isNotEmpty) {
      searchQuery.value = _routeInitialSearch!.trim();
      searchController.text = _routeInitialSearch!.trim();
      _routeInitialSearch = null;
      if (_routeHomeUnifiedSearch) {
        _routeHomeUnifiedSearch = false;
        final wantCat = _routeHomeUnifiedChannelCategoryId;
        _routeHomeUnifiedChannelCategoryId = null;
        if (wantCat != null) {
          ChannelCategory? cat;
          for (final c in d.channelCategories) {
            if (c.id == wantCat) {
              cat = c;
              break;
            }
          }
          final hidden = cat != null &&
              PlaylistCategoryHide.liveCategoryRowHidden(_app, _cache, cat);
          if (!hidden) {
            selectedCategoryId.value = wantCat;
            unawaited(_app.setLastLiveCategoryId(wantCat));
          }
        }
        _ensureSelectionInList();
        return;
      }
    }

    if (_resetLiveSelectionFromHome) {
      _resetLiveSelectionFromHome = false;
      _applyFreshLiveTvEntrySelection();
      return;
    }

    void sanitizeLiveCategoryIfHidden() {
      final cid = selectedCategoryId.value;
      if (cid == null) return;
      ChannelCategory? cat;
      for (final c in d.channelCategories) {
        if (c.id == cid) {
          cat = c;
          break;
        }
      }
      if (cat != null &&
          PlaylistCategoryHide.liveCategoryRowHidden(_app, _cache, cat)) {
        selectedCategoryId.value = null;
        unawaited(_app.setLastLiveCategoryId(null));
      }
    }

    final tv = _app.layoutMode.value == AppLayoutMode.tv;
    if (tv) {
      selectedCategoryId.value = _app.lastLiveCategoryId.value;
      sanitizeLiveCategoryIfHidden();
      final lastId = _app.lastLiveChannelId.value;
      if (lastId != null) {
        for (final c in d.channels) {
          if (c.id == lastId) {
            selectedChannel.value = c;
            _ensureSelectionInList();
            return;
          }
        }
      }
      _ensureSelectionInList();
      return;
    }

    selectedCategoryId.value = _app.lastLiveCategoryId.value;
    sanitizeLiveCategoryIfHidden();

    final lastId = _app.lastLiveChannelId.value;
    if (lastId != null) {
      Channel? found;
      for (final c in d.channels) {
        if (c.id == lastId) {
          found = c;
          break;
        }
      }
      if (found != null) {
        selectChannel(found);
        return;
      }
    }

    _ensureSelectionInList(fromPlaylistRestore: true);
    final cur = selectedChannel.value;
    if (cur != null) {
      _schedulePrecache(cur.streamUrl);
      _schedulePreview(cur);
    }
  }

  /// Ana ekrandan giriş: "Tüm kanallar" + listedeki ilk kanal; kumanda odağı solda ilk satırda.
  void _applyFreshLiveTvEntrySelection() {
    final d = _data;
    if (d == null) {
      _ensureSelectionInList(fromPlaylistRestore: true);
      return;
    }
    selectedCategoryId.value = null;
    tvDetailColumnUnlocked.value = false;
    tvTrapFocusInChannelList.value = false;
    final all = visibleChannels;
    final tv = _app.layoutMode.value == AppLayoutMode.tv;
    if (all.isEmpty) {
      selectedChannel.value = null;
    } else if (tv) {
      final first = all.first;
      selectedChannel.value = first;
      unawaited(_app.setLastLiveCategoryId(null));
      unawaited(_app.setLastLiveChannelId(first.id));
      _schedulePrecache(first.streamUrl);
      _schedulePreview(first);
    } else {
      selectedChannel.value = null;
    }
    if (!tv) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!categoryFocusNode.canRequestFocus) return;
        categoryFocusNode.requestFocus();
      });
    });
  }

  void changePlaylist() {
    Get.offNamed(AppRoutes.playlist);
  }

  void goHome() => Get.back();

  /// Portre canlı TV (mobil/tablet): EPG → detay → kanallar → kategoriler → [goHome]. TV düzeninde kullanılmaz.
  void onPortraitChannelsStepBack(BuildContext context) {
    final tc = _portraitTabController ?? DefaultTabController.maybeOf(context);
    if (tc == null) {
      goHome();
      return;
    }
    if (tc.index == 1 && searchQuery.value.trim().isNotEmpty) {
      searchQuery.value = '';
      searchController.clear();
      tc.animateTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollCategoryListToSelection();
      });
      return;
    }
    if (tc.index > 0) {
      final next = tc.index - 1;
      tc.animateTo(next);
      if (next == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scrollCategoryListToSelection();
        });
      }
    } else {
      goHome();
    }
  }

  /// TV: üst çubuk geri — kategori tuzağındaysa önce sol sütuna dön.
  void onTopBarBack() {
    if (_effectiveRemoteNav() && tvTrapFocusInChannelList.value) {
      releaseTvListFocusToCategories();
    } else {
      goHome();
    }
  }

  /// Tam ekran oynatıcıdan [Get.back] sonrası: TV'de liste kaydırılır, kumanda
  /// odağı izlenen kanal satırında kalır. Mobilde [tvTrapFocusInChannelList]
  /// tetiklenmez — aksi halde üst [Obx] yeniden çizer ve portre sekmeleri /
  /// kategori kaydırması sıfırlanır.
  void restoreChannelListFocusAfterPlayerPop() {
    if (!_effectiveRemoteNav()) return;

    tvTrapFocusInChannelList.value = true;
    tvDetailColumnUnlocked.value = false;

    void requestListFocus() {
      if (channelsListFocusNode.canRequestFocus) {
        channelsListFocusNode.requestFocus();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = channelsListFocusNode.context;
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
}
