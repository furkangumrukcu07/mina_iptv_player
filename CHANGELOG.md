# Changelog

## Uygulama özellikleri (genel)

- **Kaynaklar:** M3U / M3U8 (URL veya yerel dosya), **Xtream Codes** API; birincil ve isteğe bağlı ikinci kaynak.
- **Canlı TV:** Kategori ve kanal listesi, arama, favoriler, yatay/dikey ve **Android TV** kumanda odakları; hızlı kanal şeridi ve cam OSD.
- **VOD ve diziler:** Gözatma, önizleme, **kaldığın yerden devam**, otomatik sıradaki içerik; MediaKit ve Better Player (ExoPlayer).
- **EPG:** XMLTV ve Xtream EPG; tam ekran zaman çizelgesi; **catch-up / arşiv** için panel şablonu (timeshift yolu, `timeshift.php`, özel URL).
- **Kategori gizleme:** Xtream’de panel kategori ID’leri; M3U’da **group-title** (normalize ad) — canlı, film ve dizi sekmeleri.
- **Ebeveyn denetimi:** PIN ile korunan kategori gizleme ekranı.
- **Görseller:** Kanal logoları için **yerel disk önbelleği** (indirme, yeniden boyutlandırma, sınırlı paralel ön yükleme); liste kaydırmada daha az ağ yükü.
- **Ayarlar:** Tema (cam), dil, canlı tampon, HLS/DASH **adaptif kalite tavanı**, altyazı punto (MediaKit), PiP (telefon), düşük performans modu, decoder tercihi, uyku zamanlayıcısı, vb.

---

## 1.9.13 (build 3112)

- **Kurulum sihirbazı (TV):** Yeni TV kurulumu ekranı (blur + cam tema) ve 3 yöntem (M3U URL, M3U dosya, Xtream) akışı tamamlandı; ilk açılışta yöntemler daraltılmış gelir, seçimde genişler. Demo modu eklendi.
- **Kurulum sihirbazı (TV) — D-Pad/odak:** Başlık, alan ve butonlarda odak ağacı güçlendirildi; görünür odak çerçevesi/parlama, OK/Enter ile güvenilir tetikleme, alanlar arası yukarı-aşağı geçiş, ilk odak ve geri tuşu davranışı (IME kapat → bölüm daralt) düzeltildi.
- **Kurulum sihirbazı (TV) — klavye UX:** Metin alanlarında sanal klavye otomatik açılır; kullanıcı manuel kapattıysa aynı alanda tekrar otomatik açılmaz, OK ile yeniden açılır. Xtream formunda klavye açıkken panel yukarı kaydırılarak alanların görünürlüğü artırıldı.
- **Playlist kurulum ekranı (uygulama içi) — TV optimizasyonu:** M3U/Xtream sekmeleri, dosya seç, ikinci kaynak satırı ve yükle butonu TV kumandası için yeniden odaklandı; sekmelerde sol/sağ, içerikte yukarı/aşağı akışı, switch satırında satırın tamamından OK ile toggle, final butonda güçlü focus/scale geri bildirimi.
- **Xtream odak akışı:** Sunucu/Kullanıcı/Şifre alanlarında odakta ikon ve etiketlerin Mina yeşiline dönmesi, `Next/Done` ile zincir geçiş (şifreden sonra doğrudan yükle butonu), bilgi kutusunun (`player_api.php`) odaktan çıkarılması ve seçili Xtream sekmesinde yeşil tema.
- **Dikey oynatıcı kanal geçişi:** Portre modda kanal değişirken tam ekran logo/splash overlay kaldırıldı; oynatıcı kontrolleri + hızlı menü korunup yalnız merkezde küçük loading spinner gösterilir (yatay davranışla uyumlu).
- **Better Player (ExoPlayer) stabilite:** Canlı buffer eşikleri artırıldı (`minBufferMs=3000`, `bufferForPlaybackMs=1000`, `bufferForPlaybackAfterRebufferMs=1500`); `setupDataSource` sonrası buffering event listener ile >1 sn buffering durumunda `seekTo(0)+play` toparlama eklendi.
- **MediaKit/mpv donma ayarı:** mpv canlı açılış seçenekleri revize edildi (`cache=yes`, `demuxer-readahead-secs=20`, `min-cache-percent=0`, `cache-secs=1`, `stream-buffer-size=512KiB`, `ffmpeg-fast=yes`, `vd-lavc-fast=yes`); property set akışı cihaz uyumluluğu için güvenli hale getirildi.

## 1.5.20 (build 3024)

