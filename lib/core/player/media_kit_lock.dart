import 'dart:async';

/// Global mutex lock to prevent concurrent mpv_render_context_create and
/// mpv_render_context_free calls in libmpv / media_kit across all threads.
abstract class MinaMediaKitLock {
  static Future<void> _lock = Future.value();

  static Future<T> synchronized<T>(Future<T> Function() action) async {
    final prev = _lock;
    final completer = Completer<void>();
    _lock = completer.future;
    try {
      await prev;
    } catch (_) {}
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }
}
