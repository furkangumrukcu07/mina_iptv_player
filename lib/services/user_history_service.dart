import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/debounced_prefs_writer.dart';

/// İçerik türü — AI öneri motoru için kullanıcı izleme alışkanlığı kategorisi.
enum UserHistoryKind { live, vod, series }

/// Tek bir izleme oturumu kaydı.
/// 2 dakika ve üzeri izlemeler [UserHistoryService.record] çağrısıyla
/// yerel depoya yazılır. AI öneri motoru bu kayıtları okuyarak en sevilen
/// kategorileri ve saat-dilimi profilini çıkarır.
class UserHistoryEntry {
  const UserHistoryEntry({
    required this.kind,
    required this.contentId,
    required this.name,
    required this.categoryId,
    this.categoryName,
    this.posterUrl,
    required this.timestampMs,
    required this.watchedSeconds,
  });

  final UserHistoryKind kind;
  final int contentId;
  final String name;
  final String categoryId;
  final String? categoryName;
  final String? posterUrl;
  final int timestampMs;
  final int watchedSeconds;

  /// 0-23 yerel saat.
  int get hour =>
      DateTime.fromMillisecondsSinceEpoch(timestampMs).toLocal().hour;

  /// AI motorunun günün dilimi etiketi.
  UserHistoryTimeBand get timeBand => timeBandOf(hour);

  Map<String, dynamic> toJson() => {
        'k': kind.index,
        'id': contentId,
        'n': name,
        'c': categoryId,
        if (categoryName != null) 'cn': categoryName,
        if (posterUrl != null) 'p': posterUrl,
        't': timestampMs,
        'w': watchedSeconds,
      };

  static UserHistoryEntry? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw;
    final ki = (m['k'] as num?)?.toInt();
    if (ki == null || ki < 0 || ki >= UserHistoryKind.values.length) return null;
    final id = (m['id'] as num?)?.toInt();
    final t = (m['t'] as num?)?.toInt();
    if (id == null || t == null) return null;
    final name = (m['n'] ?? '').toString();
    final cat = (m['c'] ?? '').toString();
    final catName = m['cn']?.toString();
    final poster = m['p']?.toString();
    final w = (m['w'] as num?)?.toInt() ?? 0;
    return UserHistoryEntry(
      kind: UserHistoryKind.values[ki],
      contentId: id,
      name: name,
      categoryId: cat,
      categoryName: catName,
      posterUrl: poster,
      timestampMs: t,
      watchedSeconds: w,
    );
  }
}

/// Günün dilimi — AI motorunun saat profili.
enum UserHistoryTimeBand {
  morning, // 05-12
  afternoon, // 12-17
  evening, // 17-22
  night, // 22-05
}

UserHistoryTimeBand timeBandOf(int hour) {
  if (hour >= 5 && hour < 12) return UserHistoryTimeBand.morning;
  if (hour >= 12 && hour < 17) return UserHistoryTimeBand.afternoon;
  if (hour >= 17 && hour < 22) return UserHistoryTimeBand.evening;
  return UserHistoryTimeBand.night;
}

/// Kullanıcının izleme alışkanlıklarını JSON şeklinde yerel depoda tutar.
///
/// Şuna dikkat:
///  * 2 dakikadan kısa oturumlar AI motoruna sinyal göndermez; [record]
///    sadece 120 sn ve üzeri için çağrılır (player bu eşiği uygular).
///  * Aynı içerik kısa süre içinde tekrar tekrar kaydedilirse (örn. uygulama
///    geri-ileri sarımı) son kayıt güncellenir, böylece liste şişmez.
///  * Liste en fazla [_kMaxEntries] kayıt tutar; FIFO atılır.
class UserHistoryService extends GetxService {
  static const _kKey = 'mina_user_history_v1';
  static const int _kMaxEntries = 400;

  /// Aynı içeriğin son kaydından bu kadar süre geçmediyse, yeni kayıt
  /// eklemek yerine var olan kayıt günceller (sayıyı şişirmemek için).
  static const Duration _kDedupWindow = Duration(minutes: 30);

  /// AI motorunun ihtiyaç duyduğunda son N kayıt yeterli sayılır. Önbellek.
  List<UserHistoryEntry>? _cache;
  bool _loaded = false;

