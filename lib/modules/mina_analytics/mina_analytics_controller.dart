import 'package:get/get.dart';

import '../../core/services/app_settings_service.dart';
import '../../core/services/mina_analytics_service.dart';

/// **Mina Wrapped controller'ı.**
///
/// Sayfa kendi başına stateless; controller `selectedRange` ve snapshot
/// tutarak Obx ile UI'a anlık güncellenmiş veri sunar.
///
/// Service değiştiğinde (player tick → flush) `version` Rx artar ve
/// otomatik recompute tetiklenir.
class MinaAnalyticsController extends GetxController {
  MinaAnalyticsController({MinaAnalyticsService? service})
      : _service = service ?? Get.find<MinaAnalyticsService>();

  final MinaAnalyticsService _service;

  AppSettingsService get _settings => Get.find<AppSettingsService>();

  final selectedRange = MinaAnalyticsRange.month.obs;
  final snapshot = MinaAnalyticsSnapshot.empty.obs;

  /// UI bunu okuyarak gizlilik toggle'ı çizer. Master switch ile aynı
  /// kaynağa (`AppSettingsService.minaWrappedEnabled`) bağlıdır — Ana
  /// Ekran Ayarları, kurulum sihirbazı ve sayfa içi privacy kartı tek
  /// noktadan tetiklenir.
  RxBool get collectionEnabled => _settings.minaWrappedEnabled;

  @override
  void onInit() {
    super.onInit();
    _recompute();
    // Servis her flush'ta version'u artırır → otomatik recompute.
    ever<int>(_service.version, (_) => _recompute());
  }

  void selectRange(MinaAnalyticsRange r) {
    if (r == selectedRange.value) return;
    selectedRange.value = r;
    _recompute();
  }

  Future<void> setCollectionEnabled(bool v) async {
    // Master switch'i çağırıyoruz; setter zaten servisi de hizalıyor.
    await _settings.setMinaWrappedEnabled(v);
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    _recompute();
  }

  void _recompute() {
    snapshot.value = _service.snapshot(selectedRange.value);
  }
}
