import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../domain/entities/epg_entities.dart';
import '../../data/remote/xmltv_parser.dart';

class EpgService extends GetxService {
  final _dio = Dio();

  final RxMap<String, EpgChannel> _channels = <String, EpgChannel>{}.obs;
  final RxMap<String, List<EpgProgramme>> _programmes =
      <String, List<EpgProgramme>>{}.obs;
  final RxBool isLoading = false.obs;

  /// Obx / liste yenilemesi için; EPG yüklendikçe artar.
  final RxInt loadGeneration = 0.obs;

  Future<void> loadEpg(String url) async {
    if (url.isEmpty) return;
    isLoading.value = true;
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      final xmlContent = response.data;
      if (xmlContent != null && xmlContent.isNotEmpty) {
        final result = await compute(parseXmlTvIsolate, xmlContent);
        _channels.assignAll(result['channels'] as Map<String, EpgChannel>);
        _programmes
            .assignAll(result['programmes'] as Map<String, List<EpgProgramme>>);
        loadGeneration.value++;
        debugPrint(
            'mina_iptv: EPG loaded. Channels: ${_channels.length}, Progs: ${_programmes.length}');
      }
    } catch (e) {
      debugPrint('mina_iptv: Error loading EPG: $e');
    } finally {
      isLoading.value = false;
    }
  }

  EpgProgramme? getCurrentProgramme(String? epgId) {
    final key = epgId?.trim();
    if (key == null || key.isEmpty) return null;

    // RxMap erişimi — GetX Obx içinde dinlenebilir.
    final list = _programmes[key];
    if (list == null || list.isEmpty) return null;

    final now = DateTime.now();
    // [start, end) — şu an yayında olan ilk kayıt
    return list.firstWhereOrNull(
      (p) => !now.isBefore(p.start) && now.isBefore(p.end),
    );
  }

  List<EpgProgramme> getFullDayProgrammes(String? epgId) {
    final key = epgId?.trim();
    if (key == null || key.isEmpty) return [];
    return List<EpgProgramme>.from(_programmes[key] ?? const []);
  }

  void clear() {
    _channels.clear();
    _programmes.clear();
    loadGeneration.value++;
  }
}
