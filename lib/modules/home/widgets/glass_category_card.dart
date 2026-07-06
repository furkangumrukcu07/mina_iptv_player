import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/home/home_card_frame_style.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/haptics/adaptive_haptics_service.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/app_performance.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../ui/iptv_channel_logo.dart';
import '../../../ui/tv_dpad_focus.dart';

/// Dark Flat: çizgi (outline) ikon eşlemesi.
IconData minaFlatCategoryIcon(IconData icon) {
  if (icon == Icons.live_tv_rounded) return Icons.live_tv_outlined;
  if (icon == Icons.movie_filter_rounded) {
    return Icons.movie_filter_outlined;
  }
  if (icon == Icons.theater_comedy_rounded) {
    return Icons.theater_comedy_outlined;
  }
  if (icon == Icons.favorite_rounded) return Icons.favorite_border_rounded;
  if (icon == Icons.view_timeline_rounded) {
    return Icons.view_timeline_outlined;
  }
  if (icon == Icons.forum_rounded) return Icons.forum_outlined;
  return icon;
}

/// Referans düzen: cam panel, ikon sol üst, metinler sol hizalı.
class GlassCategoryCard extends StatelessWidget {
  const GlassCategoryCard({
    super.key,
    required this.primaryLabel,
    required this.icon,
    required this.focused,
    required this.onTap,
    this.secondaryLabel,
    this.previewImageUrl,
    /// Sağ üst köşe; gizli kategori/kanal filtreleri sonrası görünür öğe sayısı.
    this.itemCount,
    /// `null` ise varsayılan kart ikon boyutu kullanılır.
    this.iconSize,
    /// Önizleme görseli yokken merkezdeki ikonu büyük + belirgin (primary
    /// renkli) gösterir. Sohbet ve Favoriler kartları için kullanılır.
    this.prominentPlaceholderIcon = false,
    this.manageRemoteFocus = true,
  });

  final String primaryLabel;
  final String? secondaryLabel;
  final String? previewImageUrl;
  final IconData icon;
  final bool focused;
  final VoidCallback onTap;

  /// `null` veya negatifse rozet çizilmez.
  final int? itemCount;

  /// Belirli kartlar için ikon boyutu geçersiz kılma (ör. Chat kartı).
  final double? iconSize;

  /// Önizleme görseli olmayan kartlarda merkez ikonu vurgulu çizer.
  final bool prominentPlaceholderIcon;

