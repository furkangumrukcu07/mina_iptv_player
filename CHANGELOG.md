# Changelog

## Uygulama özellikleri (genel)

## 2.11.4 (build 4236)

**9 Haziran 2026 — Kategori göster/gizle iyileştirmeleri + TMDB/OMDb anahtar rotasyonu.**

- **Kategori göster / gizle** (Ayarlar > Kanal Kategori Düzeni):
  - "Kategori gizleme" adı **"Kategori göster / gizle"** olarak değiştirildi.
  - Anahtar mantığı sezgiselleştirildi: **anahtar açık = kategori görünür,
    kapalı = gizli**. Sayfaya açıklayıcı ipucu eklendi.
  - **Tümünü Göster / Tümünü Gizle** butonları eklendi; aktif sekmedeki
    (Canlı / Filmler / Diziler) tüm kategorilere uygulanır. Kumanda (D-pad)
    ile odaklanıp seçilebilir.
- **Metadata API dayanıklılığı:** TMDB için yedek API anahtarı ve otomatik
  anahtar rotasyonu eklendi (geçersiz/iptal anahtarda sıradakine geçer). OMDb
  anahtar rotasyonu, 401 (limit/geçersiz) yanıtlarının doğru algılanması için
  düzeltildi (`validateStatus`).
- 15 kısmi dil için çeviriler senkronize edildi.

## 2.10.54 (build 4186)

**3 Haziran 2026 — Bakım sürümü.**

- Sürüm yükseltildi; mağaza dağıtımı için yeni AAB paketi üretildi.
- Çeviri dosyalarındaki satır sonu kaçış düzeltmeleri korundu.

## 2.10.53 (build 4185)

**3 Haziran 2026 — Canlı TV yatay: "Listeler" üst çubuğa taşındı.**

- Yatay mod Canlı TV'de sol paneldeki **Listeler** barı kaldırıldı; kategoriler
  paneli doğrudan "Kategoriler" ile başlıyor.
- Liste seçimi, sağ üstte arama/ayarlar cam kapsülünün içine **yalnızca ikon**
  (`layers`) olarak eklendi; çerçeve içeriğe göre dinamik boyutlanır. 2+ dolu
  liste varken görünür.
- **TV / kumanda:** ikon odaklanabilir; ok tuşlarıyla üst çubuk butonları
  arasında gezinme; OK ile liste seçici açılır; seçicide ok + OK ile liste
  değiştirme. İlk kategori satırından yukarı ok ile Listeler ikonuna çıkılır.
- Dokunmatik dokunma ile liste seçici aynı şekilde açılır.

## 2.10.52 (build 4184)

**3 Haziran 2026 — Yeni "Amoled Black" teması + liste aç/kapa anında geri bildirim.**

- **Amoled Black teması** eklendi. Saf siyah AMOLED duvar kağıtları
  (`blackdikey` dikey / `blackyatay` yatay), neredeyse opak siyah cam paneller,
  ince beyaz kenarlar ve camgöbeği (#22D3EE) vurgu. Koyu cam ailesinin gerçek
  blur cam yüzeylerini korur; Ayarlar ve kurulum sihirbazındaki tema listesinde
  görünür.
- **Liste aç/kapa anahtarı artık donmuş gibi görünmüyor.** Liste Yönetimi'nde
  sağdaki anahtara basılınca anahtar **anında** hedef konuma geçer ve altında
  "Açılıyor… / Kapanıyor…" etiketi gösterilir; gerçek işlem (3-4 sn) arka planda
  sürerken kullanıcı ne olduğunu görür. İşlem boyunca anahtar tekrar basılmaya
  karşı kilitlenir.

## 2.10.51 (build 4183)

**3 Haziran 2026 — "Film & Dizi" sayfasına üst sağ "Listeler" pili.**

- Film & Dizi (Önerilen Filmler) sayfasının üst sağ köşesine, geri butonuyla
  aynı hizada cam bir **"Listeler"** pili eklendi (aktif liste adını gösterir).
  Dokununca liste seçici açılır; farklı liste seçilince film/dizi içeriği
  **anında** o listeye göre yeniden kurulur. Pil yalnızca 2+ dolu liste varken
  görünür ve TV'de D-pad ile odaklanabilir.
- `RecommendedFilmsController` artık aktif liste değişimini dinliyor — sayfa
  açıkken liste değiştirilse bile feed taze veriyle güncellenir.

## 2.10.50 (build 4182)

**3 Haziran 2026 — Liste ekle/düzenle ekranı yeniden tasarlandı (cam + TV/D-pad).**

- Liste Yönetimi'nde liste ekleme/düzenleme artık **alttan fırlayan bir sheet
  yerine tam ekran, sabit bir sayfa**. Cam tasarıma uygun, koyu gradyan zeminli.
- **TV / kumanda uyumlu:** üst geri butonu, tür seçici (M3U URL / M3U Dosya /
  Xtream) cam segmentleri ve alanlar D-pad ile gezilebilir; segmentler OK ile
  seçilir, Kaydet butonu odaklanabilir.
- **Taşma düzeltildi:** Sunucu adresi, kullanıcı adı gibi alanlar tek satır +
  yatay kaydırmalı cam alanlar; uzun metin taşmadan, imleç hareketiyle görünür.
  Etiketler ve yardımcı metinler net okunur.
- 2./3./4. listeyi eklerken M3U URL girilse de (varolan birincil akıştaki gibi)
  `username`/`password` içeren URL'ler otomatik **Xtream'e çevrilir**.
- Liste Yönetimi başlığındaki "İstediğin kadar liste ekle" metni korundu;
  "canlı, film ve dizi tek kütüphanede birleşir" ifadesi (birleştirme kaldırıldığı
  için) **silindi**.

## 2.10.49 (build 4181)

**3 Haziran 2026 — Filmler/Diziler üst çubuğuna liste seçimi düğmesi.**

- Filmler & Diziler bölümünde, üst çubukta (en solda geri butonuyla aynı hizada)
  **en sağ tarafta** bir liste seçimi düğmesi eklendi. Dokununca "Liste Seç"
  alt sayfası açılır; farklı liste seçilince içerik **anında** o listeye geçer
  (kategoriler + film/dizi ızgarası taze yüklenir). Düğme yalnızca 2+ dolu liste
  varken görünür ve kategorilerin üstündeki "Listeler" barıyla aynı seçiciyi
  paylaşır.

## 2.10.48 (build 4180)

**3 Haziran 2026 — "Listeler" barına kumanda (D-pad) navigasyonu + ana ekran
şeritlerinde canlı liste yenileme.**

1. **TV / kumanda odak akışı.** Canlı TV ve Filmler/Diziler kategori sütununun
   üstündeki **"Listeler"** barı artık D-pad ile gezilebiliyor: kategori
   listesinin ilk satırından **yukarı** ok ile bara çıkılır, **OK** ile liste
   seçici açılır, **aşağı** ok ile tekrar kategorilere inilir. Tek liste varken
   bar görünmediği için yukarı ok eskisi gibi yutulur. Liste seçici alt sayfa
   da kumanda dostu: açılışta odak aktif listede başlar, yön tuşları satırlar
   arasında gezer, OK seçer.
2. **Ana ekran canlı yenileme.** "Listeler" barından liste değiştirildiğinde
   ana ekrandaki kategori kartı önizlemeleri/sayıları ve film/dizi şeritleri
   (Mina AI önerileri, Yüksek Puanlı Filmler, karışık canlı TV) artık bölüme
   tekrar girmeyi beklemeden anında yeni listenin verisiyle yeniden çiziliyor.

## 2.10.47 (build 4179)

**3 Haziran 2026 — Liste birleştirme tamamen kaldırıldı; yerine "Listeler"
geçiş barı geldi.**

Kullanıcı isteği: Liste yüklemelerinde birleştirme özelliği tamamen devre
dışı bırakıldı. Artık birden fazla liste birbirine karışmıyor; uygulama her
zaman **tek bir aktif listeyi** gösteriyor. Kullanıcı listeler arasında yeni
**"Listeler" barından** geçiş yapıyor.

Değişiklikler:

1. **Birleştirme kapatıldı.** Splash / ana ekran yenileme / ayarlar yenileme
   artık yalnızca aktif slot'un içeriğini yükler (`ActivePlaylistService`).
   Liste Yönetimi'ndeki "Listeleri Birleştir" butonu ve otomatik birleştirme
   mantığı kaldırıldı.
2. **"Listeler" barı.** Canlı TV, Filmler ve Diziler bölümlerinde
   kategorilerin üstünde yeni bir bar. Dokununca açılan cam alt sayfadan
   liste seçilir; seçilen listenin kategorileri + içeriği anında gösterilir.
   (Yalnızca 2+ dolu liste varsa görünür.)
3. **Hızlı geçiş.** Her slot kendi anlık görüntüsünü (`SlotPlaylistSnapshotStore`)
   ve oturum içi bellek önbelleğini tutar — listeler arası geçiş ağ beklemeden
   anında olur.
4. **Yeni liste eklenince** o liste otomatik aktif olur ve gösterilir.

## 2.10.45 (build 4177)

**2 Haziran 2026 — Liste yönetimi UX pratikleştirildi + yükleme özet
diyaloğu otomatik kapanıyor.**

Kullanıcı geri bildirimi:

1. Yeni liste yüklenirken kanal/film/dizi sayıları popup'ta gösterilse
   bile kullanıcı **Tamam**'a basana kadar diyalog açık kalıyordu;
   merge cache arka planda olsa bile UX akışı bekliyordu.
2. Liste yönetimi pratik değildi — slot'taki içeriği yenilemek için
   her seferinde silip yeniden eklemek gerekiyordu.

İyileştirmeler:

- `PlaylistLoadSummaryDialog`:
  - **Otomatik kapanma**: `done` durumuna geçip 3 satır animasyonu
    tamamlandığında **5 saniyelik geri sayım** başlatılır. Süre dolunca
    diyalog otomatik kapanır; merge cache zaten arka planda devam ediyor.
  - **Tamam butonu** "Tamam (5)" → "Tamam (4)" şeklinde countdown
    gösterir; kullanıcı erken basabilir.
  - Sol altta küçük hint metni: "Diyalog otomatik kapanacak. Birleştirme
    arka planda devam ediyor."
  - **Kullanıcı dokunursa countdown iptal edilir** (gestureDetector ile
    `_cancelAutoClose`) → kullanıcı sayıları dikkatlice incelemek
    isterse diyalog açık kalır.
  - Hata durumunda countdown başlamaz — kullanıcı hatayı görmeli.

- `PlaylistsManagerController.refreshSlot(slot)` (yeni public method):
  - Mevcut kaynaktan (`M3uSource` veya `XtreamSource`) listeyi yeniden
    çeker; aynı summary popup ile kanal/film/dizi sayılarını gösterir.
  - Yerel dosya (`m3uLocal`) için anlamsız → `refreshLocalUnsupported`
    toast'u ile bilgi verir; kullanıcı dosyayı tekrar seçmeli.
  - `isFreshExtra=false` olduğundan **solo mod tetiklenmez** — yenileme
    sadece içeriği tazeler, slot'ların aktif/pasif durumunu değiştirmez.

- `PlaylistsManagerView._SlotActions`:
  - Her dolu **uzaktan kaynak** slotunun (M3U URL veya Xtream) yanına
    `Icons.refresh_rounded` butonu eklendi. Tek dokunuşla listeyi
    güncelleyebilirsin.
  - Yerel dosya kaynakları için yenileme gizli (anlamsız).

Yeni i18n anahtarları (TR/EN):

- `playlist.summary.okCountdown` — "Tamam (@n)" / "OK (@n)"
- `playlist.summary.autoCloseHint` — countdown bilgi metni
- `playlistsManager.refresh` — buton tooltip "Listeyi yenile"
- `playlistsManager.toast.refreshEmpty` — boş slot uyarısı
- `playlistsManager.toast.refreshLocalUnsupported` — yerel dosya uyarısı
- `playlistsManager.toast.refreshUnsupported` — desteklenmiyor uyarısı

## 2.10.44 (build 4176)

**2 Haziran 2026 — Otomatik liste birleştirme kaldırıldı + manuel "Listeleri Birleştir" butonu.**

Kullanıcı geri bildirimi: Yeni liste ekledikten sonra çıkan
"Birleştir / Sadece Bu Liste" prompt'u istenmedi. Otomatik birleştirme
hiç yapılmamalı; kullanıcı isterse Liste Yönetimi içinde manuel olarak
bir butonla birleştirme yapmalı.

Davranış değişikliği:

- `PlaylistsManagerController._saveAndReloadWithSummary()`:
  - `_maybeAskMergeChoice` çağrısı kaldırıldı; merge prompt diyaloğu
    artık asla açılmıyor.
  - Yerine `_enterSoloModeFor(newSlot)`: yeni 2./3./N. liste eklendiğinde
    diğer aktif slotlar **sessizce** devre dışı bırakılıyor. Toast
    `playlistsManager.toast.autoSolo` ile kullanıcıya "yalnızca @name
    aktif; birleştirmek için 'Listeleri Birleştir' butonunu kullan"
    bilgisi veriliyor.
- `PlaylistsManagerController.mergeAllSlots()` (yeni public method):
  - Tüm dolu (`!isEmpty`) slotları `setSlotDisabled(false)` ile
    aktifleştirir.
  - Anında toast `playlistsManager.toast.mergeDone` (X liste
    birleştirildi). Merge cache yenilemesi arka planda.
  - Edge case'ler: tek dolu slot → `mergeNothing` toast'u; zaten
    hepsi aktifse → `mergeAlreadyAll` toast'u (no-op).
- `PlaylistsManagerView`:
  - Header altına yeni `_MergeAllPlaylistsBar` widget'ı eklendi.
  - Sadece 2+ dolu slot varsa görünür.
  - **Etkin durum** (en az 1 disable slot var): primary renkli
    "Listeleri Birleştir (@n)" CTA + chevron, dokununca `mergeAllSlots()`.
  - **Devre dışı durum** (tüm dolu slotlar zaten aktif): "Tüm listeler
    birleştirildi (@n)" bilgi paneli, hint metni ile.

Kaldırılan kod:

- `lib/modules/settings/playlists_merge_choice_dialog.dart` (dosya
  tamamen silindi).
- Controller'dan `MergeChoiceDialog`/`MergeChoice` import'ı,
  `_maybeAskMergeChoice` method'u, `showDialog` import'u.

Yeni i18n anahtarları (TR/EN):

- `playlistsManager.merge.cta` — "Listeleri Birleştir (@n)" /
  "Merge Playlists (@n)"
- `playlistsManager.merge.cta.hint` — açıklayıcı alt metin
- `playlistsManager.merge.allActive` — "Tüm listeler birleştirildi (@n)"
- `playlistsManager.merge.allActive.hint` — açıklayıcı alt metin
- `playlistsManager.toast.autoSolo` — yeni liste ekleme sonrası bilgi
- `playlistsManager.toast.mergeDone` — birleştirme başarı toast'u
- `playlistsManager.toast.mergeNothing` — tek dolu slot uyarısı
- `playlistsManager.toast.mergeAlreadyAll` — zaten birleşik uyarısı

Eski (kullanılmayan) `playlistsManager.merge.prompt.*`,
`toast.mergeKept`, `toast.soloMode` anahtarları kod referansı
olmadığından sessizce orphan kalıyor; bir sonraki temizlikte
silinebilir.

## 2.10.43 (build 4175)

**2 Haziran 2026 — Liste yönetiminde anında geri bildirim & hızlı kapanma.**

Kullanıcı geri bildirimi:

1. 2./3. M3U listeyi ekleyip merge dialog'unda "Sadece Bu Liste"
   seçince ekran takılı kalıyordu — geri tuşuna basınca listeler
   ekranına dönüyor, liste yalnızca seçili görünüyordu.
2. Liste yönetiminde silme yaparken hiçbir geri bildirim yoktu —
   kullanıcı silinip silinmediğini anlayamıyordu.

Çözüm:

- `PlaylistsManagerController.clear()`:
  - Slot temizleme + slot listesi yenilenmesi sonrası **anında**
    `playlistsManager.toast.removedN` toast'u ile geri bildirim.
  - Merge cache yeniden hesaplaması (büyük listelerde uzun sürer)
    `unawaited(_reloadMergedCacheInBackground())` ile arka plana taşındı.
- `_maybeAskMergeChoice()` solo akışı:
  - `setSlotDisabled` + `reloadSlots` sonrası **anında**
    `playlistsManager.toast.soloMode` toast'u; merge reload arka planda.
  - Bu sayede `_SlotEditorSheet` çağıran `_submit()` hızlıca dönüyor ve
    `Navigator.pop()` ile sheet otomatik kapanıp kullanıcı listeler
    ekranına geri dönüyor (önceden uzun cache reload tamamlanana kadar
    bekliyordu).
- `toggleSlotDisabled()`:
  - Aktif/pasif geçişlerde de aynı paterne çevrildi; toast anında
    görünüyor, merge cache arka planda yenileniyor.
- `_SlotEditorSheet._confirmRemove()`:
  - Onay sonrası `playlistsManager.toast.removing` ile "Siliniyor…"
    progress toast'u — kullanıcıya işlem başladığı net bildirilir.
- `ToastService.show(force: true)`:
  - Anti-spam atlama parametresi; kullanıcı eylem toast'ları
    (silme/aktivasyon/devre dışı) aynı 2 sn pencerede tekrarlasa da
    her birinde ekrana gelir.

Yeni i18n anahtarları (TR/EN):

- `playlistsManager.toast.removedN` — "@n. liste silindi." /
  "Playlist @n deleted."
- `playlistsManager.toast.removing` — "@n. liste siliniyor…" /
  "Deleting playlist @n…"

## 2.10.42 (build 4174)

**2 Haziran 2026 — Canlı yayın kayıt özelliği tamamen kaldırıldı.**

Sebep: mpv `stream-record` ile BetterPlayer/ExoPlayer arka planında
sidecar mpv açma stratejisi çoğu IPTV sağlayıcısında (IP başına tek
bağlantı sınırı, auth gereksinimleri vb.) güvenilir çalışmıyordu;
kullanıcı için sürekli "tepki yok / dosya yok" senaryosu üretiyordu.
Bu nedenle özellik tamamen çıkarıldı, ileride daha sağlam bir
mimariyle yeniden ele alınacak.

Kaldırılanlar:

- `PlayerController` içindeki tüm kayıt API'leri: `toggleRecording`,
  `isRecording`, `isRecordingBusy`, `recordDuration`, `_startRecording`,
  `_stopRecording`, `_startRecordingSidecar`, `_verifyRecordingStarted`,
  `_teardownRecordingEngines`, `_prepareRecordingPath`, `_awaitFileFlush`,
  `_showRecordingSavedDialog`, `_showPlayerFeedback`, sidecar Player
  referansı.
- OSD butonları:
  - `tv_better_player_controls.dart` — yatay OSD'deki REC butonu
  - `tv_media_kit_player_controls.dart` — yatay OSD'deki REC butonu
  - `player_view.dart` — dikey OSD'deki REC butonu + video üzerindeki
    kırmızı pulse "REC HH:MM:SS" rozeti (`_PlayerRecordingIndicator`)
- `widgets/recording_saved_dialog.dart` widget'ı silindi.
- i18n key'leri (master TR+EN): `player.tooltip.record`,
  `player.tooltip.recordStop`, `player.recording.badge`,
  `player.toast.record*`, `player.record.*`.
- Partial locale dosyalarındaki tüm karşılıkları da silindi.

Korunanlar:

- `MediaStoreService` — film/dizi indirme akışında hâlâ kullanılıyor.
- `MainActivity.kt`'taki MethodChannel handler'ları indirme akışı için
  korundu (`saveVideoToGallery`, `openFile`, `openFolder`, `shareFile`).
- `FileProvider` + `file_paths.xml` indirme paylaşımı için kalıyor.

Build temizliği:

- `path_provider` import'u player_controller'dan kaldırıldı
  (kayıt dışında kullanılmıyordu).
- 4 multi-line string Dart escape'lerine dönüştürüldü
  (`locale_partials.dart` Ko bloğunda).
- 476 duplicate map entry temizlendi (translate_sync script artığı).

## 2.10.40 (build 4172)

**2 Haziran 2026 — Canlı kayıt sessiz başarısızlığı düzeltildi: mpv
`stream-record` set başarılı görünse de demuxer bağlanamadığında
(BetterPlayer arka planda sidecar mpv ile rakip bağlantı kuramazsa,
yayın auth/format gerektiriyorsa, IP başına tek bağlantı sınırı
varsa) dosya hiç yazılmıyordu — kullanıcı "Kayıt başladı" görüyor,
durdurunca da kırmızı "DOSYA BULUNAMADI" popup'ı çıkıyordu.**

Sorun analizi:

- mpv'nin `stream-record` property'si **sessizdir**: `setProperty`
  başarıyla döner ama demuxer akış paketi çekemezse muxer dosyayı hiç
  oluşturmaz. Hatayı kullanıcıya iletecek bir callback/exception yok.
- BetterPlayer/ExoPlayer canlı TV oynatırken kayıt için **sidecar mpv
  player** açıyoruz; aynı stream URL'si üzerinde paralel bağlantı
  kurmaya çalışıyor. Bazı IPTV sunucuları aynı kullanıcı/IP için ikinci
  bağlantıyı reddediyor → sidecar mpv'nin demuxer'ı asla
  bağlanmıyor → dosya hiç oluşmuyor.
- Sonuç: kullanıcı dakikalarca kayıt zannediyor, boşa zaman harcıyor.

Düzeltme — `PlayerController._startRecording` + `_verifyRecordingStarted`:

1. **Doğrulama**: `setProperty('stream-record', path)` (veya sidecar
   `open()`) çağrıldıktan sonra dosyanın gerçekten oluşmasını **3 sn
   içinde** bekleriz (`30 × 100ms` polling). Dosya >0 bayt olduğu an
   doğrulanmış sayılır.
2. **Erken iptal**: 3 sn içinde dosya görünmezse:
   - Aktif MediaKit oynatıcıda `stream-record`'u temizle.
   - Sidecar mpv player'ı varsa `stop()` + `dispose()` ile kapat.
   - `_startRecording` `false` döner.
3. **Kullanıcı geri bildirimi**:
   - Kayıt tuşuna basıldığında **"Kayıt başlatılıyor…"** toast'u
     (3 sn doğrulama sırasında sessiz kalmasın).
   - Başarısızsa **kırmızı toast**: *"Kayıt başlatılamadı — bu yayını
     mpv açamadı. Ayarlar > Oynatıcı > MediaKit (mpv) oynatıcısına
     geçip tekrar deneyin."*
   - Başarılıysa eski "Kayıt başladı" toast'u + REC timer.

Dialog iyileştirmesi — `RecordingSavedDialog`:

- Daha önce kayıt durdurulduktan sonra dialog hâlâ açılıyor ve "DOSYA
  BULUNAMADI" altında ham `path` gösteriyordu (kullanıcı için
  anlamsız). Artık bu durumda kullanıcı dostu hint gösterilir:
  *"mpv yayını kayıt için açamadı. Bu yayını kaydetmek için
  Ayarlar > Oynatıcı bölümünden MediaKit (mpv) oynatıcısına geçip
  tekrar deneyin."*
- Pratikte yeni doğrulama sayesinde bu dialog'a düşülmez —
  başarısızlık başlangıçta yakalanır. Yine de sidecar mpv başlayıp
  ortada düşerse (network çökmesi) hâlâ devreye girer.

Çeviriler (TR/EN, 15 partial dile sync edilecek):

- `player.toast.recordStarting` — "Kayıt başlatılıyor…"
- `player.toast.recordFailedDetail` — uzun, MediaKit önerisi
- `player.record.warnMissingHint` — dialog için MediaKit önerisi

`locale_partials.dart` temizliği:

- `xtream.error.invalidCredentialsWithMsg` (Zh) içinde literal
  newline → `\n` escape'e dönüştürüldü.
- Python iteratif dedupe script ile 437 satır duplicate kaldırıldı
  (Zh ve diğer partial diller).

## 2.10.39 (build 4171)

**2 Haziran 2026 — Liste ekleme UX: büyük M3U / Xtream listelerinde
"sonsuz bekleme" hissi giderildi. Parse biter bitmez kanal/film/dizi
sayıları popup'ta gösterilir, kullanıcı **Tamam**'a basıp uygulamayı
kullanmaya devam eder; merge cache yeniden kurulumu **arka planda**
çalışır.**

Sorun:

- Büyük bir M3U / Xtream listesi eklerken (kanal/film sayısı binlerce)
  dialog uzun süre "Yükleniyor…" durumunda kalıyordu; kullanıcı
  uygulamayı kullanamıyor, Tamam butonu hiç çıkmıyordu.
- Sebep: `_saveAndReloadWithSummary` önce yeni listeyi indirip parse
  ediyor (Adım 1 — sayılar burada belli oluyor), sonra **merge cache**
  yeniden kurulumunu da bekliyor (Adım 2 — büyük listelerde uzun
  sürebilen kısım). Dialog yalnızca Adım 2 sonunda "tamamlandı"
  oluyordu.

Düzeltme — `PlaylistsManagerController._saveAndReloadWithSummary`:

1. **Sayıları erken göster**: `loadAndPersist()` (download + parse)
   biter bitmez dialog hemen `PlaylistLoadProgress.done(...)` ile
   doldurulur. Kullanıcı kaç canlı/film/dizi yüklendiğini görür ve
   **Tamam**'a basabilir.
2. **Fire-and-forget merge**: `_reloadMergedCache()` artık `await`
   edilmiyor — `unawaited(_reloadMergedCacheInBackground())` ile
   arka planda devam eder.
