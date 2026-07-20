import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/film_dizi_media_pills.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../domain/entities/download_item.dart';
import '../../../domain/entities/movie_model.dart';
import '../../../domain/entities/series_episode_option.dart';
import '../widgets/film_dizi_detail_loading_skeleton.dart';
import '../widgets/recommended_films_loading_skeleton.dart';
import '../widgets/film_dizi_detail_top_bar.dart';
import '../widgets/film_dizi_poster_card.dart';
import '../widgets/film_dizi_quick_info_panel.dart';
import '../widgets/recommended_films_glass.dart';
import '../widgets/recommended_films_poster_grid.dart';
import 'film_dizi_series_detail_controller.dart';

class FilmDiziSeriesDetailView extends GetView<FilmDiziSeriesDetailController> {
  const FilmDiziSeriesDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        final backdrop = controller.backdropUrl;
        final landscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final tv =
            Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
        // TV kutularında 22px blur kare başına pahalı (kasılma). Statik dekoratif
        // zemin koyu gradient altında olduğundan daha düşük sigma görsel olarak
        // yeterli; ayrıca RepaintBoundary ile izole edilir → bölüm listesi scroll
        // veya D-pad odak değişiminde yeniden çizilmez. Düşük çözünürlüklü decode
        // (blur'lanacağı için) RAM ve raster yükünü ayrıca azaltır.
        final backdropSigma = tv ? 12.0 : 22.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (backdrop != null && backdrop.isNotEmpty)
              Positioned.fill(
                child: RepaintBoundary(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: backdropSigma,
                      sigmaY: backdropSigma,
                    ),
                    child: Transform.scale(
                      scale: 1.08,
                      child: CachedNetworkImage(
                        imageUrl: backdrop,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                        memCacheWidth: tv ? 480 : 720,
                        fadeInDuration: Duration.zero,
                        errorWidget: (_, __, ___) =>
                            const ColoredBox(color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      const Color(0xFF0F172A).withValues(alpha: 0.65),
                      const Color(0xFF0F172A).withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: Column(
                  children: [
                    Obx(() {
                      Get.find<FavoritesService>().seriesIds.length;
                      // Yatayda favori, İzle'nin altına taşındı → üst çubukta
                      // gösterilmez (TV + tablet + mobil yatay ortak düzen).
                      final isTv =
                          Get.find<AppSettingsService>().layoutMode.value ==
                              AppLayoutMode.tv;
                      return FilmDiziDetailTopBar(
                        onBack: () => Get.back<void>(),
                        onFavorite:
                            landscape ? null : controller.toggleFavorite,
                        isFavorite: controller.isFavorite,
                        // Yalnız TV yatayda odak Bölüm 1'e gider → geri odağı kapalı.
                        autofocusBack: !(landscape && isTv),
                      );
                    }),
                    Expanded(
                      child: landscape
                          ? _LandscapeBody(controller: controller)
                          : _PortraitBody(controller: controller),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _PortraitBody extends StatelessWidget {
  const _PortraitBody({required this.controller});

  final FilmDiziSeriesDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const FilmDiziDetailLoadingSkeleton(showEpisodes: true);
      }
      return SingleChildScrollView(
        physics: AppScrollPhysics.list(context: context),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: _SeriesDetailContent(controller: controller),
      );
    });
  }
}

class _LandscapeBody extends StatefulWidget {
  const _LandscapeBody({required this.controller});

  final FilmDiziSeriesDetailController controller;

  @override
  State<_LandscapeBody> createState() => _LandscapeBodyState();
}

class _LandscapeBodyState extends State<_LandscapeBody> {
  // Sol sütun (İzle/İndir) ↔ sağ sütun (Bölüm 1) arası D-pad geçişi için
  // paylaşılan odak düğümleri.
  final FocusNode _playFocus = FocusNode(debugLabel: 'seriesPlay');
  final FocusNode _downloadFocus = FocusNode(debugLabel: 'seriesDownload');
  final FocusNode _firstEpisodeFocus = FocusNode(debugLabel: 'seriesEp1');
  // Sağ sütundaki ilk sezon butonu: sol sütun aksiyonlarından (İzle/İndir)
  // aşağı basınca buraya inilir; buradan sol → İzle, aşağı → Bölüm 1.
  final FocusNode _seasonFocus = FocusNode(debugLabel: 'seriesSeason1');

  @override
  void dispose() {
    _playFocus.dispose();
    _downloadFocus.dispose();
    _firstEpisodeFocus.dispose();
    _seasonFocus.dispose();
    super.dispose();
  }

  Future<void> _playAndRestoreFocus() async {
    await widget.controller.playFirstEpisode();
    if (!mounted) return;
    final isTv =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
    if (!isTv) return;
    scheduleTvFocusRestore(_playFocus);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Obx(() {
      if (controller.isLoading.value) {
        return const FilmDiziDetailLoadingSkeleton();
      }
      // Otomatik "Bölüm 1" odağı yalnız TV'de; mobil/tablet yatayda dokunmatik.
      final isTv =
          Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: SingleChildScrollView(
              physics: AppScrollPhysics.list(context: context),
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
              child: _SeriesDetailContent(
                controller: controller,
                includeEpisodes: false,
                playFocus: _playFocus,
                downloadFocus: _downloadFocus,
                onPlay: _playAndRestoreFocus,
                // İzle/İndir'den sağ ok → Bölüm 1.
                actionsArrowRight: _firstEpisodeFocus,
                // İzle/İndir'den aşağı ok → sağ sütundaki ilk sezon butonu.
                actionsArrowDown: _seasonFocus,
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: _EpisodesPanel(
              controller: controller,
              autofocusFirstEpisode: isTv,
              firstEpisodeFocus: _firstEpisodeFocus,
              // Her bölümden sol ok → İzle butonu (sol sütun).
              firstEpisodeArrowLeft: _playFocus,
              // İlk sezon butonu odak düğümü: sol sütundan aşağı inince buraya gelir.
              seasonFocus: _seasonFocus,
            ),
          ),
        ],
      );
    });
  }
}

class _SeriesDetailContent extends StatelessWidget {
  const _SeriesDetailContent({
    required this.controller,
    this.includeEpisodes = true,
    this.playFocus,
    this.downloadFocus,
    this.actionsArrowRight,
    this.actionsArrowDown,
    this.onPlay,
  });

  final FilmDiziSeriesDetailController controller;
  final bool includeEpisodes;

  /// Yatay düzende İzle/İndir butonlarının D-pad odak düğümleri ve sağ/aşağı ok hedefi.
  final FocusNode? playFocus;
  final FocusNode? downloadFocus;
  final FocusNode? actionsArrowRight;
  final FocusNode? actionsArrowDown;
  final Future<void> Function()? onPlay;

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final poster = controller.posterUrl;
    final width = MediaQuery.sizeOf(context).width;
    final title = controller.meta.value?.title ?? controller.displayTitle;

    // Yatay düzen (TV + tablet + mobil yatay ortak): poster + başlık/meta/İzle
    // üstte yan yana. Özet ve altındaki tüm bölümler posterin altından başlayıp
    // tam genişlikte (en soldan) sıralanır — sol taraf boş kalmaz. Favori butonu
    // İzle'nin altına (tür rozetleriyle) taşınır, "benzer diziler" gizlenir.
    if (landscape) {
      final posterW = (width * 0.18).clamp(140.0, 240.0).toDouble();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (poster != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: posterW,
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: RecommendedFilmsPosterImage(url: poster),
                    ),
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: _headerInfo(
                  context,
                  title,
                  titleFontSize: 18,
                  trailing: _TvFavoriteAndGenres(controller: controller),
                ),
              ),
            ],
          ),
          ..._belowContent(context, tv: true),
        ],
      );
    }

    final thumbW = includeEpisodes ? width * 0.28 : width * 0.22;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (poster != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: thumbW,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: RecommendedFilmsPosterImage(url: poster),
                  ),
                ),
              ),
            const SizedBox(width: 14),
            Expanded(child: _headerInfo(context, title, titleFontSize: 20)),
          ],
        ),
        ..._belowContent(context),
      ],
    );
  }

  /// Poster sağındaki bilgi sütunu: başlık, meta satırı, kategori, İzle/İndir.
  /// [trailing] verilirse butonların altına eklenir (TV: favori + tür satırı).
  Widget _headerInfo(
    BuildContext context,
    String title, {
    required double titleFontSize,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: titleFontSize,
            fontWeight: FontWeight.w800,
            height: 1.2,
            shadows: const [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Obx(() {
          controller.meta.value;
          controller.xtreamMeta.value;
          controller.episodes.length;
          if (!controller.hasHeaderMeta) {
            return const SizedBox.shrink();
          }
          return _SeriesHeaderMeta(controller: controller);
        }),
        if (controller.categoryName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            controller.categoryName,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        // Meta satırının hemen altında, eşit ebatta yan yana
        // İzle + İndir (ilk bölüm) butonları.
        const SizedBox(height: 14),
        _SeriesActionButtons(
          controller: controller,
          playFocus: playFocus,
          downloadFocus: downloadFocus,
          arrowRight: actionsArrowRight,
          arrowDown: actionsArrowDown,
          onPlay: onPlay,
        ),
        if (trailing != null) ...[
          const SizedBox(height: 12),
          trailing,
        ],
      ],
    );
  }

  /// Poster/başlık satırının altındaki bölümler (yatayda sağ sütunda, dikeyde
  /// poster satırının altında): tür rozetleri, özet, fragman, künye, bölümler,
  /// oyuncular, benzer diziler.
  List<Widget> _belowContent(BuildContext context, {bool tv = false}) {
    final width = MediaQuery.sizeOf(context).width;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    // "Benzer diziler" posterleri: yatayda 0.35, dikeyde %40 küçültülmüş (0.6).
    final similarW = ((width - 48) / 2.4) * (landscape ? 0.35 : 0.6);
    return [
      // TV'de tür rozetleri başlık alanına (favori yanına) taşındı; burada
      // tekrar gösterilmez. Diğer modlarda posterin altında yatay sıra.
      if (!tv)
        Obx(() {
          controller.meta.value;
          controller.xtreamMeta.value;
          final genre = controller.genrePills;
          if (genre.isEmpty) {
            if (controller.metaEnriching.value) {
              return const Padding(
                padding: EdgeInsets.only(top: 14),
                child: FilmDiziPillsSkeleton(count: 3),
              );
            }
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _PillWrap(pills: genre),
          );
        }),
      const SizedBox(height: 16),
      _PlotBlock(controller: controller),
      Obx(() {
        if (controller.trailers.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),
            _SectionTitle('filmDizi.trailers'.tr),
            const SizedBox(height: 10),
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: AppScrollPhysics.list(context: context),
                itemCount: controller.trailers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) =>
                    _TrailerCard(trailer: controller.trailers[i]),
              ),
            ),
          ],
        );
      }),
      Obx(() {
        controller.meta.value;
        controller.xtreamMeta.value;
        final genres = controller.genrePills
            .map((p) => p.label.trim())
            .where((s) => s.isNotEmpty)
            .toList(growable: false);
        if (genres.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: FilmDiziQuickInfoPanel(
            director: null,
            genres: genres,
          ),
        );
      }),
      if (includeEpisodes) ...[
        const SizedBox(height: 18),
        _EpisodesPanel(
          controller: controller,
          shrinkWrap: true,
        ),
      ],
      Obx(() {
        final cast = controller.meta.value?.cast;
        if (cast == null || cast.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),
            _SectionTitle('filmDizi.cast'.tr),
            const SizedBox(height: 10),
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: AppScrollPhysics.list(context: context),
                itemCount: cast.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) => _CastChip(
                  member: cast[i],
                  onTap: () => controller.openActor(cast[i]),
                  // TV yatay sol sütunda oyuncular en son bölüm; aşağı ok
                  // ile odak boşluğa kaçmasın.
                  blockDownNav: tv,
                ),
              ),
            ),
          ],
        );
      }),
      // "Benzer diziler / bunlar da ilginizi çekebilir" TV modunda gizlenir.
      if (!tv)
        Obx(() {
          if (controller.similar.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              _SectionTitle('filmDizi.similar'.tr),
              const SizedBox(height: 10),
              SizedBox(
                height: similarW * 1.48 + 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: AppScrollPhysics.list(context: context),
                  itemCount: controller.similar.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final s = controller.similar[i];
                    return FilmDiziPosterCard.series(
                      series: s,
                      posterWidth: similarW,
                      ensureVisibleOnFocus: false,
                      onTap: () => controller.openSimilarSeries(s),
                    );
                  },
                ),
              ),
            ],
          );
        }),
    ];
  }
}

