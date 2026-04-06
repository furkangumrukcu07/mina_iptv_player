import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/error/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../ui/glass_overlays.dart';

class PlaylistController extends GetxController {
  final m3uUrlController = TextEditingController();

  final xtreamBaseUrlController = TextEditingController();
  final xtreamUsernameController = TextEditingController();
  final xtreamPasswordController = TextEditingController();

  final _repo = Get.find<PlaylistRepository>();
  final _cache = Get.find<PlaylistCacheService>();

  final tabIndex = 0.obs; // 0=M3U, 1=Xtream
  final isLoading = false.obs;
  final m3uLocalFileName = RxnString();

  String? _m3uLocalRaw;

  @override
  void onInit() {
    super.onInit();
    m3uUrlController.addListener(_onM3uUrlTyped);
  }

  void _onM3uUrlTyped() {
    if (m3uUrlController.text.trim().isNotEmpty) {
      clearPickedM3uFile();
    }
  }

  void clearPickedM3uFile() {
    _m3uLocalRaw = null;
    m3uLocalFileName.value = null;
  }

  @override
  void onClose() {
    m3uUrlController.removeListener(_onM3uUrlTyped);
    m3uUrlController.dispose();
    xtreamBaseUrlController.dispose();
    xtreamUsernameController.dispose();
    xtreamPasswordController.dispose();
    super.onClose();
  }

  void setTab(int index) => tabIndex.value = index;

  Future<void> pickM3uFile() async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType
            .any, // Use FileType.any for better compatibility with native pickers
        allowMultiple: false,
      );
      if (r == null || r.files.isEmpty) return;
      final f = r.files.single;

      // Check extension manually for better UX
      final name = f.name.toLowerCase();
      if (!name.endsWith('.m3u') &&
          !name.endsWith('.m3u8') &&
          !name.endsWith('.txt')) {
        GlassSnackbar.show(
          'playlist.snackbar.file'.tr,
          'playlist.snackbar.badExt'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      late final String content;
      if (f.path != null) {
        content = await File(f.path!).readAsString(encoding: utf8);
      } else if (f.bytes != null) {
        content = utf8.decode(f.bytes!, allowMalformed: true);
      } else {
        GlassSnackbar.show(
          'playlist.snackbar.file'.tr,
          'playlist.snackbar.readFail'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      await _repo.loadFromM3uContent(content);
      _m3uLocalRaw = content;
      m3uLocalFileName.value = f.name;
      m3uUrlController.clear();
    } on AppException catch (e) {
      GlassSnackbar.show(
        'playlist.snackbar.m3u'.tr,
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      GlassSnackbar.show(
        'playlist.snackbar.file'.tr,
        'playlist.snackbar.fileError'.trParams({'e': e.toString()}),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> submit() async {
    isLoading.value = true;
    try {
      late final M3uResult parsed;
      late final String cacheLabel;

      if (tabIndex.value == 0) {
        if (_m3uLocalRaw != null) {
          parsed = await _repo.persistM3uLocalContent(_m3uLocalRaw!);
          cacheLabel = m3uLocalFileName.value ?? 'playlist.label.localM3u'.tr;
        } else {
          final source = _m3uSource();
          parsed = await _repo.loadFromM3uUrl(source.url);
          await _repo.persistSource(source);
          cacheLabel = source.url;
        }
      } else {
        final source = _xtreamSource();
        parsed = await _repo.loadFromXtream(
          baseUrl: source.baseUrl,
          username: source.username,
          password: source.password,
        );
        await _repo.persistSource(source);
        cacheLabel = source.baseUrl;
      }

      _cache.setPlaylist(value: parsed, url: cacheLabel);
      Get.offAllNamed(AppRoutes.home);
    } on AppException catch (e) {
      GlassSnackbar.show(
        'playlist.snackbar.setup'.tr,
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      GlassSnackbar.show(
        'playlist.snackbar.setup'.tr,
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  M3uSource _m3uSource() {
    final url = m3uUrlController.text.trim();
    if (url.isEmpty) {
      throw ParseException('playlist.error.emptyUrl'.tr);
    }
    return M3uSource(url: url);
  }

  XtreamSource _xtreamSource() {
    final baseUrl = xtreamBaseUrlController.text.trim();
    final username = xtreamUsernameController.text.trim();
    final password = xtreamPasswordController.text;
    if (baseUrl.isEmpty || username.isEmpty || password.trim().isEmpty) {
      throw ParseException('playlist.error.xtream'.tr);
    }
    final normalized = _normalizeBaseUrl(baseUrl);
    return XtreamSource(
        baseUrl: normalized, username: username, password: password);
  }

  String _normalizeBaseUrl(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return '';

    // Remove any trailing player_api.php or slashes
    raw = raw.split('?').first;
    raw = raw.replaceAll('player_api.php', '');
    raw = raw.replaceAll(RegExp(r'/$'), '');

    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;

    // Handle inputs without scheme like "host:port"
    if (uri.scheme.isEmpty) {
      final fixed = Uri.tryParse('http://$raw');
      if (fixed == null || fixed.host.isEmpty) {
        return raw;
      }
      return _normalizeBaseUrl(fixed.toString());
    }

    final scheme = uri.scheme;
    final host = uri.host;
    if (host.isEmpty) return raw;

    final port = uri.hasPort ? uri.port : null;
    return (port == null) ? '$scheme://$host' : '$scheme://$host:$port';
  }
}
