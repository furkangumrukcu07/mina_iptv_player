import 'package:shared_preferences/shared_preferences.dart';

/// Profile **özel** (profil değişince takas edilen) SharedPreferences
/// anahtarları. Buradaki anahtarlar HARİÇ her şey — M3U/Xtream listeleri ve
/// kimlik bilgileri (secure storage), cihaz/oynatma motoru, EPG kaynağı,
/// kurulum durumu, bulut hesabı — tüm profiller arasında PAYLAŞILIR.
///
/// Not: Profil meta verisi anahtarları (`mina_profiles_v1`,
/// `mina_active_profile_v1`, `mina_profile_data_*`) bilinçli olarak BU sete
/// dahil DEĞİLDİR; aksi halde snapshot özyinelemesi olurdu.
abstract final class ProfilePrefKeys {
  /// Tam eşleşen profile-özel anahtarlar.
  static const Set<String> exact = <String>{
    // Görünüm / dil
    'mina_settings_language',
    'mina_settings_theme_label',
    'mina_settings_reduce_blur',
    'mina_settings_app_font_family',
    'mina_settings_home_card_scale_v1',
    'mina_settings_home_card_swipe_effect',
    'mina_settings_home_card_frame_style',
    'mina_settings_tv_osd_auto_hide_duration',
    'mina_settings_osd_landscape_bg_opacity',
    'mina_settings_landscape_status_bar',
    // Ana ekran düzeni & şeritleri
    'mina_settings_home_film_dizi_mode_v1',
    'mina_settings_home_category_card_order_v1',
    'mina_settings_home_category_card_hidden_v1',
    'mina_settings_upcoming_matches',
    'mina_settings_mixed_live_tv',
    'mina_settings_ai_recommendations',
    'mina_settings_daily_quote',
    'mina_settings_continue_watching',
    'mina_settings_mina_wrapped_enabled',
    'mina_settings_strip_live_ch_prefix',
    // Canlı kanal liste düzeni (sıralama + gizlenenler, kaynak bazında).
    // Her profil kendi kanal düzenini tutar.
    'mina_live_channel_layout_v1',
    // Gizlenen kategoriler (Xtream / M3U) — liste organizasyonu profile özel.
    'mina_xtream_hidden_categories_v1',
    'mina_m3u_hidden_categories_v1',
    // Altyazı
    'mina_settings_subtitle_font_pt',
    'mina_settings_subtitle_font_family',
    'mina_settings_subtitle_color_key',
    'mina_settings_subtitle_color_argb',
    'mina_settings_subtitle_outline',
    'mina_settings_vod_subtitle_auto_enabled',
    'mina_settings_vod_preferred_subtitle_token',
    // Son seçimler / devam konumu
    'mina_last_live_cat',
    'mina_last_live_ch',
    'mina_last_films_cat',
    'mina_last_films_vod',
    'mina_last_series_cat',
    'mina_last_series_id',
    'mina_last_fav_cat',
    'mina_last_fav_sel',
    // İzlemeye devam et indeksi
    'mina_continue_watching_v2',
  };

  /// Prefix ile eşleşen (dinamik son ekli) profile-özel anahtarlar.
  static const List<String> prefixes = <String>[
    'mina_fav_', // mina_fav_channels / _vods / _series
    'mina_watch_pos_', // izleme konumu (stream başına)
    'mina_watch_dur_', // izleme süresi (stream başına)
  ];

  static bool isProfileScoped(String key) {
    if (exact.contains(key)) return true;
    for (final p in prefixes) {
      if (key.startsWith(p)) return true;
    }
    return false;
  }
}

/// Mevcut SharedPreferences içindeki tüm profile-özel anahtarları, restore
/// sırasında doğru tipe yazabilmek için tip bilgisiyle birlikte toplar.
/// Çıktı: `{ key: {'t': <tip>, 'v': <değer>} }` ([BackupService] ile aynı format).
Map<String, Map<String, Object?>> snapshotProfilePrefs(SharedPreferences p) {
  final out = <String, Map<String, Object?>>{};
  for (final k in p.getKeys()) {
    if (!ProfilePrefKeys.isProfileScoped(k)) continue;
    final v = p.get(k);
    if (v == null) continue;
    if (v is bool) {
      out[k] = {'t': 'bool', 'v': v};
    } else if (v is int) {
      out[k] = {'t': 'int', 'v': v};
    } else if (v is double) {
      out[k] = {'t': 'double', 'v': v};
    } else if (v is String) {
      out[k] = {'t': 'string', 'v': v};
    } else if (v is List<String>) {
      out[k] = {'t': 'stringList', 'v': v};
    }
  }
  return out;
}

/// Önce mevcut tüm profile-özel anahtarları siler, ardından verilen snapshot'ı
/// (typed JSON map) SharedPreferences'a yazar. Snapshot'ta olmayan anahtarlar
/// silinmiş kalır (yani hedef profilin varsayılanı geçerli olur).
Future<void> applyProfilePrefs(
  SharedPreferences p,
  Map<String, dynamic> snapshot,
) async {
  final old = p
      .getKeys()
      .where(ProfilePrefKeys.isProfileScoped)
      .toList(growable: false);
  for (final k in old) {
    await p.remove(k);
  }
  for (final entry in snapshot.entries) {
    final key = entry.key.toString();
    if (!ProfilePrefKeys.isProfileScoped(key)) continue;
    final v = entry.value;
    if (v is! Map) continue;
    final type = v['t']?.toString();
    final value = v['v'];
    try {
      switch (type) {
        case 'bool':
          if (value is bool) await p.setBool(key, value);
          break;
        case 'int':
          if (value is int) {
            await p.setInt(key, value);
          } else if (value is num) {
            await p.setInt(key, value.toInt());
          }
          break;
        case 'double':
          if (value is num) await p.setDouble(key, value.toDouble());
          break;
        case 'string':
          if (value is String) await p.setString(key, value);
          break;
        case 'stringList':
          if (value is List) {
            await p.setStringList(
              key,
              value.map((e) => e.toString()).toList(),
            );
          }
          break;
      }
    } catch (_) {}
  }
}
