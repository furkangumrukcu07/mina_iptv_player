import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/perf/playlist_memory_diagnostics.dart';
import '../../data/local/playlist_sqlite_store.dart';
import '../../data/remote/m3u_xtream_sniffer.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';
import 'app_settings_service.dart';
import 'live_hls_stream_profile_service.dart';
import 'playlist_cache_service.dart';
import 'playlist_channel_layout_sync.dart';

/// "Listeler" barında gösterilecek tek bir liste girişi.
class PlaylistListInfo {
  const PlaylistListInfo({
    required this.slot,
    required this.displayName,
    required this.source,
  });

  final int slot;

  /// Kullanıcı etiketi veya varsayılan başlık ("Liste 1", "Liste 2"…).
  final String displayName;

  final PlaylistSource source;

  bool get isXtream => source is XtreamSource;
}

/// Aktif (gösterilen) playlist'i yöneten servis.
///
/// **Birleştirme tamamen devre dışı.** Her zaman tek bir slot'un içeriği
/// `PlaylistCacheService`'e yüklenir. Kullanıcı "Listeler" barından geçiş
/// yaptığında ilgili slot yüklenir ve önbelleğe yazılır; tüm modüller
/// (Canlı TV / Filmler / Diziler) zaten önbellekten okuduğu için otomatik
/// güncellenir.
///
/// Geçiş hızı için üç katmanlı yükleme: bellek içi map → disk anlık görüntüsü
/// → ağ/dosya.
class ActivePlaylistService extends GetxService {
  ActivePlaylistService({
    PlaylistRepository? repo,
    PlaylistCacheService? cache,
  })  : _repo = repo ?? Get.find<PlaylistRepository>(),
        _cache = cache ?? Get.find<PlaylistCacheService>();

  final PlaylistRepository _repo;
  final PlaylistCacheService _cache;

  static const String _kActiveSlotKey = 'mina_active_playlist_slot';

  /// Şu an gösterilen slot (1..N). Henüz yüklenmediyse 1.
  final RxInt activeSlot = 1.obs;

  /// "Listeler" barında listelenecek dolu slotlar.
  final RxList<PlaylistListInfo> available = <PlaylistListInfo>[].obs;

  /// Liste geçişi sürerken true (UI spinner/disable için).
  final RxBool isSwitching = false.obs;

  /// Oturum içi bellek önbelleği — aynı listeye tekrar geçişte anında.
  final Map<int, M3uResult> _memCache = <int, M3uResult>{};

  /// Birden fazla dolu liste varsa bar gösterilir.
  bool get hasMultiple => available.length >= 2;

  PlaylistListInfo? get activeInfo =>
      available.firstWhereOrNull((e) => e.slot == activeSlot.value);

