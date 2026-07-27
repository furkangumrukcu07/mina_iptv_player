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
      case TargetPlatform.macOS:
        return ios;
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

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCe5qkUpA0_SdzNs_Gb1Wjv4XotARWAUX0',
    appId: '1:678971140280:ios:268aff6caaf77457156c4d',
    messagingSenderId: '678971140280',
    projectId: 'mina-iptv-player',
    storageBucket: 'mina-iptv-player.firebasestorage.app',
    iosClientId: '678971140280-2pabne7tpdu8ar6fbad9kn8c0e1ud6e3.apps.googleusercontent.com',
    iosBundleId: 'com.mina.iptv.minaIptvPlayer',
  );
}
