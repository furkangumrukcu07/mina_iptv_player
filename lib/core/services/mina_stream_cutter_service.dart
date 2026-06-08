import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Akıllı Jenerik / Özet Atlatıcı (Smart Stream Cutter) servisi.**
///
/// IPTV Xtream akışlarında "Skip Intro" telemetri verisi yok. Onun
/// yerine kullanıcının ilk bölümlerdeki **manuel ileri sarma**
/// davranışını yerel olarak hafızaya alıyoruz: dizinin 1. veya 2.
/// bölümünde, videonun ilk 5 dakikası içinde 30+ saniyelik ileri seek
/// gerçekleşirse, hedef saniyeyi o dizi için **intro bitiş süresi**
/// olarak işaretliyoruz. Sonraki bölümlerde aynı dizide oynatma
/// başladığında, OSD üzerinde 0 → introDuration aralığında bir cam
/// "Jeneriği Atla" butonu otomatik görünür.
///
/// **Veri kaynağı:** SharedPreferences. Anahtar formatı:
/// `mina_intro_skip_v1::<seriesId>` → int saniye (1–600).
///
/// **Kabul kuralları (yanlış pozitiften kaçınmak için):**
///
/// - Yalnızca dizi içeriği (filmler ve canlı yayın hariç).
/// - Yalnızca **1. veya 2. bölüm** seek'leri öğrenme verisi olur.
/// - Seek'in başlangıç pozisyonu **0–300 sn** (ilk 5 dk).
/// - Seek delta'sı **30 sn ile 600 sn** (10 dk) arasında.
/// - Hedef pozisyon **600 sn** ile sınırlandırılır (saçma değerler
///   kayıt edilmez; uzun film sonu jenerikleri için değil, başlangıç
///   intro'su için).
///
/// **Üzerine yazma:** Kullanıcı 2. bölümde de seek yaparsa (aynı kuralı
/// karşılarsa) kayıt güncellenir; en son seek değeri kalıcı olur.
class MinaStreamCutterService extends GetxService {
  static const _prefsPrefix = 'mina_intro_skip_v1::';

  /// İlk seek'in başlayabileceği maks pozisyon (5 dk).
  static const int kMaxSeekStartSec = 300;

  /// Kabul edilebilir minimum ileri seek delta'sı.
  static const int kMinDeltaSec = 30;

  /// Üst sınır: 10 dk'dan büyük intro mantıksız (filmler hariç tutulur
  /// ama yine de güvenlik kapısı).
  static const int kMaxIntroSec = 600;

  /// Sadece 1./2. bölümlerden öğren.
  static const int kMaxLearningEpisode = 2;

  /// Uygulama içi sıcak cache — tekrar tekrar SharedPreferences
  /// I/O'ya çıkmasın diye. Her seriesId için son okuduğumuz değer.
  final Map<String, int> _memCache = {};

  /// Önbelleğe yüklendi mi (SharedPreferences full scan tek kez yapılır).
  bool _warmed = false;

  Future<void> _warmCache() async {
    if (_warmed) return;
    _warmed = true;
    try {
      final p = await SharedPreferences.getInstance();
      for (final k in p.getKeys()) {
        if (!k.startsWith(_prefsPrefix)) continue;
        final v = p.getInt(k);
        if (v == null || v <= 0 || v > kMaxIntroSec) continue;
        final id = k.substring(_prefsPrefix.length);
        _memCache[id] = v;
      }
    } catch (_) {}
  }

  /// O dizi için kayıtlı intro süresi (saniye), yoksa `null`.
  /// Sıcak cache'den okur — UI senkron çağırabilir.
  int? introDurationSecFor(String seriesId) {
    if (seriesId.isEmpty) return null;
    return _memCache[seriesId];
  }

  /// Servis init — disk'ten önbelleği yükle.
  Future<void> ensureLoaded() => _warmCache();

  /// Manuel ileri sarmayı değerlendir; uygunsa intro süresini kaydet.
  ///
  /// - [seriesId] dizinin benzersiz kimliği (Xtream `series_id` veya
  ///   normalize edilmiş ad).
  /// - [episodeNumber] mevcut bölüm numarası (1, 2, ...). 1./2. bölüm
  ///   dışındakiler reddedilir.
  /// - [fromSec] / [toSec] seek'in başlangıç/bitiş pozisyonu (saniye).
  Future<void> recordSeek({
    required String seriesId,
    required int episodeNumber,
    required int fromSec,
    required int toSec,
  }) async {
    if (seriesId.isEmpty) return;
    if (episodeNumber <= 0 || episodeNumber > kMaxLearningEpisode) return;
    if (fromSec < 0 || fromSec > kMaxSeekStartSec) return;
    final delta = toSec - fromSec;
    if (delta < kMinDeltaSec) return;
    if (toSec <= 0 || toSec > kMaxIntroSec) return;
    await _warmCache();
    _memCache[seriesId] = toSec;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('$_prefsPrefix$seriesId', toSec);
    } catch (_) {}
  }

  /// Dizi için kayıtlı intro süresini sil (kullanıcı yanlış öğrendi
  /// derse veya ileride bir "ayarları sıfırla" tile'ından çağrılırsa).
  Future<void> clearForSeries(String seriesId) async {
    if (seriesId.isEmpty) return;
    _memCache.remove(seriesId);
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove('$_prefsPrefix$seriesId');
    } catch (_) {}
  }

  /// Tüm öğrenilmiş intro verilerini temizle.
  Future<void> clearAll() async {
    final ids = List<String>.from(_memCache.keys);
    _memCache.clear();
    try {
      final p = await SharedPreferences.getInstance();
      for (final id in ids) {
        await p.remove('$_prefsPrefix$id');
      }
    } catch (_) {}
  }

  /// Kayıtlı tüm dizi → intro süresi eşlemesi (settings ekranı için).
  Map<String, int> snapshot() => Map<String, int>.unmodifiable(_memCache);
}
