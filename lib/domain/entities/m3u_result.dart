import 'channel.dart';
import 'series.dart';
import 'vod.dart';

class M3uResult {
  const M3uResult({
    required this.channels,
    required this.channelCategories,
    required this.vod,
    required this.vodCategories,
    required this.series,
    required this.seriesCategories,
    this.recentVodIds = const <int>[],
    this.recentSeriesIds = const <int>[],
    this.userInfo,
  });

  final List<Channel> channels;
  final List<ChannelCategory> channelCategories;
  final List<VodItem> vod;
  final List<VodCategory> vodCategories;
  final List<SeriesItem> series;
  final List<SeriesCategory> seriesCategories;
  final List<int> recentVodIds;
  final List<int> recentSeriesIds;
  final UserInfo? userInfo;

  /// Film/dizi nesnelerini bellekten çıkarır; kategoriler, meta ve kanallar
  /// kalır. SQLite doluysa VOD/dizi tüketicileri [PlaylistDataSource] üzerinden
  /// okumaya devam eder.
  M3uResult withoutVodSeriesInMemory() {
    if (vod.isEmpty && series.isEmpty) return this;
    return M3uResult(
      channels: channels,
      channelCategories: channelCategories,
      vod: const [],
      vodCategories: vodCategories,
      series: const [],
      seriesCategories: seriesCategories,
      recentVodIds: recentVodIds,
      recentSeriesIds: recentSeriesIds,
      userInfo: userInfo,
    );
  }

  /// SQLite önbelleği için film/dizi/kanal listelerini bellekten çıkarır;
  /// kategoriler ve meta kalır. Canlı kanallar [PlaylistDataSource] üzerinden
  /// diskten okunur.
  M3uResult slimForSqliteCache() {
    if (vod.isEmpty && series.isEmpty && channels.isEmpty) return this;
    return M3uResult(
      channels: const [],
      channelCategories: channelCategories,
      vod: const [],
      vodCategories: vodCategories,
      series: const [],
      seriesCategories: seriesCategories,
      recentVodIds: recentVodIds,
      recentSeriesIds: recentSeriesIds,
      userInfo: userInfo,
    );
  }
}

class UserInfo {
  const UserInfo({
    required this.username,
    required this.status,
    required this.expiryDate,
    required this.isTrial,
    required this.activeConnections,
    required this.maxConnections,
    this.password,
    this.message,
    this.auth,
    this.createdAt,
    this.allowedOutputFormats = const <String>[],
  });

  final String username;
  final String status;
  final DateTime? expiryDate;
  final bool isTrial;
  final int activeConnections;
  final int maxConnections;

  /// Xtream panelinde tanımlı şifre. UI'da maskelenir.
  final String? password;

  /// Panel tarafından döndürülen mesaj (ör. "Welcome").
  final String? message;

  /// `1` = doğrulandı, `0` = doğrulanmadı.
  final int? auth;
  final DateTime? createdAt;

  /// `m3u8`, `ts`, `rtmp` vb. panelin desteklediği çıktı formatları.
  final List<String> allowedOutputFormats;
}

/// Xtream panelinin döndürdüğü `server_info` bilgileri (sunucu URL'leri,
/// portlar, saat dilimi, vs.).
class XtreamServerInfo {
  const XtreamServerInfo({
    this.url,
    this.port,
    this.httpsPort,
    this.rtmpPort,
    this.serverProtocol,
    this.timezone,
    this.serverTimeUtc,
    this.serverTimeLocalLabel,
    this.process,
    this.revision,
  });

  final String? url;
  final String? port;
  final String? httpsPort;
  final String? rtmpPort;
  final String? serverProtocol;
  final String? timezone;
  final DateTime? serverTimeUtc;
  final String? serverTimeLocalLabel;
  final bool? process;
  final String? revision;

  bool get isEmpty =>
      (url == null || url!.trim().isEmpty) &&
      (port == null || port!.trim().isEmpty) &&
      (httpsPort == null || httpsPort!.trim().isEmpty) &&
      (rtmpPort == null || rtmpPort!.trim().isEmpty) &&
      (serverProtocol == null || serverProtocol!.trim().isEmpty) &&
      (timezone == null || timezone!.trim().isEmpty) &&
      serverTimeUtc == null &&
      (serverTimeLocalLabel == null || serverTimeLocalLabel!.trim().isEmpty);
}

/// Ayarlar > Xtream Hesabı ekranı için tek bir paket — `user_info` + `server_info`.
class XtreamAccountSnapshot {
  const XtreamAccountSnapshot({
    required this.user,
    required this.server,
  });

  final UserInfo? user;
  final XtreamServerInfo? server;
}
