import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:get/get.dart' hide Response;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/player/better_player_iptv_config.dart';
import '../../core/player/exo_native_track_option.dart';
import '../../core/player/iptv_playback_defaults.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/series.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../browse/browse_controller.dart';
import '../channels/channels_controller.dart';
import 'widgets/tv_better_player_controls.dart';
import '../../ui/glass_overlays.dart';

const MethodChannel _androidPipChannel = MethodChannel('mina.player/pip');

class PlayerController extends GetxController with WidgetsBindingObserver {
  PlayerController({
    required Channel channel,
    List<Channel>? movieBrowseTape,
    List<SeriesItem>? seriesBrowseTape,
    SeriesItem? playingSeriesInTape,
    this.openedFromBrowse = false,
  })  : channel = channel.obs,
        _movieBrowseTape = movieBrowseTape != null
            ? List<Channel>.from(movieBrowseTape)
            : null,
        _seriesBrowseTape = seriesBrowseTape != null
            ? List<SeriesItem>.from(seriesBrowseTape)
            : null,
        _playingSeriesInTape = playingSeriesInTape;

  /// [PlayerScreenArgs] ile açıldıysa geri dönüşte gözat listesi restore edilir.
  final bool openedFromBrowse;

  final Rx<Channel> channel;

  /// Gözat (film): sıradaki filme geçiş.
  final List<Channel>? _movieBrowseTape;

  /// Gözat (dizi): sıradaki dizinin ilk bölümüne geçiş.
  final List<SeriesItem>? _seriesBrowseTape;
  SeriesItem? _playingSeriesInTape;

  bool get isMovie => _movieBrowseTape != null;
  bool get isSeries => _seriesBrowseTape != null || _playingSeriesInTape != null;
  SeriesItem? get playingSeries => _playingSeriesInTape;

  /// İnternet / sunucu geçişi gibi tekrar denemeye uygun hatalar (kod çözücü değil).
  static bool _isLikelyNetworkOrTransientError(String msg) {
    if (msg.isEmpty) return false;
    if (_isPlaybackDecoderFailure(msg)) return false;
    final l = msg.toLowerCase();
    if (l.contains('unsupported') && l.contains('format')) return false;
    if (l.contains('drm')) return false;
    return l.contains('timeout') ||
        l.contains('timed out') ||
        l.contains('bağlantı') ||
        l.contains('baglanti') ||
        l.contains('connection') ||
        l.contains('network') ||
        l.contains('unreachable') ||
        l.contains('host lookup') ||
        l.contains('no address') ||
        l.contains('failed host') ||
        l.contains('connection reset') ||
        l.contains('connection refused') ||
        l.contains('broken pipe') ||
        l.contains('enetunreach') ||
        l.contains('econnrefused') ||
        l.contains('socket') ||
        (l.contains('ssl') && l.contains('handshake')) ||
        l.contains('ioexception') ||
        l.contains('i/o error') ||
        l.contains('io error') ||
        l.contains('502') ||
        l.contains('503') ||
        l.contains('504') ||
        l.contains('408') ||
        l.contains('failed to connect') ||
        l.contains('unable to connect') ||
        l.contains('no route') ||
        l.contains('cleartext') ||
        l.contains('err_timed_out') ||
        l.contains('network_error') ||
        l.contains('offline') ||
        l.contains('end of input') ||
        // ExoPlayer köprüsü çoğu zaman yalnızca "Source error" / "source error null" döner;
        // uzun canlı yayında segment/HTTP kopması böyle görünür (eski TV kutuları sık).
        l.contains('source error') ||
        l.contains('unexpected end of stream') ||
        l.contains('connection closed') ||
        (l.contains('http') && l.contains('50'));
  }

  /// ExoPlayer / video_player bazen `PlatformException(VideoError, ...)` döndürür;
  /// metin biçimi cihaza göre değişebilir.
  static bool _isPlaybackDecoderFailure(String msg) {
    if (msg.isEmpty) return false;
    final l = msg.toLowerCase();
    return l.contains('mediacodec') ||
        l.contains('mediacodecvideorenderer') ||
        l.contains('codecexception') ||
        l.contains('exoplaybackexception') ||
        l.contains('decoder initialization failed') ||
        l.contains('decoder failed') ||
        (l.contains('videoerror') && l.contains('renderer')) ||
        (l.contains('platformexception') &&
            l.contains('video') &&
            l.contains('mediacodec')) ||
        (l.contains('video/mp2t') && l.contains('renderer'));
  }

  final _settings = Get.find<AppSettingsService>();
  final _dio = Dio();

  BetterPlayerController? better;

  Player? _mediaKitPlayer;
  StreamSubscription<String?>? _mediaKitErrorSub;
  final List<StreamSubscription<dynamic>> _mediaKitDimSubs = [];

  /// MediaKit aktifken [UniversalVideoPlayer] üzerinden [Player] örneği.
  Player? get mediaKitPlayer => _mediaKitPlayer;

  /// [attachMediaKitPlayer] ile Obx yenilemesi (MediaKit OSD widget’ı için).
  final mediaKitAttachEpoch = 0.obs;

  /// OSD çözünürlük rozeti için Obx tetikleyici.
  final osdQualityStamp = 0.obs;

  int _lastOsdQualitySignature = -1;

  final Rxn<String> error = Rxn<String>();
  final isBusy = true.obs;

  /// TV cam OSD görünür mü; kanal değişiminde `isBusy` iken üst üste korunur.
  final RxBool tvOsdVisible = true.obs;

  /// TV: hızlı kanal şeridi açıkken OSD kapansa bile ana oynatıcı odağı şeridi ele geçirmesin.
  final RxBool liveChannelStripOverlayOpen = false.obs;

  /// Ayarlarda MediaKit kapalıyken, bu oturumda yedek motora geçildi mi (otomatik veya OSD).
  final RxBool mediaKitFallbackSession = false.obs;

  /// OSD ile Better’a geçildi (ayar MediaKit olsa bile bu oturumda Exo kullanılır).
  final RxBool betterOsdOverride = false.obs;

  /// Kumanda ile hızlı kanal değişiminde son duraklamadan 500ms sonra tek [zapTo].
  Timer? _zapRelativeDebounceTimer;
  int _zapRelativePendingDelta = 0;

  /// TV: yayın hazır olduktan sonra OSD’yi kapatmak (kanal değişiminde yeniden kurulur).
  Timer? _tvOsdAutoHideTimer;

  static const Duration _tvOsdHideAfterPlayback = Duration(seconds: 4);

  /// Ağ kesintisi / geçici kaynak hatalarında aynı yayına yeniden bağlanma.
  Timer? _networkAutoResumeTimer;
  int _networkResumeAttempt = 0;

  /// Canlı (Exo): uzun süre takılı tampon → yeniden bağlan dene.
  Timer? _liveStallWatchdogTimer;

  /// TV + canlı + Better: 15 sn kesintisiz tampon → yeniden bağlan; tekrarında MediaKit.
  Timer? _liveTvStallPollTimer;
  DateTime? _liveTvBufferingSince;
  int _liveTvStallRecoveryAttempts = 0;
  Timer? _liveTvStartupWatchdog;

  final isFading = false.obs;
  final decoderFallbackStep = 0.obs;
  final videoFit = BoxFit.fill.obs;
  bool _recovering = false;
  /// Canlıda kullanıcı OSD’den duraklattıysa [play] yalnızca devam ettirir; yayın kesildiyse tam yeniden yükleme yapılır.
  bool _userPausedLive = false;
  bool _forceSoftwareVideoDecoder = false;
  bool _vodTriedSoftwareDecoder = false;

  /// Android: sistem PiP / [onPause] girişi ile [pause] yarışmasını kısa süre engellemek için.
  bool _suppressPauseForAndroidMiniPip = false;
  Timer? _androidPipFallbackPauseTimer;
  Worker? _pipAutoEnterWorker;

  /// Kullanıcı OSD'den sabit kalite seçtiyse otomatik düşürmeyi yapma.
  bool _manualVideoQualityLock = false;

  /// Tekrarlayan tamponlamada otomatik kalite düşürme (HLS/DASH çoklu varyant).
  static const Duration _autoQBufferingWindow = Duration(seconds: 22);
  static const int _autoQBufferingStartsNeeded = 3;
  static const Duration _autoQDowngradeCooldown = Duration(seconds: 35);
  static const Duration _autoQIgnoreBufferingBefore = Duration(seconds: 4);
  final List<DateTime> _autoQRecentBufferingStarts = [];
  DateTime? _autoQLastDowngradeAt;
  DateTime? _autoQPlaybackStartedAt;

