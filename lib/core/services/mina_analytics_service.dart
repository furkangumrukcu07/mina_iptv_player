import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Mina Wrapped — İzleme Analitiği veri katmanı.**
///
/// Player'dan oynatma sırasında periyodik olarak [recordTick] çağrılır;
/// servis bu tick'leri **bellekte biriktirir**, [_flushDebounceMs] ms
/// sonra tek bir asenkron SharedPreferences yazımıyla diske kalıcılaştırır.
/// Debounce + tek JSON write sayesinde TV box gibi düşük güçlü cihazlar
/// dahi etkilenmez.
///
/// Veri modeli (JSON):
///
/// ```json
/// {
///   "schema": 1,
///   "perDay": {
///     "2026-05-29": {
///       "live": 120,     // dakika
///       "movie": 45,
///       "series": 30,
///       "hour": [0,0,0,2,5,10,12,8, ...]   // 24 hane, o gün için saat bazlı dk
///     }
///   },
///   "channels": { "BeIN Sports|http://logo.png": 240, ... },
///   "categories": { "Spor": 90, "Aksiyon": 30, ... }
/// }
/// ```
///
/// **Gizlilik:** Tüm veri yerel; bulut sync yok.
class MinaAnalyticsService extends GetxService {
  static const _kKey = 'mina_analytics_v1';

  /// **Master switch anahtarı.** `AppSettingsService.setMinaWrappedEnabled`
  /// ile birebir aynı SharedPreferences anahtarını paylaşır → kullanıcı
  /// ister Ayarlar > Ana Ekran, ister kurulum sihirbazı, ister sayfa içi
  /// gizlilik kartından kapatsın, tek noktadan kontrol edilir.
  static const _kEnabledKey = 'mina_settings_mina_wrapped_enabled';
  static const _flushDebounceMs = 5000;

  /// "perDay" / "channels" / "categories" haritaları için ortak in-memory
  /// snapshot. İlk [_load] sonrası dolu; tick'lerle güncellenir, debounce
  /// ile diske yazılır.
  _AnalyticsBlob _blob = _AnalyticsBlob.empty();

  Timer? _flushTimer;
  bool _dirty = false;
  bool _loaded = false;
  Completer<void>? _loading;

  /// Kullanıcı kapatabilir → ayarlar > gizlilik. **Varsayılan kapalı** —
  /// kullanıcı Ana Ekran Ayarları'ndan veya Kurulum Sihirbazı'ndan
  /// bilinçli olarak açana kadar tick toplama devre dışı.
  bool _enabled = false;
  bool get enabled => _enabled;

  /// Dış tetik (UI tab değişimi vb.) için reaktif sürüm sayacı —
  /// her flush + disk yazımında artar.
  final RxInt version = 0.obs;

  Future<MinaAnalyticsService> init() async {
    await _load();
    return this;
  }

