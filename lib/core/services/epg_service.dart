import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/epg_entities.dart';
import '../../data/local/epg_snapshot_codec.dart';
import '../../data/local/epg_snapshot_store.dart';
import '../../data/remote/xmltv_parser.dart';
import '../../data/remote/xtream_api.dart';
import '../epg/catch_up_url_template.dart';
import 'app_settings_service.dart';

class EpgService extends GetxService {
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  /// `get_all_live_epg` birleşiminde parça boyutu; büyük değer = daha az yield, daha hızlı birleşim.
  static const int _kXtreamMergeChunkStreams = 384;

  final RxMap<String, EpgChannel> _channels = <String, EpgChannel>{}.obs;
  final RxMap<String, List<EpgProgramme>> _programmes =
      <String, List<EpgProgramme>>{}.obs;
  final RxBool isLoading = false.obs;
  final Map<String, List<EpgProgramme>> _windowProgrammesCache =
      <String, List<EpgProgramme>>{};
  final Map<String, int> _currentProgrammeIndexCache = <String, int>{};
  static const int _kWindowProgrammesCacheMaxEntries = 4096;

  /// Obx / liste yenilemesi için; EPG yüklendikçe artar.
  final RxInt loadGeneration = 0.obs;

  /// Disk önbelleği: [logicalKey] ile [EpgSnapshotKeys.logicalKeyFor] aynı olmalı.
  Future<bool> tryRestoreFromDiskIfFresh(String logicalKey) async {
    try {
      final raw = await EpgSnapshotStore.readRaw(logicalKey);
      if (raw == null) return false;
      final root = await decodeEpgSnapshotInIsolate(raw);
      if (root == null) return false;
      if ((root['key'] as String?) != logicalKey) return false;
      final savedAt = (root['savedAtMs'] as num?)?.toInt();
      if (savedAt == null) return false;
      final age = DateTime.now().millisecondsSinceEpoch - savedAt;
      if (age < 0 || age > EpgSnapshotStore.ttlMs) return false;

      final applied = applyEpgSnapshotRoot(
        root,
        assign: (ch, pr) {
          _channels.assignAll(ch);
          _programmes.assignAll(pr);
        },
      );
      if (!applied) return false;
      _normalizeProgrammesInPlace();
      _windowProgrammesCache.clear();
      _currentProgrammeIndexCache.clear();

      loadGeneration.value++;
      debugPrint(
        'mina_iptv: EPG restored from disk cache (${_channels.length} ch, ${_programmes.length} stream keys, age ${age ~/ 1000}s)',
      );
      return true;
    } catch (e) {
      debugPrint('mina_iptv: EPG cache restore failed: $e');
      return false;
    }
  }

  Future<void> persistSnapshotToDisk(String logicalKey) async {
    if (_channels.isEmpty && _programmes.isEmpty) return;
    try {
      final map = buildEpgSnapshotMap(
        logicalKey: logicalKey,
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
        channels: Map<String, EpgChannel>.from(_channels),
        programmes: Map<String, List<EpgProgramme>>.from(
          _programmes.map((k, v) => MapEntry(k, List<EpgProgramme>.from(v))),
        ),
      );
      final json = await encodeEpgSnapshotInIsolate(map);
      await EpgSnapshotStore.write(logicalKey, json);
      debugPrint('mina_iptv: EPG snapshot saved (${_programmes.length} stream keys)');
    } catch (e) {
      debugPrint('mina_iptv: EPG snapshot save failed: $e');
    }
  }

