import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_image_cache_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/mina_analytics_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../services/user_history_service.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart'
    show TvDpadFocus, scheduleTvFocusRestore, tvDpadActivateWrap, tvSettingsBackButton;
import 'mina_analytics_controller.dart';
import 'mina_wrapped_insights.dart';

/// **Mina Wrapped & İzleme Analitiği sayfası.**
///
/// Tasarım dili: Mina Glass — `SettingsGlassPanel` ana çerçeve;
/// kartlar yarısaydam beyaz katman + ince border + 14 px köşe yarıçapı.
/// Neon vurgu rengi `Theme.primary` üzerinden gelir.
///
/// Sayfa içeriği (yukarıdan aşağı):
///
/// 1. **Range seçici** — Haftalık / Aylık / Yıllık segment.
/// 2. **Özet kartı** — Toplam saatler + üç kind ayrımı.
/// 3. **İzleme dağılımı** — Canlı / Film / Dizi yatay ilerleme çubukları.
/// 4. **Top kanallar** — Podyum (1.→2.→3.) + minik logo.
/// 5. **Alışkanlık** — En çok izlenen gün + saat dilimi (sabah/öğle/akşam/gece).
/// 6. **Günlük grafiği** — Son 7/30/365 gün bar chart (Container'larla).
/// 7. **Türler** — Top 3 kategori (Aksiyon, Spor…) minik chip listesi.
/// 8. **Paylaş** — `share_plus` ile özet metin paylaşımı.
/// 9. **Gizlilik** — Toggle + verileri sıfırla butonu.
class MinaAnalyticsView extends StatelessWidget {
  const MinaAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<MinaAnalyticsController>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ThemedSettingsBackground(
          child: SafeArea(
            child: SettingsGlassPanel(
              child: _MinaAnalyticsShell(controller: c),
            ),
          ),
        ),
      ),
    );
  }
}

/// TV kumandası: geri, aralık seçici ve kaydırılabilir kartlar arasında
/// dikey/yatay odak zinciri.
class _MinaAnalyticsShell extends StatefulWidget {
  const _MinaAnalyticsShell({required this.controller});

  final MinaAnalyticsController controller;

  @override
  State<_MinaAnalyticsShell> createState() => _MinaAnalyticsShellState();
}

class _MinaAnalyticsShellState extends State<_MinaAnalyticsShell> {
  final _scroll = ScrollController();
  final _backFocus = FocusNode(debugLabel: 'analyticsBack');
  final _rangeWeek = FocusNode(debugLabel: 'analyticsRangeWeek');
  final _rangeMonth = FocusNode(debugLabel: 'analyticsRangeMonth');
  final _rangeYear = FocusNode(debugLabel: 'analyticsRangeYear');
  final _persona = FocusNode(debugLabel: 'analyticsPersona');
  final _summary = FocusNode(debugLabel: 'analyticsSummary');
  final _breakdown = FocusNode(debugLabel: 'analyticsBreakdown');
  final _timeline = FocusNode(debugLabel: 'analyticsTimeline');
  final _topChannels = FocusNode(debugLabel: 'analyticsTopChannels');
  final _habits = FocusNode(debugLabel: 'analyticsHabits');
  final _dailyBars = FocusNode(debugLabel: 'analyticsDailyBars');
  final _topCategories = FocusNode(debugLabel: 'analyticsTopCategories');
  final _share = FocusNode(debugLabel: 'analyticsShare');
  final _privacyToggle = FocusNode(debugLabel: 'analyticsPrivacyToggle');
  final _privacyClear = FocusNode(debugLabel: 'analyticsPrivacyClear');
  final _dataUsage = FocusNode(debugLabel: 'analyticsDataUsage');
  final Map<FocusNode, GlobalKey> _nodeKeys = {};

  GlobalKey _keyFor(FocusNode node) =>
      _nodeKeys.putIfAbsent(node, GlobalKey.new);

  @override
  void dispose() {
    _scroll.dispose();
    _backFocus.dispose();
    _rangeWeek.dispose();
    _rangeMonth.dispose();
    _rangeYear.dispose();
    _persona.dispose();
    _summary.dispose();
    _breakdown.dispose();
    _timeline.dispose();
    _topChannels.dispose();
    _habits.dispose();
    _dailyBars.dispose();
    _topCategories.dispose();
    _share.dispose();
    _privacyToggle.dispose();
    _privacyClear.dispose();
    _dataUsage.dispose();
    super.dispose();
  }

  bool _remoteNav(BuildContext context) => remoteNavForScreenLayout(
        context,
        Get.find<AppSettingsService>().layoutMode.value,
      );

