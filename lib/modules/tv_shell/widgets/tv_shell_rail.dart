import 'dart:math' as math;
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_settings_service.dart';
import '../../../core/tv/tv_shell_section.dart';
import '../../../ui/tv_shell_rail_icon.dart';
import '../tv_shell_controller.dart';
import 'tv_shell_interactive.dart';
import 'tv_shell_motion.dart';
import 'tv_shell_palette.dart';
import 'tv_shell_perf.dart';

const _kLogoAsset = 'assets/images/new_logo.png';

/// Daraltılmış rail: ikon + minimum yatay dolgu.
const double kTvShellRailCollapsedWidth = 76;

/// Kategori listesi panel genişliği (rail hemen sağı).
const double kTvShellCategoryPanelWidth = 272;

/// Daraltılmış rail (yerel alias).
const double _kRailCollapsedWidth = kTvShellRailCollapsedWidth;

/// Genişletilmiş rail: en uzun çeviri etiketine göre (dil değişince yeniden ölçülür).
double _railExpandedWidth(BuildContext context, TvShellPalette palette) {
  const minW = 148.0;
  const maxW = 228.0;

  final textDir = Directionality.of(context);
  final labelStyle = palette.bodyStyle(size: 15, weight: FontWeight.w600);
  const brandFontSize = 18.0;
  final brandStyle = palette.titleStyle(size: brandFontSize);
  final brandLabel = 'tvShell.brand'.tr;

  double measure(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: textDir,
    )..layout();
    return tp.width;
  }

  var maxLabel = measure(brandLabel, brandStyle);
  for (final section in TvShellSection.values) {
    maxLabel = math.max(maxLabel, measure(section.labelKey.tr, labelStyle));
  }

  // Liste (8×2) + satır (10×2) + ikon + boşluk + metin
  const listPad = 16.0;
  const tilePad = 20.0;
  const iconBlock = 26.0 + 10.0;
  final fromLabels = listPad + tilePad + iconBlock + maxLabel;

  // Marka çerçevesi: dış pad + çerçeve pad + logo + boşluk + metin
  const brandOuterPad = 16.0;
  const brandFramePad = 16.0;
  const brandLogo = 36.0 + 8.0;
  final fromBrand = brandOuterPad +
      brandFramePad +
      brandLogo +
      measure(brandLabel, brandStyle);

  return math.max(minW, math.min(maxW, math.max(fromLabels, fromBrand)));
}

/// Sol menü: Mina Player + arama + canlı/film/dizi/playlist + ayarlar.
class TvShellRail extends StatelessWidget {
  const TvShellRail({
    super.key,
    required this.controller,
    required this.onSectionActivate,
  });

  final TvShellController controller;
  final void Function(TvShellSection section) onSectionActivate;

  @override
  Widget build(BuildContext context) {
    return TvShellThemed(
      builder: (context, palette) {
        return Obx(() {
          Get.find<AppSettingsService>().languageCode.value;
          final settings = Get.find<AppSettingsService>();
          final wrappedEnabled = settings.minaWrappedEnabled.value && settings.showTvRailWrapper.value;
          final sections = _railSections(
            wrappedEnabled: wrappedEnabled,
            showPlaylists: settings.showTvRailPlaylists.value,
            showRepeat: settings.showTvRailRepeat.value,
            showContinueWatching: settings.showTvRailContinueWatching.value,
          );

          final expanded = controller.railExpanded.value;
          final w = expanded ? _railExpandedWidth(context, palette) : _kRailCollapsedWidth;

          Widget content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),
              _BrandHeader(
                expanded: expanded,
                palette: palette,
                onTap: () {
                  if (expanded) {
                    if (tvShellTouchInputEnabled(context)) {
                      controller.collapseRail();
                    }
                  } else {
                    controller.expandRail();
                  }
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      if (i > 0) const SizedBox(height: 4),
                      _buildRailTile(
                        context: context,
                        palette: palette,
                        expanded: expanded,
                        sections: sections,
                        section: sections[i],
                        index: i,
                        onSectionActivate: onSectionActivate,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          if (palette.ga.isTrabzon) {
            content = ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: content,
              ),
            );
          }

          return TvShellAnimBox(
            duration: TvShellPerf.railWidth,
            curve: TvShellMotion.panelCurve,
            constraints: BoxConstraints.tightFor(width: w),
            decoration: palette.sidePanelDecoration(),
            child: content,
          );
        });
      },
    );
  }

