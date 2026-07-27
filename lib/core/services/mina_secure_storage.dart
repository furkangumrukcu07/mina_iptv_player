import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama genelinde tek [FlutterSecureStorage] + SharedPreferences yedekli güvenli depolama.
///
/// `encryptedSharedPreferences: true` ilk [containsKey]/[read] çağrısında
/// `EncryptedSharedPreferences.create` + Keystore AEAD yapar; bu işlem bazı
/// cihazlarda saniyeler sürer ve platform channel bekleyen UI'yı ANR gibi
/// dondurur. [warmUp] soğuk init'i splash/ayar yüklemesiyle paralel çalıştırır.
/// macOS / Desktop ortamında Keychain kısıtlaması durumunda SharedPreferences'a esnek düşer.
class MinaSecureStorage {
  MinaSecureStorage._();

  static const AndroidOptions androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  /// Playlist / lisans / yedek için paylaşılan korumalı örnek.
  static const FlutterSecureStorage instance = SafeFlutterSecureStorage();

  static const String _warmKey = '__mina_secure_storage_warmup_v1__';

  static Future<void>? _warmFuture;

  /// Keystore / EncryptedSharedPreferences soğuk init.
  static Future<void> warmUp() => _warmFuture ??= _warmUpOnce();

  /// [warmUp] bitene kadar bekler.
  static Future<void> ensureReady() => warmUp();

  static Future<void> _warmUpOnce() async {
    try {
      await instance.containsKey(key: _warmKey);
    } catch (e, st) {
      if (kDebugMode) debugPrint('mina_iptv: MinaSecureStorage warmUp failed: $e\n$st');
    }
  }
}

/// Masaüstü / macOS ortamlarında Keychain kısıtlaması durumunda
/// SharedPreferences yedekli [FlutterSecureStorage] sarmalayıcısı.
class SafeFlutterSecureStorage extends FlutterSecureStorage {
  const SafeFlutterSecureStorage({
    super.aOptions = MinaSecureStorage.androidOptions,
  });

  static const String _prefPrefix = '__mina_sec_store__';

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    try {
      final val = await super.read(
        key: key,
        iOptions: iOptions,
        aOptions: aOptions,
        lOptions: lOptions,
        webOptions: webOptions,
        mOptions: mOptions,
        wOptions: wOptions,
      );
      if (val != null) return val;
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: SecureStorage read error for $key: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefPrefix$key');
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      await delete(
        key: key,
        iOptions: iOptions,
        aOptions: aOptions,
        lOptions: lOptions,
        webOptions: webOptions,
        mOptions: mOptions,
        wOptions: wOptions,
      );
      return;
    }
    try {
      await super.write(
        key: key,
        value: value,
        iOptions: iOptions,
        aOptions: aOptions,
        lOptions: lOptions,
        webOptions: webOptions,
        mOptions: mOptions,
        wOptions: wOptions,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: SecureStorage write error for $key: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefPrefix$key', value);
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    try {
      await super.delete(
        key: key,
        iOptions: iOptions,
        aOptions: aOptions,
        lOptions: lOptions,
        webOptions: webOptions,
        mOptions: mOptions,
        wOptions: wOptions,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: SecureStorage delete error for $key: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefPrefix$key');
  }

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final val = await read(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
    return val != null;
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final map = <String, String>{};
    try {
      final secureMap = await super.readAll(
        iOptions: iOptions,
        aOptions: aOptions,
        lOptions: lOptions,
        webOptions: webOptions,
        mOptions: mOptions,
        wOptions: wOptions,
      );
      map.addAll(secureMap);
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: SecureStorage readAll error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys()) {
      if (k.startsWith(_prefPrefix)) {
        final rawKey = k.substring(_prefPrefix.length);
        if (!map.containsKey(rawKey)) {
          final v = prefs.getString(k);
          if (v != null) map[rawKey] = v;
        }
      }
    }
    return map;
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    try {
      await super.deleteAll(
        iOptions: iOptions,
        aOptions: aOptions,
        lOptions: lOptions,
        webOptions: webOptions,
        mOptions: mOptions,
        wOptions: wOptions,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: SecureStorage deleteAll error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().toList()) {
      if (k.startsWith(_prefPrefix)) {
        await prefs.remove(k);
      }
    }
  }
}