  List<FocusNode> _verticalChain() {
    final snap = widget.controller.snapshot.value;
    final timeline = widget.controller.timeline;
    final isTvMode = Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
    final chain = <FocusNode>[];
    if (!isTvMode) {
      chain.add(_backFocus);
    }
    chain.addAll([
      _rangeWeek,
      _rangeMonth,
      _rangeYear,
      _persona,
      _summary,
    ]);
    if (snap.totalMinutes >= 1) chain.add(_breakdown);
    if (timeline.isNotEmpty) chain.add(_timeline);
    chain.add(_topChannels);
    if (snap.totalMinutes >= 1) chain.add(_habits);
    chain.add(_dailyBars);
    if (snap.topCategories.isNotEmpty) chain.add(_topCategories);
    chain
      ..add(_share)
      ..add(_privacyToggle)
      ..add(_privacyClear)
      ..add(_dataUsage);
    return chain;
  }

  void _focusWithScroll(FocusNode node) {
    final key = _keyFor(node);
    void attemptFocus() {
      if (!mounted) return;
      final ctx = key.currentContext ?? node.context;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.22,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
      if (node.canRequestFocus) {
        node.requestFocus();
      }
      if (!node.hasFocus) {
        scheduleTvFocusRestore(node, maxAttempts: 16);
      }
    }

    attemptFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => attemptFocus());
  }

  KeyEventResult _handleVertical(FocusNode self, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k != LogicalKeyboardKey.arrowUp &&
        k != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    final chain = _verticalChain();
    final i = chain.indexOf(self);
    if (i < 0) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.arrowUp) {
      if (i <= 0) return KeyEventResult.handled;
      _focusWithScroll(chain[i - 1]);
      return KeyEventResult.handled;
    }
    if (i >= chain.length - 1) return KeyEventResult.handled;
    _focusWithScroll(chain[i + 1]);
    return KeyEventResult.handled;
  }

  KeyEventResult _handleNav(
    FocusNode self,
    KeyEvent event, {
    FocusNode? arrowLeft,
    FocusNode? arrowRight,
  }) {
    if (event is KeyRepeatEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.arrowUp ||
          k == LogicalKeyboardKey.arrowDown ||
          k == LogicalKeyboardKey.arrowLeft ||
          k == LogicalKeyboardKey.arrowRight) {
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft && arrowLeft != null) {
      _focusWithScroll(arrowLeft);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight && arrowRight != null) {
      _focusWithScroll(arrowRight);
      return KeyEventResult.handled;
    }
    return _handleVertical(self, event);
  }

  Widget _tvSection({
    required BuildContext context,
    required FocusNode node,
    required Widget child,
    FocusNode? arrowLeft,
    FocusNode? arrowRight,
    VoidCallback? onActivate,
  }) {
    if (!_remoteNav(context)) return child;
    return KeyedSubtree(
      key: _keyFor(node),
      child: TvDpadFocus(
        focusNode: node,
        onActivate: onActivate,
        arrowLeft: arrowLeft,
        arrowRight: arrowRight,
        blockUp: true,
        blockDown: true,
        onKeyEvent: (event) => _handleNav(
          node,
          event,
          arrowLeft: arrowLeft,
          arrowRight: arrowRight,
        ),
        borderRadius: 18,
        ensureVisibleOnFocus: false,
        child: child,
      ),
    );
  }

  List<Widget> _buildScrollChildren(
    BuildContext context,
    MinaAnalyticsSnapshot snap,
  ) {
    final remote = _remoteNav(context);
    final c = widget.controller;
    final report = MinaWrappedEngine.build(snap, formatHours: _formatHours);
    final timeline = c.timeline;
    final sections = <({
      FocusNode node,
      Widget child,
      VoidCallback? onActivate,
    })>[
      (
        node: _persona,
        child: _PersonaHeroCard(report: report),
        onActivate: null,
      ),
      (
        node: _summary,
        child: _SummaryCard(snapshot: snap),
        onActivate: null,
      ),
      if (snap.totalMinutes >= 1)
        (
          node: _breakdown,
          child: _BreakdownCard(snapshot: snap),
          onActivate: null,
        ),
      if (timeline.isNotEmpty)
        (
          node: _timeline,
          child: _TimelineCard(entries: timeline.toList(growable: false)),
          onActivate: null,
        ),
      (
        node: _topChannels,
        child: _TopChannelsCard(snapshot: snap),
        onActivate: null,
      ),
      if (snap.totalMinutes >= 1)
        (
          node: _habits,
          child: _HabitsCard(snapshot: snap),
          onActivate: null,
        ),
      (
        node: _dailyBars,
        child: _DailyBarsCard(snapshot: snap),
        onActivate: null,
      ),
      if (snap.topCategories.isNotEmpty)
        (
          node: _topCategories,
          child: _TopCategoriesCard(snapshot: snap),
          onActivate: null,
        ),
    ];

    final children = <Widget>[];
    for (final s in sections) {
      children.add(
        _tvSection(
          context: context,
          node: s.node,
          onActivate: s.onActivate,
          child: s.child,
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    final shareOnTap = snap.isEmpty ? null : () => _shareSnapshot(snap);
    children
      ..add(
        SizedBox(height: sections.isEmpty ? 0 : 2),
      )
      ..add(
        _tvSection(
          context: context,
          node: _share,
          onActivate: shareOnTap,
          child: _ShareButton(snapshot: snap, tvFocusNode: remote ? _share : null),
        ),
      )
      ..add(const SizedBox(height: 12))
      ..add(
        _PrivacyCard(
          controller: c,
          remoteNav: remote,
          tvToggleFocusNode: remote ? _privacyToggle : null,
          tvClearFocusNode: remote ? _privacyClear : null,
          onClear: () => _confirmClear(context, c),
          onVerticalNav: remote ? _handleVertical : null,
          keyFor: remote ? _keyFor : null,
        ),
      )
      ..add(const SizedBox(height: 12))
      ..add(
        _tvSection(
          context: context,
          node: _dataUsage,
          onActivate: () => Get.toNamed(AppRoutes.dataUsage),
          child: const _DataUsageCard(),
        ),
      );

    return children;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final remote = _remoteNav(context);
    final isTvMode = Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          controller: c,
          backFocusNode: (remote && !isTvMode) ? _backFocus : null,
          onVerticalNav: (remote && !isTvMode) ? _handleVertical : null,
          isTvMode: isTvMode,
        ),
        _RangeSelector(
          controller: c,
          remoteNav: remote,
          weekFocus: remote ? _rangeWeek : null,
          monthFocus: remote ? _rangeMonth : null,
          yearFocus: remote ? _rangeYear : null,
          onVerticalNav: remote ? _handleVertical : null,
          onHorizontalNav: remote ? _handleNav : null,
          autofocusMonth: remote && isTvMode,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Obx(() {
            final snap = c.snapshot.value;
            return ListView(
              controller: _scroll,
              physics: AppScrollPhysics.list(context: context),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              children: _buildScrollChildren(context, snap),
            );
          }),
        ),
      ],
    );
  }
}

