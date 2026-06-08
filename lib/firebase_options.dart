// Firebase yapılandırması — Android değerleri `android/app/google-services.json`
// dosyasından alınmıştır (proje: mina-iptv-player).
//
// iOS / diğer platformlar için: `flutterfire configure` çalıştırıldığında bu
// dosya tüm platformlar için yeniden üretilir. Şu an yalnızca Android desteklenir.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Web için Firebase yapılandırılmadı. `flutterfire configure` çalıştırın.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS için Firebase yapılandırılmadı. `flutterfire configure` '
          'çalıştırıp GoogleService-Info.plist ekleyin.',
        );
      default:
        throw UnsupportedError(
          'Bu platform için Firebase yapılandırılmadı.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBHk8sLt18SPF-2xuvvJRH3HLEm7ywD8lE',
    appId: '1:678971140280:android:aac14166585a42a2156c4d',
    messagingSenderId: '678971140280',
    projectId: 'mina-iptv-player',
    storageBucket: 'mina-iptv-player.firebasestorage.app',
  );
}