  Future<ActivePlaylistService> init() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getInt(_kActiveSlotKey);
    if (saved != null && saved >= 1) {
      activeSlot.value = saved;
    }
    await refreshAvailable();
    return this;
  }

  /// Dolu slot listesini (kaynak + etiket) yeniden okur. Devre dışı slotlar
  /// "Listeler" barında gösterilmez. Aktif slot artık uygun değilse ilk uygun
  /// slota düşer.
  Future<void> refreshAvailable() async {
    // Tek `readAll()` turu: kaynak + disabled + isim. Eskiden her slot için
    // ayrı secure-storage okumaları yapılıyordu (yavaş keystore'da açılışta
    // saniyeler).
    final slotInfos = await _repo.readAllSlotInfos();
    final infos = <PlaylistListInfo>[];
    for (final entry in slotInfos) {
      if (entry.disabled) continue;
      final name = entry.name;
      infos.add(
        PlaylistListInfo(
          slot: entry.slot,
          displayName: (name != null && name.trim().isNotEmpty)
              ? name.trim()
              : 'playlistsManager.live.prefix.plain'
                  .trParams({'n': '${entry.slot}'}),
          source: entry.source,
        ),
      );
    }
    infos.sort((a, b) => a.slot.compareTo(b.slot));
    available.assignAll(infos);

    // Aktif slot artık yoksa ilk dolu slota düş.
    if (infos.isNotEmpty &&
        !infos.any((e) => e.slot == activeSlot.value)) {
      activeSlot.value = infos.first.slot;
      await _persistActiveSlot();
    }
  }

  /// Son [loadActiveIntoCache] / [_loadSlotIntoCache] disk snapshot'tan mı geldi?
  bool lastLoadFromSnapshot = false;

  /// Aktif slot'u önbelleğe yükler. Splash / home / settings tarafından
  /// çağrılır. [preferSnapshot] true ise önce disk anlık görüntüsü denenir
  /// (hızlı açılış); yoksa ağ/dosya.
  Future<M3uResult?> loadActiveIntoCache({bool preferSnapshot = true}) async {
    final slot = activeSlot.value;
    return _loadSlotIntoCache(slot, preferSnapshot: preferSnapshot);
  }

  /// Kullanıcı "Listeler" barından bir liste seçti. [slot] yüklenir, aktif
  /// olarak işaretlenir ve önbelleğe yazılır.
  Future<bool> selectSlot(int slot) async {
    if (slot == activeSlot.value && _cache.result.value != null) {
      // Zaten aktif ve yüklü — no-op.
      return true;
    }
    isSwitching.value = true;
    // 6+ büyük liste aynı anda RAM'de kalınca 3./4. slota geçişte ANR olur.
    _trimMemCacheKeepingSlots({activeSlot.value, slot});
    try {
      final loaded = await _loadSlotIntoCache(
        slot,
        preferSnapshot: true,
        publish: false,
      );
      if (loaded == null) return false;
      final src = await _repo.readSourceAt(slot);
      if (src == null) return false;
      final dbKey = await _repo.slotDbKey(slot);
      final dbReady = await _isDbReady(dbKey);
      // Yükleme spinner'ı bir kare çizilsin; ardından tek seferde yayınla.
      await Future<void>.delayed(Duration.zero);
      final mem = _memCache[slot] ?? loaded;
      _pushToCache(mem, src, dbReady ? dbKey : null);
      activeSlot.value = slot;
      await _persistActiveSlot();
      _trimMemCacheKeeping(slot);
      return true;
    } finally {
      isSwitching.value = false;
    }
  }

  /// Yeni bir liste eklendiğinde / yenilendiğinde, az önce parse edilen
  /// sonucu doğrudan önbelleğe ve bellek/disk cache'ine yazar (ağ beklemeden).
  Future<void> applyKnownResult(int slot, M3uResult result) async {
    final src = await _repo.readSourceAt(slot);
    if (src == null) return;
    final dbKey = await _repo.slotDbKey(slot);
    var dbReady = await _isDbReady(dbKey);
    if (!dbReady && dbKey != null && _hasListPayload(result)) {
      dbReady = await _ensureSqliteFromSnapshot(dbKey, result);
    }
    final forCache = dbReady ? result.slimForSqliteCache() : result;
    _memCache[slot] = forCache;
    _pushToCache(forCache, src, dbReady ? dbKey : null);
    activeSlot.value = slot;
    await _persistActiveSlot();
    unawaited(_repo.persistSlotSnapshot(slot, result));
    await refreshAvailable();
  }

  void _publishLoaded(
    M3uResult forCache,
    PlaylistSource src,
    String? dbKey, {
    required bool publish,
  }) {
    if (!publish) return;
    _pushToCache(forCache, src, dbKey);
  }

  Future<M3uResult?> _loadSlotIntoCache(
    int slot, {
    required bool preferSnapshot,
    bool publish = true,
  }) async {
    lastLoadFromSnapshot = false;
    final src = await _repo.readSourceAt(slot);
    if (src == null) return null;
    final dbKey = await _repo.slotDbKey(slot);

    // 1) Bellek önbelleği — geçiş anında.
    final mem = _memCache[slot];
    if (mem != null) {
      var dbReady = await _isDbReady(dbKey);
      if (!dbReady && dbKey != null) {
        if (_hasListPayload(mem)) {
          dbReady = await _ensureSqliteFromSnapshot(dbKey, mem);
        } else {
          // Slim önbellek + boş DB → geçersiz; snapshot veya ağ yoluna düş.
          _memCache.remove(slot);
        }
      }
      if (_memCache.containsKey(slot)) {
        final forCache =
            dbReady && _hasListPayload(mem) ? mem.slimForSqliteCache() : mem;
        _memCache[slot] = forCache;
        _publishLoaded(
          forCache,
          src,
          dbReady ? dbKey : null,
          publish: publish,
        );
        return forCache;
      }
    }

    // 2) Disk anlık görüntüsü — hızlı açılış.
    if (preferSnapshot) {
      final snap = await _repo.restoreSlotSnapshot(slot);
      if (snap != null) {
        lastLoadFromSnapshot = true;
        var dbReady = await _isDbReady(dbKey);
        if (!dbReady && dbKey != null && _hasListPayload(snap)) {
          dbReady = await _ensureSqliteFromSnapshot(dbKey, snap);
        }
        if (!dbReady && dbKey != null && _hasListPayload(snap)) {
          debugPrint(
            'mina_iptv: snapshot SQLite backfill failed slot $slot → fresh load',
          );
        } else {
          final forCache = dbReady ? snap.slimForSqliteCache() : snap;
          _memCache[slot] = forCache;
          _publishLoaded(
            forCache,
            src,
            dbReady ? dbKey : null,
            publish: publish,
          );
          return forCache;
        }
      }
    }

    // 3) Ağ / yerel dosya (taze) — bu yol SQLite'ı da doldurur. Kaynak
    // düzenlendiyse (URL / dosya mtime değişti) yeni bir `source_key` oluşur;
    // eski parmak izine ait satırlar artık yetim → arka planda temizle.
    final fresh = await _repo.loadSlotPlaylist(slot);
    if (fresh == null) return null;
    var dbReady = await _isDbReady(dbKey);
    if (!dbReady && dbKey != null && _hasListPayload(fresh)) {
      dbReady = await _ensureSqliteFromSnapshot(dbKey, fresh);
    }
    final forCache = dbReady ? fresh.slimForSqliteCache() : fresh;
    _memCache[slot] = forCache;
    _publishLoaded(forCache, src, dbReady ? dbKey : null, publish: publish);
    unawaited(
      _repo.pruneOrphanPlaylistDbSources(
        keepExtra: dbKey != null && dbKey.isNotEmpty ? {dbKey} : const {},
      ),
    );
    return forCache;
  }

  /// Oturum içi bellek önbelleğinde yalnızca [slot] kalsın.
  void _trimMemCacheKeeping(int slot) {
    if (_memCache.length <= 1) return;
    _memCache.removeWhere((k, _) => k != slot);
  }

  void _trimMemCacheKeepingSlots(Set<int> slots) {
    if (_memCache.length <= slots.length) return;
    _memCache.removeWhere((k, _) => !slots.contains(k));
  }

  void _pushToCache(M3uResult result, PlaylistSource src, String? dbKey) {
    // `auto` modunda: aktif liste ham bir M3U URL'si ise (`get.php?...&output=ts`
    // gibi) canlı yayın biçimini URL'den yeniden çöz. Böylece yeniden başlatmada
    // ve listeler arası geçişte de doğru biçim uygulanır. Xtream'e dönüştürülmüş
    // kaynaklarda `output` bilgisi kaybolduğu için ekleme anında saklanan değer
    // korunur.
    if (src is M3uSource) {
      final hint = M3uXtreamSniffer.liveFormatHint(src.url);
      if (hint != null && Get.isRegistered<AppSettingsService>()) {
        unawaited(
          Get.find<AppSettingsService>()
              .applyAutoDetectedLiveStreamFormat(hint),
        );
      }
    }
    final xk = src is XtreamSource
        ? AppSettingsService.xtreamPreferenceKey(src)
        : null;
    final m3uK =
        src is M3uSource ? AppSettingsService.m3uPreferenceKey(src.url) : null;
    // [dbKey] yalnızca SQLite gerçekten doluysa geçilir — aksi halde
    // [PlaylistDataSource] boş DB'ye düşer ve slim önbellekte liste yoktur.
    final dbReady = dbKey != null && dbKey.isNotEmpty;
    final forCache = dbReady ? result.slimForSqliteCache() : result;
    _cache.setPlaylist(
      value: forCache,
      url: _labelFor(src),
      xtreamPreferenceKey: xk,
      m3uLayoutKey: m3uK,
      dbSourceKey: dbReady ? dbKey : null,
    );
    if (dbReady) {
      unawaited(PlaylistChannelLayoutSync.syncActiveSlot());
    }
    unawaited(
      PlaylistMemoryDiagnostics.captureAndLog(
        tag: 'playlist_cache',
        result: forCache,
        dbKey: dbReady ? dbKey : null,
      ),
    );
    if (Get.isRegistered<LiveHlsStreamProfileService>()) {
      unawaited(
        Get.find<LiveHlsStreamProfileService>().evaluatePlaylist(
          source: src,
          result: forCache,
        ),
      );
    }
  }

  String _labelFor(PlaylistSource src) => switch (src) {
        M3uSource(:final url) => url,
        XtreamSource(:final baseUrl) => baseUrl,
      };

  Future<void> _persistActiveSlot() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kActiveSlotKey, activeSlot.value);
  }

  /// Bir slot içeriği değiştiyse (silme/yenileme) bellek önbelleğini boşalt.
  void invalidate(int slot) => _memCache.remove(slot);

  void invalidateAll() => _memCache.clear();

  /// Liste yeniden numaralandıktan (compactSlots) sonra aktif slotu yeni
  /// numarasına sessizce taşır. İçerik aynı kaldığı için cache'e dokunulmaz;
  /// yalnızca "Listeler" barı highlight'ı ve kalıcı tercih güncellenir.
  Future<void> remapActiveSlot(int slot) async {
    if (activeSlot.value == slot) return;
    activeSlot.value = slot;
    await _persistActiveSlot();
  }

  static bool _hasListPayload(M3uResult r) =>
      r.channels.isNotEmpty || r.vod.isNotEmpty || r.series.isNotEmpty;

  static Future<bool> _isDbReady(String? dbKey) async =>
      dbKey != null &&
      dbKey.isNotEmpty &&
      await PlaylistSqliteStore.hasData(dbKey);

  /// Eski kurulum: snapshot'ta tam liste var, SQLite boş — tek seferlik doldur.
  static Future<bool> _ensureSqliteFromSnapshot(
    String dbKey,
    M3uResult full,
  ) async {
    if (!_hasListPayload(full)) return false;
    if (await _isDbReady(dbKey)) return true;
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await PlaylistSqliteStore.replaceFromResult(dbKey, full);
        if (await _isDbReady(dbKey)) return true;
      } catch (e) {
        lastError = e;
        debugPrint(
          'mina_iptv: SQLite backfill attempt ${attempt + 1} failed: $e',
        );
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
    }
    if (lastError != null) {
      debugPrint('mina_iptv: SQLite backfill from snapshot failed: $lastError');
    }
    return false;
  }
}
