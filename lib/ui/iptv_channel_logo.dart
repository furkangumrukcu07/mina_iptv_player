import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/services/iptv_logo_cache_service.dart';

/// Kanal logosu: önce [IptvLogoCacheService] ile disk önbelleği, yoksa ağ.
class IptvChannelLogo extends StatelessWidget {
  const IptvChannelLogo({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.showProgressIndicator = false,
    this.progressIndicatorColor = Colors.white38,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool showProgressIndicator;
  final Color progressIndicatorColor;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    if (width.isFinite && height.isFinite) {
      return _IptvChannelLogoBody(
        key: ValueKey(imageUrl.trim()),
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        borderRadius: borderRadius,
        placeholder: placeholder,
        errorWidget: errorWidget,
        showProgressIndicator: showProgressIndicator,
        progressIndicatorColor: progressIndicatorColor,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final w = width.isFinite ? width : c.maxWidth.clamp(1.0, 4096.0);
        final h = height.isFinite ? height : c.maxHeight.clamp(1.0, 4096.0);
        return _IptvChannelLogoBody(
          key: ValueKey(imageUrl.trim()),
          imageUrl: imageUrl,
          width: w,
          height: h,
          fit: fit,
          borderRadius: borderRadius,
          placeholder: placeholder,
          errorWidget: errorWidget,
          showProgressIndicator: showProgressIndicator,
          progressIndicatorColor: progressIndicatorColor,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
        );
      },
    );
  }
}

class _IptvChannelLogoBody extends StatefulWidget {
  const _IptvChannelLogoBody({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fit,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    required this.showProgressIndicator,
    required this.progressIndicatorColor,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool showProgressIndicator;
  final Color progressIndicatorColor;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  State<_IptvChannelLogoBody> createState() => _IptvChannelLogoBodyState();
}

class _IptvChannelLogoBodyState extends State<_IptvChannelLogoBody> {
  File? _file;
  bool _busy = true;
  bool _failed = false;
  late String _url;

  @override
  void initState() {
    super.initState();
    _url = widget.imageUrl.trim();
    _resolve();
  }

  @override
  void didUpdateWidget(_IptvChannelLogoBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final n = widget.imageUrl.trim();
    if (n != _url) {
      _url = n;
      _file = null;
      _failed = false;
      _busy = true;
      _resolve();
    }
  }

  bool _urlOk(String u) {
    if (u.isEmpty) return false;
    final uri = Uri.tryParse(u);
    if (uri == null || !uri.hasScheme) return false;
    final s = uri.scheme.toLowerCase();
    return s == 'http' || s == 'https';
  }

  Future<void> _resolve() async {
    if (!_urlOk(_url)) {
      if (mounted) {
        setState(() {
          _failed = true;
          _busy = false;
        });
      }
      return;
    }
    if (!Get.isRegistered<IptvLogoCacheService>()) {
      if (mounted) {
        setState(() {
          _failed = true;
          _busy = false;
        });
      }
      return;
    }
    final svc = Get.find<IptvLogoCacheService>();
    var f = await svc.getCachedFile(_url);
    f ??= await svc.warm(_url);
    if (!mounted) return;
    if (widget.imageUrl.trim() != _url) return;
    setState(() {
      _busy = false;
      _file = f;
      _failed = f == null;
    });
  }

  Widget _sized(Widget child) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );
  }

  Widget _networkFallback() {
    final mw = widget.memCacheWidth ??
        (widget.width * MediaQuery.devicePixelRatioOf(context)).round();
    final mh = widget.memCacheHeight ??
        (widget.height * MediaQuery.devicePixelRatioOf(context)).round();
    return CachedNetworkImage(
      imageUrl: _url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      memCacheWidth: mw.clamp(1, 4096),
      memCacheHeight: mh.clamp(1, 4096),
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      filterQuality: FilterQuality.high,
      progressIndicatorBuilder: widget.showProgressIndicator
          ? (_, __, ___) => _sized(
                Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.progressIndicatorColor,
                    ),
                  ),
                ),
              )
          : null,
      placeholder: widget.showProgressIndicator
          ? null
          : (_, __) => _sized(
                widget.placeholder ??
                    ColoredBox(
                      color: Colors.black.withValues(alpha: 0.18),
                      child: const SizedBox.expand(),
                    ),
              ),
      errorWidget: (_, __, ___) =>
          _sized(widget.errorWidget ?? const SizedBox.expand()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_urlOk(_url)) {
      return _sized(widget.errorWidget ?? const SizedBox.expand());
    }

    if (!Get.isRegistered<IptvLogoCacheService>()) {
      Widget net = _networkFallback();
      if (widget.borderRadius != null) {
        net = ClipRRect(borderRadius: widget.borderRadius!, child: net);
      }
      return net;
    }

    if (_failed && !_busy) {
      return _sized(widget.errorWidget ?? const SizedBox.expand());
    }

    if (_file != null) {
      final cw = widget.memCacheWidth ??
          (widget.width * MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(1, 4096);
      final ch = widget.memCacheHeight ??
          (widget.height * MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(1, 4096);
      Widget img = Image.file(
        _file!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        filterQuality: FilterQuality.low,
        cacheWidth: cw,
        cacheHeight: ch,
        errorBuilder: (_, __, ___) =>
            _sized(widget.errorWidget ?? const SizedBox.expand()),
      );
      if (widget.borderRadius != null) {
        img = ClipRRect(borderRadius: widget.borderRadius!, child: img);
      }
      return img;
    }

    if (widget.showProgressIndicator) {
      return _sized(
        Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.progressIndicatorColor,
            ),
          ),
        ),
      );
    }

    return _sized(
      widget.placeholder ??
          ColoredBox(
            color: Colors.black.withValues(alpha: 0.18),
            child: const SizedBox.expand(),
          ),
    );
  }
}
