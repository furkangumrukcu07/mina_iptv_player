import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/profiles/mina_profile.dart';
import '../../../core/profiles/profile_avatars.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/profiles_service.dart';
import '../../../ui/glass_overlays.dart';
import '../../../ui/tv_dpad_focus.dart';
import 'profile_avatar.dart';
import 'profile_pin_dialog.dart';

/// Profil oluştur / düzenle dialogu. [profile] null ise yeni profil.
Future<void> showProfileEditSheet(
  BuildContext context, {
  MinaProfile? profile,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ProfileEditDialog(profile: profile),
  );
}

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({this.profile});

  final MinaProfile? profile;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final TextEditingController _nameCtrl;
  late int _avatarId;
  late bool _locked;
  late final bool _hadLock;
  String? _pin; // belirlenen yeni PIN (null = mevcut korunur)
  String? _recoveryKey; // belirlenen yeni kurtarma anahtarı

  /// Google profil fotoğrafı (yalnızca birincil profilde olabilir). Kullanıcı
  /// bir ikon avatarı seçerse temizlenir.
  String? _photoUrl;

  ProfilesService get _svc => Get.find<ProfilesService>();
  bool get _isEdit => widget.profile != null;

  /// Düzenlenen profil birincil (Google ile eşitlenen) profil mi?
  bool get _isPrimary =>
      _isEdit && widget.profile!.id == _svc.primaryProfile?.id;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _avatarId = p?.avatarId ?? (_svc.profiles.length % kProfileAvatarCount);
    _locked = p?.isLocked ?? false;
    _hadLock = p?.isLocked ?? false;
    _photoUrl = p?.photoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _remote =>
      Get.find<AppSettingsService>().layoutMode.value.usesRemoteNavigationStyle;

  Future<void> _setupLock() async {
    final p1 = await showProfilePinDialog(
      context,
      title: 'profiles.pin.set'.tr,
      subtitle: 'profiles.pin.digits4'.tr,
    );
    if (p1 == null || !mounted) return;
    final p2 = await showProfilePinDialog(
      context,
      title: 'profiles.pin.confirm'.tr,
      subtitle: 'profiles.pin.digits4'.tr,
    );
    if (p2 == null || !mounted) return;
    if (p1 != p2) {
      GlassSnackbar.show(
        'profiles.title'.tr,
        'profiles.pin.mismatch'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final recovery = await _promptRecoveryKey();
    if (recovery == null || !mounted) return;
    setState(() {
      _pin = p1;
      _recoveryKey = recovery;
      _locked = true;
    });
  }

  /// Kurtarma anahtarı girişi — PIN belirlerken zorunlu.
  Future<String?> _promptRecoveryKey() async {
    return showProfileRecoveryKeyDialog(
      context,
      title: 'profiles.recovery.set'.tr,
      subtitle: 'profiles.recovery.setHint'.tr,
      hint: 'profiles.recovery.hint'.tr,
    );
  }

  void _removeLock() {
    setState(() {
      _pin = null;
      _recoveryKey = null;
      _locked = false;
    });
  }

  /// Kilitli profilde PIN'i doğrudan değiştir: yeni PIN (x2) + yeni kurtarma
  /// anahtarı belirlenir. (Profil zaten PIN geçidinden açıldığı için mevcut
  /// PIN tekrar sorulmaz.) Kaydet'e basınca [_svc.setLock] uygulanır.
  Future<void> _changePin() async {
    final p1 = await showProfilePinDialog(
      context,
      title: 'profiles.pin.set'.tr,
      subtitle: 'profiles.pin.digits4'.tr,
    );
    if (p1 == null || !mounted) return;
    final p2 = await showProfilePinDialog(
      context,
      title: 'profiles.pin.confirm'.tr,
      subtitle: 'profiles.pin.digits4'.tr,
    );
    if (p2 == null || !mounted) return;
    if (p1 != p2) {
      GlassSnackbar.show(
        'profiles.title'.tr,
        'profiles.pin.mismatch'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final recovery = await _promptRecoveryKey();
    if (recovery == null || !mounted) return;
    setState(() {
      _pin = p1;
      _recoveryKey = recovery;
      _locked = true;
    });
    GlassSnackbar.show(
      'profiles.title'.tr,
      'profiles.pin.changedPending'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Mevcut kilitli profilde kurtarma anahtarı ile PIN sıfırlama.
  Future<void> _resetLockWithRecovery() async {
    final p = widget.profile;
    if (p == null || !p.hasRecovery) {
      GlassSnackbar.show(
        'profiles.title'.tr,
        'profiles.recovery.notSet'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final key = await showProfileRecoveryKeyDialog(
      context,
      title: 'profiles.recovery.enter'.tr,
      subtitle: 'profiles.recovery.enterHint'.trParams({'name': p.name}),
      hint: 'profiles.recovery.hint'.tr,
    );
    if (key == null || !mounted) return;
    if (!_svc.verifyRecovery(p.id, key)) {
      GlassSnackbar.show(
        'profiles.title'.tr,
        'profiles.recovery.wrong'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final newPin = await showProfilePinDialog(
      context,
      title: 'profiles.pin.set'.tr,
      subtitle: 'profiles.pin.digits4'.tr,
    );
    if (newPin == null || !mounted) return;
    final confirm = await showProfilePinDialog(
      context,
      title: 'profiles.pin.confirm'.tr,
      subtitle: 'profiles.pin.digits4'.tr,
    );
    if (confirm == null || !mounted) return;
    if (newPin != confirm) {
      GlassSnackbar.show(
        'profiles.title'.tr,
        'profiles.pin.mismatch'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final newRecovery = await _promptRecoveryKey();
    if (newRecovery == null || !mounted) return;
    await _svc.setLock(p.id, newPin, recoveryKey: newRecovery);
    setState(() {
      _pin = newPin;
      _recoveryKey = newRecovery;
      _locked = true;
    });
    GlassSnackbar.show(
      'profiles.title'.tr,
      'profiles.recovery.resetDone'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      GlassSnackbar.show(
        'profiles.title'.tr,
        'profiles.nameRequired'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final p = widget.profile;
    if (p == null) {
      await _svc.createProfile(
        name: name,
        avatarId: _avatarId,
        pin: _locked ? _pin : null,
        recoveryKey: _locked ? _recoveryKey : null,
      );
    } else {
      await _svc.rename(p.id, name);
      await _svc.setAvatar(p.id, _avatarId);
      // Birincil profil manuel düzenlendiyse (isim/avatar/foto değiştiyse)
      // otomatik Google eşitlemesini durdur; kullanıcının seçimi kalıcı olsun.
      if (_isPrimary) {
        final changed = name != p.name ||
            _avatarId != p.avatarId ||
            _photoUrl != p.photoUrl;
        if (changed) {
          await _svc.detachPrimaryFromGoogle(p.id, photoUrl: _photoUrl);
        }
      }
      if (!_locked && _hadLock) {
        await _svc.clearLock(p.id);
      } else if (_locked && _pin != null) {
        await _svc.setLock(
          p.id,
          _pin!,
          recoveryKey: _recoveryKey,
        );
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final p = widget.profile;
    if (p == null) return;
    if (_svc.profiles.length <= 1) {
      GlassSnackbar.show(
        'profiles.title'.tr,
        'profiles.lastOne'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => GlassAlertDialog(
        tvOsdStyle: _remote,
        title: Text('profiles.delete.confirmTitle'.tr),
        content: Text('profiles.delete.confirmBody'.trParams({'name': p.name})),
        actions: [
          GlassDialogActionButton(
            label: 'common.cancel'.tr,
            onDarkSurface: _remote,
            onPressed: () => Navigator.of(dCtx).pop(false),
          ),
          GlassDialogActionButton(
            label: 'profiles.delete'.tr,
            primary: true,
            onDarkSurface: _remote,
            onPressed: () => Navigator.of(dCtx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.delete(p.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: GlassPopupPanel(
          gradientBlendTowardBlack: 0.25,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEdit ? 'profiles.edit'.tr : 'profiles.create'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                // Yuvarlak cam profil resmi önizlemesi.
                Center(
                  child: ProfileAvatar(
                    avatarId: _avatarId,
                    size: 84,
                    photoUrl: _photoUrl,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'profiles.name'.tr,
                    labelStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'profiles.picture'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 0; i < kProfileAvatarCount; i++)
                      _AvatarChoice(
                        avatarId: i,
                        selected: _avatarId == i && _photoUrl == null,
                        remote: _remote,
                        onTap: () => setState(() {
                          _avatarId = i;
                          _photoUrl = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _LockRow(
                  locked: _locked,
                  remote: _remote,
                  onSetup: _setupLock,
                  onRemove: _removeLock,
                  onChangePin: _locked ? _changePin : null,
                  onResetViaRecovery:
                      (_isEdit && (widget.profile?.hasRecovery ?? false))
                          ? _resetLockWithRecovery
                          : null,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (_isEdit) ...[
                      Expanded(
                        child: GlassDialogActionButton(
                          label: 'profiles.delete'.tr,
                          onDarkSurface: true,
                          onPressed: _delete,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: GlassDialogActionButton(
                        label: 'common.cancel'.tr,
                        onDarkSurface: true,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassDialogActionButton(
                        label: 'common.save'.tr,
                        primary: true,
                        autofocus: true,
                        onDarkSurface: true,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Resim seçici grid hücresi: yuvarlak cam avatar. Seçiliyse halka + tik.
class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.avatarId,
    required this.selected,
    required this.remote,
    required this.onTap,
  });

  final int avatarId;
  final bool selected;
  final bool remote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final choice = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 54,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ProfileAvatar(
                avatarId: avatarId,
                size: 54,
                selected: selected,
                ringColor: primary,
              ),
              if (selected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (!remote) return choice;
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 27,
      child: choice,
    );
  }
}

class _LockRow extends StatelessWidget {
  const _LockRow({
    required this.locked,
    required this.remote,
    required this.onSetup,
    required this.onRemove,
    this.onChangePin,
    this.onResetViaRecovery,
  });

  final bool locked;
  final bool remote;
  final VoidCallback onSetup;
  final VoidCallback onRemove;
  final VoidCallback? onChangePin;
  final VoidCallback? onResetViaRecovery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: locked ? Colors.greenAccent : Colors.white60,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profiles.lock.title'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      locked ? 'profiles.lock.on'.tr : 'profiles.lock.off'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (locked)
                _LockChip(
                  label: 'profiles.lock.remove'.tr,
                  remote: remote,
                  onTap: onRemove,
                )
              else
                _LockChip(
                  label: 'profiles.lock.add'.tr,
                  remote: remote,
                  primary: true,
                  onTap: onSetup,
                ),
            ],
          ),
          if (onChangePin != null || onResetViaRecovery != null) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onChangePin != null)
                  _LockChip(
                    label: 'profiles.pin.change'.tr,
                    remote: remote,
                    primary: true,
                    onTap: onChangePin!,
                  ),
                if (onResetViaRecovery != null)
                  _LockChip(
                    label: 'profiles.recovery.reset'.tr,
                    remote: remote,
                    onTap: onResetViaRecovery!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LockChip extends StatelessWidget {
  const _LockChip({
    required this.label,
    required this.remote,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final bool remote;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: primary
                ? accent.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    if (!remote) return chip;
    return tvDpadActivateWrap(context, onActivate: onTap, borderRadius: 10, child: chip);
  }
}
