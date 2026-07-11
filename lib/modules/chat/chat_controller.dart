import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/chat_service.dart';
import '../../ui/glass_overlays.dart';

/// Sohbet oda seçim ekranının controller'ı. Mesaj akışı burada açılmaz;
/// yalnızca giriş durumu + oda listesi yönetilir (trafik yok).
class ChatController extends GetxController {
  ChatService get chat => Get.find<ChatService>();
  AuthService get _auth => Get.find<AuthService>();

  /// Google ile oturum açma sürerken butonları kilitlemek için.
  final isSigningIn = false.obs;

  /// Presence uygulama genelinde [ChatService] tarafından yönetilir.
  /// Sohbete girince yalnızca sayımı tazeleriz.
  @override
  void onInit() {
    super.onInit();
    chat.acquirePresence();
  }

  @override
  void onClose() {
    chat.releasePresence();
    super.onClose();
  }

  /// Bulut yapılandırılmış mı (Firebase hazır)?
  bool get isCloudAvailable => _auth.isAvailable;

  /// Uygulamanın desteklediği yerelleştirme dillerine karşılık gelen odalar.
  /// (main.dart `supportedLocales` ile aynı sıralama.)
  static const List<ChatRoom> rooms = <ChatRoom>[
    ChatRoom(langCode: 'tr', nativeName: 'Türkçe', flag: '🇹🇷'),
    ChatRoom(langCode: 'en', nativeName: 'English', flag: '🇬🇧'),
    ChatRoom(langCode: 'fr', nativeName: 'Français', flag: '🇫🇷'),
    ChatRoom(langCode: 'ar', nativeName: 'العربية', flag: '🇸🇦'),
    ChatRoom(langCode: 'zh', nativeName: '中文', flag: '🇨🇳'),
    ChatRoom(langCode: 'ru', nativeName: 'Русский', flag: '🇷🇺'),
    ChatRoom(langCode: 'ja', nativeName: '日本語', flag: '🇯🇵'),
    ChatRoom(langCode: 'es', nativeName: 'Español', flag: '🇪🇸'),
    ChatRoom(langCode: 'ko', nativeName: '한국어', flag: '🇰🇷'),
    ChatRoom(langCode: 'he', nativeName: 'עברית', flag: '🇮🇱'),
    ChatRoom(langCode: 'da', nativeName: 'Dansk', flag: '🇩🇰'),
    ChatRoom(langCode: 'sv', nativeName: 'Svenska', flag: '🇸🇪'),
    ChatRoom(langCode: 'hi', nativeName: 'हिन्दी', flag: '🇮🇳'),
    ChatRoom(langCode: 'th', nativeName: 'ไทย', flag: '🇹🇭'),
    ChatRoom(langCode: 'it', nativeName: 'Italiano', flag: '🇮🇹'),
    ChatRoom(langCode: 'pt', nativeName: 'Português', flag: '🇵🇹'),
    ChatRoom(langCode: 'id', nativeName: 'Bahasa Indonesia', flag: '🇮🇩'),
  ];

  /// Oda → son mesaj önizlemesi (oda seçim ekranında "isim altında son mesaj").
  /// Boş = henüz yüklenmedi / mesaj yok. Yalnızca giriş yapılınca doldurulur.
  final RxMap<String, ChatMessage> lastMessages = <String, ChatMessage>{}.obs;
  final isLoadingPreviews = false.obs;
  bool _previewsRequested = false;

  /// Tüm odaların son mesajını bir kez çeker (tek seferlik get; canlı değil).
  /// Yalnızca oturum açık + bulut hazır iken ve bir kez çalışır.
  Future<void> loadRoomPreviews({bool force = false}) async {
    if (!chat.isReady) return;
    if (_previewsRequested && !force) return;
    _previewsRequested = true;
    isLoadingPreviews.value = true;
    try {
      await Future.wait(rooms.map((room) async {
        final msg = await chat.fetchLastMessage(room.langCode);
        if (msg != null) lastMessages[room.langCode] = msg;
      }));
    } finally {
      isLoadingPreviews.value = false;
    }
  }

  /// Oda listesi, kullanıcının aktif uygulama dili **en üstte** olacak şekilde
  /// sıralanır (kalan diller orijinal sırada). Böylece kullanıcı kendi dil
  /// odasını ekranın en üstünde görür.
  List<ChatRoom> get orderedRooms {
    final lang = Get.find<AppSettingsService>().languageCode.value;
    final idx = rooms.indexWhere((r) => r.langCode == lang);
    if (idx <= 0) return rooms;
    final ordered = List<ChatRoom>.from(rooms);
    final mine = ordered.removeAt(idx);
    ordered.insert(0, mine);
    return ordered;
  }

  /// Bir odaya gir — mesaj ekranına yönlendirir. Akış orada başlar.
  void openRoom(ChatRoom room) {
    if (!chat.isReady) return;
    Get.toNamed<void>(AppRoutes.chatRoom, arguments: room);
  }

  /// Oturum açmış kullanıcı admin mi? (Yöneticiye mesaj satırının davranışını
  /// ve etiketini belirler.)
  bool get isAdmin => chat.isCurrentUserAdmin;

  /// "Yöneticiye Mesaj Gönder" satırına dokununca:
  /// * Admin ise → gelen kutusu (tüm kullanıcı thread'leri).
  /// * Normal kullanıcı ise → kendi birebir admin konuşması.
  void openSupport() {
    if (!chat.isReady) return;
    if (chat.isCurrentUserAdmin) {
      Get.toNamed<void>(AppRoutes.chatSupportInbox);
      return;
    }
    final uid = chat.currentUserId;
    if (uid == null) return;
    Get.toNamed<void>(
      AppRoutes.chatRoom,
      arguments: ChatSupportTarget(
        threadUid: uid,
        title: 'chat.support.adminName'.tr,
      ),
    );
  }

  /// Giriş kapısındaki butondan Google ile oturum aç. Başarılıysa UI reaktif
  /// olarak sohbet odalarına geçer (currentUser değişimi).
  Future<void> signIn() async {
    if (isSigningIn.value) return;
    if (!_auth.isAvailable) {
      GlassSnackbar.show('chat.title'.tr, 'cloud.notConfigured'.tr);
      return;
    }
    isSigningIn.value = true;
    try {
      final result = await _auth.signInWithGoogle();
      switch (result.outcome) {
        case GoogleSignInOutcome.success:
          break;
        case GoogleSignInOutcome.cancelled:
          break;
        case GoogleSignInOutcome.notConfigured:
          GlassSnackbar.show('chat.title'.tr, 'cloud.notConfigured'.tr);
        case GoogleSignInOutcome.failed:
          GlassSnackbar.show('chat.title'.tr, result.messageKey.tr);
      }
    } finally {
      isSigningIn.value = false;
    }
  }
}
