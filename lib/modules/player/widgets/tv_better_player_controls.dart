import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/player/better_player_video_track_label.dart';
import '../../../core/player/video_player_engine.dart';
import '../../../core/player/exo_native_track_option.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/app_performance.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../domain/entities/channel.dart';
import '../player_controller.dart';
import '../../../ui/glass_overlays.dart';
import '../../../ui/iptv_channel_logo.dart';
import 'osd_stream_quality_badges.dart';
import 'player_cast_sheet.dart';
import 'player_glass_level_overlay.dart';
import 'vod_seek_bar.dart';

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
  static const _hideAfterMobile = Duration(seconds: 5);
  static const _hideAfterTv = Duration(seconds: 5);

  Worker? _tvOsdVisibleWorker;
  Worker? _stripOverlayWorker;
  Worker? _vodBrowseRailWorker;
  Worker? _tvOsdKeyBumpWorker;
  static const _skipMs = 15_000;

  // Yatay mobil + küçük ekranlarda OSD kapsülü taşmasın diye build sırasında
  // ekran genişliğine göre adaptif olarak hesaplanır.
  double _osdBtnSize = 44.0;
  double _osdBtnGap = 6.0;
  double _osdInfoMaxW = 168.0;

  Timer? _hideTimer;
  final _visible = true.obs;
  late final ValueNotifier<VideoPlayerValue?> _betterPlayerValueNotifier;

  final FocusNode _mainFocusNode = FocusNode();
  final FocusNode _firstOsdButtonFocus = FocusNode(debugLabel: 'osdFirst');

  /// [videoPlayerController] ilk frame’de null olabiliyor; dinleyici sonra bağlanmalı.
  VideoPlayerController? _videoListenerTarget;
  int _videoListenerPostFrameRetries = 0;
  static const _maxVideoListenerPostFrameRetries = 120;

  double? _verticalGestureOriginY;
  double _verticalGestureStartLevel = 1.0;
  bool _isDraggingLeft = false;
  final RxDouble _overlayValue = 0.0.obs;
  final Rxn<IconData> _overlayIcon = Rxn<IconData>();
  final RxBool _showOverlay = false.obs;
  Timer? _overlayTimer;

  Timer? _liveOsdPlayPauseCenterHoldTimer;
  bool _liveOsdPlayPauseCenterHoldPending = false;
  Timer? _vodOsdBrowseRailHoldTimer;
  bool _vodOsdBrowseRailHoldPending = false;
  bool _subDialogOpen = false;

  BetterPlayerControlsConfiguration get _cfg {
    // Use existing configuration but disable loading widget
    return widget.controller.betterPlayerControlsConfiguration;
  }


  Channel get _channel => Get.find<PlayerController>().channel.value;

  @override
  void initState() {
    super.initState();
    _betterPlayerValueNotifier = ValueNotifier<VideoPlayerValue?>(null);
    final pc = Get.find<PlayerController>();
    final settings = Get.find<AppSettingsService>();
    final remoteLayout = settings.layoutMode.value.usesRemoteNavigationStyle;
    if (remoteLayout) {
      _visible.value = pc.tvOsdVisible.value;
      _tvOsdVisibleWorker = ever(pc.tvOsdVisible, (bool visible) {
        if (!mounted) return;
        if (!Get.find<AppSettingsService>()
            .layoutMode
            .value
            .usesRemoteNavigationStyle) {
          return;
        }
        if (_visible.value == visible) return;
        _visible.value = visible;
        if (visible) {
          _restartHideTimer();
          widget.onPlayerVisibilityChanged(true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (pc.liveChannelStripOverlayOpen.value ||
                pc.liveSingleChannelEpgOpen.value ||
                pc.vodBrowseRailOpen.value ||
                _subDialogOpen) {
              return;
            }
            _firstOsdButtonFocus.requestFocus();
          });
        } else {
          _hideTimer?.cancel();
          widget.onPlayerVisibilityChanged(false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (pc.liveChannelStripOverlayOpen.value ||
                pc.liveSingleChannelEpgOpen.value ||
                pc.vodBrowseRailOpen.value) {
              return;
            }
            if (pc.vodResumeDialogOpen.value || _subDialogOpen) return;
            _mainFocusNode.requestFocus();
          });
        }
      });
      _stripOverlayWorker = ever(pc.liveChannelStripOverlayOpen, (bool open) {
        if (!mounted) return;
        if (!Get.find<AppSettingsService>()
            .layoutMode
            .value
            .usesRemoteNavigationStyle) {
          return;
        }
        if (open) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (pc.vodResumeDialogOpen.value || _subDialogOpen) return;
          _mainFocusNode.requestFocus();
        });
      });
      _vodBrowseRailWorker = ever(pc.vodBrowseRailOpen, (bool open) {
        if (!mounted) return;
        if (!Get.find<AppSettingsService>()
            .layoutMode
            .value
            .usesRemoteNavigationStyle) {
          return;
        }
        if (open) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (pc.vodResumeDialogOpen.value || _subDialogOpen) return;
          _mainFocusNode.requestFocus();
        });
      });
      _tvOsdKeyBumpWorker = ever(pc.tvOsdKeyFocusBump, (_) {
        if (!mounted) return;
        if (!Get.find<AppSettingsService>()
            .layoutMode
            .value
            .usesRemoteNavigationStyle) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (Get.find<PlayerController>().vodResumeDialogOpen.value ||
              _subDialogOpen) {
            return;
          }
          _requestTvPlayerFocus();
        });
      });
    }

    _attachVideoListenerOrRetry();
    if (!remoteLayout) {
      _restartHideTimer();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPlayerVisibilityChanged(_visible.value);
      _requestTvPlayerFocus();
      if (remoteLayout) {
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
      if (Get.find<AppSettingsService>()
          .layoutMode
          .value
          .usesRemoteNavigationStyle) {
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
      _betterPlayerValueNotifier.value = vc.value;
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
    if (pc.liveChannelStripOverlayOpen.value ||
        pc.liveSingleChannelEpgOpen.value ||
        pc.vodBrowseRailOpen.value ||
        _subDialogOpen) {
      return;
    }
    if (_visible.value) {
      _firstOsdButtonFocus.requestFocus();
    } else {
      _mainFocusNode.requestFocus();
    }
  }

  /// Üstte modal açıkken ana OSD’nin yön tuşlarını yutmasını engellemek için.
  void _suspendOsdFocusForDialog() {
    _mainFocusNode.unfocus();
    _firstOsdButtonFocus.unfocus();
    _subDialogOpen = true;
  }

  /// Ses/altyazı/kalite sheet’i açıkken otomatik gizlemeyi durdur (OSD ekranda kalsın).
  void _pauseOsdHideForModal() {
    Get.find<PlayerController>().cancelTvOsdAutoHide();
    _hideTimer?.cancel();
  }

  /// Alt diyalog kapandıktan sonra OSD’yi açık tut, odağı şeride ver, sonra yeniden zamanla.
  void _resumeOsdAfterSubDialog() {
    if (!mounted) return;
    final pc = Get.find<PlayerController>();
    final remote = Get.find<AppSettingsService>()
        .layoutMode
        .value
        .usesRemoteNavigationStyle;
    _subDialogOpen = false;
    if (remote) {
      pc.tvOsdVisible.value = true;
    }
    _visible.value = true;
    widget.onPlayerVisibilityChanged(true);
    _restartHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (pc.liveChannelStripOverlayOpen.value ||
          pc.liveSingleChannelEpgOpen.value ||
          pc.vodBrowseRailOpen.value) {
        return;
      }
      _firstOsdButtonFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _betterPlayerValueNotifier.dispose();
    _tvOsdVisibleWorker?.dispose();
    _stripOverlayWorker?.dispose();
    _vodBrowseRailWorker?.dispose();
    _tvOsdKeyBumpWorker?.dispose();
    _hideTimer?.cancel();
    _overlayTimer?.cancel();
    _detachVideoListener();
    _mainFocusNode.dispose();
    _firstOsdButtonFocus.dispose();
    super.dispose();
  }

  void _handleVerticalDragStart(DragStartDetails details) async {
    final width = MediaQuery.sizeOf(context).width;
    _isDraggingLeft = details.globalPosition.dx < width / 2;
    _verticalGestureOriginY = details.globalPosition.dy;

    final pc = Get.find<PlayerController>();
    if (_isDraggingLeft) {
      _verticalGestureStartLevel = pc.inAppPlaybackBrightness.value;
    } else {
      // PlayerController üzerinden logical volume (0..maxBoost) okunur.
      _verticalGestureStartLevel = pc.currentVolume;
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) async {
    final originY = _verticalGestureOriginY;
    if (originY == null) return;

    final height = MediaQuery.sizeOf(context).height;
    if (height <= 1) return;

    final dy = details.globalPosition.dy - originY;
    final gain = PlayerController.verticalPlaybackGestureGain;
    final delta = -(dy / height) * gain;
    final pc = Get.find<PlayerController>();
    final cap = _isDraggingLeft ? 1.0 : pc.maxPlaybackVolume;
    final newValue = (_verticalGestureStartLevel + delta).clamp(0.0, cap);

    if (_isDraggingLeft) {
      pc.setInAppPlaybackBrightness(newValue);
      _overlayIcon.value = Icons.brightness_6_rounded;
    } else {
      pc.setVolume(newValue);
      _overlayIcon.value = playerVolumeIconFor(newValue);
    }
    _overlayValue.value = newValue;
    _showOverlay.value = true;
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _showOverlay.value = false;
    });
  }

  void _nudgeVolumeFromKey(double delta) async {
    _restartHideTimer();
    final pc = Get.find<PlayerController>();
    final cap = pc.maxPlaybackVolume;
    final newVol = (pc.currentVolume + delta).clamp(0.0, cap);
    pc.setVolume(newVol);

    _overlayValue.value = newVol;
    _overlayIcon.value = playerVolumeIconFor(newVol);
    _showOverlay.value = true;
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _showOverlay.value = false;
    });
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    final v = widget.controller.videoPlayerController?.value;
    if (v == null) {
      _betterPlayerValueNotifier.value = null;
      return;
    }
    final old = _betterPlayerValueNotifier.value;
    if (old != null && _tvOsdVideoFieldsUnchanged(old, v)) {
      return;
    }
    _betterPlayerValueNotifier.value = v;
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
    final pc = Get.find<PlayerController>();
    final isVod = pc.isMovie ||
        pc.isSeries ||
        streamUrl.contains('/movie/') ||
        streamUrl.contains('/series/');
    final scrubLive = !isVod && pc.liveTimeshiftSeekAvailable;
    if ((isVod || scrubLive) &&
        _cfg.enableProgressBar &&
        (v.duration?.inMilliseconds ?? 0) > 0) {
      final d = (v.position.inMilliseconds - old.position.inMilliseconds).abs();
      return d < 500;
    }
    return true;
  }

  Duration get _hideAfter {
    final remote = Get.find<AppSettingsService>()
        .layoutMode
        .value
        .usesRemoteNavigationStyle;
    return remote ? _hideAfterTv : _hideAfterMobile;
  }

  void _restartHideTimer() {
    if (Get.find<AppSettingsService>()
        .layoutMode
        .value
        .usesRemoteNavigationStyle) {
      Get.find<PlayerController>().scheduleTvOsdAutoHide();
      return;
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (!mounted) return;
      // Kullanıcı sarma çubuğunu sürüklüyorsa gizleme — yeniden zamanla.
      if (Get.find<PlayerController>().vodScrubbing.value) {
        _restartHideTimer();
        return;
      }
      _visible.value = false;
      widget.onPlayerVisibilityChanged(false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pc = Get.find<PlayerController>();
        if (pc.liveChannelStripOverlayOpen.value ||
            pc.liveSingleChannelEpgOpen.value ||
            pc.vodBrowseRailOpen.value) {
          return;
        }
        _mainFocusNode.requestFocus();
      });
    });
  }

  void _showControls() {
    _visible.value = true;
    widget.onPlayerVisibilityChanged(true);
    _restartHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pc = Get.find<PlayerController>();
      if (pc.liveChannelStripOverlayOpen.value ||
          pc.liveSingleChannelEpgOpen.value ||
          pc.vodBrowseRailOpen.value) {
        return;
      }
      _firstOsdButtonFocus.requestFocus();
    });
  }

  void _togglePlay() {
    _restartHideTimer();
    final v = _betterPlayerValueNotifier.value;
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
    final v = _betterPlayerValueNotifier.value;
    if (v == null) return;
    final ms = math.max(0, v.position.inMilliseconds - _skipMs);
    widget.controller.seekTo(Duration(milliseconds: ms));
    widget.controller.play();
  }

  void _skipForward15() {
    _restartHideTimer();
    final v = _betterPlayerValueNotifier.value;
    if (v == null) return;
    var target = v.position.inMilliseconds + _skipMs;
    final dur = v.duration;
    if (dur != null && dur.inMilliseconds > 0) {
      target = math.min(dur.inMilliseconds, target);
    }
    widget.controller.seekTo(Duration(milliseconds: target));
    widget.controller.play();
  }

  void _zap(int delta) {
    Get.find<PlayerController>().zapRelativeDebounced(delta);
  }

  String _liveEpgSubtitle(bool live) {
    if (!live) return '';
    final epg = Get.find<EpgService>();
    final prog = epg.getCurrentProgrammeForLiveChannel(_channel);
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

  /// `1.0 → 1`, `2.0 → 2`, `1.5 → 1.5`, `1.25 → 1.25`.
  /// Tam sayı → 0 ondalık; 0.5'in tam katı → 1 ondalık; aksi halde
  /// (1.25, 1.75 gibi çeyrek adımlar) 2 ondalık.
  String _formatPlaybackRate(double rate) {
    if ((rate - rate.roundToDouble()).abs() < 0.001) {
      return rate.toStringAsFixed(0);
    }
    if (((rate * 2) - (rate * 2).roundToDouble()).abs() < 0.001) {
      return rate.toStringAsFixed(1);
    }
    return rate.toStringAsFixed(2);
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
        final remoteStyle = settings.layoutMode.value.usesRemoteNavigationStyle;
        // Yatay OSD arka plan saydamlığı (0–100, 100 = opak). Sadece kapsülün
        // arka planı / kenarı / gölgesi etkilenir — `child` içeriği korunur.
        final bgOpacity =
            (settings.osdLandscapeBackgroundOpacity.value.clamp(0, 100)) / 100;
        final sigma = bgOpacity <= 0
            ? 0.0
            : AppPerformance.glassSigmaRemoteStyle(
                settings,
                remoteStyle: remoteStyle,
                fullSigma: 20,
                reducedSigma: 10,
              );
        final decorated = Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: _scaleAlpha(ga.playerBarBorder, bgOpacity),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ga.playerBarGradientColors
                  .map((c) => _scaleAlpha(c, bgOpacity))
                  .toList(),
            ),
            boxShadow: [
              BoxShadow(
                color: _scaleAlpha(ga.playerBarShadowColor, bgOpacity),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        );
        if (sigma <= 0 ||
            !AppPerformance.usePlayerOsdBackdropBlur(settings)) {
          return decorated;
        }
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: decorated,
        );
      }),
    );
  }

  /// Bir rengin alfa kanalını [factor] (0..1) ile çarp; OSD saydamlık
  /// ayarı için cam kapsül arka planını koru ama içeriğe dokunma.
  static Color _scaleAlpha(Color c, double factor) {
    if (factor >= 1) return c;
    if (factor <= 0) return c.withValues(alpha: 0);
    return c.withValues(alpha: c.a * factor);
  }

  static const _liveStripHoldFromOsd = Duration(milliseconds: 520);

  Timer? _osdCenterHoldTimer;
  bool _osdCenterHoldPending = false;
  static const _osdCenterHoldDuration = Duration(milliseconds: 520);

  void _cancelOsdCenterHold() {
    _osdCenterHoldTimer?.cancel();
    _osdCenterHoldTimer = null;
    _osdCenterHoldPending = false;
  }

  void _osdCenterHoldKeyDown(VoidCallback onPressed) {
    _restartHideTimer();
    _cancelOsdCenterHold();
    _osdCenterHoldPending = true;
    _osdCenterHoldTimer = Timer(_osdCenterHoldDuration, () {
      _osdCenterHoldTimer = null;
      if (!mounted) return;
      if (!_osdCenterHoldPending) return;
      _osdCenterHoldPending = false;
      _openQuickMenuFromOsd();
    });
  }

  void _osdCenterHoldKeyUp(VoidCallback onPressed) {
    _osdCenterHoldTimer?.cancel();
    _osdCenterHoldTimer = null;
    final wasPending = _osdCenterHoldPending;
    _osdCenterHoldPending = false;

    if (wasPending) {
      onPressed();
    }
  }

  void _openQuickMenuFromOsd() {
    _restartHideTimer();
    final pc = Get.find<PlayerController>();
    if (pc.vodBrowseRailAvailable) {
      pc.requestOpenVodBrowseRailFromTvOsd();
    } else {
      pc.requestOpenLiveChannelStripFromTvOsd();
    }
  }

  Widget _osdButton({
    required String tooltip,
    IconData? icon,
    String? letter,
    required VoidCallback onPressed,
    VoidCallback? onHoldRepeatAction,
    bool primary = false,
    double? size,
    Color? iconColor,
    FocusNode? focusNode,
    KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent,
  }) {
    assert(icon != null || (letter != null && letter.isNotEmpty));
    final double btnSize = size ?? _osdBtnSize;
    final primaryColor = Theme.of(Get.context!).colorScheme.primary;

    return StatefulBuilder(
      builder: (context, setState) {
        return Focus(
          focusNode: focusNode,
          // InkWell vb. alt widget'lar ayrı odak hedefi olmasın; sağ/sol tek basışta bir kontrole geçsin.
          descendantsAreFocusable: false,
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              _cancelOsdCenterHold();
            }
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

            final key = event.logicalKey;
            final centerKey = key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.numpadEnter ||
                key == LogicalKeyboardKey.space ||
                key == LogicalKeyboardKey.gameButtonSelect;

            if (event is! KeyDownEvent && event is! KeyRepeatEvent && event is! KeyUpEvent) {
              return KeyEventResult.ignored;
            }

            // OSD Butonlarında Hızlı Menü (Uzun Basış) veya Özel Tekrar Eylemi
            if (centerKey) {
              if (onHoldRepeatAction != null) {
                // Özel tekrar eylemi varsa (örneğin ileri sarma), timer kullanma
                if (event is KeyRepeatEvent) {
                  _restartHideTimer();
                  onHoldRepeatAction();
                  return KeyEventResult.handled;
                }
                if (event is KeyDownEvent) {
                  onPressed();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.handled;
              } else {
                // Özel eylem yoksa standart hızlı menü uzun basış timer'ı
                if (event is KeyDownEvent) {
                  _osdCenterHoldKeyDown(onPressed);
                  return KeyEventResult.handled;
                }
                if (event is KeyUpEvent) {
                  _osdCenterHoldKeyUp(onPressed);
                  return KeyEventResult.handled;
                }
                if (event is KeyRepeatEvent) {
                  _restartHideTimer();
                  return KeyEventResult.handled;
                }
              }
            }

            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }

            final pc = Get.find<PlayerController>();
            final url = pc.channel.value.streamUrl.toLowerCase();
            final vod = pc.isMovie ||
                pc.isSeries ||
                url.contains('/movie/') ||
                url.contains('/series/');
            final liveCh = !vod;
            final liveTs = liveCh && pc.liveTimeshiftSeekAvailable;

            // Tuşu basılı tutunca tekrar: OSD'de sağ/sol ile buton gezme yerine kanal / sarma (İPTAL EDİLDİ: Sadece Canlı TV zap kaldı)
            if (key == LogicalKeyboardKey.arrowUp) {
              if (!_visible.value) {
                _visible.value = true;
                widget.onPlayerVisibilityChanged(true);
              }
              _restartHideTimer();
              if (event is KeyRepeatEvent) {
                return KeyEventResult.handled;
              }
              if (liveCh && !liveTs) {
                _zap(-1);
              } else {
                _skipBack15();
              }
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowDown) {
              if (!_visible.value) {
                _visible.value = true;
                widget.onPlayerVisibilityChanged(true);
              }
              _restartHideTimer();
              if (event is KeyRepeatEvent) {
                return KeyEventResult.handled;
              }
              if (liveCh && !liveTs) {
                _zap(1);
              } else {
                _skipForward15();
              }
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowLeft) {
              if (event is KeyRepeatEvent) {
                _restartHideTimer();
                if (liveCh && !liveTs) {
                  _zap(-1);
                } // VOD'da sağ-sol basılı tutunca sarma isteği iptal edildi, bu yüzden sadece Canlı TV zap işlemi yapıyoruz.
                return KeyEventResult.handled;
              }
              node.previousFocus();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowRight) {
              if (event is KeyRepeatEvent) {
                _restartHideTimer();
                if (liveCh && !liveTs) {
                  _zap(1);
                } // VOD'da sağ-sol basılı tutunca sarma isteği iptal edildi.
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
              final tl = Get.find<AppSettingsService>().themeLabel.value;
              final ga = GlassAppearance.fromLabel(tl);
              final isFb = tl == GlassThemeLabels.flatBlack;
              final unfocusedBg = primary
                  ? (isFb
                      ? const Color(0xFF0C0C0C)
                      : const Color(0xFF4EC4D4).withValues(alpha: 0.45))
                  : ga.playerBarDimColor;
              final focusedFill = focused
                  ? (primary && isFb
                      ? const Color(0xFF141414)
                      : primaryColor.withValues(alpha: 0.6))
                  : unfocusedBg;
              final borderClr = focused
                  ? (isFb ? const Color(0xFF1A1A1A) : Colors.white)
                  : Colors.transparent;
              // Kumanda / TV düzeninde D-pad odağı butona gelince Flutter
              // Tooltip'i "15 sn geri" gibi küçük bir balon gösteriyordu;
              // remote modda tooltip'i atla (mobil/tablet'te aynı kalır).
              final remoteStyle = Get.find<AppSettingsService>()
                  .layoutMode
                  .value
                  .usesRemoteNavigationStyle;
              final button = AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  color: focusedFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderClr,
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
                                    ? (btnSize * 0.48).clamp(16.0, 22.0)
                                    : (btnSize * 0.44).clamp(15.0, 20.0),
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          )
                        : Icon(
                            icon!,
                            color: iconColor ?? Colors.white,
                            size: primary
                                ? (btnSize * 0.59).roundToDouble()
                                : (btnSize * 0.5).roundToDouble(),
                          ),
                  ),
                ),
              );
              if (remoteStyle) return button;
              return Tooltip(
                message: tooltip,
                child: button,
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

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final leftInset = MediaQuery.paddingOf(context).left;
    final rightInset = MediaQuery.paddingOf(context).right;


    final osdTier = Get.find<AppSettingsService>().osdSizeTier.value;
    double osdScale = 1.0;
    if (osdTier == 0) {
      osdScale = 0.85;
    } else if (osdTier == 2) {
      osdScale = 1.25;
    } else if (osdTier == 3) {
      osdScale = 1.45;
    }

    _osdBtnSize = 44.0;
    _osdBtnGap = 6.0;
    _osdInfoMaxW = 168.0;

    return Obx(() {
      final ch = controller.channel.value;
      final streamUrl = ch.streamUrl.toLowerCase();
      final isVod = controller.isMovie ||
          controller.isSeries ||
          streamUrl.contains('/movie/') ||
          streamUrl.contains('/series/');
      final live = !isVod;
      final liveTimeshift = live && controller.liveTimeshiftSeekAvailable;
      final fit = controller.videoFit.value;
      final _ = controller.osdQualityStamp.value;
      final resolutionTier = controller.osdStreamResolutionTierLabel;
      final hzLabel = controller.osdStreamFrameRateHzLabel;
      final epgLine = _liveEpgSubtitle(live);
      final quickMenuBadge = controller.osdQuickMenuHoldBadgeVisible;
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
            if (_subDialogOpen) return KeyEventResult.ignored;
            final pcDialog =
                Get.find<PlayerController>().vodResumeDialogOpen.value;
            if (pcDialog) {
              return KeyEventResult.ignored;
            }
            if (Get.find<PlayerController>().vodAutoplayCountdown.value !=
                null) {
              return KeyEventResult.ignored;
            }

            final route = ModalRoute.of(context);
            if (route != null && !route.isCurrent) {
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

            // Canlı TV: ↑/↓ tek basış zap + kısa OSD (tvOsdAutoHide).
            if (key == LogicalKeyboardKey.arrowUp ||
                key == LogicalKeyboardKey.arrowDown) {
              final zapDelta =
                  key == LogicalKeyboardKey.arrowUp ? -1 : 1;
              if (live && !liveTimeshift) {
                if (!_visible.value) {
                  _showControls();
                } else {
                  _restartHideTimer();
                }
                if (event is KeyRepeatEvent) {
                  return KeyEventResult.handled;
                }
                _zap(zapDelta);
                return KeyEventResult.handled;
              }
              if (!_visible.value) {
                _showControls();
                return KeyEventResult.handled;
              }
              if (zapDelta < 0) {
                _skipBack15();
              } else {
                _skipForward15();
              }
              return KeyEventResult.handled;
            }

            if (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.space ||
                key == LogicalKeyboardKey.gameButtonSelect) {
              if (!_visible.value) {
                _showControls();
                return KeyEventResult.handled;
              }
            }
            if (key == LogicalKeyboardKey.goBack ||
                key == LogicalKeyboardKey.backspace ||
                key == LogicalKeyboardKey.escape) {
              if (_visible.value) {
                _visible.value = false;
                _mainFocusNode.requestFocus();
                widget.onPlayerVisibilityChanged(false);
                return KeyEventResult.handled;
              }
              if (key == LogicalKeyboardKey.goBack) {
                if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
                  Get.back<void>();
                  return KeyEventResult.handled;
                }
                Get.find<PlayerController>().handleBack();
                return KeyEventResult.handled;
              }
            }

            // Film/dizi veya canlı catch-up: OSD kapalıyken sol/sağ önce OSD aç.
            if (!_visible.value && (isVod || liveTimeshift)) {
              if (key == LogicalKeyboardKey.arrowLeft ||
                  key == LogicalKeyboardKey.arrowRight) {
                _showControls();
                return KeyEventResult.handled;
              }
            }
            if (_visible.value && (isVod || liveTimeshift)) {
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
              ValueListenableBuilder<VideoPlayerValue?>(
                valueListenable: _betterPlayerValueNotifier,
                builder: (context, val, _) {
                  if (val?.isBuffering != true) return const SizedBox.shrink();
                  return Center(
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
                  );
                },
              ),
              if (Platform.isIOS)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  right: _visible.value ? 24 + rightInset : -100,
                  top: 24 + MediaQuery.paddingOf(context).top,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _visible.value ? 1.0 : 0.0,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: const CircleBorder(),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () {
                          Get.back();
                        },
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: (isPortrait ? 8 : 12) + leftInset,
                right: (isPortrait ? 8 : 12) + rightInset,
                bottom: (isPortrait ? 8 : 12) + bottomInset,
                child: Transform.scale(
                  scale: osdScale,
                  alignment: Alignment.bottomCenter,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                  offset: _visible.value ? Offset.zero : const Offset(0, 1.2),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: _visible.value ? 1 : 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ValueListenableBuilder<VideoPlayerValue?>(
                          valueListenable: _betterPlayerValueNotifier,
                          builder: (context, val, _) {
                            if (val == null || val.duration == null || val.duration!.inMilliseconds <= 0) {
                              return const SizedBox.shrink();
                            }
                            if (live && !liveTimeshift) return const SizedBox.shrink();
                            if (!_cfg.enableProgressBar) return const SizedBox.shrink();
                            return Padding(
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
                                  value: val,
                                  cfg: _cfg,
                                  onSeek: (d) {
                                    _restartHideTimer();
                                    widget.controller.seekTo(d);
                                    widget.controller.play();
                                  },
                                ),
                              ),
                            );
                          },
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
                                          maxWidth:
                                              isPortrait ? 118 : _osdInfoMaxW,
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
                                                ...() {
                                                  final badges =
                                                      osdStreamQualityBadgeWidgets(
                                                    resolutionTier:
                                                        resolutionTier,
                                                    hzLabel: hzLabel,
                                                    fontSize:
                                                        isPortrait ? 8 : 9,
                                                    borderRadius: 6,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal:
                                                          isPortrait ? 4 : 5,
                                                      vertical: 2,
                                                    ),
                                                  );
                                                  if (badges.isEmpty) {
                                                    return <Widget>[];
                                                  }
                                                  return <Widget>[
                                                    SizedBox(
                                                      width: isPortrait ? 4 : 6,
                                                    ),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: badges,
                                                    ),
                                                  ];
                                                }(),
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
                                            const SizedBox(height: 4),
                                            osdContentTypeAndEngineRow(
                                              live: live,
                                              isSeries: controller.isSeries,
                                              engine: VideoPlayerEngine.betterPlayer,
                                              transportFormat: controller
                                                  .osdStreamTransportFormatLabel,
                                              portrait: isPortrait,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: isPortrait ? 8 : 12),
                              // Sağ buton şeridi: kalan alanı `Expanded`
                              // ile alıyor; içerik sığarsa
                              // `Align.centerRight` doğal genişlikte
                              // sağa hizalar, sığmazsa
                              // `SingleChildScrollView` ile kullanıcı
                              // yatay sürükleyerek gizli butonlara
                              // erişir. TV D-pad için odak değişiminde
                              // `Scrollable.ensureVisible` otomatik
                              // çalışır.
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: FocusScope(
                                    child: FocusTraversalGroup(
                                      policy: OrderedTraversalPolicy(),
                                      child: _glassBar(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isPortrait ? 6 : 8,
                                          vertical: isPortrait ? 6 : 8,
                                        ),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _osdButton(
                                                tooltip: liveTimeshift
                                                    ? 'player.tooltip.rewind'.tr
                                                    : live
                                                        ? 'player.tooltip.prevCh'.tr
                                                        : 'player.tooltip.rewind'
                                                            .tr,
                                            icon: Icons.fast_rewind_rounded,
                                            onPressed: liveTimeshift
                                                ? _skipBack15
                                                : live
                                                    ? () => _zap(-1)
                                                    : _skipBack15,
                                            onHoldRepeatAction: live
                                                ? null
                                                : _skipBack15,
                                            size: isPortrait ? 34 : _osdBtnSize,
                                          ),
                                          SizedBox(width: isPortrait ? 4 : _osdBtnGap),
                                           ValueListenableBuilder<VideoPlayerValue?>(
                                             valueListenable: _betterPlayerValueNotifier,
                                             builder: (context, val, _) {
                                               final playing = val?.isPlaying ?? false;
                                               return _osdButton(
                                                 tooltip: playing
                                                     ? 'player.tooltip.pause'.tr
                                                     : 'player.tooltip.play'.tr,
                                                 icon: playing
                                                     ? Icons.pause_rounded
                                                     : Icons.play_arrow_rounded,
                                                 onPressed: _togglePlay,
                                                 primary: true,
                                                 size: isPortrait ? 34 : _osdBtnSize,
                                                 focusNode: _firstOsdButtonFocus,
                                               );
                                             },
                                           ),
                                          SizedBox(width: isPortrait ? 4 : _osdBtnGap),
                                          _osdButton(
                                            tooltip: liveTimeshift
                                                ? 'player.tooltip.forward'.tr
                                                : live
                                                    ? 'player.tooltip.nextCh'.tr
                                                    : 'player.tooltip.forward'
                                                        .tr,
                                            icon: Icons.fast_forward_rounded,
                                            onPressed: liveTimeshift
                                                ? _skipForward15
                                                : live
                                                    ? () => _zap(1)
                                                    : _skipForward15,
                                            onHoldRepeatAction: live
                                                ? null
                                                : _skipForward15,
                                            size: isPortrait ? 34 : _osdBtnSize,
                                          ),
                                          SizedBox(
                                              width: isPortrait
                                                  ? 6
                                                  : _osdBtnGap + 2),
                                          Container(
                                            width: 1,
                                            height: isPortrait
                                                ? 24
                                                : _osdBtnSize * 0.72,
                                            color: Colors.white
                                                .withValues(alpha: 0.25),
                                          ),
                                          if (quickMenuBadge) ...[
                                            SizedBox(width: isPortrait ? 4 : _osdBtnGap),
                                            _osdButton(
                                              tooltip:
                                                  'player.tooltip.quickMenuOpen'
                                                      .tr,
                                              icon: Icons.view_sidebar_rounded,
                                              onPressed: _openQuickMenuFromOsd,
                                              size: isPortrait ? 34 : _osdBtnSize,
                                            ),
                                          ],
                                          SizedBox(width: isPortrait ? 4 : _osdBtnGap),
                                          _osdButton(
                                            tooltip: 'player.tooltip.fit'
                                                .trParams(
                                                    {'fit': _fitLabel(fit)}),
                                            icon: _fitIcon(fit),
                                            onPressed: _cycleFit,
                                            size: isPortrait ? 34 : _osdBtnSize,
                                          ),
                                          if (live) ...[
                                            SizedBox(width: isPortrait ? 4 : _osdBtnGap),
                                            _osdButton(
                                              tooltip:
                                                  'player.tooltip.liveEpg'.tr,
                                              icon: Icons.view_timeline_rounded,
                                              onPressed: () {
                                                _restartHideTimer();
                                                controller
                                                    .openLiveSingleChannelEpgOverlay();
                                              },
                                              size: isPortrait ? 34 : _osdBtnSize,
                                            ),
                                          ],
                                          SizedBox(width: isPortrait ? 4 : _osdBtnGap),
                                          Obx(() {
                                            final pc =
                                                Get.find<PlayerController>();
                                            final favs =
                                                Get.find<FavoritesService>();
                                            favs.channelIds.length;
                                            favs.vodIds.length;
                                            favs.seriesIds.length;
                                            pc.channel.value;
                                            final isFav =
                                                pc.isCurrentMediaFavorite;
                                            return _osdButton(
                                              tooltip: isFav
                                                  ? 'player.tooltip.favOn'.tr
                                                  : 'player.tooltip.favOff'.tr,
                                              icon: isFav
                                                  ? Icons.favorite_rounded
                                                  : Icons
                                                      .favorite_border_rounded,
                                              onPressed: () {
                                                _restartHideTimer();
                                                pc.toggleCurrentMediaFavorite();
                                              },
                                              size: isPortrait ? 34 : _osdBtnSize,
                                            );
                                          }),
                                          SizedBox(width: isPortrait ? 4 : _osdBtnGap),
                                          _osdButton(
                                            tooltip:
                                                'player.tooltip.quality'.tr,
                                            icon: Icons.high_quality_rounded,
                                            onPressed: _showQualityDialog,
                                            size: isPortrait ? 34 : _osdBtnSize,
                                          ),
                                          SizedBox(width: isPortrait ? 4 : _osdBtnGap),
                                          _osdButton(
                                            tooltip:
                                                'player.tooltip.cast'.tr,
                                            icon: Icons.cast_rounded,
                                            onPressed: () {
                                              _restartHideTimer();
                                              unawaited(showPlayerCastSheet(
                                                context,
                                                controller:
                                                    Get.find<PlayerController>(),
                                                onClosed: () {
                                                  if (!mounted) return;
                                                  _showControls();
                                                },
                                              ));
                                            },
                                            size: isPortrait ? 34 : _osdBtnSize,
                                          ),
                                          if (isVod) ...[
                                            SizedBox(width: isPortrait ? 4 : _osdBtnGap),
                                            _osdButton(
                                              tooltip:
                                                  'player.tooltip.audio'.tr,
                                              icon: Icons.audiotrack_rounded,
                                              onPressed: () =>
                                                  unawaited(_showAudioDialog()),
                                              size: isPortrait ? 34 : _osdBtnSize,
                                            ),
                                            SizedBox(width: isPortrait ? 4 : _osdBtnGap),
                                            _osdButton(
                                              tooltip:
                                                  'player.tooltip.subtitle'.tr,
                                              icon:
                                                  Icons.closed_caption_rounded,
                                              onPressed: () => unawaited(
                                                  _showSubtitleDialog()),
                                              size: isPortrait ? 34 : _osdBtnSize,
                                            ),
                                            SizedBox(width: isPortrait ? 4 : _osdBtnGap),
                                            Obx(() {
                                              final rate =
                                                  controller.playbackRate.value;
                                              final isNormal =
                                                  (rate - 1.0).abs() < 0.001;
                                              return _osdButton(
                                                tooltip: isNormal
                                                    ? 'player.tooltip.speed.normal'
                                                        .tr
                                                    : 'player.tooltip.speed'
                                                        .trParams({
                                                        'rate':
                                                            _formatPlaybackRate(
                                                                rate),
                                                      }),
                                                icon: isNormal
                                                    ? Icons.speed_rounded
                                                    : null,
                                                letter: isNormal
                                                    ? null
                                                    : '${_formatPlaybackRate(rate)}x',
                                                onPressed: () {
                                                  _restartHideTimer();
                                                  controller
                                                      .cyclePlaybackRate();
                                                },
                                                size:
                                                    isPortrait ? 34 : _osdBtnSize,
                                              );
                                            }),
                                          ],
                                          Obx(() {
                                            final s = Get.find<AppSettingsService>();
                                            final pc = Get.find<PlayerController>();
                                            if (s.layoutMode.value == AppLayoutMode.tv) {
                                              return const SizedBox.shrink();
                                            }
                                            final mk = pc.effectiveUseMediaKit;
                                            return Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (s.layoutMode.value == AppLayoutMode.mobile) ...[
                                                  SizedBox(
                                                    width: isPortrait ? 4 : 6,
                                                  ),
                                                  _osdButton(
                                                    tooltip: 'player.tooltip.toPortrait'.tr,
                                                    icon: Icons.stay_current_portrait_rounded,
                                                    onPressed: () {
                                                      _restartHideTimer();
                                                      unawaited(
                                                        s.requestMobileHandheldPortraitPlayback(),
                                                      );
                                                    },
                                                    size: isPortrait ? 34 : _osdBtnSize,
                                                  ),
                                                ],
                                              ],
                                            );
                                          }),
                                            ],
                                          ),
                                        ),
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
              ),
              Obx(() => AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showOverlay.value ? 1.0 : 0.0,
                    child: PlayerGlassLevelOverlay(
                      visible: _showOverlay.value,
                      icon: _overlayIcon.value,
                      value01: _overlayValue.value,
                      maxValue:
                          Get.find<PlayerController>().maxPlaybackVolume,
                    ),
                  )),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _osdInfoDialog(String title, String body) async {
    _pauseOsdHideForModal();
    _suspendOsdFocusForDialog();
    try {
      await Get.dialog<void>(
        GlassAlertDialog(
          tvOsdStyle: true,
          title: Text(title),
          content: Text(body),
          actions: [
            GlassDialogActionButton(
              label: 'common.ok'.tr,
              primary: true,
              onPressed: () => Get.back<void>(),
              onDarkSurface: true,
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } finally {
      _resumeOsdAfterSubDialog();
    }
  }

  Future<void> _showQualityDialog() async {
    final ctrl = Get.find<PlayerController>();
    final tracks = ctrl.availableTracks;
    if (tracks.isEmpty) {
      await _osdInfoDialog(
        'player.quality.title'.tr,
        'player.quality.noneLong'.tr,
      );
      return;
    }
    _pauseOsdHideForModal();
    _suspendOsdFocusForDialog();
    try {
      await Get.dialog<void>(
        _TvQualityDialog(
          controller: ctrl,
          tracks: tracks,
        ),
        barrierDismissible: false,
      );
    } finally {
      _resumeOsdAfterSubDialog();
    }
  }

  Future<void> _showAudioDialog() async {
    final ctrl = Get.find<PlayerController>();
    final asms = ctrl.availableAudioTracks;
    if (asms.isNotEmpty) {
      _pauseOsdHideForModal();
      _suspendOsdFocusForDialog();
      try {
        await Get.dialog<void>(
          _TvAudioDialog(
            controller: ctrl,
            tracks: asms,
          ),
          barrierDismissible: false,
        );
      } finally {
        _resumeOsdAfterSubDialog();
      }
      return;
    }
    final exo = await ctrl.loadExoNativeTracks();
    if (!mounted) return;
    if (exo.audio.isEmpty) {
      await _osdInfoDialog(
        'player.audio.title'.tr,
        'player.audio.noneLong'.tr,
      );
      return;
    }
    _pauseOsdHideForModal();
    _suspendOsdFocusForDialog();
    try {
      await Get.dialog<void>(
        _TvExoNativeAudioDialog(
          controller: ctrl,
          tracks: exo.audio,
        ),
        barrierDismissible: false,
      );
    } finally {
      _resumeOsdAfterSubDialog();
    }
  }

  Future<void> _showSubtitleDialog() async {
    final ctrl = Get.find<PlayerController>();
    ctrl.cancelTvOsdAutoHide();
    _pauseOsdHideForModal();
    GlassSnackbar.show(
      'player.sheet.subtitleTitle'.tr,
      'common.loading'.tr,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
    final discovered = await ctrl.discoverVodSubtitleOptions();
    if (!mounted) return;
    if (!discovered.hasSelectableTracks) {
      await _osdInfoDialog(
        'player.sheet.subtitleTitle'.tr,
        'player.subtitle.noneLong'.tr,
      );
      return;
    }
    _suspendOsdFocusForDialog();
    try {
      await Get.dialog<void>(
        _TvUnifiedSubtitleDialog(
          controller: ctrl,
          sources: discovered.betterSources,
          exoTextTracks: discovered.exoTextTracks,
        ),
        barrierDismissible: false,
      );
    } finally {
      _resumeOsdAfterSubDialog();
    }
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

    return CallbackShortcuts(
      bindings: const <ShortcutActivator, VoidCallback>{},
      child: Center(
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
                              autofocus: tracks.indexOf(t) == 0,
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
                _TvDialogCloseButton(
                  onClose: () => Navigator.pop(context),
                ),
              ],
            ),
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
    return CallbackShortcuts(
      bindings: const <ShortcutActivator, VoidCallback>{},
      child: Center(
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
                              autofocus: tracks.indexOf(t) == 0,
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
                _TvDialogCloseButton(
                  onClose: () => Navigator.pop(context),
                ),
              ],
            ),
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
            autofocus: sorted.indexOf(s) == 0,
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
              autofocus: sorted.isEmpty && exoTextTracks.indexOf(opt) == 0,
              onTap: () {
                unawaited(controller.selectExoNativeTextTrack(opt));
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    }

    return CallbackShortcuts(
      bindings: const <ShortcutActivator, VoidCallback>{},
      child: Center(
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
                _TvDialogCloseButton(
                  onClose: () => Navigator.pop(context),
                ),
              ],
            ),
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
    String getTrackLabel(BetterPlayerAsmsTrack track) =>
        betterPlayerVideoQualityTrackLabel(track);

    final sorted = List<BetterPlayerAsmsTrack>.from(tracks);
    sorted.sort(compareBetterPlayerVideoQualityTracks);

    return CallbackShortcuts(
      bindings: const <ShortcutActivator, VoidCallback>{},
      child: Center(
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
                            autofocus: sorted.indexOf(track) == 0,
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
                _TvDialogCloseButton(
                  onClose: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _TvDialogCloseButton extends StatefulWidget {
  const _TvDialogCloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_TvDialogCloseButton> createState() => _TvDialogCloseButtonState();
}

class _TvDialogCloseButtonState extends State<_TvDialogCloseButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Focus(
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonSelect) {
          widget.onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onClose,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _focused
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: _focused
                  ? primary.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.28),
            ),
          ),
          child: Text(
            'common.close'.tr,
            style: TextStyle(
              color: _focused ? Colors.white : Colors.white70,
              fontWeight: FontWeight.w700,
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
    this.autofocus = false,
  });

  final String label;
  final bool isAuto;
  final bool isCurrent;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<_TvQualityOption> createState() => _TvQualityOptionState();
}

class _TvQualityOptionState extends State<_TvQualityOption> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Focus(
      autofocus: widget.autofocus,
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
            ? Builder(
                builder: (context) {
                  final px =
                      (size * MediaQuery.devicePixelRatioOf(context)).round();
                  return IptvChannelLogo(
                    imageUrl: url,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    memCacheWidth: px,
                    memCacheHeight: px,
                    showProgressIndicator: true,
                    progressIndicatorColor: Colors.white54,
                    errorWidget: const _LogoFallback(),
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
          child: VodSeekBar(
            position: value.position,
            duration: dur,
            enabled: cfg.enableProgressBarDrag,
            trackHeight: 5,
            thumbRadius: 8,
            overlayRadius: 16,
            activeColor: cfg.progressBarPlayedColor,
            inactiveColor: Colors.white.withValues(alpha: 0.22),
            thumbColor: cfg.progressBarHandleColor,
            overlayColor: cfg.progressBarHandleColor.withValues(alpha: 0.18),
            onSeek: onSeek,
            onScrubChanged: (s) => s
                ? Get.find<PlayerController>().beginVodScrub()
                : Get.find<PlayerController>().endVodScrub(),
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
