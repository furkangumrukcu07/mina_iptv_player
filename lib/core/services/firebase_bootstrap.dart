import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../platform/android_playback_soc_hints.dart';

import '../../firebase_options.dart';

/// Firebase gerçek bir proje ile yapılandırıldı mı?
///
/// `flutterfire configure` çalıştırıp [DefaultFirebaseOptions]'ı gerçek
/// değerlerle ürettikten **sonra** bunu `true` yap. O zamana dek tüm bulut
/// özellikleri (Google ile giriş, Firestore yedekleme) güvenle devre dışı
/// kalır ve uygulama hiçbir şekilde çökmez.
const bool kFirebaseConfigured = bool.fromEnvironment(
  'MINA_FIREBASE',
  defaultValue: true,
);

/// Runtime'da Firebase başarıyla başlatıldı mı? main() guarded init sonrası
/// servisler bunu okur.
bool gFirebaseReady = false;

/// Firebase'i **korumalı** şekilde başlatır. Yapılandırma yoksa veya init
/// hata verirse sessizce `false` döner — çağıran taraf bulut özelliklerini
/// kapalı tutar, uygulama normal akışına devam eder.
Future<bool> initFirebaseGuarded() async {
  if (!kFirebaseConfigured) {
    gFirebaseReady = false;
    return false;
  }
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final prefs = await SharedPreferences.getInstance();
      final layoutRaw = prefs.getString('mina_settings_app_layout_mode_v1');
      final isTvOrTablet = layoutRaw == 'tv' ||
          layoutRaw == 'tablet' ||
          AndroidPlaybackSocHints.androidTv ||
          AndroidPlaybackSocHints.lowEndSmartTvLike ||
          AndroidPlaybackSocHints.budgetTvBoxSoc;

      // ---- Performance‑friendly Firestore configuration ----
      // Limit offline cache to 10 MB (default is 40 MB) – suitable for TV‑box RAM.
      // Enable persistence on mobile/tablet, disable on TV to prevent background DB writes.
      FirebaseFirestore.instance.settings = Settings(
        cacheSizeBytes: 10 * 1024 * 1024, // 10 MB
        persistenceEnabled: !isTvOrTablet,
      );
      // -----------------------------------------------------
    }
    gFirebaseReady = true;
  } catch (e) {
    if (kDebugMode) debugPrint('[firebase_bootstrap] init failed → cloud disabled: $e');
    gFirebaseReady = false;
  }
  return gFirebaseReady;
}
