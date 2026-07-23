import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_image_cache_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/download_service.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/download_item.dart';
import '../../modules/player/player_route_args.dart';
import '../home/widgets/download_button.dart';
import '../home/widgets/recommended_films_glass.dart';
import '../../ui/tv_dpad_focus.dart';

/// İndirilenler listesi — aktif progress + tamamlananlar. Tek ekran,
/// "Geri" ile detay sayfasına döner. Browse view'ın 3-sekme yapısına
/// karışmaz; ayrı route (`/downloads`).
class DownloadsView extends StatelessWidget {
  const DownloadsView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<DownloadService>();
    final remote = remoteNavForScreenLayout(
      context,
      Get.find<AppSettingsService>().layoutMode.value,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Get.back<void>();
      },
      child: Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: remote
            ? TvIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: () => Get.back(),
                tooltip: 'common.back'.tr,
                autofocus: true,
              )
            : IconButton(
                icon:
                    const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Get.back(),
              ),
        title: Text(
          'downloads.screen.title'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final list = svc.sortedByRecent;
          if (list.isEmpty) {
            return _EmptyState();
          }
          final active = list.where((e) => e.isActive).toList(growable: false);
          final done = list
              .where((e) => e.isCompleted || e.isFailed)
              .toList(growable: false);
          return CustomScrollView(
            slivers: [
              if (active.isNotEmpty) ...[
                _SectionHeader('downloads.section.active'.tr, active.length),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (c, i) => _DownloadRow(item: active[i], svc: svc),
                    childCount: active.length,
                  ),
                ),
              ],
              if (done.isNotEmpty) ...[
                _SectionHeader('downloads.section.done'.tr, done.length),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (c, i) => _DownloadRow(item: done[i], svc: svc),
                    childCount: done.length,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        }),
      ),
    ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_for_offline_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.32),
            ),
            const SizedBox(height: 16),
            Text(
              'downloads.empty.title'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'downloads.empty.body'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text, this.count);
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({required this.item, required this.svc});
  final DownloadItem item;
  final DownloadService svc;

  @override
  Widget build(BuildContext context) {
    final received = svc.progress[item.id]?.received ?? 0;
    final total = svc.progress[item.id]?.total;
    final percent = total != null && total > 0 ? received / total : null;

    final onPlay = item.isCompleted ? () => _play(item) : null;
    final row = InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPlay,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 88,
                  child: item.posterUrl != null && item.posterUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.posterUrl!,
                          cacheKey:
                              AppImageCacheService.cacheKeyFor(item.posterUrl!),
                          cacheManager: AppImageCacheService.manager,
                          fit: BoxFit.cover,
                          memCacheWidth: 128,
                          memCacheHeight: 176,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.white.withValues(alpha: 0.08),
                            child: const Icon(
                              Icons.movie_outlined,
                              color: Colors.white38,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.white.withValues(alpha: 0.08),
                          child: Icon(
                            item.kind == DownloadKind.episode
                                ? Icons.live_tv_outlined
                                : Icons.movie_outlined,
                            color: Colors.white38,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    _StatusLine(
                      item: item,
                      percent: percent,
                      received: received,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RowActionButton(item: item, svc: svc),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: RecommendedFilmsGlassPanel(
        padding: const EdgeInsets.all(10),
        child: onPlay != null
            ? tvDpadActivateWrap(
                context,
                onActivate: onPlay,
                borderRadius: 14,
                child: row,
              )
            : row,
      ),
    );
  }

  Future<void> _play(DownloadItem item) async {
    final f = File(item.localPath);
    if (!await f.exists()) {
      Get.snackbar('downloads.error.fileMissing'.tr, item.localPath);
      return;
    }
    Get.toNamed(
      AppRoutes.player,
      arguments: PlayerScreenArgs(
        channel: Channel(
          id: item.id.hashCode,
          name: item.title,
          streamUrl: item.localPath,
          categoryId: 0,
          logoUrl: item.posterUrl,
        ),
        // VOD UI (seek bar, progress) için movieBrowseTape verilmesi
        // yeterli — boş liste de işe yarar; isMovie=true olur.
        movieBrowseTape: const <Channel>[],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.item,
    required this.percent,
    required this.received,
  });
  final DownloadItem item;
  final double? percent;
  final int received;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (item.status) {
      case DownloadStatus.downloading:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              percent != null
                  ? '${(percent! * 100).toStringAsFixed(0)}% · ${formatDownloadBytes(received)}'
                  : formatDownloadBytes(received),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        );
      case DownloadStatus.queued:
        return Text(
          'downloads.status.queued'.tr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        );
      case DownloadStatus.completed:
        return Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: Colors.greenAccent.shade400,
            ),
            const SizedBox(width: 4),
            Text(
              formatDownloadBytes(item.sizeBytes),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        );
      case DownloadStatus.failed:
        return Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 14,
              color: Colors.redAccent,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'downloads.status.failed'.tr,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      case DownloadStatus.cancelled:
        return Text(
          'downloads.status.cancelled'.tr,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        );
    }
  }
}

class _RowActionButton extends StatelessWidget {
  const _RowActionButton({required this.item, required this.svc});
  final DownloadItem item;
  final DownloadService svc;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color tint;
    VoidCallback onTap;
    switch (item.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.queued:
        icon = Icons.close_rounded;
        tint = Colors.white.withValues(alpha: 0.9);
        onTap = () => svc.cancel(item.id);
        break;
      case DownloadStatus.failed:
        icon = Icons.refresh_rounded;
        tint = Colors.amber;
        onTap = () => svc.retry(item.id);
        break;
      case DownloadStatus.completed:
      case DownloadStatus.cancelled:
        icon = Icons.delete_outline_rounded;
        tint = Colors.redAccent.withValues(alpha: 0.85);
        onTap = () => svc.deleteItem(item.id);
        break;
    }
    final button = Material(
      color: Colors.white.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: tint, size: 20),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: tvDpadActivateWrap(
          context,
          onActivate: onTap,
          borderRadius: 10,
          child: button,
        ),
      ),
    );
  }
}
