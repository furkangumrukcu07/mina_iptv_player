import '../../core/constants/playlist_storage.dart';
import '../entities/channel.dart';
import '../entities/m3u_result.dart';
import '../entities/playlist_source.dart';
import '../entities/series_episode_option.dart';

abstract class PlaylistRepository {
  Future<M3uResult> loadFromM3uUrl(String url);

  /// `loadFromM3uUrl` ile aynıdır, ama gerçekten **çalışan** URL'i de döner.
  ///
  /// Kullanıcı `https://…` yapıştırıp da sunucu yalnızca `http://` üzerinden
  /// servis veriyorsa (veya tersi), bağlantı düzeyi bir hata aldığımızda
  /// karşı şemayı otomatik deniyoruz. Çağıran taraf [PlaylistSource]
  /// kaydedilirken ham URL yerine `resolvedUrl` kullanarak bir sonraki
  /// açılışta yeniden başarısız denemeyi atlatabilir.
  Future<({M3uResult result, String resolvedUrl})> loadFromM3uUrlResolved(
      String url);

  /// Ham M3U metnini doğrular ve ayrıştırır (ağ çağrısı yok).
  Future<M3uResult> loadFromM3uContent(String content);

  /// M3U metnini uygulama dizinine yazar, kaynağı işaretler; ayrıştırılmış sonucu döner.
  Future<M3uResult> persistM3uLocalContent(String content);

  Future<M3uResult> loadFromXtream({
    required String baseUrl,
    required String username,
    required String password,
  });

  /// `loadFromXtream` ile aynıdır, ama gerçekten **çalışan** base URL'i de
  /// döner. Kullanıcı `https://…` Xtream paneli yazıp da sunucu yalnızca
  /// `http://` üzerinden cevap veriyorsa (veya tersi), iki şemayı hızlıca
  /// yarıştırıp erişilebilen şemayı seçeriz. Çağıran taraf [XtreamSource]
  /// kaydedilirken `resolvedBaseUrl` kullanarak bir sonraki açılışta
  /// yeniden başarısız denemeyi atlatır.
  Future<({M3uResult result, String resolvedBaseUrl})> loadFromXtreamResolved({
    required String baseUrl,
    required String username,
    required String password,
  });

  /// Xtream `get_series_info` ile ilk bölümü [Channel] yapar; kaynak Xtream değilse null.
  Future<Channel?> resolveXtreamSeriesFirstEpisode({
    required int seriesId,
    required String seriesName,
    String? posterUrl,
    required int categoryId,
  });

  /// Xtream `get_series_info` ile bölümler + dizi özeti; kaynak Xtream değilse boş.
  Future<XtreamSeriesBrowseDetail> resolveXtreamSeriesEpisodes({
    required int seriesId,
    required String seriesName,
    String? posterUrl,
    required int categoryId,
  });

  /// Xtream `get_vod_info` ile film metası (plot, tür, yönetmen…).
  Future<Map<String, String>?> loadXtreamVodInfoFields(int vodStreamId);

  Future<String?> getXtreamEpgUrl();

  Future<UserInfo?> getXtreamUserInfo({
    required String baseUrl,
    required String username,
    required String password,
  });

  /// `user_info` + `server_info` snapshot'ı — Ayarlar > Xtream Hesabı için.
  Future<XtreamAccountSnapshot?> getXtreamAccountSnapshot({
    required String baseUrl,
    required String username,
    required String password,
  });

  /// Yalnızca kullanıcı adı / şifre / sunucu doğrulamak için. Hatalıysa
  /// [AppException] fırlatır (UI tekrar girmesini ister).
  Future<void> verifyXtreamCredentialsOrThrow({
    required String baseUrl,
    required String username,
    required String password,
  });

  Future<PlaylistSource?> readSource();

  Future<void> persistSource(PlaylistSource source);

  @Deprecated('Use loadFromM3uUrl(url)')
  Future<M3uResult> loadPlaylistFromUrl(String url);

  @Deprecated('Use persistSource(M3uSource)')
  Future<void> persistPlaylistUrl(String url);

  @Deprecated('Use readSource()')
  Future<String?> readPersistedPlaylistUrl();

  /// Secure storage’daki kayıtlı kaynağı (M3U / Xtream) siler.
  Future<void> clearSavedSource();

  /// İkinci kaynak (isteğe bağlı); slot 2 alias'ı.
  Future<PlaylistSource?> readSecondarySource();

  Future<void> persistSecondarySource(PlaylistSource source);

  Future<void> clearSecondarySource();

