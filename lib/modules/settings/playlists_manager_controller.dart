import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/constants/playlist_storage.dart';
import '../../core/error/app_exception.dart';
import '../../core/services/active_playlist_service.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/toast_service.dart';
import '../../data/remote/m3u_xtream_sniffer.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/playlist_source.dart';
import '../../data/local/playlist_sqlite_store.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../playlist/widgets/playlist_load_summary_dialog.dart';
/// Tek slot için UI özet kartı verisi.
class PlaylistSlotState {
  const PlaylistSlotState({
    required this.slot,
    required this.source,
    this.disabled = false,
    this.name,
  });

  final int slot;
  final PlaylistSource? source;

  /// Kullanıcı bu slotu devre dışı bıraktı mı? Devre dışı slotlar
  /// birleşik playlist'e dahil edilmez ama silinmez — tekrar açılabilir.
  final bool disabled;

  /// Kullanıcı tanımlı isteğe bağlı etiket (örn. "Spor Paketi"). Null ise
  /// UI varsayılan başlığa düşer.
  final String? name;

  bool get isEmpty => source == null;

  /// Devre dışı bırakılabilir: slot dolu olmalı.
  bool get canToggleDisabled => !isEmpty;

  /// Trim edilmiş, görüntülenecek etiket (boşsa `null` döner).
  String? get displayName {
    final n = name?.trim();
    if (n == null || n.isEmpty) return null;
    return n;
  }

  PlaylistSourceKind get kind {
    final s = source;
    if (s is XtreamSource) return PlaylistSourceKind.xtream;
    if (s is M3uSource) {
      return isAnyM3uLocalSentinel(s.url)
          ? PlaylistSourceKind.m3uLocal
          : PlaylistSourceKind.m3uUrl;
    }
    return PlaylistSourceKind.empty;
  }

  /// İnsan-okunabilir özet (URL / sunucu / dosya).
  String get summary {
    final s = source;
    if (s is XtreamSource) return s.baseUrl;
    if (s is M3uSource) {
      return isAnyM3uLocalSentinel(s.url) ? 'playlist.label.localM3u' : s.url;
    }
    return '';
  }
}

enum PlaylistSourceKind { empty, m3uUrl, m3uLocal, xtream }

/// Settings altında "Liste Yönetimi" sayfasının controller'ı.
class PlaylistsManagerController extends GetxController {
  final _repo = Get.find<PlaylistRepository>();
  final _active = Get.find<ActivePlaylistService>();

  final slots = <PlaylistSlotState>[].obs;
  final isLoading = false.obs;

  /// Aktif slot'un içeriği önbelleğe yüklenirken (liste geçişi sonrası) true.
  final isReloadingMerged = false.obs;

  /// Anahtarla aç/kapa sırasında işlemde olan slot numarası (yoksa null).
  /// İşlem 3-4 sn sürebildiğinden, UI bu slot için anahtarı **iyimser**
  /// (hedef konuma) çevirir ve "açılıyor / kapanıyor" etiketi gösterir.
  final togglingSlot = RxnInt();

  /// [togglingSlot] için hedef durum: true → açılıyor, false → kapanıyor.
  final togglingToEnabled = false.obs;

  int get totalSlots => kMaxPlaylistSlots;
  int get filledCount => slots.where((s) => !s.isEmpty).length;

  /// "Yeni liste ekle" tile'ı için sıradaki boş slot numarası (1..N).
  /// Dolu olan en yüksek slot numarasından bir sonraki; doluluk yoksa 1.
  /// Hard cap'e takılmamak için [kMaxPlaylistSlots] ile sınırlandırılır.
  int get nextEmptySlot {
    var highest = 0;
    for (final s in slots) {
      if (!s.isEmpty && s.slot > highest) highest = s.slot;
    }
    final next = highest + 1;
    if (next > kMaxPlaylistSlots) return kMaxPlaylistSlots;
    return next < 1 ? 1 : next;
  }

  /// Üst sınıra yaklaşıldığında "Yeni ekle" tile'ı gizleyeceğiz.
  bool get canAddMore => filledCount < kMaxPlaylistSlots;

