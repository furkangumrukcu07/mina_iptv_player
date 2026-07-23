part of '../tv_shell_controller.dart';

extension TvShellNavigationController on TvShellController {
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
    if (selectedSection.value == section && _categoryRowFocusHandler != null) {
      focusCategoryRow(categoryId);
      return;
    }
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
    
    if (_categoryRowFocusHandler != null) {
      _categoryRowFocusHandler!(categoryId);
      return;
    }
    
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
    final hc = Get.find<HomeController>();

    // Get.dialog kullanıyoruz ki Get.isDialogOpen == true olsun.
    // Böylece onBack() search dialog açıkken nav.pop() yerine Get.back() çağırır.
    Get.dialog<void>(
      GlobalSearchDialog(controller: hc),
      barrierColor: Colors.black54,
      barrierDismissible: true,
    ).then((_) {
      // Dialog kapandığında search section seçili kalmasın — rail'deki
      // önceki section'a (live) focus'u geri ver, tekrar dialog açılmasın.
      if (selectedSection.value == TvShellSection.search) {
        selectedSection.value = TvShellSection.live;
      }
      // Rail'deki search butonuna focus'u geri ver
      final searchFocus = railFocusNodes[TvShellSection.search];
      if (searchFocus != null && searchFocus.canRequestFocus) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (searchFocus.canRequestFocus) searchFocus.requestFocus();
        });
      }
    });
  }

  void openMinaWrapper() {
    if (!_app.minaWrappedEnabled.value) return;
    Get.toNamed(AppRoutes.minaAnalytics);
  }

  void openEpgMix() {
    Get.toNamed(AppRoutes.epgMix);
  }

  bool get showsCategoryPanel {
    final s = selectedSection.value;
    if (s == TvShellSection.search) return false;
    if (s == TvShellSection.wrapper) return false;
    if (s == TvShellSection.repeat) return false;
    if (s == TvShellSection.settings) return false;
    if (s == TvShellSection.playlists) return false;
    if (s == TvShellSection.continueWatching) return false;
    return showsRail || phase.value == TvShellPhase.categories;
  }

  bool get isRailFocused {
    for (final node in railFocusNodes.values) {
      if (node.hasFocus) return true;
    }
    return false;
  }

  void selectRailSection(TvShellSection section, {BuildContext? context}) {
    if (section == TvShellSection.search) {
      // Arama bir section değil, aksiyondur — selectedSection'ı değiştirme,
      // önceki section'a dönebilmek için kaydedip dialog kapanınca geri yükle.
      if (context != null) openSearch(context);
      return;
    }
    selectedSection.value = section;
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
  /// Oynatıcıdan tam ekrandan çıkarken TvShell'e dönüldüğünde oluşabilecek
  /// hayalet "Geri" tuşu tetiklemelerini önlemek için kullanılır.
  void preventGhostBackAfterPlayerPop() {
    _lastBackCoalesceMs = DateTime.now().millisecondsSinceEpoch + 500;
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
    // Navigator yığınında pop yapılabilecek bir sayfa varsa (alt sayfa açık)
    // TV kabuğu mantığına düşmeden önce onu kapat.
    // ÖNEMLİ: Yalnızca mevcut route'un üzerinde ekstra bir yığın varsa pop et;
    // aksi takdirde TV kabuğu navigasyonu devreye girer.
    // GetX navigator'ına doğrudan erişim — KM2 Plus gibi TV box'larda
    // Get.overlayContext / Get.context bazen hatalı navigator döndürebilir.
    final getxNav = Get.key.currentState;
    if (getxNav != null && getxNav.canPop()) {
      getxNav.pop();
      return;
    }
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx != null) {
      final rootNav = Navigator.of(ctx, rootNavigator: true);
      if (rootNav.canPop()) {
        rootNav.pop();
        return;
      }
    }

    // Settings panelindeyken ve alt sayfa açık değilken:
    // Rail odaklanmamışsa her zaman settings paneline geri dön, uygulamadan çıkma.
    if (phase.value == TvShellPhase.categories &&
        selectedSection.value == TvShellSection.settings &&
        !isRailFocused) {
      if (now - _lastBackHandledMs < 450) return;
      _lastBackHandledMs = now;
      onLeftFromSettingsPanel();
      return;
    }

    // Ana ekran / rail: doğrudan çıkış (onay veya Android TV'de anında kapat).
    if (phase.value == TvShellPhase.rail) {
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
        // Kanal listesindeyken geri → önce kategorilere dön, çıkma.
        // Kullanıcı rail'e odaklansa bile, liveContent phase'inden çıkış
        // yerine kategorilere dönülür (rail zaten ana menü).
        channels.tvShellLiveActive.value = false;
        channels.tvShellLiveBrowseActive.value = true;
        phase.value = TvShellPhase.categories;
        railExpanded.value = true;
        final liveNode = railFocusNodes[selectedSection.value];
        if (liveNode != null) scheduleTvFocusRestore(liveNode);
        return;
      case TvShellPhase.categories:
        if (selectedSection.value == TvShellSection.live &&
            channels.tvShellChannelRowHasFocus.value) {
          // Kanal listesindeyken geri → kategori listesine dön
          onLeftFromLiveBrowse();
          return;
        }
        if (selectedSection.value == TvShellSection.live &&
            channels.tvShellLiveBrowsingChannels.value) {
          // Kategori listesindeyken geri → rail'e dön
          channels.tvShellLiveBrowsingChannels.value = false;
          railExpanded.value = true;
          final node = railFocusNodes[selectedSection.value];
          if (node != null) scheduleTvFocusRestore(node);
          return;
        }
        if ((selectedSection.value == TvShellSection.movies ||
                selectedSection.value == TvShellSection.series) &&
            vodBrowsePosterHasFocus.value) {
          onLeftFromVodBrowse();
          return;
        }
        if (selectedSection.value == TvShellSection.playlists) {
          if (isRailFocused) {
            _requestTvShellExit();
            return;
          }
          onLeftFromPlaylistsPanel();
          return;
        }
        if (selectedSection.value == TvShellSection.continueWatching) {
          if (isRailFocused) {
            _requestTvShellExit();
            return;
          }
          onLeftFromContinueWatchingPanel();
          return;
        }
        if (selectedSection.value == TvShellSection.settings) {
          // Rail açık + settings seçili: panel kapatıldı, rail odaklandı.
          // Bir sonraki geri → rail'den çıkış (exit) veya çıkış onay diyalogu.
          if (isRailFocused) {
            _requestTvShellExit();
            return;
          }
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
        if (!isRailFocused) {
          railExpanded.value = true;
          final node = railFocusNodes[selectedSection.value];
          if (node != null) scheduleTvFocusRestore(node);
        } else if (selectedSection.value == TvShellSection.settings) {
          // Settings panelinde rail odaklıysa bile çıkma —
          // KM2Plus gibi cihazlarda güvenlik için panele geri dön.
          onLeftFromSettingsPanel();
        } else {
          _requestTvShellExit();
        }
        return;
      case TvShellPhase.rail:
        // [onBack] başında debounce'suz ele alınır.
        return;
    }
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

}
