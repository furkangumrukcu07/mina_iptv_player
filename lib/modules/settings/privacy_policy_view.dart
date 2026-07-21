import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_settings_subpage.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: SettingsGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tvSettingsSubpageHeader(
                  context,
                  'privacy.title'.tr,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildText('${'privacy.lastUpdated'.tr}\n\n${'privacy.intro'.tr}'),
                            
                            _buildSectionTitle('privacy.section1.title'.tr, primary),
                            _buildText('privacy.section1.body'.tr),

                            _buildSectionTitle('privacy.section2.title'.tr, primary),
                            _buildText('privacy.section2.body'.tr),

                            _buildSectionTitle('privacy.section3.title'.tr, primary),
                            _buildText('privacy.section3.body'.tr),

                            _buildSectionTitle('privacy.section4.title'.tr, primary),
                            _buildText('privacy.section4.body'.tr),

                            _buildSectionTitle('privacy.section5.title'.tr, primary),
                            _buildText('privacy.section5.body'.tr),

                            _buildSectionTitle('privacy.section6.title'.tr, primary),
                            _buildText('privacy.section6.body'.tr),
                                
                            const SizedBox(height: 32),
                            Center(
                              child: ElevatedButton(
                                onPressed: () => Get.back(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary.withValues(alpha: 0.15),
                                  foregroundColor: primary,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: primary.withValues(alpha: 0.3)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                                ),
                                child: Text('common.close'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color primary) {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0, bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          color: primary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildText(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        height: 1.6,
      ),
    );
  }
}
