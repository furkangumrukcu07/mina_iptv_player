import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/services/active_playlist_service.dart';

/// Liste (playlist) geçişi sürerken ekranın ortasında **yanıp sönen şemsiye**
/// (uygulama ikonu) göstergesi.
///
/// Kullanıcı "Listeler" seçicisinden farklı bir listeye geçtiğinde içerik
/// 4-5 sn yüklenebilir ([ActivePlaylistService.selectSlot] →
/// [ActivePlaylistService.isSwitching]). Bu süre boyunca canlı TV / filmler /
/// diziler / Film&Dizi ekranlarının tamamında merkezde küçük bir şemsiye
/// ikonu yanıp söner; liste tamamen devreye girince kaybolur.
///
/// Global olarak [GetMaterialApp.builder] içinde tüm içeriğin üzerine tek sefer
/// yerleştirilir; geçiş süresince tüm etkileşimi engeller.
class PlaylistSwitchOverlay extends StatefulWidget {
  const PlaylistSwitchOverlay({super.key});

  @override
  State<PlaylistSwitchOverlay> createState() => _PlaylistSwitchOverlayState();
}

class _PlaylistSwitchOverlayState extends State<PlaylistSwitchOverlay> {
  final _blockFocus = FocusNode(debugLabel: 'playlistSwitchBlock');

  @override
  void dispose() {
    _blockFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ActivePlaylistService>()) {
      return const SizedBox.shrink();
    }
    final active = Get.find<ActivePlaylistService>();
    return Obx(() {
      final switching = active.isSwitching.value;
      if (switching) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_blockFocus.canRequestFocus) {
            _blockFocus.requestFocus();
          }
        });
      }
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: switching
            ? Focus(
                key: const ValueKey('on'),
                focusNode: _blockFocus,
                autofocus: true,
                canRequestFocus: true,
                child: AbsorbPointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ModalBarrier(
                        color: Colors.black.withValues(alpha: 0.55),
                        dismissible: false,
                      ),
                      _BlinkingUmbrella(
                        label: 'tvShell.playlists.pleaseWait'.tr,
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('off')),
      );
    });
  }
}

/// Ana ekranda marka (Mina) çerçevesine dokununca aktif M3U listesi yenilenir;
/// bu sürede ekranın ortasında **yanıp sönen Mina ikonu** + "Liste yenileniyor"
/// ibaresi gösterilir. [active] genelde `HomeController.isRefreshing`'tir.
class PlaylistRefreshOverlay extends StatelessWidget {
  const PlaylistRefreshOverlay({super.key, required this.active});

  final RxBool active;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final refreshing = active.value;
      return IgnorePointer(
        ignoring: true,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: refreshing
              ? _BlinkingUmbrella(
                  key: const ValueKey('refresh-on'),
                  label: 'playlist.refreshing'.tr,
                )
              : const SizedBox.shrink(key: ValueKey('refresh-off')),
        ),
      );
    });
  }
}

class _BlinkingUmbrella extends StatefulWidget {
  const _BlinkingUmbrella({super.key, this.label});

  /// Varsa ikonun altında gösterilen ibare (ör. "Liste yenileniyor").
  final String? label;

  @override
  State<_BlinkingUmbrella> createState() => _BlinkingUmbrellaState();
}

class _BlinkingUmbrellaState extends State<_BlinkingUmbrella>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _scale = Tween<double>(begin: 0.9, end: 1.06).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    return Center(
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 56,
                  height: 56,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              if (label != null && label.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
