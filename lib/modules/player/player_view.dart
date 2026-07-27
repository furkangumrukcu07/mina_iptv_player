import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import '../../core/player/playback_orientation_manager.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/showcase_in_app_pip_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/home/film_dizi_catalog.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/playlist_data_source.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../../core/theme/app_performance.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../core/player/exo_native_track_option.dart';
import '../../../core/player/better_player_video_track_label.dart';
import '../../../core/player/iptv_playback_defaults.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/epg_entities.dart';
import '../../../domain/entities/m3u_result.dart';
import '../../../domain/entities/series.dart';
import '../../../domain/entities/series_episode_option.dart';
import '../../../domain/entities/vod.dart';
import 'widgets/landscape_status_overlay.dart';
import 'widgets/osd_stream_quality_badges.dart';
import 'widgets/live_channel_strip_overlay.dart';
import 'widgets/player_cast_sheet.dart';
import 'widgets/vod_browse_rail_overlay.dart';
import 'widgets/player_live_epg_overlay.dart';
import 'widgets/vod_autoplay_overlay.dart';
import 'widgets/vod_seek_bar.dart';
import 'widgets/player_glass_level_overlay.dart';
import 'widgets/tv_media_kit_player_controls.dart';
import 'widgets/playback_pinch_zoom_layer.dart';
import 'widgets/universal_video_player.dart';
import '../channels/channels_controller.dart'
    show
        kFavoritesVirtualCategoryId,
        kRecentlyWatchedVirtualCategoryId,
        kRecentlyWatchedLiveLimit;
import '../../services/user_history_service.dart';
import 'player_controller.dart';
import 'series_player_panel_data.dart';
import '../../../ui/glass_overlays.dart';
import '../../../ui/iptv_channel_logo.dart';

/// Parlaklık / ses dikey kaydırması için sol ve sağ kenar genişliği.
double playbackGestureEdgeStripWidth(double screenWidth) =>
    math.min(76.0, screenWidth * 0.14);

/// Sol kenar: parlaklık, sağ kenar: ses (dikey sürükleme).
class _PlaybackVolumeBrightnessEdgeGestures extends StatelessWidget {
  const _PlaybackVolumeBrightnessEdgeGestures({
    required this.onBrightnessDragStart,
    required this.onVolumeDragStart,
    required this.onVerticalDragUpdate,
    this.reserveSeekBarZone = false,
  });

  final void Function(DragStartDetails) onBrightnessDragStart;
  final void Function(DragStartDetails) onVolumeDragStart;
  final void Function(DragUpdateDetails) onVerticalDragUpdate;

  /// Tam ekran (yatay) yüzeyde seek bar / OSD kontrol satırı videonun
  /// üstünde, ekranın altında oturur. `true` iken alttan bir bant rezerve
  /// edilir; böylece seek bar'ı yatay sürüklerken parlaklık/ses dikey drag'i
  /// tetiklenmez. Dikey modda video 16:9 kutudadır ve seek bar onun altında
  /// ayrı durduğundan çakışma yoktur → `false`.
  final bool reserveSeekBarZone;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final edgeW = playbackGestureEdgeStripWidth(mq.size.width);
    // VOD seek bar / OSD kontrol satırı ekranın altında oturur. Parlaklık/ses
    // dikey kaydırma şeritleri tüm yüksekliği kaplarsa, seek bar'ı yatay
    // sürüklerken (soldan sağa) hareketin küçük dikey bileşeni dikey drag
    // tanıyıcısını kazandırıp yanlışlıkla parlaklık/ses değiştiriyordu.
    // Alttan bir bant rezerve ederek bu bölgede dikey gesture'ı kapatıyoruz;
    // seek scrub artık çakışmasız çalışır.
    const reservedBottom = 120.0;
    final bottomInset =
        reserveSeekBarZone ? mq.padding.bottom + reservedBottom : 0.0;
    const topInset = 12.0;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          top: topInset,
          bottom: bottomInset,
          width: edgeW,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: onBrightnessDragStart,
            onVerticalDragUpdate: onVerticalDragUpdate,
          ),
        ),
        Positioned(
          right: 0,
          top: topInset,
          bottom: bottomInset,
          width: edgeW,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: onVolumeDragStart,
            onVerticalDragUpdate: onVerticalDragUpdate,
          ),
        ),
      ],
    );
  }
}

