import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import '../../core/player/playback_orientation_manager.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../../core/theme/app_performance.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/player/exo_native_track_option.dart';
import '../../../core/player/better_player_video_track_label.dart';
import '../../../core/player/iptv_playback_defaults.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/series.dart';
import 'widgets/osd_stream_quality_badges.dart';
import 'widgets/live_channel_strip_overlay.dart';
import 'widgets/vod_browse_rail_overlay.dart';
import 'widgets/player_live_epg_overlay.dart';
import 'widgets/vod_autoplay_overlay.dart';
import 'widgets/player_glass_level_overlay.dart';
import 'widgets/tv_media_kit_player_controls.dart';
import 'widgets/universal_video_player.dart';
import 'player_controller.dart';
import '../../../ui/glass_overlays.dart';
import '../../../ui/iptv_channel_logo.dart';

/// TV / yatay kumanda: oynatıcı yüzeyi veya cam OSD henüz yokken bile canlıda kanal değişimi.
Widget _liveRemoteZapWhenPlayerChromeMissing({
  required PlayerController controller,
  required bool enable,
  required Widget child,
}) {
  if (!enable) return child;
  return Focus(
    autofocus: true,
    onKeyEvent: (node, event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      if (controller.vodResumeDialogOpen.value ||
          controller.vodAutoplayCountdown.value != null) {
        return KeyEventResult.ignored;
      }
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.arrowUp ||
          k == LogicalKeyboardKey.arrowLeft) {
        controller.zapRelativeDebounced(-1);
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.arrowDown ||
          k == LogicalKeyboardKey.arrowRight) {
        controller.zapRelativeDebounced(1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: child,
  );
}

/// Sistem parlaklığına dokunmadan yalnızca video alanını karartır ([PlayerController.inAppPlaybackBrightness]).
class _PlaybackVideoDimmer extends StatelessWidget {
  const _PlaybackVideoDimmer({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dim =
          (1.0 - controller.inAppPlaybackBrightness.value).clamp(0.0, 1.0);
      if (dim < 0.003) return const SizedBox.shrink();
      return Positioned.fill(
        child: IgnorePointer(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: dim),
          ),
        ),
      );
    });
  }
}

