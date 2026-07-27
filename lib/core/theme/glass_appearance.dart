import 'package:flutter/material.dart';

/// [AppSettingsService.themeLabel] ile eşleşen depolama anahtarları.
abstract final class GlassThemeLabels {
  /// Varsayılan cam görünümü (portre/yatay ayrı arka plan görselleri).
  static const varsayilan = 'Varsayılan';

  static const koyuCam = 'Koyu Cam';

  /// Saf siyah AMOLED cam; koyu cam ailesinden, siyah duvar kağıtları
  /// (`blackdikey` / `blackyatay`) ve neredeyse opak siyah paneller.
  static const amoledBlack = 'Amoled Black';

  /// Kömür yüzey, mor vurgu, düz kartlar; özel arka plan görseli.
  static const darkFlat = 'Dark Flat';

  /// Buzlu gri cam; gri tonlu arka plan görselleri.
  static const glassGri = 'Glass Gri';

  /// Dark Flat ile aynı düz kart stili; mor vurgu yok, siyah odak / oynat kontrolleri.
  static const flatBlack = 'Flat Black';

  /// Samsung One UI tarzı cam paneller; yatay/dikey özel arka plan görselleri.
  static const minaGlass = 'Mina Glass';

  /// Sony Xperia SEMC: koyu cam, yeşil vurgu, buzlu paneller.
  static const semcTheme = 'SEMC Theme';

  /// Meizu Flyme: sade buzlu cam, mavi–camgöbeği vurgu, yumuşak kartlar.
  static const flyUi = 'Fly UI';

  /// TV Lite: hiç blur yok, siyah yüzeyler, kırmızı vurgu; tek özel fotoğraf
  /// duvar kağıdı (dikey/yatay). Eski TV box / zayıf cihazlar için sade tema.
  static const tvLite = 'TV Lite';

  /// Tasarım C: Canlı zeminli, MacOS (Apple) tarzı buzlu cam tasarımı.
  /// İsim: Trabzon. Özellikleri: Yüksek blur, şeffaf kartlar, mesh gradient arka plan.
  static const trabzon = 'Trabzon';

  /// Kurulum sihirbazı ve ayarlarla aynı sıra. TV Lite (sade, blur'suz tema)
  /// ilk sırada — TV box / zayıf cihazlarda önce görünür.
  static const List<String> selectableThemeLabels = [
    tvLite,
    varsayilan,
    koyuCam,
    amoledBlack,
    minaGlass,
    flyUi,
    semcTheme,
    darkFlat,
    flatBlack,
    glassGri,
    trabzon,
  ];

  static bool isDarkFlatFamily(String? themeLabel) =>
      themeLabel == darkFlat || themeLabel == flatBlack;

  /// TV düzeninde seçilemez / gösterilmez temalar.
  static const Set<String> tvExcludedThemeLabels = {
    varsayilan,
    minaGlass,
    flyUi,
  };

  /// Mobil/tablet düzeninde seçilemez / gösterilmez temalar (TV'ye özel).
  static const Set<String> handheldExcludedThemeLabels = {
    tvLite,
  };

  static bool isThemeAllowedOnTv(String label) =>
      !tvExcludedThemeLabels.contains(label);

  static bool isThemeAllowedOnHandheld(String label) =>
      !handheldExcludedThemeLabels.contains(label);

  /// Ayarlar ve kurulum: TV'de [tvExcludedThemeLabels], mobil/tablet'te
  /// [handheldExcludedThemeLabels] hariç liste.
  static List<String> selectableThemesForLayout({required bool tv}) {
    if (tv) {
      return selectableThemeLabels
          .where((t) => isThemeAllowedOnTv(t))
          .toList(growable: false);
    }
    return selectableThemeLabels
        .where((t) => isThemeAllowedOnHandheld(t))
        .toList(growable: false);
  }
}

/// Tema etiketine göre pano renkleri ve opaklıkları.
final class GlassAppearance {
  const GlassAppearance._({
    required this.isDarkGlass,
    required this.isAmoledBlack,
    required this.isDarkFlat,
    required this.isFlatBlack,
    required this.isGlassGri,
    required this.isMinaGlass,
    required this.isSemc,
    required this.isFlyUi,
    required this.isTvLite,
    required this.isTrabzon,
  });

  static const _semcGreen = Color(0xFF00C989);
  static const _semcGreenDim = Color(0xFF00A877);
  static const _flyBlue = Color(0xFF219BF0);
  static const _flyCyan = Color(0xFF1BC9B8);

  /// iOS sistem mavisi vurgu.
  static const _ios27Blue = Color(0xFF0A84FF);

