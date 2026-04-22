import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// VOD (film / dizi bölümü) izleme konumu — [Channel.id] anahtarıyla kalıcı.
class WatchProgressService extends GetxService {
  static const _kPos = 'mina_watch_pos_';
  static const _kDur = 'mina_watch_dur_';

  Future<int?> loadPositionMs(int streamId) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getInt('$_kPos$streamId');
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProgress(int streamId, int positionMs, int durationMs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_kPos$streamId', positionMs);
      if (durationMs > 0) {
        await prefs.setInt('$_kDur$streamId', durationMs);
      }
    } catch (_) {}
  }

  Future<void> clear(int streamId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kPos$streamId');
      await prefs.remove('$_kDur$streamId');
    } catch (_) {}
  }
}