class PlayerView extends StatefulWidget {
  const PlayerView({super.key});

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> with WidgetsBindingObserver {
  final controller = Get.find<PlayerController>();

  /// Dikey ↔ yatay geçişte üst widget ağacı değişince [UniversalVideoPlayer] yeniden kurulmasın.
  final GlobalKey _videoSurfaceKey = GlobalKey(debugLabel: 'minaPlayerVideo');

  double? _verticalGestureOriginY;
  double _verticalGestureStartLevel = 1.0;
  bool _isDraggingLeft = false;
  final RxDouble _overlayValue = 0.0.obs;
  final Rxn<IconData> _overlayIcon = Rxn<IconData>();
  final RxBool _showOverlay = false.obs;
  Timer? _overlayTimer;

  final GlobalKey<LiveChannelStripOverlayState> _channelStripKey =
      GlobalKey<LiveChannelStripOverlayState>();
  Timer? _centerKeyHoldTimer;
  bool _centerKeyDown = false;
  Timer? _vodCenterHoldTimer;
  bool _vodCenterKeyDown = false;

  /// Şerit / tek-kanal EPG kumanda Geri sonrası, aynı sistem pop’unda [handleBack] çalışmasın.
  bool _consumeNextSystemBackPop = false;

  Worker? _busyWorker;

  /// [build] içinde yön değişince [didChangeMetrics] kaçırılırsa immersive senkronu için.
  Orientation? _lastAppliedOrientationInBuild;

  bool _hardwareKeyHandler(KeyEvent event) => _onGlobalHardwareKey(event);

  void _handleVerticalDragStart(DragStartDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    _isDraggingLeft = details.globalPosition.dx < width / 2;
    _verticalGestureOriginY = details.globalPosition.dy;
    _verticalGestureStartLevel = _isDraggingLeft
        ? controller.inAppPlaybackBrightness.value
        : controller.currentVolume;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    final originY = _verticalGestureOriginY;
    if (originY == null) return;

    final height = MediaQuery.sizeOf(context).height;
    if (height <= 1) return;

    final dy = details.globalPosition.dy - originY;
    final gain = PlayerController.verticalPlaybackGestureGain;
    final delta = -(dy / height) * gain;
    final newValue = (_verticalGestureStartLevel + delta).clamp(0.0, 1.0);

    if (_isDraggingLeft) {
      controller.setInAppPlaybackBrightness(newValue);
      _overlayIcon.value = Icons.brightness_6_rounded;
    } else {
      controller.setVolume(newValue);
      _overlayIcon.value = playerVolumeIconFor(newValue);
    }
    _overlayValue.value = newValue;

    _showOverlay.value = true;
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 2), () {
      _showOverlay.value = false;
    });
  }

  void _nudgeInAppVolume(double delta) {
    final v = (controller.currentVolume + delta).clamp(0.0, 1.0);
    controller.setVolume(v);
    _overlayIcon.value = playerVolumeIconFor(v);
    _overlayValue.value = v;
    _showOverlay.value = true;
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 1200), () {
      _showOverlay.value = false;
    });
  }

  void _syncPlayerSystemChrome() {
    if (!mounted) return;
    final settings = Get.find<AppSettingsService>();
    final layout = settings.layoutMode.value;
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    if (layout == AppLayoutMode.mobile) {
      final portraitLocked = settings.mobilePlaybackPortraitUserLocked.value;
      final landscape = portraitLocked
          ? false
          : MediaQuery.orientationOf(context) == Orientation.landscape;
      unawaited(
        settings.applyMobilePlayerOrientationChrome(
          landscapePlayback: landscape,
        ),
      );
      if (landscape && !portraitLocked) {
        void redo() {
          if (!mounted) return;
          if (MediaQuery.orientationOf(context) != Orientation.landscape) {
            return;
          }
          unawaited(
            settings.applyMobilePlayerOrientationChrome(
              landscapePlayback: true,
            ),
          );
        }

        Future<void>.delayed(const Duration(milliseconds: 120), redo);
        Future<void>.delayed(const Duration(milliseconds: 400), redo);
        Future<void>.delayed(const Duration(milliseconds: 900), redo);
      }
      return;
    }

    if (layout == AppLayoutMode.tablet) {
      final landscape =
          MediaQuery.orientationOf(context) == Orientation.landscape;
      unawaited(
        settings.applyTabletPlayerOrientationChrome(
          landscapePlayback: landscape,
        ),
      );
      if (landscape) {
        void redoTablet() {
          if (!mounted) return;
          if (MediaQuery.orientationOf(context) != Orientation.landscape) {
            return;
          }
          unawaited(
            settings.applyTabletPlayerOrientationChrome(
              landscapePlayback: true,
            ),
          );
        }

        Future<void>.delayed(const Duration(milliseconds: 120), redoTablet);
        Future<void>.delayed(const Duration(milliseconds: 400), redoTablet);
        Future<void>.delayed(const Duration(milliseconds: 900), redoTablet);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_hardwareKeyHandler);
    _busyWorker = ever(controller.isBusy, (bool busy) {
      if (!busy &&
          Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv) {
        // Oynatıcı hazır olduğunda odaklanmayı tetikle.
        // TvBetterPlayerControls kendi initState'inde ve postFrame'inde zaten yapıyor
        // ama bazen Obx geçişlerinde odak kaybolabiliyor.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            FocusScope.of(context).requestFocus();
          }
        });
      }
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncPlayerSystemChrome());
    controller.onRequestLiveChannelStripFromTvOsd = _openLiveChannelStrip;
    controller.onRequestVodBrowseRailFromTvOsd = _openVodBrowseRail;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _syncPlayerSystemChrome();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final settings = Get.find<AppSettingsService>();
    unawaited(settings.clearMobilePlaybackPortraitLockForLeavingPlayer());
    unawaited(settings.syncSystemChromeWithLayout());
    _busyWorker?.dispose();
    HardwareKeyboard.instance.removeHandler(_hardwareKeyHandler);
    _centerKeyHoldTimer?.cancel();
    _vodCenterHoldTimer?.cancel();
    _overlayTimer?.cancel();
    controller.onRequestLiveChannelStripFromTvOsd = null;
    controller.onRequestVodBrowseRailFromTvOsd = null;
    super.dispose();
  }

  bool _isLiveChannel(Channel ch) {
    final u = ch.streamUrl.toLowerCase();
    return !u.contains('/movie/') && !u.contains('/series/');
  }

  void _openLiveChannelStrip() {
    if (controller.liveChannelStripOverlayOpen.value) return;
    controller.prepareLiveChannelStrip();
    final list = controller.liveChannelStripChannelsForOverlay();
    if (list.isEmpty) return;
    controller.liveChannelStripOverlayOpen.value = true;
    controller.hideTvOsdNow();
  }

  /// [showOsdAfter]: `true` = şerit kapanınca kumanda OSD (cam panel) açılır; yayın açık kalır.
  void _closeLiveChannelStrip({required bool showOsdAfter}) {
    if (!controller.liveChannelStripOverlayOpen.value) return;
    controller.liveChannelStripOverlayOpen.value = false;
    if (showOsdAfter) {
      controller.tvOsdVisible.value = true;
      controller.bumpTvOsdKeyFocus();
      controller.scheduleTvOsdAutoHide();
    }
  }

  void _onLiveChannelStripOverlayBackToOsd() {
    _consumeNextSystemBackPop = true;
    _closeLiveChannelStrip(showOsdAfter: true);
  }

  void _openVodBrowseRail() {
    if (!controller.vodBrowseRailAvailable) return;
    controller.openVodBrowseRail();
  }

  void _onVodBrowseRailHardwareBack() {
    _consumeNextSystemBackPop = true;
    controller.closeVodBrowseRail(showOsdAfter: true);
  }

  bool _onGlobalHardwareKey(KeyEvent event) {
    if (!mounted) return false;
    if (controller.liveSingleChannelEpgOpen.value) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
        if (event is KeyDownEvent) {
          _consumeNextSystemBackPop = true;
          controller.closeLiveSingleChannelEpgOverlay(showOsdAfter: true);
        }
        return true;
      }
      return false;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.audioVolumeUp) {
        if (controller.liveChannelStripOverlayOpen.value ||
            controller.vodBrowseRailOpen.value) {
          return false;
        }
        _nudgeInAppVolume(0.06);
        return true;
      }
      if (k == LogicalKeyboardKey.audioVolumeDown) {
        if (controller.liveChannelStripOverlayOpen.value ||
            controller.vodBrowseRailOpen.value) {
          return false;
        }
        _nudgeInAppVolume(-0.06);
        return true;
      }
    }
    if (controller.vodBrowseRailOpen.value) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
        if (event is KeyDownEvent) {
          _onVodBrowseRailHardwareBack();
        }
        return true;
      }
      return false;
    }
    if (controller.liveChannelStripOverlayOpen.value) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
        if (event is KeyDownEvent) {
          _closeLiveChannelStrip(showOsdAfter: true);
        }
        return true;
      }
      if (event is KeyDownEvent) {
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.gameButtonSelect ||
            k == LogicalKeyboardKey.space) {
          _channelStripKey.currentState?.confirmSelection();
          return true;
        }
      }
      return false;
    }
    final ch = controller.channel.value;
    if (!_isLiveChannel(ch)) {
      final tv =
          Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
      if (!tv || !controller.vodBrowseRailAvailable) return false;
      final centerKey = event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter;
      if (!centerKey) return false;
      if (event is KeyDownEvent) {
        if (!_vodCenterKeyDown) {
          _vodCenterKeyDown = true;
          _vodCenterHoldTimer?.cancel();
          _vodCenterHoldTimer = Timer(const Duration(milliseconds: 520), () {
            if (!mounted || controller.vodBrowseRailOpen.value) return;
            _openVodBrowseRail();
          });
        }
      } else if (event is KeyUpEvent) {
        _vodCenterKeyDown = false;
        _vodCenterHoldTimer?.cancel();
      }
      return false;
    }

    final centerKey = event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;

    if (!centerKey) return false;

    if (event is KeyDownEvent) {
      if (!_centerKeyDown) {
        _centerKeyDown = true;
        _centerKeyHoldTimer?.cancel();
        _centerKeyHoldTimer = Timer(const Duration(milliseconds: 520), () {
          if (!mounted || controller.liveChannelStripOverlayOpen.value) {
            return;
          }
          _openLiveChannelStrip();
        });
      }
    } else if (event is KeyUpEvent) {
      _centerKeyDown = false;
      _centerKeyHoldTimer?.cancel();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final orient = MediaQuery.orientationOf(context);
    final landscape = orient == Orientation.landscape;
    if (_lastAppliedOrientationInBuild != orient) {
      _lastAppliedOrientationInBuild = orient;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPlayerSystemChrome();
      });
    }

    final tabletPlayback =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tablet;
    final uiStyle = (landscape || tabletPlayback)
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemStatusBarContrastEnforced: false,
          )
        : SystemUiOverlayStyle.light;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: uiStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_consumeNextSystemBackPop) {
            _consumeNextSystemBackPop = false;
            return;
          }
          // Sistem Geri: önce tam ekran overlay’ler (yayından çıkma yok).
          if (controller.liveSingleChannelEpgOpen.value) {
            controller.closeLiveSingleChannelEpgOverlay(showOsdAfter: true);
            return;
          }
          if (controller.vodBrowseRailOpen.value) {
            controller.closeVodBrowseRail(showOsdAfter: true);
            return;
          }
          if (controller.liveChannelStripOverlayOpen.value) {
            _closeLiveChannelStrip(showOsdAfter: true);
            return;
          }
          if (controller.vodAutoplayCountdown.value != null) {
            controller.cancelVodAutoplayCountdown(cancelledByUser: true);
            return;
          }
          if (Get.isDialogOpen == true) {
            if (controller.vodResumeDialogOpen.value) {
              Get.back<bool>(result: false);
            } else {
              Get.back<void>();
            }
            return;
          }
          controller.handleBack();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // TvBetterPlayerControls ile aynı eksen; dar pencerede yanlışlıkla çift OSD olmasın.
                final isPortrait =
                    MediaQuery.orientationOf(context) == Orientation.portrait;

                final playerWidget = Obx(() {
                  // Tüm ilgili Rx’leri erken return’lerden önce oku; iç içe Obx kullanma.
                  final busy = controller.isBusy.value;
                  controller.suppressLiveZapLoadingUi.value;
                  controller.vodResumeDialogOpen.value;
                  final message = controller.error.value;
                  final fit = controller.videoFit.value;
                  controller.betterSurfaceEpoch.value;
                  final bp = controller.better;
                  final settings = Get.find<AppSettingsService>();
                  controller.betterOsdOverride.value;
                  final useMediaKitPlayer = controller.effectiveUseMediaKit;
                  controller.orphanBetterSurfaceRecoveryAttempts.value;

                  final remoteNav = remoteNavForScreenLayout(
                      context, settings.layoutMode.value);
                  final liveCh =
                      remoteNav && _isLiveChannel(controller.channel.value);
                  final live = _isLiveChannel(controller.channel.value);

                  final loadMsg = 'player.loading.stream'.tr;

                  if (message != null) {
                    final err = _PlayerMessage(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final h = constraints.maxHeight;
                          final maxScroll =
                              h.isFinite ? math.max(120.0, h - 88) : 320.0;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.signal_wifi_off_rounded,
                                size: 48,
                                color: Colors.red.shade200,
                              ),
                              const SizedBox(height: 16),
                              ConstrainedBox(
                                constraints:
                                    BoxConstraints(maxHeight: maxScroll),
                                child: SingleChildScrollView(
                                  child: Text(
                                    message,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                    return _liveRemoteZapWhenPlayerChromeMissing(
                      controller: controller,
                      enable: liveCh,
                      child: err,
                    );
                  }

                  final hasSurface = useMediaKitPlayer || bp != null;

                  if (!hasSurface) {
                    if (busy) {
                      if (liveCh) {
                        final suppress =
                            controller.suppressLiveZapLoadingUi.value;
                        return Focus(
                          autofocus: true,
                          onKeyEvent: (node, event) {
                            if (event is! KeyDownEvent &&
                                event is! KeyRepeatEvent) {
                              return KeyEventResult.ignored;
                            }
                            if (controller.vodResumeDialogOpen.value ||
                                controller.vodAutoplayCountdown.value != null) {
                              return KeyEventResult.ignored;
                            }
                            final k = event.logicalKey;
                            if (k == LogicalKeyboardKey.arrowUp ||
                                k == LogicalKeyboardKey.arrowLeft) {
                              controller.zapRelativeDebounced(-1);
                              return KeyEventResult.handled;
                            }
                            if (k == LogicalKeyboardKey.arrowDown ||
                                k == LogicalKeyboardKey.arrowRight) {
                              controller.zapRelativeDebounced(1);
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              const ColoredBox(color: Color(0xFF0D0D0F)),
                              if (!suppress)
                                _PlayerLoadingOverlay(
                                  channel: controller.channel.value,
                                  subtitle: loadMsg,
                                ),
                              // TV'de yüzey henüz yokken bile OSD'yi göster (logo/kanal ismi güncellenir)
                              if (useMediaKitPlayer)
                                Obx(() {
                                  final cid = controller.channel.value.id;
                                  return TvMediaKitPlayerControls(
                                    key: ValueKey('mk_osd_init_$cid'),
                                    onPlayerVisibilityChanged: (v) {
                                      controller
                                          .syncTvOsdVisibilityFromControls(v);
                                    },
                                  );
                                }),
                            ],
                          ),
                        );
                      }
                      return _PlayerMessage(
                        child: _PlayerLoadingCenter(
                          channel: controller.channel.value,
                          subtitle: loadMsg,
                        ),
                      );
                    }
                    if (!useMediaKitPlayer &&
                        controller.orphanBetterSurfaceRecoveryAttempts.value >=
                            controller.effectiveMaxOrphanBetterSurfaceRetries) {
                      final notReady = _PlayerMessage(
                        child: Text(
                          'player.notReady'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16),
                        ),
                      );
                      return _liveRemoteZapWhenPlayerChromeMissing(
                        controller: controller,
                        enable: liveCh,
                        child: notReady,
                      );
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      unawaited(controller.ensureOrphanBetterBootRetry());
                    });
                    final recovering = _PlayerMessage(
                      child: _PlayerLoadingCenter(
                        channel: controller.channel.value,
                        subtitle: loadMsg,
                      ),
                    );
                    return _liveRemoteZapWhenPlayerChromeMissing(
                      controller: controller,
                      enable: liveCh,
                      child: recovering,
                    );
                  }

                  if (useMediaKitPlayer) {
                    controller.mediaKitAttachEpoch.value;
                  }

                  final player = UniversalVideoPlayer(
                    key: _videoSurfaceKey,
                    url: controller.surfaceStreamUrl,
                    useMediaKit: useMediaKitPlayer,
                    betterPlayerController: bp,
                    fit: fit,
                    onMediaKitPlayerChanged: controller.attachMediaKitPlayer,
                  );

                  final mkOsd = useMediaKitPlayer && !isPortrait
                      ? Obx(() {
                          final epoch = controller.mediaKitAttachEpoch.value;
                          final cid = controller.channel.value.id;
                          return TvMediaKitPlayerControls(
                            key: ValueKey('mk_osd_${cid}_$epoch'),
                            onPlayerVisibilityChanged: (v) {
                              controller.syncTvOsdVisibilityFromControls(v);
                            },
                          );
                        })
                      : null;

                  Widget addBusyShell(Widget core) {
                    if (!busy) return core;
                    final suppress = controller.suppressLiveZapLoadingUi.value;
                    if (liveCh || suppress) {
                      return core;
                    }
                    // Mobil dikey: kanal değişiminde tam ekran logo/splash yerine
                    // mevcut player kontrolleri kalsın, yalnız merkezde loading görünsün.
                    if (isPortrait) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          core,
                          const Positioned.fill(
                            child: _PlayerCenterLoadingSpinner(),
                          ),
                        ],
                      );
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        core,
                        Positioned.fill(
                          child: _PlayerLoadingOverlay(
                            channel: controller.channel.value,
                            subtitle: loadMsg,
                          ),
                        ),
                      ],
                    );
                  }

                  if (remoteNav) {
                    // TV / tablet kumanda veya mobil yatay: ok ile OSD, oklar ile kanal (canlı).
                    return ExcludeFocus(
                      excluding: controller.vodResumeDialogOpen.value,
                      child: Focus(
                        // Yalnızca yedek: birincil odak Tv*PlayerControls’ta olmalı; burada
                        // autofocus verilirse dış düğüm odak çalar ve oklar yalnız zap yapıp
                        // OSD açılmaz (kilitlenme).
                        autofocus: false,
                        canRequestFocus: false,
                        onKeyEvent: (node, event) {
                          if (event is! KeyDownEvent) {
                            return KeyEventResult.ignored;
                          }
                          // VOD devam diyaloğu açıkken yut. [Get.isDialogOpen] kapanışta
                          // yanlışlıkla true kalabildiği için burada kullanılmıyor.
                          if (controller.vodResumeDialogOpen.value) {
                            return KeyEventResult.ignored;
                          }
                          final k = event.logicalKey;
                          // Odak üst katmana kaçtıysa: tek ok basışı yalnız OSD aç (zap yok).
                          if (!controller.tvOsdVisible.value) {
                            if (k == LogicalKeyboardKey.arrowUp ||
                                k == LogicalKeyboardKey.arrowDown ||
                                k == LogicalKeyboardKey.arrowLeft ||
                                k == LogicalKeyboardKey.arrowRight) {
                              controller.tvOsdVisible.value = true;
                              controller.scheduleTvOsdAutoHide();
                              return KeyEventResult.handled;
                            }
                            if (k == LogicalKeyboardKey.select ||
                                k == LogicalKeyboardKey.enter ||
                                k == LogicalKeyboardKey.numpadEnter) {
                              controller.tvOsdVisible.value = true;
                              controller.scheduleTvOsdAutoHide();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: addBusyShell(
                          GestureDetector(
                            onVerticalDragStart: _handleVerticalDragStart,
                            onVerticalDragUpdate: _handleVerticalDragUpdate,
                            onLongPress: live
                                ? _openLiveChannelStrip
                                : (controller.vodBrowseRailAvailable
                                    ? _openVodBrowseRail
                                    : null),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                player,
                                if (useMediaKitPlayer)
                                  _PlaybackVideoDimmer(controller: controller),
                                if (useMediaKitPlayer && mkOsd != null) mkOsd,
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  if (useMediaKitPlayer && mkOsd != null) {
                    return addBusyShell(
                      GestureDetector(
                        onVerticalDragStart: _handleVerticalDragStart,
                        onVerticalDragUpdate: _handleVerticalDragUpdate,
                        onLongPress: live
                            ? _openLiveChannelStrip
                            : (controller.vodBrowseRailAvailable
                                ? _openVodBrowseRail
                                : null),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            player,
                            if (useMediaKitPlayer)
                              _PlaybackVideoDimmer(controller: controller),
                            mkOsd,
                          ],
                        ),
                      ),
                    );
                  }
                  return addBusyShell(
                    GestureDetector(
                      onVerticalDragStart: _handleVerticalDragStart,
                      onVerticalDragUpdate: _handleVerticalDragUpdate,
                      onLongPress: live
                          ? _openLiveChannelStrip
                          : (controller.vodBrowseRailAvailable
                              ? _openVodBrowseRail
                              : null),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          player,
                          if (useMediaKitPlayer)
                            _PlaybackVideoDimmer(controller: controller),
                        ],
                      ),
                    ),
                  );
                });

                return Stack(
                  children: [
                    Obx(
                      () => ExcludeFocus(
                        excluding:
                            controller.liveChannelStripOverlayOpen.value ||
                                controller.liveSingleChannelEpgOpen.value ||
                                controller.vodBrowseRailOpen.value,
                        child: isPortrait
                            ? _PlayerPortraitSurfaceShell(
                                controller: controller,
                                playerWidget: playerWidget,
                              )
                            : playerWidget,
                      ),
                    ),
                    Obx(() => AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _showOverlay.value ? 1.0 : 0.0,
                          child: PlayerGlassLevelOverlay(
                            visible: _showOverlay.value,
                            icon: _overlayIcon.value,
                            value01: _overlayValue.value,
                          ),
                        )),
                    _PlayerFadeLayer(controller: controller),
                    _PlayerLiveStripLayer(
                      controller: controller,
                      channelStripKey: _channelStripKey,
                      onClose: (showOsdAfter) =>
                          _closeLiveChannelStrip(showOsdAfter: showOsdAfter),
                      onBackToOsd: _onLiveChannelStripOverlayBackToOsd,
                    ),
                    _PlayerLiveSingleEpgLayer(
                      controller: controller,
                      onHardwareBack: () {
                        _consumeNextSystemBackPop = true;
                      },
                    ),
                    _PlayerVodBrowseRailLayer(
                      controller: controller,
                      onHardwareBack: _onVodBrowseRailHardwareBack,
                    ),
                    VodAutoplayOverlay(controller: controller),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PortraitOsdPanel extends StatefulWidget {
  const _PortraitOsdPanel({required this.controller});

  final PlayerController controller;

  @override
  State<_PortraitOsdPanel> createState() => _PortraitOsdPanelState();
}

class _PlayerPortraitSurfaceShell extends StatelessWidget {
  const _PlayerPortraitSurfaceShell({
    required this.controller,
    required this.playerWidget,
  });

  final PlayerController controller;
  final Widget playerWidget;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final layout = Get.find<AppSettingsService>().layoutMode.value;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: playerWidget,
          ),
          const SizedBox(height: 24),
          _PortraitOsdPanel(controller: controller),
          if (layout != AppLayoutMode.tv) ...[
            const SizedBox(height: 12),
            _PortraitCategoryChannelBar(controller: controller),
          ],
        ],
      );
    });
  }
}

