import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'privacy.title'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('privacy.title'.tr),
                _buildText('${'privacy.lastUpdated'.tr}\n\n${'privacy.intro'.tr}'),
                
                _buildSectionTitle('privacy.section1.title'.tr),
                _buildText('privacy.section1.body'.tr),

                _buildSectionTitle('privacy.section2.title'.tr),
                _buildText('privacy.section2.body'.tr),

                _buildSectionTitle('privacy.section3.title'.tr),
                _buildText('privacy.section3.body'.tr),

                _buildSectionTitle('privacy.section4.title'.tr),
                _buildText('privacy.section4.body'.tr),

                _buildSectionTitle('privacy.section5.title'.tr),
                _buildText('privacy.section5.body'.tr),

                _buildSectionTitle('privacy.section6.title'.tr),
                _buildText('privacy.section6.body'.tr),
                    
                const SizedBox(height: 32),
                Center(
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    ),
                    child: Text('common.close'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
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
        height: 1.5,
      ),
    );
  }
}
