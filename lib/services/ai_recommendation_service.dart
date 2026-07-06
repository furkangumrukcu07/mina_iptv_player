import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/app_settings_service.dart';
import '../core/services/playlist_cache_service.dart';
import '../core/services/playlist_data_source.dart';
import '../core/services/playlist_category_hide.dart';
import '../domain/entities/channel.dart';
import '../domain/entities/m3u_result.dart';
import '../domain/entities/series.dart';
import '../domain/entities/vod.dart';
import 'user_history_service.dart';
import 'ai_recommendation_isolate.dart';

/// AI önerisinin tek bir öğesi.
///
/// `kind` alanı UI tarafında rozet (Live / Film / Series) belirler. Açma
/// adımı [AiRecommendationStrip] içinde kart tipine göre yapılır.
class AiRecommendation {
  const AiRecommendation({
    required this.kind,
    required this.id,
    required this.name,
    required this.categoryId,
    this.categoryName,
    this.posterUrl,
    this.channel,
    this.vod,
    this.series,
    required this.score,
  });

  final UserHistoryKind kind;
  final int id;
  final String name;
  final String categoryId;
  final String? categoryName;
  final String? posterUrl;
  final Channel? channel;
  final VodItem? vod;
  final SeriesItem? series;

  /// 0.0 — 1.0 arası eşleşme skoru (UI'da yüzde olarak gösterilebilir).
  final double score;
}

/// Geçmiş izleme alışkanlığından çıkarılan profil — debug ve UI için.
class AiProfile {
  const AiProfile({
    required this.topCategories,
    required this.timeBand,
    required this.totalEntries,
  });

  /// `(kind, categoryId)` anahtarıyla en yüksek puanlı 3 kategori.
  final List<({UserHistoryKind kind, String categoryId, double score})>
      topCategories;
  final UserHistoryTimeBand timeBand;
  final int totalEntries;

  bool get isEmpty => totalEntries == 0;
}

/// Yapay zekâ önerileri için saf hesaplama motoru.
///
/// * Hive / Isar gerektirmez — [UserHistoryService] (SharedPreferences) ve
///   mevcut [M3uResult] kataloğu üzerinden çalışır.
/// * Tüm hesap senkronik ve hızlıdır; ana ekran her açıldığında
///   [HomeController] tarafından arkada çağrılabilir.
/// * Sonuç 6 karma öneridir (~2 canlı + ~2 film + ~2 dizi) — kullanıcı
///   profili dengesiz olduğunda dolgu ile 10'a tamamlanır.
class AiRecommendationService extends GetxService {
  static const int kRecommendationCount = 6;

  /// İsolate'e gönderilecek azami canlı aday sayısı. Skorlayıcı yalnızca üst
  /// kategorilerden ~2 kanal seçtiği için bu sınır sonucu etkilemez; ama dev
  /// listelerde ana thread'i kilitleyen `Map` üretimi/serileştirmesini önler.
  static const int _kMaxLiveCandidates = 6000;

  /// Film/dizi aday havuzu da ana thread'de `Map` üretirken sınırlandırılır;
  /// 76.000+ filmlik listelerde tüm satırları materyalize etmek (76k Map) UI'ı
  /// kilitler / OOM yapar. Skorlayıcı zaten yalnızca üst kategorileri ödüllendirir.
  static const int _kMaxVodCandidates = 6000;
  static const int _kMaxSeriesCandidates = 6000;

  /// AI rozet eşiği (UI etiket); skor bunun altındaysa "%80+ eşleşme"
  /// yerine sadece "öneri" olarak gösterilebilir. Sabit kalsın.
  static const double kHighConfidenceThreshold = 0.80;

  UserHistoryService get _history => Get.find<UserHistoryService>();

  AppSettingsService? _appOrNull() =>
      Get.isRegistered<AppSettingsService>() ? Get.find<AppSettingsService>() : null;

  PlaylistCacheService? _cacheOrNull() => Get.isRegistered<PlaylistCacheService>()
      ? Get.find<PlaylistCacheService>()
      : null;

  /// Ana ekran şeritlerinde dışlanması gereken canlı kanal mı?
  bool _isLiveHidden(M3uResult data, Channel ch) {
    final app = _appOrNull();
    final cache = _cacheOrNull();
    if (app == null || cache == null) return false;
    return PlaylistCategoryHide.liveChannelHiddenForHome(app, cache, data, ch);
  }

  /// Ana ekran şeritlerinde dışlanması gereken VOD mu?
  bool _isVodHidden(M3uResult data, VodItem v) {
    final app = _appOrNull();
    final cache = _cacheOrNull();
    if (app == null || cache == null) return false;
    return PlaylistCategoryHide.vodHiddenForHome(app, cache, data, v);
  }

