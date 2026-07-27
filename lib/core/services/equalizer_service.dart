import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 10-bant grafik equalizer için hazır ayar tanımları.
///
/// `custom` tüm diğerlerinden ayrı tutulur — kullanıcı bir slider'a dokunur
/// dokunmaz mevcut preset `custom`'a düşer; ayrı bir preset değeri olarak
/// kaydedilir ki tekrar geri dönülebilsin.
enum EqualizerPreset {
  flat,
  bassBoost,
  trebleBoost,
  vocal,
  rock,
  pop,
  jazz,
  classical,
  electronic,
  acoustic,
  custom,
}

/// Mina IPTV ses equalizer servisi.
///
/// * **10 bant** ISO 1/1 oktav frekans tablosu (31 Hz … 16 kHz).
/// * Bant başına **−12 … +12 dB** kazanç, ekstra **preamp** kazancı.
/// * 10 hazır ayar + `custom`.
/// * Veri **SharedPreferences** ile kalıcı.
/// * **MediaKit (libmpv)** motoru üzerinde `af=lavfi=[…]` filtre zinciri
///   olarak uygulanır → Android / iOS / macOS / Windows / Linux ile uyumlu.
/// * **BetterPlayer / ExoPlayer** motoru için **Android native**
///   `android.media.audiofx.Equalizer` (session=0) köprüsü; cihaz
///   desteklemezse (Android 9+ bazı OEM'ler) sessizce devre dışı kalır.
///   iOS / desktop'ta BetterPlayer EQ desteği yok — orada yalnız MediaKit
///   uygulanır.
class EqualizerService extends GetxService {
  /// ISO 1/1 oktav bant frekansları (Hz).
  static const List<double> kBandFrequenciesHz = <double>[
    31.25,
    62.5,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];

  static const double kMinGainDb = -12.0;
  static const double kMaxGainDb = 12.0;

  static EqualizerService get to => Get.find<EqualizerService>();

  static const String _kPrefsEnabled = 'mina_eq_enabled_v1';
  static const String _kPrefsPreset = 'mina_eq_preset_v1';
  static const String _kPrefsBands = 'mina_eq_bands_v1';
  static const String _kPrefsPreamp = 'mina_eq_preamp_v1';

  /// Equalizer açık mı? Kapalıyken filtre zinciri tamamen kaldırılır.
  final RxBool enabled = false.obs;

  /// Aktif hazır ayar (custom dahil).
  final Rx<EqualizerPreset> preset = EqualizerPreset.flat.obs;

  /// Bant kazançları (dB). 10 eleman, sıra [kBandFrequenciesHz] ile aynı.
  final RxList<double> bandGainsDb = RxList<double>.filled(10, 0.0);

  /// Preamp kazancı (dB).
  final RxDouble preampDb = 0.0.obs;

  /// Her ayar değişikliğinde artırılır — `PlayerController` bu sayaca
  /// `ever()` ile abone olur ve filtre zincirini gerçek zamanlı uygular.
  final RxInt revision = 0.obs;

  /// BetterPlayer/ExoPlayer için **Android native** EQ köprüsü desteğinin
  /// olup olmadığı (cihaz + Android sürümü kontrolü). UI bu değere
  /// göre kullanıcıyı bilgilendirir.
  final RxBool nativeAndroidSupported = false.obs;

  /// Native EQ köprüsünden gelen `numberOfBands` (cihaza özel, genelde 5).
  int _nativeNumBands = 0;
  List<double> _nativeCenterHz = const <double>[];
  int _nativeMinMb = -1500;
  int _nativeMaxMb = 1500;

  static const MethodChannel _nativeChannel =
      MethodChannel('mina.player/equalizer');

  Worker? _nativeApplyWorker;

  bool _loaded = false;
  Future<void>? _loading;

