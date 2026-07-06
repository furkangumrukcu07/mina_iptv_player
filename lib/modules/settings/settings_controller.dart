import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error/app_exception.dart';
import '../../core/i18n/app_locale.dart';
import '../../core/i18n/theme_label_localized.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/active_playlist_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/services/mina_stream_cutter_service.dart';
import '../../core/services/search_history_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/licensing_service.dart';
import '../../ui/glass_overlays.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/services/equalizer_service.dart';
import '../../core/services/crash_reporting.dart';
import '../../core/services/support_diagnostics.dart';
import '../../core/player/adaptive_stream_quality_ceiling.dart';
import '../../core/player/playback_user_agent.dart';
import '../../core/epg/catch_up_url_template.dart';
import '../../core/epg/global_epg_service.dart';
import '../../data/local/epg_snapshot_keys.dart';
import '../../data/remote/xtream_api.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/iptv_logo_cache_service.dart';
import '../../core/services/mina_telemetry_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/watch_progress_service.dart';
import '../../services/user_history_service.dart';
import '../home/widgets/ai_recommendations_strip.dart';
import '../../core/layout/app_layout_mode.dart';
import '../../core/player/subtitle_font_family.dart';
import '../../core/theme/glass_appearance.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../channels/channels_controller.dart';
import '../../ui/glass_overlays.dart';
import 'equalizer_dialog.dart' as eq_dialog;
import 'subtitle_font_picker_dialog.dart';
import 'subtitle_font_family_picker_dialog.dart';
import 'xtream_account_info_body.dart';

/// "Tüm ayarları sil" menüsündeki sıfırlama seçenekleri.
enum _ResetChoice { watchHistory, ai, playlist, everything }

class SettingsController extends GetxController {
  final _repo = Get.find<PlaylistRepository>();
  final _cache = Get.find<PlaylistCacheService>();
  final _fav = Get.find<FavoritesService>();
  final _app = Get.find<AppSettingsService>();
  final _backup = Get.find<BackupService>();

  AuthService? get _auth =>
      Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null;

  /// Bulut (Google) senkronu kullanılabilir mi? (Firebase yapılandırılmış)
  bool get isCloudAvailable => _auth?.isAvailable ?? false;

  /// Yedek paylaşımı / geri yüklemesi sırasında butonları kilitle.
  final isBackupBusy = false.obs;

  /// Google bulut yedekleme / geri yükleme sırasında butonları kilitle.
  final isCloudBusy = false.obs;

  /// Buluttaki son yedeğin özeti (boyut + içerik). Yüklenene kadar null.
  final cloudBackupInfo = Rxn<CloudBackupInfo>();

  /// Yedek özeti çekilirken yükleme göstergesi.
  final isCloudInfoLoading = false.obs;

  /// Buluttaki son yedeğin özetini çeker ve [cloudBackupInfo]'yu günceller.
  /// Oturum kapalı / bulut yoksa null bırakır. Panel açılışında ve yedek/geri
  /// yükleme sonrasında çağrılır.
  Future<void> refreshCloudBackupInfo() async {
    final auth = _auth;
    if (auth == null || !auth.isAvailable || !auth.isSignedIn) {
      cloudBackupInfo.value = null;
      return;
    }
    isCloudInfoLoading.value = true;
    try {
      cloudBackupInfo.value = await auth
          .fetchCloudBackupInfo()
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
    } catch (_) {
      // Sessizce geç — panel "henüz yedek yok" durumunu gösterir.
    } finally {
      isCloudInfoLoading.value = false;
    }
  }

  final now = DateTime.now().obs;
  Timer? _clock;
  final isRefreshing = false.obs;
  final isFetchingInfo = false.obs;
  final isXtream = false.obs;

  /// M3U veya Xtream — herhangi bir kaynak yüklendiğinde true. Parental
  /// Control gibi yalnızca içerik yüklendikten sonra anlamlı olan ayarları
  /// koşullu göstermek için kullanılır.
  final hasAnySource = false.obs;

  /// Ayarlar altı: Xtream kullanıcı + sunucu (şifre yok).
  final xtreamFooterLine = ''.obs;

  /// Boş: henüz yüklenmedi. Örn. `1.1.0 (2014)`.
  final packageVersionLabel = ''.obs;

  /// «Hakkında» diyalogu: Play Store güncelleme denetimi sürüyor mu?
  final isCheckingUpdate = false.obs;

  AppSettingsService get app => _app;

