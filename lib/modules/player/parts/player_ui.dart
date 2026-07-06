part of '../player_controller.dart';

extension PlayerUiExtension on PlayerController {
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
    PlayerController._lastVolumeLevel = clamped;

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
    setVolume(PlayerController._lastVolumeLevel);
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

void setSpeed(double value) {
    better?.setSpeed(value);
  }

/// OSD üzerindeki hızlı oynatma butonu için bir sonraki hıza geçer.
  /// 1x → 1.25x → 1.5x → 2x → 1x.
  void cyclePlaybackRate() {
    final current = playbackRate.value;
    var nextIndex = 0;
    for (var i = 0; i < PlayerController.playbackRateCycle.length; i++) {
      if ((PlayerController.playbackRateCycle[i] - current).abs() < 0.001) {
        nextIndex = (i + 1) % PlayerController.playbackRateCycle.length;
        break;
      }
    }
    setPlaybackRate(PlayerController.playbackRateCycle[nextIndex]);
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
        ? (live ? customDuration : PlayerController._tvOsdHideAfterPlayback)
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
  ///
  /// Dikey modda tam ekran overlay açılmaz — alttaki canlı TV panelinin EPG
  /// sekmesine geçilir (video gri perde + bozuk overlay önlenir).
  void openLiveSingleChannelEpgOverlay() {
    if (!_currentStreamIsLive) return;
    final u = channel.value.streamUrl.toLowerCase();
    if (u.contains('/movie/') || u.contains('/series/')) return;
    if (_playbackPortraitForAutoHide) {
      requestPortraitLivePanelTab(PlayerController.portraitLiveTabEpg);
      scheduleTvOsdAutoHide();
      return;
    }
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
}
