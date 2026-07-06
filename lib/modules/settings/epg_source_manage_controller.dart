import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/epg/epg_panel_xmltv_url.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../data/local/epg_snapshot_keys.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';
import 'settings_controller.dart';

class EpgMatchRow {
  const EpgMatchRow({
    required this.channel,
    required this.xmlChannelId,
    required this.xmlDisplayName,
    required this.isMatched,
  });

  final Channel channel;
  final String? xmlChannelId;
  final String? xmlDisplayName;
  final bool isMatched;
}

class EpgSourceManageController extends GetxController {
  final _app = Get.find<AppSettingsService>();
  final _repo = Get.find<PlaylistRepository>();
  final _cache = Get.find<PlaylistCacheService>();
  final _epg = Get.find<EpgService>();
  final _settings = Get.find<SettingsController>();

  final urlController = TextEditingController();
  final searchController = TextEditingController();
  final searchQuery = ''.obs;
  final tabIndex = 0.obs;
  final isSaving = false.obs;
  final isXtream = false.obs;

  final rows = <EpgMatchRow>[].obs;
  final categories = <({int id, String name})>[].obs;
  final selectedCategoryId = Rxn<int>();

  String? _cacheKey;
  List<Channel> _allChannels = [];

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() {
      searchQuery.value = searchController.text.trim().toLowerCase();
    });
    unawaited(_bootstrap());
  }

  @override
  void onClose() {
    urlController.dispose();
    searchController.dispose();
    super.onClose();
  }

  Future<void> _bootstrap() async {
    final source = await _repo.readSource();
    isXtream.value = source is XtreamSource;
    _cacheKey = source != null
        ? EpgSnapshotKeys.logicalKeyFor(source, _app)
        : null;

    final pl = _cache.result.value;
    _allChannels = pl?.channels ?? [];
    if (pl != null) {
      categories.assignAll(
        pl.channelCategories.map((c) => (id: c.id, name: c.name)),
      );
    }

    urlController.text = resolveEpgSourceDisplayUrl(
      source: source,
      customXmltvUrl: _app.xmltvUrl.value,
      m3uFallbackUrl: _app.effectiveM3uXmltvUrl,
    );

    _rebuildRows();
  }

  void _rebuildRows() {
    final mappings = _epg.m3uStreamUrlToXmlId;
    final out = <EpgMatchRow>[];
    for (final ch in _allChannels) {
      String? xmlId = mappings[ch.streamUrl];
      xmlId ??= ch.epgChannelId?.trim();
      if (xmlId != null && xmlId.isEmpty) xmlId = null;
      if (xmlId == null) {
        final byId = ch.id.toString();
        if (_epg.getFullDayProgrammes(byId).isNotEmpty) {
          xmlId = byId;
        }
      }
      final xmlName =
          xmlId != null ? _epg.xmlTvChannelDisplayName(xmlId) : null;
      final matched = xmlId != null &&
          _epg.getFullDayProgrammes(xmlId).isNotEmpty;
      out.add(
        EpgMatchRow(
          channel: ch,
          xmlChannelId: xmlId,
          xmlDisplayName: xmlName,
          isMatched: matched,
        ),
      );
    }
    rows.assignAll(out);
  }

  int get matchedCount => rows.where((r) => r.isMatched).length;

  List<EpgMatchRow> get visibleRows {
    final q = searchQuery.value;
    final cat = selectedCategoryId.value;
    return rows.where((r) {
      if (cat != null && r.channel.categoryId != cat) return false;
      if (q.isEmpty) return true;
      final blob =
          '${r.channel.name} ${r.xmlDisplayName ?? ''}'.toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  void setTab(int i) => tabIndex.value = i;

  void selectCategory(int? id) {
    selectedCategoryId.value = id;
    if (tabIndex.value == 0) tabIndex.value = 1;
  }

  Future<void> saveAndRefresh() async {
    if (isSaving.value) return;
    isSaving.value = true;
    try {
      // Allow saving XMLTV URL for all source types (M3U and Xtream)
      await _app.setXmltvUrl(urlController.text.trim());
      await _settings.refreshEpgGuide();
      final pl = _cache.result.value;
      if (pl != null && _cacheKey != null) {
        await _epg.applyM3uXmltvChannelMappings(
          cacheKey: _cacheKey,
          liveChannels: pl.channels,
        );
      }
      _rebuildRows();
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> refreshEpgOnly() async {
    await _settings.refreshEpgGuide();
    _rebuildRows();
  }

  Future<void> pickXmlForChannel(EpgMatchRow row) async {
    final entries = _epg.xmlTvChannelEntries;
    if (entries.isEmpty) {
      Get.snackbar('settings.epg.source.title'.tr, 'common.error'.tr);
      return;
    }

    final picked = await Get.dialog<String>(
      Dialog(
        backgroundColor: const Color(0xFF1A1035),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'settings.epg.source.pickXml'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    return ListTile(
                      title: Text(
                        e.value,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        e.key,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                      onTap: () => Get.back(result: e.key),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: () => Get.back<void>(),
                child: Text('common.cancel'.tr),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || _cacheKey == null) return;
    await _epg.updateM3uStreamMapping(
      cacheKey: _cacheKey!,
      streamUrl: row.channel.streamUrl,
      xmlChannelId: picked,
      liveChannels: _allChannels,
    );
    _rebuildRows();
  }
}