  late final DebouncedPrefsWriter _prefsWriter = DebouncedPrefsWriter(
    getPrefs: SharedPreferences.getInstance,
    delay: const Duration(seconds: 2),
  );

  /// **Rx tetikleyici** — her [record] / [clear] çağrısında 1 artar.
  ///
  /// `Obx` içeren widget'lar bu sayacı dinleyerek (`.value` okuyarak)
  /// UserHistory snapshot'ı senkron olarak okuyup re-render olabilir.
  /// Örn. Canlı TV kategorileri "Son İzlenenler" satırı, Film & Dizi
  /// "Son İzlenenler" şeridi.
  final RxInt revision = 0.obs;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kKey);
      if (raw == null || raw.isEmpty) {
        _cache = <UserHistoryEntry>[];
      } else {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final list = <UserHistoryEntry>[];
          for (final item in decoded) {
            final e = UserHistoryEntry.tryFromJson(item);
            if (e != null) list.add(e);
          }
          _cache = list;
        } else {
          _cache = <UserHistoryEntry>[];
        }
      }
    } catch (_) {
      _cache = <UserHistoryEntry>[];
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    try {
      final list = (_cache ?? const <UserHistoryEntry>[])
          .map((e) => e.toJson())
          .toList(growable: false);
      // jsonEncode ana isolate'te kısa; disk yazımı debounce ile (ANR).
      _prefsWriter.scheduleString(_kKey, jsonEncode(list));
    } catch (_) {}
  }

  /// İçerik 2 dakika veya daha uzun izlendiğinde çağırılır.
  ///
  /// [watchedSeconds] o oturumda gerçekten izlenen toplam saniyedir
  /// (player tarafında ölçülür). Aynı içeriğe yapılan kısa aralıklı çağrılar
  /// son kaydı günceller; ayrı sinyal saymaz.
  Future<void> record({
    required UserHistoryKind kind,
    required int contentId,
    required String name,
    required String categoryId,
    String? categoryName,
    String? posterUrl,
    required int watchedSeconds,
  }) async {
    if (watchedSeconds < 120) return;
    await _ensureLoaded();
    final now = DateTime.now().millisecondsSinceEpoch;
    final list = _cache ?? <UserHistoryEntry>[];

    final dedupCutoff = now - _kDedupWindow.inMilliseconds;
    final idx = list.lastIndexWhere((e) =>
        e.kind == kind &&
        e.contentId == contentId &&
        e.timestampMs >= dedupCutoff);
    final entry = UserHistoryEntry(
      kind: kind,
      contentId: contentId,
      name: name,
      categoryId: categoryId,
      categoryName: categoryName,
      posterUrl: posterUrl,
      timestampMs: now,
      watchedSeconds: watchedSeconds,
    );
    if (idx >= 0) {
      list[idx] = entry;
    } else {
      list.add(entry);
    }

    // FIFO — sondaki son N kayıt korunur.
    if (list.length > _kMaxEntries) {
      list.removeRange(0, list.length - _kMaxEntries);
    }
    _cache = list;
    await _persist();
    revision.value++;
  }

  /// En yeniden eskiye doğru tüm geçmiş.
  Future<List<UserHistoryEntry>> getAll() async {
    await _ensureLoaded();
    final list = List<UserHistoryEntry>.from(_cache ?? const []);
    list.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    return list;
  }

  /// AI motorunun senkron erişimi — boşsa boş liste döndürür.
  /// İlk açılışta [_ensureLoaded] henüz çalışmamışsa boş döner.
  List<UserHistoryEntry> snapshotSync() {
    return List<UserHistoryEntry>.from(_cache ?? const []);
  }

  /// Tüm geçmişi temizle (kullanıcı isteğine bağlı ileri özellik için).
  Future<void> clear() async {
    _cache = <UserHistoryEntry>[];
    _loaded = true;
    try {
      _prefsWriter.scheduleRemove(_kKey);
      await _prefsWriter.flush();
    } catch (_) {}
    revision.value++;
  }

  @override
  void onInit() {
    super.onInit();
    unawaited(_ensureLoaded());
  }

  @override
  void onClose() {
    unawaited(_prefsWriter.flush());
    _prefsWriter.dispose();
    super.onClose();
  }
}
