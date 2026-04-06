import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import 'home_controller.dart';
import 'widgets/glass_category_card.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  static const _iconAsset = 'assets/images/new_logo.png';

  String _fmtClock(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Referans: "Sal 31 Mar"
  String _fmtDateRef(DateTime d) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    const months = [
      '',
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    final w = days[d.weekday - 1];
    final mon = months[d.month];
    return '$w ${d.day} $mon';
  }

  @override
  Widget build(BuildContext context) {
    if (controller.data == null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          SystemNavigator.pop();
        },
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (controller.tryConsumeBackForExit()) return;
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Obx(() {
              final settings = Get.find<AppSettingsService>();
              final reduce = settings.reduceBlur.value;
              final tv = settings.layoutMode.value == AppLayoutMode.tv;
              final sigma = reduce ? 14.0 : 22.0;
              final bgPath = settings.customBackgroundPath.value ?? '';
              final useFile = bgPath.isNotEmpty;
              final dpr = MediaQuery.devicePixelRatioOf(context);
              final targetW = (MediaQuery.sizeOf(context).width * dpr).round();
              final targetH = (MediaQuery.sizeOf(context).height * dpr).round();
              final scaled = Transform.scale(
                scale: 1.08,
                child: useFile
                    ? Image.file(
                        File(bgPath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        alignment: Alignment.center,
                        cacheWidth: targetW,
                        cacheHeight: targetH,
                        errorBuilder: (_, __, ___) => Image.asset(
                          AppTheme.homeBackgroundAsset(context),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          alignment: Alignment.center,
                          cacheWidth: targetW,
                          cacheHeight: targetH,
                        ),
                      )
                    : Image.asset(
                        AppTheme.homeBackgroundAsset(context),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        alignment: Alignment.center,
                        cacheWidth: targetW,
                        cacheHeight: targetH,
                      ),
              );
              if (reduce || tv) return scaled;
              return ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: scaled,
              );
            }),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.32),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    Obx(() {
                      final tv = Get.find<AppSettingsService>()
                              .layoutMode
                              .value ==
                          AppLayoutMode.tv;
                      if (tv) return const SizedBox.shrink();
                      return const _StatusBarRow();
                    }),
                    const SizedBox(height: 12),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        _HeaderBrandAndGlass(
                          iconAsset: _iconAsset,
                          clockSettings: () => _CombinedGlassClockSettings(
                            clockBuilder: () => Obx(() {
                              final n = controller.now.value;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _fmtClock(n),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _fmtDateRef(n),
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.88),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            }),
                            onSettings: controller.openSettings,
                          ),
                        ),
                        Obx(() {
                          final tv = Get.find<AppSettingsService>()
                                  .layoutMode
                                  .value ==
                              AppLayoutMode.tv;
                          if (tv) return const SizedBox.shrink();
                          return _PortraitSearchButton(
                            onSearch: controller.openLiveTvWithSearch,
                          );
                        }),
                      ],
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          if (!isPortrait) const Spacer(flex: 3),
                          if (isPortrait) const Spacer(flex: 1),
                          FocusTraversalGroup(
                            policy: ReadingOrderTraversalPolicy(),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                if (isPortrait) {
                                  return _PortraitHomeCarousel(
                                    controller: controller,
                                    constraints: constraints,
                                  );
                                }

                                final side = ((constraints.maxHeight *
                                            0.32) // %26'dan %32'ye çıkararak daha da büyüttük
                                        .clamp(120.0,
                                            160.0) * // Clamp değerlerini yükselttik
                                    1.1);
                                const gap = 20.0; // Boşluğu artırdık

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _TvGlassCard(
                                      width: side *
                                          1.05, // %95'ten %105'e çıkararak genişliği büyüttük
                                      height: side *
                                          1.15, // %100'den %115'e çıkararak yüksekliği büyüttük
                                      order: 0,
                                      autofocus: true,
                                      onActivate: controller.openLiveTv,
                                      buildCard: (focused) => GlassCategoryCard(
                                        primaryLabel: 'home.live'.tr,
                                        secondaryLabel: 'home.live.subtitle'.tr,
                                        icon: Icons.live_tv_rounded,
                                        focused: focused,
                                        onTap: controller.openLiveTv,
                                        previewImageUrl:
                                            controller.getLivePreview(),
                                      ),
                                    ),
                                    const SizedBox(width: gap),
                                    _TvGlassCard(
                                      width: side * 1.05,
                                      height: side * 1.15,
                                      order: 1,
                                      onActivate: controller.openFilms,
                                      buildCard: (focused) => GlassCategoryCard(
                                        primaryLabel: 'home.films'.tr,
                                        secondaryLabel:
                                            'home.films.subtitle'.tr,
                                        icon: Icons.movie_filter_rounded,
                                        focused: focused,
                                        onTap: controller.openFilms,
                                        previewImageUrl:
                                            controller.getFilmsPreview(),
                                      ),
                                    ),
                                    const SizedBox(width: gap),
                                    _TvGlassCard(
                                      width: side * 1.05,
                                      height: side * 1.15,
                                      order: 2,
                                      onActivate: controller.openSeries,
                                      buildCard: (focused) => GlassCategoryCard(
                                        primaryLabel: 'home.series'.tr,
                                        secondaryLabel:
                                            'home.series.subtitle'.tr,
                                        icon: Icons.theater_comedy_rounded,
                                        focused: focused,
                                        onTap: controller.openSeries,
                                        previewImageUrl:
                                            controller.getSeriesPreview(),
                                      ),
                                    ),
                                    const SizedBox(width: gap),
                                    _TvGlassCard(
                                      width: side * 1.05,
                                      height: side * 1.15,
                                      order: 3,
                                      onActivate: controller.openFavorites,
                                      buildCard: (focused) => GlassCategoryCard(
                                        primaryLabel: 'home.favorites'.tr,
                                        secondaryLabel: 'Favoriler',
                                        icon: Icons.favorite_rounded,
                                        focused: focused,
                                        onTap: controller.openFavorites,
                                        previewImageUrl:
                                            controller.getFavoritesPreview(),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const Spacer(flex: 1),
                        ],
                      ),
                    ),
                    Obx(() {
                      final tv = Get.find<AppSettingsService>()
                              .layoutMode
                              .value ==
                          AppLayoutMode.tv;
                      if (tv) return const SizedBox.shrink();
                      return Center(
                        child: Container(
                          width: 120,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortraitSearchButton extends StatelessWidget {
  const _PortraitSearchButton({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tv = Get.find<AppSettingsService>().layoutMode.value ==
          AppLayoutMode.tv;
      final sigma = tv ? 0.0 : 12.0;
      final inner = InkWell(
        onTap: onSearch,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: sigma <= 0
            ? inner
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: inner,
              ),
      );
    });
  }
}

/// Üst satır: sadece sağda sistem ikonları (sol saat yok).
class _StatusBarRow extends StatelessWidget {
  const _StatusBarRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        Icon(Icons.alarm_rounded,
            color: Colors.white.withValues(alpha: 0.9), size: 18),
        const SizedBox(width: 10),
        Icon(Icons.signal_cellular_4_bar_rounded,
            color: Colors.white.withValues(alpha: 0.9), size: 18),
        const SizedBox(width: 10),
        Icon(Icons.wifi_rounded,
            color: Colors.white.withValues(alpha: 0.9), size: 18),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded,
                color: Colors.white.withValues(alpha: 0.85), size: 16),
            Text(
              '100',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Üst cam şerit: sol marka ve sağ saat+ayarlar aynı yükseklik / aynı cam stil.
const double _kHomeHeaderGlassHeight = 56;
const double _kHomeHeaderGlassRadius = 14;

BoxDecoration _homeHeaderGlassDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(_kHomeHeaderGlassRadius),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.35),
    ),
    gradient: LinearGradient(
      colors: [
        Colors.white.withValues(alpha: 0.2),
        Colors.white.withValues(alpha: 0.08),
      ],
    ),
  );
}