Future<void> _shareSnapshot(MinaAnalyticsSnapshot s) async {
  final total = _formatHours(s.totalMinutes);
  final live = _formatHours(s.liveMinutes);
  final vod = _formatHours(s.movieMinutes + s.seriesMinutes);
  final rangeName = switch (s.range) {
    MinaAnalyticsRange.week => 'analytics.range.week'.tr,
    MinaAnalyticsRange.month => 'analytics.range.month'.tr,
    MinaAnalyticsRange.year => 'analytics.range.year'.tr,
  };
  final text = 'analytics.share.text'.trParams({
    'range': rangeName.toLowerCase(),
    'total': total,
    'live': live,
    'vod': vod,
  });
  await SharePlus.instance.share(
    ShareParams(text: text, subject: 'analytics.share.subject'.tr),
  );
}

void _confirmClear(BuildContext context, MinaAnalyticsController controller) {
  Get.dialog<void>(
    AlertDialog(
      backgroundColor: const Color(0xFF1A1A1F),
      title: Text(
        'analytics.privacy.clearConfirm.title'.tr,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: Text(
        'analytics.privacy.clearConfirm.body'.tr,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 13,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back<void>(),
          child: Text('common.cancel'.tr),
        ),
        TextButton(
          onPressed: () async {
            await controller.clearAll();
            Get.back<void>();
          },
          child: Text(
            'analytics.privacy.clear'.tr,
            style: const TextStyle(color: Color(0xFFFF6B6B)),
          ),
        ),
      ],
    ),
  );
}

