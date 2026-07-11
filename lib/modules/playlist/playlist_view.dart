import 'dart:async' show unawaited;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/layout/app_layout_mode.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_settings_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/google_cloud_sign_in_panel.dart';
import '../../ui/tv_dpad_focus.dart';
import '../setup/setup_wizard_controller.dart';
import 'playlist_controller.dart';
import 'widgets/playlist_qr_loader_dialog.dart';
import 'widgets/playlist_source_setup_form.dart';

class PlaylistView extends StatefulWidget {
  const PlaylistView({super.key, this.setupWizardEmbed = false});

  /// `true`: yalnızca birincil kaynak formu; [Scaffold] yok (kurulum sihirbazı içinde).
  final bool setupWizardEmbed;

  @override
  State<PlaylistView> createState() => _PlaylistViewState();
}

class _PlaylistViewState extends State<PlaylistView> {
  final controller = Get.find<PlaylistController>();
  bool get _showCloudSignIn =>
      Get.isRegistered<AuthService>() &&
      Get.find<AuthService>().isCloudBackupSupported;
  final _scrollController = ScrollController();
  final _backFocus = FocusNode(debugLabel: 'playlistBack');
  final _firstKindFocus = FocusNode(debugLabel: 'playlistFirstKind');
  Orientation? _lastOrientation;

  @override
  void dispose() {
    _scrollController.dispose();
    _backFocus.dispose();
    _firstKindFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final o = MediaQuery.orientationOf(context);
    if (_lastOrientation != null && _lastOrientation != o) {
      FocusManager.instance.primaryFocus?.unfocus();
      unawaited(
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide'),
      );
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
    _lastOrientation = o;
  }

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

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return PopScope(
      canPop: !isTv || !keyboardOpen,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (isTv && keyboardOpen) {
          unawaited(
            SystemChannels.textInput.invokeMethod<void>('TextInput.hide'),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: isTv
              ? TvIconButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: Get.back,
                  tooltip: 'common.back'.tr,
                  focusNode: _backFocus,
                  arrowDown: _firstKindFocus,
                )
              : null,
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
            isTv
                ? TvIconButton(
                    icon: Icons.settings_outlined,
                    onPressed: () => Get.toNamed(AppRoutes.settings),
                    tooltip: 'settings.title'.tr,
                  )
                : IconButton(
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
    final appSettings = Get.find<AppSettingsService>();
    final isTv = appSettings.layoutMode.value == AppLayoutMode.tv;
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final topPad = useFullScreenBackground
        ? (isTv ? 24.0 : (landscape ? 56.0 : 100.0))
        : (isTv ? 12.0 : 4.0);

    return Obx(() {
      final themeLabel = appSettings.themeLabel.value;
      final scroll = FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: SingleChildScrollView(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, topPad, 16, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_showCloudSignIn) ...[
                    Obx(() {
                      final ctrl = Get.find<SetupWizardController>();
                      return GoogleCloudSignInCard(
                        isBusy: ctrl.isCloudBusy.value,
                        onSignIn: ctrl.isCloudBusy.value
                            ? null
                            : () => unawaited(ctrl.signInWithGoogleAndSync()),
                      );
                    }),
                    const SizedBox(height: 14),
                    const CloudSignInOrDivider(),
                    const SizedBox(height: 14),
                  ],
                  _GlassCard(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
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
                        PlaylistSourceSetupForm(
                          controller: controller,
                          includeDemo: true,
                          primaryActionLabel: 'playlist.loadList'.tr,
                          firstKindFocusNode:
                              useFullScreenBackground && isTv
                                  ? _firstKindFocus
                                  : null,
                          topFocusNode: useFullScreenBackground && isTv
                              ? _backFocus
                              : null,
                          autofocusFirstOnTv:
                              useFullScreenBackground && isTv,
                        ),
                      ],
                    ),
                  ),
                  // Karekod ile yükleme: TV/aynı Wi-Fi'da telefondan
                  // POST ile M3U/Xtream verisi alır; sunucu sadece dialog
                  // açıkken çalışır, bulut/veritabanı kullanılmaz.
                  const SizedBox(height: 16),
                  _QrLoaderCard(text: text, isTv: isTv),
                  // «Ek liste» bölümü artık ayrı bir alt sayfada — kullanıcı
                  // 2 ile sınırlı kalmadan istediği kadar liste ekleyebiliyor.
                  // Eski `_GlassCard` (toggle + 2 sekmeli mini-form) yerine
                  // "Liste Yönetimi" alt sayfasına yönlendiren tek bir cam
                  // tile bırakıyoruz. Birincil kaynak formu üstte aynen kalır.
                  if (showSecondaryPlaylistUi) ...[
                    const SizedBox(height: 16),
                    _PlaylistsManagerEntryCard(text: text, isTv: isTv),
                  ],
                  const SizedBox(height: 16),
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

/// Playlist kurulum sayfasında "ikinci kaynak" mini-formunun yerine geçen
/// kart. Tek dokunuşla `AppRoutes.playlistsManager`'a yönlendirir — sınırsız
/// liste (slot 2, 3, … 32) eklenebilen ayrı sayfa.
/// **Karekod ile playlist yükleme cam kartı.**
///
/// Birincil M3U/Xtream formunun hemen altına yerleşir. Tıklanınca
/// [PlaylistQrLoaderDialog] açılır → telefondan POST geldiğinde
/// `PlaylistController.applyQrSubmission` ile veri akar ve otomatik
/// `submit` tetiklenir.
class _QrLoaderCard extends StatelessWidget {
  const _QrLoaderCard({
    required this.text,
    required this.isTv,
  });

  final TextTheme text;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      child: tvDpadActivateWrap(
        context,
        onActivate: () => PlaylistQrLoaderDialog.show(context),
        borderRadius: 18,
        child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => PlaylistQrLoaderDialog.show(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withValues(alpha: 0.22),
                  ),
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    color: cs.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'playlist.qrEntry.title'.tr,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: isTv ? 18 : 16,
                          color: const Color(0xFFF8FAFC),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'playlist.qrEntry.body'.tr,
                        style: text.bodyMedium?.copyWith(
                          color: const Color(0xFFCBD5E1),
                          fontSize: isTv ? 13.5 : 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.75),
                  size: 26,
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

class _PlaylistsManagerEntryCard extends StatelessWidget {
  const _PlaylistsManagerEntryCard({
    required this.text,
    required this.isTv,
  });

  final TextTheme text;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      child: tvDpadActivateWrap(
        context,
        onActivate: () => Get.toNamed(AppRoutes.playlistsManager),
        borderRadius: 18,
        child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Get.toNamed(AppRoutes.playlistsManager),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.primary.withValues(alpha: 0.22),
                  ),
                  child: Icon(
                    Icons.queue_play_next_rounded,
                    color: cs.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'playlist.managerEntry.title'.tr,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: isTv ? 18 : 16,
                          color: const Color(0xFFF8FAFC),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'playlist.managerEntry.body'.tr,
                        style: text.bodyMedium?.copyWith(
                          color: const Color(0xFFCBD5E1),
                          fontSize: isTv ? 13.5 : 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.75),
                  size: 26,
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