/// İkinci satır: sol IPTV Player (cam içinde), sağ saat + ayarlar (aynı ebatta cam).
class _HeaderBrandAndGlass extends StatelessWidget {
  const _HeaderBrandAndGlass({
    required this.iconAsset,
    required this.clockSettings,
  });

  final String iconAsset;
  final Widget Function() clockSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _BrandGlassCapsule(iconAsset: iconAsset),
        const Spacer(),
        clockSettings(),
      ],
    );
  }
}

class _BrandGlassCapsule extends StatelessWidget {
  const _BrandGlassCapsule({required this.iconAsset});

  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tv = Get.find<AppSettingsService>().layoutMode.value ==
          AppLayoutMode.tv;
      final sigma = tv ? 0.0 : 16.0;
      final decorated = Container(
        height: _kHomeHeaderGlassHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: _homeHeaderGlassDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                iconAsset,
                width: 36,
                height: 36,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IPTV',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                Text(
                  'Player',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(_kHomeHeaderGlassRadius),
        child: sigma <= 0
            ? decorated
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: decorated,
              ),
      );
    });
  }
}

class _CombinedGlassClockSettings extends StatelessWidget {
  const _CombinedGlassClockSettings({
    required this.clockBuilder,
    required this.onSettings,
  });

  final Widget Function() clockBuilder;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final tv = Get.find<AppSettingsService>().layoutMode.value ==
          AppLayoutMode.tv;
      final sigma = tv ? 0.0 : 16.0;
      final decorated = Container(
        height: _kHomeHeaderGlassHeight,
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: _homeHeaderGlassDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            clockBuilder(),
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 36,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSettings,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Icon(
                    Icons.settings_rounded,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(_kHomeHeaderGlassRadius),
        child: sigma <= 0
            ? decorated
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: decorated,
              ),
      );
    });
  }
}

