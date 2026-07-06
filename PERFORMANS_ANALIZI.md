# Mina IPTV Player — Performans Analizi Raporu

**Proje:** Mina IPTV Player v2.13.23+4369
**Analiz Tarihi:** 2026-06-25 01:01
**Analiz Eden:** Kimi Work (AI Kod Analizi)

---

## 🔴 KRİTİK (Hemen Düzeltilmeli)

### 1. PlayerController 7.456 satır — Tek devasa dosya
**Dosya:** `lib/modules/player/player_controller.dart`
**Etki:** Bellek tüketimi, init süresi, bakım zorluğu, build süresi artışı
**Detay:** GetX controller tek bir dosyada 7456 satır. Her route geçişinde tüm controller init ediliyor. Memory footprint büyük. Öneri: Controller'ı 3-4 parçaya böl (PlayerPlaybackController, PlayerUiController, PlayerNavigationController).

### 2. BrowseController 4.565 satır
**Dosya:** `lib/modules/browse/browse_controller.dart`
**Etki:** UI thread blokajı, ANR riski
**Detay:** Filtreleme, sıralama, arama, TV navigasyonu hepsi tek controller'da.

### 3. 15+ Timer.periodic aynı anda çalışabilir
**Dosya:** `player_controller.dart, player_view.dart, channels_controller.dart, vb.`
**Etki:** CPU pil tüketimi, arka planda çalışma, ANR
**Detay:** PlayerController'da: UI timer (250ms), live stall poll (2sn), auto-next (3sn), watch progress (12sn), history tick (15sn), VOD autoplay (1sn), VOD countdown. Aynı anda 5-6 timer çalışabilir.

### 4. 57+ addPostFrameCallback kullanımı
**Dosya:** `Çok sayıda dosya`
**Etki:** Frame düşüşü, jank, UI thread şişmesi
**Detay:** TV navigasyonunda her D-pad hareketi için addPostFrameCallback çağrılıyor. Özellikle tv_shell_controller.dart ve channels_controller.dart'da yoğun.

### 5. Image.network direkt kullanımı (cached_network_image yerine)
**Dosya:** `lib/modules/home/widgets/home_showcase_view.dart`
**Etki:** Ağ tüketimi, bellek, OOM, yavaş görsel yükleme
**Detay:** pubspec.yaml'da cached_network_image bağımlılığı var ama bazı yerlerde Image.network kullanılıyor. Görsel cache'lenmiyor, her rebuild'de yeniden indirilebilir.

## 🟡 ORTA (İyileştirme Önerilir)

### 1. setState kullanımı GetX projesinde (~30 dosya)
**Etki:** Gereksiz widget rebuild'leri, performans düşüklüğü
**Detay:** GetX projesinde StatefulWidget + setState kullanımı anti-pattern. Özellikle tv_media_kit_player_controls.dart, tv_better_player_controls.dart, player_view.dart gibi kritik widget'larda.

### 2. ListView (builder olmayan) kullanımı
**Dosya:** `settings_view.dart, player_view.dart, browse_view.dart, vb.`
**Etki:** Büyük listelerde tüm öğeler aynı anda build edilir, bellek şişer
**Detay:** ListView.builder yerine düz ListView kullanımı. Küçük listelerde sorun yok ama EPG, kanal listesi, film listesi gibi 1000+ öğe olan yerlerde ciddi.

### 3. GetMaterialApp Obx içinde — tam uygulama rebuild'i
**Dosya:** `lib/main.dart (satır 125-219)`
**Etki:** Dil/tema/font değiştiğinde TÜM uygulama yeniden build olur
**Detay:** Obx(() => GetMaterialApp(...)) içinde. settings.languageCode, themeLabel, appFontFamilyKey değiştiğinde MaterialApp'in tamamı rebuild olur. Bu normalde kabul edilebilir ama theme değişimi sırasında tüm tree maliyetli.

