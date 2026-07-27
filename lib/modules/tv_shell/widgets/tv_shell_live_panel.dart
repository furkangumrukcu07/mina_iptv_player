import 'dart:async';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/player/video_player_engine.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/epg_service.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../core/utils/epg_channel_display.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/epg_entities.dart';
import '../../../ui/auto_scroll_text.dart';
import '../../../ui/channel_list_epg_title.dart';
import '../../../ui/glass_mini_stream_preview.dart';
import '../../../ui/iptv_channel_logo.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../ui/tv_dpad_focus.dart' show TvDpadFocus, tvKeyIsBack;
import '../../channels/channels_controller.dart';
import '../../player/widgets/osd_stream_quality_badges.dart';
import '../tv_shell_controller.dart';
import 'tv_shell_interactive.dart';
import 'tv_shell_motion.dart';
import 'tv_shell_palette.dart';
import 'tv_shell_perf.dart';

const double _kEpgPxPerMinute = 5.0;
const double _kEpgPxPerMinuteCompact = 4.0;
const double _kHeroPadL = 12;
const int _kEpgHours = 4;
const int _kEpgHoursCompact = 2;

/// Canlı TV üst önizleme çerçevesi — temel kahraman alanı ölçeği.
const double _kLivePreviewScale = 1.57;

/// EPG yokken üst önizleme alanını genişlet.
const double _kLivePreviewNoEpgScale = 1.38;

bool _channelHasLiveEpg(EpgService? epg, Channel ch) {
  if (epg == null) return false;
  final p = epg.getCurrentProgrammeForLiveChannel(ch);
  return p != null && p.title.trim().isNotEmpty;
}

bool _listHasAnyLiveEpg(EpgService? epg, List<Channel> list) {
  if (epg == null) return false;
  final limit = list.length < 50 ? list.length : 50;
  for (var i = 0; i < limit; i++) {
    if (_channelHasLiveEpg(epg, list[i])) return true;
  }
  return false;
}

/// Önizleme genişliği ile kanal sütunu hizası (önizlemenin sağ kenarı).
class _TvShellLiveMetrics {
  const _TvShellLiveMetrics({
    required this.heroH,
    required this.previewW,
    required this.channelColW,
    required this.rowH,
    required this.timelineW,
    this.compact = false,
    this.epgHours = _kEpgHours,
    this.pxPerMin = _kEpgPxPerMinute,
  });

  final double heroH;
  final double previewW;
  final double channelColW;
  final double rowH;
  final double timelineW;

  factory _TvShellLiveMetrics.of(BuildContext context, {bool compact = false}) {
    final h = MediaQuery.sizeOf(context).height;
    if (compact) {
      // Önizleme öncelikli: üst kahraman alanı; kanal listesi kalan yüksekliği doldurur.
      final heroH = ((h * 0.18).clamp(120.0, 160.0) * _kLivePreviewScale)
          .clamp(188.4, 251.2);
      final previewW = (heroH * 16 / 9).clamp(334.9, 446.5);
      final channelColW = _kHeroPadL + previewW;
      const rowH = 44.0;
      final timelineW = _kEpgHoursCompact * 60 * _kEpgPxPerMinuteCompact;
      return _TvShellLiveMetrics(
        heroH: heroH,
        previewW: previewW,
        channelColW: channelColW,
        rowH: rowH,
        timelineW: timelineW,
        compact: true,
        epgHours: _kEpgHoursCompact,
        pxPerMin: _kEpgPxPerMinuteCompact,
      );
    }
    final heroH = ((h * 0.18).clamp(130.0, 170.0) * _kLivePreviewScale)
        .clamp(204.1, 266.9);
    final previewW = heroH * 16 / 9;
    final channelColW = _kHeroPadL + previewW;
    const rowH = 52.0;
    final timelineW = _kEpgHours * 60 * _kEpgPxPerMinute;
    return _TvShellLiveMetrics(
      heroH: heroH,
      previewW: previewW,
      channelColW: channelColW,
      rowH: rowH,
      timelineW: timelineW,
      compact: false,
      epgHours: _kEpgHours,
      pxPerMin: _kEpgPxPerMinute,
    );
  }

  final bool compact;
  final int epgHours;
  final double pxPerMin;
}

/// Canlı TV içerik alanı: üst önizleme + kanal listesi + EPG ızgarası.
class TvShellLivePanel extends StatefulWidget {
  const TvShellLivePanel({
    super.key,
    required this.shell,
    required this.channels,
    this.compact = false,
    this.browseMode = false,
  });

  final TvShellController shell;
  final ChannelsController channels;
  final bool compact;
  final bool browseMode;

  @override
  State<TvShellLivePanel> createState() => _TvShellLivePanelState();
}

class _TvShellLivePanelState extends State<TvShellLivePanel> {
  final _listScroll = ScrollController();
  final _epgVScroll = ScrollController();
  final _epgHScroll = ScrollController();
  final Map<int, FocusNode> _channelFocusNodes = {};
  final Map<String, FocusNode> _epgFocusNodes = {};
  bool _syncingScroll = false;
  int _focusedRowIndex = 0;
  bool _syncingSelectionFromFocus = false;
  bool _programmaticRowNav = false;
  int _rowNavGen = 0;
  int? _lastChannelNudgeMs;
  bool _didInitialTimeAlignment = false;
  bool _initialAlignCallbackPending = false;
  Timer? _tick;
  final ValueNotifier<int> _tickValue = ValueNotifier<int>(0);

  static const Duration _channelNudgeMinInterval = Duration(milliseconds: 120);

  FocusNode _channelFocusFor(int index) => _channelFocusNodes.putIfAbsent(
        index,
        () {
          final node = FocusNode(debugLabel: 'tvShellLiveChannel_$index');
          node.addListener(() => _onChannelRowFocusChanged(index, node));
          return node;
        },
      );

  FocusNode _epgFocusFor(EpgProgramme prog) {
    final key = '${prog.channelId}-${prog.start.millisecondsSinceEpoch}';
    return _epgFocusNodes.putIfAbsent(
      key,
      () => FocusNode(debugLabel: 'epgProgramme_$key'),
    );
  }

  FocusNode? _getVerticalEpgFocusTarget({
    required int currentRowIndex,
    required int direction,
    required EpgProgramme currentProg,
    required List<Channel> channelsList,
    required List<EpgProgramme> Function(Channel) windowProgrammesFor,
  }) {
    final nextRowIndex = currentRowIndex + direction;
    if (nextRowIndex < 0 || nextRowIndex >= channelsList.length) return null;
    final nextChannel = channelsList[nextRowIndex];
    final nextProgs = windowProgrammesFor(nextChannel);
    if (nextProgs.isEmpty) return null;

    EpgProgramme? bestMatch;
    double maxOverlapSeconds = -1.0;

    for (final p in nextProgs) {
      final overlapStart = p.start.isAfter(currentProg.start) ? p.start : currentProg.start;
      final overlapEnd = p.end.isBefore(currentProg.end) ? p.end : currentProg.end;
      if (overlapEnd.isAfter(overlapStart)) {
        final overlapSec = overlapEnd.difference(overlapStart).inSeconds.toDouble();
        if (overlapSec > maxOverlapSeconds) {
          maxOverlapSeconds = overlapSec;
          bestMatch = p;
        }
      }
    }

    EpgProgramme? liveProg;
    for (final p in nextProgs) {
      if (p.isLive) {
        liveProg = p;
        break;
      }
    }
    bestMatch ??= liveProg ?? (nextProgs.isNotEmpty ? nextProgs.first : null);

    if (bestMatch != null) {
      return _epgFocusFor(bestMatch);
    }
    return null;
  }

