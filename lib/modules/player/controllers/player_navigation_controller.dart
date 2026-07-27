part of '../player_controller.dart';

extension PlayerNavigationController on PlayerController {
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
    final delay = _currentStreamIsLive ? PlayerController._zapDebounceLive : PlayerController._zapDebounceDefault;
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
    if (buf.length >= PlayerController._channelNumberMaxDigits) return;
    tvChannelNumberEntry.value = '$buf$digit';
    _channelNumberCommitTimer?.cancel();
    _channelNumberCommitTimer =
        Timer(PlayerController._channelNumberCommitDelay, commitChannelNumberEntry);
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
    if (data == null) return;
    if (Get.isRegistered<PlaylistDataSource>() &&
        Get.find<PlaylistDataSource>().isDbBacked) {
      await _ensureDbLiveCatZapListLoaded(cur.categoryId, data);
    } else if (data.channels.isEmpty) {
      return;
    }

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

Future<void> zapTo(Channel newChannel) async {
    if (_isSameChannelRow(newChannel, channel.value)) return;

    clearShowcasePipRestoreEngine();
    cancelVodAutoplayCountdown();
    _stopVodEndAutoplayMonitor();
    _resetVodAutoplayLatchState();

    final bootGen = _bumpPlaybackGeneration();

    _resumeAtAfterOsdEngineSwitch = null;
    _userPausedLive = false;
    _liveSpuriousStopLastRecovery = null;
    _liveKeepAliveArmed = false;
    _cancelZapRelativeDebounce();
    _cancelLiveZapAbrQualityRamp();
    _cancelTvOsdAutoHideTimer();
    _resetNetworkRecoveryState();
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    _cancelLiveAutoNextWatchdog();
    _revertLiveAutoBuffer('zap');
    _liveTvStallRecoveryAttempts = 0;
    _betterPlayerLightRetryWave = 0;
    _resetOrphanBetterSurfaceRecoveryForZap();
    _liveUhdBufferActive = false;
    _liveUhdBufferPromotionInFlight = false;
    _cancelLiveChannelPreload();

    final newLive = IptvPlaybackDefaults.isLikelyLiveStream(
      _normalizePlaybackStreamUrl(newChannel.streamUrl),
    );
    _preferFastLiveStartBuffer = newLive;
    // Canlı zap'ta orta logo + yanıp sönen Mina ikonu splash'ını gizle; bunun
    // yerine yayın başlamadan önce gerçek OSD'nin aynısı olan "sahte OSD" paneli
    // (kanal satırı/logosu) görünür kalır. Bu davranış TV modunda VE mobil/tablet
    // YATAY modda geçerli (kullanıcı isteği). Mobil/tablet DİKEY modda eski
    // davranış (logo + Mina ikonu splash) korunur.
    final landscapePlayback = !_playbackPortraitForAutoHide;
    suppressLiveZapLoadingUi.value = newLive &&
        (_settings.layoutMode.value == AppLayoutMode.tv || landscapePlayback);

    // Kanal kimliğini HEMEN güncelle: eski Better örneği dispose edilince
    // ([_setBetterPlayer(null)]) yüzey kaybolup splash "yüzey yok" dalına
    // düşüyor; bu pencerede [channel.value] hâlâ eski olsaydı splash bir kare
    // eski kanalın logosunu gösterirdi (dikey modda "logo flaşı").
    channel.value = newChannel;
    channel.refresh();

    // --- Save last watched live channel ---
    if (newLive) {
      unawaited(_settings.setLastLiveChannelId(newChannel.id));
    } else {
      // Save initial VOD progress (0 position) to make it the last watched content immediately
      final wp = Get.find<WatchProgressService>();
      final series = playingSeries;
      if (series != null) {
        unawaited(wp.saveSeriesProgress(
          seriesId: series.id,
          title: series.name,
          coverUrl: series.posterUrl,
          positionMs: 0,
          durationMs: 1,
          episodeStreamId: newChannel.id,
        ));
      } else {
        unawaited(wp.saveProgress(
          newChannel.id,
          0,
          1,
          title: newChannel.name,
          coverUrl: newChannel.logoUrl,
        ));
      }
    }
    // ---------------------------------------------------

    // Yeni bölümün/kanalın ses kodek ipucunu tazele (dizi şeridinde bölüm başına
    // kodek vardır → doğru motor; filmde öğe başına kodek yok → temizlenir).
    _refreshAudioCodecHintForCurrent();

    // Yeni içeriğin türüne (canlı vs film/dizi) göre hatırlanan görüntü oranını
    // uygula; kullanıcı seçimini koru.
    _applyRememberedVideoFit();

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

      // Başarı önbelleğini motor seçiminden ÖNCE uygula (mediakit/software/ts).
      final cachedFormat =
          await _settings.getStreamSuccessFormat(newChannel.id);

      // TV’de de aynı Better örneği + setupDataSource: OSD ağacı kopmaz, hızlı zap’ta
      // yalnız kanal metni/logosu güncellenir (ayrı TvLiveBusyOsd şeridine düşülmez).
      betterOsdOverride.value = false;
      mediaKitFallbackSession.value = false;
      decoderFallbackStep.value = 0;
      _forceSoftwareVideoDecoder = false;
      _lastBootUsedSoftwareVideoDecoder = false;
      _mediaKitFallbackForceSoftwareDecode = false;
      _mediaKitBlackScreenRecoveryUsed = false;
      _preferExoSoftwareForFastZap = false;
    _liveUhdBufferActive = false;
    _liveUhdBufferPromotionInFlight = false;
    _livePreloadTimer?.cancel();
    _livePreloadTimer = null;
    _livePreloadScheduledUrl = null;
    _livePlaybackEstablished = false;
    _cachedTsFormatForBoot = false;
      _mediaKitLiveBufferEscalationStep = 0;
      _exoSoftwareDecoderRetryPending = false;
      _xtreamTriedLiveUrlFormat = false;
      _xtreamTriedGetPhpFallback = false;
      _xtreamTriedSeriesMoviePathToGetPhp = false;
      _xtreamTriedGetPhpToVodPathFallback = false;
      _xtreamTriedVodMkvToTsSwap = false;
      _vodAutoTriedBetterAfterMpvFail = false;
      _mediaKitLiveTriedHlsAfterTs = false;
      _cancelMediaKitLiveTsHlsWatchdog();
      _autoEngineSwitchUsed = false;
      _decoderTriedTsToM3u8Swap = false;
      _liveTsSeekFailureHandled = false;
      _liveHttpForbiddenRetryCount = 0;
      _lastPlaybackUrl = null;
      _playUrlOverride = null;
      _lastOsdQualitySignature = -1;
      osdQualityStamp.value++;
      _applyStreamSuccessCacheForBoot(cachedFormat, channelId: newChannel.id);

      if (newLive) {
        await AndroidPlaybackSocHints.ensureLoaded();
      }
      // Canlı Better: her zaman aynı controller + setupDataSource (tek texture).
      // Hızlı zap’ta dispose/yazılım decoder zorlaması mapSize şişiriyordu.
      final reuseBetter = !effectiveUseMediaKit &&
          _shouldReuseBetterOnChannelChange(newChannel);
      if (!_isPlaybackGenerationCurrent(bootGen)) {
        return;
      }

      var disposedBetter = false;
      try {
        if (!reuseBetter && better != null) {
          disposedBetter = await _hardDisposeBetterPlayerBeforeCreate(
            reason: 'zap',
          );
        }
      } catch (_) {}

      if (disposedBetter) {
        _syncPlaybackWakelock(force: true);
      }

      if (!_isPlaybackGenerationCurrent(bootGen)) {
        return;
      }

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

int _episodeTapeIndexOfCurrent() {
    final tape = _episodeBrowseTape;
    if (tape == null || tape.isEmpty) return -1;
    final cur = channel.value;
    var idx = tape.indexWhere((e) => e.channel.id == cur.id);
    if (idx >= 0) return idx;
    return tape.indexWhere((e) => e.channel.streamUrl == cur.streamUrl);
  }

bool _vodHasNextInBrowseTape() {
    final ch = channel.value;
    final epKey = _episodeBrowseTape;
    final mvKey = _movieBrowseCategoryTapes ?? _movieBrowseTape;
    if (_vodHasNextCache != null &&
        _vodHasNextCacheChannelId == ch.id &&
        identical(_vodHasNextCacheEpKey, epKey) &&
        identical(_vodHasNextCacheMvKey, mvKey)) {
      return _vodHasNextCache!;
    }

    var hasNext = false;
    final ep = _episodeBrowseTape;
    if (ep != null && ep.length > 1) {
      final idx = _episodeTapeIndexOfCurrent();
      if (idx >= 0 && idx < ep.length - 1) hasNext = true;
    }
    if (!hasNext) {
      final mv = _flatMovieTapeForZap();
      if (mv.length > 1) {
        var idx = mv.indexWhere((c) => c.id == ch.id);
        if (idx < 0) {
          idx = mv.indexWhere((c) => c.streamUrl == ch.streamUrl);
        }
        if (idx >= 0 && idx < mv.length - 1) hasNext = true;
      }
    }
    _vodHasNextCache = hasNext;
    _vodHasNextCacheChannelId = ch.id;
    _vodHasNextCacheEpKey = epKey;
    _vodHasNextCacheMvKey = mvKey;
    return hasNext;
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

    final settings = Get.find<AppSettingsService>();
    final isMobile = settings.layoutMode.value == AppLayoutMode.mobile;
    final isLandscape = Get.context != null &&
                        MediaQuery.orientationOf(Get.context!) == Orientation.landscape;

    // macOS masaüstünde pencere yatay olsa bile ekran döndürme mantığı yok;
    // ESC tuşu doğrudan oynatıcıdan çıkmalı.
    if (!Platform.isMacOS && isMobile && isLandscape) {
      unawaited(settings.requestMobileHandheldPortraitPlayback());
      return;
    }

    if (Get.isRegistered<TvShellController>()) {
      final shell = Get.find<TvShellController>();
      shell.preventGhostBackAfterPlayerPop();
      if (shell.selectedSection.value == TvShellSection.live && Get.isRegistered<ChannelsController>()) {
        Get.find<ChannelsController>().restoreChannelListFocusAfterPlayerPop();
      } else {
        shell.restoreVodCinemaListAfterPlayerPop();
      }
    } else if (Get.isRegistered<ChannelsController>()) {
      Get.find<ChannelsController>().restoreChannelListFocusAfterPlayerPop();
    }

    final showcasePipHandoff = await _prepareLeavePlayerRoute();

    if (showcasePipHandoff) {
      // fadeIn geçişi yarım kalırsa ana ekranda gri perde + dokunma kaybı olur.
      Get.until((route) {
        final name = route.settings.name;
        return route.isFirst ||
            name == AppRoutes.home ||
            name == AppRoutes.splash;
      });
    } else {
      final nav = Get.key.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
      } else {
        Get.back<void>();
      }
    }

    if (showcasePipHandoff && Get.isRegistered<ShowcaseInAppPipService>()) {
      final pip = Get.find<ShowcaseInAppPipService>();
      unawaited(pip.recoverHomeInteractionAfterPipHandoff());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(pip.recoverHomeInteractionAfterPipHandoff());
        unawaited(pip.refreshSurfaceAfterPlayerRoutePop());
      });
    }
  }

/// Yatay tam ekrandan çıkış: Better dahili tam ekran route'u, yön kilidi ve
  /// immersive modu sıfırla; ardından [Navigator.pop] güvenle çalışsın.
  /// Handoff yapıldıysa `true` döner (motorlar serviste kalır).
  Future<bool> _prepareLeavePlayerRoute() async {
    // Tam ekran route'u handoff'tan ÖNCE kapat; aksi halde root navigator'da
    // gri/siyah perde kalır ve ana ekran dokunmaya kapalı olur.
    try {
      final bp = better;
      if (bp != null && bp.isFullScreen) {
        bp.exitFullScreen();
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
      }
    } catch (_) {}

    // Vitrin uygulama içi PiP: sistem mini-PiP'ten önce; aksi halde handoff
    // atlanıp ExoPlayer route çıkışında dispose ediliyordu.
    if (await _tryHandoffToShowcaseInAppPip()) {
      return true;
    }

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

    await _haltPlaybackForRouteExit();
    return false;
  }
}
