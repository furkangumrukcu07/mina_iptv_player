import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ToastService extends GetxService {
  final _queue = <_ToastData>[];
  bool _isShowing = false;
  OverlayEntry? _currentEntry;

  String? _lastMessage;
  DateTime? _lastTime;

  /// Ekranda bir uyarı gösterir.
  /// [message] Gösterilecek mesaj.
  /// [title] Opsiyonel başlık.
  /// [isError] Hata uyarısı mı (Kırmızı tonlu) yoksa bilgi mi.
  void show(String message, {String? title, bool isError = false}) {
    final now = DateTime.now();

    // Anti-spam: Aynı mesaj çok kısa süre içinde tekrar gelirse yoksay (2 saniye)
    if (_lastMessage == message &&
        _lastTime != null &&
        now.difference(_lastTime!) < const Duration(seconds: 2)) {
      return;
    }

    // Kuyrukta aynısı varsa ekleme
    if (_queue
        .any((element) => element.message == message && element.title == title))
      return;

    _lastMessage = message;
    _lastTime = now;

    _queue.add(_ToastData(message: message, title: title, isError: isError));
    _processQueue();
  }

  void _processQueue() {
    if (_isShowing || _queue.isEmpty) return;

    _isShowing = true;
    final data = _queue.removeAt(0);
    _showToast(data);
  }

  void _showToast(_ToastData data) {
    final context = Get.overlayContext ?? Get.context;
    if (context == null) {
      _isShowing = false;
      return;
    }

    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) {
      _isShowing = false;
      return;
    }

    _currentEntry = OverlayEntry(
      builder: (context) => _GlassToastWidget(
        message: data.message,
        title: data.title,
        isError: data.isError,
        onDismissed: () {
          _currentEntry?.remove();
          _currentEntry = null;
          _isShowing = false;
          // Kısa bir bekleme sonrası sıradaki uyarıya geç
          Future.delayed(const Duration(milliseconds: 300), _processQueue);
        },
      ),
    );

    overlayState.insert(_currentEntry!);
  }
}

class _ToastData {
  final String message;
  final String? title;
  final bool isError;
  _ToastData({required this.message, this.title, required this.isError});
}

class _GlassToastWidget extends StatefulWidget {
  final String message;
  final String? title;
  final bool isError;
  final VoidCallback onDismissed;

  const _GlassToastWidget({
    required this.message,
    this.title,
    required this.isError,
    required this.onDismissed,
  });

  @override
  State<_GlassToastWidget> createState() => _GlassToastWidgetState();
}

class _GlassToastWidgetState extends State<_GlassToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();

    // 3 saniye sonra kapat
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismissed());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
                minWidth: 120,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isError
                    ? Colors.red.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isError ? Icons.error_outline : Icons.info_outline,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.title != null && widget.title!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              widget.title!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                        Text(
                          widget.message,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ],
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
