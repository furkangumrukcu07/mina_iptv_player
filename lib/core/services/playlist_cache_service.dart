import 'package:get/get.dart';

import '../../domain/entities/m3u_result.dart';

/// In-memory playlist snapshot shared across modules (replaces passing large args on routes).
class PlaylistCacheService extends GetxService {
  final Rxn<M3uResult> result = Rxn<M3uResult>();
  final Rxn<String> sourceUrl = Rxn<String>();
  final Rxn<DateTime> lastUpdated = Rxn<DateTime>();

  void setPlaylist({required M3uResult value, required String url}) {
    result.value = value;
    sourceUrl.value = url;
    lastUpdated.value = DateTime.now();
  }

  void clear() {
    result.value = null;
    sourceUrl.value = null;
    lastUpdated.value = null;
  }
}