  int? _focusedRowIndexFromNodes() {
    for (final entry in _channelFocusNodes.entries) {
      if (entry.value.hasFocus) return entry.key;
    }
    return null;
  }

  void _syncChannelRowFocusState() {
    final nodeFocused = _focusedRowIndexFromNodes() != null;
    if (widget.browseMode && nodeFocused) {
      widget.channels.tvShellLiveBrowsingChannels.value = true;
    }
    final effective = nodeFocused ||
        (widget.browseMode &&
            widget.channels.tvShellLiveBrowsingChannels.value);
    if (widget.channels.tvShellChannelRowHasFocus.value != effective) {
      widget.channels.tvShellChannelRowHasFocus.value = effective;
    }
  }

  void _clearChannelRowFocus() {
    for (final n in _channelFocusNodes.values) {
      if (n.hasFocus) n.unfocus();
    }
    _syncChannelRowFocusState();
  }

  void _schedulePruneOutofViewport(int centerIndex, int listLength) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pruneOutofViewportFocusNodes(centerIndex, listLength);
    });
  }

  void _pruneOutofViewportFocusNodes(int centerIndex, int listLength) {
    // Genişletilmiş aralık: cacheExtent (40 satır) ile uyumlu olması için
    // ±45 aralığı tutulur. Bu, viewport dışına kısa süreli çıkışlarda
    // focus node'ların sürekli dispose/recreate edilmesini önler.
    final minKeep = (centerIndex - 45).clamp(0, listLength);
    final maxKeep = (centerIndex + 45).clamp(0, listLength);

    final channelKeys = _channelFocusNodes.keys.toList();
    for (final k in channelKeys) {
      if (k < minKeep || k > maxKeep) {
        final node = _channelFocusNodes.remove(k);
        if (node != null) {
          if (!node.hasFocus) {
            node.dispose();
          } else {
            _channelFocusNodes[k] = node;
          }
        }
      }
    }

    final list = widget.channels.filteredChannels;
    final Set<String> keepChannelIds = {};
    for (var i = minKeep; i < maxKeep && i < list.length; i++) {
      keepChannelIds.add(list[i].id.toString());
      final epgChanId = list[i].epgChannelId?.trim();
      if (epgChanId != null && epgChanId.isNotEmpty) {
        keepChannelIds.add(epgChanId);
      }
    }

    final epgKeys = _epgFocusNodes.keys.toList();
    for (final key in epgKeys) {
      final parts = key.split('-');
      if (parts.isNotEmpty) {
        final channelId = parts.first;
        if (!keepChannelIds.contains(channelId)) {
          final node = _epgFocusNodes.remove(key);
          if (node != null) {
            if (!node.hasFocus) {
              node.dispose();
            } else {
              _epgFocusNodes[key] = node;
            }
          }
        }
      }
    }
  }

  void _onChannelRowFocusChanged(int index, FocusNode node) {
    if (!mounted) return;
    if (!node.hasFocus) {
      _syncChannelRowFocusState();
      return;
    }
    if (widget.browseMode && _programmaticRowNav) {
      _syncChannelRowFocusState();
      return;
    }
    if (_focusedRowIndex == index) return;
    _focusedRowIndex = index;
    final list = widget.channels.filteredChannels;
    _schedulePruneOutofViewport(index, list.length);
    if (index < 0 || index >= list.length) return;
    if (!widget.browseMode) {
      final metrics = _TvShellLiveMetrics.of(context, compact: widget.compact);
      _scrollToRow(index, metrics.rowH);
    }
    if (_syncingSelectionFromFocus) return;
    final ch = list[index];
    if (widget.channels.selectedChannel.value?.id == ch.id) return;
    _syncingSelectionFromFocus = true;
    widget.channels.selectChannel(ch);
    _syncingSelectionFromFocus = false;
    _syncChannelRowFocusState();
  }

  @override
  void initState() {
    super.initState();
    widget.channels.attachTvChannelListScroll(_listScroll);
    widget.channels.registerTvShellChannelRowFocusHandler(_navigateToRow);
    widget.channels.registerTvShellChannelRowClearFocusHandler(
      _clearChannelRowFocus,
    );
    if (!widget.browseMode) {
      _scheduleResumeChannelRowFocus();
    }
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _tickValue.value++;
    });
  }

  int _resumeRowIndex(List<Channel> list) {
    final cur = widget.channels.selectedChannel.value;
    if (cur != null) {
      final i = list.indexWhere((c) => c.id == cur.id);
      if (i >= 0) return i;
    }
    return 0;
  }

  void _scheduleResumeChannelRowFocus({int attempt = 0}) {
    if (attempt > 32) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.browseMode) return;
      if (!widget.channels.tvShellLiveActive.value) return;
      if (_focusedRowIndexFromNodes() != null) return;
      final list = widget.channels.filteredChannels;
      if (list.isEmpty) {
        _scheduleResumeChannelRowFocus(attempt: attempt + 1);
        return;
      }
      _navigateToRow(_resumeRowIndex(list));
    });
  }

  DateTime _windowStart(DateTime now) {
    final s = now.subtract(const Duration(hours: 1));
    return DateTime(
        s.year, s.month, s.day, s.hour, s.minute - (s.minute % 30), 0);
  }

  void _scheduleInitialTimelineScroll({
    required double viewportW,
    required double channelColW,
    required DateTime windowStart,
    required DateTime nowTime,
    required double pxPerMinute,
  }) {
    if (_didInitialTimeAlignment || _initialAlignCallbackPending) return;
    _initialAlignCallbackPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialAlignCallbackPending = false;
      if (!mounted || !_epgHScroll.hasClients) return;
      _didInitialTimeAlignment = true;
      final x = nowTime.difference(windowStart).inMinutes * pxPerMinute;
      final target = x - viewportW * 0.38;
      final max = _epgHScroll.position.maxScrollExtent;
      _epgHScroll.jumpTo(target.clamp(0.0, max));
    });
  }

  @override
  void dispose() {
    widget.channels.registerTvShellChannelRowFocusHandler(null);
    widget.channels.registerTvShellChannelRowClearFocusHandler(null);
    widget.channels.detachTvChannelListScroll(_listScroll);
    for (final n in _channelFocusNodes.values) {
      n.dispose();
    }
    for (final n in _epgFocusNodes.values) {
      n.dispose();
    }
    _tick?.cancel();
    _tickValue.dispose();
    _listScroll.dispose();
    _epgVScroll.dispose();
    _epgHScroll.dispose();
    super.dispose();
  }

  int _browseRowIndex(List<Channel> list) {
    final focused = _focusedRowIndexFromNodes();
    if (focused != null && focused >= 0 && focused < list.length) {
      return focused;
    }
    return _focusedRowIndex.clamp(0, list.isEmpty ? 0 : list.length - 1);
  }

  void _nudgeBrowseRow(int delta) {
    if (!widget.browseMode) return;
    widget.shell.cancelLiveBrowseAutoFocusRetry();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastChannelNudgeMs != null &&
        now - _lastChannelNudgeMs! < _channelNudgeMinInterval.inMilliseconds) {
      return;
    }
    _lastChannelNudgeMs = now;
    final list = widget.channels.filteredChannels;
    if (list.isEmpty) return;
    final i = _browseRowIndex(list);
    final next = (i + delta).clamp(0, list.length - 1);
    if (next == i) return;
    _navigateToRow(next);
    if (_listScroll.hasClients) {
      final m = _listScroll.position;
      if (m.maxScrollExtent - m.pixels < 220) {
        widget.channels.onLiveChannelListNearScrollEnd();
      }
    }
  }

  void _navigateToRow(int index) {
    if (!mounted) return;
    final gen = ++_rowNavGen;
    final list = widget.channels.filteredChannels;
    if (list.isEmpty) {
      _focusedRowIndex = 0;
      return;
    }
    if (index < 0 || index >= list.length) return;

    if (widget.browseMode) {
      widget.channels.tvShellLiveBrowsingChannels.value = true;
    }
    _programmaticRowNav = true;
    _focusedRowIndex = index;
    widget.shell.liveChannelsFocusNode.unfocus();

    final metrics = _TvShellLiveMetrics.of(context, compact: widget.compact);
    _scrollToRow(index, metrics.rowH);

    final ch = list[index];
    final node = _channelFocusFor(index);

    void applySelectionIfNeeded() {
      if (widget.channels.selectedChannel.value?.id != ch.id) {
        _syncingSelectionFromFocus = true;
        widget.channels.selectChannel(ch);
        _syncingSelectionFromFocus = false;
      }
    }

    void finishNav() {
      applySelectionIfNeeded();
      _programmaticRowNav = false;
      _syncChannelRowFocusState();
    }

    void requestFocusOnce({int attempt = 0}) {
      if (!mounted || gen != _rowNavGen) {
        _programmaticRowNav = false;
        return;
      }
      if (attempt > 30) {
        finishNav();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || gen != _rowNavGen) {
          _programmaticRowNav = false;
          return;
        }
        if (node.canRequestFocus) {
          node.requestFocus();
        }
        if (node.hasFocus) {
          finishNav();
          return;
        }
        requestFocusOnce(attempt: attempt + 1);
      });
    }

    if (node.canRequestFocus) {
      node.requestFocus();
    }
    if (node.hasFocus) {
      finishNav();
    } else {
      // İlk denemeyi bir sonraki frame'de başlat — ListView'ın
      // scroll sonrası hedef satır widget'ını oluşturması için.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || gen != _rowNavGen) {
          _programmaticRowNav = false;
          return;
        }
        if (node.canRequestFocus) {
          node.requestFocus();
        }
        if (node.hasFocus) {
          finishNav();
          return;
        }
        requestFocusOnce();
      });
    }
  }

  void _scrollToRow(int index, double rowH) {
    if (!_listScroll.hasClients) return;
    _syncingScroll = true;
    try {
      final maxExt = _listScroll.position.maxScrollExtent;
      // itemExtent ile hizalı kaydır — kayık offset satırların üst üste binmesine yol açar.
      final target = (index * rowH).clamp(0.0, maxExt);
      if ((_listScroll.offset - target).abs() > 0.5) {
        _listScroll.jumpTo(target);
      }
      if (_epgVScroll.hasClients) {
        final epgTarget =
            target.clamp(0.0, _epgVScroll.position.maxScrollExtent);
        if ((_epgVScroll.offset - epgTarget).abs() > 0.5) {
          _epgVScroll.jumpTo(epgTarget);
        }
      }
    } finally {
      _syncingScroll = false;
    }
  }

  int _currentRowIndex(List<Channel> list) {
    final focused = _focusedRowIndexFromNodes();
    if (focused != null && focused >= 0 && focused < list.length) {
      return focused;
    }
    final cur = widget.channels.selectedChannel.value;
    if (cur != null) {
      final i = list.indexWhere((c) => c.id == cur.id);
      if (i >= 0) return i;
    }
    return _focusedRowIndex.clamp(0, list.isEmpty ? 0 : list.length - 1);
  }

  KeyEventResult _handlePanelVerticalNav(KeyEvent event) {
    if (_focusedRowIndexFromNodes() != null) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    final list = widget.channels.filteredChannels;
    if (list.isEmpty) return KeyEventResult.handled;
    final k = event.logicalKey;
    if (k != LogicalKeyboardKey.arrowUp && k != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    final delta = k == LogicalKeyboardKey.arrowUp ? -1 : 1;
    if (widget.browseMode) {
      _nudgeBrowseRow(delta);
    } else {
      final i = _currentRowIndex(list);
      final next = i + delta;
      if (next < 0 || next >= list.length) return KeyEventResult.handled;
      _navigateToRow(next);
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _handlePanelLeftNav(VoidCallback onLeft) {
    if (_focusedRowIndexFromNodes() != null) {
      return KeyEventResult.ignored;
    }
    onLeft();
    return KeyEventResult.handled;
  }

  KeyEventResult _handleBrowseChannelKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowUp) {
      _nudgeBrowseRow(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      _nudgeBrowseRow(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      widget.shell.onLeftFromLiveBrowse();
      return KeyEventResult.handled;
    }
    if (tvKeyIsBack(k)) {
      widget.shell.markBackHandled();
      widget.shell.onLeftFromLiveBrowse();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _syncVertical(double offset) {
    if (_syncingScroll) return;
    _syncingScroll = true;
    for (final sc in [_listScroll, _epgVScroll]) {
      if (sc.hasClients && (sc.offset - offset).abs() > 0.5) {
        sc.jumpTo(offset.clamp(0.0, sc.position.maxScrollExtent));
      }
    }
    _syncingScroll = false;
  }

  String _fmtClock(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildChannelEpgGrid({
    required BuildContext context,
    required TvShellPalette palette,
    required _TvShellLiveMetrics metrics,
    required List<Channel> list,
    required EpgService? epg,
    required bool touchScroll,
    required bool remoteNav,
    required bool showEpgColumn,
    required DateTime windowStart,
    required DateTime windowEnd,
    required double gridWidth,
    required double Function(DateTime) xAt,
    required List<EpgProgramme> Function(Channel) windowProgrammesFor,
    required DateTime now,
  }) {
    Widget channelList = SizedBox(
      width: showEpgColumn ? metrics.channelColW : null,
      child: ClipRect(
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollUpdateNotification && !_syncingScroll) {
              _syncVertical(n.metrics.pixels);
              final m = n.metrics;
              if (m.maxScrollExtent - m.pixels < 220) {
                widget.channels.onLiveChannelListNearScrollEnd();
              }
            }
            return false;
          },
          child: ListView.builder(
            controller: _listScroll,
            cacheExtent: remoteNav ? metrics.rowH * 40 : 250,
            physics: touchScroll
                ? const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  )
                : AppScrollPhysics.list(
                    context: context,
                  ),
            itemExtent: metrics.rowH,
            itemCount: list.length,
            itemBuilder: (context, index) {
              final ch = list[index];
              final prog = epg?.getCurrentProgrammeForLiveChannel(ch);
              final browse = widget.browseMode;
              final isSelected =
                  widget.channels.selectedChannel.value?.id == ch.id;

              final progs = windowProgrammesFor(ch);
              EpgProgramme? targetProg;
              for (final p in progs) {
                if (p.isLive) {
                  targetProg = p;
                  break;
                }
              }
              targetProg ??= progs.isNotEmpty ? progs.first : null;
              final dpadRightNode = (remoteNav && !browse && targetProg != null)
                  ? _epgFocusFor(targetProg)
                  : null;

              return RepaintBoundary(
                child: _ChannelListTile(
                  palette: palette,
                  channels: widget.channels,
                  channel: ch,
                  index: index,
                  rowH: metrics.rowH,
                  isSelected: isSelected,
                  programmeTitle: prog?.title,
                  programmeStart: prog?.start,
                  compact: widget.compact,
                  focusNode: remoteNav ? _channelFocusFor(index) : null,
                  focusable: remoteNav,
                  browseMode: browse,
                  onBrowseKey: browse ? _handleBrowseChannelKey : null,
                  dpadUp: remoteNav && !browse && index > 0
                      ? _channelFocusFor(index - 1)
                      : null,
                  dpadDown: remoteNav && !browse && index < list.length - 1
                      ? _channelFocusFor(index + 1)
                      : null,
                  dpadRight: dpadRightNode,
                  blockDpadUp: browse || index == 0,
                  blockDpadDown: browse || index >= list.length - 1,
                  onRemoteLeft: browse
                      ? widget.shell.onLeftFromLiveBrowse
                      : widget.shell.onLeftFromLiveContent,
                  onSelect: () {
                    // Mouse tıklama: focus'u da tıklanan kanala taşı.
                    if (remoteNav) {
                      _channelFocusFor(index).requestFocus();
                    }
                    if (widget.channels.selectedChannel.value?.id == ch.id) {
                      return;
                    }
                    widget.channels.selectChannel(ch);
                  },
                  onOpen: () {
                    if (browse) {
                      widget.channels.selectChannel(ch);
                      widget.shell.onCategoryChosen(
                        widget.channels.selectedCategoryId.value,
                        context: context,
                      );
                      return;
                    }
                    widget.channels.openChannel(ch);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    if (!widget.browseMode) {
      channelList = FocusTraversalGroup(child: channelList);
    }

    if (!showEpgColumn) {
      return channelList;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        channelList,
        Expanded(
          child: ExcludeFocus(
            excluding: false,
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, gridConstraints) {
                  _scheduleInitialTimelineScroll(
                    viewportW: gridConstraints.maxWidth,
                    channelColW: metrics.channelColW,
                    windowStart: windowStart,
                    nowTime: now,
                    pxPerMinute: metrics.pxPerMin,
                  );
                  return Scrollbar(
                    controller: _epgHScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _epgHScroll,
                      scrollDirection: Axis.horizontal,
                      physics: touchScroll
                          ? const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            )
                          : AppScrollPhysics.list(
                              context: context,
                            ),
                      child: SizedBox(
                        width: gridWidth,
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                Expanded(
                                  child:
                                      NotificationListener<ScrollNotification>(
                                    onNotification: (_) => false,
                                    child: ValueListenableBuilder<int>(
                                      valueListenable: _tickValue,
                                      builder: (context, tick, child) {
                                         return ListView.builder(
                                           controller: _epgVScroll,
                                           primary: false,
                                           cacheExtent: remoteNav ? metrics.rowH * 40 : 250,
                                           physics: touchScroll
                                              ? const BouncingScrollPhysics(
                                                  parent:
                                                      AlwaysScrollableScrollPhysics(),
                                                )
                                              : AppScrollPhysics.list(
                                                  context: context,
                                                ),
                                          padding:
                                              const EdgeInsets.only(right: 4),
                                          itemExtent: metrics.rowH,
                                          itemCount: list.length,
                                          itemBuilder: (context, index) {
                                            final ch = list[index];
                                            final windowProgrammes =
                                                windowProgrammesFor(ch);
                                            return SizedBox(
                                              height: metrics.rowH,
                                              child: _EpgProgrammeRow(
                                                palette: palette,
                                                channelId: ch.id,
                                                rowIndex: index,
                                                rowH: metrics.rowH,
                                                programmes:
                                                    windowProgrammes,
                                                gridWidth: gridWidth,
                                                xAt: xAt,
                                                now: now,
                                                channels: widget.channels,
                                                windowStart: windowStart,
                                                channelFocusNode: _channelFocusFor(index),
                                                epgFocusFor: _epgFocusFor,
                                                getVerticalEpgFocusTarget: _getVerticalEpgFocusTarget,
                                                channelsList: list,
                                                windowProgrammesFor: windowProgrammesFor,
                                                hScroll: _epgHScroll,
                                                channelColWidth: 0.0,
                                                onOpenChannel: () => widget.channels.openChannel(ch),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Current time vertical indicator
                            Positioned(
                              left: xAt(now),
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 2,
                                color: palette.accent.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _TvShellLiveMetrics.of(context, compact: widget.compact);

    return TvShellThemed(
      builder: (context, palette) {
        return Obx(() {
          widget.channels.playlistRevision.value;
          final list = widget.channels.filteredChannels;
          _schedulePruneOutofViewport(_focusedRowIndex, list.length);
          final touchScroll = tvShellTouchInputEnabled(context);
          final remoteNav = tvShellUsesRemoteNav(context);
          final epg =
              Get.isRegistered<EpgService>() ? Get.find<EpgService>() : null;
          final showEpgColumn = _listHasAnyLiveEpg(epg, list);

          final panel = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() {
                final selected = widget.channels.selectedChannel.value;
                EpgProgramme? heroProg;
                EpgProgramme? heroNextProg;
                if (selected != null && epg != null) {
                  heroProg = epg.getCurrentProgrammeForLiveChannel(selected);
                  if (heroProg != null && heroProg.title.trim().isEmpty) {
                    heroProg = null;
                  }
                  heroNextProg = epg.getNextProgrammeForLiveChannel(selected);
                  if (heroNextProg != null &&
                      heroNextProg.title.trim().isEmpty) {
                    heroNextProg = null;
                  }
                }
                final previewScale = showEpgColumn
                    ? _kLivePreviewScale
                    : _kLivePreviewNoEpgScale;
                final heroH =
                    (metrics.heroH / _kLivePreviewScale) * previewScale;
                final previewW = heroH * 16 / 9;
                final heroNow = DateTime.now();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GetBuilder<ChannelsController>(
                      id: 'preview',
                      builder: (c) => _HeroPanel(
                        key: ValueKey(selected?.id ?? 'no_channel'),
                        palette: palette,
                        heroH: heroH,
                        previewW: previewW,
                        channel: selected,
                        programme: heroProg,
                        nextProgramme: heroNextProg,
                        now: heroNow,
                        previewLoading: c.isPreviewLoading.value,
                        previewController: c.previewController,
                        mediaKitController: c.previewVideoMediaKit,
                        fmtClock: _fmtClock,
                        onPreviewTap: widget.browseMode || selected == null
                            ? null
                            : () => widget.channels.openChannel(selected),
                      ),
                    ),
                  ],
                );
              }),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 0.8,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.04),
                        Colors.white.withValues(alpha: 0.01),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: widget.compact ? 24 : 28,
                          child: Row(
                            children: [
                              SizedBox(
                                width: metrics.channelColW,
                                child: _ChannelColumnHeader(
                                  palette: palette,
                                  compact: widget.compact,
                                ),
                              ),
                              if (showEpgColumn)
                                Expanded(
                                  child: ExcludeFocus(
                                    excluding: remoteNav,
                                    child: AnimatedBuilder(
                                      animation: _epgHScroll,
                                      builder: (context, child) {
                                        final scrollOffset = _epgHScroll.hasClients
                                            ? _epgHScroll.offset
                                            : 0.0;
                                        return ValueListenableBuilder<int>(
                                          valueListenable: _tickValue,
                                          builder: (context, tick, child) {
                                            final now = DateTime.now();
                                            final w0 = _windowStart(now);
                                            final w1 =
                                                w0.add(Duration(hours: _kEpgHours));
                                            final gridW = w1.difference(w0).inMinutes *
                                                metrics.pxPerMin;
                                            double xAt(DateTime t) {
                                              return t.difference(w0).inMinutes *
                                                  metrics.pxPerMin;
                                            }
                                            return _EpgTimelineStrip(
                                              palette: palette,
                                              windowStart: w0,
                                              windowEnd: w1,
                                              gridWidth: gridW,
                                              stripHeight: widget.compact ? 24 : 28,
                                              xAt: xAt,
                                              now: now,
                                              scrollOffset: scrollOffset,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ClipRect(
                            child: ValueListenableBuilder<int>(
                              valueListenable: _tickValue,
                              builder: (context, tick, child) {
                                final now = DateTime.now();
                                final w0 = _windowStart(now);
                                final w1 = w0.add(Duration(hours: _kEpgHours));
                                final gridW =
                                    w1.difference(w0).inMinutes * metrics.pxPerMin;
                                double xAt(DateTime t) {
                                  return t.difference(w0).inMinutes * metrics.pxPerMin;
                                }
                                List<EpgProgramme> windowProgrammesFor(Channel ch) =>
                                    epg?.programmesInWindowForLiveChannel(ch, w0, w1) ??
                                    [];
                                return _buildChannelEpgGrid(
                                  context: context,
                                  palette: palette,
                                  metrics: metrics,
                                  list: list,
                                  epg: epg,
                                  touchScroll: touchScroll,
                                  remoteNav: remoteNav,
                                  showEpgColumn: showEpgColumn,
                                  windowStart: w0,
                                  windowEnd: w1,
                                  gridWidth: gridW,
                                  xAt: xAt,
                                  windowProgrammesFor: windowProgrammesFor,
                                  now: now,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );

          if (widget.browseMode) {
            return Focus(
              focusNode: widget.shell.liveChannelsFocusNode,
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                // Satır odağı yoksa ok tuşlarını panel düzeyinde yakala.
                if (_focusedRowIndexFromNodes() != null) {
                  return KeyEventResult.ignored;
                }
                final k = event.logicalKey;
                if (k == LogicalKeyboardKey.arrowUp ||
                    k == LogicalKeyboardKey.arrowDown) {
                  final channels = widget.channels.filteredChannels;
                  if (channels.isEmpty) return KeyEventResult.ignored;
                  final delta =
                      k == LogicalKeyboardKey.arrowUp ? -1 : 1;
                  _nudgeBrowseRow(delta);
                  return KeyEventResult.handled;
                }
                if (k == LogicalKeyboardKey.arrowLeft ||
                    tvKeyIsBack(k)) {
                  if (tvKeyIsBack(k)) {
                    widget.shell.markBackHandled();
                  }
                  widget.shell.onLeftFromLiveBrowse();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: panel,
            );
          }

          return Focus(
            focusNode: widget.shell.liveChannelsFocusNode,
            canRequestFocus: false,
            skipTraversal: remoteNav,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              if (tvKeyIsBack(event.logicalKey) && event is! KeyRepeatEvent) {
                widget.shell.onBack();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                return KeyEventResult.handled;
              }
              // Satır odağı yoksa dikey gezinmeyi panel düzeyinde devral.
              if (_focusedRowIndexFromNodes() == null) {
                final vertical = _handlePanelVerticalNav(event);
                if (vertical == KeyEventResult.handled) {
                  return vertical;
                }
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                  _focusedRowIndexFromNodes() == null &&
                  event is! KeyRepeatEvent) {
                return _handlePanelLeftNav(
                  widget.shell.onLeftFromLiveContent,
                );
              }
              return KeyEventResult.ignored;
            },
            child: panel,
          );
        });
      },
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    super.key,
    required this.palette,
    required this.heroH,
    required this.previewW,
    required this.channel,
    required this.programme,
    this.nextProgramme,
    required this.now,
    required this.previewLoading,
    required this.previewController,
    this.mediaKitController,
    required this.fmtClock,
    this.onPreviewTap,
  });

  final TvShellPalette palette;
  final double heroH;
  final double previewW;
  final Channel? channel;
  final EpgProgramme? programme;
  final EpgProgramme? nextProgramme;
  final DateTime now;
  final bool previewLoading;
  final dynamic previewController;
  final VideoController? mediaKitController;
  final String Function(DateTime) fmtClock;
  final VoidCallback? onPreviewTap;

  String _heroBodyText(EpgProgramme prog) {
    final desc = prog.description?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    final title = prog.title.trim();
    if (title.isNotEmpty) return title;
    return 'tvShell.live.noDescription'.tr;
  }

  String? _qualityTierHint() {
    // Önizleme oynatıcısından gerçek çözünürlük (varsa).
    final bp = previewController;
    if (bp is BetterPlayerController) {
      final asms = bp.betterPlayerAsmsTrack;
      final h = asms?.height ?? 0;
      final w = asms?.width ?? 0;
      if (h > 0) {
        final dim = h > w ? h : w;
        if (dim >= 2160) return '4K';
        if (dim >= 1080) return 'FHD';
        if (dim >= 720) return 'HD';
        return 'SD';
      }
      final sz = bp.videoPlayerController?.value.size;
      if (sz != null && sz.width > 0 && sz.height > 0) {
        final dim = sz.height > sz.width ? sz.height : sz.width;
        if (dim >= 2160) return '4K';
        if (dim >= 1080) return 'FHD';
        if (dim >= 720) return 'HD';
        return 'SD';
      }
    }
    final mk = mediaKitController?.player;
    if (mk != null) {
      final w = mk.state.width;
      final h = mk.state.height;
      if (w != null && h != null && w > 0 && h > 0) {
        final dim = h > w ? h : w;
        if (dim >= 2160) return '4K';
        if (dim >= 1080) return 'FHD';
        if (dim >= 720) return 'HD';
        return 'SD';
      }
    }
    final name = channel?.name;
    if (name == null || name.isEmpty) return null;
    return EpgChannelDisplay.qualityTierFromName(name);
  }

  @override
  Widget build(BuildContext context) {
    final compact = heroH < 200;
    final titleSize = compact ? 14.0 : 17.0;
    final progTitleSize = compact ? 12.5 : 15.0;
    final descLines = compact ? 2 : 4;
    final logoSize = compact ? 36.0 : 42.0;
    final hasEpg = programme != null;

    return SizedBox(
      height: heroH,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_kHeroPadL, 8, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.52),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.38),
                    blurRadius: 8,
                    spreadRadius: 1.2,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: GlassMiniStreamPreview(
                  maxHeight: heroH,
                  layoutWidth: hasEpg ? previewW : previewW * 1.12,
                  loading: previewLoading,
                  player: previewController,
                  mediaKitController: mediaKitController,
                  onSurfaceTap: onPreviewTap,
                ),
              ),
            ),
            SizedBox(width: hasEpg ? 12 : 16),
            Expanded(
              child: ClipRect(
                child: hasEpg
                    ? Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(
                          compact ? 8 : 10,
                          compact ? 6 : 8,
                          compact ? 8 : 10,
                          compact ? 8 : 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.13),
                            width: 0.85,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.075),
                              Colors.white.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (channel != null) ...[
                                  IptvChannelLogo(
                                    imageUrl: channel!.logoUrl ?? '',
                                    width: logoSize,
                                    height: logoSize,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    flex: 2,
                                    child: Text(
                                      EpgChannelDisplay.liveChannelName(
                                        channel!.name,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: palette.titleStyle(size: titleSize),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Text(
                                      '·',
                                      style: palette.mutedStyle(
                                        size: titleSize - 2,
                                      ),
                                    ),
                                  ),
                                ],
                                Flexible(
                                  flex: 3,
                                  child: Text(
                                    programme!.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: palette.titleStyle(
                                      size: progTitleSize,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${fmtClock(programme!.start)} – ${fmtClock(programme!.end)}',
                                  style: palette.mutedStyle(size: 11),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                          _ModernEpgProgressBar(
                            progress: programme!.progressAt(now),
                            accent: palette.progress,
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: SizedBox(
                              width: double.infinity,
                              child: AutoScrollVerticalText(
                                text: _heroBodyText(programme!),
                                maxVisibleLines: descLines,
                                startDelay: const Duration(milliseconds: 1500),
                                style: palette.mutedStyle(size: 9).copyWith(
                                      height: 1.3,
                                    ),
                              ),
                            ),
                          ),
                          if (nextProgramme != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${'tvShell.live.nextProgramme'.tr}: ${nextProgramme!.title.trim()} · ${fmtClock(nextProgramme!.start)} – ${fmtClock(nextProgramme!.end)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: palette.mutedStyle(size: 10).copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Obx(() {
                                  final settings =
                                      Get.find<AppSettingsService>();
                                  settings.livePlaybackEngine.value;
                                  settings.liveStreamFormat.value;
                                  final engine =
                                      VideoPlayerEngine.fromPlaybackEngineKind(
                                    settings.livePlaybackEngine.value,
                                  );
                                  final transport =
                                      settings.effectiveLiveStreamFormat
                                          .toUpperCase();
                                  final tier = _qualityTierHint();
                                  const fs = 8.5;
                                  const radius = 4.5;
                                  const hPad = 5.0;
                                  const vPad = 2.0;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (tier != null) ...[
                                        ...osdStreamQualityBadgeWidgets(
                                          resolutionTier: tier,
                                          hzLabel: null,
                                          fontSize: fs,
                                          borderRadius: radius,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      osdEngineBadge(
                                        engine: engine,
                                        fontSize: fs,
                                        radius: radius,
                                        hPad: hPad,
                                        vPad: vPad,
                                        portrait: true,
                                      ),
                                      const SizedBox(width: 4),
                                      osdTransportBadge(
                                        transportFormat: transport,
                                        fontSize: fs,
                                        radius: radius,
                                        hPad: hPad,
                                        vPad: vPad,
                                        portrait: true,
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ],
                          ],
                        ),
                      )
                    : channel == null
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'tvShell.live.pickChannel'.tr,
                              style: palette.mutedStyle(size: 12.5),
                            ),
                          )
                        : Row(
                            children: [
                              IptvChannelLogo(
                                imageUrl: channel!.logoUrl ?? '',
                                width: compact ? 72 : 96,
                                height: compact ? 72 : 96,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      channel!.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          palette.titleStyle(size: titleSize),
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
    );
  }
}

/// Narin, gradient dolgulu EPG ilerleme çubuğu (eski düz LinearProgress yerine).
class _ModernEpgProgressBar extends StatelessWidget {
  const _ModernEpgProgressBar({
    required this.progress,
    required this.accent,
  });

  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final fill = w * p;
        return SizedBox(
          height: 7,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 3.5,
                width: w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
              Container(
                height: 3.5,
                width: fill.clamp(0.0, w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.45),
                      accent,
                      accent.withValues(alpha: 0.92),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.4),
                      blurRadius: 5,
                      spreadRadius: 0.2,
                    ),
                  ],
                ),
              ),
              if (p > 0.02)
                Positioned(
                  left: (fill - 4).clamp(0.0, w - 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.95),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.85),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.55),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

extension on EpgProgramme {
  double progressAt(DateTime now) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    final elapsed = now.difference(start).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

class _ChannelColumnHeader extends StatelessWidget {
  const _ChannelColumnHeader({
    required this.palette,
    this.compact = false,
  });

  final TvShellPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateFormat = DateFormat.yMMMMd(Get.locale?.languageCode ?? 'tr');
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            'tvShell.live.channels'.tr,
            style: palette.mutedStyle(
              size: compact ? 10.5 : 12,
              weight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            dateFormat.format(now),
            style: palette.mutedStyle(
              size: compact ? 10.5 : 12,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EpgTimelineStrip extends StatelessWidget {
  const _EpgTimelineStrip({
    required this.palette,
    required this.windowStart,
    required this.windowEnd,
    required this.gridWidth,
    required this.stripHeight,
    required this.xAt,
    required this.now,
    required this.scrollOffset,
  });

  final TvShellPalette palette;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double gridWidth;
  final double stripHeight;
  final double Function(DateTime) xAt;
  final DateTime now;
  final double scrollOffset;

  @override
  Widget build(BuildContext context) {
    final times = <DateTime>[];
    var current = windowStart;
    while (current.isBefore(windowEnd)) {
      times.add(current);
      current = current.add(const Duration(minutes: 30));
    }

    return RepaintBoundary(
      child: Stack(
        children: [
          SizedBox(
            width: gridWidth,
            height: stripHeight,
          ),
          for (int i = 0; i < times.length; i++)
            Positioned(
              left: xAt(times[i]) - scrollOffset,
              top: 0,
              bottom: 0,
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '${times[i].hour.toString().padLeft(2, '0')}:${times[i].minute.toString().padLeft(2, '0')}',
                  style: palette.mutedStyle(
                    size: stripHeight * 0.35,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EpgProgrammeRow extends StatelessWidget {
  const _EpgProgrammeRow({
    required this.palette,
    required this.channelId,
    required this.rowIndex,
    required this.rowH,
    required this.programmes,
    required this.gridWidth,
    required this.xAt,
    required this.now,
    required this.channels,
    required this.windowStart,
    required this.channelFocusNode,
    required this.epgFocusFor,
    required this.getVerticalEpgFocusTarget,
    required this.channelsList,
    required this.windowProgrammesFor,
    required this.hScroll,
    required this.channelColWidth,
    required this.onOpenChannel,
  });

  final TvShellPalette palette;
  final int channelId;
  final int rowIndex;
  final double rowH;
  final List<EpgProgramme> programmes;
  final double gridWidth;
  final double Function(DateTime) xAt;
  final DateTime now;
  final ChannelsController channels;
  final DateTime windowStart;
  final FocusNode channelFocusNode;
  final FocusNode Function(EpgProgramme) epgFocusFor;
  final FocusNode? Function({
    required int currentRowIndex,
    required int direction,
    required EpgProgramme currentProg,
    required List<Channel> channelsList,
    required List<EpgProgramme> Function(Channel) windowProgrammesFor,
  }) getVerticalEpgFocusTarget;
  final List<Channel> channelsList;
  final List<EpgProgramme> Function(Channel) windowProgrammesFor;
  final ScrollController hScroll;
  final double channelColWidth;
  final VoidCallback onOpenChannel;

  @override
  Widget build(BuildContext context) {
    final isSelected = channels.selectedChannel.value?.id == channelId;

    return SizedBox(
      height: rowH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (int i = 0; i < programmes.length; i++)
            _buildProgrammeBox(i, programmes[i], isSelected),
        ],
      ),
    );
  }

  Widget _buildProgrammeBox(int index, EpgProgramme prog, bool isSelected) {
    final effectiveStart =
        prog.start.isBefore(windowStart) ? windowStart : prog.start;
    final startX = xAt(effectiveStart).clamp(0.0, gridWidth);
    final endX = xAt(prog.end).clamp(0.0, gridWidth);
    final width = (endX - startX).clamp(20.0, gridWidth - startX);
    final isLive = prog.start.isBefore(now) && prog.end.isAfter(now);

    final focusNode = epgFocusFor(prog);

    // D-pad Left target: if first program, go back to channel list row.
    // Otherwise go to previous program in the row.
    final dpadLeft = index == 0 ? channelFocusNode : epgFocusFor(programmes[index - 1]);

    // D-pad Right target: next program in the row.
    final dpadRight = index < programmes.length - 1 ? epgFocusFor(programmes[index + 1]) : null;

    // D-pad Up/Down targets calculated based on temporal overlap
    final dpadUp = getVerticalEpgFocusTarget(
      currentRowIndex: rowIndex,
      direction: -1,
      currentProg: prog,
      channelsList: channelsList,
      windowProgrammesFor: windowProgrammesFor,
    );

    final dpadDown = getVerticalEpgFocusTarget(
      currentRowIndex: rowIndex,
      direction: 1,
      currentProg: prog,
      channelsList: channelsList,
      windowProgrammesFor: windowProgrammesFor,
    );

    return Positioned(
      left: startX,
      top: 3,
      bottom: 3,
      width: width,
      child: _EpgProgrammeBox(
        palette: palette,
        prog: prog,
        isSelected: isSelected,
        isLive: isLive,
        startX: startX,
        width: width,
        focusNode: focusNode,
        dpadLeft: dpadLeft,
        dpadRight: dpadRight,
        dpadUp: dpadUp,
        dpadDown: dpadDown,
        blockDpadRight: index == programmes.length - 1,
        hScroll: hScroll,
        channelColWidth: channelColWidth,
        windowStart: windowStart,
        gridWidth: gridWidth,
        xAt: xAt,
        now: now,
        onSelectChannel: () {
          final ch = channelsList[rowIndex];
          if (channels.selectedChannel.value?.id != ch.id) {
            channels.selectChannel(ch);
          }
        },
        onOpenChannel: onOpenChannel,
      ),
    );
  }
}

class _EpgProgrammeBox extends StatefulWidget {
  const _EpgProgrammeBox({
    required this.palette,
    required this.prog,
    required this.isSelected,
    required this.isLive,
    required this.startX,
    required this.width,
    required this.focusNode,
    required this.dpadLeft,
    required this.dpadRight,
    required this.dpadUp,
    required this.dpadDown,
    required this.blockDpadRight,
    required this.hScroll,
    required this.channelColWidth,
    required this.windowStart,
    required this.gridWidth,
    required this.xAt,
    required this.now,
    required this.onSelectChannel,
    required this.onOpenChannel,
  });

  final TvShellPalette palette;
  final EpgProgramme prog;
  final bool isSelected;
  final bool isLive;
  final double startX;
  final double width;
  final FocusNode focusNode;
  final FocusNode? dpadLeft;
  final FocusNode? dpadRight;
  final FocusNode? dpadUp;
  final FocusNode? dpadDown;
  final bool blockDpadRight;
  final ScrollController hScroll;
  final double channelColWidth;
  final DateTime windowStart;
  final double gridWidth;
  final double Function(DateTime) xAt;
  final DateTime now;
  final VoidCallback onSelectChannel;
  final VoidCallback onOpenChannel;

  @override
  State<_EpgProgrammeBox> createState() => _EpgProgrammeBoxState();
}

class _EpgProgrammeBoxState extends State<_EpgProgrammeBox> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _EpgProgrammeBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
      if (widget.focusNode.hasFocus) {
        _ensureVisible();
        widget.onSelectChannel();
      }
    }
  }

  void _ensureVisible() {
    if (!widget.hScroll.hasClients) return;
    final scrollX = widget.hScroll.offset;
    final viewportW = widget.hScroll.position.viewportDimension;

    // Coordinate of the program block in the scrollable view
    final blockLeft = widget.channelColWidth + widget.startX;
    final blockRight = blockLeft + widget.width;

    // Visible range
    final visibleLeft = scrollX + widget.channelColWidth;
    final visibleRight = scrollX + viewportW;

    double? targetScrollX;
    if (blockLeft < visibleLeft) {
      targetScrollX = blockLeft - widget.channelColWidth;
    } else if (blockRight > visibleRight) {
      targetScrollX = blockRight - viewportW;
    }

    if (targetScrollX != null) {
      final max = widget.hScroll.position.maxScrollExtent;
      widget.hScroll.animateTo(
        targetScrollX.clamp(0.0, max),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = widget.focusNode.hasFocus;
    final baseTextStyle = Theme.of(context).textTheme.bodySmall;

    Widget box = AnimatedBuilder(
      animation: widget.hScroll,
      builder: (context, child) {
        final scrollX = widget.hScroll.hasClients ? widget.hScroll.offset : 0.0;
        final viewStartX = scrollX - widget.channelColWidth;

        double leftPadding = 0.0;
        if (viewStartX > widget.startX) {
          final maxPadding = (widget.width - 24.0).clamp(0.0, double.infinity);
          leftPadding = (viewStartX - widget.startX).clamp(0.0, maxPadding);
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: EdgeInsets.only(left: 6 + leftPadding, right: 4),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: isFocused
                ? widget.palette.accent.withValues(alpha: 0.4)
                : widget.isLive
                    ? widget.palette.accent.withValues(alpha: 0.25)
                    : widget.palette.ga.categoryRowFillIdle().withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isFocused
                  ? widget.palette.accent
                  : widget.isLive
                      ? widget.palette.accent.withValues(alpha: 0.6)
                      : widget.palette.ga.categoryRowBorderIdle().withValues(alpha: 0.3),
              width: isFocused
                  ? 1.8
                  : widget.isLive
                      ? 1.2
                      : 0.8,
            ),
          ),
          child: Text(
            widget.prog.title,
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: baseTextStyle?.copyWith(
                  color: widget.isSelected || isFocused
                      ? widget.palette.title
                      : widget.isLive
                          ? widget.palette.title
                          : widget.palette.body,
                  fontSize: 10,
                  fontWeight: widget.isLive || isFocused ? FontWeight.w700 : FontWeight.w600,
                  height: 1.1,
                ) ??
                TextStyle(
                  color: widget.isSelected || isFocused
                      ? widget.palette.title
                      : widget.isLive
                          ? widget.palette.title
                          : widget.palette.body,
                  fontSize: 10,
                  fontWeight: widget.isLive || isFocused ? FontWeight.w700 : FontWeight.w600,
                  height: 1.1,
                ),
          ),
        );
      },
    );

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final k = event.logicalKey;
        if (k == LogicalKeyboardKey.arrowLeft) {
          if (widget.dpadLeft != null) {
            widget.dpadLeft!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        if (k == LogicalKeyboardKey.arrowRight) {
          if (widget.dpadRight != null) {
            widget.dpadRight!.requestFocus();
            return KeyEventResult.handled;
          }
          if (widget.blockDpadRight) {
            return KeyEventResult.handled;
          }
        }
        if (k == LogicalKeyboardKey.arrowUp) {
          if (widget.dpadUp != null) {
            widget.dpadUp!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        if (k == LogicalKeyboardKey.arrowDown) {
          if (widget.dpadDown != null) {
            widget.dpadDown!.requestFocus();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) {
              widget.onOpenChannel();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: () {
            widget.focusNode.requestFocus();
          },
          child: box,
        ),
      ),
    );
  }
}

class _ChannelListTile extends StatefulWidget {
  const _ChannelListTile({
    required this.palette,
    required this.channels,
    required this.channel,
    required this.index,
    required this.rowH,
    required this.isSelected,
    required this.programmeTitle,
    required this.programmeStart,
    required this.onSelect,
    required this.onOpen,
    this.compact = false,
    this.focusable = true,
    this.focusNode,
    this.browseMode = false,
    this.onBrowseKey,
    this.dpadUp,
    this.dpadDown,
    this.dpadRight,
    this.onRemoteLeft,
    this.blockDpadUp = false,
    this.blockDpadDown = false,
  });

  final TvShellPalette palette;
  final ChannelsController channels;
  final Channel channel;
  final int index;
  final double rowH;
  final bool isSelected;
  final String? programmeTitle;
  final DateTime? programmeStart;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final bool compact;
  final bool focusable;
  final FocusNode? focusNode;
  final bool browseMode;
  final KeyEventResult Function(KeyEvent event)? onBrowseKey;
  final FocusNode? dpadUp;
  final FocusNode? dpadDown;
  final FocusNode? dpadRight;
  final VoidCallback? onRemoteLeft;
  final bool blockDpadUp;
  final bool blockDpadDown;

  @override
  State<_ChannelListTile> createState() => _ChannelListTileState();
}

class _ChannelListTileState extends State<_ChannelListTile> {
  FocusNode? _ownFocus;

  FocusNode get _focusNode => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(covariant _ChannelListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_handleFocus);
      _focusNode.addListener(_handleFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final remote = tvShellUsesRemoteNav(context);
    final isFocused = _focusNode.hasFocus;
    final textEmphasis = widget.isSelected || isFocused;
    final row = TvShellAnimBox(
      duration: remote ? Duration.zero : TvShellMotion.rowSelectDuration,
      curve: TvShellMotion.panelCurve,
      decoration: widget.palette.channelRowDecoration(
        selected: widget.isSelected,
        focused: isFocused,
      ),
      child: SizedBox(
        height: widget.rowH,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${widget.index + 1}',
                  style: widget.palette.mutedStyle(
                    size: 10.5,
                    weight: FontWeight.w600,
                  ).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              IptvChannelLogo(
                imageUrl: widget.channel.logoUrl ?? '',
                width: widget.compact ? 24 : 28,
                height: widget.compact ? 24 : 28,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ChannelListEpgTitleLine(
                    channelName: widget.channel.name,
                    programmeTitle: widget.programmeTitle,
                    programmeStart: widget.programmeStart,
                    marqueeEnabled: false,
                    highlighted: textEmphasis,
                    channelFontSize: widget.compact ? 11.5 : 12.5,
                    programmeFontSize: widget.compact ? 9.5 : 10,
                    textColor: widget.palette.navRowTextColor(textEmphasis),
                    subtitleColor: widget.palette.navRowTextColor(textEmphasis).withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final touchSurface = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onSelect,
        onDoubleTap: widget.onOpen,
        splashColor: widget.palette.accent.withValues(alpha: 0.14),
        highlightColor: widget.palette.accent.withValues(alpha: 0.08),
        child: row,
      ),
    );

    if (!remote || !widget.focusable) return touchSurface;

    if (widget.browseMode && widget.onBrowseKey != null) {
      return TvDpadFocus(
        focusNode: _focusNode,
        onActivate: widget.onOpen,
        borderRadius: 6,
        ensureVisibleOnFocus: false,
        enableFocusScale: false,
        tvFocusStyle: true,
        scaleOnFocus: 1.0,
        showFocusRing: false,
        blockUp: true,
        blockDown: true,
        blockLeft: true,
        blockRight: true,
        onKeyEvent: widget.onBrowseKey,
        child: touchSurface,
      );
    }

    return TvShellInteractive(
      focusNode: _focusNode,
      onPressed: widget.onOpen,
      onRemoteLeft: widget.onRemoteLeft,
      treatBackAsRemoteLeft: widget.onRemoteLeft != null,
      dpadUp: widget.dpadUp,
      dpadDown: widget.dpadDown,
      dpadRight: widget.dpadRight,
      blockDpadUp: widget.blockDpadUp,
      blockDpadDown: widget.blockDpadDown,
      ensureVisibleOnFocus: false,
      borderRadius: 6,
      showFocusRing: true,
      scaleOnFocus: TvShellPerf.defaultFocusScale,
      child: touchSurface,
    );
  }
}
