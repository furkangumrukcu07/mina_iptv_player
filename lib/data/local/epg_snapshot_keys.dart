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
        final skip = app.xtreamSkipPanelXmltvEpg.value ? 1 : 0;
        return 'v1|xtream|$xk|$skip';
      case M3uSource():
        final u = app.xmltvUrl.value.trim();
        if (u.isEmpty) return null;
        final h = md5.convert(utf8.encode(u)).toString();
        return 'v1|m3u|$h';
    }
  }
}
