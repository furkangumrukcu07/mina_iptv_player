import 'package:get/get.dart';

import '../../core/services/chat_service.dart';
import 'chat_controller.dart';

/// Chat bölümüne girilince oluşturulur. [ChatService] ve [ChatController]
/// yalnızca burada (tembel) kaydedilir → ana ekran açılışında hiçbir Firebase
/// chat trafiği / nesnesi oluşturulmaz.
class ChatBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ChatService>()) {
      Get.lazyPut<ChatService>(() => ChatService(), fenix: true);
    }
    Get.lazyPut<ChatController>(() => ChatController());
  }
}
