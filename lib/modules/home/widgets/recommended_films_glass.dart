import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/app_performance.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../ui/tv_dpad_focus.dart';

/// Önerilen filmler ekranları — tema duvar kağıdı.
class RecommendedFilmsGlassBackground extends StatelessWidget {
  const RecommendedFilmsGlassBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final settings = Get.find<AppSettingsService>();
      return DecoratedBox(
        decoration: AppTheme.screenBackground(
          context,
          cs,
          themeLabel: settings.themeLabel.value,
        ),
      );
    });
  }
}

/// Cam üst çubuk (geri + başlık + sağ aksiyon).
class RecommendedFilmsGlassHeader extends StatefulWidget {
  const RecommendedFilmsGlassHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  State<RecommendedFilmsGlassHeader> createState() =>
      _RecommendedFilmsGlassHeaderState();
}

class _RecommendedFilmsGlassHeaderState extends State<RecommendedFilmsGlassHeader> {
  final FocusNode _backFocus = FocusNode(debugLabel: 'rfGlassBack');

  @override
  void dispose() {
    _backFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remote = remoteNavForScreenLayout(
      context,
      Get.find<AppSettingsService>().layoutMode.value,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Obx(() {
        final ga = GlassAppearance.fromLabel(
          Get.find<AppSettingsService>().themeLabel.value,
        );
        final onHeader = ga.homeHeaderOnDecorationForeground;
        final back = remote
            ? TvIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: widget.onBack,
                focusNode: _backFocus,
                autofocus: true,
                iconColor: onHeader,
              )
            : IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: onHeader),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: widget.onBack,
              );

        return DecoratedBox(
          decoration: ga.homeHeaderDecoration(radius: 16),
          child: SizedBox(
            height: 52,
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Row(
                children: [
                  back,
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onHeader,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// [GlassTvSheet] ile aynı cam panel (padding ayarlanabilir).
class RecommendedFilmsGlassPanel extends StatelessWidget {
  const RecommendedFilmsGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 18,
    /// Film & Dizi yatay satır çerçeveleri — iç dolgu biraz daha koyu.
    this.sectionStyle = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool sectionStyle;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Obx(() {
        final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
        final tv = settings.layoutMode.value == AppLayoutMode.tv;
        final isPortrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        final sigma = (tv && !isPortrait) || isPortrait
            ? 0.0
            : AppPerformance.glassSigma(
                settings,
                zeroOnTvLayout: true,
                isTvLayout: tv && !isPortrait,
                fullSigma: 6,
                reducedSigma: 4,
              );
        final decorated = Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: ga.sheetBorder),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: sectionStyle
                  ? ga.filmDiziSectionGradientColors
                  : ga.sheetGradientColors,
            ),
          ),
          child: child,
        );
        if (sigma <= 0) return decorated;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: decorated,
        );
      }),
    );
  }
}

/// Tema birincil rengi + cam kenarlık (poster kutusu).
class RecommendedFilmsPosterFrame extends StatelessWidget {
  const RecommendedFilmsPosterFrame({
    super.key,
    required this.child,
    this.borderRadius = 8,
  });

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: ga.sheetBorder.withValues(alpha: 0.85),
          ),
          boxShadow: [
            BoxShadow(
              color: ga.popupShadowColor,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: child,
        ),
      );
    });
  }
}

/// Film & Dizi detay — cam «İzle» düğmesi. [posterUrl] verildiğinde butonun
/// arkasına posterin bulanık ve karartılmış bir kopyası yerleştirilir; cam
/// efektin üstüne posterin dominant renkleri sızar ve buton film/dizinin
/// görsel atmosferine uyumlu görünür. Ebatlar/şekil değişmez.
class FilmDiziGlassPlayButton extends StatelessWidget {
  const FilmDiziGlassPlayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.posterUrl,
  });

  final String label;
  final VoidCallback onPressed;
  final bool compact;

  /// Poster URL'i — verildiğinde butonun zemini posterin bulanık
  /// projeksiyonuyla doldurulur. Cam çerçeve aynı kalır.
  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      // Tema vurgusu (neon parlama için aksan rengi)
      final Color neon = ga.sheetGradientColors.first;
      final double radius = compact ? 20.0 : 22.0;
      final double iconBoxSize = compact ? 24.0 : 28.0;
      final double iconSize = compact ? 18.0 : 22.0;
      final hasPoster = posterUrl != null && posterUrl!.isNotEmpty;

      // Poster verilmişse gradient daha şeffaf, poster boyaması belirgin
      // kalır; verilmemişse klasik tema gradient'i.
      final gradient = hasPoster
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ga.sheetGradientColors.first.withValues(alpha: 0.35),
                ga.sheetGradientColors.last.withValues(alpha: 0.25),
              ],
            )
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ga.sheetGradientColors.first.withValues(alpha: 0.78),
                ga.sheetGradientColors.last.withValues(alpha: 0.62),
              ],
            );

      final foreground = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: ga.sheetBorder.withValues(alpha: 0.92),
                width: 1.15,
              ),
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                  color: ga.popupShadowColor.withValues(alpha: 0.40),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: neon.withValues(alpha: 0.45),
                  blurRadius: 22,
                  spreadRadius: -2,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white.withValues(alpha: 0.98),
                      size: iconSize,
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (!hasPoster) return foreground;

      // Poster zemini: sigmaX/Y 22 ile yumuşatılmış + karartılmış görüntü.
      // Hata/yüklenme durumunda foreground tek başına çalışır.
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Image.network(
                  posterUrl!,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            // Posterin üstüne yumuşak bir koyu/aksan tabakası — okunabilirlik
            // ve cam görünüm için.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.22),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
            foreground,
          ],
        ),
      );
    });
  }
}

void recommendedFilmsPop(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
    return;
  }
  Get.back<void>();
}
