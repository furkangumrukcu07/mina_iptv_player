import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/equalizer_service.dart';
import '../../ui/glass_overlays.dart';
import '../../ui/tv_dpad_focus.dart';

/// Ses Equalizer ayar diyaloğu.
///
/// * Üstte aktif/pasif anahtarı.
/// * Hazır ayar (`flat`, `bassBoost`, …, `custom`) seçici chip listesi.
/// * Preamp slider.
/// * 10 bantlı dikey grafik EQ (her bant −12 … +12 dB).
/// * Sıfırla / Kapat butonları.
///
/// Tüm değişiklikler [EqualizerService] üzerinden anında uygulanır;
/// `PlayerController` `revision` üzerinden mpv filtre zincirini gerçek
/// zamanlı günceller. Diyalog kapatılınca son durum kalıcı kalır.
Future<void> showEqualizerDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => const _EqualizerDialog(),
  );
}

class _EqualizerDialog extends StatelessWidget {
  const _EqualizerDialog();

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<EqualizerService>();
    final mq = MediaQuery.of(context);
    final isPortrait = mq.orientation == Orientation.portrait;
    final dialogWidth = (isPortrait ? mq.size.width * 0.92 : mq.size.width * 0.7)
        .clamp(320.0, 760.0);
    final tvOsdStyle = Get.isRegistered<AppSettingsService>() &&
        Get.find<AppSettingsService>()
            .layoutMode
            .value
            .usesRemoteNavigationStyle;

    return GlassAlertDialog(
      tvOsdStyle: tvOsdStyle,
      title: Row(
        children: [
          const Icon(
            Icons.graphic_eq_rounded,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'settings.equalizer.title'.tr,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      // Gövdeyi GlassAlertDialog'un sınırlı kaydırma alanına bırak; böylece
      // içerik uzun olsa bile (özellikle yatay modda) "Sıfırla"/"Kapat"
      // butonları ekran dışına taşmaz, gövde kendi içinde kayar.
      scrollable: true,
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _enableSwitch(context, svc),
            const SizedBox(height: 10),
            Text(
              'settings.equalizer.hint'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            _engineSupportInfo(),
            const SizedBox(height: 14),
            _presetChips(svc),
            const SizedBox(height: 16),
            _preampSlider(svc),
            const SizedBox(height: 12),
            _bandSliders(svc),
          ],
        ),
      ),
      actions: [
        GlassDialogActionButton(
          label: 'settings.equalizer.reset'.tr,
          onPressed: () {
            svc.resetToFlat();
          },
          onDarkSurface: true,
        ),
        GlassDialogActionButton(
          label: 'common.close'.tr,
          primary: true,
          onPressed: () => Navigator.of(context).pop(),
          onDarkSurface: true,
        ),
      ],
    );
  }

  Widget _engineSupportInfo() {
    return Obx(() {
      final svc = Get.find<EqualizerService>();
      final mediaKitOk = true;
      final betterPlayerOk = Platform.isAndroid && svc.nativeAndroidSupported.value;
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _engineLine(
              label: 'settings.equalizer.engine.mediaKit'.tr,
              ok: mediaKitOk,
            ),
            const SizedBox(height: 4),
            _engineLine(
              label: 'settings.equalizer.engine.betterPlayer'.tr,
              ok: betterPlayerOk,
              fallbackHint: !betterPlayerOk
                  ? (Platform.isAndroid
                      ? 'settings.equalizer.engine.betterPlayer.unsupported'.tr
                      : 'settings.equalizer.engine.betterPlayer.platform'.tr)
                  : null,
            ),
          ],
        ),
      );
    });
  }

  Widget _engineLine({
    required String label,
    required bool ok,
    String? fallbackHint,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1.5),
          child: Icon(
            ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 13,
            color: ok
                ? const Color(0xFF63D471)
                : Colors.white.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (fallbackHint != null && fallbackHint.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    fallbackHint,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10.5,
                      height: 1.25,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _enableSwitch(BuildContext context, EqualizerService svc) {
    return Obx(() {
      final enabled = svc.enabled.value;
      final row = Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'settings.equalizer.enable'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // TV: anahtarı ayrı odak durağı olmaktan çıkar; satırın tamamı tek
            // D-pad hedefi olsun (OK ile aç/kapat).
            ExcludeFocus(
              child: Switch.adaptive(
                value: enabled,
                onChanged: (v) => svc.setEnabled(v),
              ),
            ),
          ],
        ),
      );
      return tvDpadActivateWrap(
        context,
        onActivate: () => svc.setEnabled(!enabled),
        borderRadius: 12,
        child: row,
      );
    });
  }

  Widget _presetChips(EqualizerService svc) {
    return Obx(() {
      final current = svc.preset.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'settings.equalizer.preset.title'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final p in EqualizerPreset.values)
                _PresetChip(
                  label: svc.labelKey(p).tr,
                  selected: current == p,
                  onTap: () => svc.applyPreset(p),
                ),
            ],
          ),
        ],
      );
    });
  }

  Widget _preampSlider(EqualizerService svc) {
    return Obx(() {
      final value = svc.preampDb.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'settings.equalizer.preamp'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _fmtDb(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(Get.context!).copyWith(
              activeTrackColor:
                  Theme.of(Get.context!).colorScheme.primary,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.18),
            ),
            child: Slider(
              value: value,
              min: EqualizerService.kMinGainDb,
              max: EqualizerService.kMaxGainDb,
              divisions: 48,
              onChanged: (v) => svc.setPreampGain(v),
            ),
          ),
        ],
      );
    });
  }

  Widget _bandSliders(EqualizerService svc) {
    return LayoutBuilder(builder: (ctx, c) {
      // Bant başına ayrılan yatay alanı dinamik hesaplıyoruz; 10 bant + her
      // bantta etiket var. Dar telefonlarda küçülür, tabletlerde rahatlar.
      final perBand = (c.maxWidth / EqualizerService.kBandFrequenciesHz.length)
          .clamp(28.0, 56.0);
      return SizedBox(
        height: 180,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0;
                i < EqualizerService.kBandFrequenciesHz.length;
                i++)
              SizedBox(
                width: perBand,
                child: _BandColumn(svc: svc, index: i),
              ),
          ],
        ),
      );
    });
  }

  static String _fmtDb(double v) {
    final sign = v > 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(1)} dB';
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 20,
      child: chip,
    );
  }
}

class _BandColumn extends StatelessWidget {
  const _BandColumn({required this.svc, required this.index});

  final EqualizerService svc;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final value = svc.bandGainsDb[index];
      final hz = EqualizerService.kBandFrequenciesHz[index];
      final primary = Theme.of(context).colorScheme.primary;
      // dB değeri üstte küçük etiket.
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 18,
            child: Center(
              child: Text(
                _shortDb(value),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: primary,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.18),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withValues(alpha: 0.18),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                    elevation: 1,
                  ),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                ),
                child: Slider(
                  value: value,
                  min: EqualizerService.kMinGainDb,
                  max: EqualizerService.kMaxGainDb,
                  divisions: 48,
                  onChanged: (v) => svc.setBandGain(index, v),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 16,
            child: Center(
              child: Text(
                EqualizerService.formatBandLabel(hz),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  static String _shortDb(double v) {
    if (v.abs() < 0.05) return '0';
    final sign = v > 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(0)}';
  }
}
