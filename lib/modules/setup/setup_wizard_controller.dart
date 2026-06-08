import 'dart:async';

import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/profiles_service.dart';
import '../../core/services/toast_service.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../ui/cloud_sync_loading_dialog.dart';
import '../playlist/playlist_controller.dart';

/// Mobil kurulum sihirbazı: sayfa indeksi + oynatma listesi gömme [PlaylistController] kancası.
///
/// Sayfa sırası: 0 Language, 1 Theme, 2 Player, 3 Performance (Normal /
/// Düşük Donanım), 4 Features, 5 AppFont, 6 Personalization (Sürükleme Efekti
/// + Çerçeve Stili), 7 Source. Son sayfada [PlaylistController]'a kanca takılır
/// ve oynatma listesi yüklenince kurulum tamamlanır.
class SetupWizardController extends GetxController {
  final pageIndex = 0.obs;
  static const int totalPages = 8;

  /// Son sayfanın indeksi — `Source` adımı her zaman en sondadır.
  static const int sourcePageIndex = totalPages - 1;

  /// Son adımda «Kurulumu bitir»: yalnız M3U/Xtream liste yüklü veya kayıtlı kaynak varken.
  final canCompleteSetup = false.obs;

  /// Google ile giriş / bulut senkronu sürerken UI'da spinner için.
  final isCloudBusy = false.obs;

  /// Google ile oturum açılmışsa, kurulum tamamlandığında yerel ayarlar
  /// buluta ilk kez senkronlanır (yeni kullanıcı akışı).
  bool _syncToCloudOnComplete = false;

  void syncPage(int i) {
    pageIndex.value = i;
    if (i == sourcePageIndex) {
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
        Get.find<PlaylistController>().canSubmit,
        (_) {
          if (pageIndex.value == sourcePageIndex) {
            unawaited(recomputeCanComplete());
          }
        },
      );
      ever(
        Get.find<PlaylistController>().isM3uLoaded,
        (_) {
          if (pageIndex.value == sourcePageIndex) {
            unawaited(recomputeCanComplete());
          }
        },
      );
    }
  }

  Future<void> _afterPlaylistLoaded() async {
    await Get.find<AppSettingsService>().setSetupCompleted(true);
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

      // Oturum açıldı → "Ayarlarınız yükleniyor…" popup'ı; bulut çekilirken
      // açık kalır, işlem bitince kapanır.
      showCloudSyncLoadingDialog();

      final cloud = await auth.loadUserSettingsFromCloud();
      if (cloud != null && cloud.isNotEmpty) {
        final applied = await auth.applyCloudSettingsLocally(cloud);
        if (!applied) {
          dismissCloudSyncLoadingDialog();
          toast.show('cloud.restoreFailed'.tr, isError: true);
          return;
        }
        final app = Get.find<AppSettingsService>();
        await app.reloadCoreFromPrefs();
        if (Get.isRegistered<ProfilesService>()) {
          await Get.find<ProfilesService>().reload();
        }
        await app.setSetupCompleted(true);
        _clearHook();
        // Popup'ı kapat, ardından ana ekrana (splash → home) yönlendir.
        dismissCloudSyncLoadingDialog();
        Get.offAllNamed(AppRoutes.splash);
      } else {
        // Yeni kullanıcı: şimdilik bilgilendir, kurulum sonunda buluta yaz.
        dismissCloudSyncLoadingDialog();
        _syncToCloudOnComplete = true;
        toast.show('cloud.signedInContinue'.tr);
      }
    } finally {
      isCloudBusy.value = false;
    }
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
    await Get.find<AppSettingsService>().setSetupCompleted(true);
    unawaited(_maybeSyncToCloudOnComplete());
    Get.offAllNamed(AppRoutes.home);
  }

  @override
  void onClose() {
    _clearHook();
    super.onClose();
  }
}