  /// iOS 27 "Liquid Glass": serin lacivert tonlu, dumanlı saydam cam panel
  /// renkleri. Üstte daha parlak (specular), altta daha koyu — gerçek
  /// [BackdropFilter] blur arkasında akışkan cam hissi verir.
  static const _ios27GlassHi = Color(0x66172A4A);
  static const _ios27GlassMid = Color(0x4A101F38);
  static const _ios27GlassLo = Color(0x380A1730);

  /// Camın kenarındaki ışık yakalama (specular) — ince parlak beyaz çerçeve.
  static const _ios27EdgeColor = Color(0x4DFFFFFF);

  /// TV Lite kırmızı vurgu.
  static const _tvLiteRed = Color(0xFFE3201C);

  /// AMOLED siyah cam panel renkleri — neredeyse opak saf siyah, ince beyaz kenar.
  static const _amoledPanelHi = Color(0xE6050507);
  static const _amoledPanelLo = Color(0xB3020203);
  static const _amoledAccent = Color(0xFF22D3EE);

  final bool isDarkGlass;
  final bool isAmoledBlack;
  final bool isDarkFlat;
  final bool isFlatBlack;
  final bool isGlassGri;
  final bool isMinaGlass;
  final bool isSemc;
  final bool isFlyUi;
  final bool isTvLite;
  final bool isTrabzon;

  bool get isGlassmorphism => false;
  bool get isIos27 => false;
  bool get isMacTema => false;

  /// Buzlu beyaz cam ailesi (Flyme / Glassmorphism / Mina Glass).
  bool get _isFrostedGlass => isGlassmorphism || isMinaGlass || isFlyUi;

  /// [darkFlat], [flatBlack] ve [tvLite] ortak düz yüzey / kart dili (blur yok).
  bool get isDarkFlatStyle => isDarkFlat || isFlatBlack || isTvLite;

  /// GPU’da [BackdropFilter] yerine çok katmanlı gradient + kenar + gölge (sahte buzlu cam).
  /// [Glassmorphism], [Mina Glass], [Glass Gri], [TV Lite] ve [iOS 27] için gerçek
  /// zamanlı arka plan örneklemesi (blur) tamamen kapatılır.
  bool get usesSyntheticGlassSurface =>
      _isFrostedGlass || isGlassGri || isTvLite;

  factory GlassAppearance.fromLabel(String themeLabel) {
    final amoled = themeLabel == GlassThemeLabels.amoledBlack;
    final trab = themeLabel == GlassThemeLabels.trabzon;
    return GlassAppearance._(
      // AMOLED, koyu cam ailesini miras alır; ek olarak [isAmoledBlack]
      // override'ları ile saf siyah panellere dönüşür.
      isDarkGlass: themeLabel == GlassThemeLabels.koyuCam ||
          amoled,
      isAmoledBlack: amoled,
      isDarkFlat: themeLabel == GlassThemeLabels.darkFlat,
      isFlatBlack: themeLabel == GlassThemeLabels.flatBlack,
      isGlassGri: themeLabel == GlassThemeLabels.glassGri,
      isMinaGlass: themeLabel == GlassThemeLabels.minaGlass,
      isSemc: themeLabel == GlassThemeLabels.semcTheme,
      isFlyUi: themeLabel == GlassThemeLabels.flyUi,
      isTvLite: themeLabel == GlassThemeLabels.tvLite,
      isTrabzon: trab,
    );
  }

  /// TV hızlı kanal şeridi: [koyu cam] stili.
  factory GlassAppearance.forQuickMenuStrip() {
    return const GlassAppearance._(
      isDarkGlass: true,
      isAmoledBlack: false,
      isDarkFlat: false,
      isFlatBlack: false,
      isGlassGri: false,
      isMinaGlass: false,
      isSemc: false,
      isFlyUi: false,
      isTvLite: false,
      isTrabzon: false,
    );
  }

  /// Ana sayfa kategori kartı köşe yarıçapı.
  double get categoryCardBorderRadius {
    if (isTrabzon) return 24;
    if (isIos27) return 28;
    if (isMacTema) return 20;
    if (isMinaGlass) return 26;
    if (isFlyUi) return 20;
    if (isSemc) return 18;
    return isDarkFlatStyle ? 18 : (isGlassGri ? 16 : 14);
  }

  /// Outline ikonlar + düz yüzey (backdrop blur yok).
  bool get useFlatHomeCategoryStyle => isDarkFlatStyle;

