import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/glass_appearance.dart';
import 'tv_shell_perf.dart';

/// TV kabuğu yüzeyleri — [GlassAppearance] + [ColorScheme] ile tema uyumu.
final class TvShellPalette {
  const TvShellPalette({
    required this.ga,
    required this.cs,
  });

  final GlassAppearance ga;
  final ColorScheme cs;

  factory TvShellPalette.of(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return TvShellPalette(
      ga: GlassAppearance.fromLabel(settings.themeLabel.value),
      cs: Theme.of(context).colorScheme,
    );
  }

  Color get accent => cs.primary;

  bool get _onLightSurface =>
      ga.homeHeaderOnDecorationForeground.computeLuminance() > 0.45;

  Color get title => ga.homeHeaderOnDecorationForeground;

  Color get body => title.withValues(alpha: 0.88);

  Color get muted => title.withValues(alpha: _onLightSurface ? 0.68 : 0.58);

  Color get subtle => title.withValues(alpha: _onLightSurface ? 0.52 : 0.42);

  Color get clockAccent => accent;

  Color get nowLine => accent;

  Color get progress => accent;

  /// Sol menü / yan panel zemin + kenar.
  BoxDecoration sidePanelDecoration({bool trailingBorder = true}) {
    if (ga.isTrabzon) {
      return BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        border: trailingBorder
            ? Border(
                right: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
              )
            : null,
      );
    }
    if (TvShellPerf.lite) {
      return BoxDecoration(
        color: ga.filmDiziSectionGradientColors.first.withValues(alpha: 0.75),
        border: trailingBorder
            ? Border(right: BorderSide(color: ga.sheetBorder))
            : null,
      );
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ga.filmDiziSectionGradientColors
            .map((c) => c.withValues(alpha: 0.75))
            .toList(),
      ),
      border: trailingBorder
          ? Border(
              right: BorderSide(color: ga.sheetBorder),
            )
          : null,
    );
  }

  /// Sağ içerik alanı hafif karartma.
  BoxDecoration contentBackdropDecoration() {
    return BoxDecoration(
      color: cs.surface.withValues(alpha: 0.75),
    );
  }

  /// Menü veya kategori satırı.
  BoxDecoration navRowDecoration({
    required bool selected,
    double radius = 12,
  }) {
    if (selected) {
      if (ga.isTrabzon) {
        return BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.40), width: 1.5),
          color: Colors.white.withValues(alpha: 0.25),
        );
      }
      if (TvShellPerf.lite) {
        return BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: ga.listTileBorder(true),
            width: 1.4,
          ),
          color: cs.primary.withValues(alpha: 0.22),
        );
      }
      return BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: ga.listTileBorder(true),
          width: 1.4,
        ),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            cs.primary.withValues(alpha: 0.34),
            cs.primary.withValues(alpha: 0.14),
          ],
        ),
      );
    }
    if (ga.isTrabzon) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        color: Colors.white.withValues(alpha: 0.05),
      );
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: ga.categoryRowBorderIdle()),
      color: ga.categoryRowFillIdle(),
    );
  }

  Color navRowIconColor(bool selected) =>
      selected ? title : title.withValues(alpha: 0.78);

  Color navRowTextColor(bool selected) =>
      selected ? title : title.withValues(alpha: 0.9);

  /// Kanal listesi: odak = parlama (TvDpadFocus); seçili = ince sol çizgi.
  BoxDecoration channelRowDecoration({
    required bool selected,
    bool focused = false,
  }) {
    if (focused) {
      return const BoxDecoration(color: Colors.transparent);
    }
    if (selected) {
      if (ga.isTrabzon) {
        return BoxDecoration(
          border: Border(
            left: BorderSide(color: Colors.white.withValues(alpha: 0.60), width: 2),
          ),
        );
      }
      return BoxDecoration(
        border: Border(
          left: BorderSide(color: accent.withValues(alpha: 0.42), width: 2),
        ),
      );
    }
    return const BoxDecoration(color: Colors.transparent);
  }

  /// EPG program bloğu. [muted] «EPG henüz bulunmuyor» gibi boş satırlar
  /// için — arka plan saydam, yalnızca metin görünür.
  BoxDecoration epgBlockDecoration({
    required bool highlighted,
    bool muted = false,
  }) {
    if (muted) {
      return const BoxDecoration(color: Colors.transparent);
    }
    if (ga.isTrabzon) {
      return BoxDecoration(
        color: highlighted
            ? Colors.white.withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted
              ? Colors.white.withValues(alpha: 0.50)
              : Colors.white.withValues(alpha: 0.15),
        ),
      );
    }
    return BoxDecoration(
      color: highlighted
          ? ga.categoryRowFillSelected()
          : ga.categoryRowFillIdle(),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: highlighted
            ? ga.listTileBorder(true)
            : ga.categoryRowBorderIdle().withValues(alpha: 0.65),
      ),
    );
  }

  Color epgBlockTextColor({required bool highlighted}) =>
      highlighted ? title : body;

  /// Sinema detay katmanı — koyu scrim üzerinde ikincil aksiyon düğmeleri.
  BoxDecoration cinemaActionSecondaryDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: ga.isDarkFlatStyle
          ? const Color(0xE61E1E26)
          : const Color(0xD912121A),
      border: Border.all(
        color: Colors.white.withValues(alpha: ga.isDarkGlass ? 0.28 : 0.22),
      ),
    );
  }

  Color get cinemaActionSecondaryForeground =>
      Colors.white.withValues(alpha: 0.94);

  /// Sinema detay — meta etiketleri (yıl, süre vb.).
  BoxDecoration cinemaMetaChipDecoration({required bool filled}) {
    if (filled) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFEAB308),
      );
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: const Color(0xCC1A1A24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    );
  }

  /// Tam ekran film/dizi sıralama menüsü paneli.
  BoxDecoration sortMenuPanelDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: ga.isDarkFlatStyle
          ? const Color(0xF0181822)
          : const Color(0xEE12121A),
      border: Border.all(
        color: Colors.white.withValues(alpha: ga.isDarkGlass ? 0.26 : 0.22),
      ),
    );
  }

  Color get sortMenuTitleColor => Colors.white.withValues(alpha: 0.96);

  BoxDecoration sortMenuRowDecoration({
    required bool focused,
    required bool selected,
  }) {
    if (focused) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.11),
      );
    }
    if (selected) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      );
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    );
  }

  Color sortMenuRowForeground({required bool focused}) =>
      Colors.white.withValues(alpha: focused ? 0.98 : 0.88);

  TextStyle titleStyle({
    double size = 17,
    FontWeight weight = FontWeight.w800,
  }) =>
      TextStyle(color: title, fontSize: size, fontWeight: weight);

  TextStyle bodyStyle({
    double size = 14,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextStyle(color: body, fontSize: size, fontWeight: weight);

  TextStyle mutedStyle({
    double size = 12,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextStyle(color: muted, fontSize: size, fontWeight: weight);
}

/// Tema değişince alt ağacı yeniden boyar.
class TvShellThemed extends StatelessWidget {
  const TvShellThemed({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext context, TvShellPalette palette) builder;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    return Obx(() {
      settings.themeLabel.value;
      return builder(context, TvShellPalette.of(context));
    });
  }
}
