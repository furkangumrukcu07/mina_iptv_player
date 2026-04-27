import 'app_settings_service.dart';
import 'playlist_cache_service.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';

/// Xtream: panel kategori kimliği. M3U: `group-title` metni (normalize edilmiş) — ID’ler parse’a göre değişir.
abstract final class PlaylistCategoryHide {
  PlaylistCategoryHide._();

  static String? m3uSourceKey(PlaylistCacheService cache) {
    final xk = cache.xtreamPreferenceKey.value?.trim();
    if (xk != null && xk.isNotEmpty) return null;
    final u = cache.sourceUrl.value?.trim() ?? '';
    if (u.isEmpty) return null;
    return AppSettingsService.m3uPreferenceKey(u);
  }

  static bool liveCategoryRowHidden(
    AppSettingsService app,
    PlaylistCacheService cache,
    ChannelCategory cat,
  ) {
    final xk = cache.xtreamPreferenceKey.value?.trim();
    if (xk != null && xk.isNotEmpty) {
      return app.xtreamHiddenLiveIds(xk).contains(cat.id);
    }
    final mk = m3uSourceKey(cache);
    if (mk == null) return false;
    final n = AppSettingsService.normalizePlaylistCategoryName(cat.name);
    return app.m3uHiddenLiveNames(mk).contains(n);
  }

  static bool channelHiddenInLive(
    AppSettingsService app,
    PlaylistCacheService cache,
    M3uResult data,
    Channel ch,
  ) {
    final xk = cache.xtreamPreferenceKey.value?.trim();
    if (xk != null && xk.isNotEmpty) {
      return app.xtreamHiddenLiveIds(xk).contains(ch.categoryId);
    }
    final mk = m3uSourceKey(cache);
    if (mk == null) return false;
    for (final c in data.channelCategories) {
      if (c.id == ch.categoryId) {
        final n = AppSettingsService.normalizePlaylistCategoryName(c.name);
        return app.m3uHiddenLiveNames(mk).contains(n);
      }
    }
    return false;
  }

  static bool vodCategoryHidden(
    AppSettingsService app,
    PlaylistCacheService cache,
    M3uResult data,
    int vodCategoryId,
  ) {
    final xk = cache.xtreamPreferenceKey.value?.trim();
    if (xk != null && xk.isNotEmpty) {
      return app.xtreamHiddenVodIds(xk).contains(vodCategoryId);
    }
    final mk = m3uSourceKey(cache);
    if (mk == null) return false;
    for (final c in data.vodCategories) {
      if (c.id == vodCategoryId) {
        final n = AppSettingsService.normalizePlaylistCategoryName(c.name);
        return app.m3uHiddenVodNames(mk).contains(n);
      }
    }
    return false;
  }

  static bool seriesCategoryHidden(
    AppSettingsService app,
    PlaylistCacheService cache,
    M3uResult data,
    int seriesCategoryId,
  ) {
    final xk = cache.xtreamPreferenceKey.value?.trim();
    if (xk != null && xk.isNotEmpty) {
      return app.xtreamHiddenSeriesIds(xk).contains(seriesCategoryId);
    }
    final mk = m3uSourceKey(cache);
    if (mk == null) return false;
    for (final c in data.seriesCategories) {
      if (c.id == seriesCategoryId) {
        final n = AppSettingsService.normalizePlaylistCategoryName(c.name);
        return app.m3uHiddenSeriesNames(mk).contains(n);
      }
    }
    return false;
  }

  static bool vodItemHidden(
    AppSettingsService app,
    PlaylistCacheService cache,
    M3uResult data,
    VodItem v,
  ) =>
      vodCategoryHidden(app, cache, data, v.categoryId);

  static bool seriesItemHidden(
    AppSettingsService app,
    PlaylistCacheService cache,
    M3uResult data,
    SeriesItem s,
  ) =>
      seriesCategoryHidden(app, cache, data, s.categoryId);
}
