import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/services/playlist_live_channel_layout.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/m3u_result.dart';
import '../../domain/entities/series.dart';
import '../../domain/entities/vod.dart';

/// Büyük playlist içeriğinin (kanal / film / dizi) SQLite kopyası.
///
/// Amaç: 50-100 MB'lık M3U listelerinin tüm parse edilmiş nesnelerini RAM'de
/// tutmak yerine diske (SQLite) yazıp, ekranda sadece görünen kadarını
/// (sayfalı / lazy) sorgulamak. Tüm satırlar `source_key` (slot parmak izi)
/// ile ölçeklenir; böylece birden fazla liste yan yana saklanabilir ve liste
/// geçişinde yalnızca ilgili kayıtlar okunur.
///
/// Desen [EpgSqliteStore] ile aynı: statik facade, tek `Database`, transaction
/// içinde batch insert + periyodik `Future.delayed(Duration.zero)` ile UI'a
/// nefes aldırma, ORM yok.
abstract final class PlaylistSqliteStore {
  static Database? _db;

  static const _tChannel = 'pl_channel';
  static const _tChannelCat = 'pl_channel_cat';
  static const _tVod = 'pl_vod';
  static const _tVodCat = 'pl_vod_cat';
  static const _tSeries = 'pl_series';
  static const _tSeriesCat = 'pl_series_cat';
  static const _tMeta = 'pl_meta';

  /// Batch commit aralığı — bellek tepe noktasını düşük tutar. 76.000+ satırlık
  /// listelerde 500 çok sık commit/fsync demekti (152 ayrı transaction);
  /// 2000'e çıkarıldı → commit sayısı ~4 kat azalır, bellek tepe noktası hâlâ
  /// küçük. Her commit sonrası UI'a bir kez nefes verilir.
  static const int _kInsertChunk = 2000;

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'mina_playlist.sqlite');
    _db = await openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        // `journal_mode` bir satır döndürür → sqflite'ta `rawQuery` ile
        // çalıştırılmalı (`execute` "Queries can be performed using rawQuery
        // methods only" hatası verir). WAL, yazım sürerken sayfalı okumalara
        // izin verir.
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA synchronous=NORMAL');
        // 76.000+ satırlık toplu yazımı hızlandır: geçici b-tree/sıralama
        // verisini diske değil RAM'e al ve sayfa önbelleğini büyüt (negatif
        // değer = KB → ~8 MB). Bu, bulk insert sırasında index bakımını ve
        // sıralamayı belirgin hızlandırır.
        await db.execute('PRAGMA temp_store=MEMORY');
        await db.execute('PRAGMA cache_size=-8000');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
CREATE TABLE $_tChannel (
  source_key TEXT NOT NULL,
  id INTEGER NOT NULL,
  name TEXT NOT NULL,
  name_lower TEXT NOT NULL,
  stream_url TEXT NOT NULL,
  category_id INTEGER NOT NULL,
  logo_url TEXT,
  epg_channel_id TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  row_index INTEGER NOT NULL,
  hidden INTEGER NOT NULL DEFAULT 0,
  layout_sort INTEGER NOT NULL DEFAULT 0,
  layout_global_sort INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (source_key, id)
);''');
    await db.execute(
      'CREATE INDEX idx_pl_channel_cat ON $_tChannel(source_key, category_id, layout_sort, row_index);',
    );
    await db.execute(
      'CREATE INDEX idx_pl_channel_name ON $_tChannel(source_key, name_lower);',
    );
    await db.execute(
      'CREATE INDEX idx_pl_channel_visible ON $_tChannel(source_key, hidden, layout_global_sort);',
    );

    await db.execute('''
CREATE TABLE $_tVod (
  source_key TEXT NOT NULL,
  id INTEGER NOT NULL,
  name TEXT NOT NULL,
  name_lower TEXT NOT NULL,
  stream_url TEXT NOT NULL,
  category_id INTEGER NOT NULL,
  poster_url TEXT,
  container_ext TEXT,
  duration_secs INTEGER,
  added_unix INTEGER,
  plot TEXT,
  rating TEXT,
  trailer_url TEXT,
  row_index INTEGER NOT NULL,
  PRIMARY KEY (source_key, id)
);''');
    await db.execute(
      'CREATE INDEX idx_pl_vod_cat ON $_tVod(source_key, category_id, name_lower);',
    );
    await db.execute(
      'CREATE INDEX idx_pl_vod_name ON $_tVod(source_key, name_lower);',
    );

    await db.execute('''
