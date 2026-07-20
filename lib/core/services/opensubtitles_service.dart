import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';
import 'mina_secure_storage.dart';

/// OpenSubtitles.com API v1 — oturum (indirme sonraki aşamada).
class OpenSubtitlesService extends GetxService {
  static const _kToken = 'mina_opensubtitles_token_v1';
  static const _kUsername = 'mina_opensubtitles_username_v1';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.openSubtitlesBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Api-Key': ApiConstants.openSubtitlesApiKey,
        'User-Agent': ApiConstants.openSubtitlesUserAgent,
      },
    ),
  );

  final FlutterSecureStorage _secure = MinaSecureStorage.instance;

  final isLoggedIn = false.obs;
  final username = RxnString();
  final isBusy = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(_restoreSession());
  }

  bool get hasApiKey => ApiConstants.openSubtitlesApiKey.trim().isNotEmpty;

  Future<void> _restoreSession() async {
    try {
      final u = (await SharedPreferences.getInstance())
          .getString(_kUsername)
          ?.trim();
      final token = await _secure.read(key: _kToken);
      if (token != null && token.isNotEmpty && u != null && u.isNotEmpty) {
        username.value = u;
        isLoggedIn.value = true;
      }
    } catch (e) {
      debugPrint('OpenSubtitles restore: $e');
    }
  }

  Future<String?> login({
    required String user,
    required String password,
  }) async {
    if (!hasApiKey) {
      return 'settings.opensubtitles.errorNoApiKey'.tr;
    }
    final u = user.trim();
    final p = password.trim();
    if (u.isEmpty || p.isEmpty) {
      return 'settings.opensubtitles.errorCredentials'.tr;
    }

    isBusy.value = true;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/login',
        data: {'username': u, 'password': p},
      );
      final data = response.data;
      final token = data?['token']?.toString();
      if (token == null || token.isEmpty) {
        return 'settings.opensubtitles.errorLogin'.tr;
      }
      await _secure.write(key: _kToken, value: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUsername, u);
      username.value = u;
      isLoggedIn.value = true;
      return null;
    } on DioException catch (e) {
      final msg = e.response?.data;
      if (msg is Map && msg['message'] != null) {
        return msg['message'].toString();
      }
      return 'settings.opensubtitles.errorLogin'.tr;
    } catch (e) {
      debugPrint('OpenSubtitles login: $e');
      return 'settings.opensubtitles.errorLogin'.tr;
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> logout() async {
    if (isLoggedIn.value && hasApiKey) {
      try {
        final token = await _secure.read(key: _kToken);
        if (token != null && token.isNotEmpty) {
          await _dio.delete(
            '/logout',
            options: Options(
              headers: {'Authorization': 'Bearer $token'},
            ),
          );
        }
      } catch (_) {}
    }
    await _secure.delete(key: _kToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUsername);
    username.value = null;
    isLoggedIn.value = false;
  }

  Future<String?> readToken() => _secure.read(key: _kToken);
}