  /// İkinci yerel M3U dosyasını kaydeder ve ikinci kaynağı işaretler.
  Future<M3uResult> persistM3uLocalContentSecondary(String content);

  /// Birincil + tüm dolu ek slotları (2..[kPlaylistSlotCount]) sırayla birleştirir.
  ///
  /// [extraOrphanCategoryNameForSlot] her bir ek slot için "Liste @n" başlığı
  /// üretmek üzere çağrılır. Verilmezse `List @n` kullanılır.
  Future<M3uResult> loadMergedPlaylist({
    String Function(int slot)? extraOrphanCategoryNameForSlot,
    @Deprecated('Use extraOrphanCategoryNameForSlot')
    String secondaryOrphanCategoryName,
    // Birden fazla aktif slot olduğunda **canlı TV kategorilerini** slot
    // adıyla öne ek getirir (örn. `"Liste 1 (Spor) · Belgesel"`). Null
    // verilirse veya tek slot aktifse prefix uygulanmaz — VOD ve diziler
    // hiç dokunulmaz (kullanıcı tek karışık liste görür).
    String Function(int slot)? liveCategoryPrefixForSlot,
  });

  /// Ağdan yeni çekilmiş birleşik sonucu anlık görüntü olarak yazar (ilk kurulumda tekrar indirmeyi önler).
  Future<void> persistMergedPlaylistSnapshot(M3uResult merged);

  /// Kayıtlı kaynak(lar) ile parmak izi eşleşen yerel birleşik playlist anlık görüntüsü.
  Future<M3uResult?> restoreMergedPlaylistFromSnapshot();

  // ---------------------------------------------------------------------------
  // Tek slot anlık görüntüsü (birleştirme YOK — "Listeler" geçişi için).
  // ---------------------------------------------------------------------------

  /// Belirli bir slot'un parse edilmiş sonucunu diske yazar (slot kaynağının
  /// parmak izi ile anahtarlanır). Kullanıcı listeler arasında geçerken ağ
  /// beklemeden açılması için.
  Future<void> persistSlotSnapshot(int slot, M3uResult result);

  /// Slot kaynağı ile parmak izi eşleşen yerel slot anlık görüntüsü; yoksa null.
  Future<M3uResult?> restoreSlotSnapshot(int slot);

  /// Belirli bir slot'u **tek başına** (birleştirmeden) yükler. Kaynak yoksa
  /// null. Disk anlık görüntüsü tercih edilmez — her zaman ağdan/dosyadan taze.
  Future<M3uResult?> loadSlotPlaylist(int slot);

  /// Slot için SQLite (`PlaylistSqliteStore`) `source_key` parmak izi. Slotta
  /// kayıtlı kaynak yoksa null. Tüketiciler büyük listeleri bu anahtarla
  /// diskten (sayfalı) sorgular.
  Future<String?> slotDbKey(int slot);

  /// [loadMergedPlaylist] son çağrısında birleşik sonucun yazıldığı SQLite
  /// `source_key`'i. Birleştirme yapılmadıysa / DB'ye yazılamadıysa null.
  /// Çağıran taraf, cache'i bu anahtarla "slim" (film/dizi RAM'de değil)
  /// olarak besleyebilir.
  String? get lastMergedDbSourceKey;

  /// Artık hiçbir aktif slota karşılık gelmeyen (silinmiş / düzenlenmiş /
  /// compact edilmiş kaynaklara ait) SQLite playlist verilerini temizler.
  /// 20+ liste senaryosunda `mina_playlist.sqlite`'ın sınırsız büyümesini
  /// önler. [keepExtra] verilirse o anahtar(lar) korunur (ör. cache'in o an
  /// kullandığı birleşik anahtar).
  Future<void> pruneOrphanPlaylistDbSources({Set<String> keepExtra});

  // ---------------------------------------------------------------------------
  // Slot-tabanlı API (4'e kadar playlist için). Slot 1 = birincil, 2..N = ek.
  // ---------------------------------------------------------------------------

  /// Slot 1..[kPlaylistSlotCount] aralığında bir kayıt okur.
  Future<PlaylistSource?> readSourceAt(int slot);

  /// Slot'a kaynak yazar; slot 1 için [persistSource], slot 2 için
  /// [persistSecondarySource] ile birebir aynı davranış (delegate).
  Future<void> persistSourceAt(int slot, PlaylistSource source);

  /// Slot'u temizler (kayıt, varsa yerel m3u dosyası, snapshot).
  Future<void> clearSourceAt(int slot);

