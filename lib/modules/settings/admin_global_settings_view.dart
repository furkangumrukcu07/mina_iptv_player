import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../ui/themed_settings_background.dart';

class AdminGlobalSettingsView extends StatefulWidget {
  const AdminGlobalSettingsView({super.key});

  @override
  State<AdminGlobalSettingsView> createState() =>
      _AdminGlobalSettingsViewState();
}

class _AdminGlobalSettingsViewState extends State<AdminGlobalSettingsView> {
  bool _isLoading = true;

  String? _livePlaybackEngine;
  String? _vodPlaybackEngine;
  bool? _epgEnabled;
  String? _tvHomeLayoutMode;
  int? _liveBufferSeconds;
  String? _appLayoutMode; // 'auto', 'mobile', 'tablet', 'tv'
  String? _liveStreamFormat; // 'auto', 'hls', 'ts'
  bool? _backgroundPlayback;
  int? _volumeBoostMaxPercent; // 100, 200, 300, 400
  bool? _isAiRecommendationEnabled;

  int _currentForceUpdateId = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('global_overrides')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _livePlaybackEngine = data['livePlaybackEngine'] as String?;
        _vodPlaybackEngine = data['vodPlaybackEngine'] as String?;
        _epgEnabled = data['epgEnabled'] as bool?;
        _tvHomeLayoutMode = data['tvHomeLayoutMode'] as String?;
        _liveBufferSeconds = data['liveBufferSeconds'] as int?;
        _appLayoutMode = data['appLayoutMode'] as String?;
        _liveStreamFormat = data['liveStreamFormat'] as String?;
        _backgroundPlayback = data['backgroundPlayback'] as bool?;
        _volumeBoostMaxPercent = data['volumeBoostMaxPercent'] as int?;
        _isAiRecommendationEnabled = data['isAiRecommendationEnabled'] as bool?;
        _currentForceUpdateId = data['forceUpdateId'] as int? ?? 0;
      }
    } catch (e) {
      debugPrint('[AdminGlobalSettings] Load Error: $e');
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _applyOverrides() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    Get.dialog(
      const Center(child: CircularProgressIndicator(color: Colors.amberAccent)),
      barrierDismissible: false,
    );

    try {
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('global_overrides')
          .set({
        if (_livePlaybackEngine != null && _livePlaybackEngine!.isNotEmpty)
          'livePlaybackEngine': _livePlaybackEngine,
        if (_vodPlaybackEngine != null && _vodPlaybackEngine!.isNotEmpty)
          'vodPlaybackEngine': _vodPlaybackEngine,
        if (_epgEnabled != null) 'epgEnabled': _epgEnabled,
        if (_tvHomeLayoutMode != null && _tvHomeLayoutMode!.isNotEmpty) 'tvHomeLayoutMode': _tvHomeLayoutMode,
        if (_liveBufferSeconds != null) 'liveBufferSeconds': _liveBufferSeconds,
        if (_appLayoutMode != null && _appLayoutMode!.isNotEmpty) 'appLayoutMode': _appLayoutMode,
        if (_liveStreamFormat != null && _liveStreamFormat!.isNotEmpty) 'liveStreamFormat': _liveStreamFormat,
        if (_backgroundPlayback != null) 'backgroundPlayback': _backgroundPlayback,
        if (_volumeBoostMaxPercent != null) 'volumeBoostMaxPercent': _volumeBoostMaxPercent,
        if (_isAiRecommendationEnabled != null) 'isAiRecommendationEnabled': _isAiRecommendationEnabled,
        'forceUpdateId': now,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Get.back(); // close loading
      Get.snackbar(
        'Başarılı',
        'Tüm kullanıcılara yeni ayarlar başarıyla gönderildi!',
        backgroundColor: Colors.green.withValues(alpha: 0.8),
        colorText: Colors.white,
      );

      if (mounted) {
        setState(() {
          _currentForceUpdateId = now;
        });
      }
    } catch (e) {
      Get.back(); // close loading
      Get.snackbar(
        'Hata',
        'Ayarlar güncellenirken bir sorun oluştu: $e',
        backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ThemedSettingsBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Kullanıcı Ayarlarını Değiş',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amberAccent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.amberAccent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.amberAccent, size: 32),
                          const SizedBox(height: 8),
                          const Text(
                            'Buradan yaptığınız değişiklikler "Tüm Kullanıcılara Uygula" dediğiniz anda tüm cihazlarda (kullanıcıların kendi yaptıkları ayarları ezerek) devreye girer. Kullanıcılar daha sonra kendi cihazlarından tekrar ayar değiştirebilir.',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          if (_currentForceUpdateId > 0) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Son Güncelleme Kodu: $_currentForceUpdateId',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDropdown<String>(
                      title: 'Canlı Yayın Oynatıcı (Live Engine)',
                      value: _livePlaybackEngine ?? '',
                      items: {
                        '': 'Mevcut Durumu Koru (Değiştirme)',
                        'better': 'Better Player (Varsayılan)',
                        'mediaKit': 'MediaKit (Yeni Nesil)',
                      },
                      onChanged: (val) =>
                          setState(() => _livePlaybackEngine = val),
                    ),
                    _buildDropdown<String>(
                      title: 'Film/Dizi Oynatıcı (VOD Engine)',
                      value: _vodPlaybackEngine ?? '',
                      items: {
                        '': 'Mevcut Durumu Koru (Değiştirme)',
                        'better': 'Better Player (Varsayılan)',
                        'mediaKit': 'MediaKit (Yeni Nesil)',
                      },
                      onChanged: (val) =>
                          setState(() => _vodPlaybackEngine = val),
                    ),
                    _buildDropdown<String>(
                      title: 'TV Rehberi (EPG)',
                      value: _epgEnabled == null ? '' : _epgEnabled.toString(),
                      items: {
                        '': 'Mevcut Durumu Koru (Değiştirme)',
                        'true': 'Aktif Et (Açık)',
                        'false': 'Devre Dışı Bırak (Kapalı)',
                      },
                      onChanged: (val) {
                        setState(() {
                          if (val == '')
                            _epgEnabled = null;
                          else if (val == 'true')
                            _epgEnabled = true;
                          else if (val == 'false') _epgEnabled = false;
                        });
                      },
                    ),
                    _buildDropdown<String>(
                      title: 'TV Ana Ekran Tasarımı',
                      value: _tvHomeLayoutMode ?? '',
                      items: {
                        '': 'Mevcut Durumu Koru (Değiştirme)',
                        'shell': 'Modern (Sol Menülü)',
                        'classic': 'Klasik (Kartlı Ana Ekran)',
                      },
                      onChanged: (val) =>
                          setState(() => _tvHomeLayoutMode = val),
                    ),
                    _buildDropdown<String>(
                      title: 'Canlı Yayın Tamponu (Buffer)',
                      value: _liveBufferSeconds?.toString() ?? '',
                      items: {
                        '': 'Mevcut Durumu Koru (Değiştirme)',
                        '0': '0 Saniye',
                        '2': '2 Saniye (Önerilen)',
                        '3': '3 Saniye',
                        '5': '5 Saniye',
                        '10': '10 Saniye',
                      },
                      onChanged: (val) => setState(() {
                        if (val == '')
                          _liveBufferSeconds = null;
                        else
                          _liveBufferSeconds = int.tryParse(val ?? '');
                      }),
                    ),
                    _buildDropdown<String>(
                      title: 'Uygulama Layout Modu',
                      value: _appLayoutMode ?? '',
                      items: {
                        '': 'Mevcut Durumu Koru (Değiştirme)',
                        'auto': 'Otomatik (Cihaza Göre)',
                        'mobile': 'Telefon Modu',
                        'tablet': 'Tablet Modu',
                        'tv': 'TV Modu',
                      },
                      onChanged: (val) => setState(() => _appLayoutMode = val),
                    ),

                    _buildDropdown<String>(
                      title: 'Canlı Yayın Formatı (IPTV Motoru)',
                      value: _liveStreamFormat ?? '',
                      items: {
                        '': 'Mevcut Durumu Koru (Değiştirme)',
                        'auto': 'Otomatik (URL\'den algıla)',
                        'hls': 'HLS (.m3u8 - Kararlı)',
                        'ts': 'MPEG-TS (.ts - Hızlı/Gecikmesiz)',
                      },
                      onChanged: (val) => setState(() => _liveStreamFormat = val),
                    ),

                    _buildDropdown<String>(
                      title: 'Arka Planda Oynatma (Sesli Devam)',
                      value: _backgroundPlayback == null ? '' : _backgroundPlayback.toString(),
                      items: {
                        '': 'Mevcut Durumu Koru (Değiştirme)',
                        'true': 'Açık (Arka planda çalsın)',
                        'false': 'Kapalı (Arka planda dursun)',
                      },
                      onChanged: (val) {
                        setState(() {
                          if (val == '') _backgroundPlayback = null;
                          else if (val == 'true') _backgroundPlayback = true;
                          else if (val == 'false') _backgroundPlayback = false;
                        });
                      },
                    ),

                    _buildDropdown<String>(
                      title: 'Ses Yükseltici Maksimum Sınırı',
                      value: _volumeBoostMaxPercent?.toString() ?? '',
                      items: {
                        '': 'Mevcut Durumu Koru (Değiştirme)',
                        '100': '%100 (Normal)',
                        '200': '%200 (2 Katı)',
                        '300': '%300 (3 Katı)',
                        '400': '%400 (4 Katı)',
                      },
                      onChanged: (val) => setState(() {
                        if (val == '') _volumeBoostMaxPercent = null;
                        else _volumeBoostMaxPercent = int.tryParse(val ?? '');
                      }),
                    ),

                    _buildDropdown<String>(
                      title: 'Yapay Zeka (Mina AI) Önerileri',
                      value: _isAiRecommendationEnabled == null ? '' : _isAiRecommendationEnabled.toString(),
                      items: {
                        '': 'Mevcut Durumu Koru (Değiştirme)',
                        'true': 'Açık',
                        'false': 'Kapalı',
                      },
                      onChanged: (val) {
                        setState(() {
                          if (val == '') _isAiRecommendationEnabled = null;
                          else if (val == 'true') _isAiRecommendationEnabled = true;
                          else if (val == 'false') _isAiRecommendationEnabled = false;
                        });
                      },
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _applyOverrides,
                        child: const Text('Tüm Kullanıcılara Anında Uygula',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String title,
    required T value,
    required Map<T, String> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: items.containsKey(value) ? value : null,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
              items: items.entries.map((entry) {
                return DropdownMenuItem<T>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