class _PortraitHomeCarousel extends StatefulWidget {
  const _PortraitHomeCarousel({
    required this.controller,
    required this.constraints,
  });

  final HomeController controller;
  final BoxConstraints constraints;

  @override
  State<_PortraitHomeCarousel> createState() => _PortraitHomeCarouselState();
}

class _PortraitHomeCarouselState extends State<_PortraitHomeCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.75,
      initialPage: 0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardW = widget.constraints.maxWidth * 0.72;
    final cardH = cardW * 1.15;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center, // Ortalamayı sağla
      children: [
        SizedBox(
          height: cardH + 60,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemCount: 4,
            clipBehavior: Clip.none,
            itemBuilder: (context, index) {
              final focused = _currentPage == index;
              final scale = focused ? 1.0 : 0.82;
              final opacity = focused ? 1.0 : 0.5;

              return Center(
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 300),
                  scale: scale,
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: opacity,
                    child: SizedBox(
                      width: cardW,
                      height: cardH,
                      child: _buildCardByIndex(index, focused),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final active = _currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCardByIndex(int index, bool focused) {
    switch (index) {
      case 0:
        return GlassCategoryCard(
          primaryLabel: 'home.live'.tr,
          secondaryLabel: 'home.live.subtitle'.tr,
          icon: Icons.live_tv_rounded,
          focused: focused,
          onTap: widget.controller.openLiveTv,
          previewImageUrl: widget.controller.getLivePreview(),
        );
      case 1:
        return GlassCategoryCard(
          primaryLabel: 'home.films'.tr,
          secondaryLabel: 'home.films.subtitle'.tr,
          icon: Icons.movie_filter_rounded,
          focused: focused,
          onTap: widget.controller.openFilms,
          previewImageUrl: widget.controller.getFilmsPreview(),
        );
      case 2:
        return GlassCategoryCard(
          primaryLabel: 'home.series'.tr,
          secondaryLabel: 'home.series.subtitle'.tr,
          icon: Icons.theater_comedy_rounded,
          focused: focused,
          onTap: widget.controller.openSeries,
          previewImageUrl: widget.controller.getSeriesPreview(),
        );
      case 3:
      default:
        return GlassCategoryCard(
          primaryLabel: 'home.favorites'.tr,
          secondaryLabel: 'Favoriler',
          icon: Icons.favorite_rounded,
          focused: focused,
          onTap: widget.controller.openFavorites,
          previewImageUrl: widget.controller.getFavoritesPreview(),
        );
    }
  }
}

class _TvGlassCard extends StatelessWidget {
  const _TvGlassCard({
    required this.width,
    required this.height,
    required this.order,
    required this.buildCard,
    this.autofocus = false,
    this.onActivate,
  });

  final double width;
  final double height;
  final int order;
  final Widget Function(bool focused) buildCard;
  final bool autofocus;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: autofocus,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          onActivate?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return AnimatedScale(
            duration: const Duration(milliseconds: 250),
            scale: focused ? 1.08 : 1.0, // Odaklanınca hafif büyüme efekti
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: width,
              height: height,
              child: buildCard(focused),
            ),
          );
        },
      ),
    );
  }
}
