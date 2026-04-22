import '../entities/channel.dart';
import '../entities/m3u_result.dart';
import '../entities/playlist_source.dart';
import '../entities/series_episode_option.dart';

abstract class PlaylistRepository {
  Future<M3uResult> loadFromM3uUrl(String url);

  /// Ham M3U metnini doğrular ve ayrıştırır (ağ çağrısı yok).
  Future<M3uResult> loadFromM3uContent(String content);

  /// M3U metnini uygulama dizinine yazar, kaynağı işaretler; ayrıştırılmış sonucu döner.
  Future<M3uResult> persistM3uLocalContent(String content);

  Future<M3uResult> loadFromXtream({
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

  /// İkinci kaynak (isteğe bağlı); canlı kanallar birincil ile birleştirilir.
  Future<PlaylistSource?> readSecondarySource();

  Future<void> persistSecondarySource(PlaylistSource source);

  Future<void> clearSecondarySource();

  /// İkinci yerel M3U dosyasını kaydeder ve ikinci kaynağı işaretler.
  Future<M3uResult> persistM3uLocalContentSecondary(String content);

  /// Birincil + varsa ikincil kaynağı yükleyip canlı kanal katmanını birleştirir.
  Future<M3uResult> loadMergedPlaylist({
    String secondaryOrphanCategoryName = 'List 2',
  });

  /// Ağdan yeni çekilmiş birleşik sonucu anlık görüntü olarak yazar (ilk kurulumda tekrar indirmeyi önler).
  Future<void> persistMergedPlaylistSnapshot(M3uResult merged);

  /// Kayıtlı kaynak(lar) ile parmak izi eşleşen yerel birleşik playlist anlık görüntüsü.
  Future<M3uResult?> restoreMergedPlaylistFromSnapshot();
}
