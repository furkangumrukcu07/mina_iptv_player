import 'dart:async';

import 'package:get/get.dart';

import '../../domain/entities/m3u_result.dart';
import 'iptv_logo_cache_service.dart';

/// In-memory playlist snapshot shared across modules (replaces passing large args on routes).
class PlaylistCacheService extends GetxService {
  final Rxn<M3uResult> result = Rxn<M3uResult>();
  final Rxn<String> sourceUrl = Rxn<String>();
  final Rxn<DateTime> lastUpdated = Rxn<DateTime>();

  /// [AppSettingsService.xtreamPreferenceKey] — yalnızca birincil kaynak Xtream ise dolu.
  final RxnString xtreamPreferenceKey = RxnString();

  void setPlaylist({
    required M3uResult value,
    required String url,
    String? xtreamPreferenceKey,
  }) {
    result.value = value;
    sourceUrl.value = url;
    lastUpdated.value = DateTime.now();
    this.xtreamPreferenceKey.value = xtreamPreferenceKey;
    if (Get.isRegistered<IptvLogoCacheService>()) {
      unawaited(
        Get.find<IptvLogoCacheService>().prefetchChannelLogos(value.channels),
      );
    }
  }

  void clear() {
    result.value = null;
    sourceUrl.value = null;
    lastUpdated.value = null;
    xtreamPreferenceKey.value = null;
  }
}