- **Kanal logosu önbelleği:** Logolar indirilip izole iş parçacığında yeniden boyutlandırılarak uygulama destek dizinine yazılır; playlist yüklendikten sonra sınırlı sayıda URL **ön alınır**. Kanal listesi, EPG, oynatıcı OSD ve ilgili tüm logo noktaları ortak akışa alındı. Liste/ayar temizliğinde logo önbelleği de silinir.
- **Kategori gizleme (M3U):** Yerel veya URL M3U listelerinde gizleme, parse’a göre değişen sayısal ID yerine **kategori adı** (normalize `group-title`) ile saklanır; kaynak URL’süne bağlı anahtar. Canlı, gözat (VOD/dizi) ve ana ekran araması aynı kuralları kullanır (`PlaylistCategoryHide`).
- **Metinler:** Kategori gizleme başlığı ve kullanılamaz mesajı M3U’yu da kapsayacak şekilde güncellendi.

## 1.2.23 (build 2039)

- **Ebeveyn denetimi (Ayarlar, Xtream):** Güvenli depoda saklanan **PIN** (4–6 rakam) oluşturma; PIN doğrulamasından sonra **canlı / film / dizi** Xtream kategorilerini gizleme (mevcut kategori gizleme verisiyle aynı; ayarlardaki doğrudan “kategori gizleme” kutusu **ebeveyn** akışına taşındı).
- **Kategori gizleme ekranı:** **D-pad** — satır odağında **OK / Space** ile gizle/göster; `FocusTraversalGroup` + odak vurgulu satırlar. **Gömülü mod:** ebeveyn ekranı içinde üstte sekmeler + **Kaydet**; kayıtta tam sayfa kapanmaz.
- **Hızlı menü (oynatıcı):** Kanallar başlığı kaldırıldı; kategori kutusunda **sol/sağ ok** (çok kategori) ve **dokunmatik** ok alanları; yatayda **daha sıkı** satır yüksekliği / küçük logo ve metin; üstteki **X** kaldırıldı (kapatma: dış alan + Geri).
- **Android TV / Play:** `drawable-xhdpi` **320×180** banner PNG, **512×512** simge; TV için `drawable-television-*` ön plan; `tv_banner.xml` kaldırıldı.

## 1.2.18 (build 2034)

- **Canlı oynatıcı (TV):** OSD’de **dur/durdur** odağındayken **OK uzun basış** yalnızca **hızlı kanal şeridini** açar; kısa basış yine duraklat/devam. Şerit kapanınca (Geri / arka plan) **cam OSD** yeniden açılır ve otomatik gizlenir. **Geri** ile şerit kapanırken aynı sistem pop’unda oyuncudan çıkılması engellendi (`PopScope` tüketimi).
- **Tek kanal EPG (TV):** Kumanda **Geri** ile kapanırken çift pop nedeniyle oyuncudan çıkma giderildi (`onHardwareBack` + `PopScope`).
- **Better Player / Android:** IPTV için **canlı** (daha düşük gecikme) ve **VOD** (daha geniş tampon) tampon profilleri; Exo `setPrioritizeTimeOverSizeThresholds` desteği (`BetterPlayerBufferingConfiguration` + Kotlin `DefaultLoadControl`).
- **Kanallar / Gözat (TV):** Liste ve **sol kategori** satırlarında tek basışta **iki satır atlaması** giderildi (`KeyRepeat` yutma; basılı tutmada ilk tekrar için **~420 ms** bekleme, sonra periyodik adım).
- **Ana ekran (TV):** **Arama** ikonunda odak varken **OK**’nin bazen tepki vermemesi giderildi (`Focus.descendantsAreFocusable` + `InkWell.canRequestFocus: false`); ayarlar ikonu aynı mantıkla hizalandı.

## 1.2.14 (build 2029)

- **VOD / dizi:** Film ve bölüm için **kaldığın yerden devam** — izleme konumu kaydedilir; açılışta konum sorulur (`WatchProgressService`).
- **VOD:** İzleme bitince **sonraki film veya bölüm** için geri sayımlı **otomatik oynatma** (iptal / hemen oynat; TV kumandası ile uyum).
- **Ana ekran arama:** Kapsam seçimi — **tümü**, yalnızca **canlı**, **filmler**, **diziler** veya **favoriler** (`HomeSearchScope`).
- **EPG:** Tam ekran **zaman çizelgesi** gövdesi (`ChannelsEpgTimelineScaffold` / `ChannelsEpgTimelineBody`); EPG yükleme ve kullanım akışında iyileştirmeler.
- **Catch-up (arşiv):** Panel türüne göre arşiv URL’si — **kapalı**, klasik **Xtream timeshift yolu**, **`timeshift.php` sorgusu** veya **özel şablon** (`CatchUpUrlPreset`).
- **Xtream:** **Kategori gizleme** — canlı, VOD ve dizi sekmelerinde istenmeyen kategorileri listeden çıkarma (`XtreamCategoryHideView`).
- **Ayarlar — oynatma:** HLS/DASH için **adaptif kalite üst sınırı** (otomatik / en fazla 720p / 1080p / 4K).
- **Ayarlar — altyazı:** **MediaKit altyazı punto** seçimi (Better tarafında mevcut davranış korunur).
- **Android:** **SoC / bellek** ipuçları (ör. Amlogic benzeri kutularda tampon ve MediaKit yolu); `MainActivity` içinde PiP ve **cihaz profili** kanalı (`mediaKitSoCProfile`, TV algısı) iyileştirmeleri.
- **Oynatıcı / TV:** Canlı ve VOD için OSD, kumanda ve cam panellerde kapsamlı düzenlemeler; ayrı TV “meşgul” OSD katmanı kaldırıldı, durum tek akışta birleştirildi.
- **Gözat / Kanallar / playlist:** Düzen, odak ve liste davranışlarında güncellemeler; çeviriler genişletildi.
- **better_player_plus (fork):** Altyazı çizimi ve yapılandırma uyarlama; Android tarafında küçük düzeltmeler.