/// Video yüzeyi + isteğe bağlı pinch-zoom (mobil/tablet).
/// Parlaklık yalnızca sol kenarda, ses yalnızca sağ kenarda; orta alan zoom için serbest.
Widget _playerVideoSurfaceStack({
  required BuildContext context,
  required PlayerController controller,
  required bool enablePinchZoom,
  required Widget player,
  required bool useEmbeddedEngineOsd,
  required Widget? mkOsd,
  required void Function(DragStartDetails) onBrightnessDragStart,
  required void Function(DragStartDetails) onVolumeDragStart,
  required void Function(DragUpdateDetails) onVerticalDragUpdate,
  required VoidCallback? onLongPress,
}) {
  var video = player;
  if (enablePinchZoom) {
    video = PlaybackPinchZoomLayer(
      playbackKey: controller.channel.value.streamUrl,
      child: player,
    );
  }
  return Stack(
    fit: StackFit.expand,
    clipBehavior: Clip.none,
    children: [
      const Positioned.fill(
        child: ColoredBox(color: Colors.black),
      ),
      // MediaKit Texture'ın Stack'te genişlemesi için (PiP bubble ile aynı mantık).
      Positioned.fill(child: video),
      if (useEmbeddedEngineOsd) _PlaybackVideoDimmer(controller: controller),
      if (useEmbeddedEngineOsd && mkOsd != null) mkOsd,
      if (onLongPress != null)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: onLongPress,
          ),
        ),
      _PlaybackVolumeBrightnessEdgeGestures(
        onBrightnessDragStart: onBrightnessDragStart,
        onVolumeDragStart: onVolumeDragStart,
        onVerticalDragUpdate: onVerticalDragUpdate,
        reserveSeekBarZone: true,
      ),
      if (controller.isSeries)
        _SkipIntroVideoOverlay(controller: controller),
    ],
  );
}

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
  final Set<int> _activePointers = {};

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

  void _handleBrightnessDragStart(DragStartDetails details) {
    if (_activePointers.length >= 2) return;
    _isDraggingLeft = true;
    _verticalGestureOriginY = details.globalPosition.dy;
    _verticalGestureStartLevel = controller.inAppPlaybackBrightness.value;
  }

  void _handleVolumeDragStart(DragStartDetails details) {
    if (_activePointers.length >= 2) return;
    _isDraggingLeft = false;
    _verticalGestureOriginY = details.globalPosition.dy;
    _verticalGestureStartLevel = controller.currentVolume;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_activePointers.length >= 2) {
      _showOverlay.value = false;
      return;
    }
    final originY = _verticalGestureOriginY;
    if (originY == null) return;

    final height = MediaQuery.sizeOf(context).height;
    if (height <= 1) return;

    final dy = details.globalPosition.dy - originY;
    final gain = PlayerController.verticalPlaybackGestureGain;
    final delta = -(dy / height) * gain;
    final cap = _isDraggingLeft ? 1.0 : controller.maxPlaybackVolume;
    final newValue = (_verticalGestureStartLevel + delta).clamp(0.0, cap);

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
    final cap = controller.maxPlaybackVolume;
    final v = (controller.currentVolume + delta).clamp(0.0, cap);
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
    // Hızlı kanal şeridinden seçim sonrası 3 sn işlem olmazsa kapanır
    // (yayına dön, OSD açma).
    controller.onRequestCloseLiveChannelStrip =
        () => _closeLiveChannelStrip(showOsdAfter: false);
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

  /// Kumanda/klavye sayı tuşunu (üst sıra veya numpad) 0–9 değerine çevirir.
  /// Sayı tuşu değilse null döner.
  static int? _digitFromKey(LogicalKeyboardKey key) => switch (key) {
        LogicalKeyboardKey.digit0 || LogicalKeyboardKey.numpad0 => 0,
        LogicalKeyboardKey.digit1 || LogicalKeyboardKey.numpad1 => 1,
        LogicalKeyboardKey.digit2 || LogicalKeyboardKey.numpad2 => 2,
        LogicalKeyboardKey.digit3 || LogicalKeyboardKey.numpad3 => 3,
        LogicalKeyboardKey.digit4 || LogicalKeyboardKey.numpad4 => 4,
        LogicalKeyboardKey.digit5 || LogicalKeyboardKey.numpad5 => 5,
        LogicalKeyboardKey.digit6 || LogicalKeyboardKey.numpad6 => 6,
        LogicalKeyboardKey.digit7 || LogicalKeyboardKey.numpad7 => 7,
        LogicalKeyboardKey.digit8 || LogicalKeyboardKey.numpad8 => 8,
        LogicalKeyboardKey.digit9 || LogicalKeyboardKey.numpad9 => 9,
        _ => null,
      };

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
    controller.cancelLiveStripAutoClose();
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

  /// Android/iOS sistem Geri — overlay önceliği, ardından oynatıcıdan çıkış.
  void _onPlayerBackPressed() {
    if (_consumeNextSystemBackPop) {
      _consumeNextSystemBackPop = false;
      return;
    }
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
  }

  bool _onGlobalHardwareKey(KeyEvent event) {
    if (!mounted) return false;
    // Oynatıcı menüsü (altyazı/ses/kalite — Get.dialog) veya bir bottom sheet
    // açıkken kumanda Geri: önce menüyü kapat, yayından çıkma. Kumandanın Geri
    // tuşu hem bir KeyEvent hem de ayrı bir sistem pop'u olarak iki kez gelir;
    // burada menüyü kapatıp [_consumeNextSystemBackPop] ile sonraki sistem
    // pop'unu yutmazsak menü kapanır ama aynı basışta yayından da çıkılıyordu.
    if (event is KeyDownEvent) {
      final bk = event.logicalKey;
      if (bk == LogicalKeyboardKey.goBack ||
          bk == LogicalKeyboardKey.escape ||
          bk == LogicalKeyboardKey.backspace) {
        if (Get.isDialogOpen == true || Get.isBottomSheetOpen == true) {
          _consumeNextSystemBackPop = true;
          Get.back<void>();
          return true;
        }
        
        // Eğer hiçbir dialog açık değilse, doğrudan player'dan çıkmak için
        // Geri tuşunu biz yutalım. Böylece Android'in gereksiz sistem pop
        // üretmesini ve arkadaki menüleri kapatmasını önlemiş oluruz.
        _consumeNextSystemBackPop = true;
        controller.handleBack();
        return true;
      }
    }
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
      // Şeritte gezinme/etkileşim oldukça otomatik kapanma süresini sıfırla
      // (yalnızca bir seçim sonrası sayaç etkinse).
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        controller.bumpLiveStripAutoCloseIfActive();
      }
      return false;
    }
    final ch = controller.channel.value;

    // Kumandadan sayı tuşları (0–9): canlı yayında doğrudan kanal numarasına
    // geçiş. OSD gizliyken de çalışır; girilen rakamlar kısa süre sonra (ya da
    // OK ile) uygulanır, Geri ile iptal edilir.
    if (_isLiveChannel(ch)) {
      final tv =
          Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
      if (tv) {
        final k = event.logicalKey;
        final entryActive = controller.tvChannelNumberEntry.value.isNotEmpty;
        if (entryActive &&
            (k == LogicalKeyboardKey.goBack ||
                k == LogicalKeyboardKey.escape)) {
          if (event is KeyDownEvent) controller.cancelChannelNumberEntry();
          return true;
        }
        if (entryActive &&
            event is KeyDownEvent &&
            (k == LogicalKeyboardKey.select ||
                k == LogicalKeyboardKey.enter ||
                k == LogicalKeyboardKey.numpadEnter ||
                k == LogicalKeyboardKey.gameButtonSelect)) {
          controller.commitChannelNumberEntry();
          return true;
        }
        final digit = _digitFromKey(k);
        if (digit != null) {
          if (event is KeyDownEvent) {
            controller.pushChannelNumberDigit(digit);
          }
          return true;
        }
      }
    }

    // Yatay + OSD kapalı iken kumandadan SOL yön tuşu: hızlı menüyü açar.
    // Canlı yayında kanal şeridi, film/dizi izlerken VOD browse rayı.
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final settings = Get.find<AppSettingsService>();
      final landscape = _lastAppliedOrientationInBuild == Orientation.landscape;
      final tv = settings.layoutMode.value == AppLayoutMode.tv;
      if (tv && landscape && !controller.tvOsdVisible.value) {
        if (_isLiveChannel(ch)) {
          _openLiveChannelStrip();
          return true;
        }
        if (controller.vodBrowseRailAvailable) {
          _openVodBrowseRail();
          return true;
        }
      }
    }

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
      child: Stack(
        fit: StackFit.expand,
        children: [
          PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              _onPlayerBackPressed();
            },
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Listener(
                onPointerDown: (event) {
                  _activePointers.add(event.pointer);
                },
                onPointerUp: (event) {
                  _activePointers.remove(event.pointer);
                },
                onPointerCancel: (event) {
                  _activePointers.remove(event.pointer);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                  Expanded(
                    child: FocusTraversalGroup(
                      policy: OrderedTraversalPolicy(),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // TvBetterPlayerControls ile aynı eksen; dar pencerede yanlışlıkla çift OSD olmasın.
                          final isPortrait =
                              MediaQuery.orientationOf(context) ==
                                  Orientation.portrait;
                          controller.setPlaybackPortraitForAutoHide(isPortrait);

                          final playerWidget = Obx(() {
                            // Tüm ilgili Rx’leri erken return’lerden önce oku; iç içe Obx kullanma.
                            final busy = controller.isBusy.value;
                            // Kanal değişiminde splash (logo+şemsiye) anında güncellenmeli;
                            // yalnızca [isBusy] dinlenirse zap sırasında eski logo bir kare kalır.
                            final splashChannel = controller.channel.value;
                            controller.suppressLiveZapLoadingUi.value;
                            controller.vodResumeDialogOpen.value;
                            final message = controller.error.value;
                            final fit = controller.videoFit.value;
                            controller.betterSurfaceEpoch.value;
                            final bp = controller.better;
                            final settings = Get.find<AppSettingsService>();
                            controller.betterOsdOverride.value;
                            final activeEngine = controller.activeVideoEngine;
                            final useMediaKitPlayer = activeEngine.isMediaKit;
                            final useEmbeddedEngineOsd = useMediaKitPlayer;
                            controller
                                .orphanBetterSurfaceRecoveryAttempts.value;

                            final remoteNav = remoteNavForScreenLayout(
                                context, settings.layoutMode.value);
                            // MediaKit Texture + InteractiveViewer (pinch) Android'de
                            // ana yüzeyde siyah ekran üretebiliyor; PiP'de Video doğrudan
                            // mount edildiği için görüntü orada görünür.
                            final enablePinchZoom =
                                !useMediaKitPlayer &&
                                playbackPinchZoomEnabledForLayout(
                              settings.layoutMode.value,
                            );
                            final liveCh = remoteNav &&
                                _isLiveChannel(controller.channel.value);
                            final live =
                                _isLiveChannel(controller.channel.value);

                            if (message != null) {
                              final err = _PlayerMessage(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final h = constraints.maxHeight;
                                    final maxScroll = h.isFinite
                                        ? math.max(120.0, h - 88)
                                        : 320.0;
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
                                          constraints: BoxConstraints(
                                              maxHeight: maxScroll),
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

                            final hasSurface =
                                useEmbeddedEngineOsd || bp != null;

                            final pendingShowcasePipRestore =
                                controller.isReopeningFromInAppPip ||
                                    (Get.isRegistered<ShowcaseInAppPipService>() &&
                                        Get.find<ShowcaseInAppPipService>()
                                            .hasPendingRestoreForReopen);

                            if (!hasSurface) {
                              if (busy) {
                                if (pendingShowcasePipRestore) {
                                  return const ColoredBox(
                                    color: Color(0xFF0D0D0F),
                                  );
                                }
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
                                      if (controller
                                              .vodResumeDialogOpen.value ||
                                          controller
                                                  .vodAutoplayCountdown.value !=
                                              null) {
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
                                        const ColoredBox(
                                            color: Color(0xFF0D0D0F)),
                                        // Yatay canlı: Better/MediaKit henüz yok — merkez "Akış açılıyor" yerine
                                        // gerçek OSD ile aynı cam panel (kanal değiştirme vb. çalışır); yüzey gelince bu dal biter.
                                        if (!isPortrait && liveCh)
                                          Obx(() {
                                            final cid =
                                                controller.channel.value.id;
                                            return TvMediaKitPlayerControls(
                                              key: ValueKey(
                                                  'mk_osd_presurface_$cid'),
                                              onPlayerVisibilityChanged: (v) {
                                                controller
                                                    .syncTvOsdVisibilityFromControls(
                                                        v);
                                              },
                                            );
                                          })
                                        else ...[
                                          if (!suppress)
                                            _PlayerLoadingOverlay(
                                              key: ValueKey(
                                                  'splash_${splashChannel.id}'),
                                              channel: splashChannel,
                                            ),
                                          if (useEmbeddedEngineOsd)
                                            Obx(() {
                                              final cid =
                                                  controller.channel.value.id;
                                              return TvMediaKitPlayerControls(
                                                key: ValueKey(
                                                    'mk_osd_init_$cid'),
                                                onPlayerVisibilityChanged: (v) {
                                                  controller
                                                      .syncTvOsdVisibilityFromControls(
                                                          v);
                                                },
                                              );
                                            }),
                                        ],
                                      ],
                                    ),
                                  );
                                }
                                return _PlayerMessage(
                                  child: _PlayerLoadingCenter(
                                    key: ValueKey(
                                        'splash_center_${splashChannel.id}'),
                                    channel: splashChannel,
                                  ),
                                );
                              }
                              if (!useEmbeddedEngineOsd &&
                                  controller.orphanBetterSurfaceRecoveryAttempts
                                          .value >=
                                      controller
                                          .effectiveMaxOrphanBetterSurfaceRetries) {
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
                                if (controller.isReopeningFromInAppPipPending) {
                                  return;
                                }
                                unawaited(
                                    controller.ensureOrphanBetterBootRetry());
                              });
                              final recovering = !isPortrait && liveCh
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        const ColoredBox(
                                            color: Color(0xFF0D0D0F)),
                                        Obx(() {
                                          final cid =
                                              controller.channel.value.id;
                                          return TvMediaKitPlayerControls(
                                            key: ValueKey(
                                                'mk_osd_orphan_retry_$cid'),
                                            onPlayerVisibilityChanged: (v) {
                                              controller
                                                  .syncTvOsdVisibilityFromControls(
                                                      v);
                                            },
                                          );
                                        }),
                                      ],
                                    )
                                  : _PlayerMessage(
                                      child: _PlayerLoadingCenter(
                                        key: ValueKey(
                                            'splash_center_${splashChannel.id}'),
                                        channel: splashChannel,
                                      ),
                                    );
                              return _liveRemoteZapWhenPlayerChromeMissing(
                                controller: controller,
                                enable: liveCh,
                                child: recovering,
                              );
                            }

                            if (useEmbeddedEngineOsd) {
                              controller.mediaKitAttachEpoch.value;
                            }

                            Widget addBusyShell(Widget core) {
                              if (!busy) return core;
                              final suppress =
                                  controller.suppressLiveZapLoadingUi.value;
                              if (suppress) {
                                return core;
                              }
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  core,
                                  Positioned.fill(
                                    child: _PlayerLoadingOverlay(
                                      key: ValueKey(
                                          'splash_${splashChannel.id}'),
                                      channel: splashChannel,
                                    ),
                                  ),
                                ],
                              );
                            }

                            final player = RepaintBoundary(
                              child: UniversalVideoPlayer(
                                key: _videoSurfaceKey,
                                url: controller.surfaceStreamUrl,
                                engine: activeEngine,
                                betterPlayerController: bp,
                                fit: fit,
                                onMediaKitPlayerChanged:
                                    controller.attachMediaKitPlayer,
                              ),
                            );

                            final mkOsd = useEmbeddedEngineOsd && !isPortrait
                                ? Obx(() {
                                    final epoch =
                                        controller.mediaKitAttachEpoch.value;
                                    final cid = controller.channel.value.id;
                                    return TvMediaKitPlayerControls(
                                      key: ValueKey('mk_osd_${cid}_$epoch'),
                                      onPlayerVisibilityChanged: (v) {
                                        controller
                                            .syncTvOsdVisibilityFromControls(v);
                                      },
                                    );
                                  })
                                : null;

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
                                    // Yedek odak: canlıda ↑/↓ tek basış zap + OSD; sol şerit için yukarı bırak.
                                    if (!controller.tvOsdVisible.value) {
                                      final liveTimeshift =
                                          live &&
                                              controller
                                                  .liveTimeshiftSeekAvailable;
                                      if (live && !liveTimeshift) {
                                        if (k ==
                                                LogicalKeyboardKey.arrowUp ||
                                            k ==
                                                LogicalKeyboardKey
                                                    .arrowDown) {
                                          final delta = k ==
                                                  LogicalKeyboardKey.arrowUp
                                              ? -1
                                              : 1;
                                          controller.tvOsdVisible.value =
                                              true;
                                          controller.scheduleTvOsdAutoHide();
                                          controller
                                              .zapRelativeDebounced(delta);
                                          return KeyEventResult.handled;
                                        }
                                        if (k ==
                                            LogicalKeyboardKey.arrowLeft) {
                                          return KeyEventResult.ignored;
                                        }
                                      }
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
                                    _playerVideoSurfaceStack(
                                      context: context,
                                      controller: controller,
                                      enablePinchZoom: enablePinchZoom,
                                      player: player,
                                      useEmbeddedEngineOsd: useEmbeddedEngineOsd,
                                      mkOsd: mkOsd,
                                      onBrightnessDragStart:
                                          _handleBrightnessDragStart,
                                      onVolumeDragStart: _handleVolumeDragStart,
                                      onVerticalDragUpdate:
                                          _handleVerticalDragUpdate,
                                      onLongPress: live
                                          ? _openLiveChannelStrip
                                          : (controller.vodBrowseRailAvailable
                                              ? _openVodBrowseRail
                                              : null),
                                    ),
                                  ),
                                ),
                              );
                            }
                            if (useEmbeddedEngineOsd && mkOsd != null) {
                              return addBusyShell(
                                _playerVideoSurfaceStack(
                                  context: context,
                                  controller: controller,
                                  enablePinchZoom: enablePinchZoom,
                                  player: player,
                                  useEmbeddedEngineOsd: useEmbeddedEngineOsd,
                                  mkOsd: mkOsd,
                                  onBrightnessDragStart:
                                      _handleBrightnessDragStart,
                                  onVolumeDragStart: _handleVolumeDragStart,
                                  onVerticalDragUpdate:
                                      _handleVerticalDragUpdate,
                                  onLongPress: live
                                      ? _openLiveChannelStrip
                                      : (controller.vodBrowseRailAvailable
                                          ? _openVodBrowseRail
                                          : null),
                                ),
                              );
                            }
                            return addBusyShell(
                              _playerVideoSurfaceStack(
                                context: context,
                                controller: controller,
                                enablePinchZoom: enablePinchZoom,
                                player: player,
                                useEmbeddedEngineOsd: useEmbeddedEngineOsd,
                                mkOsd: null,
                                onBrightnessDragStart:
                                    _handleBrightnessDragStart,
                                onVolumeDragStart: _handleVolumeDragStart,
                                onVerticalDragUpdate: _handleVerticalDragUpdate,
                                onLongPress: live
                                    ? _openLiveChannelStrip
                                    : (controller.vodBrowseRailAvailable
                                        ? _openVodBrowseRail
                                        : null),
                              ),
                            );
                          });

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(
                                child: Obx(
                                  () => ExcludeFocus(
                                    excluding: controller
                                            .liveChannelStripOverlayOpen
                                            .value ||
                                        controller
                                            .liveSingleChannelEpgOpen.value ||
                                        controller.vodBrowseRailOpen.value,
                                    child: isPortrait
                                        ? ColoredBox(
                                            color: const Color(0xFF0B0F14),
                                            child: _PlayerPortraitSurfaceShell(
                                              controller: controller,
                                              playerWidget: playerWidget,
                                              onBrightnessDragStart:
                                                  _handleBrightnessDragStart,
                                              onVolumeDragStart:
                                                  _handleVolumeDragStart,
                                              onVerticalDragUpdate:
                                                  _handleVerticalDragUpdate,
                                            ),
                                          )
                                        : playerWidget,
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
                                      maxValue: controller.maxPlaybackVolume,
                                    ),
                                  )),
                              _PlayerFadeLayer(controller: controller),
                              _PlayerLiveStripLayer(
                                controller: controller,
                                channelStripKey: _channelStripKey,
                                onClose: (showOsdAfter) =>
                                    _closeLiveChannelStrip(
                                        showOsdAfter: showOsdAfter),
                                onBackToOsd:
                                    _onLiveChannelStripOverlayBackToOsd,
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
                ],
              ),
            ),
            ),
          ),
          // Kumandadan sayı tuşu ile kanal numarası girişi kutusu (canlı, TV).
          _ChannelNumberEntryPositioned(controller: controller),
          // Yatay durum göstergeleri — gerçek saat (SOL üst) + batarya yüzdesi
          // (SAĞ üst), saydam arka planla ayrı ayrı konumlanır. Tam ekranda
          // sistem saat/batarya gizlendiği için opsiyonel. TV'de (batarya yok)
          // gösterilmez. Ayar kapalıysa boş döner.
          if (landscape) ...[
            Positioned(
              top: 10 + MediaQuery.paddingOf(context).top,
              left: 16 + MediaQuery.paddingOf(context).left,
              child: Obx(() {
                final s = Get.find<AppSettingsService>();
                if (!s.landscapeStatusBarEnabled.value ||
                    s.layoutMode.value == AppLayoutMode.tv) {
                  return const SizedBox.shrink();
                }
                return const IgnorePointer(child: LandscapeClockOverlay());
              }),
            ),
            Positioned(
              top: 10 + MediaQuery.paddingOf(context).top,
              right: 16 + MediaQuery.paddingOf(context).right,
              child: Obx(() {
                final s = Get.find<AppSettingsService>();
                if (!s.landscapeStatusBarEnabled.value ||
                    s.layoutMode.value == AppLayoutMode.tv) {
                  return const SizedBox.shrink();
                }
                return const IgnorePointer(child: LandscapeBatteryOverlay());
              }),
            ),
          ],
        ],
      ),
    );
  }
}

/// Player Stack'inin üstüne yerleşen Positioned banner. Canlı kanal + OSD
/// görünürlüğü + settings toggle filtrelemesi tek `Obx` içinde yapılır;
/// banner gerekmediğinde `SizedBox.shrink()` ile sıfır maliyetli kalır.
///
/// **Layout stratejisi:** Mobil/tablet portrait & landscape ve TV — üç
/// modda da OSD farklı yükseklikte bir cam panel olarak çıkıyor.
///
/// **Portrait** (telefon dik) ve **Landscape & TV** (yatay) için OSD ve
/// üstündeki bilgi şeritleri ayrı widget'lar tarafından yönetilir.
class _PortraitOsdPanel extends StatefulWidget {
  const _PortraitOsdPanel({required this.controller});

  final PlayerController controller;

  @override
  State<_PortraitOsdPanel> createState() => _PortraitOsdPanelState();
}

