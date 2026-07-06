import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/services/download_service.dart';
import '../../../domain/entities/download_item.dart';
import '../../../ui/tv_dpad_focus.dart';

/// Film ve dizi bölümlerinde "İndir" eylemi için tek reaktif widget.
///
/// Üç durum reaktif olarak çizilir:
///
/// * **idle** — `Download` ikonu + "İndir" etiketi (opsiyonel).
/// * **active** — dönen progress halkası + yüzde / boyut göstergesi.
///   Tıklanırsa iptal onayı açılır.
/// * **completed** — tikli ikon, "İndirildi"; basıldığında sil onayı.
/// * **failed** — kırmızı uyarı ikonu; basıldığında tekrar dener.
///
/// [itemId] = `DownloadService.findVod` / `findEpisode` döndüğü kayıt id'si.
/// Henüz indirilmemiş bir film için [onStart] tıklamada [enqueue] çağıracak
/// bir callback olmalı. Tıklama olaylarını dışarıdaki controller yönetir;
/// widget yalnızca durum + UI sunar.
class DownloadButton extends StatelessWidget {
  const DownloadButton({
    super.key,
    required this.itemId,
    required this.onStart,
    this.compact = false,
    this.iconOnly = false,
    this.expand = false,
    this.tint,
    this.focusNode,
    this.arrowUp,
    this.arrowDown,
    this.arrowLeft,
    this.arrowRight,
  });

  /// Diskte indirilmiş veya devam eden item'ın id'si. null ise henüz hiç
  /// kuyrukta yok → idle gösterir.
  final String itemId;
  final Future<void> Function() onStart;
  final bool compact;
  final bool iconOnly;

  /// `true` → chip yatayda mevcut genişliği doldurur ve içeriği ortalar
  /// (örn. detay ekranında "İzle" butonuyla eşit ebatta yan yana kullanım).
  final bool expand;
  final Color? tint;

  /// TV/kumanda: D-pad odak düğümü ve komşu yön hedefleri.
  final FocusNode? focusNode;
  final FocusNode? arrowUp;
  final FocusNode? arrowDown;
  final FocusNode? arrowLeft;
  final FocusNode? arrowRight;

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<DownloadService>();
    return Obx(() {
      final item = svc.items[itemId];
      final status = item?.status;
      switch (status) {
        case DownloadStatus.downloading:
        case DownloadStatus.queued:
          return _BuildActive(
            item: item!,
            progress: svc.progress[itemId],
            compact: compact,
            iconOnly: iconOnly,
            expand: expand,
            tint: tint,
            onTap: () => _confirmCancel(context, svc, itemId),
            focusNode: focusNode,
            arrowUp: arrowUp,
            arrowDown: arrowDown,
            arrowLeft: arrowLeft,
            arrowRight: arrowRight,
          );
        case DownloadStatus.completed:
          return _BuildCompleted(
            item: item!,
            compact: compact,
            iconOnly: iconOnly,
            expand: expand,
            tint: tint,
            onTap: () => _confirmDelete(context, svc, itemId),
            focusNode: focusNode,
            arrowUp: arrowUp,
            arrowDown: arrowDown,
            arrowLeft: arrowLeft,
            arrowRight: arrowRight,
          );
        case DownloadStatus.failed:
          return _BuildFailed(
            compact: compact,
            iconOnly: iconOnly,
            expand: expand,
            tint: tint,
            onTap: () => _showErrorAndRetry(context, svc, item!),
            focusNode: focusNode,
            arrowUp: arrowUp,
            arrowDown: arrowDown,
            arrowLeft: arrowLeft,
            arrowRight: arrowRight,
          );
        case DownloadStatus.cancelled:
        case null:
          return _BuildIdle(
            compact: compact,
            iconOnly: iconOnly,
            expand: expand,
            tint: tint,
            onTap: onStart,
            focusNode: focusNode,
            arrowUp: arrowUp,
            arrowDown: arrowDown,
            arrowLeft: arrowLeft,
            arrowRight: arrowRight,
          );
      }
    });
  }

  static Future<void> _confirmCancel(
    BuildContext context,
    DownloadService svc,
    String id,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.82),
        title: Text(
          'downloads.cancelTitle'.tr,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'downloads.cancelBody'.tr,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text('common.no'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text('downloads.cancel'.tr),
          ),
        ],
      ),
    );
    if (ok == true) await svc.cancel(id);
  }

  /// Başarısız bir indirme için gerçek hata mesajını gösteren onay diyaloğu.
  /// Kullanıcı "Yeniden Dene" veya "Hatayı Kopyala" seçebilir.
  static Future<void> _showErrorAndRetry(
    BuildContext context,
    DownloadService svc,
    DownloadItem item,
  ) async {
    final reason = item.failureMessage?.trim();
    final body = (reason == null || reason.isEmpty)
        ? 'downloads.action.errorBody'.trParams({'reason': '—'})
        : 'downloads.action.errorBody'.trParams({'reason': '\n\n$reason\n'});
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.86),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'downloads.action.errorTitle'.tr,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: SelectableText(
              body,
              style: const TextStyle(color: Colors.white70, fontSize: 13.5),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 12, 8),
        actions: [
          if (reason != null && reason.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(c).pop('copy'),
              child: Text(
                'downloads.action.copyError'.tr,
                style: const TextStyle(color: Colors.white60),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(null),
            child: Text('common.cancel'.tr,
                style: const TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop('retry'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(c).colorScheme.primary,
            ),
            child: Text('downloads.action.retry'.tr),
          ),
        ],
      ),
    );
    if (action == 'retry') {
      await svc.retry(item.id);
    } else if (action == 'copy' && reason != null) {
      await Clipboard.setData(ClipboardData(text: reason));
    }
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    DownloadService svc,
    String id,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.82),
        title: Text(
          'downloads.deleteTitle'.tr,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'downloads.deleteBody'.tr,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text('common.no'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text('downloads.delete'.tr),
          ),
        ],
      ),
    );
    if (ok == true) await svc.deleteItem(id);
  }
}