  Color get popupBorderColor {
    if (isTrabzon) {
      return Colors.white.withValues(alpha: 0.30);
    }
    if (isIos27) {
      return _ios27EdgeColor;
    }
    if (isMacTema) {
      return Colors.white.withValues(alpha: 0.18);
    }
    if (isAmoledBlack) {
      return Colors.white.withValues(alpha: 0.12);
    }
    if (isSemc) {
      return _semcGreen.withValues(alpha: 0.26);
    }
    if (isFlyUi) {
      return _flyBlue.withValues(alpha: 0.38);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.46);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.44);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF353543);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.13 : 0.22);
  }

  List<Color> get popupGradientColors {
    if (isTrabzon) {
      return [
        Colors.white.withValues(alpha: 0.15),
        Colors.white.withValues(alpha: 0.05),
      ];
    }
    if (isIos27) {
      return const [_ios27GlassHi, _ios27GlassMid, _ios27GlassLo];
    }
    if (isMacTema) {
      return [
        const Color(0xFF1E1E2E).withValues(alpha: 0.80),
        const Color(0xFF181824).withValues(alpha: 0.70),
        const Color(0xFF101018).withValues(alpha: 0.60),
      ];
    }
    if (isAmoledBlack) {
      return const [_amoledPanelHi, _amoledPanelLo];
    }
    if (isSemc) {
      return [
        const Color(0xFF1A2822).withValues(alpha: 0.72),
        const Color(0xFF121A16).withValues(alpha: 0.58),
        const Color(0xFF0C100E).withValues(alpha: 0.46),
      ];
    }
    if (_isFrostedGlass) {
      return [
        Colors.white.withValues(alpha: 0.48),
        Colors.white.withValues(alpha: 0.24),
        Colors.white.withValues(alpha: 0.11),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFF8FAFC).withValues(alpha: 0.42),
        const Color(0xFFE2E8F0).withValues(alpha: 0.22),
        const Color(0xFF94A3B8).withValues(alpha: 0.11),
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF24242C), const Color(0xFF1A1A20)];
    }
    if (isDarkGlass) {
      return [const Color(0x701C1C24), const Color(0x48121218)];
    }
    return [
      Colors.white.withValues(alpha: 0.14),
      Colors.white.withValues(alpha: 0.05),
    ];
  }

  Color get popupShadowColor {
    if (isTrabzon) {
      return Colors.black.withValues(alpha: 0.25);
    }
    if (isIos27) {
      return const Color(0xFF030712).withValues(alpha: 0.55);
    }
    if (isMacTema) {
      return const Color(0xFF030712).withValues(alpha: 0.48);
    }
    if (isSemc) {
      return const Color(0xFF001A10).withValues(alpha: 0.42);
    }
    if (_isFrostedGlass) {
      return const Color(0xFF0F172A).withValues(alpha: 0.28);
    }
    if (isGlassGri) {
      return Colors.black.withValues(alpha: 0.26);
    }
    if (isDarkFlatStyle) {
      return Colors.black.withValues(alpha: 0.55);
    }
    return Colors.black.withValues(alpha: isDarkGlass ? 0.5 : 0.35);
  }

  BoxDecoration homeHeaderDecoration({double radius = 14}) {
    final effRadius = isIos27
        ? 24.0
        : isTrabzon 
            ? 24.0
            : isDarkFlatStyle
                ? 18.0
                : (isSemc ? 18.0 : (isGlassGri ? 16.0 : (isMacTema ? 20.0 : radius)));
    if (isTrabzon) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(effRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );
    }
    if (isMacTema) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(effRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF28283E).withValues(alpha: 0.75),
            const Color(0xFF1C1C2A).withValues(alpha: 0.65),
            const Color(0xFF12121D).withValues(alpha: 0.55),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );
    }
    if (isIos27) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(effRadius),
        border: Border.all(color: _ios27EdgeColor),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ios27GlassHi, _ios27GlassMid, _ios27GlassLo],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF030712).withValues(alpha: 0.42),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      );
    }
    if (isAmoledBlack) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(effRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_amoledPanelHi, _amoledPanelLo],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      );
    }
    if (isSemc) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(effRadius),
        border: Border.all(color: _semcGreen.withValues(alpha: 0.30)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0x661C2820),
            Color(0x4814181A),
            Color(0x380E1210),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003320).withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      );
    }
    if (_isFrostedGlass) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(effRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.50),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.10),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      );
    }
    if (isGlassGri) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(effRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.48),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF8FAFC).withValues(alpha: 0.36),
            const Color(0xFFE2E8F0).withValues(alpha: 0.18),
            const Color(0xFFCBD5E1).withValues(alpha: 0.10),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      );
    }
    if (isDarkFlatStyle) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(effRadius),
        color: const Color(0xFF1E1E24),
        border: Border.all(color: const Color(0xFF353543)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      );
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(effRadius),
      border: Border.all(
        color: isSemc
            ? _semcGreen.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: isDarkGlass ? 0.24 : 0.35),
      ),
      gradient: LinearGradient(
        colors: isSemc
            ? [const Color(0x5518201C), const Color(0x38101412)]
            : isDarkGlass
                ? [const Color(0x551E1E28), const Color(0x38141820)]
                : [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.08),
                  ],
      ),
    );
  }

  /// [homeHeaderDecoration] yüzeyi üzerinde başlık / ikon okunabilirliği için.
  ///
  /// Buzlu açık paneller ([_isFrostedGlass], [isGlassGri], varsayılan yarı saydam beyaz)
  /// koyu metin gerektirir; koyu paneller ([isDarkGlass], [isDarkFlatStyle], [isSemc]) açık metin.
  Color get homeHeaderOnDecorationForeground {
    if (isTrabzon) {
      return Colors.white; // Canlı zemin üzerinde okunabilmesi için
    }
    if (_isFrostedGlass || isGlassGri) {
      return const Color(0xFF0F172A);
    }
    if (isDarkFlatStyle || isSemc || isDarkGlass) {
      return Colors.white.withValues(alpha: 0.95);
    }
    return const Color(0xFF0F172A);
  }

  Color get sheetBorder {
    if (isTrabzon) {
      return Colors.white.withValues(alpha: 0.35);
    }
    if (isIos27) {
      return _ios27EdgeColor;
    }
    if (isMacTema) {
      return Colors.white.withValues(alpha: 0.16);
    }
    if (isAmoledBlack) {
      return Colors.white.withValues(alpha: 0.10);
    }
    if (isSemc) {
      return _semcGreen.withValues(alpha: 0.20);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.48);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.44);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF353543);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.1 : 0.15);
  }

  /// Film & Dizi yatay liste çerçeveleri (poster şeritleri).
  List<Color> get filmDiziSectionGradientColors {
    if (isTrabzon) {
      return [
        Colors.white.withValues(alpha: 0.15),
        Colors.transparent,
      ];
    }
    if (isIos27) {
      return [
        const Color(0xFF0E1B33).withValues(alpha: 0.62),
        const Color(0xFF0A1428).withValues(alpha: 0.46),
      ];
    }
    if (isMacTema) {
      return [
        const Color(0xFF1C1C2A).withValues(alpha: 0.72),
        const Color(0xFF12121E).withValues(alpha: 0.54),
      ];
    }
    if (isSemc) {
      return [
        const Color(0xA0222E26),
        const Color(0x88141816),
      ];
    }
    if (isAmoledBlack) {
      return const [Color(0xCC050507), Color(0xA6020203)];
    }
    if (_isFrostedGlass) {
      return [
        const Color(0xFF0F172A).withValues(alpha: 0.58),
        const Color(0xFF0B1220).withValues(alpha: 0.44),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFF1E293B).withValues(alpha: 0.65),
        const Color(0xFF0F172A).withValues(alpha: 0.50),
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF1C1C22), const Color(0xFF121218)];
    }
    if (isDarkGlass) {
      return [
        const Color(0x90181820),
        const Color(0x720E1016),
      ];
    }
    return [
      Colors.black.withValues(alpha: 0.42),
      Colors.black.withValues(alpha: 0.28),
    ];
  }

  List<Color> get sheetGradientColors {
    if (isTrabzon) {
      return [
        Colors.transparent,
        Colors.transparent,
      ];
    }
    if (_isFrostedGlass) {
      return [
        Colors.transparent,
        Colors.transparent,
      ];
    }
    if (isGlassGri) {
      return [
        Colors.transparent,
        Colors.transparent,
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF222228), const Color(0xFF18181E)];
    }
    if (isDarkGlass) {
      return [
        Colors.transparent,
        Colors.transparent,
      ];
    }
    return [
      Colors.transparent,
      Colors.transparent,
    ];
  }

  Color get topBarCapsuleBorder {
    if (isTrabzon) {
      return Colors.white.withValues(alpha: 0.25);
    }
    if (isIos27) {
      return _ios27EdgeColor;
    }
    if (isAmoledBlack) {
      return Colors.white.withValues(alpha: 0.14);
    }
    if (isSemc) {
      return _semcGreen.withValues(alpha: 0.28);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.52);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.50);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF3D3D4A);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.22 : 0.3);
  }

  List<Color> get topBarCapsuleGradientColors {
    if (isTrabzon) {
      return [
        Colors.white.withValues(alpha: 0.20),
        Colors.white.withValues(alpha: 0.05),
      ];
    }
    if (isIos27) {
      return const [_ios27GlassHi, _ios27GlassLo];
    }
    if (isAmoledBlack) {
      return const [Color(0xCC0A0A0C), Color(0x99050506)];
    }
    if (isSemc) {
      return [const Color(0x60202822), const Color(0x42141816)];
    }
    if (_isFrostedGlass) {
      return [
        Colors.white.withValues(alpha: 0.32),
        Colors.white.withValues(alpha: 0.12),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFF1F5F9).withValues(alpha: 0.28),
        const Color(0xFFCBD5E1).withValues(alpha: 0.10),
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF26262E), const Color(0xFF1C1C22)];
    }
    if (isSemc) {
      return [const Color(0x60222820), const Color(0x42141814)];
    }
    if (isDarkGlass) {
      return [const Color(0x6022222C), const Color(0x42181822)];
    }
    return [
      Colors.white.withValues(alpha: 0.16),
      Colors.white.withValues(alpha: 0.06),
    ];
  }

  Color get playerBarBorder {
    if (isTrabzon) {
      return Colors.white.withValues(alpha: 0.35);
    }
    if (isIos27) {
      return _ios27EdgeColor;
    }
    if (isAmoledBlack) {
      return Colors.white.withValues(alpha: 0.12);
    }
    if (isSemc) {
      return _semcGreen.withValues(alpha: 0.26);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.48);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.46);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF3A3A48);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.2 : 0.24);
  }

  List<Color> get playerBarGradientColors {
    if (isTrabzon) {
      return [
        Colors.white.withValues(alpha: 0.25),
        Colors.white.withValues(alpha: 0.08),
      ];
    }
    if (isIos27) {
      return const [Color(0xCC0E1B33), Color(0xA60A1428)];
    }
    if (isAmoledBlack) {
      return const [Color(0xD90A0A0C), Color(0xB3050506)];
    }
    if (isSemc) {
      return [const Color(0x681C2420), const Color(0x48101412)];
    }
    if (_isFrostedGlass) {
      return [
        Colors.white.withValues(alpha: 0.30),
        Colors.white.withValues(alpha: 0.11),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFE2E8F0).withValues(alpha: 0.32),
        const Color(0xFF94A3B8).withValues(alpha: 0.10),
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF25252E), const Color(0xFF18181E)];
    }
    if (isSemc) {
      return [const Color(0x6518201A), const Color(0x45101412)];
    }
    if (isDarkGlass) {
      return [const Color(0x65181822), const Color(0x45101218)];
    }
    return [
      const Color(0x5C1E222A),
      const Color(0x3E141A22),
    ];
  }

  Color get playerBarShadowColor {
    if (isSemc) {
      return const Color(0xFF002818).withValues(alpha: 0.38);
    }
    if (_isFrostedGlass) {
      return const Color(0xFF431407).withValues(alpha: 0.22);
    }
    if (isGlassGri) {
      return Colors.black.withValues(alpha: 0.22);
    }
    if (isDarkFlatStyle) {
      return Colors.black.withValues(alpha: 0.6);
    }
    return Colors.black.withValues(alpha: isDarkGlass ? 0.5 : 0.42);
  }

  List<Color> get playerCenterCardGradientColors {
    if (isIos27) {
      return const [_ios27GlassHi, _ios27GlassLo];
    }
    if (isAmoledBlack) {
      return const [Color(0xD90C0C0E), Color(0xB3060608)];
    }
    if (isSemc) {
      return [const Color(0x7020281E), const Color(0x48141812)];
    }
    if (_isFrostedGlass) {
      return [
        Colors.white.withValues(alpha: 0.38),
        Colors.white.withValues(alpha: 0.14),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFF1F5F9).withValues(alpha: 0.34),
        const Color(0xFFCBD5E1).withValues(alpha: 0.12),
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF2A2A32), const Color(0xFF1E1E26)];
    }
    if (isSemc) {
      return [const Color(0x701C241C), const Color(0x48101410)];
    }
    if (isDarkGlass) {
      return [const Color(0x701A1A24), const Color(0x4810141A)];
    }
    return [
      Colors.white.withValues(alpha: 0.2),
      Colors.white.withValues(alpha: 0.07),
    ];
  }

  Color get playerBarDimColor {
    if (isDarkFlatStyle) {
      return Colors.white.withValues(alpha: 0.06);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.09);
    }
    if (isSemc) {
      return _semcGreen.withValues(alpha: 0.06);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.08 : 0.10);
  }

  Color categoryRowBorderIdle() {
    if (isTrabzon) {
      return Colors.white.withValues(alpha: 0.15);
    }
    if (isIos27) {
      return Colors.white.withValues(alpha: 0.18);
    }
    if (isAmoledBlack) {
      return Colors.white.withValues(alpha: 0.10);
    }
    if (isSemc) {
      return _semcGreen.withValues(alpha: 0.18);
    }
    if (isFlyUi) {
      return _flyBlue.withValues(alpha: 0.22);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.38);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.36);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF353543);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.1 : 0.14);
  }

  Color categoryRowFillStrong() {
    if (isTrabzon) {
      return Colors.white.withValues(alpha: 0.25);
    }
    if (isIos27) {
      return _ios27Blue.withValues(alpha: 0.20);
    }
    if (isTvLite) {
      return _tvLiteRed.withValues(alpha: 0.30);
    }
    if (isSemc) {
      return _semcGreen.withValues(alpha: 0.14);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.22);
    }
    if (isGlassGri) {
      return const Color(0xFFCBD5E1).withValues(alpha: 0.20);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF2E2E38);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.1 : 0.14);
  }

  Color categoryRowFillFocused() {
    if (isTrabzon) {
      return Colors.white.withValues(alpha: 0.18);
    }
    if (isIos27) {
      return _ios27Blue.withValues(alpha: 0.14);
    }
    if (isTvLite) {
      return _tvLiteRed.withValues(alpha: 0.22);
    }
    if (isSemc) {
      return _semcGreen.withValues(alpha: 0.12);
    }
    if (isFlyUi) {
      return _flyCyan.withValues(alpha: 0.10);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.18);
    }
    if (isGlassGri) {
      return const Color(0xFFE2E8F0).withValues(alpha: 0.22);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF32323C);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.08 : 0.12);
  }

  Color categoryRowFillSelected() {
    if (isTrabzon) {
      return Colors.white.withValues(alpha: 0.22);
    }
    if (isIos27) {
      return _ios27Blue.withValues(alpha: 0.26);
    }
    if (isTvLite) {
      return _tvLiteRed.withValues(alpha: 0.34);
    }
    if (isAmoledBlack) {
      return _amoledAccent.withValues(alpha: 0.22);
    }
    if (isSemc) {
      return _semcGreen.withValues(alpha: 0.28);
    }
    if (isFlyUi) {
      return _flyBlue.withValues(alpha: 0.24);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.16);
    }
    if (isGlassGri) {
      return const Color(0xFF64748B).withValues(alpha: 0.32);
    }
    if (isFlatBlack) {
      return const Color(0xFF2E2E38);
    }
    if (isDarkFlat) {
      return const Color(0xFF21E6EB).withValues(alpha: 0.32);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.07 : 0.1);
  }

  Color categoryRowFillIdle() {
    if (isTrabzon) {
      return Colors.white.withValues(alpha: 0.08);
    }
    if (isIos27) {
      return const Color(0xFF0B1730).withValues(alpha: 0.34);
    }
    if (isAmoledBlack) {
      return const Color(0xFF050507).withValues(alpha: 0.72);
    }

    if (isSemc) {
      return const Color(0xFF101814).withValues(alpha: 0.72);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.10);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.08);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF1E1E26);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.04 : 0.03);
  }

  Color listTileBorder(bool softSelected) {
    if (isTrabzon) {
      return softSelected 
          ? Colors.white.withValues(alpha: 0.60)
          : Colors.white.withValues(alpha: 0.25);
    }
    if (isIos27) {
      return softSelected
          ? _ios27Blue.withValues(alpha: 0.60)
          : Colors.white.withValues(alpha: 0.46);
    }
    if (isTvLite) {
      return softSelected
          ? _tvLiteRed.withValues(alpha: 0.75)
          : const Color(0xFF2A2A2A);
    }

    if (isSemc) {
      return _semcGreen.withValues(alpha: softSelected ? 0.42 : 0.22);
    }
    if (isFlyUi) {
      return _flyBlue.withValues(alpha: softSelected ? 0.48 : 0.28);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: softSelected ? 0.58 : 0.46);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: softSelected ? 0.62 : 0.42);
    }
    if (isFlatBlack) {
      return softSelected ? const Color(0xFF2A2A30) : const Color(0xFF353543);
    }
    if (isDarkFlat) {
      return softSelected
          ? const Color(0xFF21E6EB).withValues(alpha: 0.75)
          : const Color(0xFF353543);
    }
    return Colors.white.withValues(
      alpha: isDarkGlass
          ? (softSelected ? 0.22 : 0.14)
          : (softSelected ? 0.3 : 0.2),
    );
  }

  /// Canlı TV kategori / kanal listesi (dikey el modu): koyu cam kutu — yoğun
  /// arka plan görsellerinde okunabilirlik için sabit sinematik yüzey.
  BoxDecoration handheldCinematicListRowDecoration({
    required bool highlighted,
    double radius = 16,
  }) {
    if (isAmoledBlack) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlighted
              ? Colors.white.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.10),
          width: highlighted ? 1.2 : 1.0,
        ),
        color: highlighted
            ? const Color(0xFF101012).withValues(alpha: 0.96)
            : const Color(0xFF050507).withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: highlighted ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
    }

    if (isFlyUi) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlighted
              ? _flyBlue.withValues(alpha: 0.52)
              : Colors.white.withValues(alpha: 0.10),
          width: highlighted ? 1.2 : 0.75,
        ),
        color: highlighted
            ? const Color(0xFF2E3038).withValues(alpha: 0.94)
            : const Color(0xFF26262C).withValues(alpha: 0.90),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: highlighted ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      );
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: highlighted
            ? Colors.white.withValues(alpha: 0.26)
            : Colors.white.withValues(alpha: 0.14),
        width: highlighted ? 1.2 : 1.0,
      ),
      color: highlighted
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.48),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.38),
          blurRadius: highlighted ? 14 : 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Liste başlıkları — dalgalı / parlak arka plan üzerinde kontrast.
  static const listTitleTextShadow = <Shadow>[
    Shadow(
      color: Color(0xCC000000),
      blurRadius: 6,
      offset: Offset(0, 1),
    ),
  ];

  double listTileBackgroundAlpha(bool strongHighlight, bool softSelected) {
    if (isSemc) {
      if (strongHighlight) return 0.16;
      if (softSelected) return 0.09;
      return 0.05;
    }
    if (isFlyUi) {
      if (strongHighlight) return 0.20;
      if (softSelected) return 0.12;
      return 0.08;
    }
    if (_isFrostedGlass) {
      if (strongHighlight) return 0.26;
      if (softSelected) return 0.14;
      return 0.09;
    }
    if (isGlassGri) {
      if (strongHighlight) return 0.24;
      if (softSelected) return 0.13;
      return 0.085;
    }
    if (isDarkFlatStyle) {
      if (strongHighlight) return 0.22;
      if (softSelected) return 0.14;
      return 0.08;
    }
    if (strongHighlight) return isDarkGlass ? 0.14 : 0.2;
    if (softSelected) return isDarkGlass ? 0.06 : 0.08;
    return isDarkGlass ? 0.035 : 0.05;
  }

  Color get thumbFallbackFill {
    if (isSemc) {
      return const Color(0xFF1A2820).withValues(alpha: 0.55);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.18);
    }
    if (isGlassGri) {
      return const Color(0xFF334155).withValues(alpha: 0.45);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF2A2A32);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.08 : 0.12);
  }

  Color get thumbFallbackBorder {
    if (isSemc) {
      return _semcGreen.withValues(alpha: 0.22);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.42);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.40);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF404050);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.14 : 0.2);
  }

  Color get detailPosterPlaceholder {
    if (isSemc) {
      return const Color(0xFF142018).withValues(alpha: 0.62);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.14);
    }
    if (isGlassGri) {
      return const Color(0xFF475569).withValues(alpha: 0.35);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF252530);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.06 : 0.08);
  }

  Color get settingsTileBorder {
    if (isIos27) {
      return _ios27EdgeColor;
    }

    if (isSemc) {
      return _semcGreen.withValues(alpha: 0.24);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.50);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.48);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF3F3F4E);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.18 : 0.26);
  }

  List<Color> settingsTileGradient(bool isColoredTint, Color themeColor) {
    if (isColoredTint) {
      if (isIos27) {
        return [
          _ios27Blue.withValues(alpha: 0.22),
          _ios27Blue.withValues(alpha: 0.06),
        ];
      }

      if (isSemc) {
        return [
          _semcGreen.withValues(alpha: 0.20),
          _semcGreenDim.withValues(alpha: 0.06),
        ];
      }
      if (_isFrostedGlass) {
        return [
          themeColor.withValues(alpha: 0.22),
          themeColor.withValues(alpha: 0.08),
        ];
      }
      if (isFlatBlack) {
        return [
          Colors.black.withValues(alpha: 0.50),
          Colors.black.withValues(alpha: 0.20),
        ];
      }
      if (isDarkFlat) {
        return [
          themeColor.withValues(alpha: 0.28),
          themeColor.withValues(alpha: 0.10),
        ];
      }
      // Renkli temalarda (Yeşil/Mavi/Kırmızı/Mor Cam) duvar kağıdının
      // görünebilmesi için alpha'yı bir miktar düşürüyoruz.
      return [
        themeColor.withValues(alpha: isDarkGlass ? 0.09 : 0.12),
        themeColor.withValues(alpha: isDarkGlass ? 0.03 : 0.04),
      ];
    }
    if (isIos27) {
      return const [_ios27GlassHi, _ios27GlassLo];
    }
    if (isAmoledBlack) {
      return const [Color(0xCC0A0A0C), Color(0x99050506)];
    }

    if (isSemc) {
      return [const Color(0x4818201C), const Color(0x2A101412)];
    }
    if (_isFrostedGlass) {
      return [
        Colors.white.withValues(alpha: 0.16),
        Colors.white.withValues(alpha: 0.05),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFF1F5F9).withValues(alpha: 0.18),
        const Color(0xFF94A3B8).withValues(alpha: 0.06),
      ];
    }
    if (isDarkFlatStyle) {
      return [const Color(0xFF2C2C34), const Color(0xFF1E1E24)];
    }
    if (isDarkGlass) {
      return [const Color(0x44181822), const Color(0x2810141A)];
    }
    return [
      Colors.white.withValues(alpha: 0.11),
      Colors.white.withValues(alpha: 0.04),
    ];
  }

  List<Color> homeCategoryCardNeutralGradient(bool portrait) {
    if (isIos27) {
      return [
        const Color(0xFF1B2E52).withValues(alpha: portrait ? 0.42 : 0.50),
        const Color(0xFF101F3C).withValues(alpha: portrait ? 0.34 : 0.40),
        const Color(0xFF0A1730).withValues(alpha: portrait ? 0.46 : 0.52),
      ];
    }
    if (isAmoledBlack) {
      return [
        const Color(0xFF0A0A0C).withValues(alpha: portrait ? 0.52 : 0.48),
        const Color(0xFF050506).withValues(alpha: portrait ? 0.58 : 0.54),
        const Color(0xFF020203).withValues(alpha: portrait ? 0.66 : 0.62),
      ];
    }

    if (isSemc) {
      return [
        const Color(0x621C2820),
        const Color(0x42121814),
        const Color(0x5018201C),
      ];
    }
    if (isFlyUi) {
      return [
        const Color(0xFF32363E).withValues(alpha: portrait ? 0.88 : 0.82),
        const Color(0xFF282A30).withValues(alpha: portrait ? 0.92 : 0.86),
        _flyBlue.withValues(alpha: portrait ? 0.10 : 0.14),
      ];
    }
    if (_isFrostedGlass) {
      return [
        Colors.white.withValues(alpha: portrait ? 0.26 : 0.34),
        Colors.white.withValues(alpha: portrait ? 0.10 : 0.16),
        Colors.white.withValues(alpha: portrait ? 0.16 : 0.22),
      ];
    }
    if (isGlassGri) {
      return [
        const Color(0xFFF8FAFC).withValues(alpha: portrait ? 0.22 : 0.28),
        const Color(0xFFCBD5E1).withValues(alpha: portrait ? 0.09 : 0.12),
        const Color(0xFFE2E8F0).withValues(alpha: portrait ? 0.14 : 0.18),
      ];
    }
    if (isDarkFlatStyle) {
      // Önizleme görünsün diye tam opak değil — altta [IptvChannelLogo] kalır.
      return [
        const Color(0xFF1E1E28).withValues(alpha: portrait ? 0.52 : 0.48),
        const Color(0xFF16161E).withValues(alpha: portrait ? 0.58 : 0.54),
        const Color(0xFF12121A).withValues(alpha: portrait ? 0.66 : 0.62),
      ];
    }
    if (isDarkGlass) {
      return [
        const Color(0x621A1E28),
        const Color(0x42121820),
        const Color(0x50161C24),
      ];
    }
    return [
      Colors.white.withValues(alpha: portrait ? 0.08 : 0.2),
      Colors.white.withValues(alpha: portrait ? 0.02 : 0.05),
      Colors.white.withValues(alpha: portrait ? 0.04 : 0.1),
    ];
  }

  Color homeCategoryCardNeutralBorder(bool portrait) {
    if (isIos27) {
      return _ios27EdgeColor;
    }
    if (isAmoledBlack) {
      return Colors.white.withValues(alpha: 0.14);
    }
    if (isSemc) {
      return _semcGreen.withValues(alpha: 0.28);
    }
    if (isFlyUi) {
      return _flyBlue.withValues(alpha: 0.32);
    }
    if (_isFrostedGlass) {
      return Colors.white.withValues(alpha: 0.52);
    }
    if (isGlassGri) {
      return Colors.white.withValues(alpha: 0.50);
    }
    if (isDarkFlatStyle) {
      return const Color(0xFF3F3F4E);
    }
    return Colors.white.withValues(alpha: isDarkGlass ? 0.26 : 0.38);
  }

  Color homeCategoryCardNeutralShadow() {
    if (isIos27) {
      return const Color(0xFF030712).withValues(alpha: 0.42);
    }
    if (isSemc) {
      return const Color(0xFF003320).withValues(alpha: 0.32);
    }
    if (isFlyUi) {
      return _flyBlue.withValues(alpha: 0.12);
    }
    if (_isFrostedGlass) {
      return const Color(0xFF9A3412).withValues(alpha: 0.16);
    }
    if (isGlassGri) {
      return Colors.black.withValues(alpha: 0.22);
    }
    if (isDarkFlatStyle) {
      return Colors.black.withValues(alpha: 0.5);
    }
    return Colors.black.withValues(alpha: isDarkGlass ? 0.35 : 0.25);
  }
}
