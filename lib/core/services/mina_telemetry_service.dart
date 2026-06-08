import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../layout/app_layout_mode.dart';
import 'app_settings_service.dart';
import 'firebase_bootstrap.dart';

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

  bool get _enabled => gFirebaseReady && _analytics != null;

  Future<MinaTelemetryService> init() async {
    if (!gFirebaseReady) return this;
    try {
      _analytics = _analyticsOverride ?? FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(true);
    } catch (e) {
      debugPrint('mina_iptv: Telemetry init hata: $e');
      _analytics = null;
    }
    return this;
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

  Map<String, Object> _collect(AppSettingsService s) {
    return <String, Object>{
      'theme': _slug(s.themeLabel.value),
      'layout_mode': _layoutName(s.layoutMode.value),
      'app_language': s.languageCode.value,
      'video_engine_vod': s.useMediaKit.value ? 'media_kit' : 'exo',
      'video_engine_live': s.liveUseMediaKit.value ? 'media_kit' : 'exo',
      'hide_adult': s.hideAdultContentEnabled.value,
      'reduce_blur': s.reduceBlur.value,
      'external_player': s.externalPlayerEnabled.value,
      'stream_preview': s.streamPreviewEnabled.value,
      'auto_refresh_days': s.autoRefreshDays.value,
      'cloud_backup_days': s.cloudAutoBackupDays.value,
    };
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
}
