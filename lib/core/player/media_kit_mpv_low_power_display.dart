import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// SM-T530 veya ayarlarda «düşük güç / eski kutu» açıkken mor/pembe renk için yazılım çözücü.
///
/// `hwdec=no`; `vd-lavc-fast` / `vd-lavc-skiploopfilter` [PlayerController.applyMediaKitLibmpvPlaybackOptions] içinde.
Future<void> applyMediaKitMpvPurpleFixOptions(NativePlayer plat) async {
  try {
    await plat.setProperty('hwdec', 'no');
    await plat.setProperty('sws-scaler', 'fast-bilinear');
  } catch (e, st) {
    debugPrint('mina_iptv: MediaKit purple-fix (sw decode) options: $e\n$st');
  }
}
