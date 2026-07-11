import 'stalker_compat.dart';

sealed class PlaylistSource {
  const PlaylistSource();
}

final class M3uSource extends PlaylistSource {
  const M3uSource({required this.url});
  final String url;
}

final class XtreamSource extends PlaylistSource {
  const XtreamSource({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  /// Example: `http://host:port` (no trailing slash required).
  final String baseUrl;
  final String username;
  final String password;
}

final class StalkerSource extends PlaylistSource {
  const StalkerSource({
    required this.baseUrl,
    required this.macAddress,
    this.magPreset = StalkerMagPreset.genericSafe,
    this.linkType = StalkerLinkType.wifi,
    this.hwVersionOverride = '',
  });

  final String baseUrl;
  final String macAddress;

  /// MAG uyumluluk ön ayarı.
  final StalkerMagPreset magPreset;

  /// X-User-Agent `Link: WiFi|Ethernet`.
  final StalkerLinkType linkType;

  /// Boşsa preset `hw_version` kullanılır.
  final String hwVersionOverride;

  StalkerCompatOptions get compat => StalkerCompatOptions(
        magPreset: magPreset,
        linkType: linkType,
        hwVersionOverride: hwVersionOverride,
      );

  StalkerSource copyWith({
    String? baseUrl,
    String? macAddress,
    StalkerMagPreset? magPreset,
    StalkerLinkType? linkType,
    String? hwVersionOverride,
  }) {
    return StalkerSource(
      baseUrl: baseUrl ?? this.baseUrl,
      macAddress: macAddress ?? this.macAddress,
      magPreset: magPreset ?? this.magPreset,
      linkType: linkType ?? this.linkType,
      hwVersionOverride: hwVersionOverride ?? this.hwVersionOverride,
    );
  }
}
