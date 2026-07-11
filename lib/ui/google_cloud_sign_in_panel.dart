import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Kurulum sihirbazı ve playlist kurulumu: Google bulut yedekten geri yükleme.
class GoogleCloudSignInCard extends StatelessWidget {
  const GoogleCloudSignInCard({
    super.key,
    required this.isBusy,
    required this.onSignIn,
  });

  final bool isBusy;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            focusColor: cs.primary.withValues(alpha: 0.28),
            highlightColor: cs.primary.withValues(alpha: 0.16),
            onTap: isBusy ? null : onSignIn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'G',
                            style: TextStyle(
                              color: Color(0xFF4285F4),
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              height: 1.0,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'cloud.googleSignInTitle'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'cloud.googleSignInSubtitle'.tr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.cloud_download_rounded,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Google giriş kartı ile manuel kaynak formu arasındaki ayraç.
class CloudSignInOrDivider extends StatelessWidget {
  const CloudSignInOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(
        height: 1,
        color: Colors.white.withValues(alpha: 0.18),
      ),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'common.or'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        line,
      ],
    );
  }
}
