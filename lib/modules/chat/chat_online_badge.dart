import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/chat_service.dart';

/// Sohbet bölümünde başlığın sağ tarafında gösterilen "N Online" rozeti —
/// yeşil canlı nokta + uygulamada anlık çevrimiçi kullanıcı sayısı. Sayı 0
/// iken (veya servis hazır değilse) tamamen gizlenir; yer kaplamaz.
class ChatOnlineBadge extends StatelessWidget {
  const ChatOnlineBadge({super.key});

  static const Color _green = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ChatService>()) return const SizedBox.shrink();
    final chat = Get.find<ChatService>();
    return Obx(() {
      final n = chat.onlineCount.value;
      if (n <= 0) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _green.withValues(alpha: 0.55),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green,
                boxShadow: [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.7),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'chat.online'.trParams({'n': '$n'}),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    });
  }
}
