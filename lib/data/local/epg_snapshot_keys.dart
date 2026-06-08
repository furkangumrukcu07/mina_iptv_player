import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/services/app_settings_service.dart';
import '../../domain/entities/playlist_source.dart';

/// EPG disk önbelleği: aynı kaynak + aynı Xtream XMLTV modu için tek dosya.
abstract final class EpgSnapshotKeys {
  /// M3U’da XMLTV URL yoksa önbellek kullanılmaz (`null`).
  static String? logicalKeyFor(PlaylistSource source, AppSettingsService app) {
    switch (source) {
      case XtreamSource():
        final xk = AppSettingsService.xtreamPreferenceKey(source);
        // v3: `get_all_live_epg` (stream_id) + panel `xmltv.php` (epg_channel_id).
        return 'v3|xtream|$xk';
      case M3uSource():
        final u = app.effectiveM3uXmltvUrl.trim();
        if (u.isEmpty) return null;
        final h = md5.convert(utf8.encode(u)).toString();
        return 'v1|m3u|$h';
    }
  }
}
