import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/epg_entities.dart';
import '../../data/local/epg_snapshot_codec.dart';
import '../../data/local/epg_snapshot_store.dart';
import '../../data/local/epg_sqlite_store.dart';
import '../../data/remote/xmltv_parser.dart';
import '../../data/remote/xtream_api.dart';
import '../epg/catch_up_url_template.dart';
import '../epg/m3u_xmltv_name_matcher.dart';
import '../epg/global_epg_service.dart';
import '../telemetry/epg_perf_telemetry.dart';
import 'app_settings_service.dart';

class EpgService extends GetxService {
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  /// `Ayarlar > EPG > EPG Kapat` anahtarına bakar; servis kapsam dışı tüm
  /// yükleme/indirme akışlarına bu kontrol eklenir. Servis kayıt edilmediyse
  /// (test / boot süresi) varsayılan olarak `true` döner.
  bool get _epgFeatureEnabled {
    if (!Get.isRegistered<AppSettingsService>()) return true;
    return Get.find<AppSettingsService>().epgEnabled.value;
  }

  /// `get_all_live_epg` birleşiminde parça boyutu; büyük değer = daha az yield, daha hızlı birleşim.
  static const int _kXtreamMergeChunkStreams = 384;

  final RxMap<String, EpgChannel> _channels = <String, EpgChannel>{}.obs;
  final RxMap<String, List<EpgProgramme>> _programmes =
      <String, List<EpgProgramme>>{}.obs;
  final RxBool isLoading = false.obs;

  // ---------------------------------------------------------------------------
  // Xtream / GitHub EPG durum izleme. Ayarlar > EPG > EPG Kaynağı tile'ı bu
  // alanları Obx ile dinler ve hangi yedeklerin gerçekten devrede olduğunu
  // kullanıcıya gösterir.
  // ---------------------------------------------------------------------------

  /// `loadXtreamAllLiveEpg`'in son turunda `get_all_live_epg` + panel `xmltv.php`
  /// üzerinden eklenen toplam program sayısı.
  final RxInt xtreamProgrammeCount = 0.obs;

  /// `loadXtreamAllLiveEpg` son turunda gelen kanal sayısı (panel xmltv.php).
  final RxInt xtreamChannelCount = 0.obs;

  /// Son Xtream EPG çağrısının başarılı oldu mu (en azından kısmen veri geldi).
  final RxBool xtreamLastSuccess = false.obs;

  /// Son Xtream EPG hatasının kullanıcı dostu metni (boşsa hata yok).
  final RxString xtreamLastError = ''.obs;

  /// Son Xtream EPG çağrısının tamamlanma zamanı (ms epoch). 0 = hiç denenmedi.
  final RxInt xtreamLastFetchMs = 0.obs;

  // ---------------------------------------------------------------------------
  // Xtream EPG çağrı paylaşımı + throttle. Splash deferred turu, settings
  // yenilemesi, EPG kaynağı mod değişimi aynı anda tetiklendiğinde tek bir
  // ağ indirimini paylaşırız; ardışık tetiklemeler [_kXtreamLoadThrottleMs]
  // içinde no-op. `GlobalEpgService`'teki paterne paralel.
  // ---------------------------------------------------------------------------

  Future<void>? _inflightXtreamLoad;
  String _lastXtreamFingerprint = '';
  int _lastXtreamLoadAtMs = 0;
  static const int _kXtreamLoadThrottleMs = 30 * 1000;
  final Map<String, List<EpgProgramme>> _windowProgrammesCache =
      <String, List<EpgProgramme>>{};
  final Map<String, int> _currentProgrammeIndexCache = <String, int>{};
  static const int _kWindowProgrammesCacheMaxEntries = 4096;

  /// M3U: yayın URL → XMLTV `channel id` (SQLite + isim benzerliği).
  final Map<String, String> _m3uStreamUrlToXmlId = <String, String>{};

