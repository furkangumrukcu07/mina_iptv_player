# Changelog

## 1.2.1 (build 2016)

- **Playlist kurulumu:** M3U sekmesinde `IndexedStack` tüm sekmelerin yüksekliğini (Xtream formu) ayırdığı için “Dosya Seç” altında büyük boşluk oluşuyordu; yalnızca seçilen sekme çiziliyor. Kaynak kartı alt/ara boşlukları ve kartlar arası mesafe sıkılaştırıldı.
- **Android PiP (Küçük ekran):** Ana ekrana Home ile çıkışta gecikmeli Dart çağrısı yerine `setAutoEnterEnabled` (API 31+) ve API 26–30 için `onPause` içinde senkron `enterPictureInPictureMode`; `setPipAutoEnterEligible` kanalı. Arka plana geçerken kısa PiP bekleme + yedek duraklatma.
- **Yönlendirme:** Dikey ↔ yatayda `inactive` ile duraklatma kaldırıldı; `UniversalVideoPlayer` için sabit `GlobalKey`.
- **Hızlı kanal şeridi:** Dokunma ve kumanda OK/Enter ile kanal seçimi; `HardwareKeyboard` ile onay.
- **Playlist:** “Dosya Seç” tam genişlik buton; “dosya seçilmedi” metni butonun altında.
- **Dikey oynatıcı OSD:** Taşan ikon şeridi yatay kaydırma; PiP/fit davranışı önceki sürümlerle uyumlu iyileştirmeler.

## 1.2.0 (build 2015)

- VOD: Xtream `/movie/...` ve `/series/...` yollarında `.ts` → `.m3u8` normalizasyonu (canlı ile aynı mantık).
- Oynatıcı OSD: altyazı seçimi (Better: HLS/DASH manifest; MediaKit: parça listesi); dikey ve yatay (cam OSD) modda ikon.
- Ayarlar (Android telefon): **Küçük ekran (PiP)** — açıkken ana ekrana dönünce Picture-in-Picture denemesi (Better/Exo; sürükleme sistem PiP ile). MediaKit’te otomatik PiP yok.

## 1.1.0 (build 2014)

- **Ayarlar:** Hakkında ve liste alt başlığındaki sürüm, `package_info_plus` ile derlemedeki gerçek `version` + `buildNumber` ile gösterilir.
- **Tema:** Kayıtlı tercih yoksa varsayılan cam teması **Koyu Cam** olur (yeni kurulumlar).
- **Oynatıcı (canlı):** Yayın kesilip durduktan sonra **Oynat** ile aynı kanal tam yeniden yüklenir; kanal değiştirmek veya çıkıp girmek gerekmez (Better ve MediaKit; kullanıcı duraklattıysa yalnızca devam).
- **Oynatıcı:** Sağ yarıda dikey kaydırma ile ses; cam çerçeveli parlaklık/ses göstergesi; donanım ses tuşları ile uyumlu HUD.

## 1.0.7

- Cam çerçeveli diyalog ve snackbar stili.
- TV canlı: tampon ayarı, 15 sn takılmada yeniden bağlanma, MediaKit yedek.
- Genişletilmiş sürüm notları.
