import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_appearance.dart';
import 'home_controller.dart';
import 'widgets/glass_category_card.dart';
import 'widgets/continue_watching_strip.dart';
import 'widgets/weekly_marquee.dart';

const _kHomeIconAsset = 'assets/images/new_logo.png';

String _homeFmtClock(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Referans: "Sal 31 Mar"
String _homeFmtDateRef(DateTime d) {
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

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

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
              final themeLabel = settings.themeLabel.value;
              final reduce = settings.reduceBlur.value;
              final tv = settings.layoutMode.value == AppLayoutMode.tv;
              final sigma =
                  tv ? 0.0 : (reduce ? 2.0 : 3.0); // Blur 3.0 ile sınırlı
              final decodeParams = AppTheme.homeBackgroundImageDecodeParams(
                context,
                themeLabel,
                isTvLayout: tv,
              );
              final scaled = Transform.scale(
                scale: decodeParams.zoom,
                child: Image.asset(
                  AppTheme.homeBackgroundAsset(
                    context,
                    themeLabel: themeLabel,
                  ),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  alignment: Alignment.center,
                  cacheWidth: decodeParams.cacheWidth,
                  cacheHeight: decodeParams.cacheHeight,
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
              child: _HomeMainColumn(
                controller: controller,
                isPortrait: isPortrait,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeMainColumn extends StatefulWidget {
  const _HomeMainColumn({
    required this.controller,
    required this.isPortrait,
  });

  final HomeController controller;
  final bool isPortrait;

  @override
  State<_HomeMainColumn> createState() => _HomeMainColumnState();
}

class _HomeMainColumnState extends State<_HomeMainColumn> {
  late final FocusNode _searchFocus = FocusNode(debugLabel: 'homeSearch');
  late final FocusNode _settingsFocus = FocusNode(debugLabel: 'homeSettings');
  late final ScrollController _scrollController = ScrollController();
  late final FocusNode _liveFocus = FocusNode(debugLabel: 'homeLive');
  late final FocusNode _favoritesFocus = FocusNode(debugLabel: 'homeFavorites');
  late final FocusNode _continueWatchingSectionFocus =
      FocusNode(debugLabel: 'continueWatchingSection');
  late final FocusNode _continueWatchingFirstItemFocus =
      FocusNode(debugLabel: 'continueWatchingFirstItem');
  bool _continueWatchingExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tv =
          Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
      if (!tv) return;
      _liveFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _settingsFocus.dispose();
    _scrollController.dispose();
    _liveFocus.dispose();
    _favoritesFocus.dispose();
    _continueWatchingSectionFocus.dispose();
    _continueWatchingFirstItemFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final screenSize = MediaQuery.sizeOf(context);

    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Obx(() {
              final tv = Get.find<AppSettingsService>().layoutMode.value ==
                  AppLayoutMode.tv;
              if (tv) return const SizedBox.shrink();
              // Android telefon: sahte pil/WiFi yok; sistem durum çubuğu görünsün (iOS'a dokunulmaz).
              if (Platform.isAndroid) return const SizedBox.shrink();
              return const _StatusBarRow();
            }),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _BrandGlassCapsule(iconAsset: _kHomeIconAsset),
                const Spacer(),
                Builder(builder: (context) {
                  final tv = Get.find<AppSettingsService>().layoutMode.value ==
                      AppLayoutMode.tv;
                  return _CombinedGlassClockSettings(
                    onSearch: () => c.showGlobalSearch(context),
                    clockBuilder: () => Obx(() {
                      final n = c.now.value;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _homeFmtClock(n),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _homeFmtDateRef(n),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    }),
                    onSettings: c.openSettings,
                    tvDpadNavigation: tv,
                    searchFocusNode: tv ? _searchFocus : null,
                    settingsFocusNode: tv ? _settingsFocus : null,
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),
            // Haftalık Kayan Yazı
            const WeeklyMarquee(),
            const SizedBox(height: 16), // Eklenen mesafe
            SizedBox(height: screenSize.height * 0.02),
            // Ana Kategori Kartları (Görünür Alan)
            FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (widget.isPortrait) {
                    return _PortraitHomeCarousel(
                      controller: c,
                      constraints: constraints,
                    );
                  }

                  // MediaQuery ile optimize edilmiş kart boyutları
                  final availableWidth =
                      screenSize.width - 32; // horizontal padding
                  final cardWidth =
                      (availableWidth / 4) - 15; // 4 kart, gap hesabı
                  final cardHeight = cardWidth * 0.85; // Aspect ratio
                  const gap = 16.0;

                  return Obx(() {
                    final tv =
                        Get.find<AppSettingsService>().layoutMode.value ==
                            AppLayoutMode.tv;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TvGlassCard(
                          width: cardWidth,
                          height: cardHeight,
                          order: 0,
                          focusNode: _liveFocus,
                          autofocus: true,
                          focusOnArrowDown:
                              tv ? _continueWatchingFirstItemFocus : null,
                          onActivate: c.openLiveTv,
                          scrollController: _scrollController,
                          buildCard: (focused) => GlassCategoryCard(
                            primaryLabel: 'home.live'.tr,
                            secondaryLabel: 'home.live.subtitle'.tr,
                            icon: Icons.live_tv_rounded,
                            focused: focused,
                            onTap: c.openLiveTv,
                            previewImageUrl: c.getLivePreview(),
                          ),
                        ),
                        const SizedBox(width: gap),
                        _TvGlassCard(
                          width: cardWidth,
                          height: cardHeight,
                          order: 1,
                          focusOnArrowDown:
                              tv ? _continueWatchingFirstItemFocus : null,
                          onActivate: c.openFilms,
                          scrollController: _scrollController,
                          buildCard: (focused) => GlassCategoryCard(
                            primaryLabel: 'home.films'.tr,
                            secondaryLabel: 'home.films.subtitle'.tr,
                            icon: Icons.movie_filter_rounded,
                            focused: focused,
                            onTap: c.openFilms,
                            previewImageUrl: c.getFilmsPreview(),
                          ),
                        ),
                        const SizedBox(width: gap),
                        _TvGlassCard(
                          width: cardWidth,
                          height: cardHeight,
                          order: 2,
                          focusOnArrowDown:
                              tv ? _continueWatchingFirstItemFocus : null,
                          onActivate: c.openSeries,
                          scrollController: _scrollController,
                          buildCard: (focused) => GlassCategoryCard(
                            primaryLabel: 'home.series'.tr,
                            secondaryLabel: 'home.series.subtitle'.tr,
                            icon: Icons.theater_comedy_rounded,
                            focused: focused,
                            onTap: c.openSeries,
                            previewImageUrl: c.getSeriesPreview(),
                          ),
                        ),
                        const SizedBox(width: gap),
                        _TvGlassCard(
                          width: cardWidth,
                          height: cardHeight,
                          order: 3,
                          focusNode: _favoritesFocus,
                          focusOnArrowUp: tv ? _searchFocus : null,
                          focusOnArrowDown:
                              tv ? _continueWatchingFirstItemFocus : null,
                          onActivate: c.openFavorites,
                          scrollController: _scrollController,
                          buildCard: (focused) => GlassCategoryCard(
                            primaryLabel: 'home.favorites'.tr,
                            secondaryLabel: 'Favoriler',
                            icon: Icons.favorite_rounded,
                            focused: focused,
                            onTap: c.openFavorites,
                            previewImageUrl: c.getFavoritesPreview(),
                          ),
                        ),
                      ],
                    );
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            // İzlemeye Devam Et Şeridi (Kaydırınca Görünen)
            if (widget.controller.data != null)
              Focus(
                focusNode: _continueWatchingSectionFocus,
                onFocusChange: (hasFocus) {
                  setState(() {
                    _continueWatchingExpanded = hasFocus;
                  });
                },
                onKeyEvent: (node, event) {
                  final tv = Get.find<AppSettingsService>().layoutMode.value ==
                      AppLayoutMode.tv;
                  if (!tv) return KeyEventResult.ignored;

                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _liveFocus.requestFocus();
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: ContinueWatchingStrip(
                  data: widget.controller.data!,
                  maxItems: 10,
                  initiallyExpanded: _continueWatchingExpanded,
                  tvFirstItemFocusNode: _continueWatchingFirstItemFocus,
                  tvFocusOnArrowUp: _liveFocus,
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
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

class _BrandGlassCapsule extends StatelessWidget {
  const _BrandGlassCapsule({required this.iconAsset});

  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = Get.find<AppSettingsService>();
      final tv = settings.layoutMode.value == AppLayoutMode.tv;
      final sigma = tv ? 0.0 : 3.0; // Blur 3.0 ile sınırlı
      final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
      final decorated = Container(
        height: _kHomeHeaderGlassHeight,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: ga.homeHeaderDecoration(radius: _kHomeHeaderGlassRadius),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                iconAsset,
                width: 34,
                height: 34,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'home.header.brandTop'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.96),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                Text(
                  'home.header.brandBottom'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
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

/// TV kumandası: [FocusNode] odağında çerçeve + gölge (InkWell tek başına göstermez).
class _TvHeaderIconFocusRing extends StatelessWidget {
  const _TvHeaderIconFocusRing({
    required this.focusNode,
    required this.child,
  });

  final FocusNode focusNode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        final primary = Theme.of(context).colorScheme.primary;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              width: focused ? 2.5 : 0,
              color: focused ? primary : Colors.transparent,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.55),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: child,
        );
      },
    );
  }
}

class _CombinedGlassClockSettings extends StatelessWidget {
  const _CombinedGlassClockSettings({
    required this.onSearch,
    required this.clockBuilder,
    required this.onSettings,
    this.tvDpadNavigation = false,
    this.searchFocusNode,
    this.settingsFocusNode,
  });

  final VoidCallback onSearch;
  final Widget Function() clockBuilder;
  final VoidCallback onSettings;
  final bool tvDpadNavigation;
  final FocusNode? searchFocusNode;
  final FocusNode? settingsFocusNode;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = Get.find<AppSettingsService>();
      final tv = settings.layoutMode.value == AppLayoutMode.tv;
      final sigma = tv ? 0.0 : 3.0; // Blur 3.0 ile sınırlı
      final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
      final decorated = Container(
        height: _kHomeHeaderGlassHeight,
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        decoration: ga.homeHeaderDecoration(radius: _kHomeHeaderGlassRadius),
        child: FocusTraversalGroup(
          policy: tvDpadNavigation
              ? OrderedTraversalPolicy()
              : ReadingOrderTraversalPolicy(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FocusTraversalOrder(
                order: const NumericFocusOrder(0),
                child: Focus(
                  focusNode: tvDpadNavigation ? searchFocusNode : null,
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent) {
                      return KeyEventResult.ignored;
                    }
                    final k = event.logicalKey;
                    if (tvDpadNavigation &&
                        settingsFocusNode != null &&
                        k == LogicalKeyboardKey.arrowRight) {
                      settingsFocusNode!.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (k == LogicalKeyboardKey.select ||
                        k == LogicalKeyboardKey.enter ||
                        k == LogicalKeyboardKey.numpadEnter ||
                        k == LogicalKeyboardKey.space ||
                        k == LogicalKeyboardKey.gameButtonSelect) {
                      onSearch();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: tvDpadNavigation && searchFocusNode != null
                      ? _TvHeaderIconFocusRing(
                          focusNode: searchFocusNode!,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onSearch,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                child: Icon(
                                  Icons.search_rounded,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onSearch,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Icon(
                                Icons.search_rounded,
                                color: Colors.white.withValues(alpha: 0.95),
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 8),
              clockBuilder(),
              const SizedBox(width: 12),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.25),
              ),
              if (tvDpadNavigation && settingsFocusNode != null)
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: Focus(
                    focusNode: settingsFocusNode,
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent) {
                        return KeyEventResult.ignored;
                      }
                      final k = event.logicalKey;
                      if (searchFocusNode != null &&
                          k == LogicalKeyboardKey.arrowLeft) {
                        searchFocusNode!.requestFocus();
                        return KeyEventResult.handled;
                      }
                      if (k == LogicalKeyboardKey.select ||
                          k == LogicalKeyboardKey.enter ||
                          k == LogicalKeyboardKey.numpadEnter ||
                          k == LogicalKeyboardKey.space ||
                          k == LogicalKeyboardKey.gameButtonSelect) {
                        onSettings();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: _TvHeaderIconFocusRing(
                      focusNode: settingsFocusNode!,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onSettings,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            child: Icon(
                              Icons.settings_rounded,
                              color: Colors.white.withValues(alpha: 0.95),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onSettings,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
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
            physics: const BouncingScrollPhysics(),
            dragStartBehavior: DragStartBehavior.down,
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
    this.focusOnArrowUp,
    this.focusOnArrowDown,
    this.focusNode,
    this.scrollController,
  });

  final double width;
  final double height;
  final int order;
  final Widget Function(bool focused) buildCard;
  final bool autofocus;
  final VoidCallback? onActivate;
  final FocusNode? focusOnArrowUp;
  final FocusNode? focusOnArrowDown;
  final FocusNode? focusNode;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final up = focusOnArrowUp;
        final down = focusOnArrowDown;
        if (up != null && event.logicalKey == LogicalKeyboardKey.arrowUp) {
          up.requestFocus();
          return KeyEventResult.handled;
        }
        if (down != null && event.logicalKey == LogicalKeyboardKey.arrowDown) {
          down.requestFocus();
          // Smooth scroll to Continue Watching section (center it)
          if (scrollController != null && scrollController!.hasClients) {
            final screenHeight = MediaQuery.of(context).size.height;
            final targetPosition = scrollController!.position.maxScrollExtent -
                (screenHeight * 0.3);
            scrollController!.animateTo(
              targetPosition.clamp(
                  0.0, scrollController!.position.maxScrollExtent),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          return KeyEventResult.handled;
        }
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