class _PlayerFadeLayer extends StatelessWidget {
  const _PlayerFadeLayer({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() => IgnorePointer(
          ignoring: !controller.isFading.value,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: controller.isFading.value ? 1.0 : 0.0,
            child: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ));
  }
}

class _PlayerLiveStripLayer extends StatelessWidget {
  const _PlayerLiveStripLayer({
    required this.controller,
    required this.channelStripKey,
    required this.onClose,
    required this.onBackToOsd,
  });

  final PlayerController controller;
  final GlobalKey<LiveChannelStripOverlayState> channelStripKey;
  final void Function(bool showOsdAfter) onClose;
  final VoidCallback onBackToOsd;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.liveChannelStripOverlayOpen.value) {
        return const SizedBox.shrink();
      }
      controller.liveStripCategoryIndex.value;
      final chipNames = controller.liveStripCategoryTabNames();
      final channels = controller.liveChannelStripChannelsForOverlay();
      if (channels.isEmpty) return const SizedBox.shrink();
      final catTabs = controller.liveChannelStripShowsCategoryTabs;
      final chipIdx = chipNames.isEmpty
          ? 0
          : controller.liveStripCategoryIndex.value.clamp(0, chipNames.length - 1);
      return LiveChannelStripOverlay(
        key: channelStripKey,
        channels: List<Channel>.from(channels),
        currentChannelId: controller.channel.value.id,
        onClose: () => onClose(true),
        onBackToOsd: onBackToOsd,
        categoryShortcutEnabled: catTabs,
        onCategoryPrevious: catTabs ? () => controller.shiftLiveStripCategory(-1) : null,
        onCategoryNext: catTabs ? () => controller.shiftLiveStripCategory(1) : null,
        categoryChipLabels: chipNames.isNotEmpty ? chipNames : null,
        selectedCategoryChipIndex: chipIdx,
        onPick: (ch) async {
          onClose(false);
          await controller.zapTo(ch);
        },
      );
    });
  }
}

