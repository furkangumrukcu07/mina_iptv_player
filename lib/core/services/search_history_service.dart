import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Arama geçmişi kapsamı — her ekranda kullanıcıya yalnız ilgili kategorinin
/// son aramaları sunulur (canlı kanal araması film/dizi sonuçlarıyla
/// karışmasın).
enum SearchHistoryScope {
  /// Ana ekran birleşik araması (canlı + film + dizi).
  home,

  /// Canlı TV ekranı (yalnız kanallar).
  liveTv,

  /// Film / Dizi gözat ekranı.
  browse,
}

/// Kullanıcının yaptığı **son N (varsayılan 5)** aramayı kapsam başına
/// tutar; arama diyalogu açıldığında giriş alanı boşken kullanıcıya tek
/// dokunuşla geri çağırabileceği chip listesi sunarız.
///
/// * Veri **SharedPreferences** içinde saklanır → cihaz yeniden başlasa
///   bile korunur.
/// * Aynı sorgu büyük/küçük harf ayırt etmeksizin tek girdiye düşer; yeni
///   girilince listenin başına alınır (LRU davranışı).
/// * Sınır aşılırsa en eski girdi otomatik atılır.
class SearchHistoryService extends GetxService {
  /// Kapsam başına saklanacak girdi sayısı.
  static const int kMaxEntries = 5;

  /// Tek bir arama metninin azami uzunluğu — UI'da chip taşmasın.
  static const int _kMaxQueryLength = 80;

  /// Singleton kısayolu (GetX dışında kullanmak için).
  static SearchHistoryService get to => Get.find<SearchHistoryService>();

  static const String _kPrefsHome = 'mina_search_history_home_v1';
  static const String _kPrefsLiveTv = 'mina_search_history_live_tv_v1';
  static const String _kPrefsBrowse = 'mina_search_history_browse_v1';

  final RxList<String> _home = <String>[].obs;
  final RxList<String> _liveTv = <String>[].obs;
  final RxList<String> _browse = <String>[].obs;

  bool _loaded = false;
  Future<void>? _loading;

  RxList<String> historyFor(SearchHistoryScope scope) {
    switch (scope) {
      case SearchHistoryScope.home:
        return _home;
      case SearchHistoryScope.liveTv:
        return _liveTv;
      case SearchHistoryScope.browse:
        return _browse;
    }
  }

  String _prefsKey(SearchHistoryScope scope) {
    switch (scope) {
      case SearchHistoryScope.home:
        return _kPrefsHome;
      case SearchHistoryScope.liveTv:
        return _kPrefsLiveTv;
      case SearchHistoryScope.browse:
        return _kPrefsBrowse;
    }
  }

  /// Tüm kapsamların diskten okunmasını sağlar. Birden çok kez çağrılırsa
  /// aynı `Future` döner; servis yaşam döngüsü boyunca diske bir kez gider.
  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final scope in SearchHistoryScope.values) {
        final raw = prefs.getStringList(_prefsKey(scope)) ?? const <String>[];
        final cleaned = <String>[];
        for (final e in raw) {
          final t = e.trim();
          if (t.isEmpty || t.length > _kMaxQueryLength) continue;
          if (cleaned.any((x) => x.toLowerCase() == t.toLowerCase())) continue;
          cleaned.add(t);
          if (cleaned.length >= kMaxEntries) break;
        }
        historyFor(scope).assignAll(cleaned);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SearchHistoryService: load failed: $e');
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  /// Yeni bir aramayı kayda alır. Boş, çok uzun veya yalnızca boşluk içeren
  /// sorgular sessizce yutulur; aynı sorgu zaten varsa listenin başına
  /// taşınır.
  Future<void> record(SearchHistoryScope scope, String? query) async {
    final q = query?.trim();
    if (q == null || q.isEmpty || q.length > _kMaxQueryLength) return;
    await ensureLoaded();
    final list = historyFor(scope);
    final lower = q.toLowerCase();
    final existingIndex =
        list.indexWhere((e) => e.toLowerCase() == lower);
    if (existingIndex == 0) return; // Zaten en üstte — disk yazımı atla.
    if (existingIndex > 0) {
      list.removeAt(existingIndex);
    }
    list.insert(0, q);
    while (list.length > kMaxEntries) {
      list.removeLast();
    }
    await _persist(scope);
  }

  /// Tek bir girdiyi siler (UI'da chip üzerindeki ✕ ikonundan).
  Future<void> remove(SearchHistoryScope scope, String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    await ensureLoaded();
    final list = historyFor(scope);
    final lower = q.toLowerCase();
    final before = list.length;
    list.removeWhere((e) => e.toLowerCase() == lower);
    if (list.length == before) return;
    await _persist(scope);
  }

  /// Tek kapsamın tüm girdilerini temizler.
  Future<void> clear(SearchHistoryScope scope) async {
    await ensureLoaded();
    final list = historyFor(scope);
    if (list.isEmpty) return;
    list.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey(scope));
  }

  Future<void> _persist(SearchHistoryScope scope) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _prefsKey(scope),
        historyFor(scope).toList(growable: false),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('SearchHistoryService: persist($scope) failed: $e');
    }
  }
}
