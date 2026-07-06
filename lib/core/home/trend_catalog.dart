import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/movie_model.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../services/movie_service.dart';
import 'film_dizi_catalog.dart';
import 'recommended_films_catalog.dart';

/// Vitrin **Trend** satırları (Trend Filmler / Trend Diziler).
///
/// "Trend" = IMDB puanı [kTrendMinRating] (7.0) ve üzeri içerikler; puana göre
/// azalan sıralanır, en fazla [kTrendMaxItems] (50) öğe gösterilir.
///
/// **Yük politikası:** Liste, halihazırda önbellekte (sağlayıcı `rating` alanı
/// veya daha önce OMDb'den çekilmiş) bulunan puanlardan anında hesaplanır;
/// hiçbir senkron ağ çağrısı yapılmaz. Puan havuzunu büyütmek için
/// [maybeRefresh] **nadir aralıklarla** (en çok 24 saatte bir) sınırlı bir
/// grup için arka planda OMDb zenginleştirmesi tetikler. Böylece uygulamaya
/// yük binmez ama liste zamanla dolar/tazelenir.
abstract final class TrendCatalog {
  TrendCatalog._();

  static const double kTrendMinRating = 7.0;
  static const int kTrendMaxItems = 50;

  /// Nadir tazeleme aralığı — en çok 24 saatte bir arka plan zenginleştirme.
  static const Duration _refreshCooldown = Duration(hours: 24);

  /// Her tazelemede en çok bu kadar film + dizi için OMDb puanı çekilir
  /// (kalanlar sonraki tazelemelerde, disk önbelleği birikerek tamamlanır).
  static const int _enrichBatchFilms = 40;
  static const int _enrichBatchSeries = 40;

  static const String _kLastEnrichMs = 'mina_trend_last_enrich_ms';

  static bool _refreshScheduled = false;

  /// IMDB 7+ filmler (puana göre azalan, en çok 50).
  static List<VodItem> trendFilms(M3uResult data) {
    final items = RecommendedFilmsCatalog.visibleVods(data);
    if (items.isEmpty) return const [];
    final rated = <VodItem>[];
    for (final v in items) {
      if (RecommendedFilmsRatingCache.effectiveRating(v) >= kTrendMinRating) {
        rated.add(v);
      }
    }
    rated.sort(
      (a, b) => RecommendedFilmsRatingCache.effectiveRating(b)
          .compareTo(RecommendedFilmsRatingCache.effectiveRating(a)),
    );
    if (rated.length <= kTrendMaxItems) return rated;
    return rated.sublist(0, kTrendMaxItems);
  }

  /// IMDB 7+ diziler (puana göre azalan, en çok 50).
  static List<SeriesItem> trendSeries(M3uResult data) {
    final items = FilmDiziCatalog.visibleSeries(data);
    if (items.isEmpty) return const [];
    final rated = <SeriesItem>[];
    for (final s in items) {
      if (SeriesRatingCache.effectiveRating(s) >= kTrendMinRating) {
        rated.add(s);
      }
    }
    rated.sort(
      (a, b) => SeriesRatingCache.effectiveRating(b)
          .compareTo(SeriesRatingCache.effectiveRating(a)),
    );
    if (rated.length <= kTrendMaxItems) return rated;
    return rated.sublist(0, kTrendMaxItems);
  }

  /// Nadir aralıklarla (en çok 24 saatte bir) arka planda puan zenginleştirme
  /// tetikler. Süre dolmadıysa hiçbir şey yapmaz. Çağıran tarafın `await`
  /// etmesi gerekmez; tüm iş arka planda yürür.
  static Future<void> maybeRefresh(M3uResult data) async {
    if (_refreshScheduled) return;
    if (!MovieService.omdbApiAvailable) return;
    _refreshScheduled = true;
    try {
      await RecommendedFilmsRatingCache.ensureDiskLoaded();
      await SeriesRatingCache.ensureDiskLoaded();
      final p = await SharedPreferences.getInstance();
      final last = p.getInt(_kLastEnrichMs) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < _refreshCooldown.inMilliseconds) {
        return;
      }
      await p.setInt(_kLastEnrichMs, now);

      // Filmler: yalnızca henüz puansız olanları gruba al (öncelik son eklenen).
      final films = RecommendedFilmsCatalog.visibleVods(data);
      await RecommendedFilmsRatingCache.enrichRatings(
        films,
        limit: _enrichBatchFilms,
      );

      final series = FilmDiziCatalog.visibleSeries(data);
      await SeriesRatingCache.enrichRatings(
        series,
        limit: _enrichBatchSeries,
      );
    } catch (_) {
    } finally {
      _refreshScheduled = false;
    }
  }
}

/// Dizi IMDB puanı önbelleği (oturum + disk). [RecommendedFilmsRatingCache]'in
/// dizi karşılığı: dizilerin `rating` alanı olmadığından puanlar yalnızca OMDb
/// (`type=series`) üzerinden, [TrendCatalog.maybeRefresh] ile nadir aralıklarla
/// çekilir ve diske yazılır.
abstract final class SeriesRatingCache {
  SeriesRatingCache._();

  static const _prefsPrefix = 'mina_trend_series_imdb_v1_';
  static final Map<int, double> _memory = {};
  static bool _diskLoaded = false;
  static final RxInt revision = 0.obs;
  static bool _revisionBumpScheduled = false;

  static void _scheduleRevisionBump() {
    if (_revisionBumpScheduled) return;
    _revisionBumpScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _revisionBumpScheduled = false;
      revision.value = revision.value + 1;
    });
  }

  static double effectiveRating(SeriesItem s) => _memory[s.id] ?? 0;

  static double _parseRating(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 0;
    final s = raw.trim().replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  static Future<void> ensureDiskLoaded() async {
    if (_diskLoaded) return;
    _diskLoaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      final keys = p.getKeys().where((k) => k.startsWith(_prefsPrefix));
      var any = false;
      for (final k in keys) {
        final id = int.tryParse(k.substring(_prefsPrefix.length));
        final v = p.getDouble(k);
        if (id != null && v != null && v > 0) {
          _memory[id] = v;
          any = true;
        }
      }
      if (any) _scheduleRevisionBump();
    } catch (_) {}
  }

  static Future<void> put(int seriesId, double rating) async {
    if (rating <= 0) return;
    _memory[seriesId] = rating;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('$_prefsPrefix$seriesId', rating);
    } catch (_) {}
  }

  /// En fazla [limit] dizi için OMDb (`type=series`) puanı çeker (sırayla).
  static Future<void> enrichRatings(
    List<SeriesItem> candidates, {
    int limit = 32,
  }) async {
    await ensureDiskLoaded();
    if (!Get.isRegistered<MovieService>()) return;
    final ms = Get.find<MovieService>();
    if (!MovieService.omdbApiAvailable) return;
    var done = 0;
    var changed = false;
    for (final s in candidates) {
      if (done >= limit) break;
      if (effectiveRating(s) > 0) continue;
      try {
        final cleaned = RecommendedFilmsCatalog.cleanTitleAndYear(s.name);
        final title = cleaned.$1;
        if (title.isEmpty) continue;
        final MovieModel? info = await ms.fetchMovieInfo(
          title,
          year: cleaned.$2,
          type: 'series',
        );
        if (!MovieService.omdbApiAvailable) break;
        final r = _parseRating(info?.imdbRating);
        if (r > 0) {
          await put(s.id, r);
          changed = true;
          done++;
        }
      } catch (_) {}
      // Ana izoleye nefes: ardışık OMDb çağrıları UI thread'i tıkamasın.
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    if (changed) _scheduleRevisionBump();
  }
}
