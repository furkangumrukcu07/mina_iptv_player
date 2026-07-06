import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// İzlemeye Devam Et öğesi türü.
enum ContinueWatchingKind { vod, series }

/// İzlemeye Devam Et listesindeki tek bir öğe (film veya dizi).
class ContinueWatchingEntry {
  const ContinueWatchingEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.coverUrl,
    required this.positionMs,
    required this.durationMs,
    required this.updatedMs,
  });

  /// Film için VOD `id`; dizi için dizi `id`.
  final int id;
  final ContinueWatchingKind kind;
  final String title;
  final String? coverUrl;
  final int positionMs;
  final int durationMs;
  final int updatedMs;

  /// 0.0 – 1.0 arası izlenme oranı.
  double get fraction {
    if (durationMs <= 0) return 0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'k': kind.index,
        't': title,
        'c': coverUrl,
        'p': positionMs,
        'd': durationMs,
        'u': updatedMs,
      };

  static ContinueWatchingEntry? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = (raw['id'] as num?)?.toInt();
    final ki = (raw['k'] as num?)?.toInt();
    final p = (raw['p'] as num?)?.toInt();
    final d = (raw['d'] as num?)?.toInt();
    if (id == null || ki == null || p == null || d == null) return null;
    if (ki < 0 || ki >= ContinueWatchingKind.values.length) return null;
    return ContinueWatchingEntry(
      id: id,
      kind: ContinueWatchingKind.values[ki],
      title: (raw['t'] ?? '').toString(),
      coverUrl: raw['c']?.toString(),
      positionMs: p,
      durationMs: d,
      updatedMs: (raw['u'] as num?)?.toInt() ?? 0,
    );
  }
}

/// VOD (film / dizi bölümü) izleme konumu — [Channel.id] anahtarıyla kalıcı.
///
/// Ek olarak «İzlemeye Devam Et» için zengin bir indeks tutar: başlık, poster,
/// izlenen konum/süre ve son güncelleme zamanı. Bu indeks hem ana ekran
/// şeridini hem de film/dizi posterleri altındaki izlenme yüzdesi barını
/// besler. İndeks bellekte de tutulur ([_index]) → poster barı senkron okur.
class WatchProgressService extends GetxService {
  static const _kPos = 'mina_watch_pos_';
  static const _kDur = 'mina_watch_dur_';
  static const _kIndex = 'mina_continue_watching_v2';

  /// İndekste tutulacak en fazla öğe (en yeni N).
  static const int _kMaxItems = 30;

  /// İzlemeye Devam Et listesine girecek üst izlenme eşiği — neredeyse bitmiş
  /// (> %95) içerikler listeye alınmaz.
  static const double _kMaxFraction = 0.95;

  /// Alt eşik **mutlak süre** (oran değil): kullanıcı en az 30 sn izleyip
  /// çıktıysa içerik «İzlemeye Devam Et»e ve poster barına girer. Oran tabanlı
  /// eşik uzun filmlerde (%2 ≈ 2-3 dk) içeriği gizliyordu; devam-et diyalogu da
  /// 30 sn eşiği kullandığından bununla hizalandı.
  static const int _kMinPositionMs = 30000;

  /// `vod` öğeleri: id → entry; `series` öğeleri: id → entry.
  final Map<int, ContinueWatchingEntry> _vodIndex = {};
  final Map<int, ContinueWatchingEntry> _seriesIndex = {};

  bool _loaded = false;

  /// İndeks her değiştiğinde 1 artar; `Obx` widget'ları dinler.
  final RxInt revision = 0.obs;

  @override
  void onInit() {
    super.onInit();
    ensureLoaded();
  }