  /// `false` iken üst widget odak/OK yönetir (ana ekran TV kartları).
  final bool manageRemoteFocus;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final settings = Get.find<AppSettingsService>();
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    return Obx(() {
      final theme = settings.themeLabel.value;
      final ga = GlassAppearance.fromLabel(theme);

      final reduce = settings.reduceBlur.value;
      final tv = settings.layoutMode.value == AppLayoutMode.tv;
      // Android + TV: gölge blur'u (raster geçişi) eski kutularda pahalı; kaldır.
      final isTvAndroid = AppPerformance.isTvAndroidLayout(settings);
      final isGm = theme == GlassThemeLabels.glassmorphism ||
          theme == GlassThemeLabels.minaGlass ||
          theme == GlassThemeLabels.flyUi;
      final isGg = theme == GlassThemeLabels.glassGri;
      final flat = ga.useFlatHomeCategoryStyle;
      // Düşük donanım modunda kart başına gerçek zamanlı BackdropFilter
      // (yatay grid'de N blur geçişi) kapatılır — normal cihazda görünüm aynı.
      final lowEnd = AppPerformance.isLowEndMode(settings);
      final sigma = flat ||
              reduce ||
              isPortrait ||
              tv ||
              lowEnd ||
              ga.usesSyntheticGlassSurface
          ? 0.0
          : (isGm || isGg ? 14.0 : 10.0);

      final cardR = ga.categoryCardBorderRadius;
      final clipInner = math.max(1.0, cardR - 1);
      final displayIcon =
          flat ? minaFlatCategoryIcon(icon) : icon;
      final iconColor = flat ? cs.onSurface : Colors.white;
      final subColor =
          flat ? cs.onSurfaceVariant : Colors.white.withValues(alpha: 0.92);

      final gradientColors = ga.homeCategoryCardNeutralGradient(isPortrait);

      final inner = Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              displayIcon,
              color: iconColor,
              size: iconSize ?? (flat ? 26 : 24),
              shadows: flat
                  ? const [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 5,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            const Spacer(),
            Text(
              primaryLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: flat ? cs.onSurface : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.12,
                letterSpacing: 0.1,
                shadows: flat
                    ? const [
                        Shadow(
                          color: Color(0xCC000000),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            ),
            if (secondaryLabel != null && secondaryLabel!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                secondaryLabel!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  height: 1.15,
                  shadows: flat
                      ? const [
                          Shadow(
                            color: Color(0xAA000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ],
        ),
      );

      final glassLayer =
          sigma > 0
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: inner,
                )
              : inner;

      final tap = Get.isRegistered<AdaptiveHapticsService>()
          ? Get.find<AdaptiveHapticsService>().wrapTap(onTap)
          : onTap;

      final remote = remoteNavForScreenLayout(
        context,
        settings.layoutMode.value,
      );
      final frameStyle = settings.homeCardFrameStyle.value;
      final card = HomeCardFrame(
          style: frameStyle,
          radius: cardR,
          child: AnimatedContainer(
            duration: AppPerformance.uiDuration(
              const Duration(milliseconds: 180),
            ),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardR),
            border: Border.all(
              width: 0.5,
              color: Colors.white.withValues(alpha: 0.28),
            ),
            boxShadow: isTvAndroid
                ? null
                : AppPerformance.liteShadow(settings, [
                    BoxShadow(
                      color: ga.homeCategoryCardNeutralShadow(),
                      blurRadius: flat ? 14 : 10,
                      offset: Offset(0, flat ? 6 : 4),
                    ),
                  ]),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(clipInner),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                if (previewImageUrl != null && previewImageUrl!.isNotEmpty)
                  Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.75,
                      heightFactor: 0.75,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        // Önizleme URL'i (canlı kartta periyodik) değiştiğinde
                        // sert geçiş yerine yumuşak çapraz geçiş.
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 450),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          layoutBuilder: (current, previous) => Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.center,
                            children: [
                              ...previous,
                              if (current != null) current,
                            ],
                          ),
                          child: LayoutBuilder(
                            key: ValueKey<String>(previewImageUrl!),
                            builder: (context, constraints) {
                              final dpr =
                                  MediaQuery.devicePixelRatioOf(context);
                              final side = math.max(
                                1,
                                (constraints.biggest.shortestSide * dpr)
                                    .round(),
                              );
                              return IptvChannelLogo(
                                imageUrl: previewImageUrl!,
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                fit: BoxFit.cover,
                                memCacheWidth: side,
                                memCacheHeight: side,
                                errorWidget: _buildPlaceholder(icon),
                                placeholder: _buildPlaceholder(icon),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.center,
                    child: FractionallySizedBox(
                      widthFactor: 0.75,
                      heightFactor: 0.75,
                      child: _buildPlaceholder(
                        icon,
                        prominent: prominentPlaceholderIcon,
                        tint: primary,
                      ),
                    ),
                  ),
                glassLayer,
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(clipInner),
                        border: Border.all(
                          width: 0.5,
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.2, 0.8, 1.0],
                          colors: [
                            Colors.white.withValues(alpha: 0.10),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (focused &&
                    MediaQuery.orientationOf(context) ==
                        Orientation.landscape)
                  Positioned(
                    bottom: -4,
                    left: 10,
                    right: 10,
                    height: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.9),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (itemCount != null && itemCount! >= 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IgnorePointer(
                      child: _HomeCategoryCountBadge(
                        count: itemCount!,
                        flat: flat,
                        glassBorderAlpha: 0.28,
                        textColor: flat ? cs.onSurface : Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      if (remote && manageRemoteFocus) {
        final activate = tap ?? onTap;
        return tvDpadActivateWrap(
          context,
          onActivate: activate,
          borderRadius: cardR,
          scaleOnFocus: 1.04,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: activate,
              borderRadius: BorderRadius.circular(cardR),
              child: card,
            ),
          ),
        );
      }
      return TouchFeedbackScale(onTap: tap, child: card);
    });
  }

  Widget _buildPlaceholder(
    IconData fallbackIcon, {
    bool prominent = false,
    Color? tint,
  }) {
    // Vurgulu mod (Sohbet / Favoriler): büyük, belirgin, primary renkli daire
    // içinde ikon. Normal mod: önceki soluk ikon davranışı korunur.
    if (prominent) {
      final accent = tint ?? Colors.white;
      return LayoutBuilder(
        builder: (context, constraints) {
          final shortest = constraints.biggest.shortestSide;
          final diameter = (shortest * 0.62).clamp(48.0, 120.0);
          final iconSz = diameter * 0.56;
          return Center(
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.32),
                    accent.withValues(alpha: 0.14),
                  ],
                ),
                border: Border.all(
                  color: accent.withValues(alpha: 0.55),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.30),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                fallbackIcon,
                color: Colors.white,
                size: iconSz,
                shadows: const [
                  Shadow(
                    color: Color(0x99000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          fallbackIcon,
          color: Colors.white.withValues(alpha: 0.15),
          size: 48,
        ),
      ),
    );
  }
}

/// Ana sayfa kategori kartı sağ üst: dinamik genişleyen sayı rozeti.
class _HomeCategoryCountBadge extends StatelessWidget {
  const _HomeCategoryCountBadge({
    required this.count,
    required this.flat,
    required this.glassBorderAlpha,
    required this.textColor,
  });

  final int count;
  final bool flat;
  final double glassBorderAlpha;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final s = count.toString();
    final primary = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            width: 0.8,
            color: flat
                ? primary.withValues(alpha: 0.35)
                : primary.withValues(alpha: 0.72),
          ),
          color: flat
              ? Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.92)
              : Colors.black.withValues(alpha: 0.48),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              s,
              maxLines: 1,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0.2,
                shadows: flat
                    ? null
                    : const [
                        Shadow(
                          color: Color(0xAA000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TouchFeedbackScale extends StatefulWidget {
  const TouchFeedbackScale({
    super.key,
    required this.onTap,
    required this.child,
    this.scale = 0.96,
  });

  final VoidCallback? onTap;
  final Widget child;
  final double scale;

  @override
  State<TouchFeedbackScale> createState() => _TouchFeedbackScaleState();
}

class _TouchFeedbackScaleState extends State<TouchFeedbackScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return Listener(
      onPointerDown: (_) => _ctrl.forward(),
      onPointerUp: (_) => _ctrl.reverse(),
      onPointerCancel: (_) => _ctrl.reverse(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
