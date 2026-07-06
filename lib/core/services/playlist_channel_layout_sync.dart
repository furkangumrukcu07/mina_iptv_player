import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/local/playlist_sqlite_store.dart';
import '../../domain/entities/channel.dart';
import 'app_settings_service.dart';
import 'playlist_cache_service.dart';

/// Kullanıcı canlı kanal düzenini SharedPreferences'tan SQLite'a yansıtır.
abstract final class PlaylistChannelLayoutSync {
  PlaylistChannelLayoutSync._();

  /// Aktif slot için kayıtlı düzeni DB'ye uygular.
  static Future<void> syncActiveSlot() async {
    if (!Get.isRegistered<PlaylistCacheService>()) return;
    final cache = Get.find<PlaylistCacheService>();
    final dbKey = cache.dbSourceKey.value?.trim();
    if (dbKey == null || dbKey.isEmpty) return;

    final prefKey = _layoutPrefKey(cache);
    if (prefKey == null) return;

    if (!Get.isRegistered<AppSettingsService>()) return;
    final app = Get.find<AppSettingsService>();

    var categories = cache.rawPlaylist?.channelCategories ??
        cache.result.value?.channelCategories ??
        const <ChannelCategory>[];
    if (categories.isEmpty) {
      categories = await PlaylistSqliteStore.channelCategories(dbKey);
    }

    await syncToDb(
      dbKey: dbKey,
      prefKey: prefKey,
      categories: categories,
      hiddenIds: app.liveChannelHiddenIds(prefKey),
      orderByCategoryId: app.liveChannelOrderByCategory(prefKey),
    );
  }

  static String? _layoutPrefKey(PlaylistCacheService cache) {
    final xk = cache.xtreamPreferenceKey.value?.trim();
    if (xk != null && xk.isNotEmpty) return xk;
    final mk = cache.m3uLayoutKey.value?.trim();
    if (mk != null && mk.isNotEmpty) return mk;
    return null;
  }

  static Future<void> syncToDb({
    required String dbKey,
    required String prefKey,
    required List<ChannelCategory> categories,
    required Set<int> hiddenIds,
    required Map<int, List<int>> orderByCategoryId,
  }) async {
    if (dbKey.isEmpty || prefKey.isEmpty) return;
    try {
      await PlaylistSqliteStore.applyChannelLayout(
        dbKey,
        categories: categories,
        hiddenIds: hiddenIds,
        orderByCategoryId: orderByCategoryId,
      );
    } catch (e, st) {
      debugPrint('mina_iptv: channel layout SQLite sync failed: $e\n$st');
    }
  }
}