  Future<void> loadEpg(String url) async {
    if (url.isEmpty) return;
    isLoading.value = true;
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      final xmlContent = response.data;
      if (xmlContent != null && xmlContent.isNotEmpty) {
        final result = await compute(parseXmlTvIsolate, xmlContent);
        _channels.assignAll(result['channels'] as Map<String, EpgChannel>);
        // Anahtar bazında yaz: Xtream `get_all_live_epg` ile paralel yüklenirken
        // `stream_id` programları silinmesin.
        final progMap =
            result['programmes'] as Map<String, List<EpgProgramme>>;
        for (final e in progMap.entries) {
          _setProgrammesForKey(e.key, e.value);
        }
        loadGeneration.value++;
        debugPrint(
            'mina_iptv: EPG loaded. Channels: ${_channels.length}, Progs: ${_programmes.length}');
      }
    } catch (e) {
      debugPrint('mina_iptv: Error loading EPG: $e');
    } finally {
      isLoading.value = false;
    }
  }

  EpgProgramme? getCurrentProgramme(String? epgId) {
    final key = epgId?.trim();
    if (key == null || key.isEmpty) return null;

    // RxMap erişimi — GetX Obx içinde dinlenebilir.
    final list = _programmes[key];
    if (list == null || list.isEmpty) return null;

    final now = DateTime.now();
    final cachedIdx = _currentProgrammeIndexCache[key];
    if (cachedIdx != null && cachedIdx >= 0 && cachedIdx < list.length) {
      final cached = list[cachedIdx];
      if (!now.isBefore(cached.start) && now.isBefore(cached.end)) {
        return cached;
      }
      if (cachedIdx + 1 < list.length) {
        final next = list[cachedIdx + 1];
        if (!now.isBefore(next.start) && now.isBefore(next.end)) {
          _currentProgrammeIndexCache[key] = cachedIdx + 1;
          return next;
        }
      }
    }

    // Programlar başlangıç zamanına göre sıralı varsayılır; current lookup binary search ile.
    var lo = 0;
    var hi = list.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final p = list[mid];
      if (now.isBefore(p.start)) {
        hi = mid - 1;
      } else if (!now.isBefore(p.end)) {
        lo = mid + 1;
      } else {
        _currentProgrammeIndexCache[key] = mid;
        return p;
      }
    }
    _currentProgrammeIndexCache.remove(key);
    return null;
  }

  /// XMLTV `epg_channel_id` yoksa veya eşleşmezse Xtream `get_all_live_epg` ile gelen
  /// **[stream_id]** anahtarına düşer.
  EpgProgramme? getCurrentProgrammeForLiveChannel(Channel ch) {
    final byXml = getCurrentProgramme(ch.epgChannelId);
    if (byXml != null) return byXml;
    return getCurrentProgramme(ch.id.toString());
  }

  /// XMLTV `epg_channel_id` yoksa veya eşleşmezse Xtream `get_all_live_epg` ile gelen
  /// **[stream_id]** anahtarına düşer.
  EpgProgramme? getCurrentProgrammeForLiveChannel(Channel ch) {
    final byXml = getCurrentProgramme(ch.epgChannelId);
    if (byXml != null) return byXml;
    return getCurrentProgramme(ch.id.toString());
  }

  List<EpgProgramme> getFullDayProgrammes(String? epgId) {
    final key = epgId?.trim();
    if (key == null || key.isEmpty) return [];
    return List<EpgProgramme>.from(_programmes[key] ?? const []);
  }

  void _setProgrammesForKey(String key, List<EpgProgramme> list) {
    final sorted = List<EpgProgramme>.from(list)
      ..sort((a, b) => a.start.compareTo(b.start));
    _programmes[key] = sorted;
    _invalidateCachesForProgrammeKey(key);
  }

  void _invalidateCachesForProgrammeKey(String key) {
    _currentProgrammeIndexCache.remove(key);
    final prefix = '$key|';
    _windowProgrammesCache.removeWhere((k, _) => k.startsWith(prefix));
  }

  void _normalizeProgrammesInPlace() {
    final keys = _programmes.keys.toList(growable: false);
    for (final key in keys) {
      final list = _programmes[key];
      if (list == null || list.isEmpty) continue;
      _setProgrammesForKey(key, list);
    }
  }

  List<EpgProgramme> getFullDayProgrammesForLiveChannel(Channel ch) {
    final fromXml = getFullDayProgrammes(ch.epgChannelId);
    if (fromXml.isNotEmpty) return fromXml;
    return getFullDayProgrammes(ch.id.toString());
  }

  String _epgLookupKeyForLiveChannel(Channel ch) {
    final xmlKey = ch.epgChannelId?.trim();
    if (xmlKey != null && xmlKey.isNotEmpty) {
      final list = _programmes[xmlKey];
      if (list != null && list.isNotEmpty) return xmlKey;
    }
    return ch.id.toString();
  }

  /// Zaman çizelgesi: [windowStart, windowEnd) ile kesişen programlar (sıralı).
  List<EpgProgramme> programmesInWindowForLiveChannel(
    Channel ch,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final chKey = _epgLookupKeyForLiveChannel(ch);
    final cacheKey =
        '$chKey|${windowStart.millisecondsSinceEpoch}|${windowEnd.millisecondsSinceEpoch}';
    final cached = _windowProgrammesCache[cacheKey];
    if (cached != null) return cached;
    final all = getFullDayProgrammes(chKey);
    if (all.isEmpty) return [];
    var lo = 0;
    var hi = all.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (all[mid].end.isAfter(windowStart)) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    final startIdx = lo;
    final result = <EpgProgramme>[];
    for (var i = startIdx; i < all.length; i++) {
      final p = all[i];
      if (!p.start.isBefore(windowEnd)) break;
      result.add(p);
    }
    if (_windowProgrammesCache.length >= _kWindowProgrammesCacheMaxEntries) {
      _windowProgrammesCache.clear();
    }
    _windowProgrammesCache[cacheKey] = result;
    return result;
  }

  /// Kanallar / gözat detay paneli: şu anki veya sıradaki program metni; yoksa çeviri ile bilgi.
  String describeLiveChannelDetail(
    Channel ch, {
    String? titleForFallback,
  }) {
    final fallbackTitle = titleForFallback ?? ch.name;
    final prog = getCurrentProgrammeForLiveChannel(ch);
    final all = getFullDayProgrammesForLiveChannel(ch);
    if (prog != null) {
      final d = prog.description?.trim();
      if (d != null && d.isNotEmpty) {
        return '${prog.title}\n\n$d';
      }
      return prog.title;
    }
    if (all.isNotEmpty) {
      final now = DateTime.now();
      EpgProgramme pick = all.first;
      for (final p in all) {
        if (p.end.isAfter(now)) {
          pick = p;
          break;
        }
      }
      final d = pick.description?.trim();
      if (d != null && d.isNotEmpty) {
        return '${pick.title}\n\n$d';
      }
      return pick.title;
    }
    if (isLoading.value) {
      return 'player.epgLoading'.tr;
    }
    return 'browse.detail.epg'.trParams({'title': fallbackTitle});
  }

  static String _normTitleForVodEpgMatch(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    s = s.replaceAll(RegExp(r'\s+(19|20)\d{2}$'), '');
    return s.trim();
  }

  /// Liste / EPG başlığı karşılaştırması için hafif Türkçe fold (ş↔s vb.).
  static String _foldTitleForVodEpgMatch(String s) {
    return s
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  static Set<String> _titleTokensForVodEpgMatch(String x) {
    return x
        .split(RegExp(r'[\s,.:|/_-]+'))
        .map((e) => e.trim())
        .where((e) => e.length > 1)
        .toSet();
  }

  static int _vodTitleMatchScore(String wantNorm, String progTitleNorm) {
    if (wantNorm.isEmpty || progTitleNorm.isEmpty) return 0;
    final a = _foldTitleForVodEpgMatch(wantNorm);
    final b = _foldTitleForVodEpgMatch(progTitleNorm);
    if (a == b) return 1000;
    if (a.contains(b) || b.contains(a)) return 800;
    final ta = _titleTokensForVodEpgMatch(a);
    final tb = _titleTokensForVodEpgMatch(b);
    if (ta.isEmpty || tb.isEmpty) return 0;
    final inter = ta.intersection(tb).length;
    if (inter == 0) return 0;
    final union = ta.union(tb).length;
    return 200 + (400 * inter ~/ union);
  }

  static String? _formatVodEpgProgrammeLine(EpgProgramme prog) {
    final d = prog.description?.trim();
    if (d != null && d.isNotEmpty) {
      return '${prog.title}\n\n$d';
    }
    final t = prog.title.trim();
    return t.isNotEmpty ? t : null;
  }

  EpgProgramme _pickVodProgrammeFromListForStreamId(
    List<EpgProgramme> all,
    String? titleFallback,
  ) {
    final want = _normTitleForVodEpgMatch(titleFallback ?? '');
    EpgProgramme? titleMatch;
    if (want.isNotEmpty) {
      var bestScore = 0;
      for (final p in all) {
        final pt = _normTitleForVodEpgMatch(p.title);
        if (pt.isEmpty) continue;
        final sc = _vodTitleMatchScore(want, pt);
        if (sc > bestScore) {
          bestScore = sc;
          titleMatch = p;
        }
      }
      if (bestScore >= 200 && titleMatch != null) {
        return titleMatch;
      }
      for (final p in all) {
        final pt = p.title.trim().toLowerCase();
        if (pt.isEmpty) continue;
        if (want.contains(pt) || pt.contains(want)) {
          return p;
        }
      }
    }

    final now = DateTime.now();
    for (final p in all) {
      if (p.end.isAfter(now)) return p;
    }
    return all.first;
  }

  /// Xtream `get_all_live_epg` (veya aynı anahtarla birleşen veri) içinde
  /// [vodStreamId] anahtarıyla program listesi varsa başlık + açıklama döner.
  /// Yalnızca bu anahtar altındaki kayıtlar kullanılır; tüm EPG’de başlık araması
  /// yapılmaz (yanlış film özeti üretiyordu).
  ///
  /// Çoğu VOD için EPG’de `stream_id` olmaz; o zaman `null` döner — arayüz
  /// `get_vod_info` ve liste `plot` alanına düşer.
  String? describeVodDetailFromXtreamEpg(
    int vodStreamId, {
    String? titleFallback,
  }) {
    if (vodStreamId > 0) {
      final all = getFullDayProgrammes('$vodStreamId');
      if (all.isNotEmpty) {
        final prog =
            _pickVodProgrammeFromListForStreamId(all, titleFallback);
        return _formatVodEpgProgrammeLine(prog);
      }
    }
    return null;
  }

  /// Xtream `get_all_live_epg` çıktısını [stream_id] string anahtarıyla birleştirir.
  /// XMLTV ile çakışmada XMLTV (önce yüklenen) korunur; yalnızca boş anahtarlar dolar.
  ///
  /// Büyük listelerde parça parça yazar; her parçadan sonra [loadGeneration] artar ve
  /// kısa gecikme ile olay döngüsüne dönülür (UI donması azalır).
  Future<void> mergeXtreamApiEpgByStreamId(
    Map<int, List<EpgProgramme>> map,
  ) async {
    if (map.isEmpty) return;
    final entries = map.entries.toList();
    var streams = 0;
    var programmes = 0;
    const chunk = _kXtreamMergeChunkStreams;
    for (var i = 0; i < entries.length; i += chunk) {
      final end = i + chunk > entries.length ? entries.length : i + chunk;
      for (var j = i; j < end; j++) {
        final e = entries[j];
        final k = '${e.key}';
        final list = e.value;
        if (list.isEmpty) continue;
        final existing = _programmes[k];
        if (existing != null && existing.isNotEmpty) continue;
        _setProgrammesForKey(k, list);
        streams++;
        programmes += list.length;
      }
      loadGeneration.value++;
      if (end < entries.length && entries.length > 800) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    debugPrint(
      'mina_iptv: Xtream API EPG merged: $streams streams, $programmes programmes (skipped non-empty XMLTV keys)',
    );
  }

  Future<void> loadXtreamAllLiveEpg(XtreamApi api) async {
    try {
      final map = await api.getAllLiveEpg(_dio);
      await mergeXtreamApiEpgByStreamId(map);
    } catch (e, st) {
      debugPrint('mina_iptv: get_all_live_epg failed (non-fatal): $e\n$st');
    }
  }

  /// EPG programı için catch-up oynatma URL’si; ayarlarda kapalı veya geçersiz şablonda null.
  String? buildCatchUpPlaybackUrl({
    required XtreamApi api,
    required Channel channel,
    required EpgProgramme programme,
    required String template,
  }) {
    return CatchUpUrlBuilder.build(
      api: api,
      streamId: channel.id,
      programme: programme,
      template: template,
    );
  }

  /// [AppSettingsService] içindeki panel şablonu / ön ayar ile aynı URL üretimi.
  String? buildCatchUpPlaybackUrlFromSettings({
    required XtreamApi api,
    required Channel channel,
    required EpgProgramme programme,
  }) {
    final t = Get.find<AppSettingsService>().catchUpTemplateEffective;
    if (t.isEmpty) return null;
    return buildCatchUpPlaybackUrl(
      api: api,
      channel: channel,
      programme: programme,
      template: t,
    );
  }

  void clear() {
    _channels.clear();
    _programmes.clear();
    _windowProgrammesCache.clear();
    _currentProgrammeIndexCache.clear();
    loadGeneration.value++;
  }
}
