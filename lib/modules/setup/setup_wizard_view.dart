import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/i18n/theme_label_localized.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_appearance.dart';
import '../../ui/glass_overlays.dart';
import '../playlist/playlist_view.dart';
import 'setup_wizard_controller.dart';

/// Mobil kurulum sihirbazı: dil → tema → varsayılan oynatıcı → kaynak (M3U/Xtream).
class SetupWizardView extends StatefulWidget {
  const SetupWizardView({super.key});

  @override
  State<SetupWizardView> createState() => _SetupWizardViewState();
}

class _SetupWizardViewState extends State<SetupWizardView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<SetupWizardController>();
    final cs = Theme.of(context).colorScheme;
    final app = Get.find<AppSettingsService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Obx(() {
            final themeLabel = app.themeLabel.value;
            return Container(
              decoration: AppTheme.screenBackground(
                context,
                cs,
                themeLabel: themeLabel,
              ),
            );
          }),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: Colors.black.withValues(alpha: 0.22),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'setup.wizardTitle'.tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Obx(() {
                        final i = ctrl.pageIndex.value;
                        final key = switch (i) {
                          0 => 'setup.stepLanguage',
                          1 => 'setup.stepTheme',
                          2 => 'setup.stepPlayer',
                          _ => 'setup.stepSource',
                        };
                        return Text(
                          key.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Obx(() {
                        final v = (ctrl.pageIndex.value + 1) /
                            SetupWizardController.totalPages;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: v.clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              cs.primary.withValues(alpha: 0.95),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (i) {
                      ctrl.syncPage(i);
                      if (i == 3) {
                        ctrl.ensurePlaylistHook();
                      }
                    },
                    children: [
                      _SetupLanguagePage(app: app),
                      _SetupThemePage(app: app),
                      _SetupPlayerPage(app: app),
                      _SetupSourcePage(),
                    ],
                  ),
                ),
                _IosWizardFooter(
                  pageController: _pageController,
                  ctrl: ctrl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupSourcePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'setup.sourceHint'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Expanded(
            child: PlaylistView(setupWizardEmbed: true),
          ),
        ],
      ),
    );
  }
}

class _SetupLanguagePage extends StatelessWidget {
  const _SetupLanguagePage({required this.app});

  final AppSettingsService app;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: _GlassPanel(
        child: Obx(
          () {
            final cur = app.languageCode.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in <({String code, String labelTr})>[
                  (code: 'tr', labelTr: 'common.lang.tr'),
                  (code: 'en', labelTr: 'common.lang.en'),
                  (code: 'fr', labelTr: 'common.lang.fr'),
                  (code: 'ar', labelTr: 'common.lang.ar'),
                  (code: 'zh', labelTr: 'common.lang.zh'),
                  (code: 'ru', labelTr: 'common.lang.ru'),
                  (code: 'ja', labelTr: 'common.lang.ja'),
                  (code: 'es', labelTr: 'common.lang.es'),
                  (code: 'ko', labelTr: 'common.lang.ko'),
                  (code: 'he', labelTr: 'common.lang.he'),
                  (code: 'da', labelTr: 'common.lang.da'),
                  (code: 'sv', labelTr: 'common.lang.sv'),
                  (code: 'hi', labelTr: 'common.lang.hi'),
                  (code: 'th', labelTr: 'common.lang.th'),
                  (code: 'it', labelTr: 'common.lang.it'),
                  (code: 'pt', labelTr: 'common.lang.pt'),
                  (code: 'id', labelTr: 'common.lang.id'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: GlassListTile(
                      title: Text(e.labelTr.tr),
                      trailing: cur == e.code
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : null,
                      selected: cur == e.code,
                      onTap: () => app.setLanguageCode(e.code),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SetupThemePage extends StatelessWidget {
  const _SetupThemePage({required this.app});

  final AppSettingsService app;

  @override
  Widget build(BuildContext context) {
    final themes = <String>[
      GlassThemeLabels.varsayilan,
      'Koyu Cam',
      GlassThemeLabels.glassmorphism,
      GlassThemeLabels.darkFlat,
      GlassThemeLabels.flatBlack,
      GlassThemeLabels.glassGri,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: _GlassPanel(
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in themes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GlassListTile(
                    title: Text(localizedThemeStorageLabel(t)),
                    trailing: app.themeLabel.value == t
                        ? const Icon(Icons.check_rounded, color: Colors.white)
                        : null,
                    selected: app.themeLabel.value == t,
                    onTap: () => app.setThemeLabel(t),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupPlayerPage extends StatelessWidget {
  const _SetupPlayerPage({required this.app});

  final AppSettingsService app;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 10.0;
          final h = (constraints.maxHeight - gap) * 0.25;
          final tileH = h.clamp(64.0, 132.0);
          return Obx(
            () => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: tileH,
                    child: _playerTile(
                      context,
                      title: 'setup.playerExoTitle'.tr,
                      subtitle: 'setup.playerExoSub'.tr,
                      selected: !app.useMediaKit.value,
                      onTap: () => app.setUseMediaKit(false),
                      cs: cs,
                    ),
                  ),
                  const SizedBox(height: gap),
                  SizedBox(
                    height: tileH,
                    child: _playerTile(
                      context,
                      title: 'setup.playerMkvTitle'.tr,
                      subtitle: 'setup.playerMkvSub'.tr,
                      selected: app.useMediaKit.value,
                      onTap: () => app.setUseMediaKit(true),
                      cs: cs,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _playerTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
            color: selected
                ? cs.primary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: cs.primary,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xB30F172A),
                const Color(0x9A0B1220),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _IosWizardFooter extends StatelessWidget {
  const _IosWizardFooter({
    required this.pageController,
    required this.ctrl,
  });

  final PageController pageController;
  final SetupWizardController ctrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Obx(() {
        final i = ctrl.pageIndex.value;
        final canFinish = ctrl.canCompleteSetup.value;
        final last = i >= SetupWizardController.totalPages - 1;
        final primaryEnabled = !last || canFinish;
        return Row(
          children: [
            if (i > 0)
              CupertinoButton(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onPressed: () {
                  pageController.previousPage(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: Text(
                  'setup.back'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              const SizedBox(width: 8),
            const Spacer(),
            Opacity(
              opacity: primaryEnabled ? 1 : 0.5,
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                onPressed: last
                    ? () {
                        unawaited(ctrl.tryCompleteSetup());
                      }
                    : () {
                        pageController.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      },
                child: Text(
                  last ? 'setup.finish'.tr : 'setup.next'.tr,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
