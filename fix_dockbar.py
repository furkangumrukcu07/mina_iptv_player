import sys
import re

file_path = 'lib/modules/home/widgets/home_showcase_view.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add state to _GlassDockState
content = content.replace(
    'class _GlassDockState extends State<_GlassDock> {\n  static const double _radius = 28;',
    'class _GlassDockState extends State<_GlassDock> with TickerProviderStateMixin {\n  static const double _radius = 28;\n\n  double? _panX;\n  int? _hoveredIndex;\n  late final AnimationController _bubbleOpacity = AnimationController(\n    vsync: this,\n    duration: const Duration(milliseconds: 250),\n  );\n\n  @override\n  void dispose() {\n    _bubbleOpacity.dispose();\n    super.dispose();\n  }\n\n  void _updatePan(Offset localPosition, double width) {\n    final x = localPosition.dx.clamp(0.0, width);\n    final segmentWidth = width / _items().length;\n    final index = (x / segmentWidth).floor().clamp(0, _items().length - 1);\n    setState(() {\n      _panX = x;\n      _hoveredIndex = index;\n    });\n    _bubbleOpacity.forward();\n  }\n\n  void _endPan() {\n    setState(() {\n      _hoveredIndex = null;\n    });\n    _bubbleOpacity.reverse();\n  }'
)

# 2. Wrap Stack with LayoutBuilder & Listener
old_stack = '''                child: Stack(\n                  // Sekme butonları çubuğun tam dikey ortasına hizalansın\n                  // (önceden Stack varsayılan topStart ile üste yapışıyordu).\n                  alignment: Alignment.center,\n                  children: [\n                    // Üst kenar ışıltısı — cam «damla» hissi için ince specular.\n                    Positioned('''

new_stack = '''                child: LayoutBuilder(\n                  builder: (context, constraints) {\n                    final width = constraints.maxWidth;\n                    return Listener(\n                      onPointerDown: (e) => _updatePan(e.localPosition, width),\n                      onPointerMove: (e) => _updatePan(e.localPosition, width),\n                      onPointerUp: (_) => _endPan(),\n                      onPointerCancel: (_) => _endPan(),\n                      child: Stack(\n                        alignment: Alignment.center,\n                        children: [\n                          // Üst kenar ışıltısı — cam «damla» hissi için ince specular.\n                          Positioned('''

content = content.replace(old_stack, new_stack)

old_row = '''                    Row(\n                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,\n                      children: [\n                        for (int i = 0; i < items.length; i++)\n                          Expanded(\n                            child: _DockButton(item: items[i]),\n                          ),\n                      ],\n                    ),\n                  ],\n                ),'''

new_row = '''                    AnimatedBuilder(\n                      animation: _bubbleOpacity,\n                      builder: (context, _) {\n                        return CustomPaint(\n                          size: Size(width, _GlassDock.height),\n                          painter: _WaterDropPainter(\n                            panX: _panX,\n                            opacity: _bubbleOpacity.value,\n                            accent: _hoveredIndex != null ? items[_hoveredIndex!].accent : Colors.white,\n                          ),\n                        );\n                      }\n                    ),\n                    Row(\n                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,\n                      children: [\n                        for (int i = 0; i < items.length; i++)\n                          Expanded(\n                            child: _DockButton(\n                              item: items[i],\n                              isHovered: i == _hoveredIndex,\n                            ),\n                          ),\n                      ],\n                    ),\n                  ],\n                ),\n              );\n            },'''

content = content.replace(old_row, new_row)

# 3. Update _DockButton
content = content.replace(
    'const _DockButton({required this.item});',
    'const _DockButton({required this.item, this.isHovered = false});'
)
content = content.replace(
    'final _DockItem item;',
    'final _DockItem item;\n  final bool isHovered;'
)
content = content.replace(
    'final targetScale = _pressed ? 0.84 : 1.0;',
    'final targetScale = _pressed ? 0.84 : (widget.isHovered ? 1.25 : 1.0);'
)

