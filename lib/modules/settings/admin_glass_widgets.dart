import 'dart:ui';
import 'package:flutter/material.dart';

class AdminGlassBackground extends StatelessWidget {
  const AdminGlassBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Vibrant mesh gradient background
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2E0942), // Dark violet
                  Color(0xFF0F1E4C), // Deep blue
                  Color(0xFF5A1A45), // Magenta
                  Color(0xFF133667), // Bright blue
                ],
              ),
            ),
          ),
        ),
        // A couple of blurred floating orbs for the mesh effect
        Positioned(
          top: -50,
          left: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00F0FF).withOpacity(0.15),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -50,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF0055).withOpacity(0.15),
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.transparent),
          ),
        ),
        // Content
        SafeArea(child: child),
      ],
    );
  }
}

class AdminGlassCard extends StatelessWidget {
  const AdminGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.disableBlur = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final bool disableBlur;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: content,
        ),
      );
    }

    if (disableBlur) {
      return Padding(
        padding: margin,
        child: content,
      );
    }

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: content,
        ),
      ),
    );
  }
}
