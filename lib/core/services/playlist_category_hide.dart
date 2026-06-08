import 'app_settings_service.dart';
import 'playlist_cache_service.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../utils/adult_content_filter.dart';

/// Xtream: panel kategori kimliği. M3U: `group-title` metni (normalize edilmiş) — ID’ler parse’a göre değişir.
abstract final class PlaylistCategoryHide {
  PlaylistCategoryHide._();

  /// M3U yolunda `data.channelCategories` üzerinde O(C) linear search yapılıyordu;
  /// her kanal/VOD/dizi başına çağrıldığı için 5000+ öğe × N kategori cost'u
  /// oluşturuyordu. M3uResult'a göre kategori adı haritalarını burada cache'liyoruz
  /// — Expando weak-key olduğu için bellek sızıntısı olmaz.
  static final Expando<Map<int, String>> _liveCatNameCache =
      Expando<Map<int, String>>('m3uLiveCatName');
  static final Expando<Map<int, String>> _vodCatNameCache =
      Expando<Map<int, String>>('m3uVodCatName');
  static final Expando<Map<int, String>> _seriesCatNameCache =
      Expando<Map<int, String>>('m3uSeriesCatName');

  static Map<int, String> _liveCatNames(M3uResult data) {
    final c = _liveCatNameCache[data];
    if (c != null) return c;
    final m = <int, String>{};
    for (final cat in data.channelCategories) {
      m[cat.id] = AppSettingsService.normalizePlaylistCategoryName(cat.name);
    }
    _liveCatNameCache[data] = m;
    return m;
  }

  static Map<int, String> _vodCatNames(M3uResult data) {
    final c = _vodCatNameCache[data];
    if (c != null) return c;
    final m = <int, String>{};
    for (final cat in data.vodCategories) {
      m[cat.id] = AppSettingsService.normalizePlaylistCategoryName(cat.name);
    }
    _vodCatNameCache[data] = m;
    return m;
  }

  static Map<int, String> _seriesCatNames(M3uResult data) {
    final c = _seriesCatNameCache[data];
    if (c != null) return c;
    final m = <int, String>{};
    for (final cat in data.seriesCategories) {
      m[cat.id] = AppSettingsService.normalizePlaylistCategoryName(cat.name);
    }
    _seriesCatNameCache[data] = m;
    return m;
  }

  static String? m3uSourceKey(PlaylistCacheService cache) {
    final xk = cache.xtreamPreferenceKey.value?.trim();
    if (xk != null && xk.isNotEmpty) return null;
    final u = cache.sourceUrl.value?.trim() ?? '';
    if (u.isEmpty) return null;
    return AppSettingsService.m3uPreferenceKey(u);
  }

  /// Kategori sıralaması için kaynak anahtarı (Xtream varsa onun anahtarı,
  /// yoksa M3U anahtarı). Hiçbiri yoksa `null`.
  static String? orderSourceKey(PlaylistCacheService cache) {
    final xk = cache.xtreamPreferenceKey.value?.trim();
    if (xk != null && xk.isNotEmpty) return xk;
    return m3uSourceKey(cache);
  }

  static bool usesXtreamIds(PlaylistCacheService cache) {
    final xk = cache.xtreamPreferenceKey.value?.trim();
    return xk != null && xk.isNotEmpty;
  }

  /// Xtream → kategori id'si (string), M3U → normalize ad. [reorder] UI'sı ve
  /// liste tüketicileri aynı kimliği üretsin diye tek noktadan.
  static String categoryIdentity(
    PlaylistCacheService cache,
    int id,
    String name,
  ) {
    return usesXtreamIds(cache)
        ? id.toString()
        : AppSettingsService.normalizePlaylistCategoryName(name);
  }

  /// Kullanıcının sürükleyerek kaydettiği sıraya göre canlı kategorilerini
  /// yeniden dizer.
  static List<ChannelCategory> orderLiveCategories(
    AppSettingsService app,
    PlaylistCacheService cache,
    List<ChannelCategory> cats,
  ) {
    final key = orderSourceKey(cache);
    if (key == null) return cats;
    final order = app.categoryOrder(key, 'live');
    if (order.isEmpty) return cats;
    return AppSettingsService.applyCategoryOrder(
      cats,
      order,
      (c) => categoryIdentity(cache, c.id, c.name),
    );
  }

  static List<VodCategory> orderVodCategories(
    AppSettingsService app,
    PlaylistCacheService cache,
    List<VodCategory> cats,
  ) {
    final key = orderSourceKey(cache);
    if (key == null) return cats;
    final order = app.categoryOrder(key, 'vod');
    if (order.isEmpty) return cats;
    return AppSettingsService.applyCategoryOrder(
      cats,
      order,
      (c) => categoryIdentity(cache, c.id, c.name),
    );
  }

  static List<SeriesCategory> orderSeriesCategories(
    AppSettingsService app,
    PlaylistCacheService cache,
    List<SeriesCategory> cats,
  ) {
    final key = orderSourceKey(cache);
    if (key == null) return cats;
    final order = app.categoryOrder(key, 'series');
    if (order.isEmpty) return cats;
    return AppSettingsService.applyCategoryOrder(
      cats,
      order,
      (c) => categoryIdentity(cache, c.id, c.name),
    );
  }