/// Eşit ebatta, yan yana "İzle" + "İndir" (ilk bölüm) butonları. Dizi
/// detayında meta satırının hemen altına yerleşir. Bölüm yoksa pasif görünür.
class _SeriesActionButtons extends StatelessWidget {
  const _SeriesActionButtons({
    required this.controller,
    this.playFocus,
    this.downloadFocus,
    this.arrowRight,
    this.arrowDown,
    this.onPlay,
  });

  final FilmDiziSeriesDetailController controller;

  /// İzle / İndir D-pad odak düğümleri, sağ ok (→ Bölüm 1) ve aşağı ok
  /// (→ sağ sütundaki ilk sezon butonu) hedefleri.
  final FocusNode? playFocus;
  final FocusNode? downloadFocus;
  final FocusNode? arrowRight;
  final FocusNode? arrowDown;
  final Future<void> Function()? onPlay;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.episodes.length;
      controller.selectedSeason.value;
      final ep = controller.firstEpisode;
      final disabled = ep == null;
      const height = 46.0;
      void activatePlay() {
        final play = onPlay ?? controller.playFirstEpisode;
        unawaited(play());
      }

      return Opacity(
        opacity: disabled ? 0.45 : 1,
        child: IgnorePointer(
          ignoring: disabled,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: height,
                  child: tvDpadActivateWrap(
                    context,
                    onActivate: activatePlay,
                    focusNode: playFocus,
                    // İzle → sağ ok: İndir varsa İndir'e, yoksa Bölüm 1'e.
                    arrowRight: ep == null ? arrowRight : downloadFocus,
                    // İzle → aşağı ok: sağ sütundaki ilk sezon butonu.
                    arrowDown: arrowDown,
                    child: FilmDiziGlassPlayButton(
                      label: 'filmDizi.watch'.tr,
                      onPressed: activatePlay,
                      compact: true,
                      posterUrl: controller.posterUrl,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: height,
                  child: ep == null
                      ? const SizedBox.shrink()
                      : tvDpadActivateWrap(
                          context,
                          onActivate: () =>
                              _showEpisodeDownloadPicker(context, controller),
                          focusNode: downloadFocus,
                          borderRadius: 14,
                          scaleOnFocus: 1.04,
                          arrowLeft: playFocus,
                          // İndir → sağ ok: Bölüm 1.
                          arrowRight: arrowRight,
                          // İndir → aşağı ok: sağ sütundaki ilk sezon butonu.
                          arrowDown: arrowDown,
                          child: _DownloadPickerChip(
                            onTap: () => _showEpisodeDownloadPicker(
                              context,
                              controller,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// "İndir" butonunun cam görünümü (İzle butonuyla eşit ebatta yan yana).
/// [onTap] dokunma için; TV/kumanda OK olayını saran [tvDpadActivateWrap] verir.
class _DownloadPickerChip extends StatelessWidget {
  const _DownloadPickerChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withValues(alpha: 0.42)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 7),
                Text(
                  'downloads.action.download'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "İndir" butonuna basılınca açılan bölüm seçim penceresi: tüm bölümler
/// sıralı listelenir, kullanıcı seçtiği bölümü indirir. D-pad: ilk satır
/// otomatik odaklı, yukarı/aşağı ile bölümler arası gezinme, OK indirir.
Future<void> _showEpisodeDownloadPicker(
  BuildContext context,
  FilmDiziSeriesDetailController controller,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (_) => _EpisodeDownloadPicker(controller: controller),
  );
}

class _EpisodeDownloadPicker extends StatelessWidget {
  const _EpisodeDownloadPicker({required this.controller});

  final FilmDiziSeriesDetailController controller;

  @override
  Widget build(BuildContext context) {
    final episodes = controller.episodes.toList()
      ..sort((a, b) {
        final s = a.season.compareTo(b.season);
        return s != 0 ? s : a.episodeNumber.compareTo(b.episodeNumber);
      });
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: size.height * 0.82,
        ),
        child: RecommendedFilmsGlassPanel(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'filmDizi.series.downloadPick'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TvIconButton(
                      icon: Icons.close_rounded,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (episodes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'filmDizi.series.episodes'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: AppScrollPhysics.list(context: context),
                      itemCount: episodes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (c, i) => _EpisodeDownloadRow(
                        controller: controller,
                        option: episodes[i],
                        autofocus: i == 0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeDownloadRow extends StatelessWidget {
  const _EpisodeDownloadRow({
    required this.controller,
    required this.option,
    this.autofocus = false,
  });

  final FilmDiziSeriesDetailController controller;
  final SeriesEpisodeOption option;
  final bool autofocus;

  String get _itemId =>
      'ep_${controller.series.id}_${option.season}x${option.episodeNumber}';

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<DownloadService>();
    final cs = Theme.of(context).colorScheme;
    return Obx(() {
      final item = svc.items[_itemId];
      final status = item?.status;
      final progress = svc.progress[_itemId];
      final total = progress?.total;
      final percent =
          (total != null && total > 0) ? progress!.received / total : null;

      Future<void> onActivate() async {
        switch (status) {
          case DownloadStatus.downloading:
          case DownloadStatus.queued:
            await svc.cancel(_itemId);
          case DownloadStatus.failed:
            if (item != null) await svc.retry(item.id);
          case DownloadStatus.completed:
            // Zaten indirildi → işlem yok.
            break;
          case DownloadStatus.cancelled:
          case null:
            await svc.enqueueEpisode(option, series: controller.series);
        }
      }

      final Widget trailing;
      switch (status) {
        case DownloadStatus.downloading:
        case DownloadStatus.queued:
          trailing = SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              value: percent,
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              backgroundColor: Colors.white24,
            ),
          );
        case DownloadStatus.completed:
          trailing = Icon(
            Icons.download_done_rounded,
            color: Colors.greenAccent.shade400,
            size: 24,
          );
        case DownloadStatus.failed:
          trailing = const Icon(
            Icons.refresh_rounded,
            color: Colors.redAccent,
            size: 24,
          );
        case DownloadStatus.cancelled:
        case null:
          trailing = Icon(Icons.download_rounded, color: cs.primary, size: 24);
      }

      final row = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                controller.episodeListTitle(option),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      );

      return tvDpadActivateWrap(
        context,
        onActivate: onActivate,
        borderRadius: 12,
        autofocus: autofocus,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onActivate,
            borderRadius: BorderRadius.circular(12),
            child: row,
          ),
        ),
      );
    });
  }
}

/// TV: İzle/İndir altındaki satır — favori (kalp) düğmesi + hemen yanında tür
/// rozetleri (Dram, Belgesel…). Favori üst çubuktan buraya taşındı.
class _TvFavoriteAndGenres extends StatelessWidget {
  const _TvFavoriteAndGenres({required this.controller});

  final FilmDiziSeriesDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.meta.value;
      controller.xtreamMeta.value;
      Get.find<FavoritesService>().seriesIds.length;
      final fav = controller.isFavorite;
      final genre = controller.genrePills;
      return Row(
        children: [
          _FavoriteChip(active: fav, onTap: controller.toggleFavorite),
          if (genre.isNotEmpty) ...[
            const SizedBox(width: 10),
            Expanded(child: _PillWrap(pills: genre)),
          ],
        ],
      );
    });
  }
}

/// Kalp (favori) düğmesi — D-pad ile seçilebilir, açıkken kırmızı dolu.
class _FavoriteChip extends StatelessWidget {
  const _FavoriteChip({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = Material(
      color: active
          ? const Color(0xFFEF4444).withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.08),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Icon(
            active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: active ? const Color(0xFFEF4444) : Colors.white,
            size: 22,
          ),
        ),
      ),
    );
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      borderRadius: 22,
      child: body,
    );
  }
}

/// Poster sağı — yıl, dil, sezon, bölüm, IMDb (Xtream → OMDB/TMDB).
class _SeriesHeaderMeta extends StatelessWidget {
  const _SeriesHeaderMeta({required this.controller});

