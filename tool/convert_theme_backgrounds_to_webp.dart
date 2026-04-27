import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:swipelab_webp/swipelab_webp.dart';

/// Generates `.webp` theme background variants under:
/// - `assets/images/*.webp` (1x)
/// - `assets/images/2x/*.webp` (2x)
/// - `assets/images/3x/*.webp` (3x)
///
/// Source images are expected as `.png` in `assets/images/`.
///
/// Output sizing policy (exact pixels via cover+center-crop):
/// - Landscape (non-portrait filenames): 1x 1280x720, 2x 2560x1440, 3x 3840x2160
/// - Portrait filenames (contains `_portrait`): 1x 720x1600, 2x 1440x3200, 3x 2160x4800
///
/// Notes:
/// - If your source PNG is lower-res than the target, this script will upscale.
///   For best results, replace the source PNGs with high-res originals first.
Future<void> main(List<String> args) async {
  final projectRoot = Directory.current.path;
  final baseDir = Directory('$projectRoot/assets/images');
  if (!baseDir.existsSync()) {
    stderr.writeln('Missing assets dir: ${baseDir.path}');
    exitCode = 2;
    return;
  }

  final names = <String>[
    'home_background',
    'home_background_portrait',
    'dark_glass_koyu_cam',
    'dark_flat_background',
    'dark_flat_background_portrait',
    'glass_gri_background',
    'glass_gri_background_portrait',
    'flat_black_background',
    'flat_black_background_portrait',
    'glassmorphism_background',
    'glassmorphism_background_portrait',
  ];

  final out1x = Directory('${baseDir.path}');
  final out2x = Directory('${baseDir.path}/2x')..createSync(recursive: true);
  final out3x = Directory('${baseDir.path}/3x')..createSync(recursive: true);

  for (final n in names) {
    final src = File('${baseDir.path}/$n.png');
    if (!src.existsSync()) {
      stderr.writeln('Skip (missing): ${src.path}');
      continue;
    }

    final bytes = src.readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      stderr.writeln('Skip (decode failed): ${src.path}');
      continue;
    }

    final isPortrait = n.contains('_portrait');
    final targets = <(Directory dir, int w, int h)>[
      (out1x, isPortrait ? 720 : 1280, isPortrait ? 1600 : 720),
      (out2x, isPortrait ? 1440 : 2560, isPortrait ? 3200 : 1440),
      (out3x, isPortrait ? 2160 : 3840, isPortrait ? 4800 : 2160),
    ];

    for (final t in targets) {
      final resized = _resizeCoverCrop(decoded, t.$2, t.$3);
      final out = File('${t.$1.path}/$n.webp');
      final rgba = Uint8List.fromList(
        resized.getBytes(order: img.ChannelOrder.rgba),
      );
      final encoded = WebPEncoder.encodeRgba(
        rgba: rgba,
        width: resized.width,
        height: resized.height,
        quality: 92,
      );
      if (encoded == null) {
        stderr.writeln('Skip (webp encode failed): ${out.path}');
        continue;
      }
      out.writeAsBytesSync(encoded, flush: true);
      stdout.writeln('Wrote: ${out.path} (${t.$2}x${t.$3})');
    }
  }
}

img.Image _resizeCoverCrop(img.Image src, int targetW, int targetH) {
  final srcW = src.width;
  final srcH = src.height;
  final scale = (targetW / srcW) > (targetH / srcH)
      ? (targetW / srcW)
      : (targetH / srcH);
  final resizedW = (srcW * scale).round().clamp(1, 100000);
  final resizedH = (srcH * scale).round().clamp(1, 100000);

  final resized = img.copyResize(
    src,
    width: resizedW,
    height: resizedH,
    interpolation: img.Interpolation.cubic,
  );

  final x = ((resized.width - targetW) / 2).round().clamp(0, resized.width - 1);
  final y =
      ((resized.height - targetH) / 2).round().clamp(0, resized.height - 1);
  final w = targetW.clamp(1, resized.width);
  final h = targetH.clamp(1, resized.height);
  return img.copyCrop(resized, x: x, y: y, width: w, height: h);
}

