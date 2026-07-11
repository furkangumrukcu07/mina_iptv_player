import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/player/video_player_engine.dart';

/// OSD kanal satırı: çözünürlük (4K/FHD/…) ve Hz ayrı rozetler — tek metinde kaybolmayı önler.
List<Widget> osdStreamQualityBadgeWidgets({
  required String? resolutionTier,
  required String? hzLabel,
  required double fontSize,
  required double borderRadius,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
}) {
  final out = <Widget>[];
  void addPill(String text, {bool emphasizeHz = false}) {
    final fs = emphasizeHz ? fontSize * 0.95 : fontSize;
    out.add(
      Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: emphasizeHz ? 0.12 : 0.14),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: emphasizeHz ? 0.32 : 0.28),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: emphasizeHz ? 0.95 : 1),
            fontSize: fs,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1,
          ),
        ),
      ),
    );
  }

  if (resolutionTier != null && resolutionTier.isNotEmpty) {
    addPill(resolutionTier);
  }
  if (hzLabel != null && hzLabel.isNotEmpty) {
    if (out.isNotEmpty) {
      out.add(SizedBox(width: fontSize < 9.5 ? 4 : 6));
    }
    addPill(hzLabel, emphasizeHz: true);
  }
  return out;
}

/// OSD sol bilgi sütununda içerik bilgisinin altındaki rozet satırı:
/// içerik türü (CANLI / FİLM / DİZİ) + taşıma (HLS/TS) + oynatıcı (Better/MediaKit).
Widget osdContentTypeAndEngineRow({
  required bool live,
  required bool isSeries,
  required VideoPlayerEngine engine,
  String? transportFormat,
  bool portrait = false,
}) {
  // TV'de uzaktan okunabilirlik için yatayda biraz daha büyük punto; ancak
  // dar yatay OSD'de (compact/micro) taşmayacak kadar ölçülü.
  final fontSize = portrait ? 8.5 : 9.5;
  final radius = portrait ? 4.0 : 5.0;
  final hPad = portrait ? 5.0 : 6.0;
  final vPad = portrait ? 2.5 : 3.0;
  final pad = EdgeInsets.symmetric(horizontal: hPad, vertical: vPad);

  // İçerik türü etiketi: yüksek kontrast dolu renk (canlı kırmızı, film mavi,
  // dizi mor). Koyu/şeffaf renkler TV'de karanlık OSD üzerinde kayboluyordu.
  final String typeLabel;
  final Color typeColor;
  if (live) {
    typeLabel = 'player.liveBadge'.tr;
    typeColor = const Color(0xFFE74C3C);
  } else if (isSeries) {
    typeLabel = 'player.seriesBadge'.tr;
    typeColor = const Color(0xFF8E44AD);
  } else {
    typeLabel = 'player.movieBadge'.tr;
    typeColor = const Color(0xFF2980B9);
  }

  Widget typeChip = Container(
    padding: pad,
    decoration: BoxDecoration(
      color: typeColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
    ),
    child: Text(
      typeLabel,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        height: 1,
      ),
    ),
  );

  final gap = SizedBox(width: portrait ? 4 : 6);
  final children = <Widget>[typeChip];

  final transport = transportFormat?.trim();
  if (transport != null && transport.isNotEmpty) {
    children.add(gap);
    children.add(
      osdTransportBadge(
        transportFormat: transport,
        fontSize: fontSize,
        radius: radius,
        hPad: hPad,
        vPad: vPad,
        portrait: portrait,
      ),
    );
  }

  children.add(gap);
  children.add(
    osdEngineBadge(
      engine: engine,
      fontSize: fontSize,
      radius: radius,
      hPad: hPad,
      vPad: vPad,
      portrait: portrait,
    ),
  );

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: children,
  );
}

/// HLS / MPEG-TS taşıma biçimi rozeti — [osdEngineBadge] ile aynı dil.
Widget osdTransportBadge({
  required String transportFormat,
  required double fontSize,
  required double radius,
  required double hPad,
  required double vPad,
  bool portrait = false,
}) {
  final ts = transportFormat.toUpperCase() == 'TS';
  final color = ts
      ? const Color(0xFF9B59B6)
      : const Color(0xFFE67E22);
  final label = ts ? 'TS' : 'HLS';
  final icon = ts ? Icons.view_stream_rounded : Icons.stream_rounded;

  return Container(
    padding: EdgeInsets.fromLTRB(hPad - 2, vPad, hPad, vPad),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: fontSize + 3, color: Colors.white),
        SizedBox(width: portrait ? 2 : 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1,
          ),
        ),
      ],
    ),
  );
}

Widget osdEngineBadge({
  required VideoPlayerEngine engine,
  required double fontSize,
  required double radius,
  required double hPad,
  required double vPad,
  bool portrait = false,
}) {
  final mk = engine.isMediaKit;
  final engineColor = mk
      ? const Color(0xFF16A085)
      : const Color(0xFF2E86DE);
  final engineLabel = mk ? 'MediaKit' : 'Better';
  final engineIcon =
      mk ? Icons.memory_rounded : Icons.bolt_rounded;

  return Container(
    padding: EdgeInsets.fromLTRB(hPad - 2, vPad, hPad, vPad),
    decoration: BoxDecoration(
      color: engineColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(engineIcon, size: fontSize + 3, color: Colors.white),
        SizedBox(width: portrait ? 2 : 4),
        Text(
          engineLabel,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            height: 1,
          ),
        ),
      ],
    ),
  );
}
