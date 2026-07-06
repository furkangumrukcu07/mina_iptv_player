import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RotatingSettingsIcon extends StatefulWidget {
  const RotatingSettingsIcon({super.key});

  @override
  State<RotatingSettingsIcon> createState() => _RotatingSettingsIconState();
}

class _RotatingSettingsIconState extends State<RotatingSettingsIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _controller.repeat(); // Slow continuous rotation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(
        Icons.settings_rounded,
        color: Colors.white.withValues(alpha: 0.95),
        size: 22,
        semanticLabel: 'settings.title'.tr,
      ),
    );
  }
}
