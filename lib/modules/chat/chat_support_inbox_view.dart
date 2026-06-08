import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/chat_service.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';

/// Admin'in kullanıcılardan gelen birebir "Yöneticiye Mesaj" thread'lerini
/// gördüğü gelen kutusu. Yalnızca admin UID'si bu ekrana ulaşabilir (yönlendirme
/// + Firestore kuralları ile zorlanır). Her satıra dokununca o kullanıcının
/// konuşması açılır ve admin doğrudan yanıt verebilir.
class ChatSupportInboxView extends StatelessWidget {
  const ChatSupportInboxView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final remote = settings.layoutMode.value.usesRemoteNavigationStyle;
    final chat = Get.find<ChatService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ThemedSettingsBackground(
          child: SafeArea(
            child: SettingsGlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        remote
                            ? TvIconButton(
                                icon: Icons.arrow_back_rounded,
                                onPressed: () => Get.back<void>(),
                              )
                            : IconButton(
                                onPressed: () => Get.back<void>(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: Colors.white,
                                tooltip: 'common.back'.tr,
                              ),
                        const SizedBox(width: 4),
                        const Icon(Icons.support_agent_rounded,
                            color: Color(0xFFFFC107), size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'chat.support.inboxTitle'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<SupportThread>>(
                      stream: chat.supportThreadsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        }
                        final threads =
                            snapshot.data ?? const <SupportThread>[];
                        if (threads.isEmpty) {
                          return _EmptyInbox();
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
                          itemCount: threads.length,
                          itemBuilder: (context, index) {
                            final t = threads[index];
                            return _ThreadTile(
                              thread: t,
                              autofocus: index == 0,
                              onTap: () => Get.toNamed<void>(
                                AppRoutes.chatRoom,
                                arguments: ChatSupportTarget(
                                  threadUid: t.userId,
                                  title: t.userName,
                                  photoUrl: t.userPhotoUrl,
                                  adminView: true,
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
          ),
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.onTap,
    this.autofocus = false,
  });

  final SupportThread thread;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ts = thread.lastTimestamp;
    final timeLabel = ts != null ? _formatRelative(ts) : '';
    final preview = thread.lastMessage ?? '';
    return GlassListTile(
      autofocus: autofocus,
      leading: _InboxAvatar(name: thread.userName, photoUrl: thread.userPhotoUrl),
      title: Text(thread.userName),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: timeLabel.isEmpty
          ? null
          : Text(
              timeLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
      onTap: onTap,
    );
  }

  String _formatRelative(DateTime time) {
    final now = DateTime.now();
    final sameDay = now.year == time.year &&
        now.month == time.month &&
        now.day == time.day;
    if (sameDay) return DateFormat.Hm().format(time);
    return DateFormat.MMMd().format(time);
  }
}

class _InboxAvatar extends StatelessWidget {
  const _InboxAvatar({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;
  static const double size = 40;

  static const List<Color> _palette = [
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFF5C6BC0),
    Color(0xFF29B6F6),
    Color(0xFF26A69A),
    Color(0xFF66BB6A),
    Color(0xFFFFA726),
    Color(0xFF8D6E63),
  ];

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  Color get _bg =>
      name.isEmpty ? _palette.first : _palette[name.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bg.withValues(alpha: 0.95), _bg.withValues(alpha: 0.6)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        _initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (photoUrl == null) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded,
              color: Colors.white.withValues(alpha: 0.4), size: 44),
          const SizedBox(height: 12),
          Text(
            'chat.support.inboxEmpty'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
