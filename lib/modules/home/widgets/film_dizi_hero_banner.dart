import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart' show filmDiziRemoteNavEnabled;
import '../../../core/services/app_settings_service.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../home_controller.dart';
import 'recommended_films_poster_grid.dart';

/// Hero banner'da gösterilecek tek bir slayt verisi — VOD ve dizi için ortak.
class FilmDiziHeroSlide {
  const FilmDiziHeroSlide({
    required this.title,
    required this.posterUrl,
    required this.rating,
    required this.onPlay,
    required this.onDetail,
    this.tags = const [],
    this.nextSlidePreview,
  });

  final String title;
  final String? posterUrl;

  /// 0 olduğunda puan satırı (yıldız + skor) gizlenir (örn. dizilerde).
  final double rating;
  final VoidCallback onPlay;
  final VoidCallback onDetail;

  /// Film başlığından ayıklanan rozet etiketleri (Örn: "4K", "HDR", "2024").
  final List<String> tags;

  /// Bir sonraki slaytın önizleme modeli. Null ise önizleme gösterilmez.
  final FilmDiziHeroSlide? nextSlidePreview;
}

/// Tam genişlikte, kayan «kahraman afiş» carousel'i.
/// Film & Dizi ekranının en üstünde «Yeni Eklenen» yatay listesinin yerine
/// geçer; ilk 5 öne çıkan film/diziyi sinematik bir banner olarak gösterir.
class FilmDiziHeroBanner extends StatefulWidget {
  const FilmDiziHeroBanner({
    super.key,
    required this.slides,
    this.autoplayInterval = const Duration(seconds: 6),
    this.isTv = false,
  });

  final List<FilmDiziHeroSlide> slides;
  final Duration autoplayInterval;

  /// TV layout (yatay) — banner yüksekliğini ve buton/font ölçeklerini büyütür.
  final bool isTv;

  @override
  State<FilmDiziHeroBanner> createState() => _FilmDiziHeroBannerState();
}

class _FilmDiziHeroBannerState extends State<FilmDiziHeroBanner> {
  late final PageController _ctrl;
  Timer? _timer;
  int _idx = 0;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(viewportFraction: widget.isTv ? 0.90 : 0.92);
    if (widget.slides.isNotEmpty && Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().showcaseAmbientPoster.value =
          widget.slides.first.posterUrl;
    }
    _startAutoplay();
  }

  @override
  void didUpdateWidget(covariant FilmDiziHeroBanner old) {
    super.didUpdateWidget(old);
    if (old.slides.length != widget.slides.length) {
      _idx = _idx.clamp(
        0,
        widget.slides.isEmpty ? 0 : widget.slides.length - 1,
      );
      _restartAutoplay();
    }
  }

  void _startAutoplay() {
    if (widget.slides.length <= 1) return;
    if (_hovered) return;
    _timer = Timer.periodic(widget.autoplayInterval, (_) {
      if (!mounted || !_ctrl.hasClients) return;
      _goToPage((_idx + 1) % widget.slides.length, animate: true);
    });
  }

  void _restartAutoplay() {
    _timer?.cancel();
    _startAutoplay();
  }

  void _pauseAutoplay() {
    _timer?.cancel();
    _timer = null;
  }

  /// D-pad odağı slayt üzerine geldi/ayrıldı — otomatik ilerleme buna göre
  /// duraklatılır/devam ettirilir. Kullanıcı yön tuşları ile slaytı manuel
  /// değiştiriyorsa otomatik geçiş onu sürpriz şekilde değiştirmesin.
  void _setHovered(bool v) {
    if (_hovered == v) return;
    _hovered = v;
    if (v) {
      _pauseAutoplay();
    } else {
      _restartAutoplay();
    }
  }

  void _goToPage(int i, {bool animate = true}) {
    if (!_ctrl.hasClients) return;
    if (animate) {
      _ctrl.animateToPage(
        i,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    } else {
      _ctrl.jumpToPage(i);
    }
  }

  void _goNext() {
    if (widget.slides.length <= 1) return;
    _goToPage((_idx + 1) % widget.slides.length, animate: true);
  }

  void _goPrev() {
    if (widget.slides.length <= 1) return;
    final n = widget.slides.length;
    _goToPage((_idx - 1 + n) % n, animate: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    // 16:9 oranına yakın — telefonlarda ekran genişliğine göre.
    final w = size.width;
    final h = widget.isTv
        ? (w * 9 / 16).clamp(320.0, 480.0)
        : landscape
            ? (w * 9 / 16).clamp(120.0, 168.0)
            : (w * 9 / 16).clamp(180.0, 280.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: h,
          child: GestureDetector(
            onPanDown: (_) => _timer?.cancel(),
            onPanCancel: _restartAutoplay,
            onPanEnd: (_) => _restartAutoplay(),
            child: PageView.builder(
              controller: _ctrl,
              itemCount: widget.slides.length,
              onPageChanged: (i) {
                setState(() => _idx = i);
                if (Get.isRegistered<HomeController>()) {
                  Get.find<HomeController>().showcaseAmbientPoster.value =
                      widget.slides[i].posterUrl;
                }
              },
              itemBuilder: (context, i) => _HeroSlideView(
                slide: widget.slides[i],
                onHoverChanged: _setHovered,
                onPrev: _goPrev,
                onNext: _goNext,
                isTv: widget.isTv,
              ),
            ),
          ),
        ),
        SizedBox(height: widget.isTv ? 14 : 10),
        _Dots(count: widget.slides.length, index: _idx),
      ],
    );
  }
}

