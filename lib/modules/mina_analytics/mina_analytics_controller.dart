import 'package:get/get.dart';

import '../../core/services/app_settings_service.dart';
import '../../core/services/mina_analytics_service.dart';
import '../../services/user_history_service.dart';

/// **Mina Wrapped controller'ı.**
///
/// Sayfa kendi başına stateless; controller `selectedRange` ve snapshot
/// tutarak Obx ile UI'a anlık güncellenmiş veri sunar.
///
/// Service değiştiğinde (player tick → flush) `version` Rx artar ve
/// otomatik recompute tetiklenir.
class MinaAnalyticsController extends GetxController {
  MinaAnalyticsController({
    MinaAnalyticsService? service,
    UserHistoryService? history,
  })  : _service = service ?? Get.find<MinaAnalyticsService>(),
        _history = history ??
            (Get.isRegistered<UserHistoryService>()
                ? Get.find<UserHistoryService>()
                : null);

  final MinaAnalyticsService _service;
  final UserHistoryService? _history;

  AppSettingsService get _settings => Get.find<AppSettingsService>();

  final selectedRange = MinaAnalyticsRange.month.obs;
  final snapshot = MinaAnalyticsSnapshot.empty.obs;

  /// Kronolojik izleme şeridi — en yeni en üstte. Timeline kartı bunu çizer.
  final timeline = <UserHistoryEntry>[].obs;

  /// Timeline kartında gösterilecek azami öğe.
  static const int kTimelineLimit = 14;

  /// UI bunu okuyarak gizlilik toggle'ı çizer. Master switch ile aynı
  /// kaynağa (`AppSettingsService.minaWrappedEnabled`) bağlıdır — Ana
  /// Ekran Ayarları, kurulum sihirbazı ve sayfa içi privacy kartı tek
  /// noktadan tetiklenir.
  RxBool get collectionEnabled => _settings.minaWrappedEnabled;

  @override
  void onInit() {
    super.onInit();
    _recompute();
    _reloadTimeline();
    // Servis her flush'ta version'u artırır → otomatik recompute.
    ever<int>(_service.version, (_) => _recompute());
    // Yeni izleme kaydı geldikçe timeline tazelensin.
    final h = _history;
    if (h != null) {
      ever<int>(h.revision, (_) => _reloadTimeline());
    }
  }

  Future<void> _reloadTimeline() async {
    final h = _history;
    if (h == null) {
      timeline.value = const [];
      return;
    }
    final all = await h.getAll();
    timeline.value = all.take(kTimelineLimit).toList(growable: false);
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
    await _reloadTimeline();
  }

  void _recompute() {
    snapshot.value = _service.snapshot(selectedRange.value);
  }
}
