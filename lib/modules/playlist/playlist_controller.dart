import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/playlist_storage.dart';
import '../../core/error/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../ui/glass_overlays.dart';

class PlaylistController extends GetxController {
  final m3uUrlController = TextEditingController();

  final xtreamBaseUrlController = TextEditingController();
  final xtreamUsernameController = TextEditingController();
  final xtreamPasswordController = TextEditingController();

  final m3uSecondaryUrlController = TextEditingController();
  final xtreamSecondaryBaseUrlController = TextEditingController();
  final xtreamSecondaryUsernameController = TextEditingController();
  final xtreamSecondaryPasswordController = TextEditingController();

  final _repo = Get.find<PlaylistRepository>();
  final _cache = Get.find<PlaylistCacheService>();

  final tabIndex = 0.obs; // 0=M3U, 1=Xtream
  final secondaryTabIndex = 0.obs;
  final enableSecondary = false.obs;
  final isLoading = false.obs;
  final m3uLocalFileName = RxnString();
  final m3uSecondaryLocalFileName = RxnString();

  String? _m3uLocalRaw;
  String? _m3uSecondaryLocalRaw;

  @override
  void onInit() {
    super.onInit();
    m3uUrlController.addListener(_onM3uUrlTyped);
    m3uSecondaryUrlController.addListener(_onM3uSecondaryUrlTyped);
    Future.microtask(_prefillFromStorage);
  }

  void _onM3uUrlTyped() {
    if (m3uUrlController.text.trim().isNotEmpty) {
      clearPickedM3uFile();
    }
  }

  void _onM3uSecondaryUrlTyped() {
    if (m3uSecondaryUrlController.text.trim().isNotEmpty) {
      clearPickedM3uSecondaryFile();
    }
  }

  void clearPickedM3uFile() {
    _m3uLocalRaw = null;
    m3uLocalFileName.value = null;
  }

  void clearPickedM3uSecondaryFile() {
    _m3uSecondaryLocalRaw = null;
    m3uSecondaryLocalFileName.value = null;
  }

  Future<void> _prefillFromStorage() async {
    try {
      final sec = await _repo.readSecondarySource();
      if (sec == null) return;
      enableSecondary.value = true;
      switch (sec) {
        case M3uSource(:final url):
          secondaryTabIndex.value = 0;
          if (isM3uLocalSentinel2(url)) {
            m3uSecondaryLocalFileName.value = 'playlist.label.localM3u'.tr;
          } else {
            m3uSecondaryUrlController.text = url;
          }
        case XtreamSource(
            :final baseUrl,
            :final username,
            :final password,
          ):
          secondaryTabIndex.value = 1;
          xtreamSecondaryBaseUrlController.text = baseUrl;
          xtreamSecondaryUsernameController.text = username;
          xtreamSecondaryPasswordController.text = password;
      }
    } catch (_) {}
  }

  @override
  void onClose() {
    m3uUrlController.removeListener(_onM3uUrlTyped);
    m3uSecondaryUrlController.removeListener(_onM3uSecondaryUrlTyped);
    m3uUrlController.dispose();
    xtreamBaseUrlController.dispose();
    xtreamUsernameController.dispose();
    xtreamPasswordController.dispose();
    m3uSecondaryUrlController.dispose();
    xtreamSecondaryBaseUrlController.dispose();
    xtreamSecondaryUsernameController.dispose();
    xtreamSecondaryPasswordController.dispose();
    super.onClose();
  }

  void setTab(int index) => tabIndex.value = index;

  void setSecondaryTab(int index) => secondaryTabIndex.value = index;

  Future<void> pickM3uFile() async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (r == null || r.files.isEmpty) return;
      final f = r.files.single;

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

  Future<void> pickM3uSecondaryFile() async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (r == null || r.files.isEmpty) return;
      final f = r.files.single;

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
      _m3uSecondaryLocalRaw = content;
      m3uSecondaryLocalFileName.value = f.name;
      m3uSecondaryUrlController.clear();
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
      late final String cacheLabel;

      if (tabIndex.value == 0) {
        if (_m3uLocalRaw != null) {
          await _repo.persistM3uLocalContent(_m3uLocalRaw!);
          cacheLabel = m3uLocalFileName.value ?? 'playlist.label.localM3u'.tr;
        } else {
          final source = _m3uSource();
          await _repo.loadFromM3uUrl(source.url);
          await _repo.persistSource(source);
          cacheLabel = source.url;
        }
      } else {
        final source = _xtreamSource();
        await _repo.loadFromXtream(
          baseUrl: source.baseUrl,
          username: source.username,
          password: source.password,
        );
        await _repo.persistSource(source);
        cacheLabel = source.baseUrl;
      }

      if (!enableSecondary.value) {
        await _repo.clearSecondarySource();
        final parsed = await _repo.loadMergedPlaylist(
          secondaryOrphanCategoryName: 'playlist.merge.orphanCategory'.tr,
        );
        _cache.setPlaylist(value: parsed, url: cacheLabel);
        Get.offAllNamed(AppRoutes.home);
        return;
      }

      if (secondaryTabIndex.value == 0) {
        if (_m3uSecondaryLocalRaw != null) {
          await _repo.persistM3uLocalContentSecondary(_m3uSecondaryLocalRaw!);
        } else {
          final url = m3uSecondaryUrlController.text.trim();
          if (url.isEmpty) {
            final existing = await _repo.readSecondarySource();
            if (existing is! M3uSource || !isM3uLocalSentinel2(existing.url)) {
              throw ParseException('playlist.error.secondaryUrl'.tr);
            }
          } else {
            final s2 = M3uSource(url: url);
            await _repo.loadFromM3uUrl(s2.url);
            await _repo.persistSecondarySource(s2);
          }
        }
      } else {
        final x2 = _xtreamSecondarySource();
        await _repo.persistSecondarySource(x2);
      }

      final merged = await _repo.loadMergedPlaylist(
        secondaryOrphanCategoryName: 'playlist.merge.orphanCategory'.tr,
      );
      _cache.setPlaylist(value: merged, url: '$cacheLabel (+2)');
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

  XtreamSource _xtreamSecondarySource() {
    final baseUrl = xtreamSecondaryBaseUrlController.text.trim();
    final username = xtreamSecondaryUsernameController.text.trim();
    final password = xtreamSecondaryPasswordController.text;
    if (baseUrl.isEmpty || username.isEmpty || password.trim().isEmpty) {
      throw ParseException('playlist.error.secondaryXtream'.tr);
    }
    final normalized = _normalizeBaseUrl(baseUrl);
    return XtreamSource(
      baseUrl: normalized,
      username: username,
      password: password,
    );
  }

  String _normalizeBaseUrl(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return '';

    raw = raw.split('?').first;
    raw = raw.replaceAll('player_api.php', '');
    raw = raw.replaceAll(RegExp(r'/$'), '');

    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;

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