class _PlayerLiveSingleEpgLayer extends StatelessWidget {
  const _PlayerLiveSingleEpgLayer({
    required this.controller,
    required this.onHardwareBack,
  });

  final PlayerController controller;
  final VoidCallback onHardwareBack;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.liveSingleChannelEpgOpen.value) {
        return const SizedBox.shrink();
      }
      return PlayerLiveEpgOverlayShell(
        channel: controller.channel.value,
        onClose: () => controller.closeLiveSingleChannelEpgOverlay(
          showOsdAfter: true,
        ),
        onHardwareBack: () {
          onHardwareBack();
          controller.closeLiveSingleChannelEpgOverlay(showOsdAfter: true);
        },
      );
    });
  }
}

class _PlayerVodBrowseRailLayer extends StatelessWidget {
  const _PlayerVodBrowseRailLayer({
    required this.controller,
    required this.onHardwareBack,
  });

  final PlayerController controller;
  final VoidCallback onHardwareBack;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.vodBrowseRailOpen.value) {
        return const SizedBox.shrink();
      }
      controller.vodBrowseRailCategoryIndex.value;
      final chipNames = controller.vodBrowseRailCategoryTabNames;
      final chipIdx = chipNames.isEmpty
          ? 0
          : controller.vodBrowseRailCategoryIndex.value.clamp(0, chipNames.length - 1);
      final movies = controller.vodBrowseRailMovies;
      final catTabs = controller.vodBrowseRailShowsCategoryTabs;
      if (movies != null && movies.isNotEmpty) {
        return VodBrowseRailOverlay(
          isMovieMode: true,
          movies: List<Channel>.from(movies),
          series: const <SeriesItem>[],
          currentMovieId: controller.channel.value.id,
          currentSeriesId: null,
          onPickMovie: (c) async {
            await controller.pickVodBrowseRailMovie(c);
            controller.closeVodBrowseRail(showOsdAfter: true);
          },
          onPickSeries: (_) async {},
          onClose: () => controller.closeVodBrowseRail(showOsdAfter: true),
          onHardwareBack: onHardwareBack,
          categoryShortcutEnabled: catTabs,
          onCategoryPrevious: catTabs ? () => controller.shiftVodBrowseRailCategory(-1) : null,
          onCategoryNext: catTabs ? () => controller.shiftVodBrowseRailCategory(1) : null,
          categoryChipLabels: chipNames.isNotEmpty ? chipNames : null,
          selectedCategoryChipIndex: chipIdx,
        );
      }
      final series = controller.vodBrowseRailSeriesItems;
      if (series != null && series.isNotEmpty) {
        return VodBrowseRailOverlay(
          isMovieMode: false,
          movies: const <Channel>[],
          series: List<SeriesItem>.from(series),
          currentMovieId: controller.channel.value.id,
          currentSeriesId: controller.playingSeries?.id,
          onPickMovie: (_) async {},
          onPickSeries: (s) async {
            await controller.pickVodBrowseRailSeries(s);
            controller.closeVodBrowseRail(showOsdAfter: true);
          },
          onClose: () => controller.closeVodBrowseRail(showOsdAfter: true),
          onHardwareBack: onHardwareBack,
          categoryShortcutEnabled: catTabs,
          onCategoryPrevious: catTabs ? () => controller.shiftVodBrowseRailCategory(-1) : null,
          onCategoryNext: catTabs ? () => controller.shiftVodBrowseRailCategory(1) : null,
          categoryChipLabels: chipNames.isNotEmpty ? chipNames : null,
          selectedCategoryChipIndex: chipIdx,
        );
      }
      return const SizedBox.shrink();
    });
  }
}

