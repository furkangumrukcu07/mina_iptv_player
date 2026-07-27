import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_lifecycle_poll_gate.dart';

/// **Veri Kullanım Detayı servisi.**
///
/// Android `TrafficStats.getUidRxBytes(myUid)` / `getUidTxBytes(myUid)`
/// üzerinden uygulamanın **bu cihazda kalkış sonrası** biriken
/// alınan/gönderilen byte sayısını periyodik (varsayılan 10 sn) olarak
/// okur. `connectivity_plus` ile algılanan mevcut bağlantı tipine göre
/// delta'yı **wifi** veya **mobil** kovalarına ekler ve
/// `SharedPreferences`'e işler.
///
/// **Cihaz yeniden başlatılırsa** TrafficStats sayaçları sıfırdan
/// başlar → bu durumda delta negatif gelir; biz baseline'ı yeni okumaya
/// eşitleyip kaybı atlarız (kayıt cihaz yeniden başlamadan önce
/// kalmıştı).
///
/// Konstantlar (SharedPreferences):
///
/// - `mina_data_usage_wifi_rx`: int (bytes, lifetime)
/// - `mina_data_usage_wifi_tx`: int (bytes, lifetime)
/// - `mina_data_usage_mobile_rx`: int (bytes, lifetime)
/// - `mina_data_usage_mobile_tx`: int (bytes, lifetime)
/// - `mina_data_usage_started_at`: int (ms since epoch — ilk okuma anı)
class DataUsageService extends GetxService {
  static const _channel = MethodChannel('mina.device/data_usage');

  static const _kWifiRx = 'mina_data_usage_wifi_rx';
  static const _kWifiTx = 'mina_data_usage_wifi_tx';
  static const _kMobileRx = 'mina_data_usage_mobile_rx';
  static const _kMobileTx = 'mina_data_usage_mobile_tx';
  static const _kStartedAt = 'mina_data_usage_started_at';

  /// Poll periyodu — 10 sn. Önemli: TrafficStats çok ucuz (sabit
  /// kernel sayacı okuması), batarya etkisi sıfıra yakın.
  static const Duration _pollInterval = Duration(seconds: 10);

  final wifiRxBytes = 0.obs;
  final wifiTxBytes = 0.obs;
  final mobileRxBytes = 0.obs;
  final mobileTxBytes = 0.obs;
  final lastConnectivity = Rxn<ConnectivityResult>();
  final startedAtMs = 0.obs;
  final isAvailable = false.obs;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  int _baselineRx = -1;
  int _baselineTx = -1;
  final Connectivity _connectivity = Connectivity();

  int get totalWifi => wifiRxBytes.value + wifiTxBytes.value;
  int get totalMobile => mobileRxBytes.value + mobileTxBytes.value;
  int get totalAll => totalWifi + totalMobile;

