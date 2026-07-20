import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../ui/themed_settings_background.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/chat_service.dart';

class AdminSupportManagerView extends StatefulWidget {
  const AdminSupportManagerView({super.key});

  @override
  State<AdminSupportManagerView> createState() => _AdminSupportManagerViewState();
}

class _AdminSupportManagerViewState extends State<AdminSupportManagerView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemedSettingsBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Destek Talepleri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Okunmadı'),
            Tab(text: 'Çözüldü'),
            Tab(text: 'Tümü'),
          ],
        ),
      ),
      body: StreamBuilder<List<SupportThread>>(
        stream: Get.find<ChatService>().supportThreadsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Bir hata oluştu.', style: TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amberAccent));
          }

          final allThreads = snapshot.data ?? [];

          final unreadThreads = allThreads.where((t) => t.status == 'unread' || (t.status == null && t.lastSenderId == t.userId)).toList();
          final resolvedThreads = allThreads.where((t) => t.status == 'resolved').toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(unreadThreads),
              _buildList(resolvedThreads),
              _buildList(allThreads),
            ],
          );
        },
      ),
    ),
  );
}

  Widget _buildList(List<SupportThread> threads) {
    if (threads.isEmpty) {
      return const Center(
        child: Text('Burada gösterilecek talep yok.', style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: threads.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final t = threads[index];
        final isUnread = t.status == 'unread' || (t.status == null && t.lastSenderId == t.userId);
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isUnread ? Colors.amberAccent.withValues(alpha: 0.5) : Colors.white12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.white12,
              backgroundImage: t.userPhotoUrl != null ? NetworkImage(t.userPhotoUrl!) : null,
              child: t.userPhotoUrl == null ? const Icon(Icons.person, color: Colors.white54) : null,
            ),
            title: Text(t.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  t.lastMessage ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: isUnread ? Colors.white : Colors.white70),
                ),
                if (t.lastTimestamp != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM HH:mm').format(t.lastTimestamp!),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              color: const Color(0xFF1E293B),
              onSelected: (val) {
                if (val == 'resolve') {
                  Get.find<ChatService>().markThreadStatus(t.userId, 'resolved');
                } else if (val == 'unread') {
                  Get.find<ChatService>().markThreadStatus(t.userId, 'unread');
                }
              },
              itemBuilder: (context) => [
                if (t.status != 'resolved')
                  const PopupMenuItem(value: 'resolve', child: Text('Çözüldü Olarak İşaretle', style: TextStyle(color: Colors.greenAccent))),
                if (t.status != 'unread')
                  const PopupMenuItem(value: 'unread', child: Text('Okunmadı Olarak İşaretle', style: TextStyle(color: Colors.amberAccent))),
              ],
            ),
            onTap: () {
              // Mark as pending or leave unread when clicked?
              // The user might just want to read. Let's navigate:
              Get.toNamed<void>(
                AppRoutes.chatRoom,
                arguments: ChatSupportTarget(
                  threadUid: t.userId,
                  title: t.userName,
                  photoUrl: t.userPhotoUrl,
                  adminView: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