  static List<TvShellSection> _railSections({
    required bool wrappedEnabled,
    required bool showPlaylists,
    required bool showRepeat,
    required bool showContinueWatching,
  }) =>
      [
        TvShellSection.search,
        TvShellSection.live,
        TvShellSection.movies,
        TvShellSection.series,
        if (showContinueWatching) TvShellSection.continueWatching,
        if (showPlaylists) TvShellSection.playlists,
        if (wrappedEnabled) TvShellSection.wrapper,
        if (showRepeat) TvShellSection.repeat,
        TvShellSection.settings,
      ];

  Widget _buildRailTile({
    required BuildContext context,
    required TvShellPalette palette,
    required bool expanded,
    required List<TvShellSection> sections,
    required TvShellSection section,
    required int index,
    required void Function(TvShellSection section) onSectionActivate,
  }) {
    final focusNode = controller.railFocusNodes[section]!;
    FocusNode? neighbor(int delta) {
      final j = index + delta;
      if (j < 0 || j >= sections.length) return null;
      return controller.railFocusNodes[sections[j]]!;
    }

    return _RailTile(
      palette: palette,
      section: section,
      expanded: expanded,
      selected: controller.selectedSection.value == section,
      focusNode: focusNode,
      dpadUp: index > 0 ? neighbor(-1) : null,
      dpadDown: index < sections.length - 1 ? neighbor(1) : null,
      blockDpadUp: index == 0,
      blockDpadDown: index >= sections.length - 1,
      onPressed: () => onSectionActivate(section),
      onRemoteRight: () {
        if (section == TvShellSection.search) return;
        if (section == TvShellSection.settings) {
          controller.enterSettingsPanel(context: context);
          return;
        }
        controller.selectRailSection(section, context: context);
        if (section == TvShellSection.playlists) {
          controller.focusPlaylistsFirstRow(context: context);
        }
      },
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.expanded,
    required this.palette,
    this.onTap,
  });

  final bool expanded;
  final TvShellPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const brandFontSize = 18.0;
    final brandLabel = 'tvShell.brand'.tr;
    final logoSize = expanded ? 36.0 : 32.0;

    final brandRow = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 8 : 0,
        vertical: expanded ? 7 : 8,
      ),
      decoration: palette.navRowDecoration(selected: false, radius: 10),
      child: expanded
          ? Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    _kLogoAsset,
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      brandLabel,
                      maxLines: 1,
                      style: palette.titleStyle(size: brandFontSize),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  _kLogoAsset,
                  width: logoSize,
                  height: logoSize,
                  fit: BoxFit.cover,
                ),
              ),
            ),
    );

    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 8 : 6),
      child: brandRow,
    );

    if (onTap == null) return content;

    // Kumanda modunda marka satırı asla odak almaz; yalnızca dokunmatikte
    // rail genişlet/daralt.
    if (!tvShellUsesRemoteNav(context)) {
      return tvShellTouchableInk(
        onPressed: onTap,
        borderRadius: 10,
        splashColor: palette.accent.withValues(alpha: 0.16),
        highlightColor: palette.accent.withValues(alpha: 0.08),
        child: content,
      );
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: content,
    );
  }
}

class _RailTile extends StatefulWidget {
  const _RailTile({
    required this.palette,
    required this.section,
    required this.expanded,
    required this.selected,
    required this.focusNode,
    required this.onPressed,
    required this.onRemoteRight,
    this.dpadUp,
    this.dpadDown,
    this.blockDpadUp = false,
    this.blockDpadDown = false,
  });

