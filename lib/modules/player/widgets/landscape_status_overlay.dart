import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/services/app_settings_service.dart';

/// Yatay (tam ekran) video izlerken gösterilen gerçek **saat** — ekranın
/// **sol üstüne** yerleşir. Arka plan saydamdır (renk/çerçeve yok); parlak
/// sahnelerde okunabilirlik için yalnızca metin gölgesi vardır.
///
/// Tam ekran oynatımda sistem durum çubuğu (saat/batarya) gizlendiği için bu
/// bilgi kullanıcı isteğiyle yeniden sunulur. Dokunma olaylarını alttaki OSD'ye
/// geçirir ([IgnorePointer] çağıran tarafından sarılır).
class LandscapeClockOverlay extends StatefulWidget {
  const LandscapeClockOverlay({super.key});

  @override
  State<LandscapeClockOverlay> createState() => _LandscapeClockOverlayState();
}

class _LandscapeClockOverlayState extends State<LandscapeClockOverlay> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleClock();
  }

  /// Saat metnini dakika sınırına hizalar: önce bir sonraki dakikaya kadar
  /// bekler, ardından 60 sn periyotla günceller (her saniye rebuild olmaz,
  /// saat kayması da yaşanmaz).
  void _scheduleClock() {
    _clockTimer?.cancel();
    final now = DateTime.now();
    _now = now;
    final msToNextMinute = 60000 - (now.second * 1000 + now.millisecond);
    _clockTimer = Timer(Duration(milliseconds: msToNextMinute), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _clockTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String get _clockText {
    final use24 = Get.isRegistered<AppSettingsService>()
        ? Get.find<AppSettingsService>().epgTimeFormat24h.value
        : true;
    if (use24) {
      final h = _now.hour.toString().padLeft(2, '0');
      final m = _now.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return DateFormat.jm().format(_now);
  }

  @override
  Widget build(BuildContext context) {
    return _TransparentStatusChip(
      child: Text(
        _clockText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          fontFeatures: [FontFeature.tabularFigures()],
          shadows: _kStatusTextShadows,
        ),
      ),
    );
  }
}

/// Yatay (tam ekran) video izlerken gösterilen gerçek **batarya** yüzdesi —
/// ekranın **sağ üstüne** yerleşir. Arka plan saydamdır.
class LandscapeBatteryOverlay extends StatefulWidget {
  const LandscapeBatteryOverlay({super.key});

  @override
  State<LandscapeBatteryOverlay> createState() =>
      _LandscapeBatteryOverlayState();
}

class _LandscapeBatteryOverlayState extends State<LandscapeBatteryOverlay> {
  static final Battery _battery = Battery();

  Timer? _batteryTimer;
  StreamSubscription<BatteryState>? _stateSub;

  int? _level;
  BatteryState _state = BatteryState.unknown;

  @override
  void initState() {
    super.initState();
    _refreshBattery();
    _batteryTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshBattery(),
    );
    try {
      _stateSub = _battery.onBatteryStateChanged.listen((s) {
        if (!mounted) return;
        setState(() => _state = s);
        _refreshBattery();
      });
    } catch (_) {}
  }

  Future<void> _refreshBattery() async {
    try {
      final lvl = await _battery.batteryLevel;
      if (!mounted) return;
      setState(() => _level = lvl);
    } catch (_) {}
  }

  @override
  void dispose() {
    _batteryTimer?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  bool get _charging =>
      _state == BatteryState.charging || _state == BatteryState.full;

  @override
  Widget build(BuildContext context) {
    final level = _level;
    return _TransparentStatusChip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BatteryGlyph(level: level, charging: _charging),
          const SizedBox(width: 6),
          Text(
            level == null ? '--%' : '$level%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
              shadows: _kStatusTextShadows,
            ),
          ),
        ],
      ),
    );
  }
}

/// Parlak video sahnelerinde metin/çizimin okunabilmesi için yumuşak gölge.
const List<Shadow> _kStatusTextShadows = [
  Shadow(color: Color(0xCC000000), blurRadius: 6),
  Shadow(color: Color(0x66000000), blurRadius: 2),
];

/// Saydam arka planlı durum çubuğu sarmalayıcısı: arkada renk/çerçeve yoktur,
/// yalnızca içerik gösterilir. `Material` ata olmadan `Text`'ler "eksik
/// Material" sarı çizgisiyle çizilir; şeffaf Material ile sarmalıyoruz.
class _TransparentStatusChip extends StatelessWidget {
  const _TransparentStatusChip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: child,
    );
  }
}

/// Küçük yatay batarya çizimi: gövde + uç + doluluk oranı. Renk; şarjda yeşil,
/// düşükte kırmızı, normalde beyaz. Saydam zeminde okunması için gövde gölgeli.
class _BatteryGlyph extends StatelessWidget {
  const _BatteryGlyph({required this.level, required this.charging});

  final int? level;
  final bool charging;

  @override
  Widget build(BuildContext context) {
    final lvl = (level ?? 0).clamp(0, 100);
    final Color fillColor = charging
        ? const Color(0xFF38E078)
        : (lvl <= 15
            ? const Color(0xFFFF6470)
            : Colors.white.withValues(alpha: 0.95));
    const double bodyW = 24;
    const double bodyH = 12;
    return SizedBox(
      width: bodyW + 3,
      height: bodyH,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: bodyW,
            height: bodyH,
            padding: const EdgeInsets.all(1.6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3.5),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 4),
              ],
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: level == null ? 0 : (lvl / 100),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1.8),
                        color: fillColor,
                      ),
                    ),
                  ),
                ),
                if (charging)
                  const Center(
                    child: Icon(
                      Icons.bolt_rounded,
                      size: 10,
                      color: Colors.black,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 2.2,
            height: bodyH * 0.42,
            margin: const EdgeInsets.only(left: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
