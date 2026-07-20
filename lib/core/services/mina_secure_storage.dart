import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Uygulama genelinde tek [FlutterSecureStorage] + Android Keystore ısınması.
///
/// `encryptedSharedPreferences: true` ilk [containsKey]/[read] çağrısında
/// `EncryptedSharedPreferences.create` + Keystore AEAD yapar; bu işlem bazı
/// cihazlarda saniyeler sürer ve platform channel bekleyen UI'yı ANR gibi
/// dondurur. [warmUp] soğuk init'i splash/ayar yüklemesiyle paralel çalıştırır.
class MinaSecureStorage {
  MinaSecureStorage._();

  static const AndroidOptions androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  /// Playlist / lisans / yedek için paylaşılan örnek — her serviste yeni
  /// `FlutterSecureStorage()` açmak birden fazla Keystore init riski taşır.
  static const FlutterSecureStorage instance = FlutterSecureStorage(
    aOptions: androidOptions,
  );

  static const String _warmKey = '__mina_secure_storage_warmup_v1__';

  static Future<void>? _warmFuture;

  /// Keystore / EncryptedSharedPreferences soğuk init. Tekrar çağrılar aynı
  /// Future'ı paylaşır. Hata yutulur; sonraki gerçek okuma yine dener.
  static Future<void> warmUp() => _warmFuture ??= _warmUpOnce();

  /// [warmUp] bitene kadar bekler (veya henüz başlamadıysa başlatır).
  static Future<void> ensureReady() => warmUp();

  static Future<void> _warmUpOnce() async {
    try {
      // containsKey → ensureInitialized → EncryptedSharedPreferences.create
      await instance.containsKey(key: _warmKey);
    } catch (e, st) {
      debugPrint('mina_iptv: MinaSecureStorage warmUp failed: $e\n$st');
    }
  }
}
