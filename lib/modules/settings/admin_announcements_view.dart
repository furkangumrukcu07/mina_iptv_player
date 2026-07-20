import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../ui/themed_settings_background.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminAnnouncementsView extends StatelessWidget {
  const AdminAnnouncementsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemedSettingsBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Duyuru Yönetimi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.amberAccent),
            tooltip: 'Yeni Duyuru Ekle',
            onPressed: () => _showAnnouncementDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _SmartAnnouncementSettingsWidget(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('admin_announcements')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('Henüz hiç duyuru oluşturulmadı.', style: TextStyle(color: Colors.white54, fontSize: 16)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final title = data['title'] as String? ?? 'Başlıksız';
              final message = data['message'] as String? ?? '';
              final url = data['url'] as String?;
              final scheduledFor = data['scheduledFor'] as Timestamp?;
              
              final isPast = scheduledFor != null && scheduledFor.toDate().isBefore(DateTime.now());

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPast ? Colors.green.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPast ? 'Gönderildi' : 'Zamanlandı',
                            style: TextStyle(
                              color: isPast ? Colors.greenAccent : Colors.amberAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    if (url != null && url.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.link, size: 16, color: Colors.blueAccent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(url, style: const TextStyle(color: Colors.blueAccent, fontSize: 13, decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Divider(color: Colors.white.withValues(alpha: 0.1)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          scheduledFor != null ? 'Hedef: ${DateFormat('dd MMM yyyy, HH:mm').format(scheduledFor.toDate())}' : 'Bilinmiyor',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                              tooltip: 'Duyuruyu Düzenle',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showAnnouncementDialog(context, existingDoc: doc),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: 'Duyuruyu Sil',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _confirmDelete(context, doc.id),
                            ),
                          ],
                        ),
                          ],
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
);
}

void _confirmDelete(BuildContext context, String docId) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Sil', style: TextStyle(color: Colors.white)),
        content: const Text('Bu duyuruyu silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('admin_announcements').doc(docId).delete();
              Get.back();
              Get.snackbar('Silindi', 'Duyuru başarıyla silindi.', backgroundColor: Colors.green.withValues(alpha: 0.8), colorText: Colors.white);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showAnnouncementDialog(BuildContext context, {DocumentSnapshot? existingDoc}) {
    final bool isEdit = existingDoc != null;
    final data = isEdit ? existingDoc.data() as Map<String, dynamic> : null;
    
    final titleCtrl = TextEditingController(text: data?['title'] as String? ?? '');
    final messageCtrl = TextEditingController(text: data?['message'] as String? ?? '');
    final urlCtrl = TextEditingController(text: data?['url'] as String? ?? '');
    
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    
    if (isEdit && data?['scheduledFor'] != null) {
      final dt = (data!['scheduledFor'] as Timestamp).toDate();
      selectedDate = dt;
      selectedTime = TimeOfDay.fromDateTime(dt);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isEdit ? 'Duyuruyu Düzenle' : 'Yeni Duyuru Oluştur', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Başlık (Örn: Yeni Güncelleme!)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: messageCtrl,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: _inputDecoration('Mesajınız...'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('URL Link (İsteğe Bağlı)'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(selectedDate != null ? DateFormat('dd MMM yyyy').format(selectedDate!) : 'Tarih Seç'),
                              style: _btnStyle(),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) setState(() => selectedDate = d);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.access_time, size: 16),
                              label: Text(selectedTime != null ? selectedTime!.format(context) : 'Saat Seç'),
                              style: _btnStyle(),
                              onPressed: () async {
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (t != null) setState(() => selectedTime = t);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
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

                              if (isEdit) {
                                await FirebaseFirestore.instance.collection('admin_announcements').doc(existingDoc.id).update({
                                  'title': title,
                                  'message': msg,
                                  'url': url,
                                  'scheduledFor': Timestamp.now(),
                                });
                                Get.back();
                                Get.snackbar('Başarılı', 'Duyuru güncellendi ve yeniden gönderildi.', backgroundColor: Colors.green.withValues(alpha: 0.8), colorText: Colors.white);
                              } else {
                                await FirebaseFirestore.instance.collection('admin_announcements').add({
                                  'title': title,
                                  'message': msg,
                                  'url': url,
                                  'scheduledFor': Timestamp.now(),
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                                Get.back();
                                Get.snackbar('Başarılı', 'Hemen gönderildi.', backgroundColor: Colors.green.withValues(alpha: 0.8), colorText: Colors.white);
                              }
                            },
                            child: Text(isEdit ? 'Yeniden Gönder' : 'Hemen Gönder', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black87,
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

                              DateTime scheduleTarget = DateTime.now();
                              if (selectedDate != null && selectedTime != null) {
                                scheduleTarget = DateTime(
                                  selectedDate!.year, selectedDate!.month, selectedDate!.day,
                                  selectedTime!.hour, selectedTime!.minute,
                                );
                              }

                              if (isEdit) {
                                await FirebaseFirestore.instance.collection('admin_announcements').doc(existingDoc.id).update({
                                  'title': title,
                                  'message': msg,
                                  'url': url,
                                  'scheduledFor': Timestamp.fromDate(scheduleTarget),
                                });
                                Get.back();
                                Get.snackbar('Başarılı', 'Duyuru güncellendi.', backgroundColor: Colors.green.withValues(alpha: 0.8), colorText: Colors.white);
                              } else {
                                await FirebaseFirestore.instance.collection('admin_announcements').add({
                                  'title': title,
                                  'message': msg,
                                  'url': url,
                                  'scheduledFor': Timestamp.fromDate(scheduleTarget),
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                                Get.back();
                                Get.snackbar('Başarılı', 'Duyuru oluşturuldu.', backgroundColor: Colors.green.withValues(alpha: 0.8), colorText: Colors.white);
                              }
                            },
                            child: Text(isEdit ? 'Güncelle' : 'Gönder', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  ButtonStyle _btnStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.white12,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _SmartAnnouncementSettingsWidget extends StatefulWidget {
  @override
  State<_SmartAnnouncementSettingsWidget> createState() => _SmartAnnouncementSettingsWidgetState();
}

class _SmartAnnouncementSettingsWidgetState extends State<_SmartAnnouncementSettingsWidget> {
  bool _isLoading = true;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('admin_settings').doc('smart_announcements').get();
      if (doc.exists) {
        _enabled = doc.data()?['trial_reminder_enabled'] as bool? ?? false;
      }
    } catch (e) {
      debugPrint('[SmartAnnouncementSettings] error loading: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggle(bool val) async {
    setState(() => _enabled = val);
    try {
      await FirebaseFirestore.instance.collection('admin_settings').doc('smart_announcements').set({'trial_reminder_enabled': val}, SetOptions(merge: true));
    } catch (e) {
      Get.snackbar('Hata', 'Ayarlar kaydedilemedi: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
      setState(() => _enabled = !val); // revert
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: Colors.amberAccent)));
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: const Text('Akıllı Deneme (Trial) Duyurusu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text('Son 1 günü kalan deneme sürümü kullanıcılarına indirim/satın alma teklifi sunar.', style: TextStyle(color: Colors.white70, fontSize: 12)),
        value: _enabled,
        activeColor: Colors.amberAccent,
        onChanged: _toggle,
      ),
    );
  }
}
