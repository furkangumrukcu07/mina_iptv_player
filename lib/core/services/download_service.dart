import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/download_item.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/series_episode_option.dart';
import '../../domain/entities/vod.dart';
import '../player/iptv_playback_defaults.dart';
import '../player/media_kit_lock.dart';
import 'toast_service.dart';

/// Film ve dizi bölümlerinin **arka plan indirme** servisi.
///
/// Mimari:
/// * **Direct HTTP** (`.mp4`, `.mkv`, `.webm`, `.avi`) → `dio.download`
///   ile progress callback'i kullanılır. Hızlı, ölçülebilir.
/// * **HLS / DASH / RTMP** (`.m3u8`, `.mpd`, vs.) → silent sidecar
///   `mpv Player` + `stream-record` property. Kayıt feature'ı ile
///   aynı yaklaşım; FFmpeg bağımlılığı yok.
///
/// Play Store izin sorunu: dosyalar **app-scoped external storage**
/// altına yazılır (`getExternalStorageDirectory()/Downloads/...`).
/// Android 10+ üstünde `WRITE_EXTERNAL_STORAGE` veya
/// `MANAGE_EXTERNAL_STORAGE` gerektirmez; uninstall'da silinir.
///
/// Eş zamanlılık: aynı anda **2 aktif** indirme. Fazlası `queued`
/// statüsünde bekler; bir tane biterse sıradakini başlatır.
class DownloadService extends GetxService {
  DownloadService();

  static DownloadService get to => Get.find<DownloadService>();

  // ---------------------------------------------------------------------------
  // State (reactive)
  // ---------------------------------------------------------------------------

  /// Tüm öğeler — `id` → `DownloadItem`. UI bunu `Obx` ile dinler.
  final RxMap<String, DownloadItem> items = <String, DownloadItem>{}.obs;

  /// Aktif indirmelerde anlık byte progress (`id` → `(received, total)`).
  /// total null veya 0 ise bilinmiyor (HLS sidecar genelde böyle).
  final RxMap<String, ({int received, int? total})> progress =
      <String, ({int received, int? total})>{}.obs;

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static const _kStoreKey = 'mina_downloads_index_v1';
  static const _kRootDirName = 'Downloads';
  static const _kVodSubdir = 'Filmler';
  static const _kSeriesSubdir = 'Diziler';
  static const int _kMaxConcurrent = 2;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  /// Aktif `dio` indirmelerini iptal etmek için.
  final Map<String, CancelToken> _cancelTokens = {};

  /// Aktif `mpv` sidecar player'ları.
  final Map<String, Player> _mpvSidecars = {};

  /// Aktif HLS indirmenin başlangıç zamanı (durations için).
  final Map<String, int> _activeStartedAt = {};

