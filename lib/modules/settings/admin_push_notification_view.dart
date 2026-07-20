import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminPushNotificationView extends StatefulWidget {
  const AdminPushNotificationView({super.key});

  @override
  State<AdminPushNotificationView> createState() => _AdminPushNotificationViewState();
}

class _AdminPushNotificationViewState extends State<AdminPushNotificationView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendPush() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      Get.snackbar('Hata', 'Lütfen başlık ve içerik girin.',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    setState(() => _isSending = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('sendBroadcastNotification');
      await callable.call({'title': title, 'body': body});

      Get.snackbar('Başarılı', 'Push bildirim başarıyla gönderildi!',
          backgroundColor: Colors.green, colorText: Colors.white);
      _titleController.clear();
      _bodyController.clear();
    } catch (e) {
      Get.snackbar('Hata', 'Gönderilemedi: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Push Bildirim (FCM)', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.notifications_active_rounded, size: 64, color: Colors.amberAccent),
                const SizedBox(height: 16),
                const Text(
                  'Herkese Anlık Bildirim Gönder',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Uygulama kapalı olsa bile kullanıcıların telefonlarına/televizyonlarına düşer.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Bildirim Başlığı',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bodyController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Bildirim İçeriği',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSending ? null : _sendPush,
                    child: _isSending
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2))
                        : const Text('Gönder', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