### 4. HomeController getter'ları her Obx tick'inde pahalı işlem yapıyor
**Dosya:** `lib/modules/home/home_controller.dart (satır 375-400)`
**Etki:** Ana ekran kartları sürekli hesaplanıyor, jank
**Detay:** homeLiveCount, homeFilmsCount gibi getter'lar her çağrıda _ensureHomeCountsFresh() çağırıyor. Obx ile dinleniyor. 5000+ kanal/dizi üzerinde her tick'te döngü yapılabilir.

### 5. BetterPlayer + MediaKit çift motor aynı anda tutuluyor
**Dosya:** `player_controller.dart`
**Etki:** Bellek çift katına çıkabilir, OOM
**Detay:** Birisi aktifken diğeri dispose edilmiyor mu? Controller'da both better ve mediaKitPlayer alanları var. Transition'larda memory leak riski.

### 6. Unified Timer yorumu ama implemente edilmemiş
**Dosya:** `player_controller.dart (satır 946-955)`
**Etki:** Timer sayısı artmaya devam ediyor
**Detay:** '--- UNIFIED TIMERS ---' yorumu var ama _uiTimer, _networkTimer, _progressTimer tanımlı sadece, kullanılmıyor. Hala 10+ ayrı timer var.

## 🟢 HAFİF / DİKKAT ÇEKEN

### 1. 17 ayrı locale initializeDateFormatting açılışta
**Dosya:** `main.dart (satır 41-55)`
**Etki:** Açılış süresi ~50-100ms uzayabilir
**Detay:** Future.wait ile paralel ama 17 locale init yine de maliyetli. Sadece aktif locale'i init etmek daha hızlı.

### 2. Flutter image cache limiti 100MB (normal cihaz)
**Etki:** IPTV logoları ve posterlerle 100MB hızla dolabilir
**Detay:** AppPerformance'da 100MB limit var. IPTV uygulamasında yüzlerce logo + poster var, bu limit hızla dolup thrashing'e yol açabilir.

### 3. EPG verisi bellekte tutuluyor
**Dosya:** `global_epg_service.dart, home_epg_catalog_cache.dart`
**Etki:** Büyük EPG dosyaları (100MB+ XML) RAM'de
**Detay:** XMLTV parse edildikten sonra bellekte. EPG servisi permanent olarak GetX'te tutuluyor.

### 4. home_showcase_view.dart içinde Image.asset kullanımı
**Etki:** Asset boyutu (13MB), açılışta decode
**Detay:** assets/ 13MB. Image.asset her kullanımda görseli decode eder. Hero banner gibi yerlerde const constructor kullanımı yok.

## ✅ MÜKEMMEL YAPILAN PERFORMANS OPTİMİZASYONLARI

### 1. AppPerformance sınıfı — TV Lite, düşük donanım modu, image cache limitleri, blur kontrolü
**Detay:** Profesyonel cihaz adaptasyonu. TV, düşük donanım, normal cihaz için farklı limitler.

### 2. BrowseFilmsFilterAsync — 2500+ öğe için compute(isolate) kullanımı
**Detay:** UI thread'i bloklamadan büyük listeleri filtreleme.

### 3. AppImageCacheService — Debounce'lu disk flush, bellek içi index, ETAG revalidation
**Detay:** SharedPreferences'ı her görselde okumak yerine bellekte cache + 1sn debounce.

### 4. PlaylistCacheService — Layout cache ile tekrar hesaplama önleme
**Detay:** _layoutCacheKey ile _layoutCachedResult kullanımı.

### 5. DevicePerformanceAdvisor — Jank frame sayma, otomatik low-end mode önerisi
**Detay:** SchedulerBinding.instance.addTimingsCallback ile 32ms+ frame sayma.

### 6. posterDecodeWidth — Görsel decode boyutunu ekran çözünürlüğüne sınırlama
**Detay:** 1000x1500 posteri tam çözmek yerine logical width * DPR * scale ile sınırlama.