class _HeroSlideView extends StatefulWidget {
  const _HeroSlideView({
    required this.slide,
    required this.onHoverChanged,
    required this.onPrev,
    required this.onNext,
    this.isTv = false,
  });

  final FilmDiziHeroSlide slide;

  /// Slayt üzerindeki butonlardan biri D-pad odağı aldığında `true`,
  /// odak başka yere taşındığında `false` çağrılır → autoplay duraklatma.
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool isTv;

  @override
  State<_HeroSlideView> createState() => _HeroSlideViewState();
}

class _HeroSlideViewState extends State<_HeroSlideView> with SingleTickerProviderStateMixin {
  final FocusNode _playFocus = FocusNode(debugLabel: 'heroPlay');
  late final AnimationController _kenBurnsCtrl;

  @override
  void initState() {
    super.initState();
    _playFocus.addListener(_onAnyFocus);
    _kenBurnsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..forward();
  }

  @override
  void dispose() {
    _playFocus.removeListener(_onAnyFocus);
    _playFocus.dispose();
    _kenBurnsCtrl.dispose();
    super.dispose();
  }

  void _onAnyFocus() {
    final hasFocus = _playFocus.hasFocus;
    widget.onHoverChanged(hasFocus);
  }

  /// Sol/Sağ D-pad — eğer odak butonlardan biri ise butonlar arasında
  /// gezinirken slayt değişmesin. Aksi halde slaytlar arası geçiş yapar.
  KeyEventResult _handleSlideKey(KeyEvent ev) {
    if (ev is! KeyDownEvent && ev is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = ev.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft) {
      widget.onPrev();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      widget.onNext();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final title = widget.slide.title;
    final rating = widget.slide.rating;
    final settings = Get.find<AppSettingsService>();
    final remote = filmDiziRemoteNavEnabled(settings.layoutMode.value);
    final isTv = widget.isTv;

    Widget playBtn = ElevatedButton.icon(
      onPressed: widget.slide.onPlay,
      icon: Icon(Icons.play_arrow_rounded, size: isTv ? 24 : 20),
      label: Text('filmDizi.watch'.tr),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: EdgeInsets.symmetric(
          horizontal: isTv ? 22 : 14,
          vertical: isTv ? 12 : 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: TextStyle(
          fontSize: isTv ? 16 : 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (remote) {
      playBtn = TvDpadFocus(
        focusNode: _playFocus,
        onActivate: widget.slide.onPlay,
        borderRadius: 12,
        scaleOnFocus: isTv ? 1.08 : 1.05,
        child: playBtn,
      );
    }

    Widget body = Padding(
        padding: EdgeInsets.symmetric(horizontal: isTv ? 12 : 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isTv ? 22 : 16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Arkaplan — afişi 16:9 alanı kapsayacak ve kayarken parallax yapacak şekilde çiz.
              Positioned.fill(
                child: ClipRect(
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.15).animate(_kenBurnsCtrl),
                    child: Obx(() {
                      final p = settings.showcaseParallaxEnabled.value;
                      return p
                          ? Flow(
                              delegate: ParallaxFlowDelegate(
                                scrollable: _findVerticalScrollable(context),
                                listItemContext: context,
                              ),
                              children: [
                                RepaintBoundary(
                                  child: RecommendedFilmsPosterImage(
                                    url: widget.slide.posterUrl,
                                  ),
                                ),
                              ],
                            )
                          : RepaintBoundary(
                              child: RecommendedFilmsPosterImage(
                                url: widget.slide.posterUrl,
                              ),
                            );
                    }),
                  ),
                ),
              ),
              // Sol → sağ ve alt → üst koyu sinematik gradient (metin okunabilirliği).
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.62),
                        Colors.black.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.28, 0.58, 1.0],
                    ),
                  ),
                ),
              ),
              // Sol-alt: başlık, rating, butonlar.
              Positioned(
                left: isTv ? 28 : 14,
                right: isTv ? 28 : 14,
                bottom: isTv ? 22 : 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (rating > 0) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: isTv ? 24 : 18,
                            color: const Color(0xFFFFC107),
                          ),
                          SizedBox(width: isTv ? 6 : 4),
                          Text(
                            rating >= 10
                                ? rating.toStringAsFixed(0)
                                : rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTv ? 17 : 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isTv ? 8 : 4),
                    ],
                    if (widget.slide.tags.isNotEmpty) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.slide.tags.map((t) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isTv ? 12 : 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )).toList(),
                      ),
                      SizedBox(height: isTv ? 8 : 4),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTv ? 34 : 24,
                        fontWeight: FontWeight.w900,
                        height: 0.95,
                        letterSpacing: -1.0,
                        shadows: const [
                          Shadow(
                            color: Colors.black87,
                            offset: Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isTv ? 16 : 10),
                    Row(
                      children: [
                        playBtn,
                        const Spacer(),
                        if (widget.slide.nextSlidePreview != null)
                           _NextSlideHint(slide: widget.slide.nextSlidePreview!, isTv: isTv),
                        // Hafif tema vurgusu (köşede)
                        Container(
                          width: isTv ? 6 : 4,
                          height: isTv ? 36 : 24,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(2),
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
    );

    if (!remote) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.slide.onDetail,
        child: body,
      );
    }

    // TV/D-pad: slayt üzerinde yön tuşları slaytlar arasında geçiş yapar
    // (sol/sağ); butonlar kendi `arrow*` referansları ile aralarında gezinir.
    // Bu Focus widget'ı butonların *parent*'ı olduğundan, butonlar odakta
    // değilken (örn. ilk açılışta) sol/sağ slaytı değiştirir.
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (n, e) => _handleSlideKey(e),
      child: body,
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: active ? 18 : 6,
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _NextSlideHint extends StatelessWidget {
  const _NextSlideHint({required this.slide, required this.isTv});
  final FilmDiziHeroSlide slide;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (slide.posterUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: slide.posterUrl!,
                width: isTv ? 32 : 24,
                height: isTv ? 48 : 36,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          SizedBox(width: isTv ? 8 : 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sıradaki',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isTv ? 11 : 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                width: isTv ? 100 : 70,
                child: Text(
                  slide.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTv ? 13 : 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: isTv ? 4 : 2),
        ],
      ),
    );
  }
}

