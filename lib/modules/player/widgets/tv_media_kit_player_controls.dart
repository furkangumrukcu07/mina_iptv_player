import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../domain/entities/channel.dart';
import '../player_controller.dart';
import '../../../ui/glass_overlays.dart';

/// MediaKit için [TvBetterPlayerControls] ile aynı cam OSD düzeni (yatay tam ekran).
class TvMediaKitPlayerControls extends StatefulWidget {
  const TvMediaKitPlayerControls({
    super.key,
    required this.onPlayerVisibilityChanged,
  });

  final void Function(bool visible) onPlayerVisibilityChanged;

  @override
  State<TvMediaKitPlayerControls> createState() =>
      _TvMediaKitPlayerControlsState();
}

class _MediaKitOsdSnapshot {
  const _MediaKitOsdSnapshot({
    required this.playing,
    required this.buffering,
    required this.position,
    required this.duration,
    required this.volume,
  });

  final bool playing;
  final bool buffering;
  final Duration position;
  final Duration duration;
  final double volume;
}

class _TvMediaKitPlayerControlsState extends State<TvMediaKitPlayerControls> {
  static const _hideAfterMobile = Duration(seconds: 3);
  static const _hideAfterTv = Duration(seconds: 4);
  static const _skipMs = 15_000;
  static const _loadingColor = Color(0xFF6ECFE0);

  Worker? _tvOsdVisibleWorker;
  Worker? _stripOverlayWorker;
  Timer? _hideTimer;

  bool _visible = true;
  _MediaKitOsdSnapshot? _mkSnap;

  Player? _mkListenerTarget;
  final List<StreamSubscription<dynamic>> _mkSubs = [];

  final FocusNode _mainFocusNode = FocusNode();
  final FocusNode _firstOsdButtonFocus = FocusNode(debugLabel: 'mkOsdFirst');

  double? _dragStartValue;
  bool _isDraggingLeft = false;
  final RxDouble _overlayValue = 0.0.obs;
  final Rxn<IconData> _overlayIcon = Rxn<IconData>();
  final RxBool _showOverlay = false.obs;
  Timer? _overlayTimer;

  FavoritesService get _fav => Get.find<FavoritesService>();

  PlayerController get _pc => Get.find<PlayerController>();

  Channel get _channel => _pc.channel.value;

  bool get _useVodFavorite =>
      _channel.streamUrl.toLowerCase().contains('/movie/') ||
      _channel.streamUrl.toLowerCase().contains('/series/');

  Player? get _player => _pc.mediaKitPlayer;

