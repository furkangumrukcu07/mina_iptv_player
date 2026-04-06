import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/services/playlist_cache_service.dart';
import '../../../domain/entities/channel.dart';
import 'widgets/live_channel_strip_overlay.dart';
import 'widgets/tv_live_busy_osd.dart';
import 'widgets/tv_media_kit_player_controls.dart';
import 'widgets/universal_video_player.dart';
import 'player_controller.dart';
import '../../../ui/glass_overlays.dart';

class PlayerView extends StatefulWidget {
  const PlayerView({super.key});

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  final controller = Get.find<PlayerController>();

  double? _dragStartValue;
  bool _isDraggingLeft = false;
  final RxDouble _overlayValue = 0.0.obs;
  final Rxn<IconData> _overlayIcon = Rxn<IconData>();
  final RxBool _showOverlay = false.obs;
  Timer? _overlayTimer;

  bool _channelStripOpen = false;
  List<Channel> _channelStripSnapshot = const [];
  Timer? _centerKeyHoldTimer;
  bool _centerKeyDown = false;

  Worker? _busyWorker;

  bool _hardwareKeyHandler(KeyEvent event) => _onGlobalHardwareKey(event);

  void _handleVerticalDragStart(DragStartDetails details) async {
    final width = MediaQuery.of(context).size.width;
    _isDraggingLeft = details.globalPosition.dx < width / 2;
    try {
      if (_isDraggingLeft) {
        _dragStartValue = await ScreenBrightness().application;
      } else {
        _dragStartValue = controller.currentVolume;
      }
    } catch (_) {
      _dragStartValue = controller.currentVolume;
      _isDraggingLeft = false;
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_dragStartValue == null) return;

    final height = MediaQuery.of(context).size.height;
    final dy = details.primaryDelta ?? details.delta.dy;
    final delta = -dy / height;
    final newValue = (_dragStartValue! + delta).clamp(0.0, 1.0);
    _dragStartValue = newValue;

    if (_isDraggingLeft) {
      try {
        ScreenBrightness().setApplicationScreenBrightness(newValue);
      } catch (_) {}
      _overlayIcon.value = Icons.brightness_6_rounded;
      _overlayValue.value = newValue;
    } else {
      controller.setVolume(newValue);
      _overlayIcon.value = newValue == 0
          ? Icons.volume_off_rounded
          : (newValue < 0.5
              ? Icons.volume_down_rounded
              : Icons.volume_up_rounded);
      _overlayValue.value = newValue;
    }

    _showOverlay.value = true;
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 800), () {
      _showOverlay.value = false;
    });
  }

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _busyWorker?.dispose();
    HardwareKeyboard.instance.removeHandler(_hardwareKeyHandler);
    _centerKeyHoldTimer?.cancel();
    _overlayTimer?.cancel();
    super.dispose();
  }

  bool _isLiveChannel(Channel ch) {
    final u = ch.streamUrl.toLowerCase();
    return !u.contains('/movie/') && !u.contains('/series/');
  }

  List<Channel> _sortedLiveChannels() {
    final cache = Get.find<PlaylistCacheService>();
    final data = cache.result.value;
    if (data == null) return [];
    final list = List<Channel>.from(data.channels)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  void _openLiveChannelStrip() {
    if (_channelStripOpen) return;
    final list = _sortedLiveChannels();
    if (list.isEmpty) return;
    controller.liveChannelStripOverlayOpen.value = true;
    controller.hideTvOsdNow();
    setState(() {
      _channelStripSnapshot = list;
      _channelStripOpen = true;
    });
  }

  bool _onGlobalHardwareKey(KeyEvent event) {
    if (!mounted || _channelStripOpen) return false;
    final ch = controller.channel.value;
    if (!_isLiveChannel(ch)) return false;

    final centerKey = event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;

    if (!centerKey) return false;

    if (event is KeyDownEvent) {
      if (!_centerKeyDown) {
        _centerKeyDown = true;
        _centerKeyHoldTimer?.cancel();
        _centerKeyHoldTimer = Timer(const Duration(milliseconds: 520), () {
          if (!mounted || _channelStripOpen) return;
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (_channelStripOpen) {
            controller.liveChannelStripOverlayOpen.value = false;
            setState(() => _channelStripOpen = false);
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
                  final decoderStep = controller.decoderFallbackStep.value;
                  final message = controller.error.value;
                  final fit = controller.videoFit.value;
                  final bp = controller.better;
                  final settings = Get.find<AppSettingsService>();
                  final isMediaKitActive = settings.useMediaKit.value ||
                      controller.mediaKitFallbackSession.value;
                  controller.betterOsdOverride.value;
                  final useMediaKitPlayer = controller.effectiveUseMediaKit;

                  final layoutTv = settings.layoutMode.value == AppLayoutMode.tv;
                  final liveCh =
                      layoutTv && _isLiveChannel(controller.channel.value);
                  final keepPlayerDuringTvLiveBusy =
                      busy && liveCh && bp != null;

                  if (busy && !keepPlayerDuringTvLiveBusy) {
                    final loadMsg = decoderStep > 0
                        ? 'player.loading.decoder'
                            .trParams({'step': '$decoderStep'})
                        : 'player.loading.stream'.tr;
                    final liveTvBusy =
                        layoutTv && _isLiveChannel(controller.channel.value);
                    if (liveTvBusy) {
                      return Focus(
                        autofocus: true,
                        onKeyEvent: (node, event) {
                          if (event is! KeyDownEvent) {
                            return KeyEventResult.ignored;
                          }
                          final k = event.logicalKey;
                          if (k == LogicalKeyboardKey.arrowUp) {
                            controller.zapRelativeDebounced(-1);
                            return KeyEventResult.handled;
                          }
                          if (k == LogicalKeyboardKey.arrowDown) {
                            controller.zapRelativeDebounced(1);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Colors.black),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Color(0xFF6ECFE0),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    loadMsg,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TvLiveBusyOsd(controller: controller),
                          ],
                        ),
                      );
                    }
                    return _PlayerMessage(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFF6ECFE0),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            loadMsg,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (message != null) {
                    return _PlayerMessage(
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
                  }

                  if (!isMediaKitActive && bp == null) {
                    return _PlayerMessage(
                      child: Text(
                        'player.notReady'.tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16),
                      ),
                    );
                  }

                  if (useMediaKitPlayer) {
                    controller.mediaKitAttachEpoch.value;
                  }

                  final live = _isLiveChannel(controller.channel.value);
                  final player = UniversalVideoPlayer(
                    url: controller.channel.value.streamUrl,
                    useMediaKit: useMediaKitPlayer,
                    betterPlayerController: bp,
                    fit: fit,
                    onMediaKitPlayerChanged: controller.attachMediaKitPlayer,
                  );

                  final mkOsd = useMediaKitPlayer && !isPortrait
                      ? Obx(() {
                          controller.mediaKitAttachEpoch.value;
                          return TvMediaKitPlayerControls(
                            onPlayerVisibilityChanged: (v) {
                              controller.tvOsdVisible.value = v;
                            },
                          );
                        })
                      : null;

                  if (layoutTv) {
                    // TV modunda MediaKit aktifse veya BetterPlayer hazırsa odak yönetimini sağla.
                    return Focus(
                      autofocus: true,
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent) {
                          return KeyEventResult.ignored;
                        }
                        final k = event.logicalKey;
                        // OSD kapalıyken ok tuşları ile kanal değiştirme (Zapping)
                        if (!controller.tvOsdVisible.value) {
                          if (k == LogicalKeyboardKey.arrowUp) {
                            controller.zapRelativeDebounced(-1);
                            return KeyEventResult.handled;
                          }
                          if (k == LogicalKeyboardKey.arrowDown) {
                            controller.zapRelativeDebounced(1);
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          player,
                          if (useMediaKitPlayer && mkOsd != null) mkOsd,
                        ],
                      ),
                    );
                  }
                  if (useMediaKitPlayer && mkOsd != null) {
                    return GestureDetector(
                      onVerticalDragStart: _handleVerticalDragStart,
                      onVerticalDragUpdate: _handleVerticalDragUpdate,
                      onLongPress: live ? _openLiveChannelStrip : null,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          player,
                          mkOsd,
                        ],
                      ),
                    );
                  }
                  return GestureDetector(
                    onVerticalDragStart: _handleVerticalDragStart,
                    onVerticalDragUpdate: _handleVerticalDragUpdate,
                    onLongPress: live ? _openLiveChannelStrip : null,
                    child: player,
                  );
                });

                return Stack(
                  children: [
                    if (isPortrait)
                      Obx(() {
                        if (controller.isBusy.value) return playerWidget;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: playerWidget,
                            ),
                            const SizedBox(height: 24),
                            _PortraitOsdPanel(controller: controller),
                          ],
                        );
                      })
                    else
                      // Yatay: tek OSD — BetterPlayer’da TvBetterPlayerControls.
                      // _PortraitOsdPanel (7 düğme şeridi) kaldırıldı; MediaKit ile üst üste biniyordu.
                      playerWidget,
                    Obx(() => AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _showOverlay.value ? 1.0 : 0.0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_overlayIcon.value,
                                      color: Colors.white, size: 42),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: 120,
                                    child: LinearProgressIndicator(
                                      value: _overlayValue.value,
                                      backgroundColor: Colors.white24,
                                      color: Colors.white,
                                      minHeight: 4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )),
                    Obx(() => IgnorePointer(
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
                        )),
                    if (_channelStripOpen && _channelStripSnapshot.isNotEmpty)
                      LiveChannelStripOverlay(
                        channels: _channelStripSnapshot,
                        currentChannelId: controller.channel.value.id,
                        onClose: () {
                          controller.liveChannelStripOverlayOpen.value = false;
                          setState(() => _channelStripOpen = false);
                        },
                        onPick: (ch) async {
                          controller.liveChannelStripOverlayOpen.value = false;
                          setState(() => _channelStripOpen = false);
                          await controller.zapTo(ch);
                        },
                      ),
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