### 7. Android build: R8 minify, shrinkResources, x86/x86_64 exclude
**Detay:** APK boyutu düşük. x86_64 libmpv ~15.8 MB harici tutuluyor.

### 8. Splash'te önceden hesaplanan home counts — AppBootstrapService
**Detay:** Ana ekranda '0' görünüp sonra dolma sorununu önleme.

### 9. IptvPrecacheService — DNS lookup + TCP preconnect
**Detay:** Kanal değişiminde el sıkışma süresi azaltma.

## 📊 Özet İstatistikler

| Metrik | Değer | Durum |
|:---|:---|:---|
| En büyük controller | PlayerController (7.456 satır) | 🔴 Kritik |
| Toplam controller boyutu | ~18.000+ satır (4 ana controller) | 🔴 Yüksek |
| Timer.periodic sayısı | 15+ (proje genelinde) | 🔴 Kritik |
| addPostFrameCallback sayısı | 57+ | 🟡 Yüksek |
| setState kullanımı | 30+ dosya | 🟡 Orta |
| Image.network (cache yok) | 1+ dosya | 🟡 Orta |
| ListView (builder yok) | 15+ dosya | 🟡 Orta |
| Isolate kullanımı (compute) | 1 (browse_films_filter_isolate) | ✅ Mükemmel |
| Image cache limiti | 45-100 MB (cihaza göre) | ✅ İyi |
| Poster decode boyut sınırlaması | posterDecodeWidth | ✅ Mükemmel |
| TV Lite / Düşük donanım modu | Var | ✅ Mükemmel |
| Jank monitoring | DevicePerformanceAdvisor | ✅ Mükemmel |

---

## 🎯 Öncelikli Düzeltme Önerileri

### 1. Controller'ları Parçala (En Önemli)
```
PlayerController (7.456 satır) →
  - PlayerPlaybackController (motor, buffer, hata kurtarma)
  - PlayerUiController (OSD, timer'lar, visibility)
  - PlayerNavigationController (zap, browse tape, kanal değişimi)
```

### 2. Timer'ları Birleştir
- PlayerController'daki 15+ timer'ı tek bir `Timer.periodic(250ms)` altında birleştir.
- Her tick'te state machine'e göre ilgili işlemi yap.
- `Timer.periodic` yerine `Stream.periodic` + RxDart consider edilebilir.

### 3. addPostFrameCallback'leri Azalt
- TV odak yönetiminde `FocusNode` + `FocusTraversalGroup` kullanımı düşünülebilir.
- Her D-pad hareketinde `addPostFrameCallback` yerine doğrudan `FocusNode.requestFocus()`.

### 4. Görsel Cache'ini Garantile
- Tüm `Image.network` kullanımlarını `CachedNetworkImage` ile değiştir.
- `home_showcase_view.dart` gibi yerlerde özellikle kritik.

### 5. ListView.builder Kullanımı
- Kanal listesi, film listesi, EPG listesi gibi 100+ öğe olan yerlerde `ListView.builder` zorunlu.
- `settings_view.dart`, `browse_view.dart` gibi yerleri gözden geçir.

---

## 🏆 Takdir Edilmesi Gerekenler

Bu proje, Flutter IPTV uygulamaları arasında **performans açısından en profesyonel** düzeyde yazılmışlardan biri. Özellikle:

- **Cihaz adaptasyonu** (TV Lite, düşük donanım modu, RAM/çekirdek algılama)
- **Görsel optimizasyonu** (posterDecodeWidth, image cache limitleri, decode scale)
- **Isolate kullanımı** (büyük liste filtreleme)
- **Bellek monitoring** (PlaylistMemoryDiagnostics, jank advisor)
- **Ağ optimizasyonu** (TCP preconnect, DNS cache, ETAG revalidation)

Bu yapıların hepsi çok doğru tasarlanmış. Tek sorun, **ölçek büyüdükçe tek dosyaların çok şişmesi** ve **timer yönetiminin** biraz elden kaçması.