// =============================================================================
// Header.
// =============================================================================

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    this.backFocusNode,
    this.onVerticalNav,
    required this.isTvMode,
  });

  final MinaAnalyticsController controller;
  final FocusNode? backFocusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onVerticalNav;
  final bool isTvMode;

  @override
  Widget build(BuildContext context) {
    final remote = backFocusNode != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 6),
      child: Row(
        children: [
          if (isTvMode)
            const SizedBox.shrink()
          else if (remote)
            KeyedSubtree(
              key: ValueKey(backFocusNode),
              child: TvDpadFocus(
                focusNode: backFocusNode,
                autofocus: true,
                onActivate: () => Get.back<void>(),
                blockUp: true,
                blockDown: true,
                onKeyEvent: onVerticalNav == null
                    ? null
                    : (event) => onVerticalNav!(backFocusNode!, event),
                borderRadius: 14,
                ensureVisibleOnFocus: false,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Get.back<void>(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white.withValues(alpha: 0.92),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            tvSettingsBackButton(context, autofocus: true),
          if (!isTvMode) const SizedBox(width: 4),
          Icon(
            Icons.insights_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'analytics.title'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Range selector.
// =============================================================================

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.controller,
    this.remoteNav = false,
    this.weekFocus,
    this.monthFocus,
    this.yearFocus,
    this.onVerticalNav,
    this.onHorizontalNav,
    this.autofocusMonth = false,
  });

  final MinaAnalyticsController controller;
  final bool remoteNav;
  final FocusNode? weekFocus;
  final FocusNode? monthFocus;
  final FocusNode? yearFocus;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onVerticalNav;
  final KeyEventResult Function(
    FocusNode node,
    KeyEvent event, {
    FocusNode? arrowLeft,
    FocusNode? arrowRight,
  })? onHorizontalNav;
  final bool autofocusMonth;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.6,
          ),
        ),
        child: Obx(() {
          final current = controller.selectedRange.value;
          return Row(
            children: [
              _RangeButton(
                label: 'analytics.range.week'.tr,
                selected: current == MinaAnalyticsRange.week,
                onTap: () => controller.selectRange(MinaAnalyticsRange.week),
                primary: primary,
                focusNode: weekFocus,
                arrowRight: remoteNav ? monthFocus : null,
                onNav: onHorizontalNav,
              ),
              _RangeButton(
                label: 'analytics.range.month'.tr,
                selected: current == MinaAnalyticsRange.month,
                onTap: () => controller.selectRange(MinaAnalyticsRange.month),
                primary: primary,
                focusNode: monthFocus,
                arrowLeft: remoteNav ? weekFocus : null,
                arrowRight: remoteNav ? yearFocus : null,
                onNav: onHorizontalNav,
                autofocus: autofocusMonth,
              ),
              _RangeButton(
                label: 'analytics.range.year'.tr,
                selected: current == MinaAnalyticsRange.year,
                onTap: () => controller.selectRange(MinaAnalyticsRange.year),
                primary: primary,
                focusNode: yearFocus,
                arrowLeft: remoteNav ? monthFocus : null,
                onNav: onHorizontalNav,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primary,
    this.focusNode,
    this.arrowLeft,
    this.arrowRight,
    this.onNav,
    this.autofocus = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;
  final FocusNode? focusNode;
  final FocusNode? arrowLeft;
  final FocusNode? arrowRight;
  final KeyEventResult Function(
    FocusNode node,
    KeyEvent event, {
    FocusNode? arrowLeft,
    FocusNode? arrowRight,
  })? onNav;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final chip = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(
                    color: primary.withValues(alpha: 0.55),
                    width: 0.6,
                  )
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.65),
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
    if (focusNode != null) {
      return Expanded(
        child: TvDpadFocus(
          focusNode: focusNode,
          autofocus: autofocus,
          onActivate: onTap,
          arrowLeft: arrowLeft,
          arrowRight: arrowRight,
          blockUp: true,
          blockDown: true,
          onKeyEvent: onNav == null
              ? null
              : (event) => onNav!(
                    focusNode!,
                    event,
                    arrowLeft: arrowLeft,
                    arrowRight: arrowRight,
                  ),
          borderRadius: 14,
          ensureVisibleOnFocus: false,
          child: chip,
        ),
      );
    }
    return Expanded(
      child: tvDpadActivateWrap(
        context,
        onActivate: onTap,
        borderRadius: 14,
        child: chip,
      ),
    );
  }
}

// =============================================================================
// Glass card shell.
// =============================================================================

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.icon,
    required this.title,
    required this.child,
    this.accent,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.6,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.withValues(alpha: 0.18),
                  border: Border.all(
                    color: c.withValues(alpha: 0.50),
                    width: 0.6,
                  ),
                ),
                child: Icon(icon, size: 16, color: c),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// =============================================================================
// 1. Özet kartı.
// =============================================================================

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.snapshot});

  final MinaAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.totalMinutes;
    if (total < 1) {
      return _GlassCard(
        icon: Icons.bedtime_outlined,
        title: 'analytics.summary.title'.tr,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'analytics.empty.summary'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      );
    }
    final liveH = _formatHours(snapshot.liveMinutes);
    final movieH = _formatHours(snapshot.movieMinutes);
    final seriesH = _formatHours(snapshot.seriesMinutes);
    return _GlassCard(
      icon: Icons.auto_awesome_rounded,
      title: 'analytics.summary.title'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'analytics.summary.body'.trParams({
              'live': liveH,
              'vod': _formatHours(
                snapshot.movieMinutes + snapshot.seriesMinutes,
              ),
            }),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BigStat(
                  label: 'analytics.kind.live'.tr,
                  value: liveH,
                  color: const Color(0xFFFF3B47),
                  icon: Icons.fiber_smart_record_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BigStat(
                  label: 'analytics.kind.movie'.tr,
                  value: movieH,
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icons.movie_filter_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BigStat(
                  label: 'analytics.kind.series'.tr,
                  value: seriesH,
                  color: const Color(0xFF22C55E),
                  icon: Icons.theaters_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.40),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. İzleme dağılımı — yatay neon çubuklar.
// =============================================================================

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.snapshot});

  final MinaAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final total = snapshot.totalMinutes;
    if (total < 1) return const SizedBox.shrink();
    final live = snapshot.liveMinutes / total;
    final movie = snapshot.movieMinutes / total;
    final series = snapshot.seriesMinutes / total;
    return _GlassCard(
      icon: Icons.donut_large_rounded,
      title: 'analytics.breakdown.title'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NeonBar(
            label: 'analytics.kind.live'.tr,
            ratio: live,
            color: const Color(0xFFFF3B47),
          ),
          const SizedBox(height: 10),
          _NeonBar(
            label: 'analytics.kind.movie'.tr,
            ratio: movie,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 10),
          _NeonBar(
            label: 'analytics.kind.series'.tr,
            ratio: series,
            color: const Color(0xFF22C55E),
          ),
        ],
      ),
    );
  }
}

