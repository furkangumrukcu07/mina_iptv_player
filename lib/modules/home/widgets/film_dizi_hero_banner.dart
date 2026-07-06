import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart' show filmDiziRemoteNavEnabled;
import '../../../core/services/app_settings_service.dart';
import '../../../ui/tv_dpad_focus.dart';
import 'recommended_films_poster_grid.dart';

/// Hero banner'da gösterilecek tek bir slayt verisi — VOD ve dizi için ortak.
class FilmDiziHeroSlide {
  const FilmDiziHeroSlide({
    required this.title,
    required this.posterUrl,
    required this.rating,
    required this.onPlay,
    required this.onDetail,
  });

  final String title;
  final String? posterUrl;

  /// 0 olduğunda puan satırı (yıldız + skor) gizlenir (örn. dizilerde).
  final double rating;
  final VoidCallback onPlay;
  final VoidCallback onDetail;
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
    _ctrl = PageController(viewportFraction: 1.0);
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
              onPageChanged: (i) => setState(() => _idx = i),
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

class _HeroSlideViewState extends State<_HeroSlideView> {
  final FocusNode _playFocus = FocusNode(debugLabel: 'heroPlay');
  final FocusNode _detailFocus = FocusNode(debugLabel: 'heroDetail');

  @override
  void initState() {
    super.initState();
    _playFocus.addListener(_onAnyFocus);
    _detailFocus.addListener(_onAnyFocus);
  }

  @override
  void dispose() {
    _playFocus.removeListener(_onAnyFocus);
    _detailFocus.removeListener(_onAnyFocus);
    _playFocus.dispose();
    _detailFocus.dispose();
    super.dispose();
  }

  void _onAnyFocus() {
    final hasFocus = _playFocus.hasFocus || _detailFocus.hasFocus;
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
    final remote = filmDiziRemoteNavEnabled(
      Get.find<AppSettingsService>().layoutMode.value,
    );
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

    Widget detailBtn = OutlinedButton(
      onPressed: widget.slide.onDetail,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.65),
          width: isTv ? 1.6 : 1.0,
        ),
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
      child: Text('filmDizi.detail'.tr),
    );

    if (remote) {
      playBtn = TvDpadFocus(
        focusNode: _playFocus,
        onActivate: widget.slide.onPlay,
        arrowRight: _detailFocus,
        borderRadius: 12,
        scaleOnFocus: isTv ? 1.08 : 1.05,
        child: playBtn,
      );
      detailBtn = TvDpadFocus(
        focusNode: _detailFocus,
        onActivate: widget.slide.onDetail,
        arrowLeft: _playFocus,
        borderRadius: 12,
        scaleOnFocus: isTv ? 1.08 : 1.05,
        child: detailBtn,
      );
    }

    Widget body = Padding(
        padding: EdgeInsets.symmetric(horizontal: isTv ? 24 : 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isTv ? 22 : 16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Arkaplan — afişi 16:9 alanı kapsayacak ve kayarken parallax yapacak şekilde çiz.
              Positioned.fill(
                child: ClipRect(
                  child: Flow(
                    delegate: ParallaxFlowDelegate(
                      scrollable: Scrollable.maybeOf(context),
                      listItemContext: context,
                    ),
                    children: [
                      RepaintBoundary(
                        child: RecommendedFilmsPosterImage(
                          url: widget.slide.posterUrl,
                        ),
                      ),
                    ],
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
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTv ? 30 : 20,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isTv ? 16 : 10),
                    Row(
                      children: [
                        playBtn,
                        SizedBox(width: isTv ? 12 : 8),
                        detailBtn,
                        const Spacer(),
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
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: i == index ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == index
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
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
