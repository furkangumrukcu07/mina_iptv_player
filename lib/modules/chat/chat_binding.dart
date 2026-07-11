import 'package:get/get.dart';

import '../../core/services/chat_service.dart';
import 'chat_controller.dart';

/// Chat bölümüne girilince [ChatController] oluşturulur.
/// [ChatService] uygulama açılışında (InitialBinding) kalıcı kayıtlıdır.
class ChatBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ChatService>()) {
      Get.put<ChatService>(ChatService(), permanent: true);
    }
    Get.lazyPut<ChatController>(() => ChatController());
  }
}
