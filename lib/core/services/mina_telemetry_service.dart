import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../layout/app_layout_mode.dart';
import '../player/playback_engine_kind.dart';
import 'app_settings_service.dart';
import 'auth_service.dart';
import 'firebase_bootstrap.dart';
import 'device_memory_service.dart';

/// **Firebase Analytics** tabanlı ürün telemetrisi.
///
/// Amaç: kullanıcıların uygulamayı nasıl yapılandırdığını **toplu** (anonim,
/// segment bazlı) görebilmek — örn. "kullanıcıların %X'i Amoled tema kullanıyor",
/// "en çok hangi video motoru açık". Bunun için Firebase Analytics
/// **user properties** (segmentasyon) + bir `settings_snapshot` olayı yazılır.
///
/// Yerel [MinaAnalyticsService] (Mina Wrapped) ile karıştırma: o tamamen
/// cihazda kalan izleme süresi istatistiğidir; bu servis ise geliştirici
/// konsolunda toplu ayar dağılımını gösterir.
///
/// Firebase yapılandırılmamışsa (`gFirebaseReady == false`) tüm çağrılar
/// sessizce no-op olur.
class MinaTelemetryService extends GetxService {
  MinaTelemetryService({FirebaseAnalytics? analytics})
      : _analyticsOverride = analytics;

  final FirebaseAnalytics? _analyticsOverride;
  FirebaseAnalytics? _analytics;
  String? _deviceModel;

  bool get _enabled => gFirebaseReady && _analytics != null;

  Future<MinaTelemetryService> init() async {
    if (!gFirebaseReady) return this;
    try {
      // ANR Düzeltme: Uygulama açılışında Firebase Analytics başlatılırken
      // Google Play Services üzerinden Binder IPC kuyruğu doluyor ve ana
      // thread kilitleniyordu (ANR). Bu işlemi UI yüklendikten sonraya alıyoruz.
      // Düşük RAM'li (1-2GB) cihazlarda bu süre çok daha uzundur (15 saniye).
      final delayMs = Get.isRegistered<DeviceMemoryService>() 
          ? Get.find<DeviceMemoryService>().recommendedStartupDelayMs 
          : 3500;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      
      _analytics = _analyticsOverride ?? FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(true);
      await _loadDeviceModel();
    } catch (e) {
      debugPrint('mina_iptv: Telemetry init hata: $e');
      _analytics = null;
    }
    return this;
  }

