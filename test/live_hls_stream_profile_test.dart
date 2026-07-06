import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tomtv tipi 10sn segment manifest uzun segment sayılır', () {
    const manifest = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXTINF:10.000000,
seg1.ts
#EXTINF:10.000000,
seg2.ts
''';
    expect(_detectForTest(manifest), isTrue);
  });

  test('çoklu EXT-X-STREAM-INF ABR — uzun segment profili devreye girmez', () {
    const manifest = '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=3000000
low/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=6000000
high/index.m3u8
''';
    expect(_detectForTest(manifest, variantCount: 2), isFalse);
  });

  test('4sn segment normal HLS — profil kapalı', () {
    const manifest = '''
#EXTM3U
#EXT-X-TARGETDURATION:4
#EXTINF:4.000000,
seg.ts
''';
    expect(_detectForTest(manifest), isFalse);
  });
}

bool _detectForTest(String manifest, {int variantCount = 0}) {
  if (variantCount > 1) return false;
  final lines = manifest.split('\n');
  var targetDuration = 0.0;
  final extinfs = <double>[];
  for (final raw in lines) {
    final line = raw.trim();
    if (line.startsWith('#EXT-X-TARGETDURATION:')) {
      targetDuration =
          double.tryParse(line.substring('#EXT-X-TARGETDURATION:'.length)) ??
              0;
    } else if (line.startsWith('#EXTINF:')) {
      final val = line.substring('#EXTINF:'.length).split(',').first.trim();
      final d = double.tryParse(val);
      if (d != null && d > 0) extinfs.add(d);
    }
  }
  final avg = extinfs.isEmpty
      ? targetDuration
      : extinfs.reduce((a, b) => a + b) / extinfs.length;
  return targetDuration >= 8 || avg >= 7.5;
}