class ParallaxFlowDelegate extends FlowDelegate {
  ParallaxFlowDelegate({
    required this.scrollable,
    required this.listItemContext,
  }) : super(repaint: scrollable?.position);

  final ScrollableState? scrollable;
  final BuildContext listItemContext;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    if (scrollable == null) return constraints;
    return BoxConstraints.tightFor(
      width: constraints.maxWidth,
      height: constraints.maxHeight * 1.32,
    );
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final scr = scrollable;
    if (scr == null) {
      context.paintChild(0);
      return;
    }
    final scrollableSize = scr.context.size ?? Size.zero;
    final listItemBox = listItemContext.findRenderObject() as RenderBox?;
    if (listItemBox == null) {
      context.paintChild(0);
      return;
    }
    final listItemOffset = listItemBox.localToGlobal(
      Offset.zero,
      ancestor: scr.context.findRenderObject(),
    );
    final viewportPercentPosition = scrollableSize.height > 0
        ? (listItemOffset.dy / scrollableSize.height).clamp(0.0, 1.0)
        : 0.5;
    final dy = (viewportPercentPosition - 0.5) * (context.size.height * 0.32);

    context.paintChild(
      0,
      transform: Matrix4.translationValues(0.0, dy, 0.0),
    );
  }

  @override
  bool shouldRepaint(ParallaxFlowDelegate oldDelegate) {
    return scrollable != oldDelegate.scrollable ||
        listItemContext != oldDelegate.listItemContext;
  }
}

ScrollableState? _findVerticalScrollable(BuildContext context) {
  ScrollableState? result;
  context.visitAncestorElements((element) {
    if (element is StatefulElement && element.state is ScrollableState) {
      final state = element.state as ScrollableState;
      if (state.axisDirection == AxisDirection.up || state.axisDirection == AxisDirection.down) {
        result = state;
        return false;
      }
    }
    return true;
  });
  return result;
}

