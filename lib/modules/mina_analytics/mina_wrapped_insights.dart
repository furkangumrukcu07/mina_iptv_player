import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/mina_analytics_service.dart';

/// **Mina Wrapped — yerel "yapay zekâ" içgörü motoru.**
///
/// Buluta hiç veri göndermeden, tamamen cihaz üzerindeki izleme istatistik
/// snapshot'ından kişiselleştirilmiş bir *izleyici personası* + çarpıcı
/// içgörüler üretir. Spotify Wrapped ruhunda; kullanıcının kendini özel
/// hissetmesini ve "Mina Wrapped benim hakkımda" algısını yaratmayı hedefler.
///
/// Tüm metinler i18n anahtarlarından (`analytics.persona.*`,
/// `analytics.insight.*`) gelir; saat biçimlendirmesi için çağıran tarafın
/// [formatHours] callback'i kullanılır (view ile aynı format).
enum MinaWrappedPersona {
  /// Yeterli veri yok — yeni kullanıcı.
  newcomer,

  /// Film ağırlıklı.
  cinephile,

  /// Dizi ağırlıklı (maraton).
  binger,

  /// Canlı yayın ağırlıklı.
  liveWire,

  /// Geç saatlerde izleyen.
  nightOwl,

  /// Dengeli / çok yönlü.
  explorer,
}

/// Tek bir içgörü satırı (ikon + yerelleştirilmiş metin).
class MinaWrappedInsight {
  const MinaWrappedInsight(this.icon, this.text);
  final IconData icon;
  final String text;
}

/// Persona + içgörüleri taşıyan UI raporu.
class MinaWrappedReport {
  const MinaWrappedReport({
    required this.persona,
    required this.title,
    required this.tagline,
    required this.insights,
    required this.highlightValue,
    required this.highlightLabel,
    required this.hasData,
  });

  final MinaWrappedPersona persona;

  /// Persona başlığı — örn. "Sinema Aşığı".
  final String title;

  /// Persona altında çıkan tek satırlık anlatı.
  final String tagline;

  /// 1-4 arası çarpıcı içgörü.
  final List<MinaWrappedInsight> insights;

  /// Öne çıkan dev sayı — örn. "12s 30dk".
  final String highlightValue;

  /// Öne çıkan sayının etiketi — örn. "Bu ay".
  final String highlightLabel;

  /// Persona gerçek veriden mi üretildi (newcomer = false).
  final bool hasData;
}

/// Persona görseli — emoji + degrade + vurgu ikonu.
class MinaWrappedPersonaVisual {
  const MinaWrappedPersonaVisual({
    required this.emoji,
    required this.gradient,
    required this.glow,
    required this.icon,
  });

  final String emoji;
  final List<Color> gradient;
  final Color glow;
  final IconData icon;
}

/// İçgörü motoru — saf hesap; yan etkisiz.
class MinaWrappedEngine {
  const MinaWrappedEngine._();

  /// Snapshot'tan tam rapor üretir. [formatHours] çağıranın saat formatçısı.
  static MinaWrappedReport build(
    MinaAnalyticsSnapshot snap, {
    required String Function(double minutes) formatHours,
  }) {
    final total = snap.totalMinutes;
    final rangeLabel = _rangeLabel(snap.range);

    if (total < 5) {
      return MinaWrappedReport(
        persona: MinaWrappedPersona.newcomer,
        title: 'analytics.persona.newcomer.title'.tr,
        tagline: 'analytics.persona.newcomer.tagline'.tr,
        insights: const [],
        highlightValue: formatHours(total),
        highlightLabel: 'analytics.wrapped.highlight'.trParams({
          'range': rangeLabel,
        }),
        hasData: false,
      );
    }

    final liveShare = snap.liveMinutes / total;
    final movieShare = snap.movieMinutes / total;
    final seriesShare = snap.seriesMinutes / total;

    // Saat dilimi payları (hourTotals üzerinden).
    final bands = _bandTotals(snap.hourTotals);
    final bandSum = bands.values.fold<double>(0, (a, b) => a + b);
    final dominantBand = _argMaxBand(bands);
    final dominantBandShare =
        bandSum <= 0 ? 0.0 : (bands[dominantBand]! / bandSum);

    final persona = _selectPersona(
      liveShare: liveShare,
      movieShare: movieShare,
      seriesShare: seriesShare,
      dominantBand: dominantBand,
      dominantBandShare: dominantBandShare,
    );

    final periodWord = _bandWord(dominantBand);
    final tagline = 'analytics.persona.${_personaKey(persona)}.tagline'
        .trParams({
      'hours': formatHours(total),
      'period': periodWord,
      'range': rangeLabel,
    });

    final insights = _buildInsights(
      snap: snap,
      total: total,
      dominantBand: dominantBand,
      dominantBandShare: dominantBandShare,
      formatHours: formatHours,
      rangeLabel: rangeLabel,
    );

    return MinaWrappedReport(
      persona: persona,
      title: 'analytics.persona.${_personaKey(persona)}.title'.tr,
      tagline: tagline,
      insights: insights,
      highlightValue: formatHours(total),
      highlightLabel: 'analytics.wrapped.highlight'.trParams({
        'range': rangeLabel,
      }),
      hasData: true,
    );
  }

