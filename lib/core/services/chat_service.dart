import 'dart:async';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:translator/translator.dart';

import 'auth_service.dart';
import 'firebase_bootstrap.dart';
import '../routes/app_routes.dart';
import 'licensing_service.dart';
import '../util/firestore_timeout.dart';

/// Tek bir sohbet odası (uygulamanın desteklediği bir yerelleştirme dili).
@immutable
class ChatRoom {
  const ChatRoom({
    required this.langCode,
    required this.nativeName,
    this.flag = '🌐',
  });

  /// Firestore koleksiyon segmenti + uygulamanın dil kodu (ör. `tr`, `en`).
  final String langCode;

  /// Odanın yerel adıyla gösterimi (ör. `Türkçe`, `English`).
  final String nativeName;

  /// Dile karşılık gelen ülke bayrağı emojisi (ör. 🇹🇷, 🇬🇧).
  final String flag;
}

/// Bir sohbet mesajının değişmez modeli. Firestore alanları:
/// `senderId`, `senderName`, `messageText`, `timestamp`, `senderPhotoUrl`,
/// `senderRole`, `replyToName`, `replyToText`, `statusTag`.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.messageText,
    required this.timestamp,
    this.senderPhotoUrl,
    this.senderRole,
    this.replyToName,
    this.replyToText,
    this.statusTag,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String messageText;

  /// Gönderenin Google profil fotoğrafı URL'i (yoksa baş harf avatarı).
  final String? senderPhotoUrl;

  /// Gönderenin rolü: `'admin'` veya `null` (normal kullanıcı).
  final String? senderRole;

  /// Yanıtlanan mesajın göndereni ve metni (reply alıntısı). Yoksa `null`.
  final String? replyToName;
  final String? replyToText;

  /// Yayın durumu etiketi anahtarı (ör. `flowing`, `freeze`, `down`). Yoksa
  /// `null`. Etiketler [ChatStatusTag] ile eşlenir.
  final String? statusTag;

  bool get isAdmin => senderRole == 'admin';

  /// Sunucu zaman damgası (henüz yazılmamışsa `null` olabilir — optimistik UI).
  final DateTime? timestamp;

  static String? _str(dynamic v) =>
      (v is String && v.trim().isNotEmpty) ? v.trim() : null;

  factory ChatMessage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['timestamp'];
    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      senderName: (data['senderName'] as String?) ?? '',
      messageText: (data['messageText'] as String?) ?? '',
      senderPhotoUrl: _str(data['senderPhotoUrl']),
      senderRole: _str(data['senderRole']),
      replyToName: _str(data['replyToName']),
      replyToText: _str(data['replyToText']),
      statusTag: _str(data['statusTag']),
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

/// [ChatRoomView] destek (admin DM) modunda açıldığında geçilen argüman.
/// Hedef thread'in sahibi kullanıcının UID'si + başlıkta gösterilecek ad.
@immutable
class ChatSupportTarget {
  const ChatSupportTarget({
    required this.threadUid,
    required this.title,
    this.photoUrl,
    this.adminView = false,
  });

  /// Konuşma sahibi kullanıcının UID'si.
  final String threadUid;

  /// Başlıkta gösterilecek ad (kullanıcı için "Yönetici", admin için kullanıcı
  /// adı).
  final String title;

  final String? photoUrl;

  /// Admin bir kullanıcının thread'ini mi görüntülüyor?
  final bool adminView;
}

/// Yönetici (destek) mesajlaşmasında bir kullanıcı dizisi (thread). Her
/// kullanıcı admin ile birebir bir konuşma yürütür; admin tüm dizileri görür.
@immutable
class SupportThread {
  const SupportThread({
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.lastMessage,
    this.lastTimestamp,
    this.lastSenderId,
    this.status,
  });

  /// Konuşma sahibi kullanıcının UID'si (thread doküman kimliği).
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String? lastMessage;
  final DateTime? lastTimestamp;
  final String? status; // 'unread', 'resolved', 'pending'

  /// Son mesajı kim yazdı (admin yanıtı mı kullanıcı mı ayırt etmek için).
  final String? lastSenderId;

  static String? _str(dynamic v) =>
      (v is String && v.trim().isNotEmpty) ? v.trim() : null;

  factory SupportThread.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['lastTimestamp'];
    return SupportThread(
      userId: doc.id,
      userName: (data['userName'] as String?) ?? doc.id,
      userPhotoUrl: _str(data['userPhotoUrl']),
      lastMessage: _str(data['lastMessage']),
      lastTimestamp: ts is Timestamp ? ts.toDate() : null,
      lastSenderId: _str(data['lastSenderId']),
      status: _str(data['status']),
    );
  }
}

/// IPTV topluluğuna özel yayın durumu etiketleri. Mesaja iliştirilerek o anki
/// yayın kalitesi hızlıca raporlanır.
enum ChatStatusTag {
  flowing,
  noFreeze,
  freeze,
  down;