  Map<String, String> get m3uStreamUrlToXmlId =>
      Map<String, String>.unmodifiable(_m3uStreamUrlToXmlId);

  String? xmlTvChannelDisplayName(String xmlChannelId) =>
      _channels[xmlChannelId]?.name;

  List<MapEntry<String, String>> get xmlTvChannelEntries {
    final out = <MapEntry<String, String>>[];
    for (final e in _channels.entries) {
      out.add(MapEntry(e.key, e.value.name));
    }
    out.sort((a, b) => a.value.compareTo(b.value));
    return out;
  }

  Future<void> updateM3uStreamMapping({
    required String cacheKey,
    required String streamUrl,
    required String xmlChannelId,
    required List<Channel> liveChannels,
  }) async {
    if (xmlChannelId.isEmpty) {
      _m3uStreamUrlToXmlId.remove(streamUrl);
    } else {
      _m3uStreamUrlToXmlId[streamUrl] = xmlChannelId;
    }
    loadGeneration.value++;
    await replaceM3uMappingsPersisted(cacheKey, liveChannels);
  }

  Future<void> replaceM3uMappingsPersisted(
    String? cacheKey,
    List<Channel> liveChannels,
  ) async {
    if (cacheKey == null || cacheKey.isEmpty) return;
    await EpgSqliteStore.replaceM3uMappings(
      cacheKey,
      Map<String, String>.from(_m3uStreamUrlToXmlId),
    );
  }

  /// Obx / liste yenilemesi için; EPG yüklendikçe artar.
  final RxInt loadGeneration = 0.obs;