  Future<int?> loadPositionMs(int streamId) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getInt('$_kPos$streamId');
    } catch (_) {
      return null;
    }
  }

  /// VOD (film veya dizi bölümü) ilerlemesini kaydeder. [title] / [coverUrl]
  /// verilirse «İzlemeye Devam Et» indeksi de güncellenir.
  Future<void> saveProgress(
    int streamId,
    int positionMs,
    int durationMs, {
    String? title,
    String? coverUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_kPos$streamId', positionMs);
      if (durationMs > 0) {
        await prefs.setInt('$_kDur$streamId', durationMs);
      }
    } catch (_) {}
    if (title != null) {
      await _upsertIndex(
        index: _vodIndex,
        kind: ContinueWatchingKind.vod,
        id: streamId,
        title: title,
        coverUrl: coverUrl,
        positionMs: positionMs,
        durationMs: durationMs,
      );
    }
  }

  /// Dizi seviyesinde ilerlemeyi kaydeder (en son izlenen bölümün konumu).
  Future<void> saveSeriesProgress({
    required int seriesId,
    required String title,
    String? coverUrl,
    required int positionMs,
    required int durationMs,
  }) async {
    await _upsertIndex(
      index: _seriesIndex,
      kind: ContinueWatchingKind.series,
      id: seriesId,
      title: title,
      coverUrl: coverUrl,
      positionMs: positionMs,
      durationMs: durationMs,
    );
  }

  Future<void> clear(int streamId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kPos$streamId');
      await prefs.remove('$_kDur$streamId');
    } catch (_) {}
    await ensureLoaded();
    if (_vodIndex.remove(streamId) != null) {
      await _persistIndex();
      revision.value++;
    }
  }

  Future<void> clearSeries(int seriesId) async {
    await ensureLoaded();
    if (_seriesIndex.remove(seriesId) != null) {
      await _persistIndex();
      revision.value++;
    }
  }

  /// Tüm İzlemeye Devam Et listesini temizler.
  Future<void> clearAll() async {
    await ensureLoaded();
    _vodIndex.clear();
    _seriesIndex.clear();
    await _persistIndex();
    revision.value++;
  }

  /// Belirli bir öğeyi listeden çıkarır (kullanıcı «kaldır» derse).
  Future<void> removeEntry(int id, ContinueWatchingKind kind) async {
    await ensureLoaded();
    final removed = kind == ContinueWatchingKind.vod
        ? _vodIndex.remove(id)
        : _seriesIndex.remove(id);
    if (removed != null) {
      await _persistIndex();
      revision.value++;
    }
  }

  /// Filmin izlenme oranı (0–1) — bellekten senkron okur. Yoksa `null`.
  double? vodFractionSync(int id) => _fractionSync(_vodIndex[id]);

  /// Dizinin izlenme oranı (0–1) — bellekten senkron okur. Yoksa `null`.
  double? seriesFractionSync(int id) => _fractionSync(_seriesIndex[id]);

  double? _fractionSync(ContinueWatchingEntry? e) {
    if (e == null || !_isInProgress(e)) return null;
    return e.fraction;
  }

  /// Bir öğe «devam ediyor» sayılır mı? En az [_kMinPositionMs] izlenmiş ve
  /// neredeyse bitmemiş (≤ %95) olmalı.
  static bool _isInProgress(ContinueWatchingEntry e) {
    if (e.durationMs <= 0) return false;
    if (e.positionMs < _kMinPositionMs) return false;
    return e.fraction <= _kMaxFraction;
  }

  /// İzlemeye Devam Et listesi — en yeni izlenenden eskiye, yarıda kalmış
  /// (≥ 30 sn izlenmiş, ≤ %95) film ve diziler.
  List<ContinueWatchingEntry> continueWatching({int max = _kMaxItems}) {
    final all = <ContinueWatchingEntry>[
      ..._vodIndex.values,
      ..._seriesIndex.values,
    ].where(_isInProgress).toList();
    all.sort((a, b) => b.updatedMs.compareTo(a.updatedMs));
    if (all.length > max) {
      return all.sublist(0, max);
    }
    return all;
  }

  /// 30 saniye alt sınırı veya yüzde üst sınırı olmaksızın en son izlenen içeriği döndürür.
  ContinueWatchingEntry? getAbsoluteLastWatched() {
    final all = <ContinueWatchingEntry>[
      ..._vodIndex.values,
      ..._seriesIndex.values,
    ];
    if (all.isEmpty) return null;
    all.sort((a, b) => b.updatedMs.compareTo(a.updatedMs));
    return all.first;
  }

  bool get hasItems => continueWatching(max: 1).isNotEmpty;

  /// Profil değişimi / bulut geri yükleme sonrası «İzlemeye Devam Et» indeksini
  /// diskten yeniden yükler.
  Future<void> reload() async {
    _loaded = false;
    _vodIndex.clear();
    _seriesIndex.clear();
    await ensureLoaded();
    revision.value++;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kIndex);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded) {
        final e = ContinueWatchingEntry.tryFromJson(item);
        if (e == null) continue;
        if (e.kind == ContinueWatchingKind.vod) {
          _vodIndex[e.id] = e;
        } else {
          _seriesIndex[e.id] = e;
        }
      }
      revision.value++;
    } catch (_) {}
  }

  Future<void> _upsertIndex({
    required Map<int, ContinueWatchingEntry> index,
    required ContinueWatchingKind kind,
    required int id,
    required String title,
    String? coverUrl,
    required int positionMs,
    required int durationMs,
  }) async {
    await ensureLoaded();
    if (durationMs <= 0) return;
    final fraction = (positionMs / durationMs).clamp(0.0, 1.0);
    // Neredeyse bitmişse listeden çıkar.
    if (fraction > _kMaxFraction) {
      if (index.remove(id) != null) {
        await _persistIndex();
        revision.value++;
      }
      return;
    }
    index[id] = ContinueWatchingEntry(
      id: id,
      kind: kind,
      title: title,
      coverUrl: coverUrl,
      positionMs: positionMs,
      durationMs: durationMs,
      updatedMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _persistIndex();
    revision.value++;
  }

  Future<void> _persistIndex() async {
    try {
      // En yeni N öğeyi koru (her iki türü zaman damgasına göre kırp).
      final combined = <ContinueWatchingEntry>[
        ..._vodIndex.values,
        ..._seriesIndex.values,
      ]..sort((a, b) => b.updatedMs.compareTo(a.updatedMs));
      if (combined.length > _kMaxItems) {
        final keep = combined.take(_kMaxItems).toSet();
        _vodIndex.removeWhere((_, e) => !keep.contains(e));
        _seriesIndex.removeWhere((_, e) => !keep.contains(e));
      }
      final list = <Map<String, dynamic>>[
        ..._vodIndex.values.map((e) => e.toJson()),
        ..._seriesIndex.values.map((e) => e.toJson()),
      ];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kIndex, jsonEncode(list));
    } catch (_) {}
  }
}
