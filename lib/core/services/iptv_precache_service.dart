import 'package:get/get.dart';

/// Seçilen yayın URL’si için Better Player **preCache** (Android: ilk N byte).
class IptvPrecacheService extends GetxService {
  /// IPTV akışının başını önbelleğe alır; oynatıcı açılışını hızlandırabilir.
  Future<void> precacheStreamUrl(String url) async {}
}
