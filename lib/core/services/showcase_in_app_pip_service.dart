import 'dart:async' show unawaited;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../home/home_layout_style.dart';
import '../../domain/entities/channel.dart';
import '../../modules/player/player_controller.dart';
import '../../modules/player/player_navigation.dart';
import '../../modules/player/player_route_args.dart';
import 'app_settings_service.dart';

/// Vitrin ana ekranında «uygulama içi PiP»: oynatıcıdan ana ekrana dönünce
/// yayın dock'taki büyütülmüş son-izlenen alanında ses+video ile devam eder.
class ShowcaseInAppPipService extends GetxService {
  final active = false.obs;
  final posterUrl = RxnString();

  PlayerScreenArgs? _args;
  BetterPlayerController? _better;
  Player? _mediaKitPlayer;
  VideoController? _mediaKitVideo;
  bool _usesMediaKit = false;

  Worker? _enabledWorker;
  Worker? _layoutWorker;

  BetterPlayerController? get better => _better;
  VideoController? get mediaKitVideo => _mediaKitVideo;
  bool get usesMediaKit => _usesMediaKit;

  /// [UniversalVideoPlayer] route kapanırken servise devredilen mpv örneğini
  /// tekrar dispose etmemek için.
  bool retainsMediaKitPlayer(Player? player) =>
      player != null && identical(_mediaKitPlayer, player);

  bool retainsBetterController(BetterPlayerController? controller) =>
      controller != null && identical(_better, controller);

  @override
  void onInit() {
    super.onInit();
    final settings = Get.find<AppSettingsService>();
    _enabledWorker = ever<bool>(settings.showcaseInAppPipEnabled, (_) {
      _stopIfUnavailable();
    });
    _layoutWorker = ever<HomeLayoutStyle>(settings.homeLayoutStyle, (_) {
      _stopIfUnavailable();
    });
  }

  @override
  void onClose() {
    _enabledWorker?.dispose();
    _layoutWorker?.dispose();
    unawaited(stopAndDispose());
    super.onClose();
  }

  void _stopIfUnavailable() {
    final settings = Get.find<AppSettingsService>();
    if (!settings.showcaseInAppPipEnabled.value ||
        settings.homeLayoutStyle.value != HomeLayoutStyle.showcase) {
      unawaited(stopAndDispose());
    }
  }

  /// Oynatıcı route kapanmadan motorları servise devralır.
  Future<bool> acceptHandoffFrom(PlayerController ctrl) async {
    final settings = Get.find<AppSettingsService>();
    if (!settings.showcaseInAppPipEnabled.value) return false;
    if (settings.homeLayoutStyle.value != HomeLayoutStyle.showcase) return false;
    if (!ctrl.showcaseInAppPipHandoff) return false;

    if (!ctrl.playbackEligibleForShowcaseHandoff()) return false;

    final args = ctrl.toPlayerScreenArgs();
    final usesMk = ctrl.effectiveUseMediaKit;
    BetterPlayerController? better;
    Player? mk;

    if (usesMk) {
      mk = ctrl.peekMediaKitPlayerForShowcasePip();
      if (mk == null) return false;
    } else {
      better = ctrl.peekBetterPlayerForShowcasePip();
      if (better == null) return false;
    }

    await stopAndDispose();

    if (!ctrl.finalizeShowcaseInAppPipHandoff()) return false;

    _args = args;
    _better = better;
    _mediaKitPlayer = mk;
    _usesMediaKit = usesMk;
    if (mk != null) {
      _mediaKitVideo = VideoController(mk);
    }
    posterUrl.value = _posterFor(args.channel);
    active.value = true;

    if (better != null) {
      try {
        better.setSuppressLifecycleAutoPause(true);
        unawaited(better.play());
      } catch (_) {}
    } else if (mk != null) {
      try {
        if (!mk.state.playing) {
          unawaited(mk.play());
        }
      } catch (_) {}
    }

    return true;
  }

  /// Yeni [PlayerController] açılışında motorları geri verir; [_boot] atlanır.
  Future<bool> tryRestoreInto(PlayerController ctrl) async {
    if (!active.value || _args == null) return false;

    final ch = ctrl.channel.value;
    if (ch.id != _args!.channel.id ||
        ch.streamUrl.trim() != _args!.channel.streamUrl.trim()) {
      unawaited(stopAndDispose());
      return false;
    }

    if (_usesMediaKit && _mediaKitPlayer != null) {
      await ctrl.attachMediaKitPlayer(_mediaKitPlayer);
      ctrl.clearShowcaseInAppPipHandoffFlags();
    } else if (_better != null) {
      if (!ctrl.restoreBetterFromShowcasePip(_better!)) return false;
    } else {
      return false;
    }

    _releaseOwnershipWithoutDispose();
    return true;
  }

  void openPlayer() {
    final args = _args;
    if (args == null) return;
    unawaited(openPlayerRoute(args));
  }

  Future<void> stopAndDispose() async {
    if (!active.value &&
        _better == null &&
        _mediaKitPlayer == null &&
        _args == null) {
      return;
    }

    active.value = false;
    posterUrl.value = null;
    _args = null;
    _mediaKitVideo = null;
    _usesMediaKit = false;

    final b = _better;
    _better = null;
    if (b != null) {
      try {
        await b.pause();
        b.dispose(forceDispose: true);
      } catch (e, st) {
        debugPrint('mina_iptv: showcase in-app pip better dispose: $e\n$st');
      }
    }

    final mk = _mediaKitPlayer;
    _mediaKitPlayer = null;
    if (mk != null) {
      try {
        await mk.pause();
        await mk.stop();
        await mk.dispose();
      } catch (e, st) {
        debugPrint('mina_iptv: showcase in-app pip mediaKit dispose: $e\n$st');
      }
    }
  }

  void _releaseOwnershipWithoutDispose() {
    active.value = false;
    posterUrl.value = null;
    _args = null;
    _mediaKitVideo = null;
    _better = null;
    _mediaKitPlayer = null;
    _usesMediaKit = false;
  }

  static String? _posterFor(Channel ch) {
    final logo = ch.logoUrl?.trim();
    if (logo != null && logo.isNotEmpty) return logo;
    return null;
  }
}