  bool _isVodLiteHidden(M3uResult data, VodLite v) {
    final app = _appOrNull();
    final cache = _cacheOrNull();
    if (app == null || cache == null) return false;
    return PlaylistCategoryHide.vodLiteHidden(app, cache, data, v);
  }

  bool _isSeriesLiteHidden(M3uResult data, SeriesLite s) {
    final app = _appOrNull();
    final cache = _cacheOrNull();
    if (app == null || cache == null) return false;
    return PlaylistCategoryHide.seriesLiteHidden(app, cache, data, s);
  }

  /// Ana ekran şeritlerinde dışlanması gereken dizi mi?
  bool _isSeriesHidden(M3uResult data, SeriesItem s) {
    final app = _appOrNull();
    final cache = _cacheOrNull();
    if (app == null || cache == null) return false;
    return PlaylistCategoryHide.seriesHiddenForHome(app, cache, data, s);
  }

  /// Mevcut profil — debug / UI etiketi için.
  AiProfile buildProfile({DateTime? now}) {
    final history = _history.snapshotSync();
    final currentBand =
        timeBandOf((now ?? DateTime.now()).toLocal().hour);
    if (history.isEmpty) {
      return AiProfile(
        topCategories: const [],
        timeBand: currentBand,
        totalEntries: 0,
      );
    }
    final scores = <String, double>{};
    final kinds = <String, UserHistoryKind>{};
    for (final e in history) {
      final key = '${e.kind.index}|${e.categoryId}';
      kinds[key] = e.kind;
      // Saat dilimi aynıysa puan iki katı.
      final bandBonus = e.timeBand == currentBand ? 2.0 : 1.0;
      // Daha uzun izlemeler logaritmik bonus (5dk vs 60dk arası ayrım kalsın).
      final durationBoost = 1.0 +
          (math.log(math.max(60, e.watchedSeconds)) / math.log(10) - 1.7) *
              0.4;
      scores.update(
        key,
        (v) => v + (1.0 * bandBonus * durationBoost),
        ifAbsent: () => 1.0 * bandBonus * durationBoost,
      );
    }
    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = <({UserHistoryKind kind, String categoryId, double score})>[];
    for (final entry in sorted.take(3)) {
      final key = entry.key;
      final kind = kinds[key]!;
      final cat = key.substring(key.indexOf('|') + 1);
      top.add((kind: kind, categoryId: cat, score: entry.value));
    }
    return AiProfile(
      topCategories: top,
      timeBand: currentBand,
      totalEntries: history.length,
    );
  }

  /// Karma 6 öneri üretir. [seedSalt] aynı gün içinde stabil bir sıralama
  /// için kullanılır (örn. uygulama açılışında her seferinde yeniden
  /// karıştırılmasın diye günlük seed verilir).
  List<AiRecommendation> recommend(
    M3uResult data, {
    int count = kRecommendationCount,
    int? seedSalt,
    DateTime? now,
  }) {
    if (count <= 0) return const [];
    final profile = buildProfile(now: now);

    // Profil yoksa: dolgu öneri (yeni kullanıcı).
    if (profile.isEmpty) {
      return _coldStart(data, count: count, seedSalt: seedSalt);
    }

    // Geçmişte oynatılmış içerik kimlikleri — bunları doğrudan tekrar
    // önermemek için "yeni içerik" hediye etmek istiyoruz; ama keşfedilenler
    // de küçük puanla yer alabilir.
    final seenIds = <String>{};
    for (final e in _history.snapshotSync()) {
      seenIds.add('${e.kind.index}|${e.contentId}');
    }

    final scoredLive = _scoreChannels(data, profile, seenIds);
    final scoredVod = _scoreVod(data, profile, seenIds);
    final scoredSeries = _scoreSeries(data, profile, seenIds);

    // Karma dağılım hedefi: ~2 canlı + ~2 film + ~2 dizi (toplam 6).
    final targetLive = (count * 0.30).round();
    final targetVod = (count * 0.40).round();
    final targetSeries = count - targetLive - targetVod;

    final picked = <AiRecommendation>[];
    picked.addAll(scoredLive.take(targetLive));
    picked.addAll(scoredVod.take(targetVod));
    picked.addAll(scoredSeries.take(targetSeries));

    // Eksik kalanları (örn. dizi 0 ise) en yüksek skorludan dolgula.
    if (picked.length < count) {
      final pool = <AiRecommendation>[
        ...scoredLive.skip(targetLive),
        ...scoredVod.skip(targetVod),
        ...scoredSeries.skip(targetSeries),
      ]..sort((a, b) => b.score.compareTo(a.score));
      for (final r in pool) {
        if (picked.length >= count) break;
        if (picked.any((p) => p.kind == r.kind && p.id == r.id)) continue;
        picked.add(r);
      }
    }

    // Sırayı kullanıcı için karıştırılmış (ama günlük stabil) hâle getir.
    final salt = seedSalt ?? _dailySalt(now: now);
    picked.shuffle(math.Random(salt ^ profile.totalEntries));

    return picked.take(count).toList(growable: false);
  }

