import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../core/player/iptv_playback_defaults.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';
import '../local/playlist_sqlite_store.dart';
import '../recent_vod_selection.dart';
import 'm3u_content_classifier.dart';
import 'm3u_extinf_fields.dart';

/// M3U içeriğini **satır satır** (stream) işleyen parser.
///
/// Klasik [M3uParser] tüm dosyayı tek bir `String` olarak belleğe alıp
/// `split('\n')` ile parçalar; 50-100 MB'lık listelerde bu, dosyanın birkaç
/// katı RAM demektir. Bu parser yerine girdiyi `Stream<String>` (satırlar)
/// olarak alır, dev `String`'i hiç tutmaz ve her satırı işler işlemez
/// [PlaylistSqliteStore]'a yazar (varsa). Böylece tepe RAM kullanımı küçük ve
/// sabit kalır.
///
/// Bellekte [M3uResult] listesi üretimi geçiş dönemi içindir. DB'ye yazılan
/// yollarda [buildVodSeriesInMemory] false yapılarak film/dizi nesneleri RAM'de
/// tutulmaz; canlı kanallar [buildChannelsInMemory] ile bellekte kalır (canlı
/// düzen + player için gerekli).
class M3uStreamParser {
  M3uStreamParser._();

  static const _extinf = '#EXTINF:';

  /// Bir compute() isolate'ine gönderilen giriş sayısı. Çok küçük olursa
  /// isolate spawn maliyeti baskın gelir; çok büyük olursa bellek tepe noktası
  /// artar ve UI'a daha seyrek nefes verilir. ~2000 iyi bir denge.
  static const int _kBatchTriples = 2000;