  SharedPreferences? _prefs;
  bool _loaded = false;
  Future<void>? _loadingFuture;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loadingFuture ??= _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_kStoreKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> arr = jsonDecode(raw) as List<dynamic>;
        final map = <String, DownloadItem>{};
        for (final e in arr) {
          try {
            final item = DownloadItem.fromJson(e as Map<String, dynamic>);
            // Disk'te kalmış "downloading" → uygulama kapanmış; failed olarak işaretle
            // kullanıcı tekrar başlatsın.
            if (item.status == DownloadStatus.downloading ||
                item.status == DownloadStatus.queued) {
              map[item.id] = item.copyWith(
                status: DownloadStatus.failed,
                failureMessage: 'downloads.error.interrupted',
              );
            } else {
              map[item.id] = item;
            }
          } catch (e) {
            if (kDebugMode) debugPrint('[downloads] failed to parse entry: $e');
          }
        }
        items.value = map;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[downloads] load failed: $e');
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final arr = items.values.map((e) => e.toJson()).toList(growable: false);
      await _prefs!.setString(_kStoreKey, jsonEncode(arr));
    } catch (e) {
      if (kDebugMode) debugPrint('[downloads] persist failed: $e');
    }
  }

  @override
  void onClose() {
    for (final t in _cancelTokens.values) {
      try {
        t.cancel('service closing');
      } catch (_) {}
    }
    for (final p in _mpvSidecars.values) {
      unawaited(p.dispose());
    }
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // Public API — Enqueue
  // ---------------------------------------------------------------------------

  /// Film (VOD) için indirme kuyruğa ekler. Aynı `id` (`vod_$vodId`) zaten
  /// kuyrukta veya tamamlanmış ise mevcut kaydı döner.
  Future<DownloadItem> enqueueFilm(VodItem v, {String? subtitle}) async {
    await ensureLoaded();
    final id = 'vod_${v.id}';
    final existing = items[id];
    if (existing != null &&
        (existing.isCompleted || existing.isActive)) {
      return existing;
    }

    final ext = _resolveContainerExtension(v.streamUrl, v.containerExtension);
    final engine = _resolveEngine(v.streamUrl, ext);
    final path = await _buildLocalPath(
      subdir: _kVodSubdir,
      baseName: v.name,
      extension: ext,
      uniqueSuffix: '${v.id}',
    );

    final item = DownloadItem(
      id: id,
      kind: DownloadKind.vod,
      title: v.name,
      sourceUrl: v.streamUrl,
      localPath: path,
      engine: engine,
      posterUrl: v.posterUrl,
      subtitle: subtitle,
      containerExtension: ext,
      durationSecs: v.durationSecs,
      addedUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      status: DownloadStatus.queued,
    );
    items[id] = item;
    await _persist();
    _kick();
    return item;
  }

  /// Dizi bölümü için indirme kuyruğa ekler.
  Future<DownloadItem> enqueueEpisode(
    SeriesEpisodeOption opt, {
    required SeriesItem series,
  }) async {
    await ensureLoaded();
    final id = 'ep_${series.id}_${opt.season}x${opt.episodeNumber}';
    final existing = items[id];
    if (existing != null &&
        (existing.isCompleted || existing.isActive)) {
      return existing;
    }

    final ext = _resolveContainerExtension(opt.channel.streamUrl, null);
    final engine = _resolveEngine(opt.channel.streamUrl, ext);

    final safeSeasonEp =
        'S${opt.season.toString().padLeft(2, '0')}E${opt.episodeNumber.toString().padLeft(2, '0')}';
    final path = await _buildLocalPath(
      subdir: '$_kSeriesSubdir/${_sanitizeFileName(series.name)}',
      baseName: '${_sanitizeFileName(series.name)} - $safeSeasonEp',
      extension: ext,
      uniqueSuffix: '${series.id}_$safeSeasonEp',
    );

    final item = DownloadItem(
      id: id,
      kind: DownloadKind.episode,
      title: opt.displayTitle,
      sourceUrl: opt.channel.streamUrl,
      localPath: path,
      engine: engine,
      posterUrl: series.posterUrl,
      subtitle: '$safeSeasonEp · ${series.name}',
      parentSeriesId: series.id,
      parentSeriesName: series.name,
      season: opt.season,
      episode: opt.episodeNumber,
      containerExtension: ext,
      durationSecs: opt.durationSecs,
      addedUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      status: DownloadStatus.queued,
    );
    items[id] = item;
    await _persist();
    _kick();
    return item;
  }

  // ---------------------------------------------------------------------------
  // Public API — Lookups
  // ---------------------------------------------------------------------------

  DownloadItem? findVod(int vodId) => items['vod_$vodId'];
  DownloadItem? findEpisode(int seriesId, int season, int episode) =>
      items['ep_${seriesId}_${season}x$episode'];

  List<DownloadItem> get sortedByRecent {
    final list = items.values.toList();
    list.sort((a, b) {
      final aTime = a.completedUnix ?? a.addedUnix;
      final bTime = b.completedUnix ?? b.addedUnix;
      return bTime.compareTo(aTime);
    });
    return list;
  }

  /// Tamamlanmış indirmelerin yerel dosya yolu — yoksa null.
  Future<String?> localPathIfReady(String id) async {
    final i = items[id];
    if (i == null || !i.isCompleted) return null;
    if (!await File(i.localPath).exists()) return null;
    return i.localPath;
  }

  // ---------------------------------------------------------------------------
  // Public API — Mutations
  // ---------------------------------------------------------------------------

  /// İndirmeyi iptal eder veya devam edenden çıkarır.
  Future<void> cancel(String id) async {
    final item = items[id];
    if (item == null) return;

    // Aktif HTTP indirmesi varsa cancel token
    final token = _cancelTokens[id];
    if (token != null) {
      try {
        token.cancel('user cancel');
      } catch (_) {}
      _cancelTokens.remove(id);
    }

    // Aktif mpv sidecar varsa dispose
    final mpv = _mpvSidecars[id];
    if (mpv != null) {
      try {
        final plat = mpv.platform;
        if (plat is NativePlayer) {
          await plat.setProperty('stream-record', '');
        }
        await mpv.stop();
        await mpv.dispose();
      } catch (_) {}
      _mpvSidecars.remove(id);
    }
    _activeStartedAt.remove(id);
    progress.remove(id);

    items[id] = item.copyWith(status: DownloadStatus.cancelled);
    await _persist();
    await _safeDeleteAsync(item.localPath);
    _kick();
  }

  /// Diskten ve listeden tamamen siler.
  Future<void> deleteItem(String id) async {
    final item = items[id];
    if (item == null) return;
    if (item.isActive) await cancel(id);
    await _safeDeleteAsync(item.localPath);
    items.remove(id);
    await _persist();
  }

  /// Başarısız bir indirmeyi tekrar dener.
  Future<void> retry(String id) async {
    final item = items[id];
    if (item == null) return;
    items[id] = item.copyWith(
      status: DownloadStatus.queued,
      failureMessage: null,
    );
    await _persist();
    _kick();
  }

  // ---------------------------------------------------------------------------
  // Scheduler
  // ---------------------------------------------------------------------------

  void _kick() {
    final activeCount = items.values
        .where((e) => e.status == DownloadStatus.downloading)
        .length;
    if (activeCount >= _kMaxConcurrent) return;
    DownloadItem? next;
    for (final v in items.values) {
      if (v.status == DownloadStatus.queued) {
        next = v;
        break;
      }
    }
    if (next == null) return;
    items[next.id] = next.copyWith(status: DownloadStatus.downloading);
    _persist();
    unawaited(_runDownload(next.id));
  }

  Future<void> _runDownload(String id) async {
    final item = items[id];
    if (item == null) return;
    _activeStartedAt[id] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final errors = <String>[];
    try {
      // Birincil engine
      try {
        if (item.engine == DownloadEngine.directHttp) {
          await _runDirectWithSchemeRace(item);
        } else {
          await _runMpv(item);
        }
      } catch (e) {
        if (e is DioException && CancelToken.isCancel(e)) rethrow;
        errors.add('${item.engine.name}: ${_humanizeError(e)}');
        // Fallback: direct ↔ mpv
        if (kDebugMode) debugPrint(
          '[downloads] $id primary engine ${item.engine.name} failed, '
          'trying fallback. error: $e',
        );
        await _safeDeleteAsync(item.localPath);
        _cancelTokens.remove(id);
        _mpvSidecars.remove(id);
        progress.remove(id);
        if (item.engine == DownloadEngine.directHttp) {
          await _runMpv(item);
        } else {
          await _runDirectWithSchemeRace(item);
        }
      }

      final f = File(item.localPath);
      final exists = await f.exists();
      final size = exists ? await f.length() : 0;
      if (!exists || size < 1024) {
        // Disk'te bir şey yok / 1 KB altı → muhtemelen sessiz başarısızlık
        throw Exception(
          'Sunucu hiç veri göndermedi (downloaded=${size}B). '
          'Sunucu indirmeye izin vermiyor olabilir.\n'
          'Denenen: ${errors.isEmpty ? "—" : errors.join("; ")}',
        );
      }
      items[id] = item.copyWith(
        status: DownloadStatus.completed,
        sizeBytes: size,
        completedUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      _toast(
        'downloads.toast.completedNamed'.trParams({'title': item.title}),
        isError: false,
        literal: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[downloads] $id failed: $e');
      if (e is DioException && CancelToken.isCancel(e)) {
        // cancel zaten state'i güncelledi
      } else {
        final msg = _humanizeError(e);
        items[id] = item.copyWith(
          status: DownloadStatus.failed,
          failureMessage: msg,
        );
        _toast(
          'downloads.toast.failedWithReason'
              .trParams({'reason': msg.length > 80 ? '${msg.substring(0, 80)}…' : msg}),
          isError: true,
          literal: true,
        );
      }
    } finally {
      _cancelTokens.remove(id);
      _mpvSidecars.remove(id);
      _activeStartedAt.remove(id);
      progress.remove(id);
      await _persist();
      _kick();
    }
  }

  /// Hatayı kullanıcıya anlamlı bir Türkçe/İngilizce metne çevirir.
  String _humanizeError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          return 'Sunucuya bağlanılamadı (zaman aşımı).';
        case DioExceptionType.receiveTimeout:
          return 'Sunucudan veri alınamadı (zaman aşımı).';
        case DioExceptionType.sendTimeout:
          return 'Sunucuya istek gönderilemedi (zaman aşımı).';
        case DioExceptionType.badCertificate:
          return 'Sunucu SSL sertifikası geçersiz.';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode;
          if (code == 401 || code == 403) {
            return 'Sunucu erişimi reddetti (HTTP $code) — '
                'lisans/oturum dolmuş olabilir.';
          }
          if (code == 404) {
            return 'Dosya sunucuda bulunamadı (HTTP 404).';
          }
          if (code == 429) {
            return 'Sunucu istek limitini aştı (HTTP 429) — '
                'sonra tekrar deneyin.';
          }
          if (code != null && code >= 500) {
            return 'Sunucu hatası (HTTP $code).';
          }
          return 'Sunucu beklenmeyen yanıt verdi (HTTP $code).';
        case DioExceptionType.cancel:
          return 'İptal edildi.';
        case DioExceptionType.connectionError:
          return 'Ağ bağlantısı kurulamadı (DNS / TCP).';
        case DioExceptionType.unknown:
          return e.message ?? e.toString();
      }
    }
    final s = e.toString();
    if (s.contains('SocketException')) {
      return 'Ağa erişilemedi (Wi-Fi / Mobil veri).';
    }
    if (s.contains('HandshakeException')) {
      return 'SSL el sıkışması başarısız.';
    }
    return s.length > 200 ? '${s.substring(0, 200)}…' : s;
  }

  // ---------------------------------------------------------------------------
  // Direct HTTP engine
  // ---------------------------------------------------------------------------

  /// Direct HTTP — önce orijinal şema, başarısız olursa diğer şema ile dener.
  /// Sıralı (paralel değil): yarış mantığı yerine deterministik olsun ki
  /// servera çift bağlantı açmayalım (concurrency limit'i olabilir).
  Future<void> _runDirectWithSchemeRace(DownloadItem item) async {
    try {
      await _runDirect(item, item.sourceUrl);
      return;
    } catch (e) {
      // Şema swap'ı sadece bağlantı / TLS sorunlarında dene; 4xx/5xx için
      // tekrar denemenin anlamı yok (server zaten cevap verdi).
      final swapped = _swapHttpScheme(item.sourceUrl);
      if (swapped == null) rethrow;
      if (!_isSchemeFallbackEligible(e)) rethrow;
      if (kDebugMode) debugPrint(
        '[downloads] ${item.id} direct failed on ${item.sourceUrl}, '
        'retrying with swapped scheme: $swapped',
      );
      await _safeDeleteAsync(item.localPath);
      await _runDirect(item, swapped);
    }
  }

  Future<void> _runDirect(DownloadItem item, String url) async {
    final token = CancelToken();
    _cancelTokens[item.id] = token;
    final headers = IptvPlaybackDefaults.downloadHeadersForUrl(url);
    await _dio.download(
      url,
      item.localPath,
      cancelToken: token,
      options: Options(
        headers: headers,
        followRedirects: true,
        maxRedirects: 5,
        receiveTimeout: const Duration(hours: 6),
        // 200 (full) veya 206 (partial / Range cevabı) — her ikisi de geçerli.
        validateStatus: (s) => s != null && s >= 200 && s < 400,
        responseType: ResponseType.stream,
      ),
      onReceiveProgress: (received, total) {
        progress[item.id] = (
          received: received,
          total: total <= 0 ? null : total,
        );
      },
    );
  }

  static String? _swapHttpScheme(String url) {
    final u = Uri.tryParse(url);
    if (u == null || !u.hasScheme) return null;
    if (u.scheme == 'http') return u.replace(scheme: 'https').toString();
    if (u.scheme == 'https') return u.replace(scheme: 'http').toString();
    return null;
  }

  /// Şema swap'ı yalnızca **ağ seviyesi** hatalarda anlamlı (bağlantı
  /// kurulamadı, TLS handshake fail, vs.). 4xx/5xx server'dan cevap
  /// alındı demektir — şema değiştirmek aynı 4xx/5xx'i tekrarlar.
  static bool _isSchemeFallbackEligible(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.badCertificate:
          return true;
        case DioExceptionType.badResponse:
          return false;
        default:
          break;
      }
    }
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('HandshakeException') ||
        s.contains('Connection') && s.contains('refused');
  }

  // ---------------------------------------------------------------------------
  // mpv stream-record engine (HLS/DASH/RTMP)
  // ---------------------------------------------------------------------------

  Future<void> _runMpv(DownloadItem item) async {
    if (Platform.isMacOS) {
      await _runDirectWithSchemeRace(item);
      return;
    }
    final completer = Completer<void>();
    Player? p;
    await MinaMediaKitLock.synchronized(() async {
      p = Player(
        configuration: const PlayerConfiguration(
          logLevel: MPVLogLevel.warn,
          bufferSize: 32 * 1024 * 1024,
        ),
      );
    });
    final player = p!;
    _mpvSidecars[item.id] = player;
    final plat = player.platform;
    if (plat is! NativePlayer) {
      await MinaMediaKitLock.synchronized(() async {
        try { await player.dispose(); } catch (_) {}
      });
      throw Exception('mpv platform unavailable');
    }
    Timer? progressTimer;
    StreamSubscription? completedSub;
    StreamSubscription? errorSub;
    try {
      await plat.setProperty('vid', 'no');
      await plat.setProperty('aid', 'auto');
      await plat.setProperty('ao', 'null');
      // VOD HLS biteceği için keep-open=no → EOF'ta completed event'i alırız.
      await plat.setProperty('keep-open', 'no');
      final headers = IptvPlaybackDefaults.headersForStreamUrl(item.sourceUrl);
      final ua = headers['User-Agent'] ?? headers['user-agent'];
      if (ua != null && ua.isNotEmpty) {
        await plat.setProperty('user-agent', ua);
      }
      final referer = headers['Referer'] ?? headers['referer'];
      if (referer != null && referer.isNotEmpty) {
        await plat.setProperty('referrer', referer);
      }
      await plat.setProperty('stream-record', item.localPath);

      completedSub = player.stream.completed.listen((isCompleted) {
        if (isCompleted && !completer.isCompleted) {
          completer.complete();
        }
      });
      errorSub = player.stream.error.listen((err) {
        if (!completer.isCompleted) {
          completer.completeError(Exception('mpv stream error: $err'));
        }
      });

      // Progress yaklaşımı: dosya boyutunu periyodik oku → bytesReceived.
      // total bilinmiyor (HLS segmentleri canlı çekiliyor).
      progressTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        final f = File(item.localPath);
        if (await f.exists()) {
          progress[item.id] = (received: await f.length(), total: null);
        }
      });

      await player.open(Media(item.sourceUrl), play: true);
      await completer.future;
    } finally {
      progressTimer?.cancel();
      await completedSub?.cancel();
      await errorSub?.cancel();
      try {
        await plat.setProperty('stream-record', '');
      } catch (_) {}
      try {
        await player.stop();
      } catch (_) {}
      try {
        await MinaMediaKitLock.synchronized(() async {
          try { await player.dispose(); } catch (_) {}
        });
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Path / extension helpers
  // ---------------------------------------------------------------------------

  Future<String> _buildLocalPath({
    required String subdir,
    required String baseName,
    required String extension,
    required String uniqueSuffix,
  }) async {
    final root = await _resolveRootDir();
    final dir = Directory('${root.path}/$_kRootDirName/$subdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final safe = _sanitizeFileName(baseName);
    final clean = safe.isEmpty ? uniqueSuffix : safe;
    final fileName = '${clean}_$uniqueSuffix$extension';
    return '${dir.path}/$fileName';
  }

  Future<Directory> _resolveRootDir() async {
    try {
      final d = await getExternalStorageDirectory();
      if (d != null) return d;
    } catch (_) {}
    return getApplicationDocumentsDirectory();
  }

  /// URL'ye veya `containerExtension` field'ına göre `.mp4`/`.mkv`/`.ts`
  /// belirler. `.m3u8` / `.mpd` → `.ts` (mpv kaydı için).
  String _resolveContainerExtension(String url, String? container) {
    if (container != null && container.isNotEmpty) {
      final c = container.startsWith('.') ? container : '.$container';
      return c.toLowerCase();
    }
    final lower = url.split('?').first.toLowerCase();
    for (final ext in [
      '.mp4',
      '.mkv',
      '.webm',
      '.avi',
      '.mov',
      '.flv',
      '.mp3',
      '.aac',
      '.ts',
    ]) {
      if (lower.endsWith(ext)) return ext;
    }
    // HLS/DASH için kayıt biçimi → .ts (mpv'nin native container'ı)
    return '.ts';
  }

  /// Direct HTTP veya mpv engine seçimi.
  DownloadEngine _resolveEngine(String url, String ext) {
    final lower = url.split('?').first.toLowerCase();
    if (lower.endsWith('.m3u8') ||
        lower.endsWith('.mpd') ||
        lower.startsWith('rtmp:') ||
        lower.startsWith('rtsp:') ||
        ext == '.ts') {
      return DownloadEngine.mpvRecord;
    }
    return DownloadEngine.directHttp;
  }

  String _sanitizeFileName(String name) {
    var s = name.trim();
    for (final ch in <String>['\\', '/', ':', '*', '?', '"', '<', '>', '|']) {
      s = s.replaceAll(ch, '_');
    }
    if (s.length > 60) s = s.substring(0, 60);
    return s;
  }


  Future<void> _safeDeleteAsync(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// [literal] true ise [key] çevirisiz olduğu varsayılır (zaten trParams
  /// ile formatlanmış). false ise `.tr` uygulanır.
  void _toast(String key, {required bool isError, bool literal = false}) {
    try {
      Get.find<ToastService>().show(literal ? key : key.tr, isError: isError);
    } catch (_) {}
  }
}
