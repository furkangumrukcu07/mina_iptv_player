import '../../data/remote/xtream_api.dart';
import '../../domain/entities/epg_entities.dart';

/// Xtream / üçüncü parti paneller için EPG tabanlı catch-up (arşiv) URL ön ayarları.
enum CatchUpUrlPreset {
  /// Catch-up URL üretilmez.
  off,

  /// Yaygın yol: `/timeshift/user/pass/süre/başlangıç/stream_id.ext`
  xtreamTimeshiftPath,

  /// Bazı paneller: `streaming/timeshift.php?…`
  timeshiftPhpQuery,

  /// [CatchUpUrlDefaults] yerine kullanıcı metni.
  custom;

  static const storageKeyOff = 'off';
  static const storageKeyPath = 'xtream_path';
  static const storageKeyPhp = 'timeshift_php';
  static const storageKeyCustom = 'custom';

  static CatchUpUrlPreset fromStorage(String? raw) {
    switch (raw?.trim()) {
      case storageKeyPath:
        return CatchUpUrlPreset.xtreamTimeshiftPath;
      case storageKeyPhp:
        return CatchUpUrlPreset.timeshiftPhpQuery;
      case storageKeyCustom:
        return CatchUpUrlPreset.custom;
      case storageKeyOff:
      case '':
      case null:
        return CatchUpUrlPreset.off;
      default:
        return CatchUpUrlPreset.off;
    }
  }

  String get storageValue {
    switch (this) {
      case CatchUpUrlPreset.off:
        return storageKeyOff;
      case CatchUpUrlPreset.xtreamTimeshiftPath:
        return storageKeyPath;
      case CatchUpUrlPreset.timeshiftPhpQuery:
        return storageKeyPhp;
      case CatchUpUrlPreset.custom:
        return storageKeyCustom;
    }
  }
}

/// Varsayılan şablonlar (çoğu Xtream uyumlu panel ile uyumludur; sunucuya göre özelleştirin).
abstract final class CatchUpUrlDefaults {
  CatchUpUrlDefaults._();

  /// Klasik Xtream timeshift yolu; tarih **UTC** `YYYY-MM-DD:HH-mm-ss`.
  static const xtreamTimeshiftPath =
      '{server}/timeshift/{username}/{password}/{duration}/{start_utc_ymd_hms}/{stream_id}.{extension}';

  /// Sorgu dizgesi örneği; `start` Unix saniye (UTC).
  static const timeshiftPhpQuery =
      '{server}/streaming/timeshift.php?username={username}&password={password}&stream={stream_id}&start={start_unix}&duration={duration}';
}

/// `{server}`, `{username}`, `{start_utc_ymd_hms}`, `{duration}` vb. yer tutucuları doldurur.
///
/// Bilinmeyen `{anahtar}` ifadeleri olduğu gibi bırakılır (panel özel alanları için).
abstract final class CatchUpUrlBuilder {
  CatchUpUrlBuilder._();

  static String? build({
    required XtreamApi api,
    required int streamId,
    required EpgProgramme programme,
    required String template,
    String extension = 'm3u8',
  }) {
    final t = template.trim();
    if (t.isEmpty) return null;

    final duration = programme.end.difference(programme.start).inSeconds;
    if (duration < 1) return null;

    final startUtc = programme.start.toUtc();
    final endUtc = programme.end.toUtc();
    final startUnix = startUtc.millisecondsSinceEpoch ~/ 1000;
    final endUnix = endUtc.millisecondsSinceEpoch ~/ 1000;

    final enc = api.encodeCredentialComponent;
    final server = api.serverBase;
    final u = enc(api.username);
    final p = enc(api.password);
    final sid = '$streamId';
    final ext = extension.trim().isEmpty ? 'm3u8' : extension.trim().toLowerCase();

    final map = <String, String>{
      'server': server,
      'username': u,
      'password': p,
      'stream_id': sid,
      'stream': sid,
      'duration': '$duration',
      'duration_sec': '$duration',
      'start_unix': '$startUnix',
      'end_unix': '$endUnix',
      'start_ms': '${startUtc.millisecondsSinceEpoch}',
      'end_ms': '${endUtc.millisecondsSinceEpoch}',
      'start_utc_ymd_hms': _formatXtreamUtcSegment(startUtc),
      'start_local_ymd_hms': _formatXtreamLocalSegment(programme.start),
      'extension': ext,
    };

    final out = t.replaceAllMapped(RegExp(r'\{([a-z0-9_]+)\}'), (m) {
      final key = m.group(1);
      if (key == null) return m.group(0)!;
      return map[key] ?? m.group(0)!;
    });

    final uri = Uri.tryParse(out);
    if (uri == null || !uri.hasScheme) return null;
    return out;
  }

  /// `YYYY-MM-DD:HH-mm-ss` (UTC), çoğu panelin timeshift yolu bu biçimi bekler.
  static String _formatXtreamUtcSegment(DateTime utc) {
    final d = utc.toUtc();
    final ymd =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final hms =
        '${d.hour.toString().padLeft(2, '0')}-${d.minute.toString().padLeft(2, '0')}-${d.second.toString().padLeft(2, '0')}';
    return '$ymd:$hms';
  }

  static String _formatXtreamLocalSegment(DateTime local) {
    final d = local;
    final ymd =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final hms =
        '${d.hour.toString().padLeft(2, '0')}-${d.minute.toString().padLeft(2, '0')}-${d.second.toString().padLeft(2, '0')}';
    return '$ymd:$hms';
  }
}
