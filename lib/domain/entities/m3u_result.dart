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
}

class UserInfo {
  const UserInfo({
    required this.username,
    required this.status,
    required this.expiryDate,
    required this.isTrial,
    required this.activeConnections,
    required this.maxConnections,
  });

  final String username;
  final String status;
  final DateTime? expiryDate;
  final bool isTrial;
  final int activeConnections;
  final int maxConnections;
}
