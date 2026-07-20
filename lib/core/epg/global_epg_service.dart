import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/channel.dart';
import '../../domain/entities/epg_entities.dart';
import '../../data/remote/xmltv_parser.dart' as xmltv_parser;
import '../services/app_settings_service.dart';

import '../epg/iptv_org_epg.dart';
import '../epg/m3u_xmltv_name_matcher.dart';
import '../telemetry/epg_perf_telemetry.dart';

/// Global EPG Manager - Dünya genelinde çalışan dinamik EPG servisi
class GlobalEpgService extends GetxService {
  static const int _maxConcurrentDownloads = 4;
  static const Duration _downloadTimeout = Duration(seconds: 30);

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: _downloadTimeout,
    receiveTimeout: _downloadTimeout,
    sendTimeout: _downloadTimeout,
  ));

  Database? _db;
  final RxBool isLoading = false.obs;
  final RxInt loadGeneration = 0.obs;
  final RxSet<String> activeCountries = <String>{}.obs;

  /// Kanal adı veya ID bazlı hızlı erişim için bellek içi cache
  final Map<String, List<EpgProgramme>> _memoryProgrammeCache = {};
  final Map<String, String> _channelNameToXmlId = {};

  // ---------------------------------------------------------------------------
  // Throttle / paylaşılan in-flight Future. Aynı playlist için kısa süre içinde
  // (özellikle splash → background-refresh → home build sırası) art arda 10+
  // çağrı geliyordu; her biri SQLite'a vurup `loadGeneration`'ı tetikleyince
  // ana ekranda kasmaya yol açıyordu. Bu yapı eş zamanlı çağrıları paylaşır ve
  // tamamlananı kısa süre cache'ler.
  // ---------------------------------------------------------------------------

  Future<void>? _inflightLoad;
  Future<void>? _inflightFetch;
  int _lastLoadFingerprint = 0;
  int _lastLoadAtMs = 0;
  static const int _loadThrottleMs = 30 * 1000;

  /// [C2] Ülke kodları + DB satır sayısı değişmeden norm→xmlId haritasını yeniden
  /// hesaplamayı atlarız (her `fetchProgrammesForPlaylist` turunda tam tablo taraması
  /// yerine bellekten eşleştirme).
  String _cachedNormMapKey = '';
  Map<String, Set<String>> _cachedNormToXmlIds = {};

  /// [A3] Bellek cache imzası — eşleşen kanal/programme sayısı değişmediyse
  /// `loadGeneration++` atlanır.
  int _lastMemoryCacheChannelCount = -1;
  int _lastMemoryCacheProgrammeCount = -1;

  static int _fingerprintChannels(List<Channel> channels) {
    var hash = channels.length & 0x7fffffff;
    for (final c in channels) {
      hash = (hash * 31 + c.name.hashCode) & 0x7fffffff;
    }
    return hash;
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initDatabase();
    unawaited(_warmupCache());
  }

  /// Veritabanındaki kanalları belleğe al
  Future<void> _warmupCache() async {
    if (_db == null) await _initDatabase();
    try {
      final channels = await _db!.query('global_epg_channel');
      for (final row in channels) {
        final name = row['display_name'] as String;
        final xmlId = row['xml_channel_id'] as String;
        _channelNameToXmlId[name.toLowerCase()] = xmlId;
      }
      debugPrint('mina_iptv: Global EPG - Cache warmed up with ${_channelNameToXmlId.length} names');
    } catch (e) {
      debugPrint('mina_iptv: Global EPG - Cache warmup failed: $e');
    }
  }

  /// Kanal ismiyle bellekteki programları bul
  List<EpgProgramme> getProgrammesForChannelName(String name) {
    final xmlId = _channelNameToXmlId[name.toLowerCase()];
    if (xmlId == null) return [];
    return _memoryProgrammeCache[xmlId] ?? [];
  }

  /// Belleğe yüklenmiş GitHub EPG kanal sayısı (playlist'le eşleşmiş).
  int get loadedMemoryChannelCount => _memoryProgrammeCache.length;

  /// Belleğe yüklenmiş GitHub EPG toplam program kaydı sayısı.
  int get loadedMemoryProgrammeCount {
    var n = 0;
    for (final list in _memoryProgrammeCache.values) {
      n += list.length;
    }
    return n;
  }

  @override
  void onClose() {
    _db?.close();
    _dio.close();
    super.onClose();
  }

  /// M3U playlist'ini analiz ederek gerekli ülke kodlarını belirle
  Future<Set<String>> _analyzePlaylistForCountries(List<Channel> channels) async {
    final countryPatterns = {
      'TR': RegExp(r'\b(TR|TURK|TÜRKİYE|TURKEY)\b', caseSensitive: false),
      'DE': RegExp(r'\b(DE|GERMANY|ALMANYA|DEUTSCH)\b', caseSensitive: false),
      'FR': RegExp(r'\b(FR|FRANCE|FRENCH)\b', caseSensitive: false),
      'US': RegExp(r'\b(US|USA|AMERICA|AMERIKA)\b', caseSensitive: false),
      'UK': RegExp(r'\b(UK|UNITED|KINGDOM|BRITISH)\b', caseSensitive: false),
      'IT': RegExp(r'\b(IT|ITALY|ITALIA|İTALYA)\b', caseSensitive: false),
      'ES': RegExp(r'\b(ES|SPAIN|ESPAÑA|İSPANYA)\b', caseSensitive: false),
      'NL': RegExp(r'\b(NL|NETHERLANDS|HOLLAND)\b', caseSensitive: false),
      'BE': RegExp(r'\b(BE|BELGIUM|BELGIKA)\b', caseSensitive: false),
      'AT': RegExp(r'\b(AT|AUSTRIA|AVUSTURYA)\b', caseSensitive: false),
      'CH': RegExp(r'\b(CH|SWITZERLAND|İSVİÇRE)\b', caseSensitive: false),
      'PL': RegExp(r'\b(PL|POLAND|POLONYA)\b', caseSensitive: false),
      'CZ': RegExp(r'\b(CZ|CZECH|ÇEK)\b', caseSensitive: false),
      'SK': RegExp(r'\b(SK|SLOVAK|SLOVAKYA)\b', caseSensitive: false),
      'HU': RegExp(r'\b(HU|HUNGARY|MACARISTAN)\b', caseSensitive: false),
      'RO': RegExp(r'\b(RO|ROMANIA|ROMANYA)\b', caseSensitive: false),
      'BG': RegExp(r'\b(BG|BULGARIA|BULGARISTAN)\b', caseSensitive: false),
      'HR': RegExp(r'\b(HR|CROATIA|HIRVATISTAN)\b', caseSensitive: false),
      'RS': RegExp(r'\b(RS|SERBIA|SIRBISTAN)\b', caseSensitive: false),
      'GR': RegExp(r'\b(GR|GREECE|YUNANISTAN)\b', caseSensitive: false),
      'PT': RegExp(r'\b(PT|PORTUGAL|PORTEKİZ)\b', caseSensitive: false),
      'SE': RegExp(r'\b(SE|SWEDEN|İSVEÇ)\b', caseSensitive: false),
      'NO': RegExp(r'\b(NO|NORWAY|NORVEÇ)\b', caseSensitive: false),
      'DK': RegExp(r'\b(DK|DENMARK|DANIMARKA)\b', caseSensitive: false),
      'FI': RegExp(r'\b(FI|FINLAND|FINLANDİYA)\b', caseSensitive: false),
      'EE': RegExp(r'\b(EE|ESTONIA|ESTONYA)\b', caseSensitive: false),
      'LV': RegExp(r'\b(LV|LATVIA|LETLAND)\b', caseSensitive: false),
      'LT': RegExp(r'\b(LT|LITHUANIA|LİTVANYA)\b', caseSensitive: false),
    };

    final detectedCountries = <String>{};
    
    for (final channel in channels) {
      final searchText = channel.name.toLowerCase();
      
      for (final entry in countryPatterns.entries) {
        if (entry.value.hasMatch(searchText)) {
          detectedCountries.add(entry.key);
        }
      }
    }

    debugPrint('mina_iptv: Global EPG - Detected countries: ${detectedCountries.join(', ')}');
    return detectedCountries;
  }

  /// Playlist'ten ülke tahmini; indirme yalnızca TTL dolduğunda veya SQLite
  /// boşken. Eş zamanlı çağrılar tek bir Future'ı paylaşır, ardışık çağrılar
  /// [_loadThrottleMs] içinde "no-op"; bu, splash+settings+home tetiklemelerinin
  /// üst üste binip kasma yaratmasını engeller. [force]=true throttle'ı atlar.
  Future<void> loadGlobalEpgForChannels(
    List<Channel> channels, {
    bool force = false,
  }) {
    if (Get.isRegistered<AppSettingsService>() &&
        !Get.find<AppSettingsService>().epgEnabled.value) {
      return Future<void>.value();
    }
    // Devam eden çağrı varsa onu paylaş.
    final pending = _inflightLoad;
    if (pending != null) return pending;

    // Throttle penceresi içinde aynı playlist için tekrar isteği yutuyoruz.
    final fp = _fingerprintChannels(channels);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        fp == _lastLoadFingerprint &&
        now - _lastLoadAtMs < _loadThrottleMs) {
      debugPrint(
        'mina_iptv: Global EPG - skip (throttled, age '
        '${((now - _lastLoadAtMs) / 1000).toStringAsFixed(1)}s)',
      );
      EpgPerfTelemetry.globalLoadThrottled++;
      return Future<void>.value();
    }

    EpgPerfTelemetry.globalLoadStarted++;
    final fut = _runLoadGlobalEpgForChannels(channels, fp, force: force);
    _inflightLoad = fut;
    return fut.whenComplete(() {
      _inflightLoad = null;
      _lastLoadFingerprint = fp;
      _lastLoadAtMs = DateTime.now().millisecondsSinceEpoch;
    });
  }

  Future<void> _runLoadGlobalEpgForChannels(
    List<Channel> channels,
    int fp, {
    bool force = false,
  }) async {
    try {
      isLoading.value = true;

      final countries = await _analyzePlaylistForCountries(channels);
      activeCountries.assignAll(countries);

      final app = Get.find<AppSettingsService>();
      final stats = await getDatabaseStats();
      final hasDb = (stats['channels'] ?? 0) > 0;
      if (!force && !app.shouldRefreshGlobalEpgFromNetwork(hasPersistedSqliteData: hasDb)) {
        if (app.lastGlobalEpgFetchMs.value <= 0 && hasDb) {
          await app.markGlobalEpgFetchedOk();
        }
        await fetchProgrammesForPlaylist(channels);
        return;
      }

      if (countries.isEmpty) {
        debugPrint('mina_iptv: Global EPG - No countries detected, using fallback');
        final fallback = Get.locale?.languageCode ?? 'tr';
        await _downloadAndMergeEpg([fallback], channels);
      } else {
        await _downloadAndMergeEpg(countries.toList(), channels);
      }
      await app.markGlobalEpgFetchedOk();
    } catch (e, st) {
      debugPrint('mina_iptv: Global EPG load failed: $e\n$st');
    } finally {
      isLoading.value = false;
      loadGeneration.value++;
    }
  }

  /// Belirlenen ülkeler için EPG dosyalarını indir ve birleştir
  Future<void> _downloadAndMergeEpg(List<String> countryCodes, List<Channel> channels) async {
    final semaphore = Semaphore(_maxConcurrentDownloads);
    final allValidResults = <EpgData>[];
    var urlAttempts = 0;

    for (final code in countryCodes) {
      final urls = IptvOrgEpg.getCountryGuideUrls(code);
      if (urls.isEmpty) continue;

      for (final url in urls) {
        urlAttempts++;
        final data = await _downloadSingleUrlEpg(code, url, semaphore);
        if (data != null) {
          allValidResults.add(data);
        }
      }
    }

    if (allValidResults.isEmpty) {
      throw Exception('No valid EPG data downloaded');
    }

    // Veritabanını güncelle
    await _mergeEpgDataToDatabase(allValidResults, channels);

    debugPrint(
      'mina_iptv: Global EPG - Merged ${allValidResults.length}/$urlAttempts '
      'sources OK · ${EpgPerfTelemetry.summaryLine()}',
    );
  }

  /// Tek bir URL'den EPG dosyasını indir
  Future<EpgData?> _downloadSingleUrlEpg(String countryCode, String url, Semaphore semaphore) async {
    await semaphore.acquire();
    try {
      debugPrint('mina_iptv: Global EPG - Downloading: $url');
      
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final raw = response.data;
      if (raw == null || raw.isEmpty) return null;
      
      // Gzip decompress if needed
      final isGzip = url.endsWith('.gz') || (raw.length >= 2 && raw[0] == 0x1f && raw[1] == 0x8b);
      List<int> xmlBytes;
      if (isGzip) {
        try {
          xmlBytes = gzip.decode(raw);
        } catch (e) {
          // If it fails to decode, it might have been auto-decompressed by Dio due to Content-Encoding headers.
          xmlBytes = raw;
        }
      } else {
        xmlBytes = raw;
      }
      
      final xmlString = utf8.decode(xmlBytes, allowMalformed: true);
      
      // Parse XML (isolate'da chunked)
      final receivePort = ReceivePort();
      await Isolate.spawn(
        xmltv_parser.parseXmlTvChunkedIsolate,
        {'sendPort': receivePort.sendPort, 'xmlString': xmlString},
      );

      final channels = <String, EpgChannel>{};
      final programmes = <String, List<EpgProgramme>>{};

      await for (final msg in receivePort) {
        if (msg is Map<String, dynamic>) {
          final type = msg['type'];
          if (type == 'channels') {
            channels.addAll(msg['data'] as Map<String, EpgChannel>);
          } else if (type == 'programmes') {
            final chunk = msg['data'] as Map<String, List<EpgProgramme>>;
            for (final e in chunk.entries) {
              programmes.putIfAbsent(e.key, () => []).addAll(e.value);
            }
          } else if (type == 'done') {
            receivePort.close();
            break;
          } else if (type == 'error') {
            receivePort.close();
            throw Exception('EPG Isolate Error: ${msg['error']} \n ${msg['stack']}');
          }
        }
      }
      
      return EpgData(
        countryCode: countryCode,
        channels: channels,
        programmes: programmes,
        sourceUrl: url,
      );
      
    } catch (e) {
      // Tek satır; 404 beklenen aynalar için tam stack basılmaz ([F2]).
      debugPrint(
        'mina_iptv: Global EPG - source failed ($countryCode): '
        '${e is DioException ? 'HTTP ${e.response?.statusCode ?? '?'}' : e.runtimeType}',
      );
      return null;
    } finally {
      semaphore.release();
    }
  }

  /// EPG verilerini SQLite veritabanına birleştir.
  ///
  /// Aynı ülke için birden çok XML kaynağı (örn. TR için epgshare01 + globetvapp
  /// + MuazT) gelebilir; bu kaynaklar genelde aynı kanal/saat dilimini farklı
  /// detaylarla yayınlar. Önce her benzersiz ülke için tek bir DELETE yapıp
  /// ardından tüm kaynakları üst üste yazıyoruz — INSERT çakışınca son veri
  /// kazanır (ConflictAlgorithm.replace). Aynı XML dosyasında aynı programın
  /// iki kez listelenmesi durumunda da hata fırlatmaz.
  Future<void> _mergeEpgDataToDatabase(List<EpgData> epgDataList, List<Channel> channels) async {
    if (_db == null) await _initDatabase();

    // Benzersiz ülke kodları — her ülkenin eski kayıtlarını bir kez sileceğiz.
    final countries = epgDataList.map((e) => e.countryCode).toSet();

    await _db!.transaction((txn) async {
      // 1) Önce tüm hedef ülkelerin eski verilerini topluca temizle.
      for (final code in countries) {
        await txn.delete(
          'global_epg_programme',
          where: 'country_code = ?',
          whereArgs: [code],
        );
        await txn.delete(
          'global_epg_channel',
          where: 'country_code = ?',
          whereArgs: [code],
        );
      }

      // 2) Sonra her kaynağı üst üste INSERT et; çakışırsa replace ile son veri kazanır.
      for (final epgData in epgDataList) {
        final channelBatch = txn.batch();
        for (final channel in epgData.channels.entries) {
          channelBatch.insert(
            'global_epg_channel',
            {
              'country_code': epgData.countryCode,
              'xml_channel_id': channel.key,
              'display_name': channel.value.name,
              'logo_url': channel.value.logoUrl,
              'source_file': epgData.sourceUrl,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await channelBatch.commit(noResult: true);

        const chunkSize = 150;
        var programmeBatch = txn.batch();
        var count = 0;

        for (final programme in epgData.programmes.entries) {
          for (final prog in programme.value) {
            programmeBatch.insert(
              'global_epg_programme',
              {
                'country_code': epgData.countryCode,
                'xml_channel_id': programme.key,
                'start_ms': prog.start.millisecondsSinceEpoch,
                'end_ms': prog.end.millisecondsSinceEpoch,
                'title': prog.title,
                'description': prog.description,
                'source_file': epgData.sourceUrl,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            count++;
            if (count % chunkSize == 0) {
              await programmeBatch.commit(noResult: true);
              programmeBatch = txn.batch();
            }
          }
        }

        if (count % chunkSize != 0) {
          await programmeBatch.commit(noResult: true);
        }
      }
    });

    // Yeni ülke verisi yazıldı — norm haritası cache geçersiz.
    _cachedNormMapKey = '';
    _cachedNormToXmlIds.clear();
    unawaited(_deleteNormMapDiskCache());

    // Playlist kanallarını veritabanından bulup belleğe yükle
    await fetchProgrammesForPlaylist(channels);

    debugPrint('mina_iptv: Global EPG - Database updated successfully');
  }

  /// Playlist'teki kanalları veritabanında arayıp programlarını belleğe çeker.
  ///
  /// `display_name` üzerinde NOCASE eşleşme çok sık başarısız oluyor (XML
  /// kaynakları "TR| beIN Sports 3 HD" gibi prefix'li adlar verirken playlist
  /// "beIN SPORTS 3" gibi sade adlar verir). Bu nedenle ad eşleşmesini
  /// [M3uXmltvNameMatcher.norm] üzerinden yapıyoruz — ülke öneklerini, HD/4K
  /// gibi nitelikleri, parantezleri ve TR diakritiklerini temizler.
  Future<void> fetchProgrammesForPlaylist(List<Channel> channels) {
    final pending = _inflightFetch;
    if (pending != null) return pending;
    final fut = _runFetchProgrammesForPlaylist(channels);
    _inflightFetch = fut;
    return fut.whenComplete(() => _inflightFetch = null);
  }

  Future<void> _runFetchProgrammesForPlaylist(List<Channel> channels) async {
    if (_db == null) await _initDatabase();

    // 1) Playlist kanallarını normalize et: normalize edilen ad → orijinal
    // adların alt küme listesi. Lookup'ta `c.name.toLowerCase()` ile arıyoruz,
    // dolayısıyla key olarak orijinal-küçük-harf isim koymalıyız.
    final normToPlaylistKeys = <String, List<String>>{};
    for (final ch in channels) {
      final original = ch.name.toLowerCase();
      final n = M3uXmltvNameMatcher.norm(ch.name);
      if (n.isEmpty) continue;
      normToPlaylistKeys.putIfAbsent(n, () => []).add(original);
    }
    if (normToPlaylistKeys.isEmpty) {
      _channelNameToXmlId.clear();
      _memoryProgrammeCache.clear();
      loadGeneration.value++;
      debugPrint(
        'mina_iptv: Global EPG - Memory cache populated with 0 channels (no playlist names)',
      );
      return;
    }

    // 2) DB kanalları — yalnızca tespit edilen ülkeler (C1); norm haritası cache (C2).
    final countries = activeCountries.isEmpty
        ? <String>{}
        : Set<String>.from(activeCountries);
    final stats = await getDatabaseStats();
    final dbChannelRows = stats['channels'] ?? 0;
    final normMapKey =
        '${countries.join(',')}|$dbChannelRows|${channels.length}';

    Map<String, Set<String>> normToXmlIds;
    if (normMapKey == _cachedNormMapKey && _cachedNormToXmlIds.isNotEmpty) {
      normToXmlIds = _cachedNormToXmlIds;
    } else {
      final fromDisk = await _loadNormMapFromDisk(normMapKey);
      if (fromDisk != null && fromDisk.isNotEmpty) {
        normToXmlIds = fromDisk;
        _cachedNormMapKey = normMapKey;
        _cachedNormToXmlIds = normToXmlIds;
      } else {
      final List<Map<String, dynamic>> dbRows;
      if (countries.isEmpty) {
        dbRows = await _db!.query(
          'global_epg_channel',
          columns: ['xml_channel_id', 'display_name'],
        );
      } else {
        final codes = countries.toList();
        dbRows = await _db!.query(
          'global_epg_channel',
          columns: ['xml_channel_id', 'display_name'],
          where: 'country_code IN (${codes.map((_) => '?').join(',')})',
          whereArgs: codes,
        );
      }
      normToXmlIds = <String, Set<String>>{};
      for (final r in dbRows) {
        final dn = (r['display_name'] as String?) ?? '';
        if (dn.isEmpty) continue;
        final n = M3uXmltvNameMatcher.norm(dn);
        if (n.isEmpty) continue;
        normToXmlIds
            .putIfAbsent(n, () => <String>{})
            .add(r['xml_channel_id'] as String);
      }
      _cachedNormMapKey = normMapKey;
      _cachedNormToXmlIds = normToXmlIds;
      unawaited(_persistNormMapToDisk(normMapKey, normToXmlIds));
      }
    }

    // 3) Eşleşmeleri topla — `_channelNameToXmlId[playlistOriginalLower]`
    // playlist'in soracağı anahtarla doldurulur.
    final matchedXmlIds = <String>{};
    _channelNameToXmlId.clear();
    for (final entry in normToPlaylistKeys.entries) {
      final xmlIds = normToXmlIds[entry.key];
      if (xmlIds == null || xmlIds.isEmpty) continue;
      matchedXmlIds.addAll(xmlIds);
      for (final playlistKey in entry.value) {
        _channelNameToXmlId[playlistKey] = xmlIds.first;
      }
    }

    final xmlIdList = matchedXmlIds.toList();
    _memoryProgrammeCache.clear();
    
    for (var i = 0; i < xmlIdList.length; i += 500) {
      final chunk = xmlIdList.sublist(i, i + 500 > xmlIdList.length ? xmlIdList.length : i + 500);
      final programmes = await _db!.query(
        'global_epg_programme',
        where: 'xml_channel_id IN (${chunk.map((_) => '?').join(',')})',
        whereArgs: chunk,
        orderBy: 'start_ms ASC',
      );
      
      for (final p in programmes) {
        final xmlId = p['xml_channel_id'] as String;
        _memoryProgrammeCache.putIfAbsent(xmlId, () => []).add(EpgProgramme(
          channelId: xmlId,
          start: DateTime.fromMillisecondsSinceEpoch(p['start_ms'] as int),
          end: DateTime.fromMillisecondsSinceEpoch(p['end_ms'] as int),
          title: p['title'] as String,
          description: p['description'] as String?,
        ));
      }
    }
    
    var progTotal = 0;
    for (final list in _memoryProgrammeCache.values) {
      progTotal += list.length;
    }
    final chCount = _memoryProgrammeCache.length;
    final changed = chCount != _lastMemoryCacheChannelCount ||
        progTotal != _lastMemoryCacheProgrammeCount;
    _lastMemoryCacheChannelCount = chCount;
    _lastMemoryCacheProgrammeCount = progTotal;
    if (changed) {
      loadGeneration.value++;
      EpgPerfTelemetry.loadGenerationBumps++;
    } else {
      EpgPerfTelemetry.loadGenerationSkipped++;
    }
    debugPrint(
      'mina_iptv: Global EPG - Memory cache populated with $chCount channels'
      '${changed ? '' : ' (no change, gen kept)'}',
    );
  }

  /// SQLite veritabanını başlat
  Future<void> _initDatabase() async {
    if (_db != null) return;
    
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'mina_global_epg.sqlite');
    
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Kanallar tablosu
        await db.execute('''
CREATE TABLE global_epg_channel (
  country_code TEXT NOT NULL,
  xml_channel_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  logo_url TEXT,
  source_file TEXT NOT NULL,
  PRIMARY KEY (country_code, xml_channel_id)
);''');

        // Programlar tablosu
        await db.execute('''
CREATE TABLE global_epg_programme (
  country_code TEXT NOT NULL,
  xml_channel_id TEXT NOT NULL,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  source_file TEXT NOT NULL,
  UNIQUE(country_code, xml_channel_id, start_ms)
);''');

        // İndeksler
        await db.execute('CREATE INDEX idx_global_prog_chan ON global_epg_programme(country_code, xml_channel_id);');
        await db.execute('CREATE INDEX idx_global_prog_time ON global_epg_programme(start_ms, end_ms);');
        await db.execute('CREATE INDEX idx_global_prog_country ON global_epg_programme(country_code);');
      },
    );
    
    debugPrint('mina_iptv: Global EPG - Database initialized at $path');
  }

  /// Belirli bir kanal için programları getir
  Future<List<EpgProgramme>> getProgrammesForChannel(String xmlChannelId) async {
    if (Get.isRegistered<AppSettingsService>() &&
        !Get.find<AppSettingsService>().epgEnabled.value) {
      return const <EpgProgramme>[];
    }
    if (_db == null) await _initDatabase();
    
    final results = await _db!.query(
      'global_epg_programme',
      where: 'xml_channel_id = ?',
      whereArgs: [xmlChannelId],
      orderBy: 'start_ms ASC',
      limit: 100, // Sonraki 100 program
    );
    
    return results.map((row) => EpgProgramme(
      channelId: xmlChannelId,
      start: DateTime.fromMillisecondsSinceEpoch(row['start_ms'] as int),
      end: DateTime.fromMillisecondsSinceEpoch(row['end_ms'] as int),
      title: row['title'] as String,
      description: row['description'] as String?,
    )).toList();
  }

  /// Veritabanını temizle
  Future<void> clearDatabase() async {
    if (_db == null) return;
    
    await _db!.transaction((txn) async {
      await txn.delete('global_epg_programme');
      await txn.delete('global_epg_channel');
    });
    
    debugPrint('mina_iptv: Global EPG - Database cleared');
  }

  /// Veritabanı istatistikleri
  Future<Map<String, int>> getDatabaseStats() async {
    if (_db == null) await _initDatabase();
    
    final channelCount = Sqflite.firstIntValue(
      await _db!.rawQuery('SELECT COUNT(*) FROM global_epg_channel')
    ) ?? 0;
    
    final programmeCount = Sqflite.firstIntValue(
      await _db!.rawQuery('SELECT COUNT(*) FROM global_epg_programme')
    ) ?? 0;
    
    return {
      'channels': channelCount,
      'programmes': programmeCount,
    };
  }

  static const String _normMapDiskFileName = 'global_epg_norm_map_v1.json';

  Future<File> _normMapCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _normMapDiskFileName));
  }

  Future<Map<String, Set<String>>?> _loadNormMapFromDisk(String normMapKey) async {
    try {
      final file = await _normMapCacheFile();
      if (!await file.exists()) return null;
      final rawString = await file.readAsString();
      return await compute(_parseNormMapIsolate, {'raw': rawString, 'key': normMapKey});
    } catch (e) {
      debugPrint('mina_iptv: Global EPG - norm map disk read failed: $e');
      return null;
    }
  }

  Future<void> _persistNormMapToDisk(
    String normMapKey,
    Map<String, Set<String>> map,
  ) async {
    try {
      final file = await _normMapCacheFile();
      final payload = await compute(_encodeNormMapIsolate, {'key': normMapKey, 'map': map});
      await file.writeAsString(payload);
    } catch (e) {
      debugPrint('mina_iptv: Global EPG - norm map disk write failed: $e');
    }
  }

  Future<void> _deleteNormMapDiskCache() async {
    try {
      final file = await _normMapCacheFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// EPG veri yapısı
class EpgData {
  final String countryCode;
  final Map<String, EpgChannel> channels;
  final Map<String, List<EpgProgramme>> programmes;
  final String sourceUrl;

  EpgData({
    required this.countryCode,
    required this.channels,
    required this.programmes,
    required this.sourceUrl,
  });
}

/// Isolate'da XMLTV parse işlemi
(Map<String, EpgChannel>, Map<String, List<EpgProgramme>>) _parseXmltvInIsolate(String xmlString) {
  final result = xmltv_parser.parseXmlTvIsolate(xmlString);
  return (result['channels'] as Map<String, EpgChannel>, result['programmes'] as Map<String, List<EpgProgramme>>);
}

/// Basit semaphore implementasyonu
class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

// --- Isolate Top-Level Functions ---

Map<String, Set<String>>? _parseNormMapIsolate(Map<String, dynamic> args) {
  final rawString = args['raw'] as String;
  final normMapKey = args['key'] as String;
  final raw = jsonDecode(rawString) as Map<String, dynamic>;
  if (raw['key'] != normMapKey) return null;
  final entries = raw['entries'] as Map<String, dynamic>?;
  if (entries == null || entries.isEmpty) return null;
  return entries.map(
    (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>().toSet()),
  );
}

String _encodeNormMapIsolate(Map<String, dynamic> args) {
  final normMapKey = args['key'] as String;
  final map = args['map'] as Map<String, Set<String>>;
  return jsonEncode({
    'key': normMapKey,
    'entries': map.map((k, v) => MapEntry(k, v.toList())),
  });
}
