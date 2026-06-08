import 'dart:async';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/remote/m3u_xtream_sniffer.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';
import 'app_settings_service.dart';
import 'playlist_cache_service.dart';

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
    try {
      final result =
          await _loadSlotIntoCache(slot, preferSnapshot: true);
      if (result == null) return false;
      activeSlot.value = slot;
      await _persistActiveSlot();
      return true;
    } finally {
      isSwitching.value = false;
    }
  }

  /// Yeni bir liste eklendiğinde / yenilendiğinde, az önce parse edilen
  /// sonucu doğrudan önbelleğe ve bellek/disk cache'ine yazar (ağ beklemeden).
  Future<void> applyKnownResult(int slot, M3uResult result) async {
    _memCache[slot] = result;
    final src = await _repo.readSourceAt(slot);
    if (src == null) return;
    _pushToCache(result, src);
    activeSlot.value = slot;
    await _persistActiveSlot();
    unawaited(_repo.persistSlotSnapshot(slot, result));
    await refreshAvailable();
  }

  Future<M3uResult?> _loadSlotIntoCache(
    int slot, {
    required bool preferSnapshot,
  }) async {
    final src = await _repo.readSourceAt(slot);
    if (src == null) return null;

    // 1) Bellek önbelleği — geçiş anında.
    final mem = _memCache[slot];
    if (mem != null) {
      _pushToCache(mem, src);
      return mem;
    }

    // 2) Disk anlık görüntüsü — hızlı açılış.
    if (preferSnapshot) {
      final snap = await _repo.restoreSlotSnapshot(slot);
      if (snap != null) {
        _memCache[slot] = snap;
        _pushToCache(snap, src);
        return snap;
      }
    }

    // 3) Ağ / yerel dosya (taze).
    final fresh = await _repo.loadSlotPlaylist(slot);
    if (fresh == null) return null;
    _memCache[slot] = fresh;
    _pushToCache(fresh, src);
    return fresh;
  }

  void _pushToCache(M3uResult result, PlaylistSource src) {
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
    _cache.setPlaylist(
      value: result,
      url: _labelFor(src),
      xtreamPreferenceKey: xk,
      m3uLayoutKey: m3uK,
    );
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
}