class _PortraitOsdPanelState extends State<_PortraitOsdPanel> {
  final _fav = Get.find<FavoritesService>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ch = widget.controller.channel.value;
      final isLive = !ch.streamUrl.toLowerCase().contains('/movie/') &&
          !ch.streamUrl.toLowerCase().contains('/series/');

      final videoFit = widget.controller.videoFit.value;
      final layoutTv =
          Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
      final landscape =
          MediaQuery.orientationOf(context) == Orientation.landscape;
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isLive && bp != null)
                    _BetterPlayerValueBuilder(
                      bp: bp,
                      builder: (value) {
                        if (value != null &&
                            (value.duration?.inMilliseconds ?? 0) > 0) {
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
                              onTap: () => isLive ? _zap(-1) : _skip(-15),
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
                            _osdAction(
                              icon: _fitIcon(videoFit),
                              onTap: () => _cycleFit(),
                              tv: useTvOsdStyle,
                            ),
                            Obx(() {
                              widget.controller.betterOsdOverride.value;
                              Get.find<AppSettingsService>().useMediaKit.value;
                              widget.controller.mediaKitFallbackSession.value;
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
                            _osdAction(
                              icon: Icons.audiotrack_rounded,
                              onTap: () => _showAudioMenu(context),
                              tv: useTvOsdStyle,
                            ),
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
                                  onTap: () =>
                                      isLive ? _zap(1) : _skip(15),
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
                                _osdAction(
                                  icon: _fitIcon(videoFit),
                                  onTap: () => _cycleFit(),
                                  tv: useTvOsdStyle,
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
                                  letter: 'B',
                                  onTap: () => unawaited(
                                    widget.controller.switchToBetterPlayer(),
                                  ),
                                  tv: useTvOsdStyle,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
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

  void _showAudioMenu(BuildContext context) {
    final tracks = widget.controller.better?.betterPlayerAsmsAudioTracks ?? [];
    if (tracks.isEmpty) {
      GlassSnackbar.show(
        'player.warn.title'.tr,
        'player.audio.noneShort'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AudioSelectionSheet(
        controller: widget.controller,
        tracks: tracks,
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
    final cache = Get.find<PlaylistCacheService>();
    final data = cache.result.value;
    if (data == null) return;
    final list = List<Channel>.from(data.channels)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final idx =
        list.indexWhere((c) => c.id == widget.controller.channel.value.id);
    if (idx < 0) return;
    final ni = (idx + d) % list.length;
    final target = list[ni < 0 ? ni + list.length : ni];
    widget.controller.zapTo(target);
  }

  void _cycleFit() {
    const fits = [BoxFit.fill, BoxFit.contain, BoxFit.cover];
    final cur = widget.controller.videoFit.value;
    final ni = (fits.indexOf(cur) + 1) % fits.length;
    widget.controller.setVideoFit(fits[ni]);
  }

  IconData _fitIcon(BoxFit f) {
    if (f == BoxFit.fill) return Icons.aspect_ratio_rounded;
    if (f == BoxFit.cover) return Icons.fullscreen_rounded;
    return Icons.fit_screen_rounded;
  }

  Widget _osdControlRow({
    required bool tv,
    required List<Widget> children,
  }) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: children,
    );
    if (tv) {
      return FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: row,
      );
    }
    return row;
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
        child: Container(
          padding: EdgeInsets.all(primary ? 12 : 8),
          decoration: primary
              ? BoxDecoration(
                  color: Theme.of(context)
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
        ),
      ),
    );
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
    final borderColor = _focused
        ? scheme.primary.withValues(alpha: 0.95)
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
                  ? scheme.primary.withValues(alpha: _focused ? 0.35 : 0.2)
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
                          'player.track.audio'.trParams({'n': '${index + 1}'}),
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

class _QualitySelectionSheet extends StatelessWidget {
  const _QualitySelectionSheet({
    required this.controller,
    required this.tracks,
  });

  final PlayerController controller;
  final List<BetterPlayerAsmsTrack> tracks;

  @override
  Widget build(BuildContext context) {
    // Quality track label logic
    String getTrackLabel(BetterPlayerAsmsTrack track) {
      if (track.width == 0 || track.height == 0) {
        return 'player.quality.auto'.tr;
      }
      if (track.height != null) {
        return '${track.height}p';
      }
      return 'player.quality.unknown'.tr;
    }

    // Sort tracks by height descending, Auto at top
    final sorted = List<BetterPlayerAsmsTrack>.from(tracks);
    sorted.sort((a, b) {
      if (a.width == 0 && a.height == 0) return -1;
      if (b.width == 0 && b.height == 0) return 1;
      return (b.height ?? 0).compareTo(a.height ?? 0);
    });

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
              separatorBuilder: (_, __) => const Divider(color: Colors.white10),
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
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
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
                  final cur =
                      selectedId != null && e.key == selectedId;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => onPick(e.key),
                    title: Text(
                      e.value.isNotEmpty ? e.value : '${e.key}',
                      style: TextStyle(
                        color: cur ? Colors.white : Colors.white70,
                        fontWeight:
                            cur ? FontWeight.bold : FontWeight.normal,
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