  final TvShellPalette palette;
  final TvShellSection section;
  final bool expanded;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final VoidCallback onRemoteRight;
  final FocusNode? dpadUp;
  final FocusNode? dpadDown;
  final bool blockDpadUp;
  final bool blockDpadDown;

  @override
  State<_RailTile> createState() => _RailTileState();
}

class _RailTileState extends State<_RailTile> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _RailTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.section.labelKey.tr;
    final focused = widget.focusNode.hasFocus;
    final emphasized = focused || widget.selected;
    final iconColor = emphasized
        ? widget.palette.title
        : widget.palette.title.withValues(alpha: 0.62);
    final icon = TvShellRailIcon(
      section: widget.section,
      color: iconColor,
      size: widget.expanded ? 24 : 26,
      strokeWidth: emphasized ? 2.0 : 1.75,
    );

    return TvShellInteractive(
      focusNode: widget.focusNode,
      onPressed: widget.onPressed,
      onRemoteRight: widget.onRemoteRight,
      dpadUp: widget.dpadUp,
      dpadDown: widget.dpadDown,
      blockDpadUp: widget.blockDpadUp,
      blockDpadDown: widget.blockDpadDown,
      borderRadius: 14,
      minHeight: 50,
      showFocusRing: false,
      splashColor: widget.palette.accent.withValues(alpha: 0.18),
      highlightColor: widget.palette.accent.withValues(alpha: 0.10),
      child: TvShellAnimBox(
        duration: TvShellMotion.rowSelectDuration,
        curve: TvShellMotion.panelCurve,
        decoration: _railTileDecoration(
          widget.palette,
          focused: focused,
          selected: widget.selected,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 10 : 6,
            vertical: widget.expanded ? 9 : 8,
          ),
          child: widget.expanded
              ? Row(
                  children: [
                    SizedBox(width: 34, child: Center(child: icon)),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: TvShellPerf.animations
                            ? TvShellMotion.panelDuration
                            : Duration.zero,
                        switchInCurve: TvShellMotion.panelCurve,
                        switchOutCurve: TvShellMotion.panelOutCurve,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axis: Axis.horizontal,
                            axisAlignment: -1,
                            child: child,
                          ),
                        ),
                        child: widget.expanded
                            ? Padding(
                                key: ValueKey<String>(
                                    'rail_label_${widget.section.name}'),
                                padding: const EdgeInsets.only(left: 4),
                                child: _MarqueeText(
                                  text: label,
                                  focused: focused,
                                  style: widget.palette
                                      .bodyStyle(
                                        size: 13.5,
                                        weight: FontWeight.w600,
                                      )
                                      .copyWith(
                                        color: widget.palette
                                            .navRowTextColor(emphasized),
                                      ),
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey<String>('rail_label_hidden'),
                              ),
                      ),
                    ),
                  ],
                )
              : Center(child: icon),
        ),
      ),
    );
  }
}

BoxDecoration _railTileDecoration(
  TvShellPalette palette, {
  required bool focused,
  required bool selected,
}) {
  final accent = palette.accent;
  if (focused) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: 0.95), width: 2),
      color: accent.withValues(alpha: 0.16),
    );
  }
  if (selected) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.25),
      color: accent.withValues(alpha: 0.1),
    );
  }
  return const BoxDecoration(color: Colors.transparent);
}

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool focused;

  const _MarqueeText({
    required this.text,
    required this.style,
    required this.focused,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void didUpdateWidget(covariant _MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focused != widget.focused) {
      if (widget.focused) {
        _startScrolling();
      } else {
        _stopScrolling();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() {
    _timer?.cancel();
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(0);
    _timer = Timer(const Duration(seconds: 1), () async {
      if (!mounted || !widget.focused || !_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: (maxScroll * 35).toInt()),
        curve: Curves.linear,
      );

      if (!mounted || !widget.focused) return;
      _timer = Timer(const Duration(seconds: 1), () {
        if (!mounted || !widget.focused || !_scrollController.hasClients) return;
        _scrollController.jumpTo(0);
        _startScrolling();
      });
    });
  }

  void _stopScrolling() {
    _timer?.cancel();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
