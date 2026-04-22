import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/playlist_storage.dart';
import '../../core/error/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
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

  final m3uSecondaryUrlController = TextEditingController();
  final xtreamSecondaryBaseUrlController = TextEditingController();
  final xtreamSecondaryUsernameController = TextEditingController();
  final xtreamSecondaryPasswordController = TextEditingController();

  final _repo = Get.find<PlaylistRepository>();
  final _cache = Get.find<PlaylistCacheService>();

  /// 0 = M3U (sol / ilk sekme), 1 = Xtream.
  final tabIndex = 0.obs;
  /// 0 = M3U, 1 = Xtream — birincil ile aynı sıra.
  final secondaryTabIndex = 0.obs;
  final enableSecondary = false.obs;
  final isLoading = false.obs;
  final m3uLocalFileName = RxnString();
  final m3uSecondaryLocalFileName = RxnString();
  
  // M3U listesi yüklü mi kontrolü
  final isM3uLoaded = false.obs;

  String? _m3uLocalRaw;
  String? _m3uSecondaryLocalRaw;

  /// TV kumandası: M3U metin alanından sekmelere güvenilir dönüş ([PlaylistView] bağlar).
  VoidCallback? _focusPrimaryM3uTabChip;
  VoidCallback? _focusPrimaryXtreamTabChip;
  VoidCallback? _focusSecondaryM3uTabChip;
  VoidCallback? _focusSecondaryXtreamTabChip;

  /// TV: sekmeden aşağı → doğrudan ilgili metin alanı ([PlaylistView] bağlar).
  VoidCallback? _focusPrimaryM3uUrlField;
  VoidCallback? _focusPrimaryM3uFilePick;
  VoidCallback? _focusPrimaryXtreamServerField;
  VoidCallback? _focusSecondaryM3uUrlField;
  VoidCallback? _focusSecondaryM3uFilePick;
  VoidCallback? _focusSecondaryXtreamServerField;

  void bindPrimarySourceTabFocus({
    required VoidCallback focusM3uChip,
    required VoidCallback focusXtreamChip,
  }) {
    _focusPrimaryM3uTabChip = focusM3uChip;
    _focusPrimaryXtreamTabChip = focusXtreamChip;
  }

  void unbindPrimarySourceTabFocus() {
    _focusPrimaryM3uTabChip = null;
    _focusPrimaryXtreamTabChip = null;
  }

  void bindSecondarySourceTabFocus({
    required VoidCallback focusM3uChip,
    required VoidCallback focusXtreamChip,
  }) {
    _focusSecondaryM3uTabChip = focusM3uChip;
    _focusSecondaryXtreamTabChip = focusXtreamChip;
  }

  void unbindSecondarySourceTabFocus() {
    _focusSecondaryM3uTabChip = null;
    _focusSecondaryXtreamTabChip = null;
  }

  void tvFocusPrimaryM3uTabChip() {
    setTab(0);
    _focusPrimaryM3uTabChip?.call();
    _postFrameTwice(() => _focusPrimaryM3uTabChip?.call());
  }

  void tvFocusPrimaryXtreamTabChip() {
    setTab(1);
    _focusPrimaryXtreamTabChip?.call();
    _postFrameTwice(() => _focusPrimaryXtreamTabChip?.call());
  }

  void tvFocusSecondaryM3uTabChip() {
    setSecondaryTab(0);
    _focusSecondaryM3uTabChip?.call();
    _postFrameTwice(() => _focusSecondaryM3uTabChip?.call());
  }

  void tvFocusSecondaryXtreamTabChip() {
    setSecondaryTab(1);
    _focusSecondaryXtreamTabChip?.call();
    _postFrameTwice(() => _focusSecondaryXtreamTabChip?.call());
  }

  void bindPrimaryM3uUrlFieldFocus(VoidCallback requestFocus) {
    _focusPrimaryM3uUrlField = requestFocus;
  }

  void unbindPrimaryM3uUrlFieldFocus() {
    _focusPrimaryM3uUrlField = null;
  }

  void bindPrimaryM3uFilePickFocus(VoidCallback requestFocus) {
    _focusPrimaryM3uFilePick = requestFocus;
  }

  void unbindPrimaryM3uFilePickFocus() {
    _focusPrimaryM3uFilePick = null;
  }

  void bindPrimaryXtreamServerFieldFocus(VoidCallback requestFocus) {
    _focusPrimaryXtreamServerField = requestFocus;
  }

  void unbindPrimaryXtreamServerFieldFocus() {
    _focusPrimaryXtreamServerField = null;
  }

  void bindSecondaryM3uUrlFieldFocus(VoidCallback requestFocus) {
    _focusSecondaryM3uUrlField = requestFocus;
  }

  void unbindSecondaryM3uUrlFieldFocus() {
    _focusSecondaryM3uUrlField = null;
  }

  void bindSecondaryM3uFilePickFocus(VoidCallback requestFocus) {
    _focusSecondaryM3uFilePick = requestFocus;
  }

  void unbindSecondaryM3uFilePickFocus() {
    _focusSecondaryM3uFilePick = null;
  }

  void bindSecondaryXtreamServerFieldFocus(VoidCallback requestFocus) {
    _focusSecondaryXtreamServerField = requestFocus;
  }

  void unbindSecondaryXtreamServerFieldFocus() {
    _focusSecondaryXtreamServerField = null;
  }

  void _postFrameTwice(VoidCallback body) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => body());
    });
  }

  void tvFocusPrimaryM3uUrlField() {
    setTab(0);
    _focusPrimaryM3uUrlField?.call();
    _postFrameTwice(() => _focusPrimaryM3uUrlField?.call());
  }

  void tvFocusPrimaryM3uFilePick() {
    setTab(0);
    _focusPrimaryM3uFilePick?.call();
    _postFrameTwice(() => _focusPrimaryM3uFilePick?.call());
  }

  void tvFocusPrimaryXtreamServerField() {
    setTab(1);
    _focusPrimaryXtreamServerField?.call();
    _postFrameTwice(() => _focusPrimaryXtreamServerField?.call());
  }

  void tvFocusSecondaryM3uUrlField() {
    setSecondaryTab(0);
    _focusSecondaryM3uUrlField?.call();
    _postFrameTwice(() => _focusSecondaryM3uUrlField?.call());
  }

  void tvFocusSecondaryM3uFilePick() {
    setSecondaryTab(0);
    _focusSecondaryM3uFilePick?.call();
    _postFrameTwice(() => _focusSecondaryM3uFilePick?.call());
  }

  void tvFocusSecondaryXtreamServerField() {
    setSecondaryTab(1);
    _focusSecondaryXtreamServerField?.call();
    _postFrameTwice(() => _focusSecondaryXtreamServerField?.call());
  }

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
      isM3uLoaded.value = false; // URL değişiminde yükleme durumunu sıfırla
    }
  }

  void _onM3uSecondaryUrlTyped() {
    if (m3uSecondaryUrlController.text.trim().isNotEmpty) {
      clearPickedM3uSecondaryFile();
      isM3uLoaded.value = false; // Secondary URL değişiminde yükleme durumunu sıfırla
    }
  }

  void clearPickedM3uFile() {
    _m3uLocalRaw = null;
    m3uLocalFileName.value = null;
    isM3uLoaded.value = false; // M3U temizlendiğinde yükleme durumunu sıfırla
  }

  void clearPickedM3uSecondaryFile() {
    _m3uSecondaryLocalRaw = null;
    m3uSecondaryLocalFileName.value = null;
    isM3uLoaded.value = false; // M3U temizlendiğinde yükleme durumunu sıfırla
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
    unbindPrimarySourceTabFocus();
    unbindSecondarySourceTabFocus();
    unbindPrimaryM3uUrlFieldFocus();
    unbindPrimaryM3uFilePickFocus();
    unbindPrimaryXtreamServerFieldFocus();
    unbindSecondaryM3uUrlFieldFocus();
    unbindSecondaryM3uFilePickFocus();
    unbindSecondaryXtreamServerFieldFocus();
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
      isM3uLoaded.value = true; // M3U listesi yüklendi olarak işaretle
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
      isM3uLoaded.value = true; // M3U listesi yüklendi olarak işaretle
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

  Future<void> loadDemoPlaylist() async {
    try {
      isLoading.value = true;
      
      // Demo M3U playlist content
      const demoM3uContent = '''#EXTM3U
#EXTINF:-1 tvg-id="1" tvg-name="Demo News" tvg-logo="https://via.placeholder.com/150" group-title="News",Demo News Channel
https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4
#EXTINF:-1 tvg-id="2" tvg-name="Demo Sports" tvg-logo="https://via.placeholder.com/150" group-title="Sports",Demo Sports Channel
https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4
#EXTINF:-1 tvg-id="3" tvg-name="Demo Movies" tvg-logo="https://via.placeholder.com/150" group-title="Movies",Demo Movie Channel
https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4
#EXTINF:-1 tvg-id="4" tvg-name="Demo Kids" tvg-logo="https://via.placeholder.com/150" group-title="Kids",Demo Kids Channel
https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4
#EXTINF:-1 tvg-id="5" tvg-name="Demo Music" tvg-logo="https://via.placeholder.com/150" group-title="Music",Demo Music Channel
https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4''';
      
      final parsedPrimary = await _repo.persistM3uLocalContent(demoM3uContent);
      final cacheLabel = 'Demo Playlist';
      
      await _repo.clearSecondarySource();
      await _repo.persistMergedPlaylistSnapshot(parsedPrimary);
      isM3uLoaded.value = true; // Demo playlist yüklendi olarak işaretle
      
      _cache.setPlaylist(
        value: parsedPrimary,
        url: cacheLabel,
        xtreamPreferenceKey: null,
      );
      
      Get.offAllNamed(AppRoutes.home);
      
      GlassSnackbar.show(
        'playlist.snackbar.setup'.tr,
        'Demo playlist loaded successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
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

  Future<void> submit() async {
    try {
      // Input validation before loading state
      late final String cacheLabel;
      late final M3uResult parsedPrimary;

      if (tabIndex.value == 0) {
        if (_m3uLocalRaw != null) {
          // Local M3U file - no validation needed
        } else {
          // Validate M3U URL before loading
          _m3uSource();
        }
      } else {
        // Validate Xtream credentials before loading
        _xtreamSource();
      }
      
      // All validations passed, start loading
      isLoading.value = true;

      if (tabIndex.value == 0) {
        if (_m3uLocalRaw != null) {
          parsedPrimary = await _repo.persistM3uLocalContent(_m3uLocalRaw!);
          cacheLabel = m3uLocalFileName.value ?? 'playlist.label.localM3u'.tr;
        } else {
          final source = _m3uSource();
          parsedPrimary = await _repo.loadFromM3uUrl(source.url);
          await _repo.persistSource(source);
          cacheLabel = source.url;
          isM3uLoaded.value = true; // M3U listesi yüklendi olarak işaretle
        }
      } else {
        final source = _xtreamSource();
        parsedPrimary = await _repo.loadFromXtream(
          baseUrl: source.baseUrl,
          username: source.username,
          password: source.password,
        );
        await _repo.persistSource(source);
        cacheLabel = source.baseUrl;
      }

      if (!enableSecondary.value) {
        await _repo.clearSecondarySource();
        await _repo.persistMergedPlaylistSnapshot(parsedPrimary);
        final xk = tabIndex.value == 1
            ? AppSettingsService.xtreamPreferenceKey(_xtreamSource())
            : null;
        _cache.setPlaylist(
          value: parsedPrimary,
          url: cacheLabel,
          xtreamPreferenceKey: xk,
        );
        Get.offAllNamed(AppRoutes.home);
        return;
      }

      // Validate secondary inputs before loading
      if (secondaryTabIndex.value == 0) {
        if (_m3uSecondaryLocalRaw != null) {
          // Local M3U file - no validation needed
        } else {
          final url = m3uSecondaryUrlController.text.trim();
          if (url.isEmpty) {
            final existing = await _repo.readSecondarySource();
            if (existing is! M3uSource || !isM3uLocalSentinel2(existing.url)) {
              throw ParseException('playlist.error.secondaryUrl'.tr);
            }
          } else {
            // Validate M3U URL before loading
            M3uSource(url: url);
          }
        }
      } else {
        // Validate Xtream credentials before loading
        _xtreamSecondarySource();
      }

      // All validations passed, continue with loading
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
            isM3uLoaded.value = true; // M3U listesi yüklendi olarak işaretle
          }
        }
      } else {
        final x2 = _xtreamSecondarySource();
        await _repo.persistSecondarySource(x2);
      }

      final merged = await _repo.loadMergedPlaylist(
        secondaryOrphanCategoryName: 'playlist.merge.orphanCategory'.tr,
      );
      final xk = tabIndex.value == 1
          ? AppSettingsService.xtreamPreferenceKey(_xtreamSource())
          : null;
      _cache.setPlaylist(
        value: merged,
        url: '$cacheLabel (+2)',
        xtreamPreferenceKey: xk,
      );
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