CREATE TABLE $_tSeries (
  source_key TEXT NOT NULL,
  id INTEGER NOT NULL,
  name TEXT NOT NULL,
  name_lower TEXT NOT NULL,
  category_id INTEGER NOT NULL,
  stream_url TEXT,
  poster_url TEXT,
  plot TEXT,
  added_unix INTEGER,
  row_index INTEGER NOT NULL,
  PRIMARY KEY (source_key, id)
);''');
    await db.execute(
      'CREATE INDEX idx_pl_series_cat ON $_tSeries(source_key, category_id, name_lower);',
    );
    await db.execute(
      'CREATE INDEX idx_pl_series_name ON $_tSeries(source_key, name_lower);',
    );

    for (final t in [_tChannelCat, _tVodCat, _tSeriesCat]) {
      await db.execute('''
CREATE TABLE $t (
  source_key TEXT NOT NULL,
  id INTEGER NOT NULL,
  name TEXT NOT NULL,
  sort_index INTEGER NOT NULL,
  PRIMARY KEY (source_key, id)
);''');
    }

    await db.execute('''
CREATE TABLE $_tMeta (
  source_key TEXT NOT NULL,
  key TEXT NOT NULL,
  value TEXT,
  PRIMARY KEY (source_key, key)
);''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $_tChannel ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE $_tChannel ADD COLUMN layout_sort INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE $_tChannel ADD COLUMN layout_global_sort INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'UPDATE $_tChannel SET layout_sort = row_index, layout_global_sort = row_index',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pl_channel_visible ON $_tChannel(source_key, hidden, layout_global_sort)',
      );
    }
    if (oldVersion < 3) {
      // Klasik film/dizi: kategori içi alfabetik sayfalama (name_lower ASC).
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pl_vod_cat_name ON $_tVod(source_key, category_id, name_lower)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pl_series_cat_name ON $_tSeries(source_key, category_id, name_lower)',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Yazma — bulk (Xtream / tam M3uResult).
  // ---------------------------------------------------------------------------

  /// Verilen [sourceKey] için tüm playlist verisini değiştirir (önce siler).
  /// Xtream gibi tam `M3uResult` üretilen yollar için.
  static Future<void> replaceFromResult(
    String sourceKey,
    M3uResult result,
  ) async {
    if (sourceKey.isEmpty) return;
    final writer = await beginReplace(sourceKey);
    for (final c in result.channels) {
      await writer.addChannel(c);
    }
    for (final v in result.vod) {
      await writer.addVod(v);
    }
    for (final s in result.series) {
      await writer.addSeries(s);
    }
    await writer.finish(
      channelCategories: result.channelCategories,
      vodCategories: result.vodCategories,
      seriesCategories: result.seriesCategories,
      recentVodIds: result.recentVodIds,
      recentSeriesIds: result.recentSeriesIds,
    );
  }

  /// Kullanıcı düzenini (gizle + kategori içi sıra) kanal tablosuna yazar.
  /// [PlaylistLiveChannelLayout.computeLayoutPlan] ile bellek içi [apply] aynı
  /// kuralları kullanır.
  static Future<void> applyChannelLayout(
    String sourceKey, {
    required List<ChannelCategory> categories,
    required Set<int> hiddenIds,
    required Map<int, List<int>> orderByCategoryId,
  }) async {
    if (sourceKey.isEmpty) return;
    final db = await _open();

    if (hiddenIds.isEmpty && orderByCategoryId.isEmpty) {
      await db.rawUpdate(
        'UPDATE $_tChannel SET hidden = 0, layout_sort = row_index, '
        'layout_global_sort = row_index WHERE source_key = ?',
        [sourceKey],
      );
      return;
    }

    final rows = await db.query(
      _tChannel,
      columns: [
        'id',
        'name',
        'stream_url',
        'category_id',
        'logo_url',
        'epg_channel_id',
        'sort_order',
        'row_index',
      ],
      where: 'source_key = ?',
      whereArgs: [sourceKey],
      orderBy: 'row_index ASC',
    );
    if (rows.isEmpty) return;

    final allChannels = [for (final r in rows) _channelFromRow(r)];
    final plan = PlaylistLiveChannelLayout.computeLayoutPlan(
      categories: categories,
      allChannels: allChannels,
      hiddenIds: hiddenIds,
      orderByCategoryId: orderByCategoryId,
    );

    final globalSortById = <int, int>{
      for (var i = 0; i < plan.visibleGlobalOrder.length; i++)
        plan.visibleGlobalOrder[i]: i,
    };

    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE $_tChannel SET hidden = 0, layout_sort = row_index, '
        'layout_global_sort = row_index WHERE source_key = ?',
        [sourceKey],
      );
      final batch = txn.batch();
      for (final id in hiddenIds) {
        batch.update(
          _tChannel,
          {'hidden': 1},
          where: 'source_key = ? AND id = ?',
          whereArgs: [sourceKey, id],
        );
      }
      for (final e in plan.layoutSortById.entries) {
        batch.update(
          _tChannel,
          {
            'layout_sort': e.value,
            'layout_global_sort': globalSortById[e.key] ?? e.value,
          },
          where: 'source_key = ? AND id = ?',
          whereArgs: [sourceKey, e.key],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Streaming yazım oturumu başlatır: önceki [sourceKey] satırlarını siler ve
  /// satır satır eklenebilen bir [PlaylistDbWriter] döner. M3U stream parse
  /// yolunda kullanılır (tüm liste asla aynı anda RAM'de tutulmaz).
  static Future<PlaylistDbWriter> beginReplace(String sourceKey) async {
    final db = await _open();
    await _deleteRows(db, sourceKey);
    return PlaylistDbWriter._(db, sourceKey);
  }

  static Future<void> _deleteRows(DatabaseExecutor db, String sourceKey) async {
    for (final t in [
      _tChannel,
      _tVod,
      _tSeries,
      _tChannelCat,
      _tVodCat,
      _tSeriesCat,
      _tMeta,
    ]) {
      await db.delete(t, where: 'source_key = ?', whereArgs: [sourceKey]);
    }
  }

  static Future<void> deleteSource(String sourceKey) async {
    if (sourceKey.isEmpty) return;
    try {
      final db = await _open();
      await _deleteRows(db, sourceKey);
    } catch (e) {
      debugPrint('mina_iptv: playlist SQLite deleteSource failed: $e');
    }
  }

  /// DB'de fiilen veri bulunan tüm `source_key` değerlerini döner
  /// (kanal + film + dizi tablolarından). Yetim liste temizliği için.
  static Future<Set<String>> distinctSourceKeys() async {
    final keys = <String>{};
    try {
      final db = await _open();
      for (final t in [_tChannel, _tVod, _tSeries]) {
        final rows = await db.rawQuery('SELECT DISTINCT source_key FROM $t');
        for (final r in rows) {
          final k = r['source_key'] as String?;
          if (k != null && k.isNotEmpty) keys.add(k);
        }
      }
    } catch (e) {
      debugPrint('mina_iptv: playlist SQLite distinctSourceKeys failed: $e');
    }
    return keys;
  }

  /// [keep] kümesinde olmayan tüm `source_key` verilerini siler. Kullanıcı bir
  /// listeyi kaldırdığında / düzenlediğinde / slotları sıkıştırdığında eski
  /// parmak izine ait satırlar yetim kalır; 20+ liste senaryosunda DB'nin
  /// sınırsız büyümesini önlemek için periyodik olarak çağrılır.
  ///
  /// Silinen yetim anahtar sayısını döner.
  static Future<int> pruneExcept(Set<String> keep) async {
    var removed = 0;
    try {
      final existing = await distinctSourceKeys();
      for (final k in existing) {
        if (keep.contains(k)) continue;
        await deleteSource(k);
        removed++;
      }
      if (removed > 0) {
        debugPrint('mina_iptv: playlist SQLite pruned $removed orphan source(s)');
      }
    } catch (e) {
      debugPrint('mina_iptv: playlist SQLite pruneExcept failed: $e');
    }
    return removed;
  }

  /// [sourceKey] için en az bir kanal/film/dizi satırı var mı?
  static Future<bool> hasData(String sourceKey) async {
    if (sourceKey.isEmpty) return false;
    try {
      final db = await _open();
      for (final t in [_tChannel, _tVod, _tSeries]) {
        final c = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT 1 FROM $t WHERE source_key = ? LIMIT 1',
          [sourceKey],
        ));
        if (c != null) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Okuma — kategoriler (küçük, tamamı belleğe alınabilir).
  // ---------------------------------------------------------------------------

  static Future<List<ChannelCategory>> channelCategories(
      String sourceKey) async {
    final rows = await _categoryRows(sourceKey, _tChannelCat);
    return [for (final r in rows) ChannelCategory(id: r.$1, name: r.$2)];
  }

  static Future<List<VodCategory>> vodCategories(String sourceKey) async {
    final rows = await _categoryRows(sourceKey, _tVodCat);
    return [for (final r in rows) VodCategory(id: r.$1, name: r.$2)];
  }

  static Future<List<SeriesCategory>> seriesCategories(
      String sourceKey) async {
    final rows = await _categoryRows(sourceKey, _tSeriesCat);
    return [for (final r in rows) SeriesCategory(id: r.$1, name: r.$2)];
  }

  static Future<List<(int, String)>> _categoryRows(
    String sourceKey,
    String table,
  ) async {
    if (sourceKey.isEmpty) return const [];
    final db = await _open();
    final rows = await db.query(
      table,
      columns: ['id', 'name'],
      where: 'source_key = ?',
      whereArgs: [sourceKey],
      orderBy: 'sort_index ASC',
    );
    return [
      for (final r in rows) ((r['id'] as num).toInt(), r['name'] as String? ?? '')
    ];
  }

  // ---------------------------------------------------------------------------
  // Okuma — sayfalı / lazy listeler.
  // ---------------------------------------------------------------------------

  /// Kanal sayfası — kullanıcı düzeni uygulanmış (gizliler hariç).
  /// [categoryId] null → kategori sırası + global düzen.
  static Future<List<Channel>> channelsPage(
    String sourceKey, {
    int? categoryId,
    String? search,
    int offset = 0,
    int limit = 100,
  }) async {
    final rows = await _channelsQuery(
      sourceKey,
      categoryId: categoryId,
      search: search,
      offset: offset,
      limit: limit,
      includeHidden: false,
      useLayoutOrder: true,
    );
    return [for (final r in rows) _channelFromRow(r)];
  }

  /// Ham kanal sayfası — düzen uygulanmaz, gizliler dahil (düzenleme ekranı).
  static Future<List<Channel>> channelsPageRaw(
    String sourceKey, {
    int? categoryId,
    String? search,
    int offset = 0,
    int limit = 100,
  }) async {
    final rows = await _channelsQuery(
      sourceKey,
      categoryId: categoryId,
      search: search,
      offset: offset,
      limit: limit,
      includeHidden: true,
      useLayoutOrder: false,
    );
    return [for (final r in rows) _channelFromRow(r)];
  }

  static Future<List<Map<String, Object?>>> _channelsQuery(
    String sourceKey, {
    int? categoryId,
    String? search,
    required int offset,
    required int limit,
    required bool includeHidden,
    required bool useLayoutOrder,
  }) async {
    if (sourceKey.isEmpty) return const [];
    final db = await _open();
    final where = StringBuffer('c.source_key = ?');
    final args = <Object?>[sourceKey];
    if (!includeHidden) {
      where.write(' AND c.hidden = 0');
    }
    if (categoryId != null) {
      where.write(' AND c.category_id = ?');
      args.add(categoryId);
    }
    final q = search?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      where.write(' AND c.name_lower LIKE ?');
      args.add('%$q%');
    }

    final orderBy = useLayoutOrder
        ? (categoryId != null
            ? 'c.layout_sort ASC, c.row_index ASC'
            : 'cat.sort_index ASC, c.layout_sort ASC, c.row_index ASC')
        : 'c.row_index ASC';

    if (useLayoutOrder && categoryId == null) {
      return db.rawQuery(
        'SELECT c.* FROM $_tChannel c '
        'LEFT JOIN $_tChannelCat cat ON cat.source_key = c.source_key '
        'AND cat.id = c.category_id '
        'WHERE ${where.toString()} '
        'ORDER BY $orderBy '
        'LIMIT ? OFFSET ?',
        [...args, limit, offset],
      );
    }

    return db.query(
      _tChannel,
      columns: null,
      where: where.toString().replaceAll('c.', ''),
      whereArgs: args,
      orderBy: orderBy.replaceAll('c.', ''),
      offset: offset,
      limit: limit,
    );
  }

  static Future<List<VodItem>> vodPage(
    String sourceKey, {
    int? categoryId,
    String? search,
    int offset = 0,
    int limit = 100,
  }) async {
    final rows = await _page(
      sourceKey,
      _tVod,
      categoryId: categoryId,
      search: search,
      offset: offset,
      limit: limit,
    );
    return [for (final r in rows) _vodFromRow(r)];
  }

  static Future<List<SeriesItem>> seriesPage(
    String sourceKey, {
    int? categoryId,
    String? search,
    int offset = 0,
    int limit = 100,
  }) async {
    final rows = await _page(
      sourceKey,
      _tSeries,
      categoryId: categoryId,
      search: search,
      offset: offset,
      limit: limit,
    );
    return [for (final r in rows) _seriesFromRow(r)];
  }

  /// Ad öneki (`name_lower`) ile dizi satırları — `idx_pl_series_name`
  /// indeksi üzerinde **aralık taraması** (`>= prefix AND < prefix+\uffff`).
  ///
  /// Bir dizinin tüm bölümlerini toplamak için tüm tabloyu OFFSET ile gezmek
  /// (binlerce satırda kuadratik) yerine yalnızca aynı başlıkla başlayan
  /// satırları getirir. Çağıran taraf yine canonical anahtarla net filtreler
  /// (önek `Pantheon`, `Pantheons`'u da getirebilir → Dart tarafında elenir).
  static Future<List<SeriesItem>> seriesByNamePrefix(
    String sourceKey,
    String prefixLower, {
    int limit = 8000,
  }) async {
    if (sourceKey.isEmpty || prefixLower.isEmpty) return const [];
    final db = await _open();
    final rows = await db.query(
      _tSeries,
      where: 'source_key = ? AND name_lower >= ? AND name_lower < ?',
      whereArgs: [sourceKey, prefixLower, '$prefixLower\u{10FFFF}'],
      orderBy: 'name_lower ASC',
      limit: limit,
    );
    return [for (final r in rows) _seriesFromRow(r)];
  }

  /// `id` keyset sayfalama (PRIMARY KEY `(source_key, id)` indeksini kullanır):
  /// `id > afterId ORDER BY id LIMIT n`. OFFSET tabanlı sayfalamanın aksine her
  /// sayfa O(limit)'tir → tüm tabloyu taramak O(n) (kuadratik değil).
  static Future<List<SeriesItem>> seriesPageAfterId(
    String sourceKey, {
    required int afterId,
    int limit = 500,
  }) async {
    if (sourceKey.isEmpty) return const [];
    final db = await _open();
    final rows = await db.query(
      _tSeries,
      where: 'source_key = ? AND id > ?',
      whereArgs: [sourceKey, afterId],
      orderBy: 'id ASC',
      limit: limit,
    );
    return [for (final r in rows) _seriesFromRow(r)];
  }

  /// AI soğuk başlangıç için **en yüksek puanlı** ilk [limit] film. Sıralama
  /// SQLite tarafında (`CAST(rating AS REAL)`) yapılır; Dart'a yalnızca [limit]
  /// satır gelir → 76.000 satırın tamamı RAM'e alınmaz.
  static Future<List<VodItem>> vodTopRated(
    String sourceKey, {
    int limit = 240,
  }) async {
    if (sourceKey.isEmpty) return const [];
    final db = await _open();
    final rows = await db.query(
      _tVod,
      where: 'source_key = ?',
      whereArgs: [sourceKey],
      orderBy: 'CAST(rating AS REAL) DESC, row_index ASC',
      limit: limit,
    );
    return [for (final r in rows) _vodFromRow(r)];
  }

  /// AI soğuk başlangıç için ilk [limit] dizi (parse/eklenme sırası). Tüm
  /// tabloyu RAM'e çekmeden örnek havuz döndürür.
  static Future<List<SeriesItem>> seriesSample(
    String sourceKey, {
    int limit = 240,
  }) async {
    if (sourceKey.isEmpty) return const [];
    final db = await _open();
    final rows = await db.query(
      _tSeries,
      where: 'source_key = ?',
      whereArgs: [sourceKey],
      orderBy: 'row_index ASC',
      limit: limit,
    );
    return [for (final r in rows) _seriesFromRow(r)];
  }

  static Future<List<Map<String, Object?>>> _page(
    String sourceKey,
    String table, {
    int? categoryId,
    String? search,
    required int offset,
    required int limit,
  }) async {
    if (sourceKey.isEmpty) return const [];
    final db = await _open();
    final where = StringBuffer('source_key = ?');
    final args = <Object?>[sourceKey];
    if (categoryId != null) {
      where.write(' AND category_id = ?');
      args.add(categoryId);
    }
    final q = search?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      where.write(' AND name_lower LIKE ?');
      args.add('%$q%');
    }
    return db.query(
      table,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'row_index ASC',
      offset: offset,
      limit: limit,
    );
  }

  // ---------------------------------------------------------------------------
  // Okuma — sayımlar.
  // ---------------------------------------------------------------------------

  static Future<int> channelCount(
    String sourceKey, {
    int? categoryId,
    bool visibleOnly = false,
  }) =>
      _count(
        sourceKey,
        _tChannel,
        categoryId: categoryId,
        extraWhere: visibleOnly ? 'hidden = 0' : null,
      );

  static Future<int> vodCount(String sourceKey, {int? categoryId}) =>
      _count(sourceKey, _tVod, categoryId: categoryId);

  static Future<int> seriesCount(String sourceKey, {int? categoryId}) =>
      _count(sourceKey, _tSeries, categoryId: categoryId);

  static Future<int> _count(
    String sourceKey,
    String table, {
    int? categoryId,
    String? extraWhere,
  }) async {
    if (sourceKey.isEmpty) return 0;
    final db = await _open();
    final where = StringBuffer('source_key = ?');
    final args = <Object?>[sourceKey];
    if (categoryId != null) {
      where.write(' AND category_id = ?');
      args.add(categoryId);
    }
    if (extraWhere != null && extraWhere.isNotEmpty) {
      where.write(' AND $extraWhere');
    }
    final c = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $table WHERE ${where.toString()}',
      args,
    ));
    return c ?? 0;
  }

  /// Kategori → satır sayısı haritası (tek sorgu, rozet/sayım UI'ı için).
  static Future<Map<int, int>> channelCountsByCategory(
    String sourceKey, {
    bool visibleOnly = false,
  }) =>
      _countsByCategory(
        sourceKey,
        _tChannel,
        extraWhere: visibleOnly ? 'hidden = 0' : null,
      );

  static Future<Map<int, int>> vodCountsByCategory(String sourceKey) =>
      _countsByCategory(sourceKey, _tVod);

  static Future<Map<int, int>> seriesCountsByCategory(String sourceKey) =>
      _countsByCategory(sourceKey, _tSeries);

  static Future<Map<int, int>> _countsByCategory(
    String sourceKey,
    String table, {
    String? extraWhere,
  }) async {
    if (sourceKey.isEmpty) return const {};
    final db = await _open();
    final where = StringBuffer('source_key = ?');
    final args = <Object?>[sourceKey];
    if (extraWhere != null && extraWhere.isNotEmpty) {
      where.write(' AND $extraWhere');
    }
    final rows = await db.rawQuery(
      'SELECT category_id AS c, COUNT(*) AS n FROM $table '
      'WHERE ${where.toString()} GROUP BY category_id',
      args,
    );
    return {
      for (final r in rows)
        (r['c'] as num).toInt(): (r['n'] as num).toInt(),
    };
  }

  // ---------------------------------------------------------------------------
  // Okuma — hafif projeksiyon (tam nesne materyalize etmeden tüm kataloğu tara).
  //
  // AI öneri skorlaması gibi tüm kataloğu gezmek zorunda olan ama tam
  // [VodItem]/[SeriesItem]/[Channel] nesnesine (poster, url, plot...) ihtiyaç
  // duymayan tüketiciler içindir. Yalnızca skorlama/gizleme için gereken küçük
  // alanlar döner; sonuç geçici olarak (örn. isolate'e gönderip atılır) tutulur,
  // RAM'de kalıcı liste birikmez.
  // ---------------------------------------------------------------------------

  static Future<List<Map<String, Object?>>> vodLite(String sourceKey) => _lite(
        sourceKey,
        _tVod,
        const ['id', 'category_id', 'name', 'rating', 'added_unix'],
      );

  static Future<List<Map<String, Object?>>> seriesLite(String sourceKey) =>
      _lite(
        sourceKey,
        _tSeries,
        const ['id', 'category_id', 'name', 'added_unix'],
      );

  static Future<List<Map<String, Object?>>> channelLite(String sourceKey) =>
      _lite(
        sourceKey,
        _tChannel,
        const ['id', 'category_id', 'name', 'logo_url'],
        extraWhere: 'hidden = 0',
        orderBy: 'layout_global_sort ASC, row_index ASC',
      );

  static Future<List<Map<String, Object?>>> _lite(
    String sourceKey,
    String table,
    List<String> columns, {
    String? extraWhere,
    String orderBy = 'row_index ASC',
  }) async {
    if (sourceKey.isEmpty) return const [];
    final db = await _open();
    final where = StringBuffer('source_key = ?');
    final args = <Object?>[sourceKey];
    if (extraWhere != null && extraWhere.isNotEmpty) {
      where.write(' AND $extraWhere');
    }
    return db.query(
      table,
      columns: columns,
      where: where.toString(),
      whereArgs: args,
      orderBy: orderBy,
    );
  }

  // ---------------------------------------------------------------------------
  // Okuma — id ile tekil / çoklu.
  // ---------------------------------------------------------------------------

  static Future<Channel?> channelById(String sourceKey, int id) async {
    final r = await _byId(sourceKey, _tChannel, id);
    return r == null ? null : _channelFromRow(r);
  }

  static Future<VodItem?> vodById(String sourceKey, int id) async {
    final r = await _byId(sourceKey, _tVod, id);
    return r == null ? null : _vodFromRow(r);
  }

  /// Birden fazla VOD'u tek (veya parçalı) `IN` sorgusuyla getirir.
  /// `last50FilmsFromDb` gibi yolların N ayrı `vodById` çağrısı yerine
  /// kullanılır → «Tümünü gör» açılışında takılma azalır.
  static Future<List<VodItem>> vodByIds(
    String sourceKey,
    List<int> ids,
  ) async {
    if (sourceKey.isEmpty || ids.isEmpty) return const [];
    final unique = <int>{};
    final ordered = <int>[];
    for (final id in ids) {
      if (unique.add(id)) ordered.add(id);
    }
    if (ordered.isEmpty) return const [];
    final db = await _open();
    final byId = <int, VodItem>{};
    const chunkSize = 400;
    for (var i = 0; i < ordered.length; i += chunkSize) {
      final chunk = ordered.sublist(
        i,
        i + chunkSize > ordered.length ? ordered.length : i + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.query(
        _tVod,
        where: 'source_key = ? AND id IN ($placeholders)',
        whereArgs: [sourceKey, ...chunk],
      );
      for (final r in rows) {
        final v = _vodFromRow(r);
        byId[v.id] = v;
      }
    }
    return [for (final id in ordered) if (byId[id] != null) byId[id]!];
  }

  static Future<SeriesItem?> seriesById(String sourceKey, int id) async {
    final r = await _byId(sourceKey, _tSeries, id);
    return r == null ? null : _seriesFromRow(r);
  }

  /// Birden fazla dizi satırını tek (veya parçalı) `IN` sorgusuyla getirir.
  static Future<List<SeriesItem>> seriesByIds(
    String sourceKey,
    List<int> ids,
  ) async {
    if (sourceKey.isEmpty || ids.isEmpty) return const [];
    final unique = <int>{};
    final ordered = <int>[];
    for (final id in ids) {
      if (unique.add(id)) ordered.add(id);
    }
    if (ordered.isEmpty) return const [];
    final db = await _open();
    final byId = <int, SeriesItem>{};
    const chunkSize = 400;
    for (var i = 0; i < ordered.length; i += chunkSize) {
      final chunk = ordered.sublist(
        i,
        i + chunkSize > ordered.length ? ordered.length : i + chunkSize,
      );
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.query(
        _tSeries,
        where: 'source_key = ? AND id IN ($placeholders)',
        whereArgs: [sourceKey, ...chunk],
      );
      for (final r in rows) {
        final s = _seriesFromRow(r);
        byId[s.id] = s;
      }
    }
    return [for (final id in ordered) if (byId[id] != null) byId[id]!];
  }

  static Future<Map<String, Object?>?> _byId(
    String sourceKey,
    String table,
    int id,
  ) async {
    if (sourceKey.isEmpty) return null;
    final db = await _open();
    final rows = await db.query(
      table,
      where: 'source_key = ? AND id = ?',
      whereArgs: [sourceKey, id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Stream URL ile kanal (player rebind / EPG eşleme için).
  static Future<Channel?> channelByStreamUrl(
    String sourceKey,
    String streamUrl,
  ) async {
    if (sourceKey.isEmpty || streamUrl.isEmpty) return null;
    final db = await _open();
    final rows = await db.query(
      _tChannel,
      where: 'source_key = ? AND stream_url = ?',
      whereArgs: [sourceKey, streamUrl],
      limit: 1,
    );
    return rows.isEmpty ? null : _channelFromRow(rows.first);
  }

  // ---------------------------------------------------------------------------
  // Satır eşleme.
  // ---------------------------------------------------------------------------

  static Channel _channelFromRow(Map<String, Object?> r) => Channel(
        id: (r['id'] as num).toInt(),
        name: r['name'] as String? ?? '',
        streamUrl: r['stream_url'] as String? ?? '',
        categoryId: (r['category_id'] as num).toInt(),
        logoUrl: r['logo_url'] as String?,
        epgChannelId: r['epg_channel_id'] as String?,
        sortOrder: (r['sort_order'] as num?)?.toInt() ?? 0,
      );

  static VodItem _vodFromRow(Map<String, Object?> r) => VodItem(
        id: (r['id'] as num).toInt(),
        name: r['name'] as String? ?? '',
        streamUrl: r['stream_url'] as String? ?? '',
        categoryId: (r['category_id'] as num).toInt(),
        posterUrl: r['poster_url'] as String?,
        containerExtension: r['container_ext'] as String?,
        durationSecs: (r['duration_secs'] as num?)?.toInt(),
        addedUnix: (r['added_unix'] as num?)?.toInt(),
        plot: r['plot'] as String?,
        rating: r['rating'] as String?,
        trailerUrl: r['trailer_url'] as String?,
      );

  static SeriesItem _seriesFromRow(Map<String, Object?> r) => SeriesItem(
        id: (r['id'] as num).toInt(),
        name: r['name'] as String? ?? '',
        categoryId: (r['category_id'] as num).toInt(),
        streamUrl: r['stream_url'] as String?,
        posterUrl: r['poster_url'] as String?,
        plot: r['plot'] as String?,
        addedUnix: (r['added_unix'] as num?)?.toInt(),
      );

  // ---------------------------------------------------------------------------
  // Meta (recentVodIds / recentSeriesIds — küçük JSON-benzeri CSV).
  // ---------------------------------------------------------------------------

  static Future<List<int>> recentVodIds(String sourceKey) =>
      _readIntList(sourceKey, 'recent_vod_ids');

  static Future<List<int>> recentSeriesIds(String sourceKey) =>
      _readIntList(sourceKey, 'recent_series_ids');

  static Future<List<int>> _readIntList(String sourceKey, String key) async {
    if (sourceKey.isEmpty) return const [];
    final db = await _open();
    final rows = await db.query(
      _tMeta,
      columns: ['value'],
      where: 'source_key = ? AND key = ?',
      whereArgs: [sourceKey, key],
      limit: 1,
    );
    if (rows.isEmpty) return const [];
    final v = rows.first['value'] as String?;
    if (v == null || v.isEmpty) return const [];
    return [
      for (final part in v.split(','))
        if (int.tryParse(part) case final n?) n,
    ];
  }
}

/// [PlaylistSqliteStore.beginReplace] ile dönen streaming yazıcı. Satır satır
/// kanal/film/dizi ekler; her [PlaylistSqliteStore._kInsertChunk] satırda bir
/// commit edip UI'a nefes aldırır. Sonunda [finish] ile kategoriler + meta
/// yazılır.
class PlaylistDbWriter {
  PlaylistDbWriter._(this._db, this._sourceKey);

  final Database _db;
  final String _sourceKey;

  Batch? _batch;
  int _pending = 0;
  int _channelIndex = 0;
  int _vodIndex = 0;
  int _seriesIndex = 0;

  int get channelCount => _channelIndex;
  int get vodCount => _vodIndex;
  int get seriesCount => _seriesIndex;

  Batch _ensureBatch() => _batch ??= _db.batch();

  Future<void> _maybeCommit() async {
    if (++_pending >= PlaylistSqliteStore._kInsertChunk) {
      await _batch?.commit(noResult: true);
      _batch = null;
      _pending = 0;
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> addChannel(Channel c) async {
    _ensureBatch().insert('pl_channel', {
      'source_key': _sourceKey,
      'id': c.id,
      'name': c.name,
      'name_lower': c.name.toLowerCase(),
      'stream_url': c.streamUrl,
      'category_id': c.categoryId,
      'logo_url': c.logoUrl,
      'epg_channel_id': c.epgChannelId,
      'sort_order': c.sortOrder,
      'row_index': _channelIndex,
      'hidden': 0,
      'layout_sort': _channelIndex,
      'layout_global_sort': _channelIndex,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _channelIndex++;
    await _maybeCommit();
  }

  Future<void> addVod(VodItem v) async {
    _ensureBatch().insert('pl_vod', {
      'source_key': _sourceKey,
      'id': v.id,
      'name': v.name,
      'name_lower': v.name.toLowerCase(),
      'stream_url': v.streamUrl,
      'category_id': v.categoryId,
      'poster_url': v.posterUrl,
      'container_ext': v.containerExtension,
      'duration_secs': v.durationSecs,
      'added_unix': v.addedUnix,
      'plot': v.plot,
      'rating': v.rating,
      'trailer_url': v.trailerUrl,
      'row_index': _vodIndex++,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _maybeCommit();
  }

  Future<void> addSeries(SeriesItem s) async {
    _ensureBatch().insert('pl_series', {
      'source_key': _sourceKey,
      'id': s.id,
      'name': s.name,
      'name_lower': s.name.toLowerCase(),
      'category_id': s.categoryId,
      'stream_url': s.streamUrl,
      'poster_url': s.posterUrl,
      'plot': s.plot,
      'added_unix': s.addedUnix,
      'row_index': _seriesIndex++,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _maybeCommit();
  }

  Future<void> finish({
    required List<ChannelCategory> channelCategories,
    required List<VodCategory> vodCategories,
    required List<SeriesCategory> seriesCategories,
    List<int> recentVodIds = const [],
    List<int> recentSeriesIds = const [],
  }) async {
    await _batch?.commit(noResult: true);
    _batch = null;
    _pending = 0;

    final b = _db.batch();
    var i = 0;
    for (final c in channelCategories) {
      b.insert('pl_channel_cat', {
        'source_key': _sourceKey,
        'id': c.id,
        'name': c.name,
        'sort_index': i++,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    i = 0;
    for (final c in vodCategories) {
      b.insert('pl_vod_cat', {
        'source_key': _sourceKey,
        'id': c.id,
        'name': c.name,
        'sort_index': i++,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    i = 0;
    for (final c in seriesCategories) {
      b.insert('pl_series_cat', {
        'source_key': _sourceKey,
        'id': c.id,
        'name': c.name,
        'sort_index': i++,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    b.insert('pl_meta', {
      'source_key': _sourceKey,
      'key': 'recent_vod_ids',
      'value': recentVodIds.join(','),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    b.insert('pl_meta', {
      'source_key': _sourceKey,
      'key': 'recent_series_ids',
      'value': recentSeriesIds.join(','),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await b.commit(noResult: true);

    if (kDebugMode) {
      debugPrint(
        'mina_iptv: playlist SQLite write ok ($_sourceKey, '
        '$_channelIndex ch / $_vodIndex vod / $_seriesIndex series)',
      );
    }
  }
}
