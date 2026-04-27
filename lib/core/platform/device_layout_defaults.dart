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

/// TV / büyük panel ile telefonu ayırmak için: bundan dar ekran = el cihazı (telefon).
const double kLayoutHandheldMaxShortestDip = 600;

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

double _longestSideDips() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return 0;
  final view = views.first;
  final ps = view.physicalSize;
  if (ps.width <= 0 || ps.height <= 0) return 0;
  final dpr = view.devicePixelRatio;
  if (dpr <= 0) return 0;
  final w = ps.width / dpr;
  final h = ps.height / dpr;
  return w > h ? w : h;
}

/// Anlık pencere en dar kenar uzunluğu (dp), bilinmiyorsa 0.
double readShortestSideDips() => _shortestSideDips();

/// En uzun kenar (dp) — 1080p TV’de kısa kenar ~540 iken “telefon” sanılmasın diye kullanılır.
double readLongestSideDips() => _longestSideDips();

/// Kayıtlı tercih yokken: Android TV/Leanback önce, sonra ekran oranı.
/// 1920×1080 TV’de kısa kenar genelde 480–600 dp arası; sadece kısa kenara bakmak TV’yi “telefon” yapıyordu.
Future<AppLayoutMode> resolveDefaultLayoutMode() async {
  if (await nativeAndroidTv()) {
    return AppLayoutMode.tv;
  }

  final dip = _shortestSideDips();
  final longDip = _longestSideDips();

  if (dip > 0 && dip < kLayoutHandheldMaxShortestDip) {
    if (longDip == 0 || longDip < 720) {
      return AppLayoutMode.mobile;
    }
    if (longDip < 800) {
      return AppLayoutMode.mobile;
    }
    if (dip < 500) {
      return AppLayoutMode.mobile;
    }
    if (longDip >= 900) {
      return AppLayoutMode.tv;
    }
    return AppLayoutMode.tablet;
  }

  if (dip >= kLayoutHandheldMaxShortestDip) {
    return AppLayoutMode.tablet;
  }
  // İlk kare: views / dp henüz 0 — mobil yerine büyük panel varsayımı (kutu/Tablet daha olası)
  return AppLayoutMode.tablet;
}
