import 'dart:convert';

/// Profil avatarı için hazır renk paleti. `avatarId` bu listeye indekstir.
const List<int> kProfileAvatarColors = <int>[
  0xFFE53935, // kırmızı
  0xFF8E24AA, // mor
  0xFF3949AB, // indigo
  0xFF039BE5, // mavi
  0xFF00897B, // teal
  0xFF43A047, // yeşil
  0xFFFB8C00, // turuncu
  0xFFF4511E, // koyu turuncu
  0xFF6D4C41, // kahve
  0xFF546E7A, // gri-mavi
];

int profileAvatarColor(int avatarId) {
  if (kProfileAvatarColors.isEmpty) return 0xFF3949AB;
  final i = avatarId % kProfileAvatarColors.length;
  return kProfileAvatarColors[i < 0 ? i + kProfileAvatarColors.length : i];
}

/// Netflix tarzı kullanıcı profili.
///
/// İçerik (M3U/Xtream listeleri + kimlik bilgileri) tüm profiller arasında
/// PAYLAŞILIR; yalnızca deneyim tercihleri (tema, dil, ana ekran düzeni,
/// +18 gizleme, altyazı, favoriler, izleme geçmişi) profile özeldir.
class MinaProfile {
  const MinaProfile({
    required this.id,
    required this.name,
    required this.avatarId,
    required this.createdAt,
    this.lockHash,
    this.recoveryHash,
    this.photoUrl,
    this.googleLinked,
  });

  /// Benzersiz profil kimliği (snapshot anahtarı için de kullanılır).
  final String id;
  final String name;

  /// [kProfileAvatarColors] listesine indeks.
  final int avatarId;

  /// Google hesabının profil fotoğrafı URL'si (yalnızca birincil profil için,
  /// kullanıcı Google ile oturum açtığında otomatik atanır). Null ise ikon +
  /// renk avatarı kullanılır.
  final String? photoUrl;

  /// Birincil profil Google hesabıyla otomatik eşitleniyor mu?
  /// - `null`: hiç eşitlenmedi (ilk Google girişinde eşitlenebilir).
  /// - `true`: Google'dan eşitlendi; isim/foto Google değişince güncellenir.
  /// - `false`: kullanıcı manuel düzenledi; otomatik eşitleme durdu.
  final bool? googleLinked;

  /// SHA-256 PIN hash'i (null/boş = kilitsiz). Düz metin asla saklanmaz.
  final String? lockHash;

  /// SHA-256 kurtarma anahtarı (özel anahtar) hash'i. PIN unutulduğunda bu
  /// anahtarla sıfırlanır. Düz metin asla saklanmaz.
  final String? recoveryHash;

  /// Oluşturulma zamanı (epoch ms) — sıralama için.
  final int createdAt;

  bool get isLocked => lockHash != null && lockHash!.isNotEmpty;

  bool get hasRecovery => recoveryHash != null && recoveryHash!.isNotEmpty;

  /// Profil adının baş harfi (avatar üzerinde gösterilir).
  String get initial {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.substring(0, 1).toUpperCase();
  }

  MinaProfile copyWith({
    String? name,
    int? avatarId,
    String? lockHash,
    String? recoveryHash,
    bool clearLock = false,
    String? photoUrl,
    bool clearPhoto = false,
    bool? googleLinked,
  }) {
    return MinaProfile(
      id: id,
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      lockHash: clearLock ? null : (lockHash ?? this.lockHash),
      recoveryHash: clearLock ? null : (recoveryHash ?? this.recoveryHash),
      createdAt: createdAt,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      googleLinked: googleLinked ?? this.googleLinked,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'avatarId': avatarId,
        if (lockHash != null && lockHash!.isNotEmpty) 'lockHash': lockHash,
        if (recoveryHash != null && recoveryHash!.isNotEmpty)
          'recoveryHash': recoveryHash,
        'createdAt': createdAt,
        if (photoUrl != null && photoUrl!.isNotEmpty) 'photoUrl': photoUrl,
        if (googleLinked != null) 'googleLinked': googleLinked,
      };

  factory MinaProfile.fromJson(Map<String, dynamic> j) {
    final lock = (j['lockHash'] as String?)?.trim();
    final recovery = (j['recoveryHash'] as String?)?.trim();
    final photo = (j['photoUrl'] as String?)?.trim();
    return MinaProfile(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      avatarId: (j['avatarId'] as num?)?.toInt() ?? 0,
      lockHash: (lock == null || lock.isEmpty) ? null : lock,
      recoveryHash: (recovery == null || recovery.isEmpty) ? null : recovery,
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      photoUrl: (photo == null || photo.isEmpty) ? null : photo,
      googleLinked: j['googleLinked'] is bool ? j['googleLinked'] as bool : null,
    );
  }

  static List<MinaProfile> listFromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <MinaProfile>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <MinaProfile>[];
      final out = <MinaProfile>[];
      for (final e in decoded) {
        if (e is Map) {
          final p = MinaProfile.fromJson(Map<String, dynamic>.from(e));
          if (p.id.isNotEmpty) out.add(p);
        }
      }
      return out;
    } catch (_) {
      return <MinaProfile>[];
    }
  }

  static String listToJsonString(List<MinaProfile> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());
}
