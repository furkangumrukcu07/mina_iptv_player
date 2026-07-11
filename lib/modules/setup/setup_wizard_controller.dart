import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/cloud_restore_coordinator.dart';
import '../../core/services/profiles_service.dart';
import '../../core/services/toast_service.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../playlist/playlist_controller.dart';

/// Kurulum sihirbazı: mobil 8 adım; TV 6 adım (… → font → kaynak).
class SetupWizardController extends GetxController {
  final pageIndex = 0.obs;
  static const int totalPages = 8;
  static const int tvTotalPages = 6;

  static int pageCountFor(bool tv) => tv ? tvTotalPages : totalPages;

  static String stepKeyFor(int index, {required bool tv}) {
    if (tv) {
      return switch (index) {
        0 => 'setup.stepLayoutMode',
        1 => 'setup.stepTheme',
        2 => 'setup.stepPlayer',
        3 => 'setup.stepPerformance',
        4 => 'setup.stepAppFont',
        5 => 'setup.stepSource',
        _ => 'setup.stepLayoutMode',
      };
    }
    return switch (index) {
      0 => 'setup.stepLayoutMode',
      1 => 'setup.stepTheme',
      2 => 'setup.stepPlayer',
      3 => 'setup.stepPerformance',
      4 => 'setup.stepFeatures',
      5 => 'setup.stepAppFont',
      _ => 'setup.stepSource',
    };
  }

  /// Son sayfanın indeksi — mobil ve TV'de kaynak adımı.
  static int lastPageIndexFor(bool tv) => pageCountFor(tv) - 1;

  static const int sourcePageIndex = totalPages - 1;
  static const int tvSourcePageIndex = tvTotalPages - 1;

  static bool isSourcePage(int index, {required bool tv}) =>
      tv ? index == tvSourcePageIndex : index == sourcePageIndex;

  /// Son adımda «Kurulumu bitir»: yalnız M3U/Xtream liste yüklü veya kayıtlı kaynak varken.
  final canCompleteSetup = false.obs;

  /// Google ile giriş / bulut senkronu sürerken UI'da spinner için.
  final isCloudBusy = false.obs;

  /// Google ile oturum açılmışsa, kurulum tamamlandığında yerel ayarlar
  /// buluta ilk kez senkronlanır (yeni kullanıcı akışı).
  bool _syncToCloudOnComplete = false;