  Future<void> _load() async {
    if (_loaded) return;
    if (_loading != null) {
      return _loading!.future;
    }
    _loading = Completer<void>();
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabledKey) ?? false;
      final raw = prefs.getString(_kKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final map = jsonDecode(raw);
          if (map is Map<String, dynamic>) {
            _blob = _AnalyticsBlob.fromJson(map);
          }
        } catch (e) {
          debugPrint('mina_iptv: analytics decode error: $e');
        }
      }
      _loaded = true;
      version.value = version.value + 1;
    } catch (e) {
      debugPrint('mina_iptv: analytics load error: $e');
      _loaded = true;
    } finally {
      _loading?.complete();
      _loading = null;
    }
  }

  Future<void> setEnabled(bool v) async {
    _enabled = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, v);
    } catch (e) {
      debugPrint('mina_iptv: analytics setEnabled error: $e');
    }
  }

  /// Player'dan periyodik çağrı. [tick] = bu çağrı kaç saniyelik izleme
  /// kapsıyor (player_controller'da 30 sn).
  void recordTick({
    required MinaMediaKind kind,
    String channelName = '',
    String channelLogo = '',
    String category = '',
    Duration tick = const Duration(seconds: 30),
  }) {
    if (!_enabled) return;
    if (!_loaded) {
      // İlk yüklemeyi beklemeden tick atılırsa kuyruğa al.
      unawaited(_load().then((_) => recordTick(
            kind: kind,
            channelName: channelName,
            channelLogo: channelLogo,
            category: category,
            tick: tick,
          )));
      return;
    }
    final now = DateTime.now();
    final dayKey = _dayKey(now);
    final hour = now.hour.clamp(0, 23);
    final minutes = (tick.inSeconds / 60.0);

    final bucket = _blob.perDay[dayKey] ??= _DayBucket.empty();
    switch (kind) {
      case MinaMediaKind.live:
        bucket.live += minutes;
      case MinaMediaKind.movie:
        bucket.movie += minutes;
      case MinaMediaKind.series:
        bucket.series += minutes;
    }
    bucket.hour[hour] += minutes;

    if (channelName.trim().isNotEmpty) {
      final key = '${channelName.trim()}|${channelLogo.trim()}';
      _blob.channels[key] = (_blob.channels[key] ?? 0) + minutes;
    }
    final cat = category.trim();
    if (cat.isNotEmpty) {
      _blob.categories[cat] = (_blob.categories[cat] ?? 0) + minutes;
    }

    _dirty = true;
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(
      const Duration(milliseconds: _flushDebounceMs),
      _flush,
    );
  }

  Future<void> _flush() async {
    if (!_dirty) return;
    _dirty = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      // 90 günden eski day bucket'ları temizle — disk maliyeti sabit kalır.
      _pruneOldDays(daysToKeep: 90);
      // Channels / categories listeleri 200'den uzunsa kuyruğun en
      // küçüklerinden 50'sini at — uzun vadede şişmesin.
      _capCounters(_blob.channels, max: 200);
      _capCounters(_blob.categories, max: 100);
      final raw = jsonEncode(_blob.toJson());
      await prefs.setString(_kKey, raw);
      version.value = version.value + 1;
    } catch (e) {
      debugPrint('mina_iptv: analytics flush error: $e');
    }
  }

  Future<void> flushNow() async => _flush();

  /// Tüm verileri sıfırlar.
  Future<void> clearAll() async {
    _blob = _AnalyticsBlob.empty();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kKey);
      version.value = version.value + 1;
    } catch (e) {
      debugPrint('mina_iptv: analytics clear error: $e');
    }
  }

  /// Belirli zaman aralığı için özet üretir.
  MinaAnalyticsSnapshot snapshot(MinaAnalyticsRange range) {
    final now = DateTime.now();
    final since = _rangeStart(now, range);
    double live = 0, movie = 0, series = 0;
    final hourTotals = List<double>.filled(24, 0);
    final weekdayTotals = List<double>.filled(7, 0); // 0=Pazartesi
    final daySeries = <_DayPoint>[];

    _blob.perDay.forEach((dayKey, bucket) {
      final d = _parseDay(dayKey);
      if (d == null) return;
      if (d.isBefore(since)) return;
      live += bucket.live;
      movie += bucket.movie;
      series += bucket.series;
      for (var i = 0; i < 24; i++) {
        hourTotals[i] += bucket.hour[i];
      }
      // weekday: Dart `DateTime.weekday` 1=Mon..7=Sun → 0..6 dönüştür
      final w = (d.weekday - 1).clamp(0, 6);
      final total = bucket.live + bucket.movie + bucket.series;
      weekdayTotals[w] += total;
      daySeries.add(_DayPoint(d, total));
    });

    daySeries.sort((a, b) => a.day.compareTo(b.day));

    // Top kanallar (range bağımsız tutuyoruz — kullanıcı için "tüm zamanlar
    // favorisi" daha anlamlı; range yalnızca toplam saatleri etkiliyor).
    final topChannels = _blob.channels.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = topChannels.take(3).map((e) {
      final parts = e.key.split('|');
      return MinaTopChannel(
        name: parts.isNotEmpty ? parts[0] : e.key,
        logo: parts.length > 1 ? parts[1] : '',
        minutes: e.value,
      );
    }).toList();

    final topCategories = _blob.categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCats = topCategories.take(3).map((e) =>
        MinaTopCategory(name: e.key, minutes: e.value)).toList();

    final peakHour = _argMax(hourTotals);
    final peakWeekday = _argMax(weekdayTotals);

    return MinaAnalyticsSnapshot(
      range: range,
      since: since,
      until: now,
      liveMinutes: live,
      movieMinutes: movie,
      seriesMinutes: series,
      hourTotals: hourTotals,
      weekdayTotals: weekdayTotals,
      daySeries: daySeries
          .map((p) => MinaDayPoint(p.day, p.minutes))
          .toList(growable: false),
      topChannels: top3,
      topCategories: topCats,
      peakHour: peakHour,
      peakWeekday: peakWeekday,
    );
  }

  void _pruneOldDays({required int daysToKeep}) {
    final cutoff = DateTime.now().subtract(Duration(days: daysToKeep));
    _blob.perDay.removeWhere((k, _) {
      final d = _parseDay(k);
      return d == null || d.isBefore(cutoff);
    });
  }

  void _capCounters(Map<String, double> map, {required int max}) {
    if (map.length <= max) return;
    final entries = map.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final toRemove = entries.take(map.length - max).map((e) => e.key);
    for (final k in toRemove) {
      map.remove(k);
    }
  }

  static String _dayKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  static DateTime? _parseDay(String s) {
    if (s.length != 10) return null;
    return DateTime.tryParse(s);
  }

  static DateTime _rangeStart(DateTime now, MinaAnalyticsRange r) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (r) {
      MinaAnalyticsRange.week => today.subtract(const Duration(days: 6)),
      MinaAnalyticsRange.month => today.subtract(const Duration(days: 29)),
      MinaAnalyticsRange.year => today.subtract(const Duration(days: 364)),
    };
  }

  static int _argMax(List<double> v) {
    var idx = 0;
    var best = -1.0;
    for (var i = 0; i < v.length; i++) {
      if (v[i] > best) {
        best = v[i];
        idx = i;
      }
    }
    return idx;
  }
}

// =============================================================================
// Veri modelleri.
// =============================================================================

