import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Dairesel hiz gostergesi (Gauge) widget'i
class SpeedTestGauge extends StatelessWidget {
  final double currentSpeed;
  final double maxSpeed;
  final bool isTesting;
  final Widget? centerWidget;
  final Color? progressColor;
  final double strokeWidth;
  final bool isTvMode;

  const SpeedTestGauge({
    super.key,
    required this.currentSpeed,
    this.maxSpeed = 100.0,
    this.isTesting = false,
    this.centerWidget,
    this.progressColor,
    this.strokeWidth = 12.0,
    this.isTvMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SizedBox(
      width: isTvMode ? 300 : 200,
      height: isTvMode ? 300 : 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arka plan dairesel progress
          _buildBackgroundGauge(colorScheme),
          
          // Hiz progress'i
          _buildSpeedProgress(colorScheme),
          
          // Merkezdeki widget (logo veya hiz degeri)
          centerWidget ?? _buildDefaultCenter(),
          
          // Test animasyonu
          if (isTesting) _buildTestAnimation(),
        ],
      ),
    );
  }

  /// Arka plan dairesel gosterge
  Widget _buildBackgroundGauge(ColorScheme colorScheme) {
    return CustomPaint(
      size: const Size(200, 200),
      painter: _GaugeBackgroundPainter(
        color: colorScheme.surfaceVariant.withOpacity(0.3),
        strokeWidth: strokeWidth,
      ),
    );
  }

  /// Hiz progress gostergesi
  Widget _buildSpeedProgress(ColorScheme colorScheme) {
    return CustomPaint(
      size: Size(isTvMode ? 300 : 200, isTvMode ? 300 : 200),
      painter: _SpeedProgressPainter(
        progress: (currentSpeed / maxSpeed).clamp(0.0, 1.0),
        color: progressColor ?? _getSpeedColor(currentSpeed),
        strokeWidth: strokeWidth,
        isAnimated: isTesting,
      ),
    );
  }

  /// Varsayilan merkez widget (hiz degeri) - TV modunda daha büyük
  Widget _buildDefaultCenter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mina Player logosu
        Container(
          width: isTvMode ? 60 : 40,
          height: isTvMode ? 60 : 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(isTvMode ? 12 : 8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: isTvMode ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isTvMode ? 10 : 6),
            child: Image.asset(
              'assets/images/new_logo.png',
              width: isTvMode ? 48 : 32,
              height: isTvMode ? 48 : 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.speed,
                  size: isTvMode ? 36 : 24,
                  color: Colors.grey[600],
                );
              },
            ),
          ),
        ),
        SizedBox(height: isTvMode ? 12 : 8),
        
        // Hiz degeri
        Text(
          isTesting ? '0.0' : currentSpeed.toStringAsFixed(1),
          style: TextStyle(
            fontSize: isTvMode ? 36 : 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(Get.context!).colorScheme.onSurface,
          ),
        ),
        Text(
          'Mbps',
          style: TextStyle(
            fontSize: isTvMode ? 18 : 12,
            color: Theme.of(Get.context!).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Test animasyonu (donen noktalar)
  Widget _buildTestAnimation() {
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: const AlwaysStoppedAnimation(0),
        builder: (context, child) {
          return Transform.rotate(
            angle: DateTime.now().millisecondsSinceEpoch * 0.001,
            child: CustomPaint(
              size: const Size(200, 200),
              painter: _TestAnimationPainter(),
            ),
          );
        },
      ),
    );
  }

  /// Hiz rengini getir
  Color _getSpeedColor(double speed) {
    if (speed < 5.0) {
      return const Color(0xFFFF5252); // Kirmizi
    } else if (speed < 12.0) {
      return const Color(0xFFFFC107); // Sari
    } else {
      return const Color(0xFF4CAF50); // Yesil
    }
  }
}

/// Arka plan dairesel gosterge painter
class _GaugeBackgroundPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _GaugeBackgroundPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Tam bir daire ciz (arka plan)
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Hiz progress painter
class _SpeedProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final bool isAnimated;

  _SpeedProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    this.isAnimated = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 270 derecelik yay ciz (ustten baslayip saga dogru)
    const startAngle = -math.pi * 0.75; // -135 derece
    final sweepAngle = math.pi * 1.5 * progress; // 270 derece * progress

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _SpeedProgressPainter &&
        (oldDelegate.progress != progress || oldDelegate.isAnimated != isAnimated);
  }
}

/// Test animasyonu painter
class _TestAnimationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 20) / 2;

    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    // 3 adet donen nokta
    for (int i = 0; i < 3; i++) {
      final angle = (i * 2 * math.pi / 3);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      canvas.drawCircle(Offset(x, y), 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