class _PortraitOsdPanelState extends State<_PortraitOsdPanel> {
  final _fav = Get.find<FavoritesService>();

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final landscape = orientation == Orientation.landscape;
        return Obx(() {
          final ch = widget.controller.channel.value;
          widget.controller.osdQualityStamp.value;
          widget.controller.betterSurfaceEpoch.value;
          final resolutionTier = widget.controller.osdStreamResolutionTierLabel;
          final hzLabel = widget.controller.osdStreamFrameRateHzLabel;
          final isLive = !widget.controller.isMovie &&
              !widget.controller.isSeries &&
              IptvPlaybackDefaults.isLikelyLiveStream(
                IptvPlaybackDefaults.normalizeStreamUrl(ch.streamUrl),
              );
          final quickMenuBadge = widget.controller.osdQuickMenuHoldBadgeVisible;

          final layoutTv = Get.find<AppSettingsService>().layoutMode.value ==
              AppLayoutMode.tv;
          // TV düzeni veya yatay ekranda kumanda dostu OSD (TvBetterPlayer ile aynı düğüm stili).
          final useTvOsdStyle = layoutTv || landscape;
          final favOn = isLive
              ? _fav.channelIds.contains(ch.id)
              : _fav.vodIds.contains(ch.id);

          final bp = widget.controller.better;
          final settings = Get.find<AppSettingsService>();
          settings.useMediaKit.value;
          widget.controller.mediaKitFallbackSession.value;
          widget.controller.betterOsdOverride.value;
          final useMediaKitPlayer = widget.controller.effectiveUseMediaKit;
          if (useMediaKitPlayer) {
            widget.controller.mediaKitAttachEpoch.value;
          }

          if (bp == null && !useMediaKitPlayer) return const SizedBox.shrink();
          // Dikey mod: OSD cam şeridine maksimum genişlik (yatay tam ekran OSD’ye dokunulmaz).
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Obx(() {
                final settings = Get.find<AppSettingsService>();
                final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
                final remoteStyle =
                    settings.layoutMode.value.usesRemoteNavigationStyle;
                final sigma = AppPerformance.glassSigmaRemoteStyle(
                  settings,
                  remoteStyle: remoteStyle,
                  fullSigma: 20,
                  reducedSigma: 10,
                );
                final decorated = Container(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ga.playerBarBorder),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: ga.playerBarGradientColors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ga.playerBarShadowColor,
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                ch.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.96),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  shadows: [
                                    Shadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.45),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            ...() {
                              final badges = osdStreamQualityBadgeWidgets(
                                resolutionTier: resolutionTier,
                                hzLabel: hzLabel,
                                fontSize: 12,
                                borderRadius: 8,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              );
                              if (badges.isEmpty) return <Widget>[];
                              return <Widget>[
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: badges,
                                ),
                              ];
                            }(),
                          ],
                        ),
                      ),
                      if (bp != null)
                        _BetterPlayerValueBuilder(
                          bp: bp,
                          builder: (value) {
                            if (value != null &&
                                (value.duration?.inMilliseconds ?? 0) > 0) {
                              if (isLive &&
                                  !widget
                                      .controller.liveTimeshiftSeekAvailable) {
                                return const SizedBox.shrink();
                              }
                              return _VideoProgressBar(bp: bp, value: value);
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      if (bp != null)
                        _BetterPlayerValueBuilder(
                          bp: bp,
                          builder: (value) {
                            final playing = value?.isPlaying ?? false;
                            return _osdControlRow(
                              tv: useTvOsdStyle,
                              children: [
                                _osdAction(
                                  icon: Icons.fast_rewind_rounded,
                                  onTap: () => isLive &&
                                          !widget.controller
                                              .liveTimeshiftSeekAvailable
                                      ? _zap(-1)
                                      : _skip(-15),
                                  tv: useTvOsdStyle,
                                  autofocus: useTvOsdStyle,
                                ),
                                _osdAction(
                                  icon: playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  onTap: () => playing
                                      ? widget.controller.pause()
                                      : widget.controller.play(),
                                  primary: true,
                                  tv: useTvOsdStyle,
                                ),
                                _osdAction(
                                  icon: Icons.fast_forward_rounded,
                                  onTap: () => isLive &&
                                          !widget.controller
                                              .liveTimeshiftSeekAvailable
                                      ? _zap(1)
                                      : _skip(15),
                                  tv: useTvOsdStyle,
                                ),
                                _osdAction(
                                  icon: favOn
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  onTap: () => isLive
                                      ? _fav.toggleChannel(ch.id)
                                      : _fav.toggleVod(ch.id),
                                  tv: useTvOsdStyle,
                                ),
                                if (quickMenuBadge)
                                  Tooltip(
                                    message: 'player.tooltip.quickMenuOpen'.tr,
                                    child: _osdAction(
                                      icon: Icons.view_sidebar_rounded,
                                      onTap: _openQuickMenuFromPortraitOsd,
                                      tv: useTvOsdStyle,
                                    ),
                                  ),
                                Obx(() {
                                  widget.controller.betterOsdOverride.value;
                                  Get.find<AppSettingsService>()
                                      .useMediaKit
                                      .value;
                                  widget
                                      .controller.mediaKitFallbackSession.value;
                                  if (widget.controller.effectiveUseMediaKit) {
                                    return const SizedBox.shrink();
                                  }
                                  return _osdAction(
                                    letter: 'M',
                                    onTap: () => unawaited(
                                      widget.controller.switchToBackupPlayer(),
                                    ),
                                    tv: useTvOsdStyle,
                                  );
                                }),
                                _osdAction(
                                  icon: Icons.high_quality_rounded,
                                  onTap: () => _showQualityMenu(context),
                                  tv: useTvOsdStyle,
                                ),
                                if (!isLive) ...[
                                  _osdAction(
                                    icon: Icons.audiotrack_rounded,
                                    onTap: () =>
                                        unawaited(_showAudioMenu(context)),
                                    tv: useTvOsdStyle,
                                  ),
                                  _osdAction(
                                    icon: Icons.closed_caption_rounded,
                                    onTap: () =>
                                        unawaited(_showSubtitleMenu(context)),
                                    tv: useTvOsdStyle,
                                  ),
                                ],
                                if (Platform.isAndroid || Platform.isIOS)
                                  Obx(() {
                                    Get.find<AppSettingsService>()
                                        .layoutMode
                                        .value;
                                    widget.controller.mediaKitFallbackSession
                                        .value;
                                    Get.find<AppSettingsService>()
                                        .useMediaKit
                                        .value;
                                    if (widget
                                            .controller.effectiveUseMediaKit ||
                                        Get.find<AppSettingsService>()
                                                .layoutMode
                                                .value ==
                                            AppLayoutMode.tv) {
                                      return const SizedBox.shrink();
                                    }
                                    return _osdAction(
                                      icon:
                                          Icons.picture_in_picture_alt_rounded,
                                      onTap: () => unawaited(widget.controller
                                          .enterPictureInPictureIfSupported()),
                                      tv: useTvOsdStyle,
                                    );
                                  }),
                                Obx(() {
                                  final s = Get.find<AppSettingsService>();
                                  if (s.layoutMode.value !=
                                      AppLayoutMode.mobile) {
                                    return const SizedBox.shrink();
                                  }
                                  final toPortrait = landscape;
                                  return Tooltip(
                                    message: toPortrait
                                        ? 'player.tooltip.toPortrait'.tr
                                        : 'player.tooltip.toLandscape'.tr,
                                    child: _osdAction(
                                      icon: toPortrait
                                          ? Icons.stay_current_portrait_rounded
                                          : Icons.screen_rotation_rounded,
                                      onTap: () => unawaited(
                                        PlaybackOrientationManager
                                            .toggleMobileForcedOrientation(),
                                      ),
                                      tv: useTvOsdStyle,
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        )
                      else if (useMediaKitPlayer)
                        _MediaKitPortraitStreamBuilder(
                          controller: widget.controller,
                          builder: (v) {
                            final playing = v?.playing ?? false;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isLive &&
                                    v != null &&
                                    v.duration.inMilliseconds > 0)
                                  _MkPortraitProgressBar(
                                    position: v.position,
                                    duration: v.duration,
                                    onSeek: widget.controller.seekTo,
                                  ),
                                _osdControlRow(
                                  tv: useTvOsdStyle,
                                  children: [
                                    _osdAction(
                                      icon: Icons.fast_rewind_rounded,
                                      onTap: () =>
                                          isLive ? _zap(-1) : _skip(-15),
                                      tv: useTvOsdStyle,
                                      autofocus: useTvOsdStyle,
                                    ),
                                    _osdAction(
                                      icon: playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      onTap: () => playing
                                          ? widget.controller.pause()
                                          : widget.controller.play(),
                                      primary: true,
                                      tv: useTvOsdStyle,
                                    ),
                                    _osdAction(
                                      icon: Icons.fast_forward_rounded,
                                      onTap: () => isLive ? _zap(1) : _skip(15),
                                      tv: useTvOsdStyle,
                                    ),
                                    _osdAction(
                                      icon: favOn
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      onTap: () => isLive
                                          ? _fav.toggleChannel(ch.id)
                                          : _fav.toggleVod(ch.id),
                                      tv: useTvOsdStyle,
                                    ),
                                    if (quickMenuBadge)
                                      Tooltip(
                                        message:
                                            'player.tooltip.quickMenuOpen'.tr,
                                        child: _osdAction(
                                          icon: Icons.view_sidebar_rounded,
                                          onTap: _openQuickMenuFromPortraitOsd,
                                          tv: useTvOsdStyle,
                                        ),
                                      ),
                                    _osdAction(
                                      icon: Icons.high_quality_rounded,
                                      onTap: () => _showMkQualityMenu(context),
                                      tv: useTvOsdStyle,
                                    ),
                                    _osdAction(
                                      icon: Icons.audiotrack_rounded,
                                      onTap: () => _showMkAudioMenu(context),
                                      tv: useTvOsdStyle,
                                    ),
                                    _osdAction(
                                      icon: Icons.closed_caption_rounded,
                                      onTap: () => _showMkSubtitleMenu(context),
                                      tv: useTvOsdStyle,
                                    ),
                                    _osdAction(
                                      letter: 'B',
                                      onTap: () => unawaited(
                                        widget.controller
                                            .promptSwitchToBetterFromMediaKit(),
                                      ),
                                      tv: useTvOsdStyle,
                                    ),
                                    Obx(() {
                                      final s = Get.find<AppSettingsService>();
                                      if (s.layoutMode.value !=
                                          AppLayoutMode.mobile) {
                                        return const SizedBox.shrink();
                                      }
                                      final toPortrait = landscape;
                                      return Tooltip(
                                        message: toPortrait
                                            ? 'player.tooltip.toPortrait'.tr
                                            : 'player.tooltip.toLandscape'.tr,
                                        child: _osdAction(
                                          icon: toPortrait
                                              ? Icons
                                                  .stay_current_portrait_rounded
                                              : Icons.screen_rotation_rounded,
                                          onTap: () => unawaited(
                                            PlaybackOrientationManager
                                                .toggleMobileForcedOrientation(),
                                          ),
                                          tv: useTvOsdStyle,
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                );
                if (sigma <= 0) return decorated;
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: decorated,
                );
              }),
            ),
          );
        });
      },
    );
  }

  Future<void> _showMkAudioMenu(BuildContext context) async {
    final tracks = widget.controller.mediaKitAudioTrackLabels();
    if (!context.mounted) return;
    if (tracks.isEmpty) {
      GlassSnackbar.show(
        'player.warn.title'.tr,
        'player.audio.noneShort'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final list = tracks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final active = widget.controller.mediaKitPlayer?.state.track.audio.id;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MkTrackSelectionSheet(
        title: 'player.mobile.pickAudio'.tr,
        entries: list,
        selectedId: active,
        onPick: (id) async {
          await widget.controller.setMediaKitAudioTrackById(id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _showMkQualityMenu(BuildContext context) async {
    final tracks = widget.controller.mediaKitVideoTrackLabels();
    if (!context.mounted) return;
    if (tracks.length <= 1) {
      GlassSnackbar.show(
        'player.warn.title'.tr,
        'player.warn.qualityShort'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final list = tracks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final active = widget.controller.mediaKitPlayer?.state.track.video.id;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MkTrackSelectionSheet(
        title: 'player.sheet.qualityTitle'.tr,
        entries: list,
        selectedId: active,
        onPick: (id) async {
          await widget.controller.setMediaKitVideoTrackById(id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _showAudioMenu(BuildContext context) async {
    final asms = widget.controller.better?.betterPlayerAsmsAudioTracks ?? [];
    if (asms.isNotEmpty) {
      if (!context.mounted) return;
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => _AudioSelectionSheet(
          controller: widget.controller,
          tracks: asms,
        ),
      );
      return;
    }
    final exo = await widget.controller.loadExoNativeTracks();
    if (!context.mounted) return;
    if (exo.audio.isEmpty) {
      GlassSnackbar.show(
        'player.warn.title'.tr,
        'player.audio.noneShort'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ExoNativeAudioSheet(
        controller: widget.controller,
        tracks: exo.audio,
      ),
    );
  }

  Future<void> _showSubtitleMenu(BuildContext context) async {
    final list = widget.controller.availableSubtitleSources;
    final exo = await widget.controller.loadExoNativeTracks();
    if (!context.mounted) return;
    final hasExternal = list.any(
      (s) => s.type != BetterPlayerSubtitlesSourceType.none,
    );
    if (!hasExternal && exo.text.isEmpty) {
      GlassSnackbar.show(
        'player.warn.title'.tr,
        'player.subtitle.noneShort'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _UnifiedSubtitleSheet(
        controller: widget.controller,
        sources: list,
        exoTextTracks: exo.text,
      ),
    );
  }

  Future<void> _showMkSubtitleMenu(BuildContext context) async {
    final tracks = widget.controller.mediaKitSubtitleTrackLabels();
    if (!context.mounted) return;
    final realCount = tracks.keys.where((k) => k != 'no').length;
    if (realCount == 0) {
      GlassSnackbar.show(
        'player.warn.title'.tr,
        'player.subtitle.noneShort'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final list = tracks.entries.toList()
      ..sort((a, b) {
        if (a.key == 'no') return -1;
        if (b.key == 'no') return 1;
        return a.key.compareTo(b.key);
      });
    final active =
        widget.controller.mediaKitPlayer?.state.track.subtitle.id ?? 'no';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MkTrackSelectionSheet(
        title: 'player.sheet.subtitleTitle'.tr,
        entries: list,
        selectedId: active,
        onPick: (id) async {
          await widget.controller.setMediaKitSubtitleById(id);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showQualityMenu(BuildContext context) {
    final tracks = widget.controller.availableTracks;
    if (tracks.isEmpty) {
      GlassSnackbar.show(
        'player.warn.title'.tr,
        'player.warn.qualityShort'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _QualitySelectionSheet(
        controller: widget.controller,
        tracks: tracks,
      ),
    );
  }

  void _skip(int s) {
    final cur = widget.controller.currentPosition;
    widget.controller.seekTo(cur + Duration(seconds: s));
  }

  void _zap(int d) {
    // Yatay OSD ile aynı: yalnızca mevcut kategorideki canlı sırası ([PlayerController.zapRelative]).
    unawaited(widget.controller.zapRelative(d));
  }

  void _openQuickMenuFromPortraitOsd() {
    final c = widget.controller;
    if (c.vodBrowseRailAvailable) {
      c.requestOpenVodBrowseRailFromTvOsd();
    } else {
      c.requestOpenLiveChannelStripFromTvOsd();
    }
  }

  Widget _osdControlRow({
    required bool tv,
    required List<Widget> children,
  }) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(width: 6));
      spaced.add(children[i]);
    }
    // Sadece bu panel dikey modda; tuşlar sığdığında ortalanır, sığmazsa yatay kaydırma (taşma yok).
    final scrollable = LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: spaced,
            ),
          ),
        );
      },
    );
    if (tv) {
      return FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: scrollable,
      );
    }
    return scrollable;
  }

  Widget _osdAction({
    IconData? icon,
    String? letter,
    required VoidCallback onTap,
    bool primary = false,
    bool tv = false,
    bool autofocus = false,
  }) {
    assert(icon != null || (letter != null && letter.isNotEmpty));
    if (tv) {
      return _TvFocusableOsdButton(
        icon: icon,
        letter: letter,
        onTap: onTap,
        primary: primary,
        autofocus: autofocus,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Obx(() {
          final isFb = Get.find<AppSettingsService>().themeLabel.value ==
              GlassThemeLabels.flatBlack;
          return Container(
            padding: EdgeInsets.all(primary ? 12 : 8),
            decoration: primary
                ? BoxDecoration(
                    color: isFb
                        ? const Color(0xFF0C0C0C)
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  )
                : null,
            child: letter != null
                ? Text(
                    letter,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: primary ? 22 : 18,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  )
                : Icon(
                    icon!,
                    color: Colors.white,
                    size: primary ? 32 : 24,
                  ),
          );
        }),
      ),
    );
  }
}

/// Dikey mod (telefon/tablet): OSD ile aynı cam panel — aynı kategorideki canlı kanallar.
class _PortraitCategoryChannelBar extends StatefulWidget {
  const _PortraitCategoryChannelBar({required this.controller});

  final PlayerController controller;

  @override
  State<_PortraitCategoryChannelBar> createState() =>
      _PortraitCategoryChannelBarState();
}

class _PortraitCategoryChannelBarState
    extends State<_PortraitCategoryChannelBar> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _selectedChannelKey = GlobalKey();
  Worker? _channelWorker;

  @override
  void initState() {
    super.initState();
    _channelWorker =
        ever(widget.controller.channel, (_) => _scrollSelectedToStart());
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollSelectedToStart());
  }

  @override
  void dispose() {
    _channelWorker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollSelectedToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _selectedChannelKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: AppPerformance.uiDuration(
          const Duration(milliseconds: 260),
        ),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      widget.controller.channel.value;
      final list = widget.controller.liveChannelsInCurrentCategory();
      if (list.length <= 1) return const SizedBox.shrink();

      final stripInner = Container(
        height: 100,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final ch = list[i];
            final sel = ch.id == widget.controller.channel.value.id;
            final primary = Theme.of(context).colorScheme.primary;
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final logoPx = (34 * dpr).round();
            final logoUrl = ch.logoUrl?.trim();
            final tile = Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => unawaited(widget.controller.zapTo(ch)),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 96,
                    maxWidth: 172,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          sel ? primary : Colors.white.withValues(alpha: 0.25),
                      width: sel ? 2 : 1,
                    ),
                    color: sel
                        ? primary.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ch.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 5),
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: logoUrl != null && logoUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: IptvChannelLogo(
                                  imageUrl: logoUrl,
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.contain,
                                  memCacheWidth: logoPx,
                                  memCacheHeight: logoPx,
                                  showProgressIndicator: true,
                                  progressIndicatorColor: Colors.white24,
                                  errorWidget: Icon(
                                    Icons.live_tv_rounded,
                                    color: Colors.white.withValues(alpha: 0.75),
                                    size: 26,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.live_tv_rounded,
                                color: Colors.white.withValues(alpha: 0.75),
                                size: 26,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            return Align(
              key: sel ? _selectedChannelKey : ValueKey<int>(ch.id),
              child: tile,
            );
          },
        ),
      );

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: stripInner,
          ),
        ),
      );
    });
  }
}

/// TV kumandası: OK / Enter ile `onTap`, odak çerçevesi ile görünürlük.
class _TvFocusableOsdButton extends StatefulWidget {
  _TvFocusableOsdButton({
    this.icon,
    this.letter,
    required this.onTap,
    this.primary = false,
    this.autofocus = false,
  }) : assert(icon != null || (letter != null && letter.isNotEmpty));

  final IconData? icon;
  final String? letter;
  final VoidCallback onTap;
  final bool primary;
  final bool autofocus;

  @override
  State<_TvFocusableOsdButton> createState() => _TvFocusableOsdButtonState();
}

class _TvFocusableOsdButtonState extends State<_TvFocusableOsdButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final isFb = Get.find<AppSettingsService>().themeLabel.value ==
          GlassThemeLabels.flatBlack;
      final borderColor = _focused
          ? (isFb
              ? const Color(0xFF1A1A1A)
              : scheme.primary.withValues(alpha: 0.95))
          : Colors.white.withValues(alpha: 0.2);

      return Focus(
        autofocus: widget.autofocus,
        onFocusChange: (v) => setState(() => _focused = v),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final k = event.logicalKey;
          if (k == LogicalKeyboardKey.select ||
              k == LogicalKeyboardKey.enter ||
              k == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: EdgeInsets.all(widget.primary ? 12 : 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: _focused ? 2 : 1),
                color: widget.primary
                    ? (isFb
                        ? const Color(0xFF0C0C0C)
                            .withValues(alpha: _focused ? 0.95 : 0.88)
                        : scheme.primary
                            .withValues(alpha: _focused ? 0.35 : 0.2))
                    : (_focused
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.transparent),
              ),
              child: widget.letter != null
                  ? Text(
                      widget.letter!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.primary ? 22 : 18,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    )
                  : Icon(
                      widget.icon!,
                      color: Colors.white,
                      size: widget.primary ? 32 : 24,
                    ),
            ),
          ),
        ),
      );
    });
  }
}