class _NeonBar extends StatelessWidget {
  const _NeonBar({
    required this.label,
    required this.ratio,
    required this.color,
  });

  final String label;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).clamp(0, 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.65),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '%$pct',
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Container(color: Colors.white.withValues(alpha: 0.06)),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  widthFactor: ratio.clamp(0, 1),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.55),
                          color,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.40),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// 3. Top kanallar — podyum.
// =============================================================================

class _TopChannelsCard extends StatelessWidget {
  const _TopChannelsCard({required this.snapshot});

  final MinaAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final list = snapshot.topChannels;
    if (list.isEmpty) {
      return _GlassCard(
        icon: Icons.emoji_events_rounded,
        title: 'analytics.topChannels.title'.tr,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'analytics.empty.channels'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12.5,
            ),
          ),
        ),
      );
    }
    return _GlassCard(
      icon: Icons.emoji_events_rounded,
      title: 'analytics.topChannels.title'.tr,
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _PodiumRow(rank: i + 1, channel: list[i]),
          ],
        ],
      ),
    );
  }
}

class _PodiumRow extends StatelessWidget {
  const _PodiumRow({required this.rank, required this.channel});

  final int rank;
  final MinaTopChannel channel;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => const Color(0xFFFFD53A),
      2 => const Color(0xFFD0D5DD),
      _ => const Color(0xFFCD7F32),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: medal.withValues(alpha: 0.40),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medal.withValues(alpha: 0.20),
              border: Border.all(
                color: medal.withValues(alpha: 0.70),
                width: 0.7,
              ),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SmallChannelLogo(url: channel.logo, fallback: channel.name),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            _formatHours(channel.minutes),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChannelLogo extends StatelessWidget {
  const _SmallChannelLogo({required this.url, required this.fallback});

  final String url;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final letter = fallback.trim().isEmpty
        ? '?'
        : fallback.trim()[0].toUpperCase();
    final placeholder = Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.5,
        ),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (url.isEmpty) return placeholder;
    return ClipOval(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CachedNetworkImage(
          imageUrl: url,
          cacheKey: AppImageCacheService.cacheKeyFor(url),
          cacheManager: AppImageCacheService.manager,
          fit: BoxFit.cover,
          memCacheWidth: 56,
          memCacheHeight: 56,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          errorWidget: (_, __, ___) => placeholder,
          placeholder: (_, __) => placeholder,
        ),
      ),
    );
  }
}

// =============================================================================
// 4. Alışkanlık kartı.
// =============================================================================

class _HabitsCard extends StatelessWidget {
  const _HabitsCard({required this.snapshot});

  final MinaAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.totalMinutes < 1) return const SizedBox.shrink();
    final dayLabel = _weekdayLabel(snapshot.peakWeekday);
    final periodLabel = _periodLabel(snapshot.peakHour);
    return _GlassCard(
      icon: Icons.psychology_alt_rounded,
      title: 'analytics.habit.title'.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'analytics.habit.body'.trParams({
              'day': dayLabel,
              'period': periodLabel,
            }),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _HourStrip(hourTotals: snapshot.hourTotals),
        ],
      ),
    );
  }
}

class _HourStrip extends StatelessWidget {
  const _HourStrip({required this.hourTotals});

  final List<double> hourTotals;

