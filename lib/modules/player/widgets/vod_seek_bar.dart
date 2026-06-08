import 'package:flutter/material.dart';

/// VOD (film / dizi) için kararlı, dokunmatik dostu sarma çubuğu.
///
/// Eski uygulamada `Slider.value` doğrudan **canlı** oynatma konumuna bağlıydı
/// ve `onChanged` her tetiklendiğinde anında `seekTo` çağrılıyordu; bu yüzden
/// kullanıcı sürüklerken oynatıcı konumu parmakla çakışıp titriyor, saniye
/// bazlı hassas sürükleme yapılamıyordu.
///
/// Bu widget sürükleme süresince **yerel** bir değer tutar (oynatıcı konumunu
/// dinlemez), gerçek `onSeek` yalnızca sürükleme bittiğinde (`onChangeEnd`)
/// çağrılır. Sürüklerken başparmağın üstünde, hedef zamanı (uzun filmlerde
/// `S:DD:SS`, kısa içerikte `DD:SS`) gösteren küçük bir cam baloncuk belirir.
class VodSeekBar extends StatefulWidget {
  const VodSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.onScrubChanged,
    this.enabled = true,
    this.trackHeight = 3,
    this.thumbRadius = 6,
    this.overlayRadius = 12,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.overlayColor,
  });

  /// Oynatıcının canlı konumu (sürükleme yokken gösterilir).
  final Duration position;
  final Duration duration;

  /// Sürükleme bittiğinde hedef konuma sarma için çağrılır.
  final ValueChanged<Duration> onSeek;

  /// Sürükleme başlayınca `true`, bitince/iptal olunca `false` gönderir.
  /// OSD'nin sürükleme sırasında otomatik gizlenmesini engellemek için
  /// kullanılır (oynatıcı kontrolleri bunu dinler).
  final ValueChanged<bool>? onScrubChanged;

  final bool enabled;
  final double trackHeight;
  final double thumbRadius;
  final double overlayRadius;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final Color? overlayColor;

  @override
  State<VodSeekBar> createState() => _VodSeekBarState();
}

class _VodSeekBarState extends State<VodSeekBar> {
  /// Sürükleme sürerken parmağın gösterdiği geçici değer (ms). Null ise
  /// kullanıcı sürüklemiyor; çubuk canlı konumu gösterir.
  double? _dragMs;

  /// Sürükleme bittiğinde sarılan hedef (ms). Oynatıcı bu konuma ulaşana
  /// kadar çubuk hedefte bekler — yoksa parmak kalkar kalkmaz eski konuma
  /// "geri sıçrar" ve yeni konuma atlardı.
  double? _settleTargetMs;

  /// `onScrubChanged(true)` gönderildi mi? Widget sürükleme ortasında ağaçtan
  /// kalkarsa `dispose`'da `false` gönderip OSD'yi kilitli bırakmamak için.
  bool _scrubReported = false;

  /// Zaman baloncuğunu kök Overlay'de gösterir; böylece yatay OSD'deki cam
  /// kapsülün [ClipRRect]'i (veya başka bir ata kırpıcı) baloncuğu kesmez.
  final OverlayPortalController _bubbleController = OverlayPortalController();

  /// Çubuğun (track) render kutusunu bulmak için anahtar — baloncuğun
  /// ekran-global konumunu hesaplamada kullanılır.
  final GlobalKey _trackKey = GlobalKey();

  /// Baloncuğun **ekran-global** sol/üst konumu (px) ve metni; her sürükleme
  /// karesinde `build` içinde güncellenir, overlay bunu okur.
  ///
  /// Not: Eski sürüm [CompositedTransformFollower] kullanıyordu; ancak yatay
  /// OSD'deki cam çubuk ([BackdropFilter]) içinde leader katmanı bazı
  /// cihazlarda follower'ı ekranın köşesine atıyor (baloncuk görünmüyordu).
  /// Global konumlama her mount bağlamında güvenilir çalışır.
  Offset _bubbleGlobal = Offset.zero;
  String _bubbleLabel = '0:00';
  static const double _bubbleWidth = 92;
  static const double _bubbleGap = 42;

  void _setScrubbing(bool active) {
    if (_scrubReported == active) return;
    _scrubReported = active;
    widget.onScrubChanged?.call(active);
  }

  void _showBubble() {
    if (!_bubbleController.isShowing) _bubbleController.show();
  }

  void _hideBubble() {
    if (_bubbleController.isShowing) _bubbleController.hide();
  }

