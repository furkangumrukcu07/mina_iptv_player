/// Aktif playlist tutucusu: 1 = birincil, 2..[kMaxPlaylistSlots] = ek listeler.
///
/// Eski (sabit 4 slot) tasarımdan dinamik bir yapıya geçildi: kullanıcı
/// Ayarlar > Liste Yönetimi'nden istediği sayıda liste ekleyebilir. Storage
/// katmanı slot başına `mina_iptv_*_$slot` anahtarlarını kullandığı için
/// üst sınır yalnızca "saçma sapan büyük olmasın" diye konuldu; gerçek bir
/// kullanıcı bunu hiç zorlamaz.
const int kMaxPlaylistSlots = 32;

/// Eski isim — birden çok dosyada referans var; yeni kod [kMaxPlaylistSlots]
/// kullanır.
const int kPlaylistSlotCount = kMaxPlaylistSlots;

/// Birincil dışında saklanabilecek ek slot sayısı.
const int kPlaylistExtraSlotCount = kMaxPlaylistSlots - 1;

/// `M3uSource.url` değeri playlist gövdesi uygulama destek dizinindeyken
/// kullanılan sentinel. Slot 1 (birincil).
const String kM3uLocalPlaylistSentinel = 'mina://local-m3u';

/// İkinci kaynak için yerel M3U dosyası — slot 2 (eski kod uyumluluğu).
const String kM3uLocalPlaylistSentinel2 = 'mina://local-m3u-2';

bool isM3uLocalSentinel(String url) => url.trim() == kM3uLocalPlaylistSentinel;

bool isM3uLocalSentinel2(String url) => url.trim() == kM3uLocalPlaylistSentinel2;

/// Verilen slot için doğru sentinel URL'sini döndürür (1..[kMaxPlaylistSlots]).
/// Slot 1: `mina://local-m3u`, slot N≥2: `mina://local-m3u-N`.
String localM3uSentinelForSlot(int slot) {
  if (slot < 1 || slot > kMaxPlaylistSlots) {
    throw ArgumentError.value(
      slot,
      'slot',
      'must be in 1..$kMaxPlaylistSlots',
    );
  }
  if (slot == 1) return kM3uLocalPlaylistSentinel;
  return '$kM3uLocalPlaylistSentinel-$slot';
}

/// `mina://local-m3u(-N)?` desenini eşleştirir.
final RegExp _localM3uPattern = RegExp(r'^mina://local-m3u(?:-(\d+))?$');

/// `url`'in herhangi bir slot için yerel sentinel olup olmadığını kontrol eder.
bool isAnyM3uLocalSentinel(String url) =>
    _localM3uPattern.hasMatch(url.trim());

/// `url` bir sentinel ise hangi slot olduğunu döner; değilse `null`.
int? slotFromLocalM3uSentinel(String url) {
  final m = _localM3uPattern.firstMatch(url.trim());
  if (m == null) return null;
  final g = m.group(1);
  if (g == null) return 1;
  return int.tryParse(g);
}

/// Slot indekslerini iterate etmek için yardımcı (1..[kMaxPlaylistSlots]).
Iterable<int> allPlaylistSlots() sync* {
  for (var i = 1; i <= kMaxPlaylistSlots; i++) {
    yield i;
  }
}

/// Yalnızca ek slotları (2..[kMaxPlaylistSlots]).
Iterable<int> extraPlaylistSlots() sync* {
  for (var i = 2; i <= kMaxPlaylistSlots; i++) {
    yield i;
  }
}
