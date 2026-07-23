import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_scroll_physics.dart';
import '../../ui/settings_glass_panel.dart';
import '../../ui/themed_settings_background.dart';
import '../../ui/tv_settings_subpage.dart';
import '../../ui/tv_dpad_focus.dart';
import '../../core/services/tv_key_mapping_service.dart';

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
    // eski listener kalması için.
    keyService.onKeyRegistered = null;
    keyService.isListeningForRegistration = false;

    // Diyalog açıldıktan sonra dinlemeye başla
    keyService.isListeningForRegistration = true;

    keyService.onKeyRegistered = (key) {
      // Callback tek seferlik olmalı — hemen temizle
      keyService.onKeyRegistered = null;

      // Korumalı tuş kontrolü — servis zaten reddeder ama UI'da da bildir
      if (TvKeyMappingService.isBlockedKey(key)) {
        // Dinlemeyi yeniden etkinleştir, kullanıcıya mesaj göster
        keyService.isListeningForRegistration = true;
        keyService.onKeyRegistered = null;
        Get.snackbar(
          'Atanamaz Tuş',
          '"${key.keyLabel}" sistem tuşudur (Geri, OK, Oklar, Home). Lütfen başka bir tuş seçin.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withValues(alpha: 0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        // Callback'i yeniden ata
        // (recursive olmaması için _showCaptureDialog yerine mevcut state'i yönet)
        _reattachKeyCallback(keyService, actionId, actionTitle, context);
        return;
      }

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
                      'Lütfen kumandanızdan atamak istediğiniz tuşa basın...\n'
                      '(Geri, OK, Oklar ve Home tuşları atanamaz)',
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

  /// Korumalı tuş basıldığında callback'i yeniden bağla.
  void _reattachKeyCallback(
    TvKeyMappingService keyService,
    String actionId,
    String actionTitle,
    BuildContext context,
  ) {
    keyService.onKeyRegistered = (key) {
      keyService.onKeyRegistered = null;
      if (TvKeyMappingService.isBlockedKey(key)) {
        Get.snackbar(
          'Atanamaz Tuş',
          '"${key.keyLabel}" sistem tuşudur. Lütfen başka bir tuş seçin.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange.withValues(alpha: 0.9),
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        keyService.isListeningForRegistration = true;
        _reattachKeyCallback(keyService, actionId, actionTitle, context);
        return;
      }
      keyService.assignKey(key.keyId, key.keyLabel, actionId);
      if (Navigator.canPop(context)) Navigator.pop(context);
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

      return _ActionTileRow(
        key: ValueKey('action_tile_$actionId'),
        actionId: actionId,
        title: title,
        primary: primary,
        isMapped: isMapped,
        keyLabel: keyLabel,
        mappedKeyId: mappedKeyId,
        iconForAction: _iconForAction,
        onTap: () => _showCaptureDialog(context, actionId, title),
        onEdit: () => _showCaptureDialog(context, actionId, title),
        onDelete: () {
          if (mappedKeyId != null) {
            keyService.removeMapping(mappedKeyId);
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final actions = [
      {'id': 'search', 'title': 'Hızlı Arama Ekranını Açma'},
      {'id': 'epg_mix', 'title': 'EPG Mix Görünümüne Gitme'},
      {'id': 'zap_back', 'title': 'Önceki İzlenen Kanala Hızlı Geçiş (Zap Back)'},
      {'id': 'playlists', 'title': 'Oynatma Listeleri Panelini Açma'},
      {'id': 'favorites', 'title': 'Favoriler Panelini Açma'},
      {'id': 'refresh', 'title': 'Aktif Oynatma Listesini Yenileme'},
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Get.back<void>();
      },
      child: Scaffold(
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
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

/// Tile + Edit + Delete ikonlarını explicit FocusNode'larla birbirine bağlayan row widget'ı.
/// Sol/Sağ ok tuşlarıyla tile → edit → delete arası geçiş garanti edilir.
class _ActionTileRow extends StatefulWidget {
  const _ActionTileRow({
    super.key,
    required this.actionId,
    required this.title,
    required this.primary,
    required this.isMapped,
    required this.keyLabel,
    required this.mappedKeyId,
    required this.iconForAction,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final String actionId;
  final String title;
  final Color primary;
  final bool isMapped;
  final String? keyLabel;
  final int? mappedKeyId;
  final IconData Function(String) iconForAction;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ActionTileRow> createState() => _ActionTileRowState();
}

class _ActionTileRowState extends State<_ActionTileRow> {
  late final FocusNode _tileFocus;
  late final FocusNode _editFocus;
  late final FocusNode _deleteFocus;

  @override
  void initState() {
    super.initState();
    _tileFocus = FocusNode(debugLabel: 'keymap_tile_${widget.actionId}');
    _editFocus = FocusNode(debugLabel: 'keymap_edit_${widget.actionId}');
    _deleteFocus = FocusNode(debugLabel: 'keymap_delete_${widget.actionId}');
  }

  @override
  void dispose() {
    _tileFocus.dispose();
    _editFocus.dispose();
    _deleteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMapped = widget.isMapped;

    final body = Expanded(
      child: TvFocusableInkWell(
        onTap: widget.onTap,
        borderRadius: 18,
        focusNode: _tileFocus,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.primary.withValues(alpha: 0.18),
                  border: Border.all(
                    color: widget.primary.withValues(alpha: 0.40),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.iconForAction(widget.actionId),
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
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isMapped
                          ? 'Atanan Tuş: ${widget.keyLabel}'
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
              if (!isMapped)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white54,
                ),
            ],
          ),
        ),
      ),
    );

    final rightControls = isMapped
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TvIconButton(
                icon: Icons.edit_rounded,
                iconColor: Colors.blueAccent,
                tooltip: 'Değiştir',
                focusNode: _editFocus,
                arrowLeft: _tileFocus,
                arrowRight: _deleteFocus,
                onPressed: widget.onEdit,
              ),
              TvIconButton(
                icon: Icons.delete_forever_rounded,
                iconColor: Colors.redAccent,
                tooltip: 'Kaldır',
                focusNode: _deleteFocus,
                arrowLeft: _editFocus,
                onPressed: widget.onDelete,
              ),
              const SizedBox(width: 8),
            ],
          )
        : const SizedBox.shrink();

    return Container(
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
        child: Row(
          children: [
            body,
            rightControls,
          ],
        ),
      ),
    );
  }
}