  Future<void> toggleStreamPreviewEnabled() async {
    final next = !_app.streamPreviewEnabled.value;
    await _app.setStreamPreviewEnabled(next);
    if (!next) {
      if (Get.isRegistered<ChannelsController>()) {
        Get.find<ChannelsController>().clearStreamPreview();
      }
    } else {
      if (Get.isRegistered<ChannelsController>()) {
        Get.find<ChannelsController>().refreshStreamPreviewFromSettings();
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
    hasAnySource.value = s != null;
    if (s is XtreamSource) {
      final host = _shortHost(s.baseUrl);
      xtreamFooterLine.value = 'settings.xtreamFooter.line'.trParams({
        'user': s.username,
        'host': host,
      });
    } else {
      xtreamFooterLine.value = '';
    }
  }

  String _shortHost(String raw) {
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
        final mode = _app.xtreamEpgSourceMode.value;
        final allowXtream = mode != XtreamEpgSourceMode.githubOnly;
        final allowGithub = mode != XtreamEpgSourceMode.xtreamOnly;

        if (allowXtream) {
          final api = XtreamApi(
            baseUrl: source.baseUrl,
            username: source.username,
            password: source.password,
          );
          try {
            await epg.loadXtreamAllLiveEpg(api);
          } catch (e) {
            debugPrint('mina_iptv: Xtream EPG (refresh) fatal: $e');
          }
        }
        // Auto'da Xtream başarılı olsa bile GitHub yedek paralel; mode != xtreamOnly.
        if (allowGithub && Get.isRegistered<GlobalEpgService>()) {
          final pl = Get.find<PlaylistCacheService>().result.value;
          if (pl != null) {
            try {
              await Get.find<GlobalEpgService>()
                  .loadGlobalEpgForChannels(pl.channels);
            } catch (e) {
              debugPrint('mina_iptv: Global EPG fallback (refresh) failed: $e');
            }
          }
        }
      } else if (source is M3uSource) {
        final urls = _app.m3uEpgFetchUrls;
        if (urls.isNotEmpty) {
          await epg.loadEpgFirstSuccessful(urls);
          if (epg.hasLoadedGuideData()) {
            await _app.markM3uEpgFetchedOk();
          }
        }
      }
      final cacheKey = EpgSnapshotKeys.logicalKeyFor(source, _app);
      if (cacheKey != null) {
        await epg.persistSnapshotToDisk(cacheKey);
      }
      final pl = Get.find<PlaylistCacheService>().result.value;
      if (pl != null && source is M3uSource) {
        await epg.applyM3uXmltvChannelMappings(
          cacheKey: cacheKey,
          liveChannels: pl.channels,
        );
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

    // İçerik otomatik yenileme aralığı seçenekleri (**saat** cinsinden):
    // 0 = Kapalı, 2 = 2 saat, 24 = 1 gün, 48 = 2 gün, 72 = 3 gün, 168 = 1 hafta.
    // «-1» dönüşü: yalnızca şimdi yenile (aralık değişmeden).
    final options = <int, String>{
      2: 'settings.dialog.refresh.every2h'.tr,
      24: 'settings.dialog.refresh.every1d'.tr,
      48: 'settings.dialog.refresh.every2d'.tr,
      72: 'settings.dialog.refresh.every3d'.tr,
      168: 'settings.dialog.refresh.every1w'.tr,
      0: 'settings.dialog.refresh.autoOff'.tr,
    };
    final hours = await Get.dialog<int>(
      GlassAlertDialog(
        title: Text('settings.dialog.refreshTitle'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('settings.dialog.refreshBody'.tr),
            const SizedBox(height: 16),
            GlassDialogListPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in options.entries)
                    GlassListTile(
                      title: Text(entry.value),
                      trailing: _app.autoRefreshHours.value == entry.key
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : null,
                      selected: _app.autoRefreshHours.value == entry.key,
                      onTap: () => Navigator.pop(Get.context!, entry.key),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          GlassDialogActionButton(
            label: 'common.cancel'.tr,
            onPressed: () => Navigator.pop(Get.context!),
          ),
          GlassDialogActionButton(
            label: 'settings.dialog.refresh.nowOnly'.tr,
            primary: true,
            onPressed: () => Navigator.pop(Get.context!, -1),
          ),
        ],
      ),
    );

    if (hours == null) return;
    if (hours >= 0) {
      await _app.setAutoRefreshHours(hours);
    }

    isRefreshing.value = true;
    try {
      // Birleştirme YOK: yalnızca aktif slot'u ağdan yeniden indir.
      final active = Get.find<ActivePlaylistService>();
      active.invalidate(active.activeSlot.value);
      final parsed = await active.loadActiveIntoCache(preferSnapshot: false);
      if (parsed == null) {
        GlassSnackbar.show(
          'settings.snackbar.content'.tr,
          'settings.snackbar.noPlaylist'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final activeSource =
          await _repo.readSourceAt(active.activeSlot.value) ?? source;
      await _app.updateLastRefreshTime();
      unawaited(_reloadEpgAfterPlaylist(activeSource));
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

  void openChannelListEditor() {
    Get.toNamed(AppRoutes.channelListEditor);
  }

  void openHomeCardOrderEditor() {
    Get.toNamed(AppRoutes.homeCardOrderEditor);
  }

  /// Ana Ekran Ayarları — kart sırası + karışık canlı TV + sıradaki maçlar
  /// + yüksek puanlı filmler tek alt-sayfada.
  void openHomeSettings() {
    Get.toNamed(AppRoutes.homeSettings);
  }

  /// Yedekleme / Geri Yükleme alt-sayfası — `mina_backup.dat` paylaşımı ve
  /// dosyadan geri yükleme aksiyonları tek ekranda.
  void openBackupRestore() {
    Get.toNamed(AppRoutes.backupRestore);
  }

  /// Daha seyrek kullanılan yardımcı araçlar (uyku zamanlayıcısı, EPG, tema,
  /// yedekleme/geri yükleme, hız testi, adaptif titreşim, uygulama fontu).
  void openOtherTools() {
    Get.toNamed(AppRoutes.otherTools);
  }

  /// «Bize Ulaşın» alt-sayfası — Telegram kanalı + sorun bildir (mail).
  void openContactUs() {
    Get.toNamed(AppRoutes.contactUs);
  }

  void openFaq() {
    Get.toNamed(AppRoutes.faq);
  }

  /// «Admine Mesaj Gönder» — uygulama içi sohbetteki yönetici (destek) bölümüne
  /// doğrudan yönlendirir. Oturum açılmamışsa sohbet listesindeki giriş kapısına
  /// düşer; admin kullanıcı için gelen kutusu, normal kullanıcı için kendi
  /// birebir admin konuşması açılır.
  void openAdminMessage() {
    if (!Get.isRegistered<ChatService>()) {
      Get.lazyPut<ChatService>(() => ChatService(), fenix: true);
    }
    final chat = Get.find<ChatService>();
    if (!chat.isReady) {
      Get.toNamed<void>(AppRoutes.chat);
      return;
    }
    if (chat.isCurrentUserAdmin) {
      Get.toNamed<void>(AppRoutes.chatSupportInbox);
      return;
    }
    final uid = chat.currentUserId;
    if (uid == null) {
      Get.toNamed<void>(AppRoutes.chat);
      return;
    }
    Get.toNamed<void>(
      AppRoutes.chatRoom,
      arguments: ChatSupportTarget(
        threadUid: uid,
        title: 'chat.support.adminName'.tr,
      ),
    );
  }

  /// Kurulum sihirbazını yeniden başlat. Tek sihirbaz (mobil tasarım) hem
  /// dokunmatik hem TV/kumanda için kullanılır. Sihirbaz bittiğinde kurulum
  /// yeniden tamamlandı olarak işaretlenip ana ekrana döner; geri tuşuyla
  /// ayarlara dönülebilir.
  void restartSetupWizard() {
    Get.toNamed(AppRoutes.setupWizard);
  }

  /// Resmi Telegram kanalı / destek grubu.
  static const String kTelegramUrl = 'https://t.me/minaiptvplayerpro';

  Future<void> openTelegram() async {
    try {
      await launchUrl(
        Uri.parse(kTelegramUrl),
        mode: LaunchMode.platformDefault,
      );
    } catch (_) {}
  }

  /// Google bulut senkronu durumu ve hızlı işlemler.
  void openCloudSync() {
    Get.toNamed(AppRoutes.cloudSync);
  }

  /// Netflix tarzı çoklu profil yönetimi.
  void openProfiles() {
    Get.toNamed(AppRoutes.profiles);
  }

  /// Veri Kullanım Detayı sayfası — uygulamanın bu cihazda
  /// kullandığı toplam mobil + wifi internet trafiği.
  void openDataUsage() {
    Get.toNamed(AppRoutes.dataUsage);
  }

  void openDownloads() {
    Get.toNamed(AppRoutes.downloads);
  }

  /// Kanal Kategori Düzeni alt-sayfası — kategori gizleme + canlı kanal
  /// listesi düzenleyici tek noktada.
  void openChannelCategoryLayout() {
    Get.toNamed(AppRoutes.channelCategoryLayout);
  }

  /// Oynatma Ayarları alt-sayfası — oynatıcı motoru, donanım kod çözücü,
  /// yazılım fallback ve canlı buffer süresi.
  void openPlaybackSettings() {
    Get.toNamed(AppRoutes.playbackSettings);
  }

  void openTvKeyMapping() {
    Get.toNamed(AppRoutes.tvKeyMapping);
  }

  void openSubtitleOptions() {
    Get.toNamed(AppRoutes.subtitleOptions);
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
      // Yeni: user_info + server_info birlikte (bağlantı portları, saat dilimi,
      // sunucu saati, izinli formatlar vs.).
      final snap = await _repo.getXtreamAccountSnapshot(
        baseUrl: source.baseUrl,
        username: source.username,
        password: source.password,
      );

      if (snap == null || (snap.user == null && snap.server == null)) {
        GlassSnackbar.show(
          'settings.snackbar.error'.tr,
          'settings.snackbar.xtreamFail'.tr,
        );
        return;
      }

      await Get.dialog(
        GlassAlertDialog(
          title: Text('settings.dialog.xtreamTitle'.tr),
          // Kaydırma yalnızca GlassAlertDialog içindeki ListView'da;
          // ek SingleChildScrollView iç içe scroll çakışması yapıp
          // aşağı çekince yukarı sıçratıyordu.
          content: XtreamAccountInfoBody(
            source: source,
            user: snap.user,
            server: snap.server,
          ),
          actions: [
            GlassDialogActionButton(
              label: 'common.close'.tr,
              onPressed: () => Navigator.pop(Get.context!),
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

  void setAutoRefreshHours(int hours) => _app.setAutoRefreshHours(hours);

  void goBack() => Get.back();

  Future<void> openPlaylistList() async {
    // Ayarlar > Playlist: slot tabanlı liste yöneticisine git. Eski
    // birincil/ikincil form, yeni bir M3U girildiğinde her zaman slot 1'i
    // ezdiği için (mevcut listeyi değiştiriyordu) buradan açılmıyor.
    // Yönetici, yeni listeyi bir sonraki boş slota ekler ve mevcut
    // listeleri korur; düzenleme/yenileme/silme de slot bazında yapılır.
    await Get.toNamed(AppRoutes.playlistsManager);
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
                      child: GlassDialogListPanel(
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
                  ),
                ],
              );
            },
          ),
          actions: [
            GlassDialogActionButton(
              label: 'common.cancel'.tr,
              onPressed: () => Navigator.pop(c),
            ),
          ],
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

  Future<void> showTvOsdAutoHideDurationDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;
    var pending = _app.tvOsdAutoHideDuration.value;

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => GlassAlertDialog(
          scrollable: remoteNav,
          tvOsdStyle: remoteNav,
          title: Text('settings.dialog.osdHideTitle'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'settings.dialog.osdHideBody'.tr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              GlassDialogListPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final sec
                        in AppSettingsService.tvOsdAutoHideSecondsOptions)
                      GlassListTile(
                        dense: true,
                        title: Text(
                          'settings.dialog.osdHideSeconds'
                              .trParams({'n': '$sec'}),
                        ),
                        selected: pending == sec,
                        trailing: pending == sec
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white)
                            : null,
                        onTap: () => setDialogState(() => pending = sec),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: glassDialogPickerActions(
            dialogContext,
            onDarkSurface: remoteNav,
            onCancel: () => Navigator.of(dialogContext).pop(),
            onApply: () async {
              await _app.setTvOsdAutoHideDuration(pending);
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> toggleStripLiveChannelPrefix() async {
    if (_app.stripLiveChannelCountryPrefix.value) {
      await _app.setStripLiveChannelCountryPrefix(false);
      GlassSnackbar.show(
        'settings.snackbar.info'.tr,
        'settings.snackbar.channelPrefixOff'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final ctx = Get.context;
    if (ctx == null) return;

    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text('settings.dialog.channelPrefixTitle'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('settings.dialog.channelPrefixBody'.tr),
            const SizedBox(height: 14),
            GlassDialogListPanel(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settings.dialog.channelPrefixExample'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TR: FX  →  FX',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'BR: Globo  →  Globo',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          GlassDialogActionButton(
            label: 'common.cancel'.tr,
            onPressed: () => Navigator.pop(c, false),
          ),
          GlassDialogActionButton(
            label: 'settings.dialog.channelPrefixConfirm'.tr,
            primary: true,
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await _app.setStripLiveChannelCountryPrefix(true);
    GlassSnackbar.show(
      'settings.snackbar.info'.tr,
      'settings.snackbar.channelPrefixOn'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Ayarlar diyalogları için güvenilir [BuildContext] — `Get.context` bazen
  /// modal kapandıktan sonra null/bağlantısız kalıyordu ve onay diyalogu açılmıyordu.
  BuildContext? _settingsDialogAnchor() {
    final navCtx = Get.key.currentState?.context;
    if (navCtx != null && navCtx.mounted) return navCtx;
    final ctx = Get.context;
    if (ctx != null && ctx.mounted) return ctx;
    return null;
  }

  /// "Tüm ayarları sil" tile'ı artık bir **sıfırlama seçenekleri** menüsü açar.
  /// Kullanıcı tek tek (son izlenenler / Mina AI önerileri / playlist) ya da en
  /// alttan "tümünü ve tüm verileri" sıfırlayabilir. Menü TV kumandasıyla da
  /// kullanılabilir (GlassListTile D-pad odaklanır).
  Future<void> confirmClearAllSettings() async {
    final anchor = _settingsDialogAnchor();
    if (anchor == null) return;
    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;

    final choice = await showDialog<_ResetChoice>(
      context: anchor,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (c) => GlassAlertDialog(
        tvOsdStyle: remoteNav,
        scrollable: true,
        title: Text('settings.reset.menuTitle'.tr),
        content: GlassDialogListPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassListTile(
                autofocus: true,
                leading: const Icon(Icons.history_rounded, color: Colors.white),
                title: Text('settings.reset.watchHistory'.tr),
                subtitle: Text(
                  'settings.reset.watchHistory.sub'.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(c, _ResetChoice.watchHistory),
              ),
              GlassListTile(
                leading:
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                title: Text('settings.reset.ai'.tr),
                subtitle: Text(
                  'settings.reset.ai.sub'.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(c, _ResetChoice.ai),
              ),
              GlassListTile(
                leading: const Icon(Icons.playlist_remove_rounded,
                    color: Colors.white),
                title: Text('settings.reset.playlist'.tr),
                subtitle: Text(
                  'settings.reset.playlist.sub'.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(c, _ResetChoice.playlist),
              ),
              GlassListTile(
                leading: const Icon(Icons.delete_forever_rounded,
                    color: Color(0xFFFFB74D)),
                title: Text('settings.reset.everything'.tr),
                subtitle: Text(
                  'settings.reset.everything.sub'.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(c, _ResetChoice.everything),
              ),
            ],
          ),
        ),
        actions: [
          GlassDialogActionButton(
            label: 'common.cancel'.tr,
            onDarkSurface: remoteNav,
            onPressed: () => Navigator.pop(c),
          ),
        ],
      ),
    );

    if (choice == null) return;
    final confirmAnchor = _settingsDialogAnchor();
    if (confirmAnchor == null || !confirmAnchor.mounted) return;
    switch (choice) {
      case _ResetChoice.watchHistory:
        await _resetWatchHistory(confirmAnchor);
      case _ResetChoice.ai:
        await _resetAiRecommendations(confirmAnchor);
      case _ResetChoice.playlist:
        await _resetPlaylistData(confirmAnchor);
      case _ResetChoice.everything:
        await _resetEverything(confirmAnchor);
    }
  }

  /// Tekil sıfırlama onayı — başlık seçilen seçeneğin etiketi, gövde ortak
  /// "geri alınamaz" uyarısı. Onaylanırsa `true`.
  Future<bool> _confirmReset(BuildContext anchor, String titleKey) async {
    if (!anchor.mounted) return false;
    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;
    final ok = await showDialog<bool>(
      context: anchor,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (c) => GlassAlertDialog(
        tvOsdStyle: remoteNav,
        title: Text(titleKey.tr),
        content: Text('settings.reset.confirmBody'.tr),
        actions: [
          GlassDialogActionButton(
            label: 'common.cancel'.tr,
            onDarkSurface: remoteNav,
            onPressed: () => Navigator.pop(c, false),
          ),
          GlassDialogActionButton(
            label: 'common.delete'.tr,
            primary: true,
            autofocus: true,
            onDarkSurface: remoteNav,
            onPressed: () => Navigator.pop(c, true),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _resetSnack(String messageKey) {
    GlassSnackbar.show(
      'settings.snackbar.settings'.tr,
      messageKey.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _clearWatchAndAiUserData() async {
    await Get.find<UserHistoryService>().clear();
    await Get.find<WatchProgressService>().clearAll();
    AiRecommendationsStrip.invalidateCache();
    if (Get.isRegistered<MinaStreamCutterService>()) {
      await Get.find<MinaStreamCutterService>().clearAll();
    }
  }

  Future<void> _clearSearchHistory() async {
    if (!Get.isRegistered<SearchHistoryService>()) return;
    final sh = Get.find<SearchHistoryService>();
    for (final scope in SearchHistoryScope.values) {
      await sh.clear(scope);
    }
  }

  /// Playlist silindikten sonra bellek içi önbellekleri de boşalt — aksi halde
  /// [ActivePlaylistService] eski [M3uResult]'ı geri yükleyebiliyordu.
  Future<void> _syncAfterPlaylistWipe() async {
    _cache.clear();
    if (Get.isRegistered<ActivePlaylistService>()) {
      final active = Get.find<ActivePlaylistService>();
      active.invalidateAll();
      await active.refreshAvailable();
    }
    if (Get.isRegistered<EpgService>()) {
      Get.find<EpgService>().clear();
    }
  }

  void _navigateToPlaylistSetupWithSnack(String messageKey) {
    Get.offAllNamed(AppRoutes.playlist);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _resetSnack(messageKey);
    });
  }

  /// Son izlenenler: izleme geçmişi + "devam et" listesi temizlenir. AI profili
  /// geçmişe dayalı olduğu için öneri önbelleği de geçersiz kılınır.
  Future<void> _resetWatchHistory(BuildContext anchor) async {
    if (!await _confirmReset(anchor, 'settings.reset.watchHistory')) return;
    try {
      await _clearWatchAndAiUserData();
      _resetSnack('settings.reset.watchHistoryDone');
    } catch (e, st) {
      debugPrint('SettingsController._resetWatchHistory failed: $e\n$st');
      _resetSnack('settings.snackbar.clearFailed');
    }
  }

  /// Mina AI önerileri: ayrı bir kalıcı depo yoktur (geçmişten türetilir);
  /// öneri önbelleği temizlenir, açık ana ekranda yeniden hesaplanır.
  Future<void> _resetAiRecommendations(BuildContext anchor) async {
    if (!await _confirmReset(anchor, 'settings.reset.ai')) return;
    AiRecommendationsStrip.invalidateCache();
    _resetSnack('settings.reset.aiDone');
  }

  /// Playlist bilgileri: kayıtlı kaynak + içerik önbelleği + logo önbelleği
  /// silinir. Kullanıcı liste ekleme ekranına yönlendirilir.
  Future<void> _resetPlaylistData(BuildContext anchor) async {
    if (!await _confirmReset(anchor, 'settings.reset.playlist')) return;
    try {
      await _repo.clearSavedSource();
      await _syncAfterPlaylistWipe();
      if (Get.isRegistered<IptvLogoCacheService>()) {
        await Get.find<IptvLogoCacheService>().wipeDisk();
      }
      _navigateToPlaylistSetupWithSnack('settings.reset.playlistDone');
    } catch (e, st) {
      debugPrint('SettingsController._resetPlaylistData failed: $e\n$st');
      _resetSnack('settings.snackbar.clearFailed');
    }
  }

  /// Tümünü sıfırla: playlist + önbellek + favoriler + tüm tercihler + geçmiş.
  Future<void> _resetEverything(BuildContext anchor) async {
    if (!await _confirmReset(anchor, 'settings.reset.everything')) return;
    try {
      await _repo.clearSavedSource();
      await _clearWatchAndAiUserData();
      await _clearSearchHistory();
      _fav.clearAll();
      await _syncAfterPlaylistWipe();
      if (Get.isRegistered<IptvLogoCacheService>()) {
        await Get.find<IptvLogoCacheService>().wipeDisk();
      }
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
    } catch (e, st) {
      debugPrint('SettingsController._resetEverything failed: $e\n$st');
      GlassSnackbar.show(
        'settings.snackbar.settings'.tr,
        'settings.snackbar.clearFailed'.trParams({'e': '$e'}),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  static const _languagePickerOptions = <(String code, String labelKey)>[
    ('tr', 'common.lang.tr'),
    ('en', 'common.lang.en'),
    ('fr', 'common.lang.fr'),
    ('ar', 'common.lang.ar'),
    ('zh', 'common.lang.zh'),
    ('ru', 'common.lang.ru'),
    ('ja', 'common.lang.ja'),
    ('es', 'common.lang.es'),
    ('ko', 'common.lang.ko'),
    ('he', 'common.lang.he'),
    ('da', 'common.lang.da'),
    ('sv', 'common.lang.sv'),
    ('hi', 'common.lang.hi'),
    ('th', 'common.lang.th'),
    ('it', 'common.lang.it'),
    ('pt', 'common.lang.pt'),
    ('id', 'common.lang.id'),
    ('de', 'common.lang.de'),
    ('fa', 'common.lang.fa'),
    ('pl', 'common.lang.pl'),
    ('nl', 'common.lang.nl'),
    ('uk', 'common.lang.uk'),
    ('vi', 'common.lang.vi'),
    ('el', 'common.lang.el'),
    ('ro', 'common.lang.ro'),
    ('sq', 'common.lang.sq'),
  ];

  Future<void> showLanguageDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    var pending = _app.languageCode.value;

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => GlassAlertDialog(
          scrollable: true,
          title: Text('settings.dialog.languageTitle'.tr),
          content: GlassDialogListPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (code, labelKey) in _languagePickerOptions)
                  GlassListTile(
                    title: Text(labelKey.tr),
                    trailing: pending == code
                        ? const Icon(Icons.check_rounded, color: Colors.white)
                        : null,
                    selected: pending == code,
                    onTap: () => setDialogState(() => pending = code),
                  ),
              ],
            ),
          ),
          actions: glassDialogPickerActions(
            dialogContext,
            onCancel: () => Navigator.pop(dialogContext),
            onApply: () async {
              await _app.setLanguageCode(pending);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
          ),
        ),
      ),
    );
  }

  Future<void> showLayoutModeDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    var pending = _app.layoutMode.value;

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => GlassAlertDialog(
          title: Text('settings.dialog.layoutTitle'.tr),
          content: GlassDialogListPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassListTile(
                  title: Text('settings.phone'.tr),
                  subtitle: Text('layout.dialog.phone.sub'.tr),
                  trailing: pending == AppLayoutMode.mobile
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : null,
                  selected: pending == AppLayoutMode.mobile,
                  onTap: () =>
                      setDialogState(() => pending = AppLayoutMode.mobile),
                ),
                GlassListTile(
                  title: Text('layout.tablet'.tr),
                  subtitle: Text('layout.tablet.sub'.tr),
                  trailing: pending == AppLayoutMode.tablet
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : null,
                  selected: pending == AppLayoutMode.tablet,
                  onTap: () =>
                      setDialogState(() => pending = AppLayoutMode.tablet),
                ),
                GlassListTile(
                  title: Text('settings.tv'.tr),
                  subtitle: Text('layout.dialog.tv.sub'.tr),
                  trailing: pending == AppLayoutMode.tv
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : null,
                  selected: pending == AppLayoutMode.tv,
                  onTap: () => setDialogState(() => pending = AppLayoutMode.tv),
                ),
              ],
            ),
          ),
          actions: glassDialogPickerActions(
            dialogContext,
            onCancel: () => Navigator.pop(dialogContext),
            onApply: () async {
              await _app.setLayoutMode(pending);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
          ),
        ),
      ),
    );
  }

  Future<void> showThemeDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    // Tema seçim diyaloğu canlı önizleme ile çalışır:
    // - Kullanıcı bir tema seçince anında uygulanır (kullanıcı arkadaki
    //   ekranda yeni temayı görür).
    // - "Kaydet" → mevcut seçim onaylanır.
    // - "İptal" / barrier tap / sistem geri tuşu → orijinal temaya dönülür.
    final originalTheme = _app.themeLabel.value;
    var pending = originalTheme;
    var saved = false;

    Future<void> applyPreview(String t) async {
      if (_app.themeLabel.value == t) return;
      await _app.setThemeLabel(t);
    }

    Future<void> revert() async {
      if (saved) return;
      if (_app.themeLabel.value != originalTheme) {
        await _app.setThemeLabel(originalTheme);
      }
    }

    final themes = GlassThemeLabels.selectableThemesForLayout(
      tv: _app.layoutMode.value == AppLayoutMode.tv,
    );

    await showDialog<void>(
      context: ctx,
      barrierDismissible: true,
      builder: (dialogContext) => PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) unawaited(revert());
        },
        child: StatefulBuilder(
          builder: (context, setDialogState) => GlassAlertDialog(
            scrollable: true,
            title: Text('settings.dialog.themeTitle'.tr),
            content: GlassDialogListPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in themes)
                    GlassListTile(
                      title: Text(localizedThemeStorageLabel(t)),
                      subtitle: t == GlassThemeLabels.flyUi
                          ? Text(
                              'theme.flyUi.sub'.tr,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12,
                              ),
                            )
                          : t == GlassThemeLabels.ios27
                              ? Text(
                                  'theme.ios27.sub'.tr,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                      trailing: pending == t
                          ? const Icon(Icons.check_rounded, color: Colors.white)
                          : null,
                      selected: pending == t,
                      onTap: () {
                        setDialogState(() => pending = t);
                        unawaited(applyPreview(t));
                      },
                    ),
                ],
              ),
            ),
            actions: glassDialogPickerActions(
              dialogContext,
              onCancel: () async {
                await revert();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              onApply: () async {
                // Kullanıcı kaydı onayladı; mevcut canlı önizleme kalsın.
                await applyPreview(pending);
                saved = true;
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
            ),
          ),
        ),
      ),
    );

    // Dialog kapatıldıktan sonra kullanıcı kaydetmediyse (örn. barrier tap)
    // PopScope `revert()`'i çoktan tetiklemiş olur; ancak farklı yolarla
    // (örn. üst seviye Get.back) kapanma ihtimaline karşı güvenlik ağı.
    if (!saved) {
      await revert();
    }
  }

  Future<void> showXmltvDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    final ctrl = TextEditingController(text: _app.xmltvUrl.value);

    await showDialog<void>(
      context: ctx,
      builder: (c) => Obx(
        () {
          final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;
          final onLabel =
              remoteNav ? Colors.white.withValues(alpha: 0.82) : null;
          return GlassAlertDialog(
            scrollable: false,
            tvOsdStyle: remoteNav,
            title: Text('settings.dialog.xmltvTitle'.tr),
            content: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'settings.dialog.xmltv.body'.tr,
                      style: TextStyle(
                        color: remoteNav
                            ? Colors.white.withValues(alpha: 0.85)
                            : null,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.url,
                      maxLines: 3,
                      style: TextStyle(
                        color: remoteNav ? Colors.white : null,
                      ),
                      decoration: InputDecoration(
                        hintText: 'settings.dialog.xmltv.hint'.tr,
                        labelText: 'settings.dialog.xmltv.label'.tr,
                        hintStyle: remoteNav
                            ? TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                              )
                            : null,
                        labelStyle: TextStyle(color: onLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              GlassDialogActionButton(
                label: 'common.cancel'.tr,
                onDarkSurface: remoteNav,
                onPressed: () => Navigator.pop(c),
              ),
              GlassDialogActionButton(
                label: 'common.clear'.tr,
                onDarkSurface: remoteNav,
                onPressed: () async {
                  await _app.setXmltvUrl('');
                  Get.find<EpgService>().clear();
                  if (c.mounted) Navigator.pop(c);
                },
              ),
              GlassDialogActionButton(
                label: 'common.refreshNow'.tr,
                primary: true,
                onDarkSurface: remoteNav,
                onPressed: () async {
                  final epg = Get.find<EpgService>();
                  if (epg.isLoading.value) return;

                  final u = ctrl.text.trim();
                  await _app.setXmltvUrl(u);

                  GlassSnackbar.show(
                    'settings.dialog.xmltvTitle'.tr,
                    'settings.tile.refresh.loading'.tr,
                    snackPosition: SnackPosition.BOTTOM,
                  );

                  await epg.loadEpgFirstSuccessful(_app.m3uEpgFetchUrls);

                  if (epg.hasLoadedGuideData()) {
                    await _app.markM3uEpgFetchedOk();
                    final src = await _repo.readSource();
                    final cacheKey = src != null
                        ? EpgSnapshotKeys.logicalKeyFor(src, _app)
                        : null;
                    if (cacheKey != null) {
                      await epg.persistSnapshotToDisk(cacheKey);
                    }

                    final pl = Get.find<PlaylistCacheService>().result.value;
                    if (pl != null) {
                      await epg.applyM3uXmltvChannelMappings(
                        cacheKey: cacheKey,
                        liveChannels: pl.channels,
                      );
                    }

                    GlassSnackbar.show(
                      'settings.dialog.xmltvTitle'.tr,
                      'common.success'.tr,
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  } else {
                    GlassSnackbar.show(
                      'settings.dialog.xmltvTitle'.tr,
                      'common.error'.tr,
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }

                  if (c.mounted) Navigator.pop(c);
                },
              ),
            ],
          );
        },
      ),
    );

    ctrl.dispose();
  }

  Future<void> showAdaptiveQualityCeilingDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    var pending = _app.adaptiveStreamQualityCeiling.value;

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => GlassAlertDialog(
          scrollable: true,
          title: Text('settings.dialog.adaptiveQualityTitle'.tr),
          content: GlassDialogListPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final opt in AdaptiveStreamQualityCeiling.values)
                  GlassListTile(
                    title: Text(_adaptiveQualityOptionLabel(opt)),
                    trailing: pending == opt
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                          )
                        : null,
                    selected: pending == opt,
                    onTap: () => setDialogState(() => pending = opt),
                  ),
              ],
            ),
          ),
          actions: glassDialogPickerActions(
            dialogContext,
            onCancel: () => Navigator.pop(dialogContext),
            onApply: () async {
              await _app.setAdaptiveStreamQualityCeiling(pending);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
          ),
        ),
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

  /// Ayarlar > Oynatıcı > "Yayın Formatı" tile'ı için kısa açıklama.
  String get liveStreamFormatSubtitle {
    final mode = _app.liveStreamFormat.value;
    if (mode == AppSettingsService.liveStreamFormatTs) {
      return 'settings.streamFormat.tsShort'.tr;
    }
    // HLS (varsayılan) — eski "auto" değeri de buraya düşer.
    return 'settings.streamFormat.hlsShort'.tr;
  }

  /// Canlı yayın taşıma biçimini (HLS / MPEG-TS) seçtirir. "Otomatik" kaldırıldı;
  /// varsayılan HLS, HLS açılmazsa oynatıcı otomatik MPEG-TS'e fallback yapar.
  Future<void> showLiveStreamFormatDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    // Eski kurulumdan "auto" gelmiş olabilir → diyalogda HLS seçili görünsün.
    var pending =
        _app.liveStreamFormat.value == AppSettingsService.liveStreamFormatTs
            ? AppSettingsService.liveStreamFormatTs
            : AppSettingsService.liveStreamFormatHls;
    const options = <String>[
      AppSettingsService.liveStreamFormatHls,
      AppSettingsService.liveStreamFormatTs,
    ];

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => GlassAlertDialog(
          scrollable: true,
          title: Text('settings.dialog.streamFormatTitle'.tr),
          content: GlassDialogListPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final opt in options)
                  GlassListTile(
                    title: Text(_liveStreamFormatLabel(opt)),
                    subtitle: Text(
                      _liveStreamFormatDesc(opt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    trailing: pending == opt
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                          )
                        : null,
                    selected: pending == opt,
                    onTap: () => setDialogState(() => pending = opt),
                  ),
              ],
            ),
          ),
          actions: glassDialogPickerActions(
            dialogContext,
            onCancel: () => Navigator.pop(dialogContext),
            onApply: () async {
              await _app.setLiveStreamFormat(pending);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
          ),
        ),
      ),
    );
  }

  String _liveStreamFormatLabel(String v) {
    if (v == AppSettingsService.liveStreamFormatTs) {
      return 'settings.streamFormat.tsTitle'.tr;
    }
    if (v == AppSettingsService.liveStreamFormatHls) {
      return 'settings.streamFormat.hlsTitle'.tr;
    }
    return 'settings.streamFormat.autoTitle'.tr;
  }

  String _liveStreamFormatDesc(String v) {
    if (v == AppSettingsService.liveStreamFormatTs) {
      return 'settings.streamFormat.tsDesc'.tr;
    }
    if (v == AppSettingsService.liveStreamFormatHls) {
      return 'settings.streamFormat.hlsDesc'.tr;
    }
    return 'settings.streamFormat.autoDesc'.tr;
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
                GlassDialogListPanel(
                  child: Column(
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
                    ],
                  ),
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
            GlassDialogActionButton(
              label: 'common.cancel'.tr,
              onPressed: () => Navigator.pop(c),
            ),
            GlassDialogActionButton(
              label: 'common.save'.tr,
              primary: true,
              onPressed: () async {
                await _app.setCatchUpUrlPreset(local);
                await _app.setCatchUpCustomTemplate(customCtrl.text);
                if (c.mounted) Navigator.pop(c);
              },
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

  /// Ses yükseltici üst sınırını seçtirir (100/125/150/175/200). 100 = kapalı
  /// (boost yok). Değer kaydedildiğinde `PlayerController.setVolume` yeni
  /// üst sınırla otomatik olarak çalışır; ek bir restart gerekmez.
  Future<void> showVolumeBoostDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;
    var local = AppSettingsService.normalizeVolumeBoostMaxPercent(
      _app.volumeBoostMaxPercent.value,
    );

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return GlassAlertDialog(
              scrollable: false,
              tvOsdStyle: remoteNav,
              title: Text('settings.dialog.volumeBoost.title'.tr),
              content: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'settings.dialog.volumeBoost.hint'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GlassDialogListPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final opt in AppSettingsService
                              .volumeBoostMaxPercentOptions)
                            GlassListTile(
                              title: Text(
                                opt ==
                                        AppSettingsService
                                            .defaultVolumeBoostMaxPercent
                                    ? 'settings.dialog.volumeBoost.off'.tr
                                    : 'settings.dialog.volumeBoost.option'
                                        .trParams({'n': '$opt'}),
                              ),
                              trailing: local == opt
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                    )
                                  : null,
                              selected: local == opt,
                              onTap: () => setDialogState(() => local = opt),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                GlassDialogActionButton(
                  label: 'common.cancel'.tr,
                  onDarkSurface: remoteNav,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                GlassDialogActionButton(
                  label: 'common.save'.tr,
                  primary: true,
                  onDarkSurface: remoteNav,
                  onPressed: () async {
                    await _app.setVolumeBoostMaxPercent(local);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Ses Equalizer dialogunu açar. Servis kapalı bile olsa kullanıcı
  /// dialog içinde anahtarı çevirebilir; tüm ayarlar reaktif olarak
  /// MediaKit (libmpv) `af` zincirine uygulanır.
  Future<void> showEqualizerDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;
    if (Get.isRegistered<EqualizerService>()) {
      await EqualizerService.to.ensureLoaded();
    }
    if (!ctx.mounted) return;
    await eq_dialog.showEqualizerDialog(ctx);
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
                GlassDialogActionButton(
                  label: 'common.cancel'.tr,
                  onDarkSurface: remoteNav,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                GlassDialogActionButton(
                  label: 'common.save'.tr,
                  primary: true,
                  onDarkSurface: remoteNav,
                  onPressed: () async {
                    await _app.setLiveBufferSeconds(local);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Şifrelenmiş `mina_backup.dat` dosyasını oluştur ve sistemin paylaşım
  /// sayfası ile (Drive / WhatsApp / e‑posta vb.) dışarı çıkar. Hiçbir genel
  /// depolama izni istenmez – Android, paylaşımı kendi anlık izniyle yapar.
  Future<void> shareBackupFile() async {
    if (isBackupBusy.value) return;
    isBackupBusy.value = true;
    try {
      final result = await _backup.exportToShareSheet(
        subject: 'Mina yedeği',
      );
      switch (result.status) {
        case BackupShareStatus.success:
          GlassSnackbar.show(
            'settings.backup.title'.tr,
            'settings.backup.shared'.tr,
            snackPosition: SnackPosition.BOTTOM,
          );
          break;
        case BackupShareStatus.dismissed:
          // Kullanıcı paylaşımı iptal etti — sessizce geç.
          break;
        case BackupShareStatus.failure:
          GlassSnackbar.show(
            'settings.backup.title'.tr,
            (result.message?.trim().isNotEmpty == true)
                ? result.message!
                : 'settings.backup.error'.tr,
            snackPosition: SnackPosition.BOTTOM,
          );
          break;
      }
    } finally {
      isBackupBusy.value = false;
    }
  }

  /// `file_picker` ile kullanıcıya bir `.dat` dosyası seçtir, çöz ve
  /// SharedPreferences + SecureStorage + yerel `.m3u` dosyalarını geri yükle.
  /// Restart önerisi ile birlikte özet snackbar gösterilir.
  Future<void> restoreBackupFromFile() async {
    if (isBackupBusy.value) return;

    // Geri yükleme yıkıcı bir işlem (mevcut `mina_*` key’leri temizlenir).
    // Önce onay penceresi göster.
    final ctx = Get.context;
    if (ctx == null) return;
    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => GlassAlertDialog(
        tvOsdStyle: remoteNav,
        title: Text('settings.backup.restore.confirmTitle'.tr),
        content: Text('settings.backup.restore.confirmBody'.tr),
        actions: [
          GlassDialogActionButton(
            label: 'common.cancel'.tr,
            onDarkSurface: remoteNav,
            onPressed: () => Navigator.of(dCtx).pop(false),
          ),
          GlassDialogActionButton(
            label: 'settings.backup.restore.confirmYes'.tr,
            primary: true,
            onDarkSurface: remoteNav,
            onPressed: () => Navigator.of(dCtx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;

    isBackupBusy.value = true;
    try {
      final result = await _backup.importFromUserPickedFile();
      switch (result.status) {
        case BackupImportStatus.success:
          final s = result.summary!;
          GlassSnackbar.show(
            'settings.backup.title'.tr,
            'settings.backup.restoredSummary'.trParams({
              'prefs': '${s.prefsCount}',
              'sec': '${s.secureCount}',
              'm3u': '${s.localM3uCount}',
            }),
            snackPosition: SnackPosition.BOTTOM,
          );
          if (Get.context != null) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
            await showDialog<void>(
              context: Get.context!,
              builder: (dCtx) => GlassAlertDialog(
                tvOsdStyle: remoteNav,
                title: Text('settings.backup.restore.doneTitle'.tr),
                content: Text('settings.backup.restore.doneBody'.tr),
                actions: [
                  GlassDialogActionButton(
                    label: 'common.ok'.tr,
                    primary: true,
                    onDarkSurface: remoteNav,
                    onPressed: () => Navigator.of(dCtx).pop(),
                  ),
                ],
              ),
            );
          }
          // Tüm servisleri taze veriyle yeniden yükletmek için splash'ten
          // temiz yeniden başlat (kısmi bellek yenilemesi yerine).
          isBackupBusy.value = false;
          Get.offAllNamed(AppRoutes.splash);
          return;
        case BackupImportStatus.cancelled:
          // Sessizce geç.
          break;
        case BackupImportStatus.failure:
          GlassSnackbar.show(
            'settings.backup.title'.tr,
            (result.message?.trim().isNotEmpty == true)
                ? result.message!
                : 'settings.backup.error'.tr,
            snackPosition: SnackPosition.BOTTOM,
          );
          break;
      }
    } finally {
      isBackupBusy.value = false;
    }
  }

  /// Google hesabı bağlı değilse oturum açar; bağlıysa true döner.
  /// Oturum açma çekirdeği — `isCloudBusy` guard'ı **kontrol etmez** ve busy
  /// bayrağını **yönetmez**. Çağıran (yedekle/geri yükle/sil) zaten busy=true
  /// yaptığı için bu metodu kullanır; aksi halde busy guard yüzünden işlem
  /// hiç başlamadan iptal olurdu (buton "tepkisiz" görünüyordu).
  Future<bool> _ensureSignedInForCloudCore() async {
    final auth = _auth;
    if (auth == null || !auth.isAvailable) {
      GlassSnackbar.show(
        'cloud.title'.tr,
        'cloud.notConfigured'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
    if (auth.isSignedIn) return true;
    final result = await auth.signInWithGoogle();
    switch (result.outcome) {
      case GoogleSignInOutcome.success:
        return true;
      case GoogleSignInOutcome.cancelled:
        return false;
      case GoogleSignInOutcome.notConfigured:
        GlassSnackbar.show(
          'cloud.title'.tr,
          'cloud.notConfigured'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      case GoogleSignInOutcome.failed:
        GlassSnackbar.show(
          'cloud.title'.tr,
          result.messageKey.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
    }
  }

  /// Doğrudan UI'dan (giriş bölümü) çağrılır; busy guard + busy yönetimini
  /// kendisi yapar. Yedekle/geri yükle/sil eylemleri busy'yi kendileri
  /// yönettiği için [_ensureSignedInForCloudCore] kullanır.
  Future<bool> ensureSignedInForCloud() async {
    if (isCloudBusy.value) return false;
    final auth = _auth;
    if (auth == null || !auth.isAvailable) {
      GlassSnackbar.show(
        'cloud.title'.tr,
        'cloud.notConfigured'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
    if (auth.isSignedIn) return true;
    isCloudBusy.value = true;
    try {
      return await _ensureSignedInForCloudCore();
    } finally {
      isCloudBusy.value = false;
    }
  }

  /// Tüm ayarları + 32 slot listelerini Google (Firestore) hesabına yedekler.
  Future<void> backupToGoogle() async {
    if (isCloudBusy.value) return;
    isCloudBusy.value = true;
    try {
      if (!await _ensureSignedInForCloudCore()) return;
      // Çakışma koruması: bulutta bu cihazın son yedeğinden daha yeni bir
      // yedek varsa (büyük olasılıkla başka bir cihazdan), üzerine yazmadan
      // önce kullanıcıya sor.
      if (!await _confirmOverwriteIfCloudNewer()) return;
      final ok = await _auth!
          .saveUserSettingsToCloud()
          .timeout(const Duration(seconds: 30), onTimeout: () => false);
      GlassSnackbar.show(
        'cloud.title'.tr,
        ok ? 'cloud.backupDone'.tr : 'cloud.backupFailed'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      if (ok) unawaited(refreshCloudBackupInfo());
    } catch (_) {
      GlassSnackbar.show(
        'cloud.title'.tr,
        'cloud.backupFailed'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isCloudBusy.value = false;
    }
  }

  /// Bulutta yerel son yedek zamanından belirgin şekilde (>2 dk) daha yeni bir
  /// yedek varsa, üzerine yazmadan önce onay penceresi gösterir. Onaylanırsa
  /// veya bulut daha yeni değilse `true`, kullanıcı iptal ederse `false`.
  Future<bool> _confirmOverwriteIfCloudNewer() async {
    final auth = _auth;
    if (auth == null) return true;
    int? cloudMs;
    try {
      cloudMs = await auth
          .fetchCloudUpdatedAtMs()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
    } catch (_) {
      cloudMs = null;
    }
    if (cloudMs == null) return true;
    final localMs = _app.lastCloudBackupTime.value;
    // 2 dk pay: kendi yazımımızın saat sapmasından kaynaklı yanlış pozitifleri
    // ele.
    if (cloudMs <= localMs + 120000) return true;
    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) return true;
    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;
    final when = DateTime.fromMillisecondsSinceEpoch(cloudMs);
    final stamp =
        '${when.day.toString().padLeft(2, '0')}.${when.month.toString().padLeft(2, '0')}.${when.year} '
        '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
    final proceed = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => GlassAlertDialog(
        tvOsdStyle: remoteNav,
        title: Text('cloud.backup.newerTitle'.tr),
        content: Text('cloud.backup.newerBody'.trParams({'date': stamp})),
        actions: [
          GlassDialogActionButton(
            label: 'common.cancel'.tr,
            onDarkSurface: remoteNav,
            onPressed: () => Navigator.of(dCtx).pop(false),
          ),
          GlassDialogActionButton(
            label: 'cloud.backup.overwrite'.tr,
            primary: true,
            onDarkSurface: remoteNav,
            onPressed: () => Navigator.of(dCtx).pop(true),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  /// Google hesabındaki yedeği yerel depoya geri yükler (onaylı).
  Future<void> restoreFromGoogle() async {
    if (isCloudBusy.value) return;
    final ctx = Get.context;
    if (ctx == null) return;
    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => GlassAlertDialog(
        tvOsdStyle: remoteNav,
        title: Text('cloud.restore.confirmTitle'.tr),
        content: Text('cloud.restore.confirmBody'.tr),
        actions: [
          GlassDialogActionButton(
            label: 'common.cancel'.tr,
            onDarkSurface: remoteNav,
            onPressed: () => Navigator.of(dCtx).pop(false),
          ),
          GlassDialogActionButton(
            label: 'settings.backup.restore.confirmYes'.tr,
            primary: true,
            onDarkSurface: remoteNav,
            onPressed: () => Navigator.of(dCtx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;

    isCloudBusy.value = true;
    try {
      if (!await _ensureSignedInForCloudCore()) return;
      final cloud = await _auth!
          .loadUserSettingsFromCloud()
          .timeout(const Duration(seconds: 30), onTimeout: () => null);
      if (cloud == null || cloud.isEmpty) {
        GlassSnackbar.show(
          'cloud.title'.tr,
          'cloud.restore.empty'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final applied = await _auth!.applyCloudSettingsLocally(cloud);
      if (!applied) {
        GlassSnackbar.show(
          'cloud.title'.tr,
          'cloud.restoreFailed'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      _logCloudRestore(success: true);
      if (Get.context != null) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await showDialog<void>(
          context: Get.context!,
          builder: (dCtx) => GlassAlertDialog(
            tvOsdStyle: remoteNav,
            title: Text('settings.backup.restore.doneTitle'.tr),
            content: Text('settings.backup.restore.doneBody'.tr),
            actions: [
              GlassDialogActionButton(
                label: 'common.ok'.tr,
                primary: true,
                onDarkSurface: remoteNav,
                onPressed: () => Navigator.of(dCtx).pop(),
              ),
            ],
          ),
        );
      }
      // Geri yükleme tüm `mina_*` ayarlarını, listeleri, favori ve izleme
      // geçmişini değiştirir. Kısmi bellek yenileme yerine splash'ten temiz
      // yeniden başlatarak tüm servislerin taze veriyle yüklenmesini garanti
      // ederiz (sihirbaz geri yükleme akışıyla aynı davranış).
      isCloudBusy.value = false;
      Get.offAllNamed(AppRoutes.splash);
      return;
    } catch (_) {
      _logCloudRestore(success: false);
      GlassSnackbar.show(
        'cloud.title'.tr,
        'cloud.restoreFailed'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isCloudBusy.value = false;
    }
  }

  void _logCloudRestore({required bool success}) {
    if (!Get.isRegistered<MinaTelemetryService>()) return;
    unawaited(
      Get.find<MinaTelemetryService>().logCloudRestore(success: success),
    );
  }

  /// Otomatik bulut yedekleme aralığını ayarlar (0: kapalı, 1: günlük,
  /// 7: haftalık). Açık bir aralık seçildiyse ve zamanı gelmişse arka planda
  /// hemen bir yedek tetiklenir.
  Future<void> setCloudAutoBackupInterval(int days) async {
    await _app.setCloudAutoBackupDays(days);
    if (days > 0) {
      final auth = _auth;
      if (auth != null && auth.isAvailable && auth.isSignedIn) {
        unawaited(auth.maybeAutoBackup());
      }
    }
  }

  /// Google oturumunu kapatır.
  Future<void> signOutFromGoogle() async {
    final auth = _auth;
    if (auth == null) return;
    await auth.signOut();
    GlassSnackbar.show(
      'cloud.title'.tr,
      'cloud.signedOut'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Buluttaki tüm kullanıcı verisini siler (GDPR). Onaylı; yerel veriler
  /// etkilenmez. Başarılı olursa son bulut yedek zamanı sıfırlanır.
  Future<void> deleteCloudData() async {
    if (isCloudBusy.value) return;
    final auth = _auth;
    if (auth == null) return;
    final ctx = Get.context;
    if (ctx == null) return;
    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dCtx) => GlassAlertDialog(
        tvOsdStyle: remoteNav,
        title: Text('cloud.delete.confirmTitle'.tr),
        content: Text('cloud.delete.confirmBody'.tr),
        actions: [
          GlassDialogActionButton(
            label: 'common.cancel'.tr,
            onDarkSurface: remoteNav,
            onPressed: () => Navigator.of(dCtx).pop(false),
          ),
          GlassDialogActionButton(
            label: 'cloud.delete.confirmYes'.tr,
            primary: true,
            onDarkSurface: remoteNav,
            onPressed: () => Navigator.of(dCtx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    isCloudBusy.value = true;
    try {
      if (!await _ensureSignedInForCloudCore()) return;
      final done = await auth
          .deleteCloudData()
          .timeout(const Duration(seconds: 30), onTimeout: () => false);
      GlassSnackbar.show(
        'cloud.title'.tr,
        done ? 'cloud.delete.done'.tr : 'cloud.delete.failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      if (done) cloudBackupInfo.value = null;
    } catch (_) {
      GlassSnackbar.show(
        'cloud.title'.tr,
        'cloud.delete.failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isCloudBusy.value = false;
    }
  }

  /// Yatay OSD kapsülünün arka plan saydamlığını ayarla (0–100, 100 = opak).
  /// Yalnızca arka planı / kenarı / gölgesi etkiler; butonlar ve ikonlar
  /// olduğu gibi kalır.
  Future<void> showOsdLandscapeBackgroundOpacityDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) {
        var local = _app.osdLandscapeBackgroundOpacity.value.clamp(0, 100);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return GlassAlertDialog(
              scrollable: false,
              tvOsdStyle: remoteNav,
              title: Text('settings.dialog.osdOpacityTitle'.tr),
              content: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'settings.dialog.osdOpacitySlider'
                          .trParams({'n': '$local'}),
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
                                        local = (local - 5).clamp(0, 100);
                                      })
                                  : null,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              '$local%',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          FocusTraversalOrder(
                            order: const NumericFocusOrder(2),
                            child: IconButton.filledTonal(
                              icon: const Icon(Icons.add_rounded),
                              onPressed: local < 100
                                  ? () => setDialogState(() {
                                        local = (local + 5).clamp(0, 100);
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
                          max: 100,
                          divisions: 20,
                          value: local.clamp(0, 100).toDouble(),
                          onChanged: (nv) {
                            setDialogState(() {
                              local = nv.round().clamp(0, 100);
                            });
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'settings.dialog.osdOpacityHint'.tr,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                GlassDialogActionButton(
                  label: 'common.cancel'.tr,
                  onDarkSurface: remoteNav,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                GlassDialogActionButton(
                  label: 'common.save'.tr,
                  primary: true,
                  onDarkSurface: remoteNav,
                  onPressed: () async {
                    await _app.setOsdLandscapeBackgroundOpacity(local);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> showEpgDiskCacheRefreshDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) {
        var local = _app.epgDiskCacheRefreshDays.value.clamp(0, 5);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 0 = otomatik yenileme kapalı (yalnızca bir kez indir).
            final valueText = local <= 0
                ? 'settings.dialog.epgCacheNever'.tr
                : 'settings.dialog.epgCacheSlider'.trParams({'n': '$local'});
            return GlassAlertDialog(
              scrollable: false,
              tvOsdStyle: remoteNav,
              title: Text('settings.epg.refreshFrequency'.tr),
              content: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'settings.dialog.epgCacheHint'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(valueText),
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
                                        local = (local - 1).clamp(0, 5);
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
                              onPressed: local < 5
                                  ? () => setDialogState(() {
                                        local = (local + 1).clamp(0, 5);
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
                          max: 5,
                          divisions: 5,
                          value: local.clamp(0, 5).toDouble(),
                          onChanged: (nv) {
                            setDialogState(() {
                              local = nv.round().clamp(0, 5);
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                GlassDialogActionButton(
                  label: 'common.cancel'.tr,
                  onDarkSurface: remoteNav,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                GlassDialogActionButton(
                  label: 'common.save'.tr,
                  primary: true,
                  onDarkSurface: remoteNav,
                  onPressed: () async {
                    await _app.setEpgDiskCacheRefreshDays(local);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
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

  Future<void> showAppFontFamilyDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;
    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) => SubtitleFontFamilyPickerDialog(
        initialKey: _app.appFontFamilyKey.value,
        tvRemote: _app.layoutMode.value.usesRemoteNavigationStyle,
        tvOsdStyle: _app.layoutMode.value == AppLayoutMode.tv,
        title: 'Uygulama Fontu',
        hint: 'Tum uygulama arayuzu icin font secimi.',
        options: kAppFontFamilyOptions,
        onCancel: () => Navigator.of(dialogContext).pop(),
        onSave: (key) async {
          await _app.setAppFontFamilyKey(key);
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        },
      ),
    );
  }

  void openEpgSettings() => Get.toNamed(AppRoutes.epgSettings);

  void openEpgSourceManage() => Get.toNamed(AppRoutes.epgSourceManage);

  String get epgStatusSubtitle {
    final epg = Get.find<EpgService>();

    // GlobalEpgService (GitHub yedek) `EpgService`'ten ayrı kendi belleğini
    // tutar; UI duruma hem Xtream/M3U EPG hem de GitHub yedek katkısını
    // birleştirerek bakmalı, aksi halde "Sadece GitHub" modunda her şey yüklü
    // olsa bile "Rehber yüklenmedi" görünür.
    var channels = epg.loadedXmlChannelCount;
    var programs = epg.loadedProgrammeKeyCount;
    var globalLoading = false;
    if (Get.isRegistered<GlobalEpgService>()) {
      final g = Get.find<GlobalEpgService>();
      // Reaktivite için: generation aboneliği. Bu getter Obx() içinde çağrılır.
      g.loadGeneration.value;
      channels += g.loadedMemoryChannelCount;
      programs += g.loadedMemoryProgrammeCount;
      globalLoading = g.isLoading.value;
    }

    if (epg.isLoading.value || globalLoading) {
      return 'settings.epg.status.sub.loading'.tr;
    }
    if (channels == 0 && programs == 0) {
      return 'settings.epg.status.sub.empty'.tr;
    }
    return 'settings.epg.status.sub.loaded'.trParams({
      'channels': '$channels',
      'programs': '$programs',
    });
  }

  /// Ayarlar > EPG > EPG Kaynağı tile'ı için alt başlık.
  /// Hangi kaynağın gerçekten aktif olduğunu kullanıcıya gösterir:
  ///   • Xtream EPG başarılıysa "Xtream sunucusundan canlı"
  ///   • Xtream başarısızsa ve GlobalEPG doluysa "GitHub yedek aktif"
  ///   • Auto'da ikisi de varsa "Xtream + GitHub yedek"
  String get xtreamEpgSourceSubtitle {
    final epg = Get.find<EpgService>();
    final mode = _app.xtreamEpgSourceMode.value;
    final xtreamOk = epg.xtreamLastSuccess.value;
    final hasGlobal = Get.isRegistered<GlobalEpgService>() &&
        Get.find<GlobalEpgService>().loadedMemoryChannelCount > 0;

    switch (mode) {
      case XtreamEpgSourceMode.xtreamOnly:
        return xtreamOk
            ? 'settings.epg.sourcePref.sub.xtreamOk'.tr
            : 'settings.epg.sourcePref.sub.xtreamOnlyFail'.tr;
      case XtreamEpgSourceMode.githubOnly:
        return hasGlobal
            ? 'settings.epg.sourcePref.sub.githubOk'.tr
            : 'settings.epg.sourcePref.sub.githubLoading'.tr;
      case XtreamEpgSourceMode.auto:
        if (xtreamOk && hasGlobal) {
          return 'settings.epg.sourcePref.sub.both'.tr;
        }
        if (xtreamOk) {
          return 'settings.epg.sourcePref.sub.xtreamOk'.tr;
        }
        if (hasGlobal) {
          return 'settings.epg.sourcePref.sub.githubFallback'.tr;
        }
        return 'settings.epg.sourcePref.sub.autoLoading'.tr;
    }
  }

  /// EPG Kaynağı tile'ında badge metni — `XTREAM` / `GITHUB` / `OTOMATİK`.
  String get xtreamEpgSourceBadge {
    switch (_app.xtreamEpgSourceMode.value) {
      case XtreamEpgSourceMode.auto:
        return 'settings.epg.sourcePref.badge.auto'.tr;
      case XtreamEpgSourceMode.xtreamOnly:
        return 'settings.epg.sourcePref.badge.xtream'.tr;
      case XtreamEpgSourceMode.githubOnly:
        return 'settings.epg.sourcePref.badge.github'.tr;
    }
  }

  /// Ayarlar > EPG > EPG Kaynağı tile tıklanınca açılan dialog.
  /// Kullanıcı 3 seçenekten birini seçebilir; ardından mevcut Xtream listesi
  /// için EPG yeniden yüklenir.
  Future<void> showXtreamEpgSourceDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    final source = await _repo.readSource();
    if (source is! XtreamSource) {
      GlassSnackbar.show(
        'settings.snackbar.info'.tr,
        'settings.snackbar.xtreamOnly'.tr,
      );
      return;
    }

    if (!ctx.mounted) return;
    var pending = _app.xtreamEpgSourceMode.value;
    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;

    final picked = await showDialog<XtreamEpgSourceMode>(
      context: ctx,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => GlassAlertDialog(
          scrollable: true,
          tvOsdStyle: remoteNav,
          title: Text('settings.epg.sourcePref.title'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'settings.epg.sourcePref.body'.tr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              GlassDialogListPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _epgSourceOption(
                      title: 'settings.epg.sourcePref.optAuto.title'.tr,
                      desc: 'settings.epg.sourcePref.optAuto.desc'.tr,
                      icon: Icons.auto_awesome_rounded,
                      selected: pending == XtreamEpgSourceMode.auto,
                      onTap: () => setDialogState(
                          () => pending = XtreamEpgSourceMode.auto),
                    ),
                    _epgSourceOption(
                      title: 'settings.epg.sourcePref.optXtream.title'.tr,
                      desc: 'settings.epg.sourcePref.optXtream.desc'.tr,
                      icon: Icons.dns_rounded,
                      selected: pending == XtreamEpgSourceMode.xtreamOnly,
                      onTap: () => setDialogState(
                          () => pending = XtreamEpgSourceMode.xtreamOnly),
                    ),
                    _epgSourceOption(
                      title: 'settings.epg.sourcePref.optGithub.title'.tr,
                      desc: 'settings.epg.sourcePref.optGithub.desc'.tr,
                      icon: Icons.cloud_download_rounded,
                      selected: pending == XtreamEpgSourceMode.githubOnly,
                      onTap: () => setDialogState(
                          () => pending = XtreamEpgSourceMode.githubOnly),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: glassDialogPickerActions(
            dialogContext,
            onDarkSurface: remoteNav,
            onCancel: () => Navigator.of(dialogContext).pop(),
            onApply: () => Navigator.of(dialogContext).pop(pending),
          ),
        ),
      ),
    );

    if (picked == null || picked == _app.xtreamEpgSourceMode.value) return;

    await _app.setXtreamEpgSourceMode(picked);

    final epg = Get.find<EpgService>();
    epg.clear();

    GlassSnackbar.show(
      'settings.epg.sourcePref.title'.tr,
      'settings.tile.refresh.loading'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );

    try {
      await _reloadEpgAfterPlaylist(source);
      final cacheKey = EpgSnapshotKeys.logicalKeyFor(source, _app);
      if (cacheKey != null && epg.hasLoadedGuideData()) {
        await epg.persistSnapshotToDisk(cacheKey);
      }
      GlassSnackbar.show(
        'settings.epg.sourcePref.title'.tr,
        epg.hasLoadedGuideData() ? 'common.success'.tr : 'common.error'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      GlassSnackbar.show(
        'settings.epg.sourcePref.title'.tr,
        'common.error'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Widget _epgSourceOption({
    required String title,
    required String desc,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GlassListTile(
      title: Row(
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(title)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 30, top: 2),
        child: Text(
          desc,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12.5,
            height: 1.3,
          ),
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: Colors.white)
          : null,
      selected: selected,
      onTap: onTap,
    );
  }

  Future<void> refreshEpgGuide() async {
    if (isRefreshing.value) return;
    final epg = Get.find<EpgService>();
    if (epg.isLoading.value) return;

    isRefreshing.value = true;
    GlassSnackbar.show(
      'settings.epg.status'.tr,
      'settings.tile.refresh.loading'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );

    try {
      // Yeni EPG verilerinin yansıması için mevcut bellek görüntüsünü sıfırla.
      // Aksi halde bir önceki Xtream/Global EPG kayıtları üzerine yazılır ve
      // sayaçlar / durum doğru güncellenmeyebilir.
      epg.clear();

      final source = await _repo.readSource();
      if (source != null) {
        await _reloadEpgAfterPlaylist(source);
        final cacheKey = EpgSnapshotKeys.logicalKeyFor(source, _app);
        if (cacheKey != null && epg.hasLoadedGuideData()) {
          await epg.persistSnapshotToDisk(cacheKey);
        }
      } else {
        await epg.loadEpgFirstSuccessful(_app.m3uEpgFetchUrls);
        if (epg.hasLoadedGuideData()) {
          await _app.markM3uEpgFetchedOk();
        }
      }
      GlassSnackbar.show(
        'settings.epg.status'.tr,
        epg.hasLoadedGuideData() ? 'common.success'.tr : 'common.error'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      GlassSnackbar.show(
        'settings.epg.status'.tr,
        'common.error'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isRefreshing.value = false;
    }
  }

  Future<void> showEpgTimeFormatDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;
    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) {
        var use24 = _app.epgTimeFormat24h.value;
        return StatefulBuilder(
          builder: (context, setState) {
            return GlassAlertDialog(
              tvOsdStyle: remoteNav,
              title: Text('settings.epg.timeFormat'.tr),
              content: RadioGroup<bool>(
                groupValue: use24,
                onChanged: (v) => setState(() => use24 = v ?? use24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<bool>(
                      title: Text('settings.epg.timeFormat24'.tr),
                      value: true,
                    ),
                    RadioListTile<bool>(
                      title: Text('settings.epg.timeFormat12'.tr),
                      value: false,
                    ),
                  ],
                ),
              ),
              actions: [
                GlassDialogActionButton(
                  label: 'common.cancel'.tr,
                  onDarkSurface: remoteNav,
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                GlassDialogActionButton(
                  label: 'common.save'.tr,
                  primary: true,
                  onDarkSurface: remoteNav,
                  onPressed: () async {
                    await _app.setEpgTimeFormat24h(use24);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> showEpgOffsetDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;
    final remoteNav = _app.layoutMode.value.usesRemoteNavigationStyle;
    const options = <int>[
      -720,
      -660,
      -600,
      -540,
      -480,
      -420,
      -360,
      -300,
      -240,
      -180,
      -120,
      -60,
      0,
      60,
      120,
      180,
      240,
      300,
      360,
      420,
      480,
      540,
      600,
      660,
      720,
      780,
    ];

    await showDialog<void>(
      context: ctx,
      builder: (dialogContext) {
        var selected = _app.epgTimezoneOffsetMinutes.value;
        return StatefulBuilder(
          builder: (context, setState) {
            return GlassAlertDialog(
              scrollable: true,
              tvOsdStyle: remoteNav,
              title: Text('settings.epg.offset'.tr),
              content: SizedBox(
                width: double.maxFinite,
                child: RadioGroup<int>(
                  groupValue: selected,
                  onChanged: (v) {
                    if (v != null) setState(() => selected = v);
                  },
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final m in options)
                        RadioListTile<int>(
                          title: Text(
                            m == 0
                                ? 'settings.epg.offset.zero'.tr
                                : '${m > 0 ? '+' : ''}${m ~/ 60}h ${(m.abs() % 60).toString().padLeft(2, '0')}m',
                          ),
                          value: m,
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                GlassDialogActionButton(
                  label: 'common.cancel'.tr,
                  onDarkSurface: remoteNav,
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                GlassDialogActionButton(
                  label: 'common.save'.tr,
                  primary: true,
                  onDarkSurface: remoteNav,
                  onPressed: () async {
                    await _app.setEpgTimezoneOffsetMinutes(selected);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                ),
              ],
            );
          },
        );
      },
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
          GlassDialogActionButton(
            label: 'settings.dialog.changelogTitle'.tr,
            onPressed: () {
              Navigator.pop(c);
              showChangelog();
            },
          ),
          Obx(
            () => GlassDialogActionButton(
              label: isCheckingUpdate.value
                  ? 'settings.update.checking'.tr
                  : 'settings.update.check'.tr,
              onPressed: isCheckingUpdate.value
                  ? null
                  : () => unawaited(checkForUpdate()),
            ),
          ),
          GlassDialogActionButton(
            label: 'common.close'.tr,
            primary: true,
            onPressed: () => Navigator.pop(c),
          ),
        ],
      ),
    );
  }

  /// «Hakkında» → Güncelleme Denetle: Play Store mağaza sayfasından en güncel
  /// sürümü çekip yüklü sürümle karşılaştırır. Güncelleme varsa kullanıcıya
  /// mağazaya yönlendiren bir diyalog, yoksa «güncelsiniz» bilgisi gösterir.
  Future<void> checkForUpdate() async {
    if (isCheckingUpdate.value) return;
    isCheckingUpdate.value = true;
    String packageName = '';
    try {
      final info = await PackageInfo.fromPlatform();
      packageName = info.packageName;
      final current = info.version;
      final store = await _fetchPlayStoreVersion(packageName);
      if (store == null || store.isEmpty) {
        _showUpdateResultDialog(
          available: false,
          unavailable: true,
          storeVersion: null,
          packageName: packageName,
        );
        return;
      }
      final hasUpdate = _isStoreVersionNewer(current, store);
      _showUpdateResultDialog(
        available: hasUpdate,
        unavailable: false,
        storeVersion: store,
        packageName: packageName,
      );
    } catch (_) {
      _showUpdateResultDialog(
        available: false,
        unavailable: true,
        storeVersion: null,
        packageName: packageName,
      );
    } finally {
      isCheckingUpdate.value = false;
    }
  }

  Future<String?> _fetchPlayStoreVersion(String packageName) async {
    if (packageName.isEmpty) return null;
    final url =
        'https://play.google.com/store/apps/details?id=$packageName&hl=en';
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        responseType: ResponseType.plain,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
        },
      ),
    );
    try {
      final res = await dio.get<String>(url);
      final body = res.data ?? '';
      if (body.isEmpty) return null;
      // Play Store sayfası sürümü AF_initDataCallback bloğunda gömülü tutuyor.
      final regex = RegExp(r'\[\[\["(\d+(?:\.\d+)+)"\]\]');
      final match = regex.firstMatch(body);
      return match?.group(1);
    } catch (_) {
      return null;
    } finally {
      dio.close(force: true);
    }
  }

  /// Mağaza sürümü yüklü sürümden yeni mi? Noktayla ayrılmış parçaları
  /// sayısal olarak karşılaştırır (örn. 1.10.0 > 1.9.5).
  bool _isStoreVersionNewer(String current, String store) {
    final c =
        current.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final s = store.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final len = c.length > s.length ? c.length : s.length;
    for (var i = 0; i < len; i++) {
      final cv = i < c.length ? c[i] : 0;
      final sv = i < s.length ? s[i] : 0;
      if (sv > cv) return true;
      if (sv < cv) return false;
    }
    return false;
  }

  void _showUpdateResultDialog({
    required bool available,
    required bool unavailable,
    required String? storeVersion,
    required String packageName,
  }) {
    final ctx = Get.context;
    if (ctx == null) return;

    final String title;
    final String body;
    if (unavailable) {
      title = 'settings.update.failTitle'.tr;
      body = 'settings.update.failBody'.tr;
    } else if (available) {
      title = 'settings.update.availableTitle'.tr;
      body =
          'settings.update.availableBody'.trParams({'v': storeVersion ?? ''});
    } else {
      title = 'settings.update.latestTitle'.tr;
      body = 'settings.update.latestBody'.tr;
    }

    showDialog<void>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        title: Text(title),
        content: Text(
          body,
          style: TextStyle(
            color: Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.9),
            height: 1.45,
          ),
        ),
        actions: [
          if (available)
            GlassDialogActionButton(
              label: 'settings.update.openStore'.tr,
              primary: true,
              onPressed: () {
                Navigator.pop(c);
                unawaited(_openPlayStore(packageName));
              },
            )
          else
            GlassDialogActionButton(
              label: 'common.close'.tr,
              primary: true,
              onPressed: () => Navigator.pop(c),
            ),
          if (available)
            GlassDialogActionButton(
              label: 'common.close'.tr,
              onPressed: () => Navigator.pop(c),
            ),
        ],
      ),
    );
  }

  Future<void> _openPlayStore(String packageName) async {
    if (packageName.isEmpty) return;
    final marketUri = Uri.parse('market://details?id=$packageName');
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$packageName',
    );
    try {
      final ok = await launchUrl(
        marketUri,
        mode: LaunchMode.externalApplication,
      );
      if (ok) return;
    } catch (_) {}
    try {
      await launchUrl(webUri, mode: LaunchMode.platformDefault);
    } catch (_) {}
  }

  void showChangelog() {
    final ctx = Get.context;
    if (ctx == null) return;

    showDialog<void>(
      context: ctx,
      builder: (c) => GlassAlertDialog(
        // İçeriği SingleChildScrollView'a sarma: GlassAlertDialog `scrollable`
        // ile zaten kaydırma sağlıyor. İç içe iki dikey kaydırma jest'i yutup
        // sürüklemeyi engelliyordu (kullanıcı "yukarı/aşağı sürükleyemiyorum").
        title: Text('settings.dialog.changelogTitle'.tr),
        content: Text(
          'settings.dialog.changelogBody'.tr,
          style: TextStyle(
            color: Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.9),
            height: 1.45,
          ),
        ),
        actions: [
          GlassDialogActionButton(
            label: 'common.close'.tr,
            primary: true,
            onPressed: () => Navigator.pop(c),
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
          GlassDialogActionButton(
            label: 'common.ok'.tr,
            primary: true,
            onPressed: () => Navigator.pop(c),
          ),
        ],
      ),
    );
  }

  Future<void> reportIssue() async {
    final diag = await SupportDiagnostics.buildSupportAppendix();
    final body = 'settings.mail.body'.trParams({'diag': diag});

    if (isSentryConfigured) {
      try {
        await Sentry.addBreadcrumb(
          Breadcrumb(
            category: 'support',
            message: 'User opened issue email composer',
            level: SentryLevel.info,
          ),
        );
      } catch (_) {}
    }

    final uri = Uri(
      scheme: 'mailto',
      path: 'furkangumrukcu07@gmail.com',
      queryParameters: {
        'subject': 'settings.mail.subject'.tr,
        'body': body,
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
          GlassDialogActionButton(
            label: 'common.close'.tr,
            primary: true,
            onPressed: () => Navigator.pop(c),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // User-Agent: IPTV oynatıcısı için seçilen UA. Stalker/Ministra panelleri
  // belirli bir UA bekleyebilir; "Özel" seçeneği ile kullanıcı kendi UA'sını
  // girebilir. Tüm değişiklikler `IptvPlaybackDefaults.effectiveUserAgent`
  // üzerinden anında player isteklerine yansır.
  // ---------------------------------------------------------------------------

  String get playbackUserAgentSubtitle {
    final id = _app.playbackUserAgentId.value;
    if (id == kPlaybackUserAgentCustomId) {
      final custom = _app.playbackUserAgentCustomValue.value.trim();
      if (custom.isEmpty) {
        return 'settings.tile.userAgent.subCustomEmpty'.tr;
      }
      return 'settings.tile.userAgent.subCustom'.trParams({
        'v': _shortenUserAgent(custom),
      });
    }
    final preset = playbackUserAgentPresetById(id);
    return preset.label;
  }

  static String _shortenUserAgent(String s) {
    if (s.length <= 48) return s;
    return '${s.substring(0, 48)}…';
  }

  Future<void> showPlaybackUserAgentDialog() async {
    final ctx = Get.context;
    if (ctx == null) return;

    var selectedId = _app.playbackUserAgentId.value;
    final customController = TextEditingController(
      text: _app.playbackUserAgentCustomValue.value,
    );

    await showDialog<void>(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return GlassAlertDialog(
            scrollable: true,
            title: Text('settings.dialog.userAgent.title'.tr),
            content: SizedBox(
              width: 380,
              child: RadioGroup<String>(
                groupValue: selectedId,
                onChanged: (v) {
                  if (v == null) return;
                  setDialogState(() => selectedId = v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'settings.dialog.userAgent.hint'.tr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final preset in kPlaybackUserAgentPresets)
                      RadioListTile<String>(
                        value: preset.id,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(preset.label),
                        subtitle: preset.description != null
                            ? Text(
                                preset.description!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 11.5,
                                ),
                              )
                            : null,
                      ),
                    RadioListTile<String>(
                      value: kPlaybackUserAgentCustomId,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('settings.dialog.userAgent.custom'.tr),
                    ),
                    if (selectedId == kPlaybackUserAgentCustomId) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customController,
                        maxLines: 3,
                        minLines: 2,
                        decoration: InputDecoration(
                          labelText: 'settings.dialog.userAgent.customLabel'.tr,
                          hintText: 'settings.dialog.userAgent.customHint'.tr,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              GlassDialogActionButton(
                label: 'common.cancel'.tr,
                onPressed: () => Navigator.pop(dCtx),
              ),
              GlassDialogActionButton(
                label: 'common.save'.tr,
                primary: true,
                onPressed: () async {
                  if (selectedId == kPlaybackUserAgentCustomId) {
                    final t = customController.text.trim();
                    await _app.setPlaybackUserAgentCustomValue(t);
                    if (t.isEmpty) {
                      // Boş özel değer girildiyse varsayılana dön.
                      await _app.setPlaybackUserAgentPreset(
                        kPlaybackUserAgentDefaultId,
                      );
                    }
                  } else {
                    await _app.setPlaybackUserAgentPreset(selectedId);
                  }
                  if (dCtx.mounted) Navigator.pop(dCtx);
                },
              ),
            ],
          );
        },
      ),
    );

    customController.dispose();
  }
  void showSubscriptionStatusDialog() {
    final ctx = Get.context;
    if (ctx == null) return;
    
    final licensing = LicensingService.to;

    showDialog<void>(
      context: ctx,
      builder: (c) {
        bool buying = false;
        bool restoring = false;
        bool buyingCoffee = false;

        // Satın alım başarılı olursa splash'e git
        ever<bool>(licensing.purchaseCompleted, (completed) {
          if (completed && c.mounted) {
            Navigator.pop(c);
            Get.offAllNamed(AppRoutes.splash);
          }
        });

        return StatefulBuilder(
          builder: (context, setState) {
            final isTv = _app.layoutMode.value == AppLayoutMode.tv;

            return GlassAlertDialog(
              title: Text('settings.subscription.dialog.title'.tr),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Obx(() => _buildDialogInfoRow(
                        'settings.subscription.dialog.status'.tr,
                        licensing.isPremium.value
                            ? (licensing.isGrandfathered.value
                                ? 'settings.subscription.grandfathered'.tr
                                : 'settings.subscription.premiumActive'.tr)
                            : (licensing.isTrialActive.value
                                ? licensing.trialRemainingFormatted
                                : 'settings.subscription.trialExpired'.tr),
                        licensing.isPremium.value ? Colors.greenAccent : Colors.redAccent,
                      )),
                      const SizedBox(height: 12),
                      Obx(() => _buildDialogInfoRow(
                        'settings.subscription.dialog.grandfathered'.tr,
                        licensing.isGrandfathered.value
                            ? 'settings.subscription.dialog.grandfathered.yes'.tr
                            : 'settings.subscription.dialog.grandfathered.no'.tr,
                        licensing.isGrandfathered.value ? Colors.greenAccent : Colors.white70,
                      )),
                      Obx(() {
                        if (licensing.isPremium.value && licensing.purchaseDate.value != null) {
                          final date = licensing.purchaseDate.value!.toLocal();
                          final formattedDate = '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _buildDialogInfoRow(
                              'settings.subscription.dialog.purchaseDate'.tr,
                              formattedDate,
                              Colors.white70,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                      Obx(() {
                        if (!licensing.isPremium.value && licensing.trialExpirationDate.value != null) {
                          final expireDate = licensing.trialExpirationDate.value!.toLocal();
                          final formattedDate = '${expireDate.day}.${expireDate.month}.${expireDate.year} ${expireDate.hour.toString().padLeft(2, '0')}:${expireDate.minute.toString().padLeft(2, '0')}';
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _buildDialogInfoRow(
                              'settings.subscription.dialog.trialEnd'.tr,
                              formattedDate,
                              Colors.white70,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                      Obx(() {
                        if (licensing.isPremium.value) {
                          if (buyingCoffee) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(
                                  color: Colors.greenAccent,
                                  strokeWidth: 3,
                                ),
                              ),
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),
                              const Divider(color: Colors.white12, height: 1),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.withValues(alpha: 0.15),
                                  foregroundColor: Colors.amberAccent,
                                  side: const BorderSide(color: Colors.amber, width: 1),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.coffee_rounded, size: 18),
                                label: Text(
                                  'paywall.button.coffee'.tr,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                onPressed: () async {
                                  setState(() => buyingCoffee = true);
                                  try {
                                    final success = await licensing.buyCoffeeProduct();
                                    if (success) {
                                      Get.snackbar(
                                        'paywall.coffee.success.title'.tr,
                                        'paywall.coffee.success.body'.tr,
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.green.withValues(alpha: 0.85),
                                        colorText: Colors.white,
                                      );
                                    } else {
                                      Get.snackbar(
                                        'paywall.error.title'.tr,
                                        'paywall.error.body'.tr,
                                        snackPosition: SnackPosition.BOTTOM,
                                        backgroundColor: Colors.red.withValues(alpha: 0.85),
                                        colorText: Colors.white,
                                      );
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      setState(() => buyingCoffee = false);
                                    }
                                  }
                                },
                              ),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white12, height: 1),
                            const SizedBox(height: 12),
                            Text(
                              'paywall.title'.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isTv ? 15 : 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDialogFeatureRow(Icons.check_circle_rounded, 'paywall.feature.performance.title'.tr),
                            _buildDialogFeatureRow(Icons.check_circle_rounded, 'paywall.feature.sync.title'.tr),
                            _buildDialogFeatureRow(Icons.check_circle_rounded, 'paywall.feature.keymapping.title'.tr),
                            _buildDialogFeatureRow(Icons.check_circle_rounded, 'paywall.feature.introcutter.title'.tr),
                            const SizedBox(height: 16),
                            if (buying || restoring || buyingCoffee)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(
                                    color: Colors.greenAccent,
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.greenAccent.withValues(alpha: 0.15),
                                      foregroundColor: Colors.greenAccent,
                                      side: const BorderSide(color: Colors.greenAccent, width: 1),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                                    label: Text(
                                      'paywall.button.buy'.tr,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    onPressed: () async {
                                      setState(() => buying = true);
                                      try {
                                        final success = await licensing.buyPremiumProduct();
                                        if (!success && c.mounted) {
                                          Get.snackbar(
                                            'paywall.error.title'.tr,
                                            'paywall.error.body'.tr,
                                            snackPosition: SnackPosition.BOTTOM,
                                            backgroundColor: Colors.red.withValues(alpha: 0.85),
                                            colorText: Colors.white,
                                          );
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setState(() => buying = false);
                                        }
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(color: Colors.white24),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.restore_rounded, size: 16),
                                    label: Text(
                                      'paywall.button.restore'.tr,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    onPressed: () async {
                                      setState(() => restoring = true);
                                      try {
                                        await licensing.triggerRestore();
                                        await Future<void>.delayed(const Duration(seconds: 3));
                                        if (licensing.isPremium.value) {
                                          if (c.mounted) Navigator.pop(c);
                                          Get.offAllNamed(AppRoutes.splash);
                                        } else {
                                          Get.snackbar(
                                            'paywall.restore.title'.tr,
                                            'paywall.restore.body'.tr,
                                            snackPosition: SnackPosition.BOTTOM,
                                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                                            colorText: Colors.white,
                                          );
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setState(() => restoring = false);
                                        }
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.withValues(alpha: 0.15),
                                      foregroundColor: Colors.amberAccent,
                                      side: const BorderSide(color: Colors.amber, width: 1),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.coffee_rounded, size: 18),
                                    label: Text(
                                      'paywall.button.coffee'.tr,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    onPressed: () async {
                                      setState(() => buyingCoffee = true);
                                      try {
                                        final success = await licensing.buyCoffeeProduct();
                                        if (success) {
                                          Get.snackbar(
                                            'paywall.coffee.success.title'.tr,
                                            'paywall.coffee.success.body'.tr,
                                            snackPosition: SnackPosition.BOTTOM,
                                            backgroundColor: Colors.green.withValues(alpha: 0.85),
                                            colorText: Colors.white,
                                          );
                                        } else {
                                          Get.snackbar(
                                            'paywall.error.title'.tr,
                                            'paywall.error.body'.tr,
                                            snackPosition: SnackPosition.BOTTOM,
                                            backgroundColor: Colors.red.withValues(alpha: 0.85),
                                            colorText: Colors.white,
                                          );
                                        }
                                      } finally {
                                        if (context.mounted) {
                                          setState(() => buyingCoffee = false);
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                GlassDialogActionButton(
                  label: 'common.close'.tr,
                  onPressed: () => Navigator.pop(c),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: Colors.greenAccent, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(String label, String value, Color valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
