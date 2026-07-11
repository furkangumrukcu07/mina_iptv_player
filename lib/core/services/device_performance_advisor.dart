import 'package:get/get.dart';

import 'app_settings_service.dart';

/// Eski otomatik «Düşük Donanımlı Cihaz Modu» önerisi.
///
/// Kullanıcı kurulumda (ve Ayarlar › Diğer araçlar) modu kendisi seçebildiği
/// için jank izleme / ana ekran popup'ı **devre dışı**. Servis kayıtlı kalır
/// (eski bağlar kırılmasın); [shouldSuggestLowEndMode] asla true olmaz.
class DevicePerformanceAdvisor extends GetxService {
  // Kurulum/ayarlar seçimi yeterli; parametre API uyumu için tutuluyor.
  DevicePerformanceAdvisor(AppSettingsService settings);

  /// Ana ekranın dinlediği bayrak; otomatik öneri kapalı olduğu için hep false.
  final shouldSuggestLowEndMode = false.obs;
}
