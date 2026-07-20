import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/services/app_settings_service.dart';
import '../core/services/cloud_restore_preview.dart';

enum CloudRestoreStage { downloading, preview, applying, done, error }

@immutable
class CloudRestoreProgress {
  const CloudRestoreProgress.downloading()
      : stage = CloudRestoreStage.downloading,
        preview = null,
        errorMessage = '';

  const CloudRestoreProgress.preview(this.preview)
      : stage = CloudRestoreStage.preview,
        errorMessage = '';

  const CloudRestoreProgress.applying(this.preview)
      : stage = CloudRestoreStage.applying,
        errorMessage = '';

  const CloudRestoreProgress.done(this.preview)
      : stage = CloudRestoreStage.done,
        errorMessage = '';

  const CloudRestoreProgress.error(this.errorMessage)
      : stage = CloudRestoreStage.error,
        preview = null;

  final CloudRestoreStage stage;
  final CloudRestorePreview? preview;
  final String errorMessage;

  bool get isDone => stage == CloudRestoreStage.done;
  bool get isError => stage == CloudRestoreStage.error;
}

/// Google oturumu sonrası bulut yedeği indirilirken / uygulanırken gösterilen
/// cam özet popup'ı. Tamamlanınca otomatik kapanır.
class CloudRestoreProgressDialog extends StatefulWidget {
  const CloudRestoreProgressDialog({super.key, required this.progress});

  final ValueListenable<CloudRestoreProgress> progress;

  static Future<void> show(
    BuildContext context, {
    required ValueNotifier<CloudRestoreProgress> progress,
  }) {
    return Get.dialog<void>(
      CloudRestoreProgressDialog(progress: progress),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
    );
  }

  @override
  State<CloudRestoreProgressDialog> createState() =>
      _CloudRestoreProgressDialogState();
}

class _CloudRestoreProgressDialogState extends State<CloudRestoreProgressDialog> {
  int _animatedRows = 0;
  Timer? _stageTimer;
  Timer? _autoCloseTimer;
  bool _animationStarted = false;

