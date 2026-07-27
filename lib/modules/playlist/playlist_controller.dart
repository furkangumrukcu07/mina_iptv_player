import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/constants/playlist_storage.dart';
import '../../core/error/app_exception.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/epg_service.dart';
import '../../core/services/playlist_cache_service.dart';
import '../../core/services/playlist_qr_server_service.dart';
import '../../core/services/toast_service.dart';
import '../../data/local/epg_snapshot_keys.dart';
import '../../data/remote/m3u_xtream_sniffer.dart';
import '../../data/remote/xtream_api.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/playlist_source.dart';
import '../../domain/entities/stalker_compat.dart';
import '../../data/local/playlist_sqlite_store.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../../ui/glass_overlays.dart';
import 'widgets/playlist_load_summary_dialog.dart';

class PlaylistController extends GetxController {
  final m3uUrlController = TextEditingController();

  final xtreamBaseUrlController = TextEditingController();
  final xtreamUsernameController = TextEditingController();
  final xtreamPasswordController = TextEditingController();

  final stalkerBaseUrlController = TextEditingController();
  final stalkerMacAddressController = TextEditingController();
  final stalkerHwVersionController = TextEditingController();

  /// MAG uyumluluk ön ayarları (giriş formu).
  final stalkerMagPreset = StalkerMagPreset.genericSafe.obs;
  final stalkerLinkType = StalkerLinkType.wifi.obs;

  final m3uSecondaryUrlController = TextEditingController();
  final xtreamSecondaryBaseUrlController = TextEditingController();
  final xtreamSecondaryUsernameController = TextEditingController();
  final xtreamSecondaryPasswordController = TextEditingController();

  final _repo = Get.find<PlaylistRepository>();
  final _cache = Get.find<PlaylistCacheService>();

  /// 0 = M3U (sol / ilk sekme), 1 = Xtream, 2 = Stalker.
  final tabIndex = 0.obs;

  /// 0 = M3U, 1 = Xtream — birincil ile aynı sıra.
  final secondaryTabIndex = 0.obs;
  final enableSecondary = false.obs;
  final isLoading = false.obs;
  final m3uLocalFileName = RxnString();
  final m3uSecondaryLocalFileName = RxnString();

  final canSubmit = false.obs;

  // M3U listesi yüklü mi kontrolü
  final isM3uLoaded = false.obs;

  /// Kurulum sihirbazı: başarıda [AppRoutes.home] yerine [setupWizardOnSuccess].
  bool setupWizardCompletionMode = false;
  void Function()? setupWizardOnSuccess;

  void _navigateAfterPlaylistLoad() {
    // İlk playlist yüklemesinde splash atlanır, dolayısıyla Xtream EPG'sini
    // arka planda burada başlatıyoruz (M3U → Xtream dönüşümü dahil her durum
    // için tek noktada). Kaynak persist edilmiş olduğundan readSource() güvenli.
    unawaited(_repo.readSource().then((src) {
      if (src != null) _kickoffXtreamEpgIfNeeded(src);
    }).catchError((_) {}));

    if (setupWizardCompletionMode && setupWizardOnSuccess != null) {
      setupWizardOnSuccess!();
      return;
    }
    Get.offAllNamed(AppRoutes.home);
  }

  /// Şu an açık olan yükleme özeti dialog'unun ilerleme notifier'ı. Submit
  /// anında [_openLoadSummaryDialog] tarafından oluşturulur, [_finishLoad]
  /// veya [_failLoadSummary] tarafından kapatılır.
  ValueNotifier<PlaylistLoadProgress>? _summaryProgress;

  /// Açıkken dialog kapanmasını izleyen Future — kullanıcı Tamam ya da
  /// **URL'yi Düzelt**'e bastığında tamamlanır. `true` dönerse kullanıcı
  /// URL'yi düzeltmek istiyor demektir; çağıran taraf focus'u alana taşımalı.
  Future<bool?>? _summaryDialogFuture;

  /// Kurulum sihirbazı (TV) veya playlist sayfası tarafından override
  /// edilebilir; verilmezse mevcut [_focusPrimaryM3uUrlField] binding'i
  /// kullanılır. Dialog hata gösterip kullanıcı "URL'yi Düzelt"'e bastığında
  /// çağrılır.
  void Function()? onLoadErrorRetryUrl;