3. **Reaktif UI**: settings → Liste Yönetimi sayfasında zaten
   `isReloadingMerged.value` reaktif gösterge var ("Yeniden
   yükleniyor…" spinner'ı); home view PlaylistCacheService
   güncellendiğinde otomatik yenilenir.
4. **Hata bildirimi**: arka plan merge başarısız olursa **kırmızı
   toast** çıkar ("Arka plan birleştirme başarısız oldu. Ana sayfadan
   aşağı çekerek yenileyin."). Başarı sessizdir (kullanıcı zaten
   Tamam'a basıp devam etti, ek toast spam'i yok).

Eş zamanlılık güvencesi:

- `_reloadMergedCache`'in mevcut `_reloadMergedInFlight` guard'ı
  korunuyor — aynı anda birden fazla `_saveAndReloadWithSummary`
  veya `_maybeAskMergeChoice` (solo seçimi) tetiklense bile merge
  tek seferde çalışır, ikinciler birinciyi bekler.

Çeviriler (TR/EN):

- `playlistsManager.toast.mergeBackgroundFailed` — "Arka plan
  birleştirme başarısız oldu…" / "Background merge failed…"
- 15 partial dile sync edilecek.

Kullanıcı akışı (yeni):

1. "Liste Ekle" → URL gir → **Yükleniyor** popup
2. Parse biter (genelde 1-3 sn) → popup'ta **"X kanal, Y film, Z dizi"**
3. Kullanıcı **Tamam** → ana ekrana döner (merge devam ediyor)
4. Home: küçük spinner ("Listeler yenileniyor…")
5. Merge biter → home otomatik yenilenir

## 2.10.38 (build 4170)

**2 Haziran 2026 — Kayıt: "Aç" butonu çalışmıyor / Galeri'de görünmüyor
sorununun diagnostik + uyumluluk düzeltmeleri. Dialog'a dosya
boyutu/varlık göstergesi (kayıt boş çıkmışsa kullanıcı görür), `video/*`
wildcard MIME ile çoklu intent fallback, "Klasör" butonu (Dosyalar
uygulamasını klasörde açar), mpv flush bekleme.**

Sorun:

- Kullanıcı kayıt yaptı → dialog "kaydedildi" diyor → "Aç" basınca
  hiçbir şey açılmıyor + Galeri'de hala görünmüyor.
- Olası kök nedenler: (a) MKV dosyası gerçekten yazılmamış / boş,
  (b) cihazda `video/x-matroska` MIME'ı işleyen app yok, (c) FileProvider
  intent açmıyor.

Düzeltmeler — `RecordingSavedDialog`:

1. **Disk boyutu göstergesi** (`_RecordingDiagnostics.read`):
   - Dialog'da renkli "DİSK BOYUTU: 12.4 MB" satırı (yeşil/turuncu/kırmızı)
   - **Dosya yoksa**: "DOSYA BULUNAMADI" (kırmızı)
   - **< 1 KB**: "UYARI — DOSYA BOŞ" (kırmızı; mpv muxer hatası)
   - **< 64 KB**: "UYARI — ÇOK KÜÇÜK DOSYA" (turuncu; HLS segment
     yetişmemiş, kullanıcı çok hızlı durdurmuş)
   - **OK**: yeşil
   - Kullanıcı kayıt boş çıkmışsa **anında görür**.

2. **"Aç" butonu çoklu MIME fallback** (`_handleOpen`):
   - Önce `video/*` wildcard ile dener (cihazların çoğunluğunda en
     yüksek uyumluluk).
   - Hâlâ açan app yoksa **Paylaş intent**'ine düşer (en azından
     WhatsApp/Drive/Files seçicisi açılır).
   - O da olmazsa toast: "Bu cihazda dosyayı açabilecek uygulama yok.
     VLC veya MX Player yükleyebilirsiniz."

3. **Yeni "Klasör" butonu** (`_handleOpenFolder`):
   - `MediaStoreService.openFolder` → Documents UI / Files app'i
     `Movies/MinaIPTV` (veya app-scoped `Recordings/`) klasöründe açar.
   - Kullanıcı kayıt dosyasını manuel görüp VLC ile açabilir.

Native (`MainActivity.kt`):

- **`openFile` çoklu MIME deneme**: cihazda `video/x-matroska` handler
  yoksa `video/*`, sonra `*/*` ile dener. `queryIntentActivities` ile
  her MIME için handler var mı kontrol eder, boşsa sonrakine geçer.
  Logcat'e hangi MIME ile başarılı olduğunu yazar.
- **`openFolder` action**: `content://com.android.externalstorage.documents/document/primary%3A<path>`
  URI ile `vnd.android.document/directory` MIME → DocumentsUI / Files
  açar. Fallback olarak `file://path` ile `resource/folder` MIME.
- **`saveVideoToGallery` verbose log**: kaynak boyutu 0 ise direkt
  null döner (boş MediaStore kaydı oluşturmaz). Yazılan byte sayısını
  da log'a basar.

Düzeltme — `PlayerController._stopRecording`:

- **mpv flush bekleme** (`_awaitFileFlush`): `setProperty('stream-record', '')`
  sonrası mpv muxer'ı kapatırken disk I/O senkron değil. Dosya boyutu
  100ms aralıkla 2 ölçümde aynı kalana kadar bekler (max 1.2s). Bu
  sayede MediaStore kopyası tam içerikle çalışır, dialog'daki boyut
  doğru okunur.

UI / i18n (TR/EN):

- `player.record.openFolder` — "Klasör" / "Folder"
- `player.record.warnEmpty` — "UYARI — DOSYA BOŞ"
- `player.record.warnSmall` — "UYARI — ÇOK KÜÇÜK DOSYA"
- `player.record.warnMissing` — "DOSYA BULUNAMADI"
- `player.record.sizeOk` — "DİSK BOYUTU"
- `player.record.openFailed` — "Bu cihazda dosyayı açabilecek uygulama yok…"
- `player.record.openFolderFailed` — "Klasör Dosyalar uygulamasında açılamadı"

Tanılama akışı:

- Dialog'da boyut **0B / "DOSYA BOŞ"** görüyorsanız → mpv MKV muxer
  source ile uyumsuz, formatı `.ts`'ye almamız gerekiyor. (Bunu
  rapor edin.)
- Boyut **OK ama "Aç" hala bir şey açmıyorsa** → cihazda video oynatıcı
  yok; VLC / MX Player kurulması gerekiyor (toast da bunu söyler).
- Boyut **OK ama Galeri görmüyorsa** → telefonun Galeri uygulaması
  MKV'yi yine de indekslemiyor; "Klasör" butonu ile manuel ulaşılır.

## 2.10.37 (build 4169)

**2 Haziran 2026 — Canlı yayın kaydı: galeri/Files'ta görünme sorunu
çözüldü. Kayıt formatı `.ts` → `.mkv` (çoğu Galeri uygulaması MPEG-TS'i
indekslemiyor; MKV ise Google Photos, Samsung Gallery, MIUI Gallery,
Google Files Videolar sekmesinde görünür). Dialog'a "Aç" butonu
(harici oynatıcıya doğrudan açılır) eklendi.**

Sorun:

- Kullanıcı yayın kaydetti → "Galeriye kaydedildi" mesajı çıktı
  → ancak Galeri uygulamasında ve Google Files'ın Videolar sekmesinde
  kayıt görünmüyordu.

Kök neden:

- Kayıt `.ts` (MPEG-TS) uzantısıyla yapılıyordu — bu format **streaming
  amaçlı** (Shoutcast / IPTV transport), Galeri uygulamalarının
  çoğunluğu (Google Photos, Samsung Gallery, MIUI Gallery, Google Files
  Videolar) bunu indekslemez.
- MediaStore'a doğru MIME (`video/mp2t`) ile insert yapılsa bile,
  Galeri tarafı dosyayı "video" sınıfına dahil etmiyordu.

Düzeltme:

1. **Kayıt formatı `.mkv`** (`PlayerController._prepareRecordingPath`):
   - mpv `stream-record` `.mkv` uzantısıyla otomatik Matroska
     muxer kullanır. **Hiçbir re-encode yok** — packetler olduğu gibi
     yazılır.
   - MKV her yaygın codec'i taşıyabilir (H.264/HEVC/MPEG-2 video,
     AAC/AC3/MP3/Opus audio).
   - MKV `video/x-matroska` MIME ile MediaStore.Video'ya insert →
     **Google Photos, Samsung Gallery, MIUI Gallery, Files apps
     indeksler ve oynatır**.

