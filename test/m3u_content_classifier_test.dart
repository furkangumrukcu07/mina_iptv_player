import 'package:flutter_test/flutter_test.dart';
import 'package:mina_iptv_player/data/remote/m3u_content_classifier.dart';

M3uContentKind classify(String name, String url, String group) =>
    M3uContentClassifier.classify(
      name: name.toLowerCase(),
      url: url.toLowerCase(),
      group: group.toLowerCase(),
    );

void main() {
  group('M3uContentClassifier — series', () {
    test('Xtream /series/ path', () {
      expect(
        classify('Foo S01E01', 'http://x/series/u/p/1.mp4', 'Drama'),
        M3uContentKind.series,
      );
    });

    test('Turkish "N. Bölüm" name (flat list, show-name group)', () {
      // #3 jsdelivr FanatikPlayDizi örneği.
      expect(
        classify('Bana Bunlarla Gel - 2. Bölüm',
            'https://cdn/play.m3u8', 'Bana Bunlarla Gel'),
        M3uContentKind.series,
      );
    });

    test('Turkish "Sezon" name', () {
      expect(
        classify('Akrep 1. Sezon 3. Bölüm', 'https://cdn/a.m3u8', 'Akrep'),
        M3uContentKind.series,
      );
    });

    test('SxxExx name', () {
      expect(
        classify('Alice in Borderland S02E05', 'https://cdn/a.m3u8',
            'Alice in Borderland'),
        M3uContentKind.series,
      );
    });

    test('NxNN episode form (2-3 digit episode)', () {
      expect(
        classify('Ada Masalı 1x02', 'https://cdn/a.m3u8', 'Ada Masalı'),
        M3uContentKind.series,
      );
    });

    test('group keyword dizi', () {
      expect(
        classify('Bir Şey', 'https://cdn/a.m3u8', 'Yerli Dizi'),
        M3uContentKind.series,
      );
    });
  });

  group('M3uContentClassifier — movie', () {
    test('group keyword Filmler', () {
      expect(
        classify('Toaster', 'https://vs/1080.m3u8', 'Filmler'),
        M3uContentKind.movie,
      );
    });

    test('year-only group → movie (dropbox movies.m3u örneği)', () {
      expect(
        classify('Satılık Uygulama', 'https://storage/play.m3u8', '2026'),
        M3uContentKind.movie,
      );
      expect(
        classify('Bir Film', 'https://vs/1080.m3u8', '1997'),
        M3uContentKind.movie,
      );
    });

    test('imdb id in url → movie', () {
      expect(
        classify('Some Movie', 'http://x/vs/tt8637498/1080.mp4', 'Arşiv'),
        M3uContentKind.movie,
      );
    });

    test('/movie/ path', () {
      expect(
        classify('Film', 'http://x/movie/u/p/9.mp4', 'Genel'),
        M3uContentKind.movie,
      );
    });
  });

  group('M3uContentClassifier — live (no false positives)', () {
    test('regular live channels stay live', () {
      expect(classify('TRT 1 HD', 'http://x/live/u/p/1.ts', 'Ulusal'),
          M3uContentKind.live);
      expect(classify('beIN Sports 1', 'http://x/live/u/p/2.ts', 'Spor'),
          M3uContentKind.live);
      expect(classify('CNN Türk', 'http://x/live/u/p/3.ts', 'Haber'),
          M3uContentKind.live);
    });

    test('channel names with x-digits do not become series', () {
      // 4x4, 24x7 → bölüm kısmı tek hane, dizi sayılmamalı.
      expect(classify('4x4 Offroad TV', 'http://x/live/u/p/4.ts', 'Belgesel'),
          M3uContentKind.live);
      expect(classify('24x7 News', 'http://x/live/u/p/5.ts', 'Haber'),
          M3uContentKind.live);
    });

    test('quality suffix channel stays live', () {
      expect(classify('Show TV - FHD', 'http://x/live/u/p/6.ts', 'Ulusal'),
          M3uContentKind.live);
    });

    test('/live/ path wins even if name matches episode pattern', () {
      // sunucu.info type=m3u: tüm canlılar /live/.../N.ts; ad kalıbı
      // yanlışlıkla benzese bile yol biçimi canlıyı garanti eder.
      expect(classify('Kanal 1x02 HD', 'http://x/live/u/p/1420.ts', ''),
          M3uContentKind.live);
    });
  });
}
