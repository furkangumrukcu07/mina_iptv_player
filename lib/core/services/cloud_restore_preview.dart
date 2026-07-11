import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'auth_service.dart';

/// Bulut yedeğinin kullanıcıya gösterilecek özeti.
@immutable
class CloudRestorePreview {
  const CloudRestorePreview({
    required this.playlistCount,
    required this.settingsCount,
    required this.localM3uCount,
    required this.profileCount,
  });

  final int playlistCount;
  final int settingsCount;
  final int localM3uCount;
  final int profileCount;

  bool get hasPlaylistData => playlistCount > 0 || localM3uCount > 0;

  bool get isEmpty =>
      playlistCount == 0 &&
      settingsCount == 0 &&
      localM3uCount == 0 &&
      profileCount == 0;

  static CloudRestorePreview fromBackup(Map<String, dynamic> data) {
    var settings = 0;
    var profiles = 0;
    final prefs = data['prefs'];
    if (prefs is Map) {
      settings = prefs.length;
      profiles = _profileCountFromPrefs(prefs);
    }

    return CloudRestorePreview(
      playlistCount: countCloudBackupPlaylistSources(data),
      settingsCount: settings,
      localM3uCount: _localM3uCount(data),
      profileCount: profiles,
    );
  }

  static int _localM3uCount(Map<String, dynamic> data) {
    final bySlot = data['localM3uBySlot'];
    if (bySlot is Map) {
      var n = 0;
      for (final v in bySlot.values) {
        if (v is String && v.trim().isNotEmpty) n++;
      }
      return n;
    }
    var n = 0;
    if (data['localM3u'] is String) n++;
    if (data['localM3u2'] is String) n++;
    return n;
  }

  static int _profileCountFromPrefs(Map<dynamic, dynamic> prefs) {
    final entry = prefs['mina_profiles_v1'];
    if (entry is! Map) return 0;
    final raw = entry['v'];
    if (raw is! String || raw.trim().isEmpty) return 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.length;
    } catch (_) {}
    return 0;
  }
}