  Future<void> init() async {
    if (!Platform.isAndroid) {
      isAvailable.value = false;
      return;
    }
    await _loadFromPrefs();
    await _refreshConnectivity();
    _connSub = _connectivity.onConnectivityChanged.listen((results) {
      lastConnectivity.value = _pickPrimary(results);
    });
    // İlk okumada baseline kur — gerçek delta bir sonraki tick'te
    // hesaplanacak. Böylece cihaz açıldığında uygulamadan önce başka
    // uygulamaların kullandığı veri bizim hesabımıza yazılmıyor.
    final stats = await _readNativeStats();
    if (stats != null) {
      _baselineRx = stats.rxBytes;
      _baselineTx = stats.txBytes;
      isAvailable.value = true;
      if (startedAtMs.value == 0) {
        startedAtMs.value = DateTime.now().millisecondsSinceEpoch;
        await _saveStartedAt();
      }
    }
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_tick()));
  }

  @override
  void onClose() {
    _timer?.cancel();
    _connSub?.cancel();
    super.onClose();
  }

  Future<void> _refreshConnectivity() async {
    try {
      final list = await _connectivity.checkConnectivity();
      lastConnectivity.value = _pickPrimary(list);
    } catch (_) {}
  }

  ConnectivityResult? _pickPrimary(List<ConnectivityResult> list) {
    if (list.isEmpty) return null;
    // Wifi öncelikli, ardından mobile, vpn, ethernet vb.
    if (list.contains(ConnectivityResult.wifi)) {
      return ConnectivityResult.wifi;
    }
    if (list.contains(ConnectivityResult.mobile)) {
      return ConnectivityResult.mobile;
    }
    if (list.contains(ConnectivityResult.ethernet)) {
      return ConnectivityResult.ethernet;
    }
    return list.first;
  }

  Future<void> _tick() async {
    if (!AppLifecyclePollGate.shouldRunBackgroundPolls) return;
    if (!Platform.isAndroid) return;
    final stats = await _readNativeStats();
    if (stats == null) return;

    if (_baselineRx < 0 || _baselineTx < 0) {
      _baselineRx = stats.rxBytes;
      _baselineTx = stats.txBytes;
      return;
    }
    var deltaRx = stats.rxBytes - _baselineRx;
    var deltaTx = stats.txBytes - _baselineTx;
    // Cihaz yeniden başlatıldı ya da TrafficStats sayacı sıfırlandı:
    // negatif delta'yı yutup baseline'ı yenile.
    if (deltaRx < 0 || deltaTx < 0) {
      _baselineRx = stats.rxBytes;
      _baselineTx = stats.txBytes;
      return;
    }
    if (deltaRx == 0 && deltaTx == 0) return;
    _baselineRx = stats.rxBytes;
    _baselineTx = stats.txBytes;

    if (lastConnectivity.value == null) {
      return;
    }
    final conn = lastConnectivity.value;
    final isWifi = conn == ConnectivityResult.wifi ||
        conn == ConnectivityResult.ethernet;
    if (isWifi) {
      wifiRxBytes.value = wifiRxBytes.value + deltaRx;
      wifiTxBytes.value = wifiTxBytes.value + deltaTx;
    } else if (conn == ConnectivityResult.mobile) {
      mobileRxBytes.value = mobileRxBytes.value + deltaRx;
      mobileTxBytes.value = mobileTxBytes.value + deltaTx;
    } else {
      // VPN / bluetooth / yok: kategorize edilemediği için Wifi gibi
      // muamele etme; en güvenli: sayma. Kullanıcı mobile'da değilse
      // toplam wifi+mobile = gerçek değil ama mobil sayaç kirlenmez.
      // İstersen ileride "diğer" kategorisi eklenebilir.
    }
    await _saveTotals();
  }

  Future<_NativeStats?> _readNativeStats() async {
    try {
      final res = await _channel.invokeMapMethod<String, Object?>('getStats');
      if (res == null) return null;
      final rx = (res['rxBytes'] as num?)?.toInt() ?? 0;
      final tx = (res['txBytes'] as num?)?.toInt() ?? 0;
      return _NativeStats(rxBytes: rx, txBytes: tx);
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: data_usage native error: $e');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('mina_iptv: data_usage unknown error: $e');
      return null;
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      wifiRxBytes.value = p.getInt(_kWifiRx) ?? 0;
      wifiTxBytes.value = p.getInt(_kWifiTx) ?? 0;
      mobileRxBytes.value = p.getInt(_kMobileRx) ?? 0;
      mobileTxBytes.value = p.getInt(_kMobileTx) ?? 0;
      startedAtMs.value = p.getInt(_kStartedAt) ?? 0;
    } catch (_) {}
  }

  Future<void> _saveTotals() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kWifiRx, wifiRxBytes.value);
      await p.setInt(_kWifiTx, wifiTxBytes.value);
      await p.setInt(_kMobileRx, mobileRxBytes.value);
      await p.setInt(_kMobileTx, mobileTxBytes.value);
    } catch (_) {}
  }

  Future<void> _saveStartedAt() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_kStartedAt, startedAtMs.value);
    } catch (_) {}
  }

  /// Kullanıcı "Sıfırla"yı seçtiğinde tüm sayaçları silip baseline'ı
  /// güncel TrafficStats okumasıyla yeniden kuruyoruz.
  Future<void> resetAll() async {
    wifiRxBytes.value = 0;
    wifiTxBytes.value = 0;
    mobileRxBytes.value = 0;
    mobileTxBytes.value = 0;
    startedAtMs.value = DateTime.now().millisecondsSinceEpoch;
    await _saveTotals();
    await _saveStartedAt();
    final stats = await _readNativeStats();
    if (stats != null) {
      _baselineRx = stats.rxBytes;
      _baselineTx = stats.txBytes;
    }
  }
}

class _NativeStats {
  const _NativeStats({required this.rxBytes, required this.txBytes});
  final int rxBytes;
  final int txBytes;
}
