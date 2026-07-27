import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../domain/entities/channel.dart';
import '../../../../domain/entities/epg_entities.dart';
import '../../../../core/services/epg_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/services/playlist_cache_service.dart';
import '../../../../core/services/playlist_data_source.dart';
import '../../../../core/services/favorites_service.dart';
import '../../player/player_route_args.dart';

class ShowcaseUpcomingEpg extends StatefulWidget {
  const ShowcaseUpcomingEpg({super.key});

  @override
  State<ShowcaseUpcomingEpg> createState() => _ShowcaseUpcomingEpgState();
}

class _ShowcaseUpcomingEpgState extends State<ShowcaseUpcomingEpg> {
  Timer? _refreshTimer;
  Timer? _scrollTimer;
  List<_EpgEntry> _entries = [];
  Worker? _epgWorker;
  Worker? _cacheWorker;

  final ScrollController _scrollController = ScrollController();
  // Pixels per scroll step — küçük tutmak CPU'yu rahatlatır
  static const double _scrollStep = 0.5;
  // Scroll interval ms
  static const int _scrollIntervalMs = 40;


  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());

    if (Get.isRegistered<EpgService>()) {
      final epg = Get.find<EpgService>();
      _epgWorker = ever<int>(epg.loadGeneration, (_) {
        _refresh();
      });
    }

    if (Get.isRegistered<PlaylistCacheService>()) {
      final cache = Get.find<PlaylistCacheService>();
      _cacheWorker = ever(cache.result, (_) => _refresh());
    }

    // Auto-scroll başlat — biraz geciktirerek (widget render olduktan sonra)
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  void _startAutoScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(
      const Duration(milliseconds: _scrollIntervalMs),
      (_) {
        if (!mounted) return;
        if (!_scrollController.hasClients) return;

        final pos = _scrollController.position;
        final maxExtent = pos.maxScrollExtent;
        if (maxExtent <= 0) return;

        final current = pos.pixels;
        if (current >= maxExtent) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(current + _scrollStep);
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollTimer?.cancel();
    _epgWorker?.dispose();
    _cacheWorker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!Get.isRegistered<EpgService>() || !Get.isRegistered<PlaylistDataSource>()) return;
    final epg = Get.find<EpgService>();
    final ds = Get.find<PlaylistDataSource>();
    final fav = Get.find<FavoritesService>();

    final newEntries = <_EpgEntry>[];

    // Create pool with favorites first
    var pool = <Channel>[];

    // Get top channels from data source
    final channels = await ds.channelsForScan(limit: 800);

    if (fav.channelIds.isNotEmpty) {
      final byId = <int, Channel>{for (final c in channels) c.id: c};
      for (final id in fav.channelIds.reversed) {
        if (byId.containsKey(id)) {
          pool.add(byId[id]!);
        }
      }
    }

    pool.addAll(channels);

    // Deduplicate pool
    final seen = <int>{};
    final uniquePool = <Channel>[];
    for (final ch in pool) {
      if (seen.add(ch.id)) {
        uniquePool.add(ch);
      }
    }

    int foundCount = 0;
    for (final ch in uniquePool) {
      bool isNext = true;
      EpgProgramme? prog = epg.getNextProgrammeForLiveChannel(ch);
      if (prog == null) {
        prog = epg.getCurrentProgrammeForLiveChannel(ch);
        isNext = false;
      }

      if (prog != null) {
        newEntries.add(_EpgEntry(channel: ch, programme: prog, isNext: isNext));
        foundCount++;
        if (foundCount >= 12) break;
      }
    }

    // Sort by start time, earliest first
    newEntries.sort((a, b) => a.programme.start.compareTo(b.programme.start));

    if (newEntries.isEmpty) {
      if (kDebugMode) debugPrint(
          'ShowcaseUpcomingEpg: No upcoming EPG found. epg.xtreamProgrammeCount=${epg.xtreamProgrammeCount.value}, poolSize=${uniquePool.length}');
    } else {
      if (kDebugMode) debugPrint(
          'ShowcaseUpcomingEpg: Found ${newEntries.length} upcoming EPGs.');
    }

    if (mounted) {
      setState(() {
        _entries = newEntries.take(10).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'showcase.upcomingEpg.header'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notif) {
              if (notif is UserScrollNotification) {
                // Kullanıcı kaydırmaya başladığında durdur, bitirdiğinde yeniden başlat
                _scrollTimer?.cancel();
                _scrollTimer = null;
                
                // idle demek kullanıcı parmağını çekti / kaydırma bitti demek
                if (notif.direction == ScrollDirection.idle) {
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) _startAutoScroll();
                  });
                }
              }
              return false;
            },
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return _UpcomingEpgCard(entry: entry);
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _EpgEntry {
  final Channel channel;
  final EpgProgramme programme;
  final bool isNext;
  _EpgEntry({required this.channel, required this.programme, this.isNext = true});
}

class _UpcomingEpgCard extends StatefulWidget {
  const _UpcomingEpgCard({required this.entry});
  final _EpgEntry entry;

  @override
  State<_UpcomingEpgCard> createState() => _UpcomingEpgCardState();
}

class _UpcomingEpgCardState extends State<_UpcomingEpgCard> {
  Timer? _timer;
  Duration _diff = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateDiff();
    // Geri sayım — saniyede bir değil, 5 saniyede bir güncelle (CPU dostu)
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _updateDiff();
    });
  }

  @override
  void didUpdateWidget(covariant _UpcomingEpgCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.programme != widget.entry.programme) {
      _updateDiff();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateDiff() {
    final now = DateTime.now();
    if (widget.entry.isNext) {
      final start = widget.entry.programme.start;
      setState(() {
        _diff = start.isAfter(now) ? start.difference(now) : Duration.zero;
      });
    } else {
      final end = widget.entry.programme.end;
      setState(() {
        _diff = end.isAfter(now) ? end.difference(now) : Duration.zero;
      });
    }
  }

  String _formatDiff(Duration d) {
    if (d.inSeconds <= 0) {
      return widget.entry.isNext
          ? 'showcase.upcomingEpg.starting'.tr
          : 'showcase.upcomingEpg.ending'.tr;
    }
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h sa $m dk';
    } else if (m > 0) {
      return '$m dk $s sn';
    } else {
      return '$s sn';
    }
  }

  String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.entry.channel;
    final prog = widget.entry.programme;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Get.toNamed(AppRoutes.player, arguments: PlayerScreenArgs(channel: ch));
        },
        child: Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              // Logo section
              Container(
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: ch.logoUrl != null && ch.logoUrl!.trim().isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: ch.logoUrl!.trim(),
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.tv, color: Colors.white54),
                        )
                      : const Icon(Icons.tv, color: Colors.white54, size: 32),
                ),
              ),
              // Info section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.entry.isNext
                            ? 'showcase.upcomingEpg.next'.tr
                            : 'showcase.upcomingEpg.onAir'.tr,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prog.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatTime(prog.start)} - ${_formatTime(prog.end)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      // Countdown Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: primary.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, color: primary, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _formatDiff(_diff),
                              style: TextStyle(
                                color: primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