  /// Xtream panellerinde `get.php?...&output=ts` bazen ExoPlayer/Media3 tarafında
  /// `Source error` üretebiliyor. Bu durumda aynı yayını `live/.../$id.ts`
  /// formatına çevirip bir kez daha deniyoruz.
  bool _xtreamTriedLiveUrlFormat = false;
  bool _xtreamTriedOutputM3u8 = false;

  /// Birincil URL `/live/...` iken hata olursa bir kez `get.php?...` dene.
  bool _xtreamTriedGetPhpFallback = false;

  /// MediaCodec hatasında MPEG-TS yerine HLS (m3u8) bir kez dene.
  bool _decoderTriedTsToM3u8Swap = false;

  /// Son oynatılan URL (decoder kurtarma için TS→m3u8 vb.).
  String? _lastPlaybackUrl;

  /// Tek seferlik retry için oynatma URL'sini override eder.
  String? _playUrlOverride;

  // Kayıt özellikleri
  final isRecording = false.obs;
  final recordDuration = 0.obs;
  Timer? _recordTimer;
  CancelToken? _recordCancelToken;
  String? _lastRecordPath;

  List<BetterPlayerAsmsTrack> get availableTracks =>
      better?.betterPlayerAsmsTracks ?? [];

  BetterPlayerAsmsTrack? get currentTrack => better?.betterPlayerAsmsTrack;

  List<BetterPlayerAsmsAudioTrack> get availableAudioTracks =>
      better?.betterPlayerAsmsAudioTracks ?? [];

  BetterPlayerAsmsAudioTrack? get currentAudioTrack =>
      better?.betterPlayerAsmsAudioTrack;

  List<BetterPlayerSubtitlesSource> get availableSubtitleSources =>
      better?.betterPlayerSubtitlesSourceList ?? const [];

  BetterPlayerSubtitlesSource? get currentSubtitleSource =>
      better?.betterPlayerSubtitlesSource;

  Future<void> setBetterSubtitleSource(
    BetterPlayerSubtitlesSource src, {
    bool disableEmbeddedExoSubtitles = true,
  }) async {
    final b = better;
    if (b == null) return;
    try {
      await b.setupSubtitleSource(src, sourceInitialize: true);
    } catch (_) {}
    if (!disableEmbeddedExoSubtitles) return;
    if (!canQueryExoNativeTracks) return;
    final t = src.type;
    if (t != null && t != BetterPlayerSubtitlesSourceType.none) {
      await disableExoNativeTextTracks();
    }
  }

  List<ExoNativeTrackOption> _parseExoTrackList(dynamic list) {
    if (list is! List) return const [];
    final out = <ExoNativeTrackOption>[];
    for (final e in list) {
      if (e is! Map) continue;
      final m = <String, dynamic>{};
      e.forEach((k, v) => m[k.toString()] = v);
      final gi = m['tracksGroupIndex'];
      final ti = m['trackIndex'];
      final tt = m['trackType'];
      int? g;
      int? t;
      var type = 0;
      if (gi is int) {
        g = gi;
      } else if (gi is num) {
        g = gi.toInt();
      }
      if (ti is int) {
        t = ti;
      } else if (ti is num) {
        t = ti.toInt();
      }
      if (tt is int) {
        type = tt;
      } else if (tt is num) {
        type = tt.toInt();
      }
      if (g == null || t == null) continue;
      out.add(
        ExoNativeTrackOption(
          tracksGroupIndex: g,
          trackIndex: t,
          trackType: type,
          label: m['label'] as String? ?? '',
          language: m['language'] as String? ?? '',
          selected: m['selected'] == true,
        ),
      );
    }
    return out;
  }

  Future<ExoNativeTracksBundle> loadExoNativeTracks() async {
    if (!canQueryExoNativeTracks) return ExoNativeTracksBundle.empty;
    try {
      final raw = await better!.getExoPlayerTracks();
      if (raw == null) return ExoNativeTracksBundle.empty;
      final audio = _parseExoTrackList(raw['audio']);
      final text = _parseExoTrackList(raw['text']);
      return ExoNativeTracksBundle(audio: audio, text: text);
    } catch (_) {
      return ExoNativeTracksBundle.empty;
    }
  }

  Future<void> selectExoNativeAudioTrack(ExoNativeTrackOption opt) async {
    if (!canQueryExoNativeTracks) return;
    try {
      await better!.selectExoPlayerTrack(opt.tracksGroupIndex, opt.trackIndex);
    } catch (_) {}
  }

  Future<void> selectExoNativeTextTrack(ExoNativeTrackOption opt) async {
    if (!canQueryExoNativeTracks) return;
    try {
      await setBetterSubtitleSource(
        BetterPlayerSubtitlesSource(type: BetterPlayerSubtitlesSourceType.none),
        disableEmbeddedExoSubtitles: false,
      );
      better!.setExoEmbeddedSubtitlesActive(true);
      await better!.selectExoPlayerTrack(opt.tracksGroupIndex, opt.trackIndex);
    } catch (_) {}
  }

  Future<void> disableExoNativeTextTracks() async {
    if (!canQueryExoNativeTracks) return;
    try {
      better?.setExoEmbeddedSubtitlesActive(false);
      await better!.setExoPlayerTextTrackDisabled(true);
    } catch (_) {}
  }

  /// MediaKit altyazı parçaları; `no` = kapalı.
  Map<String, String> mediaKitSubtitleTrackLabels() {
    final player = _mediaKitPlayer;
    if (player == null) return {};
    final off = 'player.subtitle.off'.tr;
    final out = <String, String>{'no': off};
    for (final t in player.state.tracks.subtitle) {
      if (t.id == 'no' || t.id == 'auto') continue;
      final label = (t.title?.trim().isNotEmpty == true)
          ? t.title!.trim()
          : (t.language?.trim().isNotEmpty == true)
              ? t.language!.trim()
              : t.id;
      out[t.id] = label;
    }
    return out;
  }

  Future<void> setMediaKitSubtitleById(String id) async {
    final player = _mediaKitPlayer;
    if (player == null) return;
    try {
      if (id == 'no') {
        await player.setSubtitleTrack(SubtitleTrack.no());
        return;
      }
      SubtitleTrack? picked;
      for (final e in player.state.tracks.subtitle) {
        if (e.id == id) {
          picked = e;
          break;
        }
      }
      final t = picked;
      if (t == null) return;
      await player.setSubtitleTrack(t);
    } catch (_) {}
  }

  Future<void> enterPictureInPictureIfSupported() async {
    if (effectiveUseMediaKit) return;
    final b = better;
    final k = b?.betterPlayerGlobalKey;
    if (b == null || k == null) return;
    try {
      await b.enablePictureInPicture(k);
    } catch (e) {
      debugPrint('mina_iptv: PiP: $e');
    }
  }

  bool _eligibleForMiniPlayerPip() {
    if (!_settings.miniPlayerOnHome.value) return false;
    if (_settings.layoutMode.value == AppLayoutMode.tv) return false;
    if (effectiveUseMediaKit) return false;
    final b = better;
    final k = b?.betterPlayerGlobalKey;
    final v = b?.videoPlayerController?.value;
    return b != null &&
        k != null &&
        v != null &&
        v.isPlaying &&
        !v.hasError;
  }

  Future<void> _syncAndroidPipAutoEnterEligible() async {
    if (!Platform.isAndroid) return;
    final eligible = _eligibleForMiniPlayerPip();
    try {
      await _androidPipChannel.invokeMethod<void>(
        'setPipAutoEnterEligible',
        <String, dynamic>{'eligible': eligible},
      );
    } catch (e) {
      debugPrint('mina_iptv: setPipAutoEnterEligible: $e');
    }
  }

  /// OSD sol şerit: 4K / FHD / HD / SD (akış boyutuna göre).
  String? get osdStreamQualityLabel {
    final asms = better?.betterPlayerAsmsTrack;
    if (asms != null && (asms.height ?? 0) > 0) {
      return _streamQualityLabelFromDimensions(asms.height!, asms.width ?? 0);
    }
    final sz = better?.videoPlayerController?.value.size;
    if (sz != null && sz.width > 0 && sz.height > 0) {
      return _streamQualityLabelFromDimensions(
        sz.height.round(),
        sz.width.round(),
      );
    }
    final mk = _mediaKitPlayer;
    if (mk != null) {
      final w = mk.state.width;
      final h = mk.state.height;
      if (w != null && h != null && w > 0 && h > 0) {
        return _streamQualityLabelFromDimensions(h, w);
      }
    }
    return null;
  }

