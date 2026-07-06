import '../../core/services/app_settings_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/playlist_category_hide.dart';
import '../../core/services/playlist_data_source.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';

/// Ana ekran kart rozetleri için canlı / film / dizi sayıları.
class HomeCardCounts {
  const HomeCardCounts({
    required this.live,
    required this.films,
    required this.series,
  });

  final int live;
  final int films;
  final int series;
}

/// Sayım sonuçlarının hangi veri kümesine ait olduğunu belirleyen anahtar.
/// Splash'te hesaplanan sayımın ana ekrana taşınabilmesi için home controller
/// ile **birebir aynı** formül kullanılır.
int homeCardCountsScopeKey(
  M3uResult d,
  AppSettingsService app,
  PlaylistCacheService cache,
) =>
    Object.hash(
      d.hashCode,
      cache.lastUpdated.value?.millisecondsSinceEpoch ?? 0,
      app.xtreamHideRevision.value,
      app.playlistLayoutRevision.value,
    );

/// Ana ekran kart sayılarını hesaplar. DB destekliyse ucuz `COUNT` + kategori
/// gizleme filtresiyle; aksi halde bellekteki listeler üzerinden. Splash ve
/// home controller bu tek kaynağı paylaşır (mantık tek yerde kalsın).
Future<HomeCardCounts> computeHomeCardCounts({
  required M3uResult d,
  required AppSettingsService app,
  required PlaylistCacheService cache,
  required PlaylistDataSource ds,
}) async {
  int live;
  int films;
  int series;

  if (ds.isDbBacked) {
    final channelCounts = await ds.channelCountsByCategory(visibleOnly: true);
    var liveAcc = 0;
    channelCounts.forEach((catId, n) {
      ChannelCategory? cat;
      for (final c in d.channelCategories) {
        if (c.id == catId) {
          cat = c;
          break;
        }
      }
      if (cat != null &&
          PlaylistCategoryHide.liveCategoryRowHidden(app, cache, cat)) {
        return;
      }
      liveAcc += n;
    });
    live = liveAcc;

    final vodCounts = await ds.vodCountsByCategory();
    final seriesCounts = await ds.seriesCountsByCategory();
    var filmsAcc = 0;
    vodCounts.forEach((catId, n) {
      if (!PlaylistCategoryHide.vodCategoryHidden(app, cache, d, catId)) {
        filmsAcc += n;
      }
    });
    var seriesAcc = 0;
    seriesCounts.forEach((catId, n) {
      if (!PlaylistCategoryHide.seriesCategoryHidden(app, cache, d, catId)) {
        seriesAcc += n;
      }
    });
    films = filmsAcc;
    series = seriesAcc;
  } else {
    var liveAcc = 0;
    for (final ch in d.channels) {
      if (!PlaylistCategoryHide.channelHiddenInLive(app, cache, d, ch)) {
        liveAcc++;
      }
    }
    var filmsAcc = 0;
    for (final v in d.vod) {
      if (!PlaylistCategoryHide.vodItemHidden(app, cache, d, v)) filmsAcc++;
    }
    var seriesAcc = 0;
    for (final s in d.series) {
      if (!PlaylistCategoryHide.seriesItemHidden(app, cache, d, s)) seriesAcc++;
    }
    live = liveAcc;
    films = filmsAcc;
    series = seriesAcc;
  }

  return HomeCardCounts(live: live, films: films, series: series);
}