  @override
  void dispose() {
    if (_scrubReported) {
      // Sürükleme sürerken ekran kapanırsa OSD'yi tekrar serbest bırak.
      widget.onScrubChanged?.call(false);
      _scrubReported = false;
    }
    super.dispose();
  }

  static String fmt(Duration d) {
    if (d.isNegative) return '0:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final maxMs = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final liveMs =
        widget.position.inMilliseconds.toDouble().clamp(0.0, maxMs);

    // Bırakma sonrası: oynatıcı hedefe (~1.2 sn içine) ulaşınca yerleşmeyi bitir.
    if (_settleTargetMs != null && (_settleTargetMs! - liveMs).abs() <= 1200) {
      _settleTargetMs = null;
    }

    final effectiveMs = _dragMs ?? _settleTargetMs ?? liveMs;
    final valueMs = effectiveMs.clamp(0.0, maxMs);
    final fraction = maxMs > 0 ? (valueMs / maxMs).clamp(0.0, 1.0) : 0.0;
    final canDrag = widget.enabled && totalMs > 0;

    final theme = SliderTheme.of(context).copyWith(
      trackHeight: widget.trackHeight,
      thumbShape:
          RoundSliderThumbShape(enabledThumbRadius: widget.thumbRadius),
      overlayShape:
          RoundSliderOverlayShape(overlayRadius: widget.overlayRadius),
      activeTrackColor: widget.activeColor,
      inactiveTrackColor: widget.inactiveColor,
      thumbColor: widget.thumbColor,
      overlayColor: widget.overlayColor,
    );

    final slider = SliderTheme(
      data: theme,
      child: Slider(
        value: valueMs,
        max: maxMs,
        onChanged: canDrag
            ? (v) {
                _setScrubbing(true);
                _showBubble();
                setState(() => _dragMs = v);
              }
            : null,
        onChangeStart: canDrag
            ? (v) {
                _setScrubbing(true);
                _showBubble();
                setState(() => _dragMs = v);
              }
            : null,
        onChangeEnd: canDrag
            ? (v) {
                widget.onSeek(Duration(milliseconds: v.round()));
                _hideBubble();
                setState(() {
                  _settleTargetMs = v;
                  _dragMs = null;
                });
                _setScrubbing(false);
              }
            : null,
      ),
    );

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        _bubbleLabel = fmt(Duration(milliseconds: valueMs.round()));
        // Baloncuk gösteriliyorsa ekran-global konumunu (önceki kareye ait
        // geçerli layout üzerinden) güncelle; overlay child bunu okur.
        if (_bubbleController.isShowing && width > 0) {
          _recomputeBubbleGlobal(fraction, width, ctx);
        }

        return SizedBox(
          key: _trackKey,
          width: width > 0 ? width : null,
          // Baloncuk kök Overlay'de (OverlayPortal) çizilir; yatay OSD'deki
          // cam kapsülün ClipRRect/BackdropFilter'ı onu ne kırpar ne de yanlış
          // konumlar (global koordinat kullanıldığı için).
          child: OverlayPortal(
            controller: _bubbleController,
            overlayChildBuilder: (overlayCtx) {
              return Positioned(
                left: _bubbleGlobal.dx,
                top: _bubbleGlobal.dy,
                child: SizedBox(
                  width: _bubbleWidth,
                  child: Center(
                    child: _SeekBubble(label: _bubbleLabel),
                  ),
                ),
              );
            },
            child: slider,
          ),
        );
      },
    );
  }

  /// Başparmağın bulunduğu konuma göre baloncuğun **ekran-global** sol/üst
  /// köşesini hesaplar. Çubuk render kutusunun global başlangıcını alır,
  /// üzerine thumb yatay konumunu ekler ve ekran kenarlarına kıstırır.
  void _recomputeBubbleGlobal(double fraction, double width, BuildContext ctx) {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    // Başparmak merkezi: track her iki uçta thumbRadius kadar içeride.
    final usable = (width - widget.thumbRadius * 2).clamp(0.0, width);
    final thumbX = widget.thumbRadius + fraction * usable;
    var left = origin.dx + thumbX - _bubbleWidth / 2;
    final screenW = MediaQuery.sizeOf(ctx).width;
    if (left < 4) left = 4;
    if (left > screenW - _bubbleWidth - 4) {
      left = screenW - _bubbleWidth - 4;
    }
    _bubbleGlobal = Offset(left, origin.dy - _bubbleGap);
  }
}

class _SeekBubble extends StatelessWidget {
  const _SeekBubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          height: 1,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
