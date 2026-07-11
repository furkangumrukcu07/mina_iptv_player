import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';
import 'auth_service.dart';
import 'cloud_playlist_restore_validator.dart';
import 'cloud_restore_preview.dart';
import '../../ui/cloud_restore_progress_dialog.dart';
import '../../ui/glass_overlays.dart';

enum CloudRestoreOutcome { success, empty, failed }

@immutable
class CloudRestoreResult {
  const CloudRestoreResult({
    required this.outcome,
    this.preview,
    this.playlistReport,
  });

  final CloudRestoreOutcome outcome;
  final CloudRestorePreview? preview;
  final CloudPlaylistRestoreReport? playlistReport;
}

/// Bulut yedeğini indirip uygularken ilerleme popup'ını yönetir.
class CloudRestoreCoordinator {
  CloudRestoreCoordinator._();

  static Future<CloudRestoreResult> restoreWithProgressDialog({
    required AuthService auth,
    Future<void> Function()? afterApply,
    bool navigateToSplashOnSuccess = true,
  }) async {
    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) {
      return const CloudRestoreResult(outcome: CloudRestoreOutcome.failed);
    }

    final progress = ValueNotifier(const CloudRestoreProgress.downloading());
    final dialogFuture = CloudRestoreProgressDialog.show(ctx, progress: progress);

    try {
      Map<String, dynamic>? cloud;
      try {
        cloud = await auth
            .loadUserSettingsFromCloud()
            .timeout(const Duration(seconds: 45), onTimeout: () => null);
      } catch (_) {
        cloud = null;
      }

      if (cloud == null || cloud.isEmpty) {
        await _dismissDialog();
        await _waitDialogClose(dialogFuture);
        return const CloudRestoreResult(outcome: CloudRestoreOutcome.empty);
      }

      final preview = CloudRestorePreview.fromBackup(cloud);
      progress.value = CloudRestoreProgress.preview(preview);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      progress.value = CloudRestoreProgress.applying(preview);
      final applied = await auth
          .applyCloudSettingsLocally(cloud)
          .timeout(const Duration(seconds: 120), onTimeout: () => false);

      if (!applied) {
        progress.value =
            CloudRestoreProgress.error('cloud.restoreFailed'.tr);
        await _waitDialogClose(dialogFuture);
        return const CloudRestoreResult(outcome: CloudRestoreOutcome.failed);
      }

      CloudPlaylistRestoreReport? playlistReport;
      playlistReport =
          await CloudPlaylistRestoreValidator.validateAndPruneFailedSlots();

      if (afterApply != null) {
        try {
          await afterApply();
        } catch (_) {}
      }

      progress.value = CloudRestoreProgress.done(preview);
      await _waitDialogClose(dialogFuture);

      _showPlaylistWarningIfNeeded(playlistReport);

      if (navigateToSplashOnSuccess) {
        await Get.offAllNamed<void>(AppRoutes.splash);
      }

      return CloudRestoreResult(
        outcome: CloudRestoreOutcome.success,
        preview: preview,
        playlistReport: playlistReport,
      );
    } catch (_) {
      progress.value =
          CloudRestoreProgress.error('cloud.restoreFailed'.tr);
      await _waitDialogClose(dialogFuture);
      return const CloudRestoreResult(outcome: CloudRestoreOutcome.failed);
    }
  }

  static Future<void> _waitDialogClose(Future<void> dialogFuture) async {
    try {
      await dialogFuture.timeout(const Duration(seconds: 5));
    } catch (_) {
      await _dismissDialog();
    }
  }

  static Future<void> _dismissDialog() async {
    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }
  }

  static void _showPlaylistWarningIfNeeded(
    CloudPlaylistRestoreReport? report,
  ) {
    if (report == null || !report.shouldWarn) return;
    final body = report.hasPartialFailure
        ? 'cloud.restore.partialPlaylists'.trParams({
            'ok': '${report.successCount}',
            'fail': '${report.failedCount}',
            'total': '${report.totalCount}',
          })
        : 'cloud.restore.allPlaylistsFailed'.tr;
    GlassSnackbar.show(
      'cloud.restore.partialPlaylistsTitle'.tr,
      body,
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
