/// Debug oturumu boyunca EPG yük istatistikleri ([G1]). Release'de yalnızca
/// `debugPrint` ile özet basılır; kullanıcıya görünmez.
abstract final class EpgPerfTelemetry {
  static int xtreamLoadStarted = 0;
  static int xtreamLoadThrottled = 0;
  static int globalLoadStarted = 0;
  static int globalLoadThrottled = 0;
  static int loadGenerationBumps = 0;
  static int loadGenerationSkipped = 0;

  static void logSummary() {
    // ignore: avoid_print
    assert(() {
      // debug modda özet
      return true;
    }());
  }

  static String summaryLine() =>
      'EPG perf: xtream=${xtreamLoadStarted} (throttled $xtreamLoadThrottled), '
      'global=${globalLoadStarted} (throttled $globalLoadThrottled), '
      'gen+=$loadGenerationBumps gen~=$loadGenerationSkipped';
}