class _AudioSelectionSheet extends StatelessWidget {
  const _AudioSelectionSheet({
    required this.controller,
    required this.tracks,
  });

  final PlayerController controller;
  final List<BetterPlayerAsmsAudioTrack> tracks;

  @override
  Widget build(BuildContext context) {
    final active = controller.better?.betterPlayerAsmsAudioTrack;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: GlassPopupPanel(
        topCornersOnly: true,
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.audiotrack_rounded, color: Colors.white70),
                  const SizedBox(width: 12),
                  Text(
                    'player.mobile.pickAudio'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: Colors.white10,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final t = tracks[index];
                    final isSelected = active?.id == t.id ||
                        (active == null && index == 0); // Default first

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        controller.better?.setAudioTrack(t);
                        Get.back();
                        GlassSnackbar.show(
                          'player.snackbar.audioChanged'.tr,
                          t.label ??
                              'player.track.audio'
                                  .trParams({'n': '${index + 1}'}),
                          snackPosition: SnackPosition.BOTTOM,
                          duration: const Duration(seconds: 2),
                        );
                      },
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white30,
                      ),
                      title: Text(
                        t.label ??
                            'player.track.audio'
                                .trParams({'n': '${index + 1}'}),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.green)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExoNativeAudioSheet extends StatelessWidget {
  const _ExoNativeAudioSheet({
    required this.controller,
    required this.tracks,
  });

  final PlayerController controller;
  final List<ExoNativeTrackOption> tracks;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: GlassPopupPanel(
        topCornersOnly: true,
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.audiotrack_rounded, color: Colors.white70),
                  const SizedBox(width: 12),
                  Text(
                    'player.mobile.pickAudio'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Get.back<void>(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: Colors.white10,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final t = tracks[index];
                    final isSelected = t.selected;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () async {
                        await controller.selectExoNativeAudioTrack(t);
                        if (context.mounted) Get.back<void>();
                        GlassSnackbar.show(
                          'player.snackbar.audioChanged'.tr,
                          t.displayLabel,
                          snackPosition: SnackPosition.BOTTOM,
                          duration: const Duration(seconds: 2),
                        );
                      },
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white30,
                      ),
                      title: Text(
                        t.displayLabel,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.green)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnifiedSubtitleSheet extends StatelessWidget {
  const _UnifiedSubtitleSheet({
    required this.controller,
    required this.sources,
    required this.exoTextTracks,
  });

  final PlayerController controller;
  final List<BetterPlayerSubtitlesSource> sources;
  final List<ExoNativeTrackOption> exoTextTracks;

  static String _label(BetterPlayerSubtitlesSource s) {
    if (s.type == BetterPlayerSubtitlesSourceType.none) {
      return 'player.subtitle.off'.tr;
    }
    final n = s.name?.trim();
    if (n != null && n.isNotEmpty) return n;
    return 'player.subtitle.track'.tr;
  }

  static bool _sameSubtitle(
    BetterPlayerSubtitlesSource? a,
    BetterPlayerSubtitlesSource b,
  ) {
    if (a == null) {
      return b.type == BetterPlayerSubtitlesSourceType.none;
    }
    if (a.type != b.type) return false;
    if (a.type == BetterPlayerSubtitlesSourceType.none &&
        b.type == BetterPlayerSubtitlesSourceType.none) {
      return true;
    }
    return (a.name ?? '') == (b.name ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final active = controller.currentSubtitleSource;
    final sorted = List<BetterPlayerSubtitlesSource>.from(sources);
    sorted.sort((a, b) {
      if (a.type == BetterPlayerSubtitlesSourceType.none) return -1;
      if (b.type == BetterPlayerSubtitlesSourceType.none) return 1;
      return _label(a).toLowerCase().compareTo(_label(b).toLowerCase());
    });

    final tiles = <Widget>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0) {
        tiles.add(const Divider(color: Colors.white10, height: 1));
      }
      final s = sorted[i];
      final isSelected = _sameSubtitle(active, s);
      tiles.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () async {
            await controller.setBetterSubtitleSource(s);
            if (s.type == BetterPlayerSubtitlesSourceType.none) {
              await controller.disableExoNativeTextTracks();
            }
            if (context.mounted) Get.back<void>();
            GlassSnackbar.show(
              'player.snackbar.subtitleChanged'.tr,
              _label(s),
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 2),
            );
          },
          leading: Icon(
            isSelected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.white30,
          ),
          title: Text(
            _label(s),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_rounded, color: Colors.green)
              : null,
        ),
      );
    }