  @override
  Widget build(BuildContext context) {
    if (hourTotals.length != 24) return const SizedBox.shrink();
    final maxV = hourTotals.fold<double>(0, (a, b) => a > b ? a : b);
    if (maxV < 0.01) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth - 23 * 2) / 24;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 24; i++) ...[
                _HourBar(
                  width: w,
                  ratio: hourTotals[i] / maxV,
                  hour: i,
                  color: primary,
                ),
                if (i < 23) const SizedBox(width: 2),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HourBar extends StatelessWidget {
  const _HourBar({
    required this.width,
    required this.ratio,
    required this.hour,
    required this.color,
  });

  final double width;
  final double ratio;
  final int hour;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final h = (40 * ratio).clamp(2.0, 40.0);
    final c = ratio > 0.05
        ? color.withValues(alpha: 0.40 + ratio * 0.60)
        : Colors.white.withValues(alpha: 0.10);
    return Tooltip(
      message: '${hour.toString().padLeft(2, '0')}:00',
      child: Container(
        width: width.clamp(2.0, 24.0),
        height: h.toDouble(),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// =============================================================================
// 5. Günlük bar chart (range bazlı).
// =============================================================================

class _DailyBarsCard extends StatelessWidget {
  const _DailyBarsCard({required this.snapshot});

  final MinaAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.daySeries.isEmpty) {
      return _GlassCard(
        icon: Icons.show_chart_rounded,
        title: 'analytics.dailyBars.title'.tr,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'analytics.empty.daily'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12.5,
            ),
          ),
        ),
      );
    }
    final since = snapshot.since!;
    final until = snapshot.until!;
    final days = until.difference(since).inDays + 1;
    // Day series'ı normalize et — tüm günler doldurulsun.
    final byKey = {
      for (final p in snapshot.daySeries)
        '${p.day.year.toString().padLeft(4, '0')}-${p.day.month.toString().padLeft(2, '0')}-${p.day.day.toString().padLeft(2, '0')}':
            p.minutes,
    };
    final filled = <double>[];
    for (var i = 0; i < days; i++) {
      final d = since.add(Duration(days: i));
      final k =
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      filled.add(byKey[k] ?? 0);
    }
    final maxV = filled.fold<double>(0, (a, b) => a > b ? a : b);
    final primary = Theme.of(context).colorScheme.primary;
    return _GlassCard(
      icon: Icons.show_chart_rounded,
      title: 'analytics.dailyBars.title'.tr,
      child: SizedBox(
        height: 96,
        child: maxV < 0.01
            ? Center(
                child: Text(
                  'analytics.empty.daily'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, c) {
                  final gap = 2.0;
                  final w =
                      (c.maxWidth - gap * (filled.length - 1)) / filled.length;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < filled.length; i++) ...[
                        Container(
                          width: w.clamp(2.0, 16.0),
                          height: (80 * (filled[i] / maxV))
                              .clamp(2.0, 80.0)
                              .toDouble(),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                primary.withValues(alpha: 0.20),
                                primary.withValues(alpha: 0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        if (i < filled.length - 1) SizedBox(width: gap),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }
}

// =============================================================================
// 6. Top kategoriler chip listesi.
// =============================================================================

class _TopCategoriesCard extends StatelessWidget {
  const _TopCategoriesCard({required this.snapshot});

  final MinaAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cats = snapshot.topCategories;
    if (cats.isEmpty) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;
    return _GlassCard(
      icon: Icons.label_important_rounded,
      title: 'analytics.topCategories.title'.tr,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in cats)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primary.withValues(alpha: 0.45),
                  width: 0.6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tag_rounded,
                    size: 12,
                    color: primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    c.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatHours(c.minutes),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// 7. Share button.
// =============================================================================

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.snapshot,
    this.tvFocusNode,
  });

  final MinaAnalyticsSnapshot snapshot;
  final FocusNode? tvFocusNode;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final share = snapshot.isEmpty ? null : () => _shareSnapshot(snapshot);
    final body = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: share,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [
                primary.withValues(alpha: 0.85),
                primary.withValues(alpha: 0.55),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.40),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.ios_share_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'analytics.share.button'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (share == null) return body;
    if (tvFocusNode != null) return body;
    return tvDpadActivateWrap(
      context,
      onActivate: share,
      borderRadius: 14,
      child: body,
    );
  }
}

// =============================================================================
// 8. Privacy card.
// =============================================================================

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.controller,
    this.remoteNav = false,
    this.tvToggleFocusNode,
    this.tvClearFocusNode,
    this.onClear,
    this.onVerticalNav,
    this.keyFor,
  });

  final MinaAnalyticsController controller;
  final bool remoteNav;
  final FocusNode? tvToggleFocusNode;
  final FocusNode? tvClearFocusNode;
  final VoidCallback? onClear;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onVerticalNav;
  final GlobalKey Function(FocusNode node)? keyFor;

  @override
  Widget build(BuildContext context) {
    final toggleTile = Obx(
      () => remoteNav
          ? ExcludeFocus(
              child: SwitchListTile.adaptive(
                title: Text(
                  'analytics.privacy.collect.title'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'analytics.privacy.collect.sub'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
                value: controller.collectionEnabled.value,
                onChanged: null,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            )
          : SwitchListTile.adaptive(
              title: Text(
                'analytics.privacy.collect.title'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'analytics.privacy.collect.sub'.tr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
              value: controller.collectionEnabled.value,
              onChanged: controller.setCollectionEnabled,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: Theme.of(context).colorScheme.primary,
            ),
    );

    final clearButton = TextButton.icon(
      onPressed: onClear,
      icon: const Icon(
        Icons.delete_sweep_rounded,
        color: Color(0xFFFF6B6B),
        size: 18,
      ),
      label: Text(
        'analytics.privacy.clear'.tr,
        style: const TextStyle(
          color: Color(0xFFFF6B6B),
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    Widget toggleChild = toggleTile;
    Widget clearChild = Align(
      alignment: Alignment.centerLeft,
      child: clearButton,
    );

    if (remoteNav && tvToggleFocusNode != null) {
      toggleChild = KeyedSubtree(
        key: keyFor?.call(tvToggleFocusNode!),
        child: TvDpadFocus(
          focusNode: tvToggleFocusNode,
          blockUp: true,
          blockDown: true,
          onKeyEvent: onVerticalNav == null
              ? null
              : (event) => onVerticalNav!(tvToggleFocusNode!, event),
          onActivate: () => controller.setCollectionEnabled(
            !controller.collectionEnabled.value,
          ),
          borderRadius: 12,
          ensureVisibleOnFocus: false,
          child: toggleTile,
        ),
      );
    }
    if (remoteNav && tvClearFocusNode != null) {
      clearChild = KeyedSubtree(
        key: keyFor?.call(tvClearFocusNode!),
        child: TvDpadFocus(
          focusNode: tvClearFocusNode,
          blockUp: true,
          blockDown: true,
          onKeyEvent: onVerticalNav == null
              ? null
              : (event) => onVerticalNav!(tvClearFocusNode!, event),
          onActivate: onClear,
          borderRadius: 12,
          ensureVisibleOnFocus: false,
          child: clearChild,
        ),
      );
    }

    return _GlassCard(
      icon: Icons.privacy_tip_rounded,
      title: 'analytics.privacy.title'.tr,
      accent: Colors.white.withValues(alpha: 0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          toggleChild,
          const SizedBox(height: 4),
          clearChild,
        ],
      ),
    );
  }
}

// =============================================================================
// Veri Kullanım Detayı — analitik sayfasının en altındaki gezinme kartı.
// =============================================================================

/// İzleme analitiğinin (Mina Wrapped) en altına yerleşen, dokununca «Veri
/// Kullanım Detayı» sayfasına götüren cam kart. Eskiden Ayarlar listesinde ayrı
/// bir satırdı; izleme verileriyle aynı bağlamda olduğu için buraya taşındı.
class _DataUsageCard extends StatelessWidget {
  const _DataUsageCard();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Get.toNamed(AppRoutes.dataUsage),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 0.6,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.18),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.50),
                    width: 0.6,
                  ),
                ),
                child: Icon(
                  Icons.data_usage_rounded,
                  size: 16,
                  color: primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settings.dataUsage.title'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'settings.dataUsage.subtitle'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// AI Persona Hero — Mina Wrapped'ın yıldız kartı.
// =============================================================================

class _PersonaHeroCard extends StatelessWidget {
  const _PersonaHeroCard({required this.report});

  final MinaWrappedReport report;

  @override
  Widget build(BuildContext context) {
    final visual = MinaWrappedEngine.visualOf(report.persona);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            visual.gradient.first.withValues(alpha: 0.92),
            visual.gradient.last.withValues(alpha: 0.78),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: visual.glow.withValues(alpha: 0.40),
            blurRadius: 26,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Dev şeffaf emoji filigranı.
            Positioned(
              right: -14,
              bottom: -26,
              child: Text(
                visual.emoji,
                style: TextStyle(
                  fontSize: 130,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _PersonaBadge(label: 'analytics.wrapped.tag'.tr),
                      const Spacer(),
                      Icon(
                        visual.icon,
                        color: Colors.white.withValues(alpha: 0.85),
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _PersonaEmojiBubble(emoji: visual.emoji),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'analytics.wrapped.youAre'.tr,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              report.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report.tagline,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (report.hasData) ...[
                    const SizedBox(height: 14),
                    _PersonaHighlight(
                      value: report.highlightValue,
                      label: report.highlightLabel,
                    ),
                  ],
                  if (report.insights.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    for (var i = 0; i < report.insights.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _InsightRow(insight: report.insights[i]),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonaBadge extends StatelessWidget {
  const _PersonaBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.30),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonaEmojiBubble extends StatelessWidget {
  const _PersonaEmojiBubble({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.40),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 30)),
    );
  }
}

class _PersonaHighlight extends StatelessWidget {
  const _PersonaHighlight({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 0.6,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});

  final MinaWrappedInsight insight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.16),
          ),
          child: Icon(insight.icon, size: 15, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              insight.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// İzleme Şeridi (Timeline).
// =============================================================================

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entries});

  final List<UserHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _GlassCard(
        icon: Icons.timeline_rounded,
        title: 'analytics.timeline.title'.tr,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'analytics.timeline.empty'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12.5,
            ),
          ),
        ),
      );
    }
    return _GlassCard(
      icon: Icons.timeline_rounded,
      title: 'analytics.timeline.title'.tr,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            _TimelineTile(
              entry: entries[i],
              isFirst: i == 0,
              isLast: i == entries.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.isFirst,
    required this.isLast,
  });

  final UserHistoryEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final style = _kindStyle(entry.kind, context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sol ray: çizgi + nokta.
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: style.color,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: style.color.withValues(alpha: 0.55),
                        blurRadius: 7,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isFirst ? 0 : 8,
                bottom: isLast ? 0 : 8,
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    _TimelinePoster(
                      url: entry.posterUrl ?? '',
                      fallback: entry.name,
                      kind: entry.kind,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            entry.name.trim().isEmpty
                                ? style.label
                                : entry.name.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _KindChip(style: style),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _relativeTime(entry.timestampMs),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.55),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePoster extends StatelessWidget {
  const _TimelinePoster({
    required this.url,
    required this.fallback,
    required this.kind,
  });

  final String url;
  final String fallback;
  final UserHistoryKind kind;

  @override
  Widget build(BuildContext context) {
    final live = kind == UserHistoryKind.live;
    final w = live ? 44.0 : 38.0;
    final h = live ? 44.0 : 54.0;
    final letter =
        fallback.trim().isEmpty ? '?' : fallback.trim()[0].toUpperCase();
    final placeholder = Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.5,
        ),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: w,
        height: h,
        child: CachedNetworkImage(
          imageUrl: url,
          cacheKey: AppImageCacheService.cacheKeyFor(url),
          cacheManager: AppImageCacheService.manager,
          fit: live ? BoxFit.contain : BoxFit.cover,
          memCacheWidth: 120,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          errorWidget: (_, __, ___) => placeholder,
          placeholder: (_, __) => placeholder,
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.style});

  final _KindStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: style.color.withValues(alpha: 0.45),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 11, color: style.color),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              color: style.color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _KindStyle {
  const _KindStyle(this.color, this.icon, this.label);
  final Color color;
  final IconData icon;
  final String label;
}

_KindStyle _kindStyle(UserHistoryKind kind, BuildContext context) {
  switch (kind) {
    case UserHistoryKind.live:
      return _KindStyle(
        const Color(0xFFFF3B47),
        Icons.sensors_rounded,
        'analytics.kind.live'.tr,
      );
    case UserHistoryKind.vod:
      return _KindStyle(
        Theme.of(context).colorScheme.primary,
        Icons.movie_filter_rounded,
        'analytics.kind.movie'.tr,
      );
    case UserHistoryKind.series:
      return _KindStyle(
        const Color(0xFF22C55E),
        Icons.theaters_rounded,
        'analytics.kind.series'.tr,
      );
  }
}

String _relativeTime(int timestampMs) {
  final now = DateTime.now();
  final d = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'analytics.time.justNow'.tr;
  if (diff.inMinutes < 60) {
    return 'analytics.time.minsAgo'.trParams({'n': '${diff.inMinutes}'});
  }
  if (diff.inHours < 24) {
    return 'analytics.time.hoursAgo'.trParams({'n': '${diff.inHours}'});
  }
  if (diff.inDays == 1) return 'analytics.time.yesterday'.tr;
  if (diff.inDays < 7) {
    return 'analytics.time.daysAgo'.trParams({'n': '${diff.inDays}'});
  }
  final weeks = (diff.inDays / 7).floor();
  return 'analytics.time.weeksAgo'.trParams({'n': '$weeks'});
}

// =============================================================================
// Yardımcılar.
// =============================================================================

String _formatHours(double minutes) {
  if (minutes < 1) return '0 dk';
  if (minutes < 60) {
    return '${minutes.round()} dk';
  }
  final h = minutes ~/ 60;
  final m = (minutes - h * 60).round();
  if (m == 0) return '${h}s';
  return '${h}s ${m}dk';
}

String _weekdayLabel(int idx) {
  const keys = [
    'analytics.weekday.mon',
    'analytics.weekday.tue',
    'analytics.weekday.wed',
    'analytics.weekday.thu',
    'analytics.weekday.fri',
    'analytics.weekday.sat',
    'analytics.weekday.sun',
  ];
  if (idx < 0 || idx >= keys.length) return '';
  return keys[idx].tr;
}

String _periodLabel(int hour) {
  if (hour >= 5 && hour < 12) return 'analytics.period.morning'.tr;
  if (hour >= 12 && hour < 17) return 'analytics.period.afternoon'.tr;
  if (hour >= 17 && hour < 22) return 'analytics.period.evening'.tr;
  return 'analytics.period.night'.tr;
}