  @override
  void initState() {
    super.initState();
    final settings = Get.find<AppSettingsService>();
    if (settings.layoutMode.value == AppLayoutMode.tv) {
      _visible = _pc.tvOsdVisible.value;
      _tvOsdVisibleWorker = ever(_pc.tvOsdVisible, (bool visible) {
        if (!mounted) return;
        if (Get.find<AppSettingsService>().layoutMode.value !=
            AppLayoutMode.tv) {
          return;
        }
        if (_visible == visible) return;
        setState(() => _visible = visible);
        if (visible) {
          _restartHideTimer();
          widget.onPlayerVisibilityChanged(true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _firstOsdButtonFocus.requestFocus();
          });
        } else {
          _hideTimer?.cancel();
          widget.onPlayerVisibilityChanged(false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_pc.liveChannelStripOverlayOpen.value) return;
            _mainFocusNode.requestFocus();
          });
        }
      });
      _stripOverlayWorker = ever(_pc.liveChannelStripOverlayOpen, (bool open) {
        if (!mounted) return;
        if (Get.find<AppSettingsService>().layoutMode.value !=
            AppLayoutMode.tv) {
          return;
        }
        if (open) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _mainFocusNode.requestFocus();
        });
      });
    }
    _attachMediaKitListener();
    if (Get.find<AppSettingsService>().layoutMode.value != AppLayoutMode.tv) {
      _restartHideTimer();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPlayerVisibilityChanged(_visible);
      _requestTvPlayerFocus();
      if (Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv) {
        _pc.setVolume(1.0);
        Future<void>.delayed(const Duration(milliseconds: 320), () {
          if (mounted) _requestTvPlayerFocus();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant TvMediaKitPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attachMediaKitListener();
    if (Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestTvPlayerFocus();
      });
    }
  }

  void _cancelMkSubs() {
    for (final s in _mkSubs) {
      unawaited(s.cancel());
    }
    _mkSubs.clear();
  }

  void _attachMediaKitListener() {
    final p = _player;
    if (identical(_mkListenerTarget, p)) return;
    _cancelMkSubs();
    _mkListenerTarget = p;
    if (p == null) {
      if (mounted) setState(() => _mkSnap = null);
      return;
    }
    void tick([dynamic _]) => _onMkUpdate();
    _mkSubs.add(p.stream.playing.listen(tick));
    _mkSubs.add(p.stream.buffering.listen(tick));
    _mkSubs.add(p.stream.position.listen(tick));
    _mkSubs.add(p.stream.duration.listen(tick));
    _mkSubs.add(p.stream.volume.listen(tick));
    _onMkUpdate();
  }

  void _onMkUpdate() {
    if (!mounted) return;
    final p = _player;
    if (p == null) {
      setState(() => _mkSnap = null);
      return;
    }
    final s = p.state;
    final next = _MediaKitOsdSnapshot(
      playing: s.playing,
      buffering: s.buffering,
      position: s.position,
      duration: s.duration,
      volume: s.volume,
    );
    final old = _mkSnap;
    if (old != null && _mkFieldsUnchanged(old, next)) return;
    setState(() => _mkSnap = next);
  }

  bool _mkFieldsUnchanged(_MediaKitOsdSnapshot old, _MediaKitOsdSnapshot v) {
    if (old.playing != v.playing ||
        old.buffering != v.buffering ||
        old.volume != v.volume ||
        old.duration != v.duration) {
      return false;
    }
    final url = _channel.streamUrl.toLowerCase();
    final isVod = url.contains('/movie/') || url.contains('/series/');
    if (isVod && v.duration.inMilliseconds > 0) {
      final d = (v.position.inMilliseconds - old.position.inMilliseconds).abs();
      return d < 500;
    }
    return true;
  }

  void _requestTvPlayerFocus() {
    if (_visible) {
      _firstOsdButtonFocus.requestFocus();
    } else {
      _mainFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _stripOverlayWorker?.dispose();
    _tvOsdVisibleWorker?.dispose();
    _hideTimer?.cancel();
    _overlayTimer?.cancel();
    _cancelMkSubs();
    _mkListenerTarget = null;
    _mainFocusNode.dispose();
    _firstOsdButtonFocus.dispose();
    super.dispose();
  }

  Duration get _hideAfter {
    final tv =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
    return tv ? _hideAfterTv : _hideAfterMobile;
  }

  void _restartHideTimer() {
    if (Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv) {
      _pc.scheduleTvOsdAutoHide();
      return;
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (!mounted) return;
      setState(() => _visible = false);
      widget.onPlayerVisibilityChanged(false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mainFocusNode.requestFocus();
      });
    });
  }

  void _showControls() {
    setState(() => _visible = true);
    widget.onPlayerVisibilityChanged(true);
    _restartHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _firstOsdButtonFocus.requestFocus();
    });
  }

  void _handleVerticalDragStart(DragStartDetails details) async {
    final width = MediaQuery.of(context).size.width;
    _isDraggingLeft = details.globalPosition.dx < width / 2;
    try {
      if (_isDraggingLeft) {
        _dragStartValue = await ScreenBrightness().application;
      } else {
        _dragStartValue = _pc.currentVolume;
      }
    } catch (_) {
      _dragStartValue = _pc.currentVolume;
      _isDraggingLeft = false;
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_dragStartValue == null) return;
    final height = MediaQuery.of(context).size.height;
    final delta = -details.primaryDelta! / height;
    final newValue = (_dragStartValue! + delta).clamp(0.0, 1.0);
    _dragStartValue = newValue;

    if (_isDraggingLeft) {
      try {
        ScreenBrightness().setApplicationScreenBrightness(newValue);
      } catch (_) {}
      _overlayIcon.value = Icons.brightness_6_rounded;
      _overlayValue.value = newValue;
    } else {
      _pc.setVolume(newValue);
      _overlayIcon.value = _volumeIconFor(newValue);
      _overlayValue.value = newValue;
    }

    _showOverlay.value = true;
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 800), () {
      _showOverlay.value = false;
    });
  }

  void _showVolumeOverlay() {
    final vol = _pc.currentVolume;
    _overlayIcon.value = _volumeIconFor(vol);
    _overlayValue.value = vol;
    _showOverlay.value = true;
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 2500), () {
      _showOverlay.value = false;
    });
  }

  void _adjustVolume(double delta) {
    _restartHideTimer();
    final current = _pc.currentVolume;
    final newValue = (current + delta).clamp(0.0, 1.0);
    _pc.setVolume(newValue);
    _showVolumeOverlay();
  }

  IconData _volumeIconFor(double v) {
    if (v == 0) return Icons.volume_off_rounded;
    if (v < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  void _togglePlay() {
    _restartHideTimer();
    final v = _mkSnap;
    if (v == null) return;
    if (v.playing) {
      _pc.pause();
    } else {
      _pc.play();
    }
  }

  void _skipBack15() {
    _restartHideTimer();
    final v = _mkSnap;
    if (v == null) return;
    final ms = math.max(0, v.position.inMilliseconds - _skipMs);
    _pc.seekTo(Duration(milliseconds: ms));
  }

  void _skipForward15() {
    _restartHideTimer();
    final v = _mkSnap;
    if (v == null) return;
    var target = v.position.inMilliseconds + _skipMs;
    final dur = v.duration;
    if (dur.inMilliseconds > 0) {
      target = math.min(dur.inMilliseconds, target);
    }
    _pc.seekTo(Duration(milliseconds: target));
  }

  void _zap(int delta) {
    _pc.zapRelativeDebounced(delta);
  }

  String _liveEpgSubtitle(bool live) {
    if (!live) return '';
    final epg = Get.find<EpgService>();
    final prog = epg.getCurrentProgramme(_channel.epgChannelId);
    String fmt(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (prog != null) {
      return '${fmt(prog.start)}–${fmt(prog.end)} · ${prog.title}';
    }
    if (_channel.epgChannelId != null && epg.isLoading.value) {
      return 'player.epgLoading'.tr;
    }
    final now = DateTime.now();
    return '${fmt(now)} – ${fmt(now.add(const Duration(minutes: 60)))}';
  }

  void _toggleFavorite() {
    _restartHideTimer();
    if (_pc.isMovie) {
      _fav.toggleVod(_channel.id);
    } else if (_pc.isSeries) {
      final s = _pc.playingSeries;
      if (s != null) {
        _fav.toggleSeries(s.id);
      } else {
        _fav.toggleSeries(_channel.id);
      }
    } else {
      _fav.toggleChannel(_channel.id);
    }
    setState(() {});
  }

  void _cycleFit() {
    _restartHideTimer();
    const fits = [BoxFit.fill, BoxFit.contain, BoxFit.cover];
    final cur = _pc.videoFit.value;
    final ni = (fits.indexOf(cur) + 1) % fits.length;
    _pc.setVideoFit(fits[ni]);
  }

  IconData _fitIcon(BoxFit fit) {
    return switch (fit) {
      BoxFit.contain => Icons.fit_screen_rounded,
      BoxFit.cover => Icons.crop_16_9_rounded,
      BoxFit.fill => Icons.open_in_full_rounded,
      _ => Icons.fit_screen_rounded,
    };
  }

  String _fitLabel(BoxFit fit) {
    return switch (fit) {
      BoxFit.contain => 'player.fit.contain'.tr,
      BoxFit.cover => 'player.fit.cover'.tr,
      BoxFit.fill => 'player.fit.fill'.tr,
      _ => 'player.fit.label'.tr,
    };
  }

  Widget _glassBar({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 12,
    ),
    double radius = 20,
  }) {
    final settings = Get.find<AppSettingsService>();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Obx(() {
        final reduce = settings.reduceBlur.value;
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final sigma = tv ? 0.0 : (reduce ? 10.0 : 20.0);
        final decorated = Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        );
        if (sigma <= 0) return decorated;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: decorated,
        );
      }),
    );
  }

  Widget _glassCenterOverlayCard({
    required double width,
    required Widget child,
  }) {
    const radius = 18.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Obx(() {
        final settings = Get.find<AppSettingsService>();
        final reduce = settings.reduceBlur.value;
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final sigma = tv ? 0.0 : (reduce ? 10.0 : 20.0);
        final decorated = Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.2),
                Colors.white.withValues(alpha: 0.07),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        );
        if (sigma <= 0) return decorated;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: decorated,
        );
      }),
    );
  }

  Widget _osdButton(
    BuildContext context, {
    required String tooltip,
    IconData? icon,
    String? letter,
    required VoidCallback onPressed,
    bool primary = false,
    double size = 44,
    Color? iconColor,
    FocusNode? focusNode,
    KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent,
    bool showVolumeGlassOnFocus = false,
  }) {
    assert(icon != null || (letter != null && letter.isNotEmpty));
    final bg = primary
        ? const Color(0xFF4EC4D4).withValues(alpha: 0.45)
        : Colors.white.withValues(alpha: 0.12);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return StatefulBuilder(
      builder: (ctx, setSt) {
        return Focus(
          focusNode: focusNode,
          descendantsAreFocusable: false,
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              _restartHideTimer();
              if (showVolumeGlassOnFocus) {
                _showVolumeOverlay();
              }
            }
            setSt(() {});
          },
          onKeyEvent: (node, event) {
            if (onKeyEvent != null) {
              final res = onKeyEvent(node, event);
              if (res != KeyEventResult.ignored) return res;
            }

            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            final key = event.logicalKey;
            final url = _pc.channel.value.streamUrl.toLowerCase();
            final vod = url.contains('/movie/') || url.contains('/series/');
            final liveCh = !vod;

            if (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.space ||
                key == LogicalKeyboardKey.gameButtonSelect) {
              if (event is KeyRepeatEvent) {
                _restartHideTimer();
                if (liveCh) {
                  _zap(1);
                } else {
                  _skipForward15();
                }
                return KeyEventResult.handled;
              }
              onPressed();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowLeft) {
              if (event is KeyRepeatEvent) {
                _restartHideTimer();
                if (liveCh) {
                  _zap(-1);
                } else {
                  _skipBack15();
                }
                return KeyEventResult.handled;
              }
              node.previousFocus();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowRight) {
              if (event is KeyRepeatEvent) {
                _restartHideTimer();
                if (liveCh) {
                  _zap(1);
                } else {
                  _skipForward15();
                }
                return KeyEventResult.handled;
              }
              node.nextFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Builder(builder: (innerCtx) {
            final focused = Focus.of(innerCtx).hasFocus;
            return Tooltip(
              message: tooltip,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: focused ? primaryColor.withValues(alpha: 0.6) : bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: focused ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    canRequestFocus: false,
                    borderRadius: BorderRadius.circular(12),
                    onTap: onPressed,
                    child: letter != null
                        ? Center(
                            child: Text(
                              letter,
                              style: TextStyle(
                                color: iconColor ?? Colors.white,
                                fontSize: primary
                                    ? (size * 0.48).clamp(16.0, 22.0)
                                    : (size * 0.44).clamp(15.0, 20.0),
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          )
                        : Icon(
                            icon!,
                            color: iconColor ?? Colors.white,
                            size: primary
                                ? (size * 0.59).roundToDouble()
                                : (size * 0.5).roundToDouble(),
                          ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  void _switchToBetterPlayer() {
    _restartHideTimer();
    unawaited(_pc.switchToBetterPlayer());
  }

  Future<void> _showQualityDialog() async {
    _restartHideTimer();
    final tracks = _pc.mediaKitVideoTrackLabels();
    if (!mounted) return;
    if (tracks.length <= 1) {
      _osdInfoDialog(
        'player.quality.title'.tr,
        'player.quality.noneLong'.tr,
      );
      return;
    }
    final active = _player?.state.track.video.id;
    await Get.dialog<void>(
      _MkTrackPickDialog(
        title: 'player.sheet.qualityTitle'.tr,
        entries: tracks.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
        selectedId: active,
        onPick: (id) {
          unawaited(_pc.setMediaKitVideoTrackById(id));
          Get.back<void>();
        },
      ),
    );
  }

  Future<void> _showAudioDialog() async {
    _restartHideTimer();
    final tracks = _pc.mediaKitAudioTrackLabels();
    if (!mounted) return;
    if (tracks.isEmpty) {
      _osdInfoDialog(
        'player.audio.title'.tr,
        'player.audio.noneLong'.tr,
      );
      return;
    }
    final active = _player?.state.track.audio.id;
    await Get.dialog<void>(
      _MkTrackPickDialog(
        title: 'player.sheet.audioTitle'.tr,
        entries: tracks.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
        selectedId: active,
        onPick: (id) {
          unawaited(_pc.setMediaKitAudioTrackById(id));
          Get.back<void>();
        },
      ),
    );
  }

  void _osdInfoDialog(String title, String body) {
    Get.dialog<void>(
      GlassAlertDialog(
        tvOsdStyle: true,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text('common.ok'.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    if (isPortrait) return const SizedBox.shrink();

    final playing = _mkSnap?.playing ?? false;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final leftInset = MediaQuery.paddingOf(context).left;
    final rightInset = MediaQuery.paddingOf(context).right;

    return Obx(() {
      final ch = _pc.channel.value;
      _pc.mediaKitAttachEpoch.value;
      final streamUrl = ch.streamUrl.toLowerCase();
      final isVod =
          streamUrl.contains('/movie/') || streamUrl.contains('/series/');
      final live = !isVod;
      final fit = _pc.videoFit.value;
      final _ = _pc.osdQualityStamp.value;
      final qualityLabel = _pc.osdStreamQualityLabel;
      final epgLine = _liveEpgSubtitle(live);
      final layoutTv =
          Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showControls,
        onVerticalDragStart: layoutTv ? null : _handleVerticalDragStart,
        onVerticalDragUpdate: layoutTv ? null : _handleVerticalDragUpdate,
        child: Focus(
          focusNode: _mainFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }

            final key = event.logicalKey;

            if (key == LogicalKeyboardKey.audioVolumeUp) {
              _adjustVolume(0.05);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.audioVolumeDown) {
              _adjustVolume(-0.05);
              return KeyEventResult.handled;
            }

            if (key == LogicalKeyboardKey.arrowUp) {
              _zap(-1);
              if (!_visible) _showControls();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowDown) {
              _zap(1);
              if (!_visible) _showControls();
              return KeyEventResult.handled;
            }

            if (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.space ||
                key == LogicalKeyboardKey.gameButtonSelect) {
              if (!_visible) {
                _showControls();
                return KeyEventResult.handled;
              }
            }
            if (key == LogicalKeyboardKey.backspace ||
                key == LogicalKeyboardKey.escape) {
              if (_visible) {
                setState(() {
                  _visible = false;
                  _mainFocusNode.requestFocus();
                });
                widget.onPlayerVisibilityChanged(false);
                return KeyEventResult.handled;
              }
            }

            if (!_visible && isVod) {
              if (key == LogicalKeyboardKey.arrowLeft) {
                _skipBack15();
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.arrowRight) {
                _skipForward15();
                return KeyEventResult.handled;
              }
            }

            return KeyEventResult.ignored;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_mkSnap?.buffering == true)
                Center(
                  child: _glassBar(
                    padding: const EdgeInsets.all(16),
                    radius: 999,
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _loadingColor,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 12 + leftInset,
                right: 12 + rightInset,
                bottom: 12 + bottomInset,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  offset: _visible ? Offset.zero : const Offset(0, 1.2),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _visible ? 1 : 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!live &&
                            _mkSnap != null &&
                            _mkSnap!.duration.inMilliseconds > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _glassBar(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                              child: _MkProgressBar(
                                position: _mkSnap!.position,
                                duration: _mkSnap!.duration,
                                onSeek: (d) {
                                  _restartHideTimer();
                                  _pc.seekTo(d);
                                },
                              ),
                            ),
                          ),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _glassBar(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _ChannelLogoBadge(
                                        logoUrl: ch.logoUrl,
                                        size: 42,
                                      ),
                                      const SizedBox(width: 8),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 168,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    ch.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      height: 1.1,
                                                    ),
                                                  ),
                                                ),
                                                if (qualityLabel != null &&
                                                    qualityLabel
                                                        .isNotEmpty) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 5,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.14),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      border: Border.all(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.28),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      qualityLabel,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: 0.3,
                                                        height: 1,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              epgLine,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.75),
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w500,
                                                height: 1.1,
                                              ),
                                            ),
                                            if (live) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE74C3C)
                                                      .withValues(alpha: 0.85),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                                child: Text(
                                                  'player.liveBadge'.tr,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Spacer(),
                              FocusScope(
                                child: FocusTraversalGroup(
                                  policy: OrderedTraversalPolicy(),
                                  child: _glassBar(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _osdButton(
                                            context,
                                            tooltip: live
                                                ? 'player.tooltip.prevCh'.tr
                                                : 'player.tooltip.rewind'.tr,
                                            icon: Icons.fast_rewind_rounded,
                                            onPressed: live
                                                ? () => _zap(-1)
                                                : _skipBack15,
                                            focusNode: _firstOsdButtonFocus,
                                          ),
                                          const SizedBox(width: 6),
                                          _osdButton(
                                            context,
                                            tooltip: playing
                                                ? 'player.tooltip.pause'.tr
                                                : 'player.tooltip.play'.tr,
                                            icon: playing
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            onPressed: _togglePlay,
                                            primary: true,
                                          ),
                                          const SizedBox(width: 6),
                                          _osdButton(
                                            context,
                                            tooltip: live
                                                ? 'player.tooltip.nextCh'.tr
                                                : 'player.tooltip.forward'.tr,
                                            icon: Icons.fast_forward_rounded,
                                            onPressed: live
                                                ? () => _zap(1)
                                                : _skipForward15,
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 1,
                                            height: 32,
                                            color: Colors.white
                                                .withValues(alpha: 0.25),
                                          ),
                                          const SizedBox(width: 8),
                                          Obx(
                                            () {
                                              final on = _pc.isMovie
                                                  ? _fav.hasVod(ch.id)
                                                  : _pc.isSeries
                                                      ? (_pc.playingSeries !=
                                                              null
                                                          ? _fav.hasSeries(_pc
                                                              .playingSeries!
                                                              .id)
                                                          : _fav
                                                              .hasSeries(ch.id))
                                                      : _fav.hasChannel(ch.id);
                                              return _osdButton(
                                                context,
                                                tooltip: on
                                                    ? 'player.tooltip.favOn'.tr
                                                    : 'player.tooltip.favOff'
                                                        .tr,
                                                icon: on
                                                    ? Icons.favorite_rounded
                                                    : Icons
                                                        .favorite_border_rounded,
                                                onPressed: _toggleFavorite,
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 6),
                                          _osdButton(
                                            context,
                                            tooltip: 'player.tooltip.fit'
                                                .trParams(
                                                    {'fit': _fitLabel(fit)}),
                                            icon: _fitIcon(fit),
                                            onPressed: _cycleFit,
                                          ),
                                          const SizedBox(width: 6),
                                          _osdButton(
                                            context,
                                            tooltip:
                                                'player.tooltip.quality'.tr,
                                            icon: Icons.high_quality_rounded,
                                            onPressed: () {
                                              unawaited(_showQualityDialog());
                                            },
                                          ),
                                          const SizedBox(width: 6),
                                          _osdButton(
                                            context,
                                            tooltip: 'player.tooltip.audio'.tr,
                                            icon: Icons.audiotrack_rounded,
                                            onPressed: () {
                                              unawaited(_showAudioDialog());
                                            },
                                          ),
                                          const SizedBox(width: 6),
                                          _osdButton(
                                            context,
                                            tooltip:
                                                'player.tooltip.toBetter'.tr,
                                            letter: 'B',
                                            onPressed: _switchToBetterPlayer,
                                          ),
                                          const SizedBox(width: 6),
                                          Builder(builder: (context) {
                                            final vol =
                                                (_mkSnap?.volume ?? 50) / 100.0;
                                            final icon = vol == 0
                                                ? Icons.volume_off_rounded
                                                : (vol < 0.5
                                                    ? Icons.volume_down_rounded
                                                    : Icons.volume_up_rounded);
                                            return _osdButton(
                                              context,
                                              tooltip:
                                                  'player.tooltip.volume'.tr,
                                              icon: icon,
                                              showVolumeGlassOnFocus: true,
                                              onPressed: () {
                                                _restartHideTimer();
                                                _showVolumeOverlay();
                                              },
                                              onKeyEvent: (node, event) {
                                                if (event is! KeyDownEvent &&
                                                    event is! KeyRepeatEvent) {
                                                  return KeyEventResult.ignored;
                                                }
                                                final key = event.logicalKey;
                                                if (key ==
                                                    LogicalKeyboardKey
                                                        .arrowUp) {
                                                  _adjustVolume(0.05);
                                                  return KeyEventResult.handled;
                                                }
                                                if (key ==
                                                    LogicalKeyboardKey
                                                        .arrowDown) {
                                                  _adjustVolume(-0.05);
                                                  return KeyEventResult.handled;
                                                }
                                                return KeyEventResult.ignored;
                                              },
                                            );
                                          }),
                                          const SizedBox(width: 6),
                                          Obx(
                                            () {
                                              final recording =
                                                  _pc.isRecording.value;
                                              final duration =
                                                  _pc.recordDuration.value;
                                              final minutes =
                                                  (duration / 60).floor();
                                              final seconds = duration % 60;
                                              final timeStr =
                                                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

                                              return Stack(
                                                alignment: Alignment.topRight,
                                                children: [
                                                  _osdButton(
                                                    context,
                                                    tooltip: recording
                                                        ? 'player.tooltip.recordStop'
                                                            .tr
                                                        : 'player.tooltip.record'
                                                            .tr,
                                                    icon: recording
                                                        ? Icons
                                                            .stop_circle_rounded
                                                        : Icons
                                                            .fiber_manual_record_rounded,
                                                    onPressed: () {
                                                      _restartHideTimer();
                                                      _pc.toggleRecording();
                                                    },
                                                    iconColor: recording
                                                        ? Colors.red
                                                        : null,
                                                  ),
                                                  if (recording)
                                                    Positioned(
                                                      top: 2,
                                                      right: 2,
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 4,
                                                                vertical: 1),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.red,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Text(
                                                          timeStr,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 8,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
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
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Obx(() {
                final visible = _showOverlay.value;
                final icon = _overlayIcon.value;
                final isBrightness = icon == Icons.brightness_6_rounded;
                final v = _overlayValue.value.clamp(0.0, 1.0);
                return IgnorePointer(
                  ignoring: !visible,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: visible ? 1.0 : 0.0,
                    child: Center(
                      child: _glassCenterOverlayCard(
                        width: isBrightness ? 200 : 260,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: Colors.white, size: 40),
                            const SizedBox(height: 14),
                            if (isBrightness)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: v,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  color: Colors.white,
                                  minHeight: 6,
                                ),
                              )
                            else
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 5,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 9,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                        overlayRadius: 18,
                                      ),
                                      activeTrackColor: Colors.white,
                                      inactiveTrackColor:
                                          Colors.white.withValues(alpha: 0.22),
                                      thumbColor: const Color(0xFF4EC4D4),
                                      overlayColor: const Color(0xFF4EC4D4)
                                          .withValues(alpha: 0.22),
                                    ),
                                    child: Slider(
                                      value: v,
                                      onChanged: (nv) {
                                        _restartHideTimer();
                                        _pc.setVolume(nv);
                                        _overlayValue.value = nv;
                                        _overlayIcon.value = _volumeIconFor(nv);
                                        _overlayTimer?.cancel();
                                        _overlayTimer = Timer(
                                          const Duration(milliseconds: 2500),
                                          () {
                                            _showOverlay.value = false;
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  Text(
                                    '${(v * 100).round()}%',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    });
  }
}

class _MkTrackPickDialog extends StatelessWidget {
  const _MkTrackPickDialog({
    required this.title,
    required this.entries,
    required this.selectedId,
    required this.onPick,
  });

  final String title;
  final List<MapEntry<String, String>> entries;
  final String? selectedId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 320,
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: GlassPopupPanel(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 1),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final cur = selectedId != null && e.key == selectedId;
                    return ListTile(
                      textColor: cur ? Colors.white : Colors.white70,
                      title: Text(e.value.isNotEmpty ? e.value : '${e.key}'),
                      trailing: cur
                          ? Icon(Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () => onPick(e.key),
                    );
                  },
                ),
                ),
                TextButton(
                  onPressed: () => Get.back<void>(),
                  child: Text(
                    'common.close'.tr,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MkProgressBar extends StatelessWidget {
  const _MkProgressBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  static String _fmt(Duration d) {
    if (d.isNegative) return '0:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final dur = duration;
    final total = dur.inMilliseconds > 0 ? dur.inMilliseconds : 1;
    final pos = position.inMilliseconds.clamp(0, total);
    final progress = total > 0 ? pos / total : 0.0;
    const style = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            _fmt(position),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
              thumbColor: const Color(0xFF4EC4D4),
              overlayColor: const Color(0xFF4EC4D4).withValues(alpha: 0.18),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (nv) {
                final ms = (nv * total).round();
                onSeek(Duration(milliseconds: ms));
              },
            ),
          ),
        ),
        SizedBox(
          width: 68,
          child: Text(
            _fmt(dur),
            style: style,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}

class _ChannelLogoBadge extends StatelessWidget {
  const _ChannelLogoBadge({this.logoUrl, this.size = 48.0});

  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: Colors.white.withValues(alpha: 0.08),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _LogoFallback(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                  );
                },
              )
            : const _LogoFallback(),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.live_tv_rounded,
      color: Colors.white70,
      size: 30,
    );
  }
}