    if (exoTextTracks.isNotEmpty) {
      tiles.add(const Divider(color: Colors.white24, height: 24));
      tiles.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'player.subtitle.embedded'.tr,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      for (var j = 0; j < exoTextTracks.length; j++) {
        if (j > 0) {
          tiles.add(const Divider(color: Colors.white10, height: 1));
        }
        final opt = exoTextTracks[j];
        final isSelected = opt.selected;
        tiles.add(
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () async {
              await controller.selectExoNativeTextTrack(opt);
              if (context.mounted) Get.back<void>();
              GlassSnackbar.show(
                'player.snackbar.subtitleChanged'.tr,
                opt.displayLabel,
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 2),
              );
            },
            leading: Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white30,
            ),
            title: Text(
              opt.displayLabel,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.green)
                : null,
          ),
        );
      }
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: GlassPopupPanel(
        topCornersOnly: true,
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.closed_caption_rounded,
                      color: Colors.white70),
                  const SizedBox(width: 12),
                  Text(
                    'player.mobile.pickSubtitle'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Get.back<void>(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: tiles,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QualitySelectionSheet extends StatelessWidget {
  const _QualitySelectionSheet({
    required this.controller,
    required this.tracks,
  });

  final PlayerController controller;
  final List<BetterPlayerAsmsTrack> tracks;

  @override
  Widget build(BuildContext context) {
    String getTrackLabel(BetterPlayerAsmsTrack track) =>
        betterPlayerVideoQualityTrackLabel(track);

    final sorted = List<BetterPlayerAsmsTrack>.from(tracks);
    sorted.sort(compareBetterPlayerVideoQualityTracks);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: GlassPopupPanel(
        topCornersOnly: true,
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'player.sheet.qualityTitle'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sorted.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white10),
                itemBuilder: (context, index) {
                  final track = sorted[index];
                  final isAuto = track.width == 0 && track.height == 0;
                  final isCurrent = controller.currentTrack == track;

                  return ListTile(
                    leading: Icon(
                      isAuto ? Icons.auto_awesome : Icons.high_quality,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white60,
                    ),
                    title: Text(
                      getTrackLabel(track),
                      style: TextStyle(
                        color: isCurrent ? Colors.white : Colors.white70,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      controller.setQuality(track);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _BetterPlayerValueBuilder extends StatefulWidget {
  const _BetterPlayerValueBuilder({
    required this.bp,
    required this.builder,
  });

  final BetterPlayerController bp;
  final Widget Function(VideoPlayerValue? value) builder;

  @override
  State<_BetterPlayerValueBuilder> createState() =>
      _BetterPlayerValueBuilderState();
}

class _BetterPlayerValueBuilderState extends State<_BetterPlayerValueBuilder> {
  VideoPlayerValue? _lastRebuildValue;

  @override
  void initState() {
    super.initState();
    widget.bp.videoPlayerController?.addListener(_update);
  }

  @override
  void dispose() {
    widget.bp.videoPlayerController?.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (!mounted) return;
    final v = widget.bp.videoPlayerController?.value;
    final o = _lastRebuildValue;
    if (o != null &&
        v != null &&
        o.isPlaying == v.isPlaying &&
        o.isBuffering == v.isBuffering &&
        o.hasError == v.hasError &&
        o.duration == v.duration &&
        o.size == v.size &&
        (v.position.inMilliseconds - o.position.inMilliseconds).abs() < 500) {
      return;
    }
    _lastRebuildValue = v;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(widget.bp.videoPlayerController?.value);
  }
}

class _VideoProgressBar extends StatelessWidget {
  const _VideoProgressBar({required this.bp, required this.value});

  final BetterPlayerController bp;
  final VideoPlayerValue value;

  @override
  Widget build(BuildContext context) {
    final cur = value.position;
    final dur = value.duration ?? Duration.zero;
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: cur.inMilliseconds
                .toDouble()
                .clamp(0, dur.inMilliseconds.toDouble()),
            max: dur.inMilliseconds.toDouble() > 0
                ? dur.inMilliseconds.toDouble()
                : 1.0,
            onChanged: (v) => bp.seekTo(Duration(milliseconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmtDur(cur),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              Text(
                _fmtDur(dur),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _BetterPlayerWithKey extends StatefulWidget {
  const _BetterPlayerWithKey({
    required this.controller,
    required this.fit,
  });

  final BetterPlayerController controller;
  final BoxFit fit;

  @override
  State<_BetterPlayerWithKey> createState() => _BetterPlayerWithKeyState();
}

class _BetterPlayerWithKeyState extends State<_BetterPlayerWithKey> {
  final GlobalKey _playerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _applyFit();
  }

  @override
  void didUpdateWidget(_BetterPlayerWithKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fit != widget.fit) {
      _applyFit();
    }
  }

  void _applyFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.setBetterPlayerGlobalKey(_playerKey);
        widget.controller.setOverriddenFit(widget.fit);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BetterPlayer(
      key: _playerKey,
      controller: widget.controller,
    );
  }
}

class _MediaKitPortraitSnap {
  const _MediaKitPortraitSnap({
    required this.playing,
    required this.position,
    required this.duration,
  });

  final bool playing;
  final Duration position;
  final Duration duration;
}

class _MediaKitPortraitStreamBuilder extends StatefulWidget {
  const _MediaKitPortraitStreamBuilder({
    required this.controller,
    required this.builder,
  });

  final PlayerController controller;
  final Widget Function(_MediaKitPortraitSnap? v) builder;

  @override
  State<_MediaKitPortraitStreamBuilder> createState() =>
      _MediaKitPortraitStreamBuilderState();
}

class _MediaKitPortraitStreamBuilderState
    extends State<_MediaKitPortraitStreamBuilder> {
  Player? _target;
  final List<StreamSubscription<dynamic>> _subs = [];

  void _cancelSubs() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
  }

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(covariant _MediaKitPortraitStreamBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attach();
  }

  void _attach() {
    final p = widget.controller.mediaKitPlayer;
    if (identical(_target, p)) return;
    _cancelSubs();
    _target = p;
    if (p == null) {
      if (mounted) setState(() {});
      return;
    }
    void tick([dynamic _]) {
      if (mounted) setState(() {});
    }

    _subs.add(p.stream.playing.listen(tick));
    _subs.add(p.stream.position.listen(tick));
    _subs.add(p.stream.duration.listen(tick));
    tick();
  }

  @override
  void dispose() {
    _cancelSubs();
    super.dispose();
  }

  _MediaKitPortraitSnap? _readSnap() {
    final p = widget.controller.mediaKitPlayer;
    if (p == null) return null;
    final s = p.state;
    return _MediaKitPortraitSnap(
      playing: s.playing,
      position: s.position,
      duration: s.duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_readSnap());
  }
}

class _MkPortraitProgressBar extends StatelessWidget {
  const _MkPortraitProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final void Function(Duration) onSeek;

  static String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cur = position;
    final dur = duration;
    final totalMs = dur.inMilliseconds;
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: cur.inMilliseconds
                .toDouble()
                .clamp(0, totalMs > 0 ? totalMs.toDouble() : 1.0),
            max: totalMs > 0 ? totalMs.toDouble() : 1.0,
            onChanged: (v) => onSeek(Duration(milliseconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmtDur(cur),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              Text(
                _fmtDur(dur),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MkTrackSelectionSheet extends StatelessWidget {
  const _MkTrackSelectionSheet({
    required this.title,
    required this.entries,
    required this.selectedId,
    required this.onPick,
  });

  final String title;
  final List<MapEntry<String, String>> entries;
  final String? selectedId;
  final Future<void> Function(String id) onPick;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: GlassPopupPanel(
        topCornersOnly: true,
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Colors.white70),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: Colors.white10,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    final cur = selectedId != null && e.key == selectedId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => onPick(e.key),
                      title: Text(
                        e.value.isNotEmpty ? e.value : e.key,
                        style: TextStyle(
                          color: cur ? Colors.white : Colors.white70,
                          fontWeight: cur ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: cur
                          ? Icon(Icons.check_rounded,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yayın henüz çizilmeden önce siyah ekran yerine logo + yükleme göstergesi.
class _PlayerLoadingOverlay extends StatelessWidget {
  const _PlayerLoadingOverlay({
    required this.channel,
    required this.subtitle,
  });

  final Channel channel;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF0D0D0F)),
          Center(
            child: _PlayerLoadingCenter(
              channel: channel,
              subtitle: subtitle,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerLoadingCenter extends StatelessWidget {
  const _PlayerLoadingCenter({
    required this.channel,
    required this.subtitle,
  });

  final Channel channel;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final logo = channel.logoUrl?.trim();
    final hasLogo = logo != null &&
        logo.isNotEmpty &&
        (logo.startsWith('http://') || logo.startsWith('https://'));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasLogo)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IptvChannelLogo(
              imageUrl: logo,
              width: 112,
              height: 112,
              fit: BoxFit.contain,
              showProgressIndicator: true,
              progressIndicatorColor: Color(0xFF6ECFE0),
              placeholder: const SizedBox(
                width: 112,
                height: 112,
                child: Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF6ECFE0),
                    ),
                  ),
                ),
              ),
              errorWidget: const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF6ECFE0),
                ),
              ),
            ),
          )
        else
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFF6ECFE0),
            ),
          ),
        if (hasLogo) const SizedBox(height: 10),
        SizedBox(
          width: hasLogo ? 112 : 48,
          height: 3,
          child: const LinearProgressIndicator(
            backgroundColor: Colors.white12,
            color: Color(0xFF6ECFE0),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Dikey mod kanal geçişlerinde tam ekran splash yerine yalnız merkezde spinner.
class _PlayerCenterLoadingSpinner extends StatelessWidget {
  const _PlayerCenterLoadingSpinner();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            shape: BoxShape.circle,
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF6ECFE0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerMessage extends StatelessWidget {
  const _PlayerMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: child,
      ),
    );
  }
}
