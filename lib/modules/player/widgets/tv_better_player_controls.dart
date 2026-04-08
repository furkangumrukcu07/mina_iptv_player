import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import '../../../core/player/exo_native_track_option.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../domain/entities/channel.dart';
import '../player_controller.dart';
import '../../../ui/glass_overlays.dart';
import 'player_glass_level_overlay.dart';

import 'package:screen_brightness/screen_brightness.dart';

/// Android TV / dokunmatik: cam (glass) OSD — sol logo, sağ kontroller.
class TvBetterPlayerControls extends StatefulWidget {
  const TvBetterPlayerControls({
    super.key,
    required this.controller,
    required this.onPlayerVisibilityChanged,
  });

  final BetterPlayerController controller;
  final void Function(bool visible) onPlayerVisibilityChanged;

  @override
  State<TvBetterPlayerControls> createState() => _TvBetterPlayerControlsState();
}

class _TvBetterPlayerControlsState extends State<TvBetterPlayerControls> {
  static const _hideAfterMobile = Duration(seconds: 3);
  static const _hideAfterTv = Duration(seconds: 4);

  Worker? _tvOsdVisibleWorker;
  Worker? _stripOverlayWorker;
  static const _skipMs = 15_000;

  Timer? _hideTimer;
  bool _visible = true;
  VideoPlayerValue? _value;

  final FocusNode _mainFocusNode = FocusNode();
  final FocusNode _firstOsdButtonFocus = FocusNode(debugLabel: 'osdFirst');

  /// [videoPlayerController] ilk frame’de null olabiliyor; dinleyici sonra bağlanmalı.
  VideoPlayerController? _videoListenerTarget;
  int _videoListenerPostFrameRetries = 0;
  static const _maxVideoListenerPostFrameRetries = 120;

  double? _dragStartValue;
  bool _isDraggingLeft = false;
  final RxDouble _overlayValue = 0.0.obs;
  final Rxn<IconData> _overlayIcon = Rxn<IconData>();
  final RxBool _showOverlay = false.obs;
  Timer? _overlayTimer;

  BetterPlayerControlsConfiguration get _cfg =>
      widget.controller.betterPlayerControlsConfiguration;

  FavoritesService get _fav => Get.find<FavoritesService>();

  Channel get _channel => Get.find<PlayerController>().channel.value;