  /// Firestore'da saklanan kısa anahtar.
  String get key => switch (this) {
        flowing => 'flowing',
        noFreeze => 'no_freeze',
        freeze => 'freeze',
        down => 'down',
      };

  /// i18n etiket anahtarı.
  String get labelKey => switch (this) {
        flowing => 'chat.tag.flowing',
        noFreeze => 'chat.tag.noFreeze',
        freeze => 'chat.tag.freeze',
        down => 'chat.tag.down',
      };

  static ChatStatusTag? fromKey(String? raw) {
    if (raw == null) return null;
    for (final t in values) {
      if (t.key == raw) return t;
    }
    return null;
  }
}

/// Firebase Firestore tabanlı, dile göre odalara ayrılmış canlı sohbet.
///
/// Tasarım ilkeleri:
/// * **Tembel**: bu servis yalnızca Chat bölümüne girilince ([ChatBinding] ile)
///   oluşturulur. Oda listesi statiktir; hiçbir Firestore okuması yapmaz.
/// * **Trafik yok**: mesaj akışı yalnızca belirli bir odaya girilince
///   ([messagesStream]) açılır; ana ekran ya da oda seçim ekranı ağ trafiği
///   döndürmez.
/// * **Yetki**: yazma yalnızca Google ile oturum açmış (bulut senkronu aktif)
///   kullanıcılar için. Kurallar Firestore tarafında da zorlanır.
class ChatService extends GetxService with WidgetsBindingObserver {
  ChatService({AuthService? authService}) : _authOverride = authService;

  final AuthService? _authOverride;
  Worker? _authPresenceWorker;
  StreamSubscription? _unreadSub;
  StreamSubscription? _announcementSub;

  /// Kullanıcının okunmamış destek mesajı sayısı.
  final RxInt unreadMessages = 0.obs;

  /// `chats/rooms/{lang}` — her dil kodu, mesaj dökümanlarını tutan bir
  /// koleksiyondur. (Kullanıcının istediği `chats/rooms/{lang}/messages`
  /// yapısının geçerli Firestore karşılığı.)
  static const String _chatsCollection = 'chats';
  static const String _roomsDoc = 'rooms';

  /// Performans: her odada yalnızca son [_messageLimit] mesaj dinlenir.
  static const int _messageLimit = 100;

  /// Tek mesaj uzunluğu üst sınırı (kurallarla da zorlanır).
  static const int maxMessageLength = 500;

  /// Admin (yönetici/geliştirici) Firebase UID listesi. Buradaki kullanıcılar
  /// mesajlarında [Admin] rozeti + amber renk alır ve **herhangi** bir mesajı
  /// silebilir. Yeni admin eklemek için kişinin UID'sini hem buraya hem
  /// `firestore.rules` içindeki `isChatAdmin()` listesine ekleyin.
  ///
  /// UID'yi bulmak için: Firebase Console → Authentication → Users → ilgili
  /// kullanıcının "User UID" değeri.
  static const List<String> adminUids = <String>[
    'S90HID84FieYC4UBQ6BdoFrYtff2',
  ];

  bool isAdminUid(String? uid) => uid != null && adminUids.contains(uid);

  /// Oturum açmış kullanıcı admin mi?
  bool get isCurrentUserAdmin => isAdminUid(currentUserId);

  AuthService get _auth {
    if (_authOverride != null) return _authOverride;
    return Get.find<AuthService>();
  }

  /// Bulut + **Google** oturumu hazır mı? Anonim deneme hesabı sohbet yazamaz.
  bool get isReady => gFirebaseReady && isGoogleSignedIn;

  /// Google (veya anonim olmayan) oturum — sohbet kapısı / mesaj yazma.
  bool get isGoogleSignedIn {
    final user = _auth.currentUser.value;
    return user != null && !user.isAnonymous;
  }

  /// Oturum açmış kullanıcının görünen adı (Google profil ismi) veya yedek.
  String get currentUserName {
    final user = _auth.currentUser.value;
    final name = user?.displayName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final email = user?.email;
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Misafir';
  }

  String? get currentUserId => _auth.currentUser.value?.uid;

  /// Oturum açmış kullanıcının Google profil fotoğrafı (yoksa `null`).
  String? get currentUserPhotoUrl {
    final url = _auth.currentUser.value?.photoURL;
    if (url != null && url.trim().isNotEmpty) return url.trim();
    return null;
  }

  CollectionReference<Map<String, dynamic>> _roomRef(String langCode) {
    return FirebaseFirestore.instance
        .collection(_chatsCollection)
        .doc(_roomsDoc)
        .collection(langCode);
  }

