import 'dart:math';

import 'package:get/get.dart';

import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../../services/user_history_service.dart';
import '../services/app_settings_service.dart';
import '../services/favorites_service.dart';
import '../services/playlist_cache_service.dart';
import '../services/playlist_category_hide.dart';
import 'recommended_films_catalog.dart';
import 'series_name_grouping.dart';

/// Film & Dizi ana ekranı — film / dizi sekmesi.
enum FilmDiziTab { films, series }

/// Sentinel kategori ID'si — playlist kategorisi yerine kullanıcının
/// **son izleme geçmişi**'nden derlenen "Son izlenenler" listesini
/// `RecommendedFilmsCategoryView` içinde aç.
const int kFilmDiziRecentlyWatchedCategoryId = -1001;

/// Sentinel kategori ID'si — kullanıcının **favorilerine** eklediği film/dizi
/// listesini `RecommendedFilmsCategoryView` içinde aç.
const int kFilmDiziFavoritesCategoryId = -1002;

/// «Tümünü gör» — playlist kategorisi.
class FilmDiziCategoryArgs {
  const FilmDiziCategoryArgs({
    required this.tab,
    required this.categoryId,
    required this.title,
  });

  final FilmDiziTab tab;
  final int categoryId;
  final String title;

  /// Sentinel categoryId → Son izlenenler.
  bool get isRecentlyWatched => categoryId == kFilmDiziRecentlyWatchedCategoryId;

  /// Sentinel categoryId → Favoriler.
  bool get isFavorites => categoryId == kFilmDiziFavoritesCategoryId;
}

/// Playlist kategorisi + yatay satır öğeleri.
class FilmDiziCategoryRow<T> {
  const FilmDiziCategoryRow({
    required this.categoryId,
    required this.name,
    required this.items,
  });

  final int categoryId;
  final String name;
  final List<T> items;
}

/// Film sekmesi verisi.
class FilmDiziFilmsFeed {
  const FilmDiziFilmsFeed({
    required this.recentlyAdded,
    required this.categoryRows,
  });

  final List<VodItem> recentlyAdded;
  final List<FilmDiziCategoryRow<VodItem>> categoryRows;

  bool get isEmpty =>
      recentlyAdded.isEmpty &&
      categoryRows.every((r) => r.items.isEmpty);
}

/// Dizi sekmesi verisi.
class FilmDiziSeriesFeed {
  const FilmDiziSeriesFeed({
    required this.recentlyAdded,
    required this.categoryRows,
  });

  final List<SeriesItem> recentlyAdded;
  final List<FilmDiziCategoryRow<SeriesItem>> categoryRows;

  bool get isEmpty =>
      recentlyAdded.isEmpty &&
      categoryRows.every((r) => r.items.isEmpty);
}

abstract final class FilmDiziCatalog {
  FilmDiziCatalog._();

  static const int recentlyAddedLimit = 20;
  static const int rowPreviewLimit = 16;
  static const int minCategoryItems = 1;

  static List<VodItem> visibleVods(M3uResult data) =>
      RecommendedFilmsCatalog.visibleVods(data);

  static List<SeriesItem> visibleSeries(M3uResult data) {
    final app = Get.find<AppSettingsService>();
    final cache = Get.find<PlaylistCacheService>();
    final out = <SeriesItem>[];
    for (final s in data.series) {
      if (!PlaylistCategoryHide.seriesItemHidden(app, cache, data, s)) {
        out.add(s);
      }
    }
    return out;
  }

  static int visibleContentCount(M3uResult data) =>
      visibleVods(data).length + visibleSeries(data).length;

  static FilmDiziFilmsFeed buildFilms(M3uResult data) {
    final items = visibleVods(data);
    final recentlyAdded = _sortVodByAdded(items)
        .take(recentlyAddedLimit)
        .toList();

    final rows = <FilmDiziCategoryRow<VodItem>>[];
    for (final cat in data.vodCategories) {
      if (_vodCategoryHidden(data, cat.id)) continue;
      final rowItems = _sortVodByAdded(
        items.where((v) => v.categoryId == cat.id).toList(),
      ).take(rowPreviewLimit).toList();
      if (rowItems.length < minCategoryItems) continue;
      rows.add(
        FilmDiziCategoryRow(
          categoryId: cat.id,
          name: cat.name,
          items: rowItems,
        ),
      );
    }

    return FilmDiziFilmsFeed(
      recentlyAdded: recentlyAdded,
      categoryRows: rows,
    );
  }