  Future<void> _loadDeviceModel() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceModel = '${androidInfo.brand} ${androidInfo.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceModel = '${iosInfo.model} ${iosInfo.systemVersion}';
      }
    } catch (e) {
      debugPrint('mina_iptv: Device model alınamadı: $e');
    }
  }

  /// Mevcut ayarların anlık görüntüsünü user properties olarak yazar ve bir
  /// `settings_snapshot` olayı kaydeder. Açılışta (home'a geçince) çağrılır.
  Future<void> logSettingsSnapshot(AppSettingsService s) async {
    if (!_enabled) return;
    final props = _collect(s);
    try {
      // Segmentasyon için user properties (Firebase Console → Audiences).
      for (final entry in props.entries) {
        await _analytics!.setUserProperty(
          name: entry.key,
          value: _capValue(entry.value),
        );
      }
      // Tek olayda da gönder (Realtime / DebugView'da hızlı görünürlük).
      await _analytics!.logEvent(
        name: 'settings_snapshot',
        parameters: <String, Object>{
          for (final e in props.entries) e.key: _capValue(e.value),
        },
      );
    } catch (e) {
      debugPrint('mina_iptv: Telemetry snapshot hata: $e');
    }
  }

  /// Bulut yedekleme sonucu (başarı/başarısızlık + boyut). Çağrı no-op
  /// güvenlidir; Firebase yoksa sessizce atlanır.
  Future<void> logCloudBackup({
    required bool success,
    int? sizeBytes,
    String? reason,
  }) async {
    if (!_enabled) return;
    try {
      await _analytics!.logEvent(
        name: 'cloud_backup',
        parameters: <String, Object>{
          'success': success ? 'true' : 'false',
          if (sizeBytes != null) 'size_kb': (sizeBytes / 1024).round(),
          if (reason != null) 'reason': _capValue(reason),
        },
      );
    } catch (_) {}
  }

  /// Bulut geri yükleme sonucu.
  Future<void> logCloudRestore({
    required bool success,
    String? reason,
  }) async {
    if (!_enabled) return;
    try {
      await _analytics!.logEvent(
        name: 'cloud_restore',
        parameters: <String, Object>{
          'success': success ? 'true' : 'false',
          if (reason != null) 'reason': _capValue(reason),
        },
      );
    } catch (_) {}
  }

  /// Kullanıcı bulut verisini sildi (GDPR).
  Future<void> logCloudDelete({required bool success}) async {
    if (!_enabled) return;
    try {
      await _analytics!.logEvent(
        name: 'cloud_delete',
        parameters: <String, Object>{
          'success': success ? 'true' : 'false',
        },
      );
    } catch (_) {}
  }

  /// Tek bir ayar değişimini olay olarak kaydeder (örn. kullanıcı temayı
  /// değiştirdi). Opsiyonel; çağrı no-op güvenlidir.
  Future<void> logSettingChange(String setting, Object value) async {
    if (!_enabled) return;
    try {
      await _analytics!.logEvent(
        name: 'setting_change',
        parameters: <String, Object>{
          'setting': _capValue(setting),
          'value': _capValue(value),
        },
      );
    } catch (_) {}
  }

  /// Satın alma olayını kaydeder (başarılı/başarısız).
  Future<void> logPurchase({
    required String productId,
    required bool success,
    String? price,
    String? currency,
    String? errorMessage,
  }) async {
    if (!_enabled) return;
    try {
      final params = <String, Object>{
        'product_id': _capValue(productId),
        'success': success ? 'true' : 'false',
        if (price != null) 'price': _capValue(price),
        if (currency != null) 'currency': _capValue(currency),
        if (errorMessage != null) 'error': _capValue(errorMessage),
      };

      // Google giriş durumu
      final auth = Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null;
      final isLoggedIn = auth?.currentUser.value != null;
      params['google_signed_in'] = isLoggedIn ? 'true' : 'false';

      await _analytics!.logEvent(
        name: 'purchase_attempt',
        parameters: params,
      );
    } catch (e) {
      debugPrint('mina_iptv: Purchase log hata: $e');
    }
  }

  Map<String, Object> _collect(AppSettingsService s) {
    final props = <String, Object>{
      'theme': _slug(s.themeLabel.value),
      'layout_mode': _layoutName(s.layoutMode.value),
      'app_language': s.languageCode.value,
      'video_engine_vod': _videoEngineTelemetry(s.vodPlaybackEngine.value),
      'video_engine_live': _videoEngineTelemetry(s.livePlaybackEngine.value),
      'hide_adult': s.effectiveHideAdultContent,
      'reduce_blur': s.reduceBlur.value,
      'external_player': s.externalPlayerEnabled.value,
      'stream_preview': s.streamPreviewEnabled.value,
      'auto_refresh_hours': s.autoRefreshHours.value,
      'cloud_backup_days': s.cloudAutoBackupDays.value,
    };
    if (_deviceModel != null) {
      props['device_model'] = _capValue(_deviceModel!);
    }
    return props;
  }

  static String _layoutName(AppLayoutMode m) => switch (m) {
        AppLayoutMode.mobile => 'mobile',
        AppLayoutMode.tablet => 'tablet',
        AppLayoutMode.tv => 'tv',
      };

  /// "Glass Gri" → "glass_gri" (Analytics değer kısıtlarına uygun slug).
  static String _slug(String v) {
    final s = v.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return s.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// User property değeri ≤ 36 karakter olmalı; event paramları için de güvenli.
  static String _capValue(Object v) {
    final s = v is bool ? (v ? 'true' : 'false') : v.toString();
    return s.length <= 36 ? s : s.substring(0, 36);
  }

  static String _videoEngineTelemetry(PlaybackEngineKind kind) {
    return switch (kind) {
      PlaybackEngineKind.better => 'exo',
      PlaybackEngineKind.mediaKit => 'media_kit',
    };
  }
}
