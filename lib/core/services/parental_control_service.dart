import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

/// Ebeveyn PIN’i (SHA-256) güvenli depoda tutar; kategori gizleme ekranına giriş için doğrulanır.
class ParentalControlService extends GetxService {
  static const _kPin = 'mina_parental_pin_sha256_v1';
  static const _salt = 'mina_iptv_parental|v1';

  final _secure = const FlutterSecureStorage();
  final hasPin = false.obs;

  static String hashPin(String pin) =>
      sha256.convert(utf8.encode('$pin|$_salt')).toString();

  Future<void> refreshPinState() async {
    final v = await _secure.read(key: _kPin);
    hasPin.value = v != null && v.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await _secure.write(key: _kPin, value: hashPin(pin));
    hasPin.value = true;
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _secure.read(key: _kPin);
    if (stored == null || stored.isEmpty) return false;
    return stored == hashPin(pin);
  }

  Future<void> clearPin() async {
    await _secure.delete(key: _kPin);
    hasPin.value = false;
  }
}
