import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../ui/themed_settings_background.dart';

class AdminCrashReportsView extends StatelessWidget {
  const AdminCrashReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Hata ve Çökme Raporları'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Firebase Crashlytics Aç',
            onPressed: () {
               launchUrl(Uri.parse('https://console.firebase.google.com/project/_/crashlytics'));
            },
          )
        ],
      ),
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Material(
                  color: Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      launchUrl(Uri.parse('https://console.firebase.google.com/project/_/crashlytics'));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bug_report, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Firebase Crashlytics', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Canlı ve detaylı çökme raporlarını tarayıcıda açmak için dokunun.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                          const Icon(Icons.open_in_new, color: Colors.white54),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Eski Dahili Kayıtlar', style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('app_crashes')
                      .orderBy('timestamp', descending: true)
                      .limit(100)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henüz kaydedilmiş bir hata raporu bulunmuyor.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isFatal = data['is_fatal'] == true;
                    final errorMessage = data['error_message'] ?? 'Bilinmeyen Hata';
                    final dateStr = data['date_string'] ?? '';
                    final platform = data['platform'] ?? 'Unknown';
                    final ram = data['device_ram'] ?? 'Unknown';

                    return Card(
                      color: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        iconColor: Colors.white,
                        collapsedIconColor: Colors.white70,
                        title: Text(
                          errorMessage,
                          style: TextStyle(
                            color: isFatal ? Colors.redAccent : Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(width: 12),
                              Icon(Icons.memory, size: 14, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text(ram, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(width: 12),
                              Icon(Icons.phone_android, size: 14, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text(platform, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            color: Colors.black26,
                            child: SelectableText(
                              data['stack_trace'] ?? 'Stack trace yok.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
