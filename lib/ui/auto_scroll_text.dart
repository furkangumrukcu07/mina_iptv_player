import 'dart:async';

import 'package:flutter/material.dart';

/// Tek satır içerik adı: kullanılabilir genişliğe **sığıyorsa** olduğu gibi
/// (gerekirse [maxLines] satır + ellipsis) gösterilir; **sığmıyorsa** kısa bir
/// gecikme ([startDelay]) sonrası yavaşça yatay kayar (ileri-geri/ping-pong),
/// böylece uzun film/dizi/kanal isimleri tam okunabilir.
///
/// Ana ekran şeritlerinde (Mina AI, Karışık Canlı TV, İzlemeye Devam Et)
/// kart başlıkları için kullanılır.
class AutoScrollText extends StatelessWidget {
  const AutoScrollText({
    super.key,
    required this.text,
    required this.style,
    this.maxWidth,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.startDelay = const Duration(seconds: 2),
    this.paused = false,
  });

  final String text;
  final TextStyle style;

  /// `true` iken kaydırma animasyonu durdurulur (vsync ticker boşa düşer).
  /// OSD gizliyken görünmez metnin 60fps dönmesini önlemek için kullanılır;
  /// `false`'a dönünce baştan başlar.
  final bool paused;

  /// Verilirse [LayoutBuilder] yerine bu genişlik baz alınır. İçeriğine göre
  /// büyüyen kaplar (ör. otomatik genişleyen cam çipler) için gereklidir;
  /// `null` ise üst kısıtlardan gelen `maxWidth` kullanılır.
  final double? maxWidth;
  final int maxLines;
  final TextAlign textAlign;
  final Duration startDelay;

  @override
  Widget build(BuildContext context) {
    if (maxWidth != null) {
      return _build(context, maxWidth!);
    }
    return LayoutBuilder(
      builder: (context, constraints) => _build(context, constraints.maxWidth),
    );
  }

  Widget _build(BuildContext context, double maxW) {
    if (maxW <= 0 || !maxW.isFinite) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      );
    }

    final direction = Directionality.of(context);
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: direction,
    )..layout(maxWidth: double.infinity);
    final textW = tp.width;
    final overflow = textW > maxW + 1;

    if (!overflow) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      );
    }

    return SizedBox(
      width: maxW,
      child: _AutoScrollMarquee(
        // Metin değişince (ör. yatay liste kart geri dönüşümü / şerit yeniden
        // sıralaması) eski kaydırma mesafesi yeni metne uygulanmasın diye
        // metne bağlı bir key veriyoruz; böylece State temiz kurulur.
        key: ValueKey(text),
        text: text,
        style: style,
        textWidth: textW,
        viewportWidth: maxW,
        startDelay: startDelay,
        textDirection: direction,
        paused: paused,
      ),
    );
  }
}

class _AutoScrollMarquee extends StatefulWidget {
  const _AutoScrollMarquee({
    super.key,
    required this.text,
    required this.style,
    required this.textWidth,
    required this.viewportWidth,
    required this.startDelay,
    required this.textDirection,
    this.paused = false,
  });

  final String text;
  final TextStyle style;
  final double textWidth;
  final double viewportWidth;
  final Duration startDelay;
  final TextDirection textDirection;
  final bool paused;

  @override
  State<_AutoScrollMarquee> createState() => _AutoScrollMarqueeState();
}

class _AutoScrollMarqueeState extends State<_AutoScrollMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _travel = 0;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _configureForCurrentText();
  }

  /// [_travel], süre ve animasyonu **güncel metin/genişliğe göre** kurar.
  /// `initState` dışında [didUpdateWidget] tarafından da çağrılır; böylece
  /// widget yeniden kullanıldığında (liste geri dönüşümü / şerit yeniden
  /// sıralaması) eski mesafe kalıp metni ekran dışına itmez.
  void _configureForCurrentText() {
    _startTimer?.cancel();
    _controller.stop();
    _controller.value = 0; // başa sar — başlık başı görünür.
    _travel = (widget.textWidth - widget.viewportWidth).clamp(0.0, 4000.0);
    if (_travel <= 0) return;
    // ~16 px/sn yavaş hız; çok uzun isimlerde süre üst sınırla makul kalır.
    final ms = (_travel / 16 * 1000).round().clamp(8000, 90000);
    _controller.duration = Duration(milliseconds: ms);
    // Duraklatılmışsa (ör. OSD gizli) animasyonu hiç başlatma; vsync ticker
    // boşa düşsün. paused → false olunca didUpdateWidget yeniden kurar.
    if (widget.paused) return;
    _startTimer = Timer(widget.startDelay, () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void didUpdateWidget(covariant _AutoScrollMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.textWidth != widget.textWidth ||
        oldWidget.viewportWidth != widget.viewportWidth ||
        oldWidget.startDelay != widget.startDelay) {
      _configureForCurrentText();
      return;
    }
    if (oldWidget.paused != widget.paused) {
      if (widget.paused) {
        _startTimer?.cancel();
        _controller.stop();
      } else {
        // Tekrar görünür: baştan kaydır (başlık başı görünür).
        _configureForCurrentText();
      }
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final offset = -_controller.value * _travel;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: Text(
          widget.text,
          style: widget.style,
          maxLines: 1,
          softWrap: false,
          textDirection: widget.textDirection,
        ),
      ),
    );
  }
}

