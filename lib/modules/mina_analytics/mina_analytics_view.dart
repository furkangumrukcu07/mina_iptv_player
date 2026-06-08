import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/mina_analytics_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';
import 'mina_analytics_controller.dart';

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
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: SettingsGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(controller: c),
                _RangeSelector(controller: c),
                const SizedBox(height: 12),
                Expanded(
                  child: Obx(() {
                    final snap = c.snapshot.value;
                    return ListView(
                      physics: AppScrollPhysics.list(),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      children: [
                        _SummaryCard(snapshot: snap),
                        const SizedBox(height: 12),
                        _BreakdownCard(snapshot: snap),
                        const SizedBox(height: 12),
                        _TopChannelsCard(snapshot: snap),
                        const SizedBox(height: 12),
                        _HabitsCard(snapshot: snap),
                        const SizedBox(height: 12),
                        _DailyBarsCard(snapshot: snap),
                        const SizedBox(height: 12),
                        _TopCategoriesCard(snapshot: snap),
                        const SizedBox(height: 14),
                        _ShareButton(snapshot: snap),
                        const SizedBox(height: 12),
                        _PrivacyCard(controller: c),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Header.
// =============================================================================

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final MinaAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 6),
      child: Row(
        children: [
          tvSettingsBackButton(context, autofocus: true),
          const SizedBox(width: 4),
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
  const _RangeSelector({required this.controller});

  final MinaAnalyticsController controller;

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
              ),
              _RangeButton(
                label: 'analytics.range.month'.tr,
                selected: current == MinaAnalyticsRange.month,
                onTap: () => controller.selectRange(MinaAnalyticsRange.month),
                primary: primary,
              ),
              _RangeButton(
                label: 'analytics.range.year'.tr,
                selected: current == MinaAnalyticsRange.year,
                onTap: () => controller.selectRange(MinaAnalyticsRange.year),
                primary: primary,
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;

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
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return placeholder;
          },
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
  const _ShareButton({required this.snapshot});

  final MinaAnalyticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final share = snapshot.isEmpty ? null : () => _share(snapshot);
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
    return tvDpadActivateWrap(
      context,
      onActivate: share,
      borderRadius: 14,
      child: body,
    );
  }

  Future<void> _share(MinaAnalyticsSnapshot s) async {
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
}

// =============================================================================
// 8. Privacy card.
// =============================================================================

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.controller});

  final MinaAnalyticsController controller;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      icon: Icons.privacy_tip_rounded,
      title: 'analytics.privacy.title'.tr,
      accent: Colors.white.withValues(alpha: 0.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() => SwitchListTile.adaptive(
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
                activeColor: Theme.of(context).colorScheme.primary,
              )),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _confirmClear(context),
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
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
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
