import 'package:flutter/material.dart';

import '../layout/app_layout_mode.dart';

/// Ana ekrandaki Film & Dizi seçeneklerinin görünüm modu — kurulum
/// sihirbazından veya Ayarlar > Ana Ekran > Film & Dizi modu ekranından
/// değiştirilebilir.
///
/// * [modern]: tek bir «Film & Dizi» (recommendedFilms) kartı görünür;
///   ayrı «Filmler» ve «Diziler» kartları gizlenir. Modern Netflix-tarzı.
/// * [classic]: ayrı «Filmler» ve «Diziler» kartları görünür;
///   «Film & Dizi» kartı gizlenir. Klasik IPTV oynatıcı tarzı.
/// * [both]: hepsi birden görünür (varsayılan, geriye dönük uyumluluk).
enum HomeFilmDiziMode {
  modern,
  classic,
  both;

  String get storageKey => switch (this) {
        modern => 'modern',
        classic => 'classic',
        both => 'both',
      };

  String get labelKey => switch (this) {
        modern => 'homeSettings.filmDiziMode.modern.title',
        classic => 'homeSettings.filmDiziMode.classic.title',
        both => 'homeSettings.filmDiziMode.both.title',
      };

  String get subtitleKey => switch (this) {
        modern => 'homeSettings.filmDiziMode.modern.sub',
        classic => 'homeSettings.filmDiziMode.classic.sub',
        both => 'homeSettings.filmDiziMode.both.sub',
      };

  static HomeFilmDiziMode fromStorageKey(String? raw) {
    for (final m in values) {
      if (m.storageKey == raw) return m;
    }
    return HomeFilmDiziMode.both;
  }
}

/// Ana ekrandaki büyük kategori kartları (sıralanabilir).
enum HomeCategoryCardId {
  live,
  films,
  series,
  recommendedFilms,
  epgMix,
  chat;

  static const List<HomeCategoryCardId> defaultOrder = [
    live,
    films,
    series,
    recommendedFilms,
    epgMix,
    chat,
  ];

  /// TV ana ekranı varsayılan kart sırası: Canlı TV · Filmler · Diziler ·
  /// EPG Mix. `recommendedFilms` (Film & Dizi) sona alınır ve TV'de
  /// `classic` film/dizi modu ile gizli kalır.
  static const List<HomeCategoryCardId> tvDefaultOrder = [
    live,
    films,
    series,
    epgMix,
    recommendedFilms,
  ];

  String get storageKey => switch (this) {
        live => 'live',
        films => 'films',
        series => 'series',
        recommendedFilms => 'recommended_films',
        epgMix => 'epg_mix',
        chat => 'chat',
      };

  String get labelKey => switch (this) {
        live => 'home.live',
        films => 'home.films',
        series => 'home.series',
        recommendedFilms => 'home.recommendedFilms',
        epgMix => 'home.epgMix',
        chat => 'home.chat',
      };

  String? get subtitleKey => switch (this) {
        live => 'home.live.subtitle',
        films => 'home.films.subtitle',
        series => 'home.series.subtitle',
        recommendedFilms => 'home.recommendedFilms.subtitle',
        epgMix => 'home.epgMix.subtitle',
        chat => 'home.chat.subtitle',
      };

  IconData get icon => switch (this) {
        live => Icons.live_tv_rounded,
        films => Icons.movie_filter_rounded,
        series => Icons.theater_comedy_rounded,
        recommendedFilms => Icons.local_movies_rounded,
        epgMix => Icons.view_timeline_rounded,
        chat => Icons.forum_rounded,
      };

  String get editorLabelKey => switch (this) {
        live => 'homeCardOrder.card.live',
        films => 'homeCardOrder.card.films',
        series => 'homeCardOrder.card.series',
        recommendedFilms => 'homeCardOrder.card.recommendedFilms',
        epgMix => 'homeCardOrder.card.epgMix',
        chat => 'homeCardOrder.card.chat',
      };

  static HomeCategoryCardId? tryParseStorageKey(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final id in values) {
      if (id.storageKey == raw) return id;
    }
    return null;
  }

  /// Eksik / bilinmeyen anahtarları tamamlar; yinelenenleri atar.
  static List<HomeCategoryCardId> normalizeOrder(Iterable<String>? rawKeys) {
    final out = <HomeCategoryCardId>[];
    if (rawKeys != null) {
      for (final key in rawKeys) {
        final id = tryParseStorageKey(key);
        if (id != null && !out.contains(id)) out.add(id);
      }
    }
    for (final id in defaultOrder) {
      if (!out.contains(id)) out.add(id);
    }
    return out;
  }

  /// Kartın bu cihaz tipinde görünüp görünmeyeceği.
  ///
  /// * [chat]: yalnızca mobil ve tablette görünür; Android TV / Google TV
  ///   düzeninde tamamen gizlenir (kart hiç gösterilmez, route'a erişilmez).
  /// * Diğer kartlar tüm cihaz tiplerinde görünür.
  bool visibleForLayout(AppLayoutMode mode) {
    if (this == HomeCategoryCardId.chat) {
      return mode != AppLayoutMode.tv;
    }
    return true;
  }

  /// Kullanıcının seçtiği Film & Dizi moduna göre kartın görünüp
  /// görünmeyeceğini söyler. Live / Favorites / EpgMix gibi kartlar bu
  /// filtreden **etkilenmez** (her zaman görünür kalır).
  bool visibleForFilmDiziMode(HomeFilmDiziMode mode) {
    switch (this) {
      case HomeCategoryCardId.recommendedFilms:
        return mode == HomeFilmDiziMode.modern ||
            mode == HomeFilmDiziMode.both;
      case HomeCategoryCardId.films:
      case HomeCategoryCardId.series:
        return mode == HomeFilmDiziMode.classic ||
            mode == HomeFilmDiziMode.both;
      default:
        return true;
    }
  }

  /// Verilen [order] listesinden mevcut [mode] (mobil/tablet/TV), [filmDiziMode]
  /// (modern/classic/both) ve kullanıcının manuel olarak gizlediği kartları
  /// ([hidden]) filtreleyerek son listeyi döner. [hidden] varsayılan olarak
  /// boştur — düzen editörü gizli kartları "soluk" olarak göstermek için bu
  /// parametreyi geçmemelidir; ana ekran render'ı ise mutlaka geçmelidir.
  static List<HomeCategoryCardId> orderForLayout(
    Iterable<HomeCategoryCardId> order,
    AppLayoutMode mode, {
    HomeFilmDiziMode filmDiziMode = HomeFilmDiziMode.both,
    Set<HomeCategoryCardId> hidden = const <HomeCategoryCardId>{},
  }) =>
      order
          .where((id) =>
              id.visibleForLayout(mode) &&
              id.visibleForFilmDiziMode(filmDiziMode) &&
              !hidden.contains(id))
          .toList(growable: false);
}
