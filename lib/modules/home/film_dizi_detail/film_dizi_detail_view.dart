import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/home/film_dizi_detail_args.dart';
import '../../../core/home/film_dizi_media_pills.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/favorites_service.dart';
import '../../../core/theme/app_scroll_physics.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../../../core/theme/glass_appearance.dart';
import '../../../domain/entities/movie_model.dart';
import '../widgets/download_button.dart';
import '../widgets/film_dizi_detail_loading_skeleton.dart';
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
        final poster = controller.posterUrl;

        return Stack(
          fit: StackFit.expand,
          children: [
            if (poster != null && poster.isNotEmpty)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Transform.scale(
                    scale: 1.08,
                    child: CachedNetworkImage(
                      imageUrl: poster,
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
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0.94),
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
                      return FilmDiziDetailTopBar(
                        onBack: () => Get.back<void>(),
                        onFavorite: controller.toggleFavorite,
                        isFavorite: controller.isFavorite,
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

class _DetailScroll extends StatelessWidget {
  const _DetailScroll({required this.controller});

  final FilmDiziDetailController controller;

  @override
  Widget build(BuildContext context) {
    final meta = controller.meta.value;
    final title = meta?.title ?? controller.displayTitle;
    final poster = controller.posterUrl;
    final width = MediaQuery.sizeOf(context).width;
    final thumbW = width * 0.28;
    final similarW = (width - 48) / 2.4;

    return SingleChildScrollView(
      physics: AppScrollPhysics.list(context: context),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    Obx(() {
                      controller.meta.value;
                      controller.xtreamFields.value;
                      controller.ratingTick.value;
                      final rating = controller.imdbRating;
                      if (rating == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'IMDb',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              rating,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Obx(() {
                      controller.meta.value;
                      controller.xtreamFields.value;
                      final runtime = controller.runtimeLabel;
                      if (runtime == null) return const SizedBox.shrink();
                      return Padding(
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
                    }),
                    Obx(() {
                      controller.meta.value;
                      controller.xtreamFields.value;
                      if (!controller.hasHeaderInfoPanel) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _FilmHeaderPanel(controller: controller),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: (width * 0.56).clamp(200.0, 280.0),
              height: 46,
              child: _FilmPlayButton(
                onPressed: controller.play,
                posterUrl: controller.posterUrl,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: DownloadButton(
              itemId: 'vod_${controller.vod.id}',
              onStart: () =>
                  Get.find<DownloadService>().enqueueFilm(controller.vod),
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(height: 20),
          _SectionTitle('filmDizi.synopsis'.tr),
          const SizedBox(height: 8),
          Obx(() {
            controller.meta.value;
            controller.xtreamFields.value;
            final text = controller.synopsis;
            return RecommendedFilmsGlassPanel(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.90),
                  fontSize: 14,
                  height: 1.4,
                  letterSpacing: 0.1,
                ),
              ),
            );
          }),
          Obx(() {
            if (controller.trailers.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
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
                    itemCount: controller.trailers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final t = controller.trailers[i];
                      return _TrailerCard(trailer: t);
                    },
                  ),
                ),
              ],
            );
          }),
          Obx(() {
            controller.meta.value;
            controller.xtreamFields.value;
            final director = controller.directorLabel;
            final genres = controller.genreRowPills
                .map((p) => p.label.trim())
                .where((s) => s.isNotEmpty)
                .toList(growable: false);
            if (director == null && genres.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: FilmDiziQuickInfoPanel(
                director: director,
                genres: genres,
              ),
            );
          }),
          Obx(() {
            final cast = controller.meta.value?.cast;
            if (cast == null || cast.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _SectionTitle('filmDizi.cast'.tr),
                const SizedBox(height: 10),
                SizedBox(
                  height: 132,
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
          }),
          Obx(() {
            if (controller.similar.isEmpty) {
              return const SizedBox.shrink();
            }
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
                      final v = controller.similar[i];
                      return FilmDiziPosterCard.film(
                        vod: v,
                        posterWidth: similarW,
                        onTap: () => controller.openSimilar(v),
                      );
                    },
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Poster sağı — IMDb, süre, ses + kategori / çözünürlük / codec rozetleri.
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
    final genrePills = controller.genreRowPills;
    final techPills = controller.techRowPills;
    final showLanguage =
        language != null && streamLabels.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (year != null)
              _FilmMetaChip(
                icon: Icons.calendar_today_outlined,
                label: year,
              ),
            if (releaseDate != null)
              _FilmMetaChip(
                icon: Icons.event_outlined,
                label: releaseDate,
              ),
            if (rated != null)
              _FilmMetaChip(
                icon: Icons.local_movies_outlined,
                label: rated,
              ),
            if (country != null)
              _FilmMetaChip(
                icon: Icons.public_outlined,
                label: country,
              ),
            if (director != null)
              _FilmMetaChip(
                icon: Icons.movie_creation_outlined,
                label: director,
              ),
            if (showLanguage)
              _FilmMetaChip(
                icon: Icons.translate_rounded,
                label: language,
              ),
            for (final label in streamLabels)
              _FilmMetaChip(
                icon: label.toLowerCase().contains('altyaz')
                    ? Icons.subtitles_outlined
                    : Icons.volume_up_rounded,
                label: label,
              ),
          ],
        ),
        if (genrePills.isNotEmpty) ...[
          const SizedBox(height: 10),
          _PillWrap(pills: genrePills),
        ],
        if (techPills.isNotEmpty) ...[
          const SizedBox(height: 8),
          _PillWrap(pills: techPills, muted: true),
        ],
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
    );
  }
}

class _FilmMetaChip extends StatelessWidget {
  const _FilmMetaChip({
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


/// Tek satırlık, sığmazsa yatay kaydırılabilir pill listesi. Eski `Wrap`
/// uygulaması son pill'i bir alt satıra atıp ekranda dağınık görünüyordu;
/// bu sürüm pill'leri tek hizada, sırayla tutar.
class _PillWrap extends StatelessWidget {
  const _PillWrap({required this.pills, this.muted = false});

  final List<FilmDiziMediaPill> pills;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (pills.isEmpty) return const SizedBox.shrink();
    return Obx(() {
      final ga = GlassAppearance.fromLabel(
        Get.find<AppSettingsService>().themeLabel.value,
      );
      return SizedBox(
        height: 30,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: pills.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final p = pills[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.highlight
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.55)
                    : muted
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
    return tvDpadActivateWrap(context, onActivate: _open, child: body);
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
    final body = SizedBox(
      width: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                backgroundImage: member.profilePath != null
                    ? CachedNetworkImageProvider(member.profilePath!)
                    : null,
                child: member.profilePath == null
                    ? const Icon(Icons.person, color: Colors.white38)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                member.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (member.character != null &&
                  member.character!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  member.character!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return tvDpadActivateWrap(context, onActivate: onTap, child: body);
  }
}

class _FilmPlayButton extends StatelessWidget {
  const _FilmPlayButton({required this.onPressed, this.posterUrl});

  final VoidCallback onPressed;
  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    final btn = FilmDiziGlassPlayButton(
      label: 'filmDizi.watch'.tr,
      onPressed: onPressed,
      compact: true,
      posterUrl: posterUrl,
    );
    return tvDpadActivateWrap(context, onActivate: onPressed, child: btn);
  }
}