  static const Duration _rowDelay = Duration(milliseconds: 480);
  static const int _autoCloseSeconds = 3;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgress);
    _onProgress();
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgress);
    _stageTimer?.cancel();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _onProgress() {
    final p = widget.progress.value;
    if ((p.stage == CloudRestoreStage.preview ||
            p.stage == CloudRestoreStage.applying ||
            p.stage == CloudRestoreStage.done) &&
        !_animationStarted) {
      _animationStarted = true;
      _scheduleRow(1);
    }
    if (p.isDone || p.isError) {
      _scheduleAutoClose();
    }
  }

  void _scheduleRow(int target) {
    _stageTimer?.cancel();
    if (!mounted) return;
    if (_animatedRows >= target) {
      if (target < _visibleRowCount(widget.progress.value.preview)) {
        _stageTimer = Timer(_rowDelay, () => _scheduleRow(target + 1));
      }
      return;
    }
    setState(() => _animatedRows = target);
    _stageTimer = Timer(_rowDelay, () => _scheduleRow(target + 1));
  }

  int _visibleRowCount(CloudRestorePreview? preview) {
    var n = 3; // download, playlists, settings
    if ((preview?.localM3uCount ?? 0) > 0) n++;
    if ((preview?.profileCount ?? 0) > 0) n++;
    n++; // apply row
    return n;
  }

  void _scheduleAutoClose() {
    if (_autoCloseTimer != null) return;
    _autoCloseTimer = Timer(const Duration(seconds: _autoCloseSeconds), () {
      if (mounted) {
        Get.back<void>();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final primary = Theme.of(context).colorScheme.primary;
    final reduce = settings.reduceBlur.value;
    final sigma = reduce ? 10.0 : 20.0;
    final mq = MediaQuery.of(context);
    final portrait = mq.orientation == Orientation.portrait;
    final insetH = portrait ? 22.0 : 14.0;
    final insetW = portrait ? 20.0 : 18.0;
    final maxW = math.min(420.0, mq.size.width - insetW * 2);

    return ValueListenableBuilder<CloudRestoreProgress>(
      valueListenable: widget.progress,
      builder: (context, progress, _) {
        final preview = progress.preview;
        final isError = progress.isError;
        final isDone = progress.isDone;
        final canPop = isDone || isError;

        return PopScope(
          canPop: canPop,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: insetW,
              vertical: insetH,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.2,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.88),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.24),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        portrait ? 22 : 20,
                        portrait ? 22 : 18,
                        portrait ? 22 : 20,
                        portrait ? 18 : 16,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(primary, portrait, progress),
                          SizedBox(height: portrait ? 16 : 12),
                          if (isError)
                            _errorBody(progress.errorMessage)
                          else ...[
                            _RestoreRow(
                              icon: Icons.cloud_download_rounded,
                              label: 'cloud.restore.progress.row.download'.tr,
                              done: _animatedRows >= 1,
                              accent: const Color(0xFF42A5F5),
                              busy: progress.stage ==
                                  CloudRestoreStage.downloading,
                            ),
                            const SizedBox(height: 10),
                            _RestoreRow(
                              icon: Icons.playlist_play_rounded,
                              label: 'cloud.restore.progress.row.playlists'
                                  .trParams({
                                'n': '${preview?.playlistCount ?? 0}',
                              }),
                              done: _animatedRows >= 2,
                              accent: const Color(0xFF6EC8FF),
                              busy: progress.stage ==
                                      CloudRestoreStage.downloading &&
                                  _animatedRows < 2,
                            ),
                            const SizedBox(height: 10),
                            _RestoreRow(
                              icon: Icons.tune_rounded,
                              label: 'cloud.restore.progress.row.settings'
                                  .trParams({
                                'n': '${preview?.settingsCount ?? 0}',
                              }),
                              done: _animatedRows >= 3,
                              accent: const Color(0xFFB089FF),
                              busy: false,
                            ),
                            if ((preview?.localM3uCount ?? 0) > 0) ...[
                              const SizedBox(height: 10),
                              _RestoreRow(
                                icon: Icons.description_rounded,
                                label:
                                    'cloud.restore.progress.row.localM3u'.trParams(
                                  {'n': '${preview!.localM3uCount}'},
                                ),
                                done: _animatedRows >= 4,
                                accent: const Color(0xFFFFC773),
                                busy: false,
                              ),
                            ],
                            if ((preview?.profileCount ?? 0) > 0) ...[
                              const SizedBox(height: 10),
                              _RestoreRow(
                                icon: Icons.people_rounded,
                                label:
                                    'cloud.restore.progress.row.profiles'.trParams(
                                  {'n': '${preview!.profileCount}'},
                                ),
                                done: _animatedRows >=
                                    ((preview.localM3uCount > 0) ? 5 : 4),
                                accent: const Color(0xFF81C784),
                                busy: false,
                              ),
                            ],
                            const SizedBox(height: 10),
                            _RestoreRow(
                              icon: Icons.phone_android_rounded,
                              label: 'cloud.restore.progress.row.apply'.tr,
                              done: isDone,
                              accent: primary,
                              busy: progress.stage ==
                                  CloudRestoreStage.applying,
                            ),
                          ],
                          if (isDone) ...[
                            const SizedBox(height: 14),
                            Text(
                              'cloud.restore.progress.autoClose'.trParams(
                                {'n': '$_autoCloseSeconds'},
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(Color primary, bool portrait, CloudRestoreProgress progress) {
    final isError = progress.isError;
    final isDone = progress.isDone;
    final accent = isError ? const Color(0xFFFF6B6B) : primary;
    return Row(
      children: [
        Container(
          width: portrait ? 48 : 44,
          height: portrait ? 48 : 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.18),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Icon(
            isError
                ? Icons.error_outline_rounded
                : (isDone
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_sync_rounded),
            color: accent,
            size: portrait ? 26 : 24,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isError
                    ? 'common.error'.tr
                    : (isDone
                        ? 'cloud.restore.progress.titleDone'.tr
                        : 'cloud.restore.progress.title'.tr),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: portrait ? 18 : 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isError
                    ? progress.errorMessage
                    : 'cloud.restore.progress.subtitle'.tr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: portrait ? 13 : 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorBody(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.red.withValues(alpha: 0.12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
      ),
    );
  }
}

class _RestoreRow extends StatelessWidget {
  const _RestoreRow({
    required this.icon,
    required this.label,
    required this.done,
    required this.accent,
    required this.busy,
  });

  final IconData icon;
  final String label;
  final bool done;
  final Color accent;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done
              ? accent.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.16),
        ),
        gradient: LinearGradient(
          colors: done
              ? [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.06),
                ]
              : [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.02),
                ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: done
                  ? accent.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.08),
            ),
            child: Icon(icon, size: 20, color: done ? accent : Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (busy)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: accent,
              ),
            )
          else if (done)
            Icon(Icons.check_circle_rounded, color: accent, size: 22)
          else
            Icon(
              Icons.more_horiz_rounded,
              color: Colors.white.withValues(alpha: 0.35),
              size: 22,
            ),
        ],
      ),
    );
  }
}