  void syncPage(int i) {
    pageIndex.value = i;
    final tv = Get.find<AppSettingsService>().layoutMode.value ==
        AppLayoutMode.tv;
    if (isSourcePage(i, tv: tv)) {
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
    if (Get.isRegistered<AppSettingsService>()) {
      unawaited(
        Get.find<AppSettingsService>().ensureHandheldHomeLayoutDefault(),
      );
    }
    if (Get.isRegistered<PlaylistController>()) {
      ever(
        Get.find<PlaylistController>().canSubmit,
        (_) => _recomputeCanCompleteIfOnSourcePage(),
      );
      ever(
        Get.find<PlaylistController>().isM3uLoaded,
        (_) => _recomputeCanCompleteIfOnSourcePage(),
      );
    }
  }

  Future<void> _afterPlaylistLoaded() async {
    await Get.find<AppSettingsService>()
        .setSetupCompleted(true, markShowcaseSuggestionSeen: true);
    // Bulut yazımı ana ekrana geçişi BLOKE ETMEMELİ — Firestore yazımı ağ
    // yavaşsa uzun sürebilir; arka planda çalışsın, navigasyon hemen olsun.
    unawaited(_maybeSyncToCloudOnComplete());
    _clearHook();
    Get.offAllNamed(AppRoutes.home);
  }

  /// Google ile oturum aç → bulutta veri varsa yerel depoya uygula ve ana
  /// ekrana yönlendir; yoksa yeni kullanıcı olarak işaretle ve sihirbaza
  /// devam etmesine izin ver (kurulum sonunda buluta yazılır).
  Future<void> signInWithGoogleAndSync() async {
    if (isCloudBusy.value) return;
    final auth = Get.find<AuthService>();
    final toast = Get.find<ToastService>();
    if (!auth.isAvailable) {
      toast.show('cloud.notConfigured'.tr, isError: true);
      return;
    }
    isCloudBusy.value = true;
    try {
      final result = await auth.signInWithGoogle();
      switch (result.outcome) {
        case GoogleSignInOutcome.cancelled:
          return;
        case GoogleSignInOutcome.notConfigured:
          toast.show('cloud.notConfigured'.tr, isError: true);
          return;
        case GoogleSignInOutcome.failed:
          toast.show(result.messageKey.tr, isError: true);
          return;
        case GoogleSignInOutcome.success:
          break;
      }

      final restore = await CloudRestoreCoordinator.restoreWithProgressDialog(
        auth: auth,
        navigateToSplashOnSuccess: false,
        afterApply: () async {
          final app = Get.find<AppSettingsService>();
          await app.reloadAllFromPrefs();
          await app.reconcileDeviceLocalHardwareSettings();
          if (Get.isRegistered<ProfilesService>()) {
            await Get.find<ProfilesService>().reload();
          }
        },
      );

      switch (restore.outcome) {
        case CloudRestoreOutcome.failed:
          toast.show('cloud.restoreFailed'.tr, isError: true);
          return;
        case CloudRestoreOutcome.empty:
          await _stayOnSetupAfterCloudSignIn(auth, null, toast);
          return;
        case CloudRestoreOutcome.success:
          final preview = restore.preview;
          if (preview != null && preview.hasPlaylistData) {
            final app = Get.find<AppSettingsService>();
            await app.setSetupCompleted(true, markShowcaseSuggestionSeen: true);
            _clearHook();
            await Future<void>.delayed(const Duration(milliseconds: 150));
            Get.offAllNamed(AppRoutes.splash);
          } else {
            await _stayOnSetupAfterCloudSignIn(
              auth,
              null,
              toast,
              alreadyApplied: true,
            );
          }
      }
    } catch (e, st) {
      debugPrint('[SetupWizard] signInWithGoogleAndSync error: $e\n$st');
      toast.show('cloud.restoreFailed'.tr, isError: true);
    } finally {
      isCloudBusy.value = false;
    }
  }

  /// Oturum açıldı; bulutta liste yok — kaynak adımında kal, formdan URL/Xtream gir.
  Future<void> _stayOnSetupAfterCloudSignIn(
    AuthService auth,
    Map<String, dynamic>? cloud,
    ToastService toast, {
    bool alreadyApplied = false,
  }) async {
    _syncToCloudOnComplete = true;
    if (!alreadyApplied && cloud != null && cloud.isNotEmpty) {
      try {
        await auth.applyCloudSettingsLocally(cloud);
        final app = Get.find<AppSettingsService>();
        await app.reloadAllFromPrefs();
        if (Get.isRegistered<ProfilesService>()) {
          await Get.find<ProfilesService>().reload();
        }
      } catch (e, st) {
        debugPrint('[SetupWizard] partial cloud apply on setup: $e\n$st');
      }
    }
    ensurePlaylistHook();
    unawaited(recomputeCanComplete());
    toast.show('cloud.signedInContinue'.tr);
  }

  Future<void> _maybeSyncToCloudOnComplete() async {
    if (!_syncToCloudOnComplete) return;
    if (!Get.isRegistered<AuthService>()) return;
    final auth = Get.find<AuthService>();
    if (!auth.isAvailable || !auth.isSignedIn) return;
    try {
      await auth
          .saveUserSettingsToCloud()
          .timeout(const Duration(seconds: 20));
    } catch (_) {}
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
    if (pl.canSubmit.value) {
      canCompleteSetup.value = true;
      return;
    }
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

  void _recomputeCanCompleteIfOnSourcePage() {
    final app = Get.find<AppSettingsService>();
    final tv = app.layoutMode.value == AppLayoutMode.tv;
    if (isSourcePage(pageIndex.value, tv: tv)) {
      unawaited(recomputeCanComplete());
    }
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
    final pl = Get.find<PlaylistController>();
    if (pl.canSubmit.value) {
      ensurePlaylistHook();
      await pl.submit();
      return;
    }
    _clearHook();
    await Get.find<AppSettingsService>()
        .setSetupCompleted(true, markShowcaseSuggestionSeen: true);
    unawaited(_maybeSyncToCloudOnComplete());
    Get.offAllNamed(AppRoutes.home);
  }

  @override
  void onClose() {
    _clearHook();
    super.onClose();
  }
}
