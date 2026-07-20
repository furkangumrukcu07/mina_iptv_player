part of '../tv_shell_controller.dart';

extension TvShellCategoryController on TvShellController {
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
    channels.tvShellLiveActive.value = false;
    channels.tvShellLiveBrowseActive.value = false;
    channels.clearStreamPreview();
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
    channels.tvShellLiveActive.value = false;
    channels.tvShellLiveBrowseActive.value = false;
    channels.clearStreamPreview();
    phase.value = TvShellPhase.vodContent;
    unawaited(_loadSeriesContent(categoryId));
    _requestVodContentFocusIfRemote(context);
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

}