  static FilmDiziSeriesFeed buildSeries(M3uResult data) {
    final items = visibleSeries(data);
    final recentlyAdded = _groupedSeriesSortedByAdded(items)
        .take(recentlyAddedLimit)
        .toList();

    final rows = <FilmDiziCategoryRow<SeriesItem>>[];
    for (final cat in data.seriesCategories) {
      if (_seriesCategoryHidden(data, cat.id)) continue;
      final rowItems = _groupedSeriesSortedByAdded(
        items.where((s) => s.categoryId == cat.id).toList(),
      ).take(rowPreviewLimit).toList();
      if (rowItems.length < minCategoryItems) continue;
      rows.add(
        FilmDiziCategoryRow(
          categoryId: cat.id,
          name: cat.name,
          items: rowItems,
        ),
      );
    }

    return FilmDiziSeriesFeed(
      recentlyAdded: recentlyAdded,
      categoryRows: rows,
    );
  }

  static List<VodItem> allVodsInCategory(M3uResult data, int categoryId) {
    return _sortVodByAdded(
      visibleVods(data).where((v) => v.categoryId == categoryId).toList(),
    );
  }

  static List<SeriesItem> allSeriesInCategory(M3uResult data, int categoryId) {
    return _groupedSeriesSortedByAdded(
      visibleSeries(data).where((s) => s.categoryId == categoryId).toList(),
    );
  }

  /// **Son izlenenler — Filmler.**
  ///
  /// `UserHistoryService` snapshot'ında `kind == vod` kayıtları timestamp
  /// (en yeni → en eski) sırasıyla taranır; her contentId için playlist'teki
  /// karşılık gelen [VodItem] (gizli kategori filtresi sonrası) eklenir.
  /// Kullanıcı iki dakika ve üzeri izlediği filmler bu listede çıkar; aynı
  /// film tekrar tekrar oynatılmışsa yalnız son kayıt sayılır.
  ///
  /// Senkron çalışır — `UserHistoryService.snapshotSync` belleği kullanır.
  /// Servis henüz disk'ten yüklenmediyse boş liste döner; sonraki rebuild'de
  /// snapshot dolduğunda satır kendiliğinden belirir.
  static List<VodItem> recentlyWatchedFilms(M3uResult data) {
    if (!Get.isRegistered<UserHistoryService>()) {
      return const <VodItem>[];
    }
    final history = Get.find<UserHistoryService>().snapshotSync();
    if (history.isEmpty) return const <VodItem>[];
    final entries = history
        .where((e) => e.kind == UserHistoryKind.vod)
        .toList()
      ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    if (entries.isEmpty) return const <VodItem>[];
    final visible = visibleVods(data);
    final byId = <int, VodItem>{for (final v in visible) v.id: v};
    final out = <VodItem>[];
    final seen = <int>{};
    for (final e in entries) {
      if (seen.contains(e.contentId)) continue;
      final v = byId[e.contentId];
      if (v == null) continue;
      seen.add(e.contentId);
      out.add(v);
    }
    return out;
  }

