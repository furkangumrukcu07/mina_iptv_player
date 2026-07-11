import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Yazılım kod çözücü (`hwdec=no`): mor/pembe/siyah ekran için son çare.
Future<void> applyMediaKitMpvPurpleFixOptions(NativePlayer plat) async {
  try {
    await plat.setProperty('hwdec', 'no');
    await plat.setProperty('colormatrix', 'auto');
    await plat.setProperty('sws-scaler', 'fast-bilinear');
  } catch (e, st) {
    debugPrint('mina_iptv: MediaKit purple-fix (sw decode) options: $e\n$st');
  }
}
