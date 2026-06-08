import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_settings_service.dart';
import '../../../ui/glass_overlays.dart';

/// Yükleme aşamasının durumu.
enum PlaylistLoadStage { loading, done, error }

/// Dialog'a beslenen tek anlık durum — yükleme mi bitti mi, sayılar veya hata.
@immutable
class PlaylistLoadProgress {
  const PlaylistLoadProgress.loading()
      : stage = PlaylistLoadStage.loading,
        liveChannelCount = 0,
        filmCount = 0,
        seriesCount = 0,
        errorTitle = '',
        errorMessage = '',
        errorHint = '',
        canRetryUrl = false;

  const PlaylistLoadProgress.done({
    required this.liveChannelCount,
    required this.filmCount,
    required this.seriesCount,
  })  : stage = PlaylistLoadStage.done,
        errorTitle = '',
        errorMessage = '',
        errorHint = '',
        canRetryUrl = false;

  /// URL/şifre hatalarını dialog içinde göstermek için. [canRetryUrl]
  /// true ise dialog'da "URL'yi Düzelt" butonu çıkar.
  const PlaylistLoadProgress.error({
    required this.errorTitle,
    required this.errorMessage,
    this.errorHint = '',
    this.canRetryUrl = true,
  })  : stage = PlaylistLoadStage.error,
        liveChannelCount = 0,
        filmCount = 0,
        seriesCount = 0;

  final PlaylistLoadStage stage;
  final int liveChannelCount;
  final int filmCount;
  final int seriesCount;
  final String errorTitle;
  final String errorMessage;
  final String errorHint;
  final bool canRetryUrl;

  bool get isLoading => stage == PlaylistLoadStage.loading;
  bool get isDone => stage == PlaylistLoadStage.done;
  bool get isError => stage == PlaylistLoadStage.error;
}

/// Playlist (M3U / Xtream) yüklemesi **başlar başlamaz** kullanıcıya açılan
/// cam diyalog. Üç satır (Canlı kanallar / Filmler / Diziler) önce
/// **yükleniyor** spinner'ı ile gelir; veri geldiğinde her satır sırayla
/// (`550 ms` aralıkla) "✓ + sayı" şekline döner. Tüm satırlar tamamlanınca
/// **Tamam** butonu aktifleşir ve TV cihazlarda otomatik odaklanır.
///
/// Akış:
/// ```dart
/// final progress = ValueNotifier<PlaylistLoadProgress>(
///   const PlaylistLoadProgress.loading(),
/// );
/// // Dialog'u arka planda aç (sonuç beklenmez).
/// final dialogFuture = PlaylistLoadSummaryDialog.show(ctx, progress: progress);
/// final result = await repo.loadFromXtream(...);  // veya M3U
/// progress.value = PlaylistLoadProgress.done(
///   liveChannelCount: result.channels.length,
///   filmCount: result.vod.length,
///   seriesCount: result.series.length,
/// );
/// await dialogFuture; // Kullanıcı Tamam'a basana kadar bekle.
/// ```
class PlaylistLoadSummaryDialog extends StatefulWidget {
  const PlaylistLoadSummaryDialog({
    super.key,
    required this.progress,
  });

  /// Dialog dış dünyaya bağlı; aynı notifier ile sayılar ve aşama bilgisi
  /// güncellenir. Loading → Done geçişi animasyonu tetikler.
  final ValueListenable<PlaylistLoadProgress> progress;

  /// Modal cam diyalog olarak gösterir.
  ///  * `barrierDismissible: false` — Tamam'a basmadan kapanmaz.
  ///  * `useRootNavigator: true` — alt sayfa/sheet açıkken bile kök
  ///    navigator üzerinde modal dursun, kullanıcı kaybolmasın.
  ///  * Geri tuşu (Android) `PopScope` ile yalnızca tamamlandığında izinli.
  /// Dönüş değeri:
  ///  * `true` — kullanıcı **Tamam** veya **URL'yi Düzelt**'e bastı (başarıdan veya hatadan)
  ///  * `false` / `null` — başka şekilde kapandı
  static Future<bool?> show(
    BuildContext context, {
    required ValueListenable<PlaylistLoadProgress> progress,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => PlaylistLoadSummaryDialog(progress: progress),
    );
  }

  @override
  State<PlaylistLoadSummaryDialog> createState() =>
      _PlaylistLoadSummaryDialogState();
}

class _PlaylistLoadSummaryDialogState extends State<PlaylistLoadSummaryDialog> {
  /// 0..3 — kaç satır görsel olarak "tamam" rozeti gösteriyor.
  /// Stage 3'te **Tamam** butonu aktiftir.
  int _stage = 0;
  Timer? _timer;
  bool _animationStarted = false;

  // Tamam butonu TV cihazlarda done olduğunda otomatik odaklanır.
  final FocusNode _okFocus = FocusNode(debugLabel: 'playlistSummaryOk');
  bool _okFocusRequested = false;

  static const Duration _stageDelay = Duration(milliseconds: 550);