// ─── State variants ──────────────────────────────────────────────────────────

class _BuildIdle extends StatelessWidget {
  const _BuildIdle({
    required this.compact,
    required this.iconOnly,
    required this.expand,
    required this.tint,
    required this.onTap,
    this.focusNode,
    this.arrowUp,
    this.arrowDown,
    this.arrowLeft,
    this.arrowRight,
  });
  final bool compact;
  final bool iconOnly;
  final bool expand;
  final Color? tint;
  final Future<void> Function() onTap;
  final FocusNode? focusNode;
  final FocusNode? arrowUp;
  final FocusNode? arrowDown;
  final FocusNode? arrowLeft;
  final FocusNode? arrowRight;

  @override
  Widget build(BuildContext context) {
    return _GlassActionChip(
      icon: Icons.download_rounded,
      label: iconOnly ? null : 'downloads.action.download'.tr,
      tint: tint ?? Theme.of(context).colorScheme.primary,
      compact: compact,
      expand: expand,
      onTap: onTap,
      focusNode: focusNode,
      arrowUp: arrowUp,
      arrowDown: arrowDown,
      arrowLeft: arrowLeft,
      arrowRight: arrowRight,
    );
  }
}

class _BuildActive extends StatelessWidget {
  const _BuildActive({
    required this.item,
    required this.progress,
    required this.compact,
    required this.iconOnly,
    required this.expand,
    required this.tint,
    required this.onTap,
    this.focusNode,
    this.arrowUp,
    this.arrowDown,
    this.arrowLeft,
    this.arrowRight,
  });
  final DownloadItem item;
  final ({int received, int? total})? progress;
  final bool compact;
  final bool iconOnly;
  final bool expand;
  final Color? tint;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusNode? arrowUp;
  final FocusNode? arrowDown;
  final FocusNode? arrowLeft;
  final FocusNode? arrowRight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final received = progress?.received ?? 0;
    final total = progress?.total;
    final percent = total != null && total > 0 ? received / total : null;
    final label = iconOnly
        ? null
        : (percent != null
            ? '${(percent * 100).toStringAsFixed(0)}%'
            : _formatBytes(received));
    return _GlassActionChip(
      onTap: onTap,
      tint: tint ?? cs.primary,
      compact: compact,
      expand: expand,
      label: label,
      focusNode: focusNode,
      arrowUp: arrowUp,
      arrowDown: arrowDown,
      arrowLeft: arrowLeft,
      arrowRight: arrowRight,
      iconWidget: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: percent,
          valueColor: AlwaysStoppedAnimation<Color>(
            tint ?? cs.primary,
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.16),
        ),
      ),
    );
  }
}

