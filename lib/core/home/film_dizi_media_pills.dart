import 'package:get/get.dart';

import '../../domain/entities/vod.dart';
import '../services/app_settings_service.dart';
import 'recommended_films_catalog.dart';

/// Teknik / tür rozeti.
class FilmDiziMediaPill {
  const FilmDiziMediaPill(this.label, {this.highlight = false});

  final String label;
  final bool highlight;
}

abstract final class FilmDiziMediaPills {
  FilmDiziMediaPills._();

  static List<FilmDiziMediaPill> genrePills(String? genreCsv) {
    if (genreCsv == null || genreCsv.trim().isEmpty) return [];
    return genreCsv
        .split(RegExp(r'[,;/|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.toUpperCase() != 'N/A')
        .map((e) => FilmDiziMediaPill(e))
        .toList();
  }

  static List<FilmDiziMediaPill> categoryPill(String? categoryName) {
    final n = categoryName?.trim();
    if (n == null || n.isEmpty) return [];
    return [FilmDiziMediaPill(n)];
  }

  /// 720p, H.264, Dolby Digital, Stereo vb.
  ///
  /// Öncelik: Xtream `get_vod_info` → VOD listesi (süre/uzantı) → isim/URL → OMDB yok.
  static List<FilmDiziMediaPill> techPills(
    VodItem v, {
    Map<String, String>? xtreamFields,
  }) {
    final out = <FilmDiziMediaPill>[];
    final seen = <String>{};

    void add(String label, {bool highlight = false}) {
      final key = label.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) return;
      out.add(FilmDiziMediaPill(label, highlight: highlight));
    }

    final blob =
        '${v.name} ${v.streamUrl} ${v.containerExtension ?? ''} ${xtreamFields?.values.join(' ') ?? ''}'
            .toLowerCase();

    final videoCodec = xtreamFields?['video_codec']?.toLowerCase() ?? '';
    final audioCodec = xtreamFields?['audio_codec']?.toLowerCase() ?? '';
    final resolution = xtreamFields?['video_resolution']?.toLowerCase() ?? '';
    final bitrate = xtreamFields?['bitrate']?.toLowerCase() ?? '';

    String? res;
    final resBlob = '$blob $resolution $bitrate';
    if (_has(resBlob, ['3840', '2160', '4k', 'uhd'])) {
      res = '4K';
    } else if (_has(resBlob, ['1080', 'fullhd', 'full hd'])) {
      res = '1080p';
    } else if (_has(resBlob, ['720'])) {
      res = '720p';
    } else if (_has(resBlob, ['576', '480', r'\bsd\b', ' sd '])) {
      res = 'SD';
    }
    if (res != null) {
      add(res, highlight: res == '720p' || res == '1080p' || res == '4K');
    }

    final codecBlob = '$blob $videoCodec $audioCodec';
    if (_has(codecBlob, ['h265', 'hevc', 'x265'])) {
      add('HEVC');
    } else if (_has(codecBlob, ['h264', 'x264', 'avc'])) {
      add('H.264', highlight: true);
    } else if (v.containerExtension?.toLowerCase() == 'mkv' &&
        !_has(codecBlob, ['hevc', 'h265'])) {
      add('H.264');
    }

    if (_has(codecBlob, ['dolby digital', 'ac3', 'eac3', 'dd+', 'dolby'])) {
      add('Dolby Digital');
    } else if (_has(codecBlob, ['dts', 'dts-hd'])) {
      add('DTS');
    } else if (_has(codecBlob, ['aac', 'mp4a'])) {
      add('AAC');
    }

    if (_has(codecBlob, ['stereo', '2.0', '2ch'])) {
      add('Stereo');
    } else if (_has(codecBlob, ['5.1', 'surround', '7.1'])) {
      add('5.1');
    }

    final audio = xtreamFields?['stream_audio_langs']?.toLowerCase() ?? '';
    if (audio.contains('stereo')) add('Stereo');
    if (audio.contains('5.1') || audio.contains('surround')) add('5.1');

    return out;
  }

  /// 4K / 1080p / 720p / SD — techPills içinden ilk çözünürlük.
  static String? qualityLabel(List<FilmDiziMediaPill> tech) {
    for (final p in tech) {
      if (p.label == '4K' ||
          p.label == '1080p' ||
          p.label == '720p' ||
          p.label == 'SD' ||
          p.label == '480p') {
        return p.label;
      }
    }
    return null;
  }

  /// Ses / altyazı / dublaj rozetleri (Xtream alanları → isim/kategori).
  static List<String> streamMediaLabels(
    VodItem v,
    String categoryName, {
    Map<String, String>? xtreamFields,
  }) {
    final out = <String>[];
    void ingest(String? raw, bool isSub) {
      if (raw == null || raw.trim().isEmpty) return;
      for (final p in raw.split(RegExp(r'[,;|/\n]'))) {
        final code = _langCodeForPill(p.trim());
        if (code.isEmpty) continue;
        out.add(isSub ? '$code Altyazı' : '$code Ses');
      }
    }

    ingest(xtreamFields?['stream_audio_langs'], false);
    ingest(xtreamFields?['stream_subtitle_langs'], true);

    if (out.isEmpty) {
      _ingestLangFromBlob('${v.name} $categoryName', out);
    }

    if (out.isEmpty) {
      final lang = _appLanguageCode();
      final display = _langDisplay(lang);
      if (RecommendedFilmsLanguageMatcher.isNativeDub(v, categoryName)) {
        out.add('$display Dublaj');
      } else if (RecommendedFilmsLanguageMatcher.isNativeSub(v, categoryName)) {
        out.add('$display Altyazı');
      }
    }

    return out.toSet().toList();
  }

  static String _appLanguageCode() {
    if (Get.isRegistered<AppSettingsService>()) {
      final fromSettings =
          Get.find<AppSettingsService>().languageCode.value.trim();
      if (fromSettings.isNotEmpty) return fromSettings.toLowerCase();
    }
    return Get.locale?.languageCode.toLowerCase() ?? 'tr';
  }

  static String _langDisplay(String lang) => switch (lang) {
        'tr' => 'TR',
        'en' => 'EN',
        'de' => 'DE',
        'fr' => 'FR',
        'es' => 'ES',
        'ar' => 'AR',
        'ru' => 'RU',
        _ => lang.toUpperCase(),
      };

  static void _ingestLangFromBlob(String blob, List<String> out) {
    final b = blob.toLowerCase();
    final pairs = <(RegExp, String, bool)>[
      (RegExp(r'\btr\s*dublaj|türkçe\s*dublaj|turkce\s*dublaj|\(tr\)|\|tr\|'),
          'TR Dublaj', false),
      (RegExp(r'\ben\s*dub|english\s*dub|\(en\)\s*dub'), 'EN Dublaj', false),
      (RegExp(r'\bde\s*dub|deutsch'), 'DE Dublaj', false),
      (RegExp(r'\btr\s*altyaz|türkçe\s*altyaz|turkce\s*altyaz'), 'TR Altyazı', true),
      (RegExp(r'\ben\s*sub|english\s*sub'), 'EN Altyazı', true),
      (RegExp(r'\bdual\s*audio|dual'), 'Dual Ses', false),
    ];
    for (final (re, label, _) in pairs) {
      if (re.hasMatch(b) && !out.contains(label)) out.add(label);
    }
  }

  static String _langCodeForPill(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return '';
    if (t.length <= 3 && RegExp(r'^[a-z]{2,3}$').hasMatch(t)) {
      return t.toUpperCase();
    }
    if (t.contains('turk') || t.contains('türk')) return 'TR';
    if (t.contains('english') || t == 'eng') return 'EN';
    if (t.contains('german') || t.contains('deutsch')) return 'DE';
    if (t.contains('french') || t.contains('français')) return 'FR';
    if (t.contains('spanish') || t.contains('español')) return 'ES';
    if (t.contains('arab')) return 'AR';
    if (t.contains('russian')) return 'RU';
    return '';
  }

  static bool _has(String blob, List<String> tokens) {
    for (final t in tokens) {
      if (t.startsWith(r'\b')) {
        if (RegExp(t, caseSensitive: false).hasMatch(blob)) return true;
      } else if (blob.contains(t)) {
        return true;
      }
    }
    return false;
  }

  /// Süre: OMDB/TMDB → Xtream → VOD listesi → film adı.
  static String? formatRuntime({
    String? omdbRuntime,
    int? durationSecs,
    String? durationMinutes,
    String? xtreamDurationSecs,
    String? vodName,
  }) {
    final mins = _resolveDurationMinutes(
      omdbRuntime: omdbRuntime,
      durationSecs: durationSecs,
      durationMinutes: durationMinutes,
      xtreamDurationSecs: xtreamDurationSecs,
      vodName: vodName,
    );
    if (mins == null || mins <= 0) return null;
    return _fmtMinutes(mins);
  }

  static int? _resolveDurationMinutes({
    String? omdbRuntime,
    int? durationSecs,
    String? durationMinutes,
    String? xtreamDurationSecs,
    String? vodName,
  }) {
    if (omdbRuntime != null &&
        omdbRuntime.trim().isNotEmpty &&
        omdbRuntime != 'N/A') {
      final m = RegExp(r'(\d+)').firstMatch(omdbRuntime);
      final mins = m != null ? int.tryParse(m.group(1)!) : null;
      if (mins != null && mins > 0) return mins;
    }

    if (durationMinutes != null) {
      final m = int.tryParse(durationMinutes.trim());
      if (m != null && m > 0) return m;
    }

    if (xtreamDurationSecs != null) {
      final secs = int.tryParse(xtreamDurationSecs.trim());
      if (secs != null && secs > 0) return (secs + 29) ~/ 60;
    }

    if (durationSecs != null && durationSecs > 0) {
      return (durationSecs + 29) ~/ 60;
    }

    return _minutesFromVodName(vodName);
  }

  static int? _minutesFromVodName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final n = name;

    final hMin = RegExp(
      r'(\d+)\s*h(?:ours?|r)?\s*(\d+)\s*m(?:in(?:ute)?s?)?',
      caseSensitive: false,
    ).firstMatch(n);
    if (hMin != null) {
      final h = int.tryParse(hMin.group(1)!);
      final m = int.tryParse(hMin.group(2)!);
      if (h != null && m != null) return h * 60 + m;
    }

    final minOnly = RegExp(
      r'(\d{2,3})\s*(?:min(?:ute)?s?|dk)\b',
      caseSensitive: false,
    ).firstMatch(n);
    if (minOnly != null) {
      final m = int.tryParse(minOnly.group(1)!);
      if (m != null && m >= 20 && m <= 500) return m;
    }

    return null;
  }

  static String _fmtMinutes(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    return '${m}min';
  }
}
