import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/layout/app_layout_mode.dart';
import '../../../core/services/app_settings_service.dart';
import '../../../domain/entities/channel.dart';
import '../../channels/epg_timeline_body.dart';

bool _playerEpgTvCenterKey(LogicalKeyboardKey k) =>
    k == LogicalKeyboardKey.select ||
    k == LogicalKeyboardKey.enter ||
    k == LogicalKeyboardKey.numpadEnter ||
    k == LogicalKeyboardKey.space ||
    k == LogicalKeyboardKey.gameButtonSelect;

/// Tam ekran tek-kanal EPG; yayın arkada sürer, [onClose] ile OSD’ye dönülür.
class PlayerLiveEpgOverlayShell extends StatelessWidget {
  const PlayerLiveEpgOverlayShell({
    super.key,
    required this.channel,
    required this.onClose,
    /// Kumanda Geri / Escape: [onClose] yerine (ör. aynı pop’ta [handleBack] yutulsun).
    this.onHardwareBack,
  });

  final Channel channel;
  final VoidCallback onClose;
  final VoidCallback? onHardwareBack;

  KeyEventResult _onRootKey(FocusNode node, KeyEvent event) {
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.goBack || k == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        (onHardwareBack ?? onClose)();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final app = Get.find<AppSettingsService>();
      final useDpad = remoteNavForScreenLayout(context, app.layoutMode.value);
      return FocusScope(
        child: Focus(
          autofocus: !useDpad,
          skipTraversal: true,
          onKeyEvent: _onRootKey,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black.withValues(alpha: 0.9)),
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 12, 4),
                        child: Row(
                          children: [
                            if (useDpad)
                              StatefulBuilder(
                                builder: (context, setSt) {
                                  return Focus(
                                    autofocus: true,
                                    descendantsAreFocusable: false,
                                    onFocusChange: (_) => setSt(() {}),
                                    onKeyEvent: (node, event) {
                                      if (event is! KeyDownEvent) {
                                        return KeyEventResult.ignored;
                                      }
                                      if (_playerEpgTvCenterKey(event.logicalKey)) {
                                        onClose();
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: Builder(
                                      builder: (ctx) {
                                        final f = Focus.of(ctx).hasFocus;
                                        return Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            onTap: onClose,
                                            child: Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: f
                                                        ? Colors.white
                                                            .withValues(
                                                                alpha: 0.88)
                                                        : Colors.transparent,
                                                    width: f ? 2.2 : 0,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.arrow_back_rounded,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.95),
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              )
                            else
                              IconButton(
                                tooltip: 'common.back'.tr,
                                onPressed: onClose,
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                          Expanded(
                            child: Text(
                              channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: PlayerSingleChannelEpgPanel(channel: channel),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    });
  }
}
