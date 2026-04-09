# Mina IPTV Player — Gizlilik Politikası

**Son güncelleme:** 5 Nisan 2026

Bu belge, **Mina IPTV Player** mobil ve Android TV uygulamasının kişisel verilerle ilgili yaklaşımını açıklar. Uygulama, yalnızca sizin sağladığınız kaynaklar üzerinden içerik oynatmak için tasarlanmıştır; geliştirici tarafından işletilen merkezi bir “içerik sunucusu” veya kullanıcı veritabanı bulunmamaktadır.

## 1. Veri sorumlusu ve iletişim

Gizlilikle ilgili sorularınız için: **furkangumrukcu07@gmail.com**

## 2. Uygulamanın rolü

Mina IPTV Player bir **oynatıcı**dır. Liste adresleri (M3U/URL), Xtream API bilgileri, EPG (XMLTV) adresleri ve benzeri yapılandırmalar **sizin tarafınızdan girilir**. Bu bilgilerle yapılan tüm ağ istekleri, doğrudan veya dolaylı olarak **sizin belirttiğiniz üçüncü taraf sunuculara** gider. Bu sunucuların gizlilik uygulamaları kendi politikalarına tabidir; uygulama bu sağlayıcıları denetlemez.

## 3. Cihazda işlenen ve saklanan veriler

Aşağıdaki veriler **yalnızca cihazınızda** tutulur ve geliştiriciye otomatik olarak gönderilmez:

| Veri türü | Amaç | Saklama |
|-----------|------|---------|
| Playlist / M3U URL veya yerel liste içeriği | Kanal ve içerik listesini yüklemek | Uygulama destek dizini ve güvenli depolama (Android’de şifreli tercihler) |
| Xtream kullanıcı adı, şifre, sunucu adresi | Xtream API ile bağlanmak | Güvenli depolama (flutter_secure_storage) |
| Uygulama ayarları (dil, oynatıcı tercihleri, uyku zamanlayıcısı, açılışta başlatma vb.) | Tercihlerinizi hatırlamak | SharedPreferences |
| Favori kanallar | Hızlı erişim | SharedPreferences |
| EPG kaynağı adresi | Program rehberini indirmek | Ayarlarla birlikte yerel olarak |

**Açılışta başlat:** İsteğe bağlı olarak etkinleştirirseniz, cihaz açıldığında uygulamanın başlatılması için sistem olayı (`BOOT_COMPLETED`) dinlenir; bu özellik kapalıyken bu olay işlenmez.

## 4. İnternet ve ağ trafiği

- **İnternet izni**, sizin girdiğiniz adreslere playlist, akış, EPG ve ilgili istekleri göndermek için kullanılır.
- Bazı yayınlar **şifrelenmemiş (HTTP)** olabilir; uygulama bu tür bağlantılara izin verecek şekilde yapılandırılabilir (`usesCleartextTraffic`). Ağ üzerinden iletilen verilerin gizliliği, bağlantı türüne ve ağınıza bağlıdır.
- Oynatma sırasında kullanılan oynatıcı bileşenleri (ör. ExoPlayer / MediaKit), teknik olarak akış URL’lerine istek gönderir; bu trafik hedef sunuculara gider.

## 5. Depolama ve medya izinleri

- **Harici / medya okuma izinleri**, cihazınızdaki dosyalardan playlist veya medya seçmenize yardımcı olmak için kullanılabilir (sürüme göre değişir).
- **Kayıt** özelliği kullanıldığında, desteklenen durumlarda kayıt dosyaları cihazınızdaki uygun bir dizine (ör. uygulama erişebildiği harici depolama altında `Recordings` klasörü) yazılır. Bu dosyalar yalnızca cihazınızda kalır; uygulama bunları geliştiriciye yüklemez.

## 6. Analitik, reklam ve profilleme

Bu uygulamanın standart sürümünde, geliştirici hesabına kişisel veri aktaran **entegre reklam SDK’ları** veya **kullanıcı davranışı analitiği** (ör. Firebase Analytics) **bilinçli olarak kullanılmamaktadır**. Üçüncü taraf kütüphaneler yalnızca oynatma ve uygulama işlevselliği için gereklidir.

*(Farklı bir dağıtım veya mağaza sürümü eklerseniz bu bölümü o sürüme göre güncellemeniz gerekir.)*

## 7. Verilerin aktarılması

Kişisel verilerinizi **satmıyoruz**. Cihazınızdan geliştiriciye giden tek tip iletişim, **sizin başlattığınız** e-posta veya destek talebi gibi doğrudan iletişimlerdir.

## 8. Veri güvenliği ve sizin sorumluluğunuz

- Xtream veya liste sağlayıcı şifreleri cihazda güvenli depolama ile korunmaya çalışılır; yine de cihaz güvenliği (ekran kilidi, cihaz paylaşımı) sizin sorumluluğunuzdadır.
- Kullandığınız IPTV / liste hizmetlerinin kullanım şartlarına ve yasalara uygunluk size aittir.

## 9. Çocukların gizliliği

Uygulama, 13 yaş altı çocuklardan bilerek veri toplamak için tasarlanmamıştır. Ebeveynler, çocukların cihaz ve abonelik bilgilerine erişimini denetlemelidir.

## 10. Haklarınız (KVKK / GDPR özeti)

İlgili mevzuat kapsamında, veri sorumlusuna başvurarak erişim, düzeltme, silme, itiraz veya taşınabilirlik taleplerinde bulunabilirsiniz. Uygulama çoğu veriyi cihazda tuttuğu için, pratikte **uygulama içinden listeyi/hesabı kaldırarak** veya **uygulamayı silerek** yerel verileri de kaldırabilirsiniz.

## 11. Politika değişiklikleri

Bu metin güncellenebilir. Önemli değişikliklerde, uygulama içi “Hakkında” veya mağaza sayfası üzerinden yeni sürüm notlarıyla bilgilendirme yapılması önerilir.

---

*Bu metin genel bilgilendirme amaçlıdır; belirli bir ülke veya mağaza gereksinimi için hukuk danışmanlığı almanız önerilir.*