  final FilmDiziSeriesDetailController controller;

  @override
  Widget build(BuildContext context) {
    final rating = controller.imdbRating;
    final tmdbRating = controller.tmdbRatingLabel;
    final certification = controller.certificationLabel;
    final country = controller.countryLabel;
    final year = controller.releaseYear;
    final language = controller.languageLabel;
    final genre = controller.genreLine;
    final seasons = controller.seasonCount;
    final episodes = controller.episodeCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (rating != null)
              _SeriesMetaChip(
                icon: Icons.star_rounded,
                iconColor: Colors.amber,
                label: 'IMDb $rating',
              ),
            if (tmdbRating != null)
              _SeriesMetaChip(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFF01B4E4),
                label: 'TMDB $tmdbRating',
              ),
            if (certification != null)
              _SeriesMetaChip(
                icon: Icons.local_movies_outlined,
                label: certification,
              ),
            if (country != null)
              _SeriesMetaChip(
                icon: Icons.public_outlined,
                label: country,
              ),
            if (year != null)
              _SeriesMetaChip(
                icon: Icons.calendar_today_outlined,
                label: year,
              ),
            if (language != null)
              _SeriesMetaChip(
                icon: Icons.translate_rounded,
                label: language,
              ),
            if (seasons > 0)
              _SeriesMetaChip(
                icon: Icons.layers_outlined,
                label: 'browse.series.seasonCount'.trParams({'n': '$seasons'}),
              ),
            if (episodes > 0)
              _SeriesMetaChip(
                icon: Icons.playlist_play_rounded,
                label:
                    'filmDizi.series.episodeCount'.trParams({'n': '$episodes'}),
              ),
          ],
        ),
        if (genre != null && genre.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            genre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

class _SeriesMetaChip extends StatelessWidget {
  const _SeriesMetaChip({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor ?? Colors.white70),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PlotBlock extends StatelessWidget {
  const _PlotBlock({required this.controller});

  final FilmDiziSeriesDetailController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle('filmDizi.synopsis'.tr),
        const SizedBox(height: 8),
        Obx(() {
          controller.meta.value;
          controller.xtreamMeta.value;
          final expanded = controller.plotExpanded.value;
          final text = controller.synopsis;
          // Özet hâlâ yoksa ve TMDB/Xtream verisi geliyorsa iskelet göster.
          if (controller.metaEnriching.value &&
              text == 'filmDizi.noSynopsis'.tr) {
            return const RecommendedFilmsGlassPanel(
              child: FilmDiziTextSkeleton(lines: 5),
            );
          }
          return RecommendedFilmsGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text,
                  maxLines: expanded ? null : 5,
                  overflow: expanded ? null : TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontSize: 14,
                    height: 1.4,
                    letterSpacing: 0.1,
                  ),
                ),
                if (text.length > 180) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: tvDpadActivateWrap(
                      context,
                      onActivate: controller.togglePlot,
                      borderRadius: 8,
                      child: TextButton(
                        onPressed: controller.togglePlot,
                        style: TextButton.styleFrom(
                          foregroundColor: cs.primary,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          expanded
                              ? 'filmDizi.plotLess'.tr
                              : 'filmDizi.plotMore'.tr,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _EpisodesPanel extends StatefulWidget {
  const _EpisodesPanel({
    required this.controller,
    this.shrinkWrap = false,
    this.autofocusFirstEpisode = false,
    this.firstEpisodeFocus,
    this.firstEpisodeArrowLeft,
    this.seasonFocus,
  });

  final FilmDiziSeriesDetailController controller;

  /// Dikey kaydırmalı ana gövde içindeyse [Column]; yatay düzen yan panelinde [ListView].
  final bool shrinkWrap;

  /// Yatay düzende kumanda ilk odağı ilk bölüme (Bölüm 1) gelsin.
  final bool autofocusFirstEpisode;

  /// Bölüm kartlarının sol ok hedefi (→ sol sütun İzle) ve ilk bölümün odak düğümü.
  final FocusNode? firstEpisodeFocus;
  final FocusNode? firstEpisodeArrowLeft;

  /// İlk sezon butonunun odak düğümü (sol sütun aksiyonlarından aşağı ok hedefi).
  final FocusNode? seasonFocus;

  @override
  State<_EpisodesPanel> createState() => _EpisodesPanelState();
}

class _EpisodesPanelState extends State<_EpisodesPanel> {
  /// Bölüm bazlı kalıcı odak düğümleri (kumanda oynatmadan dönünce odak korunur).
  final Map<String, FocusNode> _episodeNodes = {};

  /// Kullanıcının en son açtığı (oynattığı) bölümün anahtarı. Oynatıcıdan
  /// geri dönünce kumanda odağı bu bölüme döner (ilk girişte ilk bölüm).
  String? _focusedEpisodeKey;

  String _episodeKey(SeriesEpisodeOption o) => '${o.season}x${o.episodeNumber}_${o.channel.id}';

  FocusNode _nodeFor(SeriesEpisodeOption o) => _episodeNodes.putIfAbsent(
        _episodeKey(o),
        () => FocusNode(debugLabel: 'ep_${_episodeKey(o)}'),
      );

  @override
  void dispose() {
    for (final n in _episodeNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  /// Bölümü oynat; oynatıcıdan geri dönünce kumanda odağını aynı bölüme geri
  /// getir (TV modunda odak kaybını önler).
  Future<void> _playAndRestoreFocus(
    SeriesEpisodeOption opt,
    FocusNode node,
  ) async {
    // Geri dönüşte odak hedefi bu bölüm olsun (ilk bölüm değil) → autofocus
    // hedefi de buna kayar, böylece Bölüm 1 odağı çalmaz.
    if (widget.autofocusFirstEpisode) {
      setState(() => _focusedEpisodeKey = _episodeKey(opt));
    }
    await widget.controller.playEpisode(opt);
    if (!mounted) return;
    // Oynatıcıdan dönüş geçişi birkaç kare sürebilir; odağı oynatılan bölüme
    // ısrarla geri getir (route geçişi bitene kadar dene).
    if (widget.autofocusFirstEpisode && node.canRequestFocus) {
      scheduleTvFocusRestore(node, maxAttempts: 30);
    }
  }

  Widget _buildEpisodeTile(
    BuildContext context,
    List<SeriesEpisodeOption> list,
    int index,
  ) {
    debugPrint(
        '[EpisodesPanel] _buildEpisodeTile called for index $index (list.length=${list.length})');
    final opt = list[index];
    final isFirst = index == 0;
    final isLast = index == list.length - 1;
    final key = _episodeKey(opt);
    final firstNode = (widget.firstEpisodeFocus != null)
        ? widget.firstEpisodeFocus!
        : _nodeFor(list.first);
    final node = (isFirst && widget.firstEpisodeFocus != null)
        ? widget.firstEpisodeFocus!
        : _nodeFor(opt);
    final isFocusTarget =
        _focusedEpisodeKey == null ? isFirst : key == _focusedEpisodeKey;
    return _EpisodeCard(
      option: opt,
      controller: widget.controller,
      onPlay: () => _playAndRestoreFocus(opt, node),
      autofocus: widget.autofocusFirstEpisode && isFocusTarget,
      focusNode: node,
      arrowLeft: widget.firstEpisodeArrowLeft,
      arrowDown: (widget.autofocusFirstEpisode && isLast) ? firstNode : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final shrinkWrap = widget.shrinkWrap;
    return Obx(() {
      if (controller.episodesLoading.value) {
        return FilmDiziEpisodesLoadingSkeleton(shrinkWrap: shrinkWrap);
      }

      final err = controller.episodesError.value;
      final seasons = controller.seasons;
      final list = controller.episodesInSeason;
      final release = controller.seriesReleaseDate();
      debugPrint(
          '[EpisodesPanel] Build: shrinkWrap=$shrinkWrap, seasons.length=${seasons.length}, list.length=${list.length}');

      final children = <Widget>[
        if (err != null && err.isNotEmpty && list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              err,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14,
              ),
            ),
          ),
        // Bölüm listesi boşsa ve hata yoksa bilgi mesajı göster
        if (err == null && list.isEmpty && !controller.episodesLoading.value)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'filmDizi.series.noEpisodes'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
        if (seasons.isNotEmpty) ...[
          _SectionTitle('filmDizi.series.seasons'.tr),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: AppScrollPhysics.list(context: context),
              itemCount: seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = seasons[i];
                final sel = controller.selectedSeason.value == s;
                final isFirstSeason = i == 0;
                // İlk sezon butonu: sol sütun aksiyonlarından aşağı inilen hedef.
                // Sol ok → İzle butonu, aşağı ok → ilk bölüm.
                final firstEpNode = list.isNotEmpty
                    ? (widget.firstEpisodeFocus ?? _nodeFor(list.first))
                    : null;
                return tvDpadActivateWrap(
                  context,
                  onActivate: () => controller.selectSeason(s),
                  borderRadius: 22,
                  focusNode: isFirstSeason ? widget.seasonFocus : null,
                  arrowLeft:
                      isFirstSeason ? widget.firstEpisodeArrowLeft : null,
                  arrowDown: isFirstSeason ? firstEpNode : null,
                  child: Material(
                    color: sel
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      onTap: () => controller.selectSeason(s),
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Text(
                          'filmDizi.series.seasonN'.trParams({'n': '$s'}),
                          style: TextStyle(
                            color: Colors.white.withValues(
                              alpha: sel ? 1 : 0.8,
                            ),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (list.isNotEmpty) ...[
          _SectionTitle('filmDizi.series.episodes'.tr),
          if (release != null && release.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'filmDizi.series.release'.trParams({'date': release}),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ];

      if (shrinkWrap) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...children,
            if (list.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: i == list.length - 1 ? 0 : 10,
                    ),
                    child: _buildEpisodeTile(context, list, i),
                  );
                },
              ),
          ],
        );
      }

      return ListView.builder(
        physics: AppScrollPhysics.list(context: context),
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        itemCount: children.length + list.length,
        itemBuilder: (context, index) {
          if (index < children.length) {
            return children[index];
          }
          final i = index - children.length;
          return Padding(
            padding: EdgeInsets.only(
              bottom: i == list.length - 1 ? 0 : 10,
            ),
            child: _buildEpisodeTile(context, list, i),
          );
        },
      );
    });
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({
    required this.option,
    required this.controller,
    required this.onPlay,
    this.autofocus = false,
    this.focusNode,
    this.arrowLeft,
    this.arrowDown,
  });

  final SeriesEpisodeOption option;
  final FilmDiziSeriesDetailController controller;
  final VoidCallback onPlay;
  final bool autofocus;
  final FocusNode? focusNode;
  final FocusNode? arrowLeft;
  final FocusNode? arrowDown;

  @override
  Widget build(BuildContext context) {
    // Tüm verileri en başta güvenli şekilde alalım
    final safeChannelName = option.channel.name ?? '';
    final thumb = option.channel.logoUrl?.trim() ?? controller.posterUrl ?? '';
    final safePlot = option.plot?.trim();
    String? safeDuration;
    String safeEpisodeTitle = '';

    try {
      safeDuration = controller.durationLabel(option);
    } catch (e) {
      debugPrint('[EpisodeCard - durationLabel] Error: $e');
      safeDuration = null;
    }

    try {
      safeEpisodeTitle = controller.episodeListTitle(option) ?? safeChannelName;
    } catch (e) {
      debugPrint('[EpisodeCard - episodeListTitle] Error: $e');
      safeEpisodeTitle = safeChannelName;
    }

    try {
      // Debug: Episode card content
      debugPrint(
          '[EpisodeCard] Building card for episode: S${option.season}E${option.episodeNumber}');
      debugPrint('[EpisodeCard] Thumb: ${thumb.isNotEmpty ? thumb : "EMPTY"}');
      debugPrint('[EpisodeCard] Duration: ${safeDuration ?? "NULL"}');
      debugPrint('[EpisodeCard] Plot: ${safePlot ?? "NULL"}');
      debugPrint('[EpisodeCard] Channel name: $safeChannelName');
      debugPrint('[EpisodeCard] Episode title: $safeEpisodeTitle');
    } catch (_) {
      // Debug printler hata verse de devam edelim
    }

    try {
      final body = RecommendedFilmsGlassPanel(
        padding: const EdgeInsets.all(10),
        sectionStyle: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPlay,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 88,
                        height: 66,
                        child: thumb.isNotEmpty
                            ? RecommendedFilmsPosterImage(url: thumb)
                            : ColoredBox(
                                color: Colors.white.withValues(alpha: 0.08),
                                child: const Icon(
                                  Icons.live_tv_rounded,
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
                            safeEpisodeTitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          // TMDB bölüm tanıtım adı (varsa) — başlığın altında, vurgulu.
                          _SafeObx(
                            builder: (context) {
                              try {
                                final _ = controller.episodeTmdbInfo.isEmpty;
                                final epName =
                                    controller.episodeTmdbName(option);
                                if (epName?.isEmpty ?? true)
                                  return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    epName ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.95),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                      height: 1.2,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                debugPrint(
                                    '[EpisodeCard - epName Obx] Error: $e');
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                          if (safeDuration?.isNotEmpty ?? false) ...[
                            const SizedBox(height: 4),
                            Text(
                              safeDuration ?? '',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Yalnız dekoratif oynat ikonu (odaklanılabilir değil); OK tuşu
                    // doğrudan bölümü oynatır. Bölüm içi indirme butonu kaldırıldı
                    // → indirme artık "İndir" butonundaki bölüm seçim penceresinden.
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 36,
                    ),
                  ],
                ),
                // Bölüm açıklaması: Xtream `plot` varsa onu, yoksa TMDB'den gelen
                // bölüm özetini göster. TMDB özeti sonradan (async) gelebileceği
                // için Obx ile sarılı.
                _SafeObx(
                  builder: (context) {
                    try {
                      final _ = controller.episodeTmdbInfo.isEmpty;
                      final effective = (safePlot?.isNotEmpty ?? false)
                          ? safePlot
                          : controller.episodeTmdbOverview(option);
                      if (effective?.isEmpty ?? true) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Text(
                            effective ?? '',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    } catch (e) {
                      debugPrint('[EpisodeCard - overview Obx] Error: $e');
                      // Hata olursa varsayılan plot'u gösterelim (eğer varsa)
                      if (safePlot?.isNotEmpty ?? false) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              safePlot ?? '',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
      return tvDpadActivateWrap(
        context,
        onActivate: onPlay,
        autofocus: autofocus,
        focusNode: focusNode,
        arrowLeft: arrowLeft,
        arrowDown: arrowDown,
        child: body,
      );
    } catch (e) {
      debugPrint('[EpisodeCard - full build] Error: $e');
      // Tüm kart çökerse basit bir geri dönüş versin
      return RecommendedFilmsGlassPanel(
        padding: const EdgeInsets.all(10),
        sectionStyle: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPlay,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 88,
                    height: 66,
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.08),
                      child: const Icon(
                        Icons.live_tv_rounded,
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
                        safeChannelName,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.play_circle_fill_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 36,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

// Güvenli bir Obx wrapper'ı: GetX yaşam döngüsü hatalarını yakalar
class _SafeObx extends StatelessWidget {
  const _SafeObx({required this.builder});
  final Widget Function(BuildContext) builder;

  @override
  Widget build(BuildContext context) {
    try {
      return Obx(() => builder(context));
    } catch (e) {
      debugPrint('[_SafeObx] Error: $e');
      return const SizedBox.shrink();
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Dizi detayında tek satırlık yatay scroll pill listesi.
/// Eski `Wrap` çoklu satırda dağınık görünüyordu; bu sürüm her zaman düzenli.
class _PillWrap extends StatelessWidget {
  const _PillWrap({required this.pills});

  final List<FilmDiziMediaPill> pills;

  @override
  Widget build(BuildContext context) {
    if (pills.isEmpty) return const SizedBox.shrink();
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      return SizedBox(
        height: 28,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: pills.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final p = pills[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.highlight
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: ga.sheetBorder.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                p.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class _TrailerCard extends StatelessWidget {
  const _TrailerCard({required this.trailer});

  final FilmDiziTrailer trailer;

  Future<void> _open() async {
    final uri = Uri.tryParse(trailer.watchUrl);
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) {
      Get.snackbar('', 'browse.vod.trailerOpenFail'.tr);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final thumb = trailer.thumbnailUrl;
    final body = SizedBox(
      width: 220,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null)
                      CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
                    else
                      ColoredBox(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              trailer.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
    return tvDpadActivateWrap(context, onActivate: _open, child: body);
  }
}

class _CastChip extends StatelessWidget {
  const _CastChip({
    required this.member,
    required this.onTap,
    this.blockDownNav = false,
  });

  final CastMember member;
  final VoidCallback onTap;

  /// TV yatay sol sütunda oyuncular en alttadır; aşağı ok ile odak boşluğa
  /// kaçmasın diye aşağı tuşunu yutar.
  final bool blockDownNav;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.85,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  backgroundImage: member.profilePath != null
                      ? CachedNetworkImageProvider(member.profilePath!)
                      : null,
                  child: member.profilePath == null
                      ? const Icon(Icons.person, color: Colors.white38)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (member.character != null &&
                          member.character!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          member.character!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],

                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return tvDpadActivateWrap(
      context,
      onActivate: onTap,
      blockDown: blockDownNav,
      child: body,
    );
  }
}
