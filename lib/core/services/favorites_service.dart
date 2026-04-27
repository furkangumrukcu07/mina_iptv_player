import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kalıcı favoriler (SharedPreferences ile).
class FavoritesService extends GetxService {
  static const _kCh = 'mina_fav_channels';
  static const _kVod = 'mina_fav_vods';
  static const _kSer = 'mina_fav_series';

  final RxList<int> channelIds = <int>[].obs;
  final RxList<int> vodIds = <int>[].obs;
  final RxList<int> seriesIds = <int>[].obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ch = p.getStringList(_kCh);
      final vod = p.getStringList(_kVod);
      final ser = p.getStringList(_kSer);

      if (ch != null) channelIds.assignAll(ch.map(int.parse));
      if (vod != null) vodIds.assignAll(vod.map(int.parse));
      if (ser != null) seriesIds.assignAll(ser.map(int.parse));
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kCh, channelIds.map((e) => e.toString()).toList());
      await p.setStringList(_kVod, vodIds.map((e) => e.toString()).toList());
      await p.setStringList(_kSer, seriesIds.map((e) => e.toString()).toList());
    } catch (_) {}
  }

  bool hasChannel(int id) => channelIds.contains(id);
  bool hasVod(int id) => vodIds.contains(id);
  bool hasSeries(int id) => seriesIds.contains(id);

  void toggleChannel(int id) {
    if (channelIds.contains(id)) {
      channelIds.remove(id);
    } else {
      channelIds.add(id);
    }
    _save();
  }

  void toggleVod(int id) {
    if (vodIds.contains(id)) {
      vodIds.remove(id);
    } else {
      vodIds.add(id);
    }
    _save();
  }

  void toggleSeries(int id) {
    if (seriesIds.contains(id)) {
      seriesIds.remove(id);
    } else {
      seriesIds.add(id);
    }
    _save();
  }

  /// Gruplu dizi satırı: tamamı favoride değilse hepsini ekle, hepsi favorideyse kaldır.
  void toggleSeriesGroup(Iterable<int> ids) {
    final list = ids.toSet().toList();
    if (list.isEmpty) return;
    final allIn = list.every(seriesIds.contains);
    if (allIn) {
      for (final id in list) {
        seriesIds.remove(id);
      }
    } else {
      for (final id in list) {
        if (!seriesIds.contains(id)) {
          seriesIds.add(id);
        }
      }
    }
    _save();
  }

  bool hasAnySeries(Iterable<int> ids) => ids.any(seriesIds.contains);

  int get totalCount =>
      channelIds.length + vodIds.length + seriesIds.length;

  void clearAll() {
    channelIds.clear();
    vodIds.clear();
    seriesIds.clear();
    _save();
  }
}