  static String? _streamQualityLabelFromDimensions(int height, int width) {
    final dim = math.max(height, width);
    if (dim <= 0) return null;
    if (dim >= 2160) return '4K';
    if (dim >= 1080) return 'FHD';
    if (dim >= 720) return 'HD';
    if (dim >= 480) return 'SD';
    return 'SD';
  }

  void _maybeBumpOsdQualitySignature() {
    final s = _osdQualitySignature();
    if (s != _lastOsdQualitySignature) {
      _lastOsdQualitySignature = s;
      osdQualityStamp.value++;
      update(['osd']);
    }
  }

  int _osdQualitySignature() {
    final t = better?.betterPlayerAsmsTrack;
    final sz = better?.videoPlayerController?.value.size;
    final mk = _mediaKitPlayer;
    final mkW = mk?.state.width;
    final mkH = mk?.state.height;
    return Object.hash(
      t?.id,
      t?.height,
      t?.width,
      sz != null && sz.width > 0 ? sz.width.round() : 0,
      sz != null && sz.height > 0 ? sz.height.round() : 0,
      mkW != null && mkW > 0 ? mkW : 0,
      mkH != null && mkH > 0 ? mkH : 0,
    );
  }

  void setQuality(BetterPlayerAsmsTrack track) {
    final auto = (track.height ?? 0) <= 0 &&
        (track.width ?? 0) <= 0 &&
        (track.bitrate ?? 0) <= 0;
    _manualVideoQualityLock = !auto;
    if (auto) {
      _autoQRecentBufferingStarts.clear();
      _autoQLastDowngradeAt = null;
    }
    better?.setTrack(track);
    _maybeBumpOsdQualitySignature();
    update(['osd']);
  }

  void setVideoFit(BoxFit fit) {
    videoFit.value = fit;
    better?.setOverriddenFit(fit);
    update(['osd']);
  }

  /// O anki kanal URL’sine göre canlı mı (film/dizi yolu değil).
  bool get _currentStreamIsLive {
    final norm =
        IptvPlaybackDefaults.normalizeStreamUrl(channel.value.streamUrl);
    return IptvPlaybackDefaults.isLikelyLiveStream(norm);
  }

  /// Better (Exo) + oturum yedeği: gerçekten MediaKit kullanılıyor mu.
  /// Canlı yayınlarda varsayılan Better; MediaKit yalnızca OSD/hata yedeği.
  /// Film/dizide [AppSettingsService.useMediaKit] ve yedek oturum geçerlidir.
  bool get effectiveUseMediaKit {
    if (betterOsdOverride.value) return false;
    if (_currentStreamIsLive) {
      return mediaKitFallbackSession.value;
    }
    return _settings.useMediaKit.value || mediaKitFallbackSession.value;
  }

  /// Android Better: ExoPlayer [currentTracks] ile gömülü ses/altyazı sorgulanabilir.
  bool get canQueryExoNativeTracks =>
      Platform.isAndroid &&
      !effectiveUseMediaKit &&
      better?.videoPlayerController != null;

  /// OSD: MediaKit’e geç (Better’dan veya Better OSD geçersiz kılma sonrası).
  Future<void> switchToBackupPlayer() async {
    final wasBetterOverride = betterOsdOverride.value;
    betterOsdOverride.value = false;
    if (!wasBetterOverride && effectiveUseMediaKit) {
      return;
    }
    if (!_settings.useMediaKit.value || _currentStreamIsLive) {
      mediaKitFallbackSession.value = true;
    }
    await _performMediaKitFallbackBoot();
  }

