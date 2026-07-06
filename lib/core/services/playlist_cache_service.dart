import 'dart:async';

import 'package:get/get.dart';

import '../../domain/entities/m3u_result.dart';
import 'app_settings_service.dart';
import 'iptv_logo_cache_service.dart';
import 'playlist_live_channel_layout.dart';
import 'playlist_channel_layout_sync.dart';
import 'playlist_data_source.dart';

/// In-memory playlist snapshot shared across modules (replaces passing large args on routes).
class PlaylistCacheService extends GetxService {
  final Rxn<M3uResult> result = Rxn<M3uResult>();
  final Rxn<String> sourceUrl = Rxn<String>();

  /// Ham birleştirilmiş liste (kullanıcı düzeni uygulanmamış).
  M3uResult? rawPlaylist;

  /// [AppSettingsService.m3uPreferenceKey]; birincil kaynak M3U / yerel ise dolu.
  final RxnString m3uLayoutKey = RxnString();
  final Rxn<DateTime> lastUpdated = Rxn<DateTime>();

  /// Yalnızca canlı kanal düzeni (gizle/sıra) değişince artar — EPG veya tam
  /// playlist yenilemesinden bağımsız dar dinleme için.
  final layoutRevision = 0.obs;

  /// [AppSettingsService.xtreamPreferenceKey] — yalnızca birincil kaynak Xtream ise dolu.
  final RxnString xtreamPreferenceKey = RxnString();

  /// Aktif slot'un [PlaylistSqliteStore] `source_key` parmak izi. Tüketiciler
  /// büyük kanal/film/dizi listelerini RAM yerine bu anahtarla diskten
  /// (sayfalı) sorgular. DB henüz dolmadıysa veya kaynak yoksa null.
  final RxnString dbSourceKey = RxnString();

  int? _layoutCacheKey;
  M3uResult? _layoutCachedResult;

  void setPlaylist({
    required M3uResult value,
    required String url,
    String? xtreamPreferenceKey,
    String? m3uLayoutKey,
    String? dbSourceKey,
  }) {
    rawPlaylist = value;
    _layoutCacheKey = null;
    _layoutCachedResult = null;
    result.value = _withLayoutApplied(value, xtreamPreferenceKey, m3uLayoutKey);
    sourceUrl.value = url;
    lastUpdated.value = DateTime.now();
    this.xtreamPreferenceKey.value = xtreamPreferenceKey;
    this.m3uLayoutKey.value = m3uLayoutKey;
    this.dbSourceKey.value = dbSourceKey;
    layoutRevision.value++;
    if (Get.isRegistered<IptvLogoCacheService>()) {
      final logos = result.value?.channels ?? value.channels;
      if (logos.isNotEmpty) {
        unawaited(
          Get.find<IptvLogoCacheService>().prefetchChannelLogos(logos),
        );
      } else if (this.dbSourceKey.value != null &&
          Get.isRegistered<PlaylistDataSource>()) {
        unawaited(_prefetchLogosFromDb());
      }
    }
  }

  Future<void> _prefetchLogosFromDb() async {
    if (!Get.isRegistered<PlaylistDataSource>()) return;
    final ds = Get.find<PlaylistDataSource>();
    if (!ds.isDbBacked) return;
    try {
      final page = await ds.channelsForScan(limit: 500);
      if (page.isEmpty) return;
      if (Get.isRegistered<IptvLogoCacheService>()) {
        await Get.find<IptvLogoCacheService>().prefetchChannelLogos(page);
      }
    } catch (_) {}
  }

  int _layoutKeyFor(
    M3uResult raw,
    String? xtreamKey,
    String? m3uKey,
  ) {
    if (!Get.isRegistered<AppSettingsService>()) {
      return Object.hash(raw.channels.length, xtreamKey, m3uKey);
    }
    final app = Get.find<AppSettingsService>();
    final xk = xtreamKey?.trim() ?? '';
    final mk = m3uKey?.trim() ?? '';
    final pref = xk.isNotEmpty ? xk : mk;
    if (pref.isEmpty) {
      return Object.hash(raw.channels.length, raw.hashCode);
    }
    final hidden = app.liveChannelHiddenIds(pref);
    final order = app.liveChannelOrderByCategory(pref);
    return Object.hash(
      raw.hashCode,
      pref,
      hidden.length,
      hidden.hashCode,
      order.length,
      Object.hashAll(order.entries.map((e) => Object.hash(e.key, e.value.length))),
      app.playlistLayoutRevision.value,
    );
  }

  M3uResult _withLayoutApplied(
    M3uResult raw,
    String? xtreamKey,
    String? m3uKey,
  ) {
    final key = _layoutKeyFor(raw, xtreamKey, m3uKey);
    if (_layoutCacheKey == key && _layoutCachedResult != null) {
      return _layoutCachedResult!;
    }
    if (!Get.isRegistered<AppSettingsService>()) {
      _layoutCacheKey = key;
      _layoutCachedResult = raw;
      return raw;
    }
    final app = Get.find<AppSettingsService>();
    final xk = xtreamKey?.trim();
    if (xk != null && xk.isNotEmpty) {
      final applied = PlaylistLiveChannelLayout.apply(app, raw, xk);
      _layoutCacheKey = key;
      _layoutCachedResult = applied;
      return applied;
    }
    final mk = m3uKey?.trim();
    if (mk != null && mk.isNotEmpty) {
      final applied = PlaylistLiveChannelLayout.apply(app, raw, mk);
      _layoutCacheKey = key;
      _layoutCachedResult = applied;
      return applied;
    }
    _layoutCacheKey = key;
    _layoutCachedResult = raw;
    return raw;
  }

  /// Kayıtlı canlı kanal düzenini tekrar uygular (düzenleme ekranından sonra).
  void reapplyLiveChannelLayout() {
    final raw = rawPlaylist;
    if (raw == null) return;
    final xk = xtreamPreferenceKey.value?.trim();
    final mk = m3uLayoutKey.value?.trim();
    _layoutCacheKey = null;
    _layoutCachedResult = null;

    final dbKey = dbSourceKey.value?.trim();
    if (dbKey != null && dbKey.isNotEmpty) {
      unawaited(
        PlaylistChannelLayoutSync.syncActiveSlot().whenComplete(() {
          layoutRevision.value++;
        }),
      );
    }

    // Bellek yedek / kanallar hâlâ RAM'deyse düzeni orada da uygula (DB yedekte kanallar RAM'de tutulmaz).
    if (raw.channels.isNotEmpty && (dbKey == null || dbKey.isEmpty)) {
      final next = _withLayoutApplied(raw, xk, mk);
      if (!identical(result.value, next)) {
        result.value = next;
      }
    }
    if (dbKey == null || dbKey.isEmpty) {
      layoutRevision.value++;
    }
  }

  @Deprecated('Use reapplyLiveChannelLayout')
  void reapplyCategoryLayout() => reapplyLiveChannelLayout();

  void clear() {
    rawPlaylist = null;
    result.value = null;
    sourceUrl.value = null;
    lastUpdated.value = null;
    xtreamPreferenceKey.value = null;
    m3uLayoutKey.value = null;
    dbSourceKey.value = null;
    _layoutCacheKey = null;
    _layoutCachedResult = null;
    layoutRevision.value++;
  }
}
