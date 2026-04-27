import 'dart:async';

import 'package:get/get.dart';

import 'continue_watching_service.dart';
import 'watch_progress_service.dart';

class PlaybackProgressWriteTask {
  const PlaybackProgressWriteTask.save({
    required this.vodId,
    required this.title,
    required this.coverUrl,
    required this.positionMs,
    required this.durationMs,
  }) : clearOnly = false;

  const PlaybackProgressWriteTask.clear({
    required this.vodId,
  })  : clearOnly = true,
        title = null,
        coverUrl = null,
        positionMs = 0,
        durationMs = 0;

  final int vodId;
  final bool clearOnly;
  final String? title;
  final String? coverUrl;
  final int positionMs;
  final int durationMs;
}

/// Watch progress + continue watching yazımlarını tek kuyruğa toplar.
class PlaybackProgressWriteQueueService extends GetxService {
  static const Duration _flushDebounce = Duration(milliseconds: 900);
  final Map<int, PlaybackProgressWriteTask> _pendingByVodId =
      <int, PlaybackProgressWriteTask>{};
  Timer? _flushTimer;
  Future<void>? _activeFlush;

  Future<void> saveVodProgress({
    required int vodId,
    required String title,
    required String? coverUrl,
    required int positionMs,
    required int durationMs,
    bool flushNow = false,
  }) {
    _pendingByVodId[vodId] = PlaybackProgressWriteTask.save(
      vodId: vodId,
      title: title,
      coverUrl: coverUrl,
      positionMs: positionMs,
      durationMs: durationMs,
    );
    if (flushNow) {
      return flushPendingAndWait();
    } else {
      _scheduleFlush();
    }
    return Future<void>.value();
  }

  Future<void> clearVodProgress(int vodId, {bool flushNow = false}) {
    _pendingByVodId[vodId] = PlaybackProgressWriteTask.clear(vodId: vodId);
    if (flushNow) {
      return flushPendingAndWait();
    } else {
      _scheduleFlush();
    }
    return Future<void>.value();
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(_flushDebounce, () {
      unawaited(flushPendingAndWait());
    });
  }

  Future<void> flushPendingAndWait() async {
    if (_activeFlush != null) {
      return _activeFlush!;
    }
    final completer = Completer<void>();
    _activeFlush = completer.future;
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_pendingByVodId.isEmpty) {
      completer.complete();
      _activeFlush = null;
      return;
    }

    final watch = Get.find<WatchProgressService>();
    final continueWatching = Get.isRegistered<ContinueWatchingService>()
        ? Get.find<ContinueWatchingService>()
        : null;
    final tasks = _pendingByVodId.values.toList(growable: false);
    _pendingByVodId.clear();

    for (final task in tasks) {
      if (task.clearOnly) {
        await watch.clear(task.vodId);
        continueWatching?.removeItem(task.vodId);
        continue;
      }
      await watch.saveProgress(task.vodId, task.positionMs, task.durationMs);
      continueWatching?.saveProgress(
        vodId: task.vodId,
        title: task.title ?? '',
        coverUrl: task.coverUrl,
        positionMs: task.positionMs,
        durationMs: task.durationMs,
      );
    }
    completer.complete();
    _activeFlush = null;
  }

  @override
  void onClose() {
    unawaited(flushPendingAndWait());
    super.onClose();
  }
}
