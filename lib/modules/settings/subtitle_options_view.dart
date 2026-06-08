import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/player/subtitle_appearance.dart';
import '../../core/player/subtitle_font_family.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/opensubtitles_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';
import 'subtitle_font_family_picker_dialog.dart';
import 'subtitle_font_picker_dialog.dart';

/// Altyazı boyutu, renk, font ve OpenSubtitles hesabı.
class SubtitleOptionsView extends StatefulWidget {
  const SubtitleOptionsView({super.key});

  @override
  State<SubtitleOptionsView> createState() => _SubtitleOptionsViewState();
}

class _SubtitleOptionsViewState extends State<SubtitleOptionsView> {
  final _osUser = TextEditingController();
  final _osPass = TextEditingController();
  final _osUserFocus = FocusNode();
  final _osPassFocus = FocusNode();

  AppSettingsService get _app => Get.find<AppSettingsService>();
  OpenSubtitlesService get _os => Get.find<OpenSubtitlesService>();

  @override
  void dispose() {
    _osUser.dispose();
    _osPass.dispose();
    _osUserFocus.dispose();
    _osPassFocus.dispose();
    super.dispose();
  }

  Future<void> _pickSize() async {
    final tv = _app.layoutMode.value.usesRemoteNavigationStyle;
    final osd = _app.layoutMode.value == AppLayoutMode.tv;
    await showDialog<void>(
      context: context,
      builder: (ctx) => SubtitleFontPickerDialog(
        initialPt: _app.subtitleFontPt.value,
        tvRemote: tv,
        tvOsdStyle: osd,
        onCancel: () => Navigator.of(ctx).pop(),
        onSave: (pt) async {
          await _app.setSubtitleFontPt(pt);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _pickFont() async {
    final tv = _app.layoutMode.value.usesRemoteNavigationStyle;
    final osd = _app.layoutMode.value == AppLayoutMode.tv;
    await showDialog<void>(
      context: context,
      builder: (ctx) => SubtitleFontFamilyPickerDialog(
        initialKey: _app.subtitleFontFamilyKey.value,
        tvRemote: tv,
        tvOsdStyle: osd,
        title: 'settings.subtitle.font'.tr,
        hint: 'settings.subtitle.fontHint'.tr,
        onCancel: () => Navigator.of(ctx).pop(),
        onSave: (key) async {
          await _app.setSubtitleFontFamilyKey(key);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _loginOpenSubtitles() async {
    final err = await _os.login(
      user: _osUser.text,
      password: _osPass.text,
    );
    if (!mounted) return;
    if (err != null) {
      GlassSnackbar.show(
        'settings.opensubtitles.title'.tr,
        err,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    _osPass.clear();
    GlassSnackbar.show(
      'settings.opensubtitles.title'.tr,
      'settings.opensubtitles.loginSuccess'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _logoutOpenSubtitles() async {
    await _os.logout();
    if (!mounted) return;
    GlassSnackbar.show(
      'settings.opensubtitles.title'.tr,
      'settings.opensubtitles.logoutDone'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final tv = _app.layoutMode.value == AppLayoutMode.tv;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: SettingsGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(primary),
                Expanded(
                  child: ListView(
                    physics: AppScrollPhysics.list(context: context),
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    children: [
                      _sectionTitle('settings.subtitle.sectionAppearance'.tr),
                      const SizedBox(height: 8),
                      Obx(() => _previewBox()),
                      const SizedBox(height: 14),
                      _sizeRow(),
                      const SizedBox(height: 12),
                      _colorSection(),
                      const SizedBox(height: 12),
                      _fontRow(),
                      const SizedBox(height: 8),
                      _outlineSwitch(),
                      const SizedBox(height: 22),
                      _sectionTitle(
                          'settings.subtitle.sectionOpenSubtitles'.tr),
                      const SizedBox(height: 8),
                      _openSubtitlesCard(tv),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(Color primary) {
    final remote = remoteNavForScreenLayout(context, _app.layoutMode.value);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Row(
        children: [
          remote
              ? TvIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Get.back<void>(),
                  tooltip: 'common.back'.tr,
                  autofocus: true,
                )
              : IconButton(
                  onPressed: () => Get.back<void>(),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                ),
          Expanded(
            child: Text(
              'settings.subtitle.title'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.72),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _previewBox() {
    final pt = _app.subtitleFontPt.value;
    final color = _app.subtitleFontColor;
    final family = betterPlayerSubtitleFontFamilyFor(
      _app.subtitleFontFamilyKey.value,
    );
    final outline = _app.subtitleOutlineEnabled.value;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade900,
                    Colors.grey.shade800,
                  ],
                ),
              ),
            ),
          ),
          Text(
            'settings.subtitle.previewSample'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: pt,
              fontFamily: family,
              color: color,
              shadows: outline
                  ? const [
                      Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2,
                          color: Colors.black),
                      Shadow(
                          offset: Offset(-1, -1),
                          blurRadius: 2,
                          color: Colors.black),
                    ]
                  : null,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sizeRow() {
    return Obx(
      () => _actionTile(
        icon: Icons.format_size_rounded,
        title: 'settings.subtitle.size'.tr,
        value: '${_app.subtitleFontPt.value.round()} pt',
        onTap: _pickSize,
      ),
    );
  }

  Widget _fontRow() {
    return Obx(
      () => _actionTile(
        icon: Icons.font_download_rounded,
        title: 'settings.subtitle.font'.tr,
        value: _app.subtitleFontFamilyLabel,
        onTap: _pickFont,
      ),
    );
  }

  Widget _colorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'settings.subtitle.color'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Obx(
          () => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final o in kSubtitleColorOptions)
                _colorChip(
                  option: o,
                  selected: _app.subtitleColorKey.value == o.key,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _colorChip({
    required SubtitleColorOption option,
    required bool selected,
  }) {
    return tvDpadActivateWrap(
      context,
      onActivate: () => _app.setSubtitleColorKey(option.key),
      borderRadius: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _app.setSubtitleColorKey(option.key),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? option.color
                    : Colors.white.withValues(alpha: 0.2),
                width: selected ? 2 : 1,
              ),
              color: selected
                  ? option.color.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  option.labelKey.tr,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _outlineSwitch() {
    return Obx(
      () => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: SwitchListTile(
          value: _app.subtitleOutlineEnabled.value,
          onChanged: (v) => _app.setSubtitleOutlineEnabled(v),
          activeThumbColor: Theme.of(context).colorScheme.primary,
          title: Text(
            'settings.subtitle.outline'.tr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'settings.subtitle.outlineHint'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 14,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white70, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _openSubtitlesCard(bool tv) {
    return Obx(() {
      final loggedIn = _os.isLoggedIn.value;
      final busy = _os.isBusy.value;
      final hasKey = _os.hasApiKey;

      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A237E).withValues(alpha: 0.35),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.closed_caption_rounded,
                        color: Colors.amber.shade200,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'settings.opensubtitles.title'.tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'settings.opensubtitles.hint'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  if (!hasKey) ...[
                    const SizedBox(height: 12),
                    _infoBanner('settings.opensubtitles.noApiKeyBanner'.tr),
                  ],
                  if (loggedIn) ...[
                    const SizedBox(height: 16),
                    _infoBanner(
                      'settings.opensubtitles.loggedIn'.trParams({
                        'user': _os.username.value ?? '',
                      }),
                      success: true,
                    ),
                    const SizedBox(height: 12),
                    _glassButton(
                      label: 'settings.opensubtitles.logout'.tr,
                      onPressed: busy ? null : _logoutOpenSubtitles,
                      outlined: true,
                    ),
                  ] else if (hasKey) ...[
                    const SizedBox(height: 16),
                    _osField(
                      controller: _osUser,
                      focusNode: _osUserFocus,
                      label: 'settings.opensubtitles.username'.tr,
                      tv: tv,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _osPassFocus.requestFocus(),
                    ),
                    const SizedBox(height: 10),
                    _osField(
                      controller: _osPass,
                      focusNode: _osPassFocus,
                      label: 'settings.opensubtitles.password'.tr,
                      tv: tv,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!busy) unawaited(_loginOpenSubtitles());
                      },
                    ),
                    const SizedBox(height: 14),
                    _glassButton(
                      label: busy
                          ? 'common.loading'.tr
                          : 'settings.opensubtitles.login'.tr,
                      onPressed: busy ? null : _loginOpenSubtitles,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _infoBanner(String text, {bool success = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: success
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.orange.withValues(alpha: 0.12),
        border: Border.all(
          color: success
              ? Colors.green.withValues(alpha: 0.35)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: success ? Colors.greenAccent.shade100 : Colors.orange.shade100,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _osField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required bool tv,
    bool obscure = false,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _glassButton({
    required String label,
    required VoidCallback? onPressed,
    bool outlined = false,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    final body = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color:
                outlined ? Colors.transparent : primary.withValues(alpha: 0.85),
            border: Border.all(
              color: outlined ? Colors.white38 : primary,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: outlined ? Colors.white : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (onPressed == null) return body;
    return tvDpadActivateWrap(
      context,
      onActivate: onPressed,
      borderRadius: 14,
      child: body,
    );
  }
}
