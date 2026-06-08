import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../ui/glass_overlays.dart';
import 'firebase_bootstrap.dart';

/// Uygulama arka planda / kapalıyken gelen FCM mesajlarını işleyen üst-seviye
/// handler. Firebase plugin'i izole bir isolate'te çağırır; bu yüzden global
/// (top-level) ve `@pragma('vm:entry-point')` olmak zorunda.
///
/// "Notification" payload'lu mesajlar (Firebase Console → Bildirim oluştur ile
/// gönderilen) zaten sistem tarafından otomatik bildirim çubuğunda gösterilir;
/// burada ekstra bir şey yapmaya gerek yok. Yine de ileride veri-mesajı (data
/// message) işlemek istenirse bağlantı noktası burası.
@pragma('vm:entry-point')
Future<void> minaFirebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[MinaPush] background message: ${message.messageId}');
}

/// Firebase Cloud Messaging (push bildirim) sarmalayıcısı.
///
/// Tasarım:
/// * **Tembel-güvenli**: Firebase hazır değilse hiçbir şey yapmaz (fail-open).
/// * **Topic tabanlı yayın**: tüm kullanıcılar `all` topic'ine abone edilir;
///   yönetici Firebase Console → Cloud Messaging'den bu topic'e bildirim
///   göndererek herkese ulaşır (sunucu/kod gerekmez).
/// * **İzin**: Android 13+ (API 33) `POST_NOTIFICATIONS` runtime iznini
///   [FirebaseMessaging.requestPermission] tetikler; reddedilse bile uygulama
///   normal çalışır (yalnızca bildirim gösterilmez).
/// * **Foreground**: uygulama açıkken gelen bildirim sistem çubuğunda
///   gösterilmez; bunun yerine uygulama içi cam snackbar ile gösterilir.
class MinaPushService extends GetxService {
  /// Herkese yayın için ortak topic. Console'dan bu topic'e gönderilen
  /// bildirim tüm abone cihazlara ulaşır.
  static const String kBroadcastTopic = 'all';

  FirebaseMessaging? _fm;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  bool _initStarted = false;

  /// Son alınan cihaz FCM token'ı (debug / hedefli gönderim için log'lanır).
  String? token;

  /// Splash sonrası (UI hazırken) çağrılır. Firebase yoksa sessizce çıkar.
  Future<MinaPushService> init() async {
    if (_initStarted) return this;
    _initStarted = true;
    if (!gFirebaseReady) {
      debugPrint('[MinaPush] Firebase hazır değil — push devre dışı');
      return this;
    }
    try {
      _fm = FirebaseMessaging.instance;

      // İzin iste (Android 13+ runtime prompt; iOS APNs izni). Reddedilirse
      // uygulama çalışmaya devam eder.
      final settings = await _fm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
        '[MinaPush] permission: ${settings.authorizationStatus}',
      );

      // Uygulama foreground iken sistem bildirimini bastırma (iOS) — burada
      // kendi uygulama içi snackbar'ımızı gösteriyoruz.
      await _fm!.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Herkese yayın topic'ine abone ol.
      await _fm!.subscribeToTopic(kBroadcastTopic);

      // Token (hedefli gönderim veya hata ayıklama için).
      token = await _fm!.getToken();
      debugPrint('[MinaPush] token: $token');
      _fm!.onTokenRefresh.listen((t) {
        token = t;
        debugPrint('[MinaPush] token refresh: $t');
      });

      // Foreground mesajları → uygulama içi cam snackbar.
      _foregroundSub = FirebaseMessaging.onMessage.listen(_onForeground);
    } catch (e) {
      debugPrint('[MinaPush] init hata: $e');
    }
    return this;
  }

  void _onForeground(RemoteMessage message) {
    final n = message.notification;
    final title = n?.title ?? message.data['title']?.toString() ?? '';
    final body = n?.body ?? message.data['body']?.toString() ?? '';
    if (title.isEmpty && body.isEmpty) return;
    GlassSnackbar.show(
      title.isNotEmpty ? title : 'Mina',
      body,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void onClose() {
    _foregroundSub?.cancel();
    super.onClose();
  }
}