## 1.2.13 (build 2028)

- **Playlist kurulum (TV düzeni):** **Xtream** sekmesi solda / ilk sırada, **M3U** sağda; birincil ve ikinci kaynak aynı sırayı kullanır (`tabIndex` / `secondaryTabIndex`: 0 = Xtream, 1 = M3U).
- **TV kumanda odak:** `OrderedTraversalPolicy` + `NumericFocusOrder` ile ayarlar, sekmeler, alanlar, dosya seç ve **Listeyi yükle** sıralı gezilebilir; sekme dilimlerinde odak çerçevesi.
- **TV URL girişi:** Sanal klavye açıkken alanın görünür kalması için `resizeToAvoidBottomInset: false`, kaydırılabilir içerikte ek alt boşluk, metin alanlarında büyük `scrollPadding` ve odakta `Scrollable.ensureVisible` (`_PlaylistTextField`).

## 1.2.12 (build 2027)

- **Canlı yayın — hızlı zapping:** Kumanda **yukarı / aşağı** (veya OSD’de kanal adımları) ile kanal değiştirirken bekleme süresi canlı akışta **~200 ms** olacak şekilde kısaltıldı (önceki ~500 ms). Ardışık basışlar yine tek `zapTo` ile birleştirilir; ağ ve oynatıcı yükü korunur.
- **Canlı yayın — OSD:** TV’de kanal değişiminde mümkün olduğunda aynı Better/Exo örneği yeniden kullanılır; cam OSD kapanıp ikinci “yükleniyor” şeridine düşmez, kanal adı/logo OSD üzerinde hızlı güncellenir.
- **Kanallar — EPG zaman çizelgesi:** Yatay düzende üst çubukta zaman çizelgesi ikonu; **dikey (telefon)** düzende de aynı ikon + sekmeler **kaydırılabilir** (dördüncü sekme EPG). Tam ekran EPG için `ChannelsEpgTimelineScaffold`.

## 1.2.11 (build 2026)

- **Android TV — canlı yayın, hızlı kanal şeridi:** OK’ye uzun basınca açılan şerit açıkken **Geri** (veya Escape) artık yayından çıkmıyor; şerit kapanıyor ve ana oynatıcı OSD (cam panel) açılıyor. Sistem geri hareketi (`PopScope`) aynı davranışı izler.

## 1.2.10 (build 2025)

- **Tablet düzeni — oynatıcı:** Yayın izlenirken üst durum çubuğu gizlenir; `immersiveSticky` ile tam ekran oynatma (çıkışta tablet chrome geri yüklenir).

## 1.2.9 (build 2024)

- **Tema (Koyu Cam):** Yeni arka plan görseli hem dikey hem yatayda kullanılıyor.
- **Telefon düzeni — yatay oynatma:** Durum çubuğu gizli tam ekran (immersive); dikeyde edge-to-edge + sistem çubuğu. Yön değişiminde chrome senkronu.
- **Telefon düzeni — yön kilidi:** “Yataya çevir” sonrası ekranın hemen tekrar dikeye dönmesi giderildi; yön kilidi yalnızca fiziksel **dikeyde** kaldırılıyor.
- **Dikey oynatıcı OSD:** Yatay moda geçiş için **ekran döndürme** ikonu (`screen_rotation`); kilit ikonu kaldırıldı.
- **Dikey oynatıcı — kanal şeridi:** Şerit genişletildi; kanal adının altında logo; izlenen kanal şeridin soluna kaydırılarak hizalanıyor.
- **Wakelock (telefon):** Dikeyde yayın oynatılırken / tamponlanırken ekranın kapanması engellenir; duraklatınca normal; tablet/TV’de oynatıcı açıkken önceki davranış korunur.
- **Canlı TV / Gözat (telefon):** Yatay geniş düzende üst cam çubukta **geri** düğmesi; dokunma alanı büyütüldü (48×48).
- **Ana ekran:** Alttaki dekoratif (sahte) beyaz çizgi kaldırıldı — tüm düzenler ve yönler.

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