  /// Hazır ayar tabloları (10 bant, dB). Yaygın stereo equalizer
  /// kurulumlarından alınmıştır.
  static const Map<EqualizerPreset, List<double>> presetBands =
      <EqualizerPreset, List<double>>{
    EqualizerPreset.flat: <double>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    EqualizerPreset.bassBoost: <double>[6, 5, 4, 2, 0, -1, -1, 0, 1, 2],
    EqualizerPreset.trebleBoost: <double>[-1, -1, 0, 0, 1, 2, 3, 4, 5, 6],
    EqualizerPreset.vocal: <double>[-2, -3, -3, 1, 3, 4, 3, 2, 0, -1],
    EqualizerPreset.rock: <double>[4, 3, 1, -2, -1, 1, 3, 5, 6, 6],
    EqualizerPreset.pop: <double>[-1, 1, 2, 4, 4, 3, 1, -1, -2, -2],
    EqualizerPreset.jazz: <double>[3, 2, 1, 2, -1, -1, 0, 1, 2, 3],
    EqualizerPreset.classical: <double>[4, 3, 2, 1, -1, -1, 0, 1, 2, 3],
    EqualizerPreset.electronic: <double>[4, 3, 1, 0, -2, 2, 1, 1, 3, 4],
    EqualizerPreset.acoustic: <double>[3, 3, 2, 1, 2, 1, 2, 2, 2, 1],
  };

  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final p = await SharedPreferences.getInstance();
      enabled.value = p.getBool(_kPrefsEnabled) ?? false;
      preset.value = _parsePreset(p.getString(_kPrefsPreset));
      final bandsRaw = p.getStringList(_kPrefsBands) ?? const <String>[];
      if (bandsRaw.length == 10) {
        final parsed = <double>[];
        for (final s in bandsRaw) {
          final v = double.tryParse(s) ?? 0.0;
          parsed.add(v.clamp(kMinGainDb, kMaxGainDb));
        }
        bandGainsDb.assignAll(parsed);
      } else {
        final defaults = presetBands[preset.value] ??
            presetBands[EqualizerPreset.flat]!;
        bandGainsDb.assignAll(defaults.map((e) => e.toDouble()));
      }
      preampDb.value =
          (p.getDouble(_kPrefsPreamp) ?? 0.0).clamp(kMinGainDb, kMaxGainDb);
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService: load failed: $e');
    } finally {
      _loaded = true;
      _loading = null;
    }
    unawaited(_probeNativeAndroidEq());
  }

  @override
  void onClose() {
    _nativeApplyWorker?.dispose();
    _nativeApplyWorker = null;
    if (Platform.isAndroid) {
      // Activity yaşayan FlutterEngine ile birlikte release olur, yine de
      // best-effort native serbest bırakma denemesi.
      unawaited(
        _nativeChannel.invokeMethod<bool>('release').catchError((_) => false),
      );
    }
    super.onClose();
  }

  /// Native (ExoPlayer/BetterPlayer için) EQ desteğini bir kez sorgula
  /// ve devam eden değişiklikleri uygulamak için worker'ı kur.
  Future<void> _probeNativeAndroidEq() async {
    if (!Platform.isAndroid) {
      nativeAndroidSupported.value = false;
      return;
    }
    try {
      final info = await _nativeChannel
          .invokeMethod<Map<dynamic, dynamic>>('info');
      final supported = info?['supported'] == true;
      nativeAndroidSupported.value = supported;
      if (!supported) return;
      _nativeNumBands = (info?['numberOfBands'] as int?) ?? 0;
      _nativeMinMb = (info?['minLevelMb'] as int?) ?? -1500;
      _nativeMaxMb = (info?['maxLevelMb'] as int?) ?? 1500;
      final raw = info?['centerFreqMillihertz'];
      if (raw is List) {
        _nativeCenterHz = raw
            .map((e) => ((e as num?)?.toDouble() ?? 0) / 1000.0)
            .toList(growable: false);
      } else {
        _nativeCenterHz = const <double>[];
      }
      // Önce mevcut ayarları uygula, sonra reaktif dinleyici kur.
      await _applyToAndroidNative();
      _nativeApplyWorker?.dispose();
      _nativeApplyWorker = ever<int>(revision, (_) {
        unawaited(_applyToAndroidNative());
      });
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService: native probe failed: $e');
      nativeAndroidSupported.value = false;
    }
  }

  /// Cihazın N bantlı native EQ'una, 10 logical bant değerlerimizi
  /// frekans-bazlı (log interpolasyon) eşleyerek uygular. Preamp
  /// kazancı her bantın değerine eklenir (Android Equalizer ayrı
  /// preamp sunmaz).
  Future<void> _applyToAndroidNative() async {
    if (!nativeAndroidSupported.value) return;
    if (_nativeNumBands <= 0) return;
    try {
      final levelsMb = <int>[];
      if (enabled.value) {
        final pre = preampDb.value;
        if (_nativeCenterHz.length == _nativeNumBands) {
          for (var i = 0; i < _nativeNumBands; i++) {
            final hz = _nativeCenterHz[i];
            final db = (_interpolatedGainAtHz(hz) + pre)
                .clamp(kMinGainDb, kMaxGainDb);
            final mb = (db * 100).round().clamp(_nativeMinMb, _nativeMaxMb);
            levelsMb.add(mb);
          }
        } else {
          // Frekans listesi alınamadıysa düzgün interpolasyon yapılamaz;
          // tüm bantları preamp ile aynı seviyeye getir.
          final mb = (pre * 100).round().clamp(_nativeMinMb, _nativeMaxMb);
          for (var i = 0; i < _nativeNumBands; i++) {
            levelsMb.add(mb);
          }
        }
      } else {
        for (var i = 0; i < _nativeNumBands; i++) {
          levelsMb.add(0);
        }
      }
      await _nativeChannel.invokeMethod<bool>('apply', <String, dynamic>{
        'enabled': enabled.value,
        'bandLevelsMb': levelsMb,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService: native apply failed: $e');
    }
  }

  /// Log-frekansta lineer interpolasyon — verilen [hz] için 10 logical
  /// bant arasında en yakın iki bandın kazancını harmanlar.
  double _interpolatedGainAtHz(double hz) {
    if (bandGainsDb.isEmpty) return 0.0;
    if (hz <= kBandFrequenciesHz.first) return bandGainsDb.first;
    if (hz >= kBandFrequenciesHz.last) return bandGainsDb.last;
    for (var i = 0; i < kBandFrequenciesHz.length - 1; i++) {
      final lo = kBandFrequenciesHz[i];
      final hi = kBandFrequenciesHz[i + 1];
      if (hz >= lo && hz <= hi) {
        // Log-uzayda interpolasyon (oktav merkezler eşit aralıklı).
        final t = (_log2(hz) - _log2(lo)) / (_log2(hi) - _log2(lo));
        return bandGainsDb[i] + (bandGainsDb[i + 1] - bandGainsDb[i]) * t;
      }
    }
    return 0.0;
  }

  static double _log2(double x) =>
      x <= 0 ? 0 : (math.log(x) / math.log(2.0));

  Future<void> setEnabled(bool v) async {
    if (enabled.value == v) return;
    enabled.value = v;
    revision.value++;
    await _persistFlag(_kPrefsEnabled, v);
  }

  /// Hazır ayar seçer. `custom` seçilirse mevcut bant değerleri olduğu gibi
  /// korunur; diğerleri seçilirse bantlar tabloya göre güncellenir.
  Future<void> applyPreset(EqualizerPreset p) async {
    preset.value = p;
    if (p != EqualizerPreset.custom) {
      final table = presetBands[p] ?? presetBands[EqualizerPreset.flat]!;
      bandGainsDb.assignAll(table.map((e) => e.toDouble()));
    }
    revision.value++;
    await _persistAll();
  }

  /// Tek bir bantın kazancını günceller. İlk dokunuşta preset otomatik
  /// `custom`'a düşer.
  Future<void> setBandGain(int index, double db) async {
    if (index < 0 || index >= bandGainsDb.length) return;
    final v = db.clamp(kMinGainDb, kMaxGainDb);
    if ((bandGainsDb[index] - v).abs() < 0.01) return;
    bandGainsDb[index] = v;
    if (preset.value != EqualizerPreset.custom) {
      preset.value = EqualizerPreset.custom;
    }
    revision.value++;
    await _persistAll();
  }

  Future<void> setPreampGain(double db) async {
    final v = db.clamp(kMinGainDb, kMaxGainDb);
    if ((preampDb.value - v).abs() < 0.01) return;
    preampDb.value = v;
    revision.value++;
    await _persistAll();
  }

  /// Tüm bantları 0 dB'e indirir, preset = `flat`, preamp = 0.
  Future<void> resetToFlat() async {
    bandGainsDb.assignAll(List<double>.filled(10, 0.0));
    preampDb.value = 0.0;
    preset.value = EqualizerPreset.flat;
    revision.value++;
    await _persistAll();
  }

  Future<void> _persistFlag(String key, bool v) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(key, v);
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService: persist flag failed: $e');
    }
  }

  Future<void> _persistAll() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kPrefsEnabled, enabled.value);
      await p.setString(_kPrefsPreset, preset.value.name);
      await p.setStringList(
        _kPrefsBands,
        bandGainsDb.map((e) => e.toStringAsFixed(2)).toList(growable: false),
      );
      await p.setDouble(_kPrefsPreamp, preampDb.value);
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService: persist failed: $e');
    }
  }

  /// MediaKit (libmpv) [Player] üzerine `af` filtre zincirini uygular.
  ///
  /// * EQ kapalı → zincir temizlenir (`af=""`).
  /// * EQ açık → preamp + sıfırdan farklı bantlar için tek bir
  ///   `lavfi=[volume=…,equalizer=f=…:g=…,…]` zinciri kurulur.
  /// * `t=o:w=1` her bandı 1 oktav bant genişliğine ayarlar (klasik
  ///   grafik EQ davranışı).
  Future<void> applyToMediaKit(Player? player) async {
    if (player == null) return;
    final plat = player.platform;
    if (plat is! NativePlayer) return;
    try {
      if (!enabled.value) {
        await plat.setProperty('af', '');
        return;
      }
      final chain = _buildFilterChain();
      await plat.setProperty('af', chain);
    } catch (e) {
      if (kDebugMode) debugPrint('EqualizerService: applyToMediaKit failed: $e');
    }
  }

  String _buildFilterChain() {
    final parts = <String>[];
    final pre = preampDb.value;
    if (pre.abs() > 0.05) {
      parts.add('volume=${pre.toStringAsFixed(2)}dB:precision=fixed');
    }
    for (var i = 0; i < kBandFrequenciesHz.length; i++) {
      final g = bandGainsDb[i];
      if (g.abs() < 0.05) continue;
      parts.add(
        'equalizer='
        'f=${kBandFrequenciesHz[i].toStringAsFixed(2)}'
        ':t=o:w=1'
        ':g=${g.toStringAsFixed(2)}',
      );
    }
    if (parts.isEmpty) return '';
    return 'lavfi=[${parts.join(',')}]';
  }

  static EqualizerPreset _parsePreset(String? name) {
    if (name == null) return EqualizerPreset.flat;
    for (final v in EqualizerPreset.values) {
      if (v.name == name) return v;
    }
    return EqualizerPreset.flat;
  }

  /// i18n anahtarı — `'…'.tr` ile çağrılacak.
  String labelKey(EqualizerPreset p) {
    return switch (p) {
      EqualizerPreset.flat => 'settings.equalizer.preset.flat',
      EqualizerPreset.bassBoost => 'settings.equalizer.preset.bassBoost',
      EqualizerPreset.trebleBoost => 'settings.equalizer.preset.trebleBoost',
      EqualizerPreset.vocal => 'settings.equalizer.preset.vocal',
      EqualizerPreset.rock => 'settings.equalizer.preset.rock',
      EqualizerPreset.pop => 'settings.equalizer.preset.pop',
      EqualizerPreset.jazz => 'settings.equalizer.preset.jazz',
      EqualizerPreset.classical => 'settings.equalizer.preset.classical',
      EqualizerPreset.electronic => 'settings.equalizer.preset.electronic',
      EqualizerPreset.acoustic => 'settings.equalizer.preset.acoustic',
      EqualizerPreset.custom => 'settings.equalizer.preset.custom',
    };
  }

  /// "31" / "1K" / "16K" gibi insan dostu bant etiketi.
  static String formatBandLabel(double hz) {
    if (hz >= 1000) {
      final k = hz / 1000;
      if (k == k.truncateToDouble()) return '${k.toInt()}K';
      return '${k.toStringAsFixed(1)}K';
    }
    if (hz == hz.truncateToDouble()) return '${hz.toInt()}';
    return hz.toStringAsFixed(0);
  }
}
