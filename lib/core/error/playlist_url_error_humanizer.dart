import 'package:get/get.dart';

import 'app_exception.dart';

/// Dio / ağ hatalarını kullanıcıya gösterilecek Türkçe (i18n) metne çevirir.
String humanizePlaylistUrlError(
  Object error, {
  String url = '',
}) {
  final raw = error is AppException ? error.message : error.toString();
  final lower = raw.toLowerCase();

  if (lower.contains('handshake') ||
      lower.contains('certificate') ||
      lower.contains('ssl') ||
      lower.contains('tls') ||
      lower.contains('x509')) {
    return 'playlist.error.url.ssl'.tr;
  }
  if (lower.contains('host lookup') ||
      lower.contains('nodename nor servname') ||
      lower.contains('failed host lookup') ||
      lower.contains('no address associated') ||
      lower.contains('unknown host')) {
    return 'playlist.error.url.host'.tr;
  }
  if (lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('zaman aşımı') ||
      lower.contains('took longer than')) {
    return 'playlist.error.url.timeout'.tr;
  }
  if (lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('connection closed') ||
      lower.contains('connection terminated') ||
      lower.contains('software caused connection')) {
    return 'playlist.error.url.refused'.tr;
  }
  if (lower.contains('http 401') || lower.contains('http 403')) {
    return 'playlist.error.url.auth'.tr;
  }
  if (lower.contains('http 404')) {
    return 'playlist.error.url.notFound'.tr;
  }
  if (lower.contains('http 5')) {
    return 'playlist.error.url.server'.tr;
  }
  if (lower.contains('empty response') ||
      lower.contains('m3u content is empty') ||
      lower.contains('playlist url is empty')) {
    return 'playlist.error.url.empty'.tr;
  }
  if (lower.contains('failed to load playlist') ||
      lower.contains('network error')) {
    return 'playlist.error.url.network'.tr;
  }

  if (error is AppException) {
    return error.message;
  }
  return 'playlist.error.url.network'.tr;
}
