/// Düz (flat) M3U girişinin içerik tipi.
enum M3uContentKind { live, movie, series }

/// M3U girişini **canlı kanal / film (VOD) / dizi bölümü** olarak sınıflandırır.
///
/// Pek çok "düz" liste Xtream yol biçimini (`/series/`, `/movie/`) kullanmaz ve
/// grup adında `dizi`/`film` anahtarı taşımaz. Bu durumda diziler ve filmler
/// yanlışlıkla **canlı kanal** olarak sınıflanır (kullanıcı "diziler/filmler
/// eksik" diye bildiriyor). Sınıflandırıcı grup/URL ipuçlarına ek olarak
/// **ad kalıplarını** dener:
///   * `S01E02`, `1x02`            → dizi bölümü
///   * `12. Bölüm`, `3. Sezon`     → dizi bölümü (TR)
///   * `Episode 4`, `Season 2`     → dizi bölümü (EN)
///   * grup yalnızca yıl (`2024`)  → film arşivi (VOD)
///
/// Heuristikler canlı kanallarda nadir görülen güçlü sinyallerle sınırlıdır;
/// yanlış pozitif riski (gerçek canlı kanalı dizi/film sanmak) düşük tutulur.
/// İki parser ([M3uParser] ve [M3uStreamParser]) aynı davransın diye ortak.
abstract final class M3uContentClassifier {
  /// `S01E02`, `S1 E2`, `S01 E2` — `s` öneki güçlü dizi sinyali.
  static final RegExp _seasonEpisode = RegExp(
    r's\d{1,3}\s?[ex]\s?\d{1,3}',
    caseSensitive: false,
  );

  /// `1x02` biçimi. Bölüm kısmı **2-4 hane** olmalı; böylece `4x4`, `24x7`
  /// gibi kanal adları yanlışlıkla dizi sayılmaz.
  static final RegExp _nxnnEpisode = RegExp(
    r'\b\d{1,2}\s?x\s?\d{2,4}\b',
    caseSensitive: false,
  );

  /// Ad içinde geçen güçlü bölüm/sezon kelimeleri (TR + EN).
  static final RegExp _episodeWords = RegExp(
    r'(\bbölüm\b|\bsezon\b|\bepisode\b|\bseason\b)',
    caseSensitive: false,
  );

  /// IMDb id kalıbı: `tt` + en az 6 rakam (ör. `/vs/tt8637498/`). Güçlü VOD
  /// sinyali.
  static final RegExp _imdbIdInUrl = RegExp(r'/tt\d{6,}');

  /// group-title yalnızca 4 haneli yıl ("2024") → genelde film (VOD) arşivi.
  static final RegExp _yearOnlyGroup = RegExp(r'^(19|20)\d{2}$');

  /// [name] / [url] / [group] **küçük harfe çevrilmiş** beklenir.
  static M3uContentKind classify({
    required String name,
    required String url,
    required String group,
  }) {
    // 1) Xtream yol biçimi en kesin sinyaldir ve **en yüksek önceliklidir**.
    // Böylece bir canlı kanalın adı yanlışlıkla bölüm kalıbına benzese bile
    // (`/live/.../1x02`) dizi/film sanılmaz.
    if (url.contains('/series/')) return M3uContentKind.series;
    if (url.contains('/movie/')) return M3uContentKind.movie;
    if (url.contains('/live/')) return M3uContentKind.live;

    // 2) Grup + ad ipuçları (düz listeler — yol biçimi yok).
    if (_isSeries(name, group)) return M3uContentKind.series;
    if (_isMovie(url, group)) return M3uContentKind.movie;
    return M3uContentKind.live;
  }

  static bool _isSeries(String name, String group) {
    if (group.contains('series') ||
        group.contains('tv show') ||
        group.contains('episode') ||
        group.contains('dizi') ||
        group.contains('sezon') ||
        group.contains('season')) {
      return true;
    }
    // Düz dizi listeleri: "Show - 12. Bölüm", "Show S01E02" gibi adlar.
    if (_episodeWords.hasMatch(name)) return true;
    if (_seasonEpisode.hasMatch(name)) return true;
    if (_nxnnEpisode.hasMatch(name)) return true;
    return false;
  }

  static bool _isMovie(String url, String group) {
    if (group.contains('movie') ||
        group.contains('vod') ||
        group.contains('film')) {
      return true;
    }
    // IMDb id taşıyan girişler Film (VOD). Diziler yukarıda ÖNCE yakalandığı
    // için gerçek diziler etkilenmez.
    if (_imdbIdInUrl.hasMatch(url)) return true;
    // group-title yalnızca yıl ("2024") → film arşivi düzeni.
    if (_yearOnlyGroup.hasMatch(group.trim())) return true;
    return false;
  }
}
