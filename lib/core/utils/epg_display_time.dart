import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../services/app_settings_service.dart';

/// EPG zaman ofseti + 12/24 saat tercihi ile gösterim.
DateTime applyEpgDisplayOffset(DateTime utcOrLocal) {
  if (!Get.isRegistered<AppSettingsService>()) return utcOrLocal;
  final mins = Get.find<AppSettingsService>().epgTimezoneOffsetMinutes.value;
  return utcOrLocal.add(Duration(minutes: mins));
}

String formatEpgClock(DateTime time) {
  final d = applyEpgDisplayOffset(time);
  final use24 = Get.isRegistered<AppSettingsService>()
      ? Get.find<AppSettingsService>().epgTimeFormat24h.value
      : true;
  if (use24) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  return DateFormat.jm().format(d);
}

String epgOffsetLabel(int minutes) {
  if (minutes == 0) return 'UTC±0';
  final sign = minutes > 0 ? '+' : '-';
  final abs = minutes.abs();
  final h = abs ~/ 60;
  final m = abs % 60;
  if (m == 0) return 'UTC$sign$h';
  return 'UTC$sign${h}h ${m}m';
}
