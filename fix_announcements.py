import re

with open('lib/modules/settings/admin_announcements_view.dart', 'r') as f:
    content = f.read()

# Replace the dialog buttons
target = """                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Get.back(), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {"""

replacement = """                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Get.back(), child: const Text('İptal', style: TextStyle(color: Colors.white70))),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final title = titleCtrl.text.trim();
                              final msg = messageCtrl.text.trim();
                              final url = urlCtrl.text.trim();
                              
                              if (title.isEmpty || msg.isEmpty) {
                                Get.snackbar('Hata', 'Başlık ve mesaj zorunludur.', backgroundColor: Colors.redAccent.withValues(alpha: 0.8), colorText: Colors.white);
                                return;
                              }

                              await FirebaseFirestore.instance.collection('admin_announcements').add({
                                'title': title,
                                'message': msg,
                                'url': url,
                                'scheduledFor': Timestamp.now(),
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              Get.back();
                              Get.snackbar('Başarılı', 'Hemen gönderildi.', backgroundColor: Colors.green.withValues(alpha: 0.8), colorText: Colors.white);
                            },
                            child: const Text('Hemen Gönder', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black87,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {"""

content = content.replace(target, replacement)

# Add "Hemen Gönder" hint
target2 = """                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),"""
replacement2 = """                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),"""
content = content.replace(target2, replacement2)

with open('lib/modules/settings/admin_announcements_view.dart', 'w') as f:
    f.write(content)