  static bool liveCategoryRowHidden(
    AppSettingsService app,
    PlaylistCacheService cache,
    ChannelCategory cat,
  ) {
    final xk = cache.xtreamPreferenceKey.value?.trim();
    if (xk != null && xk.isNotEmpty) {
      if (app.xtreamHiddenLiveIds(xk).contains(cat.id)) return true;
    } else {
      final mk = m3uSourceKey(cache);
      if (mk != null) {
        final n = AppSettingsService.normalizePlaylistCategoryName(cat.name);
        if (app.m3uHiddenLiveNames(mk).contains(n)) return true;
      }
    }
    if (app.effectiveHideAdultContent && AdultContentFilter.isAdult(cat.name)) {
      return true;
    }
    return false;
  }

  static bool channelHiddenInLive(
    AppSettingsService app,
    PlaylistCacheService cache,
    M3uResult data,
    Channel ch,
  ) {
    final xk = cache.xtreamPreferenceKey.value?.trim();
    if (xk != null && xk.isNotEmpty) {
      if (app.xtreamHiddenLiveIds(xk).contains(ch.categoryId)) return true;
    } else {
      final mk = m3uSourceKey(cache);
      if (mk != null) {
        final n = _liveCatNames(data)[ch.categoryId];
        if (n != null && app.m3uHiddenLiveNames(mk).contains(n)) return true;
      }
    }
    if (app.effectiveHideAdultContent && _adultLiveChannel(data, ch)) {
      return true;
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
      if (app.xtreamHiddenVodIds(xk).contains(vodCategoryId)) return true;
    } else {
      final mk = m3uSourceKey(cache);
      if (mk != null) {
        final n = _vodCatNames(data)[vodCategoryId];
        if (n != null && app.m3uHiddenVodNames(mk).contains(n)) return true;
      }
    }
    if (app.effectiveHideAdultContent) {
      final catName = _vodCatNames(data)[vodCategoryId];
      if (AdultContentFilter.isAdult(catName)) return true;
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
      if (app.xtreamHiddenSeriesIds(xk).contains(seriesCategoryId)) {
        return true;
      }
    } else {
      final mk = m3uSourceKey(cache);
      if (mk != null) {
        final n = _seriesCatNames(data)[seriesCategoryId];
        if (n != null && app.m3uHiddenSeriesNames(mk).contains(n)) return true;
      }
    }
    if (app.effectiveHideAdultContent) {
      final catName = _seriesCatNames(data)[seriesCategoryId];
      if (AdultContentFilter.isAdult(catName)) return true;
    }
    return false;
  }

  static bool vodItemHidden(
    AppSettingsService app,
    PlaylistCacheService cache,
    M3uResult data,
    VodItem v,
  ) {
    if (vodCategoryHidden(app, cache, data, v.categoryId)) return true;
    if (app.effectiveHideAdultContent && _adultVod(data, v)) return true;
    return false;
  }

  static bool seriesItemHidden(
    AppSettingsService app,
    PlaylistCacheService cache,
    M3uResult data,
    SeriesItem s,
  ) {
    if (seriesCategoryHidden(app, cache, data, s.categoryId)) return true;
    if (app.effectiveHideAdultContent && _adultSeries(data, s)) return true;
    return false;
  }

  // ---------------------------------------------------------------------
  // Ana ekran şeritleri (Önerilenler / Karışık canlı / İzlemeye devam et)
  //
  // İki katmanı tek bayrakta birleştirir:
  //   1. Kullanıcının gizlediği kategori (kanal / film / dizi)
  //   2. [AppSettingsService.hideAdultContentEnabled] açıkken kategori/öğe
  //      adında +18 token tespit edilmesi
  //
  // Strip'ler bu helper'ları kullanarak hem gizlenmiş hem de +18 içeriği
  // dışlar. Toggle değiştiğinde [AppSettingsService.xtreamHideRevision]
  // artırılarak reactive UI'lar yeniden hesaplama yapar.
  // ---------------------------------------------------------------------

  static bool _adultLiveChannel(M3uResult data, Channel ch) {
    final catName = _liveCatNames(data)[ch.categoryId];
    return AdultContentFilter.isAnyAdult([catName, ch.name]);
  }

  static bool _adultVod(M3uResult data, VodItem v) {
    final catName = _vodCatNames(data)[v.categoryId];
    return AdultContentFilter.isAnyAdult([catName, v.name]);
  }

  static bool _adultSeries(M3uResult data, SeriesItem s) {
    final catName = _seriesCatNames(data)[s.categoryId];
    return AdultContentFilter.isAnyAdult([catName, s.name]);
  }

  /// Ana ekran şeritlerinde gösterilmemesi gereken canlı kanal mı?
  static bool liveChannelHiddenForHome(
    AppSettingsService app,
    PlaylistCacheService cache,
    M3uResult data,
    Channel ch,
  ) {
    if (channelHiddenInLive(app, cache, data, ch)) return true;
    if (app.effectiveHideAdultContent && _adultLiveChannel(data, ch)) {
      return true;
    }
    return false;
  }

  /// Ana ekran şeritlerinde gösterilmemesi gereken VOD mu?
  static bool vodHiddenForHome(
    AppSettingsService app,
    PlaylistCacheService cache,
    M3uResult data,
    VodItem v,
  ) {
    if (vodItemHidden(app, cache, data, v)) return true;
    if (app.effectiveHideAdultContent && _adultVod(data, v)) return true;
    return false;
  }

  /// Ana ekran şeritlerinde gösterilmemesi gereken dizi mi?
  static bool seriesHiddenForHome(
    AppSettingsService app,
    PlaylistCacheService cache,
    M3uResult data,
    SeriesItem s,
  ) {
    if (seriesItemHidden(app, cache, data, s)) return true;
    if (app.effectiveHideAdultContent && _adultSeries(data, s)) {
      return true;
    }
    return false;
  }
}