  /// OSD: Better/Exo’ya geç (MediaKit ayarı açık olsa bile bu oturumda).
  Future<void> switchToBetterPlayer() async {
    betterOsdOverride.value = true;
    mediaKitFallbackSession.value = false;
    error.value = null;
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: false,
    );
  }

  void _cancelMediaKitDimSubs() {
    for (final s in _mediaKitDimSubs) {
      unawaited(s.cancel());
    }
    _mediaKitDimSubs.clear();
  }

  void attachMediaKitPlayer(Player? p) {
    if (identical(_mediaKitPlayer, p)) return;

    _mediaKitErrorSub?.cancel();
    _mediaKitErrorSub = null;
    _cancelMediaKitDimSubs();

    _mediaKitPlayer = p;

    if (p != null) {
      _mediaKitErrorSub = p.stream.error.listen((e) {
        if (e.isNotEmpty) {
          _emitPlaybackErrorForRecovery(e);
        }
      });
      void dimBump([dynamic _]) {
        _maybeBumpOsdQualitySignature();
        update(['osd']);
      }

      _mediaKitDimSubs.add(p.stream.width.listen(dimBump));
      _mediaKitDimSubs.add(p.stream.height.listen(dimBump));
      _mediaKitDimSubs.add(p.stream.track.listen(dimBump));

      unawaited(p.setVolume(100.0).catchError((_, __) {}));
    }

    _maybeBumpOsdQualitySignature();
    mediaKitAttachEpoch.value++;
    update(['osd']);
    if (Platform.isAndroid) {
      unawaited(_syncAndroidPipAutoEnterEligible());
    }
  }

  Map<String, String> mediaKitAudioTrackLabels() {
    final player = _mediaKitPlayer;
    if (player == null) return {};
    final out = <String, String>{};
    for (final t in player.state.tracks.audio) {
      final label = (t.title?.trim().isNotEmpty == true)
          ? t.title!.trim()
          : (t.language?.trim().isNotEmpty == true)
              ? t.language!.trim()
              : t.id;
      out[t.id] = label;
    }
    return out;
  }

  Future<void> setMediaKitAudioTrackById(String id) async {
    final player = _mediaKitPlayer;
    if (player == null) return;
    AudioTrack? picked;
    for (final e in player.state.tracks.audio) {
      if (e.id == id) {
        picked = e;
        break;
      }
    }
    final t = picked;
    if (t == null) return;
    try {
      await player.setAudioTrack(t);
    } catch (_) {}
  }

  Map<String, String> mediaKitVideoTrackLabels() {
    final player = _mediaKitPlayer;
    if (player == null) return {};
    final out = <String, String>{};
    for (final t in player.state.tracks.video) {
      final dims = (t.w != null && t.h != null && t.w! > 0 && t.h! > 0)
          ? ' (${t.w}×${t.h})'
          : '';
      final base = (t.title?.trim().isNotEmpty == true)
          ? t.title!.trim()
          : (t.codec ?? t.id);
      out[t.id] = '$base$dims';
    }
    return out;
  }

  Future<void> setMediaKitVideoTrackById(String id) async {
    final player = _mediaKitPlayer;
    if (player == null) return;
    VideoTrack? picked;
    for (final e in player.state.tracks.video) {
      if (e.id == id) {
        picked = e;
        break;
      }
    }
    final t = picked;
    if (t == null) return;
    try {
      await player.setVideoTrack(t);
    } catch (_) {}
  }

  bool _isCurrentChannelLive() {
    final norm =
        IptvPlaybackDefaults.normalizeStreamUrl(channel.value.streamUrl);
    return IptvPlaybackDefaults.isLikelyLiveStream(norm);
  }

  /// Aynı kanalı baştan yükler (canlı kesinti / takılı Exo durumu).
  Future<void> restartCurrentStream() async {
    if (isClosed) return;
    _resetNetworkRecoveryState();
    error.value = null;
    _userPausedLive = false;
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: true,
    );
  }

  double get currentVolume {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      return (mk.state.volume.clamp(0.0, 100.0)) / 100.0;
    }
    return better?.videoPlayerController?.value.volume ?? 1.0;
  }

  Duration get currentPosition {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      return mk.state.position;
    }
    return better?.videoPlayerController?.value.position ?? Duration.zero;
  }

  void play() {
    if (isBusy.value) {
      final mk = _mediaKitPlayer;
      if (mk != null) {
        unawaited(mk.play().catchError((_, __) {}));
      } else {
        better?.play();
      }
      return;
    }

    final mk = _mediaKitPlayer;
    if (mk != null) {
      if (_isCurrentChannelLive()) {
        if (_userPausedLive) {
          _userPausedLive = false;
          unawaited(mk.play().catchError((_, __) {}));
          return;
        }
        final s = mk.state;
        if (!s.playing && !s.buffering) {
          unawaited(restartCurrentStream());
          return;
        }
      } else {
        _userPausedLive = false;
      }
      unawaited(mk.play().catchError((_, __) {}));
      return;
    }

    if (_isCurrentChannelLive()) {
      if (_userPausedLive) {
        _userPausedLive = false;
        better?.play();
        return;
      }
      final v = better?.videoPlayerController?.value;
      if (v != null &&
          v.initialized &&
          !v.hasError &&
          !v.isPlaying &&
          !v.isBuffering) {
        unawaited(restartCurrentStream());
        return;
      }
    } else {
      _userPausedLive = false;
    }
    better?.play();
  }

  void pause() {
    if (_isCurrentChannelLive()) {
      _userPausedLive = true;
    } else {
      _userPausedLive = false;
    }
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(mk.pause().catchError((_, __) {}));
      return;
    }
    better?.pause();
  }

  void seekTo(Duration position) {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(mk.seek(position).catchError((_, __) {}));
      return;
    }
    better?.seekTo(position);
  }

  void setVolume(double value01) {
    final v = value01.clamp(0.0, 1.0);
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(mk.setVolume(v * 100.0).catchError((_, __) {}));
      return;
    }
    better?.setVolume(v);
  }

  void setSpeed(double value) {
    better?.setSpeed(value);
  }

  /// Aynı native Exo örneği ve [VideoPlayerController] ile yeni URL yüklenirken
  /// tampon/decoder yeniden kurulumunu sınırlamak için (Android: stop + clearMediaItems + setMediaSource).
  bool _canReuseBetterForDataSource(BetterPlayerDataSource newDs) {
    final vpc = better?.videoPlayerController;
    if (vpc == null) return false;
    final o = vpc.bufferingConfiguration;
    final n = newDs.bufferingConfiguration;
    return o.preferSoftwareVideoDecoder == n.preferSoftwareVideoDecoder &&
        o.minBufferMs == n.minBufferMs &&
        o.maxBufferMs == n.maxBufferMs &&
        o.bufferForPlaybackMs == n.bufferForPlaybackMs &&
        o.bufferForPlaybackAfterRebufferMs ==
            n.bufferForPlaybackAfterRebufferMs;
  }

  /// [zapTo] öncesi: motor değişmeyecekse Better örneğini dispose etme.
  bool _shouldReuseBetterOnChannelChange(Channel newCh) {
    if (better == null) return false;

    final nextNormalized =
        IptvPlaybackDefaults.normalizeStreamUrl(newCh.streamUrl);
    if (nextNormalized.isEmpty) return false;

    final nextLive = IptvPlaybackDefaults.isLikelyLiveStream(nextNormalized);
    final lp = nextNormalized.toLowerCase();
    final tsLiveAndroid = nextLive &&
        Platform.isAndroid &&
        _settings.layoutMode.value != AppLayoutMode.tv &&
        (lp.split('?').first.endsWith('.ts') || lp.contains('output=ts'));

    final isTv = _settings.layoutMode.value == AppLayoutMode.tv;
    final nextDs = iptvBetterPlayerDataSource(
      nextNormalized,
      liveStream: nextLive,
      cacheConfiguration: null,
      useAsmsTracks: null,
      useAsmsAudioTracks: null,
      useAsmsSubtitles: null,
      preferSoftwareVideoDecoder:
          (nextLive ? _settings.preferSoftwareVideoDecoder.value : false) ||
              tsLiveAndroid,
      tvBoxLiveOptimize: isTv && nextLive,
    );
    return _canReuseBetterForDataSource(nextDs);
  }

  void _applyPreferredMaxHeightToBetter(
    BetterPlayerController ctrl, {
    required int? preferredMaxHeight,
    required bool disableAsms,
  }) {
    if (disableAsms || preferredMaxHeight == null) return;
    final tracks = List<BetterPlayerAsmsTrack>.from(ctrl.betterPlayerAsmsTracks)
      ..removeWhere((t) => (t.height ?? 0) <= 0);
    if (tracks.isEmpty) return;
    tracks.sort((a, b) => (a.height ?? 0).compareTo(b.height ?? 0));
    BetterPlayerAsmsTrack? chosen;
    for (var i = tracks.length - 1; i >= 0; i--) {
      final h = tracks[i].height ?? 0;
      if (h > 0 && h <= preferredMaxHeight) {
        chosen = tracks[i];
        break;
      }
    }
    chosen ??= tracks.first;
    ctrl.setTrack(chosen);
  }

  /// Eski yayının sesi karartma beklenmeden kesilsin (hızlı kanal değişimi).
  void _silenceCurrentPlaybackImmediately() {
    final mk = _mediaKitPlayer;
    if (mk != null) {
      unawaited(
        mk.pause().then((_) => mk.setVolume(0.0)).catchError((_, __) {}),
      );
    }
    final b = better;
    if (b != null) {
      unawaited(
        b.stop().then((_) => b.setVolume(0)).catchError((_, __) {}),
      );
    }
  }

  void _cancelZapRelativeDebounce() {
    _zapRelativeDebounceTimer?.cancel();
    _zapRelativeDebounceTimer = null;
    _zapRelativePendingDelta = 0;
  }

  /// Ok tuşu ile hızlı gezinme: 500ms durulunca biriken adımlar tek seferde uygulanır.
  void zapRelativeDebounced(int delta) {
    _zapRelativePendingDelta += delta;
    _zapRelativeDebounceTimer?.cancel();
    _zapRelativeDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      final d = _zapRelativePendingDelta;
      _zapRelativePendingDelta = 0;
      _zapRelativeDebounceTimer = null;
      if (d == 0) return;
      unawaited(zapRelative(d));
    });
  }

  void _cancelTvOsdAutoHideTimer() {
    _tvOsdAutoHideTimer?.cancel();
    _tvOsdAutoHideTimer = null;
  }

  /// TV cam OSD: sabit yayın yüklendikten `_tvOsdHideAfterPlayback` sonra gizle.
  /// Kumanda/etkileşimde tekrar başlatmak için de çağrılır.
  void scheduleTvOsdAutoHide() {
    if (_settings.layoutMode.value != AppLayoutMode.tv) return;
    _cancelTvOsdAutoHideTimer();
    _tvOsdAutoHideTimer = Timer(_tvOsdHideAfterPlayback, () {
      _tvOsdAutoHideTimer = null;
      tvOsdVisible.value = false;
    });
  }

  /// TV: uzun OK ile kanal şeridi açılırken cam OSD’yi hemen gizle.
  void hideTvOsdNow() {
    if (_settings.layoutMode.value != AppLayoutMode.tv) return;
    _cancelTvOsdAutoHideTimer();
    tvOsdVisible.value = false;
  }

  void _cancelNetworkAutoResumeTimer() {
    _networkAutoResumeTimer?.cancel();
    _networkAutoResumeTimer = null;
  }

  void _cancelLiveStallWatchdog() {
    _liveStallWatchdogTimer?.cancel();
    _liveStallWatchdogTimer = null;
    _liveTvStallPollTimer?.cancel();
    _liveTvStallPollTimer = null;
    _liveTvBufferingSince = null;
  }

  void _cancelLiveTvStartupWatchdog() {
    _liveTvStartupWatchdog?.cancel();
    _liveTvStartupWatchdog = null;
  }

  void _resetNetworkRecoveryState() {
    _cancelNetworkAutoResumeTimer();
    _networkResumeAttempt = 0;
  }

  Duration _networkResumeDelayForAttempt() {
    const steps = [1, 3, 6, 12, 24];
    final i = _networkResumeAttempt.clamp(0, steps.length - 1);
    return Duration(seconds: steps[i]);
  }

  void _scheduleNetworkAutoResumeIfNeeded(String msg) {
    if (!_isLikelyNetworkOrTransientError(msg)) return;
    if (_recovering) return;
    _networkAutoResumeTimer?.cancel();
    final d = _networkResumeDelayForAttempt();
    debugPrint(
      'mina_iptv: Network recovery in ${d.inSeconds}s (attempt idx $_networkResumeAttempt)',
    );
    _networkAutoResumeTimer = Timer(d, () {
      _networkAutoResumeTimer = null;
      unawaited(_performNetworkResume());
    });
  }

  void _emitPlaybackErrorForRecovery(String msg) {
    error.value = msg;
    _scheduleNetworkAutoResumeIfNeeded(msg);
  }

  Future<void> _performNetworkResume() async {
    if (isClosed) return;
    if (_recovering) {
      _scheduleNetworkAutoResumeIfNeeded(error.value ?? 'connection');
      return;
    }
    _cancelNetworkAutoResumeTimer();
    error.value = null;
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: true,
    );
    if (error.value != null && _isLikelyNetworkOrTransientError(error.value!)) {
      _networkResumeAttempt = (_networkResumeAttempt + 1).clamp(0, 8);
      _scheduleNetworkAutoResumeIfNeeded(error.value!);
    } else {
      _networkResumeAttempt = 0;
    }
  }

  static const Duration _liveTvStallThreshold = Duration(seconds: 15);

  void _armLiveTvStartupWatchdog() {
    if (_settings.layoutMode.value != AppLayoutMode.tv) return;
    if (effectiveUseMediaKit) return;
    final norm =
        IptvPlaybackDefaults.normalizeStreamUrl(channel.value.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) return;

    _liveTvStartupWatchdog?.cancel();
    _liveTvStartupWatchdog = Timer(_liveTvStallThreshold, () {
      _liveTvStartupWatchdog = null;
      if (isClosed || effectiveUseMediaKit) return;
      final v = better?.videoPlayerController?.value;
      if (v == null) return;
      final ok = v.isPlaying && !v.isBuffering && !v.hasError;
      if (ok) return;
      debugPrint(
        'mina_iptv: TV live Better — ${_liveTvStallThreshold.inSeconds}s startup, stabil oynatma yok',
      );
      unawaited(_handleLiveTvStallRecovery());
    });
  }

  Future<void> _handleLiveTvStallRecovery() async {
    if (isClosed) return;
    if (_settings.layoutMode.value != AppLayoutMode.tv) return;
    if (effectiveUseMediaKit) return;
    final norm =
        IptvPlaybackDefaults.normalizeStreamUrl(channel.value.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) return;

    _liveTvStallRecoveryAttempts++;
    if (_liveTvStallRecoveryAttempts <= 1) {
      debugPrint(
        'mina_iptv: TV live takılma → yeniden bağlan ($_liveTvStallRecoveryAttempts. deneme)',
      );
      _resetNetworkRecoveryState();
      await _performNetworkResume();
      return;
    }
    _liveTvStallRecoveryAttempts = 0;
    debugPrint('mina_iptv: TV live takılma → MediaKit');
    betterOsdOverride.value = false;
    mediaKitFallbackSession.value = true;
    await _performMediaKitFallbackBoot();
  }

  void _startLiveStallWatchdog() {
    if (better == null) return;
    if (effectiveUseMediaKit) return;
    final norm =
        IptvPlaybackDefaults.normalizeStreamUrl(channel.value.streamUrl);
    if (!IptvPlaybackDefaults.isLikelyLiveStream(norm)) return;

    if (_settings.layoutMode.value == AppLayoutMode.tv) {
      // Ardışık bufferingStart süreyi sıfırlamasın (15 sn ilk takılmadan sayılır).
      if (_liveTvStallPollTimer != null) return;
      _liveTvBufferingSince = DateTime.now();
      _liveTvStallPollTimer =
          Timer.periodic(const Duration(seconds: 1), (_) {
        if (isClosed || better == null || effectiveUseMediaKit) {
          _liveTvStallPollTimer?.cancel();
          _liveTvStallPollTimer = null;
          return;
        }
        final since = _liveTvBufferingSince;
        if (since == null) {
          _liveTvStallPollTimer?.cancel();
          _liveTvStallPollTimer = null;
          return;
        }
        final v = better?.videoPlayerController?.value;
        if (v == null) return;
        if (!v.isBuffering || v.hasError) {
          _liveTvStallPollTimer?.cancel();
          _liveTvStallPollTimer = null;
          _liveTvBufferingSince = null;
          return;
        }
        if (DateTime.now().difference(since) < _liveTvStallThreshold) return;
        _liveTvStallPollTimer?.cancel();
        _liveTvStallPollTimer = null;
        _liveTvBufferingSince = null;
        debugPrint(
          'mina_iptv: TV live ${_liveTvStallThreshold.inSeconds}s tampon takılması',
        );
        unawaited(_handleLiveTvStallRecovery());
      });
      return;
    }

    // Telefon / tablet: uzun tampon → tek seferde yeniden bağlan.
    if (_liveStallWatchdogTimer != null) return;
    _liveStallWatchdogTimer = Timer(const Duration(seconds: 45), () {
      _liveStallWatchdogTimer = null;
      if (isClosed) return;
      final v = better?.videoPlayerController?.value;
      if (v == null) return;
      if (!v.isBuffering || v.hasError) return;
      debugPrint('mina_iptv: Live buffering stall → reconnect');
      _networkResumeAttempt = 0;
      unawaited(_performNetworkResume());
    });
  }

  /// Tüm kanallar listesinde [delta] kadar kaydırarak `zapTo` çağırır (anında; düğmeler için).
  Future<void> zapRelative(int delta) async {
    _cancelZapRelativeDebounce();
    final cur = channel.value;
    final url = cur.streamUrl.toLowerCase();
    final isVod = url.contains('/movie/') || url.contains('/series/');

    if (isVod) {
      final movieTape = _movieBrowseTape;
      if (movieTape != null && movieTape.isNotEmpty) {
        var idx = movieTape.indexWhere((c) => c.id == cur.id);
        if (idx < 0) idx = 0;
        final n = idx + delta;
        if (n < 0 || n >= movieTape.length) return;
        final target = movieTape[n];
        if (target.id == cur.id) return;
        await zapTo(target);
        return;
      }
      final seriesTape = _seriesBrowseTape;
      if (seriesTape != null &&
          seriesTape.isNotEmpty &&
          _playingSeriesInTape != null) {
        var idx =
            seriesTape.indexWhere((s) => s.id == _playingSeriesInTape!.id);
        if (idx < 0) return;
        final n = idx + delta;
        if (n < 0 || n >= seriesTape.length) return;
        final nextSer = seriesTape[n];
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
        return;
      }
      return;
    }

    final cache = Get.find<PlaylistCacheService>();
    final data = cache.result.value;
    if (data == null || data.channels.isEmpty) return;
    final list = List<Channel>.from(data.channels)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final curId = cur.id;
    var idx = list.indexWhere((c) => c.id == curId);
    if (idx < 0) idx = 0;
    final nextIdx = (idx + delta) % list.length;
    final ni = nextIdx < 0 ? nextIdx + list.length : nextIdx;
    final target = list[ni];
    if (target.id == curId) return;
    await zapTo(target);
  }

  Worker? _mediaKitSettingsWorker;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    decoderFallbackStep.value = 0;
    unawaited(WakelockPlus.enable());
    _mediaKitSettingsWorker = ever(_settings.useMediaKit, (_) {
      betterOsdOverride.value = false;
      unawaited(zapTo(channel.value));
    });
    _pipAutoEnterWorker = ever(_settings.miniPlayerOnHome, (_) {
      unawaited(_syncAndroidPipAutoEnterEligible());
    });
    _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_settings.backgroundPlayback.value) return;

    if (state == AppLifecycleState.resumed) {
      _androidPipFallbackPauseTimer?.cancel();
      _androidPipFallbackPauseTimer = null;
      _suppressPauseForAndroidMiniPip = false;
    }

    // iOS: arka plana geçerken PiP dene.
    if (state == AppLifecycleState.paused && !Platform.isAndroid) {
      if (_tryEnterMiniPlayerPipInsteadOfPause()) {
        return;
      }
    }

    // `inactive` yönlendirme / config değişiminde de gelir; burada duraklatmak yayını keser.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final vpc = better?.videoPlayerController?.value;
      if (vpc?.isPip == true) return;

      // Android: Küçük ekran açıkken sistem PiP (setAutoEnterEnabled / onPause) için kısa süre bekle.
      if (Platform.isAndroid && _eligibleForMiniPlayerPip()) {
        _suppressPauseForAndroidMiniPip = true;
        _androidPipFallbackPauseTimer?.cancel();
        _androidPipFallbackPauseTimer =
            Timer(const Duration(milliseconds: 900), () {
          _androidPipFallbackPauseTimer = null;
          _suppressPauseForAndroidMiniPip = false;
          if (_settings.backgroundPlayback.value) return;
          final v = better?.videoPlayerController?.value;
          if (v != null && v.isPip) return;
          final mk = _mediaKitPlayer;
          if (mk != null) {
            unawaited(mk.pause().catchError((_, __) {}));
          } else {
            better?.pause();
          }
        });
        return;
      }

      if (Platform.isAndroid && _suppressPauseForAndroidMiniPip) return;
      final mk = _mediaKitPlayer;
      if (mk != null) {
        unawaited(mk.pause().catchError((_, __) {}));
        return;
      }
      better?.pause();
    }
  }

  /// Ayar açıkken arka plana geçişte PiP dene; başarılıysa duraklatmayı atla (iOS vb.).
  bool _tryEnterMiniPlayerPipInsteadOfPause() {
    if (!_eligibleForMiniPlayerPip()) return false;
    unawaited(enterPictureInPictureIfSupported());
    return true;
  }

  Future<void> zapTo(Channel newChannel) async {
    if (newChannel.id == channel.value.id) return;

    _userPausedLive = false;
    _cancelZapRelativeDebounce();
    _cancelTvOsdAutoHideTimer();
    _resetNetworkRecoveryState();
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    _liveTvStallRecoveryAttempts = 0;

    final newLive = IptvPlaybackDefaults.isLikelyLiveStream(
      IptvPlaybackDefaults.normalizeStreamUrl(newChannel.streamUrl),
    );
    final tvLiveZap = _settings.layoutMode.value == AppLayoutMode.tv && newLive;

    if (tvLiveZap) {
      tvOsdVisible.value = true;
    }

    _silenceCurrentPlaybackImmediately();

    // Canlı kanal değişimi: TV ve telefonda fade yok (VOD’da kısa kararma kalır).
    if (newLive) {
      isFading.value = false;
      await Future.delayed(Duration.zero);
    } else {
      isFading.value = true;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final reuseBetter = _shouldReuseBetterOnChannelChange(newChannel);

    try {
      if (!reuseBetter) {
        final old = better;
        better = null;
        if (old != null) {
          old.videoPlayerController?.removeListener(_onVideoPlayerChanged);
          old.pause();
          old.dispose(forceDispose: true);
        }
      }
    } catch (_) {}

    channel.value = newChannel;
    mediaKitFallbackSession.value = false;
    decoderFallbackStep.value = 0;
    _forceSoftwareVideoDecoder = false;
    _vodTriedSoftwareDecoder = false;
    _xtreamTriedLiveUrlFormat = false;
    _xtreamTriedOutputM3u8 = false;
    _xtreamTriedGetPhpFallback = false;
    _decoderTriedTsToM3u8Swap = false;
    _lastPlaybackUrl = null;
    _playUrlOverride = null;
    _lastOsdQualitySignature = -1;
    osdQualityStamp.value++;
    await _boot(reuseSameBetterPlayer: reuseBetter);

    // Yeni kanal açıldığında aydınlat
    isFading.value = false;
  }

  Future<void> _boot({
    int? preferredMaxHeight,
    bool disableAsms = false,
    bool reuseSameBetterPlayer = false,
    bool suppressNetworkRecoverySchedule = false,
  }) async {
    isBusy.value = true;
    error.value = null;
    _cancelNetworkAutoResumeTimer();
    _manualVideoQualityLock = false;
    _autoQRecentBufferingStarts.clear();
    _autoQLastDowngradeAt = null;
    _autoQPlaybackStartedAt = null;
    try {
      final isTv = _settings.layoutMode.value == AppLayoutMode.tv;
      final orientations = isTv
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : <DeviceOrientation>[];

      final cur = channel.value;
      final normalizedUrl =
          IptvPlaybackDefaults.normalizeStreamUrl(cur.streamUrl);
      final live = IptvPlaybackDefaults.isLikelyLiveStream(normalizedUrl);

      final override = _playUrlOverride;
      _playUrlOverride = null;

      final playUrl = override ??
          (_xtreamTriedLiveUrlFormat
              ? _tryConvertXtreamGetPhpToLiveUrl(normalizedUrl) ?? normalizedUrl
              : normalizedUrl);

      if (playUrl.isNotEmpty) {
        _lastPlaybackUrl = playUrl;
      }

      final lp = playUrl.toLowerCase();
      final tsLiveAndroid = live &&
          Platform.isAndroid &&
          _settings.layoutMode.value != AppLayoutMode.tv &&
          (lp.split('?').first.endsWith('.ts') || lp.contains('output=ts'));

      debugPrint(
          'mina_iptv: Playing stream: $playUrl (Step: ${decoderFallbackStep.value}, XtreamAlt: $_xtreamTriedLiveUrlFormat)');

      if (playUrl.isEmpty) {
        error.value = 'Geçersiz yayın adresi';
        return;
      }

      // Android TV / Xiaomi'de çökmelere yol açtığı için disk önbelleği tamamen devre dışı.
      final ds = iptvBetterPlayerDataSource(
        playUrl,
        liveStream: live,
        cacheConfiguration: null,
        useAsmsTracks: disableAsms ? false : null,
        useAsmsAudioTracks: null, // Otomatik seçime (Adaptive tespiti) bırak
        useAsmsSubtitles: disableAsms ? false : null,
        preferSoftwareVideoDecoder: _forceSoftwareVideoDecoder ||
            (live ? _settings.preferSoftwareVideoDecoder.value : false) ||
            tsLiveAndroid,
        tvBoxLiveOptimize: isTv && live,
      );

      debugPrint('mina_iptv: DataSource headers: ${ds.headers}');

      if (effectiveUseMediaKit) {
        // MediaKit (ayar veya yedek oturum): BetterPlayer'ı tamamen temizle.
        final old = better;
        better = null;
        if (old != null) {
          old.videoPlayerController?.removeListener(_onVideoPlayerChanged);
          old.pause();
          old.dispose(forceDispose: true);
        }
        isBusy.value = false;
        return;
      }

      if (reuseSameBetterPlayer &&
          better != null &&
          _canReuseBetterForDataSource(ds)) {
        final ctrl = better!;
        ctrl.setOverriddenFit(videoFit.value);
        await ctrl.setupDataSource(ds);
        _applyPreferredMaxHeightToBetter(
          ctrl,
          preferredMaxHeight: preferredMaxHeight,
          disableAsms: disableAsms,
        );
        await ctrl.play();
        _autoQPlaybackStartedAt = DateTime.now();
        ctrl.setVolume(1.0);
        if (isTv && live) {
          _armLiveTvStartupWatchdog();
        }
        if (Platform.isAndroid && !live) {
          _scheduleAndroidVodAudioFix(ctrl);
        }
        return;
      }

      if (reuseSameBetterPlayer && better != null) {
        try {
          better!.videoPlayerController?.removeListener(_onVideoPlayerChanged);
          await better!.pause();
          better!.dispose(forceDispose: true);
        } catch (_) {}
        better = null;
      }

      // Ağ/stall kurtarma ve benzeri yollar `reuseSameBetterPlayer: false` ile _boot
      // çağırırken eski ExoPlayer'ı atlamış oluyordu; ikinci ses + çıkış sonrası ses
      // (özellikle Amlogic TV kutularında) bu yüzden oluşabiliyordu.
      if (!reuseSameBetterPlayer && better != null) {
        try {
          better!.videoPlayerController?.removeListener(_onVideoPlayerChanged);
          await better!.pause();
          better!.dispose(forceDispose: true);
        } catch (_) {}
        better = null;
      }

      final controls = IptvBetterPlayerConfig.tvControls(
        customControlsBuilder: (c, onVisibilityChanged, config) =>
            TvBetterPlayerControls(
          controller: c,
          onPlayerVisibilityChanged: (v) {
            tvOsdVisible.value = v;
            onVisibilityChanged(v);
          },
        ),
      );

      final cfg = IptvBetterPlayerConfig.playerConfiguration(
        controls: controls,
        eventListener: _onBetterPlayerEvent,
        handleLifecycle: false,
        autoDispose: false,
        deviceOrientationsOnFullScreen: orientations,
        deviceOrientationsAfterFullScreen: orientations,
      );

      final ctrl = BetterPlayerController(cfg);
      ctrl.setOverriddenFit(videoFit.value);
      await ctrl.setupDataSource(ds);
      _applyPreferredMaxHeightToBetter(
        ctrl,
        preferredMaxHeight: preferredMaxHeight,
        disableAsms: disableAsms,
      );
      better = ctrl;

      // Native hataları yakalamak için VideoPlayerController'ı dinle
      ctrl.videoPlayerController?.addListener(_onVideoPlayerChanged);

      await ctrl.play();
      _autoQPlaybackStartedAt = DateTime.now();
      ctrl.setVolume(1.0);
      if (isTv && live) {
        _armLiveTvStartupWatchdog();
      }

      // Film/dizi (VOD): telefonda AC3 öncelikli parça sessiz kalabiliyor; mix + AAC seçimi tekrarlanır.
      if (Platform.isAndroid && !live) {
        _scheduleAndroidVodAudioFix(ctrl);
      }
    } catch (e) {
      final s = e.toString();
      error.value = s;
      if (!suppressNetworkRecoverySchedule) {
        _scheduleNetworkAutoResumeIfNeeded(s);
      }
    } finally {
      isBusy.value = false;
      if (error.value == null) {
        _networkResumeAttempt = 0;
      }
      if (_settings.layoutMode.value == AppLayoutMode.tv &&
          error.value == null) {
        scheduleTvOsdAutoHide();
      }
      if (Platform.isAndroid) {
        unawaited(_syncAndroidPipAutoEnterEligible());
      }
    }
  }

  /// HLS ses listesi geç geldiğinde veya ilk seçim yanlış olduğunda tekrar dene.
  void _scheduleAndroidVodAudioFix(BetterPlayerController c) {
    void tryFix() {
      if (better != c) return;
      try {
        c.setMixWithOthers(false);
      } catch (_) {}
      final tracks = c.betterPlayerAsmsAudioTracks;
      if (tracks == null || tracks.isEmpty) return;
      int score(BetterPlayerAsmsAudioTrack t) {
        final s = '${t.label ?? ''} ${t.language ?? ''} ${t.mimeType ?? ''}'
            .toLowerCase();
        var n = 0;
        if (s.contains('aac') ||
            s.contains('mp4a') ||
            s.contains('audio/mp4')) {
          n += 14;
        }
        if (s.contains('opus')) n += 10;
        if (s.contains('mp3') || s.contains('mpeg')) n += 6;
        if (s.contains('ac3') ||
            s.contains('ac-3') ||
            s.contains('eac3') ||
            s.contains('dts')) {
          n -= 12;
        }
        return n;
      }

      var chosen = tracks.first;
      for (var i = 1; i < tracks.length; i++) {
        if (score(tracks[i]) > score(chosen)) chosen = tracks[i];
      }
      try {
        c.setAudioTrack(chosen);
      } catch (_) {}
    }

    Future<void>.delayed(const Duration(milliseconds: 450), tryFix);
    Future<void>.delayed(const Duration(seconds: 2), tryFix);
  }

  void handleBack() {
    Get.back();
    if (openedFromBrowse) {
      if (Get.isRegistered<BrowseController>()) {
        Get.find<BrowseController>().restoreBrowseListFocusAfterPlayerPop();
      }
    } else {
      if (Get.isRegistered<ChannelsController>()) {
        Get.find<ChannelsController>().restoreChannelListFocusAfterPlayerPop();
      }
    }
  }

  void _onBetterPlayerEvent(BetterPlayerEvent event) {
    if (event.betterPlayerEventType == BetterPlayerEventType.exception) {
      final ex = event.parameters?['exception'];
      if (ex != null && ex.toString().isNotEmpty) {
        final msg = ex.toString();
        if (_shouldAutoFallbackToMediaKit(msg)) {
          debugPrint(
            'mina_iptv: BetterPlayer exception → MediaKit yedek: $msg',
          );
          betterOsdOverride.value = false;
          mediaKitFallbackSession.value = true;
          unawaited(_performMediaKitFallbackBoot());
          return;
        }
        _emitPlaybackErrorForRecovery(msg);
      }
      return;
    }
    if (event.betterPlayerEventType == BetterPlayerEventType.bufferingStart) {
      _maybeAutoDowngradeQualityOnBufferingStress();
      _startLiveStallWatchdog();
    }
    if (event.betterPlayerEventType == BetterPlayerEventType.bufferingEnd) {
      _cancelLiveStallWatchdog();
      final v = better?.videoPlayerController?.value;
      if (v != null && v.isPlaying && !v.hasError) {
        _liveTvStallRecoveryAttempts = 0;
      }
    }
  }

  /// Aynı yayında kısa sürede birden fazla tampon başlangıcı olursa bir alt HLS/DASH varyantına in.
  void _maybeAutoDowngradeQualityOnBufferingStress() {
    final c = better;
    if (c == null || isBusy.value) return;
    if (_manualVideoQualityLock) return;

    final started = _autoQPlaybackStartedAt;
    if (started == null) return;
    if (DateTime.now().difference(started) < _autoQIgnoreBufferingBefore) {
      return;
    }

    final tracks =
        c.betterPlayerAsmsTracks.where((t) => (t.height ?? 0) > 0).toList();
    if (tracks.length < 2) return;

    final heights = tracks.map((t) => t.height!).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    if (heights.length < 2) return;

    int currentH = c.betterPlayerAsmsTrack?.height ?? 0;
    if (currentH <= 0) {
      final sz = c.videoPlayerController?.value.size;
      if (sz != null && sz.width > 0 && sz.height > 0) {
        currentH = math.max(sz.height.round(), sz.width.round());
      }
    }
    if (currentH <= 0) currentH = heights.first;

    int? nextH;
    for (final h in heights) {
      if (h < currentH) {
        nextH = h;
        break;
      }
    }
    if (nextH == null) return;

    final now = DateTime.now();
    _autoQRecentBufferingStarts
        .removeWhere((t) => now.difference(t) > _autoQBufferingWindow);
    _autoQRecentBufferingStarts.add(now);
    if (_autoQRecentBufferingStarts.length < _autoQBufferingStartsNeeded) {
      return;
    }
    if (_autoQLastDowngradeAt != null &&
        now.difference(_autoQLastDowngradeAt!) < _autoQDowngradeCooldown) {
      return;
    }

    BetterPlayerAsmsTrack? pick;
    for (final t in tracks) {
      if (t.height == nextH) {
        pick = t;
        break;
      }
    }
    if (pick == null) return;

    debugPrint(
      'mina_iptv: Otomatik kalite düşürme (~${nextH}p): tekrarlayan tampon (önce ~${currentH}p)',
    );
    c.setTrack(pick);
    _autoQRecentBufferingStarts.clear();
    _autoQLastDowngradeAt = now;
    _maybeBumpOsdQualitySignature();
    update(['osd']);
  }

  /// ExoPlayer / donanım kod çözücü hatalarında otomatik MediaKit’e düş.
  bool _shouldAutoFallbackToMediaKit(String msg) {
    if (msg.isEmpty) return false;
    if (_settings.useMediaKit.value && !_currentStreamIsLive) return false;
    if (mediaKitFallbackSession.value) return false;
    if (_isPlaybackDecoderFailure(msg)) return true;
    final l = msg.toLowerCase();
    if (l.contains('exoplaybackexception')) return true;
    if (l.contains('media3') && l.contains('error')) return true;
    if (l.contains('codec') &&
        (l.contains('unsupported') ||
            l.contains('not supported') ||
            l.contains('failed'))) {
      return true;
    }
    return false;
  }

  Future<void> _performMediaKitFallbackBoot() async {
    if (isClosed) return;
    _cancelNetworkAutoResumeTimer();
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    error.value = null;
    try {
      final old = better;
      better = null;
      if (old != null) {
        old.videoPlayerController?.removeListener(_onVideoPlayerChanged);
        await old.pause();
        old.dispose(forceDispose: true);
      }
    } catch (_) {}
    mediaKitAttachEpoch.value++;
    await _boot(
      preferredMaxHeight: null,
      disableAsms: false,
      reuseSameBetterPlayer: false,
      suppressNetworkRecoverySchedule: false,
    );
  }

  void _onVideoPlayerChanged() {
    try {
      final v = better?.videoPlayerController?.value;
      if (v == null) return;
      if (v.hasError) {
      final msg = v.errorDescription ?? 'Video oynatılamadı';
      debugPrint('mina_iptv: VideoPlayer error: $msg');
      if (_shouldAutoFallbackToMediaKit(msg)) {
        debugPrint('mina_iptv: VideoPlayer error → MediaKit yedek');
        betterOsdOverride.value = false;
        mediaKitFallbackSession.value = true;
        unawaited(_performMediaKitFallbackBoot());
        return;
      }
      if (!_xtreamTriedGetPhpFallback &&
          channel.value.streamUrl.toLowerCase().contains('/live/') &&
          msg.toLowerCase().contains('source')) {
        final original = IptvPlaybackDefaults.normalizeStreamUrl(
          channel.value.streamUrl,
        );
        final converted = _tryConvertXtreamLivePathToGetPhp(original);
        if (converted != null && converted != original) {
          _xtreamTriedGetPhpFallback = true;
          _playUrlOverride = converted;
          unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
          return;
        }
      } else if (!_xtreamTriedOutputM3u8 &&
          channel.value.streamUrl.toLowerCase().contains('get.php') &&
          msg.toLowerCase().contains('source')) {
        // Bazı panellerde get.php output=ts yerine output=m3u8 daha stabil çalışır.
        final original = IptvPlaybackDefaults.normalizeStreamUrl(
          channel.value.streamUrl,
        );
        final converted = _tryConvertXtreamGetPhpOutput(original, 'm3u8');
        if (converted != null && converted != original) {
          _xtreamTriedOutputM3u8 = true;
          _playUrlOverride = converted;
          unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
          return;
        }
      } else if (!_xtreamTriedLiveUrlFormat &&
          (msg.toLowerCase().contains('source error') ||
              msg.toLowerCase().contains('source') ||
              msg.toLowerCase().contains('http') ||
              msg.toLowerCase().contains('404'))) {
        // Xtream get.php formatında Source error alınıyorsa, live/.../$id.ts formatına çevirip 1 kez daha deniyoruz.
        final original =
            IptvPlaybackDefaults.normalizeStreamUrl(channel.value.streamUrl);
        final converted = _tryConvertXtreamGetPhpToLiveUrl(original);
        if (converted != null && converted != original) {
          _xtreamTriedLiveUrlFormat = true;
          // Kaynak hatasında 1 kez daha dene (get.php yerine /live/... formatı).
          unawaited(_boot(preferredMaxHeight: null, disableAsms: false));
          return;
        }
      } else {
        _emitPlaybackErrorForRecovery(msg);
      }
      return;
    }
    if (_settings.layoutMode.value == AppLayoutMode.tv &&
        !effectiveUseMediaKit &&
        v.isPlaying &&
        !v.isBuffering &&
        !v.hasError) {
      _cancelLiveTvStartupWatchdog();
    }
    _maybeBumpOsdQualitySignature();
    } finally {
      if (Platform.isAndroid) {
        unawaited(_syncAndroidPipAutoEnterEligible());
      }
    }
  }

  /// `get.php?...&output=ts` / `output=m3u8` gibi Xtream URL'lerini
  /// `/live/username/password/stream_id.(ts|m3u8)` formatına çevirir.
  /// Uygun değilse `null` döner.
  String? _tryConvertXtreamGetPhpToLiveUrl(String normalizedUrl) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    if (!uri.path.toLowerCase().endsWith('get.php')) return null;

    final q = uri.queryParameters;
    final streamId = q['stream_id'];
    final username = q['username'];
    final password = q['password'];
    final output = q['output'];

    if (streamId == null || streamId.isEmpty) return null;
    if (username == null || username.isEmpty) return null;
    if (password == null || password.isEmpty) return null;

    final ext = (output ?? '').toLowerCase();
    String suffix;
    if (ext.contains('m3u8')) {
      suffix = 'm3u8';
    } else if (ext.contains('mpd')) {
      suffix = 'mpd';
    } else {
      // varsayılan: ts
      suffix = 'ts';
    }

    String encodePathSegment(String v) =>
        Uri.encodeComponent(v).replaceAll('+', '%20');

    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$base/live/${encodePathSegment(username)}/${encodePathSegment(password)}/$streamId.$suffix';
  }

  /// `get.php?...&output=ts` -> `get.php?...&output=m3u8` (veya tersine) dönüştürür.
  /// `/live/user/pass/id.ts` -> `get.php?...&output=ts` (ters yedek).
  String? _tryConvertXtreamLivePathToGetPhp(String normalizedUrl) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length < 4 || segments[0].toLowerCase() != 'live') {
      return null;
    }
    final user = Uri.decodeComponent(segments[1]);
    final pass = Uri.decodeComponent(segments[2]);
    final last = segments[3];
    final dot = last.lastIndexOf('.');
    if (dot <= 0) return null;
    final id = last.substring(0, dot);
    final output = last.substring(dot + 1);
    if (int.tryParse(id) == null) return null;

    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return '$base/get.php?username=${Uri.encodeQueryComponent(user)}&password=${Uri.encodeQueryComponent(pass)}&stream_id=$id&output=$output';
  }

  String? _tryConvertXtreamGetPhpOutput(String normalizedUrl, String output) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return null;
    if (!uri.path.toLowerCase().endsWith('get.php')) return null;

    final q = Map<String, String>.from(uri.queryParameters);
    final streamId = q['stream_id'];
    final username = q['username'];
    final password = q['password'];

    if (streamId == null || streamId.isEmpty) return null;
    if (username == null || username.isEmpty) return null;
    if (password == null || password.isEmpty) return null;

    q['output'] = output;

    final base =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    final query = q.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base/get.php?$query';
  }

  @override
  void onClose() {
    _androidPipFallbackPauseTimer?.cancel();
    _pipAutoEnterWorker?.dispose();
    if (Platform.isAndroid) {
      unawaited(
        _androidPipChannel.invokeMethod<void>(
          'setPipAutoEnterEligible',
          <String, dynamic>{'eligible': false},
        ),
      );
    }
    _mediaKitSettingsWorker?.dispose();
    _cancelZapRelativeDebounce();
    _cancelTvOsdAutoHideTimer();
    _resetNetworkRecoveryState();
    _cancelLiveStallWatchdog();
    _cancelLiveTvStartupWatchdog();
    unawaited(WakelockPlus.disable());
    WidgetsBinding.instance.removeObserver(this);
    _stopRecording();
    try {
      final mk = _mediaKitPlayer;
      if (mk != null) {
        // native tarafta sesin hemen kesilmesi için
        unawaited(mk.pause().then((_) => mk.stop()).then((_) => mk.dispose()));
      }
    } catch (_) {}
    try {
      better?.videoPlayerController?.removeListener(_onVideoPlayerChanged);
      better?.pause();
      better?.dispose(forceDispose: true);
    } catch (_) {}
    better = null;
    _mediaKitErrorSub?.cancel();
    _mediaKitErrorSub = null;
    _cancelMediaKitDimSubs();
    _mediaKitPlayer = null;
    super.onClose();
  }

  Future<void> toggleRecording() async {
    if (isRecording.value) {
      await _stopRecording();
      GlassSnackbar.show(
        'Kayıt Tamamlandı',
        'Video kaydedildi: $_lastRecordPath',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      final started = await _startRecording();
      if (started) {
        GlassSnackbar.show(
          'Kayıt Başladı',
          'Yayın telefon hafızasına kaydediliyor...',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  Future<bool> _startRecording() async {
    try {
      final streamUrl =
          IptvPlaybackDefaults.normalizeStreamUrl(channel.value.streamUrl);
      if (streamUrl.isEmpty) return false;

      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/Recordings');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final fileName =
          'REC_${channel.value.name}_${DateTime.now().millisecondsSinceEpoch}.ts';
      final savePath = '${downloadsDir.path}/$fileName';
      _lastRecordPath = savePath;

      _recordCancelToken = CancelToken();
      isRecording.value = true;
      recordDuration.value = 0;

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        recordDuration.value++;
      });

      // Arka planda indirmeyi başlat
      unawaited(_dio
          .download(
        streamUrl,
        savePath,
        cancelToken: _recordCancelToken,
        options: Options(
          headers: IptvPlaybackDefaults.headersForStreamUrl(streamUrl),
        ),
      )
          .catchError((e) {
        if (isRecording.value) {
          _stopRecording();
          debugPrint('mina_iptv: Recording error: $e');
        }
        // Analyzer: catchError callback dönüş değeri istemektedir.
        return Response<dynamic>(
          data: null,
          statusCode: 0,
          requestOptions: RequestOptions(path: savePath),
        );
      }));

      return true;
    } catch (e) {
      debugPrint('mina_iptv: Could not start recording: $e');
      return false;
    }
  }

  Future<void> _stopRecording() async {
    isRecording.value = false;
    _recordTimer?.cancel();
    _recordTimer = null;
    _recordCancelToken?.cancel();
    _recordCancelToken = null;
  }
}
