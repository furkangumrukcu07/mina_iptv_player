part of '../tv_shell_controller.dart';

extension TvShellContentController on TvShellController {
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

  void toggleFocusedFavorite() {
    final vod = focusedVodContentItem;
    if (vod == null) return;
    Get.find<FavoritesService>().toggleVod(vod.id);
  }

  void toggleFocusedSeriesFavorite() {
    final series = focusedSeriesContentItem;
    if (series == null) return;
    Get.find<FavoritesService>().toggleSeries(series.id);
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

  /// Tam canlı TV panelinde ilk kanal satırına odak (kategori seçimi sonrası).
  void focusLiveChannelRow(int index, {BuildContext? context}) {
    if (!_usesRemoteNav(context)) return;
    liveChannelsFocusNode.unfocus();
    channels.focusTvShellChannelRow(index);
  }

}