  /// [lines] satır akışını işler; [sourceKey] boş değilse [PlaylistSqliteStore]
  /// içine streaming yazar. En az bir giriş yoksa [ParseException] fırlatır.
  static Future<M3uResult> parse({
    required Stream<String> lines,
    required String sourceKey,
    bool buildChannelsInMemory = true,
    bool buildVodSeriesInMemory = true,
  }) async {
    final writeDb = sourceKey.isNotEmpty;
    final writer =
        writeDb ? await PlaylistSqliteStore.beginReplace(sourceKey) : null;

    final channels = buildChannelsInMemory ? <Channel>[] : null;
    final vod = buildVodSeriesInMemory ? <VodItem>[] : null;
    final seriesList = buildVodSeriesInMemory ? <SeriesItem>[] : null;

    final channelCatNames = <String, int>{};
    final vodCatNames = <String, int>{};
    final seriesCatNames = <String, int>{};

    var channelCatId = 1;
    var vodCatId = 1;
    var seriesCatId = 1;
    var autoId = 1;
    var channelOrder = 0;

    // recentVodIds / recentSeriesIds: dosyada en sonda geçen son N giriş.
    final recentVodBuf = <int>[];
    final recentSeriesBuf = <int>[];

    String? pendingExtinf;
    String? pendingGroup;
    var sawAny = false;
    // Parse sağlık sayaçları — "sessiz düşen giriş" sınıfı hataları kullanıcı
    // bildirmeden loglardan yakalamak için (bkz. captureAndLog sonu).
    var extinfSeen = 0;
    var emitted = 0;

    void pushRecent(List<int> buf, int id) {
      buf.add(id);
      if (buf.length > kRecentVodListLimit) buf.removeAt(0);
    }

    // Batch tamponu: `[extinf, url, fallbackGroup]` üçlüleri. Tampon dolunca
    // CPU-yoğun parse + sınıflandırma bir isolate'e (compute) gönderilir;
    // böylece regex derleme/eşleştirme ana thread'i (UI) kilitlemez. SQLite
    // yazımı ve kategori-id ataması ana isolate'te kalır (DB ana izolata bağlı).
    final batchTriples = <String>[];

    Future<void> flushBatch() async {
      if (batchTriples.isEmpty) return;
      final input = List<String>.of(batchTriples);
      batchTriples.clear();
      final parsed = await compute(parseM3uEntryBatchIsolate, input);

      for (final e in parsed) {
        sawAny = true;
        final id =
            e.tvgId != null ? (int.tryParse(e.tvgId!) ?? autoId++) : autoId++;
        switch (e.kind) {
          case M3uContentKind.series:
            final catId =
                seriesCatNames.putIfAbsent(e.group, () => seriesCatId++);
            final item = SeriesItem(
              id: id,
              name: e.name,
              categoryId: catId,
              streamUrl: e.url,
              posterUrl: e.logo,
              plot: e.plot,
            );
            if (writer != null) await writer.addSeries(item);
            seriesList?.add(item);
            pushRecent(recentSeriesBuf, id);
          case M3uContentKind.movie:
            final catId = vodCatNames.putIfAbsent(e.group, () => vodCatId++);
            final item = VodItem(
              id: id,
              name: e.name,
              streamUrl: e.url,
              categoryId: catId,
              posterUrl: e.logo,
              containerExtension: e.ext,
              plot: e.plot,
            );
            if (writer != null) await writer.addVod(item);
            vod?.add(item);
            pushRecent(recentVodBuf, id);
          case M3uContentKind.live:
            final catId =
                channelCatNames.putIfAbsent(e.group, () => channelCatId++);
            final item = Channel(
              id: id,
              name: e.name,
              streamUrl: IptvPlaybackDefaults.normalizeStreamUrl(e.url),
              categoryId: catId,
              logoUrl: e.logo,
              epgChannelId: e.tvgId,
              sortOrder: channelOrder++,
            );
            if (writer != null) await writer.addChannel(item);
            channels?.add(item);
        }
      }
    }

    await for (final raw in lines) {
      final line = raw.trim();

      if (line.startsWith(_extinf)) {
        pendingExtinf = line;
        pendingGroup = null;
        extinfSeen++;
        continue;
      }
      if (pendingExtinf == null) continue;
      // #EXTINF ile URL arasına giren direktif satırları (#EXTVLCOPT,
      // #EXTGRP, #KODIPROP, #EXTSUB, #EXT-X-…) ve boş satırlar girişi
      // İPTAL ETMEZ — sadece atlanır, pending EXTINF korunur. Aksi halde
      // (eski davranış) bu satırları içeren tüm girişler (ör. prectv film
      // listelerinde #EXTVLCOPT'lu binlerce film/dizi) sessizce düşüyordu.
      if (line.isEmpty || line.startsWith('#')) {
        // #EXTGRP grup adını taşır; group-title attribute'u yoksa onu kullan.
        if (line.startsWith('#EXTGRP:')) {
          final g = line.substring('#EXTGRP:'.length).trim();
          if (g.isNotEmpty) pendingGroup = g;
        }
        continue;
      }

      batchTriples
        ..add(pendingExtinf)
        ..add(line)
        ..add(pendingGroup ?? '');
      pendingExtinf = null;
      pendingGroup = null;
      emitted++;

      if (batchTriples.length >= _kBatchTriples * 3) {
        await flushBatch();
      }
    }

    await flushBatch();

    if (!sawAny) {
      if (writer != null) {
        await writer.finish(
          channelCategories: const [],
          vodCategories: const [],
          seriesCategories: const [],
        );
      }
      throw const ParseException('M3U content is empty');
    }

    final channelCats = channelCatNames.entries
        .map((e) => ChannelCategory(id: e.value, name: e.key))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final vodCats = vodCatNames.entries
        .map((e) => VodCategory(id: e.value, name: e.key))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final seriesCats = seriesCatNames.entries
        .map((e) => SeriesCategory(id: e.value, name: e.key))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final recentVodIds = recentVodBuf.reversed.toList(growable: false);
    final recentSeriesIds = recentSeriesBuf.reversed.toList(growable: false);

    if (writer != null) {
      await writer.finish(
        channelCategories: channelCats,
        vodCategories: vodCats,
        seriesCategories: seriesCats,
        recentVodIds: recentVodIds,
        recentSeriesIds: recentSeriesIds,
      );
    }

    // Parse sağlık raporu: #EXTINF sayısı ile üretilen giriş eşleşmiyorsa
    // (URL'siz / hatalı yapı) kayıp var demektir. "Sessiz düşen giriş" sınıfı
    // hataları kullanıcı bildirmeden loglardan yakalamak için.
    final dropped = extinfSeen - emitted;
    if (dropped > 0) {
      if (kDebugMode) debugPrint(
        'mina_iptv: ⚠️ m3u parse drop — extinf=$extinfSeen emitted=$emitted '
        'dropped=$dropped (URL eşleşmeyen giriş) '
        'live=${channelCats.length}cat vod=${vodCats.length}cat '
        'series=${seriesCats.length}cat',
      );
    } else {
      if (kDebugMode) debugPrint(
        'mina_iptv: m3u parse ok — extinf=$extinfSeen emitted=$emitted',
      );
    }

    return M3uResult(
      channels: channels ?? const [],
      channelCategories: channelCats,
      vod: vod ?? const [],
      vodCategories: vodCats,
      series: seriesList ?? const [],
      seriesCategories: seriesCats,
      recentVodIds: recentVodIds,
      recentSeriesIds: recentSeriesIds,
    );
  }
}
