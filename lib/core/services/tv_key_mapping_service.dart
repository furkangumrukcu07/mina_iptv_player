import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layout/app_layout_mode.dart';
import 'app_settings_service.dart';
import 'playlist_data_source.dart';
import '../../modules/player/player_controller.dart';
import '../../modules/player/player_navigation.dart';
import '../../modules/player/player_route_args.dart';
import '../../modules/home/home_controller.dart';
import '../../modules/tv_shell/tv_shell_controller.dart';
import '../../modules/channels/channels_controller.dart' show kFavoritesVirtualCategoryId;
import '../routes/app_routes.dart';
import '../tv/tv_shell_section.dart';

class TvKeyMappingService extends GetxService {
  static TvKeyMappingService get to => Get.find<TvKeyMappingService>();

  static const String _kPrefsKey = 'mina_tv_key_mappings';

  // Map<keyId, { 'action': action, 'label': label }>
  final RxMap<int, Map<String, dynamic>> mappings = <int, Map<String, dynamic>>{}.obs;

  bool isListeningForRegistration = false;
  void Function(LogicalKeyboardKey key)? onKeyRegistered;

  @override
  void onInit() {
    super.onInit();
    _loadMappings();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void onClose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.onClose();
  }

  Future<void> _loadMappings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw != null) {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        final newMap = <int, Map<String, dynamic>>{};
        decoded.forEach((key, value) {
          final keyId = int.tryParse(key);
          if (keyId != null && value is Map<String, dynamic>) {
            newMap[keyId] = value;
          }
        });
        mappings.assignAll(newMap);
      }
    } catch (e) {
      debugPrint('TvKeyMappingService: Error loading mappings: $e');
    }
  }

  Future<void> _saveMappings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringMap = <String, dynamic>{};
      mappings.forEach((key, value) {
        stringMap[key.toString()] = value;
      });
      await prefs.setString(_kPrefsKey, json.encode(stringMap));
    } catch (e) {
      debugPrint('TvKeyMappingService: Error saving mappings: $e');
    }
  }

  Future<void> assignKey(int keyId, String keyLabel, String action) async {
    // Aynı eyleme (action) atanmış eski tuşlar varsa temizle
    mappings.removeWhere((k, v) => v['action'] == action);
    
    // Aynı tuşa atanmış eski eylemi sil/güncelle
    mappings[keyId] = {
      'action': action,
      'label': keyLabel,
    };
    await _saveMappings();
  }

  Future<void> removeMapping(int keyId) async {
    mappings.remove(keyId);
    await _saveMappings();
  }

  Future<void> clearAll() async {
    mappings.clear();
    await _saveMappings();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // TV ve tablet uzaktan kumanda düzeninde çalışır.
    final appSettings = Get.find<AppSettingsService>();
    if (!appSettings.layoutMode.value.usesRemoteNavigationStyle) return false;

    // Tuş kayıt modundaysa
    if (isListeningForRegistration) {
      isListeningForRegistration = false;
      onKeyRegistered?.call(event.logicalKey);
      return true; // Tüket
    }

    // Yazı girilen odak varsa kısayolları engelle
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus.context != null) {
      final widget = primaryFocus.context!.widget;
      if (widget is EditableText) {
        return false;
      }
    }

    final keyId = event.logicalKey.keyId;
    final mapping = mappings[keyId];
    if (mapping != null) {
      final action = mapping['action'] as String;
      // UI döngüsünü engellememek için asenkron tetikle
      Future.microtask(() => _triggerAction(action));
      return true; // Tüket
    }

    return false;
  }

  Future<void> _triggerAction(String action) async {
    debugPrint('TvKeyMappingService: Triggering action: $action');
    switch (action) {
      case 'search':
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().showGlobalSearch(Get.context!);
        }
        break;
      case 'epg_mix':
        Get.toNamed(AppRoutes.epgMix);
        break;
      case 'zap_back':
        await _zapBack();
        break;
      case 'playlists':
        if (Get.isRegistered<TvShellController>()) {
          Get.find<TvShellController>().selectRailSection(TvShellSection.playlists, context: Get.context);
        }
        break;
      case 'favorites':
        if (Get.isRegistered<TvShellController>()) {
          final tvShell = Get.find<TvShellController>();
          tvShell.selectRailSection(TvShellSection.live, context: Get.context);
          tvShell.onCategoryChosen(kFavoritesVirtualCategoryId, context: Get.context);
        }
        break;
      case 'refresh':
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().refreshPlaylist();
        }
        break;
    }
  }

  Future<void> _zapBack() async {
    final prevId = Get.find<AppSettingsService>().previousLiveChannelId.value;
    if (prevId == null) {
      debugPrint('TvKeyMappingService: Zap Back failed: No previous channel.');
      return;
    }
    final channel = await Get.find<PlaylistDataSource>().channelById(prevId);
    if (channel == null) {
      debugPrint('TvKeyMappingService: Zap Back failed: Channel not found.');
      return;
    }
    if (Get.isRegistered<PlayerController>()) {
      try {
        final pc = Get.find<PlayerController>();
        await pc.zapTo(channel);
        return;
      } catch (e) {
        debugPrint('TvKeyMappingService: Zap Back failed zapTo: $e');
      }
    }
    await openPlayerRoute(PlayerScreenArgs(channel: channel));
  }
}
