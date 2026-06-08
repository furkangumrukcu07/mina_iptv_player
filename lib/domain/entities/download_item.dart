/// İndirme kuyruğundaki tek bir öğe — film (VOD) veya dizi bölümü.
///
/// Disk modeli (`DownloadsStore`) bunun JSON serileştirimini tutar; aktif
/// progress (`bytesReceived`, `totalBytes`, `durationSecs`) bellek üstü
/// `DownloadService` tarafından `RxMap` ile yönetilir.
enum DownloadKind { vod, episode }

enum DownloadStatus { queued, downloading, completed, failed, cancelled }

enum DownloadEngine {
  /// Direct HTTP indirme — `.mp4`, `.mkv`, `.webm`, `.avi` vs.
  /// `dio.download(...)` ile progress'li indirir.
  directHttp,

  /// libmpv `stream-record` ile arka plan kaydı — HLS (`.m3u8`),
  /// DASH (`.mpd`), RTMP yayınları için. Silent sidecar `mpv Player`
  /// kullanılır (kayıt feature'ı ile aynı yaklaşım).
  mpvRecord,
}

class DownloadItem {
  const DownloadItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.sourceUrl,
    required this.localPath,
    required this.engine,
    this.posterUrl,
    this.subtitle,
    this.parentSeriesId,
    this.parentSeriesName,
    this.season,
    this.episode,
    this.containerExtension,
    this.durationSecs,
    this.sizeBytes,
    required this.addedUnix,
    this.completedUnix,
    this.status = DownloadStatus.queued,
    this.failureMessage,
  });

  /// Benzersiz kimlik — `vod_$vodId` veya `ep_$seriesId_${season}x${ep}`
  /// formatında. Aynı film/bölümü iki kez kuyruğa eklemeyi engeller.
  final String id;
  final DownloadKind kind;
  final String title;
  final String sourceUrl;

  /// Diskte tam dosya yolu (örn.
  /// `/storage/emulated/0/Android/data/.../files/Downloads/Filmler/...mp4`).
  final String localPath;
  final DownloadEngine engine;

  final String? posterUrl;
  final String? subtitle;

  // Dizi bölümleri için:
  final int? parentSeriesId;
  final String? parentSeriesName;
  final int? season;
  final int? episode;

  final String? containerExtension;
  final int? durationSecs;

  /// Tamamlandığında diskteki gerçek boyut. Devam ederken null.
  final int? sizeBytes;

  final int addedUnix;
  final int? completedUnix;
  final DownloadStatus status;
  final String? failureMessage;

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;
  bool get isFailed => status == DownloadStatus.failed;

  DownloadItem copyWith({
    DownloadStatus? status,
    int? sizeBytes,
    int? completedUnix,
    String? failureMessage,
    String? localPath,
  }) {
    return DownloadItem(
      id: id,
      kind: kind,
      title: title,
      sourceUrl: sourceUrl,
      localPath: localPath ?? this.localPath,
      engine: engine,
      posterUrl: posterUrl,
      subtitle: subtitle,
      parentSeriesId: parentSeriesId,
      parentSeriesName: parentSeriesName,
      season: season,
      episode: episode,
      containerExtension: containerExtension,
      durationSecs: durationSecs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      addedUnix: addedUnix,
      completedUnix: completedUnix ?? this.completedUnix,
      status: status ?? this.status,
      failureMessage: failureMessage ?? this.failureMessage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'sourceUrl': sourceUrl,
        'localPath': localPath,
        'engine': engine.name,
        if (posterUrl != null) 'posterUrl': posterUrl,
        if (subtitle != null) 'subtitle': subtitle,
        if (parentSeriesId != null) 'parentSeriesId': parentSeriesId,
        if (parentSeriesName != null) 'parentSeriesName': parentSeriesName,
        if (season != null) 'season': season,
        if (episode != null) 'episode': episode,
        if (containerExtension != null) 'containerExtension': containerExtension,
        if (durationSecs != null) 'durationSecs': durationSecs,
        if (sizeBytes != null) 'sizeBytes': sizeBytes,
        'addedUnix': addedUnix,
        if (completedUnix != null) 'completedUnix': completedUnix,
        'status': status.name,
        if (failureMessage != null) 'failureMessage': failureMessage,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> j) {
    DownloadKind kind;
    switch (j['kind'] as String?) {
      case 'episode':
        kind = DownloadKind.episode;
        break;
      case 'vod':
      default:
        kind = DownloadKind.vod;
    }
    DownloadEngine engine;
    switch (j['engine'] as String?) {
      case 'mpvRecord':
        engine = DownloadEngine.mpvRecord;
        break;
      case 'directHttp':
      default:
        engine = DownloadEngine.directHttp;
    }
    DownloadStatus status;
    switch (j['status'] as String?) {
      case 'downloading':
        status = DownloadStatus.downloading;
        break;
      case 'completed':
        status = DownloadStatus.completed;
        break;
      case 'failed':
        status = DownloadStatus.failed;
        break;
      case 'cancelled':
        status = DownloadStatus.cancelled;
        break;
      case 'queued':
      default:
        status = DownloadStatus.queued;
    }
    return DownloadItem(
      id: j['id'] as String,
      kind: kind,
      title: j['title'] as String,
      sourceUrl: j['sourceUrl'] as String,
      localPath: j['localPath'] as String,
      engine: engine,
      posterUrl: j['posterUrl'] as String?,
      subtitle: j['subtitle'] as String?,
      parentSeriesId: (j['parentSeriesId'] as num?)?.toInt(),
      parentSeriesName: j['parentSeriesName'] as String?,
      season: (j['season'] as num?)?.toInt(),
      episode: (j['episode'] as num?)?.toInt(),
      containerExtension: j['containerExtension'] as String?,
      durationSecs: (j['durationSecs'] as num?)?.toInt(),
      sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
      addedUnix: (j['addedUnix'] as num).toInt(),
      completedUnix: (j['completedUnix'] as num?)?.toInt(),
      status: status,
      failureMessage: j['failureMessage'] as String?,
    );
  }
}
