import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/theme/app_scroll_physics.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_settings_subpage.dart';
import '../../core/services/tv_key_mapping_service.dart';
import '../../core/services/app_settings_service.dart';

class TvKeyMappingSettingsView extends StatelessWidget {
  const TvKeyMappingSettingsView({super.key});

  IconData _iconForAction(String actionId) {
    switch (actionId) {
      case 'search':
        return Icons.search_rounded;
      case 'epg_mix':
        return Icons.view_carousel_rounded;
      case 'zap_back':
        return Icons.replay_rounded;
      case 'playlists':
        return Icons.playlist_play_rounded;
      case 'favorites':
        return Icons.favorite_rounded;
      case 'refresh':
        return Icons.refresh_rounded;
      default:
        return Icons.settings_remote_rounded;
    }
  }

  void _showCaptureDialog(BuildContext context, String actionId, String actionTitle) {
    final keyService = TvKeyMappingService.to;

    // Önce eski callback'i temizle — değiştirme senaryosunda
    // eski listener kalmaması için.
    keyService.onKeyRegistered = null;
    keyService.isListeningForRegistration = false;

    // Diyalog açıldıktan sonra dinlemeye başla
    keyService.isListeningForRegistration = true;

    keyService.onKeyRegistered = (key) {
      // Callback tek seferlik olmalı — hemen temizle
      keyService.onKeyRegistered = null;
      keyService.assignKey(key.keyId, key.keyLabel, actionId);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      Get.snackbar(
        'settings.keyMapping.success.title'.tr,
        'settings.keyMapping.success.msg'.trParams({
          'action': actionTitle,
          'key': key.keyLabel,
        }),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withValues(alpha: 0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    };

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CaptureKey',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (dialogContext, anim1, anim2) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              keyService.isListeningForRegistration = false;
              keyService.onKeyRegistered = null;
            }
          },
          child: Center(
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.settings_remote_rounded,
                      color: Colors.blueAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      actionTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Lütfen kumandanızdan atamak istediğiniz tuşa basın...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.35,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        keyService.isListeningForRegistration = false;
                        keyService.onKeyRegistered = null;
                        Navigator.pop(dialogContext);
                      },
                      child: const Text(
                        'İptal',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile(BuildContext context, String actionId, String title, int index, Color primary) {
    final keyService = TvKeyMappingService.to;
    return Obx(() {
      int? mappedKeyId;
      String? keyLabel;
      for (final entry in keyService.mappings.entries) {
        if (entry.value['action'] == actionId) {
          mappedKeyId = entry.key;
          keyLabel = entry.value['label'] as String?;
          break;
        }
      }

      final isMapped = mappedKeyId != null;

      final tile = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.07),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primary.withValues(alpha: 0.18),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.40),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _iconForAction(actionId),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isMapped
                            ? 'Atanan Tuş: $keyLabel'
                            : 'Atanmadı (Tuş atamak için tıklayın)',
                        style: TextStyle(
                          color: isMapped ? Colors.greenAccent : Colors.white70,
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isMapped) ...[
                  // Değiştir butonu
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent),
                    tooltip: 'Değiştir',
                    onPressed: () => _showCaptureDialog(context, actionId, title),
                  ),
                  // Sil butonu
                  IconButton(
                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                    tooltip: 'Kaldır',
                    onPressed: () {
                      if (mappedKeyId != null) {
                        keyService.removeMapping(mappedKeyId);
                      }
                    },
                  ),
                ] else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white54,
                  ),
              ],
            ),
          ),
        ),
      );

      return tvSettingsDpadWrap(
        context,
        index: index,
        onActivate: () => _showCaptureDialog(context, actionId, title),
        borderRadius: 18,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showCaptureDialog(context, actionId, title),
          child: tile,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tvDpad = Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;

    final actions = [
      {'id': 'search', 'title': 'Hızlı Arama Ekranını Açma'},
      {'id': 'epg_mix', 'title': 'EPG Mix Görünümüne Gitme'},
      {'id': 'zap_back', 'title': 'Önceki İzlenen Kanala Hızlı Geçiş (Zap Back)'},
      {'id': 'playlists', 'title': 'Oynatma Listeleri Panelini Açma'},
      {'id': 'favorites', 'title': 'Favoriler Panelini Açma'},
      {'id': 'refresh', 'title': 'Aktif Oynatma Listesini Yenileme'},
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: ThemedSettingsBackground(
        child: SafeArea(
          child: SettingsGlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tvSettingsSubpageHeader(context, 'settings.tile.keyMapping'.tr),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Text(
                    'Kumandanızdaki kullanılmayan veya özel tuşları (sayı tuşları, renkli tuşlar vb.) sık kullanılan eylemlere atayabilirsiniz.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
                Expanded(
                  child: TvSettingsDpadScope(
                    enabled: tvDpad,
                    child: ListView.builder(
                      physics: AppScrollPhysics.list(),
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: actions.length,
                      itemBuilder: (context, index) {
                        final action = actions[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildActionTile(
                            context,
                            action['id']!,
                            action['title']!,
                            index,
                            primary,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
