import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/playlist_storage.dart';
import '../../core/error/app_exception.dart';
import '../../core/i18n/app_locale.dart';
import '../../core/i18n/theme_label_localized.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/player/adaptive_stream_quality_ceiling.dart';
import '../../core/epg/catch_up_url_template.dart';
import '../../core/services/epg_service.dart';
import '../../data/local/epg_snapshot_keys.dart';
import '../../data/remote/xtream_api.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/iptv_logo_cache_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/theme/glass_appearance.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../browse/browse_controller.dart';
import '../channels/channels_controller.dart';
import '../../ui/glass_overlays.dart';
import 'subtitle_font_picker_dialog.dart';

class SettingsController extends GetxController {
  final _repo = Get.find<PlaylistRepository>();
  final _cache = Get.find<PlaylistCacheService>();
  final _fav = Get.find<FavoritesService>();
  final _app = Get.find<AppSettingsService>();

  final now = DateTime.now().obs;
  Timer? _clock;
  final isRefreshing = false.obs;
  final isFetchingInfo = false.obs;
  final isXtream = false.obs;

  /// Ayarlar altı: Xtream kullanıcı + sunucu (şifre yok).
  final xtreamFooterLine = ''.obs;

  /// Boş: henüz yüklenmedi. Örn. `1.1.0 (2014)`.
  final packageVersionLabel = ''.obs;

  AppSettingsService get app => _app;

  Future<void> toggleXtreamSkipPanelXmltvEpg() async {
    await _app.setXtreamSkipPanelXmltvEpg(!_app.xtreamSkipPanelXmltvEpg.value);
  }

  Future<void> toggleStreamPreviewEnabled() async {
    final next = !_app.streamPreviewEnabled.value;
    await _app.setStreamPreviewEnabled(next);
    if (!next) {
      if (Get.isRegistered<ChannelsController>()) {
        Get.find<ChannelsController>().clearStreamPreview();
      }
      if (Get.isRegistered<BrowseController>()) {
        Get.find<BrowseController>().clearStreamPreview();
      }
    }
  }

