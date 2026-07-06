/// Ses kodeğine göre oynatıcı motoru ipucu.
///
/// ExoPlayer (Better Player) bazı TV box / Amlogic cihazlarda **AC-3 / E-AC-3 /
/// DTS / TrueHD** sesli VOD akışlarında ses saatini master alıp A/V senkronunu
/// kaybeder (görüntü "donarak" oynar, kasar). libmpv (MediaKit) bu kodekleri
/// kendi FFmpeg'i ile yazılımda çözüp esnek senkronla sorunsuz oynatır.
///
/// Bu yüzden Xtream `get_vod_info` / `get_series_info` ses kodeği bu aileden
/// ise, kullanıcı motoru **bilinçli seçmediği** sürece (varsayılan mod) VOD
/// proaktif olarak MediaKit ile açılır.
class AudioCodecPlaybackHint {
  const AudioCodecPlaybackHint._();

  /// ExoPlayer'da senkron sorunu çıkaran ses kodek aileleri (normalize).
  static const Set<String> _exoProblematicAudioCodecs = {
    'ac3',
    'ac-3',
    'eac3',
    'e-ac-3',
    'ec3',
    'ec-3',
    'dts',
    'dca',
    'dts-hd',
    'truehd',
    'mlp',
  };

  /// [codec] ExoPlayer'da sorunlu bir ses kodeğine işaret ediyorsa `true`.
  ///
  /// `null`/boş/bilinmeyen kodek → `false` (proaktif yönlendirme yapılmaz,
  /// reaktif fallback devrede kalır).
  static bool prefersMediaKit(String? codec) {
    final norm = _normalize(codec);
    if (norm.isEmpty) return false;
    return _exoProblematicAudioCodecs.contains(norm);
  }

  static String _normalize(String? raw) {
    if (raw == null) return '';
    var s = raw.trim().toLowerCase();
    if (s.isEmpty || s == 'null') return '';
    // "A_AC3", "ATSC A/52A (AC-3)" gibi etiketlerden çekirdek adı çıkar.
    if (s.startsWith('a_')) s = s.substring(2);
    if (s.contains('ac-3') || s.contains('ac3') || s.contains('a/52')) {
      return s.contains('e-ac') || s.contains('eac') ? 'eac3' : 'ac3';
    }
    if (s.contains('truehd') || s.contains('true hd') || s.contains('mlp')) {
      return 'truehd';
    }
    if (s.contains('dts')) return 'dts';
    return s;
  }
}
