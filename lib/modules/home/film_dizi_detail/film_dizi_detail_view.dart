import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/film_dizi_media_pills.dart';
import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../domain/entities/movie_model.dart';
import '../widgets/download_button.dart';
import '../widgets/film_dizi_detail_loading_skeleton.dart';
import '../widgets/recommended_films_loading_skeleton.dart';
import '../widgets/film_dizi_detail_top_bar.dart';
import '../widgets/film_dizi_poster_card.dart';
import '../widgets/film_dizi_quick_info_panel.dart';
import '../widgets/recommended_films_glass.dart';
import '../widgets/recommended_films_poster_grid.dart';
import 'film_dizi_detail_controller.dart';

class FilmDiziDetailView extends GetView<FilmDiziDetailController> {
  const FilmDiziDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        final loading = controller.isLoading.value;
        final backdrop = controller.backdropUrl;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (backdrop != null && backdrop.isNotEmpty)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Transform.scale(
                    scale: 1.08,
                    child: CachedNetworkImage(
                      imageUrl: backdrop,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      errorWidget: (_, __, ___) =>
                          const ColoredBox(color: Colors.black),
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
                      Get.find<FavoritesService>().vodIds.length;
                      // Yatayda favori, İzle'nin altına taşındı → üst çubukta
                      // gösterilmez (TV + tablet + mobil yatay ortak düzen).
                      final landscape =
                          MediaQuery.orientationOf(context) ==
                          Orientation.landscape;
                      final isTv =
                          Get.find<AppSettingsService>().layoutMode.value ==
                          AppLayoutMode.tv;
                      return FilmDiziDetailTopBar(
                        onBack: () => Get.back<void>(),
                        onFavorite:
                            landscape ? null : controller.toggleFavorite,
                        isFavorite: controller.isFavorite,
                        // Yalnız TV yatayda odak İzle'ye gider → geri odağı kapalı.
                        autofocusBack: !(landscape && isTv),
                      );
                    }),
                    Expanded(
                      child: loading
                          ? const FilmDiziDetailLoadingSkeleton()
                          : _DetailScroll(controller: controller),
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

class _DetailScroll extends StatefulWidget {
  const _DetailScroll({required this.controller});

  final FilmDiziDetailController controller;

  @override
  State<_DetailScroll> createState() => _DetailScrollState();
}

class _DetailScrollState extends State<_DetailScroll> {
  final FocusNode _playFocus = FocusNode(debugLabel: 'filmPlay');

  FilmDiziDetailController get controller => widget.controller;

  @override
  void dispose() {
    _playFocus.dispose();
    super.dispose();
  }

  /// Oynatıcıdan geri dönünce TV kumanda odağını İzle butonunda tutar.
  Future<void> _playAndRestoreFocus() async {
    await controller.play();
    if (!mounted) return;
    final isTv =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
    if (!isTv) return;
    scheduleTvFocusRestore(_playFocus);
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isTv =
        Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
    final meta = controller.meta.value;
    final title = meta?.title ?? controller.displayTitle;
    final poster = controller.posterUrl;
    final width = MediaQuery.sizeOf(context).width;

    final Widget content;
    if (landscape) {
      // Yatay (TV + tablet + mobil yatay): ortak düzen. Poster + başlık/meta/
      // İzle üstte yan yana; favori butonu İzle'nin altında, yanında tür/teknik
      // rozetleri. Özet ve diğer bölümler posterin altından başlayıp tam
      // genişlikte (soldan) sıralanır — boş alan kalmaz. Otomatik İzle odağı
      // yalnız TV'de.
      final posterW = (width * 0.18).clamp(140.0, 240.0).toDouble();
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (poster != null) _poster(poster, posterW),
              const SizedBox(width: 16),
              Expanded(
                child: _headerColumn(
                  context,
                  title,
                  autofocusPlay: isTv,
                  playFocus: _playFocus,
                  onPlay: _playAndRestoreFocus,
                  trailing: _FilmTvFavoriteAndPills(controller: controller),
                ),
              ),
            ],
          ),
          ..._belowContent(context, tv: true),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (poster != null) _poster(poster, width * 0.28),
              const SizedBox(width: 14),
              Expanded(child: _headerColumn(context, title)),
            ],
          ),
          ..._belowContent(context),
        ],
      );
    }

    return SingleChildScrollView(
      physics: AppScrollPhysics.list(context: context),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: content,
    );
  }

  Widget _poster(String poster, double w) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: w,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: RecommendedFilmsPosterImage(url: poster),
        ),
      ),
    );
  }

  /// Poster sağındaki bilgi sütunu: başlık, IMDb/TMDB puanı, süre, yıl/ülke/dil
  /// meta satırı ve İzle/İndir butonları. [trailing] verilirse butonların
  /// altına eklenir (TV: favori + tür/teknik satırı). [autofocusPlay]: kumanda
  /// ilk odağı İzle butonuna gelir.
  Widget _headerColumn(
    BuildContext context,
    String title, {
    Widget? trailing,
    bool autofocusPlay = false,
    FocusNode? playFocus,
    Future<void> Function()? onPlay,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.2,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        Obx(() {
          controller.meta.value;
          controller.xtreamFields.value;
          controller.ratingTick.value;
          final rating = controller.imdbRating;
          final tmdb = controller.tmdbRatingLabel;
          final tmdbVotes = controller.tmdbVoteCountLabel;
          final runtime = controller.runtimeLabel;
          
          final ratingBadge = (rating == null && tmdb == null)
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (rating != null)
                        _RatingBadge(
                          source: 'IMDb',
                          value: rating,
                          color: Colors.amber,
                        ),
                      if (tmdb != null)
                        _RatingBadge(
                          source: 'TMDB',
                          value: tmdbVotes != null ? '$tmdb ($tmdbVotes)' : tmdb,
                          color: const Color(0xFF01B4E4),
                        ),
                    ],
                  ),
                );
          
          final runtimeBadge = runtime == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        runtime,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ratingBadge,
              runtimeBadge,
              _FilmHeaderPanel(controller: controller),
            ],
          );
        }),
        // "Ülke" satırının hemen altında, eşit ebatta yan yana
        // İzle + İndir butonları.
        const SizedBox(height: 14),
        _DetailActionButtons(
          controller: controller,
          autofocusPlay: autofocusPlay,
          playFocus: playFocus,
          onPlay: onPlay,
        ),
        if (trailing != null) ...[
          const SizedBox(height: 12),
          trailing,
        ],
      ],
    );
  }

  /// İzle/İndir altındaki bölümler: tür+teknik rozetleri (TMDB/OMDB), özet,
  /// fragman, künye, oyuncular, benzer filmler. Yatayda sağ sütunda; dikeyde
  /// poster satırının altında sıralanır.
  List<Widget> _belowContent(BuildContext context, {bool tv = false}) {
    final width = MediaQuery.sizeOf(context).width;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    // "Bunlar da ilginizi çekebilir" posterleri: yatayda 0.35, dikeyde %40
    // küçültülmüş (0.6) gösterilir.
    final similarW = ((width - 48) / 2.4) * (landscape ? 0.35 : 0.6);
    return [
      // TV'de tür/teknik rozetleri başlık alanına (favori yanına) taşındı;
      // burada tekrar gösterilmez. Diğer modlarda İzle/İndir altında.
      Obx(() {
        controller.meta.value;
        controller.xtreamFields.value;
        controller.metaEnriching.value;
        final genre = controller.genreRowPills;
        final tech = controller.techRowPills;
        final synopsis = controller.synopsis;
        final director = controller.directorLabel;
        final genres = controller.genreRowPills
            .map((p) => p.label.trim())
            .where((s) => s.isNotEmpty)
            .toList(growable: false);
        final cast = controller.meta.value?.cast;
        
        final pillsSection = tv
            ? const SizedBox.shrink()
            : (genre.isEmpty && tech.isEmpty
                ? (controller.metaEnriching.value
                    ? const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: FilmDiziPillsSkeleton(count: 3),
                      )
                    : const SizedBox.shrink())
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _DetailPillRow(genre: genre, tech: tech),
                  ));
          
          final quickInfoSection = director == null && genres.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: FilmDiziQuickInfoPanel(
                    director: director,
                    genres: genres,
                  ),
                );
          
          final castSection = cast == null || cast.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    _SectionTitle('filmDizi.cast'.tr),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 74,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: AppScrollPhysics.list(context: context),
                        itemCount: cast.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, i) {
                          return _CastChip(
                            member: cast[i],
                            onTap: () => controller.openActor(cast[i]),
                          );
                        },
                      ),
                    ),
                  ],
                );
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              pillsSection,
              const SizedBox(height: 20),
              _SectionTitle('filmDizi.synopsis'.tr),
              const SizedBox(height: 8),
              RecommendedFilmsGlassPanel(
                child: Text(
                  synopsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontSize: 14,
                    height: 1.4,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              quickInfoSection,
              castSection,
            ],
          );
        }),
      Obx(() {
        final trailers = controller.trailers;
        final similar = controller.similar;
        
        final trailerSection = trailers.isEmpty
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  _SectionTitle('filmDizi.trailers'.tr),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 148,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: AppScrollPhysics.list(context: context),
                      itemCount: trailers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final t = trailers[i];
                        return _TrailerCard(trailer: t);
                      },
                    ),
                  ),
                ],
              );
        
        final similarSection = similar.isEmpty
            ? const SizedBox.shrink()
            : Column(
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
                      itemCount: similar.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final v = similar[i];
                        return FilmDiziPosterCard.film(
                          vod: v,
                          posterWidth: similarW,
                          ensureVisibleOnFocus: false,
                          onTap: () => controller.openSimilar(v),
                        );
                      },
                    ),
                  ),
                ],
              );
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            trailerSection,
            similarSection,
          ],
        );
      }),
    ];
  }
}

