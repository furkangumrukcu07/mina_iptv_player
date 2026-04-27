import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// İzlemeye Devam Et servisi
/// - VOD izleme ilerlemesini kaydeder
/// - Throttling: 10 saniyede bir kayıt
/// - Bellek optimizasyonu: Static cache
class ContinueWatchingService extends GetxService {
  static ContinueWatchingService get to => Get.find<ContinueWatchingService>();
  
  static const String _prefsKey = 'continue_watching_items';
  static const int _maxItems = 20; // Maksimum 20 öğe sakla
  static const int _minProgressDeltaMs = 15000;
  
  // Throttling için
  DateTime? _lastSaveTime;
  static const Duration _saveThrottle = Duration(seconds: 10);
  
  // Bellek cache'i
  List<ContinueWatchingItem>? _cachedItems;
  bool _isDirty = false;
  
  // Timer
  Timer? _saveTimer;
  
  @override
  void onInit() {
    super.onInit();
    _loadFromPrefs();
  }
  
  @override
  void onClose() {
    _saveTimer?.cancel();
    // Son kaydetme
    if (_isDirty) {
      _saveImmediately();
    }
    super.onClose();
  }
  
  /// VOD izleme ilerlemesini kaydet (throttled)
  void saveProgress({
    required int vodId,
    required String title,
    required String? coverUrl,
    required int positionMs,
    required int durationMs,
  }) {
    if (durationMs <= 0) return;
    
    final progressPercent = (positionMs / durationMs * 100).clamp(0, 100);
    
    // %95'ten fazla izlendiyse kaldır
    if (progressPercent > 95) {
      removeItem(vodId);
      return;
    }
    
    // Cache'den al
    final items = _cachedItems ?? [];
    
    // Aynı VOD varsa güncelle, yoksa ekle
    final existingIndex = items.indexWhere((item) => item.vodId == vodId);
    
    final newItem = ContinueWatchingItem(
      vodId: vodId,
      title: title,
      coverUrl: coverUrl,
      positionMs: positionMs,
      durationMs: durationMs,
      progressPercent: progressPercent.toDouble(),
      lastUpdated: DateTime.now(),
    );
    
    if (existingIndex >= 0) {
      final prev = items[existingIndex];
      final sameDuration = prev.durationMs == durationMs;
      final delta = (positionMs - prev.positionMs).abs();
      // Çok küçük ilerleme güncellemelerinde yazmayı atla.
      if (sameDuration && delta < _minProgressDeltaMs) {
        return;
      }
      items[existingIndex] = newItem;
    } else {
      items.insert(0, newItem); // En başa ekle
    }
    
    // Maksimum sınıra göre kırp
    if (items.length > _maxItems) {
      items.removeRange(_maxItems, items.length);
    }
    
    _cachedItems = items;
    _isDirty = true;
    
    // Throttle kontrolü
    _scheduleSave();
  }
  
  void _scheduleSave() {
    final now = DateTime.now();
    
    // Son kayıttan 10 saniye geçtiyse hemen kaydet
    if (_lastSaveTime == null || 
        now.difference(_lastSaveTime!) >= _saveThrottle) {
      _saveImmediately();
      return;
    }
    
    // Yoksa timer ayarla
    _saveTimer?.cancel();
    final remaining = _saveThrottle - now.difference(_lastSaveTime!);
    _saveTimer = Timer(remaining, _saveImmediately);
  }
  
  void _saveImmediately() async {
    if (!_isDirty || _cachedItems == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _cachedItems!.map((item) => item.toJson()).toList();
      await prefs.setString(_prefsKey, jsonEncode(jsonList));
      _lastSaveTime = DateTime.now();
      _isDirty = false;
    } catch (e) {
      // Silent fail - log olmadan
    }
  }
  
  void _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final jsonList = jsonDecode(jsonStr) as List;
        _cachedItems = jsonList
            .map((j) => ContinueWatchingItem.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      _cachedItems = [];
    }
  }
  
  /// Öğeyi kaldır
  void removeItem(int vodId) {
    if (_cachedItems == null) return;
    _cachedItems!.removeWhere((item) => item.vodId == vodId);
    _isDirty = true;
    _scheduleSave();
  }
  
  /// Tüm öğeleri getir
  List<ContinueWatchingItem> getContinueWatchingItems() {
    return _cachedItems ?? [];
  }
  
  /// Öğe sayısı
  int get itemCount => _cachedItems?.length ?? 0;
  
  /// Boş mu?
  bool get isEmpty => itemCount == 0;
}

/// İzlemeye Devam Et öğesi modeli
class ContinueWatchingItem {
  final int vodId;
  final String title;
  final String? coverUrl;
  final int positionMs;
  final int durationMs;
  final double progressPercent;
  final DateTime lastUpdated;
  
  const ContinueWatchingItem({
    required this.vodId,
    required this.title,
    this.coverUrl,
    required this.positionMs,
    required this.durationMs,
    required this.progressPercent,
    required this.lastUpdated,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'vodId': vodId,
      'title': title,
      'coverUrl': coverUrl,
      'positionMs': positionMs,
      'durationMs': durationMs,
      'progressPercent': progressPercent,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
  
  factory ContinueWatchingItem.fromJson(Map<String, dynamic> json) {
    return ContinueWatchingItem(
      vodId: json['vodId'] as int,
      title: json['title'] as String,
      coverUrl: json['coverUrl'] as String?,
      positionMs: json['positionMs'] as int,
      durationMs: json['durationMs'] as int,
      progressPercent: (json['progressPercent'] as num).toDouble(),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }
}