/// OSD kapalıyken tek dokunuşla panel açar; iki parmak pinch için olayları videoya bırakır.
class _PortraitVideoTapToShowOsd extends StatefulWidget {
  const _PortraitVideoTapToShowOsd({required this.controller});

  final PlayerController controller;

  @override
  State<_PortraitVideoTapToShowOsd> createState() =>
      _PortraitVideoTapToShowOsdState();
}

class _PortraitVideoTapToShowOsdState
    extends State<_PortraitVideoTapToShowOsd> {
  int _activePointers = 0;

  @override
  Widget build(BuildContext context) {
    final edgeW =
        playbackGestureEdgeStripWidth(MediaQuery.sizeOf(context).width);
    return IgnorePointer(
      ignoring: _activePointers >= 2,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => setState(() => _activePointers++),
        onPointerUp: (_) =>
            setState(() => _activePointers = math.max(0, _activePointers - 1)),
        onPointerCancel: (_) =>
            setState(() => _activePointers = math.max(0, _activePointers - 1)),
        // Kenarlar ses/parlaklık sürüklemesi için boş — yalnızca ortada tap.
        child: Row(
          children: [
            SizedBox(width: edgeW),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  widget.controller.tvOsdVisible.value = true;
                  widget.controller.scheduleTvOsdAutoHide();
                },
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            SizedBox(width: edgeW),
          ],
        ),
      ),
    );
  }
}

/// Akıllı Jenerik Atlatıcı (Smart Stream Cutter) — dizi içeriğinde,
/// ilk `introSkipTargetSec` saniyesi boyunca video yüzeyinin sağ alt
/// köşesinde beliren cam "Jeneriği Atla" butonu.
///
/// **Görünürlük:**
/// 1. `controller.introSkipTargetSec.value > 0` (o dizi için intro
///    süresi öğrenilmiş).
/// 2. Mevcut pozisyon `0..introSkipTargetSec` aralığında.
///
/// **Throttle:** Player'ın `currentPosition`'ı Rx değil — Duration
/// getter. Saniyede ~30 kez stream tetiklenebileceği için TV
/// box'larda UI yorulmasın diye `Timer.periodic(1 sn)` kullanıyoruz.
/// Cihaz işlemcisi yalnız saniyede 1 kez state güncellemesi yaşar.

/// Kumandadan sayı tuşu (0–9) ile girilen kanal numarasını sağ üstte gösteren
/// cam kutu. Boşken görünmez. Geçerli kategorideki toplam kanal sayısı küçük
/// bir alt etiket olarak yazılır.
class _ChannelNumberEntryPositioned extends StatelessWidget {
  const _ChannelNumberEntryPositioned({required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final entry = controller.tvChannelNumberEntry.value;
      if (entry.isEmpty) return const SizedBox.shrink();
      final total = controller.liveChannelsInCurrentCategory().length;
      final cs = Theme.of(context).colorScheme;
      return Positioned(
        top: 24 + MediaQuery.paddingOf(context).top,
        right: 24 + MediaQuery.paddingOf(context).right,
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.black.withValues(alpha: 0.55),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.85),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      entry,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        height: 1.0,
                      ),
                    ),
                    if (total > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '1–$total',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Akıllı Jenerik Atlatıcı — dizi VOD'da video yüzeyinin sağ alt köşesinde
/// cam «Jeneriği Atla» butonu. Yalnızca [_playerVideoSurfaceStack] içinde
/// konumlanır; böylece dikey 16:9 alan ve yatay tam ekran görüntüsüyle hizalı kalır.
///
/// **Görünürlük:**
/// 1. `controller.introSkipTargetSec.value > 0`
/// 2. Mevcut pozisyon `0..introSkipTargetSec` aralığında.
class _SkipIntroVideoOverlay extends StatefulWidget {
  const _SkipIntroVideoOverlay({required this.controller});
  final PlayerController controller;

  @override
  State<_SkipIntroVideoOverlay> createState() => _SkipIntroVideoOverlayState();
}

class _SkipIntroVideoOverlayState extends State<_SkipIntroVideoOverlay> {
  Timer? _ticker;
  Worker? _introTargetWorker;
  int _posSec = 0;

  @override
  void initState() {
    super.initState();
    _syncIntroTicker(widget.controller.introSkipTargetSec.value);
    _introTargetWorker = ever<int>(
      widget.controller.introSkipTargetSec,
      _syncIntroTicker,
    );
  }

  void _syncIntroTicker(int target) {
    if (target <= 0) {
      _stopIntroTicker();
      return;
    }
    _startIntroTicker();
  }

  void _startIntroTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final s = widget.controller.currentPosition.inSeconds;
      if (s == _posSec) return;
      final target = widget.controller.introSkipTargetSec.value;
      final wasVisible = target > 0 && _posSec < target && _posSec >= 0;
      final nowVisible = target > 0 && s < target && s >= 0;
      _posSec = s;
      if (wasVisible != nowVisible) {
        setState(() {});
      }
    });
  }

  void _stopIntroTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _introTargetWorker?.dispose();
    _stopIntroTicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final target = widget.controller.introSkipTargetSec.value;
      final visible = target > 0 && _posSec < target && _posSec >= 0;
      final isPortrait =
          MediaQuery.orientationOf(context) == Orientation.portrait;
      // Dikey: OSD video altında ayrı panel — buton 16:9 alanın sağ altında.
      // Yatay: OSD görüntü üstünde; gizliyken kenara yakın, açıkken seek bar üstü.
      final osdVisible = widget.controller.tvOsdVisible.value;
      final bottomInset = isPortrait
          ? 12.0
          : (osdVisible ? 104.0 : 16.0);
      return Positioned(
        right: 14,
        bottom: bottomInset,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: !visible,
            child: _SkipIntroButton(
              onTap: widget.controller.skipIntroNow,
            ),
          ),
        ),
      );
    });
  }
}

class _SkipIntroButton extends StatelessWidget {
  const _SkipIntroButton({required this.onTap});
  final VoidCallback onTap;

  Widget _buildSkipIntroCapsule(Color primary) {
    final capsule = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(alpha: 0.72),
            Colors.black.withValues(alpha: 0.52),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          width: 0.7,
          color: Colors.white.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.30),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.40),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.fast_forward_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            'player.skip_intro'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
    if (!Get.isRegistered<AppSettingsService>()) return capsule;
    final settings = Get.find<AppSettingsService>();
    if (!AppPerformance.usePlayerOsdBackdropBlur(settings)) {
      return capsule;
    }
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: capsule,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'player.skip_intro'.tr,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: _buildSkipIntroCapsule(primary),
          ),
        ),
      ),
    );
  }
}

class _PlayerPortraitSurfaceShell extends StatelessWidget {
  const _PlayerPortraitSurfaceShell({
    required this.controller,
    required this.playerWidget,
    required this.onBrightnessDragStart,
    required this.onVolumeDragStart,
    required this.onVerticalDragUpdate,
  });

  final PlayerController controller;
  final Widget playerWidget;
  final void Function(DragStartDetails) onBrightnessDragStart;
  final void Function(DragStartDetails) onVolumeDragStart;
  final void Function(DragUpdateDetails) onVerticalDragUpdate;

  @override
  Widget build(BuildContext context) {
    // `top: true` → video ve panel telefonun durum çubuğunun **altına**
    // konumlansın (saat / pil çubuğunu kapatmasın). `bottom: false` →
    // gestür çubuğu boşluğunu Column kendisi yönetiyor.
    return SafeArea(
      top: true,
      bottom: false,
      left: false,
      right: false,
      child: Obx(() {
        // Playlist arka planda yüklenince kategori/kanal listesi anında güncellensin.
        if (Get.isRegistered<PlaylistCacheService>()) {
          Get.find<PlaylistCacheService>().result.value;
        }
        // Reactive: kanal değişiminde Obx rebuild olsun.
        controller.channel.value;
        // Live TV paneli yalnızca **movie/series** modundayken gizlensin.
        // `channel.streamUrl` boot sırasında geç set edilebildiği için
        // controller'ın resmi `isMovie/isSeries` flag'lerine güvenelim;
        // aksi halde 4-5 saniye boyunca panel yer kaplamaz ve kullanıcı
        // boş gri zemin görür.
        final isLive = !controller.isMovie && !controller.isSeries;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video — ekranın en üstünde, 16:9 oranlı.
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    playerWidget,
                    if (Platform.isIOS)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              Get.back();
                            },
                          ),
                        ),
                      ),
                    // Tap-to-show OSD katmanı her zaman aktif olsun;
                    // OSD paneli artık daima görünür ama kullanıcı video
                    // alanına tıklayarak auto-hide süresini yeniler.
                    Positioned.fill(
                      child: _PortraitVideoTapToShowOsd(
                        controller: controller,
                      ),
                    ),
                    // Dikey modda tap katmanı tam ekranı kapladığı için ses /
                    // parlaklık şeritleri videonun üstünde tekrar eklenir.
                    _PlaybackVolumeBrightnessEdgeGestures(
                      onBrightnessDragStart: onBrightnessDragStart,
                      onVolumeDragStart: onVolumeDragStart,
                      onVerticalDragUpdate: onVerticalDragUpdate,
                    ),
                  ],
                ),
              ),
            ),
            // Video ile OSD arasına boşluk.
            const SizedBox(height: 12),
            // OSD paneli — dikey modda **daima** görünür. Yatay tam ekran
            // OSD'sinden farklı olarak burada panel video alanını
            // kaplamadığı için auto-hide gerekli değil; kullanıcı kanal
            // adı / play-pause / favori butonlarına sürekli erişmeli.
            _PortraitOsdPanel(controller: controller),
            // OSD altındaki ikincil panel:
            //  • Canlı TV → Kategoriler / Kanallar / EPG sekmeleri
            //  • Film     → Kategoriler / Filmler sekmeleri
            //  • Dizi     → Dizi (özet/IMDb/oyuncular) / Bölümler sekmeleri
            if (isLive) ...[
              const SizedBox(height: 12),
              Expanded(
                child: _PortraitLiveTvPanel(controller: controller),
              ),
            ] else if (controller.isSeries) ...[
              const SizedBox(height: 12),
              Expanded(
                child: _PortraitSeriesPanel(controller: controller),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Expanded(
                child: _PortraitVodPanel(
                  controller: controller,
                  isSeriesMode: false,
                ),
              ),
            ],
          ],
        );
      }),
    );
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
          : controller.liveStripCategoryIndex.value
              .clamp(0, chipNames.length - 1);
      return LiveChannelStripOverlay(
        key: channelStripKey,
        channels: List<Channel>.from(channels),
        currentChannelId: controller.channel.value.id,
        onClose: () => onClose(true),
        onBackToOsd: onBackToOsd,
        categoryShortcutEnabled: catTabs,
        onCategoryPrevious:
            catTabs ? () => controller.shiftLiveStripCategory(-1) : null,
        onCategoryNext:
            catTabs ? () => controller.shiftLiveStripCategory(1) : null,
        categoryChipLabels: chipNames.isNotEmpty ? chipNames : null,
        selectedCategoryChipIndex: chipIdx,
        onPick: (ch) async {
          // Seçim sonrası şeridi HEMEN kapatma; kullanıcı işlem yapmazsa
          // 3 sn sonra otomatik kapanır (etkileşimde süre sıfırlanır).
          controller.scheduleLiveStripAutoClose();
          await controller.zapTo(ch);
          controller.scheduleLiveStripAutoClose();
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
      // Dikey modda EPG, alttaki panel sekmesiyle açılır; tam ekran overlay
      // video yüzeyini gri perdeye çevirir.
      if (controller.isPortraitPlaybackUi) {
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
          : controller.vodBrowseRailCategoryIndex.value
              .clamp(0, chipNames.length - 1);
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
          onCategoryPrevious:
              catTabs ? () => controller.shiftVodBrowseRailCategory(-1) : null,
          onCategoryNext:
              catTabs ? () => controller.shiftVodBrowseRailCategory(1) : null,
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
          onCategoryPrevious:
              catTabs ? () => controller.shiftVodBrowseRailCategory(-1) : null,
          onCategoryNext:
              catTabs ? () => controller.shiftVodBrowseRailCategory(1) : null,
          categoryChipLabels: chipNames.isNotEmpty ? chipNames : null,
          selectedCategoryChipIndex: chipIdx,
        );
      }
      return const SizedBox.shrink();
    });
  }
}

class _PortraitOsdPanelState extends State<_PortraitOsdPanel> {
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

          final bp = widget.controller.better;
          final settings = Get.find<AppSettingsService>();
          settings.useMediaKit.value;
          settings.liveUseMediaKit.value;
          widget.controller.mediaKitFallbackSession.value;
          widget.controller.betterOsdOverride.value;
          final activeEngine = widget.controller.activeVideoEngine;
          final useEmbeddedEngineOsd = activeEngine.isMediaKit;
          if (useEmbeddedEngineOsd) {
            widget.controller.mediaKitAttachEpoch.value;
          }

          final double screenWidth = Get.width;
          double osdScale = 1.0;
          final osdTier = settings.osdSizeTier.value;
          if (osdTier == 0) {
            osdScale = 0.85;
          } else if (osdTier == 2) {
            osdScale = 1.25;
          } else if (osdTier == 3) {
            osdScale = 1.45;
          } else {
            if (useTvOsdStyle) {
              if (screenWidth > 900) {
                osdScale = 1.35;
              } else if (screenWidth > 600) {
                osdScale = 1.15;
              }
            }
          }

