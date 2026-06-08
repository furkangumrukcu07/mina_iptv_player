import 'package:flutter/material.dart';

import 'mina_profile.dart';

/// Profil resmi (avatar) ikon kataloğu. [kProfileAvatarColors] ile **aynı
/// uzunlukta ve indeks hizalı** olmalıdır; `avatarId` her ikisine de indeks.
///
/// Gerçek görsel dosyası yerine ikon + renk kombinasyonu kullanılır: ek asset
/// gerektirmez, her temada keskin kalır ve cam stiliyle uyumludur.
const List<IconData> kProfileAvatarIcons = <IconData>[
  Icons.face_rounded,
  Icons.face_3_rounded,
  Icons.face_4_rounded,
  Icons.face_6_rounded,
  Icons.sentiment_satisfied_alt_rounded,
  Icons.pets_rounded,
  Icons.child_care_rounded,
  Icons.sports_esports_rounded,
  Icons.rocket_launch_rounded,
  Icons.music_note_rounded,
];

/// Toplam hazır profil resmi sayısı (renk + ikon hizalı).
int get kProfileAvatarCount => kProfileAvatarIcons.length;

/// [avatarId] için ikon. Aralık dışı değerler güvenle döngülenir.
IconData profileAvatarIcon(int avatarId) {
  if (kProfileAvatarIcons.isEmpty) return Icons.person_rounded;
  final i = avatarId % kProfileAvatarIcons.length;
  return kProfileAvatarIcons[i < 0 ? i + kProfileAvatarIcons.length : i];
}
