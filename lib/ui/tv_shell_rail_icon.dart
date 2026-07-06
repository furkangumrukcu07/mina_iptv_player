import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tv/tv_shell_section.dart';

/// TV sol menü — özgün ince çizgi ikonlar (Material / üçüncü parti set yok).
class TvShellRailIcon extends StatelessWidget {
  const TvShellRailIcon({
    super.key,
    required this.section,
    required this.color,
    this.size = 26,
    this.strokeWidth = 1.75,
  });

  final TvShellSection section;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TvShellRailIconPainter(
        section: section,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _TvShellRailIconPainter extends CustomPainter {
  _TvShellRailIconPainter({
    required this.section,
    required this.color,
    required this.strokeWidth,
  });

  final TvShellSection section;
  final Color color;
  final double strokeWidth;

  static const double _v = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _v;
    canvas.save();
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (section) {
      case TvShellSection.search:
        _drawSearch(canvas, paint);
      case TvShellSection.live:
        _drawLive(canvas, paint);
      case TvShellSection.movies:
        _drawMovies(canvas, paint);
      case TvShellSection.series:
        _drawSeries(canvas, paint);
      case TvShellSection.continueWatching:
        _drawContinue(canvas, paint);
      case TvShellSection.playlists:
        _drawPlaylists(canvas, paint);
      case TvShellSection.wrapper:
        _drawWrapper(canvas, paint);
      case TvShellSection.repeat:
        _drawRepeat(canvas, paint);
      case TvShellSection.settings:
        _drawSettings(canvas, paint);
    }
    canvas.restore();
  }

  void _drawSearch(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(10.5, 10.5), 5.5, paint);
    canvas.drawLine(const Offset(14.8, 14.8), const Offset(19.5, 19.5), paint);
  }

  void _drawLive(Canvas canvas, Paint paint) {
    final screen = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4.5, 5, 15, 10.5),
      const Radius.circular(2.2),
    );
    canvas.drawRRect(screen, paint);
    canvas.drawLine(const Offset(8.5, 19), const Offset(15.5, 19), paint);
    canvas.drawLine(const Offset(12, 15.5), const Offset(12, 19), paint);
    final play = Path()
      ..moveTo(10.2, 8.2)
      ..lineTo(10.2, 12.3)
      ..lineTo(14.2, 10.25)
      ..close();
    canvas.drawPath(play, paint..style = PaintingStyle.stroke);
    paint.style = PaintingStyle.stroke;
  }

  void _drawMovies(Canvas canvas, Paint paint) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(5, 4.5, 14, 15),
      const Radius.circular(2),
    );
    canvas.drawRRect(body, paint);
    for (final y in [7.5, 12.0, 16.5]) {
      canvas.drawCircle(Offset(7.2, y), 1.1, paint);
      canvas.drawCircle(Offset(16.8, y), 1.1, paint);
    }
    canvas.drawLine(const Offset(9.5, 4.5), const Offset(9.5, 19.5), paint);
    canvas.drawLine(const Offset(14.5, 4.5), const Offset(14.5, 19.5), paint);
  }

  void _drawSeries(Canvas canvas, Paint paint) {
    final back = RRect.fromRectAndRadius(
      const Rect.fromLTWH(7.5, 4, 12.5, 14),
      const Radius.circular(2.2),
    );
    final front = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 7, 12.5, 14),
      const Radius.circular(2.2),
    );
    canvas.drawRRect(back, paint);
    canvas.drawRRect(front, paint);
    canvas.drawLine(const Offset(7, 11), const Offset(13, 11), paint);
    canvas.drawLine(const Offset(7, 14.5), const Offset(13, 14.5), paint);
    canvas.drawLine(const Offset(7, 18), const Offset(11, 18), paint);
  }

  void _drawContinue(Canvas canvas, Paint paint) {
    canvas.drawArc(
      const Rect.fromLTWH(4, 4, 16, 16),
      -math.pi * 0.72,
      math.pi * 1.55,
      false,
      paint,
    );
    final play = Path()
      ..moveTo(10.5, 9)
      ..lineTo(10.5, 15)
      ..lineTo(16, 12)
      ..close();
    canvas.drawPath(play, paint);
  }

  void _drawPlaylists(Canvas canvas, Paint paint) {
    final play = Path()
      ..moveTo(5, 8)
      ..lineTo(5, 12.5)
      ..lineTo(9.2, 10.25)
      ..close();
    canvas.drawPath(play, paint);
    canvas.drawLine(const Offset(12, 8.5), const Offset(19, 8.5), paint);
    canvas.drawLine(const Offset(12, 12), const Offset(18, 12), paint);
    canvas.drawLine(const Offset(12, 15.5), const Offset(19.5, 15.5), paint);
  }

  void _drawWrapper(Canvas canvas, Paint paint) {
    final frame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4.5, 5, 15, 14),
      const Radius.circular(2.4),
    );
    canvas.drawRRect(frame, paint);
    final trend = Path()
      ..moveTo(7.5, 15)
      ..lineTo(10.5, 12)
      ..lineTo(13.2, 13.5)
      ..lineTo(17, 8.5);
    canvas.drawPath(trend, paint);
    canvas.drawCircle(const Offset(17, 8.5), 1.2, paint);
  }

  void _drawRepeat(Canvas canvas, Paint paint) {
    canvas.drawArc(
      const Rect.fromLTWH(5, 5, 14, 14),
      math.pi * 0.15,
      math.pi * 1.35,
      false,
      paint,
    );
    _arrowHead(canvas, paint, const Offset(17.8, 9.2), -0.55);
    canvas.drawArc(
      const Rect.fromLTWH(5, 5, 14, 14),
      math.pi * 1.15,
      math.pi * 1.35,
      false,
      paint,
    );
    _arrowHead(canvas, paint, const Offset(6.2, 14.8), 2.6);
  }

  void _arrowHead(Canvas canvas, Paint paint, Offset tip, double angle) {
    const len = 3.2;
    final left = Offset(
      tip.dx + len * math.cos(angle + 2.5),
      tip.dy + len * math.sin(angle + 2.5),
    );
    final right = Offset(
      tip.dx + len * math.cos(angle - 2.5),
      tip.dy + len * math.sin(angle - 2.5),
    );
    canvas.drawLine(tip, left, paint);
    canvas.drawLine(tip, right, paint);
  }

  void _drawSettings(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(12, 12), 3.2, paint);
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final inner = Offset(12 + 5.2 * math.cos(a), 12 + 5.2 * math.sin(a));
      final outer = Offset(12 + 7.2 * math.cos(a), 12 + 7.2 * math.sin(a));
      canvas.drawLine(inner, outer, paint);
      final side = a + math.pi / 6;
      final c1 = Offset(12 + 7.2 * math.cos(side), 12 + 7.2 * math.sin(side));
      final c2 = Offset(
        12 + 7.2 * math.cos(side + math.pi / 3),
        12 + 7.2 * math.sin(side + math.pi / 3),
      );
      canvas.drawLine(outer, c1, paint);
      canvas.drawLine(outer, c2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TvShellRailIconPainter oldDelegate) {
    return oldDelegate.section != section ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
