import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../layout/app_layout_mode.dart';

const MethodChannel kMinaDeviceLayoutChannel =
    MethodChannel('mina.device/layout');

/// Android TV / Google TV (Leanback): [true]. Telefon ve tablet: [false].
Future<bool> nativeAndroidTv() async {
  if (!Platform.isAndroid) return false;
  try {
    final v = await kMinaDeviceLayoutChannel.invokeMethod<bool>('isAndroidTv');
    return v ?? false;
  } on Exception {
    return false;
  }
}

double _shortestSideDips() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return 0;
  final view = views.first;
  final ps = view.physicalSize;
  if (ps.shortestSide <= 0) return 0;
  final dpr = view.devicePixelRatio;
  if (dpr <= 0) return 0;
  return ps.shortestSide / dpr;
}

/// Kayıtlı tercih yokken: TV kutusu → [AppLayoutMode.tv], telefon → [mobile],
/// büyük dokunmatik tablet → [tablet]. iOS / diğer: ekran boyutuna göre tablet/mobil.
Future<AppLayoutMode> resolveDefaultLayoutMode() async {
  if (await nativeAndroidTv()) {
    return AppLayoutMode.tv;
  }
  final dip = _shortestSideDips();
  if (dip >= 600) {
    return AppLayoutMode.tablet;
  }
  return AppLayoutMode.mobile;
}
