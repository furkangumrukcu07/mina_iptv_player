import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:async';

import '../../ui/tv_dpad_focus.dart';
import '../../core/i18n/app_locale.dart';

class PerformanceSettingsController extends GetxController {
  final usedMemoryMb = 0.obs;
  final maxMemoryMb = 0.obs;
  final storageCacheMb = 0.0.obs;
  final isCalculatingStorage = false.obs;
  final isCleaningStorage = false.obs;

  Timer? _timer;
  static const MethodChannel _infoChannel = MethodChannel('mina.device/info');

  @override
  void onInit() {
    super.onInit();
    _fetchMaxMemory();
    _calculateStorageCache();
    _updateMemoryUsage();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateMemoryUsage();
    });
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  void _updateMemoryUsage() {
    final bytes = ProcessInfo.currentRss;
    usedMemoryMb.value = bytes ~/ (1024 * 1024);
  }

  Future<void> _fetchMaxMemory() async {
    if (Platform.isAndroid) {
      try {
        final largeClass = await _infoChannel.invokeMethod<int>('getLargeMemoryClass');
        if (largeClass != null) {
          maxMemoryMb.value = largeClass;
        }
      } catch (e) {
        debugPrint('Error fetching max memory: $e');
      }
    }
  }

  Future<void> _calculateStorageCache() async {
    isCalculatingStorage.value = true;
    try {
      int totalBytes = 0;
      final tempDir = await getTemporaryDirectory();
      totalBytes += await _getDirSize(tempDir);

      storageCacheMb.value = totalBytes / (1024 * 1024);
    } catch (e) {
      debugPrint('Error calculating cache: $e');
    } finally {
      isCalculatingStorage.value = false;
    }
  }

  Future<int> _getDirSize(Directory dir) async {
    int size = 0;
    try {
      if (await dir.exists()) {
        await for (var entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            size += await entity.length();
          }
        }
      }
    } catch (e) {
      // Ignore
    }
    return size;
  }

  void runRamMaintenance() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    Get.snackbar(
      'settings.performance.ramCleaned.title'.tr,
      'settings.performance.ramCleaned.desc'.tr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.black87,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
    );
    _updateMemoryUsage();
  }

  Future<void> cleanStorageCache() async {
    isCleaningStorage.value = true;
    try {
      await DefaultCacheManager().emptyCache();
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (var entity in tempDir.list(recursive: false, followLinks: false)) {
          if (entity is File || entity is Directory) {
            try {
              await entity.delete(recursive: true);
            } catch (_) {}
          }
        }
      }
      await _calculateStorageCache();
      
      Get.snackbar(
        'settings.performance.storageCleaned.title'.tr,
        'settings.performance.storageCleaned.desc'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.black87,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } catch (e) {
      debugPrint('Error cleaning cache: $e');
    } finally {
      isCleaningStorage.value = false;
    }
  }
}

class PerformanceSettingsView extends StatelessWidget {
  const PerformanceSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PerformanceSettingsController());
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('settings.tile.performance'.tr),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'settings.performance.device'.tr.toUpperCase(),
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    label: 'performance.ram.used'.tr,
                    valueStream: controller.usedMemoryMb,
                    suffix: ' MB',
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  _InfoRow(
                    label: 'performance.ram.limit'.tr,
                    valueStream: controller.maxMemoryMb,
                    suffix: ' MB',
                    placeholder: 'Bilinmiyor',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'settings.performance.maintenance'.tr.toUpperCase(),
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _ActionTile(
              title: 'performance.ram.clean'.tr,
              subtitle: 'performance.ram.clean.desc'.tr,
              buttonText: 'performance.action.run'.tr,
              primary: primary,
              onTap: controller.runRamMaintenance,
            ),
            const SizedBox(height: 16),
            Obx(() => _ActionTile(
                  title: 'performance.storage.clean'.tr,
                  subtitle: controller.isCalculatingStorage.value
                      ? 'performance.storage.calc'.tr
                      : 'performance.storage.clean.desc'.trParams({
                          'n': controller.storageCacheMb.value.toStringAsFixed(2),
                        }),
                  buttonText: 'performance.action.clean'.tr,
                  primary: primary,
                  isLoading: controller.isCleaningStorage.value,
                  onTap: controller.isCalculatingStorage.value
                      ? null
                      : controller.cleanStorageCache,
                )),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Rx<num> valueStream;
  final String suffix;
  final String? placeholder;

  const _InfoRow({
    required this.label,
    required this.valueStream,
    required this.suffix,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        Obx(() {
          final val = valueStream.value;
          if (val == 0 && placeholder != null) {
            return Text(
              placeholder!,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          }
          return Text(
            '$val$suffix',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          );
        }),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final Color primary;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.primary,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusableInkWell(
      onTap: onTap,
      borderRadius: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