enum MinaMediaKind { live, movie, series }

enum MinaAnalyticsRange { week, month, year }

/// Üst seviye snapshot — UI'a verilen anlık görünüm.
class MinaAnalyticsSnapshot {
  const MinaAnalyticsSnapshot({
    required this.range,
    required this.since,
    required this.until,
    required this.liveMinutes,
    required this.movieMinutes,
    required this.seriesMinutes,
    required this.hourTotals,
    required this.weekdayTotals,
    required this.daySeries,
    required this.topChannels,
    required this.topCategories,
    required this.peakHour,
    required this.peakWeekday,
  });

  static const empty = MinaAnalyticsSnapshot(
    range: MinaAnalyticsRange.month,
    since: null,
    until: null,
    liveMinutes: 0,
    movieMinutes: 0,
    seriesMinutes: 0,
    hourTotals: <double>[],
    weekdayTotals: <double>[],
    daySeries: <MinaDayPoint>[],
    topChannels: <MinaTopChannel>[],
    topCategories: <MinaTopCategory>[],
    peakHour: 0,
    peakWeekday: 0,
  );

  final MinaAnalyticsRange range;
  final DateTime? since;
  final DateTime? until;
  final double liveMinutes;
  final double movieMinutes;
  final double seriesMinutes;
  final List<double> hourTotals;
  final List<double> weekdayTotals;
  final List<MinaDayPoint> daySeries;
  final List<MinaTopChannel> topChannels;
  final List<MinaTopCategory> topCategories;

  /// 0..23 — en çok izlenen saat dilimi.
  final int peakHour;

  /// 0..6 (Pzt..Pzr).
  final int peakWeekday;

  double get totalMinutes => liveMinutes + movieMinutes + seriesMinutes;

  bool get isEmpty => totalMinutes < 1;
}

class MinaDayPoint {
  const MinaDayPoint(this.day, this.minutes);
  final DateTime day;
  final double minutes;
}

class MinaTopChannel {
  const MinaTopChannel({
    required this.name,
    required this.logo,
    required this.minutes,
  });
  final String name;
  final String logo;
  final double minutes;
}

class MinaTopCategory {
  const MinaTopCategory({required this.name, required this.minutes});
  final String name;
  final double minutes;
}

// =============================================================================
// Disk modeli (private).
// =============================================================================

class _DayBucket {
  _DayBucket({
    required this.live,
    required this.movie,
    required this.series,
    required this.hour,
  });

  factory _DayBucket.empty() => _DayBucket(
        live: 0,
        movie: 0,
        series: 0,
        hour: List<double>.filled(24, 0),
      );

  double live;
  double movie;
  double series;
  final List<double> hour; // 24

  Map<String, dynamic> toJson() => {
        'l': live,
        'm': movie,
        's': series,
        'h': hour,
      };

  static _DayBucket fromJson(Map<String, dynamic> j) {
    final hRaw = j['h'];
    final hour = List<double>.filled(24, 0);
    if (hRaw is List) {
      for (var i = 0; i < 24 && i < hRaw.length; i++) {
        final v = hRaw[i];
        if (v is num) hour[i] = v.toDouble();
      }
    }
    return _DayBucket(
      live: (j['l'] as num?)?.toDouble() ?? 0,
      movie: (j['m'] as num?)?.toDouble() ?? 0,
      series: (j['s'] as num?)?.toDouble() ?? 0,
      hour: hour,
    );
  }
}

class _AnalyticsBlob {
  _AnalyticsBlob({
    required this.perDay,
    required this.channels,
    required this.categories,
  });

  factory _AnalyticsBlob.empty() => _AnalyticsBlob(
        perDay: <String, _DayBucket>{},
        channels: <String, double>{},
        categories: <String, double>{},
      );

  final Map<String, _DayBucket> perDay;
  final Map<String, double> channels;
  final Map<String, double> categories;

  Map<String, dynamic> toJson() => {
        'schema': 1,
        'perDay': perDay.map((k, v) => MapEntry(k, v.toJson())),
        'channels': channels,
        'categories': categories,
      };

  static _AnalyticsBlob fromJson(Map<String, dynamic> j) {
    final perDay = <String, _DayBucket>{};
    final rawPerDay = j['perDay'];
    if (rawPerDay is Map) {
      rawPerDay.forEach((k, v) {
        if (k is String && v is Map) {
          perDay[k] = _DayBucket.fromJson(v.cast<String, dynamic>());
        }
      });
    }
    final channels = <String, double>{};
    final rawCh = j['channels'];
    if (rawCh is Map) {
      rawCh.forEach((k, v) {
        if (k is String && v is num) channels[k] = v.toDouble();
      });
    }
    final categories = <String, double>{};
    final rawCat = j['categories'];
    if (rawCat is Map) {
      rawCat.forEach((k, v) {
        if (k is String && v is num) categories[k] = v.toDouble();
      });
    }
    return _AnalyticsBlob(
      perDay: perDay,
      channels: channels,
      categories: categories,
    );
  }
}

class _DayPoint {
  const _DayPoint(this.day, this.minutes);
  final DateTime day;
  final double minutes;
}