  /// Disk önbelleği: [logicalKey] ile [EpgSnapshotKeys.logicalKeyFor] aynı olmalı.
  Future<bool> tryRestoreFromDiskIfFresh(
    String logicalKey, {
    bool markXtreamSuccess = false,
  }) async {
    try {
      final raw = await EpgSnapshotStore.readRaw(logicalKey);
      if (raw == null) return false;
      // Çöz + entity + sıralama TAMAMI isolate'te → ana iş parçacığı bloke
      // olmaz (splash imleci donmaz).
      final decoded = await decodeAndBuildEpgSnapshotInIsolate(raw);
      if (decoded == null) return false;
      if (decoded.key != logicalKey) return false;
      final savedAt = decoded.savedAtMs;
      if (savedAt == null) return false;
      final age = DateTime.now().millisecondsSinceEpoch - savedAt;
      final ttlMs = Get.find<AppSettingsService>().epgDiskCacheTtlMs;
      if (age < 0 || age > ttlMs) return false;
      if (!decoded.hasData) return false;

      // Listeler isolate'te zaten sıralandı; ana iş parçacığında yalnızca
      // atama + cache temizliği yapılır (ucuz).
      _channels.assignAll(decoded.channels);
      _programmes.assignAll(decoded.programmes);
      _windowProgrammesCache.clear();
      _currentProgrammeIndexCache.clear();
      if (markXtreamSuccess) {
        _markXtreamSuccessFromSnapshot(savedAt);
      }

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

  /// TTL dolmuş olsa bile (çevrimdışı / sıra gelmemiş yenileme) son kayıtlı anlık görüntüyü yükler.
  Future<bool> tryRestoreFromDiskIgnoringTtl(
    String logicalKey, {
    bool markXtreamSuccess = false,
  }) async {
    try {
      final raw = await EpgSnapshotStore.readRaw(logicalKey);
      if (raw == null) return false;
      final decoded = await decodeAndBuildEpgSnapshotInIsolate(raw);
      if (decoded == null) return false;
      if (decoded.key != logicalKey) return false;
      if (!decoded.hasData) return false;
      final savedAt = decoded.savedAtMs;

      _channels.assignAll(decoded.channels);
      _programmes.assignAll(decoded.programmes);
      _windowProgrammesCache.clear();
      _currentProgrammeIndexCache.clear();
      if (markXtreamSuccess) {
        _markXtreamSuccessFromSnapshot(savedAt);
      }

      loadGeneration.value++;
      debugPrint(
        'mina_iptv: EPG restored from disk (ignoring TTL, ${_channels.length} ch)',
      );
      return true;
    } catch (e) {
      debugPrint('mina_iptv: EPG stale cache restore failed: $e');
      return false;
    }
  }

  /// Diskten geri yüklenen snapshot tipik olarak son başarılı Xtream
  /// `loadXtreamAllLiveEpg` çıktısıdır (M3U snapshot ayrı bir yola çıkar).
  /// UI sayaçlarının "boş" görünmesini engellemek için sayaçları ayarlarız.
  void _markXtreamSuccessFromSnapshot(int? savedAt) {
    if (_channels.isEmpty && _programmes.isEmpty) return;
    xtreamChannelCount.value = _channels.length;
    xtreamProgrammeCount.value = _programmes.length;
    xtreamLastSuccess.value = true;
    xtreamLastError.value = '';
    xtreamLastFetchMs.value = savedAt ?? DateTime.now().millisecondsSinceEpoch;
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
      unawaited(
        EpgSqliteStore.replaceSnapshot(
          sourceKey: logicalKey,
          channels: Map<String, EpgChannel>.from(_channels),
          programmes: Map<String, List<EpgProgramme>>.from(
            _programmes.map(
              (k, v) => MapEntry(k, List<EpgProgramme>.from(v)),
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('mina_iptv: EPG snapshot save failed: $e');
    }
  }

  /// JSON önbellekten belleğe yüklendikten sonra SQLite kopyasını doldurur (yük yükseltme).
  Future<void> persistSqliteMirrorOnly(String logicalKey) async {
    if (logicalKey.isEmpty) return;
    if (_channels.isEmpty && _programmes.isEmpty) return;
    try {
      await EpgSqliteStore.replaceSnapshot(
        sourceKey: logicalKey,
        channels: Map<String, EpgChannel>.from(_channels),
        programmes: Map<String, List<EpgProgramme>>.from(
          _programmes.map(
            (k, v) => MapEntry(k, List<EpgProgramme>.from(v)),
          ),
        ),
      );
    } catch (e) {
      debugPrint('mina_iptv: EPG SQLite mirror failed: $e');
    }
  }

  /// M3U XMLTV: kanal listesi ile XML kanallarını eşleştir; URL→XML id kalıcıdır.
  Future<void> applyM3uXmltvChannelMappings({
    required String? cacheKey,
    required List<Channel> liveChannels,
  }) async {
    if (cacheKey == null || cacheKey.isEmpty) {
      _m3uStreamUrlToXmlId.clear();
      loadGeneration.value++;
      return;
    }

    try {
      _m3uStreamUrlToXmlId
        ..clear()
        ..addAll(await EpgSqliteStore.readM3uMappings(cacheKey));

      final xmlCandidates = <XmlTvMatchCandidate>[];
      for (final e in _channels.entries) {
        final id = e.key;
        final list = _programmes[id];
        if (list == null || list.isEmpty) continue;
        xmlCandidates.add(
          XmlTvMatchCandidate(
            xmlChannelId: id,
            displayName: e.value.name,
          ),
        );
      }

      final needs = <M3uMatchNeed>[];
      for (final ch in liveChannels) {
        if (_playlistChannelHasXmltvRows(ch)) continue;
        needs.add(
          M3uMatchNeed(streamUrl: ch.streamUrl, playlistName: ch.name),
        );
      }

      if (needs.isNotEmpty && xmlCandidates.isNotEmpty) {
        final matched = await compute(
          m3uXmltvMatchIsolate,
          <String, dynamic>{
            'xml': [
              for (final x in xmlCandidates)
                <String, String>{'id': x.xmlChannelId, 'name': x.displayName},
            ],
            'needs': [
              for (final n in needs)
                <String, String>{'u': n.streamUrl, 'n': n.playlistName},
            ],
          },
        );
        _m3uStreamUrlToXmlId.addAll(matched);
      }

      loadGeneration.value++;
      await EpgSqliteStore.replaceM3uMappings(
        cacheKey,
        Map<String, String>.from(_m3uStreamUrlToXmlId),
      );
    } catch (e, st) {
      debugPrint('mina_iptv: M3U XMLTV mapping failed: $e\n$st');
    }
  }

  bool _playlistChannelHasXmltvRows(Channel ch) {
    final id = ch.epgChannelId?.trim();
    if (id != null && id.isNotEmpty) {
      final list = _programmes[id];
      if (list != null && list.isNotEmpty) return true;
    }
    return false;
  }

  int get loadedXmlChannelCount => _channels.length;

  int get loadedProgrammeKeyCount => _programmes.length;

  /// Bellekte çözümlenmiş EPG verisi var mı (XMLTV veya Xtream birleşimi).
  bool hasLoadedGuideData() =>
      _programmes.isNotEmpty || _channels.isNotEmpty;

  Future<void> loadEpg(String url) async {
    await loadEpgFirstSuccessful(<String>[url]);
  }

  /// Sırayla dener; ilk başarılı XMLTV yüklemesinde durur (yedek mirror için).
  Future<void> loadEpgFirstSuccessful(Iterable<String> urls) async {
    if (!_epgFeatureEnabled) return;
    final list = urls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (list.isEmpty) return;
    isLoading.value = true;
    try {
      for (final url in list) {
        try {
          debugPrint('mina_iptv: EPG candidate trying: $url');
          await _fetchAndApplyXmlTv(url);
          if (hasLoadedGuideData()) {
            debugPrint('mina_iptv: EPG candidate success: $url');
            return;
          }
        } catch (e) {
          debugPrint('mina_iptv: EPG candidate failed ($url): $e');
        }
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchAndApplyXmlTv(String url) async {
    final lower = url.toLowerCase();
    final receiveTimeout =
        lower.contains('iptv-org.github.io') ||
                lower.contains('worker-9dd4.onrender.com') ||
                lower.contains('epgshare01.online') ||
                lower.contains('epg.pw')
            ? const Duration(seconds: 600)
            : const Duration(seconds: 120);
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: receiveTimeout,
      ),
    );
    final raw = response.data;
    if (raw == null || raw.isEmpty) return;

    final result = await compute(parseXmlTvBytesIsolate, {
      'bytes': raw,
      'isGz': lower.endsWith('.gz'),
    });
    final newChannels = result['channels'] as Map<String, EpgChannel>;
    final progMap = result['programmes'] as Map<String, List<EpgProgramme>>;

    // Veri gerçekten değişti mi? (kanal/programme sayıları aynı + key set
    // aynı → ana ekran widget'larını gereksiz rebuild etmemek için
    // `loadGeneration++` atlanır). Aynı XMLTV'nin tekrar indirilmesi (snapshot
    // restore sonrası `_fetchAndApplyXmlTv` veya yenileme) sıklıkla aynı veriyi
    // yazar; bu durumda Obx dinleyicilerini boş yere tetiklemeyiz.
    final sizeChanged = newChannels.length != _channels.length ||
        progMap.length != _programmes.length;
    var keysetChanged = sizeChanged;
    if (!keysetChanged) {
      // Aynı boyutta — key set'leri farklı olabilir, hızlıca karşılaştır.
      for (final k in newChannels.keys) {
        if (!_channels.containsKey(k)) {
          keysetChanged = true;
          break;
        }
      }
    }

    // [E1] Aynı kanal seti ise assignAll atlanır (gereksiz Rx bildirimi yok).
    if (keysetChanged) {
      _channels.assignAll(newChannels);
      for (final e in progMap.entries) {
        _setProgrammesForKey(e.key, e.value);
      }
    }
    if (keysetChanged) {
      loadGeneration.value++;
      EpgPerfTelemetry.loadGenerationBumps++;
    } else {
      EpgPerfTelemetry.loadGenerationSkipped++;
    }
    debugPrint(
      'mina_iptv: EPG loaded. Channels: ${_channels.length}, '
      'prog keys: ${_programmes.length}'
      '${keysetChanged ? '' : ' (no change, gen kept)'} · ${EpgPerfTelemetry.summaryLine()}',
    );
  }

  EpgProgramme? getCurrentProgramme(String? epgId) {
    if (!_epgFeatureEnabled) return null;
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

  /// XMLTV `tvg-id` / `epg_channel_id`, ardından M3U URL eşlemesi, son olarak Xtream
  /// **[stream_id]** anahtarı.
  EpgProgramme? getCurrentProgrammeForLiveChannel(Channel ch) {
    if (!_epgFeatureEnabled) return null;
    final direct = ch.epgChannelId?.trim();
    if (direct != null && direct.isNotEmpty) {
      final prog = getCurrentProgramme(direct);
      if (prog != null) return prog;
    }
    final mapped = _m3uStreamUrlToXmlId[ch.streamUrl];
    if (mapped != null) {
      final prog = getCurrentProgramme(mapped);
      if (prog != null) return prog;
    }
    final byId = getCurrentProgramme(ch.id.toString());
    if (byId != null) return byId;

    // Eğer normal EPG'de bulunamadıysa, GlobalEpgService'den (Bellek Cache) kontrol et
    if (Get.isRegistered<GlobalEpgService>()) {
      final global = Get.find<GlobalEpgService>();
      final list = global.getProgrammesForChannelName(ch.name);
      if (list.isNotEmpty) {
        // İkili arama (binary search) mantığını buraya da uygula
        final now = DateTime.now();
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
            return p;
          }
        }
      }
    }

    return null;
  }

  /// Canlı kanal için şu anki yayından sonraki program (varsa).
  EpgProgramme? getNextProgrammeForLiveChannel(Channel ch) {
    if (!_epgFeatureEnabled) return null;
    final all = getFullDayProgrammesForLiveChannel(ch);
    if (all.isEmpty) return null;
    final now = DateTime.now();

    for (var i = 0; i < all.length; i++) {
      final p = all[i];
      if (!p.end.isAfter(now)) continue;
      if (p.start.isAfter(now)) return p;
      if (i + 1 < all.length) {
        final next = all[i + 1];
        if (next.start.isAfter(now) || next.end.isAfter(now)) {
          return next;
        }
      }
      return null;
    }
    return null;
  }

  List<EpgProgramme> getFullDayProgrammes(String? epgId) {
    final key = epgId?.trim();
    if (key == null || key.isEmpty) return [];
    return List<EpgProgramme>.from(_programmes[key] ?? const []);
  }

  void _setProgrammesForKey(String key, List<EpgProgramme> list) {
    final now = DateTime.now();
    final windowStart = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final windowEnd = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 2));
    final trimmed = list
        .where((p) => p.end.isAfter(windowStart) && p.start.isBefore(windowEnd))
        .toList(growable: false);
    final sorted = List<EpgProgramme>.from(trimmed)
      ..sort((a, b) => a.start.compareTo(b.start));
    _programmes[key] = sorted;
    _invalidateCachesForProgrammeKey(key);
  }

  void _invalidateCachesForProgrammeKey(String key) {
    _currentProgrammeIndexCache.remove(key);
    final prefix = '$key|';
    _windowProgrammesCache.removeWhere((k, _) => k.startsWith(prefix));
  }

  List<EpgProgramme> getFullDayProgrammesForLiveChannel(Channel ch) {
    if (!_epgFeatureEnabled) return const <EpgProgramme>[];
    final direct = ch.epgChannelId?.trim();
    if (direct != null && direct.isNotEmpty) {
      final list = _programmes[direct];
      if (list != null && list.isNotEmpty) {
        return getFullDayProgrammes(direct);
      }
    }
    final mapped = _m3uStreamUrlToXmlId[ch.streamUrl];
    if (mapped != null) {
      final ml = _programmes[mapped];
      if (ml != null && ml.isNotEmpty) {
        return getFullDayProgrammes(mapped);
      }
    }
    final byId = getFullDayProgrammes(ch.id.toString());
    if (byId.isNotEmpty) return byId;

    // GlobalEpgService Fallback
    if (Get.isRegistered<GlobalEpgService>()) {
      return Get.find<GlobalEpgService>().getProgrammesForChannelName(ch.name);
    }

    return [];
  }

  /// Zaman çizelgesi: [windowStart, windowEnd) ile kesişen programlar (sıralı).
  List<EpgProgramme> programmesInWindowForLiveChannel(
    Channel ch,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final cacheKey =
        '${ch.id}|${ch.name}|${windowStart.millisecondsSinceEpoch}|${windowEnd.millisecondsSinceEpoch}';
    final cached = _windowProgrammesCache[cacheKey];
    if (cached != null) return cached;
    final all = getFullDayProgrammesForLiveChannel(ch);
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

  /// Xtream `get_all_live_epg` çıktısını **[stream_id]** string anahtarıyla yazar (canlı EPG).
  ///
  /// Büyük listelerde parça parça yazar; UI donmamak için her chunk sonrası
  /// kısa gecikme ile olay döngüsüne döner. [loadGeneration] her chunk yerine
  /// tüm tur bitiminde **bir kez** ve yalnız yeni veri eklendiyse artar — Obx
  /// dinleyicilerinin her chunk için rebuild olmasını engeller.
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
        _setProgrammesForKey(k, list);
        streams++;
        programmes += list.length;
      }
      if (end < entries.length && entries.length > 800) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (streams > 0) {
      loadGeneration.value++;
    }
    debugPrint(
      'mina_iptv: Xtream API EPG merged: $streams streams, $programmes programmes',
    );
  }

  /// Xtream canlı EPG: önce `get_all_live_epg` (stream_id), sonra panel `xmltv.php`.
  ///
  /// İki kaynaktan da hiç veri gelmediyse [xtreamLastSuccess] false olur ve
  /// [xtreamLastError] doldurulur — UI bunu görüp GitHub yedeğin devrede
  /// olduğunu kullanıcıya gösterebilir.
  ///
  /// Eş zamanlı çağrılar paylaşılır; ardışık çağrılar [_kXtreamLoadThrottleMs]
  /// içinde no-op. [force]=true throttle'ı atlar (kullanıcı tetiklemesi).
  Future<void> loadXtreamAllLiveEpg(
    XtreamApi api, {
    bool force = false,
  }) {
    if (!_epgFeatureEnabled) return Future<void>.value();
    final pending = _inflightXtreamLoad;
    if (pending != null) return pending;

    // baseUrl + username Xtream hesabını benzersizleştirir; password ve port
    // baseUrl içinde zaten gömülü. Throttle bu kimlik için çalışır.
    final fp = '${api.baseUrl}|${api.username}';
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        fp == _lastXtreamFingerprint &&
        now - _lastXtreamLoadAtMs < _kXtreamLoadThrottleMs) {
      final ageSec = ((now - _lastXtreamLoadAtMs) / 1000).toStringAsFixed(1);
      debugPrint('mina_iptv: Xtream EPG - skip (throttled, age ${ageSec}s)');
      EpgPerfTelemetry.xtreamLoadThrottled++;
      return Future<void>.value();
    }

    EpgPerfTelemetry.xtreamLoadStarted++;
    final fut = _runLoadXtreamAllLiveEpg(api);
    _inflightXtreamLoad = fut;
    return fut.whenComplete(() {
      _inflightXtreamLoad = null;
      _lastXtreamFingerprint = fp;
      _lastXtreamLoadAtMs = DateTime.now().millisecondsSinceEpoch;
    });
  }

  Future<void> _runLoadXtreamAllLiveEpg(XtreamApi api) async {
    var apiStreams = 0;
    final errors = <String>[];
    var apiOk = false;
    var xmltvOk = false;

    try {
      final map = await api.getAllLiveEpg(_dio);
      apiStreams = map.length;
      await mergeXtreamApiEpgByStreamId(map);
      // Bazı paneller `action=get_all_live_epg`'yi desteklemiyor ve boş
      // gövde döndürüyor; bunu hata saymıyoruz — `xmltv.php` yedektir.
      apiOk = apiStreams > 0;
      if (apiStreams == 0) {
        debugPrint(
          'mina_iptv: get_all_live_epg: no stream EPG from panel '
          '(action unsupported or empty) — using xmltv.php',
        );
      }
    } catch (e, st) {
      debugPrint('mina_iptv: get_all_live_epg failed (non-fatal): $e\n$st');
      errors.add('get_all_live_epg: $e');
    }

    try {
      final url = api.xmlTvUrl;
      debugPrint('mina_iptv: Xtream panel XMLTV: $url');
      await _fetchAndApplyXmlTv(url);
      debugPrint(
        'mina_iptv: Xtream EPG done — api streams: $apiStreams, '
        'prog keys: ${_programmes.length}, xmltv channels: ${_channels.length}',
      );
      xmltvOk = true;
    } catch (e, st) {
      debugPrint('mina_iptv: Xtream panel XMLTV failed (non-fatal): $e\n$st');
      errors.add('xmltv.php: $e');
    }

    // Mutlak değere bakıyoruz: snapshot restore'dan sonra XMLTV aynı
    // programları yeniden yazsa bile fark 0 olur, ama gerçekte Xtream
    // sunucusundan veri geliyor → başarılı saymalıyız.
    xtreamProgrammeCount.value = _programmes.length;
    xtreamChannelCount.value = _channels.length;
    xtreamLastFetchMs.value = DateTime.now().millisecondsSinceEpoch;

    // Başarı kriteri: en az bir Xtream kaynağı hatasız tamamlandı VE
    // EpgService dolu. Hem hata aldıysak hem de veri yoksa — başarısız.
    final dataPresent = _channels.isNotEmpty || _programmes.isNotEmpty;
    final atLeastOneOk = apiOk || xmltvOk;
    xtreamLastSuccess.value = atLeastOneOk && dataPresent;
    xtreamLastError.value = xtreamLastSuccess.value ? '' : errors.join(' · ');
  }

  /// Global EPG servisi ile M3U için dinamik ülke bazlı EPG yükle
  Future<void> loadGlobalEpgForM3U(List<Channel> channels) async {
    if (!_epgFeatureEnabled) return;
    try {
      final globalEpgService = Get.find<GlobalEpgService>();
      await globalEpgService.loadGlobalEpgForChannels(channels);
    } catch (e, st) {
      debugPrint('mina_iptv: Global EPG failed (non-fatal): $e\n$st');
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
    _m3uStreamUrlToXmlId.clear();
    _windowProgrammesCache.clear();
    _currentProgrammeIndexCache.clear();
    xtreamProgrammeCount.value = 0;
    xtreamChannelCount.value = 0;
    xtreamLastSuccess.value = false;
    xtreamLastError.value = '';
    xtreamLastFetchMs.value = 0;
    // Throttle sıfırla: kullanıcı yenile dediğinde 30sn beklemeden tekrar dener.
    _lastXtreamFingerprint = '';
    _lastXtreamLoadAtMs = 0;
    loadGeneration.value++;
  }
}
