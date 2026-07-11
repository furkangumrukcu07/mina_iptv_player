import 'package:flutter/material.dart';

/// Kurulum / ayar ekranında uygulama içi PiP davranışını anlatan statik önizleme.
class ShowcaseInAppPipSetupPreview extends StatelessWidget {
  const ShowcaseInAppPipSetupPreview({super.key});

  static const Color _accent = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.55,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141820), Color(0xFF0A0D12)],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Tam ekran oynatıcı (üst)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF1A237E).withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.35),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.play_circle_filled_rounded,
                      size: 44,
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                ),
              ),
              // Ana ekran kartları (alt)
              Positioned(
                left: 14,
                right: 14,
                bottom: 52,
                child: Row(
                  children: [
                    _miniCard(const Color(0xFFEF5350)),
                    const SizedBox(width: 6),
                    _miniCard(const Color(0xFFFFC107)),
                    const SizedBox(width: 6),
                    _miniCard(const Color(0xFF42A5F5)),
                  ],
                ),
              ),
              // Dock çubuğu
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                height: 34,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withValues(alpha: 0.1),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
              // PiP dikdörtgeni (dock üstü sağ, arama butonunun üstü)
              Positioned(
                right: 18,
                bottom: 46,
                child: Container(
                  width: 72,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _accent.withValues(alpha: 0.75),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _accent.withValues(alpha: 0.85),
                                const Color(0xFF1B5E20),
                              ],
                            ),
                          ),
                        ),
                        Center(
                          child: Icon(
                            Icons.live_tv_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Geri ok ipucu
              Positioned(
                left: 14,
                top: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 36,
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniCard(Color color) {
    return Expanded(
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: color.withValues(alpha: 0.35),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}