  /// Büyük kataloglarda skorlamayı isolate'te yapar; küçük listelerde
  /// senkron [recommend] yeterince hızlıdır.
  Future<List<AiRecommendation>> recommendAsync(
    M3uResult data, {
    int count = kRecommendationCount,
    int? seedSalt,
    DateTime? now,
  }) async {
    final ds = Get.isRegistered<PlaylistDataSource>()
        ? Get.find<PlaylistDataSource>()
        : null;
    final dbBacked = ds?.isDbBacked == true;

    if (dbBacked) {
      final profile = buildProfile(now: now);
      final salt = seedSalt ?? _dailySalt(now: now);
      if (profile.isEmpty) {
        return _coldStartFromDb(data, ds!, count: count, seedSalt: salt);
      }
      final input = await _buildIsolateInputFromDb(
        data: data,
        ds: ds!,
        profile: profile,
        count: count,
        seedSalt: salt,
      );
      final raw = await compute(aiRecommendIsolate, input);
      return _hydrateRecommendationsFromDb(data, ds, raw);
    }

    final dsForCount = Get.isRegistered<PlaylistDataSource>()
        ? Get.find<PlaylistDataSource>()
        : null;
    final vodLen = dsForCount?.isDbBacked == true
        ? await dsForCount!.vodCount()
        : data.vod.length;
    final seriesLen = dsForCount?.isDbBacked == true
        ? await dsForCount!.seriesCount()
        : data.series.length;
    final channelLen = dsForCount?.isDbBacked == true
        ? await dsForCount!.channelCount(visibleOnly: true)
        : data.channels.length;
    final total = channelLen + vodLen + seriesLen;
    if (total < 2500) {
      return recommend(
        data,
        count: count,
        seedSalt: seedSalt,
        now: now,
      );
    }
    final profile = buildProfile(now: now);
    final input = _buildIsolateInput(
      data: data,
      profile: profile,
      count: count,
      seedSalt: seedSalt ?? _dailySalt(now: now),
    );
    final raw = await compute(aiRecommendIsolate, input);
    return _hydrateRecommendations(data, raw);
  }

  // ---------------------------------------------------------------------------
  // Disk önbelleği — uygulama her soğuk açılışta isolate skorlamasını baştan
  // hesaplıyordu (büyük kataloglarda ~yüzlerce ms + spinner). Son hesaplanan
  // öneriler kompakt biçimde (`{k,id,s}`) diske yazılır; bir sonraki açılışta
  // anında geri yüklenip (10 öğe hydrate ~hızlı) gösterilir, arka planda taze
  // hesap yapılır. Böylece şerit "hemen" gelir.
  // ---------------------------------------------------------------------------
  static const String _kRawCacheKey = 'mina_ai_reco_raw_v1';

  List<Map<String, dynamic>> _toCompact(List<AiRecommendation> recs) => [
        for (final r in recs)
          {'k': r.kind.index, 'id': r.id, 's': r.score},
      ];

