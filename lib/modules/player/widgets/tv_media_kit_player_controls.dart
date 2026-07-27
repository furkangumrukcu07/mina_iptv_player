import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';

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
  static const _hideAfterMobile = Duration(seconds: 5);
  static const _hideAfterTv = Duration(seconds: 5);
  static const _skipMs = 15_000;
  static const _loadingColor = Color(0xFF6ECFE0);

  // Yatay mobil + küçük ekranlarda OSD kapsülü taşmasın diye build sırasında
  // ekran genişliğine göre adaptif olarak hesaplanır.
  double _osdBtnSize = 44.0;
  double _osdBtnGap = 6.0;
  double _osdInfoMaxW = 168.0;

  Worker? _tvOsdVisibleWorker;
  Worker? _stripOverlayWorker;
  Worker? _vodBrowseRailWorker;
  Worker? _tvOsdKeyBumpWorker;
  Timer? _hideTimer;

  final _visible = true.obs;
  late final ValueNotifier<_MediaKitOsdSnapshot?> _mkSnapNotifier;

  Player? _mkListenerTarget;
  final List<StreamSubscription<dynamic>> _mkSubs = [];

  final FocusNode _mainFocusNode = FocusNode();
  final FocusNode _firstOsdButtonFocus = FocusNode(debugLabel: 'mkOsdFirst');

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


  PlayerController get _pc => Get.find<PlayerController>();

  Channel get _channel => _pc.channel.value;

  Player? get _player => _pc.mediaKitPlayer;

  @override
  void initState() {
    super.initState();
    _mkSnapNotifier = ValueNotifier<_MediaKitOsdSnapshot?>(null);
    final settings = Get.find<AppSettingsService>();
    final remoteLayout = settings.layoutMode.value.usesRemoteNavigationStyle;
    if (remoteLayout) {
      _visible.value = _pc.tvOsdVisible.value;
      _tvOsdVisibleWorker = ever(_pc.tvOsdVisible, (bool visible) {
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
            if (_pc.liveChannelStripOverlayOpen.value ||
                _pc.liveSingleChannelEpgOpen.value ||
                _pc.vodBrowseRailOpen.value ||
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
            if (_pc.liveChannelStripOverlayOpen.value ||
                _pc.liveSingleChannelEpgOpen.value ||
                _pc.vodBrowseRailOpen.value) {
              return;
            }
            if (_pc.vodResumeDialogOpen.value || _subDialogOpen) return;
            _mainFocusNode.requestFocus();
          });
        }
      });
      _stripOverlayWorker = ever(_pc.liveChannelStripOverlayOpen, (bool open) {
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
          if (_pc.vodResumeDialogOpen.value || _subDialogOpen) return;
          _mainFocusNode.requestFocus();
        });
      });
      _vodBrowseRailWorker = ever(_pc.vodBrowseRailOpen, (bool open) {
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
          if (_pc.vodResumeDialogOpen.value) return;
          _mainFocusNode.requestFocus();
        });
      });
      _tvOsdKeyBumpWorker = ever(_pc.tvOsdKeyFocusBump, (_) {
        if (!mounted) return;
        if (!Get.find<AppSettingsService>()
            .layoutMode
            .value
            .usesRemoteNavigationStyle) {
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_pc.vodResumeDialogOpen.value || _subDialogOpen) return;
          _requestTvPlayerFocus();
        });
      });
    }
    _attachMediaKitListener();
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
  void didUpdateWidget(covariant TvMediaKitPlayerControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attachMediaKitListener();
    if (Get.find<AppSettingsService>()
        .layoutMode
        .value
        .usesRemoteNavigationStyle) {
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
    final p = _pc.mediaKitPlayer;
    if (identical(_mkListenerTarget, p)) return;
    _cancelMkSubs();
    _mkListenerTarget = p;
    if (p == null) {
      if (mounted) _mkSnapNotifier.value = null;
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
      _mkSnapNotifier.value = null;
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
    final old = _mkSnapNotifier.value;
    if (old != null && _mkFieldsUnchanged(old, next)) return;
    _mkSnapNotifier.value = next;
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
    if (_pc.liveChannelStripOverlayOpen.value ||
        _pc.liveSingleChannelEpgOpen.value ||
        _pc.vodBrowseRailOpen.value ||
        _subDialogOpen) {
      return;
    }
    if (_visible.value) {
      _firstOsdButtonFocus.requestFocus();
    } else {
      _mainFocusNode.requestFocus();
    }
  }

  void _suspendOsdFocusForDialog() {
    _subDialogOpen = true;
    _mainFocusNode.unfocus();
    _firstOsdButtonFocus.unfocus();
  }

  void _pauseOsdHideForModal() {
    _pc.cancelTvOsdAutoHide();
    _hideTimer?.cancel();
  }

  void _resumeOsdAfterSubDialog() {
    if (!mounted) return;
    _subDialogOpen = false;
    final remote = Get.find<AppSettingsService>()
        .layoutMode
        .value
        .usesRemoteNavigationStyle;
    if (remote) {
      _pc.tvOsdVisible.value = true;
    }
    _visible.value = true;
    widget.onPlayerVisibilityChanged(true);
    _restartHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pc.liveChannelStripOverlayOpen.value ||
          _pc.liveSingleChannelEpgOpen.value ||
          _pc.vodBrowseRailOpen.value) {
        return;
      }
      _firstOsdButtonFocus.requestFocus();
    });
  }

  /// Worker'lari guvenli sekilde dispose et - memory leak onleme
  void _safeDisposeWorker(Worker? worker) {
    if (worker != null) {
      worker.dispose();
    }
  }

  @override
  void dispose() {
    _cancelLiveOsdPlayPauseCenterHold();
    _mkSnapNotifier.dispose();
    // TUM Worker'lari guvenli sekilde dispose et - memory leak kritik fix
    _safeDisposeWorker(_tvOsdVisibleWorker);
    _safeDisposeWorker(_stripOverlayWorker);
    _safeDisposeWorker(_vodBrowseRailWorker);
    _safeDisposeWorker(_tvOsdKeyBumpWorker);
    _hideTimer?.cancel();
    _overlayTimer?.cancel();
    _cancelMkSubs();
    _mkListenerTarget = null;
    _mainFocusNode.dispose();
    _firstOsdButtonFocus.dispose();
    super.dispose();
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
      _pc.scheduleTvOsdAutoHide();
      return;
    }
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (!mounted) return;
      // Kullanıcı sarma çubuğunu sürüklüyorsa gizleme — yeniden zamanla.
      if (_pc.vodScrubbing.value) {
        _restartHideTimer();
        return;
      }
      _visible.value = false;
      widget.onPlayerVisibilityChanged(false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pc.liveChannelStripOverlayOpen.value ||
            _pc.liveSingleChannelEpgOpen.value ||
            _pc.vodBrowseRailOpen.value) {
          return;
        }
        _mainFocusNode.requestFocus();
      });
    });
  }

  void _showControls() {
    if (Get.find<AppSettingsService>()
        .layoutMode
        .value
        .usesRemoteNavigationStyle) {
      _pc.tvOsdVisible.value = true;
    }
    _visible.value = true;
    widget.onPlayerVisibilityChanged(true);
    _restartHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pc.liveChannelStripOverlayOpen.value ||
          _pc.liveSingleChannelEpgOpen.value ||
          _pc.vodBrowseRailOpen.value) {
        return;
      }
      _firstOsdButtonFocus.requestFocus();
    });
  }

  void _handleVerticalDragStart(DragStartDetails details) async {
    final width = MediaQuery.sizeOf(context).width;
    _isDraggingLeft = details.globalPosition.dx < width / 2;
    _verticalGestureOriginY = details.globalPosition.dy;

    if (_isDraggingLeft) {
      _verticalGestureStartLevel = _pc.inAppPlaybackBrightness.value;
    } else {
      // PlayerController üzerinden logical volume (0..maxBoost) okunur.
      _verticalGestureStartLevel = _pc.currentVolume;
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
    final cap = _isDraggingLeft ? 1.0 : _pc.maxPlaybackVolume;
    final newValue = (_verticalGestureStartLevel + delta).clamp(0.0, cap);

    if (_isDraggingLeft) {
      _pc.setInAppPlaybackBrightness(newValue);
      _overlayIcon.value = Icons.brightness_6_rounded;
    } else {
      _pc.setVolume(newValue);
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
    final cap = _pc.maxPlaybackVolume;
    final newVol = (_pc.currentVolume + delta).clamp(0.0, cap);
    _pc.setVolume(newVol);

    _overlayValue.value = newVol;
    _overlayIcon.value = playerVolumeIconFor(newVol);
    _showOverlay.value = true;
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _showOverlay.value = false;
    });
  }

  void _togglePlay() {
    _restartHideTimer();
    final v = _mkSnapNotifier.value;
    if (v == null) return;
    if (v.playing) {
      _pc.pause();
    } else {
      _pc.play();
    }
  }

  void _skipBack15() {
    _restartHideTimer();
    final v = _mkSnapNotifier.value;
    if (v == null) return;
    final ms = math.max(0, v.position.inMilliseconds - _skipMs);
    _pc.seekTo(Duration(milliseconds: ms));
  }

  void _skipForward15() {
    _restartHideTimer();
    final v = _mkSnapNotifier.value;
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
        // arka planı / kenarı / gölgesi etkilenir — butonlar, ikonlar, metin
        // ve dolgu rengi `child` içinde, dokunulmaz.
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

  /// Bir rengin alfa kanalını [factor] (0..1) ile çarp; saydamlık slider'ı
  /// için cam kapsül arka planını koru ama içeriğe dokunma.
  static Color _scaleAlpha(Color c, double factor) {
    if (factor >= 1) return c;
    if (factor <= 0) return c.withValues(alpha: 0);
    return c.withValues(alpha: c.a * factor);
  }

  static const _liveStripHoldFromOsd = Duration(milliseconds: 520);

  bool _deferLiveStripHoldForOsdPlayPause(PlayerController pc) {
    final url = pc.channel.value.streamUrl.toLowerCase();
    final vod = pc.isMovie ||
        pc.isSeries ||
        url.contains('/movie/') ||
        url.contains('/series/');
    final liveCh = !vod;
    return liveCh && !pc.liveTimeshiftSeekAvailable;
  }

  void _cancelLiveOsdPlayPauseCenterHold() {
    _liveOsdPlayPauseCenterHoldTimer?.cancel();
    _liveOsdPlayPauseCenterHoldTimer = null;
    _liveOsdPlayPauseCenterHoldPending = false;
    _vodOsdBrowseRailHoldTimer?.cancel();
    _vodOsdBrowseRailHoldTimer = null;
    _vodOsdBrowseRailHoldPending = false;
  }

  void _liveOsdPlayPauseCenterKeyDown() {
    _restartHideTimer();
    if (_deferLiveStripHoldForOsdPlayPause(_pc)) {
      _cancelLiveOsdPlayPauseCenterHold();
      _liveOsdPlayPauseCenterHoldPending = true;
      _liveOsdPlayPauseCenterHoldTimer = Timer(_liveStripHoldFromOsd, () {
        _liveOsdPlayPauseCenterHoldTimer = null;
        if (!mounted) return;
        if (!_liveOsdPlayPauseCenterHoldPending) return;
        _liveOsdPlayPauseCenterHoldPending = false;
        _pc.requestOpenLiveChannelStripFromTvOsd();
      });
      return;
    }
    if (_pc.vodBrowseRailAvailable) {
      _cancelLiveOsdPlayPauseCenterHold();
      _vodOsdBrowseRailHoldPending = true;
      _vodOsdBrowseRailHoldTimer = Timer(_liveStripHoldFromOsd, () {
        _vodOsdBrowseRailHoldTimer = null;
        if (!mounted) return;
        if (!_vodOsdBrowseRailHoldPending) return;
        _vodOsdBrowseRailHoldPending = false;
        _pc.requestOpenVodBrowseRailFromTvOsd();
      });
      return;
    }
    _togglePlay();
  }

  void _liveOsdPlayPauseCenterKeyUp() {
    _liveOsdPlayPauseCenterHoldTimer?.cancel();
    _liveOsdPlayPauseCenterHoldTimer = null;
    final liveWasPending = _liveOsdPlayPauseCenterHoldPending;
    _liveOsdPlayPauseCenterHoldPending = false;

    _vodOsdBrowseRailHoldTimer?.cancel();
    _vodOsdBrowseRailHoldTimer = null;
    final vodWasPending = _vodOsdBrowseRailHoldPending;
    _vodOsdBrowseRailHoldPending = false;

    if (vodWasPending && _pc.vodBrowseRailAvailable) {
      _togglePlay();
      return;
    }
    if (liveWasPending && _deferLiveStripHoldForOsdPlayPause(_pc)) {
      _togglePlay();
    }
  }

  void _openQuickMenuFromOsd() {
    _restartHideTimer();
    if (_pc.vodBrowseRailAvailable) {
      _pc.requestOpenVodBrowseRailFromTvOsd();
    } else {
      _pc.requestOpenLiveChannelStripFromTvOsd();
    }
  }

  Widget _osdButton(
    BuildContext context, {
    required String tooltip,
    IconData? icon,
    String? letter,
    required VoidCallback onPressed,
    bool primary = false,
    double? size,
    Color? iconColor,
    FocusNode? focusNode,
    KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent,
    bool deferLiveOsdCenterForStrip = false,
  }) {
    final double btnSize = size ?? _osdBtnSize;
    assert(icon != null || (letter != null && letter.isNotEmpty));
    final primaryColor = Theme.of(context).colorScheme.primary;

    return StatefulBuilder(
      builder: (ctx, setSt) {
        return Focus(
          focusNode: focusNode,
          descendantsAreFocusable: false,
          onFocusChange: (hasFocus) {
            if (!hasFocus && deferLiveOsdCenterForStrip) {
              _cancelLiveOsdPlayPauseCenterHold();
            }
            if (hasFocus) {
              _restartHideTimer();
            }
            setSt(() {});
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

            if (deferLiveOsdCenterForStrip && centerKey) {
              if (event is KeyUpEvent) {
                _liveOsdPlayPauseCenterKeyUp();
                return KeyEventResult.handled;
              }
            }

            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            final url = _pc.channel.value.streamUrl.toLowerCase();
            final vod = _pc.isMovie ||
                _pc.isSeries ||
                url.contains('/movie/') ||
                url.contains('/series/');
            final liveCh = !vod;
            final liveTs = liveCh && _pc.liveTimeshiftSeekAvailable;

            if (deferLiveOsdCenterForStrip && centerKey) {
              if (event is KeyDownEvent) {
                _liveOsdPlayPauseCenterKeyDown();
                return KeyEventResult.handled;
              }
              if (event is KeyRepeatEvent) {
                _restartHideTimer();
                return KeyEventResult.handled;
              }
            }

            if (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.numpadEnter ||
                key == LogicalKeyboardKey.space ||
                key == LogicalKeyboardKey.gameButtonSelect) {
              if (event is KeyRepeatEvent) {
                _restartHideTimer();
                // Canlý (timeshift deðil): uzun OK tekrarýnda zýplatma yok; þerit OSD/PlayerView ile açýlýr.
                if (liveCh && !liveTs) {
                  return KeyEventResult.handled;
                }
                _skipForward15();
                return KeyEventResult.handled;
              }
              onPressed();
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowUp) {
              // Yukarý tuþu: OSD'yi hemen göster ve önceki kanala geç
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
              // Aþaðý tuþu: OSD'yi hemen göster ve sonraki kanala geç
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
                if (liveCh && !liveTs) {
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

  Future<void> _showQualityDialog() async {
    final tracks = _pc.mediaKitVideoTrackLabels();
    if (!mounted) return;
    if (tracks.length <= 1) {
      await _osdInfoDialog(
        'player.quality.title'.tr,
        'player.quality.noneLong'.tr,
      );
      return;
    }
    _pauseOsdHideForModal();
    _suspendOsdFocusForDialog();
    try {
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
        barrierDismissible: false,
      );
    } finally {
      _resumeOsdAfterSubDialog();
    }
  }

  Future<void> _showAudioDialog() async {
    final tracks = _pc.mediaKitAudioTrackLabels();
    if (!mounted) return;
    if (tracks.isEmpty) {
      await _osdInfoDialog(
        'player.audio.title'.tr,
        'player.audio.noneLong'.tr,
      );
      return;
    }
    _pauseOsdHideForModal();
    _suspendOsdFocusForDialog();
    try {
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
        barrierDismissible: false,
      );
    } finally {
      _resumeOsdAfterSubDialog();
    }
  }

  Future<void> _showSubtitleDialog() async {
    _pc.cancelTvOsdAutoHide();
    GlassSnackbar.show(
      'player.sheet.subtitleTitle'.tr,
      'common.loading'.tr,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
    final discovered = await _pc.discoverVodSubtitleOptions();
    if (!mounted) return;

    if (!discovered.hasMediaKitTracks) {
      await _osdInfoDialog(
        'player.sheet.subtitleTitle'.tr,
        'player.subtitle.noneLong'.tr,
      );
      return;
    }

    final tracks = discovered.mediaKitTracks;
    final list = tracks.entries.toList()
      ..sort((a, b) {
        if (a.key == 'no') return -1;
        if (b.key == 'no') return 1;
        return a.value.toLowerCase().compareTo(b.value.toLowerCase());
      });
    _pauseOsdHideForModal();
    _suspendOsdFocusForDialog();
    try {
      final active = _player?.state.track.subtitle.id ?? 'no';
      await Get.dialog<void>(
        _MkTrackPickDialog(
          title: 'player.sheet.subtitleTitle'.tr,
          entries: list,
          selectedId: active,
          onPick: (id) {
            unawaited(_pc.setMediaKitSubtitleById(id));
            Get.back<void>();
          },
        ),
        barrierDismissible: false,
      );
    } finally {
      _resumeOsdAfterSubDialog();
    }
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

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
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
      final ch = _pc.channel.value;
      _pc.mediaKitAttachEpoch.value;
      final streamUrl = ch.streamUrl.toLowerCase();
      final isVod = _pc.isMovie ||
          _pc.isSeries ||
          streamUrl.contains('/movie/') ||
          streamUrl.contains('/series/');
      final live = !isVod;
      final fit = _pc.videoFit.value;
      final _ = _pc.osdQualityStamp.value;
      final resolutionTier = _pc.osdStreamResolutionTierLabel;
      final hzLabel = _pc.osdStreamFrameRateHzLabel;
      final epgLine = _liveEpgSubtitle(live);
      final quickMenuBadge = _pc.osdQuickMenuHoldBadgeVisible;

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
            final pcDialog = _pc.vodResumeDialogOpen.value;
            if (pcDialog) {
              return KeyEventResult.ignored;
            }
            if (_pc.vodAutoplayCountdown.value != null) {
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

            if (key == LogicalKeyboardKey.arrowUp ||
                key == LogicalKeyboardKey.arrowDown) {
              final zapDelta =
                  key == LogicalKeyboardKey.arrowUp ? -1 : 1;
              final liveTimeshift = live && _pc.liveTimeshiftSeekAvailable;
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
                key == LogicalKeyboardKey.numpadEnter ||
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

            if (!_visible.value && isVod) {
              if (key == LogicalKeyboardKey.arrowLeft ||
                  key == LogicalKeyboardKey.arrowRight) {
                _showControls();
                return KeyEventResult.handled;
              }
            }
            if (_visible.value && isVod) {
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
              ValueListenableBuilder<_MediaKitOsdSnapshot?>(
                valueListenable: _mkSnapNotifier,
                builder: (context, snap, _) {
                  if (snap?.buffering != true) return const SizedBox.shrink();
                  return Center(
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
                left: 12 + leftInset,
                right: 12 + rightInset,
                bottom: 12 + bottomInset,
                child: ExcludeFocus(
                  excluding: !_visible.value,
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
                          ValueListenableBuilder<_MediaKitOsdSnapshot?>(
                            valueListenable: _mkSnapNotifier,
                            builder: (context, snap, _) {
                              if (live || snap == null || snap.duration.inMilliseconds <= 0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _glassBar(
                                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                                  child: _MkProgressBar(
                                    position: snap.position,
                                    duration: snap.duration,
                                    onSeek: (d) {
                                      _restartHideTimer();
                                      _pc.seekTo(d);
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
                                          key: ValueKey(
                                            '${ch.id}_${ch.logoUrl ?? ''}',
                                          ),
                                          logoUrl: ch.logoUrl,
                                          size: 42,
                                        ),
                                        const SizedBox(width: 8),
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: _osdInfoMaxW,
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
                                                  ...() {
                                                    final badges =
                                                        osdStreamQualityBadgeWidgets(
                                                      resolutionTier:
                                                          resolutionTier,
                                                      hzLabel: hzLabel,
                                                      fontSize: 9,
                                                      borderRadius: 6,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 5,
                                                        vertical: 2,
                                                      ),
                                                    );
                                                    if (badges.isEmpty) {
                                                      return <Widget>[];
                                                    }
                                                    return <Widget>[
                                                      SizedBox(width: _osdBtnGap),
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
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.1,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              osdContentTypeAndEngineRow(
                                                live: live,
                                                isSeries: _pc.isSeries,
                                                engine: _pc.activeVideoEngine,
                                                transportFormat: _pc
                                                    .osdStreamTransportFormatLabel,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Buton şeridi: sağ kapsül kalan tüm
                                // alanı alır, içerik sığarsa sağa
                                // hizalı doğal genişlikte kalır,
                                // sığmazsa kullanıcı yatay
                                // kaydırarak gizlenen butonlara
                                // ulaşır. TV D-pad odağı `Focus`
                                // tarafından otomatik
                                // `Scrollable.ensureVisible`
                                // çağrısı ile görünür kılınır.
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: FocusScope(
                                      child: FocusTraversalGroup(
                                        policy: OrderedTraversalPolicy(),
                                        child: _glassBar(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            physics:
                                                const BouncingScrollPhysics(),
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
                                            ),
                                            SizedBox(width: _osdBtnGap),
                                            ValueListenableBuilder<_MediaKitOsdSnapshot?>(
                                              valueListenable: _mkSnapNotifier,
                                              builder: (context, snap, _) {
                                                final playing = snap?.playing ?? false;
                                                return _osdButton(
                                                  context,
                                                  tooltip: playing
                                                      ? 'player.tooltip.pause'.tr
                                                      : 'player.tooltip.play'.tr,
                                                  icon: playing
                                                      ? Icons.pause_rounded
                                                      : Icons.play_arrow_rounded,
                                                  onPressed: _togglePlay,
                                                  primary: true,
                                                  focusNode: _firstOsdButtonFocus,
                                                  deferLiveOsdCenterForStrip: true,
                                                );
                                              },
                                            ),
                                            SizedBox(width: _osdBtnGap),
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
                                            SizedBox(width: _osdBtnGap + 2),
                                            Container(
                                              width: 1,
                                              height: _osdBtnSize * 0.72,
                                              color: Colors.white
                                                  .withValues(alpha: 0.25),
                                            ),
                                            if (quickMenuBadge) ...[
                                              SizedBox(width: _osdBtnGap),
                                              _osdButton(
                                                context,
                                                tooltip:
                                                    'player.tooltip.quickMenuOpen'
                                                        .tr,
                                                icon:
                                                    Icons.view_sidebar_rounded,
                                                onPressed:
                                                    _openQuickMenuFromOsd,
                                              ),
                                            ],
                                            SizedBox(width: _osdBtnGap),
                                            _osdButton(
                                              context,
                                              tooltip: 'player.tooltip.fit'
                                                  .trParams(
                                                      {'fit': _fitLabel(fit)}),
                                              icon: _fitIcon(fit),
                                              onPressed: _cycleFit,
                                            ),
                                            if (live) ...[
                                              SizedBox(width: _osdBtnGap),
                                              _osdButton(
                                                context,
                                                tooltip:
                                                    'player.tooltip.liveEpg'.tr,
                                                icon:
                                                    Icons.view_timeline_rounded,
                                                onPressed: () {
                                                  _restartHideTimer();
                                                  _pc.openLiveSingleChannelEpgOverlay();
                                                },
                                              ),
                                            ],
                                            SizedBox(width: _osdBtnGap),
                                            Obx(() {
                                              final favs =
                                                  Get.find<FavoritesService>();
                                              favs.channelIds.length;
                                              favs.vodIds.length;
                                              favs.seriesIds.length;
                                              _pc.channel.value;
                                              final isFav =
                                                  _pc.isCurrentMediaFavorite;
                                              return _osdButton(
                                                context,
                                                tooltip: isFav
                                                    ? 'player.tooltip.favOn'.tr
                                                    : 'player.tooltip.favOff'
                                                        .tr,
                                                icon: isFav
                                                    ? Icons.favorite_rounded
                                                    : Icons
                                                        .favorite_border_rounded,
                                                onPressed: () {
                                                  _restartHideTimer();
                                                  _pc
                                                      .toggleCurrentMediaFavorite();
                                                },
                                              );
                                            }),
                                            SizedBox(width: _osdBtnGap),
                                            _osdButton(
                                              context,
                                              tooltip:
                                                  'player.tooltip.quality'.tr,
                                              icon: Icons.high_quality_rounded,
                                              onPressed: () {
                                                unawaited(_showQualityDialog());
                                              },
                                            ),
                                            SizedBox(width: _osdBtnGap),
                                            _osdButton(
                                              context,
                                              tooltip:
                                                  'player.tooltip.cast'.tr,
                                              icon: Icons.cast_rounded,
                                              onPressed: () {
                                                _restartHideTimer();
                                                unawaited(showPlayerCastSheet(
                                                  context,
                                                  controller: _pc,
                                                  onClosed: () {
                                                    if (!mounted) return;
                                                    _showControls();
                                                  },
                                                ));
                                              },
                                            ),
                                            SizedBox(width: _osdBtnGap),
                                            _osdButton(
                                              context,
                                              tooltip:
                                                  'player.tooltip.audio'.tr,
                                              icon: Icons.audiotrack_rounded,
                                              onPressed: () {
                                                unawaited(_showAudioDialog());
                                              },
                                            ),
                                            SizedBox(width: _osdBtnGap),
                                            if (!live) ...[
                                              _osdButton(
                                                context,
                                                tooltip:
                                                    'player.tooltip.subtitle'
                                                        .tr,
                                                icon: Icons
                                                    .closed_caption_rounded,
                                                onPressed: () {
                                                  unawaited(
                                                      _showSubtitleDialog());
                                                },
                                              ),
                                              SizedBox(width: _osdBtnGap),
                                              Obx(() {
                                                final rate =
                                                    _pc.playbackRate.value;
                                                final isNormal =
                                                    (rate - 1.0).abs() < 0.001;
                                                return _osdButton(
                                                  context,
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
                                                    _pc.cyclePlaybackRate();
                                                  },
                                                );
                                              }),
                                              SizedBox(width: _osdBtnGap),
                                            ],
                                             Obx(() {
                                               final s = Get.find<AppSettingsService>();
                                               if (s.layoutMode.value == AppLayoutMode.tv) {
                                                 return const SizedBox.shrink();
                                               }
                                               final mk = _pc.effectiveUseMediaKit;
                                               return Row(
                                                 mainAxisSize: MainAxisSize.min,
                                                 children: [
                                                   if (s.layoutMode.value == AppLayoutMode.mobile) ...[
                                                     SizedBox(width: _osdBtnGap),
                                                     _osdButton(
                                                       context,
                                                       tooltip: 'player.tooltip.toPortrait'.tr,
                                                       icon: Icons.stay_current_portrait_rounded,
                                                       onPressed: () {
                                                         _restartHideTimer();
                                                         unawaited(
                                                           s.requestMobileHandheldPortraitPlayback(),
                                                         );
                                                       },
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
              ),
              Obx(() => AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showOverlay.value ? 1.0 : 0.0,
                    child: PlayerGlassLevelOverlay(
                      visible: _showOverlay.value,
                      icon: _overlayIcon.value,
                      value01: _overlayValue.value,
                      maxValue: _pc.maxPlaybackVolume,
                    ),
                  )),
            ],
          ),
        ),
      );
    });
  }
}

class _MkTrackPickDialog extends StatefulWidget {
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
  State<_MkTrackPickDialog> createState() => _MkTrackPickDialogState();
}

class _MkTrackPickDialogState extends State<_MkTrackPickDialog> {
  final ScrollController _scrollController = ScrollController();
  late final List<FocusNode> _entryFocusNodes;
  final FocusNode _closeFocusNode = FocusNode(debugLabel: 'mkTrackClose');
  late int _focusedIndex;

  @override
  void initState() {
    super.initState();
    _entryFocusNodes = List<FocusNode>.generate(
      widget.entries.length,
      (i) => FocusNode(debugLabel: 'mkTrackOption_$i'),
    );
    final selectedIndex = widget.selectedId == null
        ? -1
        : widget.entries.indexWhere((e) => e.key == widget.selectedId);
    _focusedIndex = selectedIndex >= 0 ? selectedIndex : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _entryFocusNodes.isEmpty) return;
      _entryFocusNodes[_focusedIndex].requestFocus();
      _ensureFocusedVisible();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final n in _entryFocusNodes) {
      n.dispose();
    }
    _closeFocusNode.dispose();
    super.dispose();
  }

  void _moveFocus(int delta) {
    if (_entryFocusNodes.isEmpty) return;
    final next = (_focusedIndex + delta).clamp(0, _entryFocusNodes.length - 1);
    if (next == _focusedIndex) return;
    _focusedIndex = next;
    _entryFocusNodes[_focusedIndex].requestFocus();
    _ensureFocusedVisible();
    setState(() {});
  }

  void _ensureFocusedVisible() {
    if (!_scrollController.hasClients || widget.entries.isEmpty) return;
    const rowExtent = 57.0;
    final targetTop = (_focusedIndex * rowExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      targetTop,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
  }

  void _pickFocused() {
    if (widget.entries.isEmpty) return;
    widget.onPick(widget.entries[_focusedIndex].key);
  }

  bool get _isCloseFocused => _closeFocusNode.hasFocus;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: const <ShortcutActivator, VoidCallback>{},
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.handled;
          }
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowUp) {
            if (_isCloseFocused) {
              if (_entryFocusNodes.isNotEmpty) {
                _entryFocusNodes[_focusedIndex].requestFocus();
              }
              return KeyEventResult.handled;
            }
            _moveFocus(-1);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown) {
            if (_isCloseFocused) {
              return KeyEventResult.handled;
            }
            if (_focusedIndex >= _entryFocusNodes.length - 1) {
              _closeFocusNode.requestFocus();
              return KeyEventResult.handled;
            }
            _moveFocus(1);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight) {
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonSelect) {
            if (_isCloseFocused) {
              Get.back<void>();
              return KeyEventResult.handled;
            }
            _pickFocused();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: FocusScope(
          autofocus: true,
          child: Center(
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
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView.separated(
                          controller: _scrollController,
                          shrinkWrap: true,
                          itemCount: widget.entries.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: Colors.white12, height: 1),
                          itemBuilder: (context, i) {
                            final e = widget.entries[i];
                            final cur =
                                widget.selectedId != null && e.key == widget.selectedId;
                            return _MkTrackOptionTile(
                              node: _entryFocusNodes[i],
                              label: e.value.isNotEmpty ? e.value : e.key,
                              selected: cur,
                              onFocused: () {
                                if (_focusedIndex == i) return;
                                _focusedIndex = i;
                                _ensureFocusedVisible();
                                setState(() {});
                              },
                              onActivate: () => widget.onPick(e.key),
                            );
                          },
                        ),
                      ),
                      _MkDialogCloseButton(
                        focusNode: _closeFocusNode,
                        onClose: () => Get.back<void>(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MkTrackOptionTile extends StatefulWidget {
  const _MkTrackOptionTile({
    required this.node,
    required this.label,
    required this.selected,
    required this.onFocused,
    required this.onActivate,
  });

  final FocusNode node;
  final String label;
  final bool selected;
  final VoidCallback onFocused;
  final VoidCallback onActivate;

  @override
  State<_MkTrackOptionTile> createState() => _MkTrackOptionTileState();
}

class _MkTrackOptionTileState extends State<_MkTrackOptionTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: widget.node,
      onFocusChange: (value) {
        if (_focused == value) return;
        _focused = value;
        if (value) widget.onFocused();
        setState(() {});
      },
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.handled;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonSelect) {
          widget.onActivate();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onActivate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _focused
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused
                  ? Colors.white
                  : (widget.selected
                      ? primary.withValues(alpha: 0.45)
                      : Colors.transparent),
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.selected ? Colors.white : Colors.white70,
                    fontWeight:
                        widget.selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.selected)
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

class _MkDialogCloseButton extends StatefulWidget {
  const _MkDialogCloseButton({
    required this.focusNode,
    required this.onClose,
  });

  final FocusNode focusNode;
  final VoidCallback onClose;

  @override
  State<_MkDialogCloseButton> createState() => _MkDialogCloseButtonState();
}

class _MkDialogCloseButtonState extends State<_MkDialogCloseButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (_, event) {
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
          child: VodSeekBar(
            position: position,
            duration: dur,
            trackHeight: 5,
            thumbRadius: 8,
            overlayRadius: 16,
            activeColor: Colors.white,
            inactiveColor: Colors.white.withValues(alpha: 0.22),
            thumbColor: const Color(0xFF4EC4D4),
            overlayColor: const Color(0xFF4EC4D4).withValues(alpha: 0.18),
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

class _ChannelLogoBadge extends StatelessWidget {
  const _ChannelLogoBadge({super.key, this.logoUrl, this.size = 48.0});

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
