import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mina_secure_storage.dart';

/// Ebeveyn PIN'i (SHA-256 + sabit tuz) çift yedeklemeli depoda tutar.
///
/// **Neden iki depo?** Bazı Android cihazlarda (özellikle keystore reset /
/// "app data temizleme yapmadan yeniden kurulum" / OEM-spesifik yedekleme
/// senaryolarında) [FlutterSecureStorage] yazılan veriyi geri okuyamaz hâle
/// gelebilir; sonuçta kullanıcı **doğru PIN'i girdiği hâlde "yanlış PIN"
/// uyarısı** alır. Bu sınıf şu stratejiyi uygular:
///
///  * PIN hash'i AYNI ANDA hem [FlutterSecureStorage]'a (öncelik) hem de
///    [SharedPreferences]'a (yedek) yazılır. Hash zaten salt + SHA-256
///    olduğu için düz metin sızdırılmaz.
///  * Doğrulamada önce secure storage okunur; null/boş dönerse otomatik
///    SharedPreferences'a düşülür.
///  * Açılışta tek tarafta kayıt varsa eksik tarafa otomatik **kendini
///    iyileştirme** yapılır (kaybolan kopya yeniden yazılır).
///  * Bellek içi cache (`_cachedHash`) read çağrıları arasında sessiz
///    fallback'i mümkün kılar.
class ParentalControlService extends GetxService {
  static const _kPin = 'mina_parental_pin_sha256_v1';
  static const _kRecovery = 'mina_parental_recovery_sha256_v1';
  static const _salt = 'mina_iptv_parental|v1';

  final _secure = MinaSecureStorage.instance;
  final hasPin = false.obs;

  /// Kurtarma kelimesi belirlenmiş mi? PIN sıfırlamada bu kelime sorulur.
  final hasRecoveryWord = false.obs;

  /// Tek seferlik salt'lı SHA-256 hash — depolanan ve doğrulanan değer.
  static String hashPin(String pin) =>
      sha256.convert(utf8.encode('$pin|$_salt')).toString();

  /// Kurtarma kelimesi normalize edilip (trim + küçük harf) hash'lenir —
  /// kullanıcı büyük/küçük harf ya da baş/son boşlukla yanılmasın.
  static String _normalizeRecovery(String word) => word.trim().toLowerCase();

  static String hashRecovery(String word) => sha256
      .convert(utf8.encode('${_normalizeRecovery(word)}|$_salt|recovery'))
      .toString();

  /// Son okunan veya yazılan hash'in bellek içi kopyası. Secure storage
  /// gücünü kaybettiğinde dahi aynı oturum içinde verify çalışabilsin diye.
  String? _cachedHash;
  String? _cachedRecoveryHash;

  Future<void> refreshPinState() async {
    final stored = await _readHashWithSelfHeal(_kPin, _cachedHash);
    _cachedHash = stored;
    hasPin.value = stored != null && stored.isNotEmpty;
    final rec = await _readHashWithSelfHeal(_kRecovery, _cachedRecoveryHash);
    _cachedRecoveryHash = rec;
    hasRecoveryWord.value = rec != null && rec.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    final hash = hashPin(pin);
    _cachedHash = hash;
    // Çift yazım: secure storage öncelikli, SharedPreferences yedek.
    // Hangi taraf düşerse düşsün diğer kopya çalışmaya devam eder.
    await _writeBothStores(_kPin, hash);
    hasPin.value = true;
  }

  /// PIN ile birlikte kurtarma kelimesini de belirler.
  Future<void> setRecoveryWord(String word) async {
    final hash = hashRecovery(word);
    _cachedRecoveryHash = hash;
    await _writeBothStores(_kRecovery, hash);
    hasRecoveryWord.value = true;
  }

  Future<bool> verifyPin(String pin) async {
    final expected = hashPin(pin);
    final stored = await _readHashWithSelfHeal(_kPin, _cachedHash);
    if (stored == null || stored.isEmpty) {
      // Hiçbir depoda PIN yoksa doğrulama anlamsız.
      hasPin.value = false;
      return false;
    }
    return stored == expected;
  }

  /// Kurtarma kelimesini doğrular (PIN sıfırlama için).
  Future<bool> verifyRecoveryWord(String word) async {
    final expected = hashRecovery(word);
    final stored = await _readHashWithSelfHeal(_kRecovery, _cachedRecoveryHash);
    if (stored == null || stored.isEmpty) return false;
    return stored == expected;
  }

  Future<void> clearPin() async {
    _cachedHash = null;
    _cachedRecoveryHash = null;
    for (final key in [_kPin, _kRecovery]) {
      try {
        await _secure.delete(key: key);
      } catch (_) {}
      try {
        final p = await SharedPreferences.getInstance();
        await p.remove(key);
      } catch (_) {}
    }
    hasPin.value = false;
    hasRecoveryWord.value = false;
  }

  // ---------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------

  /// İki depodan da okur, yalnız birinde varsa eksik tarafı yeniden yazar
  /// (self-heal). [cached] bellek içi son değer (her iki depo da düşerse).
  Future<String?> _readHashWithSelfHeal(String key, String? cached) async {
    String? secureValue;
    try {
      secureValue = await _secure.read(key: key);
    } catch (_) {
      // KeyStore reset / decrypt fail vs. — okuma başarısız olursa null
      // gibi davran, prefs'e düş.
      secureValue = null;
    }
    String? prefsValue;
    try {
      final p = await SharedPreferences.getInstance();
      prefsValue = p.getString(key);
    } catch (_) {
      prefsValue = null;
    }

    final secureOk = secureValue != null && secureValue.isNotEmpty;
    final prefsOk = prefsValue != null && prefsValue.isNotEmpty;

    if (secureOk && !prefsOk) {
      // Secure storage'da var, prefs'te eksik — yedeği geri yaz.
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(key, secureValue);
      } catch (_) {}
      return secureValue;
    }
    if (!secureOk && prefsOk) {
      // Prefs'te var, secure storage'da yok — secure storage'a geri yaz.
      try {
        await _secure.write(key: key, value: prefsValue);
      } catch (_) {}
      return prefsValue;
    }
    if (secureOk && prefsOk) {
      // İki tarafta da var — secure storage primary kabul edilir.
      if (secureValue != prefsValue) {
        // Tutarsızlık (örn. eski kayıt): secure storage'ı kanonik say,
        // prefs'i ona göre güncelle.
        try {
          final p = await SharedPreferences.getInstance();
          await p.setString(key, secureValue);
        } catch (_) {}
      }
      return secureValue;
    }
    // İki depoda da yok ancak bu oturumda set ettiysek bellek cache'ine
    // güven (read çağrıları arasında storage düşmesine karşı son savunma).
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return null;
  }

  Future<void> _writeBothStores(String key, String hash) async {
    try {
      await _secure.write(key: key, value: hash);
    } catch (_) {}
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(key, hash);
    } catch (_) {}
  }
}
