import 'package:get/get.dart';

/// Film/dizi detayında IMDb satırı için kısa süre metni (örn. `1h 36m`).
String vodFmtDurationCompact(int totalSecs) {
  if (totalSecs <= 0) return 'browse.duration.unknown'.tr;
  final h = totalSecs ~/ 3600;
  final m = (totalSecs % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

String? vodFmtOmdbRuntimeForDetail(String? runtime) {
  if (runtime == null || runtime.trim().isEmpty || runtime == 'N/A') {
    return null;
  }
  final m = RegExp(r'(\d+)').firstMatch(runtime);
  if (m != null) {
    return 'browse.duration.minutes'.trParams({'n': m.group(1)!});
  }
  return runtime.trim();
}
