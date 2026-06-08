import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/services/playlist_qr_server_service.dart';
import '../playlist_controller.dart';

/// **Karekod ile playlist yükleme diyaloğu.**
///
/// Açılışta `PlaylistQrServerService.start()` çağrılır → cihazın yerel IP
/// ve dinamik port ile URL üretilir → QR kod render edilir. Telefondan
/// POST gelir gelmez `submissionStream` event yayar; dialog veriyi
/// `PlaylistController`'a yansıtır, `submit()` çağırır, sunucuyu kapatır
/// ve kapanır.
class PlaylistQrLoaderDialog extends StatefulWidget {
  const PlaylistQrLoaderDialog({super.key});

  /// Diyalogu standart `showDialog` ile açar.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const PlaylistQrLoaderDialog(),
    );
  }

  @override
  State<PlaylistQrLoaderDialog> createState() => _PlaylistQrLoaderDialogState();
}

class _PlaylistQrLoaderDialogState extends State<PlaylistQrLoaderDialog> {
  final _server = PlaylistQrServerService();
  StreamSubscription<QrPlaylistSubmission>? _sub;

  String? _url;
  String? _error;
  bool _waiting = true;
  bool _consumed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      final url = await _server.start();
      if (!mounted) return;
      setState(() {
        _url = url;
        _waiting = true;
      });
      _sub = _server.submissionStream.listen(_onSubmission);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _waiting = false;
      });
    }
  }

  Future<void> _onSubmission(QrPlaylistSubmission sub) async {
    if (_consumed) return;
    _consumed = true;
    final controller = Get.find<PlaylistController>();
    controller.applyQrSubmission(sub);
    // Sunucuyu kapatmak için kısa bir delay — telefonun cevabı almasına izin.
    Future.delayed(const Duration(milliseconds: 400), _server.stop);
    if (!mounted) return;
    Navigator.of(context).pop();
    HapticFeedback.mediumImpact();
    // submit'i controller `applyQrSubmission` sonunda kendisi tetikleyecek.
  }

  @override
  void dispose() {
    _sub?.cancel();
    unawaited(_server.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xEE0F172A), Color(0xE6121824)],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'playlist.qr.title'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'common.close'.tr,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'playlist.qr.subtitle'.tr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              if (_error != null)
                _ErrorBlock(error: _error!, onRetry: _retry)
              else if (_url == null)
                const _LoadingBlock()
              else
                _QrBlock(url: _url!, waiting: _waiting),
              if (_url != null) ...[
                const SizedBox(height: 16),
                _UrlPill(url: _url!),
              ],
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'playlist.qr.hint'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _retry() {
    setState(() {
      _error = null;
      _waiting = true;
      _url = null;
    });
    unawaited(_boot());
  }
}

// =============================================================================
// İç widget'lar.
// =============================================================================

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 0.6,
        ),
      ),
      child: const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(strokeWidth: 2.6),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B47).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF3B47).withValues(alpha: 0.40),
          width: 0.6,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Color(0xFFFFAFB5)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'playlist.qr.error.title'.tr,
                  style: const TextStyle(
                    color: Color(0xFFFFD1D5),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'playlist.qr.error.sub'.tr,
            style: TextStyle(
              color: const Color(0xFFFFD1D5).withValues(alpha: 0.85),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: Text(
              'common.retry'.tr,
              style: const TextStyle(color: Colors.white),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.30),
                width: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrBlock extends StatelessWidget {
  const _QrBlock({required this.url, required this.waiting});

  final String url;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: url,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0F172A),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0F172A),
            ),
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            gapless: false,
          ),
          if (waiting) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'playlist.qr.waiting'.tr,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UrlPill extends StatelessWidget {
  const _UrlPill({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.6,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('playlist.qr.urlCopied'.tr),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.copy_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