  /// Dolu slotları boşlukları kapatacak şekilde 1..N olarak yeniden numaralar.
  ///
  /// Örn. kullanıcı 5 listeden 3.'yü silince geriye 1,2,4,5 kalır; bu metot
  /// 4→3 ve 5→4 taşıyarak 1,2,3,4 yapar. Kaynak, kullanıcı etiketi, devre dışı
  /// bayrağı ve (yerel m3u ise) dosya birlikte taşınır.
  ///
  /// Dönüş: taşınan slotlar için `{eskiSlot: yeniSlot}` haritası. Hiçbir şey
  /// taşınmadıysa (zaten ardışık) boş harita döner. Çağıran taraf aktif slot
  /// referansını bu harita ile güncellemelidir.
  Future<Map<int, int>> compactSlots();

  /// Slot için yerel M3U gövdesini diske yazar ve kaynağı sentinel'le işaretler.
  Future<M3uResult> persistM3uLocalContentAt(int slot, String content);

  /// Tüm slotları sırayla okur; null'lar listede yer almaz. Slot 1'i de içerir.
  ///
  /// **Devre dışı bırakılmış slotlar da listeye dahildir** — UI'ın
  /// "Liste Yönetimi" görünümünde silinmiş ile devre dışı arasındaki farkı
  /// göstermesi için. Aktif (birleşik playlist'e dahil edilecek) slotları
  /// almak için [isSlotDisabled] ile filtreleyin veya [loadMergedPlaylist]
  /// kullanın (otomatik atlar).
  Future<List<({int slot, PlaylistSource source})>> readAllSources();

  /// Tüm dolu slotların kaynağı + devre dışı bayrağı + kullanıcı etiketini
  /// **tek** secure-storage `readAll()` çağrısıyla okur. Açılışta her slot için
  /// ayrı ayrı [readAllSources] + [readDisabledSlots] + [readSlotName]
  /// çağırmak yavaş keystore'lu cihazlarda onlarca method-channel turu
  /// demekti; bu metot hepsini bellek içinde tek turda üretir.
  Future<List<({int slot, PlaylistSource source, bool disabled, String? name})>>
      readAllSlotInfos();

  // ---------------------------------------------------------------------------
  // Devre Dışı Bırakma (Slot Disable / Enable)
  // ---------------------------------------------------------------------------
  //
  // Kullanıcı `Ayarlar > Liste Yönetimi` ekranından bir veya birden çok
  // listeyi geçici olarak devre dışı bırakabilir (silmeden). Devre dışı
  // bırakılan slotlar:
  //   * [loadMergedPlaylist] tarafından atlanır,
  //   * [readAllSources] çıktısında **görünmeye devam eder** (UI için),
  //   * Manager dışında diğer akışlar (splash, channels, browse) tarafından
  //     `readSource()` ile okunurken aynı kayda eriştiğinden devre dışı
  //     bayrağını [isSlotDisabled] ile sorgulamalıdır.

  /// Slot devre dışı mı? Kaydedilmiş bir bayrak yoksa **false** döner.
  Future<bool> isSlotDisabled(int slot);

  /// Slot devre dışı / aktif bayrağını günceller. Aktif (false) yazılırken
  /// disk girişi temizlenir — disk şişmesin diye.
  Future<void> setSlotDisabled(int slot, bool disabled);

  /// Devre dışı tüm slotların kümesi. Tek geçişte okumak isteyen UI/test
  /// için (her slot için ayrı [isSlotDisabled] çağrısı yapmaktan hızlı).
  Future<Set<int>> readDisabledSlots();

  // ---------------------------------------------------------------------------
  // Slot İsimlendirme (Slot Name / Label)
  // ---------------------------------------------------------------------------
  //
  // Kullanıcı bir slota istediği etiketi verebilir (örn. "Spor Paketi",
  // "Eve Ait", "Yedek Liste"). Etiket optional'dır:
  //   * Yazılmazsa varsayılan başlık ("Birincil liste" / "Liste #N") kullanılır.
  //   * `clearSourceAt` slot'u sıfırlarken etiketi de temizler.
  //   * Devre dışı bırakma etiketi etkilemez — etiket sürdürülür.

  /// Slot için kullanıcı tanımlı etiket; ayarlanmadıysa `null`.
  Future<String?> readSlotName(int slot);

  /// Slot etiketini yazar. Boş string veya `null` → kayıt silinir
  /// (varsayılan başlığa döner).
  Future<void> writeSlotName(int slot, String? name);
}