2. **Dialog'a "Aç" butonu** (`RecordingSavedDialog`):
   - Yeni `MediaStoreService.openFile` → native `Intent.ACTION_VIEW`
     + FileProvider content URI ile dosyayı sistem seçicisinde açar.
   - Kullanıcı VLC / MX Player / Samsung Video / Galeri vb. seçer.
   - 3 buton: **Aç** | **Paylaş** | **Tamam** (ikon + alt etiket
     layout'u → daha kompakt).

3. **MIME tipi otomatik tespit** (`_mimeFor`):
   - `.mkv` → `video/x-matroska`
   - `.mp4` → `video/mp4`
   - `.webm` → `video/webm`
   - `.ts` → `video/mp2t`

UI / i18n (TR/EN):

- `player.record.open` — "Aç" / "Open"
- (15 kısmi dile sync)

Native (`MainActivity.kt`):

- Yeni `MethodChannel mina.player/media_store` action: **`openFile`**
  → `Intent.ACTION_VIEW` + FileProvider URI + `FLAG_GRANT_READ_URI_PERMISSION`
  + `Intent.createChooser`.

Geriye dönük uyumluluk:

- Eski `.ts` kayıtları cihazda kalsa bile Galeri'de görünmeyebilir;
  kullanıcı bu kayıtları "Dosyalar" (Android Dosyalar) uygulamasından
  `Movies/MinaIPTV` altında bulabilir veya silebilir.
- Yeni kayıtlar `.mkv` olarak yazılır ve Galeri'de görünür.

## 2.10.36 (build 4168)

**2 Haziran 2026 — Film/dizi indirme: "0'da kalıp tekrar deneyin"
hatasının kökten çözümü. Otomatik engine fallback (direct↔mpv),
HTTPS↔HTTP scheme fallback, IPTV-uyumlu header'lar, gerçek hata
sebebini gösteren toast + tıklanabilir hata diyaloğu.**

Sorun:

- Kullanıcı film indir butonuna basıyor → progress 0%'de takılı kalıyor
  → birkaç saniye sonra "Tekrar Dene" butonu çıkıyor.
- Toast yalnızca "İndirme başarısız oldu" diyordu — gerçek neden gizli
  (401/403, scheme uyumsuzluğu, Icy-MetaData header reddi, vs.).

Düzeltme — `DownloadService._runDownload` + `_runDirect`:

1. **IPTV-uyumlu header'lar** (`IptvPlaybackDefaults.downloadHeadersForUrl`):
   - **`Icy-MetaData: 1` kaldırıldı** — bu Shoutcast/Icecast live audio
     için tasarlandı, bazı Xtream panelleri VOD isteklerinde reddediyor.
   - `Accept-Encoding: identity` — gzip kapalı, binary video akışında
     yararsız + Content-Length kafa karıştırıyor.
   - `Connection: keep-alive` — bağlantı yeniden kurmayı önler.
   - `Range: bytes=0-` — chunked transfer sorunlarını aşar, server
     206 Partial Content ile cevap verirse de OK.
   - `Referer` (host kökü) — Xtream panellerinin çoğu zorunlu kılar.

2. **Engine auto-fallback**: birincil engine (direct HTTP veya mpv)
   başarısız olursa **otomatik olarak diğer engine ile yeniden dener**.
   Direct HTTP → mpv `stream-record`'a düşer (mpv'nin daha sağlam HTTP
   stack'i, redirect / chunked / weird headers ile baş eder). mpv →
   direct HTTP'ye düşer (segmentli `.ts` dosyaları için bazen daha hızlı).

3. **HTTPS↔HTTP scheme fallback** (`_runDirectWithSchemeRace`): direct
   HTTP **ağ seviyesi** hatasıyla (DNS, TCP refused, TLS handshake)
   başarısız olursa, alternatif şema (HTTP↔HTTPS) ile yeniden dener.
   4xx/5xx server cevaplarında tekrar denenmez (server zaten cevap
   verdi, şema değişikliği yardımcı olmaz).

4. **Sıfır byte kontrolü**: indirme `complete` olsa bile diskte 1KB
   altı dosya varsa "sessiz başarısızlık" sayılır ve `failed` olarak
   işaretlenir (denenen engine'lerin listesiyle birlikte).

5. **Anlamlı hata mesajları** (`_humanizeError`):
   - `connectionTimeout` → "Sunucuya bağlanılamadı (zaman aşımı)."
   - `badResponse 401/403` → "Sunucu erişimi reddetti (HTTP 403) —
     lisans/oturum dolmuş olabilir."
   - `badResponse 404` → "Dosya sunucuda bulunamadı (HTTP 404)."
   - `badResponse 429` → "Sunucu istek limitini aştı — sonra
     tekrar deneyin."
   - `badResponse 5xx` → "Sunucu hatası (HTTP 500)."
   - `connectionError` → "Ağ bağlantısı kurulamadı (DNS / TCP)."
   - `badCertificate` → "Sunucu SSL sertifikası geçersiz."
   - `SocketException` → "Ağa erişilemedi (Wi-Fi / Mobil veri)."

UI (`DownloadButton`):

- Başarısız indirmeye basınca artık **sessizce retry tetiklemez** —
  önce **hata diyaloğu** açılır:
  - Başlık: "İndirme hatası" + kırmızı uyarı ikonu
  - Gövde: gerçek hata sebebi (server'dan gelen mesaj dahil)
  - "Hatayı Kopyala" — pano'ya kopyalar (destek almak için)
  - "Vazgeç" — diyaloğu kapatır
  - **"Yeniden Dene"** — fallback'leri yeniden tetikler

Toast (`DownloadService._runDownload`):

- Başarılı: "Avengers — indirildi" (film adıyla).
- Başarısız: "İndirme başarısız: Sunucu erişimi reddetti (HTTP 403)" —
  ilk 80 karakter toast'ta, tam metin diyalogda.

Çeviriler (TR/EN + 15 partial):

- `downloads.toast.completedNamed` — "@title — indirildi"
- `downloads.toast.failedWithReason` — "İndirme başarısız: @reason"
- `downloads.action.errorTitle` — "İndirme hatası"
- `downloads.action.errorBody` — açıklama + sebep
- `downloads.action.viewError` / `copyError` — diyalog butonları

## 2.10.35 (build 4167)

**2 Haziran 2026 — Canlı yayın kayıt feedback'i: toast yerine kalıcı
cam stilli dialog (kullanıcı Tamam'a basana kadar açık) + Android 10+
otomatik MediaStore kopyalama → kayıt dosyaları Galeri uygulamasında
görünür (Movies/MinaIPTV altında). Paylaş intent (WhatsApp, Drive,
Photos) butonu.**

Düzeltme — kayıt feedback'i (`PlayerController.toggleRecording`):

- Eski davranış: kayıt durdurulunca 3 sn toast → player overlay'i
  altında fark edilmiyordu, kullanıcı kaydın bitip bitmediğini
  bilmiyordu.
- Yeni davranış: `_showRecordingSavedDialog` ile kalıcı
  `RecordingSavedDialog` (`barrierDismissible: false`). Kullanıcı
  Tamam'a basana kadar açık kalır. İçerik:
  - Yeşil tikli "Kayıt tamamlandı" başlığı + süre rozeti
  - Dosya adı (`REC_xxx.ts`)
  - Galeri durumu — kopyalandıysa **"GALERİYE KAYDEDİLDİ:
    Movies/MinaIPTV/REC_xxx.ts"** (yeşil); yoksa orijinal app-scoped
    yol gri
  - "Paylaş" butonu — sistem paylaş menüsü (FileProvider)
  - "Tamam" butonu — diyaloğu kapatır

Yenilik — `MediaStoreService` (`lib/core/services/media_store_service.dart`):

- Yeni MethodChannel `mina.player/media_store`:
  - **`saveToGallery`** — Android 10+ (`MediaStore.Video` insert) ile
    dosyayı `Movies/MinaIPTV` altına kopyalar. `IS_PENDING` flag akışı
    ile atomik yazım. Mime type `video/mp2t` (TS) → modern Galeri
    uygulamaları (Google Photos, Samsung Gallery, MIUI Gallery)
    indeksler. Android 9 ve altı için MediaScanner fallback.
  - **`shareFile`** — `FileProvider` üzerinden `ACTION_SEND` intent;
    WhatsApp, Drive, Photos vb. uygulamalara paylaşım.
- Yeni `GetxService` (singleton, permanent: true) → `InitialBinding`'e
  kaydedildi.

Native değişiklikler (`MainActivity.kt`):

- `MediaStore.Video.Media.EXTERNAL_PRIMARY` koleksiyonuna insert +
  `ContentResolver.openOutputStream` ile 64 KB buffer'lı kopyalama.
- `RELATIVE_PATH = Movies/MinaIPTV` → kullanıcı Galeri'de doğrudan
  görür.
- Hata durumunda `IS_PENDING` kaydını siler (atomik).
- `FileProvider` ile `ACTION_SEND` intent (`FLAG_GRANT_READ_URI_PERMISSION`).

Manifest değişiklikleri (`AndroidManifest.xml`):

- `<provider androidx.core.content.FileProvider>` eklendi
  (`authorities=${applicationId}.fileprovider`).
- `res/xml/file_paths.xml` yeni dosya — `external-files-path`,
  `external-cache-path`, `cache-path`, `files-path` exposes.
- **Hiçbir yeni izin yok** — `WRITE_EXTERNAL_STORAGE` /
  `READ_MEDIA_VIDEO` gerekmez. Android 10+ scoped storage + Play
  policy uyumlu.

UI / i18n (TR/EN):

- `player.record.savedTitle` — "Kayıt tamamlandı"
- `player.record.savedDuration` — "Süre: @duration"
- `player.record.fileLabel` — "DOSYA ADI"
- `player.record.pathLabel` — "KAYDEDİLDİĞİ YER"
- `player.record.galleryLabel` — "GALERİYE KAYDEDİLDİ"
- `player.record.share` — "Paylaş"
- 15 kısmi dile sync edilecek (translate_sync.py)

Galeri görünürlüğü:

- `.ts` dosyaları doğrudan `video/mp2t` MIME tipiyle MediaStore'a
  yazılır. Modern Galeri uygulamaları (Photos, Samsung Gallery, MIUI
  Gallery, vb.) bunları indeksler ve oynatır.
- Galeri'de görünmüyorsa: kullanıcı "Paylaş" butonu ile herhangi bir
  video oynatıcısına gönderebilir; veya cihazın Dosyalar uygulamasından
  `Movies/MinaIPTV` altında bulabilir.

## 2.10.34 (build 4166)

**2 Haziran 2026 — Film ve dizi indirme özelliği. Detay ekranlarında
"İndir" butonu; arka planda hibrit indirme motoru (direct HTTP MP4 veya
libmpv stream-record HLS/DASH). Telefon hafızasına app-scoped storage
ile yazılır → Play Store izin sorunu yok. Çevrimdışı oynatma destekli.**

Yenilik — `DownloadService` (`lib/core/services/download_service.dart`):

- Singleton `GetxService`, `InitialBinding`'de `permanent: true` ile
  kayıt. SharedPreferences (`mina_downloads_index_v1`) JSON index.
- Eşzamanlı 2 aktif indirme; fazlası `queued` statüsünde bekler.
- **Hibrit engine seçimi**:
  - **Direct HTTP** (`directHttp`) → `.mp4`, `.mkv`, `.webm`, `.avi`,
    `.mov`, `.flv` URL'leri için `dio.download` + progress callback.
    Hızlı, gerçek byte progress'i (`received/total`).
  - **mpv stream-record** (`mpvRecord`) → `.m3u8` (HLS), `.mpd` (DASH),
    `rtmp:`, `rtsp:` için silent sidecar `Player` + `stream-record`
    property. Kayıt feature'ı ile aynı yaklaşım (`vid=no`, `ao=null`,
    `keep-open=no` ile EOF'ta otomatik kapanma). Header'lar
    (`User-Agent`, `Referer`) `IptvPlaybackDefaults` ile aktarılır.
- Storage: `getExternalStorageDirectory()/Downloads/{Filmler|Diziler/<Dizi>}/…`
  → Android 10+ scoped storage, **hiçbir izin gerekmez**, uninstall'da
  silinir, IPTV oynatıcımız doğrudan erişebilir.
- API:
  - `enqueueFilm(VodItem v)` — film indirme (id: `vod_$vodId`)
  - `enqueueEpisode(SeriesEpisodeOption opt, {SeriesItem series})` —
    bölüm (id: `ep_${seriesId}_${season}x${ep}`)
  - `cancel(id)`, `retry(id)`, `deleteItem(id)`
  - `findVod(id)` / `findEpisode(seriesId, season, ep)` — lookup
  - `localPathIfReady(id)` — diskte var mı kontrolü
  - `sortedByRecent` — UI listesi
- State: `RxMap<String, DownloadItem> items` + `RxMap progress` (anlık
  byte sayaçları); UI bunları `Obx` ile dinler.
- Uygulama kapanıp açıldığında "downloading" → "failed (interrupted)"
  olarak işaretlenir; kullanıcı tekrar başlatabilir.

Yenilik — `DownloadItem` (`lib/domain/entities/download_item.dart`):

- Enum'lar: `DownloadKind` (vod / episode), `DownloadStatus`
  (queued, downloading, completed, failed, cancelled),
  `DownloadEngine` (directHttp, mpvRecord).
- Tam JSON serileştirme/deserileştirme (SharedPrefs için).

Yenilik — `DownloadButton` widget
(`lib/modules/home/widgets/download_button.dart`):

- Reusable, tek widget; 4 reaktif durum: **idle** (download ikonu),
  **active** (dönen progress halkası + yüzde), **completed** (yeşil
  tik), **failed** (kırmızı yenile).
- `compact: true` ve `iconOnly: true` modları (episode kartlarında
  küçük varyant).
- Tıklama akışı: idle → `onStart()`; active → iptal onayı; completed
  → sil onayı; failed → `svc.retry()`.
- Cam stilli (`BackdropFilter` + tint border).

Entegrasyon noktaları:

- **Film detay** (`film_dizi_detail_view.dart`): play butonunun
  altına merkezde `DownloadButton(itemId: 'vod_${vod.id}')` eklendi.
- **Dizi bölüm kartı** (`film_dizi_series_detail_view.dart`):
  her `_EpisodeCard`'da play ikonunun altında compact + iconOnly
  `DownloadButton(itemId: 'ep_…')` eklendi; bölüm bazlı indirme.
- **Settings**: yeni "İndirilenler" tile'ı (`settings.downloads.title`)
  → `Get.toNamed(AppRoutes.downloads)`.

Yeni ekran — `DownloadsView`
(`lib/modules/downloads/downloads_view.dart`, route `/downloads`):

- Aktif (downloading + queued) ve tamamlanan + başarısız bölümleri
  ayrı section header'larla listelenir.
- Her satırda poster, başlık + subtitle (`S01E02 · Dizi Adı`),
  durum satırı (progress bar / yüzde / boyut / hata mesajı), sağ
  tarafta action button (iptal / yenile / sil).
- Tamamlanan bir öğeye dokununca `PlayerScreenArgs(channel: Channel(
  streamUrl: localPath))` ile player'a yönlendirilir → lokal dosya
  oynatımı.
- Empty state: dostane bilgi ekranı.

Player lokal dosya desteği
(`lib/core/player/better_player_iptv_config.dart`):

- `iptvBetterPlayerDataSource` artık URL'yi lokal dosya olarak
  algılarsa (`/storage/...` veya `file://...`)
  `BetterPlayerDataSource.file()` factory'sini kullanır.
- MediaKit zaten lokal path'leri (`Media(path)`) doğal olarak
  destekliyor; ekstra değişiklik gerekmedi.

i18n (TR/EN + 15 kısmi dile sync):

- `settings.downloads.{title,subtitle}` — settings tile
- `downloads.screen.title`, `downloads.section.{active,done}`
- `downloads.empty.{title,body}` — boş durum
- `downloads.action.{download,downloaded,retry}` — buton etiketleri
- `downloads.cancelTitle/Body/cancel`, `downloads.deleteTitle/Body/delete`
- `downloads.status.{queued,failed,cancelled}`
- `downloads.toast.{completed,failed}`
- `downloads.error.{fileMissing,interrupted}`

Play Store uyumluluğu:

- **AndroidManifest izinleri değişmedi** —
  `WRITE_EXTERNAL_STORAGE`, `MANAGE_EXTERNAL_STORAGE`,
  `READ_MEDIA_VIDEO` gerekmiyor.
- Dosyalar app-scoped external (`/Android/data/com.mina.iptv.../files/
  Downloads/`) → Android 10+ scoped storage politikasıyla uyumlu;
  Play Store policy review'da sorun çıkmaz.

## 2.10.33 (build 4165)

**2 Haziran 2026 — Google Play yayını için AAB (Android App Bundle)
paketi. İçerik 2.10.32 ile aynı (paralel HTTPS/HTTP şema race, liste
birleştirme onay diyaloğu, canlı TV slot prefix'i, kayıt, equalizer,
ses yükseltici, arama geçmişi); yalnızca build target ve versiyon
artırıldı.**

## 2.10.32 (build 4164)

**2 Haziran 2026 — M3U URL yüklemede paralel şema race: HTTPS + HTTP
aynı anda denenir, ilk başarılı body kazanır. Kullanıcı 30 sn TLS
handshake timeout'unu beklemiyor.**

Yenilik — `PlaylistRepositoryImpl._raceSchemes` (paralel şema yarışı):

- M3U URL yüklenirken (`loadFromM3uUrlResolved`) şema swap mümkünse
  (`http://` ↔ `https://`) iki istek **aynı anda** açılır:
  - Primary (kullanıcının yazdığı şema) → 8 sn fast-fail timeout
  - Swap (ters şema) → normal `BaseOptions` timeout (30/120 sn)
- İlk başarılı body kazanır (`Completer` race). Primary doğruysa anında
  döner; primary TLS/DNS hatası alırsa swap kazanır.
- Kullanıcı eskiden 30 sn connect timeout + 30 sn swap = **60 sn**
  bekliyordu. Şimdi worst-case 8 sn fast-fail → swap körlüğü; tipik
  yanlış şema senaryosunda **2-3 sn** içinde başarılı yüklenir.

Davranış değişiklikleri:

- `_isSchemeFallbackEligible` (eski eligibility filtresi) kaldırıldı.
  Race tüm hatalar için fallback yapar — sunucu 4xx/5xx döndüyse bile
  swap'tan gelecek body kabul edilir. İkisi de hata verirse **primary'nin
  hatası** fırlatılır (kullanıcı o URL'yi yazdı, daha anlamlı).
- Sonsuz döngü yok — toplam **2 deneme**. Üçüncü deneme yapılmaz.
- Tek şema mümkün (`ftp://`, `file://`, vs.) durumda race anlamsız;
  tek istek normal timeout ile gönderilir.

Etkilenen akışlar:

- Birincil liste editörü (`PlaylistController.submit`)
- Liste Yönetimi 2./3./N. slot ekleme (`PlaylistsManagerController.saveM3uUrl`)
- Splash sırasında merge tetikleme (`loadMergedPlaylist` → `_loadParsedForMerge`
  → `loadFromM3uUrl`)
- Manuel cache yenileme (Pull-to-refresh, ağ tabanlı yeniden yükleme)

## 2.10.31 (build 4163)

**2 Haziran 2026 — Liste Yönetimi: 2./3./N. liste eklerken "Listeleri
Birleştir?" onay diyaloğu + canlı TV kategori adlarında slot prefix'i
(`"Liste 1 (Spor Paketi) · Belgesel"`). Film ve diziler dokunulmadan tek
karışık liste olarak kalır.**

Yenilik — birleştirme onay diyaloğu (`MergeChoiceDialog`):

- Kullanıcı **boş bir slotu** ilk kez doldurduğunda (2./3./N. liste) ve
  toplam aktif slot sayısı 2+ olduğunda, summary popup'tan sonra cam
  stilli bir onay diyaloğu açılır.
- İki seçenek:
  - **Birleştir** (varsayılan, autofocus) → mevcut tüm aktif slotlar
    birleşik kalır; canlı TV kategori adlarında slot prefix uygulanır.
  - **Sadece bu liste** → yeni slot dışındaki tüm aktif slotlar
    `setSlotDisabled(true)` ile devre dışı bırakılır; merged cache
    yenilenir. Toast: `"Yalnızca @name aktif."`.
- Edit (dolu → dolu) akışında diyalog **gösterilmez** — kullanıcı
  zaten mevcut slotu güncelliyor, soru anlamsız.
- Dialog `useRootNavigator: true` ile root navigator üstünden açılır;
  arka plan tıklamasıyla kapanmaz (`barrierDismissible: false`).

Yenilik — canlı TV kategorilerinde slot prefix'i:

- `PlaylistRepositoryImpl.loadMergedPlaylist` artık opsiyonel
  `liveCategoryPrefixForSlot: String Function(int slot)?` callback'i
  alıyor. **Yalnızca** 2+ aktif slot olduğunda her slotun
  `channelCategories.name` değerleri `"$prefix · $originalName"`
  şeklinde öne ek alır (idempotent — aynı slot iki kez yüklense de
  duplicate prefix oluşmaz).
- Prefix formatı (`PlaylistsManagerController._liveCategoryPrefixForSlot`):
  - İsim varsa → `"Liste @n (@name)"` (`"Liste 2 (Spor Paketi)"`)
  - İsim yoksa → `"Liste @n"` (`"Liste 2"`)
- Slot bazında orphan kategori adı da aynı prefix'i kullanır → kategori
  ID eşi olmayan kanallar slot başlığına düşer.
- **VOD ve diziler bu callback'ten etkilenmez** — `_prefixChannelCategoryNames`
  yalnızca `channelCategories` listesini yeniden adlandırır; `vodCategories`
  ve `seriesCategories` dokunulmadan kalır (kullanıcı film ve dizilerde
  tek karışık liste görür).

Mimari — `mergePlaylistLayers` değişmedi:

- Prefix işi `loadMergedPlaylist` içinde, merge'den **önce** uygulanır
  (yardımcı `_prefixChannelCategoryNames`). Böylece mevcut merge
  algoritması ID offsetleme + orphan oluşturma davranışını korur ve
  geriye dönük uyumlu kalır.

i18n (TR/EN + 15 kısmi dil):

- `playlistsManager.live.prefix.plain` — `"Liste @n"` / `"List @n"`
- `playlistsManager.live.prefix.named` — `"Liste @n (@name)"` / `"List @n (@name)"`
- `playlistsManager.merge.prompt.{title,body,hint,merge,solo}` — onay
  diyaloğu metinleri (TR/EN); `translate_sync.py` ile 15 kısmi dile
  yansıtıldı.
- `playlistsManager.toast.{mergeKept,soloMode}` — kullanıcı kararı
  sonrası geri bildirim.

## 2.10.30 (build 4162)

**2 Haziran 2026 — Liste Yönetimi: klavye URL alanını kapatmıyor, pano URL
şeması (`http`/`https`) korunuyor, yeni liste eklerken 1. listedeki cam
summary popup (canlı kanal / film / dizi sayısı) görünüyor.**

Düzeltme — 2/3/4. liste editör sheet (klavye kaplama):

- `_SlotEditorSheet` artık `DraggableScrollableController` ile yönetiliyor.
  Initial sheet boyutu 0.65 → **0.85**'e çıkarıldı; herhangi bir
  `TextField` (isim, M3U URL, Xtream alanları) odaklandığında sheet
  otomatik olarak **0.95**'e (`animateTo` 220 ms easeOutCubic) genişler.
- Her `TextField`'a `scrollPadding: EdgeInsets.only(bottom: 280)`
  eklendi → odaklanan alan klavye üstüne kayar.
- Xtream sekmesinde 3 alan arasında `textInputAction.next` ile zincirli
  geçiş yapar; klavyenin "İleri" butonu her zaman görünür.

Düfzeltme — URL şema dönüşümü (`http://` → `https://`):

- **Birincil liste** (`PlaylistController`): `loadFromM3uUrlResolved`'dan
  dönen `resolvedUrl` şema swap olmuş olsa bile artık **disk'e
  yazılmaz**; persist edilen kaynak her zaman kullanıcının yazdığı /
  yapıştırdığı orijinal URL'dir (`source.url`). Sonraki açılışta yine
  aynı URL görünür; gerekirse şema swap fallback'i fetch sırasında
  internal olarak yine devreye girer.
- **İkincil liste** ve **Yönetilen listeler** (slot 2..N): aynı kural —
  pano `http://` ile geldiyse `http://` kalır.

Yeni — 2/3/4. liste yüklerken cam summary popup:

- `PlaylistsManagerController.saveM3uUrl` / `saveXtream` /
  `saveM3uFromFilePicker` çağrılarının üçü de **1. liste yüklemesinde
  kullanılan** `PlaylistLoadSummaryDialog` ile sarmalandı:
  - Üç satır (canlı kanal / film / dizi) `loading` spinner ile açılır.
  - Yükleme bitince **canlı kanal / film / dizi sayısı** sırayla (550 ms
    aralıkla) "✓ + sayı" rozetine döner.
  - Tamam butonu animasyon bitince odaklanır (TV cihazlarda otomatik).
- Hata olursa diyalog kırmızı bantla mesajı + ipucunu gösterir;
  birleştirilmiş cache yenilenemezse uygun uyarı çıkar.
- `verifyXtreamCredentialsOrThrow` çağrısı `loadFromXtream` ile
  değiştirildi — aynı uçları zaten çekiyordu, ek olarak `M3uResult`
  döndüğü için summary popup'a bant sayılarını veriyor.
- Yerel M3U dosyalarında `persistM3uLocalContentAt` zaten parse edip
  `M3uResult` döndürdüğü için sayılar oradan alınır.

## 2.10.29 (build 4161)

**2 Haziran 2026 — OSD kayıt özelliği libmpv `stream-record` ile gerçek
çalışır hâle geldi; ekranda her zaman görünür kırmızı REC pill + canlı
saniye/dakika sayacı.**

Düzeltme — Yayın Kaydet butonu:

- Eski `dio.download(streamUrl)` yaklaşımı HLS (`.m3u8`) ve DASH
  (`.mpd`) akışlarında sadece manifest text dosyasını indiriyordu — gerçek
  video kaydı olmuyordu. Yeni mimari **libmpv'nin `stream-record`**
  property'sini kullanır: demuxed TS paketleri doğrudan diske yazılır,
  HLS / DASH / RTMP / progressive HTTP / TS hepsi tek implementasyon ile
  çalışır.
- **MediaKit motoru aktifse:** mevcut `_mediaKitPlayer` üzerinde
  `stream-record=<path>` set edilir → ek bandwidth tüketimi yok.
- **BetterPlayer motoru aktifse:** arka planda video render olmayan
  (`vid=no`, `ao=null`) sessiz bir `Player` instance açılır; aynı URL'i
  paralel olarak çeker, IPTV User-Agent / Referer header'larını taşır,
  diske yazar.
- Dosya konumu: `<external app dir>/Recordings/REC_<kanal>_<ISO ts>.ts`.
  App-scoped external storage olduğundan **hiçbir runtime izin
  gerektirmez** — `MODIFY_AUDIO_SETTINGS` dışında Play Store için temiz.

Yeni — OSD üzerinde belirgin REC göstergesi:

- Yatay tam ekran, dikey mod ve TV'de aynı konumda (sol üst, safe area
  içeride) **kırmızı pill**: 8px beyaz nokta + `REC` rozeti + `MM:SS`
  (60 dk üstünde `HH:MM:SS`) sayacı. Pulse animasyonu ile dikkat çeker.
- Sayaç ekran döndürmeden ve OSD kapanmasından bağımsız çalışır;
  kullanıcı kaydın devam ettiğini her zaman görür.
- Kayıt butonu üstündeki küçük rozet de korunur — odak kullanıcısı
  için ek görsel ipucu.
- Toast mesajları yerel: "Kayıt başladı / Kayıt tamamlandı (01d 23sn):
  REC_Kanal_….ts / Kayıt başlatılamadı".

İç temizlik:

- Artık kullanılmayan `_dio` field ve `dio` import'u `player_controller`
  içinden kaldırıldı. `_recordCancelToken` ve eski indirme akışı tamamen
  yeni mpv tabanlı `_startRecording` / `_stopRecording` ile değiştirildi.
- Bilinmeyen kanal adlarındaki yasadışı dosya karakterleri (`\\/:*?"<>|`)
  `_` ile temizlenir; isim 60 karakterle sınırlanır.

## 2.10.28 (build 4160)

**2 Haziran 2026 — Ses Equalizer: BetterPlayer/ExoPlayer için Android native
köprü eklendi; OSD player'da EQ ikonu yok.**

Yeni — Ses Equalizer (motor kapsamı genişletildi):

- BetterPlayer (ExoPlayer) çıkışı için **Android native**
  `android.media.audiofx.Equalizer` köprüsü (`mina.player/equalizer`
  MethodChannel) eklendi. Manifest'e `MODIFY_AUDIO_SETTINGS` izni;
  `MainActivity.kt` tarafında `info` / `apply` / `release` çağrıları,
  `onDestroy()` temizliği.
- `EqualizerService` cihazın `numberOfBands`, `centerFreqMillihertz`,
  `bandLevelRange` bilgisini bir kez sorgular; 10 logical bandımızı (31 Hz
  … 16 kHz) cihazın N bantlı EQ'una **log-frekansta lineer
  interpolasyon** ile eşler. Preamp kazancı her bandın değerine eklenir
  (Android Equalizer ayrı preamp sunmaz).
- `revision` worker hem MediaKit (mpv `af=lavfi=[…]`) hem native köprüyü
  reaktif olarak günceller — preset seçimi, slider değişimi, enable
  toggle anında her iki motorda işler.
- Equalizer dialoğuna "Desteklenen motorlar" rozeti eklendi:
  - ✅ MediaKit (mpv) — tam destek
  - ✅ / ❌ BetterPlayer (ExoPlayer) — cihaza göre. Android 9+ bazı
    OEM'lerde session=0 effect kısıtı varsa kullanıcıya neden EQ'un
    BetterPlayer akışlarına uygulanmadığı açıklanır.
- iOS / macOS / Windows / Linux'ta BetterPlayer EQ köprüsü yok; dialog
  bunu "Bu platformda BetterPlayer için EQ köprüsü yok" şeklinde belirtir.

Doğrulama — OSD player:

- Player OSD'sinde (yatay & dikey, MediaKit & BetterPlayer kontrolleri)
  `graphic_eq` veya equalizer ikonu **yok** — equalizer yalnızca
  Ayarlar → Oynatma sekmesinden açılır.

## 2.10.27 (build 4159)

**1 Haziran 2026 — Film & Dizi TV/D-pad iyileştirmeleri, dizi panel
veri kaynağı düzeltildi, Ana Ekran Ayarları kart boyutu kumanda hatası
giderildi, kart boyutu varsayılanı %100'e çekildi.**

Yeni / iyileştirme — Film & Dizi (TV yatay):

- Hero banner yüksekliği 280 → 480dp tavan; başlık 20 → 30, "İzle/Detay"
  butonları 13 → 16dp + odak ölçeği 1.05 → 1.08 ile uzaktan rahat
  okunabilir hâle geldi.
- Sekme barı (Filmler / Arama / Diziler) TV'de 56dp yüksekliğe ve 17dp
  fonta çıktı; arama ikonu 56×56 dp.
- Kategori başlıkları 13 → 16dp, "Tümünü Gör" 14dp ve daha geniş tap
  target.
- Yatay liste sütun sayıları 4.5 → 4.5/5.5/6.5 (1280/1700 eşiklerine
  göre); "Tümünü Gör" gridi 5 → 5/6/7. 1920px TV'de poster artık doğru
  oranda görünüyor.
- İçerik genişliği 920 → 1600 dp tavanına çekildi, ekran yarısı boş
  kalmıyor; yatay padding 24 → 56 dp.
- `FocusTraversalGroup` kapsamı genişletildi → geri pill ↔ tab bar ↔
  hero ↔ kategoriler arasında ▲ ▼ doğal akıyor; `ensureVisibleOnFocus`
  ile odak posteri ekran ortasına çekiliyor.

Düzeltme — Dikey mod dizi paneli "Dizi bilgisi yüklenemedi":

- **Veri kaynağı genişletildi:** Panel artık detay sayfasıyla aynı yolu
  kullanıyor — Xtream `get_series_info` (özet, IMDb, tür, yıl, kapak)
  + `MovieService.getMovieWithFallback` (TMDB+OMDb, oyuncular, çeviri).
  Eski yalnızca `OmdbService.getMovieInfo` çağrısı boş dönen «Mahsun J
  EXXEN» benzeri Türkçe başlıklarda da artık dolu sonuç geliyor.
- **`playingSeriesInTape` artık daima geçiriliyor:** Detay sayfasından
  ve Film & Dizi hero "İzle" butonundan oynatınca dizi nesnesi de
  oynatıcıya iletiliyor; yerel özet/poster fallback'i devreye giriyor.
- **`_resolveSeriesForPanel`:** Browse/EPG yollarından gelen ve sadece
  `episodeBrowseTape` taşıyan açılışlar için, kanal adı/bölüm başlığı
  üzerinden playlist'teki dizi otomatik eşleştiriliyor.

Düzeltme — Ana Ekran Ayarları "Kart boyutu" (TV / D-pad):

- Material `Slider` TV'de odak alıp ▼ tuşunu değer değiştirme için
  yutuyordu; alt seçeneklere inilemiyordu.
- Slider `ExcludeFocus` ile odak ağacından çıkarıldı; tüm blok artık
  tek bir `TvDpadFocus` hedefi.
- TV haritası: ◀ ▶ boyutu küçült/büyüt (8 kademe %80–%120), ▲ ▼ önceki
  / sonraki ayar, OK bir kademe büyüt. Üst başlığa kısa kumanda ipucu
  metni eklendi (15 partial dile sync).

Sürüm dağıtımı:

- Telefon (release APK) ve Play Store (AAB) paketleri birlikte
  oluşturuldu.

Düzeltme — Kart boyutu varsayılanı:

- Yeni kurulumlar artık kartları **%100** boyutunda gösteriyor (eski
  varsayılan %95'ti). Eski varsayılana takılı kalmış (slider'a hiç
  dokunmamış) kullanıcılar da otomatik olarak %100'e taşınıyor;
  manuel olarak %95 dışında bir değer seçenler korunur.

## 2.10.26 (build 4157)

**1 Haziran 2026 — 2.10.25 düzeltme paketi telefon yayını.**

- 2.10.25'te yapılan dizi izleyicisi dikey panel yenilemesi ve Ebeveyn
  Denetimi TV/D-pad düzeltmelerinin telefon dağıtımı (release APK).

## 2.10.25 (build 4156)

**1 Haziran 2026 — Dizi izleyicisi dikey panel: "Dizi" + "Bölümler"
sekmeleri & Ebeveyn Denetimi TV/D-pad düzeltmeleri.**

Yeni özellikler:

- **Dikey mod dizi paneli yeniden tasarlandı:** Telefonda dizi izlerken OSD
  altındaki cam panel artık canlı TV kategorileri/EPG yerine *yalnızca* dizi
  bağlamına özel iki sekme gösterir:
  - **Dizi** — Poster, başlık, IMDb puanı, yıl/süre/tür rozetleri, özet,
    yönetmen ve oyuncu listesi. OmdbService.getMovieInfo(isSeries:true) ile
    arka planda doldurulur; veri gelene kadar başlık + poster ile iskelet
    görünür kalır.
  - **Bölümler** — Browse'tan açılan dizinin sezon/bölüm sıralı tüm
    bölümleri. Şu an oynayan bölüm "OYNATILIYOR" rozeti ile vurgulanır,
    diğer satırlara dokunmak `zapTo()` ile aynı oturumda bölüm değiştirir.
- **PlayerController.isSeries güçlendirildi:** Önceden yalnızca
  `seriesBrowseTape` veya `playingSeriesInTape` set edilmişse `true`
  dönüyordu. Artık `episodeBrowseTape != null` durumunda da `true` döner;
  yani Recommended Films bölümünden / dizi detayından açılışlarda da panel
  doğru moda girer.

Düzeltmeler — Ebeveyn Denetimi (TV / D-pad):

- **Sıfırla (Clear) düğmesi odaklanılabilir oldu:** Numpad sağ-alt "Sıfırla"
  hücresi daha önce gönder düğmesi ile aynı `FocusNode`'u paylaşıyordu;
  TV kumandası ile bu hücreye odak gelmiyordu. Ayrı `FocusNode` eklendi.
- **TV açılışında otomatik odak:** TV layout'unda PIN ekranı ilk açıldığında
  fokus numpad'in ortasındaki `5` tuşuna düşer. Kullanıcı dört yöne tek tuş
  ile gezinebilir; PIN sıfırlama akışından sonra da otomatik odak yeniden
  yerleştirilir.
- **Donanım rakam ve silme tuşları:** TV uzaktan kumandanın 0-9 sayı
  tuşları artık PIN alanına yazıyor; klavye `Backspace` siler, `Delete`
  tüm girişi temizler. Olaylar üst-seviye `KeyboardListener` ile yakalanır
  ve görsel düğmelerin ok/select etkileşimini bozmaz.
- **Şifremi unuttum bağlantısı:** AppBar'daki kilit-sıfırla ikonu TV ile
  zor erişiliyordu; PIN ekranında submit düğmesinin altına odaklanılabilir
  bir "Şifremi unuttum / Sıfırla" bağlantısı eklendi (yalnızca PIN giriş
  modunda). Submit'ten aşağı oka basınca buraya, yukarı oka basınca tekrar
  submit'e dönülür.
- **Submit düğmesi yön tuşları:** Submit'ten yukarı ok numpad'in alt
  satırında `0` tuşuna, sol ok backspace'e, sağ ok clear'a geçer; aşağı ok
  ise reset bağlantısı görünüyorsa oraya iner. Kullanıcı kumandayı tek
  yönde tutarak akışta kilitlenmez.

Notlar:

- EPG sekmesi dizi panelinden tamamen kaldırıldı; canlı TV paneli
  değişmedi (Kategoriler / Kanallar / EPG aynen kalıyor).

## 2.10.24 (build 4155)

**1 Haziran 2026 — Bakım: küçük ekran ana ekran header taşma düzeltmesi.**

Düzeltmeler:

- **Ana ekran üst cam şeridi (mobil):** Düşük dpi / dar ekranlarda
  (≤ 360dp) sol marka kapsülü ve sağ saat/ayarlar kapsülünün toplam
  intrinsic genişliği ekran genişliğini aştığında içerik kırpılıyordu.
  Artık her iki kapsül `Flexible` + `FittedBox(scaleDown)` ile
  sarılmıştır; gerekirse orantılı küçültülürler. Geniş ekranlarda
  görünüm aynen korunur.

## 2.10.23 (build 4154)

**1 Haziran 2026 — Bakım sürümü: EPG Kapat anahtarı, M3U liste isimleri,
TV ana ekranında Film & Dizi kartı, ana ekran ve film/dizi düzeltmeleri.**

Yeni özellikler:

- **EPG Kapat anahtarı (Ayarlar > EPG):** Tek dokunuşla EPG'yi tamamen
  devre dışı bırakır; ağ indirmeleri, disk önbelleği ve UI'da "şu an
  yayında" rozetleri durur. Tekrar açıldığında planlı yenileme akışı
  doğal şekilde geri döner.
- **M3U liste isimleri (Ayarlar > Liste Yönetimi):** Slot başına
  opsiyonel kullanıcı tanımlı etiket (örn. "Spor Paketi", "Yedek
  Liste"); kart başlığında öne çıkar, varsayılan başlık alt satıra
  iner. 64 karakter, 15 dilde i18n.
- **TV ana ekranı: Film & Dizi kartı:** TV'de Canlı TV / Filmler /
  Diziler'in arkasına yeni «Film & Dizi» kartı eklendi (mobil görünümün
  TV karşılığı). Mevcut TV kullanıcılarına bir kerelik migration ile
  zorla görünür yapılır; sonrasında kullanıcı kart düzenini istediği
  gibi yeniden ayarlayabilir.
- **TV ana ekranı varsayılan şeritleri:** Bir kerelik migration —
  yalnızca «Mina AI Senin için Önerilenler» ve «Sıradaki Maçlar»
  şeritleri açık; «En Çok Beğenilen Filmler» ve «Karışık Canlı TV»
  varsayılan kapalı. Ayarlardan istenildiğinde geri açılır.

İyileştirmeler:

- **Film & Dizi: Son İzlenenler fallback'i:** Kullanıcı henüz hiçbir
  film/dizi izlemediyse satır boş kalmıyor; playlist havuzundan stable
  seed ile karıştırılmış rastgele bir önizleme gösteriliyor. İlk gerçek
  izlemede liste otomatik gerçek veriye geçer.
- **Liste Yönetimi M3U URL korunması:** Kullanıcının yapıştırdığı
  http/https URL'i **olduğu gibi** persist edilir; otomatik şema
  dönüşümü yapılmaz. Bağlantı düzeyi şema swap fallback'i ağ tarafında
  korunur.
- Mevcut TV kullanıcılarda otomatik migration: kayıtlı kart düzenine
  «Film & Dizi» kartı `series`'in arkasına eklenir, gizli setten
  çıkarılır, Film & Dizi modu `classic` ise `both`'a çevrilir.

## 2.10.22 (build 4153)

**31 Mayıs 2026 — Toplu güncelleme: Akıllı Jenerik Atlatıcı, Veri
Kullanım Detayı, Spor Modu düzeltmeleri ve daha fazlası.**

Yeni özellikler:

- **Akıllı Jenerik Atlatıcı (Smart Stream Cutter):** Xtream
  dizilerinde 1./2. bölümde manuel ileri sardığın süreyi yerel
  olarak hafızaya alır; sonraki bölümlerde sağ alt köşede cam
  "Jeneriği Atla" butonu otomatik çıkar. Tek dokunuşla intro
  bitiş saniyesine atlar. Yalnız ilk 5 dakika içindeki 30+
  saniyelik ileri sarmalar öğrenilir (yanlış pozitif filtreleri).
  Oynatma Ayarları ve kurulum sihirbazı "Anahtarla Aç"
  bölümünden tek tıkla kapatılabilir.
- **Veri Kullanım Detayı sayfası (Ayarlar):** Uygulamanın bu
  cihazda kullandığı toplam **wifi** ve **mobil veri** trafiğini
  gösterir. Android `TrafficStats` ile 10 sn'de bir poll;
  bağlantı tipine göre ayrı sayaçlar. Toplam, indirme/yükleme
  detayı, oran çubuğu ve sıfırlama butonu.

İyileştirmeler:

- **Yüksek Puanlı Filmler şeridi:** Xtream sağlayıcısının
  `rating` alanı boş gelse bile artık "Senin İçin Önerilenler"
  ile aynı OMDb puan önbelleğini kullanıyor; arka planda
  enrichment ilerledikçe şerit kendiliğinden dolar.
- **Spor Modu (Beta) — Veri yükleme:** "Puan Durumu / Gol
  Krallığı / Asist Krallığı / Takımlar" sekmeleri çoğu ülkede boş
  geliyordu. `fetchTeamsForLeague`, `fetchPastFixturesForLeague`,
  `fetchNextFixturesForLeague`, `fetchTopScorers` ve
  `fetchTopAssists` artık 3 sezonluk fallback (`primary →
  primary-1 → primary-2`) zincirini deniyor. Auth/quota hataları
  yutulmuyor; doğru hata mesajları görünüyor.
- **Spor Modu — Turnuva chip'lerinde** (UCL/UEL/EURO/Dünya
  Kupası) Gol Krallığı ve Asist Krallığı sekmeleri de
  yükleniyor.
- **Spor Modu — Sezon etiketi:** Lig pill'inde bazen "2024/2025"
  gibi eski sezon yazıyordu. Etiket artık her zaman takvim
  sezonuyla hesaplanıyor; veri çekme tarafında da takvim
  sezonuyla maksimumlanıyor.

Düzeltmeler:

- **Kurulum sihirbazı "Anahtarla Aç" açıklamaları:** uzun TR
  açıklamaları artık `maxLines: 2 + ellipsis` ile yarıda
  kesilmiyor; satır sınırı kaldırıldı, kart yüksekliği metne
  göre dinamik artıyor. Alpha 0.62 ve line-height 1.30 ile
  okunabilirlik iyileştirildi.

## 2.10.21 (build 4152)

**31 Mayıs 2026 — Akıllı Jenerik Atlatıcı toggle + sihirbaz açıklama düzeltmesi.**

- Akıllı Jenerik Atlatıcı artık **Oynatma Ayarları → "Akıllı Jenerik
  Atlatıcı"** ve **kurulum sihirbazı → Anahtarla Aç** sekmesinden
  tek tıkla kapatılabilir. Varsayılan açık. Kapalıyken hem öğrenme
  (manuel seek kayıtları) hem de gösterme (sağ alt köşedeki cam buton)
  durur. Reactive: ayar değişince oynatıcıdaki overlay anında saklanır
  veya geri gelir.
- `AppSettingsService` yeni alan: `smartStreamCutterEnabled`
  (`mina_settings_smart_stream_cutter`). `setSmartStreamCutterEnabled(v)`
  setter'ı.
- **Kurulum sihirbazı "Anahtarla Aç" satırlarındaki uzun açıklamalar
  artık kesilmiyor.** Daha önce `subtitle` `maxLines: 2 + ellipsis`
  ile zorunlu iki satıra sıkıştırılıyordu; özellikle TR'de uzun
  açıklamalar yarıda kesiliyordu (örn. "+18 İçerikleri Gizle"). Yeni
  davranış:
  - Başlık ve alt-açıklama `softWrap: true` ile satır sınırı olmadan
    sarmalanır; metin uzunluğuna göre satır kart yüksekliği dinamik
    artar.
  - Alpha 0.58 → 0.62 yapıldı, satır yüksekliği 1.25 → 1.30 → metin
    daha okunaklı.
  - Düzen `CrossAxisAlignment.center` ile ikon ve switch dikey
    olarak metnin merkezinde kalır; uzun metinde de görsel hizalama
    bozulmaz.

## 2.10.20 (build 4151)

**31 Mayıs 2026 — Akıllı Jenerik Atlatıcı / Smart Stream Cutter (yeni özellik).**

IPTV Xtream akışlarında Netflix'in "Skip Intro" verisi yok. Bu sürüm,
kullanıcının ilk bölümlerdeki manuel ileri sarma davranışını yerel
olarak hafızaya alarak sonraki bölümlerde otomatik bir cam **Jeneriği
Atla** butonu çıkarıyor:

- Yeni servis `MinaStreamCutterService`
  (`lib/core/services/mina_stream_cutter_service.dart`):
  SharedPreferences anahtarı `mina_intro_skip_v1::<seriesId>`. Kabul
  kuralları:
  - Yalnız dizi içeriği (filmler ve canlı yayın hariç).
  - Yalnız 1. veya 2. bölüm seek'leri (yanlış öğrenmeyi engellemek için).
  - Seek başlangıcı ilk 5 dk (0–300 sn) içinde.
  - İleri seek delta'sı **30 sn** ile 600 sn arasında.
  - Hedef pozisyon 600 sn üstünde olamaz (intro değil son jenerik
    olduğunu varsayar).
- `PlayerController.seekTo` artık dahili olarak servisi besliyor;
  her bölüm değişiminde reactive `introSkipTargetSec` güncelleniyor.
- Yeni overlay widget `_SkipIntroPositioned` (`player_view.dart`):
  - Dizi içeriğinde 0 → introDuration aralığında sağ alt köşede cam
    "Jeneriği Atla" butonu çıkar.
  - `BackdropFilter` blur 12 + tema rengi glow + cam panel; "Mina
    Glass" tasarım dilimize uyumlu.
  - Tıklayınca `controller.skipIntroNow()` → introDuration saniyesine
    seek + buton 220 ms fade-out.
  - **Throttle:** Player position Rx değil; TV box / düşük donanımlı
    cihazlarda UI yorulmasın diye `Timer.periodic(1 sn)` ile saniyede
    bir kez state güncellenir.
- Yeni i18n anahtarı `player.skip_intro` (TR: "Jeneriği Atla", EN:
  "Skip Intro").
- Servis `InitialBinding`'de permanent kayıtlı; uygulama açılışında
  disk önbelleği yüklenir.

## 2.10.19 (build 4150)

**31 Mayıs 2026 — Veri Kullanım Detayı (yeni özellik).**

Ayarlar listesine yeni bir tile: **"Veri Kullanım Detayı"**. Sayfa,
uygulamanın bu cihazda kullandığı toplam **wifi** ve **mobil veri**
trafiğini analiz eder.

- Yeni servis `DataUsageService` (`lib/core/services/data_usage_service.dart`):
  Android `TrafficStats.getUidRxBytes(myUid)` / `getUidTxBytes(myUid)`
  üzerinden 10 saniyede bir poll yapar; delta'yı `connectivity_plus`
  ile algılanan mevcut bağlantıya (wifi/mobil/ethernet) ayırır,
  `SharedPreferences`'e lifetime sayaç olarak yazar.
- Cihaz yeniden başlatıldığında TrafficStats sayacı sıfırlanır →
  servis negatif delta'yı yakalayıp baseline'ı yeniden kurar; geçmiş
  sayım korunur.
- Yeni Android MethodChannel `mina.device/data_usage`. UID izleme
  desteklenmediği eski cihazlarda toplam (mobil + wifi) RX/TX değeri
  fallback olarak okunur.
- Yeni sayfa `/data-usage` (`DataUsageView`):
  - Üst kart: genel toplam (KB/MB/GB/TB), wifi/mobil oran çubuğu,
    sayım başlangıç tarihi.
  - İki kart yan yana: Wifi ve Mobil; her birinin **İndirilen / Gönderilen**
    detayı + aktif bağlantıyı vurgulayan rozet.
  - Bilgi notu + "Sıfırla" butonu (onay diyaloğuyla).
- Servis `InitialBinding`'de permanent kayıtlı; uygulama açıldığında
  init olur.
- 14 yeni i18n anahtarı (TR + EN) eklendi (`settings.dataUsage.*`).

## 2.10.18 (build 4149)

**31 Mayıs 2026 — Spor Modu sezon etiketi düzeltmesi.**

Lig pill etiketinde bazı liglerde "2024/2025" gibi eski sezon
yazıyordu. Sebep: API-Football lig bazında `current=true` bilgisini
geç güncelliyor, bazı liglerde önceki yıl "current" olarak işaretli
kalıyor. Çözüm:

- Lig pill etiketi artık her zaman **takvim sezonu**ndan üretiliyor
  (Avrupa futbolu Temmuz öncesi `Y-1`, sonrası `Y`). Mayıs 2026 için
  daima `2025/26` görünür.
- Veri çekerken kullanılan birincil sezon da takvim sezonuyla
  maksimumlandı; ligin API-Football'daki `currentSeason`'ı eski yılda
  kalsa bile birincil çağrı 2025 ile yapılıyor.
- 3 sezonlu fallback (`primary → primary-1 → primary-2`) hâlâ
  yedekte; gerçekten yeni sezon yayımlanmadıysa eski sezonun verisi
  geliyor.

## 2.10.17 (build 4148)

**31 Mayıs 2026 — Spor Modu (Beta) veri yükleme düzeltmesi.**

Çoğu ülke ligi için **Puan Durumu / Gol Krallığı / Asist Krallığı /
Takımlar** sekmeleri boş geliyordu. Sebep: API-Football'un
`current=true` ile döndürdüğü sezon bazı planlarda erişilebilir
değildi; yalnızca puan durumunda fallback varken takımlar ve maç
listelerinde fallback yoktu.

Yapılanlar:

- `fetchTeamsForLeague` artık `primary → primary-1 → primary-2`
  sezon zincirini deniyor. Yeni sezon henüz takım listesi yayımlamasa
  bile son geçerli sezonun takımları geliyor.
- `fetchPastFixturesForLeague` ve `fetchNextFixturesForLeague` aynı
  3 sezonlu fallback'e taşındı; "Yakın zamanda" / "Yaklaşan" sekmeleri
  artık eski sezonlarda da boş kalmıyor.
- `fetchTopScorers` ve `fetchTopAssists` 3. sezona kadar düşüyor;
  daha önce yalnız 2 sezon deneniyordu.
- Tüm fallback metotları `ApiFootballAuthRequired` / `QuotaExceeded`
  hatalarını yutmuyor — sadece geçici sezon hatalarını yakalıyor.
  Böylece yanlış key veya kota dolduğunda kullanıcıya doğru hata
  mesajı gösteriliyor.
- **Turnuva chip'lerinde** (UCL/UEL/EURO/Dünya Kupası vb.) Gol/Asist
  Krallığı yüklenmiyordu — `selectScope` artık turnuva durumunda da
  `_loadScorers` çağırıyor.

## 2.10.16 (build 4147)

**31 Mayıs 2026 — Yüksek puanlı filmler şeridi düzeltmesi.**

Ana ekrandaki **Yüksek Puanlı Filmler** şeridi, Xtream sağlayıcısının
`rating` alanını boş gönderdiği listelerde görünmüyordu. Şimdi şerit,
"Senin İçin Önerilenler" bölümüyle aynı OMDb puan önbelleğini
kullanıyor:

- `RecommendedFilmsRatingCache` artık reactive bir `revision` sayacına
  sahip; her yeni puan eklendiğinde / disk'ten yüklendiğinde
  `Obx` rebuild'i tetikliyor.
- `TopRatedFilmsStrip` doğrudan `effectiveRating()` kullanıyor;
  Xtream `rating` boş gelse bile OMDb cache'i (oturum + disk) doldukça
  filmler şeride sızıyor.
- Şerit ilk açıldığında 64 filme kadar OMDb enrichment'ı kendisi
  tetikliyor (önceden bu yalnızca Önerilenler bölümü görünürse
  oluyordu); artık özellik bağımsız çalışıyor.
- Şeridin günlük cache anahtarına `revision` da eklendi → cache
  güncellenince eski boş liste yapışıp kalmıyor.

## 2.10.15 (build 4146)

**31 Mayıs 2026 — Tüm dillerde eksik çevirilerin tamamlanması.**

15 kısmi dil için master İngilizce sözlükle eşitleme yapıldı; eksik
anahtarlar Google Translate üzerinden çevrildi ve `@param` GetX
placeholder'ları korundu. Sonuç: tüm 17 dil (TR + EN master + 15 kısmi
dil) **1110/1110** anahtarda hizalı.

Eklenen çeviri sayıları (yaklaşık):

| Dil | Eklendi |
|---|---|
| FR | 878 |
| AR | 885 |
| ZH | 883 |
| RU | 883 |
| KO | 1082 |
| HE | 1082 |
| DA | 1082 |
| SV | 1082 |
| HI | 1082 |
| TH | 1082 |
| IT | 1082 |
| PT | 1087 |
| ID | 1087 |
| ES | 633 |
| JA | 633 |

Toplam ~13.500 anahtar.

Ek bakım:

- `_tr`'de "concat string" formatında yazılan tek anahtar
  (`settings.epg.sourcePref.optXtream.desc`) tek satıra birleştirildi —
  parser artık doğru sayıyor.
- `locale_es.dart`'tan master'da artık olmayan 2 ölü anahtar
  (`settings.dialog.aboutFeatures`, `settings.dialog.changelogBody`)
  temizlendi.
- `translate_sync.py` v2: socket-level timeout (10 sn), exponential
  backoff retry (2/4/8 sn × 3), her 25 anahtarda checkpoint, verbose
  logging — uzun çeviri seansları artık donmuyor.

## 2.10.14 (build 4145)

**30 Mayıs 2026 — "Spor Modu Beta" etiketi + AAB paketi.**

Ana ekran kart adı **"Spor Modu" → "Spor Modu Beta"** olarak değiştirildi.
Özelliğin beta aşamasında olduğu kullanıcıya net olarak iletilmesi için
bu ibare hem ana ekran kartında hem kart düzeni editöründe görünür.

i18n güncellemeleri (`lib/core/i18n/app_translations.dart`):

* `home.sportsMode`:
  * TR: "Spor Modu" → "Spor Modu Beta"
  * EN: "Sports Mode" → "Sports Mode Beta"
* `homeCardOrder.card.sportsMode`:
  * TR: "Spor Modu" → "Spor Modu Beta"
  * EN: "Sports Mode" → "Sports Mode Beta"

Sayfa içi başlık (`sportsMode.title`) ve alt-sekme/etiket anahtarları
korundu — yalnızca ana ekran kartı işaretlendi.

Bu sürüm için Play Store yüklemesine uygun **App Bundle (.aab)** paketi
de üretildi (`build/app/outputs/bundle/release/app-release.aab`).

## 2.10.13 (build 4144)

**30 Mayıs 2026 — Spor kanalı filtresi + Film&Dizi modu cihaza özel
varsayılan.**

### 1) Canlı maç skor banner'ı yalnızca spor kanalında

Banner şimdiye dek "canlı (m3u live) ve film/dizi değil" eşiğine bağlıydı —
bu yüzden haber, eğlence, müzik vb. **tüm canlı kanallarda** görünüyordu.
Yeni filtre:

`lib/core/utils/sports_channel_detector.dart` — iki sinyali birlikte
kullanır:

* **Kanal adı**: `BeIN`, `S Sport`, `Tivibu Spor`, `Eurosport`, `DAZN`,
  `ESPN`, `Fox Sport`, `Sky Sport`, `TNT Sport`, `Viaplay Sport`,
  `Ziggo Sport`, `Mola TV`, `GS TV`, `FB TV`, `BJK TV`, `TS TV`,
  `Galatasaray`, `Fenerbahçe`, `Beşiktaş`, `Trabzonspor` ve `spor /
  sport / futbol / football / soccer` jenerikleri.
* **Kategori adı**: M3U grup başlığında `spor / sport / sports / futbol /
  football / soccer / maç / match / live games / fight / mma / ufc / box /
  wrestl / racing / formula / f1 / motogp / nba / nfl / mlb / nhl /
  tennis / golf / cricket / rugby`.

`player_view.dart` artık banner için `SportsChannelDetector.isSportsLiveChannel`
kullanır. Sonuç: haber/eğlence/çocuk kanallarında banner artık çizilmez;
yalnızca gerçek spor kanallarında görünür.

### 2) Orientation grace bug — spor filtresiyle birlikte doğal çözüm

Daha önce service-tabanlı grace deadline (v2.10.12) eklendi; orientation
değişiminde state korunuyor. Bu sürümde **spor filtresi** spor olmayan
kanallarda banner'ı tamamen elimine ettiği için "yatay'a dönünce 5sn sonra
kapanmıyor" semptomu pratikte çözüldü: spor olmayan kanallarda banner
zaten görünmez; spor kanalında grace timer doğru şekilde 5sn sonra
deadline'ı `null`'a düşürür ve Obx rebuild olur → banner kapanır.

### 3) Film & Dizi modu — cihaz tipine göre varsayılan

Eski varsayılan: `both` (hem "Film & Dizi" kartı hem ayrı "Filmler" /
"Diziler" kartları). Yeni varsayılan:

* **Mobil + Tablet** → `modern` (tek "Film & Dizi" kartı — Netflix tarzı).
* **TV** → `classic` (ayrı "Filmler" / "Diziler" kartları — kumandayla
  daha rahat gezinme).

`AppSettingsService._defaultHomeFilmDiziModeForLayout(layoutMode)` helper'ı
eklendi. `ensureLoaded()` storage'da kayıt yoksa cihaz tipine göre default
verir; `resetToDefaults()` da aynı mantıkla davranır. Kullanıcı manuel
seçim yaparsa o korunur.

Kurulum sihirbazından `_FilmDiziModePanel` (ve `_FilmDiziModeOption`,
`_FilmDiziModePreview`, `_PreviewCardSpec`) tamamen kaldırıldı —
kullanıcı kurulumu hızlandırmak için seçim yapmak zorunda değil.

## 2.10.12 (build 4143)

**30 Mayıs 2026 — Orientation'a dayanıklı canlı skor grace + Ayarlar
yeniden düzeni.**

### 1) Canlı maç skoru auto-hide (orientation bug)

Senaryo: Dikey modda OSD üzerindeki canlı maç skor şeridinde sürükleme
yapıp telefon **yatay moda** döndürüldüğünde, banner artık 5 saniye sonra
gizleneceği yerde **sonsuza kadar görünür kalıyordu**.

Kök neden: Grace period state'i (`_lastScrollInteractionAt`, `_scrollGraceTimer`)
her bir banner widget instance'ında ayrı tutuluyordu. Orientation değişince
portrait widget dispose oluyor, landscape widget ise grace state'i sıfır
mount ediliyor → service yeniden çağrılana kadar yatay banner ne zaman
kapanacağını bilemiyordu.

Çözüm: Grace state'i **`TheSportsDbLivescoreService`** içinde global olarak
tutuldu:

- `bannerScrollGraceUntil` (`Rxn<DateTime>`) → reactive deadline.
- `registerBannerScrollInteraction()` → deadline + timer set eder.
- `bannerInScrollGrace` getter → Obx içinde reactive okuma sağlar.
- Timer süre dolunca `bannerScrollGraceUntil.value = null` → Obx rebuild
  → banner kapanır.

`LiveScoresVisibilityGraceMixin` artık service'i wrapper olarak çağırır;
widget'lar arası state paylaşımı orientation değişiminden etkilenmez.

### 2) Ayarlar yeniden düzeni

Kullanıcı isteği üzerine 4 ayar **«Oynatma Ayarları»** alt-sayfasına
taşındı ve «Oynatma Ayarları» tile'ı **4. sıraya** çekildi:

Eski Ana Ayarlar (silindi):
- İçerikleri Yenile
- Yatay OSD Saydamlığı
- +18 İçerikleri Gizle
- Kanal Öneki

Yeni Ana Ayarlar sırası:
1. Oynatma Listesi
2. Kanal Kategori Düzeni
3. Ana Ekran Ayarları
4. **Oynatma Ayarları** (yeni 4. konum, sık erişim için)
5. EPG (Yayın Akışı)
6. Uyku Zamanlayıcı
7. Dil
8. Tema
9. Yedekleme / Geri Yükleme
... (geri kalan)

`_toggleHideAdultWithDialog` ve `_hasAnyAdultInLibrary` helper'ları
playback_settings_view.dart'a `toggleHideAdultWithDialog` top-level
fonksiyonu olarak taşındı; mevcut popup / debounce / fail-safe timeout
davranışı korundu.

## 2.10.11 (build 4142)

**30 Mayıs 2026 — Dikey modda beyaz perde sorununun gerçek kök nedeni.**

Logcat ile yapılan canlı diagnostikte beyaz perdenin gerçek sebebi şu hata
çıktı:

```
[Get] the improper use of a GetX has been detected.
You should only use GetX or Obx for the specific widget that will be updated.
```

`_LiveScoresBannerPositioned.build` ve `_PortraitLiveScoresStrip.build`
metodlarında `Obx(() { ... })` kapsamında **ilk satırlar reactive değişken
okumadan** erken `return SizedBox.shrink()` yapıyordu:

- `_LiveScoresBannerPositioned`: `MediaQuery.orientationOf(context) ==
  Orientation.portrait` ise reactive okuma yapılmadan dönüyordu.
- `_PortraitLiveScoresStrip`: `!widget.isLive` ise reactive okuma yapılmadan
  dönüyordu (`widget.isLive` constructor'dan gelen `bool`, reactive değil).

Bu, GetX'in `Obx`'i "improper use" olarak işaretlemesine ve render tree'de
exception oluşturmasına yol açıyordu (logcat: `Another exception was thrown:
Instance of 'DiagnosticsProperty<void>'`). Hata her player açılışında ve her
kanal değişiminde fırlıyor, dolayısıyla portrait modda OSD katmanı boyamada
tutarsızlık yaratıyordu (beyaz perde).

Düzeltme:

- `_LiveScoresBannerPositioned`: orientation kontrolü `Obx` dışına alındı.
- `_PortraitLiveScoresStrip`: `widget.isLive` kontrolü `Obx` dışına alındı.
- Obx içinde reactive okumalar (`channel.value`, `tvOsdVisible.value`) erken
  yapılır → koşulla çıkışlar artık dependency takibini bozmaz.

Ek temizlik:

- `_PortraitCategoryChannelBar`: `BackdropFilter` portrait moddan kaldırıldı
  (aynı leak nedeniyle), solid koyu zemin + tema gradient'i kullanılıyor.
- `import 'dart:ui'` artık gereksizdi, kaldırıldı.

Doğrulama: 30 sn'lik canlı logcat'te `improper use`, `DiagnosticsProperty`
ve `RxInterface.notifyChildren` hatalarının tamamı kaybolduğu doğrulandı.

## 2.7.0 (build 4123)

**29 Mayıs 2026 — Spor Modu: sabit ülke/turnuva kataloğu + Tümü modu.**

Üstteki tüm-dünya ülke chip listesi kaldırıldı. Yerine kullanıcının
isteğine göre **15 sabit kategori chip'i** geldi:

1. **Tümü** (varsayılan) → sayfa açılır açılmaz seçili. Tek "Maçlar"
   sekmesi; bugünün tüm canlı + yaklaşan + bitmiş futbol maçları
   listelenir, hangi ligden geldiği maç satırının altında küçük etiketle.
2. **10 ülke**: Türkiye, İngiltere, Almanya, Brezilya, Arjantin, Fransa,
   İspanya, İtalya, Rusya, Ukrayna. Seçilince mevcut ülke → lig
   chipleri → 3 sekme akışı.
3. **4 turnuva** (UEFA Şampiyonlar Ligi, UEFA Avrupa Ligi, UEFA Konferans
   Ligi, FIFA Dünya Kupası). Seçilince lig listesi gizli, doğrudan o
   liginin Maçlar/Puan Durumu/Takımlar sekmeleri dolar.

Teknik:

- `lib/modules/sports_mode/sports_mode_catalog.dart` — sabit ülke listesi
  (TheSportsDB API name + i18n key) ve UEFA/FIFA lig ID'leri
  (4480=UCL, 4481=UEL, 5071=UECL, 4429=FIFA WC). API ile doğrulanmış.
  Üç tipli `SportsScope` sealed class: `SportsScopeAll`,
  `SportsScopeCountry`, `SportsScopeTournament`.
- `lib/data/remote/the_sports_db_api.dart` — yeni `fetchEventsForDate()`
  metodu (`eventsday.php?d=YYYY-MM-DD&s=Soccer`); "Tümü" modu için.
- `lib/modules/sports_mode/sports_mode_controller.dart` — komple
  refactor: `scope` Rx + `selectScope()` ile sealed switch. "Tümü"
  modunda `_loadAllDay()` (5 dk cache); ülke modunda mevcut akış;
  turnuva modunda direkt `selectLeague()`. `showsLeagueChips` ve
  `showsThreeTabs` getter'ları view'in koşullu render'ı için.
- `lib/modules/sports_mode/sports_mode_view.dart`:
  - `_CountryChipRow` → `_TopScopeChipRow` (yatay: Tümü chip + 10 ülke +
    4 turnuva; aralarında ince dikey ayraçlar).
  - `_LeagueChipRow` artık `Obx` ile `showsLeagueChips`'e bağlı —
    Tümü/turnuva modunda yer kaplamaz.
  - `_TabBar` `showsThreeTabs`'e bağlı: Tümü modunda tek "Maçlar"
    butonu satırı doldurur.
  - Yeni `_AllDayMatchesTab` — canlı/yaklaşan/bitmiş üç gruplu;
    yaklaşan maçlar saate göre sıralı; her maç satırının altında lig
    adı küçük etiketle.
  - `_MatchRow` `showLeague` opsiyonel parametre kazandı.
  - `_PillChip` `leadingIcon` opsiyonel parametre kazandı (Tümü için
    `public_rounded`, turnuvalar için `emoji_events_rounded`).
- i18n: TR + EN için 16 yeni anahtar (`sportsMode.scope.all`,
  `sportsMode.country.{turkey..ukraine}`,
  `sportsMode.tournament.{ucl,uel,uecl,worldCup}`,
  `sportsMode.empty.allDay`).

## 2.6.1 (build 4122)

**29 Mayıs 2026 — OSD canlı skor şeridi: yaklaşan maç fallback + tolerans.**

Kullanıcı "canlı yayın açtığımda OSD üstünde canlı skorlar görünmüyor"
geri bildirimi: TheSportsDB free key `123` ile V1 `eventsday.php` endpoint'i
**sadece o anda sahada oynanan** maçları `1H/2H/HT` status'üyle döndürür;
gece saatlerinde ve maç yokken liste boş kalıyordu → banner hep gizleniyordu.

Düzeltmeler:

- `LiveScoreEvent.isInProgress` artık hem kısa kod (`NS`, `FT`, `1H`,
  `HT` …) hem uzun metin (`Not Started`, `Match Finished`, `In Play` …)
  için toleranslı. V1/V2 mixed response'ları yakalar.
- Yeni `LiveScoreEvent.isUpcoming` getter: bugün oynanacak ama henüz
  başlamamış maçları işaretler.
- Yeni `LiveScoreEvent.strTime` ve `startClock` — `HH:mm` saat rozeti
  için kullanılır.
- `live_scores_banner_overlay.dart` artık **iki mod** destekler:
  - **Canlı mod**: sahada oynanan maçlar varsa kırmızı `CANLI` rozeti +
    skor + dakika gösterilir.
  - **Yaklaşan mod** (canlı yoksa): bugünün en yakın **6 maçı** mavi
    saat rozeti (`HH:mm`) + `vs` ile gösterilir. Böylece kullanıcı OSD
    açtığında banner her zaman bilgi verir — gündüz/gece farketmez.
- Skor boş veya henüz başlamamışsa "0 – 0" yerine `vs` yazılır.
- `_SoftBadge` reusable component: dolu kırmızı CANLI veya yarı saydam
  saat/dakika rozeti.
- Debug log: her fetch sonrası `mina_iptv: thesportsdb fetched N events
  (inProgress=X, upcoming=Y) from <url>` ile `adb logcat` üzerinden API
  yanıtı tanılanabilir.
- `_LiveScoresBannerPositioned` bottom offset'i tüm layout'larda OSD'nin
  hemen üstüne otursun diye yeniden ayarlandı: portrait 152 dp, landscape
  & TV 140 dp.
- i18n: TR `liveScores.upcoming` → `Bugün`, EN → `Today`.

Hiç canlı + yaklaşan maç yoksa banner hâlâ tamamen gizlenir (UI temiz
kalır); ama TheSportsDB bugün için bir maç döndürdüğü sürece kullanıcı
banner'ı her zaman görür.

## 2.6.0 (build 4121)

**29 Mayıs 2026 — Karekod ile playlist yükleme (Telefon Kumanda).**

Playlist sayfasındaki M3U/Xtream formunun hemen altına yeni cam çerçeve
eklendi: **Karekod ile yükle**. Kullanıcı bu çerçeveye dokunduğunda
diyalog açılır; cihazın LAN IP'si + dinamik port ile bir karekod
gösterilir. Aynı Wi-Fi'daki telefon karekodu tarayıp açılan formdan
M3U URL veya Xtream bilgilerini gönderdiğinde TV listeyi anında alıp
yükler. Hiçbir bulut sunucusu / veritabanı kullanılmaz, veri
doğrudan LAN üzerinden cihazlar arasında akar.

Teknik:

- `lib/core/services/playlist_qr_server_service.dart` — `dart:io`
  `HttpServer` ile `InternetAddress.anyIPv4:0` üzerinde rastgele port
  açar. `network_info_plus` ile Wi-Fi IP'sini okur; başarısız olursa
  `NetworkInterface.list` fallback'i ile Ethernet IPv4 adresini bulur.
  GET `/` veya `/add_playlist` → mobil için optimize tek-dosya HTML form
  (M3U / Xtream sekmeleri, glass tasarım, dark mode). POST `/submit`
  JSON gövdeyi parse eder, `QrPlaylistSubmission` (sealed class) yayar.
  10 dakika auto-shutdown timer; idempotent `stop()` + `dispose()`.
- `lib/modules/playlist/widgets/playlist_qr_loader_dialog.dart` —
  diyalog widget'ı, `qr_flutter` ile QR render (220 px, level M, gapless).
  `_QrBlock` waiting indicator ile telefon beklenirken döner spinner;
  başarısız LAN'de `_ErrorBlock` retry butonuyla; URL pill kopyalama
  ikonuyla snackbar geri bildirimli.
- `lib/modules/playlist/playlist_controller.dart` — `applyQrSubmission()`
  metodu: sealed switch ile M3U/Xtream submission'a göre tab seçer,
  ilgili `TextEditingController`'lara yazar, `_updateSubmitState()`
  çağırır ve `unawaited(submit())` ile otomatik yüklemeyi başlatır.
- `lib/modules/playlist/playlist_view.dart` — `_QrLoaderCard` cam tile
  (44px daire + qr_code_2 ikonu + başlık/alt başlık + chevron) M3U/Xtream
  `_GlassCard`'ın hemen altına yerleşti; `PlaylistsManagerEntryCard`'dan
  önce gelir.
- `pubspec.yaml`: `qr_flutter: ^4.1.0`, `network_info_plus: ^7.0.0`.
- `android/app/src/main/AndroidManifest.xml`:
  `ACCESS_NETWORK_STATE` + `ACCESS_WIFI_STATE` izinleri eklendi
  (network_info_plus `getWifiIP` için gerekli).
- i18n: TR + EN master sözlüklere `playlist.qrEntry.title/body`,
  `playlist.qr.title/subtitle/waiting/hint/urlCopied/error.title/error.sub`,
  `common.retry` (toplam 10 yeni anahtar) eklendi.

Güvenlik & gizlilik:

- Sunucu sadece dialog açıkken yaşar; kapanırken `HttpServer.close(force: true)`
  ile zorla kapatılır, port serbest kalır.
- Veri **bulutta değil**, LAN üzerinden iki cihaz arasında akar. POST
  gövdesi 64 KB ile sınırlıdır (DoS koruması).
- Otomatik 10 dakika timeout — kullanıcı dialog'u açık unutsa bile RAM /
  port sızıntısı olmaz.
- Telefon `null/empty/0.0.0.0` IP durumunda diyalog `error.title` ile
  retry butonu sunar (mobil veride wifi yokken senaryosu).

## 2.5.0 (build 4120)

**29 Mayıs 2026 — Spor Modu (TheSportsDB entegrasyonu).**

Ana ekrana yeni `Spor Modu` kategori kartı eklendi. Bu kart açılana kadar
hiçbir HTTP isteği atılmaz (tam lazy). Sayfa açıldığında TheSportsDB v1 free
API (key `123`) üzerinden ülke listesi gelir, varsayılan olarak Türkiye
seçilir, Türkiye'nin tüm futbol ligleri otomatik fetch edilir ve ilk lig
(çoğunlukla Süper Lig) seçilir.

Sayfa içinde 3 sekme: **Maçlar / Puan Durumu / Takımlar**. Her sekme kendi
spinner'ından bağımsız çalışır; yükleme sırasında cam tasarıma uygun
yanıp sönme (pulsating) iskeletleri gösterilir.

Teknik:

- `lib/data/remote/the_sports_db_api.dart` — stateless API client.
  Endpoint'ler: `all_countries.php`, `search_all_leagues.php?c=&s=Soccer`,
  `lookuptable.php?l=&s=`, `lookup_all_teams.php?id=`,
  `eventsnextleague.php?id=`, `eventspastleague.php?id=`.
  10 sn timeout, `HttpClient` üzerinden. JSON modelleri: `SportsLeague`,
  `StandingsRow`, `SportsTeam`, `SportsEvent`.
- `lib/modules/sports_mode/sports_mode_controller.dart` — `GetxController`,
  lazy `onInit` ile ülke listesi çekilir; ülke seçilince lig listesi,
  lig seçilince 3 endpoint (`events`, `standings`, `teams`) **paralel**
  fetch edilir. Her seviye için yerel cache (`_leaguesCache`,
  `_standingsCache`, `_teamsCache`, `_eventsCache`).
- `lib/modules/sports_mode/sports_mode_binding.dart` — `Get.lazyPut` ile
  bind; sayfa açılmadıkça controller oluşturulmaz.
- `lib/modules/sports_mode/widgets/sports_skeleton.dart` —
  `SportsSkeletonPulse` 1.3 sn opacity 0.30→0.85 animasyon; her sekme için
  `SportsSkeletonMatchRow`, `SportsSkeletonStandingsRow`,
  `SportsSkeletonTeamTile`.
- `lib/modules/sports_mode/sports_mode_view.dart` — `ThemedSettingsBackground`
  üzerine: üst başlık (geri + lig sezonu rozeti) → yatay ülke chip listesi →
  yatay lig chip listesi → 3 sekmeli tab bar → tab içeriği. Maçlar sekmesi
  canlı/yaklaşan/son sonuçlar başlıklarıyla gruplanır; canlı maçlar
  kırmızı nokta + kapsül skor. Puan Durumu yarı saydam tablo (rank, takım,
  oynanan, averaj, puan). Takımlar 3 sütunlu grid. Tüm logolar
  `_CrestLogo` ile yüklenir (404'te harf placeholder).
- `lib/core/home/home_category_card_id.dart` — `sportsMode` enum değeri
  + `defaultOrder` sonuna eklendi; storage/label/icon
  (`Icons.sports_soccer_rounded`) entegrasyonu.
- `lib/modules/home/widgets/home_category_card_slot.dart` — `sportsMode`
  case'i `controller.openSportsMode` ile bağlandı; önizleme görseli ve
  itemCount boş bırakıldı (lazy).
- `lib/modules/home/home_controller.dart` — `openSportsMode()`.
- `lib/core/routes/app_routes.dart` + `app_pages.dart` — `sportsMode`
  route + `SportsModeBinding`.
- i18n: TR + EN master sözlüklere `home.sportsMode`,
  `home.sportsMode.subtitle`, `homeCardOrder.card.sportsMode`,
  `sportsMode.title/tab.matches/tab.standings/tab.teams/section.live/
  upcoming/recent/col.team/played/gd/points/empty.{countries,leagues,
  matches,standings,teams}` (toplam 19 yeni anahtar) eklendi.

Yan etkiler / lazy garantisi:

- Spor Modu kartı ana ekranda görünür ama `HomeCategoryCardSlot` tıklamadan
  önce TheSportsDB API'sini **çağırmaz**. `Get.lazyPut` controller'ı
  yalnız route açıldığında yaratır; route'tan çıkıldığında dispose olur ve
  bir sonraki açılışta cache yenilenir.
- Mevcut OSD `LiveScoresBannerOverlay` (TheSportsDB v1 `eventsday.php`)
  tamamen bağımsız çalışmaya devam eder; iki feature aynı API client
  sınıfını paylaşmaz, çakışmaz.

## 2.1.9 (build 4109)

**27 Mayıs 2026 — Film & Dizi modu (Modern / Klasik / Her İkisi).**

Kullanıcı kurulum sihirbazında ve sonradan Ayarlar > Ana Ekran Ayarları içinden ana ekran Film & Dizi kart kompozisyonunu seçebilir:

- **Modern**: tek bir «Film & Dizi» (recommendedFilms) kartı görünür; ayrı «Filmler» / «Diziler» kartları gizlenir.
- **Klasik**: ayrı «Filmler» + «Diziler» kartları görünür; «Film & Dizi» kartı gizlenir.
- **Her İkisi (varsayılan)**: hepsi birden görünür (geriye dönük uyumluluk).

Teknik:

- `HomeFilmDiziMode` enum (`modern/classic/both`) + storage key, label key, subtitle key — `home_category_card_id.dart`.
- `HomeCategoryCardId.visibleForFilmDiziMode` + `orderForLayout(... , filmDiziMode: ...)` — kart sırası filtrelemesi.
- `AppSettingsService.homeFilmDiziMode: Rx<HomeFilmDiziMode>` + `_kHomeFilmDiziMode` SharedPreferences + `setHomeFilmDiziMode()` + `resetToDefaults` sıfırlama.
- `home_view.dart` `_homeCategoryCardsForLayout` her çağrıda `app.homeFilmDiziMode.value`'yu okur; üst Obx mevcut olduğu için reaktif yenilenir.
- `setup_wizard_view.dart` yeni `_FilmDiziModePanel` cam panel; 3 modlu radio listesi + canlı mini önizleme kartları (`_FilmDiziModeOption` + `_FilmDiziModePreview`).
- `home_settings_view.dart` aynı yapı `_FilmDiziModeSection` olarak; Kart sırası ve Kart boyutu sectionlarının ardına yerleşti.
- i18n: TR + EN master sözlüklere `setup.filmDiziMode.title/sub`, `homeSettings.filmDiziMode.title/sub`, `homeSettings.filmDiziMode.{modern,classic,both}.{title,sub}` (toplam 12 anahtar) eklendi.

## 2.1.8 (build 4108)

**27 Mayıs 2026 — Ana ekran kart boyutu kontrol ayarı.**

Ayarlar > Ana Ekran Ayarları içine yeni **«Kart boyutu»** slider'ı eklendi. Tek bir global ölçek (0.80 – 1.20, default 1.00, %5 adımlarla) tüm ana ekran kartlarını ve şeritlerini reaktif olarak küçültür/büyütür.

- `AppSettingsService.homeCardScale: RxDouble(1.0)` + `homeCardScaleMin/Max` sabitleri + `_kHomeCardScale` SharedPreferences anahtarı + `setHomeCardScale()` setter (clamp + persist).
- **Kategori kartları** (Canlı/Film/Dizi/Tekrar/Favori/Film&Dizi): `home_view.dart` landscape `cardWidth *= 0.85 * scale`, portrait `cardW = maxWidth * 0.6375 * scale`. Mevcut Obx zaten bu değeri okuyacak şekilde güncellendi.
- **Continue Watching strip**: kart `width/height` ve strip `SizedBox.height` `* scale`; `_cardScaleListener: Worker` ile setState.
- **AI Recommendations strip**: aynı pattern, scale Worker ile setState.
- **Top Rated Films strip**: aynı pattern + initState'te Worker, dispose'da temizleme.
- **Mixed Live TV chip** (`HomeGlassStripChip`): `minWidth/maxWidth/padding` `* scale`. Obx zaten reaktif.
- `home_settings_view.dart`: yeni `_CardScaleSection` widget — başlık + alt yazı + `%XX` yüzde rozeti + Material `Slider` (8 division) + Küçük/Standart/Büyük etiketleri + animasyonlu mini 3 kartlık önizleme.
- i18n: TR + EN master sözlüğe `homeSettings.cardScale.title/sub/small/standard/large` eklendi.
- `resetToDefaults()` artık `homeCardScale = 1.0` da sıfırlıyor.

## 2.1.7 (build 4107)

**27 Mayıs 2026 — Film & Dizi detay pill'leri tek satırda sıralı.**

Film/Dizi detay sayfasındaki teknik (SD, H.264, Dolby Digital, Stereo) ve tür (Action, Horror...) pill'leri eski `Wrap` ile çoklu satıra dağılıyor, en son pill kendi başına alta düşüp dağınık görünüyordu.

- `film_dizi_detail_view.dart` `_PillWrap`: `Wrap` → `SizedBox(height: 30) + ListView.separated(scrollDirection: Axis.horizontal)`.
- `film_dizi_series_detail_view.dart` `_PillWrap`: aynı dönüşüm (height: 28, pill padding biraz daha sıkı).
- Pill'ler artık her zaman tek hizada, soldan başlayıp sağa doğru sıralanır. Ekran genişliğine sığmazsa yatay olarak yumuşak kaydırılabilir.
- Pill stilleri (renk, border, font) korundu — yalnızca dizilim Wrap'ten Row'a alındı.

## 2.1.6 (build 4106)

**27 Mayıs 2026 — Ana ekran kategori kartları %15 küçültüldü.**

Canlı Yayınlar, Film & Dizi, Filmler, Diziler, Tekrar & EPG Mix ve Favori kartlarının lineer boyutları (en + boy) %15 azaltıldı. Aspect oranı (0.85 yatay / 1.15 dikey) korundu — yalnızca kart küçüldü, etrafındaki boşluk doğal olarak büyüdü.

- `home_view.dart` (landscape): `cardWidth = baseCardWidth * 0.85`, `cardHeight = cardWidth * 0.85` (aynı oran).
- `home_view.dart` (`_PortraitHomeCarouselState`): `cardW = maxWidth * 0.75` → `* 0.6375` (=0.75 * 0.85). PageView `viewportFraction: 0.83` aynı kaldığı için sayfa boşlukları yumuşak artar.
- Kart içerikleri (`GlassCategoryCard`) `double.infinity` ile büyüdüğü için padding/ikon/yazı boyutu otomatik kart boyutuyla orantılı görünür — ek bir tema değişikliği gerekmedi.

## 2.1.5 (build 4105)

**27 Mayıs 2026 — Film & Dizi hero "İzle" / "Detay" butonları ayrıldı.**

Hero banner widget'ı `onPlay` ve `onDetail` callback'lerini zaten ayrı tutuyordu ama besleyici taraf (`_FilmsBody._heroSlides` ve `_SeriesBody._heroSlides`) ikisini de aynı detay fonksiyonuna bağlıyordu. Kullanıcı "İzle"ye basınca da detay sayfası açılıyordu.

- **Film hero "İzle"** → yeni `_playFilmDirect(VodItem v)`: VOD doğrudan `AppRoutes.player`'a açılır; `movieBrowseTape` `data.vod` üzerinden Channel listesine map edilir (player'da yatay gezinti).
- **Film hero "Detay"** → mevcut `_openFilmDetail` (film detay sayfası).
- **Dizi hero "İzle"** → yeni `_playSeriesFirstEpisodeDirect(SeriesItem s)`: bölüm listesi `SeriesEpisodeLoader.load(...)` ile çekilir, glass loading dialog (`_SeriesPlayLoadingDialog`) yumuşak feedback verir, sonra ilk bölüm `AppRoutes.player`'a yönlenir. Bölüm yoksa veya hata olursa otomatik detay sayfasına düşer.
- **Dizi hero "Detay"** → mevcut `_openSeries` (dizi detay sayfası).
- Kart tıklamaları (yatay kategori şeritleri) eski davranışta kalır: filmde detay sayfası, dizide detay sayfası.
- i18n: `filmDizi.series.startingFirstEpisode` (TR + EN) eklendi.

## 2.1.4 (build 4104)

**27 Mayıs 2026 — Ayarlar > "Liste Yönetimi" tile'ı kaldırıldı.**

Aynı navigasyon zaten Ayarlar > Playlist akışındaki `PlaylistView` içindeki `_PlaylistsManagerEntryCard` üzerinden mevcut; iki noktadan da aynı sayfaya gitmek gereksiz tekrar.

- `settings_view.dart`: `_GlassTile` (queue_play_next_rounded) bloğu kaldırıldı.
- `settings_controller.dart`: `openPlaylistsManager()` helper'ı temizlendi (artık çağıran kalmadı).
- `app_translations.dart`: `settings.tile.playlistsManager` ve `.sub` anahtarları (TR + EN) çıkarıldı; geriye not bırakıldı.
- `AppRoutes.playlistsManager` ve `PlaylistsManagerBinding` aktif kalıyor — `PlaylistView` entry card'ı bu rotayı kullanıyor.

## 2.1.3 (build 4103)

**27 Mayıs 2026 — M3U URL → Xtream dönüşümü her zaman denenir.**

Önceki sürümde `M3uXtreamSniffer`, `type=m3u_plus` / `type=adv_m3u_icon` gibi açık M3U export parametrelerinde sniffi atlıyordu. Bu, EPG/VOD/Series uçlarına erişimi olan panellerde Xtream entegrasyonunu gereksiz şekilde kapatıyordu.

- Sniffer artık `username` + `password` query'si bulduğu her URL için Xtream'i deniyor (eski davranış geri geldi).
- `PlaylistController.submit` ve `PlaylistsManagerController.saveM3uUrl` `loadFromXtream` exception fırlatırsa ham M3U URL'sine sessiz fallback yapıyor (2.1.2'de eklenen güvenlik ağı korundu).
- Sonuç: panel Xtream API'yi destekliyorsa kullanıcı M3U URL'i yazsa bile Xtream entegrasyonu çalışır; desteklemiyorsa otomatik M3U yükleme.

## 2.1.2 (build 4102)

**27 Mayıs 2026 — M3U URL submit'inde "URL'yi düzelt" yanılsaması.**

Bazı paneller `get.php?...&type=adv_m3u_icon&output=ts` gibi açık M3U export URL'i veriyor ama `player_api.php` ucunu kapatıyor veya çok yavaş cevap veriyor. `M3uXtreamSniffer` kullanıcının URL'sinde `username/password` query'sini görüp Xtream'e çeviriyor, sonra Xtream API timeout/error olunca submit fail oluyor ve kullanıcı "URL'yi Düzelt" diyalogu görüyor. Çift katmanlı düzeltme:

- **Sniffer**: `type=` query'si `m3u` içeriyorsa (`type=m3u_plus`, `type=adv_m3u_icon`, `type=m3u`, `type=adv_m3u`) sniff `null` döner. Kullanıcı zaten M3U export istemiş — Xtream'e çevirme.
- **PlaylistController.submit**: Sniff yine de Xtream'e dönerse ve `loadFromXtream` exception fırlatırsa **sessiz fallback** olarak ham M3U URL'sine düşülür (`_repo.loadFromM3uUrl(source.url)`). Aynı strateji secondary M3U akışında ve `PlaylistsManagerController.saveM3uUrl`'de de uygulandı.
- Sonuç: Kullanıcı M3U sekmesinden URL gönderir, sunucu Xtream API'ye cevap vermezse otomatik olarak M3U indirilir; "URL'yi Düzelt" diyalogu yalnızca **gerçek** ağ/SSL/format hatalarında çıkar.

## 2.1.1 (build 4101)

**27 Mayıs 2026 — kurulum sihirbazına +18 toggle.**

Kullanıcı isteği üzerine kurulum sihirbazındaki "anahtarla aç" iOS-tarzı `CupertinoSwitch` listesine **+18 İçerikleri Gizle** satırı eklendi. AI Önerilenler satırından hemen sonra konumlandı çünkü filtre tam olarak o strip'leri (Continue Watching / AI Önerilenler / Karışık Canlı) etkiliyor.

- `Icons.shield_outlined` ikon + "+18 İçerikleri Gizle" başlık + "Ana ekran önerilerinde, karışık canlı şeridinde ve izlemeye devam et bölümünde +18 kanal, film ve dizileri gösterme" alt satırı.
- Değer `AppSettingsService.hideAdultContentEnabled.value`, setter `setHideAdultContentEnabled`. Toggle değiştiğinde `xtreamHideRevision` otomatik artar; downstream Worker'lar Ana Ekran şeritlerini reaktif olarak yeniden hesaplar.
- TR + EN master sözlüklere `setup.hideAdultTitle` ve `setup.hideAdultSub` anahtarları eklendi; 15 kısmi dil İngilizce fallback üzerinden çalışır.
- TV kurulum sayfasında (`setup_wizard_tv_view.dart`) "anahtarla aç" listesi yok — yalnızca handheld/portrait flow'a eklendi.

## 2.1.0 (build 4100)

**27 Mayıs 2026 — Kurulum ekranı sadeleştirme.**

### 🗂️ Playlist Kurulum → "İkinci kaynak" kalktı, "Liste Yönetimi" geldi

Eski tasarımda kurulum sayfası iki büyük cam kart gösteriyordu: birincil kaynak formu + ikinci kaynak için "Aktif" toggle'lı, M3U/Xtream sekmeli mini-form. Bu yapı kullanıcıyı en fazla 2 listeyle sınırlıyordu.

- **"İkinci kaynak" cam kartı tamamen kaldırıldı** (`playlist.secondaryTitle`/`secondarySubtitle`/`secondaryEnable` blok'u; ~85 satır).
- Yerine **tek bir cam tile**: `_PlaylistsManagerEntryCard` — `Icons.queue_play_next_rounded` rozet + "Liste Yönetimi" başlık + "İstediğin kadar ek liste …" alt başlığı + `chevron_right_rounded`. Tek dokunuşla `AppRoutes.playlistsManager` sayfasına gider; orada slot 1'den 32'ye kadar tüm listeler yönetiliyor (kullanıcı önceki sürümlerde eklenen dinamik yapıdan yararlanır).
- Birincil kaynak formu yerinde — kurulum sihirbazı akışı bozulmadı.

### 🧹 Kod temizliği

Eski form artık kullanılmadığı için bunlar silindi:
- `_M3uSecondaryTab` (195 satır) ve `_XtreamSecondaryTab` (199 satır) widget sınıfları
- 11 adet `_secondary*Focus` FocusNode (`_secondaryM3uTabFocus`, `_secondaryXtreamTabFocus`, `_secondaryM3uUrlFocus`, `_secondaryM3uFilePickFocus`, `_secondaryXtreamServerFocus`, `_secondaryXtreamUserFocus`, `_secondaryXtreamPassFocus`, `_secondarySubmitFocus`, `_secondaryEnableFocus`)
- 6 adet TV kumanda `onKeyEvent` handler'ı (yukarı/aşağı navigasyon)
- 8 adet `_bindTvKeyboardAutoOpen(_secondary*)` çağrısı
- 4 adet controller binding'i (`bindSecondarySourceTabFocus`, `bindSecondaryM3uUrlFieldFocus`, `bindSecondaryM3uFilePickFocus`, `bindSecondaryXtreamServerFieldFocus`)
- Kullanılmayan `_minaGreen` sabiti

`PlaylistController` üzerindeki `enableSecondary` / `secondary*Controller` alanları geriye uyumluluk için **dokunulmadı** — eski sürümlerden kalan persisted state'i çiğnememek için. Yeni akış (slot 2+) `PlaylistsManagerController` üzerinden gider.

Net dosya boyutu: `playlist_view.dart` 1705 → 1310 satır (−395, %23 küçülme).

## 2.0.99 (build 4099)

**27 Mayıs 2026 — UI temizliği ve popup fix.**

### 🛡️ +18 İçerikleri Gizle — popup sonsuz dönmesi düzeltildi

- **Kök neden**: Önceki sürümde popup `showDialog` ile açılmıştı ama `Get.isDialogOpen` yalnızca `Get.dialog` ile açılan diyalogları izler — bu yüzden `Get.back()` hiç çağrılmıyor, popup sonsuza dek dönüyordu.
- **Düzeltme**:
  - Popup artık `Get.dialog<void>` ile açılır → `Get.back()` her zaman çalışır.
  - Setter çağrısı `Future.timeout(1200ms)` ile sarıldı; herhangi bir nedenle sıkışırsa popup yine de fail-safe olarak kapanır.
- **Akıllı hızlandırma**: Kullanıcının kütüphanesinde +18 keyword'ü taşıyan içerik yoksa (canlı kanal, VOD, dizi veya kategori adı) downstream Worker drain'i beklemek anlamsız — popup setter tamamlanır tamamlanmaz **bir sonraki frame'de** kapanır. `_hasAnyAdultInLibrary()` yardımcı metodu `PlaylistCacheService.result.value` üzerinde `AdultContentFilter.isAnyAdult([name])` ile tarama yapar; +18 yoksa 200 ms buffer bile beklemez.

### 💔 OSD'den favori (kalp) butonu kaldırıldı

Kullanıcı isteği üzerine her iki yönelimden de tek seferde temizlendi. Etkilenen dosyalar:

- `lib/modules/player/widgets/tv_better_player_controls.dart` (landscape Better controls + `_toggleFavorite`, `_fav` getter, `favorites_service.dart` import)
- `lib/modules/player/widgets/tv_media_kit_player_controls.dart` (landscape MediaKit controls + aynı temizlik)
- `lib/modules/player/player_view.dart` (3 portrait OSD branch'ı: Better-with-bp, Better-no-bp, MediaKit portrait + `favOn` değişkeni + `_fav` field + import)

Favoriler hâlâ kanal/film/dizi listelerinden eklenebilir; OSD'de yer kazanmak için player overlay'inde kaldırıldı.

## 2.0.98 (build 4098)

**27 Mayıs 2026 — sınırsız playlist desteği.**

### 🗂️ Liste Yönetimi — sabit 4 slot kalktı, dinamik yapı

Önceki tasarımda playlist sınırı `kPlaylistSlotCount = 4` ile sabitti; Ayarlar > Liste Yönetimi sayfası 4 slot kartı göstererek 5. listeyi eklemeyi imkânsız hâle getiriyordu. Bu yapı tamamen değiştirildi:

- **`kMaxPlaylistSlots = 32`** olarak yükseltildi (`kPlaylistSlotCount` legacy alias). Pratikte kullanıcı bu üst sınırı zorlamaz; storage katmanı slot başına `mina_iptv_*_$slot` anahtarlarını dinamik üretir.
- **`_slotKeys(slot)` formül tabanlı** çalışıyor — slot 1 (birincil) legacy anahtar isimlerini korur, N≥2 ise `mina_iptv_source_type_N` / `mina_iptv_xtream_base_url_N` … vb. Slot 3, 4 için ayrı `_kSourceType3/4` sabit grupları kaldırıldı; aynı kod 5, 6, 7, …, 32 slotları için de çalışır.
- **Sentinel sistemi generalize edildi**: `mina://local-m3u` (slot 1) ve `mina://local-m3u-N` (N≥2). `localM3uSentinelForSlot(slot)`, `slotFromLocalM3uSentinel(url)` ve regex tabanlı `isAnyM3uLocalSentinel(url)` ile herhangi bir slot dinamik tanınır. Eski `kM3uLocalPlaylistSentinel3/4` sabit grubu artık tek formülle üretiliyor.
- **Snapshot fingerprint** (`_mergedSnapshotKeyAll`) hard-coded L1/L2/L3/L4 branş'larından kurtuldu, `slotFromLocalM3uSentinel` ile herhangi bir slot için aynı `L$slot|...` kalıbını üretir.

### 🎨 UI — "Yeni liste ekle" davetkâr kartı

- `PlaylistsManagerController.reloadSlots()` artık 32 slotu tarayıp **yalnız dolu olanları + her zaman birincil slot 1 + tek bir trailing "Yeni liste ekle" placeholder'ı** UI listesine koyar.
- Trailing slot, `DottedFrame` ile çizilmiş **dashed-border davetkâr kart** olarak renderlanır: küçük primary-tinted `add_rounded` ikonu, "Yeni liste ekle" başlığı, "M3U URL, M3U dosyası veya Xtream — @n. slot olarak eklenir" alt satırı ve `chevron_right_rounded` ipucu. Dokununca aynı `_SlotEditorSheet` (M3U URL / M3U Dosya / Xtream sekmeli) açılır ama bu sefer **boş slot N+1** üzerinde.
- Yeni slot eklendikçe controller otomatik olarak bir sonraki boş slot için "Yeni liste ekle" tile'ı sunar — kullanıcı 5., 10., 20. listeyi eklemek için ayar değişikliği yapmak zorunda kalmaz.
- Subtitle değişti: "En fazla 4 liste" → "**İstediğin kadar liste ekle** — canlı, film ve dizi tek kütüphanede birleşir" (`playlistsManager.subtitle.unlimited`).

## 2.0.97 (build 4097)

**26 Mayıs 2026 — Tekrar bölümü oynatma fix'i.**

### 📺 Tekrar (Catch-up) — tıklayınca oynatma çalışıyor

Sorun: "Tekrar & EPG Mix" menüsünde Tekrar sekmesi içerikleri listeliyordu fakat bir programa tıklayınca hiçbir tepki yoktu. Kök neden: kullanıcı çoğunluğunun Ayarlar > **Catch-up URL Şablonu** preset'i `off` olarak kaldığı için `catchUpTemplateEffective` boş dönüyordu ve `_playReplay` hemen snackbar gösterip çıkıyordu.

- **Otomatik varsayılan şablon**: kullanıcı catch-up preset'ini hiç seçmediyse Tekrar bölümü artık `CatchUpUrlDefaults.xtreamTimeshiftPath` ile (klasik Xtream `/timeshift/USER/PASS/SÜRE/START_UTC/STREAM_ID.m3u8` yolu) URL üretir. Kullanıcının Ayarlar'da seçtiği farklı bir şablon her zaman önceliklidir; preset değiştirilmemiş kullanıcılar artık "no-op" yaşamaz.
- **M3U URL → Xtream sniff**: Aktif slotlarda doğrudan `XtreamSource` yoksa, ilk `M3uSource.url` üzerine `M3uXtreamSniffer.toXtreamSource(...)` çalıştırılır. Pek çok kullanıcı panelini "M3U URL" olarak ekleyip yine de `get.php?username=…&password=…` formuyla bağlandığı için bu fallback Tekrar'ı çoğu kurulumda kullanılabilir kılar.
- **Tanı log'ları**: Üç fail yolunda (Xtream yok / URL üretilemedi) `debugPrint` ile detaylı log atılıyor; başarılı oynatımda kullanılan timeshift URL'si ve programme aralığı da log'lanıyor.

## 2.0.96 (build 4096)

**26 Mayıs 2026 — kullanıcı geri bildirimi yamaları.**

### ⏩ OSD hız butonu — portrait desteği + 10x

- Portrait (dikey) modda OSD'de **hız butonu artık görünür**. Önceden yalnızca landscape OSD'lerde (TV MediaKit / TV BetterPlayer landscape) çıkıyordu; portrait OSD branch'lerinden (BetterPlayer-with-bp, BetterPlayer-no-bp, MediaKit portrait) hepsine eklendi. Yalnızca VOD modunda (canlı yayında gizli) görünür.
- Döngü genişletildi: **1x → 2x → 3x → 5x → 10x → 1x**. `playbackRateCycle` listesine `10.0` eklendi; `setPlaybackRate` clamp aralığı `8.0 → 16.0` çıkarıldı (MediaKit `setRate` ve BetterPlayer `setSpeed` ikisini de zaten yüksek hızlarda destekliyor).
- Portrait branch'lerinde tek yerden formatlama için `_portraitFmtRate(double)` üst seviye helper eklendi (landscape kontroldekilerle aynı davranış: tam değer için `'10x'`, ondalıklı için `'1.5x'`).

### 🛡️ +18 İçerikleri Gizle — kasma yerine glass popup

- "Hide +18 content" toggle'ına basıldığında **anında kapatılamaz cam popup** açılır:
  - `GlassPopupPanel` üzerine merkezde küçük `CircularProgressIndicator`, başlık `settings.hideAdult.applying.title` ("Tercih uygulanıyor"), alt satır `settings.hideAdult.applying.body` ("Ana ekran şeritleri yeniden hesaplanıyor…").
  - `gradientBlendTowardBlack: 0.22` ile diyalog okunabilirliği için hafif koyu degrade.
  - `PopScope(canPop: false)` + `barrierDismissible: false` ile dış tıklama ve geri tuşu engellenir.
- Akış: popup açılır → 32 ms ilk frame render → `AppSettingsService.setHideAdultContentEnabled(...)` await → 420 ms downstream Worker drain buffer'ı (`ContinueWatchingStrip`, `AiRecommendationsStrip`, `MixedLiveTvStrip` cache invalidate'leri otursun diye) → popup `Get.back()` ile kapanır.
- Kullanıcı tarafta artık ayar tile'ı kasmıyor; geri bildirim canlı kalıyor, downstream şeritler işini popup arkasında yapıp bitiriyor.

## 2.0.95 (build 4095)

**26 Mayıs 2026 — bu seansta eklenenler.**

### 📺 Tekrar & EPG Mix (yeniden adlandırma + geriye dönük izleme)

- Ana ekrandaki "EPG Mix" kartı ve menü başlığı artık **"Tekrar & EPG Mix"**.
- EPG Mix menüsünde **sol üstteki ilk chip "Tekrar"** olarak eklendi (`EpgMixCategory.replay`).
- "Tekrar" seçildiğinde **son 24 saatte biten** canlı kanal programları kanal başına en fazla 6, toplam 240 ile "yeni → eski" sıralı listelenir (`EpgReplayCatalog`).
- Tıklandığında: `AppSettingsService.catchUpTemplateEffective` üzerinden catch-up URL üretilir ve player'a iletilir; Xtream timeshift mekanizmasıyla geriye dönük yayın oynatılır.
- Tile altında "Tekrar · X dk önce / Y sa önce / Dün" relative time satırı.
- Hata durumları (kaynak Xtream değil / şablon kapalı / URL üretilemedi) localized snackbar ile gösterilir.

### 🗂️ Liste Yönetimi (4 playlist'e kadar)

- Playlist sınırı **2 → 4**'e çıkarıldı. Ayarlar > **"Liste Yönetimi"** alt sayfası eklendi (`AppRoutes.playlistsManager`).
- Repo katmanı slot-tabanlı yeni API: `readSourceAt/persistSourceAt/clearSourceAt/persistM3uLocalContentAt/readAllSources`. Eski `readSecondarySource/...` slot 2 delegate'i olarak korundu (geriye uyumlu).
- `loadMergedPlaylist` artık birincil + dolu olan tüm ek slotları sırayla `mergePlaylistLayers` ile zincirler (orphan kategori adı slot başına özelleştirilebilir).
- Snapshot fingerprint tüm slotları kapsayacak şekilde güncellendi.
- UI: 4 slot kart bazlı liste, slot başına M3U URL / M3U Dosya / Xtream sekmeli bottom-sheet düzenleme, slot 2/3/4 için silme. Her kaydetme/silme sonrası birleşik playlist otomatik yenilenir.

### ⏩ OSD'de hızlı oynatma butonu (VOD)

- Player OSD'sine yeni buton: **1x → 2x → 3x → 5x → 1x** döngüsü.
- Yalnızca film/dizi (VOD) modunda görünür; canlı yayında gizli.
- 1x'te `speed_rounded` ikonu, hızlandırılmış modlarda "2x/3x/5x" rozeti (cam OSD'deki "B" butonuyla aynı stil).
- MediaKit (`setRate`) ve BetterPlayer (`setSpeed`) tek noktadan: `PlayerController.cyclePlaybackRate()` / `setPlaybackRate(double)`.
- Yeni VOD açılışında `resetPlaybackSpeed()` artık `playbackRate` Rx'ini de 1.0'a senkronlar — rozet otomatik kaybolur.

## 2.0.89 (build 4089)

**Konsolidasyon sürümü — 25 Mayıs 2026.** Bugün yapılan tüm Ebeveyn Kontrolü, Ana Ekran ve geliştirici araçları çalışmalarının özet bültenidir. Hiç bir feature 4086-4088 sürümlerinden geri alınmadı; bu giriş onları **tek başlık altında derleyip Play Store yayın için referans noktası** oluşturuyor.

### 🛡️ Ebeveyn / Çocuk Kontrolü — büyük yenileme

- **PIN doğrulama bug'ı tamamen düzeltildi.** "PIN'i kaydettim, çıkıp tekrar girince doğru PIN'i kabul etmiyor" şikâyetinin kök nedeni `flutter_secure_storage`'ın bazı Android cihazlarda (KeyStore reset, OEM yedekleme akışları, app data silinmeden yeniden kurulum senaryolarında) yazılan değeri **decrypt edememesi** ve `read` çağrısında `null` döndürmesiydi. `verifyPin` da bu `null`'ı `hashPin(input)` ile karşılaştırınca her zaman "yanlış PIN" diyordu. Yeni `ParentalControlService`:
  - **Çift yedekli storage:** PIN'in SHA-256 + sabit-tuz hash'i hem `FlutterSecureStorage`'a (öncelik) hem `SharedPreferences`'a (yedek) **eş zamanlı** yazılır. Hash zaten geri-dönüşsüz olduğu için düz metin sızdırılmaz.
  - **`_readHashWithSelfHeal()`:** Önce secure storage denenir, `null` veya throw olursa otomatik prefs'e düşer. Yalnız bir tarafta kayıt bulunursa eksik kopya sessizce geri yazılır. İki tarafta farklı değer varsa secure storage kanonik kabul edilir.
  - **Bellek içi `_cachedHash`:** Aynı oturumda storage düşmesine karşı son savunma.
  - **Sonuç:** Cihaz yeniden başlatılsa bile, kaydedilen doğru PIN her zaman tanınır.
- **Tamamen yeni glass numpad arayüzü.** Klasik `TextField` formu atıldı, yerine:
  - **6 nokta PIN göstergesi**: girilen rakam sayısı kadar primary renkte glow ile dolar; aktif slot hafifçe büyür.
  - **3×4 cam numpad**: 1-9 + Backspace (sol-alt) + 0 (orta-alt) + Clear (sağ-alt). Her tuş glassmorphism kart; focus durumunda primary gradient + 14 px shadow ile öne çıkar.
  - **Header**: gradient halka içinde kilit / kalkan / açık-kilit iconu (aşamaya göre değişir) + başlık + alt açıklama.
  - **Hata / başarı şeritleri**: kırmızı `error_outline` veya yeşil `check_circle_outline`, 14 dp yuvarlatılmış, %16 opaklığında dolgulu.
  - **Submit butonu**: oluşturma akışında "İleri → Kaydet"; doğrulama akışında "Aç". Min. 4 hane girilmemişse opaklık 0.55 ile devre dışı.
  - **PIN sıfırlama:** AppBar sağında `lock_reset` icon → glass confirm dialog ile çift onaylı temizlik.
- **TV kumandası tam uyumlu.** Numpad üzerinde D-Pad ile tüm yönlerde gezinme; son satırın aşağısı doğrudan submit butonuna odaklanır. Select / Enter / OK / NumpadEnter / Space / GameButtonSelect tuşlarının hepsi handle edilir.
- **Tema-uyumlu Kategori Gizleme arka planı.** PIN doğrulandıktan sonra açılan `XtreamCategoryHideView` (embedded modda) eskiden kendi etrafını `ColoredBox(color: Colors.black)` ile sarıyordu; bu da parent `ParentalControlView`'ın `ThemedSettingsBackground` gradientini (Mina Glass / Dark Flat / SEMC / Fly UI vb.) **eziyordu** — liste etrafı düz siyaha boyanıyordu. Çözüm: `ColoredBox` kaldırıldı; yerine `Padding(12, 4, 12, 12) + _glassShell` (Playback Settings stiliyle birebir). `useBackdrop: !reduceBlur` ile gerçek backdrop blur açıldı. Artık seçili tema gradientinin tamamı sayfaya sızıyor.
- **Çift başlık temizliği.** Önceden "Ebeveyn denetimi" (AppBar) + "Kategori gizleme" (embedded header) iki kez görünüyordu. Artık AppBar başlığı **dinamik**: PIN aşamasında `settings.parental.title`, kategori listesi açıldığında otomatik `settings.xtreamCategoryHide.title` olur; embedded view'in tepesindeki yedek başlık satırı tamamen silindi.
- **17 dilde tam çeviri.** 9 yeni anahtar (`pinSaved`, `next`, `title.create/confirm/enter`, `confirmIntro`, `reset`, `resetTitle`, `resetConfirm`) TR, EN, FR, AR, ZH, RU, KO, HE, DA, SV, HI, TH, IT, PT, ID, ES, JA dillerinin tamamına eklendi.

### 🏠 Ana Ekran

- **"Mina AI: Senin İçin Önerilenler" başlığından kıvılcım iconu kaldırıldı.** Kullanıcı isteğiyle başlık artık sade düz metin. Mor-pembe gradient çember içindeki `auto_awesome_rounded` iconu (`_AiSparkIcon` widget'ı) + yanındaki 8 px boşluk tamamen silindi; sınıf da dosyadan kaldırıldı. Tasarımsal olarak diğer ana ekran şerit başlıklarıyla (İzlemeye Devam Et, Yüksek Puanlı Filmler) hizalı bir görünüm sağlandı. **Kartların sağ üstündeki AI eşleşme yüzdesi rozetindeki altın kıvılcım iconu korundu**, sadece header etkilendi.

### 🛠️ Geliştirici araçları (APK içeriğine girmez ama proje sağlığı için)

- **`translate_sync.py` — i18n eşitleyici** (proje kökü). GetX `AppTranslations` (Dart `const Map`) tabanlı i18n yapısı için **tam otomatik eksik anahtar tespiti + Google Translate ile çeviri + Dart map'ine güvenli enjekte** yapan script. 5 ciddi parser bug'ı düzeltildi: çok satırlı değerler (`re.DOTALL`), kaçışlı tek-tırnak literal (`'(?:\\.|[^'\\])*'`), `he` → `iw` (Google), placeholder maskeleme (`ZXQPH{i}ZXQ`), çoklu map terminasyonu anchor'u (`\n\};`). Ekstra: `--dry-run`, `--lang fr`, `--sleep-ms` opsiyonları, lazy import.
- **`.cursor/rules/mina-i18n.mdc`** — proje kuralı. Cursor her oturumda otomatik okuyup uygular: "Yeni anahtarlar sadece `_tr` + `_en`'e ekle, sonra `python3 translate_sync.py` çalıştır." JSON / .arb kullanılmadığı, `@param` placeholder formatı zorunlu olduğu net olarak belirtildi.

## 2.0.88 (build 4088)

- **Ebeveyn Kontrolü → Kategori Gizleme arka planı artık temaya uyuyor.** Kullanıcı PIN'i doğru girip içeri girdiğinde gösterilen `XtreamCategoryHideView` (embedded modda) kendi etrafını `ColoredBox(color: Colors.black)` ile sarıyordu; bu da parent `ParentalControlView`'ın `ThemedSettingsBackground`'unu (Mina Glass / Dark Flat / SEMC / Fly UI vb. tema gradientleri) **eziyor** ve liste etrafını düz siyaha boyuyordu (ekran görüntüsünde yeşil gradient AppBar'ın altı tamamen siyah karelerden oluşuyordu). Çözüm:
  - Embedded modda `ColoredBox` siyahı tamamen kaldırıldı; yerine `Padding(12, 4, 12, 12) + _glassShell` koyuldu.
  - Glass shell artık `reduceBlur` ayarına göre gerçek backdrop blur kullanıyor (önceden `useBackdrop: false` ile sabitleniyordu); kullanıcı `Hızlı tema (blur azalt)`'ı kapatmışsa Playback Settings'teki gibi tam cam efekt görünüyor.
  - Parent tema arka planı (Mina Glass yumuşak yeşil gradient, Dark Flat koyu gri, SEMC mavi-mor radial, Fly UI canlı pastel vb.) doğrudan glass kutudan içeri sızıyor; "Oynatma Ayarları" ile birebir aynı görsel dilde.
- **Çift başlık temizliği.** Önceden sayfada iki başlık vardı: AppBar'da "Ebeveyn denetimi" + embedded view'in tepesinde "Kategori gizleme". Artık tek başlık var:
  - PIN aşamasında AppBar `settings.parental.title` ("Ebeveyn denetimi") gösterir.
  - Doğrulama başarılı olup kategori listesi açıldığında AppBar dinamik olarak `settings.xtreamCategoryHide.title` ("Kategori gizleme") olur.
  - Embedded view içindeki yedek başlık satırı (`if (widget.embeddedInParent) Padding(...Text(...))`) tamamen silindi; sayfada baş başlık + TabBar + liste şeklinde temiz akış kaldı.
- Tüm i18n anahtarları zaten 17 dilde mevcuttu; ek çeviri gerekmedi.

## 2.0.87 (build 4087)

- **Ana ekran "Mina AI: Senin İçin Önerilenler" başlığından mor-pembe gradient kıvılcım iconu kaldırıldı.** Kullanıcı isteğiyle başlık satırı sadece düz metin olarak gösteriliyor; `_AiSparkIcon` widget'ı (`auto_awesome_rounded` + gradient çember + shadow) ve yanındaki 8 px boşluk tamamen silindi. Tasarımsal olarak daha sade ve diğer ana ekran şerit başlıklarıyla (İzlemeye Devam Et, Yüksek Puanlı Filmler vb.) hizalı bir görünüm elde edildi. Sadece header etkilendi — kartların sağ üst köşesindeki AI eşleşme yüzdesi rozetinde kullanılan altın kıvılcım iconu **korundu**.

## 2.0.86 (build 4086)

- **Ebeveyn Kontrolü PIN doğrulama hatası giderildi.** "PIN kaydettim, çıkıp yeniden girince doğru PIN'i kabul etmiyor" şikâyetinin kök nedeni: `flutter_secure_storage` bazı Android cihazlarda (KeyStore reset, OEM yedekleme akışları, "veri silmeden yeniden kurulum" senaryolarında) yazılan değeri **decrypt edemediği için null döndürebiliyordu**; `verifyPin` da `null` ile `hashPin(input)`'i karşılaştırdığı için her zaman _yanlış PIN_ diyordu. Yeni mimari:
  - `ParentalControlService` artık **çift yedekli storage** kullanır: PIN'in SHA-256 + salt hash'i hem `FlutterSecureStorage`'a (öncelik) hem de `SharedPreferences`'a (yedek) **eş zamanlı** yazılır. Hash zaten geri-dönüşsüz olduğu için düz metin sızdırılmaz.
  - Doğrulamada `_readHashWithSelfHeal()` önce secure storage'ı dener, başarısız (`null` / `read` throws) olursa otomatik `SharedPreferences`'a düşer.
  - **Self-heal**: Yalnız bir tarafta kayıt bulunursa eksik kopya sessizce geri yazılır (gelecekte secure storage geri gelirse de tutarlı kalır). İki tarafta farklı değer varsa secure storage kanonik kabul edilir.
  - Bellek içi `_cachedHash` aynı oturumda storage düşmesine karşı son savunma; setPin sonrası read başarısız olsa dahi verifyPin doğru çalışır.
  - Sonuç: kullanıcı PIN'i bir kez kaydettiğinde, **cihaz yeniden başlatılsa bile** doğru PIN her zaman tanınır.
- **Ebeveyn Kontrolü arayüzü tamamen yenilendi.** Eski `TextField` + iki butonlu klasik form yerine **glass numpad** tasarımı:
  - Üstte gradient halka içinde **kilit / kalkan / açık-kilit** iconu (akışın aşamasına göre değişir) + başlık + açıklama tek satırlık header kartı.
  - PIN gösterge: ortalanmış **6 nokta**; girilen rakam sayısı kadar primary renkte glow ile dolar, boş slotlar gri-saydam kalır. Aktif slot hafifçe büyür.
  - **3×4 cam numpad**: 1-9 + Backspace (sol-alt) + 0 (orta-alt) + Clear (sağ-alt). Her tuş glassmorphism kart; focus durumunda primary gradient + parlatma + 14 px shadow ile öne çıkar.
  - Geniş **submit butonu** altta: oluşturma akışında "İleri" → "Kaydet"; doğrulama akışında "Aç" yazar. Minimum 4 hane girilmemişse opaklık 0.55 ile devre dışı.
  - Hata / başarı **şeritleri**: kırmızı `error_outline` veya yeşil `check_circle_outline` ile 14 dp yuvarlatılmış, 16 % opaklığında dolgulu, renkli kenarlık.
- **TV kumandası uyumu.** Numpad üzerinde **D-Pad** ile gezinme: yukarı/aşağı/sol/sağ tüm yönlerden komşu tuşa odaklanır. Son satırın altındaki "aşağı" basışı doğrudan submit butonuna odaklar. Select / Enter / OK / NumpadEnter / Space / GameButtonSelect tuşlarının hepsi hem rakam basışı hem submit için handle edilir.
- **PIN sıfırlama akışı.** AppBar sağına `lock_reset` ikonu eklendi (PIN varsa görünür). Tıklayınca **glass confirm dialog** ile çift onay alır → secure storage + prefs + bellek cache tamamen temizlenir → kullanıcı baştan PIN oluşturma akışına döner.
- **Tema-uyumlu arka plan** korundu: sayfa `ThemedSettingsBackground` içinde olduğundan Mina Glass / Dark Flat / SEMC / Fly UI hangisi seçiliyse arka plan ona uyar; cam shell ise primary renkle armoni içinde tüm temalarda çalışır.
- **17 dile tam çeviri.** Yeni 9 anahtar (`pinSaved`, `next`, `title.create/confirm/enter`, `confirmIntro`, `reset`, `resetTitle`, `resetConfirm`) TR, EN, FR, AR, ZH, RU, KO, HE, DA, SV, HI, TH, IT, PT, ID, ES, JA dillerinin tamamına eklendi.

## 2.0.85 (build 4085)

- **Playlist yükleme özet dialog'u artık gerçek zamanlı** (önceki sürümde işlem _bittikten sonra_ animasyonla geliyordu). Yeni davranış:
  - Kullanıcı M3U URL'sini yazıp ya da Xtream bilgilerini girip **gönder** butonuna basar basmaz cam diyalog **hemen** açılır.
  - Üç satır (**Canlı kanallar / Filmler / Diziler**) başlangıçta spinner ile **yükleniyor** olarak görünür; alttaki **Tamam** butonu opaklık 0.45 ile devre dışıdır.
  - Repo `loadFromXtream` / `loadFromM3uUrl` / merged playlist çağrısı bittiğinde, dialog'a sayılar gönderilir; her satır 550 ms aralıkla sırayla "✓ + sayı" rozeti alır.
  - Son satır tamamlandığında **Tamam** butonu tam opaklığa geçer; TV cihazlarda `FocusNode.requestFocus()` ile **otomatik odaklanır**, kumandanın **OK / Select / Enter** tuşları doğrudan butonu basar.
  - `PopScope(canPop: done)` ile **geri tuşu** (Android) ve **dış alana dokunma** yükleme bitene dek engellenir; kullanıcı yarım iş bırakamaz.
  - Hata durumu: yükleme başarısız olursa dialog otomatik kapanır (`_abortLoadSummary`), kullanıcıya hata toast'u gösterilir.
- Mimari değişiklik: `PlaylistLoadSummaryDialog` artık `ValueListenable<PlaylistLoadProgress>` üzerinden besleniyor (`loading` ↔ `done(sayılar)`). Controller (`PlaylistController`) submit anında `ValueNotifier` oluşturup dialog'u açıyor, repo dönüşünde `notifier.value = PlaylistLoadProgress.done(...)` ile aşama animasyonunu tetikliyor.
- Tüm 17 dilde mevcut `playlist.summary.*` anahtarları kullanılıyor; ek çeviri gerekmedi.

## 2.0.84 (build 4084)

- **Ayarlar yeniden düzenlemesi.** Eskiden ayarlar ana listesinde dağınık duran şu 5 oynatma ilişkili seçenek tek başlığa — **Ayarlar → Oynatma Ayarları** — taşındı:
  - **OSD gizleme süresi** (sayaç dialog'u, chevron'lu).
  - **Yayın önizlemesi** (kanal listesi üzerinde gezinirken minik canlı pencere).
  - **Arka planda oynatma** (uygulama arkaya alındığında ses akmaya devam etsin).
  - **Küçük ekran PIP** (Android, sadece Better Player; MediaKit / TV modu uygun değilse alt yazı ile bilgi).
  - **Cihaz açıldığında başlat** (boot completed → auto-launch).
  Servis API'leri (`setBackgroundPlayback`, `setMiniPlayerOnHome`, `toggleStreamPreviewEnabled`, `showTvOsdAutoHideDurationDialog`, `setLaunchOnBoot`) birebir korundu; UI sadece tek alt-sayfaya yeniden gruplandı, mevcut işlevsellik etkilenmedi.
- **Yeni: Ebeveyn / Çocuk Kontrolü ayarlar girişi.** Eskiden gizli kalıyordu (route var, settings_view'da link yoktu). Artık ayarlar listesinde **Yedekleme / Geri Yükleme** satırının altında `Icons.child_care_rounded` ile çıkıyor. **Yalnızca bir playlist (M3U veya Xtream) yüklendikten sonra görünür** — `SettingsController.hasAnySource` yeni RxBool sinyali ile koşullu; içerik yoksa tile gösterilmez (kullanıcıya boşa bir menü öğesi sunulmaz).
- **Ebeveyn Kontrol sayfası tema arka planı.** Daha önce de `ThemedSettingsBackground` kullanıyordu; artık ayarlar girişi geldiği için kullanıcılar bu kısımdan tema-uyumlu (Mina Glass / Dark Flat / SEMC / Fly UI vb.) cam arka plana sahip PIN ekranına erişebiliyor. AppBar yarı saydam, içerik glass shell.
- Tüm 17 dilde mevcut `settings.tile.parental` + `settings.tile.parental.sub` çevirileri kullanıldı; ek çeviri gerekmedi.

## 2.0.83 (build 4083)

- **Yeni: Mina AI — Senin İçin Önerilenler şeridi.** Ana ekrana _İzlemeye Devam Et_ şeridinin hemen altına eklenen yapay zekâ destekli kişiselleştirilmiş öneri sistemi. Kullanıcı yerel saatine ve geçmiş izleme alışkanlıklarına göre **10 karma içerik** (canlı kanal + film + dizi) önerir. Kartlar _İzlemeye Devam Et_ ile **aynı çerçeve ebatlarını** (portait 130×100 / TV 144×108 / yatay 160×120) kullanır, glassmorphism dizaynı korunur. Her kartta:
  - Sol üstte tür rozeti: kırmızı **Canlı**, mavi **Film**, mor **Dizi** (yarı saydam cam efekti).
  - Sağ üstte **AI eşleşme yüzdesi** (yüksek skorlarda, altın kıvılcım iconlu).
  - Başlık aşağıda gradient karartmada.
- **Yeni: UserHistoryService (`lib/services/user_history_service.dart`).** Kullanıcı bir kanalı/filmi/diziyi **2 dakika ve üzeri** izlediğinde yerel hafızaya (SharedPreferences JSON, max 400 kayıt FIFO) içeriğin türü, kategorisi, adı, posterini ve yerel saat damgasını yazar. 30 dakikalık dedup penceresinde aynı içeriğin tekrar tekrar şişmesini önler.
- **Yeni: AIRecommendationService (`lib/services/ai_recommendation_service.dart`).** Saf hesaplama motoru:
  - **Top 3 kategori** + saat-dilimi profili (Sabah 05-12, Öğle 12-17, Akşam 17-22, Gece 22-05) çıkarır; geçerli saat dilimine uygun kategoriler **2× puan** alır.
  - Skor formülü: kategori puanı × log10-tabanlı izleme süresi bonusu × görülmüş penaltısı.
  - Sonuç dağılımı: ~3 canlı + ~4 film + ~3 dizi (toplam 10); profil zayıfsa eksik tip dolgulanır.
  - **Soğuk başlangıç:** yeni kullanıcı için IMDB ≥7 filmler ve rastgele canlı/dizi kombinasyonu (günlük tuzla stabil).
- **Player entegrasyonu:** `player_controller.dart` içinde her 15 saniyede bir tick atan ayrı tracker — playback aktifse `_userHistoryWatchedSec += 15`. 120 saniye eşiği aşıldığında `UserHistoryService.record` çağrılır; sonrasında her ~60 sn'de güncelleme yazılır. Kanal değişiminde ve dispose'da otomatik flush.
- **Ayarlar → Ana Ekran Ayarları** sayfasına dördüncü toggle: **«Yapay Zekâ Destekli Ana Ekran Önerileri»** (Mor `auto_awesome` ikonu, 4 demo kart önizlemesi: Live/Film/Dizi/Film rozetleriyle). `settings.isAiRecommendationEnabled` ile bağlı.
- **Kurulum sihirbazına anahtar:** `setup.aiRecommendationsTitle` / `setup.aiRecommendationsSub` ile setup wizard switch satırı eklendi (varsayılan açık).
- **Tam i18n:** Yeni 8 anahtar (`home.ai.title`, `home.ai.badge.live/film/series`, `homeSettings.aiRecommendations.title/sub`, `setup.aiRecommendationsTitle/Sub`) **17 dile** çevrildi: TR, EN, FR, AR, ZH, RU, KO, HE, DA, SV, HI, TH, IT, PT, ID, ES, JA.
- **Performans:** Strip widget statik cache (catalog hash + günlük tuz) ile aynı gün içinde rebuild'ler arasında yeniden hesaplama yapmaz; gün dönünce profil + öneriler yenilenir.

## 2.0.82 (build 4082)

- **Yeni: Playlist yükleme özeti popup'ı.** Kullanıcı M3U URL'si, yerel M3U dosyası veya Xtream bilgilerini girip başarıyla yüklediğinde artık ana ekrana atlamadan önce şık bir cam diyalog açılır. Diyalog 3 satır sırayla "yükleniyor → ✓ tamamlandı" animasyonuyla ilerler:
  - **Canlı kanallar** — adetiyle (mavi vurgu)
  - **Filmler** — adetiyle (turuncu vurgu)
  - **Diziler** — adetiyle (mor vurgu)
  Her satırda kategoriye özel ikon, sayım `1,234,567` gruplandırmasıyla, ve aşama tamamlanınca yeşil tik yerine kategoriye uygun aksan rengi ile check rozeti. Aşama animasyonu bittiğinde **Tamam** butonu aktifleşir (önceden %45 opacity ile pasif), kullanıcı dokununca dialog kapanır ve normal navigasyon (Home veya kurulum sihirbazı tamamlama) devreye girer.
- Tüm 15 desteklenen dilde tam çeviri: **TR, EN, FR, AR, ZH, RU, JA, ES, KO, HE, DA, SV, HI, TH, IT, PT, ID**.
- Setup wizard / Demo playlist akışlarında da çalışır — yeni cam diyalog her başarılı yükleme için aynı UI'ı gösterir; tutarlı kullanıcı deneyimi.

## 2.0.81 (build 4081)

- **Ayarlar alt-sayfalarının arka planı artık aktif tema duvar kâğıdına uyumlu.** Eskiden _Kategori Gizleme_, _Canlı Kanal Düzeni_, _Ana Ekran Ayarları_, _Yedekleme / Geri Yükleme_, _Kanal Kategori Düzeni_, _Oynatma Ayarları_, _Ana Ekran Kart Sırası_, _Altyazı Seçenekleri_, _EPG Ayarları_, _EPG Kaynağı Yönetimi_ ve _Ebeveyn Kontrolü_ sayfaları sabit **siyah + mor primary** gradient çiziyordu; artık ana ayarlar sayfasıyla birebir aynı şekilde **aktif temanın duvar kâğıdı** + portrede 7σ / yatayda 11σ blur + 0.42→0.72 koyulaştırıcı overlay kullanıyor. Böylece kullanıcı:
  - **Mina Glass** seçtiyse ekran görüntüsündeki gibi **yeşilimsi cam tonu**,
  - **Dark Flat** / **Flat Black** seçtiyse düz koyu zemin,
  - **SEMC / Fly UI / Glassmorphism / Koyu Cam** seçtiyse o temaya özel arka planı
  alt-sayfalarda da görür. `TV` modu ve `reduce blur` durumlarında blur otomatik kapanır (CPU/GPU tasarrufu).
- Yeni paylaşılan widget: `ThemedSettingsBackground` (`lib/ui/themed_settings_background.dart`) — `AppTheme.homeBackgroundAsset` + `AppTheme.homeBackgroundImageDecodeParams` ile aynı decode cache parametrelerini kullanır, böylece her alt-sayfada ek bellek harcaması yapılmaz.

## 2.0.80 (build 4080)

- **Yüksek Puanlı Filmler şeridi yenilendi:**
  - Yıldız aralığı **7.0–10.0** olarak değiştirildi (eskiden ≥0.1; artık sadece yüksek puanlılar, hiper popüler 9.5+ filmler sürekli baskın değil).
  - **Aynı isimde filmler kaldırıldı.** Ad anahtarı normalize ediliyor: lowercase + Türkçe diakritik (`çğıöşü…` → `cgiosu…`) + sondaki `(2010)` / `[2024]` yıl parantezleri + `HD/4K/1080p/HEVC/x265/x264` gibi kalite kuyrukları + noktalama atılır. Aynı ada düşen kopyalardan en yüksek puanlı olan tutulur.
  - **Günlük rastgele karışım.** Tohum, yerel takvim günü (UTC değil — kullanıcının saat dilimi). Aynı gün boyunca her açılışta **aynı sıra/içerik** (kullanıcı şeride dokunduğunda kart değişmiyor), **gün dönünce farklı 30 film**.
  - Karıştırma deterministik Fisher–Yates (`math.Random(dayKey)`); pool önce `vod.id`'ye göre stabil sıralanıp sonra karıştırılır → aynı gün + aynı playlist için sonuç değişmez.
  - **30 film** gösteriliyor (eskiden 20).

## 2.0.79 (build 4079)

- **Yeni: Ayarlar → «Oynatma Ayarları» alt-sayfası** (`Icons.play_circle_filled_rounded`). Eskiden ayarlar listesinde dağınık duran şu 4 seçenek tek başlık altında toplandı:
  - **MediaKit/MPV Kullan** (oynatıcı motoru: MediaKit ↔ Better Player)
  - **Donanım Hızlandırma** (`mediacodec-copy` / `mediacodec`)
  - **Video Kod Çözücü** (donanım / yazılım)
  - **Düşük Gecikme Buffer** (0–30 sn slider)
  Cam shell içinde her satır 40×40 ikon + başlık + dinamik özet ile gelir; canlı buffer satırı chevron'la slider dialog'unu açar. Servis API'leri (`setUseMediaKit`, `setMediaKitLowPowerHwdec`, `setPreferSoftwareVideoDecoder`, `showLiveBufferDialog`) birebir korundu.

## 2.0.78 (build 4078)

- **Ayarlar listesi sadeleşti:** «Kategori Gizleme» ve «Canlı Kanal Düzeni» tile'ları tek bir **«Kanal Kategori Düzeni»** girişinde (`Icons.tune_rounded`) birleştirildi. Bu tile'a tıklanınca yeni `ChannelCategoryLayoutView` alt-sayfası açılır ve içinde iki büyük cam kart halinde **«Kategori gizleme»** ve **«Canlı kanal düzeni»** seçenekleri sunulur; her satırdaki chevron, kendi düzenleyici sayfasını açar (orijinal işlevsellik birebir korunur).

## 2.0.77 (build 4077)

- **Ayarlar listesi sadeleşti:** «Ayarları yedekle (paylaş)» ve «Yedekten geri yükle» tile'ları tek bir **«Yedekleme / Geri Yükleme»** girişinde birleştirildi (`Icons.backup_rounded`). Tile'a tıklanınca yeni `BackupRestoreView` alt-sayfası açılır; içinde iki büyük cam kart halinde **«Yedeği paylaş»** ve **«Dosya seç ve geri yükle»** aksiyonları, her birinin altında ne yapacağını açıklayan madde işaretli özet ile birlikte sunulur. İşlem sırasında dairesel ilerleme göstergesi gösterilir, busy state'inde iki buton da kilitlenir.

## 2.0.76 (build 4076)

- **Yeni alt-sayfa: «Ana Ekran Ayarları»** — Ayarlar → kart sırası tile'ının yerinde tek başlık altında topladık. İçerik:
  - **Kart sırası** (eski yere kıyasla aynı düzenleyici açılır)
  - **Karışık Canlı TV** anahtarı
  - **Sıradaki Maçlar** anahtarı
  - **Yüksek Puanlı Filmler** anahtarı (yeni `topRatedFilmsEnabled` ayarı; varsayılan açık, SharedPreferences'a kaydediliyor).
  Her satırın hemen altında, açıldığında ana ekranda ne göründüğünü gösteren küçük bir **önizleme illüstrasyonu** var (renkli kart blokları, kanal logoları, maç chipleri ve IMDB rozetli mini posterler).
- **Ayarlar listesi sadeleşti:** Eski Karışık Canlı TV ve Sıradaki Maçlar tile'ları artık ayrı ayrı listelenmiyor — hepsi tek «Ana Ekran Ayarları» girişinden yönetiliyor.
- **Kurulum sihirbazı korundu:** Sihirbazdaki Karışık Canlı TV / Sıradaki Maçlar anahtarları aynı yerinde; ek olarak **Yüksek Puanlı Filmler** anahtarı eklendi. Sihirbaz yeni alanı varsayılan açık olarak getirir.

## 2.0.75 (build 4075)

- **Ana ekran → «Yüksek Puanlı Filmler» şeridi:** İzlemeye Devam Et şeridinin hemen altına, karışık canlı TV / sıradaki maçlardan **önce** yeni yatay bölüm. Filmler kategorisinden IMDB / Xtream rating'i ≥ 0.1 olan tüm VOD'ler puana göre azalan sıralanır ve ilk **20** film gösterilir. Posterler **İzlemeye Devam Et kartlarıyla bire bir aynı boyutta** (portrait 130×100, mobil yatay 160×120, TV 144×108). Her kartta cam tasarımda dairesel IMDB rozeti (sağ üst, sarı tonlu, blur+gölgeli) ve altta gradient overlay üstünde film adı yer alır; tıklayınca filmin oynatma sayfası açılır.

## 2.0.74 (build 4074)

- **Ayarları + M3U bilgilerini yedekleme & geri yükleme:**
  - Yeni `BackupService` (`lib/core/services/backup_service.dart`) tüm `mina_*` SharedPreferences anahtarlarını, SecureStorage’daki M3U/Xtream kimlik bilgilerini (10 anahtar) ve yerel olarak kaydedilmiş `saved_playlist.m3u` / `saved_playlist_2.m3u` dosyalarını tek bir JSON’da topluyor.
  - Bu JSON **AES‑256 (CBC + PKCS7, rastgele IV)** ile şifreleniyor. Çıktı: `MNB1` (4 bayt magic) + IV (16 bayt) + ciphertext biçiminde `mina_backup.dat`.
  - **Dışa aktarım:** Ayarlar → «Ayarları yedekle (paylaş)» tile’ı `share_plus` ile sistemin yerel paylaşım sayfasını açar; kullanıcı Drive / WhatsApp / e‑posta vb. ile gönderir. **Hiçbir tehlikeli depolama izni istenmiyor** (AndroidManifest dokunulmadı).
  - **Geri yükleme:** Ayarlar → «Yedekten geri yükle» tile’ı `file_picker` ile tek `.dat` dosyası seçer; AES çözümü, eski `mina_*` anahtarlarının temizlenmesi ve tüm verilerin tip‑güvenli (`bool` / `int` / `double` / `String` / `List<String>`) geri yazımı ardından özet + yeniden başlatma diyaloğu gösterir.
  - Onay diyaloğu, başarı snackbar’ı ve hata mesajları TR/EN olarak yerelleştirildi (`settings.backup.*`).

## 2.0.73 (build 4073)

- **Ayarlar → «Yerleşim» seçeneği kaldırıldı:** Uygulama, ekran boyutuna göre yerleşim modunu otomatik yönetiyor; gereksiz kullanıcı seçimi gizlendi.
- **Yatay OSD arka plan saydamlığı (0–100):** Ayarlar → yeni «Yatay OSD saydamlığı» kartı. Slider ile (mobilde 0–100, kumandada ±5 adımlı butonlarla) OSD kapsülünün **sadece arka planı / kenarı / gölgesi** istenildiği ölçüde şeffaflaştırılabiliyor. **Butonlar, ikonlar, kanal logosu ve metinler hiç etkilenmiyor** (her birinin alfa kanalı orijinal değeriyle korunuyor). Hem MediaKit hem de Better Player OSD'leri için aktif.
- **VOD altyazısı varsayılan kapalı:** Film/Dizi açıldığında altyazı artık otomatik açılmıyor — kullanıcı OSD'deki altyazı butonundan istediği dili manuel seçer (önceki tercih kaydedilmeye devam ediyor).

## 2.0.72 (build 4072)

- **OSD adaptif boyut (yatay mobil küçük ekranlar):** Yatay modda oynatıcı OSD panelinin sağ kontrol kapsülü bazı dar/küçük ekranlı telefonlarda taşıyordu. Artık ekran genişliğine göre dinamik küçülüyor: buton boyutu (44 → 36 → 32 dp), butonlar arası boşluk (6 → 4 → 3 dp), sol kanal bilgi bloğu maksimum genişlik (168 → 134 → 108 dp) ve ortadaki dikey ayraç (32 → ~26 → ~23 dp) ekran genişliğine göre üç kademede ayarlanıyor (`< 600`, `< 780`, `≥ 780` dp eşikleri). Hem **MediaKit** hem de **Better Player** OSD'leri için uyumlu.

## 2.0.71 (build 4071)

- **Kanal ön eki mantığı yeniden tasarlandı:** Artık yalnızca **ülke ön ekleri** (TR:, EN:, US:, BR:, RU:, SP:, [TR] vb.) temizleniyor. Kalite / etiket bilgileri (HD, SD, FHD, UHD, HEVC, H.265, H.264, 4K, 8K, VIP, PPV, LIVE, MULTI, ALT, SY …) artık **olduğu gibi korunuyor** — kullanıcı yayını açmadan kanalın kalitesini görebilsin diye. Sondaki tag'lere (örn. «… [HD]») de dokunulmuyor. Whitelist tabanlı `_isCountryCode` kontrolü ile yanlış pozitifler (`VIP:`, `HD:`, `SD:` gibi tokenler artık ülke kodu sayılmıyor) engellendi.

## 2.0.70 (build 4070) — Play Store sürümü

Bu sürüm; son birkaç güncellemeyle Film & Dizi (VOD) ekranında yapılan tüm modernizasyon çalışmasını tek bir mağaza paketi (AAB) hâlinde toparlar.

- **Sinematik Hero Banner Carousel** (Film + Dizi sekmeleri): Sayfanın en üstünde tam genişlikte 16:9 banner; ilk 5 öne çıkan film/dizi, otomatik geçiş (6 sn), sayfa noktaları, **İzle** + **Detay** butonları. Diziler için aynı carousel `FilmDiziHeroSlide` ortak modeliyle çalışıyor; puan satırı dizi için otomatik gizleniyor.
- **Buzlu cam (Glassmorphism) kategori blokları + neon vurgu:** Eski koyu yeşil kart yapısı kaldırıldı; her kategori (Örn: «EN YENİLER 2025») şeffaf, blur'lu (9–14) bir panelde. Sol-üstte ince tema-renkli neon vurgu çubuğu + zarif başlık tipografisi (letter-spacing 1.1) + «Tümünü Gör». Listenin sağ/sol kenarlarında **fade-in/out maskesi**, bloklar arası dikey **24 dp** boşluk.
- **Yenilenen poster afişi:** Afişin sol-üstündeki yuvarlak IMDb rozeti kaldırıldı; yerine **sağ-alt köşeye** «sarı yıldız + IMDb + puan» kapsül rozeti. Sağ-üstteki favori kalp daha küçük (16 dp), arka plansız, hafif gölgeli — afişin üzerine bindirmeden zarif. Afiş altı film/dizi adı **tek satır gri** ellipsis (kompakt label).
- **Film & Dizi sekme barında arama butonu:** Film/Dizi kapsülleri arasına küçük cam arama butonu eklendi. Bu butondan açılan dialog:
  - **Sadece film + dizi** sonuçları gösterir (canlı TV gizli — `excludeLive: true`).
  - Bir sonuç seçildiğinde eski «Browse» listesine değil, doğrudan **yeni Film & Dizi detay sayfası**na yönlendirir (`onVodPick` / `onSeriesPick` callback'leri).
- **Ek polish:** Eski «Film & Dizi» tam genişlik başlığı kaldırıldı; sol-üstte minimal cam geri pili. Genel akıcı kaydırma, başlık tipografisi, dikey boşluk hiyerarşisi yeniden düzenlendi.

## 2.0.69 (build 4069)

- **Film & Dizi araması → yeni detay sayfaları:** Sekme barındaki arama butonundan açılan dialog'ta bir film/dizi seçildiğinde artık eski «Browse» listesine değil, doğrudan yeni Film & Dizi **detay sayfasına** gidiliyor. Birleşik arama dialog'una opsiyonel `onVodPick` / `onSeriesPick` callback'leri eklendi.

## 2.0.68 (build 4068)

- **Film & Dizi araması — sadece film + dizi:** Film & Dizi sayfasındaki sekme barındaki arama butonuna basıldığında artık canlı TV sonuçları listelenmiyor; sadece film ve dizi sonuçları gösteriliyor. Birleşik arama dialog'una opsiyonel `excludeLive` bayrağı eklendi (ana ekrandaki birleşik arama hâlâ tüm kaynakları gösteriyor).

## 2.0.67 (build 4067)

- **Dizi sekmesi modernize:** Film sekmesinde yapılan tüm görsel iyileştirmeler dizi sekmesine de uygulandı. Üstte aynı sinematik Hero Banner carousel'i (ilk 5 yeni eklenen dizi; otomatik geçiş, sayfa noktaları, İzle/Detay butonları). Kategori blokları aynı buzlu cam (BackdropFilter) + neon vurgu paneliyle render ediliyor; başlık tipografisi, kenar fade-in/out, dikey 24 dp boşluk ve kompakt gri poster etiketi de bire bir aynı.
- **Ortak hero modeli:** `FilmDiziHeroSlide` modeli sayesinde hero banner artık VOD ve dizi için tek tip — diziler IMDB puanı taşımadığı için puan satırı otomatik gizleniyor.

## 2.0.66 (build 4066)

- **Kategori blokları — Glassmorphism + neon vurgu:** Eski koyu yeşil kart yapısı kaldırıldı; her kategori (Örn: «EN YENİLER 2025») artık şeffaf, buzlu cam (BackdropFilter blur 9–14) bir panelde. Sol üstte ince tema-renkli neon vurgu çubuğu + zarif başlık + «Tümünü Gör». Akrilik beyaz gradyan dolgu (alpha 0.10 → 0.03), hafif accent gölge.
- **Poster IMDB rozeti yenilendi:** Afişin sol-üstündeki yuvarlak puan rozeti kaldırıldı. Yerine afişin sağ-alt köşesine (film isminin hemen üstüne) **sarı yıldız + «IMDb» + puan** yatay kapsül rozet eklendi.
- **Favori kalp zarifleşti:** Sağ üst köşedeki favori ikonu artık daha küçük (16 dp), arka plansız, hafif gölgeli — afişin üzerine bindirmeden zarif duruyor.

## 2.0.64 (build 4064)

- **Film & Dizi — sinematik Hero Banner:** Sayfanın en üstündeki «Yeni Eklenen Filmler» yatay listesi, tam genişlikte kayan kahraman afiş carousel'i ile değiştirildi. İlk 5 öne çıkan film (IMDb puanı olanlar önceliklidir) 16:9 oranında, üzerinde başlık + yıldız puanı + «İzle» / «Detay» butonları ile sergileniyor. Otomatik geçiş (6 sn) + animasyonlu sayfa noktaları + dokunulduğunda durur.
- **Kategori blokları modernize:** Kategori başlıkları («EN YENİLER 2025» vb.) koyu yeşil kart yapısından çıkarıldı; doğrudan sayfa arka planı üzerinde daha zarif tipografiyle (1.1 letter-spacing). Yatay listenin sağ/sol kenarlarında **fade-in/out maskesi** ile akıcı görsel; bloklar arası dikey boşluk 14 → **24 dp**.
- **Poster etiketleri (kompakt):** Posterlerin altındaki film/dizi isimleri tek satıra düşürüldü (ellipsis), gri ton, hafifçe daha küçük yazı — sayfa daha temiz nefes alıyor.

## 2.0.63 (build 4063)

- **Film & Dizi — sekme arası arama:** Film/Dizi sekme kapsüllerinin arasına küçük cam arama butonu eklendi. Dokununca birleşik arama dialog'u (canlı + film + dizi) açılır. Sekme genişliklerini bozmadan tasarıma entegre.

## 2.0.62 (build 4062)

- **Film & Dizi — üst başlık kaldırıldı:** Tam ekran «Film & Dizi» sayfasındaki yeşil/cam başlık çubuğu tamamen kaldırıldı; ekran daha temiz ve içerik (Film/Dizi sekmesi, şeritler) için daha fazla alan var. Sol üst köşede minimal yarı saydam yuvarlak geri butonu kaldı.

## 2.0.61 (build 4061)

- **Oyuncu detay — Filmler:** Kart tıklamaları artık `GestureDetector(opaque)` ile garantili çalışıyor. Eşleştirmede artık tüm playlist VOD'ları (gizli kategoriler dahil) taranıyor; kelime kümesi tabanlı Jaccard skoru, Türkçe karakter normalizasyonu (`şŞıİğçÇöÖüÜ`) ve ±1 yıl toleransı eklendi. Eşleşme bulunmazsa kullanıcıya **toast** bildirimi (snackbar yerine, daha güvenilir).

## 2.0.60 (build 4060)

- **Oyuncu detay — Filmler:** TMDB filmografisindeki filme dokununca playlist’te eşleşen VOD bulunup film detayına gidiliyor; eşleşme yoksa bilgilendirme snackbar’ı.

## 2.0.59 (build 4059)

- **TV OSD otomatik gizleme — 3 sn seçeneği:** Ayarlar → «TV OSD otomatik gizleme» listesine `3 sn` eklendi (3, 5, 7, 10, 15, 20). Varsayılan 7 sn olarak korundu.

## 2.0.58 (build 4058)

- **Xtream EPG — ilk yüklemede de aktif:** Playlist eklendikten sonra (M3U → Xtream akıllı dönüşüm dahil) Xtream EPG'si arka planda otomatik indiriliyor; kullanıcı uygulamayı yeniden başlatmak zorunda kalmadan EPG'yi görüyor. Sonuçlar diske `persistSnapshotToDisk` ile yazılır, bir sonraki splash anında hazır. `XtreamEpgSourceMode.githubOnly` modunda atlanır; throttling/in-flight paylaşımı sayesinde çift indirme olmaz.

## 2.0.57 (build 4057)

- **Akıllı M3U → Xtream dönüşümü:** Playlist eklerken girilen M3U URL'si Xtream parametreleri (`username/user/auth` + `password/pass/auth_password`) içeriyorsa, arka planda otomatik olarak `XtreamSource`'a çevrilip Xtream API üzerinden yükleniyor. Sonuç: EPG/VOD/Series uçları aktif, çok daha hızlı ve hafif yükleme; URL düz M3U ise eski davranışla devam ediliyor. Birincil ve ikincil kaynaklarda etkin.

## 2.0.56 (build 4056)

- **Ayarlar — modern liste:** «01/02/03» numaraları kaldırıldı; her satırda sol başta işlevsel ikon (cam kapsül). Ayar kartlarında cam opaklığı ve blur hafifletildi — özellikle Yeşil Cam temasında duvar kağıdı daha görünür.
- **Film & Dizi — detay cilası:** «İzle» düğmesinde yuvarlak oynat ikonu, yumuşak köşeler ve tema renginde neon gölge. Oyuncular şeridinde ad ile rol arasında boşluk (film + dizi). Özet metni satır yüksekliği 1.4 ile daha okunaklı.

## 2.0.55 (build 4055)

- **Kanal ön eki temizliği genişledi:** `EpgChannelDisplay.name()` artık yalnızca ülke kodları (TR:, BR:, [EN] …) değil, kalite/etiket öneklerini de kaldırıyor — `Full HD:`, `FHD:`, `HD:`, `SD:`, `UHD:`, `4K (UHD):`, `8K:`, `HEVC:`, `H.265:`, `H.264:`, `VIP:`, `LIVE:`, `SY:`, `BACKUP:`, `ALT:`, `MULTI:`, `PPV:`. Zincirleme önekler tek seferde temizlenir (ör. `TR: Full HD: beIN SPORTS 3` → `beIN SPORTS 3`). Sondaki kalite tag'i de («… Full HD», «… [HD]») bir kez çıkarılır.
- **Uygulanan yerler:** Ana ekran «İzlemeye Devam Et» (VOD başlığı + önerilen canlı kanal başlığı), Karışık Canlı TV şeridi ve Canlı TV kanal listesi — Ayarlar → «Kanal ön eki» tek anahtarla kontrol ediyor.
- **Kurulum sihirbazı — Özellikler:** «Kanal ön eki kaldır» anahtarı eklendi (Karışık Canlı TV ile Adaptif titreşim arasında); ilk kurulumda kullanıcı tercihi hemen alınıyor.

## 2.0.54 (build 4054)

- **Adaptive titreşim — Samsung uyumu:** One UI'ın `CLOCK_TICK` sabitini yok saymasından kaynaklanan «titreşim çalışmıyor» sorunu giderildi. Android'de doğrudan `Vibrator`/`VibratorManager` köprüsü ile `EFFECT_TICK` (API 29+) veya `createOneShot(12 ms, 80)` tetikleniyor; köprü uygunsuz olduğunda `lightImpact` (VIRTUAL_KEY) fallback'ine düşülüyor. A–Z hızlı kaydırma çubuğu da aynı servise yönlendirildi.
- **Performans (EPG dışı):** Ana ekran kart sayım getter'larında (Canlı / Film / Dizi / Film & Dizi) Obx tetiklemesi başına 5000+ öğe taraması yerine scope tabanlı tek geçişli cache. Karışık Canlı TV şeridi her render'da O(N×kategori) gizleme aramalarını O(1) map lookup'a düşürdü; chip render'ı için `id → kanal` haritası. Gizli kategori `Set<int>/Set<String>` allocation'ları revizyon değişene kadar paylaşılan tek instance'a indirildi. Sonuç: ana ekran tazelemesinde belirgin daha az jank ve GC baskısı.

## 2.0.53 (build 4053)

- Play Store yayın paketi (AAB).

## 2.0.52 (build 4052)

- **Canlı TV — Kanallar (portre):** EPG programı kanal adının altında; küçük yazı; program adı + başlangıç saati.

## 2.0.51 (build 4051)

- **Canlı TV — Kanallar (portre):** EPG parantezsiz; kanal adı solda, program metni sağda (logo yönü) hizalı; arada boşluk; kaydırma yalnızca programda.

## 2.0.50 (build 4050)

- **Canlı TV — Kanallar (portre):** Kaydırma yalnızca parantez içindeki EPG programında; kanal adı sabit kalır (sığmazsa program … / yavaş kaydırma).

## 2.0.49 (build 4049)

- **Oynatıcı (mobil/tablet):** Parlaklık yalnızca sol kenar, ses yalnızca sağ kenar; ortada dikey kaydırma ses/parlaklığı tetiklemez; iki parmak zoom daha güvenilir (portre OSD katmanı çoklu dokunuşta devre dışı).
- **Canlı TV — Kanallar (portre):** Liste satırında kanal adı + güncel EPG programı; uzun başlıkta yavaş kaydırma.
- **Ayarlar:** «Kanal ön eki» — isteğe bağlı ülke öneklerini gizle (TR:, BR: vb.; varsayılan kapalı).

## 2.0.48 (build 4048)

- **Film & Dizi:** Tam bölüm (film/dizi sekmeleri, yeni eklenenler, kategori satırları); detayda poster yanında IMDb, süre, tür ve teknik rozetler (Xtream → OMDB/TMDB); cam «İzle» düğmesi; yüklemede yanıp sönen cam iskelet.
- **Film & Dizi — Tümünü gör:** A–Z sıralı liste; sağ kenarda sürüklenebilir harf indeksi; sürüklerken aktif harf balonu.
- **Dizi detay:** Film detayıyla aynı cam «1. bölümü izle» düğmesi.
- **Canlı TV — EPG menüsü:** Kanal adlarından ülke önekleri kaldırıldı (TR:, BR: vb.); boş program dilimlerinde çerçeve yok; yazı boyutu küçültüldü; dar kutularda dinamik satır.
- **Canlı TV — portre detay:** Seçili kanalın kategorisindeki diğer kanallar (logo + doğrudan oynatma).
- **Oynatıcı (mobil/tablet):** İki parmakla yakınlaştırma/kaydırma (%100–%400); sol üstte zoom yüzdesi ve konum göstergesi; «Sıfırla (1:1)»; kanal/içerik değişince otomatik sıfır.
- **Ayarlar — EPG:** «EPG bilgileri güncelleme» kaldırıldı; yeni EPG menüsü (rehber durumu, yenileme, 12/24 saat, saat dilimi, kaynak yönetimi / XMLTV eşleştirme).
- **Ayarlar:** «Bulanıklığı kapat» seçeneği kaldırıldı; «İçerikleri yenile» varsayılanı haftada bir (7 gün).
- **TV gözat — film detay:** Hatalı «Ses» rozetleri kaldırıldı.

## 2.0.35 (build 4035)

- **Önerilen Filmler:** Kahraman posteri kaydırınca kaybolma düzeltmesi (OMDB boş poster, OMDb yenilemede rastgele kahraman değişimi).
- **Play Store:** Google Play kurulumunda, puanlamayan kullanıcıya günde bir kez yıldız değerlendirme diyaloğu.

## 2.0.34 (build 4034)

- **Önerilen Filmler:** 4K / UHD satırı; tümünü gör üst çubukta başlık ve arama ikonu okunabilirliği (buzlu temalar).

## 2.0.33 (build 4033)

- **Önerilen Filmler:** Cam UI (tema duvar kağıdı, cam üst çubuk ve paneller); renkler seçili temaya uyumlu.

## 2.0.32 (build 4032)

- **Tümünü gör:** Gri üst çubuk düzeltmesi, çalışan geri, cam arama ile film filtreleme.
- **Dizi detay:** Önce klasik önizleme; «Detaylara Git» ile yeni detay arayüzü.

## 2.0.31 (build 4031)

- **Önerilen Filmler:** Kahramanda Oynat + Favori hizalı; «Tümünü gör» kategori poster ızgarası (yatay mod); 17 dilde Oynat metni.

## 2.0.30 (build 4030)

- **Önerilen Filmler:** Ana ekran kartı ve tam ekran bölüm (mobil/tablet); lazy yükleme ve yanıp sönen iskelet; 17 dil.
- **Ana ekran kart sırası:** Önerilen Filmler kartı sıralama editörüne eklendi.

## 2.0.29 (build 4029)

- **Dizi detay (dikey):** Yeni kapak, IMDb/tarih/sezon, sezon seçimi, bölüm kartları; Xtream veya OMDB meta; bölüm indirme ve oynatma.

## 2.0.28 (build 4028)

- **Fly UI:** Flyme tarzı yeni tema — buzlu cam, mavi vurgu, yatay/dikey duvar kağıtları; mobil kurulum sihirbazında seçilebilir.
- **Cam popup’lar:** Seçenek listelerinde koyu panel ve yüksek kontrast; Tema, Dil, Düzen, OSD süresi, adaptif kalite vb. diyaloglarda İptal + Kaydet; İçerikleri yenile’de İptal + Şimdi yenile.
- **Kaydırma:** Mobilde iOS tarzı bounce; TV’de clamp.
- **Ana ekran:** Kart sırası düzenleme (Canlı TV, film, dizi, EPG Mix, favoriler).
- **EPG Mix:** Canlı TV cam stili liste; kategori çipleri; okunabilirlik iyileştirmeleri.
- **Varsayılan:** Adaptif titreşim ilk kurulumda açık.

## 2.0.27 (build 4027)

- **Cam popup’lar:** Seçenek listelerinde daha koyu zemin ve okunaklı yazı; Tema, Dil, Düzen ve benzeri diyaloglarda İptal + Kaydet alt düğmeleri.

## 2.0.26 (build 4026)

- **Fly UI:** Yeni Flyme tarzı tema (buzlu cam, mavi vurgu, özel duvar kağıtları).
- **Kurulum sihirbazı:** Fly UI mobil tema adımında (alt başlık ile).

## 2.0.25 (build 4025)

- **Kaydırma:** Kanal, film, dizi, favori, EPG Mix ve diğer listelerde mobilde iOS tarzı yay (bounce) efekti; TV modunda clamp korunur.

## 2.0.24 (build 4024)

- **Ayarlar:** Ana ekran kart sırası — Canlı TV, film, dizi, EPG Mix ve favori kartlarını sıralama (DPAD destekli).
- **EPG Mix:** Liste kartları Canlı TV kategori cam stiline uyarlandı; okunabilirlik artırıldı.
- **Varsayılan:** Adaptif titreşim ilk kurulumda açık kaydedilir.

## 2.0.23 (build 4023)

- **EPG Mix:** Yayın hatırlatıcısı ve bildirim izinleri geçici olarak kaldırıldı (kararlılık için).

## 2.0.22 (build 4022)

- **EPG hatırlatıcı:** İzin önbelleği artık otomatik silinmiyor; 2.+ hatırlatıcıda izin tekrar istenmez. Zamanlama `inexact` modlarıyla daha uyumlu.

## 2.0.21 (build 4021)

- **EPG hatırlatıcı:** İzin önbelleği artık yanlışlıkla silinmiyor; her hatırlatıcıya benzersiz bildirim kimliği.
- **EPG Mix:** Kategori kaydırınca üst çipler seçili kategoriye kayar.
- **Ana ekran:** Kart sırası Canlı TV → Film → Dizi → EPG Mix → Favoriler.

## 2.0.20 (build 4020)

- **Kurulum sihirbazı:** Özellikler adımına Karışık Canlı TV, açılışta başlat, PiP, EPG güncelleme (1–4 gün); ayrı adımda uygulama fontu seçimi.
- **Karışık Canlı TV:** Ana ekran şeridi ayarlardan ve sihirbazdan kapatılabilir.

## 2.0.19 (build 4019)

- **EPG Mix:** Kategoriler arası sola/sağa kaydırma (mobil/tablet).
- **EPG Mix hatırlatıcı:** Bildirim izni önbelleği (MIUI); planlama yedek modu; kaldırma init sonrası da çalışır.

## 2.0.18 (build 4018)

- **Kurulum sihirbazı — Özellikler:** Sıradaki Maçlar ve Adaptif titreşim dar iOS tarzı anahtar satırları (CupertinoSwitch).

## 2.0.17 (build 4017)

- **Adaptif titreşim (mobil):** Liste kaydırırken ve öğe seçerken hafif titreşim; Ayarlar’da açılıp kapatılabilir.

## 2.0.16 (build 4016)

- **EPG Mix hatırlatıcı — izin:** Bildirim izni verildikten sonra tekrar istek/ayarlar açılmaz; izin durumu önce kontrol edilir.
- **Zamanlanmış bildirimler:** `flutter_local_notifications` alıcıları manifest’e eklendi; cihaz saat dilimi doğru ayarlanır.

## 2.0.15 (build 4015)

- **EPG Mix — Hatırlat düzeltmesi:** Hatırlat butonu liste satırının oynatma dokunuşundan ayrıldı; basınca haptic + toast/snackbar geri bildirimi.

## 2.0.14 (build 4014)

- **EPG Mix — Hatırlat iyileştirmesi:** Aktif hatırlatıcıda belirgin ikon ve «Hatırlatmayı kaldır» metni; eklendi/kaldırıldı toast mesajları.
- **Bildirim izni:** Hatırlat’a basıldığında Android’de sistem izin diyaloğu; gerekirse uygulama bildirim ayarlarına yönlendirme.

## 2.0.13 (build 4013)

- **Sıradaki Maçlar anahtarı:** Ayarlar ve mobil kurulum sihirbazında açılıp kapatılabilir; kapalıyken ana ekran şeridi gizlenir.
- **TV kumanda:** Sıradaki Maçlar şeridinde İzlemeye Devam Et / rastgele canlı öneri ile aynı D-pad akışı (yukarı/aşağı, OK ile oynat).
- **EPG Mix hatırlatıcı:** Yayın satırında «Hatırlat»; yayın başlamadan 30 dk önce yerel bildirim (Android bildirim izni gerekir). TV’de sağ odak + OK.

## 2.0.12 (build 4012)

- **Açılış akışı:** Splash en az ~1,4 sn görünür; durum metinleri (liste, program rehberi, neredeyse hazır). Ağır EPG indirmeleri (global rehber, XMLTV/Xtream ağı) ana ekrana geçtikten ~2 sn sonra arka planda yapılır; diskten EPG önbelleği splash’te hazırlanır. Ana ekranda EPG Mix rozeti ve Sıradaki Maçlar taraması kısa süre ertelenir — ilk açılış takılması azaltıldı.
- **Sıradaki Maçlar — yükleme göstergesi:** EPG gelene kadar gerçek çiplerle aynı boyutta yanıp sönen cam placeholder kartlar ve «Program rehberi yükleniyor…» metni.
- **Sıradaki Maçlar — kararlılık:** Liste sırası karıştırıldıktan sonra sürekli yenileme döngüsü giderildi.

## 2.0.11 (build 4011)

- **Sıradaki Maçlar:** Ana ekranda karışık canlı TV şeridinin hemen altında yeni yatay şerit. EPG’den spor sınıflandırmasıyla eşleşen sıradaki yayınlar, karışık canlı TV ile aynı cam çerçeve boyutlarında gösterilir (program adı, saat ve kanal). Çipe dokununca ilgili kanal oynatılır.

## 2.0.10 (build 4010)

- **SEMC Theme:** Sony SEMC tarzı koyu yüzeyler, yeşil vurgu (`#00C989`), cam paneller ve 18px kart köşeleri. Yatay/dikey tam çözünürlüklü arka planlar (`semc_landscape.jpg`, `semc_portrait.jpg`). Ayarlar → Tema ve kurulum sihirbazına eklendi (`theme.semcTheme`).
- **EPG Mix:** Ana ekranda beşinci kart; Spor, Belgesel, Film, Dizi ve Haber kategorilerinde sıradaki yayınları listeler. Telefon, tablet ve TV’de açılır; TV’de D-pad ile kategori ve satır odakları.
- **Global EPG (M3U):** Özel XMLTV URL’si yoksa varsayılan **iptv-org** rehberi (~günde bir güncelleme); programlar SQLite’da saklanır, kanal adları eşleştirilerek EPG Mix ve zaman çizelgesine beslenir.
- **Canlı kanal listesi düzenleyici:** Ayarlar’dan kategori seçerek kanalları sıralama ve listeden çıkarma (yalnızca canlı TV; tercihler kaynak anahtarına göre kalıcı).
- **Ana ekran tarih satırı:** Saat altındaki kısa tarih artık uygulama diline göre (`formatAppShortDateLine`); her dilde sabit Türkçe kısaltma sorunu giderildi.
- **Google Play değerlendirme:** Play sürümünde güncelleme sonrası cam diyalog ile mağaza sayfasına yönlendirme.
- **Uygulama simgesi:** Android ve iOS launcher ikonları güncellendi.

## 2.0.6 (build 4006)

- **Mina Glass teması:** Samsung One UI tarzı mavi vurgu, daha geniş köşe yarıçaplı kartlar ve cam paneller. Yatay modda `mina_glass_landscape.png`, dikey modda `mina_glass_portrait.png` tam ekran arka plan. Ayarlar → Tema ve **kurulum sihirbazı** tema adımına eklendi; çoklu dil anahtarı `theme.minaGlass`.
- **Canlı TV — akış hatası sonrası sıradaki kanal:** Otomatik geçiş artık playlist sırasıyla aynı kategorideki listeyi kullanıyor (`sortOrder` sapması giderildi). Ana sayfa karışık canlı şerit tercihleri **kanal ID** ile saklanıyor; aynı URL’nin birden fazla satırda olması yanlış kategori/kanala atlama yapmıyor.
- **Oynatıcı OSD:** Otomatik kanal değişiminde (ağ/hata kurtarma) OSD metni ve şerit yeni kanalla güncellenir; kanal değişim bayrağı `try/finally` ile her durumda sıfırlanır, TV OSD otomatik gizleme zamanlayıcısı doğru zamanda kurulur; Better özel kontroller `Obx` + `ValueKey` ile kanal değişiminde yenilenir; canlıda `prepareLiveChannelStrip()` ile şerit sekmesi hizalanır.

## 2.0.4 (build 4004)

- **EPG Zaman Çizelgesi Yeniden Tasarımı:** Dikey modda EPG menüsü için görsel iyileştirmeler yapıldı. Okunabilirliği artırmak ve metin taşmasını önlemek amacıyla program ve kanal satır yükseklikleri dinamikleştirildi, font boyutları ayarlandı ve glass estetiğine uygun gölgeler eklendi.
- **Ana Ekran Yaklaşan Sporlar UI Düzenlemesi:** Ana ekrandaki "Yaklaşan Sporlar" bölümündeki dikdörtgen çerçevelerin genişliği %50 oranında daraltıldı. Metin okunabilirliğini korumak için font boyutları yeniden düzenlendi.


- **Kaynaklar:** M3U / M3U8 (URL veya yerel dosya), **Xtream Codes** API; birincil ve isteğe bağlı ikinci kaynak.
- **Canlı TV:** Kategori ve kanal listesi, arama, favoriler, yatay/dikey ve **Android TV** kumanda odakları; hızlı kanal şeridi ve cam OSD.
- **VOD ve diziler:** Gözatma, önizleme, **kaldığın yerden devam**, otomatik sıradaki içerik; MediaKit ve Better Player (ExoPlayer).
- **EPG:** XMLTV ve Xtream EPG; tam ekran zaman çizelgesi; **catch-up / arşiv** için panel şablonu (timeshift yolu, `timeshift.php`, özel URL).
- **Kategori gizleme:** Xtream’de panel kategori ID’leri; M3U’da **group-title** (normalize ad) — canlı, film ve dizi sekmeleri.
- **Ebeveyn denetimi:** PIN ile korunan kategori gizleme ekranı.
- **Görseller:** Kanal logoları için **yerel disk önbelleği** (indirme, yeniden boyutlandırma, sınırlı paralel ön yükleme); liste kaydırmada daha az ağ yükü.
- **Ayarlar:** Tema (cam), dil, canlı tampon, HLS/DASH **adaptif kalite tavanı**, altyazı punto (MediaKit), PiP (telefon), düşük performans modu, decoder tercihi, uyku zamanlayıcısı, vb.

---

## 1.9.20 (build 3119)

- **Gözlemlenebilirlik (production):** İsteğe bağlı **Sentry** entegrasyonu (`--dart-define=SENTRY_DSN=...`). DSN verilmezse SDK başlatılmaz.
- **Sorun bildir:** E-posta gövdesine otomatik tanı özeti eklendi (uygulama sürümü, paket adı, cihaz/OS, düzen ve dil). `device_info_plus` kullanıldı.
- **Ayarlar:** “Yardım & Destek” yerine **Telegram Adresimiz**; altına **Sorun Bildir** kartı (`mailto:furkangumrukcu07@gmail.com`). Sentry aktifken kullanıcı bildirimi breadcrumb olarak işlenir.
- **Android derleme:** Flutter eklentilerinde eski Kotlin dil hedefinden kaynaklanan derleme uyarısı için kök `build.gradle.kts` ile Kotlin dil/API hedefi hizalandı (`sentry_flutter` dahil).

## 1.9.19 (build 3118)

- **Dikey OSD (Better):** VOD/dizi modunda `HQ`, dil ve altyazı aksiyonlarının popup akışı güçlendirildi.
- **Dikey/Yatay OSD (MediaKit):** canlı yayında `CC` altyazı ikonu gizlendi.
- **Dikey OSD buton sırası:** oynatıcı geçiş butonu (`M`/`B`) en sağa taşındı.
- **VOD altyazı tercihi:** seçilen altyazı dili kalıcı hale getirildi; sonraki film/dizilerde otomatik uygulanır.
- **Kararlılık:** quality/audio/subtitle menülerinde seçenek yok durumları popup bilgi ekranı ile tutarlılaştırıldı.

## 1.9.18 (build 3117)

- **Mobil kurulum sihirbazı:** Son adımda “Kurulumu bitir” artık M3U dosya/URL veya Xtream bilgileri girildiyse otomatik liste yüklemeyi tetikler.
- **Kurulum tamamlama akışı:** Liste başarıyla yüklendiğinde doğrudan ana ekrana geçiş sağlandı.
- **Tema güncellemesi:** Mor tema/vurgu renkleri global olarak `#21E6EB` rengine taşındı.
- **Ana ekran görsel iyileştirme:** Kartlarda ince beyaz kenarlık + iç gölge ile cam hissi güçlendirildi (dinamik arka plan efekti kaldırıldı).
- **OSD düzenlemeleri:** Dikey/yatay OSD’de canlı yayın için `CC` ikonları gizlendi; motor geçiş (`M`/`B`) butonları sıranın sonuna alındı.
- **Kalite/Ses/Altyazı menüleri:** Dikey Better OSD’de `HQ`, dil ve altyazı aksiyonlarının popup akışı düzeltildi.
- **VOD altyazı tercihi:** Varsayılan altyazı seçimi etkinleştirildi; kullanıcı seçtiği altyazı dili sonraki film/dizilerde otomatik uygulanır.

## 1.9.17 (build 3116)

- **Dil desteği genişletildi:** Portekizce (`pt`) ve Endonezce (`id`) eklendi.
- **İlk kurulum sihirbazı:** Mobil setup dil adımına Portekizce ve Endonezce seçenekleri dahil edildi.
- **Ayarlar dil menüsü:** Uygulama dili listesindeki yeni diller seçilebilir hale getirildi.
- **Locale eşleme:** Cihaz dili algılama (`languageCodeFromDeviceLocale`) ve `supportedLocales` yeni dilleri kapsayacak şekilde güncellendi.
- **i18n sözlükleri:** Yeni diller için çeviri partial map’leri eklendi; eksik anahtarlar İngilizce fallback ile güvenli çalışır.

## 1.9.16 (build 3115)

- **Ayarlar — oynatıcı motoru kartı:** “MediaKit kullan” satırı daha anlaşılır hale getirildi; açıklama metni Better Player / MediaKit seçim durumunu net gösterir.
- **Ayarlar — uygulama fontu seçimi:** Yeni “Uygulama Fontu” kartı eklendi. Seçim tüm uygulama metinlerine uygulanır ve kalıcı olarak saklanır.
- **Font seçenekleri:** Sony (TV tarzı), Roboto, Noto Sans ve Monospace seçenekleri eklendi (telif riski olmayan / açık lisanslı aileler).
- **TV D-pad odak:** Font seçim menüsünde satırlar ile İptal/Kaydet aksiyonları kumandayla tam odaklanabilir hale getirildi.
- **Dikey detay önizleme görseli:** Köşe yumuşatma ile çakışan üst keskin gölge/gradient katmanı düzeltildi; önizleme paneli ile uyumlu clipping sağlandı.
- **Dikey oynatıcı OSD:** Yayın yüzeyi açılmasa bile mevcut OSD paneli ve butonları görünür kalacak şekilde koşullar düzeltildi.
- **Ayarlar görsel tutarlılık:** 16 ve 17. kartların sağ üst göstergeleri, uygulamadaki diğer ayar kartlarıyla aynı ikon diline geri alındı.

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