  /// Son hesaplanan önerileri [cacheKey] ile diske yazar. Boşsa siler.
  Future<void> persistRaw(String cacheKey, List<AiRecommendation> recs) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (recs.isEmpty) {
        await p.remove(_kRawCacheKey);
        return;
      }
      await p.setString(
        _kRawCacheKey,
        jsonEncode({'key': cacheKey, 'raw': _toCompact(recs)}),
      );
    } catch (_) {
      // Önbellek yazımı kritik değil; sessizce geç.
    }
  }

  /// Diskteki öneriyi [cacheKey] eşleşiyorsa geri yükler ve hydrate eder.
  /// Anahtar uyuşmazsa veya kayıt yoksa `null` döner.
  Future<List<AiRecommendation>?> restoreRaw(
    M3uResult data,
    String cacheKey,
  ) async {
    try {
      final p = await SharedPreferences.getInstance();
      final str = p.getString(_kRawCacheKey);
      if (str == null || str.isEmpty) return null;
      final decoded = jsonDecode(str);
      if (decoded is! Map) return null;
      if (decoded['key'] != cacheKey) return null;
      final rawList = decoded['raw'];
      if (rawList is! List || rawList.isEmpty) return null;
      final raw = <Map<String, dynamic>>[
        for (final m in rawList)
          if (m is Map)
            {
              'k': (m['k'] as num).toInt(),
              'id': (m['id'] as num).toInt(),
              's': (m['s'] as num).toDouble(),
            },
      ];
      if (raw.isEmpty) return null;

      final ds = Get.isRegistered<PlaylistDataSource>()
          ? Get.find<PlaylistDataSource>()
          : null;
      final dbBacked = ds?.isDbBacked == true;
      final out = dbBacked
          ? await _hydrateRecommendationsFromDb(data, ds!, raw)
          : _hydrateRecommendations(data, raw);
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  bool _isChannelLiteHidden(M3uResult data, ChannelLite cl) {
    return _isLiveHidden(
      data,
      Channel(
        id: cl.id,
        name: cl.name,
        streamUrl: '',
        categoryId: cl.categoryId,
        logoUrl: cl.logoUrl,
      ),
    );
  }

  Future<AiRecommendIsolateInput> _buildIsolateInputFromDb({
    required M3uResult data,
    required PlaylistDataSource ds,
    required AiProfile profile,
    required int count,
    required int seedSalt,
  }) async {
    final vodLite = await ds.vodLite();
    final seriesLite = await ds.seriesLite();
    final channelLite = await ds.channelLite();
    final seenKeys = <String>[
      for (final e in _history.snapshotSync())
        '${e.kind.index}|${e.contentId}',
    ];
    final top = [
      for (final t in profile.topCategories)
        {
          'k': t.kind.index,
          'cat': t.categoryId,
          's': t.score,
        },
    ];
    // Canlı aday havuzunu kullanıcının üst canlı kategorileriyle sınırla:
    // profil dolu olduğunda isolate skorlayıcısı zaten yalnızca bu
    // kategorilerdeki kanalları tutuyor (diğerleri `base<=0` → elenir). Böylece
    // 233 bin kanallık listelerde ana thread'de 233 bin `Map` üretip +18 ismi
    // taramak yerine yalnızca birkaç bin aday işlenir; ANR önlenir.
    final topLiveCats = <String>{
      for (final t in profile.topCategories)
        if (t.kind == UserHistoryKind.live) t.categoryId,
    };
    final liveItems = <Map<String, dynamic>>[];
    if (topLiveCats.isNotEmpty) {
      for (final cl in channelLite) {
        if (!topLiveCats.contains(cl.categoryId.toString())) continue;
        if (_isChannelLiteHidden(data, cl)) continue;
        liveItems.add({'id': cl.id, 'cat': cl.categoryId, 'hidden': false});
        if (liveItems.length >= _kMaxLiveCandidates) break;
      }
    }

    // Film/dizi adaylarını da sınırla. Kullanıcının üst kategorileri varsa önce
    // onları al; havuz dolmazsa kalan kategorilerden tamamla. 76.000+ satırı tek
    // tek Map'e çevirip isolate'e göndermek ana thread'i kilitler.
    final topVodCats = <int>{
      for (final t in profile.topCategories)
        if (t.kind == UserHistoryKind.vod)
          if (int.tryParse(t.categoryId) case final c?) c,
    };
    final topSeriesCats = <int>{
      for (final t in profile.topCategories)
        if (t.kind == UserHistoryKind.series)
          if (int.tryParse(t.categoryId) case final c?) c,
    };

    final vodItems = _boundedLiteItems<VodLite>(
      vodLite,
      preferredCats: topVodCats,
      max: _kMaxVodCandidates,
      categoryOf: (v) => v.categoryId,
      toMap: (v) => {
        'id': v.id,
        'cat': v.categoryId,
        'rating': _ratingOf(v.rating),
        'hidden': _isVodLiteHidden(data, v),
      },
    );
    final seriesItems = _boundedLiteItems<SeriesLite>(
      seriesLite,
      preferredCats: topSeriesCats,
      max: _kMaxSeriesCandidates,
      categoryOf: (s) => s.categoryId,
      toMap: (s) => {
        'id': s.id,
        'cat': s.categoryId,
        'added': s.addedUnix ?? 0,
        'hidden': _isSeriesLiteHidden(data, s),
      },
    );

    return AiRecommendIsolateInput(
      count: count,
      seedSalt: seedSalt,
      profileEmpty: profile.isEmpty,
      topCategories: top,
      timeBand: profile.timeBand.index,
      totalHistoryEntries: profile.totalEntries,
      seenKeys: seenKeys,
      liveItems: liveItems,
      vodItems: vodItems,
      seriesItems: seriesItems,
    );
  }

  /// Büyük lite listelerinden en çok [max] aday üretir; varsa [preferredCats]
  /// kategorileri önce alınır, havuz dolmazsa kalanlardan tamamlanır.
  static List<Map<String, dynamic>> _boundedLiteItems<T>(
    List<T> all, {
    required Set<int> preferredCats,
    required int max,
    required int Function(T) categoryOf,
    required Map<String, dynamic> Function(T) toMap,
  }) {
    if (all.length <= max) {
      return [for (final e in all) toMap(e)];
    }
    final out = <Map<String, dynamic>>[];
    if (preferredCats.isNotEmpty) {
      for (final e in all) {
        if (!preferredCats.contains(categoryOf(e))) continue;
        out.add(toMap(e));
        if (out.length >= max) return out;
      }
    }
    for (final e in all) {
      if (preferredCats.contains(categoryOf(e))) continue;
      out.add(toMap(e));
      if (out.length >= max) break;
    }
    return out;
  }

  Future<List<AiRecommendation>> _coldStartFromDb(
    M3uResult data,
    PlaylistDataSource ds, {
    required int count,
    int? seedSalt,
  }) async {
    final salt = seedSalt ?? _dailySalt();
    final rand = math.Random(salt);
    final liveTarget = (count * 0.30).round();
    final vodTarget = (count * 0.40).round();
    final seriesTarget = count - liveTarget - vodTarget;

    final liveCats = {
      for (final c in data.channelCategories) c.id: c.name,
    };
    final vodCats = {
      for (final c in data.vodCategories) c.id: c.name,
    };
    final seriesCats = {
      for (final c in data.seriesCategories) c.id: c.name,
    };

    final list = <AiRecommendation>[];
    // Dev listelerde (~233 bin kanal) tüm kanalları gezip +18 taraması yapmak
    // yerine sınırlı rastgele örnekten ilk `liveTarget` görünür kanalı seç.
    final total = await ds.channelCount(visibleOnly: true);
    if (total > 0 && liveTarget > 0) {
      final maxProbe = math.min(total, math.max(200, liveTarget * 80));
      final start = total > maxProbe ? rand.nextInt(total - maxProbe) : 0;
      final probe = await ds.channelsPage(offset: start, limit: maxProbe);
      var added = 0;
      for (final ch in probe) {
        if (_isLiveHidden(data, ch)) continue;
        list.add(AiRecommendation(
          kind: UserHistoryKind.live,
          id: ch.id,
          name: ch.name,
          categoryId: ch.categoryId.toString(),
          categoryName: liveCats[ch.categoryId],
          posterUrl: ch.logoUrl,
          channel: ch,
          score: 0.55,
        ));
        if (++added >= liveTarget) break;
      }
    }

    final app = _appOrNull();
    final cache = _cacheOrNull();
    // 76.000+ satırlık listelerde tüm `vodLite()`'ı RAM'e çekip sıralamak ANR
    // yapar. Onun yerine SQLite tarafında puana göre sıralı, sınırlı bir havuz
    // çek; tam nesneler (poster/url) zaten bu sorguyla geliyor → ayrıca
    // `vodById` döngüsüne gerek yok.
    final vodPool = await ds.vodTopRated(limit: math.max(80, vodTarget * 8));
    final ratedVod = vodPool
        .where((v) =>
            app == null ||
            cache == null ||
            !PlaylistCategoryHide.vodItemHidden(app, cache, data, v))
        .toList(growable: false)
      ..shuffle(rand);
    for (final v in ratedVod.take(vodTarget)) {
      list.add(AiRecommendation(
        kind: UserHistoryKind.vod,
        id: v.id,
        name: v.name,
        categoryId: v.categoryId.toString(),
        categoryName: vodCats[v.categoryId],
        posterUrl: v.posterUrl,
        vod: v,
        score: 0.6,
      ));
    }

    final seriesPool =
        await ds.seriesSample(limit: math.max(80, seriesTarget * 8));
    final filteredSeries = seriesPool
        .where((s) =>
            app == null ||
            cache == null ||
            !PlaylistCategoryHide.seriesItemHidden(app, cache, data, s))
        .toList(growable: false)
      ..shuffle(rand);
    for (final s in filteredSeries.take(seriesTarget)) {
      list.add(AiRecommendation(
        kind: UserHistoryKind.series,
        id: s.id,
        name: s.name,
        categoryId: s.categoryId.toString(),
        categoryName: seriesCats[s.categoryId],
        posterUrl: s.posterUrl,
        series: s,
        score: 0.55,
      ));
    }

    list.shuffle(math.Random(salt + 1));
    return list.take(count).toList(growable: false);
  }

  Future<List<AiRecommendation>> _hydrateRecommendationsFromDb(
    M3uResult data,
    PlaylistDataSource ds,
    List<Map<String, dynamic>> raw,
  ) async {
    final liveCats = {for (final c in data.channelCategories) c.id: c.name};
    final vodCats = {for (final c in data.vodCategories) c.id: c.name};
    final seriesCats = {for (final c in data.seriesCategories) c.id: c.name};

    final out = <AiRecommendation>[];
    for (final m in raw) {
      final kind = UserHistoryKind.values[m['k'] as int];
      final id = m['id'] as int;
      final score = (m['s'] as num).toDouble();
      switch (kind) {
        case UserHistoryKind.live:
          final ch = await ds.channelById(id);
          if (ch == null) continue;
          out.add(AiRecommendation(
            kind: kind,
            id: id,
            name: ch.name,
            categoryId: ch.categoryId.toString(),
            categoryName: liveCats[ch.categoryId],
            posterUrl: ch.logoUrl,
            channel: ch,
            score: score,
          ));
        case UserHistoryKind.vod:
          final v = await ds.vodById(id);
          if (v == null) continue;
          out.add(AiRecommendation(
            kind: kind,
            id: id,
            name: v.name,
            categoryId: v.categoryId.toString(),
            categoryName: vodCats[v.categoryId],
            posterUrl: v.posterUrl,
            vod: v,
            score: score,
          ));
        case UserHistoryKind.series:
          final s = await ds.seriesById(id);
          if (s == null) continue;
          out.add(AiRecommendation(
            kind: kind,
            id: id,
            name: s.name,
            categoryId: s.categoryId.toString(),
            categoryName: seriesCats[s.categoryId],
            posterUrl: s.posterUrl,
            series: s,
            score: score,
          ));
      }
    }
    return out;
  }

  AiRecommendIsolateInput _buildIsolateInput({
    required M3uResult data,
    required AiProfile profile,
    required int count,
    required int seedSalt,
  }) {
    final seenKeys = <String>[
      for (final e in _history.snapshotSync())
        '${e.kind.index}|${e.contentId}',
    ];
    final top = [
      for (final t in profile.topCategories)
        {
          'k': t.kind.index,
          'cat': t.categoryId,
          's': t.score,
        },
    ];
    // Bkz. `_buildIsolateInputFromDb`: canlı havuzu üst kategorilerle sınırla.
    final topLiveCats = <String>{
      for (final t in profile.topCategories)
        if (t.kind == UserHistoryKind.live) t.categoryId,
    };
    final liveItems = <Map<String, dynamic>>[];
    if (topLiveCats.isNotEmpty) {
      for (final ch in data.channels) {
        if (!topLiveCats.contains(ch.categoryId.toString())) continue;
        if (_isLiveHidden(data, ch)) continue;
        liveItems.add({'id': ch.id, 'cat': ch.categoryId, 'hidden': false});
        if (liveItems.length >= _kMaxLiveCandidates) break;
      }
    }
    return AiRecommendIsolateInput(
      count: count,
      seedSalt: seedSalt,
      profileEmpty: profile.isEmpty,
      topCategories: top,
      timeBand: profile.timeBand.index,
      totalHistoryEntries: profile.totalEntries,
      seenKeys: seenKeys,
      liveItems: liveItems,
      vodItems: [
        for (final v in data.vod)
          {
            'id': v.id,
            'cat': v.categoryId,
            'rating': _ratingOf(v.rating),
            'hidden': _isVodHidden(data, v),
          },
      ],
      seriesItems: [
        for (final s in data.series)
          {
            'id': s.id,
            'cat': s.categoryId,
            'added': s.addedUnix ?? 0,
            'hidden': _isSeriesHidden(data, s),
          },
      ],
    );
  }

  List<AiRecommendation> _hydrateRecommendations(
    M3uResult data,
    List<Map<String, dynamic>> raw,
  ) {
    final liveById = {for (final c in data.channels) c.id: c};
    final vodById = {for (final v in data.vod) v.id: v};
    final seriesById = {for (final s in data.series) s.id: s};
    final liveCats = {for (final c in data.channelCategories) c.id: c.name};
    final vodCats = {for (final c in data.vodCategories) c.id: c.name};
    final seriesCats = {for (final c in data.seriesCategories) c.id: c.name};

    final out = <AiRecommendation>[];
    for (final m in raw) {
      final kind = UserHistoryKind.values[m['k'] as int];
      final id = m['id'] as int;
      final score = (m['s'] as num).toDouble();
      switch (kind) {
        case UserHistoryKind.live:
          final ch = liveById[id];
          if (ch == null) continue;
          out.add(AiRecommendation(
            kind: kind,
            id: id,
            name: ch.name,
            categoryId: ch.categoryId.toString(),
            categoryName: liveCats[ch.categoryId],
            posterUrl: ch.logoUrl,
            channel: ch,
            score: score,
          ));
        case UserHistoryKind.vod:
          final v = vodById[id];
          if (v == null) continue;
          out.add(AiRecommendation(
            kind: kind,
            id: id,
            name: v.name,
            categoryId: v.categoryId.toString(),
            categoryName: vodCats[v.categoryId],
            posterUrl: v.posterUrl,
            vod: v,
            score: score,
          ));
        case UserHistoryKind.series:
          final s = seriesById[id];
          if (s == null) continue;
          out.add(AiRecommendation(
            kind: kind,
            id: id,
            name: s.name,
            categoryId: s.categoryId.toString(),
            categoryName: seriesCats[s.categoryId],
            posterUrl: s.posterUrl,
            series: s,
            score: score,
          ));
      }
    }
    return out;
  }

  /// Profil boşken «soft cold-start» — kataloğun başından + rastgele bir
  /// kesişimden 10 örnek çıkar. Saat dilimine göre küçük bir önyargı vardır.
  List<AiRecommendation> _coldStart(
    M3uResult data, {
    required int count,
    int? seedSalt,
  }) {
    final list = <AiRecommendation>[];
    final salt = seedSalt ?? _dailySalt();
    final rand = math.Random(salt);

    // ~30% canlı, ~40% film, ~30% dizi (rating > 7 olanı önceler).
    final liveTarget = (count * 0.30).round();
    final vodTarget = (count * 0.40).round();
    final seriesTarget = count - liveTarget - vodTarget;

    final liveCats = {
      for (final c in data.channelCategories) c.id: c.name,
    };
    final vodCats = {
      for (final c in data.vodCategories) c.id: c.name,
    };
    final seriesCats = {
      for (final c in data.seriesCategories) c.id: c.name,
    };

    final channels = data.channels
        .where((ch) => !_isLiveHidden(data, ch))
        .toList(growable: false);
    final shuffledChannels = List<Channel>.from(channels)..shuffle(rand);
    for (final ch in shuffledChannels.take(liveTarget)) {
      list.add(AiRecommendation(
        kind: UserHistoryKind.live,
        id: ch.id,
        name: ch.name,
        categoryId: ch.categoryId.toString(),
        categoryName: liveCats[ch.categoryId],
        posterUrl: ch.logoUrl,
        channel: ch,
        score: 0.55,
      ));
    }

    final ratedVod = data.vod
        .where((v) => !_isVodHidden(data, v))
        .toList(growable: false);
    final sortedVod = List<VodItem>.from(ratedVod)
      ..sort((a, b) {
        final ar = _ratingOf(a.rating);
        final br = _ratingOf(b.rating);
        return br.compareTo(ar);
      });
    final vodPool = sortedVod.take(math.max(60, vodTarget * 6)).toList()
      ..shuffle(rand);
    for (final v in vodPool.take(vodTarget)) {
      list.add(AiRecommendation(
        kind: UserHistoryKind.vod,
        id: v.id,
        name: v.name,
        categoryId: v.categoryId.toString(),
        categoryName: vodCats[v.categoryId],
        posterUrl: v.posterUrl,
        vod: v,
        score: 0.6,
      ));
    }

    final filteredSeries = data.series
        .where((s) => !_isSeriesHidden(data, s))
        .toList(growable: false);
    final seriesList = List<SeriesItem>.from(filteredSeries)..shuffle(rand);
    for (final s in seriesList.take(seriesTarget)) {
      list.add(AiRecommendation(
        kind: UserHistoryKind.series,
        id: s.id,
        name: s.name,
        categoryId: s.categoryId.toString(),
        categoryName: seriesCats[s.categoryId],
        posterUrl: s.posterUrl,
        series: s,
        score: 0.55,
      ));
    }

    list.shuffle(math.Random(salt + 1));
    return list.take(count).toList(growable: false);
  }

  // ---------------- Skorlayıcılar ----------------

  Iterable<AiRecommendation> _scoreChannels(
    M3uResult data,
    AiProfile profile,
    Set<String> seenIds,
  ) sync* {
    if (data.channels.isEmpty) return;
    final catNames = {
      for (final c in data.channelCategories) c.id: c.name,
    };
    final liveCatScores = <String, double>{};
    double maxScore = 0;
    for (final t in profile.topCategories) {
      if (t.kind == UserHistoryKind.live) {
        liveCatScores[t.categoryId] = t.score;
        if (t.score > maxScore) maxScore = t.score;
      }
    }
    if (maxScore <= 0) maxScore = 1.0;

    final scored = <AiRecommendation>[];
    for (final ch in data.channels) {
      if (_isLiveHidden(data, ch)) continue;
      final catId = ch.categoryId.toString();
      final base = liveCatScores[catId] ?? 0.0;
      if (base <= 0) continue;
      final seenPenalty =
          seenIds.contains('${UserHistoryKind.live.index}|${ch.id}')
              ? 0.6
              : 1.0;
      final score = (base / maxScore) * seenPenalty;
      scored.add(AiRecommendation(
        kind: UserHistoryKind.live,
        id: ch.id,
        name: ch.name,
        categoryId: catId,
        categoryName: catNames[ch.categoryId],
        posterUrl: ch.logoUrl,
        channel: ch,
        score: 0.55 + 0.45 * score.clamp(0, 1),
      ));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    yield* scored;
  }

  Iterable<AiRecommendation> _scoreVod(
    M3uResult data,
    AiProfile profile,
    Set<String> seenIds,
  ) sync* {
    if (data.vod.isEmpty) return;
    final catNames = {
      for (final c in data.vodCategories) c.id: c.name,
    };
    final vodCatScores = <String, double>{};
    double maxScore = 0;
    for (final t in profile.topCategories) {
      if (t.kind == UserHistoryKind.vod) {
        vodCatScores[t.categoryId] = t.score;
        if (t.score > maxScore) maxScore = t.score;
      }
    }
    if (maxScore <= 0) maxScore = 1.0;
    final hasVodProfile = vodCatScores.isNotEmpty;

    final scored = <AiRecommendation>[];
    for (final v in data.vod) {
      if (_isVodHidden(data, v)) continue;
      final catId = v.categoryId.toString();
      double base = vodCatScores[catId] ?? 0.0;

      // VOD profili yoksa kategorik ortalama yerine puana bak (>7 ödüllü).
      double categoryScore = hasVodProfile ? (base / maxScore) : 0.0;
      final r = _ratingOf(v.rating);
      // 7-10 arası lineer (0..1).
      final ratingScore = r <= 0 ? 0.0 : ((r - 5.0) / 5.0).clamp(0.0, 1.0);

      if (!hasVodProfile && ratingScore < 0.4) continue;
      if (hasVodProfile && base <= 0 && ratingScore < 0.6) continue;

      final seenPenalty =
          seenIds.contains('${UserHistoryKind.vod.index}|${v.id}')
              ? 0.55
              : 1.0;
      final score = (categoryScore * 0.7 + ratingScore * 0.3) * seenPenalty;
      scored.add(AiRecommendation(
        kind: UserHistoryKind.vod,
        id: v.id,
        name: v.name,
        categoryId: catId,
        categoryName: catNames[v.categoryId],
        posterUrl: v.posterUrl,
        vod: v,
        score: 0.6 + 0.4 * score.clamp(0, 1),
      ));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    yield* scored;
  }

  Iterable<AiRecommendation> _scoreSeries(
    M3uResult data,
    AiProfile profile,
    Set<String> seenIds,
  ) sync* {
    if (data.series.isEmpty) return;
    final catNames = {
      for (final c in data.seriesCategories) c.id: c.name,
    };
    final seriesCatScores = <String, double>{};
    double maxScore = 0;
    for (final t in profile.topCategories) {
      if (t.kind == UserHistoryKind.series) {
        seriesCatScores[t.categoryId] = t.score;
        if (t.score > maxScore) maxScore = t.score;
      }
    }
    if (maxScore <= 0) maxScore = 1.0;
    final hasSeriesProfile = seriesCatScores.isNotEmpty;

    final scored = <AiRecommendation>[];
    for (final s in data.series) {
      if (_isSeriesHidden(data, s)) continue;
      final catId = s.categoryId.toString();
      double base = seriesCatScores[catId] ?? 0.0;
      double categoryScore =
          hasSeriesProfile ? (base / maxScore) : 0.0;

      // Yeni eklenenlere küçük bir bonus (son 90 gün).
      final freshness = _freshnessScore(s.addedUnix);

      if (!hasSeriesProfile && freshness < 0.15) continue;
      if (hasSeriesProfile && base <= 0 && freshness < 0.4) continue;

      final seenPenalty =
          seenIds.contains('${UserHistoryKind.series.index}|${s.id}')
              ? 0.55
              : 1.0;
      final score =
          (categoryScore * 0.7 + freshness * 0.3) * seenPenalty;
      scored.add(AiRecommendation(
        kind: UserHistoryKind.series,
        id: s.id,
        name: s.name,
        categoryId: catId,
        categoryName: catNames[s.categoryId],
        posterUrl: s.posterUrl,
        series: s,
        score: 0.55 + 0.45 * score.clamp(0, 1),
      ));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    yield* scored;
  }

  // ---------------- Yardımcılar ----------------

  /// IMDB / rating string'inden 0-10 arası double çıkarır.
  static double _ratingOf(String? raw) {
    if (raw == null) return 0;
    final cleaned = raw.replaceAll(',', '.').trim();
    final v = double.tryParse(cleaned);
    if (v == null) return 0;
    if (v.isNaN || v.isInfinite) return 0;
    if (v > 10) return v / 10.0;
    return v;
  }

  /// Son 90 günde eklenmiş içerikler için 0..1 skoru.
  static double _freshnessScore(int? unixSecs) {
    if (unixSecs == null || unixSecs <= 0) return 0;
    final added = DateTime.fromMillisecondsSinceEpoch(unixSecs * 1000);
    final ageDays = DateTime.now().difference(added).inDays;
    if (ageDays < 0) return 0;
    if (ageDays > 90) return 0;
    return 1 - (ageDays / 90.0);
  }

  /// Gün başına stabil rastgelelik sağlayan tuz.
  int _dailySalt({DateTime? now}) {
    final d = (now ?? DateTime.now()).toLocal();
    return d.year * 10000 + d.month * 100 + d.day;
  }
}
