import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_settings_service.dart';
import '../../../core/theme/glass_appearance.dart';

/// Film & Dizi detay sayfalarının «Hızlı Bilgi Paneli».
/// - Fragmanların hemen altında konumlanır.
/// - Tek bakışta görülebilen «Yönetmen» ve «Tür» bilgilerini cam çerçeveli
///   düzenli iki satır halinde sunar.
/// - Tür birden fazlaysa virgülle birleştirilip tek satır gösterilir,
///   sığmazsa ellipsis ile kısaltılır.
/// - Yönetmen ya da tür bilgisi yoksa o satır gösterilmez. Hiçbir bilgi
///   yoksa widget boş döner (`SizedBox.shrink`).
class FilmDiziQuickInfoPanel extends StatelessWidget {
  const FilmDiziQuickInfoPanel({
    super.key,
    required this.director,
    required this.genres,
  });

  final String? director;
  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    final hasDirector = director != null && director!.trim().isNotEmpty;
    final genreText = genres
        .map((g) => g.trim())
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList();
    final genreLine = genreText.isEmpty ? null : genreText.join(', ');

    final rows = <Widget>[];
    if (hasDirector) {
      rows.add(
        _QuickInfoRow(
          icon: Icons.movie_creation_outlined,
          labelKey: 'filmDizi.quickInfo.director',
          value: director!,
        ),
      );
    }
    if (genreLine != null) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 10));
      }
      rows.add(
        _QuickInfoRow(
          icon: Icons.local_movies_outlined,
          labelKey: 'filmDizi.quickInfo.genre',
          value: genreLine,
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 0.9,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ),
    );
  }
}

class _QuickInfoRow extends StatelessWidget {
  const _QuickInfoRow({
    required this.icon,
    required this.labelKey,
    required this.value,
  });

  final IconData icon;
  final String labelKey;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.78)),
        const SizedBox(width: 10),
        SizedBox(
          width: 78,
          child: Text(
            labelKey.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
