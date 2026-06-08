import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/profiles/mina_profile.dart';
import '../../../core/profiles/profile_avatars.dart';

/// Yuvarlak, cam stiline uygun profil resmi.
///
/// Renk + ikon kombinasyonundan oluşur ([kProfileAvatarColors] /
/// [kProfileAvatarIcons], `avatarId` ile hizalı). Üstte hafif bir parlama
/// katmanı ve yarı saydam beyaz kenar ile camsı bir görünüm verir; ek blur
/// (BackdropFilter) kullanmaz — grid içinde çok sayıda örnek olabileceği için
/// performans dostudur.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatarId,
    this.size = 96,
    this.selected = false,
    this.ringColor,
    this.dim = false,
    this.photoUrl,
  });

  final int avatarId;
  final double size;

  /// Verilirse ikon yerine bu URL'deki Google profil fotoğrafı gösterilir.
  final String? photoUrl;

  /// Seçili / aktif halka vurgusu.
  final bool selected;

  /// Seçili halka rengi (null → tema primary).
  final Color? ringColor;

  /// Düzenleme modunda hafif karartma (üzerine ikon bindirmek için).
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final base = Color(profileAvatarColor(avatarId));
    final ring = ringColor ?? Theme.of(context).colorScheme.primary;
    final icon = profileAvatarIcon(avatarId);
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, 0.18)!,
            Color.lerp(base, Colors.black, 0.42)!,
          ],
        ),
        border: Border.all(
          color: selected ? ring : Colors.white.withValues(alpha: 0.22),
          width: selected ? 3 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: size * 0.12,
            offset: Offset(0, size * 0.04),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Google profil fotoğrafı (varsa) — daireyi tamamen kaplar.
          if (hasPhoto)
            Positioned.fill(
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: photoUrl!,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 180),
                  errorWidget: (_, __, ___) => Icon(
                    icon,
                    color: Colors.white.withValues(alpha: 0.95),
                    size: size * 0.5,
                  ),
                ),
              ),
            ),
          // Üst camsı parlama.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    Colors.white.withValues(alpha: hasPhoto ? 0.12 : 0.28),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          if (!hasPhoto)
            Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.95),
              size: size * 0.5,
            ),
          if (dim)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.42),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
