import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/local/playlist_sqlite_store.dart';
import '../../domain/entities/m3u_result.dart';
import 'active_playlist_service.dart';
import 'playlist_cache_service.dart';

/// Büyük playlist'lerin SQLite'a yazımını UI kritik yolundan ayırır.
///
/// [PlaylistSqliteStore.replaceFromResult] on binlerce satırda ana isolate'i
/// uzun süre meşgul edebilir; bu servis yazımı arka planda koordine eder ve
/// tamamlandığında aktif slot hâlâ aynıysa önbelleği günceller.
class PlaylistSqliteBackfillService extends GetxService {
  final Map<String, int> _generationByKey = <String, int>{};
  final Map<String, Future<void>> _inFlightByKey = <String, Future<void>>{};

  /// [dbKey] için backfill başlatır. Zaten sürüyorsa mevcut [Future]'ı döner.
  Future<void> scheduleReplaceFromResult({
    required String dbKey,
    required M3uResult full,
    int? forSlot,
  }) {
    if (dbKey.isEmpty) return Future<void>.value();
    final existing = _inFlightByKey[dbKey];
    if (existing != null) return existing;

    final gen = (_generationByKey[dbKey] ?? 0) + 1;
    _generationByKey[dbKey] = gen;

    final job = _runReplace(dbKey: dbKey, full: full, gen: gen, forSlot: forSlot);
    _inFlightByKey[dbKey] = job;
    return job.whenComplete(() {
      if (_inFlightByKey[dbKey] == job) {
        _inFlightByKey.remove(dbKey);
      }
    });
  }

  void cancelKey(String dbKey) {
    if (dbKey.isEmpty) return;
    _generationByKey[dbKey] = (_generationByKey[dbKey] ?? 0) + 1;
    _inFlightByKey.remove(dbKey);
  }

  Future<void> _runReplace({
    required String dbKey,
    required M3uResult full,
    required int gen,
    int? forSlot,
  }) async {
    try {
      if (await PlaylistSqliteStore.hasData(dbKey)) return;
      await PlaylistSqliteStore.replaceFromResult(dbKey, full);
      if (_generationByKey[dbKey] != gen) return;
      if (!await PlaylistSqliteStore.hasData(dbKey)) return;
      await _notifyActiveSlotIfNeeded(dbKey: dbKey, forSlot: forSlot);
    } catch (e, st) {
      debugPrint('mina_iptv: SQLite backfill failed ($dbKey): $e\n$st');
    }
  }

  Future<void> _notifyActiveSlotIfNeeded({
    required String dbKey,
    required int? forSlot,
  }) async {
    if (!Get.isRegistered<ActivePlaylistService>()) return;
    if (!Get.isRegistered<PlaylistCacheService>()) return;
    final active = Get.find<ActivePlaylistService>();
    final cache = Get.find<PlaylistCacheService>();
    final slot = forSlot ?? active.activeSlot.value;
    if (active.activeSlot.value != slot) return;
    if (cache.dbSourceKey.value != dbKey) return;
    await active.onSqliteBackfillReady(slot: slot, dbKey: dbKey);
  }
}
