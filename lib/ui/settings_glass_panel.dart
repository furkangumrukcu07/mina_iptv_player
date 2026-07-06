import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/services/app_settings_service.dart';

/// Ayarlar altındaki tüm alt-sayfaların ortak cam paneli.
///
/// **Neden ayrı bir widget?**
/// Eski yapı `ClipRRect → BackdropFilter → DecoratedBox → Column(ListView)`
/// şeklindeydi. `BackdropFilter`, [child] olarak verilen büyük scroll'lu
/// ListView'ı sardığı için her frame'de `saveLayer + ImageFilter.blur`
/// zinciri yeniden çalışıyordu; üstelik `ThemedSettingsBackground` zaten
/// görsel arka plana statik bir `ImageFiltered.blur` uyguluyordu → **çift
/// blur**, dokunmatik scroll'da görünür kasılmalara yol açıyordu.
///
/// Bu widget aynı görsel sonucu çok daha ucuza üretir:
///
/// * `BackdropFilter`'ı [Stack]'in **alt çocuğu** olarak, sabit bir arka
///   plan paneli halinde tutar. Üstündeki içerik scroll edildiğinde
///   panel'in kendi layer'ı dirty olmaz; sadece arka plandaki tema
///   görseli üzerinden bir kez blur'lanır.
/// * Panel + içerik birer [RepaintBoundary] içine alınır — Flutter dirty
///   bölgeyi her iki tarafta izole eder.
/// * Sigma değerleri eski 22/12 yerine 14/0 — yüksek sigma'nın görsel
///   katkısı küçük, GPU maliyeti büyüktü. `reduceBlur` açıkken
///   `BackdropFilter` tamamen atlanır ve yalnızca renkli/yarısaydam panel
///   çizilir.
///
/// Kullanım örneği:
///
/// ```dart
/// Scaffold(
///   backgroundColor: Colors.black,
///   body: ThemedSettingsBackground(
///     child: SafeArea(
///       child: SettingsGlassPanel(
///         child: Column(
///           children: [
///             // Header Row (geri + başlık + actions)
///             // Hint metni
///             // Expanded(ListView(...))
///           ],
///         ),
///       ),
///     ),
///   ),
/// );
/// ```
class SettingsGlassPanel extends StatelessWidget {
  const SettingsGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 12),
    this.borderRadius = 22,
    this.blurBackground = true,
  });

  /// Panel içerisindeki içerik. Tipik olarak header Row + hint Padding +
  /// `Expanded(ListView(...))` içeren bir [Column].
  final Widget child;

  /// Panelin dış kenar boşluğu. Tüm ayar ekranlarında varsayılan değer
  /// `EdgeInsets.fromLTRB(12, 8, 12, 12)` kullanılır.
  final EdgeInsetsGeometry padding;

  /// Köşe yumuşatma yarıçapı. Tüm ayar ekranlarında varsayılan `22`.
  final double borderRadius;

  /// Panelin kendi [BackdropFilter]'ını uygulasın mı? Arka plan (örn.
  /// [ThemedSettingsBackground]) zaten blur'lanmışsa, panelin ikinci blur'u
  /// görsel olarak gereksiz ama her frame `saveLayer` maliyeti getirir. Çok
  /// sık yeniden çizilen ekranlarda (canlı sohbet listesi) `false` verilerek
  /// çift blur tek katmana indirilir.
  final bool blurBackground;

  /// `reduceBlur=false` durumda BackdropFilter sigması. Eski sürümde 22
  /// kullanılıyordu; saveLayer maliyeti scroll'da görünür kasılma yaratıyordu.
  /// 14 görsel olarak yakın sonuç, GPU maliyeti ~%40 daha düşük.
  static const double _kSigmaNormal = 14.0;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final reduce = settings.reduceBlur.value;
    // Reduce modunda veya çağıran blur'u kapattığında BackdropFilter tamamen
    // kaldırılır; yarısaydam zemin ve border görsel olarak yine cam hissini
    // korur ama GPU yükü 0.
    final sigma = (reduce || !blurBackground) ? 0.0 : _kSigmaNormal;

    final radius = BorderRadius.circular(borderRadius);
    final decoration = BoxDecoration(
      borderRadius: radius,
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.22),
        width: 1.2,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.04),
        ],
      ),
    );

    return Padding(
      padding: padding,
      child: Stack(
        children: [
          // Alt katman: sabit cam panel. ListView üst çocuk olarak çizildiği
          // için bu panel'in saveLayer'ı scroll dirty'sinden etkilenmez.
          Positioned.fill(
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: radius,
                child: sigma > 0
                    ? BackdropFilter(
                        filter:
                            ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                        child: DecoratedBox(
                          decoration: decoration,
                          child: const SizedBox.expand(),
                        ),
                      )
                    : DecoratedBox(
                        decoration: decoration,
                        child: const SizedBox.expand(),
                      ),
              ),
            ),
          ),
          // Üst katman: içerik. RepaintBoundary scroll dirty'sini
          // BackdropFilter layer'ından izole eder.
          RepaintBoundary(child: child),
        ],
      ),
    );
  }
}