class _BuildCompleted extends StatelessWidget {
  const _BuildCompleted({
    required this.item,
    required this.compact,
    required this.iconOnly,
    required this.expand,
    required this.tint,
    required this.onTap,
    this.focusNode,
    this.arrowUp,
    this.arrowDown,
    this.arrowLeft,
    this.arrowRight,
  });
  final DownloadItem item;
  final bool compact;
  final bool iconOnly;
  final bool expand;
  final Color? tint;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusNode? arrowUp;
  final FocusNode? arrowDown;
  final FocusNode? arrowLeft;
  final FocusNode? arrowRight;

  @override
  Widget build(BuildContext context) {
    return _GlassActionChip(
      icon: Icons.download_done_rounded,
      label: iconOnly ? null : 'downloads.action.downloaded'.tr,
      tint: tint ?? Colors.greenAccent.shade400,
      compact: compact,
      expand: expand,
      onTap: onTap,
      focusNode: focusNode,
      arrowUp: arrowUp,
      arrowDown: arrowDown,
      arrowLeft: arrowLeft,
      arrowRight: arrowRight,
    );
  }
}

class _BuildFailed extends StatelessWidget {
  const _BuildFailed({
    required this.compact,
    required this.iconOnly,
    required this.expand,
    required this.tint,
    required this.onTap,
    this.focusNode,
    this.arrowUp,
    this.arrowDown,
    this.arrowLeft,
    this.arrowRight,
  });
  final bool compact;
  final bool iconOnly;
  final bool expand;
  final Color? tint;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusNode? arrowUp;
  final FocusNode? arrowDown;
  final FocusNode? arrowLeft;
  final FocusNode? arrowRight;

  @override
  Widget build(BuildContext context) {
    return _GlassActionChip(
      icon: Icons.refresh_rounded,
      label: iconOnly ? null : 'downloads.action.retry'.tr,
      tint: tint ?? Colors.redAccent,
      compact: compact,
      expand: expand,
      onTap: onTap,
      focusNode: focusNode,
      arrowUp: arrowUp,
      arrowDown: arrowDown,
      arrowLeft: arrowLeft,
      arrowRight: arrowRight,
    );
  }
}

// ─── Shared chip primitive ───────────────────────────────────────────────────

class _GlassActionChip extends StatelessWidget {
  const _GlassActionChip({
    this.icon,
    this.iconWidget,
    this.label,
    required this.tint,
    required this.onTap,
    required this.compact,
    this.expand = false,
    this.focusNode,
    this.arrowUp,
    this.arrowDown,
    this.arrowLeft,
    this.arrowRight,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final String? label;
  final Color tint;
  final FutureOr<void> Function() onTap;
  final bool compact;
  final bool expand;
  final FocusNode? focusNode;
  final FocusNode? arrowUp;
  final FocusNode? arrowDown;
  final FocusNode? arrowLeft;
  final FocusNode? arrowRight;

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 7)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    final iconSize = compact ? 18.0 : 20.0;
    final fontSize = compact ? 12.0 : 13.0;

    final chip = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.10),
          child: InkWell(
            onTap: () => onTap(),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: tint.withValues(alpha: 0.42),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconWidget ??
                      Icon(icon, size: iconSize, color: tint),
                  if (label != null) ...[
                    const SizedBox(width: 7),
                    Text(
                      label!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // TV/kumanda: D-pad odak çerçevesi + OK ile indirme aksiyonu (mobilde
    // tvDpadActivateWrap child'ı olduğu gibi döndürür).
    return tvDpadActivateWrap(
      context,
      onActivate: () => onTap(),
      borderRadius: 14,
      scaleOnFocus: 1.04,
      focusNode: focusNode,
      arrowUp: arrowUp,
      arrowDown: arrowDown,
      arrowLeft: arrowLeft,
      arrowRight: arrowRight,
      child: chip,
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

/// Helper format dış kullanım için (Downloads listesi vs.).
String formatDownloadBytes(int? bytes) =>
    bytes == null ? '' : _formatBytes(bytes);
