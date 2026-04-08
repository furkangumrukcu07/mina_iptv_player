import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../core/services/epg_service.dart';
import '../../../domain/entities/channel.dart';
import '../player_controller.dart';

/// TV canlıda `isBusy` iken BetterPlayer yok; cam OSD kaybolmasın diye alt şerit.
class TvLiveBusyOsd extends StatelessWidget {
  const TvLiveBusyOsd({super.key, required this.controller});

  final PlayerController controller;

  static String _epgLine(Channel ch) {
    final epg = Get.find<EpgService>();
    final prog = epg.getCurrentProgramme(ch.epgChannelId);
    String fmt(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (prog != null) {
      return '${fmt(prog.start)}–${fmt(prog.end)} · ${prog.title}';
    }
    if (ch.epgChannelId != null && epg.isLoading.value) {
      return 'EPG yükleniyor…';
    }
    final now = DateTime.now();
    return '${fmt(now)} – ${fmt(now.add(const Duration(minutes: 60)))}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final leftInset = MediaQuery.paddingOf(context).left;
    final rightInset = MediaQuery.paddingOf(context).right;
    final settings = Get.find<AppSettingsService>();

    return Obx(() {
      if (!controller.tvOsdVisible.value) return const SizedBox.shrink();

      final ch = controller.channel.value;
      controller.osdQualityStamp.value;
      Get.find<EpgService>().isLoading.value;
      final quality = controller.osdStreamQualityLabel;
      final epgLine = _epgLine(ch);

      return Positioned(
        left: 12 + leftInset,
        right: 12 + rightInset,
        bottom: 12 + bottomInset,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Obx(() {
            final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
            final reduce = settings.reduceBlur.value;
            final tv = settings.layoutMode.value == AppLayoutMode.tv;
            final sigma = tv ? 0.0 : (reduce ? 10.0 : 20.0);
            final decorated = Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ga.playerBarBorder),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: ga.playerBarGradientColors,
                ),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _LogoBadge(logoUrl: ch.logoUrl, size: 42),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ch.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              if (quality != null && quality.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: Text(
                                    quality,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            epgLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE74C3C)
                                      .withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'CANLI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Akış açılıyor…',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ZapIcon(
                      icon: Icons.fast_rewind_rounded,
                      onPressed: () => controller.zapRelative(-1),
                    ),
                    const SizedBox(width: 4),
                    _ZapIcon(
                      icon: Icons.fast_forward_rounded,
                      onPressed: () => controller.zapRelative(1),
                    ),
                  ],
                ),
            );
            if (sigma <= 0) return decorated;
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: decorated,
            );
          }),
        ),
      );
    });
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge({this.logoUrl, this.size = 48.0});

  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: Colors.white.withValues(alpha: 0.08),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _LogoFallback(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    ),
                  );
                },
              )
            : const _LogoFallback(),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.live_tv_rounded,
      color: Colors.white70,
      size: 30,
    );
  }
}

class _ZapIcon extends StatelessWidget {
  const _ZapIcon({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.select ||
            k == LogicalKeyboardKey.enter ||
            k == LogicalKeyboardKey.space ||
            k == LogicalKeyboardKey.gameButtonSelect) {
          onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