/// Çok satırlı metin: alana sığıyorsa sabit; sığmıyorsa dikey ping-pong kayar.
class AutoScrollVerticalText extends StatelessWidget {
  const AutoScrollVerticalText({
    super.key,
    required this.text,
    required this.style,
    this.startDelay = const Duration(seconds: 2),
    this.paused = false,
    /// Verilirse görünür alan en fazla bu kadar satır yüksekliğinde tutulur;
    /// metin daha uzunsa kaydırma başlar (hero EPG özeti gibi).
    this.maxVisibleLines,
  });

  final String text;
  final TextStyle style;
  final Duration startDelay;
  final bool paused;
  final int? maxVisibleLines;

  double _lineHeight(TextStyle s) =>
      (s.fontSize ?? 14) * (s.height ?? 1.0);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        if (maxW <= 0 ||
            maxH <= 0 ||
            !maxW.isFinite ||
            !maxH.isFinite) {
          return Text(
            text,
            style: style,
            maxLines: maxVisibleLines ?? 3,
            overflow: TextOverflow.ellipsis,
          );
        }

        final direction = Directionality.of(context);
        final tp = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: direction,
          maxLines: null,
        )..layout(maxWidth: maxW);

        final lineH = _lineHeight(style);
        final cappedH = maxVisibleLines != null
            ? (lineH * maxVisibleLines!).clamp(0.0, maxH)
            : maxH;

        if (tp.height <= cappedH + 1) {
          return SizedBox(
            width: maxW,
            child: Text(
              text,
              style: style,
              maxLines: maxVisibleLines,
              overflow: maxVisibleLines != null
                  ? TextOverflow.ellipsis
                  : TextOverflow.clip,
            ),
          );
        }

        return SizedBox(
          width: maxW,
          height: cappedH,
          child: _AutoScrollVerticalMarquee(
            key: ValueKey(text),
            text: text,
            style: style,
            textHeight: tp.height,
            viewportHeight: cappedH,
            maxWidth: maxW,
            startDelay: startDelay,
            textDirection: direction,
            paused: paused,
          ),
        );
      },
    );
  }
}

class _AutoScrollVerticalMarquee extends StatefulWidget {
  const _AutoScrollVerticalMarquee({
    super.key,
    required this.text,
    required this.style,
    required this.textHeight,
    required this.viewportHeight,
    required this.maxWidth,
    required this.startDelay,
    required this.textDirection,
    this.paused = false,
  });

  final String text;
  final TextStyle style;
  final double textHeight;
  final double viewportHeight;
  final double maxWidth;
  final Duration startDelay;
  final TextDirection textDirection;
  final bool paused;

  @override
  State<_AutoScrollVerticalMarquee> createState() =>
      _AutoScrollVerticalMarqueeState();
}

class _AutoScrollVerticalMarqueeState extends State<_AutoScrollVerticalMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _travel = 0;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _configureForCurrentText();
  }

  void _configureForCurrentText() {
    _startTimer?.cancel();
    _controller.removeStatusListener(_onStatus);
    _controller.stop();
    _controller.value = 0;
    _travel =
        (widget.textHeight - widget.viewportHeight).clamp(0.0, 4000.0);
    if (_travel <= 0) return;
    final ms = (_travel / 12 * 1000).round().clamp(8000, 90000);
    _controller.duration = Duration(milliseconds: ms);
    if (widget.paused) return;
    _startTimer = Timer(widget.startDelay, () {
      if (mounted) {
        _controller.addStatusListener(_onStatus);
        _controller.forward();
      }
    });
  }

  // Animasyon bitince: kısa bir duraklama ardından başa sıfırlayıp tekrar oynat.
  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _startTimer?.cancel();
      _startTimer = Timer(const Duration(seconds: 1), () {
        if (mounted && !widget.paused) {
          _controller.value = 0;
          _controller.forward();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _AutoScrollVerticalMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.textHeight != widget.textHeight ||
        oldWidget.viewportHeight != widget.viewportHeight ||
        oldWidget.startDelay != widget.startDelay) {
      _configureForCurrentText();
      return;
    }
    if (oldWidget.paused != widget.paused) {
      if (widget.paused) {
        _startTimer?.cancel();
        _controller.stop();
      } else {
        _configureForCurrentText();
      }
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final offset = -_controller.value * _travel;
          return Transform.translate(
            offset: Offset(0, offset),
            child: child,
          );
        },
        child: SizedBox(
          width: widget.maxWidth,
          child: Text(
            widget.text,
            style: widget.style,
            textDirection: widget.textDirection,
          ),
        ),
      ),
    );
  }
}