/// Poster sağı — yıl, tarih, sınıf, ülke, dil + oyuncu önizleme satırı.
/// Tür / teknik rozetler artık posterin altında ayrı satırda gösterilir.
class _FilmHeaderPanel extends StatelessWidget {
  const _FilmHeaderPanel({required this.controller});

  final FilmDiziDetailController controller;

  @override
  Widget build(BuildContext context) {
    final year = controller.releaseYear;
    final releaseDate = controller.releaseDateLabel;
    final language = controller.languageLabel;
    final director = controller.directorLabel;
    final rated = controller.ratedLabel;
    final country = controller.countryLabel;
    final castPreview = controller.castPreviewLabel;
    final streamLabels = controller.streamMediaLabels;
    final showLanguage = language != null && streamLabels.isEmpty;

    final chips = <Widget>[
      if (year != null)
        _FilmMetaChip(icon: Icons.calendar_today_outlined, label: year),
      if (releaseDate != null)
        _FilmMetaChip(icon: Icons.event_outlined, label: releaseDate),
      if (rated != null)
        _FilmMetaChip(icon: Icons.local_movies_outlined, label: rated),
      if (country != null)
        _FilmMetaChip(icon: Icons.public_outlined, label: country),
      if (director != null)
        _FilmMetaChip(icon: Icons.movie_creation_outlined, label: director),
      if (showLanguage)
        _FilmMetaChip(icon: Icons.translate_rounded, label: language),
      for (final label in streamLabels)
        _FilmMetaChip(
          icon: label.toLowerCase().contains('altyaz')
              ? Icons.subtitles_outlined
              : Icons.volume_up_rounded,
          label: label,
        ),
    ];

    if (chips.isEmpty && castPreview == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chips.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: chips,
            ),
          if (castPreview != null) ...[
            const SizedBox(height: 10),
            Text(
              castPreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Eşit ebatta, yan yana "İzle" + "İndir" butonları. Detay başlığında ülke
/// satırının hemen altına yerleşir.
class _DetailActionButtons extends StatelessWidget {
  const _DetailActionButtons({
    required this.controller,
    this.autofocusPlay = false,
    this.playFocus,
    this.onPlay,
  });

  final FilmDiziDetailController controller;
  final bool autofocusPlay;
  final FocusNode? playFocus;
  final Future<void> Function()? onPlay;

  @override
  Widget build(BuildContext context) {
    const height = 46.0;
    final play = onPlay ?? controller.play;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: height,
            child: _FilmPlayButton(
              onPressed: play,
              posterUrl: controller.posterUrl,
              autofocus: autofocusPlay,
              focusNode: playFocus,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: height,
            child: DownloadButton(
              itemId: 'vod_${controller.vod.id}',
              compact: true,
              expand: true,
              onStart: () =>
                  Get.find<DownloadService>().enqueueFilm(controller.vod),
            ),
          ),
        ),
      ],
    );
  }
}

/// IMDb / TMDB puan rozeti (yıldız + kaynak + değer).
class _RatingBadge extends StatelessWidget {
  const _RatingBadge({
    required this.source,
    required this.value,
    required this.color,
  });

