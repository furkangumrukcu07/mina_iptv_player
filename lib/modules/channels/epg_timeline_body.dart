import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/utils/epg_channel_display.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/theme/app_performance.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../core/theme/glass_appearance.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/epg_entities.dart';
import '../player/player_controller.dart';
import 'channels_controller.dart';
import '../../ui/iptv_channel_logo.dart';

const double _kPxPerMinute = 4.0;
const int _kWindowHours = 12;
/// Kanal adı sütunu (logo + saat + isim); dikey/yatay kompakt.
const double _kNameColPortrait = 84; // Dikey modda daha fazla yer açın
const double _kNameColLandscape = 108;
const double _kTimelineStripH = 40;
/// Yatay EPG: referans düzeni — daha geniş kanal satırı.
const double _kRowLandscape = 52;
final Map<String, Timer> _epgEnsureVisibleDebounceTimers = <String, Timer>{};

void _scheduleEpgEnsureVisible(
  BuildContext context, {
  required String debounceKey,
  required double alignment,
  required Duration duration,
  Duration debounce = const Duration(milliseconds: 70),
}) {
  _epgEnsureVisibleDebounceTimers[debounceKey]?.cancel();
  _epgEnsureVisibleDebounceTimers[debounceKey] = Timer(debounce, () {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: alignment,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    });
  });
}

bool _epgIsPortrait(BuildContext context) =>
    MediaQuery.orientationOf(context) == Orientation.portrait;

double _epgNameColW(BuildContext context) =>
    _epgIsPortrait(context) ? _kNameColPortrait : _kNameColLandscape;

double _epgRowH(BuildContext context) {
  if (_epgIsPortrait(context)) {
    // Portre modunda, 7 kanalı sığdırmak için dinamik yükseklik hesaplayın
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    // SafeArea, başlık ve zaman şeridi yüksekliğini çıkarın
    // Bu değerler sabit kabul edilirse veya dinamik olarak hesaplanabilirse daha iyi olur
    final headerHeight = 60.0; // Tahmini başlık yüksekliği
    final epgHeroHeight = _epgHeroHeight(context); // Dinamik olarak hesaplanan Hero panel yüksekliği
    final timelineStripHeight = _kTimelineStripH + 4 + 4; // Zaman şeridi + üst/alt dolgu
    final bottomPadding = 12.0; // ListView padding bottom

    final availableHeight = screenHeight -
        mediaQuery.padding.top -
        mediaQuery.padding.bottom -
        headerHeight -
        epgHeroHeight -
        timelineStripHeight -
        bottomPadding;

    // Yaklaşık 7 kanal için satır yüksekliği
    return (availableHeight / 7).clamp(48.0, 70.0); // Minimum ve maksimum değeri belirleyin
  }
  return _kRowLandscape;
}

double _epgHeroHeight(BuildContext context) {
  if (MediaQuery.orientationOf(context) == Orientation.portrait) {
    return 238;
  }
  // Yatay: üst paneli dar tut; zaman şeridi + kanal ızgarasına daha çok yükseklik kalır.
  final h = MediaQuery.sizeOf(context).height;
  return (h * 0.13).clamp(112.0, 132.0);
}

EpgProgramme? _epgResolveHeroProgramme(
  EpgService epg,
  Channel ch, {
  required int? pickChannelId,
  required DateTime? pickProgStart,
  required String? pickProgTitle,
}) {
  if (pickChannelId == ch.id && pickProgStart != null && pickProgTitle != null) {
    for (final p in epg.getFullDayProgrammesForLiveChannel(ch)) {
      if (p.start == pickProgStart && p.title == pickProgTitle) return p;
    }
  }
  return epg.getCurrentProgrammeForLiveChannel(ch);
}

String? _categoryNameFromCategories(List<ChannelCategory> cats, Channel ch) {
  for (final c in cats) {
    if (c.id == ch.categoryId) return c.name;
  }
  return null;
}

bool _epgTvCenterActivateKey(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.select ||
    k == LogicalKeyboardKey.enter ||
    k == LogicalKeyboardKey.numpadEnter ||
    k == LogicalKeyboardKey.space ||
    k == LogicalKeyboardKey.gameButtonSelect;

bool _epgProgrammeHasContent(EpgProgramme p) {
  final t = p.title.trim();
  if (t.isEmpty) return false;
  final lower = t.toLowerCase();
  const placeholders = {
    'no information',
    'bilgi yok',
    'to be announced',
    'tba',
    'n/a',
    'unknown',
    'no info',
  };
  return !placeholders.contains(lower);
}

/// Tam ekran: üstte cam çerçeveli detay + önizleme, altta zaman şeridi ve ızgara.
class ChannelsEpgTimelineScaffold extends StatelessWidget {
  const ChannelsEpgTimelineScaffold({super.key, required this.controller});

  final ChannelsController controller;

  @override
  Widget build(BuildContext context) {
    // Kanallar sekmesindeki EPG ile aynı görsel bağlam: tema arka planı + gradient
    // (önceden yalnızca route düz siyahtı; “farklı EPG” algısı bundan kaynaklanıyordu).
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Obx(() {
            final settings = Get.find<AppSettingsService>();
            final themeLabel = settings.themeLabel.value;
            final reduce = settings.reduceBlur.value;
            final mode = settings.layoutMode.value;
            final sharpBg = remoteNavForScreenLayout(context, mode);
            const sigma = 6.5;
            final skipBgBlur = reduce ||
                sharpBg ||
                GlassAppearance.fromLabel(themeLabel)
                    .usesSyntheticGlassSurface;
            final bgDecode = AppTheme.homeBackgroundImageDecodeParams(
              context,
              themeLabel,
              isTvLayout: mode == AppLayoutMode.tv,
            );
            final scaled = Transform.scale(
              scale: bgDecode.zoom,
              child: Image.asset(
                AppTheme.homeBackgroundAsset(
                  context,
                  themeLabel: themeLabel,
                ),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: bgDecode.cacheWidth,
                cacheHeight: bgDecode.cacheHeight,
                filterQuality: AppTheme.homeBackgroundFilterQuality(
                  isTvLayout: mode == AppLayoutMode.tv,
                  themeLabel: themeLabel,
                ),
              ),
            );
            if (skipBgBlur) {
              return scaled;
            }
            return ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: scaled,
            );
          }),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.42),
                  Colors.black.withValues(alpha: 0.68),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 12, 4),
                  child: Row(
                    children: [
                      _EpgGlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'channels.epgTimeline.title'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.55),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ChannelsEpgTimelineBody(controller: controller),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EpgGlassIconButton extends StatelessWidget {
  const _EpgGlassIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = Get.find<AppSettingsService>();
      final mode = settings.layoutMode.value;
      final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
      final tvBlur = mode == AppLayoutMode.tv;
      final dpad = remoteNavForScreenLayout(context, mode);
      final sigma = AppPerformance.glassSigma(
        settings,
        zeroOnTvLayout: true,
        isTvLayout: tvBlur,
        fullSigma: 10,
        reducedSigma: 6,
      );
      final r = BorderRadius.circular(14);

      Widget glassCore(bool focused) {
        final child = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: r,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        );
        final box = Container(
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(
              color: dpad && focused
                  ? Colors.white.withValues(alpha: 0.88)
                  : ga.popupBorderColor,
              width: dpad && focused ? 2.2 : 1,
            ),
            gradient: LinearGradient(colors: ga.popupGradientColors),
            boxShadow: [
              BoxShadow(
                color: ga.popupShadowColor,
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
        return ClipRRect(
          borderRadius: r,
          child: sigma <= 0
              ? box
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: box,
                ),
        );
      }

      if (!dpad) {
        return glassCore(false);
      }
      return StatefulBuilder(
        builder: (context, setSt) {
          return Focus(
            canRequestFocus: true,
            skipTraversal: false,
            descendantsAreFocusable: false,
            onFocusChange: (_) => setSt(() {}),
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (_epgTvCenterActivateKey(event.logicalKey)) {
                onPressed();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Builder(
              builder: (ctx) => glassCore(Focus.of(ctx).hasFocus),
            ),
          );
        },
      );
    });
  }
}

