import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_settings_service.dart';
import '../../core/theme/glass_appearance.dart';
import '../../ui/glass_overlays.dart';

/// Ayarlar → Hakkında → «Yönetici» kartı ve iletişim popup'ı.
class AdminAboutDialog {
  AdminAboutDialog._();

  static const _photoAsset = 'assets/images/admin_furkan.png';
  static const _whatsappDigits = '905446450607';
  static const _emailAddress = 'furkangumrukcu@outlook.com';

  static void show(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ga = GlassAppearance.fromLabel(
      Get.find<AppSettingsService>().themeLabel.value,
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => GlassAlertDialog(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withValues(alpha: 0.35),
                    cs.primary.withValues(alpha: 0.12),
                  ],
                ),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.admin_panel_settings_rounded,
                color: cs.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'settings.dialog.adminTitle'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: _AdminAboutBody(cs: cs, ga: ga),
        ),
        actions: [
          GlassDialogActionButton(
            label: 'common.close'.tr,
            primary: true,
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  static Future<void> openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/$_whatsappDigits');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _toastFail('settings.admin.whatsappFail'.tr);
    } catch (_) {
      _toastFail('settings.admin.whatsappFail'.tr);
    }
  }

  static Future<void> openEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _emailAddress,
      queryParameters: {'subject': 'Mina IPTV Player'},
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!ok) _toastFail('settings.admin.emailFail'.tr);
    } catch (_) {
      _toastFail('settings.admin.emailFail'.tr);
    }
  }

  static void _toastFail(String message) {
    GlassSnackbar.show('settings.dialog.adminTitle'.tr, message);
  }
}

class _AdminAboutBody extends StatelessWidget {
  const _AdminAboutBody({required this.cs, required this.ga});

  final ColorScheme cs;
  final GlassAppearance ga;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        _AvatarRing(cs: cs),
        const SizedBox(height: 14),
        Text(
          'settings.admin.name'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.96),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'settings.admin.role'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cs.primary.withValues(alpha: 0.92),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 18),
        _ContactTile(
          icon: Icons.chat_rounded,
          iconColor: const Color(0xFF25D366),
          label: 'settings.admin.whatsappLabel'.tr,
          value: 'settings.admin.whatsappNumber'.tr,
          onTap: AdminAboutDialog.openWhatsApp,
        ),
        const SizedBox(height: 8),
        _ContactTile(
          icon: Icons.mail_outline_rounded,
          iconColor: cs.primary,
          label: 'settings.admin.emailLabel'.tr,
          value: 'settings.admin.emailAddress'.tr,
          onTap: AdminAboutDialog.openEmail,
        ),
        const SizedBox(height: 8),
        _ContactTile(
          icon: Icons.public_rounded,
          iconColor: Colors.white70,
          label: 'settings.admin.countryLabel'.tr,
          value: 'settings.admin.countryValue'.tr,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: ga.popupBorderColor.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            'settings.admin.bio'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.82),
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: 0.95),
            cs.primary.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.25),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF0D0D0F),
        ),
        child: ClipOval(
          child: Image.asset(
            AdminAboutDialog._photoAsset,
            width: 108,
            height: 108,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 108,
              height: 108,
              color: const Color(0xFF1A1A1E),
              child: Icon(
                Icons.person_rounded,
                size: 52,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final interactive = onTap != null;
    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: interactive ? 0.07 : 0.04),
        border: Border.all(
          color: Colors.white.withValues(alpha: interactive ? 0.14 : 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.16),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.94),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (interactive)
            Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.45),
            ),
        ],
      ),
    );

    if (!interactive) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }
}
