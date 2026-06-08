import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/home/home_card_swipe_effect.dart';
import '../../core/home/home_category_card_id.dart';
import '../../core/i18n/localized_short_date.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/glass_appearance.dart';
import 'home_controller.dart';
import 'widgets/home_category_card_slot.dart';
import 'widgets/ai_recommendations_strip.dart';
import 'widgets/continue_watching_strip.dart';
import 'widgets/mixed_live_tv_strip.dart';
import 'widgets/upcoming_matches_strip.dart';
import 'widgets/weekly_marquee.dart';

const _kHomeIconAsset = 'assets/images/new_logo.png';

/// Mobil / tablet ana ekranındaki başlık çerçevesinden açılan resmi Telegram
/// kanalı. Aynı URL ayarlar > yardım menüsündeki kısayolla birebir aynıdır;
/// tek noktada güncellenebilmesi için burada sabit tutuluyor.
const String _kMinaTelegramUrl = 'https://t.me/minaiptvplayerpro';

Future<void> _launchMinaTelegram() async {
  final uri = Uri.parse(_kMinaTelegramUrl);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Kullanıcının seçtiği [HomeFilmDiziMode]'a göre `films`/`series` veya
/// `recommendedFilms` kartları gizlenebilir; ayrıca düzen editöründen
/// manuel olarak gizlenmiş kartlar [AppSettingsService.homeCategoryCardHidden]
/// üzerinden tamamen çıkarılır.
List<HomeCategoryCardId> _homeCategoryCardsForLayout(AppLayoutMode mode) {
  final app = Get.find<AppSettingsService>();
  final order = app.homeCategoryCardOrder;
  return HomeCategoryCardId.orderForLayout(
    order,
    mode,
    filmDiziMode: app.homeFilmDiziMode.value,
    hidden: app.homeCategoryCardHidden.toSet(),
  );
}

String _homeFmtClock(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
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
              // Build içinde tek seferlik servis kullanımı — controller'ın
              // ömrü boyunca aynı instance.
              final settings = Get.find<AppSettingsService>();
              final themeLabel = settings.themeLabel.value;
              final reduce = settings.reduceBlur.value;
              final tv = settings.layoutMode.value == AppLayoutMode.tv;
              final sigma = tv ? 0.0 : (reduce ? 2.0 : 3.0);
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
              if (reduce ||
                  tv ||
                  GlassAppearance.fromLabel(themeLabel)
                      .usesSyntheticGlassSurface) {
                return scaled;
              }
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
  late final Map<HomeCategoryCardId, FocusNode> _cardFocus;
  late final FocusNode _upcomingMatchesFirstFocus =
      FocusNode(debugLabel: 'upcomingMatchesFirstItem');
  late final FocusNode _aiFirstFocus =
      FocusNode(debugLabel: 'aiRecommendationsFirstItem');
  late final FocusNode _continueFirstFocus =
      FocusNode(debugLabel: 'continueWatchingFirstItem');

  // Build hot-path: Get.find çağrısını bir kez yap, build ağacında tekrar etme.
  late final AppSettingsService _settings = Get.find<AppSettingsService>();

  @override
  void initState() {
    super.initState();
    _cardFocus = {
      for (final id in HomeCategoryCardId.values)
        id: FocusNode(debugLabel: 'homeCard_${id.storageKey}'),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tv =
          Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
      if (!tv) return;
      _focusForFirstCard().requestFocus();
    });
  }

  FocusNode _focusFor(HomeCategoryCardId id) => _cardFocus[id]!;

  FocusNode _focusForFirstCard() {
    final mode = _settings.layoutMode.value;
    final order = _homeCategoryCardsForLayout(mode);
    return _focusFor(order.first);
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _settingsFocus.dispose();
    _scrollController.dispose();
    for (final n in _cardFocus.values) {
      n.dispose();
    }
    _upcomingMatchesFirstFocus.dispose();
    _aiFirstFocus.dispose();
    _continueFirstFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final screenSize = MediaQuery.sizeOf(context);
    final primary = Theme.of(context).colorScheme.primary;
    final tv = _settings.layoutMode.value == AppLayoutMode.tv;

    // TV modunda pull-to-refresh kullanılmaz (DPAD ile down scroll yapılır);
    // sadece dokunmatik (telefon/tablet) layout için aktif. RefreshIndicator
    // her zaman scrollable bir liste ister; `AlwaysScrollableScrollPhysics`
    // ile sarmalayıp `bouncing` davranışı koruyoruz.
    final list = SingleChildScrollView(
      controller: _scrollController,
      physics: tv
          ? AppScrollPhysics.list()
          : const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            Obx(() {
              if (_settings.layoutMode.value == AppLayoutMode.tv) {
                return const SizedBox.shrink();
              }
              // Android telefon: sahte pil/WiFi yok; sistem durum çubuğu görünsün (iOS'a dokunulmaz).
              if (Platform.isAndroid) return const SizedBox.shrink();
              return const _StatusBarRow();
            }),
            const SizedBox(height: 12),
            // Cam header satırı düşük dpi / dar ekranlarda (≤ 360dp) sol
            // marka kapsülü + sağ saat/ayarlar kapsülünün toplam intrinsic
            // genişliği ekran genişliğini aştığında taşıyordu (Spacer flex
            // overflow → clip). Çözüm: her iki kapsülü `Flexible` ile sar,
            // `FittedBox(scaleDown)` ile çocuğun **intrinsic boyutu**
            // gerekirse orantılı küçültülsün. Geniş ekranlarda FittedBox
            // büyütme yapmadığından mevcut görünüm korunur.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child:
                          const _BrandGlassCapsule(iconAsset: _kHomeIconAsset),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Builder(builder: (context) {
                        final tv =
                            _settings.layoutMode.value == AppLayoutMode.tv;
                        return _CombinedGlassClockSettings(
                          onSearch: () => c.showGlobalSearch(context),
                          clockBuilder: () => Obx(() {
                            final n = c.now.value;
                            final lang = _settings.languageCode.value;
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
                                  formatAppShortDateLine(n, lang),
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
                          onSettings: c.openSettings,
                          tvDpadNavigation: tv,
                          searchFocusNode: tv ? _searchFocus : null,
                          settingsFocusNode: tv ? _settingsFocus : null,
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
            // Günün Sözü (Haftalık Kayan Yazı) — Ayarlar'dan kapatıldığında
            // şerit ve çevresindeki tüm dikey boşluk tamamen kaldırılır,
            // böylece üst başlık ile alttaki kategori kartları arasındaki
            // ekran alanı doğal olarak doldurulur.
            Obx(() {
              if (!_settings.dailyQuoteEnabled.value) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const WeeklyMarquee(),
                  SizedBox(height: widget.isPortrait ? 8 : 16),
                  SizedBox(
                    height: screenSize.height *
                        (widget.isPortrait ? 0.008 : 0.02),
                  ),
                ],
              );
            }),
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

                  final availableWidth =
                      screenSize.width - 32; // horizontal padding
                  const gap = 16.0;

                  return Obx(() {
                    final app = Get.find<AppSettingsService>();
                    final layoutMode = app.layoutMode.value;
                    final tv = layoutMode == AppLayoutMode.tv;
                    app.homeCategoryCardOrderRevision.value;
                    // Liste değişiminde kart önizlemeleri/sayıları tazelensin.
                    widget.controller.playlistRevision.value;
                    final order = _homeCategoryCardsForLayout(layoutMode);
                    final cardCount =
                        order.isEmpty ? 1.0 : order.length.toDouble();
                    // Kullanıcı isteği — kart ebatları default %15 küçültüldü
                    // (en + boy lineer 0.85x). Aspect oranı (0.85) korunur,
                    // kartlar arasındaki boşluk doğal artar. Ek olarak
                    // `homeCardScale` global ölçek (0.80-1.20) ayarlardan
                    // gelir; küçült/büyüt tek noktadan kontrol edilir.
                    final scale = app.homeCardScale.value;
                    final baseCardWidth = (availableWidth / cardCount) - 15;
                    final cardWidth = baseCardWidth * 0.85 * scale;
                    final cardHeight = cardWidth * 0.85;
                    final children = <Widget>[];
                    for (var i = 0; i < order.length; i++) {
                      final id = order[i];
                      if (i > 0) children.add(const SizedBox(width: gap));
                      children.add(
                        _TvGlassCard(
                          width: cardWidth,
                          height: cardHeight,
                          focusNode: _focusFor(id),
                          autofocus: i == 0,
                          onActivate: homeCategoryActivate(c, id),
                          buildCard: (focused) => HomeCategoryCardSlot(
                            id: id,
                            controller: c,
                            focused: focused,
                          ),
                        ),
                      );
                    }
                    final row = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: children,
                    );
                    if (tv) {
                      return row;
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: AppScrollPhysics.list(),
                      child: row,
                    );
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            // İzlemeye Devam Et şeridi: yarıda kalmış film ve diziler, en son
            // izlenenden başlayarak. Ayarlar → Ana Ekran Ayarları anahtarı ile
            // kapatılabilir. Liste boşsa şerit kendini gizler.
            if (widget.controller.data != null)
              Obx(() {
                widget.controller.playlistRevision.value;
                if (!_settings.continueWatchingEnabled.value) {
                  return const SizedBox.shrink();
                }
                final data = widget.controller.data;
                if (data == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    ContinueWatchingStrip(
                      data: data,
                      tvFirstItemFocusNode: _continueFirstFocus,
                    ),
                  ],
                );
              }),
            // Mina AI — Senin İçin Önerilenler şeridi: kullanıcı geçmiş
            // izleme alışkanlığını analiz eden yerel AI motoru, 10 karma
            // canlı/film/dizi içeriği önerir. Ayarlar → Ana Ekran Ayarları
            // anahtarı ile kapatılabilir.
            if (widget.controller.data != null)
              Obx(() {
                widget.controller.playlistRevision.value;
                if (!_settings.isAiRecommendationEnabled.value) {
                  return const SizedBox.shrink();
                }
                final data = widget.controller.data;
                if (data == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    AiRecommendationsStrip(
                      data: data,
                      tvFirstItemFocusNode: _aiFirstFocus,
                    ),
                  ],
                );
              }),
            Obx(() {
              final mode = _settings.layoutMode.value;
              final upcomingOn = _settings.upcomingMatchesEnabled.value;
              final mixedOn = _settings.mixedLiveTvEnabled.value;
              if (mode == AppLayoutMode.tv) {
                if (!upcomingOn) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    UpcomingMatchesStrip(
                      tvFirstItemFocusNode: _upcomingMatchesFirstFocus,
                    ),
                  ],
                );
              }
              final strips = <Widget>[];
              if (mixedOn) {
                strips.addAll([
                  const SizedBox(height: 20),
                  const MixedLiveTvStrip(),
                ]);
              }
              if (upcomingOn) {
                if (strips.isNotEmpty) strips.add(const SizedBox(height: 20));
                strips.add(const UpcomingMatchesStrip());
              }
              if (strips.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: strips,
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    if (tv) return list;

    return RefreshIndicator.adaptive(
      onRefresh: c.refreshPlaylist,
      color: Colors.white,
      backgroundColor: primary.withValues(alpha: 0.92),
      displacement: 36,
      edgeOffset: 8,
      strokeWidth: 2.4,
      child: list,
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
      // Mobil ve tabletteki Telegram kısayolu için sol kenarı biraz daha
      // nefes aldıracak şekilde genişletiyoruz; TV modunda Telegram ikonu
      // gizlendiği için eski daha dar padding'i koruyoruz.
      final EdgeInsetsGeometry decoratedPadding = tv
          ? const EdgeInsets.fromLTRB(4, 8, 4, 8)
          : const EdgeInsets.fromLTRB(8, 8, 4, 8);
      final decorated = Container(
        height: _kHomeHeaderGlassHeight,
        padding: decoratedPadding,
        decoration: ga.homeHeaderDecoration(radius: _kHomeHeaderGlassRadius),
        child: FocusTraversalGroup(
          policy: tvDpadNavigation
              ? OrderedTraversalPolicy()
              : ReadingOrderTraversalPolicy(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!tv) ...[
                // Resmi Mina Telegram kanalına tek dokunuşla açılış. TV
                // modunda gizleniyor çünkü TV kumanda akışında ek bir
                // odak hedefi gereksiz yere navigasyonu uzatır ve kullanıcı
                // TV'de URL açmıyor.
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => unawaited(_launchMinaTelegram()),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Icon(
                        Icons.telegram,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: 22,
                        semanticLabel: 'home.header.telegram'.tr,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 4),
              ],
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.83,
      initialPage: 0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// PageView henüz bağlanmadan [page] erişilemez; sürüklerken kesintisiz derinlik için kesirli sayfa.
  double _carouselPage() {
    final c = _pageController;
    if (!c.hasClients) return c.initialPage.toDouble();
    try {
      return c.page ?? c.initialPage.toDouble();
    } catch (_) {
      return c.initialPage.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final app = Get.find<AppSettingsService>();
      app.homeCategoryCardOrderRevision.value;
      // Liste değişiminde portrait kart önizlemeleri/sayıları tazelensin.
      widget.controller.playlistRevision.value;
      // Kullanıcı isteği — portrait kategori kartları default %15 küçültüldü
      // (0.75 → 0.6375). `cardH = cardW * 1.15` oranı korunur. Ek olarak
      // `homeCardScale` global ölçek ayarlardan gelir (0.80-1.20).
      final scale = app.homeCardScale.value;
      final cardW = widget.constraints.maxWidth * 0.6375 * scale;
      final cardH = cardW * 1.15;
      final order = _homeCategoryCardsForLayout(app.layoutMode.value);
      final itemCount = order.length;
      final effect = app.homeCardSwipeEffect.value;
      // rubberBand efektinde elastik snap-back için BouncingScrollPhysics;
      // diğer tüm efektlerde projenin default `AppScrollPhysics.list()` davranışı.
      final scrollPhysics = effect == HomeCardSwipeEffect.rubberBand
          ? const BouncingScrollPhysics(
              decelerationRate: ScrollDecelerationRate.normal,
            )
          : AppScrollPhysics.list();
      final primary = Theme.of(context).colorScheme.primary;

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: cardH + 40,
            child: PageView.builder(
              key: ValueKey(order.map((e) => e.storageKey).join(',')),
              controller: _pageController,
              physics: scrollPhysics,
              clipBehavior: Clip.none,
              itemCount: itemCount,
              itemBuilder: (context, index) {
                final cardId = order[index];
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    final page = _carouselPage();
                    final delta = page - index;
                    final dist = delta.abs().clamp(0.0, 1.0);
                    return _SwipeEffectFrame(
                      effect: effect,
                      delta: delta,
                      dist: dist,
                      primary: primary,
                      child: child!,
                    );
                  },
                  child: _PortraitCarouselPage(
                    child: SizedBox(
                      width: cardW,
                      height: cardH,
                      child: HomeCategoryCardSlot(
                        id: cardId,
                        controller: widget.controller,
                        focused: false,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _pageController,
            builder: (context, _) {
              double page = 0.0;
              try {
                page = _pageController.page ?? 0.0;
              } catch (_) {}
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(itemCount, (index) {
                  final active = (page - index).abs() < 0.5;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      );
    });
  }
}

/// Portrait carousel item'larına seçili [HomeCardSwipeEffect]'e göre
/// transform/decoration uygulayan sarmalayıcı. `delta` = (page - index)
/// işaretli mesafe (negatif → kart soluda kalıyor); `dist` = |delta|
/// 0..1 arası.
///
/// Tüm efektler aynı sahnede mutually exclusive çalışır; ortak baz olarak
/// her zaman scale/opacity/translate uygulanır, üzerine efekt özel
/// dekorasyon eklenir.
class _SwipeEffectFrame extends StatelessWidget {
  const _SwipeEffectFrame({
    required this.effect,
    required this.delta,
    required this.dist,
    required this.primary,
    required this.child,
  });

  final HomeCardSwipeEffect effect;
  final double delta;
  final double dist;
  final Color primary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rawFocus = 1.0 - dist;
    final focus = Curves.easeOutCubic.transform(rawFocus);

    // rubberBand efektinde aktif kart hafif overshoot yapar; diğerlerinde
    // 0.91..1.0 lineer ölçek baz davranıştır.
    final double baseScale;
    if (effect == HomeCardSwipeEffect.rubberBand) {
      final overshoot = math.sin(rawFocus * math.pi) * 0.05;
      baseScale = lerpDouble(0.91, 1.0, focus)! + overshoot * focus;
    } else {
      baseScale = lerpDouble(0.91, 1.0, focus)!;
    }
    final baseOpacity = lerpDouble(0.70, 1.0, focus)!.clamp(0.0, 1.0);
    final dy = lerpDouble(8.0, 0.0, focus)!;
    final dx = lerpDouble(0.0, delta * 6.0, 1.0 - focus)!;

    Widget content = child;

    // Overlay efektleri (kart yüzeyinin üzerine bir Stack ile bindirilir).
    final overlay = _buildOverlay(effect);
    if (overlay != null) {
      content = Stack(
        fit: StackFit.passthrough,
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(child: overlay),
          ),
        ],
      );
    }

    // Blur efektinde kartın kendisi bulanır (ImageFilter); ortadaki net.
    if (effect == HomeCardSwipeEffect.blur && dist > 0.001) {
      final sigma = dist * 18.0;
      content = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: content,
      );
    }

    return Center(
      child: Opacity(
        opacity: baseOpacity,
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: baseScale,
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }

  /// Kartın yüzeyine bindirilecek overlay (varsa). `null` dönerse base
  /// transform dışı ek bir katman uygulanmaz.
  Widget? _buildOverlay(HomeCardSwipeEffect effect) {
    switch (effect) {
      case HomeCardSwipeEffect.defaultStack:
      case HomeCardSwipeEffect.blur:
      case HomeCardSwipeEffect.rubberBand:
        return null;
      case HomeCardSwipeEffect.tintSweep:
        // Theme primary renkli diagonal gradient — yan kartların üzerinden
        // sürükleme yönüne göre kayar; aktif kart şeffaf.
        if (dist < 0.02) return null;
        final progress = delta.clamp(-1.0, 1.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1.0 + progress * 1.4, -1.0),
                end: Alignment(1.0 + progress * 1.4, 1.0),
                colors: [
                  primary.withValues(alpha: 0.0),
                  primary.withValues(alpha: 0.45 * dist),
                  primary.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        );
    }
  }
}

/// PageView sayfası: görüntü önbelleği + izole repaint (kaydırma sırasında daha akıcı).
class _PortraitCarouselPage extends StatefulWidget {
  const _PortraitCarouselPage({required this.child});

  final Widget child;

  @override
  State<_PortraitCarouselPage> createState() => _PortraitCarouselPageState();
}

class _PortraitCarouselPageState extends State<_PortraitCarouselPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}

class _TvGlassCard extends StatelessWidget {
  const _TvGlassCard({
    required this.width,
    required this.height,
    required this.buildCard,
    this.autofocus = false,
    this.onActivate,
    this.focusNode,
  });

  final double width;
  final double height;
  final Widget Function(bool focused) buildCard;
  final bool autofocus;
  final VoidCallback? onActivate;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      // Yön tuşları kasıtlı olarak BURADA tüketilmez; Flutter'ın yönsel odak
      // gezinimi (geometri tabanlı + otomatik kaydırma) devreye girer. Böylece
      // kullanıcı tüm kartlara/şeritlere stabil ve mantıklı şekilde gidebilir.
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.numpadEnter ||
            k == LogicalKeyboardKey.gameButtonSelect) {
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
