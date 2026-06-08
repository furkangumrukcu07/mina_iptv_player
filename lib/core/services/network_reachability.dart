import 'package:connectivity_plus/connectivity_plus.dart';

/// Hızlı “çevrimiçi olabilir” kontrolü (kesin değil; gerçek indirme denemesi son söz).
abstract final class NetworkReachability {
  static Future<bool> likelyOnline() async {
    try {
      final r = await Connectivity().checkConnectivity();
      return r.any((e) => e != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }
}