  @override
  void onInit() {
    super.onInit();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      now.value = DateTime.now();
    });
    unawaited(_loadPackageInfo());
    _checkSource();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      packageVersionLabel.value = '${info.version} (${info.buildNumber})';
    } catch (_) {
      packageVersionLabel.value = '';
    }
  }

  Future<void> _checkSource() async {
    final s = await _repo.readSource();
    isXtream.value = s is XtreamSource;
    if (s is XtreamSource) {
      final host = _shortUrlHost(s.baseUrl);
      xtreamFooterLine.value = 'settings.xtreamFooter.line'.trParams({
        'user': s.username,
        'host': host,
      });
    } else {
      xtreamFooterLine.value = '';
    }
  }

  String _shortUrlHost(String raw) {
    final u = Uri.tryParse(raw.trim());
    if (u != null && u.host.isNotEmpty) {
      return u.hasPort ? '${u.host}:${u.port}' : u.host;
    }
    return raw.trim();
  }

  @override
  void onReady() {
    super.onReady();
    now.value = DateTime.now();
  }

  @override
  void onClose() {
    _clock?.cancel();
    super.onClose();
  }

  Future<void> _reloadEpgAfterPlaylist(PlaylistSource source) async {
    final epg = Get.find<EpgService>();
    try {
      if (source is XtreamSource) {
        final u = await _repo.getXtreamEpgUrl();
        final api = XtreamApi(
          baseUrl: source.baseUrl,
          username: source.username,
          password: source.password,
        );
        if (u != null && u.isNotEmpty && !_app.xtreamSkipPanelXmltvEpg.value) {
          await epg.loadEpg(u);
        }
        await epg.loadXtreamAllLiveEpg(api);
      } else if (source is M3uSource) {
        final u = _app.xmltvUrl.value.trim();
        if (u.isNotEmpty) {
          await epg.loadEpg(u);
        }
      }
      final cacheKey = EpgSnapshotKeys.logicalKeyFor(source, _app);
      if (cacheKey != null) {
        await epg.persistSnapshotToDisk(cacheKey);
      }
    } catch (e) {
      debugPrint('mina_iptv: EPG reload after refresh: $e');
    }
  }

  Future<void> refreshContent() async {
    if (isRefreshing.value) return;
    final source = await _repo.readSource();
    if (source == null) {
      GlassSnackbar.show(
        'settings.snackbar.content'.tr,
        'settings.snackbar.noPlaylist'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final days = await Get.dialog<int>(
      GlassAlertDialog(
        title: Text('settings.dialog.refreshTitle'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('settings.dialog.refreshBody'.tr),
            const SizedBox(height: 16),
            GlassListTile(
              title: Text('settings.dialog.refresh.autoOff'.tr),
              trailing: _app.autoRefreshDays.value == 0
                  ? const Icon(Icons.check_rounded, color: Colors.white)
                  : null,
              selected: _app.autoRefreshDays.value == 0,
              onTap: () => Navigator.pop(Get.context!, 0),
            ),
            GlassListTile(
              title: Text('settings.dialog.refresh.every3'.tr),
              trailing: _app.autoRefreshDays.value == 3
                  ? const Icon(Icons.check_rounded, color: Colors.white)
                  : null,
              selected: _app.autoRefreshDays.value == 3,
              onTap: () => Navigator.pop(Get.context!, 3),
            ),
            GlassListTile(
              title: Text('settings.dialog.refresh.every7'.tr),
              trailing: _app.autoRefreshDays.value == 7
                  ? const Icon(Icons.check_rounded, color: Colors.white)
                  : null,
              selected: _app.autoRefreshDays.value == 7,
              onTap: () => Navigator.pop(Get.context!, 7),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(Get.context!, -1),
            child: Text('settings.dialog.refresh.nowOnly'.tr),
          ),
        ],
      ),
    );

    if (days == null) return;
    if (days >= 0) {
      await _app.setAutoRefreshDays(days);
    }

    isRefreshing.value = true;
    try {
      final parsed = await _repo.loadMergedPlaylist(
        secondaryOrphanCategoryName: 'playlist.merge.orphanCategory'.tr,
      );
      final sec = await _repo.readSecondarySource();
      final urlLabel = switch (source) {
        M3uSource() => isM3uLocalSentinel(source.url)
            ? 'playlist.label.localM3u'.tr
            : source.url,
        XtreamSource() => source.baseUrl,
      };
      final label = sec == null ? urlLabel : '$urlLabel (+2)';
      final xk = switch (source) {
        XtreamSource x => AppSettingsService.xtreamPreferenceKey(x),
        _ => null,
      };
      _cache.setPlaylist(
        value: parsed,
        url: label,
        xtreamPreferenceKey: xk,
      );
      await _app.updateLastRefreshTime();
      unawaited(_reloadEpgAfterPlaylist(source));
      GlassSnackbar.show(
        'settings.snackbar.content'.tr,
        'settings.snackbar.refreshOk'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } on AppException catch (e) {
      GlassSnackbar.show(
        'settings.snackbar.error'.tr,
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      GlassSnackbar.show(
        'settings.snackbar.error'.tr,
        'settings.snackbar.loadFailed'.trParams({'e': '$e'}),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isRefreshing.value = false;
    }
  }

  void openParentalControl() {
    Get.toNamed(AppRoutes.parentalControl);
  }

  void openCategoryHide() {
    Get.toNamed(AppRoutes.xtreamCategoryHide);
  }

  Future<void> showXtreamInfo() async {
    if (isFetchingInfo.value) return;

    final source = await _repo.readSource();
    if (source is! XtreamSource) {
      GlassSnackbar.show(
        'settings.snackbar.info'.tr,
        'settings.snackbar.xtreamOnly'.tr,
      );
      return;
    }

    isFetchingInfo.value = true;
    try {
      final info = await _repo.getXtreamUserInfo(
        baseUrl: source.baseUrl,
        username: source.username,
        password: source.password,
      );

      if (info == null) {
        GlassSnackbar.show(
          'settings.snackbar.error'.tr,
          'settings.snackbar.xtreamFail'.tr,
        );
        return;
      }

      final expiry = info.expiryDate != null
          ? "${info.expiryDate!.day}.${info.expiryDate!.month}.${info.expiryDate!.year}"
          : 'settings.xtream.unlimited'.tr;

      await Get.dialog(
        GlassAlertDialog(
          title: Text('settings.dialog.xtreamTitle'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('settings.xtream.user'.tr, info.username),
              _infoRow('settings.xtream.status'.tr, info.status.toUpperCase()),
              _infoRow('settings.xtream.expiry'.tr, expiry),
              _infoRow(
                'settings.xtream.connections'.tr,
                '${info.activeConnections} / ${info.maxConnections}',
              ),
              _infoRow(
                'settings.xtream.trial'.tr,
                info.isTrial ? 'common.yes'.tr : 'common.no'.tr,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(Get.context!),
              child: Text('common.close'.tr),
            ),
          ],
        ),
      );
    } catch (e) {
      GlassSnackbar.show(
        'settings.snackbar.error'.tr,
        'settings.snackbar.xtreamError'.trParams({'e': '$e'}),
      );
    } finally {
      isFetchingInfo.value = false;
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void setAutoRefreshDays(int days) => _app.setAutoRefreshDays(days);

  void goBack() => Get.back();

  Future<void> openPlaylistList() async {
    await Get.toNamed(
      AppRoutes.playlist,
      arguments: const {AppRoutes.argPlaylistManage: true},
    );
    await _checkSource();
  }

  Future<void> showSleepTimerDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    Future<int?> pickMinutes() {
      return showDialog<int>(
        context: ctx,
        builder: (c) => GlassAlertDialog(
          scrollable: false,
          title: Text('settings.dialog.sleepTimerTitle'.tr),
          content: LayoutBuilder(
            builder: (context, _) {
              final maxListH = MediaQuery.sizeOf(context).height * 0.5;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxListH),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GlassListTile(
                            dense: true,
                            title: Text('settings.sleepTimer.off'.tr),
                            trailing: _app.sleepTimerEndMs.value == null
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white)
                                : null,
                            selected: _app.sleepTimerEndMs.value == null,
                            onTap: () => Navigator.pop(c, 0),
                          ),
                          for (final m in [15, 30, 45, 60, 90, 120])
                            GlassListTile(
                              dense: true,
                              title: Text(
                                'settings.sleepTimer.optionMinutes'
                                    .trParams({'n': '$m'}),
                              ),
                              onTap: () => Navigator.pop(c, m),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text('common.cancel'.tr),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: null,
        ),
      );
    }

    final minutes = await pickMinutes();
    if (!ctx.mounted) return;
    if (minutes == null) return;

    await _app.setSleepTimerMinutes(minutes);
    if (!ctx.mounted) return;
    if (minutes <= 0) {
      GlassSnackbar.show(
        'settings.sleepTimer.title'.tr,
        'settings.sleepTimer.cleared'.tr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } else {
      GlassSnackbar.show(
        'settings.sleepTimer.title'.tr,
        'settings.sleepTimer.set'.trParams({'n': '$minutes'}),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> confirmClearAllSettings() async {
    final ctx = Get.context;
    if (ctx == null) return;

    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text('settings.dialog.clearTitle'.tr),
        content: Text('settings.dialog.clearBody'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('common.cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('common.delete'.tr),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _repo.clearSavedSource();
      _cache.clear();
      if (Get.isRegistered<IptvLogoCacheService>()) {
        unawaited(Get.find<IptvLogoCacheService>().wipeDisk());
      }
      _fav.clearAll();
      await _app.resetToDefaults();
      Get.updateLocale(
        materialLocaleFromLanguageCode(_app.languageCode.value),
      );
      Get.offAllNamed(AppRoutes.playlist);
      SchedulerBinding.instance.addPostFrameCallback((_) {
        GlassSnackbar.show(
          'settings.snackbar.settings'.tr,
          'settings.snackbar.cleared'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      });
    } catch (e) {
      GlassSnackbar.show(
        'settings.snackbar.settings'.tr,
        'settings.snackbar.clearFailed'.trParams({'e': '$e'}),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> showLanguageDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    await showDialog<void>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text('settings.dialog.languageTitle'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => GlassListTile(
                title: Text('common.lang.tr'.tr),
                trailing: _app.languageCode.value == 'tr'
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.languageCode.value == 'tr',
                onTap: () async {
                  await _app.setLanguageCode('tr');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title: Text('common.lang.en'.tr),
                trailing: _app.languageCode.value == 'en'
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.languageCode.value == 'en',
                onTap: () async {
                  await _app.setLanguageCode('en');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title: Text('common.lang.fr'.tr),
                trailing: _app.languageCode.value == 'fr'
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.languageCode.value == 'fr',
                onTap: () async {
                  await _app.setLanguageCode('fr');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title: Text('common.lang.ar'.tr),
                trailing: _app.languageCode.value == 'ar'
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.languageCode.value == 'ar',
                onTap: () async {
                  await _app.setLanguageCode('ar');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title: Text('common.lang.zh'.tr),
                trailing: _app.languageCode.value == 'zh'
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.languageCode.value == 'zh',
                onTap: () async {
                  await _app.setLanguageCode('zh');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title: Text('common.lang.ru'.tr),
                trailing: _app.languageCode.value == 'ru'
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.languageCode.value == 'ru',
                onTap: () async {
                  await _app.setLanguageCode('ru');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title: Text('common.lang.ja'.tr),
                trailing: _app.languageCode.value == 'ja'
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.languageCode.value == 'ja',
                onTap: () async {
                  await _app.setLanguageCode('ja');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title: Text('common.lang.es'.tr),
                trailing: _app.languageCode.value == 'es'
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.languageCode.value == 'es',
                onTap: () async {
                  await _app.setLanguageCode('es');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showLayoutModeDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    await showDialog<void>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text('settings.dialog.layoutTitle'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => GlassListTile(
                title: Text('settings.phone'.tr),
                subtitle: Text('layout.dialog.phone.sub'.tr),
                trailing: _app.layoutMode.value == AppLayoutMode.mobile
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.layoutMode.value == AppLayoutMode.mobile,
                onTap: () async {
                  await _app.setLayoutMode(AppLayoutMode.mobile);
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title: Text('settings.tv'.tr),
                subtitle: Text('layout.dialog.tv.sub'.tr),
                trailing: _app.layoutMode.value == AppLayoutMode.tv
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.layoutMode.value == AppLayoutMode.tv,
                onTap: () async {
                  await _app.setLayoutMode(AppLayoutMode.tv);
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showThemeDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    await showDialog<void>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text('settings.dialog.themeTitle'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => GlassListTile(
                title: Text(
                    localizedThemeStorageLabel(GlassThemeLabels.varsayilan)),
                trailing: _app.themeLabel.value == GlassThemeLabels.varsayilan
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.themeLabel.value == GlassThemeLabels.varsayilan,
                onTap: () async {
                  await _app.setThemeLabel(GlassThemeLabels.varsayilan);
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title: Text(localizedThemeStorageLabel('Koyu Cam')),
                trailing: _app.themeLabel.value == 'Koyu Cam'
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.themeLabel.value == 'Koyu Cam',
                onTap: () async {
                  await _app.setThemeLabel('Koyu Cam');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title: Text(
                    localizedThemeStorageLabel(GlassThemeLabels.glassmorphism)),
                trailing:
                    _app.themeLabel.value == GlassThemeLabels.glassmorphism
                        ? const Icon(Icons.check_rounded, color: Colors.white)
                        : null,
                selected:
                    _app.themeLabel.value == GlassThemeLabels.glassmorphism,
                onTap: () async {
                  await _app.setThemeLabel(GlassThemeLabels.glassmorphism);
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title:
                    Text(localizedThemeStorageLabel(GlassThemeLabels.darkFlat)),
                trailing: _app.themeLabel.value == GlassThemeLabels.darkFlat
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.themeLabel.value == GlassThemeLabels.darkFlat,
                onTap: () async {
                  await _app.setThemeLabel(GlassThemeLabels.darkFlat);
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title: Text(
                    localizedThemeStorageLabel(GlassThemeLabels.flatBlack)),
                trailing: _app.themeLabel.value == GlassThemeLabels.flatBlack
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.themeLabel.value == GlassThemeLabels.flatBlack,
                onTap: () async {
                  await _app.setThemeLabel(GlassThemeLabels.flatBlack);
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => GlassListTile(
                title: Text(
                  localizedThemeStorageLabel(GlassThemeLabels.glassGri),
                ),
                trailing: _app.themeLabel.value == GlassThemeLabels.glassGri
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
                selected: _app.themeLabel.value == GlassThemeLabels.glassGri,
                onTap: () async {
                  await _app.setThemeLabel(GlassThemeLabels.glassGri);
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showXmltvDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    final ctrl = TextEditingController(text: _app.xmltvUrl.value);

    await showDialog<void>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text('settings.dialog.xmltvTitle'.tr),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: 'settings.dialog.xmltv.hint'.tr,
            labelText: 'settings.dialog.xmltv.label'.tr,
          ),
          keyboardType: TextInputType.url,
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('common.cancel'.tr),
          ),
          TextButton(
            onPressed: () async {
              await _app.setXmltvUrl('');
              Get.find<EpgService>().clear();
              if (c.mounted) Navigator.pop(c);
            },
            child: Text('common.clear'.tr),
          ),
          FilledButton(
            onPressed: () async {
              final u = ctrl.text.trim();
              await _app.setXmltvUrl(u);
              final epg = Get.find<EpgService>();
              if (u.isEmpty) {
                epg.clear();
              } else {
                await epg.loadEpg(u);
                final src = await _repo.readSource();
                final cacheKey = src != null
                    ? EpgSnapshotKeys.logicalKeyFor(src, _app)
                    : null;
                if (cacheKey != null) {
                  await epg.persistSnapshotToDisk(cacheKey);
                }
              }
              if (c.mounted) Navigator.pop(c);
            },
            child: Text('common.save'.tr),
          ),
        ],
      ),
    );

    ctrl.dispose();
  }

  Future<void> showAdaptiveQualityCeilingDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    await showDialog<void>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text('settings.dialog.adaptiveQualityTitle'.tr),
        content: Obx(
          () => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final opt in AdaptiveStreamQualityCeiling.values)
                  GlassListTile(
                    title: Text(_adaptiveQualityOptionLabel(opt)),
                    trailing: _app.adaptiveStreamQualityCeiling.value == opt
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                          )
                        : null,
                    selected: _app.adaptiveStreamQualityCeiling.value == opt,
                    onTap: () async {
                      await _app.setAdaptiveStreamQualityCeiling(opt);
                      if (c.mounted) Navigator.pop(c);
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('common.close'.tr),
          ),
        ],
      ),
    );
  }

  String _adaptiveQualityOptionLabel(AdaptiveStreamQualityCeiling v) {
    switch (v) {
      case AdaptiveStreamQualityCeiling.auto:
        return 'settings.adaptiveQuality.optionAuto'.tr;
      case AdaptiveStreamQualityCeiling.p720:
        return 'settings.adaptiveQuality.option720'.tr;
      case AdaptiveStreamQualityCeiling.p1080:
        return 'settings.adaptiveQuality.option1080'.tr;
      case AdaptiveStreamQualityCeiling.p4k:
        return 'settings.adaptiveQuality.option4k'.tr;
    }
  }

  Future<void> showCatchUpUrlTemplateDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    final customCtrl =
        TextEditingController(text: _app.catchUpCustomTemplate.value);
    var local = _app.catchUpUrlPreset.value;

    await showDialog<void>(
      context: ctx,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => GlassAlertDialog(
          title: Text('settings.dialog.catchUpTitle'.tr),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final opt in CatchUpUrlPreset.values)
                  GlassListTile(
                    title: Text(_catchUpPresetLabel(opt)),
                    trailing: local == opt
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                          )
                        : null,
                    selected: local == opt,
                    onTap: () => setDialogState(() => local = opt),
                  ),
                if (local == CatchUpUrlPreset.custom) ...[
                  const SizedBox(height: 8),
                  Text(
                    'settings.catchUp.customLabel'.tr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: customCtrl,
                    maxLines: 4,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      hintText: 'settings.catchUp.customHint'.tr,
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'settings.catchUp.help'.tr,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('common.cancel'.tr),
            ),
            FilledButton(
              onPressed: () async {
                await _app.setCatchUpUrlPreset(local);
                await _app.setCatchUpCustomTemplate(customCtrl.text);
                if (c.mounted) Navigator.pop(c);
              },
              child: Text('common.save'.tr),
            ),
          ],
        ),
      ),
    );

    customCtrl.dispose();
  }

  String _catchUpPresetLabel(CatchUpUrlPreset v) {
    switch (v) {
      case CatchUpUrlPreset.off:
        return 'settings.catchUp.optionOff'.tr;
      case CatchUpUrlPreset.xtreamTimeshiftPath:
        return 'settings.catchUp.optionXtreamPath'.tr;
      case CatchUpUrlPreset.timeshiftPhpQuery:
        return 'settings.catchUp.optionTimeshiftPhp'.tr;
      case CatchUpUrlPreset.custom:
        return 'settings.catchUp.optionCustom'.tr;
    }
  }

  Future<void> showLiveBufferDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) {
        var local = _app.liveBufferSeconds.value.clamp(0, 30);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return GlassAlertDialog(
              scrollable: false,
              tvOsdStyle: remoteNav,
              title: Text('settings.dialog.bufferTitle'.tr),
              content: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'settings.dialog.bufferSlider'.trParams({'n': '$local'}),
                    ),
                    const SizedBox(height: 8),
                    if (remoteNav) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(1),
                            child: IconButton.filledTonal(
                              autofocus: true,
                              icon: const Icon(Icons.remove_rounded),
                              onPressed: local > 0
                                  ? () => setDialogState(() {
                                        local = (local - 1).clamp(0, 30);
                                      })
                                  : null,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            child: Text(
                              '$local',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(2),
                            child: IconButton.filledTonal(
                              icon: const Icon(Icons.add_rounded),
                              onPressed: local < 30
                                  ? () => setDialogState(() {
                                        local = (local + 1).clamp(0, 30);
                                      })
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ] else
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: Slider(
                          autofocus: true,
                          min: 0,
                          max: 30,
                          divisions: 30,
                          value: local.clamp(0, 30).toDouble(),
                          onChanged: (nv) {
                            setDialogState(() {
                              local = nv.round().clamp(0, 30);
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('common.cancel'.tr),
                ),
                FilledButton(
                  onPressed: () async {
                    await _app.setLiveBufferSeconds(local);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text('common.save'.tr),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> showSubtitleOptionsDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) => SubtitleFontPickerDialog(
        initialPt: _app.subtitleFontPt.value,
        tvRemote: _app.layoutMode.value.usesRemoteNavigationStyle,
        tvOsdStyle: _app.layoutMode.value == AppLayoutMode.tv,
        onCancel: () => Navigator.of(dialogContext).pop(),
        onSave: (pt) async {
          await _app.setSubtitleFontPt(pt);
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        },
      ),
    );
  }

  void showAboutApp() {
    final ctx = Get.context;
    if (ctx == null) return;

    showDialog<void>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text('settings.snackbar.aboutTitle'.tr),
        content: SingleChildScrollView(
          child: Obx(() {
            final v = packageVersionLabel.value;
            final head = v.isEmpty ? 'Mina IPTV Player' : 'Mina IPTV Player $v';
            return Text(
              '$head\n\n${'settings.dialog.aboutFeatures'.tr}',
              style: TextStyle(
                color: Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.9),
                height: 1.45,
              ),
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              showChangelog();
            },
            child: Text('settings.dialog.changelogTitle'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: Text('common.close'.tr),
          ),
        ],
      ),
    );
  }

  void showChangelog() {
    final ctx = Get.context;
    if (ctx == null) return;

    showDialog<void>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text('settings.dialog.changelogTitle'.tr),
        content: SingleChildScrollView(
          child: Text(
            'settings.dialog.changelogBody'.tr,
            style: TextStyle(
              color: Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.9),
              height: 1.45,
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: Text('common.close'.tr),
          ),
        ],
      ),
    );
  }

  void showDeveloper() {
    final ctx = Get.context;
    if (ctx == null) return;

    showDialog<void>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text('settings.dialog.developerTitle'.tr),
        content: Text(
          'settings.dialog.developerBody'.tr,
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: Text('common.ok'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> reportIssue() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'furkangumrukcu@gmail.com',
      queryParameters: {
        'subject': 'settings.mail.subject'.tr,
        'body': 'settings.mail.body'.tr,
      },
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
      if (!launched) {
        GlassSnackbar.show(
          'settings.snackbar.report'.tr,
          'settings.snackbar.reportFail'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (_) {
      GlassSnackbar.show(
        'settings.snackbar.report'.tr,
        'settings.snackbar.reportManual'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Mağaza / kullanıcı bilgilendirmesi için GitHub deposu (gizlilik metni repo kökünde).
  static const String kPrivacyPolicyUrl =
      'https://github.com/furkangumrukcu07/mina_iptv_player';

  Future<void> openPrivacyPolicy() async {
    final uri = Uri.parse(kPrivacyPolicyUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
      if (!launched) {
        GlassSnackbar.show(
          'settings.snackbar.privacy'.tr,
          'settings.snackbar.privacyFail'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (_) {
      GlassSnackbar.show(
        'settings.snackbar.privacy'.tr,
        'settings.snackbar.privacyManual'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Alarm subtitle for settings
  String get alarmSubtitle => 'settings.tile.alarm.sub'.tr;

  /// Show alarm dialog
  void showAlarmDialog() {
    final ctx = Get.context;
    if (ctx == null) return;

    showDialog<void>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text('settings.tile.alarm'.tr),
        content: Text('Alarm ayarleri'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            child: Text('common.close'.tr),
          ),
        ],
      ),
    );
  }
}