# 4. Update _DockCircleButton
old_circle_deco = '''                                child: Container(\n                                  decoration: BoxDecoration(\n                                    shape: BoxShape.circle,\n                                    color: accent.withValues(alpha: opacity * 0.25),\n                                    border: Border.all(\n                                      color: Colors.white.withValues(alpha: opacity * 0.85),\n                                      width: 1.5 + (1 - t) * 2.5,\n                                    ),\n                                    boxShadow: [\n                                      BoxShadow(\n                                        color: accent.withValues(alpha: opacity * 0.6),\n                                        blurRadius: 16 * t,\n                                        spreadRadius: 6 * t,\n                                      ),\n                                    ],\n                                  ),\n                                ),'''

new_circle_deco = '''                                child: CustomPaint(\n                                  painter: _WaterDropRipplePainter(\n                                    opacity: opacity,\n                                    accent: accent,\n                                    strokeWidth: 1.5 + (1 - t) * 2.5,\n                                    blurRadius: 16 * t,\n                                  ),\n                                ),'''
content = content.replace(old_circle_deco, new_circle_deco)

old_button_deco = '''                            child: Container(\n                              decoration: BoxDecoration(\n                                shape: BoxShape.circle,\n                                color: accent.withValues(alpha: opacity * 0.25),\n                                border: Border.all(\n                                  color: Colors.white.withValues(alpha: opacity * 0.85),\n                                  width: 1.5 + (1 - t) * 2.5,\n                                ),\n                                boxShadow: [\n                                  BoxShadow(\n                                    color: accent.withValues(alpha: opacity * 0.6),\n                                    blurRadius: 16 * t,\n                                    spreadRadius: 6 * t,\n                                  ),\n                                ],\n                              ),\n                            ),'''

new_button_deco = '''                            child: CustomPaint(\n                              painter: _WaterDropRipplePainter(\n                                opacity: opacity,\n                                accent: accent,\n                                strokeWidth: 1.5 + (1 - t) * 2.5,\n                                blurRadius: 16 * t,\n                              ),\n                            ),'''
content = content.replace(old_button_deco, new_button_deco)

painters_code = '''
class _WaterDropPainter extends CustomPainter {
  _WaterDropPainter({required this.panX, required this.opacity, required this.accent});
  final double? panX;
  final double opacity;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (panX == null || opacity <= 0.001) return;
    
    final center = Offset(panX!, size.height / 2);
    final radius = 26.0 + (opacity * 4.0);

    final rPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.redAccent.withValues(alpha: opacity * 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      
    final bPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.blueAccent.withValues(alpha: opacity * 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      
    final gPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.greenAccent.withValues(alpha: opacity * 0.9);

    final fillPaint = Paint()
      ..color = accent.withValues(alpha: opacity * 0.35)
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: opacity * 0.95);

    canvas.drawCircle(center.translate(-2.0, 0), radius, rPaint);
    canvas.drawCircle(center.translate(2.0, 0), radius, bPaint);
    canvas.drawCircle(center, radius, gPaint);
    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _WaterDropPainter oldDelegate) {
    return panX != oldDelegate.panX || opacity != oldDelegate.opacity || accent != oldDelegate.accent;
  }
}

class _WaterDropRipplePainter extends CustomPainter {
  _WaterDropRipplePainter({
    required this.opacity,
    required this.accent,
    required this.strokeWidth,
    required this.blurRadius,
  });
  final double opacity;
  final Color accent;
  final double strokeWidth;
  final double blurRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.001) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (blurRadius > 0) {
      final shadowPaint = Paint()
        ..color = accent.withValues(alpha: opacity * 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);
      canvas.drawCircle(center, radius, shadowPaint);
    }

    final rPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 1.0
      ..color = Colors.redAccent.withValues(alpha: opacity * 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      
    final bPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 1.0
      ..color = Colors.blueAccent.withValues(alpha: opacity * 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      
    final gPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.greenAccent.withValues(alpha: opacity * 0.9);

    final fillPaint = Paint()
      ..color = accent.withValues(alpha: opacity * 0.25)
      ..style = PaintingStyle.fill;
      
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withValues(alpha: opacity * 0.85);

    canvas.drawCircle(center.translate(-1.5, 0), radius, rPaint);
    canvas.drawCircle(center.translate(1.5, 0), radius, bPaint);
    canvas.drawCircle(center, radius, gPaint);
    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _WaterDropRipplePainter oldDelegate) => true;
}
'''

content = content + painters_code

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Successfully applied chromatic aberration water drop effect!")