  final String source;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          source,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FilmMetaChip extends StatelessWidget {
  const _FilmMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
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


/// Posterin altında, tek satırda yatay kaydırılabilir tür + teknik rozetleri.
/// Tür pill'leri normal/vurgulu, teknik pill'ler (H.264, 5.1 vb.) sönük tonda.
class _DetailPillRow extends StatelessWidget {
  const _DetailPillRow({required this.genre, required this.tech});

  final List<FilmDiziMediaPill> genre;
  final List<FilmDiziMediaPill> tech;

  @override
  Widget build(BuildContext context) {
    final items = <({FilmDiziMediaPill pill, bool muted})>[
      for (final p in genre) (pill: p, muted: false),
      for (final p in tech) (pill: p, muted: true),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      return SizedBox(
        height: 30,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final it = items[i];
            final p = it.pill;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.highlight
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.55)
                    : it.muted
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: ga.sheetBorder.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                p.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 12,
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

/// TV: İzle/İndir butonlarının altında favori düğmesi ve hemen yanında
/// tür/teknik rozetleri (Son İzlenenler, Komedi, SD, H.264 ...).
class _FilmTvFavoriteAndPills extends StatelessWidget {
  const _FilmTvFavoriteAndPills({required this.controller});

  final FilmDiziDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.meta.value;
      controller.xtreamFields.value;
      Get.find<FavoritesService>().vodIds.length;
      final fav = controller.isFavorite;
      final genre = controller.genreRowPills;
      final tech = controller.techRowPills;
      final hasPills = genre.isNotEmpty || tech.isNotEmpty;
      return Row(
        children: [
          _FavoriteChip(active: fav, onTap: controller.toggleFavorite),
          if (hasPills) ...[
            const SizedBox(width: 10),
            Expanded(child: _DetailPillRow(genre: genre, tech: tech)),
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
      child: Material(
        color: Colors.transparent,
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
                        CachedNetworkImage(
                          imageUrl: thumb,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _trailerPlaceholder(),
                        )
                      else
                        _trailerPlaceholder(),
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
              if (trailer.subtitle != null)
                Text(
                  trailer.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return tvDpadActivateWrap(
      context,
      onActivate: _open,
      ensureVisibleOnFocus: false,
      child: body,
    );
  }

  Widget _trailerPlaceholder() {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(Icons.movie_creation_outlined, color: Colors.white38),
      ),
    );
  }
}

class _CastChip extends StatelessWidget {
  const _CastChip({required this.member, required this.onTap});

  final CastMember member;
  final VoidCallback onTap;

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
      ensureVisibleOnFocus: false,
      child: body,
    );
  }
}

class _FilmPlayButton extends StatelessWidget {
  const _FilmPlayButton({
    required this.onPressed,
    this.posterUrl,
    this.autofocus = false,
    this.focusNode,
  });

  final Future<void> Function() onPressed;
  final String? posterUrl;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    void activate() => onPressed();
    final btn = FilmDiziGlassPlayButton(
      label: 'filmDizi.watch'.tr,
      onPressed: activate,
      compact: true,
      posterUrl: posterUrl,
    );
    return tvDpadActivateWrap(
      context,
      onActivate: activate,
      autofocus: autofocus,
      focusNode: focusNode,
      child: btn,
    );
  }
}