  @override
  void onInit() {
    super.onInit();
    unawaited(reloadSlots());
  }

  /// Diskteki tüm slotları (1..[kMaxPlaylistSlots]) tarar ve yalnızca dolu
  /// olanları + birincil slot (her zaman görünür) + sıradaki tek "Yeni
  /// liste ekle" yer tutucusunu UI listesine koyar.
  ///
  /// Eski sabit 4-slot listesi yerine dinamik — kullanıcı 5, 6, 10. listeyi
  /// eklediğinde de aynı görünür şekilde sıralanır.
  Future<void> reloadSlots() async {
    isLoading.value = true;
    try {
      // Tek `readAll()` turu: kaynak + devre dışı + isim. Eskiden her slot için
      // ayrı `readSourceAt` + `readSlotName` + `readDisabledSlots` çağrılıyordu;
      // yavaş Android Keystore'da 32 slot × method-channel turu ekranı saniyelerce
      // bekletiyordu. Artık hepsi bellek içinde tek turda üretiliyor.
      final slotInfos = await _repo.readAllSlotInfos();
      final filled = <PlaylistSlotState>[
        for (final e in slotInfos)
          PlaylistSlotState(
            slot: e.slot,
            source: e.source,
            disabled: e.disabled,
            name: e.name,
          ),
      ];
      filled.sort((a, b) => a.slot.compareTo(b.slot));

      // Birincil slot (1) her zaman görünür olmalı — kullanıcı henüz
      // listeyi hiç yüklememişse boş slot 1 düzenleme tile'ı olarak görünür.
      final hasPrimary = filled.any((s) => s.slot == 1);
      final next = <PlaylistSlotState>[
        if (!hasPrimary)
          const PlaylistSlotState(slot: 1, source: null),
        ...filled,
      ];

      // Sıradaki boş slotu "Yeni liste ekle" tile'ı olarak ekle.
      if (canAddMoreAfter(next)) {
        final maxFilled =
            next.where((s) => !s.isEmpty).fold<int>(0, (acc, s) => s.slot > acc ? s.slot : acc);
        final nextSlot = maxFilled + 1;
        if (nextSlot <= kMaxPlaylistSlots) {
          next.add(PlaylistSlotState(slot: nextSlot, source: null));
        }
      }

      slots.assignAll(next);
    } catch (e, st) {
      debugPrint('mina_iptv: playlists manager refresh failed: $e\n$st');
    } finally {
      isLoading.value = false;
    }
  }

  /// `slots` listesi sıradaki "yeni ekle" placeholder'ını alabilir mi?
  bool canAddMoreAfter(List<PlaylistSlotState> list) {
    final filled = list.where((s) => !s.isEmpty).length;
    return filled < kMaxPlaylistSlots;
  }

