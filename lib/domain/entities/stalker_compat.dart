import 'dart:convert';

/// Stalker/Ministra MAG uyumluluk ön ayarları.
///
/// Tipik preset değerleri: MAG250, MAG250 legacy, MAG254, MAG322.
enum StalkerMagPreset {
  /// MAG250 + yaygın portal sürümü (varsayılan).
  genericSafe,

  /// Eski MAG250 imajı.
  mag250Legacy,

  /// MAG254 + katı kimlik.
  mag254Strict,

  /// MAG322 / Ministra modern.
  ministraModern,
}

enum StalkerLinkType {
  wifi,
  ethernet,
}

extension StalkerMagPresetX on StalkerMagPreset {
  String get storageId => switch (this) {
        StalkerMagPreset.genericSafe => 'genericSafe',
        StalkerMagPreset.mag250Legacy => 'mag250Legacy',
        StalkerMagPreset.mag254Strict => 'mag254Strict',
        StalkerMagPreset.ministraModern => 'ministraModern',
      };

  String get labelKey => 'stalker.preset.$storageId';

  static StalkerMagPreset fromStorage(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'mag250Legacy':
        return StalkerMagPreset.mag250Legacy;
      case 'mag254Strict':
        return StalkerMagPreset.mag254Strict;
      case 'ministraModern':
        return StalkerMagPreset.ministraModern;
      case 'genericSafe':
      default:
        return StalkerMagPreset.genericSafe;
    }
  }
}

extension StalkerLinkTypeX on StalkerLinkType {
  String get storageId => switch (this) {
        StalkerLinkType.wifi => 'wifi',
        StalkerLinkType.ethernet => 'ethernet',
      };

  String get xUserAgentLink => switch (this) {
        StalkerLinkType.wifi => 'WiFi',
        StalkerLinkType.ethernet => 'Ethernet',
      };

  String get labelKey => 'stalker.link.$storageId';

  static StalkerLinkType fromStorage(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'ethernet':
      case 'eth':
        return StalkerLinkType.ethernet;
      default:
        return StalkerLinkType.wifi;
    }
  }
}

/// get_profile / X-User-Agent için cihaz parmak izi.
final class StalkerMagPresetSpec {
  const StalkerMagPresetSpec({
    required this.stbType,
    required this.versionString,
    required this.imageVersion,
    required this.hwVersion,
    required this.apiSignature,
  });

  final String stbType;
  final String versionString;
  final String imageVersion;
  final String hwVersion;
  final String apiSignature;
}

StalkerMagPresetSpec stalkerMagPresetSpec(StalkerMagPreset preset) {
  switch (preset) {
    case StalkerMagPreset.genericSafe:
      return const StalkerMagPresetSpec(
        stbType: 'MAG250',
        versionString:
            'ImageDescription: 0.2.18-r19-pub-250; ImageDate: Mon Jun 12 11:04:49 '
            'EEST 2017; PORTAL version: 5.6.10; API Version: JS API version: 343; '
            'STB API version: 146; Player Engine version: 0x23',
        imageVersion: '218',
        hwVersion: '1.7-BD-00',
        apiSignature: '262',
      );
    case StalkerMagPreset.mag250Legacy:
      return const StalkerMagPresetSpec(
        stbType: 'MAG250',
        versionString:
            'ImageDescription: 0.2.16-r17-250; ImageDate: Thu Sep 13 12:08:56 '
            'EEST 2017; PORTAL version: 5.3.0; API Version: JS API version: 331; '
            'STB API version: 141; Player Engine version: 0x572',
        imageVersion: '216',
        hwVersion: '1.7-BD-00',
        apiSignature: '254',
      );
    case StalkerMagPreset.mag254Strict:
      return const StalkerMagPresetSpec(
        stbType: 'MAG254',
        versionString:
            'ImageDescription: 0.2.18-r23-254; ImageDate: Thu Nov 1 11:14:12 '
            'EET 2018; PORTAL version: 5.6.8; API Version: JS API version: 343; '
            'STB API version: 146; Player Engine version: 0x58c',
        imageVersion: '254',
        hwVersion: '2.6-IB-00',
        apiSignature: '263',
      );
    case StalkerMagPreset.ministraModern:
      return const StalkerMagPresetSpec(
        stbType: 'MAG322',
        versionString:
            'ImageDescription: 0.2.21-r14-254; ImageDate: Wed Apr 24 13:42:11 '
            'EEST 2019; PORTAL version: 5.6.8; API Version: JS API version: 343; '
            'STB API version: 146; Player Engine version: 0x5a1',
        imageVersion: '221',
        hwVersion: '2.6-IB-00',
        apiSignature: '270',
      );
  }
}

/// Stalker kaynağına bağlı kalıcı uyumluluk seçenekleri.
final class StalkerCompatOptions {
  const StalkerCompatOptions({
    this.magPreset = StalkerMagPreset.genericSafe,
    this.linkType = StalkerLinkType.wifi,
    this.hwVersionOverride = '',
  });

  final StalkerMagPreset magPreset;
  final StalkerLinkType linkType;

  /// Boşsa preset `hw_version` kullanılır.
  final String hwVersionOverride;

  static const empty = StalkerCompatOptions();

  String get effectiveHwVersion {
    final o = hwVersionOverride.trim();
    if (o.isNotEmpty) return o;
    return stalkerMagPresetSpec(magPreset).hwVersion;
  }

  StalkerCompatOptions copyWith({
    StalkerMagPreset? magPreset,
    StalkerLinkType? linkType,
    String? hwVersionOverride,
  }) {
    return StalkerCompatOptions(
      magPreset: magPreset ?? this.magPreset,
      linkType: linkType ?? this.linkType,
      hwVersionOverride: hwVersionOverride ?? this.hwVersionOverride,
    );
  }

  /// Stalker slotunda Xtream şifre alanına yazılan JSON (veya boş = varsayılan).
  static String encodeForStorage(StalkerCompatOptions o) {
    if (o.magPreset == StalkerMagPreset.genericSafe &&
        o.linkType == StalkerLinkType.wifi &&
        o.hwVersionOverride.trim().isEmpty) {
      return '';
    }
    return jsonEncode({
      'preset': o.magPreset.storageId,
      'link': o.linkType.storageId,
      if (o.hwVersionOverride.trim().isNotEmpty)
        'hw': o.hwVersionOverride.trim(),
    });
  }

  static StalkerCompatOptions decodeFromStorage(String? raw) {
    final t = (raw ?? '').trim();
    if (t.isEmpty || !t.startsWith('{')) return empty;
    try {
      final decoded = jsonDecode(t);
      if (decoded is! Map) return empty;
      return StalkerCompatOptions(
        magPreset: StalkerMagPresetX.fromStorage(decoded['preset']?.toString()),
        linkType: StalkerLinkTypeX.fromStorage(decoded['link']?.toString()),
        hwVersionOverride:
            (decoded['hw'] ?? decoded['hw_version'] ?? '').toString(),
      );
    } catch (_) {
      return empty;
    }
  }
}
