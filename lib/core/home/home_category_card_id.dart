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
  minaAnalytics,
  chat;

  /// Mobil/tablet ana ekranı varsayılan kart sırası: Canlı TV · Film & Dizi ·
  /// Filmler · Diziler · Mina Analytics · EPG Mix. Görünürlük ayrıca Film & Dizi
  /// moduna ([visibleForFilmDiziMode]) ve kullanıcının gizledikleri kartlara
  /// bağlıdır; bu yalnızca sıradır.
  static const List<HomeCategoryCardId> defaultOrder = [
    live,
    recommendedFilms,
    films,
    series,
    minaAnalytics,
    epgMix,
  ];

  /// TV ana ekranı varsayılan kart sırası: Canlı TV · Filmler · Diziler ·
  /// EPG Mix · Mina Analytics. `recommendedFilms` (Film & Dizi) TV'de HİÇ
  /// gösterilmez ([visibleForLayout]), bu yüzden TV sırasında yer almaz.
  static const List<HomeCategoryCardId> tvDefaultOrder = [
    live,
    films,
    series,
    epgMix,
    minaAnalytics,
  ];

  String get storageKey => switch (this) {
        live => 'live',
        films => 'films',
        series => 'series',
        recommendedFilms => 'recommended_films',
        epgMix => 'epg_mix',
        minaAnalytics => 'mina_analytics',
        chat => 'chat',
      };

  String get labelKey => switch (this) {
        live => 'home.live',
        films => 'home.films',
        series => 'home.series',
        recommendedFilms => 'home.recommendedFilms',
        epgMix => 'home.epgMix',
        minaAnalytics => 'home.minaAnalytics',
        chat => 'home.chat',
      };

  String? get subtitleKey => switch (this) {
        live => 'home.live.subtitle',
        films => 'home.films.subtitle',
        series => 'home.series.subtitle',
        recommendedFilms => 'home.recommendedFilms.subtitle',
        epgMix => 'home.epgMix.subtitle',
        minaAnalytics => 'home.minaAnalytics.subtitle',
        chat => 'home.chat.subtitle',
      };

  IconData get icon => switch (this) {
        live => Icons.live_tv_rounded,
        films => Icons.movie_filter_rounded,
        series => Icons.theater_comedy_rounded,
        recommendedFilms => Icons.local_movies_rounded,
        epgMix => Icons.view_timeline_rounded,
        minaAnalytics => Icons.insights_rounded,
        chat => Icons.forum_rounded,
      };

  String get editorLabelKey => switch (this) {
        live => 'homeCardOrder.card.live',
        films => 'homeCardOrder.card.films',
        series => 'homeCardOrder.card.series',
        recommendedFilms => 'homeCardOrder.card.recommendedFilms',
        epgMix => 'homeCardOrder.card.epgMix',
        minaAnalytics => 'homeCardOrder.card.minaAnalytics',
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
  ///
  /// [chat] artık ana ekranda kart olarak gösterilmediği için (sohbete başlık
  /// ikonundan ulaşılır) eski kayıtlarda kalmış olsa bile sıradan düşürülür;
  /// aksi halde düzen editöründe "hayalet" bir satır olarak kalabilir.
  static List<HomeCategoryCardId> normalizeOrder(Iterable<String>? rawKeys) {
    final out = <HomeCategoryCardId>[];
    if (rawKeys != null) {
      for (final key in rawKeys) {
        final id = tryParseStorageKey(key);
        if (id != null && id != HomeCategoryCardId.chat && !out.contains(id)) {
          out.add(id);
        }
      }
    }
    for (final id in defaultOrder) {
      if (!out.contains(id)) out.add(id);
    }
    return out;
  }

  /// Kartın bu cihaz tipinde görünüp görünmeyeceği.
  ///
  /// * [chat]: artık ana ekranda **kart olarak gösterilmez** (hiçbir cihaz
  ///   tipinde). Kullanıcı sohbete ana ekran başlığındaki sohbet ikonundan
  ///   ulaşır. Enum değeri route/aktivasyon için korunur.
  /// * [recommendedFilms] (Film & Dizi): **TV'de hiç gösterilmez**; TV'de
  ///   ayrı Filmler / Diziler kartları kullanılır.
  /// * Diğer kartlar tüm cihaz tiplerinde görünür.
  bool visibleForLayout(AppLayoutMode mode) {
    if (this == HomeCategoryCardId.chat) {
      return false;
    }
    if (mode == AppLayoutMode.tv) {
      // TV modunda sadece ayrı Filmler ve Diziler kartları gösterilir, Film & Dizi (recommendedFilms) gizlidir.
      if (this == HomeCategoryCardId.recommendedFilms) {
        return false;
      }
      return true;
    } else {
      // Mobil/Tablet modunda sadece Film & Dizi (recommendedFilms) kartı gösterilir, ayrı Filmler ve Diziler gizlidir.
      if (this == HomeCategoryCardId.films || this == HomeCategoryCardId.series) {
        return false;
      }
      return true;
    }
  }

  /// Kullanıcının seçtiği Film & Dizi moduna göre kartın görünüp
  /// görünmeyeceğini söyler. Bu seçim kaldırıldığı için artık her zaman görünür kabul edilir.
  bool visibleForFilmDiziMode(HomeFilmDiziMode mode) {
    return true;
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
