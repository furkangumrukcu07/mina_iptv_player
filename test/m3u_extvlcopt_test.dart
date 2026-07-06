import 'package:flutter_test/flutter_test.dart';
import 'package:mina_iptv_player/data/remote/m3u_parser.dart';
import 'package:mina_iptv_player/data/remote/m3u_stream_parser.dart';

/// prectv / deathless tarzı listelerde her giriş #EXTINF ile URL arasında bir
/// #EXTVLCOPT (ve bazen #EXTSUB) satırı taşır. Eski parser bu satırı görünce
/// girişi iptal ediyordu → binlerce film/dizi sessizce kayboluyordu.
const _sample = '''#EXTM3U
#EXTINF:-1 tvg-logo="http://x/p1.jpg" group-title="Tüm Filmler",Film Bir
#EXTVLCOPT:http-user-agent=okhttp/4.12.0
https://load.prectv.lol/hls/1/a.mp4/index.m3u8
#EXTINF:-1 tvg-logo="http://x/p2.jpg" group-title="Tüm Filmler",Film İki
#EXTVLCOPT:http-user-agent=okhttp/4.12.0
https://load.prectv.lol/hls/1/b.mp4/index.m3u8
#EXTINF:-1 tvg-logo="http://x/d1.jpg" group-title="Tüm Dizileri",Dizi Bir - 1. Bölüm
#EXTVLCOPT:http-user-agent=okhttp/4.12.0
#EXTSUB:https://x/tr.vtt
https://load.prectv.lol/hls/2/c.mp4/index.m3u8
#EXTINF:-1 group-title="DeaTHLesS-TV",Canli Kanal
http://x/live/u/p/1.ts
''';

void main() {
  test('M3uParser keeps entries with #EXTVLCOPT/#EXTSUB directives', () {
    final r = M3uParser.instance.parse(_sample);
    expect(r.vod.length, 2, reason: 'iki film de gelmeli');
    expect(r.series.length, 1, reason: 'dizi bölümü gelmeli (#EXTSUB rağmen)');
    expect(r.channels.length, 1, reason: 'canlı kanal gelmeli');
    expect(r.vod.map((v) => v.name), containsAll(['Film Bir', 'Film İki']));
  });

  test('M3uStreamParser keeps entries with #EXTVLCOPT/#EXTSUB directives',
      () async {
    final r = await M3uStreamParser.parse(
      lines: Stream.fromIterable(_sample.split('\n')),
      sourceKey: '',
    );
    expect(r.vod.length, 2);
    expect(r.series.length, 1);
    expect(r.channels.length, 1);
  });

  // #EXTGRP: bazı listelerde grup adı group-title yerine ayrı satırda gelir.
  const extgrp = '''#EXTM3U
#EXTINF:-1,Kanal A
#EXTGRP:Spor
http://x/live/1.ts
#EXTINF:-1,Kanal B
#EXTGRP:Haber
http://x/live/2.ts
''';

  test('M3uParser uses #EXTGRP as group when group-title is absent', () {
    final r = M3uParser.instance.parse(extgrp);
    expect(r.channels.length, 2);
    expect(
      r.channelCategories.map((c) => c.name),
      containsAll(['Spor', 'Haber']),
    );
  });

  test('M3uStreamParser uses #EXTGRP as group when group-title is absent',
      () async {
    final r = await M3uStreamParser.parse(
      lines: Stream.fromIterable(extgrp.split('\n')),
      sourceKey: '',
    );
    expect(r.channels.length, 2);
    expect(
      r.channelCategories.map((c) => c.name),
      containsAll(['Spor', 'Haber']),
    );
  });
}
