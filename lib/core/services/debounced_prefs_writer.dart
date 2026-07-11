import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences yazımlarını birleştirir (debounce).
///
/// Android legacy plugin her `setInt`/`setString` için senkron `commit()`
/// yapar; hızlı zap / ilerleme kaydı sırasında bu ANR üretebilir.
/// Bellek güncellemesi çağıran tarafta anında kalır; disk yazımı sessizlik
/// sonrası tek turda yapılır. [flush] ile arka plana geçerken zorlanır.
class DebouncedPrefsWriter {
  DebouncedPrefsWriter({
    required this.getPrefs,
    this.delay = const Duration(milliseconds: 900),
  });

  final Future<SharedPreferences> Function() getPrefs;
  final Duration delay;

  final Map<String, Object?> _pending = <String, Object?>{};
  Timer? _timer;
  Future<void>? _inFlight;
  bool _closed = false;

  bool get hasPending => _pending.isNotEmpty || _inFlight != null;

  void scheduleInt(String key, int value) => _schedule(key, value);

  void scheduleBool(String key, bool value) => _schedule(key, value);

  void scheduleDouble(String key, double value) => _schedule(key, value);

  void scheduleString(String key, String value) => _schedule(key, value);

  void scheduleStringList(String key, List<String> value) =>
      _schedule(key, List<String>.from(value));

  void scheduleRemove(String key) => _schedule(key, null);

  void _schedule(String key, Object? value) {
    if (_closed) return;
    _pending[key] = value;
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(delay, () {
      unawaited(flush());
    });
  }

  /// Bekleyen yazımları hemen diske uygular.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;

    while (_inFlight != null) {
      await _inFlight;
    }
    if (_pending.isEmpty) return;

    final batch = Map<String, Object?>.of(_pending);
    _pending.clear();

    final done = Completer<void>();
    _inFlight = done.future;
    try {
      final p = await getPrefs();
      for (final e in batch.entries) {
        final v = e.value;
        if (v == null) {
          await p.remove(e.key);
        } else if (v is int) {
          await p.setInt(e.key, v);
        } else if (v is bool) {
          await p.setBool(e.key, v);
        } else if (v is double) {
          await p.setDouble(e.key, v);
        } else if (v is String) {
          await p.setString(e.key, v);
        } else if (v is List<String>) {
          await p.setStringList(e.key, v);
        }
      }
    } catch (e, st) {
      debugPrint('mina_iptv: DebouncedPrefsWriter flush error: $e\n$st');
    } finally {
      if (!done.isCompleted) done.complete();
      _inFlight = null;
      if (_pending.isNotEmpty && !_closed) {
        _arm();
      }
    }
  }

  Future<void> dispose() async {
    _closed = true;
    await flush();
  }
}
