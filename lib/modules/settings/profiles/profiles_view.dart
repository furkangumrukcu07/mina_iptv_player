import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/profiles/mina_profile.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/profiles_service.dart';
import '../../../ui/glass_overlays.dart';
import '../../../ui/settings_glass_panel.dart';
import '../../../ui/themed_settings_background.dart';
import '../../../ui/tv_dpad_focus.dart';
import 'profile_avatar.dart';
import 'profile_edit_sheet.dart';
import 'profile_pin_dialog.dart';

/// Aktif olmayan profile dokununca kullanıcının seçtiği eylem.
enum _ProfileTapAction { switchTo, edit }

/// Netflix tarzı profil yönetimi: profil oluştur / düzenle / sil / değiştir.
/// TV'de tüm akış D-Pad ile gezilebilir.
class ProfilesView extends StatefulWidget {
  const ProfilesView({super.key});

  @override
  State<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends State<ProfilesView> {
  bool _manageMode = false;

  ProfilesService get _svc => Get.find<ProfilesService>();

  Future<void> _onCardTap(MinaProfile p, bool remote) async {
    final isActive = p.id == _svc.activeId.value;

    // Yönet modu → her zaman düzenle.
    // Aktif profile dokunma → düzenle (kendine geçiş anlamsız).
    // Aktif olmayan profile dokunma → kullanıcıya seç: Geç / Düzenle.
    var wantsEdit = _manageMode || isActive;
    if (!wantsEdit) {
      final action = await _chooseProfileAction(p);
      if (action == null || !mounted) return;
      wantsEdit = action == _ProfileTapAction.edit;
    }

    // Kilitli profilde hem geçiş hem düzenleme için PIN gerekir (Netflix
    // mantığı: kilit yalnızca PIN bilen kişiye açılır).
    if (p.isLocked) {
      final ok = await _unlockGate(p);
      if (!ok || !mounted) return;
    }

    if (wantsEdit) {
      await showProfileEditSheet(context, profile: p);
      return;
    }
    // force: true → activeId bayat/eşit kalsa bile hedef profilin ayarları
    // her zaman uygulanır ve servisler yenilenir (geçiş garanti edilir).
    await _svc.switchTo(p.id, force: true);
    if (!mounted) return;
    GlassSnackbar.show(
      'profiles.title'.tr,
      'profiles.switched'.trParams({'name': p.name}),
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Aktif olmayan profile dokununca: "Bu profile geç" mi "Düzenle" mi?
  /// İptalde `null`. D-pad uyumlu cam dialog.
  Future<_ProfileTapAction?> _chooseProfileAction(MinaProfile p) {
    final remote =
        Get.find<AppSettingsService>().layoutMode.value.usesRemoteNavigationStyle;
    return showDialog<_ProfileTapAction>(
      context: context,
      builder: (dCtx) => GlassAlertDialog(
        tvOsdStyle: remote,
        title: Text(p.name),
        content: Text('profiles.action.prompt'.tr),
        actions: [
          GlassDialogActionButton(
            label: 'common.cancel'.tr,
            onDarkSurface: remote,
            onPressed: () => Navigator.of(dCtx).pop(),
          ),
          GlassDialogActionButton(
            label: 'profiles.action.edit'.tr,
            onDarkSurface: remote,
            onPressed: () =>
                Navigator.of(dCtx).pop(_ProfileTapAction.edit),
          ),
          GlassDialogActionButton(
            label: 'profiles.action.switch'.tr,
            primary: true,
            autofocus: true,
            onDarkSurface: remote,
            onPressed: () =>
                Navigator.of(dCtx).pop(_ProfileTapAction.switchTo),
          ),
        ],
      ),
    );
  }

  /// Kilitli profile erişim geçidi: PIN sorar. Doğruysa `true`. Kullanıcı
  /// "PIN'i unuttum" derse kurtarma anahtarıyla yeni PIN belirleme akışına
  /// girer; başarılıysa yine `true` (kimlik kanıtlandı). İptal/yanlış → `false`.
  Future<bool> _unlockGate(MinaProfile p) async {
    var recoveryRequested = false;
    // "PIN'i unuttum" her zaman sunulur: kurtarma anahtarı varsa onunla,
    // yoksa cihaz sahibi onayıyla sıfırlanır. Aksi halde eski şemada (ör. 6
    // haneli) kurulmuş profiller kalıcı kilitli kalabiliyordu.
    final pin = await showProfilePinDialog(
      context,
      title: 'profiles.pin.enter'.tr,
      subtitle: p.name,
      onForgotPin: () => recoveryRequested = true,
    );
    if (recoveryRequested) {
      if (!mounted) return false;
      return _recoverAndResetPin(p);
    }
    if (pin == null) return false;
    if (!_svc.verifyLock(p.id, pin)) {
      GlassSnackbar.show(
        'profiles.title'.tr,
        'profiles.pin.wrong'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
    return true;
  }

  /// Kurtarma anahtarı ile PIN sıfırlama. Başarılıysa profilin yeni PIN +
  /// kurtarma anahtarı kaydedilir ve `true` döner (profil geçişi/düzenleme
  /// kararı çağırana ait). Profili kendisi DEĞİŞTİRMEZ.
  Future<bool> _recoverAndResetPin(MinaProfile p) async {
    if (p.hasRecovery) {
      // Kurtarma anahtarı var → anahtarla doğrula.
      final key = await showProfileRecoveryKeyDialog(
        context,
        title: 'profiles.recovery.enter'.tr,
        subtitle: 'profiles.recovery.enterHint'.trParams({'name': p.name}),
        hint: 'profiles.recovery.hint'.tr,
      );
      if (key == null || !mounted) return false;
      if (!_svc.verifyRecovery(p.id, key)) {
        GlassSnackbar.show(
          'profiles.title'.tr,
          'profiles.recovery.wrong'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
    } else {
      // Kurtarma anahtarı yok (eski şemada kurulmuş veya anahtarsız profil).
      // Cihaz sahibi olarak onaylı sıfırlamaya izin ver — profil verisi zaten
      // tüm profiller arasında paylaşıldığından bu yumuşak kilit kaldırılabilir.
      final remote = Get.find<AppSettingsService>()
          .layoutMode
          .value
          .usesRemoteNavigationStyle;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dCtx) => GlassAlertDialog(
          tvOsdStyle: remote,
          title: Text('profiles.recovery.reset'.tr),
          content: Text('profiles.recovery.ownerResetBody'.trParams({
            'name': p.name,
          })),
          actions: [
            GlassDialogActionButton(
              label: 'common.cancel'.tr,
              onDarkSurface: remote,
              onPressed: () => Navigator.of(dCtx).pop(false),
            ),
            GlassDialogActionButton(
              label: 'profiles.recovery.reset'.tr,
              primary: true,
              onDarkSurface: remote,
              onPressed: () => Navigator.of(dCtx).pop(true),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return false;
    }
    final newPin = await showProfilePinDialog(
      context,
      title: 'profiles.pin.set'.tr,
      subtitle: 'profiles.pin.digits4'.tr,
    );
    if (newPin == null || !mounted) return false;
    final confirm = await showProfilePinDialog(
      context,
      title: 'profiles.pin.confirm'.tr,
      subtitle: 'profiles.pin.digits4'.tr,
    );
    if (confirm == null || !mounted) return false;
    if (newPin != confirm) {
      GlassSnackbar.show(
        'profiles.title'.tr,
        'profiles.pin.mismatch'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
    final newRecovery = await showProfileRecoveryKeyDialog(
      context,
      title: 'profiles.recovery.set'.tr,
      subtitle: 'profiles.recovery.setHint'.tr,
      hint: 'profiles.recovery.hint'.tr,
    );
    if (newRecovery == null || !mounted) return false;
    await _svc.setLock(p.id, newPin, recoveryKey: newRecovery);
    GlassSnackbar.show(
      'profiles.title'.tr,
      'profiles.recovery.resetDone'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final remote = remoteNavForScreenLayout(context, settings.layoutMode.value);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Get.back<void>();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ThemedSettingsBackground(
          child: SafeArea(
            child: SettingsGlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        remote
                            ? TvIconButton(
                                icon: Icons.arrow_back_rounded,
                                onPressed: () => Get.back<void>(),
                                autofocus: true,
                              )
                            : IconButton(
                                onPressed: () => Get.back<void>(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: Colors.white,
                                tooltip: 'common.back'.tr,
                              ),
                        Expanded(
                          child: Text(
                            'profiles.title'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _ManageToggle(
                          remote: remote,
                          active: _manageMode,
                          onTap: () =>
                              setState(() => _manageMode = !_manageMode),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Text(
                      _manageMode
                          ? 'profiles.manageHint'.tr
                          : 'profiles.hint'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Obx(() {
                      final profiles = _svc.profiles;
                      final activeId = _svc.activeId.value;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final p in profiles)
                              _ProfileCard(
                                profile: p,
                                isActive: p.id == activeId,
                                manageMode: _manageMode,
                                remote: remote,
                                onTap: () => _onCardTap(p, remote),
                              ),
                            _AddProfileCard(
                              remote: remote,
                              onTap: () => showProfileEditSheet(context),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _ManageToggle extends StatelessWidget {
  const _ManageToggle({
    required this.remote,
    required this.active,
    required this.onTap,
  });

  final bool remote;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active
                ? primary.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.check_rounded : Icons.edit_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                active ? 'common.done'.tr : 'profiles.manage'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!remote) return btn;
    return tvDpadActivateWrap(context, onActivate: onTap, child: btn);
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.manageMode,
    required this.remote,
    required this.onTap,
  });

  final MinaProfile profile;
  final bool isActive;
  final bool manageMode;
  final bool remote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 116,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ProfileAvatar(
                      avatarId: profile.avatarId,
                      size: 96,
                      selected: isActive,
                      ringColor: primary,
                      dim: manageMode,
                      photoUrl: profile.photoUrl,
                    ),
                    if (manageMode)
                      const Icon(Icons.edit_rounded,
                          color: Colors.white, size: 30),
                    if (isActive)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                    if (profile.isLocked)
                      Positioned(
                        left: 2,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(Icons.lock_rounded,
                              color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.8),
                  fontSize: 13.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!remote) return card;
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 18,
      child: card,
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  const _AddProfileCard({required this.remote, required this.onTap});

  final bool remote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 116,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add_rounded,
                    color: Colors.white70, size: 40),
              ),
              const SizedBox(height: 8),
              Text(
                'profiles.add'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!remote) return card;
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 18,
      child: card,
    );
  }
}