          // Dikey modda yayın açılmasa bile OSD paneli görünür kalsın.
          // Böylece kullanıcı "akış açılıyor" durumunda paneli kaybetmez.
          // Dikey mod: OSD cam şeridine maksimum genişlik (yatay tam ekran OSD’ye dokunulmaz).
          Widget osdContent = Listener(
            behavior: HitTestBehavior.deferToChild,
            onPointerDown: (_) => widget.controller.scheduleTvOsdAutoHide(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                // İç içe Obx kullanılmaz — Rx okumadan Obx GetX'te
                // "improper Obx" fırlatır ve alttaki panel/OSD çizilmez
                // (beyaz/gri perde). Tüm reactive okumalar üst Obx'te.
                child: ColoredBox(
                  color: const Color(0xCC0B0F14),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xE60B0F14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
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
                                        color: Colors.black
                                            .withValues(alpha: 0.45),
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
                                return <Widget>[
                                  const SizedBox(width: 8),
                                  ...() {
                                    final transport = widget
                                        .controller.osdStreamTransportFormatLabel;
                                    if (transport == null || transport.isEmpty) {
                                      return <Widget>[];
                                    }
                                    return <Widget>[
                                      osdTransportBadge(
                                        transportFormat: transport,
                                        fontSize: 11,
                                        radius: 8,
                                        hPad: 8,
                                        vPad: 4,
                                        portrait: true,
                                      ),
                                      const SizedBox(width: 6),
                                    ];
                                  }(),
                                  osdEngineBadge(
                                    engine: widget.controller.activeVideoEngine,
                                    fontSize: 11,
                                    radius: 8,
                                    hPad: 8,
                                    vPad: 4,
                                    portrait: true,
                                  ),
                                  if (badges.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: badges,
                                    ),
                                  ],
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
                                    !widget.controller
                                        .liveTimeshiftSeekAvailable) {
                                  return const SizedBox.shrink();
                                }
                                return _VideoProgressBar(
                                  bp: bp,
                                  value: value,
                                  onScrub: (s) => s
                                      ? widget.controller.beginVodScrub()
                                      : widget.controller.endVodScrub(),
                                );
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
                                  _buildPortraitFavToggle(tv: useTvOsdStyle),
                                  _osdAction(
                                    icon: Icons.high_quality_rounded,
                                    onTap: () =>
                                        unawaited(_showQualityMenu(context)),
                                    tv: useTvOsdStyle,
                                  ),
                                  _osdAction(
                                    icon: Icons.cast_rounded,
                                    onTap: () => unawaited(showPlayerCastSheet(
                                      context,
                                      controller: widget.controller,
                                    )),
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
                                      onTap: () => unawaited(
                                          _showVodSubtitleMenu(context)),
                                      tv: useTvOsdStyle,
                                    ),
                                    Obx(() {
                                      final rate =
                                          widget.controller.playbackRate.value;
                                      final isNormal =
                                          (rate - 1.0).abs() < 0.001;
                                      return _osdAction(
                                        icon: isNormal
                                            ? Icons.speed_rounded
                                            : null,
                                        letter: isNormal
                                            ? null
                                            : '${_portraitFmtRate(rate)}x',
                                        onTap: () => widget.controller
                                            .cyclePlaybackRate(),
                                        tv: useTvOsdStyle,
                                      );
                                    }),
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
                                      Get.find<AppSettingsService>()
                                          .liveUseMediaKit
                                          .value;
                                      if (widget.controller
                                              .effectiveUseMediaKit ||
                                          Get.find<AppSettingsService>()
                                                  .layoutMode
                                                  .value ==
                                              AppLayoutMode.tv) {
                                        return const SizedBox.shrink();
                                      }
                                      return _osdAction(
                                        icon: Icons
                                            .picture_in_picture_alt_rounded,
                                        onTap: () => unawaited(widget.controller
                                            .enterPictureInPictureIfSupported()),
                                        tv: useTvOsdStyle,
                                      );
                                    }),
                                  _engineToggleAction(tv: useTvOsdStyle),
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
                              );
                            },
                          )
                        else if (!useEmbeddedEngineOsd)
                          _osdControlRow(
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
                                icon: Icons.play_arrow_rounded,
                                onTap: () => widget.controller.play(),
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
                              if (quickMenuBadge)
                                Tooltip(
                                  message: 'player.tooltip.quickMenuOpen'.tr,
                                  child: _osdAction(
                                    icon: Icons.view_sidebar_rounded,
                                    onTap: _openQuickMenuFromPortraitOsd,
                                    tv: useTvOsdStyle,
                                  ),
                                ),
                              _buildPortraitFavToggle(tv: useTvOsdStyle),
                              _osdAction(
                                icon: Icons.high_quality_rounded,
                                onTap: () =>
                                    unawaited(_showQualityMenu(context)),
                                tv: useTvOsdStyle,
                              ),
                              _osdAction(
                                icon: Icons.cast_rounded,
                                onTap: () => unawaited(showPlayerCastSheet(
                                  context,
                                  controller: widget.controller,
                                )),
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
                                      unawaited(_showVodSubtitleMenu(context)),
                                  tv: useTvOsdStyle,
                                ),
                                Obx(() {
                                  final rate =
                                      widget.controller.playbackRate.value;
                                  final isNormal = (rate - 1.0).abs() < 0.001;
                                  return _osdAction(
                                    icon: isNormal ? Icons.speed_rounded : null,
                                    letter: isNormal
                                        ? null
                                        : '${_portraitFmtRate(rate)}x',
                                    onTap: () =>
                                        widget.controller.cyclePlaybackRate(),
                                    tv: useTvOsdStyle,
                                  );
                                }),
                              ],
                              if (Platform.isAndroid || Platform.isIOS)
                                Obx(() {
                                  Get.find<AppSettingsService>()
                                      .layoutMode
                                      .value;
                                  widget
                                      .controller.mediaKitFallbackSession.value;
                                  Get.find<AppSettingsService>()
                                      .useMediaKit
                                      .value;
                                  Get.find<AppSettingsService>()
                                      .liveUseMediaKit
                                      .value;
                                  if (widget.controller.effectiveUseMediaKit ||
                                      Get.find<AppSettingsService>()
                                              .layoutMode
                                              .value ==
                                          AppLayoutMode.tv) {
                                    return const SizedBox.shrink();
                                  }
                                  return _osdAction(
                                    icon: Icons.picture_in_picture_alt_rounded,
                                    onTap: () => unawaited(
                                      widget.controller
                                          .enterPictureInPictureIfSupported(),
                                    ),
                                    tv: useTvOsdStyle,
                                  );
                                }),
                              _engineToggleAction(tv: useTvOsdStyle),
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
                          )
                        else if (useEmbeddedEngineOsd)
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
                                      onScrub: (s) => s
                                          ? widget.controller.beginVodScrub()
                                          : widget.controller.endVodScrub(),
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
                                      if (quickMenuBadge)
                                        Tooltip(
                                          message:
                                              'player.tooltip.quickMenuOpen'.tr,
                                          child: _osdAction(
                                            icon: Icons.view_sidebar_rounded,
                                            onTap:
                                                _openQuickMenuFromPortraitOsd,
                                            tv: useTvOsdStyle,
                                          ),
                                        ),
                                      _buildPortraitFavToggle(
                                          tv: useTvOsdStyle),
                                      _osdAction(
                                        icon: Icons.high_quality_rounded,
                                        onTap: () =>
                                            _showMkQualityMenu(context),
                                        tv: useTvOsdStyle,
                                      ),
                                      _osdAction(
                                        icon: Icons.cast_rounded,
                                        onTap: () => unawaited(
                                          showPlayerCastSheet(
                                            context,
                                            controller: widget.controller,
                                          ),
                                        ),
                                        tv: useTvOsdStyle,
                                      ),
                                      _osdAction(
                                        icon: Icons.audiotrack_rounded,
                                        onTap: () => _showMkAudioMenu(context),
                                        tv: useTvOsdStyle,
                                      ),
                                      if (!isLive)
                                        _osdAction(
                                          icon: Icons.closed_caption_rounded,
                                          onTap: () => unawaited(
                                            _showVodSubtitleMenu(context),
                                          ),
                                          tv: useTvOsdStyle,
                                        ),
                                      if (!isLive)
                                        Obx(() {
                                          final rate = widget
                                              .controller.playbackRate.value;
                                          final isNormal =
                                              (rate - 1.0).abs() < 0.001;
                                          return _osdAction(
                                            icon: isNormal
                                                ? Icons.speed_rounded
                                                : null,
                                            letter: isNormal
                                                ? null
                                                : '${_portraitFmtRate(rate)}x',
                                            onTap: () => widget.controller
                                                .cyclePlaybackRate(),
                                            tv: useTvOsdStyle,
                                          );
                                        }),
                                      _engineToggleAction(tv: useTvOsdStyle),
                                      Obx(() {
                                        final s =
                                            Get.find<AppSettingsService>();
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
                  ),
                ),
              ),
            ),
          );

          return Transform.scale(
            scale: osdScale,
            alignment: Alignment.bottomCenter,
            child: osdContent,
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
      await _showQualityUnavailableSheet(context);
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
      await _showInfoSheet(
        context,
        title: 'player.sheet.audioTitle'.tr,
        body: 'player.audio.noneLong'.tr,
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

  Future<void> _showVodSubtitleMenu(BuildContext context) async {
    final c = widget.controller;
    c.cancelTvOsdAutoHide();
    GlassSnackbar.show(
      'player.sheet.subtitleTitle'.tr,
      'common.loading'.tr,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
    final discovered = await c.discoverVodSubtitleOptions();
    if (!context.mounted) return;
    c.scheduleTvOsdAutoHide();

    final mediaKitOnly = c.effectiveUseMediaKit &&
        !discovered.hasBetterTracks &&
        discovered.exoTextTracks.isEmpty;

    if (!discovered.hasSelectableTracks) {
      // Better/Exo'da gömülü altyazı izi var ama resim tabanlı (PGS/VobSub) →
      // Exo çizemiyor. mpv (MediaKit) bunları render eder: geçiş öner.
      if (!c.effectiveUseMediaKit && discovered.exoHasUnsupportedText) {
        await _offerSwitchToMediaKitForSubtitles(context);
        return;
      }
      if (mediaKitOnly) {
        GlassSnackbar.show(
          'player.warn.title'.tr,
          'player.subtitle.noneShort'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        await _showInfoSheet(
          context,
          title: 'player.sheet.subtitleTitle'.tr,
          body: 'player.subtitle.noneLong'.tr,
        );
      }
      return;
    }

    if (mediaKitOnly) {
      _showMkSubtitleSheet(context, discovered.mediaKitTracks);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _UnifiedSubtitleSheet(
        controller: c,
        sources: discovered.betterSources,
        exoTextTracks: discovered.exoTextTracks,
      ),
    );
  }

  void _showMkSubtitleSheet(
    BuildContext context,
    Map<String, String> tracks,
  ) {
    final list = tracks.entries.toList()
      ..sort((a, b) {
        if (a.key == 'no') return -1;
        if (b.key == 'no') return 1;
        return a.value.toLowerCase().compareTo(b.value.toLowerCase());
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

  Future<void> _showQualityMenu(BuildContext context) async {
    final tracks = widget.controller.availableTracks;
    if (tracks.isEmpty) {
      await _showQualityUnavailableSheet(context);
      return;
    }

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _QualitySelectionSheet(
        controller: widget.controller,
        tracks: tracks,
      ),
    );
  }

  Future<void> _showQualityUnavailableSheet(BuildContext context) async {
    await _showInfoSheet(
      context,
      title: 'player.sheet.qualityTitle'.tr,
      body: 'player.quality.noneLong'.tr,
    );
  }

  /// Better/Exo gömülü altyazıyı (resim tabanlı PGS/VobSub) çizemediğinde:
  /// kullanıcıya MediaKit (mpv/libass) oynatıcısına geçişi öner. Onaylarsa
  /// motoru bu yayın için değiştirip altyazı listesini MediaKit'ten tekrar açar.
  Future<void> _offerSwitchToMediaKitForSubtitles(BuildContext context) async {
    if (!context.mounted) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => GlassPopupPanel(
        borderRadius: 20,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'player.subtitle.imageBasedTitle'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'player.subtitle.imageBasedBody'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GlassDialogActionButton(
                  label: 'common.cancel'.tr,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                const SizedBox(width: 10),
                GlassDialogActionButton(
                  label: 'player.subtitle.switchToMediaKit'.tr,
                  primary: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final c = widget.controller;
    GlassSnackbar.show(
      'player.engine.title'.tr,
      'player.subtitle.switchingForSubs'.tr,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
    await c.switchToBackupPlayer();
    // mpv yeniden açılıp altyazı izlerini listeleyene kadar kısa bekle.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!context.mounted) return;
    final again = await c.discoverVodSubtitleOptions();
    if (!context.mounted) return;
    if (again.hasMediaKitTracks) {
      _showMkSubtitleSheet(context, again.mediaKitTracks);
    } else {
      GlassSnackbar.show(
        'player.warn.title'.tr,
        'player.subtitle.noneShort'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _showInfoSheet(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => GlassPopupPanel(
        borderRadius: 20,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
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

  /// OSD: oynatma motorunu (Better/Exo ↔ MediaKit/mpv) **yalnızca bu yayın
  /// için** değiştiren buton. Mobil (Android/iOS) için; TV'de gizli.
  /// Geçiş kalıcı ayarı değiştirmez — kanal/içerik değişince varsayılana döner.
  Widget _engineToggleAction({required bool tv}) {
    return const SizedBox.shrink();
  }

  Future<void> _togglePlaybackEngine(bool currentlyMediaKit) async {
    widget.controller.scheduleTvOsdAutoHide();
    if (currentlyMediaKit) {
      await widget.controller.switchToBetterPlayer();
    } else {
      await widget.controller.switchToBackupPlayer();
    }
    final nowMk = widget.controller.effectiveUseMediaKit;
    GlassSnackbar.show(
      'player.engine.title'.tr,
      nowMk
          ? 'player.engine.switchedMediaKit'.tr
          : 'player.engine.switchedExo'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
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
          physics: AppScrollPhysics.list(),
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

  /// OSD kontrol satırına eklenen kalp ikonu — basılınca o an oynayan içerik
  /// (canlı kanal / film / dizi) favorilere eklenir/çıkarılır. Favori durumu
  /// `FavoritesService` Rx listeleri üzerinden izlenir.
  Widget _buildPortraitFavToggle({required bool tv}) {
    return Obx(() {
      final c = widget.controller;
      // Rx listelerine bağlan (kanal/film/dizi) ki durum değişince yenilensin.
      final favs = Get.find<FavoritesService>();
      favs.channelIds.length;
      favs.vodIds.length;
      favs.seriesIds.length;
      c.channel.value;
      final isFav = c.isCurrentMediaFavorite;
      return Tooltip(
        message: isFav ? 'player.tooltip.favOn'.tr : 'player.tooltip.favOff'.tr,
        child: _osdAction(
          icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          onTap: () {
            c.toggleCurrentMediaFavorite();
            c.scheduleTvOsdAutoHide();
          },
          tv: tv,
        ),
      );
    });
  }
}

/// Portrait OSD hız etiketi için: `1.0 → 1`, `2.0 → 2`, `1.5 → 1.5`.
/// `_PortraitOsdPanelState` içindeki üç OSD branch'i (Better/bp, Better/no-bp,
/// MediaKit) ortak kullanır.
String _portraitFmtRate(double rate) {
  if ((rate - rate.roundToDouble()).abs() < 0.001) {
    return rate.toStringAsFixed(0);
  }
  return rate.toStringAsFixed(1);
}

/// Dikey mod (telefon/tablet) canlı tv tarayıcısı: video ve OSD'nin altına
/// yerleşen, kalan dikey alanı dolduran cam panel. Üç sekmeli yapı:
///
/// 1. **Kategoriler** — `liveChannelStripCategoryTapes()` üzerinden canlı
///    kanalları olan tüm kategoriler + kanal sayısı.
/// 2. **Kanallar** — seçilen kategorinin canlı kanalları; tıklayınca `zapTo`.
/// 3. **EPG** — o an açılan kanal için gün boyu program listesi;
///    `EpgService.getFullDayProgrammesForLiveChannel`. Şu an yayında olan
///    program "DEVAM EDİYOR" rozetiyle vurgulanır.
///
/// Tasarım: glass tema (popup gradient + border + gölge) — `GlassAppearance`
/// üzerinden tema rengini takip eder. Sekme altı çubuk seçili tab için
/// `colorScheme.primary` rengindedir.
// ============================================================================
// VOD / Series — Dikey panel (OSD altı)
// ============================================================================

/// Sentinel kategori anahtarları — film/dizi panelinde "Tümü" ve
/// "Son İzlenenler" sanal satırları için negatif ID'ler. Geçerli VOD/series
/// kategorileri pozitif ID kullandığı için çakışma riski yok.
const int _kVodPanelAllCategoryId = -100001;
const int _kVodPanelRecentlyWatchedCategoryId = -100002;

// ============================================================================
// Series — Dikey panel (OSD altı) — Dizi izlerken
// ============================================================================
//
// İki sekmeli yapı:
//  1. **Dizi** — başlık, poster, IMDb puanı, yıl/tür/süre, özet, oyuncular.
//     Veri OmdbService.getMovieInfo(isSeries: true) ile arka planda yüklenir;
//     PlayerController.seriesPanelData (RxN<SeriesPlayerPanelData>) dinlenir.
//  2. **Bölümler** — _episodeBrowseTape üzerinden sezon-bölüm sıralı liste.
//     Şu an oynayan bölüm "OYNATILIYOR" rozetiyle vurgulanır; satıra dokununca
//     `controller.zapTo(opt.channel)` ile aynı oturumda bölüm değiştirilir.
//
// EPG sekmesi *yok*: Bu panel canlı TV ile karıştırılmasın diye yapım gereği
// yalnızca "Dizi" + "Bölümler" sekmelerini barındırır.

enum _PortraitSeriesTab { info, episodes }

class _PortraitSeriesPanel extends StatefulWidget {
  const _PortraitSeriesPanel({required this.controller});

  final PlayerController controller;

  @override
  State<_PortraitSeriesPanel> createState() => _PortraitSeriesPanelState();
}

class _PortraitSeriesPanelState extends State<_PortraitSeriesPanel> {
  _PortraitSeriesTab _tab = _PortraitSeriesTab.info;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE60B0F14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          child: Column(
            children: [
              _buildTabBar(context),
              const Divider(
                height: 1,
                thickness: 0.6,
                color: Color(0x22FFFFFF),
              ),
              Expanded(child: _buildTabBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tabs = <(_PortraitSeriesTab, String)>[
      (_PortraitSeriesTab.info, 'portraitSeriesPanel.tab.info'.tr),
      (_PortraitSeriesTab.episodes, 'portraitSeriesPanel.tab.episodes'.tr),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: _TabButton(
                label: t.$2,
                active: _tab == t.$1,
                primary: primary,
                onTap: () => setState(() => _tab = t.$1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBody(BuildContext context) {
    switch (_tab) {
      case _PortraitSeriesTab.info:
        return _buildInfoTab(context);
      case _PortraitSeriesTab.episodes:
        return _buildEpisodesTab(context);
    }
  }

  // --------------------------------- Dizi ---------------------------------

  Widget _buildInfoTab(BuildContext context) {
    return Obx(() {
      final data = widget.controller.seriesPanelData.value;
      if (data == null) {
        return _EmptyState(
          icon: Icons.local_movies_outlined,
          message: 'portraitSeriesPanel.loading'.tr,
        );
      }

      final actors = data.actors;
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        children: [
          _buildHero(context, data),
          if (data.plot != null && data.plot!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle('portraitSeriesPanel.synopsis'.tr),
            const SizedBox(height: 6),
            Text(
              data.plot!.trim(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
          if (data.director != null && data.director!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _MetaLine(
              label: 'portraitSeriesPanel.director'.tr,
              value: data.director!.trim(),
            ),
          ],
          if (actors.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle('portraitSeriesPanel.cast'.tr),
            const SizedBox(height: 8),
            _CastRow(actors: actors),
          ],
          if (!data.hasAnyDetail) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'portraitSeriesPanel.empty.info'.tr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildHero(BuildContext context, SeriesPlayerPanelData data) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final posterUrl = data.posterUrl;
    final posterPx = (90 * dpr).round().clamp(120, 480);

    final chips = <Widget>[];
    final imdb = data.imdbRating;
    if (imdb != null && imdb.trim().isNotEmpty) {
      chips.add(_InfoChip(
        icon: Icons.star_rounded,
        label: 'IMDb ${imdb.trim()}',
        emphasize: true,
      ));
    }
    final year = data.year;
    if (year != null && year.trim().isNotEmpty) {
      chips.add(_InfoChip(
        icon: Icons.calendar_today_rounded,
        label: year.trim(),
      ));
    }
    final runtime = data.runtime;
    if (runtime != null && runtime.trim().isNotEmpty) {
      chips.add(_InfoChip(
        icon: Icons.schedule_rounded,
        label: runtime.trim(),
      ));
    }
    final genre = data.genre;
    if (genre != null && genre.trim().isNotEmpty) {
      chips.add(_InfoChip(
        icon: Icons.local_offer_outlined,
        label: genre.trim(),
      ));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 90,
            height: 130,
            child: posterUrl != null && posterUrl.trim().isNotEmpty
                ? IptvChannelLogo(
                    imageUrl: posterUrl,
                    width: 90,
                    height: 130,
                    memCacheWidth: posterPx,
                  )
                : Container(
                    color: Colors.white.withValues(alpha: 0.06),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.local_movies_outlined,
                      size: 32,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: 0.1,
                ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: chips,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------- Bölümler -------------------------------

  Widget _buildEpisodesTab(BuildContext context) {
    final tape = widget.controller.seriesEpisodeBrowseTape;
    if (tape.isEmpty) {
      return _EmptyState(
        icon: Icons.list_alt_rounded,
        message: 'portraitSeriesPanel.empty.episodes'.tr,
      );
    }

    return Obx(() {
      // Reactive: bölüm değişince "şu an oynayan" rozetini yenilensin.
      widget.controller.channel.value;
      final current = widget.controller.currentSeriesEpisodeOption;
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: tape.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (ctx, i) {
          final opt = tape[i];
          final isPlaying = current != null &&
              opt.channel.id == current.channel.id &&
              opt.season == current.season &&
              opt.episodeNumber == current.episodeNumber;
          return _SeriesEpisodeRow(
            option: opt,
            isPlaying: isPlaying,
            onTap: () {
              if (isPlaying) return;
              widget.controller.zapTo(opt.channel);
            },
          );
        },
      );
    });
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6),
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${label.toUpperCase()}: ',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = emphasize
        ? primary.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.08);
    final fg = emphasize ? primary : Colors.white.withValues(alpha: 0.85);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: emphasize
              ? primary.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CastRow extends StatelessWidget {
  const _CastRow({required this.actors});
  final List<SeriesPlayerCastMember> actors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final a = actors[i];
          return SizedBox(
            width: 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(a.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  a.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    final first = parts.first.characters.first;
    final last = parts.last.characters.first;
    return '$first$last'.toUpperCase();
  }
}

class _SeriesEpisodeRow extends StatelessWidget {
  const _SeriesEpisodeRow({
    required this.option,
    required this.isPlaying,
    required this.onTap,
  });

  final SeriesEpisodeOption option;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = isPlaying
        ? primary.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.04);
    final border = isPlaying
        ? primary.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.08);
    final epLabel = 'portraitSeriesPanel.episodeLabel'.trParams({
      's': option.season.toString().padLeft(2, '0'),
      'e': option.episodeNumber.toString().padLeft(2, '0'),
    });
    final dur = option.durationSecs;
    final durLabel = (dur != null && dur > 0) ? _formatDuration(dur) : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? primary.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  epLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isPlaying ? primary : Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isPlaying ? primary : Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isPlaying) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'portraitSeriesPanel.nowPlaying'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (durLabel != null ||
                        (option.plot != null &&
                            option.plot!.trim().isNotEmpty)) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (durLabel != null) ...[
                            Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              durLabel,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (option.plot != null &&
                                option.plot!.trim().isNotEmpty)
                              Text(
                                '  ·  ',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                          if (option.plot != null &&
                              option.plot!.trim().isNotEmpty)
                            Expanded(
                              child: Text(
                                option.plot!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int secs) {
    if (secs <= 0) return '';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }
}

/// Dikey moddaki film / dizi izleyicisinde OSD'nin altına yerleşen panel.
/// Canlı TV'deki [_PortraitLiveTvPanel]'in muadili.
///
/// İki sekmeli yapı:
///  1. **Kategoriler** — "Tümü", varsa "Son İzlenenler" ve aktif kütüphanedeki
///     gerçek film/dizi kategorileri. İçerik adedini gösterir.
///  2. **Filmler / Diziler** — seçili kategorinin tam liste görünümü;
///     tıklanan öğe doğrudan oynatıcıda açılır
///     ([PlayerController.pickVodBrowseRailMovie]
///     veya [PlayerController.pickVodBrowseRailSeries]).
class _PortraitVodPanel extends StatefulWidget {
  const _PortraitVodPanel({
    required this.controller,
    required this.isSeriesMode,
  });

  final PlayerController controller;
  final bool isSeriesMode;

  @override
  State<_PortraitVodPanel> createState() => _PortraitVodPanelState();
}

enum _PortraitVodTab { categories, items }

class _PortraitVodPanelState extends State<_PortraitVodPanel> {
  _PortraitVodTab _tab = _PortraitVodTab.items;
  int? _selectedCategoryId;
  Worker? _channelWorker;
  Worker? _playlistWorker;
  Worker? _historyWorker;

  bool _loadingCategories = true;
  bool _loadingItems = true;
  int _allCount = 0;
  int _recentCount = 0;
  List<({int id, String name, int count})> _realCats = const [];
  List<VodItem> _filmItems = const [];
  List<SeriesItem> _seriesItems = const [];
  int _categoriesGen = 0;
  int _itemsGen = 0;

  @override
  void initState() {
    super.initState();
    _syncCategoryWithCurrent();
    unawaited(_reloadCategories());
    unawaited(_reloadItems());
    // Aktif içerik değişince kategori seçimini hizala — kullanıcı manuel
    // "Tümü" / "Son İzlenenler" seçtiğinde tercihi koru.
    _channelWorker = ever(widget.controller.channel, (_) {
      _syncCategoryWithCurrent();
    });
    if (Get.isRegistered<PlaylistCacheService>()) {
      _playlistWorker = ever(
        Get.find<PlaylistCacheService>().result,
        (_) {
          unawaited(_reloadCategories());
          unawaited(_reloadItems());
        },
      );
    }
    if (Get.isRegistered<UserHistoryService>()) {
      _historyWorker = ever(
        Get.find<UserHistoryService>().revision,
        (_) {
          unawaited(_reloadCategories());
          if (_selectedCategoryId == _kVodPanelRecentlyWatchedCategoryId) {
            unawaited(_reloadItems());
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _channelWorker?.dispose();
    _playlistWorker?.dispose();
    _historyWorker?.dispose();
    super.dispose();
  }

  void _syncCategoryWithCurrent() {
    if (!mounted) return;
    if (_selectedCategoryId == _kVodPanelAllCategoryId) return;
    if (_selectedCategoryId == _kVodPanelRecentlyWatchedCategoryId) return;
    if (widget.isSeriesMode) {
      final ser = widget.controller.playingSeries;
      if (ser != null && _selectedCategoryId != ser.categoryId) {
        setState(() => _selectedCategoryId = ser.categoryId);
      }
    } else {
      final cur = widget.controller.channel.value;
      if (_selectedCategoryId != cur.categoryId) {
        setState(() => _selectedCategoryId = cur.categoryId);
      }
    }
  }

  M3uResult? _data() {
    if (!Get.isRegistered<PlaylistCacheService>()) return null;
    return Get.find<PlaylistCacheService>().result.value;
  }

  bool _isDbSlim(M3uResult d) {
    if (!Get.isRegistered<PlaylistDataSource>()) return false;
    final ds = Get.find<PlaylistDataSource>();
    if (!ds.isDbBacked) return false;
    return widget.isSeriesMode ? d.series.isEmpty : d.vod.isEmpty;
  }

  Future<void> _reloadCategories() async {
    final gen = ++_categoriesGen;
    final d = _data();
    if (d == null) {
      if (!mounted || gen != _categoriesGen) return;
      setState(() {
        _loadingCategories = false;
        _allCount = 0;
        _recentCount = 0;
        _realCats = const [];
      });
      return;
    }

    if (!_isDbSlim(d)) {
      final allCount = widget.isSeriesMode ? d.series.length : d.vod.length;
      final recentCount = widget.isSeriesMode
          ? _recentlyWatchedSeries(d).length
          : _recentlyWatchedMovies(d).length;
      final realCats = widget.isSeriesMode
          ? _seriesCategoryRowsMem(d)
          : _filmCategoryRowsMem(d);
      if (!mounted || gen != _categoriesGen) return;
      setState(() {
        _loadingCategories = false;
        _allCount = allCount;
        _recentCount = recentCount;
        _realCats = realCats;
      });
      return;
    }

    final ds = Get.find<PlaylistDataSource>();
    if (widget.isSeriesMode) {
      final allCount = await ds.seriesCount();
      final counts = await ds.seriesCountsByCategory();
      final recentCount = (await _recentlyWatchedSeriesDb(ds)).length;
      final realCats = <({int id, String name, int count})>[];
      for (final c in d.seriesCategories) {
        final n = counts[c.id] ?? 0;
        if (n > 0) realCats.add((id: c.id, name: c.name, count: n));
      }
      if (!mounted || gen != _categoriesGen) return;
      setState(() {
        _loadingCategories = false;
        _allCount = allCount;
        _recentCount = recentCount;
        _realCats = realCats;
      });
    } else {
      final allCount = await ds.vodCount();
      final counts = await ds.vodCountsByCategory();
      final recentCount = (await _recentlyWatchedMoviesDb(ds)).length;
      final realCats = <({int id, String name, int count})>[];
      for (final c in d.vodCategories) {
        final n = counts[c.id] ?? 0;
        if (n > 0) realCats.add((id: c.id, name: c.name, count: n));
      }
      if (!mounted || gen != _categoriesGen) return;
      setState(() {
        _loadingCategories = false;
        _allCount = allCount;
        _recentCount = recentCount;
        _realCats = realCats;
      });
    }
  }

  Future<void> _reloadItems() async {
    final gen = ++_itemsGen;
    if (mounted) setState(() => _loadingItems = true);
    final d = _data();
    if (d == null) {
      if (!mounted || gen != _itemsGen) return;
      setState(() {
        _loadingItems = false;
        _filmItems = const [];
        _seriesItems = const [];
      });
      return;
    }

    final selectedId = _selectedCategoryId;
    if (!_isDbSlim(d)) {
      if (widget.isSeriesMode) {
        final list = _resolveSeriesListMem(d, selectedId);
        if (!mounted || gen != _itemsGen) return;
        setState(() {
          _loadingItems = false;
          _seriesItems = list;
        });
      } else {
        final list = _resolveMovieListMem(d, selectedId);
        if (!mounted || gen != _itemsGen) return;
        setState(() {
          _loadingItems = false;
          _filmItems = list;
        });
      }
      return;
    }

    final ds = Get.find<PlaylistDataSource>();
    if (widget.isSeriesMode) {
      final list = await _resolveSeriesListDb(ds, d, selectedId);
      if (!mounted || gen != _itemsGen) return;
      setState(() {
        _loadingItems = false;
        _seriesItems = list;
      });
    } else {
      final list = await _resolveMovieListDb(ds, d, selectedId);
      if (!mounted || gen != _itemsGen) return;
      setState(() {
        _loadingItems = false;
        _filmItems = list;
      });
    }
  }

  List<({int id, String name, int count})> _filmCategoryRowsMem(M3uResult d) {
    final byCat = _moviesByCategory(d);
    return [
      for (final c in d.vodCategories)
        if ((byCat[c.id] ?? const <VodItem>[]).isNotEmpty)
          (
            id: c.id,
            name: c.name,
            count: (byCat[c.id] ?? const <VodItem>[]).length,
          ),
    ];
  }

  List<({int id, String name, int count})> _seriesCategoryRowsMem(M3uResult d) {
    final byCat = _seriesByCategory(d);
    return [
      for (final c in d.seriesCategories)
        if ((byCat[c.id] ?? const <SeriesItem>[]).isNotEmpty)
          (
            id: c.id,
            name: c.name,
            count: (byCat[c.id] ?? const <SeriesItem>[]).length,
          ),
    ];
  }

  Future<List<VodItem>> _recentlyWatchedMoviesDb(PlaylistDataSource ds) async {
    final ids = _watchedIdsOrdered();
    if (ids.isEmpty) return const <VodItem>[];
    final out = <VodItem>[];
    for (final id in ids) {
      final v = await ds.vodById(id);
      if (v != null) out.add(v);
    }
    return out;
  }

  Future<List<SeriesItem>> _recentlyWatchedSeriesDb(PlaylistDataSource ds) async {
    final ids = _watchedIdsOrdered();
    if (ids.isEmpty) return const <SeriesItem>[];
    final out = <SeriesItem>[];
    for (final id in ids) {
      final s = await ds.seriesById(id);
      if (s != null) out.add(s);
    }
    return out;
  }

  Future<List<VodItem>> _loadAllVodsDb(PlaylistDataSource ds) async {
    final out = <VodItem>[];
    var offset = 0;
    const pageSize = 300;
    while (true) {
      final page = await ds.vodPage(offset: offset, limit: pageSize);
      if (page.isEmpty) break;
      out.addAll(page);
      offset += page.length;
      if (page.length < pageSize) break;
      await Future<void>.delayed(Duration.zero);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Future<List<SeriesItem>> _loadAllSeriesDb(PlaylistDataSource ds) async {
    final out = <SeriesItem>[];
    var offset = 0;
    const pageSize = 300;
    while (true) {
      final page = await ds.seriesPage(offset: offset, limit: pageSize);
      if (page.isEmpty) break;
      out.addAll(page);
      offset += page.length;
      if (page.length < pageSize) break;
      await Future<void>.delayed(Duration.zero);
    }
    out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return out;
  }

  Future<List<VodItem>> _resolveMovieListDb(
    PlaylistDataSource ds,
    M3uResult d,
    int? selectedId,
  ) async {
    if (selectedId == _kVodPanelRecentlyWatchedCategoryId) {
      return _recentlyWatchedMoviesDb(ds);
    }
    if (selectedId == _kVodPanelAllCategoryId || selectedId == null) {
      return _loadAllVodsDb(ds);
    }
    return FilmDiziCatalog.allVodsInCategoryFromDb(d, ds, selectedId);
  }

  Future<List<SeriesItem>> _resolveSeriesListDb(
    PlaylistDataSource ds,
    M3uResult d,
    int? selectedId,
  ) async {
    if (selectedId == _kVodPanelRecentlyWatchedCategoryId) {
      return _recentlyWatchedSeriesDb(ds);
    }
    if (selectedId == _kVodPanelAllCategoryId || selectedId == null) {
      return _loadAllSeriesDb(ds);
    }
    return FilmDiziCatalog.allSeriesInCategoryFromDb(d, ds, selectedId);
  }

  /// Tüm filmler — kategori bazında VodItem listeleri (alfabetik sıralı).
  /// Boş kategoriler atılır.
  Map<int, List<VodItem>> _moviesByCategory(M3uResult d) {
    final out = <int, List<VodItem>>{};
    for (final v in d.vod) {
      out.putIfAbsent(v.categoryId, () => []).add(v);
    }
    for (final list in out.values) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return out;
  }

  /// Tüm diziler — kategori bazında SeriesItem listeleri (alfabetik sıralı).
  Map<int, List<SeriesItem>> _seriesByCategory(M3uResult d) {
    final out = <int, List<SeriesItem>>{};
    for (final s in d.series) {
      out.putIfAbsent(s.categoryId, () => []).add(s);
    }
    for (final list in out.values) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return out;
  }

  /// Kullanıcının izleme geçmişinden bu mod (film veya dizi) için
  /// kronolojik sırayla içerik ID listesi (en yeni → en eski). Aynı içerik
  /// birden fazla kez izlendiyse en yeni kayıt kalır.
  List<int> _watchedIdsOrdered() {
    if (!Get.isRegistered<UserHistoryService>()) return const <int>[];
    final svc = Get.find<UserHistoryService>();
    final entries = svc.snapshotSync()
      ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    final wanted =
        widget.isSeriesMode ? UserHistoryKind.series : UserHistoryKind.vod;
    final seen = <int>{};
    final out = <int>[];
    for (final e in entries) {
      if (e.kind != wanted) continue;
      if (!seen.add(e.contentId)) continue;
      out.add(e.contentId);
    }
    return out;
  }

  List<VodItem> _recentlyWatchedMovies(M3uResult d) {
    final ids = _watchedIdsOrdered();
    if (ids.isEmpty) return const <VodItem>[];
    final byId = <int, VodItem>{
      for (final v in d.vod) v.id: v,
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  List<SeriesItem> _recentlyWatchedSeries(M3uResult d) {
    final ids = _watchedIdsOrdered();
    if (ids.isEmpty) return const <SeriesItem>[];
    final byId = <int, SeriesItem>{
      for (final s in d.series) s.id: s,
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE60B0F14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          child: Column(
            children: [
              _buildTabBar(context),
              const Divider(
                height: 1,
                thickness: 0.6,
                color: Color(0x22FFFFFF),
              ),
              Expanded(child: _buildTabBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final itemsLabel = widget.isSeriesMode
        ? 'portraitVodPanel.tab.series'.tr
        : 'portraitVodPanel.tab.films'.tr;
    final tabs = <(_PortraitVodTab, String)>[
      (_PortraitVodTab.categories, 'channels.tab.categories'.tr),
      (_PortraitVodTab.items, itemsLabel),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: _TabButton(
                label: t.$2,
                active: _tab == t.$1,
                primary: primary,
                onTap: () => setState(() => _tab = t.$1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBody(BuildContext context) {
    switch (_tab) {
      case _PortraitVodTab.categories:
        return _buildCategoriesList(context);
      case _PortraitVodTab.items:
        return _buildItemsList(context);
    }
  }

  // ------------------------------ Kategoriler ------------------------------

  Widget _buildCategoriesList(BuildContext context) {
    return Obx(() {
      // Reactive bağlantılar — playlist veri değişimi + history.
      if (Get.isRegistered<PlaylistCacheService>()) {
        Get.find<PlaylistCacheService>().result.value;
      }
      if (Get.isRegistered<UserHistoryService>()) {
        Get.find<UserHistoryService>().revision.value;
      }
      if (_data() == null) {
        return _EmptyState(
          icon: Icons.category_outlined,
          message: 'portraitPanel.empty.categories'.tr,
        );
      }
      if (_loadingCategories) {
        return const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        );
      }

      final allCount = _allCount;
      final recentCount = _recentCount;
      final realCats = _realCats;
      final showRecent = recentCount > 0;

      if (realCats.isEmpty && allCount == 0) {
        return _EmptyState(
          icon: Icons.category_outlined,
          message: 'portraitPanel.empty.categories'.tr,
        );
      }

      final virtualRows = 1 + (showRecent ? 1 : 0);
      return ListView.separated(
        physics: AppScrollPhysics.list(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        itemCount: realCats.length + virtualRows,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          if (i == 0) {
            final selected = _selectedCategoryId == _kVodPanelAllCategoryId;
            final allLabel = widget.isSeriesMode
                ? 'portraitVodPanel.allSeries'.tr
                : 'portraitVodPanel.allFilms'.tr;
            return _CategoryRow(
              name: allLabel,
              count: allCount,
              selected: selected,
              isCurrent: false,
              leadingIcon: Icons.apps_rounded,
              onTap: () {
                setState(() {
                  _selectedCategoryId = _kVodPanelAllCategoryId;
                  _tab = _PortraitVodTab.items;
                });
                unawaited(_reloadItems());
              },
            );
          }
          if (showRecent && i == 1) {
            final selected =
                _selectedCategoryId == _kVodPanelRecentlyWatchedCategoryId;
            return _CategoryRow(
              name: 'browse.recentlyWatched'.tr,
              count: recentCount,
              selected: selected,
              isCurrent: false,
              leadingIcon: Icons.history_rounded,
              onTap: () {
                setState(() {
                  _selectedCategoryId = _kVodPanelRecentlyWatchedCategoryId;
                  _tab = _PortraitVodTab.items;
                });
                unawaited(_reloadItems());
              },
            );
          }
          final cat = realCats[i - virtualRows];
          final selected = _selectedCategoryId == cat.id;
          // Aktif kanalın/dizinin gerçek kategorisi → yıldız işareti.
          final currentCatId = widget.isSeriesMode
              ? widget.controller.playingSeries?.categoryId
              : widget.controller.channel.value.categoryId;
          final isCurrent = currentCatId == cat.id;
          return _CategoryRow(
            name: cat.name,
            count: cat.count,
            selected: selected,
            isCurrent: isCurrent,
            onTap: () {
              setState(() {
                _selectedCategoryId = cat.id;
                _tab = _PortraitVodTab.items;
              });
              unawaited(_reloadItems());
            },
          );
        },
      );
    });
  }

  // ------------------------------ İçerikler ------------------------------

  Widget _buildItemsList(BuildContext context) {
    return Obx(() {
      if (Get.isRegistered<PlaylistCacheService>()) {
        Get.find<PlaylistCacheService>().result.value;
      }
      if (_selectedCategoryId == _kVodPanelRecentlyWatchedCategoryId &&
          Get.isRegistered<UserHistoryService>()) {
        Get.find<UserHistoryService>().revision.value;
      }
      // Aktif içerik değişimini izle ki "şu an oynayan" rozeti yenilensin.
      widget.controller.channel.value;
      if (_data() == null) {
        return _EmptyState(
          icon: widget.isSeriesMode
              ? Icons.theater_comedy_outlined
              : Icons.movie_outlined,
          message: 'portraitVodPanel.empty.items'.tr,
        );
      }
      if (_loadingItems) {
        return const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        );
      }

      if (widget.isSeriesMode) {
        final list = _seriesItems;
        if (list.isEmpty) {
          return _EmptyState(
            icon: Icons.theater_comedy_outlined,
            message: 'portraitVodPanel.empty.items'.tr,
          );
        }
        final activeId = widget.controller.playingSeries?.id;
        return ListView.separated(
          physics: AppScrollPhysics.list(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final s = list[i];
            return _VodItemRow(
              title: s.name,
              posterUrl: s.posterUrl,
              isCurrent: activeId == s.id,
              isSeries: true,
              onTap: () {
                unawaited(widget.controller.pickVodBrowseRailSeries(s));
              },
            );
          },
        );
      } else {
        final list = _filmItems;
        if (list.isEmpty) {
          return _EmptyState(
            icon: Icons.movie_outlined,
            message: 'portraitVodPanel.empty.items'.tr,
          );
        }
        // Şu an oynayan film için karşılaştırma — id veya streamUrl.
        final cur = widget.controller.channel.value;
        return ListView.separated(
          physics: AppScrollPhysics.list(),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final v = list[i];
            final isCurrent = v.id == cur.id || v.streamUrl == cur.streamUrl;
            return _VodItemRow(
              title: v.name,
              posterUrl: v.posterUrl,
              isCurrent: isCurrent,
              isSeries: false,
              onTap: () {
                final ch = Channel(
                  id: v.id,
                  name: v.name,
                  streamUrl: v.streamUrl,
                  categoryId: v.categoryId,
                  logoUrl: v.posterUrl,
                );
                unawaited(widget.controller.pickVodBrowseRailMovie(ch));
              },
            );
          },
        );
      }
    });
  }

  List<VodItem> _resolveMovieListMem(M3uResult d, int? selectedId) {
    if (selectedId == _kVodPanelRecentlyWatchedCategoryId) {
      return _recentlyWatchedMovies(d);
    }
    if (selectedId == _kVodPanelAllCategoryId || selectedId == null) {
      final all = List<VodItem>.from(d.vod);
      all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return all;
    }
    final byCat = _moviesByCategory(d);
    return byCat[selectedId] ?? const <VodItem>[];
  }

  List<SeriesItem> _resolveSeriesListMem(M3uResult d, int? selectedId) {
    if (selectedId == _kVodPanelRecentlyWatchedCategoryId) {
      return _recentlyWatchedSeries(d);
    }
    if (selectedId == _kVodPanelAllCategoryId || selectedId == null) {
      final all = List<SeriesItem>.from(d.series);
      all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return all;
    }
    final byCat = _seriesByCategory(d);
    return byCat[selectedId] ?? const <SeriesItem>[];
  }
}

/// Dikey VOD/Series panelinde tek liste satırı: poster + başlık + "şu an
/// oynayan" rozeti. Sade ve tıklamaya odaklı; gridler büyük posterler için
/// browse modülünde zaten mevcut, burada amaç hızlı ön-listeleme.
class _VodItemRow extends StatelessWidget {
  const _VodItemRow({
    required this.title,
    required this.posterUrl,
    required this.isCurrent,
    required this.isSeries,
    required this.onTap,
  });

  final String title;
  final String? posterUrl;
  final bool isCurrent;
  final bool isSeries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logoPx = (44 * dpr).round();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isCurrent
                ? primary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: isCurrent
                  ? primary.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
              width: isCurrent ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: (posterUrl != null && posterUrl!.trim().isNotEmpty)
                      ? IptvChannelLogo(
                          imageUrl: posterUrl!,
                          width: 40,
                          height: 56,
                          fit: BoxFit.cover,
                          memCacheWidth: logoPx,
                        )
                      : Container(
                          color: Colors.white.withValues(alpha: 0.06),
                          child: Center(
                            child: Icon(
                              isSeries
                                  ? Icons.theater_comedy_outlined
                                  : Icons.movie_outlined,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isSeries
                              ? Icons.theater_comedy_outlined
                              : Icons.movie_outlined,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSeries ? 'browse.series'.tr : 'browse.films'.tr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: primary.withValues(alpha: 0.55),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'portraitVodPanel.nowPlaying'.tr,
                              style: TextStyle(
                                color: primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_arrow_rounded,
                size: 22,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortraitLiveTvPanel extends StatefulWidget {
  const _PortraitLiveTvPanel({required this.controller});

  final PlayerController controller;

  @override
  State<_PortraitLiveTvPanel> createState() => _PortraitLiveTvPanelState();
}

enum _PortraitLiveTab { categories, channels, epg }

class _PortraitLiveTvPanelState extends State<_PortraitLiveTvPanel> {
  _PortraitLiveTab _tab = _PortraitLiveTab.channels;
  int? _selectedCategoryId;
  Worker? _channelWorker;
  Worker? _tabRequestWorker;
  Timer? _epgTicker;

  _PortraitLiveTab _tabFromRequestIndex(int idx) {
    return switch (idx) {
      PlayerController.portraitLiveTabCategories =>
        _PortraitLiveTab.categories,
      PlayerController.portraitLiveTabEpg => _PortraitLiveTab.epg,
      _ => _PortraitLiveTab.channels,
    };
  }

  @override
  void initState() {
    super.initState();
    _syncCategoryWithCurrentChannel();
    // Aktif kanal değişince kategori seçimini güncel kanala hizala.
    _channelWorker = ever(widget.controller.channel, (_) {
      _syncCategoryWithCurrentChannel();
    });
    // OSD'deki EPG ikonu → bu panelin EPG sekmesine geçer (dikey mod).
    _tabRequestWorker =
        ever(widget.controller.portraitLivePanelTabPulse, (_) {
      if (!mounted) return;
      final next =
          _tabFromRequestIndex(widget.controller.portraitLivePanelTabRequest.value);
      if (_tab != next) {
        setState(() => _tab = next);
      }
    });
    // EPG sekmesinde "DEVAM EDİYOR" rozetinin saat geçişinde tazelenmesi için
    // dakikada bir tetikleme. (Sekme EPG değilse ucuz `setState`.)
    _epgTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (_tab != _PortraitLiveTab.epg) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _channelWorker?.dispose();
    _tabRequestWorker?.dispose();
    _epgTicker?.cancel();
    super.dispose();
  }

  void _syncCategoryWithCurrentChannel() {
    if (!mounted) return;
    // Favoriler / Son İzlenenler sanal kategorileri seçili iken kullanıcının
    // tercihi korunsun; aktif kanalın gerçek kategorisi olsa da otomatik
    // geri dönmeyelim.
    if (_selectedCategoryId == kFavoritesVirtualCategoryId) return;
    if (_selectedCategoryId == kRecentlyWatchedVirtualCategoryId) return;
    final cur = widget.controller.channel.value;
    if (_selectedCategoryId != cur.categoryId) {
      setState(() => _selectedCategoryId = cur.categoryId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Oynatıcı sahnesi: tema fark etmeksizin koyu opak panel.
            // Frosted Glass / Mina Glass / Glass Gri sentetik camda
            // popupGradientColors beyaz alpha; player'da görüntüyü
            // örtüyordu.
            color: const Color(0xE60B0F14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          child: Column(
            children: [
              _buildTabBar(context),
              const Divider(
                height: 1,
                thickness: 0.6,
                color: Color(0x22FFFFFF),
              ),
              Expanded(child: _buildTabBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tabs = <(_PortraitLiveTab, String)>[
      (_PortraitLiveTab.categories, 'channels.tab.categories'.tr),
      (_PortraitLiveTab.channels, 'channels.tab.channels'.tr),
      (_PortraitLiveTab.epg, 'channels.tab.epgTimeline'.tr),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: _TabButton(
                label: t.$2,
                active: _tab == t.$1,
                primary: primary,
                onTap: () => setState(() => _tab = t.$1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBody(BuildContext context) {
    switch (_tab) {
      case _PortraitLiveTab.categories:
        return _buildCategoriesList(context);
      case _PortraitLiveTab.channels:
        return _buildChannelsList(context);
      case _PortraitLiveTab.epg:
        return _buildEpgList(context);
    }
  }

  // ------------------------------ Kategoriler ------------------------------

  Widget _buildCategoriesList(BuildContext context) {
    return Obx(() {
      widget.controller.channel.value;
      // DB destekli şerit async dolunca yeniden çiz.
      widget.controller.liveStripTapesRevision.value;
      if (Get.isRegistered<PlaylistCacheService>()) {
        Get.find<PlaylistCacheService>().result.value;
      }
      // Favori RxList değişimini dinle (favorite sayısı + seçili sekme).
      final favs = Get.find<FavoritesService>();
      favs.channelIds.length;
      // UserHistory revision'ı dinle — yeni izleme kaydı eklenince
      // "Son İzlenenler" satırı/sayacı anında yenilensin.
      if (Get.isRegistered<UserHistoryService>()) {
        Get.find<UserHistoryService>().revision.value;
      }
      final tapes = widget.controller.liveChannelStripCategoryTapes();
      if (tapes.isEmpty) {
        return _EmptyState(
          icon: Icons.category_outlined,
          message: 'portraitPanel.empty.categories'.tr,
        );
      }
      final curCatId = widget.controller.channel.value.categoryId;
      final favCount = _favoriteLiveChannels().length;
      final recentList = _recentlyWatchedLiveChannels();
      final showRecent = recentList.isNotEmpty;
      // Üst sanal satırlar: Favoriler (her zaman), Son İzlenenler (kayıt
      // varsa). İkisinin altına gerçek kategoriler. Toplam satır =
      // 1 + (showRecent ? 1 : 0) + tapes.length.
      final virtualRows = 1 + (showRecent ? 1 : 0);
      return ListView.separated(
        physics: AppScrollPhysics.list(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        itemCount: tapes.length + virtualRows,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          if (i == 0) {
            final selected = _selectedCategoryId == kFavoritesVirtualCategoryId;
            return _CategoryRow(
              name: 'channels.favoritesCategory'.tr,
              count: favCount,
              selected: selected,
              isCurrent: false,
              leadingIcon: Icons.favorite_rounded,
              onTap: () {
                setState(() {
                  _selectedCategoryId = kFavoritesVirtualCategoryId;
                  _tab = _PortraitLiveTab.channels;
                });
              },
            );
          }
          if (showRecent && i == 1) {
            final selected =
                _selectedCategoryId == kRecentlyWatchedVirtualCategoryId;
            return _CategoryRow(
              name: 'channels.recentlyWatchedCategory'.tr,
              count: recentList.length,
              selected: selected,
              isCurrent: false,
              leadingIcon: Icons.history_rounded,
              onTap: () {
                setState(() {
                  _selectedCategoryId = kRecentlyWatchedVirtualCategoryId;
                  _tab = _PortraitLiveTab.channels;
                });
              },
            );
          }
          final t = tapes[i - virtualRows];
          final selected = (_selectedCategoryId != null &&
                  _selectedCategoryId != kFavoritesVirtualCategoryId &&
                  _selectedCategoryId != kRecentlyWatchedVirtualCategoryId &&
                  _selectedCategoryId == t.categoryId) ||
              (_selectedCategoryId == null && curCatId == t.categoryId);
          return _CategoryRow(
            name: t.name,
            count: t.items.length,
            selected: selected,
            isCurrent: curCatId == t.categoryId,
            onTap: () {
              setState(() {
                _selectedCategoryId = t.categoryId;
                _tab = _PortraitLiveTab.channels;
              });
            },
          );
        },
      );
    });
  }

  /// Canlı kanallar arasında favoride olanlar (`liveChannelStripCategoryTapes`
  /// içindeki kanal akışı ile aynı sıralamayı korur).
  List<Channel> _favoriteLiveChannels() {
    final favs = Get.find<FavoritesService>();
    if (favs.channelIds.isEmpty) return const [];
    final out = <Channel>[];
    final seen = <int>{};
    for (final tape in widget.controller.liveChannelStripCategoryTapes()) {
      for (final ch in tape.items) {
        if (!seen.add(ch.id)) continue;
        if (favs.hasChannel(ch.id)) out.add(ch);
      }
    }
    return out;
  }

  /// **Son İzlenenler** sanal kategorisi için kanal listesi —
  /// `UserHistoryService` snapshot'ından `kind == live` kayıtları timestamp
  /// sırasıyla işler; her contentId tek kez (en yeni izleme) liste başına
  /// gelir; toplam [kRecentlyWatchedLiveLimit] sınırı uygulanır.
  ///
  /// Her zaman gerçek `liveChannelStripCategoryTapes` üzerinden kanal
  /// nesnelerine map eder; playlist'te artık olmayan veya gizli kategoride
  /// kalan kanallar listede gösterilmez.
  List<Channel> _recentlyWatchedLiveChannels() {
    if (!Get.isRegistered<UserHistoryService>()) return const [];
    final history = Get.find<UserHistoryService>().snapshotSync();
    if (history.isEmpty) return const [];
    final entries = history
        .where((e) => e.kind == UserHistoryKind.live)
        .toList(growable: false)
      ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    if (entries.isEmpty) return const [];
    final byId = <int, Channel>{};
    for (final tape in widget.controller.liveChannelStripCategoryTapes()) {
      for (final ch in tape.items) {
        byId.putIfAbsent(ch.id, () => ch);
      }
    }
    final out = <Channel>[];
    final seen = <int>{};
    for (final e in entries) {
      if (seen.contains(e.contentId)) continue;
      final ch = byId[e.contentId];
      if (ch == null) continue;
      seen.add(e.contentId);
      out.add(ch);
      if (out.length >= kRecentlyWatchedLiveLimit) break;
    }
    return out;
  }

  // ------------------------------ Kanallar ------------------------------

  Widget _buildChannelsList(BuildContext context) {
    return Obx(() {
      widget.controller.channel.value;
      // DB destekli şerit async dolunca yeniden çiz.
      widget.controller.liveStripTapesRevision.value;
      if (Get.isRegistered<PlaylistCacheService>()) {
        Get.find<PlaylistCacheService>().result.value;
      }
      // Favori RxList değişimi sanal "Favoriler" kanal listesini ve normal
      // listedeki kalp ikonlarını anında tazelesin.
      Get.find<FavoritesService>().channelIds.length;
      // UserHistory: yalnız Son İzlenenler seçiliyken dinle (oynatma sırasında
      // history tick → tüm kanal listesi Obx rebuild olmasın).
      if (_selectedCategoryId == kRecentlyWatchedVirtualCategoryId &&
          Get.isRegistered<UserHistoryService>()) {
        Get.find<UserHistoryService>().revision.value;
      }
      final tapes = widget.controller.liveChannelStripCategoryTapes();
      if (tapes.isEmpty) {
        return _EmptyState(
          icon: Icons.live_tv_outlined,
          message: 'portraitPanel.empty.channels'.tr,
        );
      }
      // Favoriler sanal kategorisi seçili — favori canlı kanalları göster.
      if (_selectedCategoryId == kFavoritesVirtualCategoryId) {
        final favList = _favoriteLiveChannels();
        if (favList.isEmpty) {
          return Column(
            children: [
              _CategoryHeader(
                name: 'channels.favoritesCategory'.tr,
                count: 0,
                onChangeTap: () =>
                    setState(() => _tab = _PortraitLiveTab.categories),
                icon: Icons.favorite_rounded,
              ),
              Expanded(
                child: _EmptyState(
                  icon: Icons.favorite_border_rounded,
                  message: 'channels.favoritesCategoryEmpty'.tr,
                ),
              ),
            ],
          );
        }
        final currentId = widget.controller.channel.value.id;
        return Column(
          children: [
            _CategoryHeader(
              name: 'channels.favoritesCategory'.tr,
              count: favList.length,
              onChangeTap: () =>
                  setState(() => _tab = _PortraitLiveTab.categories),
              icon: Icons.favorite_rounded,
            ),
            Expanded(
              child: ListView.separated(
                physics: AppScrollPhysics.list(),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                itemCount: favList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final ch = favList[i];
                  final isCurrent = ch.id == currentId;
                  return _ChannelRow(
                    channel: ch,
                    isCurrent: isCurrent,
                    onTap: () => unawaited(widget.controller.zapTo(ch)),
                  );
                },
              ),
            ),
          ],
        );
      }
      // Son İzlenenler sanal kategorisi seçili — UserHistory'den son 20
      // canlı kanalı kronolojik olarak göster.
      if (_selectedCategoryId == kRecentlyWatchedVirtualCategoryId) {
        final recent = _recentlyWatchedLiveChannels();
        final currentId = widget.controller.channel.value.id;
        if (recent.isEmpty) {
          return Column(
            children: [
              _CategoryHeader(
                name: 'channels.recentlyWatchedCategory'.tr,
                count: 0,
                onChangeTap: () =>
                    setState(() => _tab = _PortraitLiveTab.categories),
                icon: Icons.history_rounded,
              ),
              Expanded(
                child: _EmptyState(
                  icon: Icons.history_toggle_off_rounded,
                  message: 'portraitPanel.empty.channels'.tr,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            _CategoryHeader(
              name: 'channels.recentlyWatchedCategory'.tr,
              count: recent.length,
              onChangeTap: () =>
                  setState(() => _tab = _PortraitLiveTab.categories),
              icon: Icons.history_rounded,
            ),
            Expanded(
              child: ListView.separated(
                physics: AppScrollPhysics.list(),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                itemCount: recent.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final ch = recent[i];
                  final isCurrent = ch.id == currentId;
                  return _ChannelRow(
                    channel: ch,
                    isCurrent: isCurrent,
                    onTap: () => unawaited(widget.controller.zapTo(ch)),
                  );
                },
              ),
            ),
          ],
        );
      }
      final catId =
          _selectedCategoryId ?? widget.controller.channel.value.categoryId;
      List<Channel> list = const [];
      String? catName;
      for (final t in tapes) {
        if (t.categoryId == catId) {
          list = t.items;
          catName = t.name;
          break;
        }
      }
      // Eğer seçili kategori kanal listesinde yoksa (örn. boşaldı) ilk kategoriye düş.
      if (list.isEmpty) {
        list = tapes.first.items;
        catName = tapes.first.name;
      }
      final currentId = widget.controller.channel.value.id;
      return Column(
        children: [
          if (catName != null)
            _CategoryHeader(
              name: catName,
              count: list.length,
              onChangeTap: () =>
                  setState(() => _tab = _PortraitLiveTab.categories),
            ),
          Expanded(
            child: ListView.separated(
              physics: AppScrollPhysics.list(),
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final ch = list[i];
                final isCurrent = ch.id == currentId;
                return _ChannelRow(
                  channel: ch,
                  isCurrent: isCurrent,
                  onTap: () => unawaited(widget.controller.zapTo(ch)),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  // ------------------------------ EPG ------------------------------

  Widget _buildEpgList(BuildContext context) {
    return Obx(() {
      final ch = widget.controller.channel.value;
      if (Get.isRegistered<PlaylistCacheService>()) {
        Get.find<PlaylistCacheService>().result.value;
      }
      final epg =
          Get.isRegistered<EpgService>() ? Get.find<EpgService>() : null;
      if (epg == null) {
        return _EmptyState(
          icon: Icons.schedule_outlined,
          message: 'portraitPanel.empty.epg'.tr,
        );
      }
      // EPG yüklendiğinde / yenilendiğinde panel otomatik tazelensin.
      epg.loadGeneration.value;
      final progs = epg.getFullDayProgrammesForLiveChannel(ch);
      if (progs.isEmpty) {
        return _EmptyState(
          icon: Icons.schedule_outlined,
          message: 'portraitPanel.empty.epg'.tr,
        );
      }
      final now = DateTime.now();
      var liveIdx = -1;
      for (var i = 0; i < progs.length; i++) {
        if (now.isAfter(progs[i].start) && now.isBefore(progs[i].end)) {
          liveIdx = i;
          break;
        }
      }
      return ListView.separated(
        physics: AppScrollPhysics.list(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        itemCount: progs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          return _EpgRow(programme: progs[i], isLive: i == liveIdx);
        },
      );
    });
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? primary : Colors.white.withValues(alpha: 0.78),
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.name,
    required this.count,
    required this.onChangeTap,
    this.icon = Icons.category_outlined,
  });

  final String name;
  final int count;
  final VoidCallback onChangeTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.15,
              ),
            ),
          ),
          Text(
            'portraitPanel.channelCount'.trParams({'n': count.toString()}),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onChangeTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.count,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
    this.leadingIcon,
  });

  final String name;
  final int count;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final iconData =
        leadingIcon ?? (isCurrent ? Icons.live_tv_rounded : Icons.tv_outlined);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? primary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                iconData,
                size: 20,
                color: isCurrent || leadingIcon != null
                    ? primary
                    : Colors.white.withValues(alpha: 0.72),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'portraitPanel.channelCount'.trParams({'n': count.toString()}),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channel,
    required this.isCurrent,
    required this.onTap,
  });

  final Channel channel;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logoPx = (44 * dpr).round();
    final logoUrl = channel.logoUrl?.trim();
    final epg = Get.isRegistered<EpgService>() ? Get.find<EpgService>() : null;
    final cur = epg?.getCurrentProgrammeForLiveChannel(channel);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isCurrent
                ? primary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: isCurrent
                  ? primary.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
              width: isCurrent ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: logoUrl != null && logoUrl.isNotEmpty
                      ? IptvChannelLogo(
                          imageUrl: logoUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                          memCacheWidth: logoPx,
                          memCacheHeight: logoPx,
                          showProgressIndicator: true,
                          progressIndicatorColor: Colors.white24,
                          errorWidget: Icon(
                            Icons.live_tv_rounded,
                            color: Colors.white.withValues(alpha: 0.75),
                            size: 28,
                          ),
                        )
                      : Container(
                          color: Colors.white.withValues(alpha: 0.06),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.live_tv_rounded,
                            color: Colors.white.withValues(alpha: 0.75),
                            size: 26,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // EPG bilgisi gelmemişse "program mevcut değil" yazısı yerine
                    // cam stilli, üzeri çapraz çizili EPG rozeti göster.
                    if (cur != null)
                      Text(
                        _formatEpgLineForRow(cur),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                        ),
                      )
                    else
                      const _NoEpgGlassBadge(),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isCurrent
                    ? Icons.play_arrow_rounded
                    : Icons.chevron_right_rounded,
                size: isCurrent ? 22 : 18,
                color:
                    isCurrent ? primary : Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// EPG verisi gelmemiş kanallar için, "program mevcut değil" yazısı yerine
/// gösterilen cam stilli rozet: EPG simgesi ([Icons.view_timeline_rounded] —
/// uygulamadaki EPG butonuyla aynı) üzerine çapraz "çarpı" çizgisi.
class _NoEpgGlassBadge extends StatelessWidget {
  const _NoEpgGlassBadge();

  @override
  Widget build(BuildContext context) {
    final iconColor = Colors.white.withValues(alpha: 0.5);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.view_timeline_rounded,
            size: 14,
            color: iconColor,
          ),
          // Üzerine çapraz çizgi (çarpı): altta koyu kontur, üstte açık çizgi.
          Transform.rotate(
            angle: -0.7853981633974483, // -45°
            child: Container(
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Transform.rotate(
            angle: -0.7853981633974483,
            child: Container(
              width: 20,
              height: 1.6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpgRow extends StatelessWidget {
  const _EpgRow({
    required this.programme,
    required this.isLive,
  });

  final EpgProgramme programme;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final s = _fmtHm(programme.start);
    final e = _fmtHm(programme.end);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isLive
            ? primary.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: isLive
              ? primary.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.08),
          width: isLive ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$s - $e',
                  style: TextStyle(
                    color:
                        isLive ? primary : Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (isLive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: primary.withValues(alpha: 0.22),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.55),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'portraitPanel.live'.tr,
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            programme.title.trim().isEmpty
                ? 'portraitPanel.noProgramme'.tr
                : programme.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          if ((programme.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              programme.description!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatEpgLineForRow(EpgProgramme p) {
  final s = _fmtHm(p.start);
  final e = _fmtHm(p.end);
  final t = p.title.trim();
  if (t.isEmpty) return '$s - $e';
  return '$t · $s - $e';
}

String _fmtHm(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
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
  const _VideoProgressBar({
    required this.bp,
    required this.value,
    this.onScrub,
  });

  final BetterPlayerController bp;
  final VideoPlayerValue value;
  final ValueChanged<bool>? onScrub;

  @override
  Widget build(BuildContext context) {
    final cur = value.position;
    final dur = value.duration ?? Duration.zero;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: VodSeekBar(
            position: cur,
            duration: dur,
            onSeek: (d) => bp.seekTo(d),
            onScrubChanged: onScrub,
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
  Player? _mkTarget;
  final List<StreamSubscription<dynamic>> _subs = [];
  // Son rebuild edilen snapshot; position stream saniyede ~5 kez tetiklendiği
  // için, yalnızca oynat/duraklat, süre veya ≥500ms konum değişiminde yeniden
  // çiz (BetterPlayer builder'ı ile aynı eşik).
  _MediaKitPortraitSnap? _lastBuilt;

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
    if (identical(_mkTarget, p)) return;
    _cancelSubs();
    _mkTarget = p;
    _lastBuilt = null;
    if (p == null) {
      if (mounted) setState(() {});
      return;
    }
    void tick([dynamic _]) {
      if (!mounted) return;
      final snap = _readSnap();
      final o = _lastBuilt;
      if (o != null &&
          snap != null &&
          o.playing == snap.playing &&
          o.duration == snap.duration &&
          (snap.position.inMilliseconds - o.position.inMilliseconds).abs() <
              500) {
        return;
      }
      _lastBuilt = snap;
      setState(() {});
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
    this.onScrub,
  });

  final Duration position;
  final Duration duration;
  final void Function(Duration) onSeek;
  final ValueChanged<bool>? onScrub;

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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: VodSeekBar(
            position: cur,
            duration: dur,
            onSeek: onSeek,
            onScrubChanged: onScrub,
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
    super.key,
    required this.channel,
  });

  final Channel channel;

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
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerLoadingCenter extends StatelessWidget {
  const _PlayerLoadingCenter({
    super.key,
    required this.channel,
  });

  final Channel channel;

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
            key: ValueKey('splash_logo_${channel.id}_$logo'),
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
        if (hasLogo) const SizedBox(height: 18),
        const _PlayerLoadingBlinkingUmbrella(),
      ],
    );
  }
}

/// Yayın açılırken kanal logosunun altında yanıp sönen küçük uygulama ikonu
/// (mavi şemsiye). Eski "Akış açılıyor…" metni + progress bar yerine geçer.
class _PlayerLoadingBlinkingUmbrella extends StatefulWidget {
  const _PlayerLoadingBlinkingUmbrella();

  @override
  State<_PlayerLoadingBlinkingUmbrella> createState() =>
      _PlayerLoadingBlinkingUmbrellaState();
}

class _PlayerLoadingBlinkingUmbrellaState
    extends State<_PlayerLoadingBlinkingUmbrella>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scale = Tween<double>(begin: 0.88, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: Image.asset(
          'assets/images/app_icon.png',
          width: 40,
          height: 40,
          filterQuality: FilterQuality.medium,
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