  static MinaWrappedPersonaVisual visualOf(MinaWrappedPersona p) {
    switch (p) {
      case MinaWrappedPersona.cinephile:
        return const MinaWrappedPersonaVisual(
          emoji: '🎬',
          gradient: [Color(0xFF6D28D9), Color(0xFF2563EB)],
          glow: Color(0xFF7C3AED),
          icon: Icons.movie_filter_rounded,
        );
      case MinaWrappedPersona.binger:
        return const MinaWrappedPersonaVisual(
          emoji: '🍿',
          gradient: [Color(0xFFEA580C), Color(0xFFDB2777)],
          glow: Color(0xFFF97316),
          icon: Icons.theaters_rounded,
        );
      case MinaWrappedPersona.liveWire:
        return const MinaWrappedPersonaVisual(
          emoji: '📡',
          gradient: [Color(0xFFDC2626), Color(0xFFEA580C)],
          glow: Color(0xFFEF4444),
          icon: Icons.sensors_rounded,
        );
      case MinaWrappedPersona.nightOwl:
        return const MinaWrappedPersonaVisual(
          emoji: '🦉',
          gradient: [Color(0xFF312E81), Color(0xFF6D28D9)],
          glow: Color(0xFF4F46E5),
          icon: Icons.nightlight_round,
        );
      case MinaWrappedPersona.explorer:
        return const MinaWrappedPersonaVisual(
          emoji: '🧭',
          gradient: [Color(0xFF0D9488), Color(0xFF2563EB)],
          glow: Color(0xFF14B8A6),
          icon: Icons.explore_rounded,
        );
      case MinaWrappedPersona.newcomer:
        return const MinaWrappedPersonaVisual(
          emoji: '✨',
          gradient: [Color(0xFF334155), Color(0xFF475569)],
          glow: Color(0xFF64748B),
          icon: Icons.auto_awesome_rounded,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // İç hesaplar.
  // ---------------------------------------------------------------------------

  static MinaWrappedPersona _selectPersona({
    required double liveShare,
    required double movieShare,
    required double seriesShare,
    required _Band dominantBand,
    required double dominantBandShare,
  }) {
    // Gece kuşu: izlemenin yarısından fazlası gece (22-05).
    if (dominantBand == _Band.night && dominantBandShare >= 0.5) {
      return MinaWrappedPersona.nightOwl;
    }
    final maxKind = [liveShare, movieShare, seriesShare]
        .reduce((a, b) => a > b ? a : b);
    // Belirgin baskınlık yoksa keşifçi.
    if (maxKind < 0.45) return MinaWrappedPersona.explorer;
    if (maxKind == liveShare) return MinaWrappedPersona.liveWire;
    if (maxKind == movieShare) return MinaWrappedPersona.cinephile;
    return MinaWrappedPersona.binger;
  }

  static List<MinaWrappedInsight> _buildInsights({
    required MinaAnalyticsSnapshot snap,
    required double total,
    required _Band dominantBand,
    required double dominantBandShare,
    required String Function(double) formatHours,
    required String rangeLabel,
  }) {
    final out = <MinaWrappedInsight>[];

    // 1. Saat dilimi payı.
    if (dominantBandShare >= 0.30) {
      out.add(MinaWrappedInsight(
        _bandIcon(dominantBand),
        'analytics.insight.period'.trParams({
          'pct': (dominantBandShare * 100).round().toString(),
          'period': _bandWord(dominantBand),
        }),
      ));
    }

    // 2. En sadık kanal.
    if (snap.topChannels.isNotEmpty) {
      final ch = snap.topChannels.first;
      if (ch.name.trim().isNotEmpty && ch.minutes >= 1) {
        out.add(MinaWrappedInsight(
          Icons.favorite_rounded,
          'analytics.insight.topChannel'.trParams({
            'channel': ch.name.trim(),
            'hours': formatHours(ch.minutes),
          }),
        ));
      }
    }

    // 3. En aktif gün.
    final weekdaySum =
        snap.weekdayTotals.fold<double>(0, (a, b) => a + b);
    if (weekdaySum >= 1) {
      out.add(MinaWrappedInsight(
        Icons.event_available_rounded,
        'analytics.insight.peakDay'.trParams({
          'day': _weekdayLabel(snap.peakWeekday),
        }),
      ));
    }

    // 4. Favori tür.
    if (snap.topCategories.isNotEmpty &&
        snap.topCategories.first.name.trim().isNotEmpty) {
      out.add(MinaWrappedInsight(
        Icons.local_fire_department_rounded,
        'analytics.insight.topCategory'.trParams({
          'category': snap.topCategories.first.name.trim(),
        }),
      ));
    }

    // En fazla 4 içgörü.
    return out.take(4).toList(growable: false);
  }

  static Map<_Band, double> _bandTotals(List<double> hourTotals) {
    final m = {
      _Band.morning: 0.0,
      _Band.afternoon: 0.0,
      _Band.evening: 0.0,
      _Band.night: 0.0,
    };
    if (hourTotals.length != 24) return m;
    for (var h = 0; h < 24; h++) {
      final v = hourTotals[h];
      if (h >= 5 && h < 12) {
        m[_Band.morning] = m[_Band.morning]! + v;
      } else if (h >= 12 && h < 17) {
        m[_Band.afternoon] = m[_Band.afternoon]! + v;
      } else if (h >= 17 && h < 22) {
        m[_Band.evening] = m[_Band.evening]! + v;
      } else {
        m[_Band.night] = m[_Band.night]! + v;
      }
    }
    return m;
  }

  static _Band _argMaxBand(Map<_Band, double> bands) {
    var best = _Band.evening;
    var bestV = -1.0;
    bands.forEach((k, v) {
      if (v > bestV) {
        bestV = v;
        best = k;
      }
    });
    return best;
  }

  static String _bandWord(_Band b) => switch (b) {
        _Band.morning => 'analytics.period.morning'.tr,
        _Band.afternoon => 'analytics.period.afternoon'.tr,
        _Band.evening => 'analytics.period.evening'.tr,
        _Band.night => 'analytics.period.night'.tr,
      };

  static IconData _bandIcon(_Band b) => switch (b) {
        _Band.morning => Icons.wb_twilight_rounded,
        _Band.afternoon => Icons.wb_sunny_rounded,
        _Band.evening => Icons.nights_stay_rounded,
        _Band.night => Icons.bedtime_rounded,
      };

  static String _personaKey(MinaWrappedPersona p) => switch (p) {
        MinaWrappedPersona.newcomer => 'newcomer',
        MinaWrappedPersona.cinephile => 'cinephile',
        MinaWrappedPersona.binger => 'binger',
        MinaWrappedPersona.liveWire => 'liveWire',
        MinaWrappedPersona.nightOwl => 'nightOwl',
        MinaWrappedPersona.explorer => 'explorer',
      };

  static String _rangeLabel(MinaAnalyticsRange r) => switch (r) {
        MinaAnalyticsRange.week => 'analytics.range.week'.tr,
        MinaAnalyticsRange.month => 'analytics.range.month'.tr,
        MinaAnalyticsRange.year => 'analytics.range.year'.tr,
      };

  static String _weekdayLabel(int idx) {
    const keys = [
      'analytics.weekday.mon',
      'analytics.weekday.tue',
      'analytics.weekday.wed',
      'analytics.weekday.thu',
      'analytics.weekday.fri',
      'analytics.weekday.sat',
      'analytics.weekday.sun',
    ];
    if (idx < 0 || idx >= keys.length) return '';
    return keys[idx].tr;
  }
}

enum _Band { morning, afternoon, evening, night }
