import 'dart:async';

import 'package:get/get.dart';

import 'watch_progress_service.dart';

class PlaybackProgressWriteTask {
  const PlaybackProgressWriteTask.save({
    required this.vodId,
    required this.title,
    required this.coverUrl,
    required this.positionMs,
    required this.durationMs,
    this.seriesId,
    this.seriesTitle,
    this.seriesCoverUrl,
  }) : clearOnly = false;

  const PlaybackProgressWriteTask.clear({
    required this.vodId,
    this.seriesId,
  })  : clearOnly = true,
        title = null,
        coverUrl = null,
        positionMs = 0,
        durationMs = 0,
        seriesTitle = null,
        seriesCoverUrl = null;

  final int vodId;
  final bool clearOnly;
  final String? title;
  final String? coverUrl;
  final int positionMs;
  final int durationMs;

  /// Bölüm bir diziye aitse, dizi seviyesinde de ilerleme kaydedilir.
  final int? seriesId;
  final String? seriesTitle;
  final String? seriesCoverUrl;
}

/// Watch progress yazımlarını tek kuyruğa toplar.
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
    int? seriesId,
    String? seriesTitle,
    String? seriesCoverUrl,
    bool flushNow = false,
  }) {
    _pendingByVodId[vodId] = PlaybackProgressWriteTask.save(
      vodId: vodId,
      title: title,
      coverUrl: coverUrl,
      positionMs: positionMs,
      durationMs: durationMs,
      seriesId: seriesId,
      seriesTitle: seriesTitle,
      seriesCoverUrl: seriesCoverUrl,
    );
    if (flushNow) {
      return flushPendingAndWait();
    } else {
      _scheduleFlush();
    }
    return Future<void>.value();
  }

  Future<void> clearVodProgress(
    int vodId, {
    int? seriesId,
    bool flushNow = false,
  }) {
    _pendingByVodId[vodId] = PlaybackProgressWriteTask.clear(
      vodId: vodId,
      seriesId: seriesId,
    );
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
    final tasks = _pendingByVodId.values.toList(growable: false);
    _pendingByVodId.clear();

    for (final task in tasks) {
      if (task.clearOnly) {
        await watch.clear(task.vodId, flushDisk: false);
        if (task.seriesId != null) {
          await watch.clearSeries(task.seriesId!, flushDisk: false);
        }
        continue;
      }
      await watch.saveProgress(
        task.vodId,
        task.positionMs,
        task.durationMs,
        title: task.title,
        coverUrl: task.coverUrl,
      );
      if (task.seriesId != null) {
        await watch.saveSeriesProgress(
          seriesId: task.seriesId!,
          title: task.seriesTitle ?? task.title ?? '',
          coverUrl: task.seriesCoverUrl ?? task.coverUrl,
          positionMs: task.positionMs,
          durationMs: task.durationMs,
        );
      }
    }
    await watch.flushPendingDisk();
    completer.complete();
    _activeFlush = null;
  }

  @override
  void onClose() {
    unawaited(flushPendingAndWait());
    super.onClose();
  }
}