  /// Belirli bir odanın son [_messageLimit] mesajını canlı dinler.
  /// En yeni mesaj en altta olacak şekilde (kronolojik) sıralı döner.
  ///
  /// NOT: Bu stream yalnızca çağrıldığında Firestore'a bağlanır; oda seçim
  /// ekranı veya ana ekran bunu çağırmaz → gereksiz trafik oluşmaz.
  Stream<List<ChatMessage>> messagesStream(String langCode) {
    if (!gFirebaseReady) return const Stream<List<ChatMessage>>.empty();
    return _roomRef(langCode)
        .orderBy('timestamp', descending: true)
        .limit(_messageLimit)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(ChatMessage.fromDoc).toList();
      // En yeni en altta: descending çekip ters çeviriyoruz.
      return list.reversed.toList(growable: false);
    });
  }

  /// Odaya mesaj gönderir. Boş/aşırı uzun metin reddedilir. Başarılıysa `true`.
  /// [replyTo] verilirse mesaj o mesajı alıntılar; [statusTag] verilirse yayın
  /// durumu etiketi iliştirilir. Yalnızca metin + emoji desteklenir (medya yok).
  Future<bool> sendMessage(
    String langCode,
    String text, {
    ChatMessage? replyTo,
    ChatStatusTag? statusTag,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (!isReady) return false;
    final uid = currentUserId;
    if (uid == null) return false;
    final clipped = trimmed.length > maxMessageLength
        ? trimmed.substring(0, maxMessageLength)
        : trimmed;
    try {
      final data = <String, dynamic>{
        'senderId': uid,
        'senderName': currentUserName,
        'messageText': clipped,
        'timestamp': FieldValue.serverTimestamp(),
      };
      final photo = currentUserPhotoUrl;
      if (photo != null) data['senderPhotoUrl'] = photo;
      if (isAdminUid(uid)) data['senderRole'] = 'admin';
      if (replyTo != null) {
        data['replyToName'] = replyTo.senderName;
        final rt = replyTo.messageText;
        data['replyToText'] = rt.length > 140 ? rt.substring(0, 140) : rt;
      }
      if (statusTag != null) data['statusTag'] = statusTag.key;
      await _roomRef(langCode).add(data);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatService] sendMessage error: $e');
      return false;
    }
  }

  /// Bir odanın son (en güncel) mesajını tek seferlik çeker. Oda seçim
  /// ekranında önizleme için kullanılır (canlı dinleme değil → hafif).
  /// Mesaj yoksa `null` döner.
  Future<ChatMessage?> fetchLastMessage(String langCode) async {
    if (!gFirebaseReady) return null;
    try {
      final snap = await withFirestoreTimeout(_roomRef(langCode)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get());
      if (snap.docs.isEmpty) return null;
      return ChatMessage.fromDoc(snap.docs.first);
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatService] fetchLastMessage error: $e');
      return null;
    }
  }

  /// Bir mesajı silebilir miyim? Kendi mesajım ya da admin isem herhangi mesaj.
  bool canDelete(ChatMessage message) {
    final uid = currentUserId;
    if (uid == null) return false;
    return message.senderId == uid || isAdminUid(uid);
  }

  /// Mesajı siler. Kullanıcı kendi mesajını veya admin **herhangi** bir mesajı
  /// silebilir (Firestore kuralı tarafında da zorlanır). Başarılıysa `true`.
  Future<bool> deleteMessage(String langCode, ChatMessage message) async {
    if (!isReady) return false;
    if (!canDelete(message)) return false;
    try {
      await _roomRef(langCode).doc(message.id).delete();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatService] deleteMessage error: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Yöneticiye mesaj (destek / birebir admin DM)
  //
  // Her kullanıcı admin ile birebir bir "thread" yürütür. Thread doküman
  // kimliği = kullanıcının UID'si. Yapı:
  //   support_threads/{userUid}            → thread meta (son mesaj, isim, foto)
  //   support_threads/{userUid}/messages   → mesajlar (ChatMessage)
  //
  // Görünürlük: yalnızca thread sahibi (kullanıcı) ve admin. Firestore
  // kuralları tarafında da zorlanır. Admin tüm thread'leri listeleyebilir;
  // normal kullanıcı yalnızca kendi thread'ine erişir.
  // -------------------------------------------------------------------------

  static const String _supportThreadsCollection = 'support_threads';
  static const String _supportMessagesSub = 'messages';

  CollectionReference<Map<String, dynamic>> _supportThreadsRef() {
    return FirebaseFirestore.instance.collection(_supportThreadsCollection);
  }

  CollectionReference<Map<String, dynamic>> _supportMessagesRef(
    String userUid,
  ) {
    return _supportThreadsRef().doc(userUid).collection(_supportMessagesSub);
  }

  /// Admin'in belirli bir kullanıcıya özel destek mesajı atmasını sağlar.
  Future<void> sendAdminMessageToUser(String targetUid, String text) async {
    final senderId = currentUserId;
    if (senderId == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final threadRef = _supportThreadsRef().doc(targetUid);
    final msgRef = _supportMessagesRef(targetUid).doc();
    final now = FieldValue.serverTimestamp();

    final msgData = <String, dynamic>{
      'senderId': senderId,
      'senderName': currentUserName.isEmpty ? 'Admin' : currentUserName,
      'messageText': trimmed,
      'timestamp': now,
      'senderRole': 'admin',
    };
    final photo = currentUserPhotoUrl;
    if (photo != null) msgData['senderPhotoUrl'] = photo;

    final metaData = <String, dynamic>{
      'userId': targetUid,
      'lastMessageText': trimmed,
      'lastMessageTime': now,
      'unreadCountUser': FieldValue.increment(1),
    };

    batch.set(msgRef, msgData);
    batch.set(threadRef, metaData, SetOptions(merge: true));

    await withFirestoreTimeout(batch.commit());
  }

  /// Admin'in birden fazla kullanıcıya tek seferde mesaj atmasını sağlar.
  Future<void> sendBulkAdminMessage(List<String> targetUids, String text) async {
    final senderId = currentUserId;
    if (senderId == null || text.trim().isEmpty) return;

    final trimmed = text.trim();
    final db = FirebaseFirestore.instance;
    WriteBatch batch = db.batch();
    int opCount = 0;

    for (final uid in targetUids) {
      if (opCount >= 490) { // Firestore batch limit is 500
        await withFirestoreTimeout(batch.commit());
        batch = db.batch();
        opCount = 0;
      }

      final threadRef = _supportThreadsRef().doc(uid);
      final msgRef = _supportMessagesRef(uid).doc();
      final now = FieldValue.serverTimestamp();

      final msgData = <String, dynamic>{
        'senderId': senderId,
        'senderName': 'Admin',
        'messageText': trimmed,
        'timestamp': now,
        'senderRole': 'admin',
      };

      final metaData = <String, dynamic>{
        'userId': uid,
        'lastMessageText': trimmed,
        'lastMessageTime': now,
        'unreadCountUser': FieldValue.increment(1),
      };

      batch.set(msgRef, msgData);
      batch.set(threadRef, metaData, SetOptions(merge: true));
      opCount += 2;
    }

    if (opCount > 0) {
      await withFirestoreTimeout(batch.commit());
    }
  }

  /// Belirli bir kullanıcının admin ile konuşmasının son [_messageLimit]
  /// mesajını canlı dinler (en yeni en altta).
  Stream<List<ChatMessage>> supportMessagesStream(String userUid) {
    if (!gFirebaseReady) return const Stream<List<ChatMessage>>.empty();
    return _supportMessagesRef(userUid)
        .orderBy('timestamp', descending: true)
        .limit(_messageLimit)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(ChatMessage.fromDoc).toList();
      return list.reversed.toList(growable: false);
    });
  }

  /// Admin için: tüm destek thread'lerini son mesaja göre (en yeni üstte)
  /// canlı dinler. Yalnızca admin çağırmalı (kurallar da kısıtlar).
  Stream<List<SupportThread>> supportThreadsStream() {
    if (!gFirebaseReady) return const Stream<List<SupportThread>>.empty();
    return _supportThreadsRef()
        .orderBy('lastTimestamp', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map(SupportThread.fromDoc).toList());
  }

  /// Yöneticiye (veya admin → kullanıcıya) mesaj gönderir. [userUid] thread'in
  /// sahibi kullanıcının UID'sidir (normal kullanıcı için kendi UID'si; admin
  /// yanıtlarken hedef kullanıcının UID'si). Başarılıysa `true`.
  Future<bool> sendSupportMessage(
    String userUid,
    String text, {
    ChatMessage? replyTo,
    String? targetUserName,
    String? targetUserPhotoUrl,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (!isReady) return false;
    final uid = currentUserId;
    if (uid == null) return false;
    final clipped = trimmed.length > maxMessageLength
        ? trimmed.substring(0, maxMessageLength)
        : trimmed;
    final sentByAdmin = isAdminUid(uid);
    try {
      final data = <String, dynamic>{
        'senderId': uid,
        'senderName': currentUserName,
        'messageText': clipped,
        'timestamp': FieldValue.serverTimestamp(),
      };
      final photo = currentUserPhotoUrl;
      if (photo != null) data['senderPhotoUrl'] = photo;
      if (sentByAdmin) data['senderRole'] = 'admin';
      if (replyTo != null) {
        data['replyToName'] = replyTo.senderName;
        final rt = replyTo.messageText;
        data['replyToText'] = rt.length > 140 ? rt.substring(0, 140) : rt;
      }
      await _supportMessagesRef(userUid).add(data);

      // Thread meta'yı güncelle (inbox önizlemesi + sıralama). Kullanıcı
      // kendi adına yazıyorsa kimlik bilgilerini de tazele; admin yanıtında
      // kullanıcı bilgilerini ezme.
      final meta = <String, dynamic>{
        'userId': userUid,
        'lastMessage': clipped,
        'lastTimestamp': FieldValue.serverTimestamp(),
        'lastSenderId': uid,
      };
      if (!sentByAdmin && uid == userUid) {
        meta['userName'] = currentUserName;
        if (photo != null) meta['userPhotoUrl'] = photo;
        meta['status'] = 'unread'; // Sadece kullanıcı yazarsa unread yap, admin yanıtlarsa değil
      } else {
        // Admin yazarken hedefin ismi/resmi varsa (örneğin çevrimiçi listesinden geliyorsa)
        // isim/resim eksikse diye meta dokümanına kaydedelim:
        if (targetUserName != null && targetUserName.isNotEmpty) {
          meta['userName'] = targetUserName;
        }
        if (targetUserPhotoUrl != null && targetUserPhotoUrl.isNotEmpty) {
          meta['userPhotoUrl'] = targetUserPhotoUrl;
        }
      }
      await _supportThreadsRef()
          .doc(userUid)
          .set(meta, SetOptions(merge: true));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatService] sendSupportMessage error: $e');
      return false;
    }
  }

  /// Thread durumunu günceller (unread, resolved, pending)
  Future<bool> markThreadStatus(String userUid, String status) async {
    if (!isReady || currentUserId == null) return false;
    try {
      await _supportThreadsRef()
          .doc(userUid)
          .set({'status': status}, SetOptions(merge: true));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatService] markThreadStatus error: $e');
      return false;
    }
  }

  /// Bir destek mesajını siler (kendi mesajı veya admin). Başarılıysa `true`.
  Future<bool> deleteSupportMessage(
    String userUid,
    ChatMessage message,
  ) async {
    if (!isReady) return false;
    if (!canDelete(message)) return false;
    try {
      await _supportMessagesRef(userUid).doc(message.id).delete();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatService] deleteSupportMessage error: $e');
      return false;
    }
  }

  /// Bir kullanıcının admin ile olan destek thread'inin **tamamını** siler:
  /// tüm mesajlar (`messages` alt koleksiyonu) + thread meta dökümanı.
  ///
  /// Yetki: kullanıcı yalnızca **kendi** thread'ini, admin **herhangi** bir
  /// thread'i silebilir (Firestore kuralları tarafında da zorlanır). Mesajlar
  /// Firestore batch limiti (500) altında dilimlenerek silinir.
  /// Başarılıysa `true` döner.
  Future<bool> deleteSupportThread(String userUid) async {
    if (!isReady) return false;
    final uid = currentUserId;
    if (uid == null) return false;
    if (uid != userUid && !isAdminUid(uid)) return false;
    try {
      final db = FirebaseFirestore.instance;
      final snap = await _supportMessagesRef(userUid).get();
      final docs = snap.docs;
      const chunk = 450;
      for (var i = 0; i < docs.length; i += chunk) {
        final batch = db.batch();
        for (final d in docs.skip(i).take(chunk)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
      await _supportThreadsRef().doc(userUid).delete();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatService] deleteSupportThread error: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Çevrimiçi varlık (presence) — uygulamada oturumu açık kullanıcılar.
  //
  // Heartbeat (lastSeen) uygulama genelinde yazılır. Aggregate/filtre sayımı
  // sohbet açıkken yapılır. lastSeen bayatlayınca (~3 dk) «offline» sayılır;
  // kısa pause/hidden'da döküman SİLİNMEZ (aksi halde rozet 1'e düşer).
  // -------------------------------------------------------------------------

  static const String _presenceCollection = 'presence';
  static const Duration _presenceHeartbeat = Duration(seconds: 35);
  static const Duration _presenceStaleWindow = Duration(minutes: 3);
  static const Duration _onlineCountPoll = Duration(seconds: 20);

  /// O an uygulamada çevrimiçi (son ~3 dk lastSeen) kullanıcı sayısı.
  final RxInt onlineCount = 0.obs;

  Timer? _presenceTimer;
  Timer? _onlineCountTimer;
  bool _presenceActive = false;
  int _presenceEpoch = 0;
  int _chatCountInterest = 0;

  CollectionReference<Map<String, dynamic>> _presenceRef() =>
      FirebaseFirestore.instance.collection(_presenceCollection);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _authPresenceWorker = ever(_auth.currentUser, (_) => syncAppPresence());
    // Auth / Firebase biraz gecikebilir; kısa gecikmeyle bir kez daha dene.
    unawaited(Future<void>.delayed(const Duration(seconds: 2), () {
      if (isClosed) return;
      syncAppPresence();
      _listenToAnnouncements();
    }));
    syncAppPresence();
    _listenToAnnouncements();
    _checkSmartTrialAnnouncement();
  }

  void _listenToAnnouncements() {
    _announcementSub?.cancel();
    if (!gFirebaseReady) return;
    _announcementSub = FirebaseFirestore.instance
        .collection('admin_announcements')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) return;
      
      // Bulunan 5 duyuru içerisinden scheduledFor (Zamanlanan vakit) şu andan küçük olan İLK duyuruyu bul:
      QueryDocumentSnapshot<Map<String, dynamic>>? targetDoc;
      final now = DateTime.now();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['scheduledFor'] != null) {
          final scheduledDate = (data['scheduledFor'] as Timestamp).toDate();
          if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
            targetDoc = doc;
            break;
          }
        }
      }

      if (targetDoc == null) return; // Geçerli duyuru yok
      
      final data = targetDoc.data();
      final id = targetDoc.id;
      String? title = data['title'] as String?;
      String? message = data['message'] as String?;
      final url = data['url'] as String?;
      
      if (title == null || message == null) return;

      // Kullanıcının dili Türkçe değilse, metinleri çevir
      final localeCode = Get.locale?.languageCode ?? 'en';
      if (localeCode != 'tr') {
        try {
          final translator = GoogleTranslator();
          final translatedTitle = await translator.translate(title, from: 'tr', to: localeCode);
          final translatedMsg = await translator.translate(message, from: 'tr', to: localeCode);
          title = translatedTitle.text;
          message = translatedMsg.text;
        } catch (e) {
          if (kDebugMode) debugPrint('Translation error: $e');
        }
      }

      // Sıçrama (Splash) ekranı veya henüz hazır değilse bekle.
      // Bu sayede splash ekranı kapanırken pop-up'ın da kapanmasını engelliyoruz.
      while (Get.currentRoute == '/' || Get.currentRoute.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Navigasyon geçişinin (animasyonunun) tamamen bitmesi için ekstra bekleme süresi:
      // Aksi halde Get.offAll işlemi sırasında dialog da kaybolabiliyor.
      await Future.delayed(const Duration(seconds: 2));

      final prefs = await SharedPreferences.getInstance();
      
      // Uygulamanın bu sürüme güncellendiği/kurulduğu zamanı kontrol et:
      int? installTime = prefs.getInt('mina_app_install_time');
      if (installTime == null) {
        // Yeni kurulum veya bu özelliğin eklendiği yeni güncelleme.
        installTime = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt('mina_app_install_time', installTime);
        // Eski (şu anki en son) duyuruyu gösterimden gizlemek için id'sini kaydedip çıkıyoruz.
        await prefs.setString('last_admin_announcement_id', id);
        return;
      }

      // Duyurunun zamanı, uygulamanın kurulduğu zamandan daha eskiyse (önceyse), gösterme!
      final scheduledTimestamp = data['scheduledFor'] as Timestamp?;
      if (scheduledTimestamp != null) {
        if (scheduledTimestamp.millisecondsSinceEpoch < installTime) {
          final lastShownCheck = prefs.getString('last_admin_announcement_id');
          if (lastShownCheck != id) {
            await prefs.setString('last_admin_announcement_id', id);
          }
          return;
        }
      }

      final lastShown = prefs.getString('last_admin_announcement_id');
      if (lastShown != id) {
        await prefs.setString('last_admin_announcement_id', id);
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        Get.dialog<void>(
          Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.campaign_rounded, size: 48, color: Colors.amberAccent),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message!,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => Get.back(),
                              child: Text(localeCode == 'tr' ? 'Kapat' : 'Close', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                          ),
                          if (url != null && url.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amberAccent,
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () async {
                                  final uri = Uri.tryParse(url);
                                  if (uri != null && await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                  Get.back();
                                },
                                child: Text(localeCode == 'tr' ? 'Detaylar' : 'Details', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          barrierDismissible: false,
        );
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('[ChatService] Announcements stream error: $e');
    });
  }

  Future<void> _checkSmartTrialAnnouncement() async {
    if (!gFirebaseReady) return;
    
    try {
      // Yalnızca admin ayarını kontrol et
      final docSnap = await FirebaseFirestore.instance.collection('admin_settings').doc('smart_announcements').get();
      if (!docSnap.exists) return;
      final data = docSnap.data();
      if (data == null || data['trialExpiryEnabled'] != true) return;

      if (!Get.isRegistered<LicensingService>()) return;
      final licensing = Get.find<LicensingService>();
      if (licensing.isPremium.value) return;

      final expire = licensing.trialExpirationDate.value;
      if (expire == null) return;

      final remainingHours = expire.difference(DateTime.now()).inHours;
      if (remainingHours < 0 || remainingHours >= 24) return;

      // Günlük kontrol (Günde 1 kez)
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final lastShown = prefs.getString('last_smart_trial_day');
      if (lastShown == today) return;

      // Çeviri
      String title = "Ömür Boyu Ücretsiz Kullanım";
      String message = "Bize şans verip ömür boyu ücretsiz kullanmak için şimdi ödeme yapabilirsiniz.";
      String btnText = "Hemen Satın Al";
      String closeText = "Kapat";
      
      final localeCode = Get.locale?.languageCode ?? 'en';
      if (localeCode != 'tr') {
        try {
          final translator = GoogleTranslator();
          title = (await translator.translate(title, from: 'tr', to: localeCode)).text;
          message = (await translator.translate(message, from: 'tr', to: localeCode)).text;
          btnText = (await translator.translate(btnText, from: 'tr', to: localeCode)).text;
          closeText = (await translator.translate(closeText, from: 'tr', to: localeCode)).text;
        } catch (e) {
          if (kDebugMode) debugPrint('Smart Trial Translation error: $e');
        }
      }

      // Splash beklemesi
      while (Get.currentRoute == '/' || Get.currentRoute.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await Future.delayed(const Duration(seconds: 4)); // Splash sonrası bekleme
      
      // Tekrar premium oldu mu kontrol et
      if (licensing.isPremium.value) return;

      await prefs.setString('last_smart_trial_day', today);

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.dialog<void>(
        Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(color: Colors.amberAccent.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 48),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(message, style: const TextStyle(color: Colors.white70, fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Get.back(); // Kapat
                    Get.toNamed(AppRoutes.paywall);
                  },
                  child: Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Get.back(),
                  child: Text(closeText, style: const TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatService] Smart Trial Announcement Error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncAppPresence();
      if (_chatCountInterest > 0) {
        unawaited(_refreshOnlineCount());
      }
    } else if (state == AppLifecycleState.detached) {
      // Yalnızca süreç kapanırken sil — pause/hidden'da dokunma (sayım çöker).
      _stopPresence(removeDoc: true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Heartbeat'i durdur; lastSeen bayatlayınca sayım düşer.
      _stopPresence(removeDoc: false);
    }
  }

  /// Ön plan + oturum açıksa heartbeat başlat; aksi halde durdur.
  void syncAppPresence() {
    if (!gFirebaseReady || currentUserId == null) {
      _stopPresence(removeDoc: true);
      return;
    }
    final life = WidgetsBinding.instance.lifecycleState;
    if (life != null &&
        life != AppLifecycleState.resumed &&
        life != AppLifecycleState.inactive) {
      return;
    }
    _startPresence();
  }

  /// Sohbet rozeti görünürken count sorgusunu açar.
  void acquirePresence() {
    _chatCountInterest++;
    syncAppPresence();
    _armOnlineCountPoll();
    unawaited(_refreshOnlineCount());
  }

  /// Sohbet kapanınca count sorgusunu kapatır (heartbeat uygulama genelinde kalır).
  void releasePresence() {
    if (_chatCountInterest > 0) _chatCountInterest--;
    if (_chatCountInterest <= 0) {
      _onlineCountTimer?.cancel();
      _onlineCountTimer = null;
    }
  }

  void _armOnlineCountPoll() {
    _onlineCountTimer?.cancel();
    if (_chatCountInterest <= 0) return;
    _onlineCountTimer = Timer.periodic(_onlineCountPoll, (_) {
      if (_chatCountInterest > 0) unawaited(_refreshOnlineCount());
    });
  }

  void _startPresence() {
    if (!gFirebaseReady || currentUserId == null) return;
    if (_presenceActive) {
      unawaited(_beat());
      return;
    }
    _presenceActive = true;
    unawaited(_beat());
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(_presenceHeartbeat, (_) {
      _beat();
    });
    _listenToUnreadMessages();
  }

  void _listenToUnreadMessages() {
    _unreadSub?.cancel();
    _unreadSub = null;
    final uid = currentUserId;
    if (gFirebaseReady && uid != null) {
      _unreadSub = _supportThreadsRef().doc(uid).snapshots().listen((snap) {
        if (snap.exists) {
          final data = snap.data();
          if (data != null) {
            final oldUnread = unreadMessages.value;
            final newUnread = (data['unreadCountUser'] as num?)?.toInt() ?? 0;
            unreadMessages.value = newUnread;
            
            if (newUnread > oldUnread && !isCurrentUserAdmin) {
               final lastSenderId = data['lastSenderId'] as String?;
               final lastMessage = data['lastMessage'] as String?;
               if (lastSenderId != null && lastSenderId != uid && lastMessage != null && lastMessage.isNotEmpty) {
                  _showAdminMessagePopup(lastMessage);
               }
            }
          }
        } else {
          unreadMessages.value = 0;
        }
      }, onError: (e) {
        if (kDebugMode) debugPrint('[ChatService] Unread messages stream error: $e');
        unreadMessages.value = 0;
      });
    } else {
      unreadMessages.value = 0;
    }
  }

  void _showAdminMessagePopup(String originalMessage) async {
    if (Get.isSnackbarOpen) {
       Get.closeAllSnackbars();
    }
    if (Get.currentRoute == AppRoutes.chatRoom) {
       return;
    }

    String title = 'Yöneticiden Mesajınız Var';
    String message = originalMessage;
    String btnReply = 'Cevap Ver';
    String btnClose = 'Kapat';

    final localeCode = Get.locale?.languageCode ?? 'en';
    if (localeCode != 'tr') {
      try {
        final t = GoogleTranslator();
        title = (await t.translate(title, from: 'tr', to: localeCode)).text;
        message = (await t.translate(message, from: 'tr', to: localeCode)).text;
        btnReply = (await t.translate(btnReply, from: 'tr', to: localeCode)).text;
        btnClose = (await t.translate(btnClose, from: 'tr', to: localeCode)).text;
      } catch (_) {}
    }

    Get.defaultDialog<void>(
      title: title,
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
      backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.95),
      titleStyle: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
      textConfirm: btnReply,
      textCancel: btnClose,
      confirmTextColor: Colors.white,
      cancelTextColor: Colors.white70,
      buttonColor: Colors.blueAccent,
      onConfirm: () {
        Get.back(); // close dialog
        final uid = currentUserId;
        if (uid != null) {
          Get.toNamed<void>(
            AppRoutes.chatRoom,
            arguments: ChatSupportTarget(
              threadUid: uid,
              title: 'chat.support.adminName'.tr,
            ),
          );
        }
      },
      onCancel: () {},
    );
  }

  /// Okunmamış mesaj sayacını sıfırlar.
  Future<void> markSupportMessagesRead() async {
    final uid = currentUserId;
    if (uid == null || !gFirebaseReady) return;
    try {
      await _supportThreadsRef().doc(uid).set(
        <String, dynamic>{'unreadCountUser': 0},
        SetOptions(merge: true),
      );
      unreadMessages.value = 0;
    } catch (_) {}
  }

  void _stopPresence({required bool removeDoc}) {
    _presenceEpoch++;
    _presenceActive = false;
    _presenceTimer?.cancel();
    _presenceTimer = null;
    if (!removeDoc) return;
    final uid = currentUserId;
    if (gFirebaseReady && uid != null) {
      _presenceRef().doc(uid).delete().catchError((_) {});
    }
  }

  Future<void> _beat() async {
    if (!_presenceActive || !gFirebaseReady) return;
    final uid = currentUserId;
    if (uid == null) return;
    final epoch = _presenceEpoch;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final data = <String, dynamic>{
        'lastSeen': FieldValue.serverTimestamp(),
        'name': currentUserName,
      };
      if (user?.email != null) data['email'] = user!.email;
      if (user?.photoURL != null) data['photoUrl'] = user!.photoURL;

      await _presenceRef().doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatService] presence beat error: $e');
    }
    if (!_presenceActive || epoch != _presenceEpoch) return;
    if (_chatCountInterest > 0) {
      await _refreshOnlineCount();
    }
  }

  /// [lastSeen] Timestamp veya epoch-ms olabilir (eski istemciler).
  static DateTime? _readLastSeen(dynamic raw) {
    if (raw is Timestamp) return raw.toDate().toUtc();
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    }
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true);
    }
    return null;
  }

  Future<void> _refreshOnlineCount() async {
    if (!gFirebaseReady || currentUserId == null) return;
    try {
      // Aggregate + inequality bazı cihazlarda eksik sonuç verebiliyor;
      // sunucudan tüm presence dokümanlarını alıp lastSeen'e göre say.
      final snap = await _presenceRef().get(
        const GetOptions(source: Source.server),
      );
      final cutoff = DateTime.now().toUtc().subtract(_presenceStaleWindow);
      var n = 0;
      for (final doc in snap.docs) {
        final t = _readLastSeen(doc.data()['lastSeen']);
        if (t != null && !t.isBefore(cutoff)) n++;
      }
      onlineCount.value = n;
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatService] online count error: $e');
      // Yedek: aggregate count (indeks / kurallar uygunsa).
      try {
        final cutoff = Timestamp.fromDate(
          DateTime.now().toUtc().subtract(_presenceStaleWindow),
        );
        final agg = await _presenceRef()
            .where('lastSeen', isGreaterThan: cutoff)
            .count()
            .get(source: AggregateSource.server);
        if (agg.count != null) onlineCount.value = agg.count!;
      } catch (e2) {
        if (kDebugMode) debugPrint('[ChatService] online count fallback error: $e2');
      }
    }
  }

  @override
  void onClose() {
    _authPresenceWorker?.dispose();
    _presenceTimer?.cancel();
    _unreadSub?.cancel();
    _announcementSub?.cancel();
    _onlineCountTimer?.cancel();
    _onlineCountTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    _stopPresence(removeDoc: true);
    super.onClose();
  }
}
