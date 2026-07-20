import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/chat_service.dart';
import '../chat/chat_room_view.dart';

class AdminOnlineUsersView extends StatefulWidget {
  const AdminOnlineUsersView({super.key});

  @override
  State<AdminOnlineUsersView> createState() => _AdminOnlineUsersViewState();
}

class _AdminOnlineUsersViewState extends State<AdminOnlineUsersView> {
  final _chatService = Get.find<ChatService>();

  Stream<QuerySnapshot<Map<String, dynamic>>> _getOnlineUsersStream() {
    final threeMinutesAgo = DateTime.now().subtract(const Duration(minutes: 3));
    return FirebaseFirestore.instance
        .collection('presence')
        .where('lastSeen', isGreaterThan: Timestamp.fromDate(threeMinutesAgo))
        .orderBy('lastSeen', descending: true)
        .snapshots();
  }

  void _showSendMessageDialog(String userUid, String userName) {
    final textController = TextEditingController();
    bool isSending = false;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.message_rounded,
                        size: 48, color: Colors.blueAccent),
                    const SizedBox(height: 16),
                    Text(
                      '$userName\'a Mesaj',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Mesajınızı yazın...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('İptal',
                              style: TextStyle(color: Colors.white70)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isSending
                              ? null
                              : () async {
                                  final text = textController.text.trim();
                                  if (text.isEmpty) return;

                                  setState(() => isSending = true);
                                  try {
                                    await _chatService.sendAdminMessageToUser(
                                        userUid, text);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      Get.snackbar(
                                          'Başarılı', 'Mesaj gönderildi.',
                                          backgroundColor: Colors.green
                                              .withValues(alpha: 0.8),
                                          colorText: Colors.white);
                                    }
                                  } catch (e) {
                                    setState(() => isSending = false);
                                    Get.snackbar('Hata', 'Gönderilemedi: $e',
                                        backgroundColor:
                                            Colors.red.withValues(alpha: 0.8),
                                        colorText: Colors.white);
                                  }
                                },
                          child: isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Gönder',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.8, -0.8),
                  radius: 1.5,
                  colors: [
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Get.back(),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Çevrimiçi Kullanıcılar',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),

                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _getOnlineUsersStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Bir hata oluştu:\n${snapshot.error}',
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'Şu anda çevrimiçi kullanıcı yok.',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 18),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final uid = docs[index].id;
                          final name = data['name'] as String? ?? 'Misafir';
                          final email = data['email'] as String?;
                          final photoUrl = data['photoUrl'] as String?;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white10,
                                backgroundImage: photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl == null
                                    ? const Icon(Icons.person,
                                        color: Colors.white70)
                                    : null,
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16),
                              ),
                              subtitle: email != null
                                  ? Text(email,
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.6),
                                          fontSize: 13))
                                  : null,
                              trailing: Container(
                                decoration: BoxDecoration(
                                  color:
                                      Colors.blueAccent.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.chat_bubble_rounded,
                                      color: Colors.blueAccent),
                                  tooltip: 'Mesaja Git',
                                  onPressed: () {
                                    Get.to(
                                      () => const ChatRoomView(),
                                      arguments: ChatSupportTarget(
                                        threadUid: uid,
                                        title: name,
                                        photoUrl: photoUrl,
                                        adminView: true,
                                      ),
                                    );
                                  },
                                ),
                              ),
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
        ],
      ),
    );
  }
}