  /// **Son izlenenler — Filmler (fallback'li).**
  ///
  /// Önce gerçek geçmişi denenir ([recentlyWatchedFilms]); kullanıcı henüz
  /// hiçbir film izlemediyse veya playlist'teki ID'lerle eşleşme yoksa,
  /// satırın boş kalmaması için [visibleVods] havuzundan **stable seed**
  /// ile karıştırılmış rastgele bir önizleme döner. Kullanıcı ilk izlemeyi
  /// gerçekleştirdiğinde liste otomatik gerçek veriye geçer.
  ///
  /// [excludeIds] — hero/recentlyAdded gibi başka satırlarda zaten görünen
  /// öğeler havuzdan çıkarılır (fallback boş kalmaması için yeterli sayı
  /// kalmadığında tüm görünür havuza geri düşülür).
  static List<VodItem> recentlyWatchedFilmsOrFallback(
    M3uResult data, {
    Set<int>? excludeIds,
    int count = rowPreviewLimit,
  }) {
    final real = recentlyWatchedFilms(data);
    if (real.isNotEmpty) return real;
    final visible = visibleVods(data);
    if (visible.isEmpty) return const <VodItem>[];
    final exclude = excludeIds ?? const <int>{};
    var pool = visible.where((v) => !exclude.contains(v.id)).toList();
    if (pool.length < count) {
      pool = visible.toList();
    }
    final seed = visible.length * 1009 + visible.first.id;
    pool.shuffle(Random(seed));
    if (pool.length <= count) return List<VodItem>.unmodifiable(pool);
    return List<VodItem>.unmodifiable(pool.sublist(0, count));
  }

  /// **Son izlenenler — Diziler.**
  ///
  /// `UserHistoryService` `series` kayıtlarındaki `contentId` aslında
  /// oynatıcıdaki **bölüm channel id**'sidir; doğrudan [SeriesItem.id] ile
  /// eşleşmeyebilir. Bu yüzden eşleştirme:
  /// 1) `entry.contentId == s.id` doğrudan kontrol,
  /// 2) Aksi halde `displayTitleFromName` üzerinden ad eşleşmesi
  ///    (oynatıcıdaki bölüm adı dizi adına normalize edilir).
  /// Her dizi başlığı tek temsilci [SeriesItem] ile çıkar; aynı dizi tekrar
  /// gelirse atlanır.
  static List<SeriesItem> recentlyWatchedSeries(M3uResult data) {
    if (!Get.isRegistered<UserHistoryService>()) {
      return const <SeriesItem>[];
    }
    final history = Get.find<UserHistoryService>().snapshotSync();
    if (history.isEmpty) return const <SeriesItem>[];
    final entries = history
        .where((e) => e.kind == UserHistoryKind.series)
        .toList()
      ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    if (entries.isEmpty) return const <SeriesItem>[];

    final visible = visibleSeries(data);
    if (visible.isEmpty) return const <SeriesItem>[];
    // Aynı dizi başlığına ait farklı bölüm SeriesItem'larını grupla — bir
    // başlık için tek temsilci yeterli.
    final groups = SeriesNameGrouping.group(visible);
    final byId = <int, SeriesItem>{};
    final byNormalizedTitle = <String, SeriesItem>{};
    for (final g in groups) {
      final rep = SeriesNameGrouping.representative(g);
      final t = SeriesNameGrouping.displayTitleForGroup(g).toLowerCase();
      byNormalizedTitle.putIfAbsent(t, () => rep);
      for (final s in g) {
        byId.putIfAbsent(s.id, () => rep);
      }
    }

    final out = <SeriesItem>[];
    final seenIds = <int>{};
    final seenTitles = <String>{};
    for (final e in entries) {
      var match = byId[e.contentId];
      if (match == null) {
        final t = SeriesNameGrouping.displayTitleFromName(e.name).toLowerCase();
        if (t.isNotEmpty) match = byNormalizedTitle[t];
      }
      if (match == null) continue;
      final tNorm =
          SeriesNameGrouping.displayTitleFromName(match.name).toLowerCase();
      if (seenIds.contains(match.id) || seenTitles.contains(tNorm)) continue;
      seenIds.add(match.id);
      seenTitles.add(tNorm);
      out.add(match);
    }
    return out;
  }

