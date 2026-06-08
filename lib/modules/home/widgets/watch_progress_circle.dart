import 'package:flutter/material.dart';

/// İzlenme oranını poster köşesinde **daire içinde yüzde** olarak gösteren
/// zarif cam rozet: dış halka ilerlemeyi (accent), ortadaki metin yüzdeyi
/// gösterir. Poster afişinin boş köşesine [Positioned] ile yerleştirilir.
class WatchProgressCircle extends StatelessWidget {
  const WatchProgressCircle({
    super.key,
    required this.fraction,
    required this.accent,
    this.size = 30,
  });

  /// 0.0–1.0 arası izlenme oranı.
  final double fraction;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    final pct = (f * 100).round().clamp(1, 100);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(2.4),
            child: SizedBox.expand(
              child: CircularProgressIndicator(
                value: f,
                strokeWidth: 2.4,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.16),
              child: Text(
                '%$pct',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.30,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