  /// Submit kuyruğu başlar başlamaz dialog'u aç. Tüm satırlar başlangıçta
  /// **yükleniyor** durumundadır. Veri geldiğinde [_finishLoad] çağrılır.
  void _openLoadSummaryDialog() {
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null) return;
    final notifier =
        ValueNotifier<PlaylistLoadProgress>(const PlaylistLoadProgress.loading());
    _summaryProgress = notifier;
    _summaryDialogFuture =
        PlaylistLoadSummaryDialog.show(ctx, progress: notifier);
  }

  /// Yükleme başarılı bittiğinde dialog'a sayıları gönder, kullanıcı
  /// **Tamam**'a basana kadar bekle, sonra navigate et.
  ///
  /// `setupWizardCompletionMode` durumunda da gösteririz — kullanıcı kurulum
  /// sırasında da "kaç kanalı/filmi/dizisi yüklendi" özetini görmeli.
  Future<({int films, int series})> _loadSummaryCounts(M3uResult result) async {
    if (result.vod.isNotEmpty || result.series.isNotEmpty) {
      return (films: result.vod.length, series: result.series.length);
    }
    final dbKey = _cache.dbSourceKey.value ?? await _repo.slotDbKey(0);
    if (dbKey == null || dbKey.isEmpty) {
      return (films: result.vod.length, series: result.series.length);
    }
    return (
      films: await PlaylistSqliteStore.vodCount(dbKey),
      series: await PlaylistSqliteStore.seriesCount(dbKey),
    );
  }

  /// M3U→Xtream dönüşümü sonucu "boş" mu? Panel `player_api.php`'yi kısıtlayıp
  /// hiç kanal/film/dizi döndürmediğinde true; bu durumda ham M3U (`get.php`)
  /// genelde dolu olduğu için ona düşülür.
  static bool _isXtreamResultEmpty(M3uResult r) =>
      r.channels.isEmpty && r.vod.isEmpty && r.series.isEmpty;

  Future<void> _finishLoad(M3uResult result) async {
    final notifier = _summaryProgress;
    if (notifier == null) {
      // Dialog hiç açılmamışsa (Get.context yoktu) direkt yönlendir.
      _navigateAfterPlaylistLoad();
      return;
    }
    final counts = await _loadSummaryCounts(result);
    notifier.value = PlaylistLoadProgress.done(
      liveChannelCount: result.channels.length,
      filmCount: counts.films,
      seriesCount: counts.series,
    );
    final future = _summaryDialogFuture;
    if (future != null) {
      try {
        await future;
      } finally {
        _summaryProgress = null;
        _summaryDialogFuture = null;
        notifier.dispose();
      }
    } else {
      _summaryProgress = null;
      notifier.dispose();
    }
    _navigateAfterPlaylistLoad();
  }

  /// Yükleme hata ile sonlandı — dialog AÇIK kalır ve hata bölümünü gösterir.
  /// Kullanıcı **URL'yi Düzelt**'e basarsa [onLoadErrorRetryUrl] çağrılır.
  /// Dialog hiç açılmamışsa eski davranış: toast.
  Future<void> _failLoadSummary(
    String message, {
    String hint = '',
    bool canRetryUrl = true,
    String? title,
  }) async {
    final notifier = _summaryProgress;
    final future = _summaryDialogFuture;
    if (notifier == null || future == null) {
      // Dialog yok — geri toast'a düş.
      Get.find<ToastService>().show(message, isError: true);
      return;
    }
    notifier.value = PlaylistLoadProgress.error(
      errorTitle: title ?? 'playlist.summary.errorTitle'.tr,
      errorMessage: message,
      errorHint: hint,
      canRetryUrl: canRetryUrl,
    );
    final retry = await future;
    _summaryProgress = null;
    _summaryDialogFuture = null;
    notifier.dispose();
    if (retry == true && canRetryUrl) {
      final cb = onLoadErrorRetryUrl ?? _focusPrimaryM3uUrlField;
      cb?.call();
    }
  }

  /// Geri uyumluluk — dialog'u zorla kapatır (eski hata akışı için).
  void _abortLoadSummary() {
    final notifier = _summaryProgress;
    final future = _summaryDialogFuture;
    if (notifier == null && future == null) return;
    if (Get.isDialogOpen ?? false) {
      Get.back<void>();
    }
    _summaryProgress = null;
    _summaryDialogFuture = null;
    notifier?.dispose();
  }

  /// HTTPS başarısızsa `http://...` öner; tersi de geçerli. Kullanıcının
  /// yazdığı şema soldaki butonda gösterilmez — sadece ipucu satırı.
  String _suggestSchemeSwap(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (lower.startsWith('https://')) {
      return 'playlist.error.hint.tryHttp'.tr;
    }
    if (lower.startsWith('http://')) {
      return 'playlist.error.hint.tryHttps'.tr;
    }
    return 'playlist.error.hint.addScheme'.tr;
  }

  /// `NetworkException` / `ParseException` mesajından kullanıcıya gösterilecek
  /// insan okunabilir mesaj ve ipucu üretir.
  ({String message, String hint}) _humanizeUrlError(
    Object error, {
    required String url,
  }) {
    final raw = error is AppException ? error.message : error.toString();
    final lower = raw.toLowerCase();

    String message = raw;
    String hint = _suggestSchemeSwap(url);

    if (lower.contains('handshake') ||
        lower.contains('certificate') ||
        lower.contains('ssl') ||
        lower.contains('tls') ||
        lower.contains('x509')) {
      message = 'playlist.error.url.ssl'.tr;
      hint = 'playlist.error.hint.tryHttp'.tr;
    } else if (lower.contains('host lookup') ||
        lower.contains('nodename nor servname') ||
        lower.contains('failed host lookup') ||
        lower.contains('no address associated') ||
        lower.contains('unknown host')) {
      message = 'playlist.error.url.host'.tr;
    } else if (lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('zaman aşımı')) {
      message = 'playlist.error.url.timeout'.tr;
    } else if (lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed') ||
        lower.contains('connection terminated') ||
        lower.contains('software caused connection')) {
      message = 'playlist.error.url.refused'.tr;
    } else if (lower.contains('http 401') || lower.contains('http 403')) {
      message = 'playlist.error.url.auth'.tr;
      hint = '';
    } else if (lower.contains('http 404')) {
      message = 'playlist.error.url.notFound'.tr;
    } else if (lower.contains('http 5')) {
      message = 'playlist.error.url.server'.tr;
    } else if (lower.contains('empty response') ||
        lower.contains('m3u content is empty') ||
        lower.contains('playlist url is empty')) {
      message = 'playlist.error.url.empty'.tr;
    } else if (lower.contains('failed to load playlist') ||
        lower.contains('network error')) {
      message = 'playlist.error.url.network'.tr;
    }
    return (message: message, hint: hint);
  }

  /// İlk playlist yüklemesinden sonra Xtream EPG'sini arka planda indirir;
  /// kullanıcı yeniden başlatma yapmadan EPG'yi görebilsin diye gerekli.
  /// Splash akışı zaten `XtreamSource` algıladığında aynı kanaldan yüklüyor
  /// olduğundan, throttle/in-flight paylaşımı sayesinde çift indirme olmaz.
  void _kickoffXtreamEpgIfNeeded(PlaylistSource source) {
    if (source is! XtreamSource) return;
    if (!Get.isRegistered<EpgService>()) return;

    Future<void>.microtask(() async {
      try {
        final epg = Get.find<EpgService>();
        final app = Get.find<AppSettingsService>();
        final mode = app.xtreamEpgSourceMode.value;
        if (mode == XtreamEpgSourceMode.githubOnly) return;
        final api = XtreamApi(
          baseUrl: source.baseUrl,
          username: source.username,
          password: source.password,
        );
        await epg.loadXtreamAllLiveEpg(api, force: true);
        final cacheKey = EpgSnapshotKeys.logicalKeyFor(source, app);
        if (cacheKey != null && epg.hasLoadedGuideData()) {
          await epg.persistSnapshotToDisk(cacheKey);
        }
      } catch (_) {
        // sessiz: splash sonraki açılışta tekrar deneyecek
      }
    });
  }

  String? _m3uLocalRaw;
  String? _m3uSecondaryLocalRaw;
  String? _m3uLocalFilePath;
  String? _m3uSecondaryLocalFilePath;

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

    m3uUrlController.addListener(_updateSubmitState);
    xtreamBaseUrlController.addListener(_updateSubmitState);
    xtreamUsernameController.addListener(_updateSubmitState);
    xtreamPasswordController.addListener(_updateSubmitState);

    stalkerBaseUrlController.addListener(_updateSubmitState);
    stalkerMacAddressController.addListener(_updateSubmitState);

    m3uSecondaryUrlController.addListener(_updateSubmitState);
    xtreamSecondaryBaseUrlController.addListener(_updateSubmitState);
    xtreamSecondaryUsernameController.addListener(_updateSubmitState);
    xtreamSecondaryPasswordController.addListener(_updateSubmitState);

    ever(tabIndex, (_) => _updateSubmitState());
    ever(secondaryTabIndex, (_) => _updateSubmitState());
    ever(enableSecondary, (_) => _updateSubmitState());
    ever(m3uLocalFileName, (_) => _updateSubmitState());
    ever(m3uSecondaryLocalFileName, (_) => _updateSubmitState());

    Future.microtask(_prefillFromStorage);
  }

  void _updateSubmitState() {
    bool primaryOk = false;
    if (tabIndex.value == 0) {
      primaryOk = m3uUrlController.text.trim().isNotEmpty ||
          m3uLocalFileName.value != null;
    } else if (tabIndex.value == 1) {
      primaryOk = xtreamBaseUrlController.text.trim().isNotEmpty &&
          xtreamUsernameController.text.trim().isNotEmpty &&
          xtreamPasswordController.text.trim().isNotEmpty;
    } else {
      primaryOk = stalkerBaseUrlController.text.trim().isNotEmpty &&
          stalkerMacAddressController.text.trim().isNotEmpty;
    }

    if (!enableSecondary.value) {
      canSubmit.value = primaryOk;
      return;
    }

    bool secondaryOk = false;
    if (secondaryTabIndex.value == 0) {
      secondaryOk = m3uSecondaryUrlController.text.trim().isNotEmpty ||
          m3uSecondaryLocalFileName.value != null;
    } else {
      secondaryOk = xtreamSecondaryBaseUrlController.text.trim().isNotEmpty &&
          xtreamSecondaryUsernameController.text.trim().isNotEmpty &&
          xtreamSecondaryPasswordController.text.trim().isNotEmpty;
    }

    canSubmit.value = primaryOk && secondaryOk;
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
      isM3uLoaded.value =
          false; // Secondary URL değişiminde yükleme durumunu sıfırla
    }
  }

  void clearPickedM3uFile() {
    _m3uLocalRaw = null;
    _m3uLocalFilePath = null;
    m3uLocalFileName.value = null;
    isM3uLoaded.value = false; // M3U temizlendiğinde yükleme durumunu sıfırla
    _updateSubmitState();
  }

  void clearPickedM3uSecondaryFile() {
    m3uLocalFileName.value = null;
    m3uSecondaryLocalFileName.value = null;
    _m3uLocalFilePath = null;
    _m3uSecondaryLocalFilePath = null;
    _m3uLocalFilePath = null;
    _m3uSecondaryLocalFilePath = null;
    isM3uLoaded.value = false; // M3U temizlendiğinde yükleme durumunu sıfırla
    _updateSubmitState();
  }

  Future<void> _prefillFromStorage() async {
    try {
      final pri = await _repo.readSource();
      if (pri != null) {
        switch (pri) {
          case M3uSource(:final url):
            tabIndex.value = 0;
            if (isM3uLocalSentinel(url)) {
              m3uLocalFileName.value = 'playlist.label.localM3u'.tr;
            } else {
              m3uUrlController.text = url;
            }
            break;
          case XtreamSource(
              :final baseUrl,
              :final username,
              :final password,
            ):
            tabIndex.value = 1;
            xtreamBaseUrlController.text = baseUrl;
            xtreamUsernameController.text = username;
            xtreamPasswordController.text = password;
            break;
          case StalkerSource(
              :final baseUrl,
              :final macAddress,
              :final magPreset,
              :final linkType,
              :final hwVersionOverride,
            ):
            tabIndex.value = 2;
            stalkerBaseUrlController.text = baseUrl;
            stalkerMacAddressController.text = macAddress;
            stalkerMagPreset.value = magPreset;
            stalkerLinkType.value = linkType;
            stalkerHwVersionController.text = hwVersionOverride;
            break;
        }
      }

      final sec = await _repo.readSecondarySource();
      if (sec == null) {
        _updateSubmitState();
        return;
      }
      enableSecondary.value = true;
      switch (sec) {
        case M3uSource(:final url):
          secondaryTabIndex.value = 0;
          if (isM3uLocalSentinel2(url)) {
            m3uSecondaryLocalFileName.value = 'playlist.label.localM3u'.tr;
          } else {
            m3uSecondaryUrlController.text = url;
          }
          break;
        case XtreamSource(
            :final baseUrl,
            :final username,
            :final password,
          ):
          secondaryTabIndex.value = 1;
          xtreamSecondaryBaseUrlController.text = baseUrl;
          xtreamSecondaryUsernameController.text = username;
          xtreamSecondaryPasswordController.text = password;
          break;
        case StalkerSource():
          break;
      }
      _updateSubmitState();
    } catch (_) {
      _updateSubmitState();
    }
  }

  @override
  void onClose() {
    m3uUrlController.removeListener(_onM3uUrlTyped);
    m3uSecondaryUrlController.removeListener(_onM3uSecondaryUrlTyped);
    m3uUrlController.removeListener(_updateSubmitState);
    xtreamBaseUrlController.removeListener(_updateSubmitState);
    xtreamUsernameController.removeListener(_updateSubmitState);
    xtreamPasswordController.removeListener(_updateSubmitState);
    stalkerBaseUrlController.removeListener(_updateSubmitState);
    stalkerMacAddressController.removeListener(_updateSubmitState);
    m3uSecondaryUrlController.removeListener(_updateSubmitState);
    xtreamSecondaryBaseUrlController.removeListener(_updateSubmitState);
    xtreamSecondaryUsernameController.removeListener(_updateSubmitState);
    xtreamSecondaryPasswordController.removeListener(_updateSubmitState);

    m3uUrlController.dispose();
    xtreamBaseUrlController.dispose();
    xtreamUsernameController.dispose();
    xtreamPasswordController.dispose();
    stalkerBaseUrlController.dispose();
    stalkerMacAddressController.dispose();
    stalkerHwVersionController.dispose();
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

  /// **Karekod dialog'undan gelen submission'ı birincil forma yazar ve
  /// otomatik [submit] tetikler.**
  ///
  /// QR sayfasından telefonun M3U veya Xtream verisi `submissionStream`
  /// üzerinden gelir; dialog kapanırken bunu controller'a aktarır.
  void applyQrSubmission(QrPlaylistSubmission sub) {
    switch (sub) {
      case QrM3uSubmission(:final url):
        setTab(0);
        m3uUrlController.text = url;
        m3uLocalFileName.value = null;
        break;
      case QrXtreamSubmission(:final server, :final username, :final password):
        setTab(1);
        xtreamBaseUrlController.text = server;
        xtreamUsernameController.text = username;
        xtreamPasswordController.text = password;
        break;
    }
    _updateSubmitState();
    // Kullanıcı QR ile gönderdiğinde direkt submit istiyor. Dialog
    // kapandıktan hemen sonra çağrı yapılır.
    unawaited(submit());
  }

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
        Get.find<ToastService>().show(
          'playlist.snackbar.badExt'.tr,
          isError: true,
        );
        return;
      }

      if (f.path != null) {
        await _repo.loadFromM3uFile(f.path!);
        _m3uLocalFilePath = f.path!;
        _m3uLocalRaw = null;
      } else if (f.bytes != null) {
        final content = utf8.decode(f.bytes!, allowMalformed: true);
        await _repo.loadFromM3uContent(content);
        _m3uLocalRaw = content;
        _m3uLocalFilePath = null;
      } else {
        Get.find<ToastService>().show(
          'playlist.snackbar.readFail'.tr,
          isError: true,
        );
        return;
      }
      m3uLocalFileName.value = f.name;
      m3uUrlController.clear();
      isM3uLoaded.value = true; // M3U listesi yüklendi olarak işaretle
    } on AppException catch (e) {
      Get.find<ToastService>().show(e.message, isError: true);
    } catch (e) {
      Get.find<ToastService>().show(
        'playlist.snackbar.fileError'.trParams({'e': e.toString()}),
        isError: true,
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

      if (f.path != null) {
        await _repo.loadFromM3uFile(f.path!);
        _m3uSecondaryLocalFilePath = f.path!;
        _m3uSecondaryLocalRaw = null;
      } else if (f.bytes != null) {
        final content = utf8.decode(f.bytes!, allowMalformed: true);
        await _repo.loadFromM3uContent(content);
        _m3uSecondaryLocalRaw = content;
        _m3uSecondaryLocalFilePath = null;
      } else {
        GlassSnackbar.show(
          'playlist.snackbar.file'.tr,
          'playlist.snackbar.readFail'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
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

      _openLoadSummaryDialog();
      final parsedPrimary = await _repo.persistM3uLocalContent(demoM3uContent);
      final cacheLabel = 'Demo Playlist';

      await _repo.clearSecondarySource();
      await _repo.persistMergedPlaylistSnapshot(parsedPrimary);
      isM3uLoaded.value = true; // Demo playlist yüklendi olarak işaretle

      final persisted = await _repo.readSource();
      final m3uK = persisted is M3uSource
          ? AppSettingsService.m3uPreferenceKey(persisted.url)
          : null;

      _cache.setPlaylist(
        value: parsedPrimary,
        url: cacheLabel,
        xtreamPreferenceKey: null,
        m3uLayoutKey: m3uK,
      );

      isLoading.value = false;
      await _finishLoad(parsedPrimary);
    } on AppException catch (e) {
      isLoading.value = false;
      await _failLoadSummary(
        e.message,
        canRetryUrl: false,
      );
    } catch (e) {
      isLoading.value = false;
      await _failLoadSummary(
        e.toString(),
        canRetryUrl: false,
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
        if (_m3uLocalFilePath != null || _m3uLocalRaw != null) {
          // Local M3U file - no validation needed
        } else {
          // Validate M3U URL before loading
          _m3uSource();
        }
      } else if (tabIndex.value == 1) {
        // Validate Xtream credentials before loading
        _xtreamSource();
      } else {
        // Validate Stalker before loading
        _stalkerSource();
      }

      // All validations passed, start loading
      isLoading.value = true;
      // Dialog'u **HEMEN** aç — kullanıcı M3U URL'i / Xtream bilgilerini
      // gönderir göndermez "Canlı kanallar / Filmler / Diziler yükleniyor"
      // satırlarını spinner ile görsün. Veri geldiğinde [_finishLoad]
      // sayıları gönderir ve Tamam butonunu aktifleştirir.
      _openLoadSummaryDialog();

      if (tabIndex.value == 0) {
        if (_m3uLocalFilePath != null) {
          parsedPrimary = await _repo.persistM3uLocalFile(_m3uLocalFilePath!);
          cacheLabel = m3uLocalFileName.value ?? 'playlist.label.localM3u'.tr;
        } else if (_m3uLocalRaw != null) {
          parsedPrimary = await _repo.persistM3uLocalContent(_m3uLocalRaw!);
          cacheLabel = m3uLocalFileName.value ?? 'playlist.label.localM3u'.tr;
        } else {
          final source = _m3uSource();
          // Otomatik biçim: URL'de `output=ts`/`output=m3u8` ipucu varsa
          // `auto` modundaki canlı yayın biçimini buna göre çöz (sniff sonrası
          // `output` parametresi kaybolduğu için orijinal URL'den yakalanır).
          final fmtHint = M3uXtreamSniffer.liveFormatHint(source.url);
          if (fmtHint != null) {
            unawaited(
              Get.find<AppSettingsService>()
                  .applyAutoDetectedLiveStreamFormat(fmtHint),
            );
          }
          // Akıllı dönüşüm: M3U URL'si Xtream tarzı (username/password)
          // parametreleri içeriyorsa kullanıcıya hiçbir şey hissettirmeden
          // doğrudan Xtream API üzerinden yüklüyoruz; EPG/VOD/Series uçları
          // da çalışmış oluyor.
          final converted = M3uXtreamSniffer.toXtreamSource(source.url);
          M3uResult? xtreamLoaded;
          XtreamSource? resolvedXtream;
          if (converted != null) {
            // Xtream sniff başarılı görünse de panel `player_api.php`
            // ucunu kapatabilir veya çok yavaş cevap verebilir. Hata olursa
            // sessiz fallback olarak ham M3U URL'sini deniyoruz; kullanıcı
            // "URL'yi düzelt" diyaloğuyla karşılaşmadan listesi yüklenir.
            //
            // `loadFromXtreamResolved`: kullanıcının yazdığı şema (http/https)
            // sunucuda kapalıysa karşı şemayı **yine Xtream olarak** dener;
            // çalışan base URL'i döndürür.
            try {
              final res = await _repo.loadFromXtreamResolved(
                baseUrl: converted.baseUrl,
                username: converted.username,
                password: converted.password,
              );
              if (_isXtreamResultEmpty(res.result)) {
                // Panel `player_api.php`'yi kısıtlıyor (boş kanal/film/dizi)
                // ama `get.php` (ham M3U) dolu olabilir. Dönüşümü iptal et,
                // aşağıda ham M3U yoluna düş — "içerikler eksik" önlenir.
                if (kDebugMode) debugPrint(
                  '[playlist] Xtream conversion returned empty for '
                  '${converted.baseUrl} → falling back to raw M3U',
                );
                xtreamLoaded = null;
              } else {
                xtreamLoaded = res.result;
                resolvedXtream = XtreamSource(
                  baseUrl: res.resolvedBaseUrl,
                  username: converted.username,
                  password: converted.password,
                );
              }
            } catch (e) {
              if (kDebugMode) debugPrint(
                '[playlist] Xtream sniff failed for ${converted.baseUrl}, '
                'falling back to raw M3U: $e',
              );
              xtreamLoaded = null;
            }
          }

          if (xtreamLoaded != null && resolvedXtream != null) {
            parsedPrimary = xtreamLoaded;
            await _repo.persistSource(resolvedXtream);
            cacheLabel = resolvedXtream.baseUrl;
            // UI durumunu da senkronla — kullanıcı playlist ekranına geri
            // döndüğünde Xtream sekmesinde alanları dolu olarak görsün.
            xtreamBaseUrlController.text = resolvedXtream.baseUrl;
            xtreamUsernameController.text = resolvedXtream.username;
            xtreamPasswordController.text = resolvedXtream.password;
            m3uUrlController.clear();
            tabIndex.value = 1;
            isM3uLoaded.value = true;
          } else {
            // Kullanıcının yazdığı orijinal URL persist edilir; indirme
            // satır akışı + SQLite ile yapılır (dev VOD listelerinde OOM önlenir).
            await _repo.persistSource(source);
            try {
              parsedPrimary = await _repo.loadM3uUrlIntoSlot(1, source.url);
            } catch (e) {
              await _repo.clearSourceAt(1);
              rethrow;
            }
            cacheLabel = source.url;
            isM3uLoaded.value = true;
          }
        }
      } else if (tabIndex.value == 1) {
        final source = _xtreamSource();
        // Xtream sekmesinde de şema otomatik düzeltilir: kullanıcı `https://`
        // yazıp sunucu yalnızca `http://` veriyorsa (veya tersi) çalışan
        // şema bulunur ve o base URL persist edilir.
        final res = await _repo.loadFromXtreamResolved(
          baseUrl: source.baseUrl,
          username: source.username,
          password: source.password,
        );
        parsedPrimary = res.result;
        final resolvedSource = XtreamSource(
          baseUrl: res.resolvedBaseUrl,
          username: source.username,
          password: source.password,
        );
        await _repo.persistSource(resolvedSource);
        cacheLabel = resolvedSource.baseUrl;
        if (res.resolvedBaseUrl != source.baseUrl) {
          xtreamBaseUrlController.text = res.resolvedBaseUrl;
        }
      } else {
        final source = _stalkerSource();
        final res = await _repo.loadFromStalker(
          baseUrl: source.baseUrl,
          macAddress: source.macAddress,
          magPreset: source.magPreset,
          linkType: source.linkType,
          hwVersionOverride: source.hwVersionOverride,
        );
        parsedPrimary = res;
        await _repo.persistSource(source);
        cacheLabel = source.baseUrl;
      }

      if (!enableSecondary.value) {
        await _repo.clearSecondarySource();
        await _repo.persistMergedPlaylistSnapshot(parsedPrimary);
        final xk = tabIndex.value == 1
            ? AppSettingsService.xtreamPreferenceKey(_xtreamSource())
            : (tabIndex.value == 2
                ? AppSettingsService.stalkerPreferenceKey(_stalkerSource())
                : null);
        final persisted = await _repo.readSource();
        final m3uK = persisted is M3uSource
            ? AppSettingsService.m3uPreferenceKey(persisted.url)
            : null;
        _cache.setPlaylist(
          value: parsedPrimary,
          url: cacheLabel,
          xtreamPreferenceKey: xk,
          m3uLayoutKey: m3uK,
        );
        isLoading.value = false;
        await _finishLoad(parsedPrimary);
        return;
      }

      // Validate secondary inputs before loading
      if (secondaryTabIndex.value == 0) {
        if (_m3uSecondaryLocalFilePath != null || _m3uSecondaryLocalRaw != null) {
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
        if (_m3uSecondaryLocalFilePath != null) {
          await _repo.persistM3uLocalFileSecondary(_m3uSecondaryLocalFilePath!);
        } else if (_m3uSecondaryLocalRaw != null) {
          await _repo.persistM3uLocalContentSecondary(_m3uSecondaryLocalRaw!);
        } else {
          final url = m3uSecondaryUrlController.text.trim();
          if (url.isEmpty) {
            final existing = await _repo.readSecondarySource();
            if (existing is! M3uSource || !isM3uLocalSentinel2(existing.url)) {
              throw ParseException('playlist.error.secondaryUrl'.tr);
            }
          } else {
            final fmtHint2 = M3uXtreamSniffer.liveFormatHint(url);
            if (fmtHint2 != null) {
              unawaited(
                Get.find<AppSettingsService>()
                    .applyAutoDetectedLiveStreamFormat(fmtHint2),
              );
            }
            // İkincil link de Xtream-tarzıysa otomatik dönüştür; başarısız
            // olursa ham M3U URL'sine fallback (primary akışla aynı strateji).
            final converted2 = M3uXtreamSniffer.toXtreamSource(url);
            XtreamSource? resolvedSecondary;
            if (converted2 != null) {
              try {
                final res = await _repo.loadFromXtreamResolved(
                  baseUrl: converted2.baseUrl,
                  username: converted2.username,
                  password: converted2.password,
                );
                if (_isXtreamResultEmpty(res.result)) {
                  if (kDebugMode) debugPrint(
                    '[playlist] Secondary Xtream conversion empty for '
                    '${converted2.baseUrl} → raw M3U fallback',
                  );
                } else {
                  resolvedSecondary = XtreamSource(
                    baseUrl: res.resolvedBaseUrl,
                    username: converted2.username,
                    password: converted2.password,
                  );
                }
              } catch (e) {
                if (kDebugMode) debugPrint(
                  '[playlist] Secondary Xtream sniff failed for '
                  '${converted2.baseUrl}, falling back to raw M3U: $e',
                );
              }
            }
            if (resolvedSecondary != null) {
              await _repo.persistSecondarySource(resolvedSecondary);
              xtreamSecondaryBaseUrlController.text = resolvedSecondary.baseUrl;
              xtreamSecondaryUsernameController.text =
                  resolvedSecondary.username;
              xtreamSecondaryPasswordController.text =
                  resolvedSecondary.password;
              m3uSecondaryUrlController.clear();
              secondaryTabIndex.value = 1;
              isM3uLoaded.value = true;
            } else {
              // Birincil akışla aynı kural: şema swap fallback'i internal
              // fetch sırasında çalışır ama kalıcı kaynak **kullanıcının
              // yazdığı orijinal URL** olur. Kullanıcı `http://` yazdıysa
              // sonraki açılışta yine `http://` görür.
              await _repo.persistSecondarySource(M3uSource(url: url));
              try {
                await _repo.loadM3uUrlIntoSlot(2, url);
              } catch (e) {
                await _repo.clearSourceAt(2);
                rethrow;
              }
              isM3uLoaded.value = true;
            }
          }
        }
      } else {
        final x2 = _xtreamSecondarySource();
        // İkincil Xtream sekmesinde de şema otomatik düzeltilir.
        try {
          final res = await _repo.loadFromXtreamResolved(
            baseUrl: x2.baseUrl,
            username: x2.username,
            password: x2.password,
          );
          final resolved2 = XtreamSource(
            baseUrl: res.resolvedBaseUrl,
            username: x2.username,
            password: x2.password,
          );
          await _repo.persistSecondarySource(resolved2);
          if (res.resolvedBaseUrl != x2.baseUrl) {
            xtreamSecondaryBaseUrlController.text = res.resolvedBaseUrl;
          }
        } catch (_) {
          // Çözümleme başarısızsa kullanıcının yazdığı kaynağı persist et;
          // loadMergedPlaylist sırasında uygun hata yüzeye çıkar.
          await _repo.persistSecondarySource(x2);
        }
      }

      final merged = await _repo.loadMergedPlaylist(
        secondaryOrphanCategoryName: 'playlist.merge.orphanCategory'.tr,
      );
      // loadMergedPlaylist birleşik sonucu SQLite'a yazdıysa `merged` zaten
      // slim'dir (film/dizi RAM'de değil); cache'i DB anahtarıyla besle ki
      // tüketiciler büyük listeleri diskten (sayfalı) okusun.
      final mergedDbKey = _repo.lastMergedDbSourceKey;
      final xk = tabIndex.value == 1
          ? AppSettingsService.xtreamPreferenceKey(_xtreamSource())
          : null;
      final persistedPrimary = await _repo.readSource();
      final m3uK = persistedPrimary is M3uSource
          ? AppSettingsService.m3uPreferenceKey(persistedPrimary.url)
          : null;
      _cache.setPlaylist(
        value: merged,
        url: '$cacheLabel (+2)',
        xtreamPreferenceKey: xk,
        m3uLayoutKey: m3uK,
        dbSourceKey: mergedDbKey,
      );
      isLoading.value = false;
      await _finishLoad(merged);
    } on AppException catch (e) {
      isLoading.value = false;
      await _handleSubmitError(e.message, cause: e);
    } catch (e) {
      isLoading.value = false;
      await _handleSubmitError(e.toString(), cause: e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Submit içinde fırlayan hata için dialog hata akışını yönetir.
  /// * Xtream kimlik hataları → Xtream sekmesinde snackbar (klasik akış).
  /// * URL/ağ/SSL hataları → dialog içinde "URL'yi Düzelt" akışı.
  Future<void> _handleSubmitError(String raw, {Object? cause}) async {
    final t = raw.trim();
    if (t.startsWith('xtream.error.') || t.startsWith('stalker.error.')) {
      _abortLoadSummary();
      _showSubmitError(t, cause: cause);
      return;
    }
    final isM3uTab = tabIndex.value == 0;
    final url = isM3uTab
        ? m3uUrlController.text.trim()
        : (tabIndex.value == 2
            ? stalkerBaseUrlController.text.trim()
            : xtreamBaseUrlController.text.trim());
    final humanized = _humanizeUrlError(cause ?? t, url: url);
    await _failLoadSummary(
      humanized.message,
      hint: humanized.hint,
      canRetryUrl: isM3uTab && url.isNotEmpty,
    );
  }

  /// `xtream.error.*` / `stalker.error.*` anahtarlarını çevirip snackbar gösterir.
  void _showSubmitError(String raw, {Object? cause}) {
    final t = raw.trim();
    // `xtream.error.invalidCredentialsMsg|<panel mesajı>` — panelin mesajı varsa
    // kullanıcıya birebir göstermek faydalı (örn. "User and pass not found").
    if (t.startsWith('xtream.error.invalidCredentialsMsg|')) {
      final panelMessage = t.substring('xtream.error.invalidCredentialsMsg|'.length).trim();
      GlassSnackbar.show(
        'xtream.error.title'.tr,
        'xtream.error.invalidCredentialsWithMsg'
            .trParams({'m': panelMessage}),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
      return;
    }
    if (t == 'xtream.error.invalidCredentials' ||
        t == 'xtream.error.credentialsEmpty') {
      GlassSnackbar.show(
        'xtream.error.title'.tr,
        t.tr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
      return;
    }
    if (t.startsWith('stalker.error.')) {
      GlassSnackbar.show(
        'stalker.error.title'.tr,
        t.tr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
      return;
    }
    // Ağ / parse hataları (Xtream öncesi M3U vb.) için eski davranış.
    Get.find<ToastService>().show(
      t.startsWith('xtream.error.')
          ? 'xtream.error.title'.tr
          : t,
      isError: true,
    );
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

  StalkerSource _stalkerSource() {
    final baseUrl = stalkerBaseUrlController.text.trim();
    final macAddress = stalkerMacAddressController.text.trim();
    if (baseUrl.isEmpty || macAddress.isEmpty) {
      throw ParseException('stalker.error.credentialsEmpty'.tr);
    }
    final normalized = _normalizeBaseUrl(baseUrl);
    return StalkerSource(
      baseUrl: normalized,
      macAddress: macAddress,
      magPreset: stalkerMagPreset.value,
      linkType: stalkerLinkType.value,
      hwVersionOverride: stalkerHwVersionController.text.trim(),
    );
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