  /// **Son izlenenler — Diziler (fallback'li).**
  ///
  /// Aynı [recentlyWatchedFilmsOrFallback] mantığı: gerçek geçmiş varsa
  /// onu döner, yoksa görünür dizi havuzundan stable seed ile shuffle ile
  /// önizleme. Diziler için temsilci ([SeriesNameGrouping.representative])
  /// kullanılır — aynı dizinin farklı sezon/bölüm satırları havuzu kirletmez.
  static List<SeriesItem> recentlyWatchedSeriesOrFallback(
    M3uResult data, {
    Set<int>? excludeIds,
    int count = rowPreviewLimit,
  }) {
    final real = recentlyWatchedSeries(data);
    if (real.isNotEmpty) return real;
    final visible = visibleSeries(data);
    if (visible.isEmpty) return const <SeriesItem>[];
    final groups = SeriesNameGrouping.group(visible);
    if (groups.isEmpty) return const <SeriesItem>[];
    final reps = groups.map(SeriesNameGrouping.representative).toList();
    final exclude = excludeIds ?? const <int>{};
    var pool = reps.where((s) => !exclude.contains(s.id)).toList();
    if (pool.length < count) {
      pool = reps.toList();
    }
    final seed = reps.length * 1013 + reps.first.id;
    pool.shuffle(Random(seed));
    if (pool.length <= count) return List<SeriesItem>.unmodifiable(pool);
    return List<SeriesItem>.unmodifiable(pool.sublist(0, count));
  }

  /// **Favoriler — Filmler.**
  ///
  /// `FavoritesService.vodIds` içindeki favori film ID'leri, playlist'teki
  /// görünür [VodItem]'larla eşleştirilir. En son favorilenen başta olacak
  /// şekilde (liste ekleme sırasının tersi) döner. Favori yoksa boş liste.
  static List<VodItem> favoriteFilms(M3uResult data) {
    if (!Get.isRegistered<FavoritesService>()) return const <VodItem>[];
    final fav = Get.find<FavoritesService>();
    if (fav.vodIds.isEmpty) return const <VodItem>[];
    final visible = visibleVods(data);
    if (visible.isEmpty) return const <VodItem>[];
    final byId = <int, VodItem>{for (final v in visible) v.id: v};
    final out = <VodItem>[];
    for (final id in fav.vodIds.reversed) {
      final v = byId[id];
      if (v != null) out.add(v);
    }
    return out;
  }

  /// **Favoriler — Diziler.**
  ///
  /// `FavoritesService.seriesIds` içindeki favori dizi ID'leri, görünür dizi
  /// havuzunda gruplandırılıp temsilci [SeriesItem] olarak döner; aynı dizi
  /// tekrar gelmez. En son favorilenen başta. Favori yoksa boş liste.
  static List<SeriesItem> favoriteSeries(M3uResult data) {
    if (!Get.isRegistered<FavoritesService>()) return const <SeriesItem>[];
    final fav = Get.find<FavoritesService>();
    if (fav.seriesIds.isEmpty) return const <SeriesItem>[];
    final visible = visibleSeries(data);
    if (visible.isEmpty) return const <SeriesItem>[];
    final groups = SeriesNameGrouping.group(visible);
    final byId = <int, SeriesItem>{};
    for (final g in groups) {
      final rep = SeriesNameGrouping.representative(g);
      for (final s in g) {
        byId.putIfAbsent(s.id, () => rep);
      }
    }
    final out = <SeriesItem>[];
    final seen = <int>{};
    for (final id in fav.seriesIds.reversed) {
      final rep = byId[id];
      if (rep == null || seen.contains(rep.id)) continue;
      seen.add(rep.id);
      out.add(rep);
    }
    return out;
  }

  /// M3U bölüm satırlarını dizi başlığı altında birleştirir; en yeni eklenen önce.
  static List<SeriesItem> _groupedSeriesSortedByAdded(List<SeriesItem> items) {
    final groups = SeriesNameGrouping.group(items);
    groups.sort((a, b) {
      final au = SeriesNameGrouping.maxAddedUnix(a);
      final bu = SeriesNameGrouping.maxAddedUnix(b);
      if (bu != au) return bu.compareTo(au);
      return SeriesNameGrouping.displayTitleForGroup(a)
          .compareTo(SeriesNameGrouping.displayTitleForGroup(b));
    });
    return groups.map(SeriesNameGrouping.representative).toList();
  }

  static bool _vodCategoryHidden(M3uResult data, int categoryId) {
    final app = Get.find<AppSettingsService>();
    final cache = Get.find<PlaylistCacheService>();
    return PlaylistCategoryHide.vodCategoryHidden(app, cache, data, categoryId);
  }