  @override
  void initState() {
    super.initState();
    final pc = Get.find<PlayerController>();
    if (Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv) {
      _visible = pc.tvOsdVisible.value;
      _tvOsdVisibleWorker = ever(pc.tvOsdVisible, (bool visible) {
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
            if (!mounted) return;
            if (pc.liveChannelStripOverlayOpen.value) return;
            _firstOsdButtonFocus.requestFocus();
          });
        } else {
          _hideTimer?.cancel();
          widget.onPlayerVisibilityChanged(false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (pc.liveChannelStripOverlayOpen.value) return;
            _mainFocusNode.requestFocus();
          });
        }
      });
      _stripOverlayWorker = ever(pc.liveChannelStripOverlayOpen, (bool open) {
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
    _attachVideoListenerOrRetry();
    if (Get.find<AppSettingsService>().layoutMode.value != AppLayoutMode.tv) {
      _restartHideTimer();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPlayerVisibilityChanged(_visible);
      _requestTvPlayerFocus();
      Get.find<PlayerController>().setVolume(1.0);
      if (Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv) {
        Future<void>.delayed(const Duration(milliseconds: 320), () {
          if (mounted) _requestTvPlayerFocus();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant TvBetterPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        !identical(
          oldWidget.controller.videoPlayerController,
          widget.controller.videoPlayerController,
        )) {
      _videoListenerPostFrameRetries = 0;
      _attachVideoListenerOrRetry();
      if (Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _requestTvPlayerFocus();
        });
      }
    }
  }

  void _detachVideoListener() {
    _videoListenerTarget?.removeListener(_onVideoUpdate);
    _videoListenerTarget = null;
  }

  void _attachVideoListenerOrRetry() {
    _detachVideoListener();
    final vc = widget.controller.videoPlayerController;
    if (vc != null) {
      _videoListenerTarget = vc;
      vc.addListener(_onVideoUpdate);
      _value = vc.value;
      _onVideoUpdate();
      _videoListenerPostFrameRetries = 0;
      return;
    }
    if (_videoListenerPostFrameRetries >= _maxVideoListenerPostFrameRetries) {
      return;
    }
    _videoListenerPostFrameRetries++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _attachVideoListenerOrRetry();
    });
  }

  void _requestTvPlayerFocus() {
    final pc = Get.find<PlayerController>();
    if (pc.liveChannelStripOverlayOpen.value) return;
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
    _detachVideoListener();
    _mainFocusNode.dispose();
    _firstOsdButtonFocus.dispose();
    super.dispose();
  }

  void _handleVerticalDragStart(DragStartDetails details) async {
    final width = MediaQuery.of(context).size.width;
    _isDraggingLeft = details.globalPosition.dx < width / 2;
    if (_isDraggingLeft) {
      try {
        _dragStartValue = await ScreenBrightness().application;
      } catch (_) {
        _dragStartValue = null;
      }
    } else {
      _dragStartValue = Get.find<PlayerController>().currentVolume;
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_dragStartValue == null) return;

    final height = MediaQuery.of(context).size.height;
    final dy = details.primaryDelta ?? details.delta.dy;
    final delta = -dy / height;
    final newValue = (_dragStartValue! + delta).clamp(0.0, 1.0);
    _dragStartValue = newValue;

    final pc = Get.find<PlayerController>();
    if (_isDraggingLeft) {
      try {
        ScreenBrightness().setApplicationScreenBrightness(newValue);
      } catch (_) {}
      _overlayIcon.value = Icons.brightness_6_rounded;
    } else {
      pc.setVolume(newValue);
      _overlayIcon.value = playerVolumeIconFor(newValue);
    }
    _overlayValue.value = newValue;

    _showOverlay.value = true;
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 800), () {
      _showOverlay.value = false;
    });
  }

  void _nudgeVolumeFromKey(double delta) {
    _restartHideTimer();
    final pc = Get.find<PlayerController>();
    final v = (pc.currentVolume + delta).clamp(0.0, 1.0);
    pc.setVolume(v);
    _overlayIcon.value = playerVolumeIconFor(v);
    _overlayValue.value = v;
    _showOverlay.value = true;
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 1200), () {
      _showOverlay.value = false;
    });
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    final v = widget.controller.videoPlayerController?.value;
    if (v == null) {
      setState(() => _value = null);
      return;
    }
    final old = _value;
    if (old != null && _tvOsdVideoFieldsUnchanged(old, v)) {
      return;
    }
    setState(() => _value = v);
  }

  /// Canlı: pozisyon/buffer sürekli değişir; OSD çoğunlukla oynatma/tampona bağlı.
  /// VOD: ilerleme çubuğu için pozisyonu ~0,5 sn adımla güncelle.
  bool _tvOsdVideoFieldsUnchanged(VideoPlayerValue old, VideoPlayerValue v) {
    if (old.isPlaying != v.isPlaying ||
        old.isBuffering != v.isBuffering ||
        old.hasError != v.hasError ||
        old.volume != v.volume ||
        old.size != v.size ||
        old.duration != v.duration) {
      return false;
    }
    final streamUrl = _channel.streamUrl.toLowerCase();
    final isVod =
        streamUrl.contains('/movie/') || streamUrl.contains('/series/');
    if (isVod &&
        _cfg.enableProgressBar &&
        (v.duration?.inMilliseconds ?? 0) > 0) {
      final d = (v.position.inMilliseconds - old.position.inMilliseconds).abs();
      return d < 500;
    }
    return true;
  }

  Duration get _hideAfter {
    final tv =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
    return tv ? _hideAfterTv : _hideAfterMobile;
  }

  void _restartHideTimer() {
    if (Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv) {
      Get.find<PlayerController>().scheduleTvOsdAutoHide();
      return;
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (!mounted) return;
      setState(() {
        _visible = false;
      });
      widget.onPlayerVisibilityChanged(false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (Get.find<PlayerController>().liveChannelStripOverlayOpen.value) {
          return;
        }
        _mainFocusNode.requestFocus();
      });
    });
  }

  void _showControls() {
    setState(() {
      _visible = true;
    });
    widget.onPlayerVisibilityChanged(true);
    _restartHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Get.find<PlayerController>().liveChannelStripOverlayOpen.value) {
        return;
      }
      _firstOsdButtonFocus.requestFocus();
    });
  }

  void _togglePlay() {
    _restartHideTimer();
    final v = _value;
    if (v == null) return;
    final pc = Get.find<PlayerController>();
    if (v.isPlaying) {
      pc.pause();
    } else {
      pc.play();
    }
  }

  void _skipBack15() {
    _restartHideTimer();
    final v = _value;
    if (v == null) return;
    final ms = math.max(0, v.position.inMilliseconds - _skipMs);
    widget.controller.seekTo(Duration(milliseconds: ms));
  }

  void _skipForward15() {
    _restartHideTimer();
    final v = _value;
    if (v == null) return;
    var target = v.position.inMilliseconds + _skipMs;
    final dur = v.duration;
    if (dur != null && dur.inMilliseconds > 0) {
      target = math.min(dur.inMilliseconds, target);
    }
    widget.controller.seekTo(Duration(milliseconds: target));
  }

  void _zap(int delta) {
    Get.find<PlayerController>().zapRelativeDebounced(delta);
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
    final pc = Get.find<PlayerController>();
    final ch = pc.channel.value;
    if (pc.isMovie) {
      _fav.toggleVod(ch.id);
    } else if (pc.isSeries) {
      final s = pc.playingSeries;
      if (s != null) {
        _fav.toggleSeries(s.id);
      } else {
        _fav.toggleSeries(ch.id);
      }
    } else {
      _fav.toggleChannel(ch.id);
    }
    setState(() {});
  }

  void _cycleFit() {
    _restartHideTimer();
    const fits = [BoxFit.fill, BoxFit.contain, BoxFit.cover];
    final ctrl = Get.find<PlayerController>();
    final cur = ctrl.videoFit.value;
    final ni = (fits.indexOf(cur) + 1) % fits.length;
    ctrl.setVideoFit(fits[ni]);
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
        final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
        final reduce = settings.reduceBlur.value;
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final sigma = tv ? 0.0 : (reduce ? 10.0 : 20.0);
        final decorated = Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: ga.playerBarBorder),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ga.playerBarGradientColors,
            ),
            boxShadow: [
              BoxShadow(
                color: ga.popupShadowColor,
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

  Widget _osdButton({
    required String tooltip,
    IconData? icon,
    String? letter,
    required VoidCallback onPressed,
    bool primary = false,
    double size = 44,
    Color? iconColor,
    FocusNode? focusNode,
    KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent,

  }) {
    assert(icon != null || (letter != null && letter.isNotEmpty));
    final primaryColor = Theme.of(Get.context!).colorScheme.primary;

    return StatefulBuilder(
      builder: (context, setState) {
        return Focus(
          focusNode: focusNode,
          // InkWell vb. alt widget'lar ayrı odak hedefi olmasın; sağ/sol tek basışta bir kontrole geçsin.
          descendantsAreFocusable: false,
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              _restartHideTimer();
            }
            setState(() {});
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
            final url = Get.find<PlayerController>()
                .channel
                .value
                .streamUrl
                .toLowerCase();
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
            // Tuşu basılı tutunca tekrar: OSD'de sağ/sol ile buton gezme yerine kanal / sarma.
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
          child: Builder(builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return Obx(() {
              final ga = GlassAppearance.fromLabel(
                Get.find<AppSettingsService>().themeLabel.value,
              );
              final unfocusedBg = primary
                  ? const Color(0xFF4EC4D4).withValues(alpha: 0.45)
                  : ga.playerBarDimColor;
              return Tooltip(
                message: tooltip,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: focused
                        ? primaryColor.withValues(alpha: 0.6)
                        : unfocusedBg,
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
            });
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    // Dikey: alttaki _PortraitOsdPanel. Yatay: cam OSD (mobil ve TV aynı TvBetterPlayerControls).
    if (isPortrait) return const SizedBox.shrink();

    final playing = _value?.isPlaying ?? false;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final leftInset = MediaQuery.paddingOf(context).left;
    final rightInset = MediaQuery.paddingOf(context).right;

    return Obx(() {
      final ch = controller.channel.value;
      final streamUrl = ch.streamUrl.toLowerCase();
      final isVod =
          streamUrl.contains('/movie/') || streamUrl.contains('/series/');
      final live = !isVod;
      final fit = controller.videoFit.value;
      final _ = controller.osdQualityStamp.value;
      final qualityLabel = controller.osdStreamQualityLabel;
      final epgLine = _liveEpgSubtitle(live);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showControls,
        onVerticalDragStart: _handleVerticalDragStart,
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        child: Focus(
          focusNode: _mainFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }

            final key = event.logicalKey;

            if (key == LogicalKeyboardKey.audioVolumeUp) {
              _nudgeVolumeFromKey(0.05);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.audioVolumeDown) {
              _nudgeVolumeFromKey(-0.05);
              return KeyEventResult.handled;
            }

            // Yukarı/aşağı: canlıda kanal; film/dizide sıradaki içerik (OSD açık olsa da).
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

            // Film / dizi: OSD kapalıyken sol/sağ ile sarma
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
              if (_value?.isBuffering == true)
                Center(
                  child: _glassBar(
                    padding: EdgeInsets.all(isPortrait ? 12 : 16),
                    radius: 999,
                    child: SizedBox(
                      width: isPortrait ? 24 : 32,
                      height: isPortrait ? 24 : 32,
                      child: CircularProgressIndicator(
                        strokeWidth: isPortrait ? 2 : 2.5,
                        color: _cfg.loadingColor,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: (isPortrait ? 8 : 12) + leftInset,
                right: (isPortrait ? 8 : 12) + rightInset,
                bottom: (isPortrait ? 8 : 12) + bottomInset,
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
                            _cfg.enableProgressBar &&
                            _value?.duration != null &&
                            (_value!.duration!.inMilliseconds > 0))
                          Padding(
                            padding:
                                EdgeInsets.only(bottom: isPortrait ? 6 : 8),
                            child: _glassBar(
                              padding: EdgeInsets.fromLTRB(
                                isPortrait ? 10 : 14,
                                isPortrait ? 6 : 8,
                                isPortrait ? 10 : 14,
                                isPortrait ? 6 : 8,
                              ),
                              child: _TvProgressBar(
                                value: _value!,
                                cfg: _cfg,
                                onSeek: (d) {
                                  _restartHideTimer();
                                  widget.controller.seekTo(d);
                                },
                              ),
                            ),
                          ),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _glassBar(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isPortrait ? 6 : 8,
                                  vertical: isPortrait ? 6 : 8,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _ChannelLogoBadge(
                                        logoUrl: ch.logoUrl,
                                        size: isPortrait ? 32 : 42,
                                      ),
                                      SizedBox(width: isPortrait ? 6 : 8),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: isPortrait ? 118 : 168,
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
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize:
                                                          isPortrait ? 11 : 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      height: 1.1,
                                                    ),
                                                  ),
                                                ),
                                                if (qualityLabel != null &&
                                                    qualityLabel
                                                        .isNotEmpty) ...[
                                                  SizedBox(
                                                      width:
                                                          isPortrait ? 4 : 6),
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal:
                                                          isPortrait ? 4 : 5,
                                                      vertical:
                                                          isPortrait ? 2 : 2,
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
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize:
                                                            isPortrait ? 8 : 9,
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
                                                fontSize: isPortrait ? 9 : 9.5,
                                                fontWeight: FontWeight.w500,
                                                height: 1.1,
                                              ),
                                            ),
                                            if (live) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      isPortrait ? 5 : 6,
                                                  vertical: isPortrait ? 2 : 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE74C3C)
                                                      .withValues(alpha: 0.85),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          isPortrait ? 4 : 5),
                                                ),
                                                child: Text(
                                                  'player.liveBadge'.tr,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize:
                                                        isPortrait ? 8 : 9,
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
                              SizedBox(width: isPortrait ? 8 : 12),
                              const Spacer(),
                              FocusScope(
                                child: FocusTraversalGroup(
                                  policy: OrderedTraversalPolicy(),
                                  child: _glassBar(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isPortrait ? 6 : 8,
                                      vertical: isPortrait ? 6 : 8,
                                    ),
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _osdButton(
                                            tooltip: live
                                                ? 'player.tooltip.prevCh'.tr
                                                : 'player.tooltip.rewind'.tr,
                                            icon: Icons.fast_rewind_rounded,
                                            onPressed: live
                                                ? () => _zap(-1)
                                                : _skipBack15,
                                            size: isPortrait ? 34 : 44,
                                            focusNode: _firstOsdButtonFocus,
                                          ),
                                          SizedBox(width: isPortrait ? 4 : 6),
                                          _osdButton(
                                            tooltip: playing
                                                ? 'player.tooltip.pause'.tr
                                                : 'player.tooltip.play'.tr,
                                            icon: playing
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            onPressed: _togglePlay,
                                            primary: true,
                                            size: isPortrait ? 34 : 44,
                                          ),
                                          SizedBox(width: isPortrait ? 4 : 6),
                                          _osdButton(
                                            tooltip: live
                                                ? 'player.tooltip.nextCh'.tr
                                                : 'player.tooltip.forward'.tr,
                                            icon: Icons.fast_forward_rounded,
                                            onPressed: live
                                                ? () => _zap(1)
                                                : _skipForward15,
                                            size: isPortrait ? 34 : 44,
                                          ),
                                          SizedBox(width: isPortrait ? 6 : 8),
                                          Container(
                                            width: 1,
                                            height: isPortrait ? 24 : 32,
                                            color: Colors.white
                                                .withValues(alpha: 0.25),
                                          ),
                                          SizedBox(width: isPortrait ? 6 : 8),
                                          Obx(
                                            () {
                                              final pc =
                                                  Get.find<PlayerController>();
                                              final on = pc.isMovie
                                                  ? _fav.hasVod(ch.id)
                                                  : pc.isSeries
                                                      ? (pc.playingSeries !=
                                                              null
                                                          ? _fav.hasSeries(pc
                                                              .playingSeries!
                                                              .id)
                                                          : _fav
                                                              .hasSeries(ch.id))
                                                      : _fav.hasChannel(ch.id);
                                              return _osdButton(
                                                tooltip: on
                                                    ? 'player.tooltip.favOn'.tr
                                                    : 'player.tooltip.favOff'
                                                        .tr,
                                                icon: on
                                                    ? Icons.favorite_rounded
                                                    : Icons
                                                        .favorite_border_rounded,
                                                onPressed: _toggleFavorite,
                                                size: isPortrait ? 34 : 44,
                                              );
                                            },
                                          ),
                                          SizedBox(width: isPortrait ? 4 : 6),
                                          _osdButton(
                                            tooltip: 'player.tooltip.fit'
                                                .trParams(
                                                    {'fit': _fitLabel(fit)}),
                                            icon: _fitIcon(fit),
                                            onPressed: _cycleFit,
                                            size: isPortrait ? 34 : 44,
                                          ),
                                          SizedBox(width: isPortrait ? 4 : 6),
                                          Obx(() {
                                            final pc =
                                                Get.find<PlayerController>();
                                            pc.betterOsdOverride.value;
                                            pc.mediaKitFallbackSession.value;
                                            Get.find<AppSettingsService>()
                                                .useMediaKit
                                                .value;
                                            if (pc.effectiveUseMediaKit) {
                                              return const SizedBox.shrink();
                                            }
                                            return _osdButton(
                                              tooltip:
                                                  'player.tooltip.toMediaKit'
                                                      .tr,
                                              letter: 'M',
                                              onPressed: _switchToBackupPlayer,
                                              size: isPortrait ? 34 : 44,
                                            );
                                          }),
                                          SizedBox(width: isPortrait ? 4 : 6),
                                          _osdButton(
                                            tooltip:
                                                'player.tooltip.quality'.tr,
                                            icon: Icons.high_quality_rounded,
                                            onPressed: _showQualityDialog,
                                            size: isPortrait ? 34 : 44,
                                          ),
                                          if (isVod) ...[
                                            SizedBox(width: isPortrait ? 4 : 6),
                                            _osdButton(
                                              tooltip:
                                                  'player.tooltip.audio'.tr,
                                              icon: Icons.audiotrack_rounded,
                                              onPressed: () => unawaited(
                                                  _showAudioDialog()),
                                              size: isPortrait ? 34 : 44,
                                            ),
                                            SizedBox(width: isPortrait ? 4 : 6),
                                            _osdButton(
                                              tooltip: 'player.tooltip.subtitle'
                                                  .tr,
                                              icon: Icons.closed_caption_rounded,
                                              onPressed: () => unawaited(
                                                  _showSubtitleDialog()),
                                              size: isPortrait ? 34 : 44,
                                            ),
                                          ],
                                          SizedBox(width: isPortrait ? 4 : 6),
                                          Obx(
                                            () {
                                              final recording =
                                                  controller.isRecording.value;
                                              final duration = controller
                                                  .recordDuration.value;
                                              final minutes =
                                                  (duration / 60).floor();
                                              final seconds = duration % 60;
                                              final timeStr =
                                                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

                                              return Stack(
                                                alignment: Alignment.topRight,
                                                children: [
                                                  _osdButton(
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
                                                      controller
                                                          .toggleRecording();
                                                    },
                                                    iconColor: recording
                                                        ? Colors.red
                                                        : null,
                                                    size: isPortrait ? 34 : 44,
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
              Obx(() => AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showOverlay.value ? 1.0 : 0.0,
                    child: PlayerGlassLevelOverlay(
                      visible: _showOverlay.value,
                      icon: _overlayIcon.value,
                      value01: _overlayValue.value,
                    ),
                  )),
            ],
          ),
        ),
      );
    });
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

  void _switchToBackupPlayer() {
    _restartHideTimer();
    unawaited(Get.find<PlayerController>().switchToBackupPlayer());
  }

  void _showQualityDialog() {
    _restartHideTimer();
    final ctrl = Get.find<PlayerController>();

    final tracks = ctrl.availableTracks;
    if (tracks.isEmpty) {
      _osdInfoDialog(
        'player.quality.title'.tr,
        'player.quality.noneLong'.tr,
      );
      return;
    }

    Get.dialog<void>(
      _TvQualityDialog(
        controller: ctrl,
        tracks: tracks,
      ),
    );
  }

  Future<void> _showAudioDialog() async {
    _restartHideTimer();
    final ctrl = Get.find<PlayerController>();

    final asms = ctrl.availableAudioTracks;
    if (asms.isNotEmpty) {
      Get.dialog<void>(
        _TvAudioDialog(
          controller: ctrl,
          tracks: asms,
        ),
      );
      return;
    }
    final exo = await ctrl.loadExoNativeTracks();
    if (!mounted) return;
    if (exo.audio.isEmpty) {
      _osdInfoDialog(
        'player.audio.title'.tr,
        'player.audio.noneLong'.tr,
      );
      return;
    }
    Get.dialog<void>(
      _TvExoNativeAudioDialog(
        controller: ctrl,
        tracks: exo.audio,
      ),
    );
  }

  Future<void> _showSubtitleDialog() async {
    _restartHideTimer();
    final ctrl = Get.find<PlayerController>();
    final exo = await ctrl.loadExoNativeTracks();
    if (!mounted) return;
    final hasExternal = ctrl.availableSubtitleSources.any(
      (s) => s.type != BetterPlayerSubtitlesSourceType.none,
    );
    if (!hasExternal && exo.text.isEmpty) {
      _osdInfoDialog(
        'player.sheet.subtitleTitle'.tr,
        'player.subtitle.noneLong'.tr,
      );
      return;
    }
    Get.dialog<void>(
      _TvUnifiedSubtitleDialog(
        controller: ctrl,
        sources: ctrl.availableSubtitleSources,
        exoTextTracks: exo.text,
      ),
    );
  }
}

class _TvAudioDialog extends StatelessWidget {
  const _TvAudioDialog({
    required this.controller,
    required this.tracks,
  });

  final PlayerController controller;
  final List<BetterPlayerAsmsAudioTrack> tracks;

  @override
  Widget build(BuildContext context) {
    final active = controller.currentAudioTrack;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 320,
          child: GlassPopupPanel(
            padding: const EdgeInsets.all(24),
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.audiotrack_rounded, color: Colors.white70),
                    const SizedBox(width: 12),
                    Text(
                      'player.sheet.audioTitle'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final t in tracks)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TvQualityOption(
                            label: t.label ??
                                'player.track.audio'.trParams({
                                  'n': '${tracks.indexOf(t) + 1}',
                                }),
                            isAuto: false,
                            isCurrent: active?.id == t.id ||
                                (active == null && tracks.indexOf(t) == 0),
                            onTap: () {
                              controller.better?.setAudioTrack(t);
                              Navigator.pop(context);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
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

class _TvExoNativeAudioDialog extends StatelessWidget {
  const _TvExoNativeAudioDialog({
    required this.controller,
    required this.tracks,
  });

  final PlayerController controller;
  final List<ExoNativeTrackOption> tracks;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 320,
          child: GlassPopupPanel(
            padding: const EdgeInsets.all(24),
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.audiotrack_rounded, color: Colors.white70),
                    const SizedBox(width: 12),
                    Text(
                      'player.sheet.audioTitle'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final t in tracks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TvQualityOption(
                              label: t.displayLabel,
                              isAuto: false,
                              isCurrent: t.selected,
                              onTap: () {
                                unawaited(
                                  controller.selectExoNativeAudioTrack(t),
                                );
                                Navigator.pop(context);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
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

class _TvUnifiedSubtitleDialog extends StatelessWidget {
  const _TvUnifiedSubtitleDialog({
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

    final children = <Widget>[
      for (final s in sorted)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _TvQualityOption(
            label: _label(s),
            isAuto: false,
            isCurrent: _sameSubtitle(active, s),
            onTap: () async {
              await controller.setBetterSubtitleSource(s);
              if (s.type == BetterPlayerSubtitlesSourceType.none) {
                await controller.disableExoNativeTextTracks();
              }
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ),
    ];

    if (exoTextTracks.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
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
      for (final opt in exoTextTracks) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TvQualityOption(
              label: opt.displayLabel,
              isAuto: false,
              isCurrent: opt.selected,
              onTap: () {
                unawaited(controller.selectExoNativeTextTrack(opt));
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 320,
          child: GlassPopupPanel(
            padding: const EdgeInsets.all(24),
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.closed_caption_rounded,
                        color: Colors.white70),
                    const SizedBox(width: 12),
                    Text(
                      'player.sheet.subtitleTitle'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(children: children),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
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

class _TvQualityDialog extends StatelessWidget {
  const _TvQualityDialog({
    required this.controller,
    required this.tracks,
  });

  final PlayerController controller;
  final List<BetterPlayerAsmsTrack> tracks;

  @override
  Widget build(BuildContext context) {
    String getTrackLabel(BetterPlayerAsmsTrack track) {
      if (track.width == 0 || track.height == 0) {
        return 'player.quality.auto'.tr;
      }
      if (track.height != null) {
        return '${track.height}p';
      }
      return 'player.quality.unknown'.tr;
    }

    final sorted = List<BetterPlayerAsmsTrack>.from(tracks);
    sorted.sort((a, b) {
      if (a.width == 0 && a.height == 0) return -1;
      if (b.width == 0 && b.height == 0) return 1;
      return (b.height ?? 0).compareTo(a.height ?? 0);
    });

    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 320,
          child: GlassPopupPanel(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'player.sheet.qualityTitle'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: sorted.map((track) {
                      final isAuto = track.width == 0 && track.height == 0;
                      final isCurrent = controller.currentTrack == track;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TvQualityOption(
                          label: getTrackLabel(track),
                          isAuto: isAuto,
                          isCurrent: isCurrent,
                          onTap: () {
                            controller.setQuality(track);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
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

class _TvQualityOption extends StatefulWidget {
  const _TvQualityOption({
    required this.label,
    required this.isAuto,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final bool isAuto;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  State<_TvQualityOption> createState() => _TvQualityOptionState();
}

class _TvQualityOptionState extends State<_TvQualityOption> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _focused
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused
                  ? primary.withValues(alpha: 0.5)
                  : (widget.isCurrent
                      ? primary.withValues(alpha: 0.3)
                      : Colors.transparent),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.isAuto ? Icons.auto_awesome : Icons.high_quality,
                color: widget.isCurrent ? primary : Colors.white60,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isCurrent ? Colors.white : Colors.white70,
                    fontWeight:
                        widget.isCurrent ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.isCurrent)
                Icon(
                  Icons.check_circle_rounded,
                  color: primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
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

class _TvProgressBar extends StatelessWidget {
  const _TvProgressBar({
    required this.value,
    required this.cfg,
    required this.onSeek,
  });

  final VideoPlayerValue value;
  final BetterPlayerControlsConfiguration cfg;
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

  static TextStyle _timeStyle(BuildContext context) {
    return TextStyle(
      color: Colors.white.withValues(alpha: 0.92),
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dur = value.duration!;
    final total = dur.inMilliseconds > 0 ? dur.inMilliseconds : 1;
    final pos = value.position.inMilliseconds.clamp(0, total);
    final progress = total > 0 ? pos / total : 0.0;
    final style = _timeStyle(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            _fmt(value.position),
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
              activeTrackColor: cfg.progressBarPlayedColor,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
              thumbColor: cfg.progressBarHandleColor,
              overlayColor: cfg.progressBarHandleColor.withValues(alpha: 0.18),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: cfg.enableProgressBarDrag
                  ? (nv) {
                      final ms = (nv * total).round();
                      onSeek(Duration(milliseconds: ms));
                    }
                  : null,
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
