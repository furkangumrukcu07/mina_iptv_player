import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/theme/app_theme.dart';
import 'playlist_controller.dart';

class PlaylistView extends StatefulWidget {
  const PlaylistView({super.key, this.setupWizardEmbed = false});

  /// `true`: yalnızca birincil kaynak formu; [Scaffold] yok (kurulum sihirbazı içinde).
  final bool setupWizardEmbed;

  @override
  State<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  final controller = Get.find<PlaylistController>();
  static const _minaGreen = Color(0xFF22C55E);

  final _primaryM3uTabFocus = FocusNode(debugLabel: 'primaryM3uTab');
  final _primaryXtreamTabFocus = FocusNode(debugLabel: 'primaryXtreamTab');
  final _secondaryM3uTabFocus = FocusNode(debugLabel: 'secondaryM3uTab');
  final _secondaryXtreamTabFocus = FocusNode(debugLabel: 'secondaryXtreamTab');

  final _primaryM3uUrlFocus = FocusNode(debugLabel: 'primaryM3uUrl');
  final _primaryM3uFilePickFocus = FocusNode(debugLabel: 'primaryM3uFilePick');
  final _primaryXtreamServerFocus =
      FocusNode(debugLabel: 'primaryXtreamServer');
  final _primaryXtreamUserFocus = FocusNode(debugLabel: 'primaryXtreamUser');
  final _primaryXtreamPassFocus = FocusNode(debugLabel: 'primaryXtreamPass');
  final _primarySubmitFocus = FocusNode(debugLabel: 'primarySubmit');
  final _demoFocus = FocusNode(debugLabel: 'demoPlaylist');

  final _secondaryM3uUrlFocus = FocusNode(debugLabel: 'secondaryM3uUrl');
  final _secondaryM3uFilePickFocus =
      FocusNode(debugLabel: 'secondaryM3uFilePick');
  final _secondaryXtreamServerFocus =
      FocusNode(debugLabel: 'secondaryXtreamServer');
  final _secondaryXtreamUserFocus =
      FocusNode(debugLabel: 'secondaryXtreamUser');
  final _secondaryXtreamPassFocus =
      FocusNode(debugLabel: 'secondaryXtreamPass');
  final _secondarySubmitFocus = FocusNode(debugLabel: 'secondarySubmit');
  final _secondaryEnableFocus = FocusNode(debugLabel: 'secondaryEnable');