/// TV rehberi gövdesi: üst kahraman paneli + zaman bandı + kanal/program ızgarası.
class ChannelsEpgTimelineBody extends StatefulWidget {
  const ChannelsEpgTimelineBody({super.key, required this.controller});

  final ChannelsController controller;

  @override
  State<ChannelsEpgTimelineBody> createState() => _ChannelsEpgTimelineBodyState();
}

class _ChannelsEpgTimelineBodyState extends State<ChannelsEpgTimelineBody> {
  late ScrollController _hScroll;
  late ScrollController _vScroll;
  Timer? _tick;

  /// EPG zamanlayıcısı için optimize edilmiş ValueNotifier
  /// setState() yerine kullanılarak rebuild kapsamı sadece liste ile sınırlanır
  final ValueNotifier<int> _tickValue = ValueNotifier<int>(0);

  /// İlk açılışta “şimdi” çizgisini görünür alana getir (bir kez).
  bool _didInitialTimeAlignment = false;
  bool _initialAlignCallbackPending = false;

  /// Kullanıcının seçtiği program (ızgara); null iken kanal + “şimdiki” özetlenir.
  int? _pickChannelId;
  DateTime? _pickProgStart;
  String? _pickProgTitle;

  void _scheduleInitialTimelineScroll({
    required double viewportW,
    required double nameColW,
    required DateTime windowStart,
    required DateTime nowTime,
  }) {
    if (_didInitialTimeAlignment || _initialAlignCallbackPending) return;
    _initialAlignCallbackPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialAlignCallbackPending = false;
      if (!mounted || !_hScroll.hasClients) return;
      _didInitialTimeAlignment = true;
      final x = nowTime.difference(windowStart).inMinutes * _kPxPerMinute;
      final needleX = nameColW + x;
      final target = needleX - viewportW * 0.38;
      final max = _hScroll.position.maxScrollExtent;
      _hScroll.jumpTo(target.clamp(0.0, max));
    });
  }

  @override
  void initState() {
    super.initState();
    _hScroll = ScrollController();
    _vScroll = ScrollController();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      // setState() yerine ValueNotifier kullan - rebuild kapsamını sınırla
      if (mounted) _tickValue.value++;
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tickValue.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  DateTime _windowStart(DateTime now) {
    final s = now.subtract(const Duration(hours: 1));
    return DateTime(s.year, s.month, s.day, s.hour, s.minute - (s.minute % 30), 0);
  }

  String _fmtHm(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Channel _resolvedChannel(List<Channel> channels) {
    if (channels.isEmpty) {
      throw StateError('empty');
    }
    if (_pickChannelId != null) {
      for (final c in channels) {
        if (c.id == _pickChannelId) return c;
      }
    }
    return channels.first;
  }

  void _selectProgramme(Channel ch, EpgProgramme p) {
    setState(() {
      _pickChannelId = ch.id;
      _pickProgStart = p.start;
      _pickProgTitle = p.title;
    });
  }

  void _onChannelCellFocused(Channel ch) {
    setState(() {
      _pickChannelId = ch.id;
      _pickProgStart = null;
      _pickProgTitle = null;
    });
  }

  bool _isPicked(Channel ch, EpgProgramme p) {
    return _pickChannelId == ch.id &&
        _pickProgStart == p.start &&
        _pickProgTitle == p.title;
  }

  /// Sol sütunda gösterilecek yayın başlangıç saati (şimdiki veya penceredeki ilk).
  String _programmeStartLabelForRow(
    Channel ch,
    EpgService epg,
    List<EpgProgramme> windowProgrammes,
  ) {
    final cur = epg.getCurrentProgrammeForLiveChannel(ch);
    if (cur != null) return _fmtHm(cur.start);
    if (windowProgrammes.isNotEmpty) return _fmtHm(windowProgrammes.first.start);
    return '--:--';
  }

  @override
  Widget build(BuildContext context) {
    final epg = Get.find<EpgService>();
    return Obx(() {
      widget.controller.now.value;
      epg.loadGeneration.value;
      epg.isLoading.value;

      final now = DateTime.now();
      final w0 = _windowStart(now);
      final w1 = w0.add(Duration(hours: _kWindowHours));
      final gridW = w1.difference(w0).inMinutes * _kPxPerMinute;

      final raw = widget.controller.filteredChannels;
      final channels = List<Channel>.from(raw);
      // [PERF] Window programlarını burada (tüm kanallar için) eager hesaplamak
      // "Tüm kanallar" seçiliyken binlerce kanal × her `now` (30 sn) tetikte
      // ana thread'i bloke ediyordu. Artık her satır kendi programını
      // itemBuilder içinde lazy çözer; EpgService zaten sonucu cache'liyor.
      List<EpgProgramme> windowProgrammesFor(Channel ch) =>
          epg.programmesInWindowForLiveChannel(ch, w0, w1);

      if (channels.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'channels.empty'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
            ),
          ),
        );
      }

      final selCh = _resolvedChannel(channels);
      final heroProg = _epgResolveHeroProgramme(
        epg,
        selCh,
        pickChannelId: _pickChannelId,
        pickProgStart: _pickProgStart,
        pickProgTitle: _pickProgTitle,
      );
      final cache = Get.find<PlaylistCacheService>();
      final rawUrl = (cache.sourceUrl.value ?? '').trim();
      final playlistTitle = rawUrl.isEmpty
          ? 'channels.epgTimeline.playlistSource'.tr
          : (rawUrl.length > 42 ? '${rawUrl.substring(0, 39)}…' : rawUrl);
      final catName =
          _categoryNameFromCategories(widget.controller.categories, selCh);
      final app = Get.find<AppSettingsService>();
      final selList = widget.controller.selectedChannel.value;
      final previewOk =
          app.streamPreviewEnabled.value && selList?.id == selCh.id;
      BetterPlayerController? heroPlayerBetter;
      if (!_epgIsPortrait(context) && Get.isRegistered<PlayerController>()) {
        final pc = Get.find<PlayerController>();
        pc.channel.value;
        pc.isBusy.value;
        final cur = pc.channel.value;
        final u = cur.streamUrl.toLowerCase();
        final vod = u.contains('/movie/') || u.contains('/series/');
        if (!vod &&
            cur.id == selCh.id &&
            pc.better != null &&
            !pc.isBusy.value) {
          heroPlayerBetter = pc.better;
        }
      }
      final heroPreviewCtrl =
          previewOk ? widget.controller.previewController : heroPlayerBetter;
      final heroUseVideo = previewOk || heroPlayerBetter != null;
      final heroPreviewLoading =
          previewOk && widget.controller.isPreviewLoading.value;

      double xAt(DateTime t) {
        return t.difference(w0).inMinutes * _kPxPerMinute;
      }

      final nameCol = _epgNameColW(context);
      final rowH = _epgRowH(context);
      final totalW = nameCol + gridW;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heroH = _epgHeroHeight(context);
                return FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: heroH,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: _EpgHeroGlassPanel(
                            channel: selCh,
                            programme: heroProg,
                            playlistTitle: playlistTitle,
                            categoryName: catName,
                            previewPlayer: heroPreviewCtrl,
                            previewLoading: heroPreviewLoading,
                            useVideoPreview: heroUseVideo,
                            referenceLandscapeLayout:
                                !_epgIsPortrait(context),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: LayoutBuilder(
                            builder: (context, gridConstraints) {
                              _scheduleInitialTimelineScroll(
                                viewportW: gridConstraints.maxWidth,
                                nameColW: nameCol,
                                windowStart: w0,
                                nowTime: now,
                              );
                              return Scrollbar(
                                controller: _hScroll,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _hScroll,
                                  scrollDirection: Axis.horizontal,
                                  physics: AppScrollPhysics.list(),
                                  child: SizedBox(
                                    width: totalW,
                                    height: gridConstraints.maxHeight,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: _EpgTimelineStripGlass(
                                            windowStart: w0,
                                            windowEnd: w1,
                                            gridWidth: gridW,
                                            nameColWidth: nameCol,
                                            stripHeight: _kTimelineStripH,
                                            xAt: xAt,
                                            now: now,
                                          ),
                                        ),
                                        Expanded(
                                          child: Scrollbar(
                                            controller: _vScroll,
                                            thumbVisibility: true,
                                            child: ValueListenableBuilder<int>(
                                              valueListenable: _tickValue,
                                              builder: (context, tick, child) {
                                                return ListView.builder(
                                                  controller: _vScroll,
                                                  primary: false,
                                                  physics:
                                                      AppScrollPhysics.list(),
                                                  padding:
                                                      const EdgeInsets.only(
                                                    right: 4,
                                                    bottom: 8,
                                                  ),
                                                  itemCount: channels.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final ch =
                                                        channels[index];
                                                    final windowProgrammes =
                                                        windowProgrammesFor(
                                                            ch);
                                                    return SizedBox(
                                                      height: rowH,
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          SizedBox(
                                                            width: nameCol,
                                                            child:
                                                                _EpgChannelLogoCell(
                                                              channel: ch,
                                                              programmeStartLabel:
                                                                  _programmeStartLabelForRow(
                                                                ch,
                                                                epg,
                                                                windowProgrammes,
                                                              ),
                                                              onFocused: () =>
                                                                  _onChannelCellFocused(
                                                                      ch),
                                                              landscapeEpgLayout:
                                                                  !_epgIsPortrait(
                                                                      context),
                                                              isResolvedChannelRow:
                                                                  ch.id ==
                                                                      selCh.id,
                                                              landscapeChannelRank:
                                                                  !_epgIsPortrait(
                                                                          context)
                                                                      ? index +
                                                                          1
                                                                      : null,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: gridW,
                                                            child:
                                                                _EpgProgrammeRowGlass(
                                                              channel: ch,
                                                              programmes:
                                                                  windowProgrammes,
                                                              gridWidth: gridW,
                                                              xAt: xAt,
                                                              now: now,
                                                              isPicked:
                                                                  _isPicked,
                                                              onPick:
                                                                  _selectProgramme,
                                                            ),
                                                          ),
                                                        ],
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
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (epg.isLoading.value)
            const LinearProgressIndicator(minHeight: 2),
        ],
      );
    });
  }
}

/// Oynatıcı overlay: [ChannelsController] olmadan yalnızca bir canlı kanalın EPG ızgarası.
class PlayerSingleChannelEpgPanel extends StatefulWidget {
  const PlayerSingleChannelEpgPanel({super.key, required this.channel});

  final Channel channel;

  @override
  State<PlayerSingleChannelEpgPanel> createState() =>
      _PlayerSingleChannelEpgPanelState();
}

class _PlayerSingleChannelEpgPanelState extends State<PlayerSingleChannelEpgPanel> {
  late ScrollController _hScroll;
  late ScrollController _vScroll;
  Timer? _tick;
  final ValueNotifier<int> _tickValue = ValueNotifier<int>(0);
  bool _didInitialTimeAlignment = false;
  bool _initialAlignCallbackPending = false;

  int? _pickChannelId;
  DateTime? _pickProgStart;
  String? _pickProgTitle;

  @override
  void initState() {
    super.initState();
    _hScroll = ScrollController();
    _vScroll = ScrollController();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _tickValue.value++;
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tickValue.dispose();
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  DateTime _windowStart(DateTime now) {
    final s = now.subtract(const Duration(hours: 1));
    return DateTime(s.year, s.month, s.day, s.hour, s.minute - (s.minute % 30), 0);
  }

  String _fmtHm(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Channel _resolvedChannel() {
    final ch = widget.channel;
    if (_pickChannelId != null && ch.id == _pickChannelId) return ch;
    return ch;
  }

  void _selectProgramme(Channel ch, EpgProgramme p) {
    setState(() {
      _pickChannelId = ch.id;
      _pickProgStart = p.start;
      _pickProgTitle = p.title;
    });
  }

  void _onChannelCellFocused(Channel ch) {
    setState(() {
      _pickChannelId = ch.id;
      _pickProgStart = null;
      _pickProgTitle = null;
    });
  }

  bool _isPicked(Channel ch, EpgProgramme p) {
    return _pickChannelId == ch.id &&
        _pickProgStart == p.start &&
        _pickProgTitle == p.title;
  }

  String _programmeStartLabelForRow(
    Channel ch,
    EpgService epg,
    List<EpgProgramme> windowProgrammes,
  ) {
    final cur = epg.getCurrentProgrammeForLiveChannel(ch);
    if (cur != null) return _fmtHm(cur.start);
    if (windowProgrammes.isNotEmpty) return _fmtHm(windowProgrammes.first.start);
    return '--:--';
  }

  void _scheduleInitialTimelineScroll({
    required double viewportW,
    required double nameColW,
    required DateTime windowStart,
    required DateTime nowTime,
  }) {
    if (_didInitialTimeAlignment || _initialAlignCallbackPending) return;
    _initialAlignCallbackPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialAlignCallbackPending = false;
      if (!mounted || !_hScroll.hasClients) return;
      _didInitialTimeAlignment = true;
      final x = nowTime.difference(windowStart).inMinutes * _kPxPerMinute;
      final needleX = nameColW + x;
      final target = needleX - viewportW * 0.38;
      final max = _hScroll.position.maxScrollExtent;
      _hScroll.jumpTo(target.clamp(0.0, max));
    });
  }

  @override
  Widget build(BuildContext context) {
    final epg = Get.find<EpgService>();
    return ValueListenableBuilder<int>(
      valueListenable: _tickValue,
      builder: (context, tick, child) {
        return Obx(() {
          epg.loadGeneration.value;
          epg.isLoading.value;

          final now = DateTime.now();
      final w0 = _windowStart(now);
      final w1 = w0.add(Duration(hours: _kWindowHours));
      final gridW = w1.difference(w0).inMinutes * _kPxPerMinute;

      final ch = _resolvedChannel();
      final channels = <Channel>[ch];
      final windowProgrammes =
          epg.programmesInWindowForLiveChannel(ch, w0, w1);
      final heroProg = _epgResolveHeroProgramme(
        epg,
        ch,
        pickChannelId: _pickChannelId,
        pickProgStart: _pickProgStart,
        pickProgTitle: _pickProgTitle,
      );
      final cache = Get.find<PlaylistCacheService>();
      final r = cache.result.value;
      final cats = r?.channelCategories ?? const <ChannelCategory>[];
      final catName = _categoryNameFromCategories(cats, ch);
      final rawUrl = (cache.sourceUrl.value ?? '').trim();
      final playlistTitle = rawUrl.isEmpty
          ? 'channels.epgTimeline.playlistSource'.tr
          : (rawUrl.length > 42 ? '${rawUrl.substring(0, 39)}…' : rawUrl);

      double xAt(DateTime t) {
        return t.difference(w0).inMinutes * _kPxPerMinute;
      }

      final nameCol = _epgNameColW(context);
      final rowH = _epgRowH(context);
      final totalW = nameCol + gridW;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heroH = _epgHeroHeight(context);
                return FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: heroH,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: Obx(() {
                            BetterPlayerController? pb;
                            var slot = false;
                            var busy = false;
                            if (!_epgIsPortrait(context) &&
                                Get.isRegistered<PlayerController>()) {
                              final pc = Get.find<PlayerController>();
                              busy = pc.isBusy.value;
                              pc.channel.value;
                              final u =
                                  pc.channel.value.streamUrl.toLowerCase();
                              final vod = u.contains('/movie/') ||
                                  u.contains('/series/');
                              if (!vod) {
                                slot = true;
                                pb = pc.better;
                              }
                            }
                            return _EpgHeroGlassPanel(
                              channel: ch,
                              programme: heroProg,
                              playlistTitle: playlistTitle,
                              categoryName: catName,
                              previewPlayer: pb,
                              previewLoading: slot && busy,
                              useVideoPreview: slot,
                              referenceLandscapeLayout:
                                  !_epgIsPortrait(context),
                            );
                          }),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: LayoutBuilder(
                            builder: (context, gridConstraints) {
                              _scheduleInitialTimelineScroll(
                                viewportW: gridConstraints.maxWidth,
                                nameColW: nameCol,
                                windowStart: w0,
                                nowTime: now,
                              );
                              return Scrollbar(
                                controller: _hScroll,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _hScroll,
                                  scrollDirection: Axis.horizontal,
                                  physics: AppScrollPhysics.list(),
                                  child: SizedBox(
                                    width: totalW,
                                    height: gridConstraints.maxHeight,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: _EpgTimelineStripGlass(
                                            windowStart: w0,
                                            windowEnd: w1,
                                            gridWidth: gridW,
                                            nameColWidth: nameCol,
                                            stripHeight: _kTimelineStripH,
                                            xAt: xAt,
                                            now: now,
                                          ),
                                        ),
                                        Expanded(
                                          child: Scrollbar(
                                            controller: _vScroll,
                                            thumbVisibility: true,
                                            child: ValueListenableBuilder<int>(
                                              valueListenable: _tickValue,
                                              builder: (context, tick, _) {
                                                return ListView.builder(
                                                  controller: _vScroll,
                                                  primary: false,
                                                  physics:
                                                      AppScrollPhysics.list(),
                                                  padding:
                                                      const EdgeInsets.only(
                                                    right: 4,
                                                    bottom: 8,
                                                  ),
                                                  itemCount: channels.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final rowCh =
                                                        channels[index];
                                                    return SizedBox(
                                                      height: rowH,
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          SizedBox(
                                                            width: nameCol,
                                                            child:
                                                                _EpgChannelLogoCell(
                                                              channel: rowCh,
                                                              programmeStartLabel:
                                                                  _programmeStartLabelForRow(
                                                                rowCh,
                                                                epg,
                                                                windowProgrammes,
                                                              ),
                                                              onFocused: () =>
                                                                  _onChannelCellFocused(
                                                                      rowCh),
                                                              landscapeEpgLayout:
                                                                  !_epgIsPortrait(
                                                                      context),
                                                              isResolvedChannelRow:
                                                                  rowCh.id ==
                                                                      ch.id,
                                                              landscapeChannelRank:
                                                                  !_epgIsPortrait(
                                                                          context)
                                                                      ? 1
                                                                      : null,
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: gridW,
                                                            child:
                                                                _EpgProgrammeRowGlass(
                                                              channel: rowCh,
                                                              programmes:
                                                                  windowProgrammes,
                                                              gridWidth: gridW,
                                                              xAt: xAt,
                                                              now: now,
                                                              isPicked:
                                                                  _isPicked,
                                                              onPick:
                                                                  _selectProgramme,
                                                            ),
                                                          ),
                                                        ],
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
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (epg.isLoading.value)
            const LinearProgressIndicator(minHeight: 2),
        ],
      );
        });
      },
    );
  }
}

/// Üst cam panel: canlı önizleme veya logo + saat; program özeti; sağda sistem saati.
class _EpgHeroGlassPanel extends StatelessWidget {
  const _EpgHeroGlassPanel({
    required this.channel,
    this.programme,
    required this.playlistTitle,
    this.categoryName,
    this.previewPlayer,
    this.previewLoading = false,
    this.useVideoPreview = false,
    this.referenceLandscapeLayout = false,
  });

  final Channel channel;
  final EpgProgramme? programme;
  final String playlistTitle;
  final String? categoryName;
  final BetterPlayerController? previewPlayer;
  final bool previewLoading;
  final bool useVideoPreview;
  /// Yatay: referans düzeni — oynatma listesi / grup sağ sütunda, ortada yalnız özet.
  final bool referenceLandscapeLayout;

  static Widget _heroLogoFallback() {
    return ColoredBox(
      color: const Color(0xFF12121A),
      child: Icon(
        Icons.live_tv_rounded,
        size: 26,
        color: Colors.white.withValues(alpha: 0.28),
      ),
    );
  }

  Widget _previewBox(
    BuildContext context,
    BorderRadius qr,
    double w,
    double h,
  ) {
    final showVideo = useVideoPreview &&
        previewPlayer != null &&
        !previewLoading;
    if (showVideo) {
      return ClipRRect(
        borderRadius: qr,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.55),
          child: SizedBox(
            width: w,
            height: h,
            child: ExcludeFocus(
              child: BetterPlayer(controller: previewPlayer!),
            ),
          ),
        ),
      );
    }
    if (useVideoPreview && previewLoading) {
      return ClipRRect(
        borderRadius: qr,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.45),
          child: SizedBox(
            width: w,
            height: h,
            child: const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white38,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final localeTag = Localizations.localeOf(context).toString();
    final timeStr = DateFormat.jm(localeTag).format(now);
    final dateStr = DateFormat.yMMMd(localeTag).format(now);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final px = (52 * dpr).round();
    return ClipRRect(
      borderRadius: qr,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: channel.logoUrl != null && channel.logoUrl!.isNotEmpty
                      ? ColoredBox(
                          color: const Color(0xFF12121A),
                          child: IptvChannelLogo(
                            imageUrl: channel.logoUrl!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.contain,
                            memCacheWidth: px,
                            memCacheHeight: px,
                            errorWidget: _heroLogoFallback(),
                          ),
                        )
                      : _heroLogoFallback(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      timeStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clockColumn(BuildContext context) {
    final now = DateTime.now();
    final localeTag = Localizations.localeOf(context).toString();
    final t = DateFormat.jm(localeTag).format(now);
    final d = DateFormat.yMMMd(localeTag).format(now);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            d,
            maxLines: 2,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _landscapeSourceRail(BuildContext context) {
    final prim = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _clockColumn(context),
            const SizedBox(height: 8),
            Text(
              playlistTitle,
              maxLines: 2,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            if (categoryName != null && categoryName!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'channels.epgTimeline.metaGroup'
                      .trParams({'name': categoryName!.trim()}),
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: prim.withValues(alpha: 0.78),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metaScrollable(
    BuildContext context, {
    required bool portrait,
    bool omitPlaylistMeta = false,
  }) {
    final localeTag = Localizations.localeOf(context).toString();
    final p = programme;
    final title = (p != null && p.title.trim().isNotEmpty)
        ? p.title
        : 'channels.epgTimeline.noProgrammeInfo'.tr;
    final timeRange = p == null
        ? ''
        : () {
            final df =
                portrait ? DateFormat.Hm(localeTag) : DateFormat.jm(localeTag);
            return '${df.format(p.start)} – ${df.format(p.end)}';
          }();
    var left = '';
    if (p != null && p.isLive) {
      final dur = p.end.difference(DateTime.now());
      if (dur.inSeconds > 0) {
        left = dur.inMinutes < 1
            ? 'channels.epgTimeline.endsUnderMinute'.tr
            : 'channels.epgTimeline.minutesLeft'
                .trParams({'n': '${dur.inMinutes}'});
      }
    }
    final rawDesc = p?.description?.trim();
    final descText = (rawDesc == null || rawDesc.isEmpty)
        ? 'channels.epgTimeline.noSummary'.tr
        : rawDesc;

    final compact = !portrait;
    final titleFs = compact ? 13.5 : 16.0;
    final titleMax = compact ? 2 : 3;
    final chanFs = compact ? 9.5 : 11.0;
    final timeFs = compact ? 10.5 : 12.0;
    final leftFs = compact ? 9.5 : 11.0;
    final descFs = compact ? 10.0 : 12.0;
    final descHeight = compact ? 1.22 : 1.28;
    final gapSm = compact ? 2.0 : 3.0;
    final gapMd = compact ? 3.0 : 4.0;
    final gapLg = compact ? 4.0 : 6.0;

    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          EpgChannelDisplay.liveChannelName(channel.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.42),
            fontSize: chanFs,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: gapSm),
        Text(
          title,
          maxLines: titleMax,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleFs,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
        if (timeRange.isNotEmpty) ...[
          SizedBox(height: gapMd),
          Text(
            timeRange,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: timeFs,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (p != null && p.isLive) ...[
          SizedBox(height: gapLg),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: p.progress.clamp(0.0, 1.0),
              minHeight: compact ? 3 : 4,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              color: !portrait
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.55),
            ),
          ),
          if (left.isNotEmpty) ...[
            SizedBox(height: gapMd),
            Text(
              left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: leftFs,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
        if (!omitPlaylistMeta) ...[
          SizedBox(height: gapMd),
          Text(
            playlistTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: compact ? 9.5 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (categoryName != null && categoryName!.trim().isNotEmpty) ...[
            SizedBox(height: compact ? 1 : 2),
            Text(
              'channels.epgTimeline.metaGroup'
                  .trParams({'name': categoryName!.trim()}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: compact ? 9.5 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
        SizedBox(height: compact ? 4 : 6),
      ],
    );

    final body = Text(
      descText,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.78),
        fontSize: descFs,
        height: descHeight,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        head,
        Expanded(
          child: SingleChildScrollView(
            physics: AppScrollPhysics.list(),
            child: body,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = Get.find<AppSettingsService>();
      final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
      final tv = settings.layoutMode.value == AppLayoutMode.tv;
      final sigma = AppPerformance.glassSigma(
        settings,
        zeroOnTvLayout: true,
        isTvLayout: tv,
        fullSigma: 14,
        reducedSigma: 8,
      );
      final r = BorderRadius.circular(16);
      final previewR = BorderRadius.circular(10);

      final decorated = Container(
        decoration: BoxDecoration(
          borderRadius: r,
          border: Border.all(color: ga.popupBorderColor, width: 1.2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: ga.popupGradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: ga.popupShadowColor,
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: r,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: LayoutBuilder(
              builder: (ctx, cons) {
                final portrait =
                    MediaQuery.orientationOf(context) == Orientation.portrait;
                if (portrait) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (c2, c2c) {
                                final aw = c2c.maxWidth;
                                final ah = aw * 9 / 16;
                                return _previewBox(
                                  context,
                                  previewR,
                                  aw,
                                  ah,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          _clockColumn(context),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _metaScrollable(context, portrait: true),
                      ),
                    ],
                  );
                }
                final h = cons.maxHeight;
                final idealPw = h * 16 / 9;
                final maxPw = cons.maxWidth * 0.42;
                final fullPw = math.min(idealPw, maxPw);
                final previewW = fullPw * 0.5;
                final previewH = math.min(h, math.max(h * 0.5, 56.0));
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: previewW,
                      child: Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: previewW,
                          height: previewH,
                          child: _previewBox(
                            context,
                            previewR,
                            previewW,
                            previewH,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metaScrollable(
                        context,
                        portrait: false,
                        omitPlaylistMeta: referenceLandscapeLayout,
                      ),
                    ),
                    const SizedBox(width: 6),
                    referenceLandscapeLayout
                        ? _landscapeSourceRail(context)
                        : _clockColumn(context),
                  ],
                );
              },
            ),
          ),
        ),
      );

      return ClipRRect(
        borderRadius: r,
        child: sigma <= 0
            ? decorated
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: decorated,
              ),
      );
    });
  }
}

class _EpgTimelineStripGlass extends StatelessWidget {
  const _EpgTimelineStripGlass({
    required this.windowStart,
    required this.windowEnd,
    required this.gridWidth,
    required this.nameColWidth,
    required this.stripHeight,
    required this.xAt,
    required this.now,
  });

  final DateTime windowStart;
  final DateTime windowEnd;
  final double gridWidth;
  final double nameColWidth;
  final double stripHeight;
  final double Function(DateTime) xAt;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = Get.find<AppSettingsService>();
      final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
      final tv = settings.layoutMode.value == AppLayoutMode.tv;
      final sigma = AppPerformance.glassSigma(
        settings,
        zeroOnTvLayout: true,
        isTvLayout: tv,
        fullSigma: 9,
        reducedSigma: 5,
      );
      final cache = Get.find<PlaylistCacheService>();
      final label = (cache.sourceUrl.value ?? '').trim();
      final sourceTitle = label.isEmpty
          ? 'channels.epgTimeline.playlistSource'.tr
          : (label.length > 42 ? '${label.substring(0, 39)}…' : label);

      final localeTag = Localizations.localeOf(context).toString();
      final landscapeStrip =
          MediaQuery.orientationOf(context) == Orientation.landscape;
      final fmt = landscapeStrip
          ? DateFormat.jm(localeTag)
          : DateFormat('HH:mm', localeTag);
      final ticks = <Widget>[];
      for (var t = windowStart;
          t.isBefore(windowEnd);
          t = t.add(const Duration(minutes: 30))) {
        final x = xAt(t);
        final isHour = t.minute == 0;
        ticks.add(
          Positioned(
            left: x,
            top: 0,
            bottom: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 1,
                  color: Colors.white.withValues(alpha: isHour ? 0.32 : 0.14),
                ),
                if (isHour)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          fmt.format(t),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      final nowX = xAt(now);
      final showNeedle = nowX >= 0 && nowX <= gridWidth;
      final needleColor = landscapeStrip
          ? Theme.of(context).colorScheme.primary
          : Colors.redAccent;

      final inner = SizedBox(
        height: stripHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: nameColWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4),
                  child: Text(
                    sourceTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: gridWidth,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: Stack(
                      fit: StackFit.expand,
                      children: ticks,
                    ),
                  ),
                  if (showNeedle)
                    Positioned(
                      left: nowX - 6,
                      top: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomPaint(
                            size: const Size(12, 7),
                            painter: _NowTrianglePainter(color: needleColor),
                          ),
                          Container(
                            width: 2,
                            height: stripHeight - 7,
                            decoration: BoxDecoration(
                              color: needleColor.withValues(alpha: 0.92),
                              boxShadow: [
                                BoxShadow(
                                  color: needleColor.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

      final r = BorderRadius.circular(16);
      final decorated = Container(
        decoration: BoxDecoration(
          borderRadius: r,
          border: Border.all(color: ga.popupBorderColor),
          gradient: LinearGradient(colors: ga.popupGradientColors),
          boxShadow: [
            BoxShadow(
              color: ga.popupShadowColor,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: r, child: inner),
      );

      return ClipRRect(
        borderRadius: r,
        child: Focus(
          canRequestFocus: true,
          skipTraversal: false,
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              _scheduleEpgEnsureVisible(
                context,
                debounceKey: 'timeline_strip',
                alignment: 0.2,
                duration: AppPerformance.uiDuration(
                  const Duration(milliseconds: 260),
                ),
              );
            }
          },
          child: sigma <= 0
              ? decorated
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: decorated,
                ),
        ),
      );
    });
  }
}

class _NowTrianglePainter extends CustomPainter {
  const _NowTrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NowTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _EpgChannelLogoCell extends StatelessWidget {
  const _EpgChannelLogoCell({
    required this.channel,
    required this.programmeStartLabel,
    required this.onFocused,
    this.landscapeEpgLayout = false,
    this.isResolvedChannelRow = false,
    this.landscapeChannelRank,
  });

  final Channel channel;
  final String programmeStartLabel;
  final VoidCallback onFocused;
  final bool landscapeEpgLayout;
  final bool isResolvedChannelRow;
  final int? landscapeChannelRank;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = Get.find<AppSettingsService>();
      final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
      final r = BorderRadius.circular(10);
      final prim = Theme.of(context).colorScheme.primary;

      final dpr = MediaQuery.devicePixelRatioOf(context);
      final logoSz = landscapeEpgLayout ? 30.0 : 26.0;
      final logoPx = (logoSz * dpr).round();
      final thumb = channel.logoUrl != null && channel.logoUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: IptvChannelLogo(
                imageUrl: channel.logoUrl!,
                width: logoSz,
                height: logoSz,
                fit: BoxFit.cover,
                memCacheWidth: logoPx,
                memCacheHeight: logoPx,
                errorWidget: _logoFallback(logoSz),
              ),
            )
          : _logoFallback(logoSz);

      return Focus(
        canRequestFocus: true,
        skipTraversal: false,
        descendantsAreFocusable: false,
        onFocusChange: (hasFocus) {
          if (hasFocus) {
            onFocused();
            _scheduleEpgEnsureVisible(
              context,
              debounceKey: 'channel_cell',
              alignment: 0.12,
              duration: AppPerformance.uiDuration(
                const Duration(milliseconds: 260),
              ),
            );
          }
        },
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (_epgTvCenterActivateKey(event.logicalKey)) {
            onFocused();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (ctx) {
            final focused = Focus.of(ctx).hasFocus;
            final rank = landscapeChannelRank;
            final rankBox = (landscapeEpgLayout && rank != null)
                ? Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: prim.withValues(alpha: 0.22),
                        border: Border.all(
                          color: prim.withValues(alpha: 0.45),
                        ),
                      ),
                      child: SizedBox(
                        width: 22,
                        height: 28,
                        child: Center(
                          child: Text(
                            '$rank',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink();

            final inner = Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onFocused,
                borderRadius: r,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    landscapeEpgLayout ? 4 : 2,
                    2,
                    4,
                    2,
                  ),
                  child: Row(
                    children: [
                      rankBox,
                      SizedBox(
                        width: landscapeEpgLayout ? 32 : 28,
                        height: landscapeEpgLayout ? 32 : 28,
                        child: Center(child: thumb),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              programmeStartLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: landscapeEpgLayout ? 9.5 : 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              EpgChannelDisplay.liveChannelName(channel.name),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: landscapeEpgLayout ? 10.5 : 10,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            final borderCol = landscapeEpgLayout
                ? (focused
                    ? prim.withValues(alpha: 0.92)
                    : isResolvedChannelRow
                        ? prim.withValues(alpha: 0.72)
                        : ga.popupBorderColor.withValues(alpha: 0.85))
                : (focused
                    ? Colors.white.withValues(alpha: 0.85)
                    : ga.popupBorderColor.withValues(alpha: 0.85));
            final fillTop = landscapeEpgLayout && isResolvedChannelRow
                ? Color.alphaBlend(
                    prim.withValues(alpha: 0.24),
                    ga.popupGradientColors.first,
                  )
                : ga.popupGradientColors.first;
            final fillBot = landscapeEpgLayout && isResolvedChannelRow
                ? Color.alphaBlend(
                    prim.withValues(alpha: 0.14),
                    ga.popupGradientColors.last,
                  )
                : ga.popupGradientColors.last;

            final decorated = AnimatedContainer(
              duration: AppPerformance.uiDuration(
                const Duration(milliseconds: 140),
              ),
              decoration: BoxDecoration(
                borderRadius: r,
                border: Border.all(
                  color: borderCol,
                  width: (landscapeEpgLayout && (focused || isResolvedChannelRow))
                      ? 2
                      : (focused ? 2 : 1),
                ),
                gradient: LinearGradient(
                  colors: [fillTop, fillBot],
                ),
              ),
              child: inner,
            );

            return ClipRRect(
              borderRadius: r,
              child: decorated,
            );
          },
        ),
      );
    });
  }

  static Widget _logoFallback([double side = 26]) {
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.white.withValues(alpha: 0.06),
      ),
      child: Icon(
        Icons.tv_rounded,
        size: side * 0.62,
        color: Colors.white.withValues(alpha: 0.35),
      ),
    );
  }
}

/// Kumanda ile odak + OK/Enter ile seçim; oklar [ReadingOrderTraversalPolicy] ile komşulara gider.
class _EpgProgrammeFocusCell extends StatelessWidget {
  const _EpgProgrammeFocusCell({
    required this.channel,
    required this.programme,
    required this.cellWidth,
    required this.picked,
    required this.live,
    required this.borderIdle,
    required this.fill,
    required this.timeFmt,
    required this.onPick,
    this.landscapeBlueAccent = false,
  });

  final Channel channel;
  final EpgProgramme programme;
  final double cellWidth;
  final bool picked;
  final bool live;
  final Color borderIdle;
  final List<Color> fill;
  final DateFormat timeFmt;
  final void Function(Channel ch, EpgProgramme p) onPick;
  final bool landscapeBlueAccent;

  @override
  Widget build(BuildContext context) {
    final p = programme;
    return Focus(
      canRequestFocus: true,
      skipTraversal: false,
      descendantsAreFocusable: false,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _scheduleEpgEnsureVisible(
            context,
            debounceKey: 'programme_cell',
            alignment: 0.25,
            duration: AppPerformance.uiDuration(
              const Duration(milliseconds: 280),
            ),
          );
        }
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (_epgTvCenterActivateKey(event.logicalKey)) {
          onPick(channel, p);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          final prim = Theme.of(ctx).colorScheme.primary;
          final borderColor = focused
              ? (landscapeBlueAccent
                  ? prim.withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.92))
              : borderIdle;
          final borderW = focused ? 2.0 : (picked ? 1.5 : 1.0);
          final narrow = cellWidth < 56;
          final titleFs = narrow
              ? (landscapeBlueAccent ? 8.0 : 8.5)
              : (landscapeBlueAccent ? 9.0 : 9.5);
          final timeFs = narrow
              ? (landscapeBlueAccent ? 7.5 : 8.0)
              : (landscapeBlueAccent ? 8.0 : 8.5);
          final hPad = narrow ? 4.0 : 5.0;
          final vPad = narrow ? 2.0 : 3.0;
          final titleLines = narrow ? 1 : (cellWidth < 88 ? 1 : 2);
          final showTime = cellWidth >= 40;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onPick(channel, p),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: AppPerformance.uiDuration(
                  const Duration(milliseconds: 160),
                ),
                width: cellWidth,
                padding: EdgeInsets.symmetric(
                  horizontal: hPad,
                  vertical: vPad,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor, width: borderW),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: fill,
                  ),
                  boxShadow: picked
                      ? [
                          BoxShadow(
                            color: landscapeBlueAccent
                                ? prim.withValues(alpha: 0.22)
                                : Colors.white.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      p.title.trim(),
                      maxLines: titleLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.96),
                        fontSize: titleFs,
                        height: 1.12,
                        fontWeight: live ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: 0.05,
                      ),
                    ),
                    if (showTime)
                      Text(
                        timeFmt.format(p.start),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: timeFs,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EpgProgrammeRowGlass extends StatelessWidget {
  const _EpgProgrammeRowGlass({
    required this.channel,
    required this.programmes,
    required this.gridWidth,
    required this.xAt,
    required this.now,
    required this.isPicked,
    required this.onPick,
  });

  final Channel channel;
  final List<EpgProgramme> programmes;
  final double gridWidth;
  final double Function(DateTime) xAt;
  final DateTime now;
  final bool Function(Channel, EpgProgramme) isPicked;
  final void Function(Channel, EpgProgramme) onPick;

  @override
  Widget build(BuildContext context) {
    final list = programmes.where(_epgProgrammeHasContent).toList();
    final nowX = xAt(now);
    final timeFmt =
        DateFormat('HH:mm', Localizations.localeOf(context).toString());
    final settings = Get.find<AppSettingsService>();
    final ga = GlassAppearance.fromLabel(settings.themeLabel.value);
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final prim = Theme.of(context).colorScheme.primary;
    final rowH = _epgRowH(context);

    final children = <Widget>[
      ...list.map((p) {
        final left = xAt(p.start);
        final right = xAt(p.end);
        final w = (right - left).clamp(0.0, gridWidth);
        if (w < 14) return const SizedBox.shrink();
        final picked = isPicked(channel, p);
        final live = p.isLive;
        final fill = live
            ? (landscape
                ? [
                    prim.withValues(alpha: 0.16),
                    prim.withValues(alpha: 0.06),
                  ]
                : [
                    Colors.tealAccent.withValues(alpha: 0.14),
                    Colors.tealAccent.withValues(alpha: 0.06),
                  ])
            : [
                Colors.white.withValues(alpha: picked ? 0.12 : 0.06),
                Colors.white.withValues(alpha: picked ? 0.06 : 0.03),
              ];
        final borderC = picked
            ? (landscape
                ? prim.withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.42))
            : (live
                ? (landscape
                    ? prim.withValues(alpha: 0.52)
                    : Colors.tealAccent.withValues(alpha: 0.45))
                : ga.popupBorderColor.withValues(alpha: 0.9));

        return Positioned(
          left: left,
          top: 4,
          height: rowH - 8,
          width: w,
          child: _EpgProgrammeFocusCell(
            channel: channel,
            programme: p,
            cellWidth: w,
            picked: picked,
            live: live,
            borderIdle: borderC,
            fill: fill,
            timeFmt: timeFmt,
            onPick: onPick,
            landscapeBlueAccent: landscape,
          ),
        );
      }),
      if (nowX >= 0 && nowX <= gridWidth)
        Positioned(
          left: nowX,
          top: 0,
          bottom: 0,
          child: ExcludeFocus(
            child: IgnorePointer(
              child: Container(
                width: 2,
                color: landscape
                    ? prim.withValues(alpha: 0.62)
                    : Colors.redAccent.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
    ];

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: children,
    );
  }
}