  /// Done sonrası otomatik kapanma için kalan saniye (5 → 0).
  /// `null` ise countdown henüz başlamamış veya devre dışı (hata, kullanıcı
  /// etkileşimi).
  int? _autoCloseRemaining;
  Timer? _autoCloseTimer;
  bool _autoCloseCancelled = false;

  /// Done + 3 satır animasyonu tamamlandıktan sonra başlatılan auto-close
  /// süresi. Kullanıcı bu süre boyunca sayıları rahatça görür, sonra
  /// dialog kapanır ve merge cache zaten arka planda yenilenir.
  static const int _autoCloseSeconds = 5;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgressChanged);
    // Eğer çağıran zaten "done" ile gelmişse direkt animasyona başla.
    _onProgressChanged();
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgressChanged);
    _timer?.cancel();
    _autoCloseTimer?.cancel();
    _okFocus.dispose();
    super.dispose();
  }

  void _onProgressChanged() {
    _maybeStartDoneAnimation();
  }

  /// [progress] zaten `done` iken dinleyici kaçırılırsa (hızlı yükleme / frame
  /// sırası) Tamam düğümü kilitli kalmasın.
  void _maybeStartDoneAnimation() {
    final p = widget.progress.value;
    if (p.isDone && !_animationStarted) {
      _animationStarted = true;
      if (_stage < 3) {
        _scheduleNextStage();
      } else {
        _maybeRequestOkFocus();
        _startAutoCloseCountdown();
      }
    }
  }

  void _scheduleNextStage() {
    _timer?.cancel();
    if (_stage >= 3) {
      _maybeRequestOkFocus();
      _startAutoCloseCountdown();
      return;
    }
    _timer = Timer(_stageDelay, () {
      if (!mounted) return;
      setState(() => _stage += 1);
      _scheduleNextStage();
    });
  }

  void _maybeRequestOkFocus() {
    if (_okFocusRequested || !widget.progress.value.isDone) return;
    _okFocusRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _okFocus.requestFocus();
    });
  }

  /// 5 saniyelik geri sayım — her saniye `_autoCloseRemaining` azalır,
  /// 0'a düştüğünde dialog otomatik kapanır. Kullanıcı bu sırada **Tamam**'a
  /// basarsa veya dialog'a dokunursa countdown iptal edilir (focus / tap).
  void _startAutoCloseCountdown() {
    if (_autoCloseTimer != null || _autoCloseCancelled) return;
    if (!mounted) return;
    setState(() => _autoCloseRemaining = _autoCloseSeconds);
    _autoCloseTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = (_autoCloseRemaining ?? 0) - 1;
      if (remaining <= 0) {
        timer.cancel();
        _autoCloseTimer = null;
        // Kapan: kullanıcı "Tamam" basmış gibi true döndür.
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
        return;
      }
      setState(() => _autoCloseRemaining = remaining);
    });
  }

  /// Kullanıcı dialog ile etkileşime girdi (dokunma / odak değişimi) →
  /// auto-close'u iptal et; dialog Tamam'a basana kadar açık kalsın.
  void _cancelAutoClose() {
    if (_autoCloseTimer == null && _autoCloseRemaining == null) return;
    _autoCloseTimer?.cancel();
    _autoCloseTimer = null;
    _autoCloseCancelled = true;
    if (!mounted) return;
    setState(() => _autoCloseRemaining = null);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsService>();
    final primary = Theme.of(context).colorScheme.primary;
    final reduce = settings.reduceBlur.value;
    final sigma = reduce ? 10.0 : 20.0;
    final mq = MediaQuery.of(context);
    final portrait = mq.orientation == Orientation.portrait;
    final insetH = portrait ? 22.0 : 14.0;
    final insetW = portrait ? 20.0 : 18.0;
    final maxW = math.min(420.0, mq.size.width - insetW * 2);

    return ValueListenableBuilder<PlaylistLoadProgress>(
      valueListenable: widget.progress,
      builder: (context, progress, _) {
        final done = progress.isDone;
        final isError = progress.isError;
        // Hata veya tamamlanma sonrası dialog kapanabilir.
        final canDismiss = done || isError;
        final liveValue = done ? progress.liveChannelCount : 0;
        final filmValue = done ? progress.filmCount : 0;
        final seriesValue = done ? progress.seriesCount : 0;

        if (done) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybeStartDoneAnimation();
          });
        }

        return PopScope(
          canPop: canDismiss,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: insetW,
              vertical: insetH,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _cancelAutoClose,
              child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: Stack(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            color: Colors.black.withValues(alpha: 0.84),
                          ),
                          child: const SizedBox(width: double.infinity),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.22),
                              width: 1.2,
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.13),
                                Colors.white.withValues(alpha: 0.04),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withValues(alpha: 0.22),
                                blurRadius: 32,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              portrait ? 22 : 20,
                              portrait ? 22 : 18,
                              portrait ? 22 : 20,
                              portrait ? 16 : 14,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _header(primary, portrait, progress),
                                SizedBox(height: portrait ? 16 : 12),
                                if (isError)
                                  _ErrorBody(progress: progress, portrait: portrait)
                                else ...[
                                  _SummaryRow(
                                    icon: Icons.live_tv_rounded,
                                    label: 'playlist.summary.liveChannels'.tr,
                                    value: liveValue,
                                    done: _stage >= 1,
                                    accentColor: const Color(0xFF6EC8FF),
                                  ),
                                  const SizedBox(height: 10),
                                  _SummaryRow(
                                    icon: Icons.movie_creation_rounded,
                                    label: 'playlist.summary.films'.tr,
                                    value: filmValue,
                                    done: _stage >= 2,
                                    accentColor: const Color(0xFFFFC773),
                                  ),
                                  const SizedBox(height: 10),
                                  _SummaryRow(
                                    icon: Icons.tv_rounded,
                                    label: 'playlist.summary.series'.tr,
                                    value: seriesValue,
                                    done: _stage >= 3,
                                    accentColor: const Color(0xFFB089FF),
                                  ),
                                ],
                                SizedBox(height: portrait ? 20 : 16),
                                _actionRow(
                                  context: context,
                                  isError: isError,
                                  done: done,
                                  progress: progress,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(Color primary, bool portrait, PlaylistLoadProgress progress) {
    final isError = progress.isError;
    final isDone = progress.isDone;
    final accent = isError ? const Color(0xFFFF6B6B) : primary;
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.playlist_add_check_rounded;
    final title = isError
        ? (progress.errorTitle.isNotEmpty
            ? progress.errorTitle
            : 'playlist.summary.errorTitle'.tr)
        : (isDone
            ? 'playlist.summary.title'.tr
            : 'playlist.summary.titleLoading'.tr);
    final subtitle = isError
        ? 'playlist.summary.errorSubtitle'.tr
        : (isDone
            ? 'playlist.summary.subtitle'.tr
            : 'playlist.summary.subtitleLoading'.tr);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.5),
                accent.withValues(alpha: 0.22),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
          ),
          child: Icon(icon, color: Colors.white, size: portrait ? 30 : 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: portrait ? 19 : 17,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: portrait ? 13 : 12.5,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionRow({
    required BuildContext context,
    required bool isError,
    required bool done,
    required PlaylistLoadProgress progress,
  }) {
    if (isError) {
      final retry = progress.canRetryUrl;
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (retry)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GlassDialogActionButton(
                label: 'playlist.summary.cancel'.tr,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          GlassDialogActionButton(
            label: retry
                ? 'playlist.summary.fixUrl'.tr
                : 'playlist.summary.ok'.tr,
            primary: true,
            focusNode: _okFocus,
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(retry),
          ),
        ],
      );
    }
    final countdown = _autoCloseRemaining;
    final showCountdown = done && countdown != null && countdown > 0;
    final okLabel = showCountdown
        ? 'playlist.summary.okCountdown'
            .trParams({'n': '$countdown'})
        : 'playlist.summary.ok'.tr;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (showCountdown)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                'playlist.summary.autoCloseHint'.tr,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ),
          )
        else
          const Spacer(),
        FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: done ? 1 : 0.45,
            child: GlassDialogActionButton(
              label: okLabel,
              primary: true,
              focusNode: _okFocus,
              autofocus: false,
              onPressed: done ? () => Navigator.of(context).pop(true) : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.progress, required this.portrait});

  final PlaylistLoadProgress progress;
  final bool portrait;

  @override
  Widget build(BuildContext context) {
    final hasHint = progress.errorHint.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.55),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF6B6B).withValues(alpha: 0.18),
            const Color(0xFFFF6B6B).withValues(alpha: 0.06),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            progress.errorMessage,
            style: TextStyle(
              color: Colors.white,
              fontSize: portrait ? 14 : 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (hasHint) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: Color(0xFFFFD479),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    progress.errorHint,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: portrait ? 13 : 12.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.done,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final int value;
  final bool done;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done
              ? accentColor.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.16),
          width: 1.1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: done
              ? [
                  accentColor.withValues(alpha: 0.18),
                  accentColor.withValues(alpha: 0.06),
                ]
              : [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.02),
                ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: done
                  ? accentColor.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: done
                    ? accentColor.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: done ? accentColor : Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  child: Text(
                    done
                        ? 'playlist.summary.itemsCount'
                            .trParams({'n': _formatCount(value)})
                        : 'playlist.summary.loading'.tr,
                    key: ValueKey<bool>(done),
                    style: TextStyle(
                      color: done
                          ? accentColor
                          : Colors.white.withValues(alpha: 0.70),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 26,
            height: 26,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: done
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey('check'),
                      color: accentColor,
                      size: 26,
                    )
                  : SizedBox(
                      key: const ValueKey('spin'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sayıyı `1,234,567` gibi grupları olan kullanıcı-dostu metne çevirir
  /// (cihazın locale'inden bağımsız sabit virgül-ayraç; sayılar her dilde
  /// aynı okunabilir).
  String _formatCount(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
