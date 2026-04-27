import 'dart:async';

import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/toast_service.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../playlist/playlist_controller.dart';

/// Mobil kurulum sihirbazı: sayfa indeksi + oynatma listesi gömme [PlaylistController] kancası.
class SetupWizardController extends GetxController {
  final pageIndex = 0.obs;
  static const int totalPages = 4;

  /// Son adımda «Kurulumu bitir»: yalnız M3U/Xtream liste yüklü veya kayıtlı kaynak varken.
  final canCompleteSetup = false.obs;

  void syncPage(int i) {
    pageIndex.value = i;
    if (i == 3) {
      unawaited(recomputeCanComplete());
    }
  }

  bool _hooked = false;

  void ensurePlaylistHook() {
    if (_hooked) return;
    if (!Get.isRegistered<PlaylistController>()) return;
    _hooked = true;
    final c = Get.find<PlaylistController>();
    c.setupWizardCompletionMode = true;
    c.setupWizardOnSuccess = () {
      unawaited(_afterPlaylistLoaded());
    };
    unawaited(recomputeCanComplete());
  }

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<PlaylistController>()) {
      ever(
        Get.find<PlaylistController>().isM3uLoaded,
        (_) {
          if (pageIndex.value == 3) {
            unawaited(recomputeCanComplete());
          }
        },
      );
    }
  }

  Future<void> _afterPlaylistLoaded() async {
    await Get.find<AppSettingsService>().setSetupCompleted(true);
    _clearHook();
    Get.offAllNamed(AppRoutes.splash);
  }

  void _clearHook() {
    if (!Get.isRegistered<PlaylistController>()) return;
    final c = Get.find<PlaylistController>();
    c.setupWizardCompletionMode = false;
    c.setupWizardOnSuccess = null;
    _hooked = false;
  }

  /// Liste yüklü veya depoda kayıtlı birincil kaynak varken true.
  Future<void> recomputeCanComplete() async {
    if (!Get.isRegistered<PlaylistController>()) {
      canCompleteSetup.value = false;
      return;
    }
    final pl = Get.find<PlaylistController>();
    if (pl.isM3uLoaded.value) {
      canCompleteSetup.value = true;
      return;
    }
    if (!Get.isRegistered<PlaylistRepository>()) {
      canCompleteSetup.value = false;
      return;
    }
    final src = await Get.find<PlaylistRepository>().readSource();
    canCompleteSetup.value = src != null;
  }

  /// «Kurulumu bitir» — kayıtlı/ yüklenmiş M3U veya Xtream yoksa izin yok.
  Future<void> tryCompleteSetup() async {
    await recomputeCanComplete();
    if (!canCompleteSetup.value) {
      Get.find<ToastService>().show(
        'setup.finishRequiresSource'.tr,
        isError: true,
      );
      return;
    }
    _clearHook();
    await Get.find<AppSettingsService>().setSetupCompleted(true);
    Get.offAllNamed(AppRoutes.splash);
  }

  @override
  void onClose() {
    _clearHook();
    super.onClose();
  }
}
