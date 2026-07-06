import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/tv/tv_shell_section.dart';
import '../home/home_controller.dart';
import '../settings/settings_view.dart';
import 'tv_shell_controller.dart';
import 'widgets/tv_shell_category_panel.dart';
import 'widgets/tv_shell_live_panel.dart';
import 'widgets/tv_shell_motion.dart';
import 'widgets/tv_shell_palette.dart';
import 'widgets/tv_shell_movies_cinema_panel.dart';
import 'widgets/tv_shell_movies_panel.dart';
import 'widgets/tv_shell_series_cinema_panel.dart';
import 'widgets/tv_shell_series_panel.dart';
import 'widgets/tv_shell_playlists_panel.dart';
import 'widgets/tv_shell_continue_watching_panel.dart';
import 'widgets/tv_shell_rail.dart';

class _TvShellBackIntent extends Intent {
  const _TvShellBackIntent();
}

/// TV ana kabuğu — sol menü + dinamik sağ panel.
class TvShellView extends GetView<TvShellController> {
  const TvShellView({super.key, required this.homeController});

  final HomeController homeController;

  Widget _buildRightPanel(
    BuildContext context, {
    required bool showSettings,
    required bool showPlaylists,
    required bool showMoviesContent,
    required bool showSeriesContent,
    required bool showLive,
    required bool showLiveBrowse,
    required bool showMoviesBrowse,
    required bool showSeriesBrowse,
    required bool showCats,
    required TvShellSection section,
  }) {
    if (showSettings) {
      return const SettingsView(embeddedInTvShell: true);
    }
    if (showPlaylists) {
      return TvShellPlaylistsPanel(shell: controller);
    }
    if (section == TvShellSection.continueWatching) {
      return TvShellContinueWatchingPanel(
        controller: controller,
        palette: TvShellPalette.of(context),
        onBack: () => controller.onBack(),
      );
    }
    if (showMoviesContent) {
      return TvShellMoviesCinemaPanel(shell: controller);
    }
    if (showSeriesContent) {
      return TvShellSeriesCinemaPanel(shell: controller);
    }
    if (showLive) {
      return TvShellLivePanel(
        shell: controller,
        channels: controller.channels,
      );
    }
    if (showLiveBrowse) {
      return TvShellLivePanel(
        shell: controller,
        channels: controller.channels,
        compact: true,
        browseMode: true,
      );
    }
    if (showMoviesBrowse) {
      return TvShellMoviesBrowsePanel(shell: controller);
    }
    if (showSeriesBrowse) {
      return TvShellSeriesBrowsePanel(shell: controller);
    }
    return TvShellThemed(
      builder: (context, palette) => Container(
        decoration: palette.contentBackdropDecoration(),
        alignment: Alignment.center,
        child: showCats
            ? const SizedBox.shrink()
            : Text(
                'tvShell.hint.selectSection'.tr,
                style: palette.mutedStyle(size: 14),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.goBack): _TvShellBackIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _TvShellBackIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonB): _TvShellBackIntent(),
      },
      child: Actions(
        actions: {
          _TvShellBackIntent: CallbackAction<_TvShellBackIntent>(
            onInvoke: (_) {
              controller.onBack();
              return null;
            },
          ),
        },
        child: PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        controller.onBack();
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() => TvShellCollapsingPanel(
                visible: controller.showsRail,
                child: TvShellRail(
                  controller: controller,
                  onSectionActivate: (s) {
                    if (s == TvShellSection.search) {
                      controller.openSearch(context);
                      return;
                    }
                    if (s == TvShellSection.wrapper) {
                      controller.openMinaWrapper();
                      return;
                    }
                    if (s == TvShellSection.repeat) {
                      controller.openEpgMix();
                      return;
                    }
                    controller.selectRailSection(s, context: context);
                  },
                ),
              )),
          Obx(() => TvShellCollapsingPanel(
                visible: controller.showsCategoryPanel,
                width: kTvShellCategoryPanelWidth,
                child: TvShellCategoryPanel(
                  controller: controller,
                  section: controller.selectedSection.value,
                ),
              )),
          Expanded(
            child: ClipRect(
              child: Obx(() {
                final section = controller.selectedSection.value;
                final showCats = controller.showsCategoryPanel;
                final showLive = controller.showsLiveContent;
                final showLiveBrowse = controller.showsLiveBrowsePanel;
                final showMoviesBrowse = controller.showsMoviesBrowsePanel;
                final showMoviesContent = controller.showsMoviesContentPanel;
                final showSeriesBrowse = controller.showsSeriesBrowsePanel;
                final showSeriesContent = controller.showsSeriesContentPanel;
                final showSettings = controller.showsSettingsPanel;
                final showPlaylists = controller.showsPlaylistsPanel;
                final panelKey = controller.panelTransitionKey;

                return TvShellPanelTransition(
                  transitionKey: panelKey,
                  child: _buildRightPanel(
                    context,
                    showSettings: showSettings,
                    showPlaylists: showPlaylists,
                    showMoviesContent: showMoviesContent,
                    showSeriesContent: showSeriesContent,
                    showLive: showLive,
                    showLiveBrowse: showLiveBrowse,
                    showMoviesBrowse: showMoviesBrowse,
                    showSeriesBrowse: showSeriesBrowse,
                    showCats: showCats,
                    section: section,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