  @override
  void initState() {
    super.initState();
    controller.bindPrimarySourceTabFocus(
      focusM3uChip: _primaryM3uTabFocus.requestFocus,
      focusXtreamChip: _primaryXtreamTabFocus.requestFocus,
    );
    controller.bindSecondarySourceTabFocus(
      focusM3uChip: _secondaryM3uTabFocus.requestFocus,
      focusXtreamChip: _secondaryXtreamTabFocus.requestFocus,
    );
    controller.bindPrimaryM3uUrlFieldFocus(_primaryM3uUrlFocus.requestFocus);
    controller
        .bindPrimaryM3uFilePickFocus(_primaryM3uFilePickFocus.requestFocus);
    controller.bindPrimaryXtreamServerFieldFocus(
        _primaryXtreamServerFocus.requestFocus);

    controller
        .bindSecondaryM3uUrlFieldFocus(_secondaryM3uUrlFocus.requestFocus);
    controller
        .bindSecondaryM3uFilePickFocus(_secondaryM3uFilePickFocus.requestFocus);
    controller.bindSecondaryXtreamServerFieldFocus(
        _secondaryXtreamServerFocus.requestFocus);

    _bindTvKeyboardAutoOpen(_primaryM3uUrlFocus);
    _bindTvKeyboardAutoOpen(_primaryXtreamServerFocus);
    _bindTvKeyboardAutoOpen(_primaryXtreamUserFocus);
    _bindTvKeyboardAutoOpen(_primaryXtreamPassFocus);
    _bindTvKeyboardAutoOpen(_secondaryM3uUrlFocus);
    _bindTvKeyboardAutoOpen(_secondaryXtreamServerFocus);
    _bindTvKeyboardAutoOpen(_secondaryXtreamUserFocus);
    _bindTvKeyboardAutoOpen(_secondaryXtreamPassFocus);

    // TV Kumanda: En üstteki input alanlarında yukarı tuşuna basınca sekmelere odaklan.
    _primaryM3uUrlFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          controller.tvFocusPrimaryM3uTabChip();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _primaryM3uFilePickFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _primaryM3uFilePickFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _primaryM3uUrlFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _primarySubmitFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _primaryXtreamServerFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          controller.tvFocusPrimaryXtreamTabChip();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _primaryXtreamUserFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _primaryXtreamUserFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _primaryXtreamServerFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _primaryXtreamPassFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _primaryXtreamPassFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _primaryXtreamUserFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _primarySubmitFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _primarySubmitFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        FocusScope.of(context).previousFocus();
        return KeyEventResult.handled;
      } else if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        FocusScope.of(context).nextFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    _demoFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        FocusScope.of(context).previousFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    _secondaryM3uUrlFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          controller.tvFocusSecondaryM3uTabChip();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _secondaryM3uFilePickFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _secondaryM3uFilePickFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _secondaryM3uUrlFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _secondarySubmitFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _secondaryXtreamServerFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          controller.tvFocusSecondaryXtreamTabChip();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _secondaryXtreamUserFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _secondaryXtreamUserFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _secondaryXtreamServerFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _secondaryXtreamPassFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _secondaryXtreamPassFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _secondaryXtreamUserFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _secondarySubmitFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _secondarySubmitFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        FocusScope.of(context).previousFocus();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        FocusScope.of(context).nextFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _primaryM3uTabFocus.dispose();
    _primaryXtreamTabFocus.dispose();
    _secondaryM3uTabFocus.dispose();
    _secondaryXtreamTabFocus.dispose();
    _primaryM3uUrlFocus.dispose();
    _primaryM3uFilePickFocus.dispose();
    _primaryXtreamServerFocus.dispose();
    _primaryXtreamUserFocus.dispose();
    _primaryXtreamPassFocus.dispose();
    _primarySubmitFocus.dispose();
    _demoFocus.dispose();
    _secondaryM3uUrlFocus.dispose();
    _secondaryM3uFilePickFocus.dispose();
    _secondaryXtreamServerFocus.dispose();
    _secondaryXtreamUserFocus.dispose();
    _secondaryXtreamPassFocus.dispose();
    _secondarySubmitFocus.dispose();
    _secondaryEnableFocus.dispose();
    super.dispose();
  }

  void _bindTvKeyboardAutoOpen(FocusNode node) {
    node.addListener(() {
      if (!mounted || !node.hasFocus) return;
      final isTv =
          Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
      if (!isTv) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !node.hasFocus) return;
        unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
      });
    });
  }

  @override
  State<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  final controller = Get.find<PlaylistController>();

  final _primaryM3uTabFocus = FocusNode(debugLabel: 'primaryM3uTab');
  final _primaryXtreamTabFocus = FocusNode(debugLabel: 'primaryXtreamTab');
  final _secondaryM3uTabFocus = FocusNode(debugLabel: 'secondaryM3uTab');
  final _secondaryXtreamTabFocus = FocusNode(debugLabel: 'secondaryXtreamTab');

  final _primaryM3uUrlFocus = FocusNode(debugLabel: 'primaryM3uUrl');
  final _primaryM3uFilePickFocus = FocusNode(debugLabel: 'primaryM3uFilePick');
  final _primaryXtreamServerFocus =
      FocusNode(debugLabel: 'primaryXtreamServer');
  final _primaryXtreamUserFocus = FocusNode(debugLabel: 'primaryXtreamUser');
  final _primaryXtreamPassFocus = FocusNode(debugLabel: 'primaryXtreamPass');
  final _primarySubmitFocus = FocusNode(debugLabel: 'primarySubmit');
  final _demoFocus = FocusNode(debugLabel: 'demoPlaylist');

  final _secondaryM3uUrlFocus = FocusNode(debugLabel: 'secondaryM3uUrl');
  final _secondaryM3uFilePickFocus =
      FocusNode(debugLabel: 'secondaryM3uFilePick');
  final _secondaryXtreamServerFocus =
      FocusNode(debugLabel: 'secondaryXtreamServer');
  final _secondaryXtreamUserFocus =
      FocusNode(debugLabel: 'secondaryXtreamUser');
  final _secondaryXtreamPassFocus =
      FocusNode(debugLabel: 'secondaryXtreamPass');
  final _secondarySubmitFocus = FocusNode(debugLabel: 'secondarySubmit');

  @override
  void initState() {
    super.initState();
    controller.bindPrimarySourceTabFocus(
      focusM3uChip: _primaryM3uTabFocus.requestFocus,
      focusXtreamChip: _primaryXtreamTabFocus.requestFocus,
    );
    controller.bindSecondarySourceTabFocus(
      focusM3uChip: _secondaryM3uTabFocus.requestFocus,
      focusXtreamChip: _secondaryXtreamTabFocus.requestFocus,
    );
    controller.bindPrimaryM3uUrlFieldFocus(_primaryM3uUrlFocus.requestFocus);
    controller
        .bindPrimaryM3uFilePickFocus(_primaryM3uFilePickFocus.requestFocus);
    controller.bindPrimaryXtreamServerFieldFocus(
        _primaryXtreamServerFocus.requestFocus);

    controller
        .bindSecondaryM3uUrlFieldFocus(_secondaryM3uUrlFocus.requestFocus);
    controller
        .bindSecondaryM3uFilePickFocus(_secondaryM3uFilePickFocus.requestFocus);
    controller.bindSecondaryXtreamServerFieldFocus(
        _secondaryXtreamServerFocus.requestFocus);

    // TV Kumanda: En üstteki input alanlarında yukarı tuşuna basınca sekmelere odaklan.
    _primaryM3uUrlFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          controller.tvFocusPrimaryM3uTabChip();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _primaryM3uFilePickFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _primaryM3uFilePickFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _primaryM3uUrlFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _primarySubmitFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _primaryXtreamServerFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          controller.tvFocusPrimaryXtreamTabChip();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _primaryXtreamUserFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _primaryXtreamUserFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _primaryXtreamServerFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _primaryXtreamPassFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _primaryXtreamPassFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _primaryXtreamUserFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _primarySubmitFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _primarySubmitFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (controller.tabIndex.value == 0) {
          _primaryM3uFilePickFocus.requestFocus();
        } else {
          _primaryXtreamPassFocus.requestFocus();
        }
        return KeyEventResult.handled;
      } else if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final isTv =
            Get.find<AppSettingsService>().layoutMode.value == AppLayoutMode.tv;
        if (isTv) {
          _demoFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _demoFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _primarySubmitFocus.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    _secondaryM3uUrlFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          controller.tvFocusSecondaryM3uTabChip();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _secondaryM3uFilePickFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _secondaryM3uFilePickFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _secondaryM3uUrlFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _secondarySubmitFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _secondaryXtreamServerFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          controller.tvFocusSecondaryXtreamTabChip();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _secondaryXtreamUserFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _secondaryXtreamUserFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _secondaryXtreamServerFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _secondaryXtreamPassFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _secondaryXtreamPassFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _secondaryXtreamUserFocus.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _secondarySubmitFocus.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
    _secondarySubmitFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (controller.secondaryTabIndex.value == 0) {
          _secondaryM3uFilePickFocus.requestFocus();
        } else {
          _secondaryXtreamPassFocus.requestFocus();
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _primaryM3uTabFocus.dispose();
    _primaryXtreamTabFocus.dispose();
    _secondaryM3uTabFocus.dispose();
    _secondaryXtreamTabFocus.dispose();
    _primaryM3uUrlFocus.dispose();
    _primaryM3uFilePickFocus.dispose();
    _primaryXtreamServerFocus.dispose();
    _primaryXtreamUserFocus.dispose();
    _primaryXtreamPassFocus.dispose();
    _primarySubmitFocus.dispose();
    _demoFocus.dispose();
    _secondaryM3uUrlFocus.dispose();
    _secondaryM3uFilePickFocus.dispose();
    _secondaryXtreamServerFocus.dispose();
    _secondaryXtreamUserFocus.dispose();
    _secondaryXtreamPassFocus.dispose();
    _secondarySubmitFocus.dispose();
    super.dispose();
  }

  /// Okunaklılık için açık gri — saf beyaz yaprak üstünde kaybolmaz.
  static const _denseFieldStyle = TextStyle(
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w500,
    color: Color(0xFFF1F5F9),
  );

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    final showSecondaryPlaylistUi = widget.setupWizardEmbed
        ? false
        : (args is Map && args[AppRoutes.argPlaylistManage] == true);

    if (widget.setupWizardEmbed) {
      return _buildFormBody(
        context,
        showSecondaryPlaylistUi: showSecondaryPlaylistUi,
        useFullScreenBackground: false,
      );
    }

    final appSettings = Get.find<AppSettingsService>();
    final isTv = appSettings.layoutMode.value == AppLayoutMode.tv;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: isTv
            ? null
            : Text(
                'playlist.title'.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 10,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: Colors.white.withValues(alpha: 0.95),
            ),
            tooltip: 'settings.title'.tr,
            onPressed: () => Get.toNamed(AppRoutes.settings),
          ),
        ],
        ),
        body: _buildFormBody(
          context,
          showSecondaryPlaylistUi: showSecondaryPlaylistUi,
          useFullScreenBackground: true,
        ),
      ),
    );
  }

  Widget _buildFormBody(
    BuildContext context, {
    required bool showSecondaryPlaylistUi,
    required bool useFullScreenBackground,
  }) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final appSettings = Get.find<AppSettingsService>();
    final isTv = appSettings.layoutMode.value == AppLayoutMode.tv;
    final topPad = useFullScreenBackground
        ? (isTv ? 24.0 : 100.0)
        : (isTv ? 12.0 : 4.0);

    return Obx(() {
      final themeLabel = appSettings.themeLabel.value;
      final scroll = FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, topPad, 16, 16 + bottomInset),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                          _GlassCard(
                            padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'playlist.sourceTitle'.tr,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: const Color(0xFFF8FAFC),
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'playlist.sourceSubtitle'.tr,
                                  style: text.bodyMedium?.copyWith(
                                    color: const Color(0xFFCBD5E1),
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Obx(
                                  () => _SourceTabs(
                                    index: controller.tabIndex.value,
                                    onChanged: controller.setTab,
                                    cs: cs,
                                    m3uFocus: _primaryM3uTabFocus,
                                    xtreamFocus: _primaryXtreamTabFocus,
                                    isTv: isTv,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Obx(
                                  () => controller.tabIndex.value == 0
                                      ? _M3uTab(
                                          controller: controller,
                                          denseStyle: _denseFieldStyle,
                                          cs: cs,
                                          isTv: isTv,
                                          urlFocus: _primaryM3uUrlFocus,
                                          filePickFocus:
                                              _primaryM3uFilePickFocus,
                                        )
                                      : _XtreamTab(
                                          controller: controller,
                                          denseStyle: _denseFieldStyle,
                                          cs: cs,
                                          isTv: isTv,
                                          serverFocus:
                                              _primaryXtreamServerFocus,
                                          userFocus: _primaryXtreamUserFocus,
                                          passFocus: _primaryXtreamPassFocus,
                                          submitFocus: _primarySubmitFocus,
                                        ),
                                ),
                              ],
                            ),
                          ),
                          if (showSecondaryPlaylistUi) ...[
                            const SizedBox(height: 16),
                            _GlassCard(
                              child: Obx(() {
                                final en = controller.enableSecondary.value;
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'playlist.secondaryTitle'.tr,
                                      style: text.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                        color: const Color(0xFFF8FAFC),
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'playlist.secondarySubtitle'.tr,
                                      style: text.bodyMedium?.copyWith(
                                        color: const Color(0xFFCBD5E1),
                                        fontWeight: FontWeight.w500,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _TvToggleRow(
                                      value: en,
                                      focusNode: _secondaryEnableFocus,
                                      isTv: isTv,
                                      title: 'playlist.secondaryEnable'.tr,
                                      onChanged: (v) {
                                        controller.enableSecondary.value = v;
                                      },
                                      activeColor: _minaGreen,
                                    ),
                                    if (en)
                                      Obx(() {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const SizedBox(height: 8),
                                            _SourceTabs(
                                              index: controller
                                                  .secondaryTabIndex.value,
                                              onChanged:
                                                  controller.setSecondaryTab,
                                              cs: cs,
                                              m3uFocus: _secondaryM3uTabFocus,
                                              xtreamFocus:
                                                  _secondaryXtreamTabFocus,
                                              isTv: isTv,
                                            ),
                                            const SizedBox(height: 14),
                                            controller.secondaryTabIndex
                                                        .value ==
                                                    0
                                                ? _M3uSecondaryTab(
                                                    controller: controller,
                                                    denseStyle:
                                                        _denseFieldStyle,
                                                    cs: cs,
                                                    isTv: isTv,
                                                    urlFocus:
                                                        _secondaryM3uUrlFocus,
                                                    filePickFocus:
                                                        _secondaryM3uFilePickFocus,
                                                  )
                                                : _XtreamSecondaryTab(
                                                    controller: controller,
                                                    denseStyle:
                                                        _denseFieldStyle,
                                                    cs: cs,
                                                    isTv: isTv,
                                                    serverFocus:
                                                        _secondaryXtreamServerFocus,
                                                    userFocus:
                                                        _secondaryXtreamUserFocus,
                                                    passFocus:
                                                        _secondaryXtreamPassFocus,
                                                    submitFocus:
                                                        _secondarySubmitFocus,
                                                  ),
                                          ],
                                        );
                                      }),
                                  ],
                                );
                              }),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Obx(
                            () => _GlassButton(
                              onPressed: (controller.isLoading.value || !controller.canSubmit.value)
                                  ? null
                                  : controller.submit,
                              isLoading: controller.isLoading.value,
                              label: controller.isLoading.value
                                  ? 'common.loading'.tr
                                  : 'playlist.loadList'.tr,
                              icon: Icons.rocket_launch_rounded,
                              focusNode: _primarySubmitFocus,
                              isTv: isTv,
                            ),
                          ),
                          if (isTv) ...[
                            const SizedBox(height: 14),
                            Obx(
                              () => _GlassButton(
                                onPressed: controller.isLoading.value
                                    ? null
                                    : controller.loadDemoPlaylist,
                                isLoading: controller.isLoading.value,
                                label: 'playlist.demoList'.tr,
                                icon: Icons.play_circle_outline_rounded,
                                focusNode: _demoFocus,
                                isTv: isTv,
                              ),
                            ),
                          ],
                ],
              ),
            ),
          ),
        ),
      );

      if (useFullScreenBackground) {
        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: AppTheme.screenBackground(
            context,
            cs,
            themeLabel: themeLabel,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [scroll],
          ),
        );
      }
      return scroll;
    });
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xEE0F172A),
                const Color(0xE6121824),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final bool isLoading;
  final FocusNode? focusNode;
  final bool isTv;

  const _GlassButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    this.isLoading = false,
    this.focusNode,
    this.isTv = false,
  });

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final enabled = widget.onPressed != null;

    return Transform.scale(
      scale: widget.isTv && _focused ? 1.05 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          focusNode: widget.focusNode,
          onFocusChange: (v) => setState(() => _focused = v),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: enabled
                    ? [
                        Color.lerp(
                            primary, Colors.white, _focused ? 0.3 : 0.12)!,
                        primary,
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.08),
                      ],
              ),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: (widget.isTv
                                ? const Color(0xFF22C55E)
                                : primary)
                            .withValues(alpha: _focused ? 0.78 : 0.55),
                        blurRadius: _focused ? 26 : 18,
                        spreadRadius: _focused ? 3 : 0,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
              border: Border.all(
                color: _focused
                    ? (widget.isTv ? const Color(0xFF22C55E) : Colors.white)
                    : enabled
                        ? Colors.white.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.18),
                width: _focused ? (widget.isTv ? 2.0 : 2.5) : 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isLoading)
                  const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(widget.icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
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

class _TvToggleRow extends StatefulWidget {
  const _TvToggleRow({
    required this.value,
    required this.title,
    required this.onChanged,
    required this.activeColor,
    required this.focusNode,
    required this.isTv,
  });

  final bool value;
  final String title;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final FocusNode focusNode;
  final bool isTv;

  @override
  State<_TvToggleRow> createState() => _TvToggleRowState();
}

class _TvToggleRowState extends State<_TvToggleRow> {
  bool _focused = false;

  void _toggle() => widget.onChanged(!widget.value);

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.space) {
          _toggle();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggle,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused
                  ? const Color(0xFF22C55E)
                  : Colors.white.withValues(alpha: 0.2),
              width: _focused ? 2 : 1,
            ),
            color: Colors.white.withValues(alpha: _focused ? 0.08 : 0.03),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Switch.adaptive(
                value: widget.value,
                onChanged: (_) => _toggle(),
                activeThumbColor: Colors.white,
                activeTrackColor: widget.activeColor,
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _SourceTabs extends StatelessWidget {
  const _SourceTabs({
    required this.index,
    required this.onChanged,
    required this.cs,
    required this.isTv,
    this.m3uFocus,
    this.xtreamFocus,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final ColorScheme cs;
  final bool isTv;
  final FocusNode? m3uFocus;
  final FocusNode? xtreamFocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: 'M3U',
              selected: index == 0,
              onTap: () => onChanged(0),
              cs: cs,
              isTv: isTv,
              focusNode: m3uFocus,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabChip(
              label: 'Xtream',
              selected: index == 1,
              onTap: () => onChanged(1),
              cs: cs,
              isTv: isTv,
              focusNode: xtreamFocus,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
    required this.isTv,
    this.focusNode,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isTv;
  final FocusNode? focusNode;

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: Focus(
          focusNode: widget.focusNode,
          onFocusChange: (v) => setState(() => _focused = v),
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              FocusScope.of(context).previousFocus();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              FocusScope.of(context).nextFocus();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.space) {
              widget.onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: (widget.isTv && _focused)
                  ? const Color(0xFF22C55E)
                  : widget.selected
                      ? const Color(0xFF22C55E).withValues(alpha: 0.88)
                      : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focused
                    ? const Color(0xFF22C55E)
                    : widget.selected
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.14),
                width: (_focused || widget.selected) ? 2 : 1,
              ),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color:
                            const Color(0xFF22C55E).withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : _focused
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
            ),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: (widget.isTv && _focused)
                      ? Colors.black
                      : (widget.selected || _focused)
                          ? Colors.white
                      : const Color(0xFFE2E8F0),
                  fontWeight: (widget.selected || _focused)
                      ? FontWeight.w800
                      : FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _M3uTab extends StatefulWidget {
  const _M3uTab({
    required this.controller,
    required this.denseStyle,
    required this.cs,
    required this.isTv,
    this.urlFocus,
    this.filePickFocus,
  });

  final PlaylistController controller;
  final TextStyle denseStyle;
  final ColorScheme cs;
  final bool isTv;
  final FocusNode? urlFocus;
  final FocusNode? filePickFocus;

  @override
  State<_M3uTab> createState() => _M3uTabState();
}

class _M3uTabState extends State<_M3uTab> {
  bool _pickFocused = false;

  InputDecoration _fieldDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: const Color(0xFF22C55E),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
        filled: true,
        fillColor: const Color(0xD9070D14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFF22C55E), width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller.m3uUrlController,
          focusNode: widget.urlFocus,
          style: widget.denseStyle,
          decoration:
              _fieldDecoration('playlist.m3uUrl'.tr, Icons.link_rounded),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          scrollPadding: const EdgeInsets.only(bottom: 260),
          onSubmitted: (_) => widget.controller.submit(),
        ),
        const SizedBox(height: 16),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xD9070D14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _pickFocused
                  ? const Color(0xFF22C55E)
                  : Colors.white.withValues(alpha: 0.26),
              width: _pickFocused ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _pickFocused
                    ? const Color(0xFF22C55E).withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.2),
                blurRadius: _pickFocused ? 14 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Focus(
              focusNode: widget.filePickFocus,
              onFocusChange: (v) => setState(() => _pickFocused = v),
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                    event.logicalKey == LogicalKeyboardKey.space) {
                  widget.controller.pickM3uFile();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: InkWell(
                onTap: widget.controller.pickM3uFile,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: AnimatedScale(
                    scale: _pickFocused ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          color: widget.cs.primary.withValues(alpha: 0.95),
                          size: _pickFocused ? 25 : 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'playlist.pickFile'.tr,
                          style: const TextStyle(
                            color: Color(0xFFF1F5F9),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Obx(() {
          final name = widget.controller.m3uLocalFileName.value;
          if (name == null || name.isEmpty) {
            return Text(
              'playlist.noFile'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            );
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: widget.cs.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.file_present_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.white70),
                  onPressed: widget.controller.clearPickedM3uFile,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _XtreamTab extends StatefulWidget {
  const _XtreamTab({
    required this.controller,
    required this.denseStyle,
    required this.cs,
    required this.isTv,
    this.serverFocus,
    this.userFocus,
    this.passFocus,
    this.submitFocus,
  });

  final PlaylistController controller;
  final TextStyle denseStyle;
  final ColorScheme cs;
  final bool isTv;
  final FocusNode? serverFocus;
  final FocusNode? userFocus;
  final FocusNode? passFocus;
  final FocusNode? submitFocus;

  @override
  State<_XtreamTab> createState() => _XtreamTabState();
}

class _XtreamTabState extends State<_XtreamTab> {
  bool _serverFocused = false;
  bool _userFocused = false;
  bool _passFocused = false;

  @override
  void initState() {
    super.initState();
    widget.serverFocus?.addListener(_refreshFocusState);
    widget.userFocus?.addListener(_refreshFocusState);
    widget.passFocus?.addListener(_refreshFocusState);
  }

  @override
  void didUpdateWidget(covariant _XtreamTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverFocus != widget.serverFocus) {
      oldWidget.serverFocus?.removeListener(_refreshFocusState);
      widget.serverFocus?.addListener(_refreshFocusState);
    }
    if (oldWidget.userFocus != widget.userFocus) {
      oldWidget.userFocus?.removeListener(_refreshFocusState);
      widget.userFocus?.addListener(_refreshFocusState);
    }
    if (oldWidget.passFocus != widget.passFocus) {
      oldWidget.passFocus?.removeListener(_refreshFocusState);
      widget.passFocus?.addListener(_refreshFocusState);
    }
  }

  @override
  void dispose() {
    widget.serverFocus?.removeListener(_refreshFocusState);
    widget.userFocus?.removeListener(_refreshFocusState);
    widget.passFocus?.removeListener(_refreshFocusState);
    super.dispose();
  }

  void _refreshFocusState() {
    if (!mounted) return;
    setState(() {
      _serverFocused = widget.serverFocus?.hasFocus ?? false;
      _userFocused = widget.userFocus?.hasFocus ?? false;
      _passFocused = widget.passFocus?.hasFocus ?? false;
    });
  }

  InputDecoration _fieldDecoration(
    String label,
    IconData icon, {
    required bool focused,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color:
              focused ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: const Color(0xFF22C55E),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
        prefixIcon: Icon(
          icon,
          color:
              focused ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
          size: 22,
        ),
        filled: true,
        fillColor: focused
            ? const Color(0xFF22C55E).withValues(alpha: 0.2)
            : const Color(0xD9070D14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFF22C55E), width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller.xtreamBaseUrlController,
          focusNode: widget.serverFocus,
          style: widget.denseStyle,
          decoration:
              _fieldDecoration('playlist.xtream.server'.tr, Icons.dns_rounded,
                  focused: _serverFocused),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          scrollPadding: const EdgeInsets.only(bottom: 260),
          onSubmitted: (_) => widget.userFocus?.requestFocus(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.controller.xtreamUsernameController,
          focusNode: widget.userFocus,
          style: widget.denseStyle,
          decoration: _fieldDecoration(
            'playlist.xtream.user'.tr,
            Icons.person_outline_rounded,
            focused: _userFocused,
          ),
          textInputAction: TextInputAction.next,
          scrollPadding: const EdgeInsets.only(bottom: 260),
          onSubmitted: (_) => widget.passFocus?.requestFocus(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.controller.xtreamPasswordController,
          focusNode: widget.passFocus,
          style: widget.denseStyle,
          decoration: _fieldDecoration(
            'playlist.xtream.pass'.tr,
            Icons.lock_outline_rounded,
            focused: _passFocused,
          ),
          obscureText: true,
          textInputAction: TextInputAction.done,
          scrollPadding: const EdgeInsets.only(bottom: 260),
          onSubmitted: (_) => widget.submitFocus?.requestFocus(),
        ),
        const SizedBox(height: 12),
        ExcludeFocus(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: widget.cs.primary.withValues(alpha: 0.95),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'playlist.xtream.hint'.tr,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _M3uSecondaryTab extends StatefulWidget {
  const _M3uSecondaryTab({
    required this.controller,
    required this.denseStyle,
    required this.cs,
    required this.isTv,
    this.urlFocus,
    this.filePickFocus,
  });

  final PlaylistController controller;
  final TextStyle denseStyle;
  final ColorScheme cs;
  final bool isTv;
  final FocusNode? urlFocus;
  final FocusNode? filePickFocus;

  @override
  State<_M3uSecondaryTab> createState() => _M3uSecondaryTabState();
}

class _M3uSecondaryTabState extends State<_M3uSecondaryTab> {
  bool _pickFocused = false;

  InputDecoration _fieldDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: const Color(0xFF22C55E),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 22),
        filled: true,
        fillColor: const Color(0xD9070D14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFF22C55E), width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller.m3uSecondaryUrlController,
          focusNode: widget.urlFocus,
          style: widget.denseStyle,
          decoration: _fieldDecoration(
            'playlist.secondaryUrlHint'.tr,
            Icons.link_rounded,
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          scrollPadding: const EdgeInsets.only(bottom: 260),
          onSubmitted: (_) => widget.controller.submit(),
        ),
        const SizedBox(height: 16),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xD9070D14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _pickFocused
                  ? const Color(0xFF22C55E)
                  : Colors.white.withValues(alpha: 0.26),
              width: _pickFocused ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Focus(
              focusNode: widget.filePickFocus,
              onFocusChange: (v) => setState(() => _pickFocused = v),
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                    event.logicalKey == LogicalKeyboardKey.space) {
                  widget.controller.pickM3uSecondaryFile();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: InkWell(
                onTap: widget.controller.pickM3uSecondaryFile,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: AnimatedScale(
                    scale: _pickFocused ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          color: widget.cs.primary.withValues(alpha: 0.95),
                          size: _pickFocused ? 25 : 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'playlist.pickFile'.tr,
                          style: const TextStyle(
                            color: Color(0xFFF1F5F9),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Obx(() {
          final name = widget.controller.m3uSecondaryLocalFileName.value;
          if (name == null || name.isEmpty) {
            return Text(
              'playlist.noFile'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            );
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: widget.cs.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.file_present_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.white70),
                  onPressed: widget.controller.clearPickedM3uSecondaryFile,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _XtreamSecondaryTab extends StatefulWidget {
  const _XtreamSecondaryTab({
    required this.controller,
    required this.denseStyle,
    required this.cs,
    required this.isTv,
    this.serverFocus,
    this.userFocus,
    this.passFocus,
    this.submitFocus,
  });

  final PlaylistController controller;
  final TextStyle denseStyle;
  final ColorScheme cs;
  final bool isTv;
  final FocusNode? serverFocus;
  final FocusNode? userFocus;
  final FocusNode? passFocus;
  final FocusNode? submitFocus;

  @override
  State<_XtreamSecondaryTab> createState() => _XtreamSecondaryTabState();
}

class _XtreamSecondaryTabState extends State<_XtreamSecondaryTab> {
  bool _serverFocused = false;
  bool _userFocused = false;
  bool _passFocused = false;

  @override
  void initState() {
    super.initState();
    widget.serverFocus?.addListener(_refreshFocusState);
    widget.userFocus?.addListener(_refreshFocusState);
    widget.passFocus?.addListener(_refreshFocusState);
  }

  @override
  void didUpdateWidget(covariant _XtreamSecondaryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverFocus != widget.serverFocus) {
      oldWidget.serverFocus?.removeListener(_refreshFocusState);
      widget.serverFocus?.addListener(_refreshFocusState);
    }
    if (oldWidget.userFocus != widget.userFocus) {
      oldWidget.userFocus?.removeListener(_refreshFocusState);
      widget.userFocus?.addListener(_refreshFocusState);
    }
    if (oldWidget.passFocus != widget.passFocus) {
      oldWidget.passFocus?.removeListener(_refreshFocusState);
      widget.passFocus?.addListener(_refreshFocusState);
    }
  }

  @override
  void dispose() {
    widget.serverFocus?.removeListener(_refreshFocusState);
    widget.userFocus?.removeListener(_refreshFocusState);
    widget.passFocus?.removeListener(_refreshFocusState);
    super.dispose();
  }

  void _refreshFocusState() {
    if (!mounted) return;
    setState(() {
      _serverFocused = widget.serverFocus?.hasFocus ?? false;
      _userFocused = widget.userFocus?.hasFocus ?? false;
      _passFocused = widget.passFocus?.hasFocus ?? false;
    });
  }

  InputDecoration _fieldDecoration(
    String label,
    IconData icon, {
    required bool focused,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color:
              focused ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: const Color(0xFF22C55E),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
        prefixIcon: Icon(
          icon,
          color:
              focused ? const Color(0xFF22C55E) : const Color(0xFF94A3B8),
          size: 22,
        ),
        filled: true,
        fillColor: focused
            ? const Color(0xFF22C55E).withValues(alpha: 0.2)
            : const Color(0xD9070D14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.26)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFF22C55E), width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller.xtreamSecondaryBaseUrlController,
          focusNode: widget.serverFocus,
          style: widget.denseStyle,
          decoration:
              _fieldDecoration('playlist.xtream.server'.tr, Icons.dns_rounded,
                  focused: _serverFocused),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          scrollPadding: const EdgeInsets.only(bottom: 260),
          onSubmitted: (_) => widget.userFocus?.requestFocus(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.controller.xtreamSecondaryUsernameController,
          focusNode: widget.userFocus,
          style: widget.denseStyle,
          decoration: _fieldDecoration(
            'playlist.xtream.user'.tr,
            Icons.person_outline_rounded,
            focused: _userFocused,
          ),
          textInputAction: TextInputAction.next,
          scrollPadding: const EdgeInsets.only(bottom: 260),
          onSubmitted: (_) => widget.passFocus?.requestFocus(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.controller.xtreamSecondaryPasswordController,
          focusNode: widget.passFocus,
          style: widget.denseStyle,
          decoration: _fieldDecoration(
            'playlist.xtream.pass'.tr,
            Icons.lock_outline_rounded,
            focused: _passFocused,
          ),
          obscureText: true,
          textInputAction: TextInputAction.done,
          scrollPadding: const EdgeInsets.only(bottom: 260),
          onSubmitted: (_) => widget.submitFocus?.requestFocus(),
        ),
        const SizedBox(height: 12),
        ExcludeFocus(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: widget.cs.primary.withValues(alpha: 0.95),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'playlist.xtream.hint'.tr,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
