import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import 'playlist_controller.dart';

class PlaylistView extends GetView<PlaylistController> {
  const PlaylistView({super.key});

  /// Okunaklılık için açık gri — saf beyaz yaprak üstünde kaybolmaz.
  static const _denseFieldStyle = TextStyle(
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: Color(0xFFF1F5F9),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final args = Get.arguments;
    final showSecondaryPlaylistUi = args is Map &&
        args[AppRoutes.argPlaylistManage] == true;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'playlist.title'.tr,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 10,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            tooltip: 'settings.title'.tr,
            onPressed: () => Get.toNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: Obx(() {
        final themeLabel = Get.find<AppSettingsService>().themeLabel.value;
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: AppTheme.screenBackground(
            context,
            cs,
            themeLabel: themeLabel,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FocusTraversalGroup(
              policy: WidgetOrderTraversalPolicy(),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(16, 100, 16, 16 + bottomInset),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _GlassCard(
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'playlist.sourceTitle'.tr,
                                style: text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: const Color(0xFFF8FAFC),
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'playlist.sourceSubtitle'.tr,
                                style: text.bodyMedium?.copyWith(
                                  color: const Color(0xFFCBD5E1),
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Obx(
                                () => _SourceTabs(
                                  index: controller.tabIndex.value,
                                  onChanged: controller.setTab,
                                  cs: cs,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Obx(
                                () => controller.tabIndex.value == 0
                                    ? _M3uTab(
                                        controller: controller,
                                        denseStyle: _denseFieldStyle,
                                        cs: cs,
                                      )
                                    : _XtreamTab(
                                        controller: controller,
                                        denseStyle: _denseFieldStyle,
                                        cs: cs,
                                      ),
                              ),
                            ],
                          ),
                        ),
                        if (showSecondaryPlaylistUi) ...[
                          const SizedBox(height: 16),
                          _GlassCard(
                            child: Obx(() {
                              final en = controller.enableSecondary.value;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'playlist.secondaryTitle'.tr,
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 17,
                                      color: const Color(0xFFF8FAFC),
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'playlist.secondarySubtitle'.tr,
                                    style: text.bodyMedium?.copyWith(
                                      color: const Color(0xFFCBD5E1),
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SwitchListTile.adaptive(
                                    value: en,
                                    onChanged: (v) {
                                      controller.enableSecondary.value = v;
                                    },
                                    title: Text(
                                      'playlist.secondaryEnable'.tr,
                                      style: const TextStyle(
                                        color: Color(0xFFF1F5F9),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    activeThumbColor: Colors.white,
                                    activeTrackColor: cs.primary,
                                  ),
                                  if (en)
                                    Obx(() {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const SizedBox(height: 8),
                                          _SourceTabs(
                                            index: controller
                                                .secondaryTabIndex.value,
                                            onChanged:
                                                controller.setSecondaryTab,
                                            cs: cs,
                                          ),
                                          const SizedBox(height: 14),
                                          controller.secondaryTabIndex.value ==
                                                  0
                                              ? _M3uSecondaryTab(
                                                  controller: controller,
                                                  denseStyle: _denseFieldStyle,
                                                  cs: cs,
                                                )
                                              : _XtreamSecondaryTab(
                                                  controller: controller,
                                                  denseStyle: _denseFieldStyle,
                                                  cs: cs,
                                                ),
                                        ],
                                      );
                                    }),
                                ],
                              );
                            }),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Obx(
                          () => _GlassButton(
                            onPressed: controller.isLoading.value
                                ? null
                                : controller.submit,
                            isLoading: controller.isLoading.value,
                            label: controller.isLoading.value
                                ? 'common.loading'.tr
                                : 'playlist.loadList'.tr,
                            icon: Icons.rocket_launch_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        );
      }),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xEE0F172A),
                const Color(0xE6121824),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final bool isLoading;

  const _GlassButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: onPressed != null
                    ? [
                        Color.lerp(primary, Colors.white, 0.12)!,
                        primary,
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.08),
                      ],
              ),
              boxShadow: onPressed != null
                  ? [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.55),
                        blurRadius: 18,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
              border: Border.all(
                color: onPressed != null
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.18),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceTabs extends StatelessWidget {
  const _SourceTabs({
    required this.index,
    required this.onChanged,
    required this.cs,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: 'M3U',
              selected: index == 0,
              onTap: () => onChanged(0),
              cs: cs,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabChip(
              label: 'Xtream',
              selected: index == 1,
              onTap: () => onChanged(1),
              cs: cs,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? cs.primary.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? Colors.white.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.14),
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : const Color(0xFFE2E8F0),
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _M3uTab extends StatelessWidget {
  const _M3uTab({
    required this.controller,
    required this.denseStyle,
    required this.cs,
  });

  final PlaylistController controller;
  final TextStyle denseStyle;
  final ColorScheme cs;

  InputDecoration _fieldDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
        filled: true,
        fillColor: const Color(0xD9070D14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller.m3uUrlController,
          style: denseStyle,
          decoration: _fieldDecoration('playlist.m3uUrl'.tr, Icons.link_rounded),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => controller.submit(),
        ),
        const SizedBox(height: 16),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xD9070D14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.26),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: controller.pickM3uFile,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      color: cs.primary.withValues(alpha: 0.95),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'playlist.pickFile'.tr,
                      style: const TextStyle(
                        color: Color(0xFFF1F5F9),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Obx(() {
          final name = controller.m3uLocalFileName.value;
          if (name == null || name.isEmpty) {
            return Text(
              'playlist.noFile'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            );
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.file_present_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.white70),
                  onPressed: controller.clearPickedM3uFile,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _XtreamTab extends StatelessWidget {
  const _XtreamTab({
    required this.controller,
    required this.denseStyle,
    required this.cs,
  });

  final PlaylistController controller;
  final TextStyle denseStyle;
  final ColorScheme cs;

  InputDecoration _fieldDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
        filled: true,
        fillColor: const Color(0xD9070D14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller.xtreamBaseUrlController,
          style: denseStyle,
          decoration:
              _fieldDecoration('playlist.xtream.server'.tr, Icons.dns_rounded),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.xtreamUsernameController,
          style: denseStyle,
          decoration:
              _fieldDecoration('playlist.xtream.user'.tr, Icons.person_outline_rounded),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.xtreamPasswordController,
          style: denseStyle,
          decoration:
              _fieldDecoration('playlist.xtream.pass'.tr, Icons.lock_outline_rounded),
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => controller.submit(),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: cs.primary.withValues(alpha: 0.95),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'playlist.xtream.hint'.tr,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _M3uSecondaryTab extends StatelessWidget {
  const _M3uSecondaryTab({
    required this.controller,
    required this.denseStyle,
    required this.cs,
  });

  final PlaylistController controller;
  final TextStyle denseStyle;
  final ColorScheme cs;

  InputDecoration _fieldDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
        filled: true,
        fillColor: const Color(0xD9070D14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller.m3uSecondaryUrlController,
          style: denseStyle,
          decoration: _fieldDecoration(
            'playlist.secondaryUrlHint'.tr,
            Icons.link_rounded,
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => controller.submit(),
        ),
        const SizedBox(height: 16),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xD9070D14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.26),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: controller.pickM3uSecondaryFile,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      color: cs.primary.withValues(alpha: 0.95),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'playlist.pickFile'.tr,
                      style: const TextStyle(
                        color: Color(0xFFF1F5F9),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Obx(() {
          final name = controller.m3uSecondaryLocalFileName.value;
          if (name == null || name.isEmpty) {
            return Text(
              'playlist.noFile'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            );
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.file_present_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.white70),
                  onPressed: controller.clearPickedM3uSecondaryFile,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _XtreamSecondaryTab extends StatelessWidget {
  const _XtreamSecondaryTab({
    required this.controller,
    required this.denseStyle,
    required this.cs,
  });

  final PlaylistController controller;
  final TextStyle denseStyle;
  final ColorScheme cs;

  InputDecoration _fieldDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
        filled: true,
        fillColor: const Color(0xD9070D14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller.xtreamSecondaryBaseUrlController,
          style: denseStyle,
          decoration:
              _fieldDecoration('playlist.xtream.server'.tr, Icons.dns_rounded),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.xtreamSecondaryUsernameController,
          style: denseStyle,
          decoration: _fieldDecoration(
              'playlist.xtream.user'.tr, Icons.person_outline_rounded),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.xtreamSecondaryPasswordController,
          style: denseStyle,
          decoration: _fieldDecoration(
              'playlist.xtream.pass'.tr, Icons.lock_outline_rounded),
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => controller.submit(),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: cs.primary.withValues(alpha: 0.95),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'playlist.xtream.hint'.tr,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