  static bool _seriesCategoryHidden(M3uResult data, int categoryId) {
    final app = Get.find<AppSettingsService>();
    final cache = Get.find<PlaylistCacheService>();
    return PlaylistCategoryHide.seriesCategoryHidden(
      app,
      cache,
      data,
      categoryId,
    );
  }

  static List<VodItem> _sortVodByAdded(List<VodItem> items) {
    final copy = List<VodItem>.from(items)
      ..sort((a, b) {
        final au = a.addedUnix ?? 0;
        final bu = b.addedUnix ?? 0;
        if (bu != au) return bu.compareTo(au);
        return a.name.compareTo(b.name);
      });
    return copy;
  }

  /// TMDB oyuncu filmografisi başlığını playlist VOD kaydıyla eşleştirir.
  /// Tüm playlist VOD'ları taranır (gizli kategoriler dahil) — kullanıcı
  /// oyuncu sayfasından eriştiği filmi her zaman açabilmeli.
  static VodItem? findVodByTitle(
    M3uResult data,
    String title, {
    String? year,
  }) {
    final needle = _normalizeFilmTitleForMatch(title);
    if (needle.isEmpty) return null;
    final needleTokens = needle.split(' ').where((t) => t.length >= 2).toSet();

    VodItem? best;
    var bestScore = -1;

    for (final v in data.vod) {
      final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(v.name);
      final hay = _normalizeFilmTitleForMatch(cleaned.$1);
      if (hay.isEmpty) continue;

      var score = 0;
      if (hay == needle) {
        score = 100;
      } else if (hay.contains(needle) || needle.contains(hay)) {
        final shorter = hay.length < needle.length ? hay.length : needle.length;
        final longer = hay.length > needle.length ? hay.length : needle.length;
        if (shorter < 3 || shorter / longer < 0.40) {
          // Düşük güvenli içerme — kelime overlap ile bir şans daha ver
        } else {
          score = 78;
        }
      }

      // Kelime kümesi tabanlı eşleşme (Jaccard-benzeri); kısa başlıklarda
      // "The Sleeper" ↔ "Sleeper" gibi durumları yakalar.
      if (score < 70 && needleTokens.isNotEmpty) {
        final hayTokens =
            hay.split(' ').where((t) => t.length >= 2).toSet();
        if (hayTokens.isNotEmpty) {
          final inter = needleTokens.intersection(hayTokens).length;
          final union = needleTokens.union(hayTokens).length;
          final overlap = inter / union;
          if (overlap >= 0.6 && inter >= 1) {
            score = 70 + ((overlap - 0.6) * 50).round();
          }
        }
      }

      if (score <= 0) continue;

      final vodYear = cleaned.$2;
      if (year != null && year.isNotEmpty) {
        if (vodYear == year) {
          score += 25;
        } else if (vodYear != null && vodYear != year) {
          final yi = int.tryParse(vodYear);
          final yj = int.tryParse(year);
          if (yi != null && yj != null && (yi - yj).abs() <= 1) {
            // 1 yıl tolerans (DVD vs sinema ayrımı için)
            score += 5;
          } else {
            score -= 20;
          }
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }

    return bestScore >= 65 ? best : null;
  }

  static String _normalizeFilmTitleForMatch(String raw) {
    var s = raw.trim().toLowerCase();
    // Türkçe karakterleri ASCII'ye düşür (playlist'te 'şŞıİğç' farklı yazılabiliyor).
    const trMap = {
      'ı': 'i',
      'İ': 'i',
      'ş': 's',
      'Ş': 's',
      'ğ': 'g',
      'Ğ': 'g',
      'ü': 'u',
      'Ü': 'u',
      'ö': 'o',
      'Ö': 'o',
      'ç': 'c',
      'Ç': 'c',
    };
    final buf = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      buf.write(trMap[ch] ?? ch);
    }
    s = buf.toString();
    s = s.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    s = s.replaceAll(RegExp(r'\b(the|a|an|bir)\b', unicode: true), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

}
