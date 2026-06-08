import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/layout/app_layout_mode.dart';
import '../core/services/app_settings_service.dart';
import 'glass_overlays.dart';

/// Diyalog sonucu: [rated] = Play Store CTA; [later] / kapatma = bugün tekrar gösterme.
enum PlayStoreRateDialogResult { later, rated }

/// CTA + Daha Sonra düğmelerini ekran genişliğine göre dinamik dizer:
/// - Yeterli yer varsa yan yana sağa hizalı (eski davranış).
/// - Düğme etiketleri (bazı dillerde uzun) toplam genişliği aşıyorsa alt
///   alta, tam genişlikte sıralanır. Böylece dar/küçük ekranlarda taşmaz.
class _RateDialogActions extends StatelessWidget {
  const _RateDialogActions({
    required this.laterLabel,
    required this.ctaLabel,
    required this.autofocusCta,
    required this.onLater,
    required this.onRate,
  });

  final String laterLabel;
  final String ctaLabel;
  final bool autofocusCta;
  final VoidCallback onLater;
  final VoidCallback onRate;

  /// Düğme için kaba genişlik tahmini — `GlassDialogActionButton` iç
  /// padding'i ~32px ve karakter başı ~9px varsayar. LayoutBuilder ile gelen
  /// gerçek max genişliğe karşı kullanılır.
  double _estimateButtonWidth(String label) {
    const horizontalPadding = 36.0;
    const perChar = 9.5;
    return horizontalPadding + label.length * perChar;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final maxW = constraints.maxWidth;
        final estLater = _estimateButtonWidth(laterLabel);
        final estCta = _estimateButtonWidth(ctaLabel);
        final fitsRow = (estLater + estCta + gap) <= maxW;

        final laterBtn = FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: GlassDialogActionButton(
            label: laterLabel,
            onDarkSurface: true,
            onPressed: onLater,
          ),
        );
        final ctaBtn = FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: GlassDialogActionButton(
            label: ctaLabel,
            primary: true,
            autofocus: autofocusCta,
            onPressed: onRate,
          ),
        );

        if (fitsRow) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              laterBtn,
              const SizedBox(width: gap),
              ctaBtn,
            ],
          );
        }

        // Dar ekran — düğmeler tek satıra sığmıyor; alt alta, sağa hizalı.
        // CTA üstte (birincil aksiyon), «Daha Sonra» altında. Düğmeler
        // intrinsic genişliklerini korur, böylece taşma olmaz.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            ctaBtn,
            const SizedBox(height: gap),
            laterBtn,
          ],
        );
      },
    );
  }
}

/// Google Play’den yüklenen sürümde, güncelleme sonrası değerlendirme isteği için cam diyalog.
class PlayStoreRateGlassDialog extends StatelessWidget {
  const PlayStoreRateGlassDialog({
    super.key,
    required this.packageName,
  });

  final String packageName;

  static Future<PlayStoreRateDialogResult?> show(
    BuildContext context, {
    required String packageName,
  }) {
    return showDialog<PlayStoreRateDialogResult>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (ctx) => PlayStoreRateGlassDialog(packageName: packageName),
    );
  }

  Future<void> _openListing() async {
    final market = Uri.parse('market://details?id=$packageName');
    final https = Uri.parse(
      'https://play.google.com/store/apps/details?id=$packageName',
    );
    if (await launchUrl(market, mode: LaunchMode.externalApplication)) {
      return;
    }
    await launchUrl(https, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final primary = Theme.of(context).colorScheme.primary;
    final tv = settings.layoutMode.value == AppLayoutMode.tv;
    final reduce = settings.reduceBlur.value;
    final sigma = reduce ? 10.0 : 20.0;
    final mq = MediaQuery.of(context);
    final portrait = mq.orientation == Orientation.portrait;
    final insetH = portrait ? 22.0 : 12.0;
    final insetW = portrait ? 20.0 : 16.0;
    final maxW = math.min(400.0, mq.size.width - insetW * 2);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          EdgeInsets.symmetric(horizontal: insetW, vertical: insetH),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: Stack(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: Colors.black.withValues(alpha: 0.86),
                    ),
                    child: const SizedBox(width: double.infinity),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.2,
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.14),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.22),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        portrait ? 22 : 18,
                        portrait ? 20 : 16,
                        portrait ? 22 : 18,
                        portrait ? 16 : 14,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      primary.withValues(alpha: 0.45),
                                      primary.withValues(alpha: 0.2),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber.shade200,
                                  size: portrait ? 36 : 30,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'rateApp.title'.tr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: portrait ? 19 : 17,
                                        fontWeight: FontWeight.w800,
                                        height: 1.2,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (i) => Padding(
                                          padding: EdgeInsets.only(
                                              right: i < 4 ? 4 : 0),
                                          child: Icon(
                                            Icons.star_rounded,
                                            color: Colors.amber.shade400,
                                            size: portrait ? 22 : 20,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black
                                                    .withValues(
                                                        alpha: 0.45),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'rateApp.body'.tr,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: portrait ? 14 : 13,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _RateDialogActions(
                            laterLabel: 'rateApp.later'.tr,
                            ctaLabel: 'rateApp.cta'.tr,
                            autofocusCta: tv,
                            onLater: () => Navigator.of(context).pop(
                              PlayStoreRateDialogResult.later,
                            ),
                            onRate: () async {
                              await _openListing();
                              if (context.mounted) {
                                Navigator.of(context).pop(
                                  PlayStoreRateDialogResult.rated,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
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
