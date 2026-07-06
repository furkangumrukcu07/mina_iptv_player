import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:workmanager/workmanager.dart';

import 'app_settings_service.dart';

class BackgroundSyncService extends GetxService {
  static BackgroundSyncService get to => Get.find<BackgroundSyncService>();

  static const String taskName = 'mina_silent_sync_task';
  static const String uniqueName = 'mina_silent_sync';

  final _app = Get.find<AppSettingsService>();
  Worker? _syncSettingsWorker;

  @override
  void onInit() {
    super.onInit();
    
    // Listen to changes in the silentBackgroundSyncEnabled setting
    _syncSettingsWorker = ever<bool>(
      _app.silentBackgroundSyncEnabled,
      (enabled) {
        updateSyncSchedule();
      },
    );

    // Initial scheduling update
    updateSyncSchedule();
  }

  @override
  void onClose() {
    _syncSettingsWorker?.dispose();
    super.onClose();
  }

  Future<void> updateSyncSchedule() async {
    try {
      final enabled = _app.silentBackgroundSyncEnabled.value;
      if (enabled) {
        debugPrint('BackgroundSyncService: Scheduling silent background sync...');
        await Workmanager().registerPeriodicTask(
          uniqueName,
          taskName,
          frequency: const Duration(hours: 24),
          constraints: Constraints(
            networkType: NetworkType.connected,
            requiresBatteryNotLow: true,
          ),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        );
      } else {
        debugPrint('BackgroundSyncService: Cancelling silent background sync...');
        await Workmanager().cancelByUniqueName(uniqueName);
      }
    } catch (e) {
      debugPrint('BackgroundSyncService: Error updating sync schedule: $e');
    }
  }

  /// Triggers a one-off silent sync immediately for testing or manual usage.
  Future<void> triggerOneOffSync() async {
    try {
      debugPrint('BackgroundSyncService: Triggering one-off silent sync...');
      await Workmanager().registerOneOffTask(
        '${uniqueName}_oneoff_${DateTime.now().millisecondsSinceEpoch}',
        taskName,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (e) {
      debugPrint('BackgroundSyncService: Error triggering one-off sync: $e');
    }
  }
}
