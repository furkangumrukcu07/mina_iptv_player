import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/auth_service.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_dpad_focus.dart';
import '../settings/admin_panel_view.dart';
import 'chat_controller.dart';
import 'chat_online_badge.dart';
import 'chat_support_thread_delete.dart';

/// Sohbet bölümünün giriş ekranı. Önce oturum/senkron durumu kontrol edilir;
/// uygun değilse giriş kapısı, uygunsa dil odalarının listesi gösterilir.
/// Hiçbir Firestore okuması yapılmaz (yalnızca odaya girince akış başlar).
class ChatRoomsView extends GetView<ChatController> {
  const ChatRoomsView({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final remote = settings.layoutMode.value.usesRemoteNavigationStyle;
    final auth = Get.find<AuthService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ThemedSettingsBackground(
          child: SafeArea(
            child: SettingsGlassPanel(
              blurBackground: false,
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
                        const Icon(Icons.forum_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'chat.title'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const ChatOnlineBadge(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Obx(() {
                      final user = auth.currentUser.value;
                      final signedIn = user != null &&
                          !user.isAnonymous &&
                          auth.isAvailable;
                      if (!signedIn) {
                        return _ChatSignInGate(controller: controller);
                      }
                      return _RoomList(controller: controller);
                    }),
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

/// Giriş yapılmamış kullanıcılar için şık uyarı + Google ile giriş butonu.
class _ChatSignInGate extends StatelessWidget {
  const _ChatSignInGate({required this.controller});

  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: Colors.white70, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'chat.signIn.title'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'chat.signIn.body'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Obx(() {
              final busy = controller.isSigningIn.value;
              return SizedBox(
                width: double.infinity,
                child: GlassDialogActionButton(
                  label: busy
                      ? 'chat.signIn.busy'.tr
                      : 'chat.signIn.action'.tr,
                  primary: true,
                  onPressed: busy ? null : controller.signIn,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Dil odalarının listesi. Her satır ilgili dilin odasına yönlendirir;
/// isim altında o odanın son mesajı, sağında dil bayrağı gösterilir.
class _RoomList extends StatefulWidget {
  const _RoomList({required this.controller});

  final ChatController controller;

  @override
  State<_RoomList> createState() => _RoomListState();
}

class _RoomListState extends State<_RoomList> {
  @override
  void initState() {
    super.initState();
    // Oda önizlemeleri (son mesajlar) tek seferlik çekilir — yalnızca chat
    // bölümüne girilince, ana ekranda değil.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadRoomPreviews();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final rooms = controller.orderedRooms;
    final myLang = Get.find<AppSettingsService>().languageCode.value;
    // İlk satır her zaman "Yöneticiye Mesaj Gönder" (admin için gelen kutusu).
    final isAdmin = controller.isAdmin;
    final extraCount = isAdmin ? 2 : 1;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
      itemCount: rooms.length + extraCount,
      itemBuilder: (context, rawIndex) {
        if (isAdmin && rawIndex == 0) {
          return GlassListTile(
            autofocus: true,
            leading: const Icon(Icons.admin_panel_settings, color: Colors.deepPurpleAccent, size: 28),
            title: const Text('Admin Paneli', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: const Text(
              'Yönetici araçları ve istatistikler',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            onTap: () => Get.to(() => const AdminPanelView()),
          );
        }

        final supportIndex = isAdmin ? 1 : 0;
        if (rawIndex == supportIndex) {
          return GlassListTile(
            autofocus: !isAdmin, // If not admin, autofocus this
            leading: const _SupportLeading(),
            title: Text(
              isAdmin
                  ? 'chat.support.inboxTitle'.tr
                  : 'chat.support.contactAdmin'.tr,
            ),
            subtitle: Text(
              isAdmin
                  ? 'chat.support.inboxSubtitle'.tr
                  : 'chat.support.contactAdminSub'.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Colors.white54),
            onTap: controller.openSupport,
            // Admin için gelen kutusudur (tek bir thread değil),
            // bu yüzden silme yalnızca normal kullanıcının kendi konuşmasına uygulanır.
            onLongPress: isAdmin
                ? null
                : () {
                    final uid = controller.chat.currentUserId;
                    if (uid == null) return;
                    showSupportThreadDeleteMenu(context, userUid: uid);
                  },
          );
        }
        final index = rawIndex - extraCount;
        final room = rooms[index];
        final mine = room.langCode == myLang;
        return Obx(() {
          final last = controller.lastMessages[room.langCode];
          final String subtitle;
          if (last != null) {
            final name = last.senderName.isNotEmpty ? last.senderName : '?';
            subtitle = '$name: ${last.messageText}';
          } else if (mine) {
            subtitle = 'chat.room.yourLanguage'.tr;
          } else {
            subtitle = 'chat.room.subtitle'
                .trParams({'lang': room.langCode.toUpperCase()});
          }
          return GlassListTile(
            selected: mine,
            title: Text(room.nativeName),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              room.flag,
              style: const TextStyle(fontSize: 26),
            ),
            onTap: () => controller.openRoom(room),
          );
        });
      },
    );
  }
}

/// "Yöneticiye Mesaj Gönder" satırının baştaki amber destek ikonu.
class _SupportLeading extends StatelessWidget {
  const _SupportLeading();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFC107).withValues(alpha: 0.16),
        border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.5)),
      ),
      child: const Icon(Icons.support_agent_rounded,
          color: Color(0xFFFFD54F), size: 22),
    );
  }
}
