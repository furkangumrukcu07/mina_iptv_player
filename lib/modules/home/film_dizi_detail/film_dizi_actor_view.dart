import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_scroll_physics.dart';
import '../../../ui/tv_dpad_focus.dart';
import '../widgets/film_dizi_detail_loading_skeleton.dart';
import '../widgets/recommended_films_glass.dart';
import 'film_dizi_actor_controller.dart';

class FilmDiziActorView extends GetView<FilmDiziActorController> {
  const FilmDiziActorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RecommendedFilmsGlassBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RecommendedFilmsGlassHeader(
                  title: controller.args.name,
                  onBack: () => recommendedFilmsPop(context),
                ),
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const FilmDiziDetailLoadingSkeleton();
                    }
                    return _ActorBody(controller: controller);
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActorBody extends StatelessWidget {
  const _ActorBody({required this.controller});

  final FilmDiziActorController controller;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cellW = (width - 48) / 2.4;
    final bio = controller.bio.value?.trim();

    return SingleChildScrollView(
      physics: AppScrollPhysics.list(context: context),
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: CircleAvatar(
              radius: 56,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              backgroundImage: controller.photoUrl.value != null
                  ? CachedNetworkImageProvider(controller.photoUrl.value!)
                  : null,
              child: controller.photoUrl.value == null
                  ? const Icon(Icons.person, size: 56, color: Colors.white38)
                  : null,
            ),
          ),
          if (controller.args.character != null &&
              controller.args.character!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              controller.args.character!.trim(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'filmDizi.actorBio'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            RecommendedFilmsGlassPanel(
              child: Text(
                bio,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ],
          if (controller.credits.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'filmDizi.actorFilms'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: cellW * 1.48 + 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: AppScrollPhysics.list(context: context),
                itemCount: controller.credits.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final c = controller.credits[i];
                  return SizedBox(
                    width: cellW,
                    child: tvDpadActivateWrap(
                      context,
                      onActivate: () => controller.openCredit(c),
                      borderRadius: 10,
                      scaleOnFocus: 1.04,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => controller.openCredit(c),
                          borderRadius: BorderRadius.circular(10),
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: c.posterUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: c.posterUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          _posterFallback(),
                                    )
                                  : _posterFallback(),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (c.year != null)
                            Text(
                              c.year!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                        ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _posterFallback() {
    return ColoredBox(
      color: Colors.white.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(Icons.movie_rounded, color: Colors.white38),
      ),
    );
  }
}
