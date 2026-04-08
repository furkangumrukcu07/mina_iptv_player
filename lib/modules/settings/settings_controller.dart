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
import '../../core/services/epg_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/theme/glass_appearance.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../browse/browse_controller.dart';
import '../channels/channels_controller.dart';
import '../../ui/glass_overlays.dart';

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
      packageVersionLabel.value =
          '${info.version} (${info.buildNumber})';
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
            ListTile(
              title: Text('settings.dialog.refresh.autoOff'.tr),
              trailing: _app.autoRefreshDays.value == 0
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(Get.context!, 0),
            ),
            ListTile(
              title: Text('settings.dialog.refresh.every3'.tr),
              trailing: _app.autoRefreshDays.value == 3
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(Get.context!, 3),
            ),
            ListTile(
              title: Text('settings.dialog.refresh.every7'.tr),
              trailing: _app.autoRefreshDays.value == 7
                  ? const Icon(Icons.check_rounded)
                  : null,
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
      _cache.setPlaylist(value: parsed, url: label);
      await _app.updateLastRefreshTime();
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

  Future<void> showAlarmDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    final action = await showDialog<String>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text('settings.dialog.alarmTitle'.tr),
        content: Text('settings.dialog.alarmBody'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'cancel'),
            child: Text('common.cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'clear'),
            child: Text('settings.dialog.alarmRemove'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'pick'),
            child: Text('settings.dialog.alarmPick'.tr),
          ),
        ],
      ),
    );

    if (action == 'clear') {
      await clearAlarm();
      return;
    }
    if (action != 'pick') return;

    final pickerCtx = Get.context;
    if (pickerCtx == null || !pickerCtx.mounted) return;

    final initial = TimeOfDay(
      hour: _app.alarmHour.value ?? 7,
      minute: _app.alarmMinute.value ?? 0,
    );

    final picked = await showTimePicker(
      context: pickerCtx,
      initialTime: initial,
      builder: (c, child) {
        return Theme(
          data: Theme.of(c).copyWith(
            colorScheme: Theme.of(c).colorScheme.copyWith(
                  primary: const Color(0xFF5DD9E8),
                ),
          ),
          child: GlassPopupPanel(
            padding: EdgeInsets.zero,
            borderRadius: 28,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );

    if (picked != null) {
      await _app.setAlarm(hour: picked.hour, minute: picked.minute);
      if (pickerCtx.mounted) {
        GlassSnackbar.show(
          'settings.snackbar.alarm'.tr,
          'settings.snackbar.alarmSaved'.tr,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  Future<void> clearAlarm() async {
    await _app.clearAlarm();
    GlassSnackbar.show(
      'settings.snackbar.alarm'.tr,
      'settings.snackbar.alarmCleared'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
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
                          ListTile(
                            dense: true,
                            title: Text('settings.sleepTimer.off'.tr),
                            trailing: _app.sleepTimerEndMs.value == null
                                ? const Icon(Icons.check_rounded)
                                : null,
                            onTap: () => Navigator.pop(c, 0),
                          ),
                          for (final m in [15, 30, 45, 60, 90, 120])
                            ListTile(
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
              () => ListTile(
                title: Text('common.lang.tr'.tr),
                trailing: _app.languageCode.value == 'tr'
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setLanguageCode('tr');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => ListTile(
                title: Text('common.lang.en'.tr),
                trailing: _app.languageCode.value == 'en'
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setLanguageCode('en');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => ListTile(
                title: Text('common.lang.fr'.tr),
                trailing: _app.languageCode.value == 'fr'
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setLanguageCode('fr');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => ListTile(
                title: Text('common.lang.ar'.tr),
                trailing: _app.languageCode.value == 'ar'
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setLanguageCode('ar');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => ListTile(
                title: Text('common.lang.zh'.tr),
                trailing: _app.languageCode.value == 'zh'
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setLanguageCode('zh');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => ListTile(
                title: Text('common.lang.ru'.tr),
                trailing: _app.languageCode.value == 'ru'
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setLanguageCode('ru');
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
              () => ListTile(
                title: Text('settings.phone'.tr),
                subtitle: Text('layout.dialog.phone.sub'.tr),
                trailing: _app.layoutMode.value == AppLayoutMode.mobile
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setLayoutMode(AppLayoutMode.mobile);
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => ListTile(
                title: Text('settings.tv'.tr),
                subtitle: Text('layout.dialog.tv.sub'.tr),
                trailing: _app.layoutMode.value == AppLayoutMode.tv
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
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
              () => ListTile(
                title: Text(
                    localizedThemeStorageLabel(GlassThemeLabels.varsayilan)),
                trailing: _app.themeLabel.value == GlassThemeLabels.varsayilan
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setThemeLabel(GlassThemeLabels.varsayilan);
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => ListTile(
                title: Text(localizedThemeStorageLabel('Mavi Cam')),
                trailing: _app.themeLabel.value == 'Mavi Cam'
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setThemeLabel('Mavi Cam');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => ListTile(
                title: Text(localizedThemeStorageLabel('Yeşil Cam')),
                trailing: _app.themeLabel.value == 'Yeşil Cam'
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setThemeLabel('Yeşil Cam');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => ListTile(
                title: Text(localizedThemeStorageLabel('Kırmızı Cam')),
                trailing: _app.themeLabel.value == 'Kırmızı Cam'
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setThemeLabel('Kırmızı Cam');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => ListTile(
                title: Text(localizedThemeStorageLabel('Mor Cam')),
                trailing: _app.themeLabel.value == 'Mor Cam'
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setThemeLabel('Mor Cam');
                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ),
            Obx(
              () => ListTile(
                title: Text(localizedThemeStorageLabel('Koyu Cam')),
                trailing: _app.themeLabel.value == 'Koyu Cam'
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(c).colorScheme.primary)
                    : null,
                onTap: () async {
                  await _app.setThemeLabel('Koyu Cam');
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
              if (u.isEmpty) {
                Get.find<EpgService>().clear();
              } else {
                unawaited(Get.find<EpgService>().loadEpg(u));
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

  Future<void> showLiveBufferDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) {
        var local = _app.liveBufferSeconds.value.clamp(0, 30);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return GlassAlertDialog(
              scrollable: false,
              title: Text('settings.dialog.bufferTitle'.tr),
              content: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'settings.dialog.bufferSlider'
                          .trParams({'n': '$local'}),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(2),
                          child: TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(),
                            child: Text('common.cancel'.tr),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FocusTraversalOrder(
                          order: const NumericFocusOrder(3),
                          child: FilledButton(
                            onPressed: () async {
                              await _app.setLiveBufferSeconds(local);
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            },
                            child: Text('common.save'.tr),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> showSubtitleSettingsInfo() async {
    GlassSnackbar.show(
      'settings.snackbar.subtitles'.tr,
      'settings.snackbar.subtitlesSoon'.tr,
      snackPosition: SnackPosition.BOTTOM,
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
            final head = v.isEmpty
                ? 'Mina IPTV Player'
                : 'Mina IPTV Player $v';
            return Text(
              '$head\n\n${'settings.dialog.aboutFeatures'.tr}',
              style: TextStyle(
                color:
                    Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.9),
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
}