  /// Slot'a M3U URL atar (gerekirse Xtream-sniff dönüşümü yapar) ve cache'i
  /// yeniler.
  ///
  /// 1. **M3U → Xtream sniff:** URL `username`/`password` parametreleri ile
  ///    Xtream paneline işaret ediyorsa Xtream kaynağına çevirip kaydederiz.
  ///    Böylece EPG/VOD/Series uçları otomatik çalışır.
  /// 2. **Şema swap fallback:** İlk denemede bağlantı düzeyi hata alınırsa
  ///    karşı şema (`http`↔`https`) denenir. Persist edilen URL **her zaman
  ///    kullanıcının yazdığı orijinaldir** — pano yapıştırma ile `http`
  ///    yazılmış URL otomatik `https` olarak kaydedilmez.
  /// 3. **Stats popup:** 1. liste yüklemesindeki ile aynı cam diyalog
  ///    (canlı kanal / film / dizi sayısı) gösterilir.
  Future<bool> saveM3uUrl({required int slot, required String url}) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      _toast('playlist.error.url.empty'.tr, isError: true);
      return false;
    }
    // Otomatik biçim: URL'de `output=ts`/`output=m3u8` ipucu varsa `auto`
    // modundaki canlı yayın biçimini buna göre çöz. Sniff XtreamSource'a
    // çevirince `output` parametresi kaybolduğu için burada (orijinal URL
    // eldeyken) yakalanmalı.
    final fmtHint = M3uXtreamSniffer.liveFormatHint(trimmed);
    if (fmtHint != null && Get.isRegistered<AppSettingsService>()) {
      unawaited(
        Get.find<AppSettingsService>()
            .applyAutoDetectedLiveStreamFormat(fmtHint),
      );
    }
    return _saveAndReloadWithSummary(
      slot: slot,
      loadAndPersist: () async {
        // Akıllı dönüşüm (birincil akışla aynı): M3U URL'si Xtream tarzı
        // (`username`/`password`) parametreler içeriyorsa Xtream API'ye
        // çevir. Sniff başarısız olursa ham M3U URL'sine fallback.
        final converted = M3uXtreamSniffer.toXtreamSource(trimmed);
        if (converted != null) {
          try {
            // `loadFromXtreamResolved`: yazılan şema (http/https) sunucuda
            // kapalıysa karşı şemayı yine Xtream olarak dener; çalışan base
            // URL'i persist eder.
            final res = await _repo.loadFromXtreamResolved(
              baseUrl: converted.baseUrl,
              username: converted.username,
              password: converted.password,
            );
            // Panel `player_api.php`'yi kısıtlayıp boş dönerse (kanal+film+dizi
            // hepsi boş) dönüşümü iptal et; aşağıda ham M3U (`get.php`) denenir
            // — "içerikler eksik" sorununu önler.
            if (res.result.channels.isEmpty &&
                res.result.vod.isEmpty &&
                res.result.series.isEmpty) {
              debugPrint(
                '[playlistsManager] Xtream conversion empty for '
                '${converted.baseUrl} → falling back to raw M3U',
              );
            } else {
              await _repo.persistSourceAt(
                slot,
                XtreamSource(
                  baseUrl: res.resolvedBaseUrl,
                  username: converted.username,
                  password: converted.password,
                ),
              );
              return res.result;
            }
          } catch (e) {
            debugPrint(
              '[playlistsManager] Xtream sniff failed for '
              '${converted.baseUrl}, falling back to raw M3U: $e',
            );
          }
        }
        // Bağlantı düzeyi şema swap fallback'i ağ tarafında çalışır
        // (`loadFromM3uUrlResolved`), ancak kullanıcının yazdığı orijinal
        // URL'i persist ederiz — yapıştırılan `http://` URL otomatik
        // `https://`'ye çevrilmez. Bir sonraki açılışta gerekirse aynı
        // fallback yine devreye girer.
        final loaded = await _repo.loadFromM3uUrlResolved(trimmed);
        await _repo.persistSourceAt(slot, M3uSource(url: trimmed));
        return loaded.result;
      },
    );
  }

  /// Slot'a Xtream kaynağı yazar.
  Future<bool> saveXtream({
    required int slot,
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final b = baseUrl.trim();
    final u = username.trim();
    final p = password.trim();
    if (b.isEmpty || u.isEmpty || p.isEmpty) {
      _toast('xtream.error.credentialsEmpty'.tr, isError: true);
      return false;
    }
    return _saveAndReloadWithSummary(
      slot: slot,
      loadAndPersist: () async {
        // `loadFromXtreamResolved` zaten aynı uçları çekiyor, ek olarak
        // M3uResult dönerek summary popup için bant sayılarını veriyor.
        // Şema (http/https) sunucuda kapalıysa karşı şema otomatik denenir.
        final res = await _repo.loadFromXtreamResolved(
          baseUrl: b,
          username: u,
          password: p,
        );
        await _repo.persistSourceAt(
          slot,
          XtreamSource(
            baseUrl: res.resolvedBaseUrl,
            username: u,
            password: p,
          ),
        );
        return res.result;
      },
    );
  }

  /// Cihaz dosya seçicisinden M3U dosyası okur ve slot'a yazar.
  Future<bool> saveM3uFromFilePicker({required int slot}) async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (r == null || r.files.isEmpty) return false;
      final f = r.files.single;
      final name = f.name.toLowerCase();
      if (!name.endsWith('.m3u') &&
          !name.endsWith('.m3u8') &&
          !name.endsWith('.txt')) {
        _toast('playlist.snackbar.badExt'.tr, isError: true);
        return false;
      }
      String content;
      if (f.path != null) {
        content = await File(f.path!).readAsString(encoding: utf8);
      } else if (f.bytes != null) {
        content = utf8.decode(f.bytes!, allowMalformed: true);
      } else {
        _toast('playlist.snackbar.readFail'.tr, isError: true);
        return false;
      }
      return _saveAndReloadWithSummary(
        slot: slot,
        loadAndPersist: () async {
          // persistM3uLocalContentAt parse'i de yapar ve M3uResult döner
          // — summary popup'a bant sayılarını verir.
          return _repo.persistM3uLocalContentAt(slot, content);
        },
      );
    } on AppException catch (e) {
      _toast(e.message, isError: true);
      return false;
    } catch (e) {
      _toast(
        'playlist.snackbar.fileError'.trParams({'e': e.toString()}),
        isError: true,
      );
      return false;
    }
  }

  /// Slot'u mevcut kaynağıyla yeniden yükler. Network'ten taze veri çekip
  /// cache'i yeniler. Sadece dolu slotlar için anlamlı.
  ///
  /// Solo mode tetiklenmez (`isFreshExtra=false` etkisi), kullanıcı sadece
  /// listenin içeriğini tazelemek istiyor.
  Future<bool> refreshSlot({required int slot}) async {
    final state = slots.firstWhereOrNull((s) => s.slot == slot);
    if (state == null || state.isEmpty) {
      _toast('playlistsManager.toast.refreshEmpty'.tr, isError: true);
      return false;
    }
    final src = state.source;
    if (src is M3uSource) {
      final url = src.url;
      if (isAnyM3uLocalSentinel(url)) {
        _toast('playlistsManager.toast.refreshLocalUnsupported'.tr,
            isError: true);
        return false;
      }
      return _saveAndReloadWithSummary(
        slot: slot,
        loadAndPersist: () async {
          final loaded = await _repo.loadFromM3uUrlResolved(url);
          // Kaynak değişmedi → tekrar persist gerekmez ama yan etki olarak
          // disabled bayrağı korunur.
          return loaded.result;
        },
      );
    }
    if (src is XtreamSource) {
      return _saveAndReloadWithSummary(
        slot: slot,
        loadAndPersist: () async {
          final result = await _repo.loadFromXtream(
            baseUrl: src.baseUrl,
            username: src.username,
            password: src.password,
          );
          return result;
        },
      );
    }
    _toast('playlistsManager.toast.refreshUnsupported'.tr, isError: true);
    return false;
  }

  /// Slot'u temizler. Birincil slot (1) dahil her slot silinebilir; ancak
  /// en az bir dolu liste kalmalı — son listeyi silmek engellenir.
  ///
  /// Akış: persist tarafında slot'u temizle + slotları yenile + kullanıcıya
  /// **anında** "silindi" toast'u göster. Merge cache (büyük listelerde
  /// uzun süren kısım) arka planda yenilenir; settings sayfası
  /// `isReloadingMerged.value` reaktif spinner'ı ile gösterir.
  Future<bool> clear({required int slot}) async {
    // En az bir dolu liste kalmalı — tek liste silinemez (uygulama kaynaksız
    // kalmasın). 1. liste de silinebilir; silinince [compactSlots] 2. listeyi
    // fiziksel olarak 1. slota taşır → yeniden açılışta m3u sorulmaz.
    if (filledCount <= 1) {
      _toast('playlistsManager.error.cannotRemoveLast'.tr, isError: true);
      return false;
    }
    isLoading.value = true;
    try {
      final prevActive = _active.activeSlot.value;
      final wasActive = prevActive == slot;
      await _repo.clearSourceAt(slot);
      _active.invalidate(slot);

      // Boşlukları kapat: 1,2,4,5 → 1,2,3,4. Taşınan slotların bellek
      // önbelleği geçersizleşir; aktif slot (silinmeyen) yeni numarasına
      // remap edilir ki "Listeler" barı doğru listeyi seçili göstersin.
      final remap = await _repo.compactSlots();
      if (remap.isNotEmpty) {
        _active.invalidateAll();
        if (!wasActive) {
          final newActive = remap[prevActive];
          if (newActive != null) {
            await _active.remapActiveSlot(newActive);
          }
        }
      }

      await reloadSlots();
      await _active.refreshAvailable();
      // Silinen liste aktifse, geçerli bir listeye geçip içeriği yükle.
      if (wasActive) {
        unawaited(_reloadActiveIntoCache());
      }
      // Kullanıcıya **anında** geri bildirim.
      _toast(
        'playlistsManager.toast.removedN'.trParams({'n': '$slot'}),
        force: true,
      );
      return true;
    } catch (e) {
      _toast(e.toString(), isError: true);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Aktif slot'un içeriğini önbelleğe (yeniden) yükler. Liste silme / devre
  /// dışı bırakma sonrası gösterilen listeyi tazelemek için.
  Future<void> _reloadActiveIntoCache() async {
    isReloadingMerged.value = true;
    try {
      await _active.loadActiveIntoCache(preferSnapshot: true);
    } catch (e) {
      debugPrint('mina_iptv: reload active into cache failed: $e');
    } finally {
      isReloadingMerged.value = false;
    }
  }

  /// Slot'u devre dışı bırakır veya tekrar aktifleştirir. Silmeden geçici
  /// olarak birleşik playlist'ten çıkarır / geri ekler.
  ///
  /// * En az bir slot **aktif** kalmalı — kullanıcı tüm listeleri kapatamaz.
  /// * Slot boşsa (henüz kaynak yok) toggle yapılamaz.
  Future<bool> toggleSlotDisabled({required int slot}) async {
    PlaylistSlotState? current;
    for (final s in slots) {
      if (s.slot == slot) {
        current = s;
        break;
      }
    }
    if (current == null || current.isEmpty) return false;

    final willDisable = !current.disabled;
    if (willDisable) {
      // Devre dışı bırakmadan önce en az bir aktif slot kalacağından emin ol.
      final activeCount =
          slots.where((s) => !s.isEmpty && !s.disabled).length;
      if (activeCount <= 1) {
        _toast('playlistsManager.error.cannotDisableLast'.tr, isError: true);
        return false;
      }
    }

    // Anında geri bildirim — kullanıcı switch'e bastığı anda ne olduğunu
    // görsün (özellikle devre dışı listeyi tekrar açarken). Anahtar iyimser
    // olarak hedef konuma çevrilir ve satırda "açılıyor / kapanıyor" yazar.
    togglingSlot.value = slot;
    togglingToEnabled.value = !willDisable;
    _toast(
      willDisable
          ? 'playlistsManager.toast.disabling'
              .trParams({'n': '$slot'})
          : 'playlistsManager.toast.enabling'.trParams({'n': '$slot'}),
      force: true,
    );

    isLoading.value = true;
    try {
      final wasActive = _active.activeSlot.value == slot;
      await _repo.setSlotDisabled(slot, willDisable);
      await reloadSlots();
      await _active.refreshAvailable();
      // Aktif liste devre dışı bırakıldıysa başka bir listeye geç.
      if (willDisable && wasActive) {
        unawaited(_reloadActiveIntoCache());
      }
      _toast(
        willDisable
            ? 'playlistsManager.toast.disabled'.trParams({'n': '$slot'})
            : 'playlistsManager.toast.enabled'.trParams({'n': '$slot'}),
        force: true,
      );
      return true;
    } catch (e) {
      _toast(e.toString(), isError: true);
      return false;
    } finally {
      isLoading.value = false;
      togglingSlot.value = null;
    }
  }

  /// Slot için kullanıcı tanımlı etiket yazar / temizler. Boş değer
  /// gönderildiğinde varsayılan başlığa (Birincil liste / Liste #N) dönülür.
  /// Slot içeriği boşsa **yine de** etiketi tutarız — kullanıcı önce isim
  /// verip sonra kaynak ekleyebilsin.
  Future<bool> setSlotName({required int slot, required String? name}) async {
    final cleaned = name?.trim();
    try {
      await _repo.writeSlotName(slot, cleaned);
      await reloadSlots();
      // "Listeler" barındaki etiketi güncelle.
      await _active.refreshAvailable();
      return true;
    } catch (e) {
      _toast(e.toString(), isError: true);
      return false;
    }
  }

  /// Slot yazma akışını **1. liste yüklemesindeki ile aynı cam summary
  /// diyaloğu** ile sarmalar. Birleştirme YOK. Akış:
  ///
  /// 1. Diyalog açılır (`loading`).
  /// 2. [loadAndPersist] çağrılır → `M3uResult` döner; slot diske yazılır.
  /// 3. Slot listesi tazelenir.
  /// 4. Diyaloğa **done** + canlı / film / dizi sayıları verilir.
  /// 5. Yeni/yüklenen liste **aktif** liste yapılır ve önbelleğe yazılır —
  ///    kullanıcı eklediği listeyi anında görür. Diğer listelere "Listeler"
  ///    barından geçilir.
  Future<bool> _saveAndReloadWithSummary({
    required int slot,
    required Future<M3uResult> Function() loadAndPersist,
  }) async {
    isLoading.value = true;
    final progress = _openLoadSummaryDialog();
    try {
      final result = await loadAndPersist();
      await reloadSlots();

      final dbKey = await _repo.slotDbKey(slot);
      final filmCount = (dbKey != null &&
              dbKey.isNotEmpty &&
              result.vod.isEmpty)
          ? await PlaylistSqliteStore.vodCount(dbKey)
          : result.vod.length;
      final seriesCount = (dbKey != null &&
              dbKey.isNotEmpty &&
              result.series.isEmpty)
          ? await PlaylistSqliteStore.seriesCount(dbKey)
          : result.series.length;
      progress?.value = PlaylistLoadProgress.done(
        liveChannelCount: result.channels.length,
        filmCount: filmCount,
        seriesCount: seriesCount,
      );

      // Yeni yüklenen listeyi aktif yap + önbelleğe yaz (birleştirme yok).
      // applyKnownResult bellek/disk snapshot'ını da günceller ve "Listeler"
      // barını tazeler.
      await _active.applyKnownResult(slot, result);

      await _awaitSummaryClose();
      return true;
    } on AppException catch (e) {
      progress?.value = PlaylistLoadProgress.error(
        errorTitle: 'playlist.summary.errorTitle'.tr,
        errorMessage: e.message,
        canRetryUrl: false,
      );
      await _awaitSummaryClose();
      return false;
    } catch (e) {
      progress?.value = PlaylistLoadProgress.error(
        errorTitle: 'playlist.summary.errorTitle'.tr,
        errorMessage: e.toString(),
        canRetryUrl: false,
      );
      await _awaitSummaryClose();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // --- Summary diyalogu yardımcıları (1. listedeki ile aynı widget) -------

  ValueNotifier<PlaylistLoadProgress>? _summaryProgress;
  Future<bool?>? _summaryDialogFuture;

  ValueNotifier<PlaylistLoadProgress>? _openLoadSummaryDialog() {
    final ctx = Get.overlayContext ?? Get.context;
    if (ctx == null) return null;
    final notifier = ValueNotifier<PlaylistLoadProgress>(
      const PlaylistLoadProgress.loading(),
    );
    _summaryProgress = notifier;
    _summaryDialogFuture =
        PlaylistLoadSummaryDialog.show(ctx, progress: notifier);
    return notifier;
  }

  Future<void> _awaitSummaryClose() async {
    final fut = _summaryDialogFuture;
    final notifier = _summaryProgress;
    if (fut == null) {
      _summaryProgress = null;
      notifier?.dispose();
      return;
    }
    try {
      await fut;
    } finally {
      _summaryProgress = null;
      _summaryDialogFuture = null;
      notifier?.dispose();
    }
  }

  void _toast(String message, {bool isError = false, bool force = false}) {
    if (Get.isRegistered<ToastService>()) {
      Get.find<ToastService>().show(message, isError: isError, force: force);
    }
  }
}
