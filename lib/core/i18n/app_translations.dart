import 'package:get/get.dart';

import 'locale_partials.dart';
import 'translation_merge.dart';

import 'locale_es.dart';
import 'locale_ja.dart';
import 'privacy_translations.dart';

/// Locales: `tr_TR`, `en_US`, plus partials merged over English.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'tr_TR': mergeTranslations(_tr, kPrivacyTr),
        'en_US': mergeTranslations(_en, kPrivacy__en),
        'fr_FR': mergeTranslations(mergeTranslations(_en, kLocalePartialFr), kPrivacy_kLocalePartialFr),
        'ar_SA': mergeTranslations(mergeTranslations(_en, kLocalePartialAr), kPrivacy_kLocalePartialAr),
        'zh_CN': mergeTranslations(mergeTranslations(_en, kLocalePartialZh), kPrivacy_kLocalePartialZh),
        'ru_RU': mergeTranslations(mergeTranslations(_en, kLocalePartialRu), kPrivacy_kLocalePartialRu),
        'ja_JP': mergeTranslations(mergeTranslations(_en, kLocalePartialJa), kPrivacy_kLocalePartialJa),
        'es_ES': mergeTranslations(mergeTranslations(_en, kLocalePartialEs), kPrivacy_kLocalePartialEs),
        'ko_KR': mergeTranslations(mergeTranslations(_en, kLocalePartialKo), kPrivacy_kLocalePartialKo),
        'he_IL': mergeTranslations(mergeTranslations(_en, kLocalePartialHe), kPrivacy_kLocalePartialHe),
        'da_DK': mergeTranslations(mergeTranslations(_en, kLocalePartialDa), kPrivacy_kLocalePartialDa),
        'sv_SE': mergeTranslations(mergeTranslations(_en, kLocalePartialSv), kPrivacy_kLocalePartialSv),
        'hi_IN': mergeTranslations(mergeTranslations(_en, kLocalePartialHi), kPrivacy_kLocalePartialHi),
        'th_TH': mergeTranslations(mergeTranslations(_en, kLocalePartialTh), kPrivacy_kLocalePartialTh),
        'it_IT': mergeTranslations(mergeTranslations(_en, kLocalePartialIt), kPrivacy_kLocalePartialIt),
        'pt_PT': mergeTranslations(mergeTranslations(_en, kLocalePartialPt), kPrivacy_kLocalePartialPt),
        'id_ID': mergeTranslations(mergeTranslations(_en, kLocalePartialId), kPrivacy_kLocalePartialId),
        'de_DE': mergeTranslations(mergeTranslations(_en, kLocalePartialDe), kPrivacy_kLocalePartialDe),
        'fa_IR': mergeTranslations(mergeTranslations(_en, kLocalePartialFa), kPrivacy_kLocalePartialFa),
        'pl_PL': mergeTranslations(mergeTranslations(_en, kLocalePartialPl), kPrivacy_kLocalePartialPl),
        'nl_NL': mergeTranslations(mergeTranslations(_en, kLocalePartialNl), kPrivacy_kLocalePartialNl),
        'uk_UA': mergeTranslations(mergeTranslations(_en, kLocalePartialUk), kPrivacy_kLocalePartialUk),
        'vi_VN': mergeTranslations(mergeTranslations(_en, kLocalePartialVi), kPrivacy_kLocalePartialVi),
        'el_GR': mergeTranslations(mergeTranslations(_en, kLocalePartialEl), kPrivacy_kLocalePartialEl),
        'ro_RO': mergeTranslations(mergeTranslations(_en, kLocalePartialRo), kPrivacy_kLocalePartialRo),
        'sq_AL': mergeTranslations(mergeTranslations(_en, kLocalePartialSq), kPrivacy_kLocalePartialSq),
      };
}

const Map<String, String> _tr = {
  // App / home
  'app.title': 'Mina IPTV Player',
  'paywall.title': 'Mina IPTV Premium',
  'paywall.trial.expired': '2 günlük ücretsiz deneme süreniz sona erdi.',
  'paywall.trial.active': 'Deneme sürenizin bitmesine @time kaldı.',
  'paywall.feature.performance.title': 'Sayısız Tema ve Kişiselleştirme',
  'paywall.feature.performance.subtitle': 'Uygulamanın görünümünü zevkinize göre özelleştirin, premium temalarla farkı hissedin.',
  'paywall.feature.sync.title': 'Güçlü Medya Oynatıcı',
  'paywall.feature.sync.subtitle': 'Gelişmiş donanım hızlandırma ve geniş format desteği ile kesintisiz oynatma deneyimi.',
  'paywall.feature.keymapping.title': 'Tek Abonelik 3 Farklı Cihaz',
  'paywall.feature.keymapping.subtitle': 'Tablet, TV ve mobil cihazlarınızda aynı abonelikle sınırsız kullanım.',
  'paywall.feature.introcutter.title': 'Tüm Diğer Özellikler',
  'paywall.feature.introcutter.subtitle': 'Vod Özel Bilgiler, Bulut Yedekleme, Farklı Tasarımlar, Ömür Boyu Güncelleme Garantisi.',
  'paywall.button.buy': 'Satın Al',
  'paywall.button.buy3devices': 'Add 3 More Devices',
  'paywall.button.coffee': 'Bana Bir Kahve Ismarla ☕',
  'paywall.coffee.success.title': 'Teşekkürler!',
  'paywall.coffee.success.body': 'Desteğiniz için çok teşekkür ederiz, harikasınız!',
  'paywall.button.connecting': 'Bağlanıyor...',
  'paywall.button.restore': 'Satın Alımı Geri Yükle',
  'paywall.button.restoring': 'Sorgulanıyor...',
  'paywall.grandfather.prompt': '28 Haziran 2026 öncesi üye misiniz?',
  'paywall.grandfather.button': 'Google ile Giriş Yapıp Muafiyeti Aktif Et',
  'paywall.grandfather.syncing': 'Lisans doğrulanıyor…',
  'paywall.user.logged_in': 'Kullanıcı olarak giriş yapıldı: @email',
  'paywall.error.title': 'Ödeme Başarısız',
  'paywall.error.body': 'Google Play Market ile bağlantı kurulamadı veya ödeme iptal edildi.',
  'paywall.restore.title': 'Satın Alım Bulunamadı',
  'paywall.restore.body': 'Google Play hesabınızda aktif bir satın alım bulunamadı.',
  'paywall.deviceLimit.title': 'Cihaz Limiti Aşıldı',
  'paywall.deviceLimit.body': 'Bir lisans en fazla @max cihazda kullanılabilir. Devam etmek için kayıtlı cihazlardan birini kaldırın.',
  'paywall.deviceLimit.count': 'Kayıtlı cihaz: @count / @max',
  'paywall.deviceLimit.thisDevice': 'Bu cihaz',
  'paywall.deviceLimit.remove': 'Kaldır',
  'paywall.deviceLimit.retry': 'Tekrar Dene',
  'paywall.deviceLimit.removed': 'Cihaz kaldırıldı. Kayıt yenileniyor…',
  'paywall.deviceLimit.removeFailed': 'Cihaz kaldırılamadı. Lütfen tekrar deneyin.',
  'settings.tile.subscription': 'Abonelik Durumu',
  'settings.tile.subscription.sub': 'Lisans ve deneme süresi detayları',
  'settings.subscription.grandfathered': 'Ömür Boyu Ücretsiz (Eski Üye)',
  'settings.subscription.premiumActive': 'Premium Aktif (Sınırsız)',
  'settings.subscription.trialActive': 'Ücretsiz Deneme: @days Gün Kaldı',
  'settings.subscription.trialExpired': 'Deneme Süresi Doldu',
  'settings.subscription.dialog.title': 'Lisans Bilgileri',
  'settings.subscription.dialog.status': 'Lisans Durumu: ',
  'settings.subscription.dialog.installDate': 'İlk Kurulum Tarihi: ',
  'settings.subscription.dialog.purchaseDate': 'Lisans Alım Tarihi: ',
  'settings.subscription.dialog.trialEnd': 'Deneme Bitiş Tarihi: ',
  'settings.subscription.dialog.type': 'Paket Türü: ',
  'settings.subscription.dialog.grandfathered': 'Muafiyet Durumu: ',
  'settings.subscription.dialog.grandfathered.yes': 'Evet (Eski Üye Muafiyeti)',
  'settings.subscription.dialog.grandfathered.no': 'Hayır',
  'settings.subscription.dialog.devices': 'Kayıtlı Cihazlar: ',
  'settings.subscription.deviceLimit': 'Cihaz limiti doldu (@count/@max)',
  'dialog.exit.title': 'Uygulamadan Çıkılsın Mı ?',
  'dialog.exit.body': 'Uygulamadan çıkılacak?',
  'dialog.exit.seconds': 'saniye',
  'dialog.exit.yes': 'Evet',
  'dialog.exit.no': 'Hayır',
  'home.live': 'Canlı Yayınlar',
  'home.live.subtitle': 'Canlı TV',
  'home.films': 'Filmler',
  'home.films.subtitle': 'Film / dizi',
  'home.series': 'Diziler',
  'home.series.subtitle': 'Dizi',
  'home.recommendedFilms': 'Film & Dizi',
  'home.recommendedFilms.subtitle': 'Keşfet',
  'home.refresh.done': 'İçerik yenilendi',
  'home.refresh.failed': 'Yenileme başarısız: @e',
  'playlist.refreshing': 'Liste yenileniyor',
  'filmDizi.tab.films': 'Film',
  'filmDizi.tab.series': 'Dizi',
  'filmDizi.recentlyAddedFilms': 'Yeni eklenen filmler',
  'filmDizi.recentlyAddedSeries': 'Yeni eklenen diziler',
  'filmDizi.empty': 'Film veya dizi bulunamadı.',
  'filmDizi.emptyFilms': 'Film bulunamadı.',
  'filmDizi.emptySeries': 'Dizi bulunamadı.',
  'filmDizi.loading': 'İçerik yükleniyor…',
  'filmDizi.searchHintFilms': 'Film adı yazın…',
  'filmDizi.searchHintSeries': 'Dizi adı yazın…',
  'filmDizi.watch': 'İzle',
  'filmDizi.detail': 'Detay',
  'filmDizi.series.startingFirstEpisode': 'İlk bölüm hazırlanıyor…',
  'filmDizi.synopsis': 'Özet',
  'filmDizi.trailers': 'Fragmanlar',
  'filmDizi.trailer.xtream': 'Xtream',
  'filmDizi.quickInfo.director': 'Yönetmen',
  'filmDizi.quickInfo.genre': 'Tür',
  'filmDizi.cast': 'Oyuncular',
  'filmDizi.similar': 'Bunlar da ilginizi çekebilir',
  'filmDizi.noSynopsis': 'Özet bilgisi bulunamadı.',
  'filmDizi.actorBio': 'Biyografi',
  'filmDizi.actorFilms': 'Filmler',
  'filmDizi.actorFilmNotFoundTitle': 'Film bulunamadı',
  'filmDizi.actorFilmNotFound': '@title playlist\'inizde bulunamadı.',
  'filmDizi.plotMore': 'Devamını oku',
  'filmDizi.plotLess': 'Daha az göster',
  'filmDizi.series.watchEpisode1': '1. Bölümü İzle',
  'filmDizi.series.seasons': 'Sezonlar',
  'filmDizi.series.seasonN': 'Sezon @n',
  'filmDizi.series.episodes': 'Bölümler',
  'filmDizi.series.episodeN': 'Bölüm @n',
  'filmDizi.series.episodeLine': '@show · Sezon @season · Bölüm @episode',
  'filmDizi.series.downloadPick': 'İndirilecek bölümü seç',
  'filmDizi.series.release': 'Yayın: @date',
  'filmDizi.series.episodeCount': '@n Bölüm',
  'filmDizi.series.meta.language': '@lang',
  'filmDizi.series.noEpisodes': 'Bölüm bulunamadı.',
  'filmDizi.series.loadFail': 'Bölümler yüklenemedi.',
  'recommendedFilms.topRated': 'En İyiler',
  'recommendedFilms.recentlyAdded': 'Son Eklenen',
  'recommendedFilms.uhd4k': '4K / UHD',
  'recommendedFilms.nativeDub': 'Yerli Dil Dublajlı',
  'recommendedFilms.nativeSub': 'Yerli Dil Altyazılı',
  'recommendedFilms.seeAll': 'Tümünü Gör',
  'recommendedFilms.last50Films': 'Son Eklenen 50 Film',
  'recommendedFilms.last50Series': 'Son Eklenen 50 Dizi',
  'recommendedFilms.recentlyWatched.title': 'Son İzlenenler',
  'recommendedFilms.recentlyWatched.empty':
      'Henüz hiçbir şey izlemedin. İzlemeye başla, son izlediklerin burada listelensin.',
  'recommendedFilms.favorite': 'Favori',
  'recommendedFilms.play': 'Oynat',
  'recommendedFilms.hrs': 'sa',
  'recommendedFilms.min': 'dk',
  'recommendedFilms.empty': 'Önerilen film bulunamadı.',
  'recommendedFilms.loading': 'Filmler yükleniyor…',
  'recommendedFilms.search': 'Ara',
  'recommendedFilms.searchHint': 'Film adı yazın…',
  'recommendedFilms.searchResults': '@count sonuç: «@query»',
  'home.epgMix': 'Tekrar & EPG Mix',
  'home.epgMix.subtitle': 'Geçmiş ve sıradaki yayınlar',
  'home.minaAnalytics': 'Mina İzleme Analizi',
  'home.minaAnalytics.subtitle': 'İzleme istatistiklerin ve özetin',
  'home.dock.live': 'Canlı TV',
  'home.dock.films': 'Film & Dizi',
  'home.dock.replay': 'Tekrar & EPG',
  'home.dock.wrapper': 'Mina Wrapper',
  'home.chat': 'Sohbet',
  'home.chat.subtitle': 'Dil odalarında canlı sohbet',
  'chat.title': 'Sohbet',
  'chat.online': '@n Çevrimiçi',
  'chat.signIn.title': 'Sohbete katılmak için giriş yapın',
  'chat.signIn.body':
      'Sohbet odalarına katılmak ve mesaj yazabilmek için lütfen Google ile oturum açın ve yedeklemenizi aktif edin.',
  'chat.signIn.action': 'Google ile oturum aç',
  'chat.signIn.busy': 'Oturum açılıyor…',
  'chat.signIn.failed': 'Oturum açılamadı. Lütfen tekrar deneyin.',
  'chat.room.subtitle': '@lang odası',
  'chat.room.yourLanguage': 'Senin dilin · oda',
  'chat.room.headerSub': 'Canlı sohbet · son 100 mesaj',
  'chat.room.empty': 'Henüz mesaj yok. İlk mesajı sen yaz!',
  'chat.composer.hint': 'Mesaj yaz…',
  'chat.composer.send': 'Gönder',
  'chat.msg.you': 'Sen',
  'chat.msg.copy': 'Kopyala',
  'chat.msg.copied': 'Mesaj panoya kopyalandı',
  'chat.msg.reply': 'Yanıtla',
  'chat.msg.delete': 'Sil',
  'chat.msg.deleteForAll': 'Herkesten Sil',
  'chat.msg.deleteTitle': 'Mesajı sil',
  'chat.msg.deleteBody':
      'Bu mesaj herkes için kalıcı olarak silinecek. Emin misiniz?',
  'chat.msg.deleteFailed': 'Mesaj silinemedi. Lütfen tekrar deneyin.',
  'chat.role.admin': 'Yönetici',
  'chat.support.adminName': 'Yönetici',
  'chat.support.contactAdmin': 'Yöneticiye Mesaj Gönder',
  'chat.support.contactAdminSub':
      'Soru ve sorunların için yöneticiyle özel sohbet',
  'chat.support.inboxTitle': 'Kullanıcı Mesajları',
  'chat.support.inboxSubtitle':
      'Kullanıcılardan gelen mesajları görüntüle ve yanıtla',
  'chat.support.inboxEmpty': 'Henüz kullanıcı mesajı yok.',
  'chat.support.userHeaderSub': 'Yönetici ile özel sohbet',
  'chat.support.adminHeaderSub': 'Kullanıcı ile özel sohbet',
  'chat.support.emptyUser':
      'Yöneticiye ilk mesajını yaz. Yalnızca sen ve yönetici görebilir.',
  'chat.support.emptyAdmin': 'Bu kullanıcıyla henüz mesaj yok.',
  'chat.support.deleteThread': 'Sohbeti Sil',
  'chat.support.deleteTitle': 'Sohbeti sil',
  'chat.support.deleteBody':
      'Bu konuşmadaki tüm mesajlar kalıcı olarak silinecek. Bu işlem geri alınamaz.',
  'chat.support.deleteFailed': 'Sohbet silinemedi. Lütfen tekrar deneyin.',
  'chat.support.deleteEmpty': 'Henüz silinecek bir konuşma yok.',
  'chat.support.deleted': 'Sohbet silindi.',
  'chat.tag.title': 'Yayın durumu',
  'chat.tag.pick': 'Yayın durumu ekle',
  'chat.tag.clear': 'Etiketi kaldır',
  'chat.tag.flowing': 'Yayın Akıyor',
  'chat.tag.noFreeze': 'Donma Yok',
  'chat.tag.freeze': 'Donma Var',
  'chat.tag.down': 'Yayın Yok',
  'epgMix.title': 'Tekrar & EPG Mix',
  'epgMix.cat.replay': 'Tekrar',
  'epgMix.cat.sport': 'Spor',
  'epgMix.cat.documentary': 'Belgesel',
  'epgMix.cat.film': 'Film',
  'epgMix.cat.series': 'Dizi',
  'epgMix.cat.news': 'Haber',
  'epgMix.schedule': '@start – @end',
  'epgMix.empty': 'Bu kategoride EPG ile eşleşen sıradaki yayın bulunamadı.',
  'epgMix.replay.empty':
      'Geriye dönük yayın bulunamadı. Canlı kanal EPG verisi yüklendikçe burada görünecek.',
  'epgMix.replay.metaLine': 'Tekrar · @when',
  'epgMix.replay.justEnded': 'az önce sona erdi',
  'epgMix.replay.minutesAgo': '@n dk önce',
  'epgMix.replay.hoursAgo': '@n sa önce',
  'epgMix.replay.yesterday': 'Dün',
  'epgMix.replay.error.title': 'Tekrar oynatılamadı',
  'epgMix.replay.error.notXtream':
      'Geriye dönük yayın yalnızca Xtream tabanlı listelerde desteklenir.',
  'epgMix.replay.error.template':
      'Catch-up URL şablonu kapalı. Ayarlar > EPG > Catch-up URL şablonu üzerinden açın.',
  'epgMix.replay.error.url':
      'Bu program için geçerli bir catch-up URL üretilemedi.',
  'epgMix.remind': 'Hatırlat',
  'epgMix.remind.cancel': 'Hatırlatmayı kaldır',
  'epgMix.remind.added':
      'Hatırlatma eklendi. Yayın başlamadan 30 dk önce bildirim gönderilecek.',
  'epgMix.remind.removed': 'Hatırlatma kaldırıldı.',
  'epgMix.remind.scheduled':
      'Yayın başlamadan 30 dk önce bildirim gönderilecek.',
  'epgMix.remind.active': 'Hatırlatıcı açık',
  'epgMix.remind.tooLate': 'Bu yayın için hatırlatma süresi geçti.',
  'epgMix.remind.permissionDenied':
      'Bildirim izni verilmedi. Hatırlatıcı kurulamadı.',
  'epgMix.remind.permissionSettings':
      'Bildirimler kapalı. Bildirim ayarları açıldı — izni açıp tekrar deneyin.',
  'epgMix.remind.failed': 'Hatırlatıcı zamanlanamadı. Lütfen tekrar deneyin.',
  'epgMix.remind.title': 'Sıradaki yayın',
  'epgMix.remind.body': '@channel · @minutes dk sonra başlıyor',
  'settings.tile.upcomingMatches': 'Sıradaki Maçlar',
  'settings.tile.upcomingMatches.subtitle':
      'Ana ekranda EPG spor şeridini göster',
  'settings.tile.adaptiveHaptics': 'Adaptif titreşim',
  'settings.tile.adaptiveHaptics.subtitle':
      'Mobil modda liste kaydırma ve seçimlerde hafif titreşim',
  'settings.lowEndMode.title': 'Düşük donanım',
  'settings.lowEndMode.subOn':
      'Açık — sade grafik, blur/gölge kapalı, bellek öncelikli',
  'settings.lowEndMode.subOff':
      'Kapalı — tam görsel efektler (normal performans)',
  'settings.tvLite.title': 'TV Lite (sade grafik)',
  'settings.tvLite.subOn':
      'Açık — blur/gölge kapalı, sade odak, hızlı animasyon (TV için)',
  'settings.tvLite.subOff':
      'Kapalı — tam cam tasarımı (blur, gölge, animasyonlar)',
  'lowEndMode.suggest.title': 'Performans sorunu algılandı',
  'lowEndMode.suggest.body':
      'Cihazınız uygulamayı akıcı çalıştırmakta zorlanıyor gibi görünüyor. Daha akıcı bir deneyim için «Düşük Donanımlı Cihaz Modu»na geçmelisiniz; görsel efektler azaltılır ve performans önceliklendirilir. Bu ayarı dilediğinizde Ayarlar › Diğer Araçlar bölümünden değiştirebilirsiniz.',
  'lowEndMode.suggest.enable': 'Düşük donanım moduna geç',
  'lowEndMode.suggest.later': 'Şimdi değil',
  'setup.upcomingMatchesTitle': 'Sıradaki Maçlar',
  'setup.upcomingMatchesSub': 'Ana ekranda spor şeridi',
  'setup.adaptiveHapticsTitle': 'Adaptif titreşim',
  'setup.adaptiveHapticsSub': 'Kaydırma ve dokunma titreşimi',
  'setup.mixedLiveTitle': 'Karışık Canlı TV',
  'setup.mixedLiveSub': 'Ana ekranda rastgele kanal şeridi',
  'setup.stripChannelPrefixTitle': 'Kanal ön eki kaldır',
  'setup.stripChannelPrefixSub':
      'TR:/BR:/EN:/US: gibi ülke öneklerini temizle (kalite etiketleri kalır)',
  'setup.launchOnBootTitle': 'Açılışta başlat',
  'setup.launchOnBootSub': 'Cihaz açılınca uygulamayı aç',
  'setup.pipTitle': 'Küçük ekran (PiP)',
  'setup.pipSub': 'Ana ekrandan çıkınca mini oynatıcı',
  'setup.inAppPipTitle': 'Uygulama İçi PiP',
  'setup.inAppPipSub':
      'Yayından ana ekrana dönünce yayın küçük oynatıcıda devam eder',
  'setup.inAppPipPreviewCaption':
      'Geri tuşu ile ana ekrana dönünce yayın sağ üstte veya altta (düzene göre) oynar; dokununca tam ekrana açılır.',
  'setup.epgCacheTitle': 'EPG güncelleme',
  'setup.epgCacheSub': 'Program rehberi kaç günde bir yenilensin',
  'setup.epgCacheDays': '@n gün',
  'setup.epgCacheNever': 'Kapalı',
  'setup.stepAppFont': 'Uygulama fontu',
  'setup.appFontHint': 'Arayüz yazı tipini seçin.',
  'setup.featuresHint': 'Anahtarla açın veya kapatın.',
  'setup.personalizationHint':
      'Ana ekrandaki kategori kartları arasında sürüklerken kullanılacak efekti ve tüm kartlara uygulanacak çerçeve stilini seçin. Bu seçenekleri daha sonra Ayarlar > Ana Ekran Ayarları üzerinden de değiştirebilirsiniz.',
  'setup.stepFeatures': 'Özellikler',
  'settings.tile.mixedLiveTv': 'Karışık Canlı TV',
  'settings.tile.channelPrefix': 'Kanal ön eki',
  'settings.tile.channelPrefix.on':
      'TR:/BR:/EN:/US: gibi ülke önekleri gizleniyor (kalite kalır)',
  'settings.tile.channelPrefix.off': 'Playlist adları olduğu gibi',
  'settings.tile.hideLiveDetail': 'Canlı TV detay sekmesini gizle (dikey)',
  'settings.tile.hideLiveDetail.on':
      'Detay sekmesi gizli; kanal seçilince yayın doğrudan açılır',
  'settings.tile.hideLiveDetail.off':
      'Kanal seçilince önce Detay önizlemesi açılır',
  'settings.dialog.channelPrefixTitle': 'Kanal ön ekini kaldır',
  'settings.dialog.channelPrefixBody':
      'Canlı TV kanal listelerinde, EPG satırlarında ve ilgili şeritlerde ülke kodu önekleri (TR:, BR:, EN:, DE: vb.) gösterilmez. Yalnızca kanal adı kalır.',
  'settings.dialog.channelPrefixExample': 'Örnek dönüşümler:',
  'settings.dialog.channelPrefixConfirm': 'Kaldır',
  'settings.snackbar.channelPrefixOn':
      'Kanal ön ekleri canlı yayın listelerinde gizlenecek.',
  'settings.snackbar.channelPrefixOff':
      'Kanal adları playlist’teki gibi gösterilecek.',
  'settings.tile.mixedLiveTv.subtitle':
      'Ana ekranda rastgele canlı kanal şeridi',
  'epgMix.loading': 'EPG yükleniyor…',
  'home.mixed_live': 'Karışık Canlı TV',
  'home.showcase.topRatedFilms': 'IMDB Yüksek Puanlı Filmler',
  'home.showcase.becauseYouWatched': '@title izlediğiniz için öneriliyor',
  'home.showcase.mixedFilms': 'Karışık Filmler',
  'home.showcase.mixedSeries': 'Karışık Diziler',
  'home.showcase.trendFilms': 'Trend Filmler',
  'home.showcase.trendSeries': 'Trend Diziler',
  'home.showcase.favoriteSeries': 'Favori Diziler',
  'home.showcase.favoriteChannels': 'Favori Kanallar',
  'home.showcase.favoriteFilms': 'Favori Filmler',
  'home.showcase.suggest.title': 'Yeni: Vitrin düzeni',
  'home.showcase.suggest.body':
      'Ana ekran için yeni Vitrin düzenini ekledik: dikey kayan poster şeritleri ve altta «damla cam» bir menü çubuğu. Şimdi denemek ister misiniz? İstediğiniz zaman Ayarlar > Ana Ekran\'dan geri dönebilirsiniz.',
  'home.showcase.suggest.tryIt': 'Hemen dene',
  'home.upcomingMatches': 'Sıradaki Maçlar',
  'home.upcomingMatches.loading': 'Program rehberi yükleniyor…',
  'marquee.monday': 'Yeni hafta, yeni bölümler! Mina ile keyifli başlangıçlar.',
  'marquee.tuesday': 'Salı keyfi: favori dizileriniz Mina’da.',
  'marquee.wednesday': 'Haftanın ortası, mola zamanı! Mina ile nefes alın.',
  'marquee.thursday': 'Hafta sonuna az kaldı, listenizi hazırlayın.',
  'marquee.friday': 'Cuma geldi! Bu akşam sinema keyfi Mina’da.',
  'marquee.saturday': 'Cumartesi maç ve film günü, en iyisi Mina’da.',
  'marquee.sunday': 'Pazar huzurla geçsin, keyifli seyirler!',
  'home.header.brandTop': 'Mina',
  'home.header.brandBottom': 'IPTV Player',
  'home.search.hint': 'Ara…',
  'home.search.dialogTitle': 'Ara',
  'home.search.typeToSeeResults': 'Sonuçlar için yazmaya başlayın.',
  'home.search.sectionLive': 'Canlı yayın',
  'home.search.sectionFilms': 'Filmler',
  'home.search.sectionSeries': 'Diziler',
  'home.search.noResults': 'Eşleşen sonuç yok.',
  'splash.preparing': 'Kütüphane hazırlanıyor…',
  'splash.playlist': 'Liste yükleniyor…',
  'splash.epg': 'Program rehberi hazırlanıyor…',
  'splash.finishing': 'Neredeyse hazır…',
  'setup.wizardTitle': 'Hoş geldiniz',
  'setup.trialWelcome.title': 'Hoş Geldiniz!',
  'setup.trialWelcome.message': 'Mina IPTV Player\'ı 2 gün boyunca tamamen ücretsiz ve sınırsız bir şekilde deneyebilir ve test edebilirsiniz. Memnun kalırsanız, 2 günün sonunda tek seferlik bir ödeme ile ömür boyu kullanım hakkına sahip olabilirsiniz. Dilediğiniz zaman Ayarlar > Abonelik Bilgisi bölümünden de şimdi satın alabilirsiniz.',
  'setup.trialWelcome.autoClose': 'Bu uyarı @seconds saniye sonra otomatik kapanacaktır.',
  'setup.stepLanguage': 'Dil',
  'setup.stepLayoutMode': 'Yerleşim modu',
  'setup.stepTheme': 'Görünüm',
  'setup.stepPlayer': 'Oynatıcı',
  'setup.stepPerformance': 'Performans',
  'setup.stepSource': 'Oynatma listesi',
  'setup.layoutModeHint':
      'Ana ekran düzenini seç. Vitrin düzeninde bazı kişiselleştirme seçenekleri (kart efektleri, çerçeve stili) devre dışı kalır.',
  'setup.tvLayoutModeHint':
      'TV ana ekran düzenini seç. TV modu sol menülü yeni kabuğu açar; kart düzeni klasik kartlı ana ekrandır.',
  'setup.performanceHint':
      'Cihazınızın gücüne göre bir mod seçin. 2 GB RAM ve altı cihazlarda Düşük donanım daha akıcı çalışır.',
  'setup.perfNormalTitle': 'Normal Performans Modu',
  'setup.perfNormalSub':
      'Tüm görsel efektler açık (blur, gölge). Güçlü cihazlar için önerilir.',
  'setup.perfLowEndTitle': 'Düşük donanım',
  'setup.perfLowEndSub':
      'Sade grafik: blur/gölge kapalı, görsel kalitesi ve önbellek düşürülür. 2 GB RAM ve altı için önerilir.',
  'setup.next': 'İlerle',
  'setup.back': 'Geri',
  'setup.finish': 'Kurulumu bitir',
  'setup.finishRequiresSource':
      'Önce oynatma listesini yükleyin (M3U veya Xtream).',
  'setup.skip': 'Atla',
  'setup.sourceHint':
      'M3U veya Xtream bilgilerinizi girin; listeyi yükledikten sonra uygulama açılır.',
  'common.or': 'veya',
  'cloud.googleSignInTitle': 'Google ile Oturum Aç ve Listelerini Getir',
  'cloud.googleSignInSubtitle':
      'Listelerin ve ayarların buluttan otomatik gelsin; yeni cihazlarda tek tıkla geri yükle.',
  'cloud.signingIn': 'Oturum açılıyor',
  'cloud.signedInContinue':
      'Giriş yapıldı. Kuruluma devam edin; ayarlarınız tamamlanınca buluta kaydedilecek.',
  'cloud.restored': 'Bulut yedeğiniz geri yüklendi.',
  'cloud.restoreFailed': 'Bulut yedeği geri yüklenemedi.',
  'cloud.signInFailed': 'Google ile giriş başarısız oldu.',
  'cloud.playServicesUnavailable':
      'Bu cihazda Google Servisleri bulunmadığı için yedekleme özelliği desteklenmemektedir.',
  'cloud.signInBrowserOpening': 'Tarayıcıda Google ile oturum açılıyor…',
  'cloud.signInBrowserHint':
      'Bu cihazda Google hesabı tarayıcı üzerinden açılacaktır.',
  'cloud.signInUnavailable':
      'Bu cihazda Google ile oturum açılamadı. Google Play Hizmetleri yüklü ve güncel olmalı, cihaza en az bir Google hesabı eklenmiş olmalı. Lütfen güncelleyip tekrar deneyin.',
  'cloud.signInConfigError':
      'Google girişi tamamlanamadı (yapılandırma/kimlik doğrulama hatası). Lütfen birkaç saniye sonra tekrar deneyin.',
  'cloud.notConfigured':
      'Bulut özelliği bu derlemede yapılandırılmamış (Firebase gerekli).',
  'cloud.title': 'Google Bulut Senkronu',
  'cloud.syncHint':
      'Listeleriniz ve ayarlarınız Google hesabınızla bulutta yedeklenir; yeni cihazda tek tıkla geri yüklenir.',
  'cloud.status.unavailable': 'Bulut kullanılamıyor',
  'cloud.status.notSignedIn': 'Google hesabına bağlı değil',
  'cloud.status.notSignedInBody':
      'Oturum açarak listelerinizi ve ayarlarınızı buluta kaydedebilirsiniz.',
  'cloud.status.active': 'Senkron aktif',
  'cloud.status.signedIn': '@email ile oturum açık',
  'cloud.signIn.action': 'Google ile oturum aç',
  'cloud.signOut.action': 'Google oturumunu kapat',
  'cloud.signedOut': 'Google oturumu kapatıldı.',
  'cloud.backup.title': 'Google\'a yedekle',
  'cloud.backup.body':
      'Tüm M3U/Xtream listeleriniz (32 slota kadar), tema, font ve PIN ayarlarınız Google hesabınıza kaydedilir.',
  'cloud.backup.b1': 'İnternet bağlantısı gerekir',
  'cloud.backup.b2': 'Mevcut bulut yedeğinin üzerine birleştirilir (merge)',
  'cloud.backup.b3': 'Yeni cihazda aynı Google hesabıyla geri yükleyin',
  'cloud.backup.action': 'Google\'a yedekle',
  'cloud.lastBackup.title': 'Son yedek',
  'cloud.lastBackup.loading': 'Yedek bilgisi yükleniyor…',
  'cloud.lastBackup.none': 'Bulutta henüz bir yedeğiniz yok.',
  'cloud.lastBackup.date': 'Tarih',
  'cloud.lastBackup.playlists': 'Listeler',
  'cloud.lastBackup.settings': 'Ayarlar',
  'cloud.lastBackup.localM3u': 'Yerel M3U dosyaları',
  'cloud.lastBackup.device': 'Cihaz',
  'cloud.backupDone': 'Buluta yedeklendi.',
  'cloud.backupFailed': 'Buluta yedeklenemedi.',
  'cloud.backup.newerTitle': 'Bulutta daha yeni yedek var',
  'cloud.backup.newerBody':
      'Bulutta @date tarihli (büyük olasılıkla başka bir cihazdan) daha yeni bir yedek var. Bu cihazdaki verilerle üzerine yazmak istediğinize emin misiniz?',
  'cloud.backup.overwrite': 'Üzerine yaz',
  'cloud.delete.action': 'Bulut verisini sil',
  'cloud.delete.confirmTitle': 'Bulut verisi silinsin mi?',
  'cloud.delete.confirmBody':
      'Buluttaki tüm yedeğiniz kalıcı olarak silinir. Bu cihazdaki yerel verileriniz etkilenmez. Bu işlem geri alınamaz.',
  'cloud.delete.confirmYes': 'Sil',
  'cloud.delete.done': 'Bulut verisi silindi.',
  'cloud.delete.failed': 'Bulut verisi silinemedi.',
  'cloud.restore.title': 'Google\'dan geri yükle',
  'cloud.restore.body':
      'Buluttaki son yedeği bu cihaza uygular; mevcut yerel ayarların üzerine yazar.',
  'cloud.restore.b1': 'Önce Google ile oturum açmanız gerekir',
  'cloud.restore.b2':
      'Yerel `mina_*` ayarları ve liste kimlik bilgileri değişir',
  'cloud.restore.b3':
      'Geri yükleme sonrası uygulamayı yeniden başlatmanız önerilir',
  'cloud.restore.action': 'Google\'dan geri yükle',
  'cloud.restore.confirmTitle': 'Buluttan geri yüklensin mi?',
  'cloud.restore.confirmBody':
      'Mevcut yerel ayarlar ve liste kimlik bilgileri buluttaki yedekle değiştirilir. Devam edilsin mi?',
  'cloud.restore.empty': 'Bulutta kayıtlı yedek bulunamadı.',
  'cloud.restore.progress.title': 'Bulut yedeği yükleniyor',
  'cloud.restore.progress.titleDone': 'Yedek yüklendi',
  'cloud.restore.progress.subtitle':
      'Google hesabınızdaki veriler cihazınıza aktarılıyor',
  'cloud.restore.progress.autoClose': '@n saniye içinde kapanacak',
  'cloud.restore.progress.row.download': 'Buluttan indiriliyor',
  'cloud.restore.progress.row.playlists': '@n oynatma listesi',
  'cloud.restore.progress.row.settings': '@n ayar',
  'cloud.restore.progress.row.localM3u': '@n yerel M3U dosyası',
  'cloud.restore.progress.row.profiles': '@n profil',
  'cloud.restore.progress.row.apply': 'Cihaza uygulanıyor',
  'cloud.restore.partialPlaylistsTitle': 'Liste yükleme uyarısı',
  'cloud.restore.partialPlaylists':
      '@fail liste yüklenemedi; @ok/@total liste başarıyla kuruldu.',
  'cloud.restore.allPlaylistsFailed':
      'Hiçbir oynatma listesi yüklenemedi. Ayarlarınız kuruldu; listeleri Ayarlar bölümünden yeniden ekleyebilirsiniz.',
  'cloud.signIn.title': 'Google ile oturum aç',
  'cloud.signIn.body':
      'Listelerinizi ve ayarlarınızı buluta yedeklemek ve diğer cihazlarda geri yüklemek için Google hesabınızla oturum açın.',
  'cloud.prompt.title': 'Listelerini buluta yedekle',
  'cloud.prompt.body':
      'Google ile oturum açarsan tüm listelerin ve ayarların buluta otomatik yedeklenir; yeni bir cihazda tek dokunuşla geri yüklersin.',
  'cloud.prompt.later': 'Daha sonra',
  'cloud.prompt.signedIn':
      'Giriş yapıldı. Listeleriniz ve ayarlarınız buluta yedeklenecek.',
  'cloud.prompt.loading': 'Ayarlarınız yükleniyor…',
  'cloud.prompt.loaded': 'Bulut ayarlarınız yüklendi.',
  // Profiller (Netflix tarzı)
  'settings.tile.profiles': 'Profiller',
  'settings.tile.profiles.sub': 'Her kullanıcı için ayrı tercihler',
  'settings.tile.profiles.active': 'Aktif: @name · @n profil',
  'profiles.title': 'Profiller',
  'profiles.hint':
      'Her profilin kendi teması, dili, ana ekranı ve tercihleri olur. Listeler tüm profiller arasında paylaşılır.',
  'profiles.manageHint':
      'Düzenlemek için bir profile dokun. Çıkmak için «Bitti».',
  'profiles.manage': 'Düzenle',
  'profiles.add': 'Profil ekle',
  'profiles.create': 'Profil oluştur',
  'profiles.edit': 'Profili düzenle',
  'profiles.delete': 'Sil',
  'profiles.delete.confirmTitle': 'Profil silinsin mi?',
  'profiles.delete.confirmBody':
      '«@name» profili ve bu profile ait tercihler silinecek. Listeler etkilenmez.',
  'profiles.name': 'Profil adı',
  'profiles.nameRequired': 'Lütfen bir profil adı girin.',
  'profiles.avatar': 'Avatar rengi',
  'profiles.picture': 'Profil resmi',
  'profiles.lastOne': 'En az bir profil bulunmalı.',
  'profiles.switched': '«@name» profiline geçildi.',
  'profiles.lock.title': 'PIN kilidi',
  'profiles.lock.on': 'Bu profil PIN ile korunuyor',
  'profiles.lock.off': 'Bu profil korumasız',
  'profiles.lock.add': 'PIN belirle',
  'profiles.lock.remove': 'Kilidi kaldır',
  'profiles.pin.enter': 'PIN girin',
  'profiles.pin.set': 'Yeni PIN belirleyin',
  'profiles.pin.confirm': 'PIN’i onaylayın',
  'profiles.pin.wrong': 'Hatalı PIN.',
  'profiles.pin.mismatch': 'PIN’ler eşleşmiyor.',
  'profiles.pin.digits4': '4 haneli PIN girin',
  'profiles.pin.forgot': 'PIN’i unuttum',
  'profiles.pin.change': 'PIN değiştir',
  'profiles.pin.changedPending':
      'Yeni PIN hazır. Kaydet’e basınca uygulanacak.',
  'profiles.action.prompt': 'Ne yapmak istersiniz?',
  'profiles.action.switch': 'Bu profile geç',
  'profiles.action.edit': 'Düzenle',
  'profiles.recovery.set': 'Kurtarma anahtarı belirleyin',
  'profiles.recovery.setHint':
      'PIN’i unutursanız bu anahtarla sıfırlarsınız. Güvenli bir yerde saklayın.',
  'profiles.recovery.hint': 'Özel anahtarınız',
  'profiles.recovery.enter': 'Kurtarma anahtarını girin',
  'profiles.recovery.enterHint':
      '«@name» profilinin PIN’ini sıfırlamak için belirlediğiniz anahtarı yazın.',
  'profiles.recovery.wrong': 'Kurtarma anahtarı hatalı.',
  'profiles.recovery.notSet':
      'Bu profil için kurtarma anahtarı tanımlı değil. Ayarlardan profili düzenleyerek sıfırlayabilirsiniz.',
  'profiles.recovery.reset': 'Anahtar ile PIN sıfırla',
  'profiles.recovery.resetDone': 'PIN kurtarma anahtarı ile sıfırlandı.',
  'profiles.recovery.ownerResetBody':
      '"@name" profilinde kurtarma anahtarı tanımlı değil. Cihaz sahibi olarak yeni bir PIN belirleyerek kilidi sıfırlamak istiyor musunuz?',
  'cloud.autoBackup.title': 'Otomatik yedekleme',
  'cloud.autoBackup.body':
      'Ayarlarınız ve listeleriniz seçtiğiniz aralıkta arka planda otomatik olarak Google\'a yedeklenir.',
  'cloud.autoBackup.off': 'Kapalı',
  'cloud.autoBackup.daily': 'Günde bir',
  'cloud.autoBackup.weekly': 'Haftada bir',
  'backupRestore.localSection': 'Yerel dosya yedekleme',
  'settings.tile.cloudSync': 'Google Bulut Senkronu',
  'setup.tvTitle': 'Oynatma listesini girin',
  'setup.tv.brand': 'Mina Player TV',
  'setup.tv.welcome': 'Kuruluma hoş geldiniz',
  'setup.tv.subtitle':
      'Aşağıdan bir yöntem seçin; liste eklendikten sonra uygulama açılır.',
  'setup.tv.methodUrl': '1. Yöntem: M3U URL',
  'setup.tv.methodFile': '2. Yöntem: M3U dosyası',
  'setup.tv.methodXtream': '3. Yöntem: Xtream',
  'setup.tv.urlConnect': 'URL ile bağlan',
  'setup.tv.filePick': 'Dosya seç',
  'setup.tv.xtreamLogin': 'Giriş yap',
  'setup.tv.demo': 'Demo modu',
  'setup.tv.langLine': 'Dil, cihazla aynı (otomatik).',
  'setup.tv.xtreamServer': 'Sunucu URL',
  'setup.tv.xtreamUser': 'Kullanıcı adı',
  'setup.tv.xtreamPass': 'Şifre',
  'setup.tv.urlFieldHint': 'M3U çalma listesi URL’si',
  'setup.playerExoTitle': 'Better / ExoPlayer',
  'setup.playerExoSub':
      'Düşük gecikme, Android önerisi; çoğu canlı ve film için uygundur.',
  'setup.playerMkvTitle': 'MediaKit (mpv)',
  'setup.playerMkvSub':
      'Daha ağır akışlarda / özel altyapıda alternatif; ayarlardan değiştirilebilir.',
  'setup.playerVlcSub':
      'libVLC tabanlı üçüncü motor; bazı akışlarda daha uyumlu olabilir.',
  'integrity.dialog.title': 'Resmi sürüm önerisi',
  'integrity.dialog.body':
      'Bu kopya Google Play lisansıyla eşleşmiyor. En güvenli deneyim için uygulamayı Google Play’den yüklemenizi öneririz.',
  'integrity.dialog.later': 'Daha sonra',
  'integrity.dialog.openPlay': 'Google Play’de aç',

  // Zorunlu / önerilen güncelleme (Remote Config: zorunlu_surum_kontrolu)
  'update.forced.title': 'Güncelleme gerekli',
  'update.forced.body':
      'Bu sürüm artık desteklenmiyor. Devam etmek için lütfen uygulamayı en son sürüme güncelleyin.',
  'update.forced.later': 'Daha sonra',
  'update.forced.update': 'Şimdi güncelle',

  // Browse
  'browse.films': 'Filmler',
  'browse.series': 'Diziler',
  'browse.favorites': 'Favoriler',
  'browse.empty': 'Sonuç bulunamadı.',
  'browse.pickItem': 'Bir öğe seçin',
  'browse.tab.category': 'Kategori',
  'browse.tab.detail': 'Detay',
  'browse.categoriesHeader': 'Kategoriler',
  'browse.recentAdded': 'Son Eklenenler',
  'browse.recentlyWatched': 'Son İzlenenler',
  'browse.seriesShort': 'Dizi',
  'browse.season': 'Sezon',
  'browse.episodes': 'Bölümler',
  'browse.series.seasonLabel': 'Sezon @n',
  'browse.series.seasonCount': '@n Sezon',
  'browse.series.readMore': 'Devamını oku',
  'browse.series.readLess': 'Daha az göster',
  'browse.episode.number': 'Bölüm @n',
  'browse.castHeading': 'Oyuncular',
  'browse.seriesEpgButton': 'Detay',
  'browse.seriesEpgEmpty': 'Bu dizi için ayrıntılı bilgi bulunamadı.',
  'browse.playFullscreen': 'Tam ekran oynat',
  'browse.selectEpisode': 'Bölüm seçin',
  'browse.notPlayable': 'Oynatılamıyor',
  'browse.section.onNow': 'Şu an',
  'browse.badge.live': '• Canlı',
  'browse.section.movie': 'Film',
  'browse.section.preview': 'Önizleme',
  'browse.favorite': 'Favori',
  'browse.detail.epg':
      'Bu kanal için EPG akışı henüz bağlı değil. Yayın bilgisi geldiğinde program adı ve özet burada görünecek.\n\nSeçili: @title',
  'browse.detail.movie':
      'Film detayı ve açıklama kaynaktan gelmediğinde burada özet gösterilir.\n\nSüre: @duration\nSeçili: @name',
  'browse.duration.unknown': 'Süre bilgisi yok',
  'browse.duration.minutes': '@n dk',
  'browse.vod.trailer': 'Fragman',
  'browse.vod.trailerMissing': 'Bu film için fragman bağlantısı yok.',
  'browse.vod.overview': 'Özet:',
  'browse.vod.shortInfo': 'Kısa film bilgisi',
  'browse.vod.metaLine.genre': 'Tür: @v',
  'browse.vod.metaLine.director': 'Yönetmen: @v',
  'browse.vod.metaLine.cast': 'Oyuncular: @v',
  'browse.vod.metaLine.release': 'Yayın: @v',
  'browse.vod.metaLine.rating': 'Puan: @v',
  'browse.vod.noSynopsis': 'Bu film için kaynakta özet bulunmuyor.',
  'browse.vod.trailerOpenFail': 'Fragman açılamadı.',

  // Channels
  'channels.search': 'Kanal ara…',
  'channels.searchDialogTitle': 'Kanal ara',
  'channels.searchSubmit': 'Ara',

  // Recent searches (canlı TV / film & dizi / ana ekran arama diyalogları)
  'search.recent.title': 'Son aramalar',
  'search.recent.clear': 'Temizle',

  // Ses Equalizer (Oynatma Ayarları → Ses Equalizer)
  'settings.tile.equalizer': 'Ses Equalizer',
  'settings.tile.equalizer.off': 'Kapalı',
  'settings.tile.equalizer.sub': 'Aktif · @p',
  'settings.equalizer.title': 'Ses Equalizer',
  'settings.equalizer.hint':
      '10 bantlı grafik EQ. MediaKit (libmpv) motoruyla anında uygulanır; BetterPlayer (ExoPlayer) motorunda devre dışıdır.',
  'settings.equalizer.enable': 'Equalizer\'i aç',
  'settings.equalizer.preamp': 'Preamp',
  'settings.equalizer.reset': 'Sıfırla',
  'settings.equalizer.preset.title': 'Hazır ayar',
  'settings.equalizer.preset.flat': 'Düz',
  'settings.equalizer.preset.bassBoost': 'Bas Boost',
  'settings.equalizer.preset.trebleBoost': 'Tiz Boost',
  'settings.equalizer.preset.vocal': 'Vokal',
  'settings.equalizer.preset.rock': 'Rock',
  'settings.equalizer.preset.pop': 'Pop',
  'settings.equalizer.preset.jazz': 'Caz',
  'settings.equalizer.preset.classical': 'Klasik',
  'settings.equalizer.preset.electronic': 'Elektronik',
  'settings.equalizer.preset.acoustic': 'Akustik',
  'settings.equalizer.preset.custom': 'Özel',
  'settings.equalizer.engine.mediaKit': 'MediaKit (mpv) — tam destek',
  'settings.equalizer.engine.betterPlayer': 'BetterPlayer (ExoPlayer)',
  'settings.equalizer.engine.betterPlayer.unsupported':
      'Bu cihazda Android sistem equalizer\'ı kullanılamıyor (Android 9+ kısıtı). BetterPlayer akışlarında EQ uygulanmaz.',
  'settings.equalizer.engine.betterPlayer.platform':
      'Bu platformda BetterPlayer için EQ köprüsü yok; yalnızca MediaKit akışlarına uygulanır.',
  'channels.title': 'Kanallar',
  'channels.empty': 'Kanal bulunamadı.',
  'channels.pick': 'Kanal seçin',
  'channels.tab.categories': 'Kategoriler',
  'channels.tab.channels': 'Kanallar',
  'channels.tab.detail': 'Detay',
  'channels.tab.epgTimeline': 'EPG',
  'channels.epgTimeline.title': 'EPG zaman çizelgesi',
  'channels.epgTimeline.axis': 'Saat',
  'channels.epgTimeline.truncated':
      'Liste uzun; yalnızca ilk @n kanal gösteriliyor.',
  'channels.epgTimeline.upNext': 'Sırada',
  'channels.epgTimeline.noSummary': 'Özet yok.',
  'channels.epgTimeline.playlistSource': 'Oynatma listesi',
  'channels.epgTimeline.noProgrammeInfo': 'Program bilgisi yok',
  'channels.epgTimeline.minutesLeft': '@n dk kaldı',
  'channels.epgTimeline.endsUnderMinute': 'Bir dakikadan az kaldı',
  'channels.epgTimeline.metaGroup': 'Grup: @name',
  'channels.allChannels': 'Tüm kanallar',
  'channels.favoritesCategory': 'Favoriler',
  'channels.recentlyWatchedCategory': 'Son İzlenenler',
  'channels.favoritesCategoryEmpty':
      'Henüz favori kanal yok. Bir kanalı kalp ikonu ile favorilere ekleyin.',
  'channels.detail.sameCategory': 'Bu kategorideki kanallar',
  'channels.detail.sameCategoryNamed': '@name kanalları',

  // Common
  'common.play': 'Oynat',
  'common.notPlayable': 'Oynatılamıyor',
  'common.favorite': 'Favori',
  'common.back': 'Geri',
  'common.close': 'Kapat',
  'common.cancel': 'Vazgeç',
  'common.confirm': 'Onayla',
  'common.delete': 'Sil',
  'common.save': 'Kaydet',
  'common.refreshNow': 'Şimdi yenile',
  'common.clear': 'Temizle',
  'common.done': 'Tamam',
  'common.retry': 'Tekrar dene',
  'common.ok': 'Tamam',
  'common.later': 'Daha Sonra',
  'common.success': 'Başarılı',
  'common.error': 'Bir hata oluştu',
  'common.yes': 'Evet',
  'common.no': 'Hayır',
  'common.active': 'Aktif',
  'common.inactive': 'Pasif',
  'common.on': 'Açık',
  'common.off': 'Kapalı',
  'common.loading': 'Yükleniyor…',
  'common.fetching': 'Yükleniyor…',
  'common.copy': 'Kopyala',
  'common.copied': 'Kopyalandı',
  'common.show': 'Göster',
  'common.hide': 'Gizle',

  'rateApp.title': 'Beğendiniz mi?',
  'rateApp.body':
      'Yeni sürümü yüklediğiniz için teşekkürler. Google Play’de 5 yıldız ve kısa bir yorum bırakırsanız geliştirmeye büyük katkı sağlarsınız.',
  'rateApp.cta': 'Play Store’da değerlendir',
  'rateApp.later': 'Şimdi değil',

  // Speed Test
  'settings.speed_test.title': 'Hız Testi',
  'settings.speed_test.start': 'Testi Başlat',
  'settings.speed_test.testing': 'Test Ediliyor...',
  'settings.speed_test.completed': 'Test Tamamlandı',
  'settings.speed_test.retry': 'Tekrar Dene',
  'settings.speed_test.download': 'İndirme Hızı',
  'settings.speed_test.last_result': 'Son Test Sonucu',
  'settings.speed_test.info.title': 'Hız Sınırları',
  'settings.speed_test.threshold.very_slow':
      'Çok Yavaş - Donmalar ve takılmalar yaşayabilirsiniz',
  'settings.speed_test.threshold.borderline':
      'Sınırda - HD yayınlarda anlık takılmalar olabilir',
  'settings.speed_test.threshold.excellent':
      'Harika - Kesintisiz yayın izleyebilirsiniz',
  'settings.speed_test.message.very_slow':
      'İnternet hızınız çok düşük. Donmalar yaşamanız normaldir. Lütfen ağınızı kontrol edin.',
  'settings.speed_test.message.borderline':
      'İnternet hızınız sınırda. HD yayınlarda anlık takılmalar olabilir.',
  'settings.speed_test.message.excellent':
      'İnternet hızınız harika. Kesintisiz yayın izleyebilirsiniz.',
  'settings.speed_test.analysis.very_slow': 'Çok Düşük Hız',
  'settings.speed_test.analysis.borderline': 'Sınır Hız',
  'settings.speed_test.analysis.excellent': 'Harika Hız',
  'settings.speed_test.error.title': 'Hata',
  'settings.speed_test.error.no_internet': 'Lütfen internete bağlanın',
  'settings.speed_test.error.test_failed': 'Test başarısız oldu: @error',
  'settings.tile.speedTest': 'Hız Testi',
  'settings.tile.speedTest.sub': 'İnternet hızını ölç',
  'common.lang.tr': 'Türkçe',
  'common.lang.en': 'İngilizce',
  'common.lang.fr': 'Fransızca',
  'common.lang.ar': 'Arapça',
  'common.lang.zh': 'Çince',
  'common.lang.ru': 'Rusça',
  'common.lang.ja': 'Japonca',
  'common.lang.es': 'İspanyolca',
  'common.lang.ko': 'Korece',
  'common.lang.he': 'İbranice',
  'common.lang.da': 'Danca',
  'common.lang.sv': 'İsveççe',
  'common.lang.hi': 'Hintçe',
  'common.lang.th': 'Tayca',
  'common.lang.it': 'İtalyanca',
  'common.lang.pt': 'Portekizce',
  'common.lang.id': 'Endonezce',
  'common.lang.de': 'Almanca',
  'common.lang.fa': 'Farsça',
  'common.lang.pl': 'Lehçe',
  'common.lang.nl': 'Felemenkçe',
  'common.lang.uk': 'Ukraynaca',
  'common.lang.vi': 'Vietnamca',
  'common.lang.el': 'Yunanca',
  'common.lang.ro': 'Rumence',
  'common.lang.sq': 'Arnavutça',

  // Search hints
  'search.channel': 'Kanal ara…',
  'search.film': 'Film ara…',
  'search.series': 'Dizi ara…',
  'search.favorite': 'Favori ara…',

  // Layout mode
  'layout.mobile': 'Mobil',
  'layout.tablet': 'Tablet',
  'layout.tv': 'TV',
  'layout.mobile.sub': 'Telefon için dokunma ve kompakt liste.',
  'layout.tablet.sub': 'Geniş ekran, orta boy yazı ve aralıklar.',
  'layout.tv.sub': 'Uzaktan kumanda ve uzak izleme için büyük yazı.',
  'layout.dialog.phone.sub': 'Dikey / yatay serbest',
  'layout.dialog.tv.sub': 'Yatay kilit (kumanda odaklı)',

  // Theme (display names)
  'theme.defaultName': 'Varsayılan',
  'theme.darkGlass': 'Koyu Cam',
  'theme.amoledBlack': 'Amoled Black',
  'theme.glassmorphism': 'Glassmorphism',
  'theme.darkFlat': 'Dark Flat',
  'theme.glassGri': 'Glass Gri',
  'theme.flatBlack': 'Flat Black',
  'theme.minaGlass': 'Mina Glass',
  'theme.semcTheme': 'SEMC Theme',
  'theme.flyUi': 'Fly UI',
  'theme.flyUi.sub': 'Flyme tarzı buzlu cam ve mavi vurgu',
  'theme.tvLite': 'TV Lite',
  'theme.ios27': 'OS27',
  'theme.ios27.sub':
      'iOS damla cam (Liquid Glass): saydam paneller, mavi vurgu, akışkan cam duvar kağıdı',
  'theme.macTema': 'Mac Tema',
  'theme.macTema.sub':
      'macOS Tahoe: Apple koyu cam paneller, Apple mavisi vurgu, Tahoe dalga duvar kağıdı',
  'theme.mint': 'Mint',
  'theme.mint.sub': 'Linux Mint yeşil vurgulu, yarı saydam paneller',

  // Settings — sections & tiles
  'settings.title': 'Ayarlar',
  'settings.language': 'Uygulama Dili',
  'settings.deviceMode': 'Cihaz modu',
  'settings.phone': 'Telefon',
  'settings.tv': 'TV',
  'settings.blurReduce': 'Blur azalt (performans)',
  'settings.blurReduce.subtitle':
      'Düşük GPU kullanımı için blur efektini azalt',
  'settings.launchOnBoot': 'Cihaz açılınca otomatik aç',
  'settings.launchOnBoot.subtitle':
      'Cihaz yeniden başlatıldığında uygulamayı aç',
  'settings.section.general': 'Genel Ayarlar',
  'settings.section.about': 'Uygulama Bilgileri',
  'settings.tile.playlist': 'Playlist Listesi',
  'settings.tile.playlist.sub': 'Kaynağı görüntüle veya değiştir',
  'settings.tile.refresh': 'İçerikleri Yenile',
  'settings.tile.refresh.loading': 'Yenileniyor…',
  'settings.tile.refresh.sub': 'Sunucudan son listeyi çek',
  'settings.tile.autoRefresh': 'Otomatik Yenileme',
  'settings.tile.autoRefresh.sub': '@days günde bir',
  'settings.tile.account': 'Hesap Bilgileri',
  'settings.tile.account.sub': 'Xtream abonelik bilgilerini gör',
  'settings.tile.parental': 'Ebeveyn denetimi',
  'settings.tile.parental.sub':
      'PIN ile koruma; Xtream kategorilerini gizleyin (canlı, film, dizi)',
  'settings.tile.xtreamApiEpgOnly': 'Yalnızca Xtream API EPG',
  'settings.tile.xtreamApiEpgOnly.on':
      'Açık: panel XMLTV atlanıyor, yalnızca get_all_live_epg',
  'settings.tile.xtreamApiEpgOnly.off':
      'Kapalı: panel XMLTV ile API EPG birlikte (paralel)',
  'settings.xtreamCategoryHide.title': 'Kategori göster / gizle',
  'settings.xtreamCategoryHide.unavailable':
      'Önce bir oynatma listesi yükleyin (Xtream veya M3U).',
  'settings.xtreamCategoryHide.tabLive': 'Canlı',
  'settings.xtreamCategoryHide.tabVod': 'Filmler',
  'settings.xtreamCategoryHide.tabSeries': 'Diziler',
  'settings.xtreamCategoryHide.emptyLive': 'Canlı kategori listesi boş.',
  'settings.xtreamCategoryHide.emptyVod': 'Film kategorisi listesi boş.',
  'settings.xtreamCategoryHide.emptySeries': 'Dizi kategorisi listesi boş.',
  'settings.xtreamCategoryHide.idLabel': 'Kimlik: @id',
  'settings.xtreamCategoryHide.m3uNameHint':
      'M3U: group-title adına göre (liste yenilense de kalır)',
  'settings.xtreamCategoryHide.saved': 'Kategori gizleme kaydedildi.',
  'settings.xtreamCategoryHide.reorderHint':
      'Sıralamayı değiştirmek için sağdaki tutamaçtan sürükleyin.',
  'settings.xtreamCategoryHide.visibilityHint':
      'Anahtar açık = kategori görünür, kapalı = gizli.',
  'settings.xtreamCategoryHide.hideAll': 'Tümünü Gizle',
  'settings.xtreamCategoryHide.showAll': 'Tümünü Göster',
  'settings.tile.categoryHide': 'Kategori göster / gizle',
  'settings.tile.categoryHide.sub':
      'Kanallar, filmler ve diziler için kategori göster / gizle',
  'settings.tile.channelLayout': 'Kanal Kategori Düzeni',
  'settings.tile.channelLayout.sub':
      'Kategori gizleme ve canlı kanal düzeni (sıralama / çıkarma) tek noktada',
  'settings.tile.playback': 'Oynatma Ayarları',
  'settings.tile.playback.sub':
      'Oynatıcı motoru, donanım hızlandırma, video kod çözücü ve düşük gecikme buffer',
  'settings.tile.keyMapping': 'Kumanda Tuş Atama',
  'settings.tile.keyMapping.sub':
      'Kumanda üzerindeki boş veya özel tuşlara hızlı eylemler atayın',
  'settings.osdSizeTier.title': 'Osd Panel Büyüklüğü',
  'settings.osdSizeTier.subtitle': 'Oynatıcı arayüzünün (OSD) ekrandaki boyutunu ayarlar.',
  'settings.osdSizeTier.small': 'Küçük',
  'settings.osdSizeTier.normal': 'Normal',
  'settings.osdSizeTier.large': 'Büyük',
  'settings.osdSizeTier.extraLarge': 'Çok Büyük',
  'settings.keyMapping.success.title': 'Başarılı',
  'settings.keyMapping.success.msg': '"{action}" eylemine "{key}" tuşu atandı.',
  'playbackSettings.title': 'Oynatma Ayarları',
  'playbackSettings.hint':
      'Oynatıcı motoru ve düşük seviye video ayarları. Yayın takılırsa motoru değiştirip veya kod çözücüyü yazılıma alıp deneyebilirsin.',
  'playbackSettings.inAppPip.title': 'Uygulama İçi PiP',
  'playbackSettings.inAppPip.subOn':
      'Ana ekrana dönünce yayın küçük oynatıcıda devam eder',
  'playbackSettings.inAppPip.subOff':
      'Ana ekrana dönünce yayın durur',
  'playbackSettings.inAppPip.handheldOnly':
      'Yalnızca mobil ve tablette kullanılabilir',
  'playbackSettings.inAppPip.blockedLiveMediaKit':
      'Canlı motor MediaKit iken uygulama içi PiP kapalıdır',
  'inAppPip.suggest.title': 'Uygulama İçi PiP',
  'inAppPip.suggest.body':
      'Yayından ana ekrana döndüğünüzde yayın küçük oynatıcıda devam eder. Vitrin ve kart düzeninde çalışır. Denemek ister misiniz?',
  'inAppPip.suggest.enable': 'Aç',
  'inAppPip.suggest.later': 'Sonra',
  'settings.tile.silentSync': 'Arka Planda Sessiz Senkronizasyon',
  'settings.tile.silentSync.sub': 'Uygulama kapalıyken listeyi sessizce günceller',
  'settings.tile.silentSync.enabled': 'Açık (Günde bir kez güncellenir)',
  'settings.tile.silentSync.disabled': 'Kapalı',
  'settings.tile.otherTools': 'Diğer Araçlar',
  'settings.tile.otherTools.sub':
      'Uyku zamanlayıcısı, EPG, tema, yedekleme, hız testi, titreşim ve font',
  'otherTools.title': 'Diğer Araçlar',
  'otherTools.hint':
      'Daha seyrek kullanılan yardımcı araçlar tek bir yerde toplandı.',
  'otherTools.inAppPip.title': 'Uygulama İçi PiP',
  'otherTools.inAppPip.subOn':
      'Vitrin ana ekranında mini oynatıcı açık',
  'otherTools.inAppPip.subOff':
      'Ana ekrana dönünce yayın durur',
  'channelLayout.title': 'Kanal Kategori Düzeni',
  'channelLayout.hint':
      'Kategorileri gizleyebilir ve canlı kanal listenin sırasını/içeriğini düzenleyebilirsin. Her seçenek kendi düzenleyicisini açar; geri dönüldüğünde değişiklikler ana ekrana yansır.',
  'channelEditor.title': 'Canlı kanal düzeni',
  'channelEditor.unavailable':
      'Önce bir oynatma listesi yükleyin (Xtream veya M3U).',
  'channelEditor.hint':
      'Üstten canlı kategori seçin. Kumanda: ◀ ▶ veya ▲ ▼ ile sıra · Sil ile kanalı listeden çıkarın.',
  'channelEditor.emptyCategory': 'Bu kategoride kanal yok.',
  'channelEditor.saved': 'Kanal düzeni kaydedildi.',
  'channelEditor.removeTitle': 'Kanalı listeden çıkar',
  'channelEditor.removeBody':
      'Kanal uygulama listesinde görünmez. Listeyi yeniden yüklemek veya tüm ayarları sıfırlamak geri alabilir.',
  'channelEditor.idLabel': 'Kimlik: @id',
  'settings.tile.channelListEdit': 'Canlı kanal düzeni',
  'settings.tile.channelListEdit.sub':
      'Yalnızca canlı TV: kategori seçip kanalları sıralayın veya çıkarın',
  'settings.tile.homeCardOrder': 'Ana ekran kart sırası',
  'settings.tile.homeCardOrder.sub':
      'Canlı TV, film, dizi, Film & Dizi, EPG Mix ve Mina İzleme Analizi kartlarının sırası',
  'settings.tile.homeSettings': 'Ana Ekran Ayarları',
  'settings.tile.homeSettings.sub':
      'Kart sırası, karışık canlı TV ve sıradaki maçlar',
  'homeSettings.title': 'Ana Ekran Ayarları',
  'homeSettings.hint':
      'Aşağıdaki anahtarlar ana ekranda hangi şeritlerin görüneceğini belirler. Her satırın altındaki önizleme, açıldığında nelerin yer alacağını gösterir.',
  'homeSettings.cardOrder.title': 'Kart sırası',
  'homeSettings.cardOrder.sub':
      'Canlı TV, filmler, diziler, favoriler vb. büyük kartların sırasını düzenle',
  'homeSettings.cardScale.title': 'Kart boyutu',
  'homeSettings.cardScale.sub':
      'Ana ekrandaki tüm kartların ve şeritlerin boyutunu küçült/büyüt',
  'homeSettings.cardScale.small': 'Küçük',
  'homeSettings.cardScale.standard': 'Standart',
  'homeSettings.cardScale.large': 'Büyük',
  'homeSettings.cardScale.tvHint':
      'Kumanda: ◀ ▶ boyutu değiştirir, ▲ ▼ sonraki seçeneğe gider',
  'homeSettings.mixedLive.title': 'Karışık Canlı TV',
  'homeSettings.mixedLive.sub':
      'Açıkken ana ekrana farklı kategorilerden rastgele canlı kanallar şeridi eklenir',
  'homeSettings.trendFilms.title': 'Trend Filmler',
  'homeSettings.trendFilms.sub':
      'Yalnızca vitrin düzeninde: IMDB 7 puan ve üzeri en iyi 50 filmi şerit olarak gösterir (nadir aralıklarla yenilenir)',
  'homeSettings.upcomingEpg.title': 'Sıradaki Yayınlar (EPG)',
  'homeSettings.upcomingEpg.sub':
      'Yalnızca vitrin düzeninde: popüler kanalların sıradaki yayın saatlerini ve geri sayımlarını gösterir',
  'showcase.upcomingEpg.header': 'Sıradaki Yayınlar',
  'showcase.upcomingEpg.next': 'Sıradaki',
  'showcase.upcomingEpg.onAir': 'Şu An Yayında',
  'showcase.upcomingEpg.starting': 'Başlıyor',
  'showcase.upcomingEpg.ending': 'Bitiyor',
  'homeSettings.trendSeries.title': 'Trend Diziler',
  'homeSettings.trendSeries.sub':
      'Yalnızca vitrin düzeninde: IMDB 7 puan ve üzeri en iyi 50 diziyi şerit olarak gösterir (nadir aralıklarla yenilenir)',
  'homeSettings.favoriteFilms.title': 'Favori Filmler',
  'homeSettings.favoriteFilms.sub':
      'Yalnızca vitrin düzeninde: favorilere eklediğin filmleri ana ekranda şerit olarak gösterir',
  'homeSettings.favoriteSeries.title': 'Favori Diziler',
  'homeSettings.favoriteSeries.sub':
      'Yalnızca vitrin düzeninde: favorilere eklediğin dizileri ana ekranda şerit olarak gösterir',
  'homeSettings.mixedFilms.title': 'Karışık Filmler',
  'homeSettings.mixedFilms.sub':
      'Yalnızca vitrin düzeninde: tüm kategorilerden rastgele karışık filmleri ana ekranda şerit olarak gösterir',
  'homeSettings.mixedSeries.title': 'Karışık Diziler',
  'homeSettings.mixedSeries.sub':
      'Yalnızca vitrin düzeninde: tüm kategorilerden rastgele karışık dizileri ana ekranda şerit olarak gösterir',
  'homeSettings.lastWatchedButton.title': 'Son İzlenen Butonu',
  'homeSettings.lastWatchedButton.sub':
      'Vitrin düzeninde arama butonunun üzerindeki son izlenen dairesel butonu gösterir/gizler',
  'homeSettings.upcomingMatches.title': 'Sıradaki Maçlar',
  'homeSettings.upcomingMatches.sub':
      'Yaklaşan futbol/spor karşılaşmalarını ana ekranda kart şeridi olarak göster',
  'homeSettings.continueWatching.title': 'İzlemeye Devam Et',
  'homeSettings.continueWatching.sub':
      'Yarıda bıraktığın film ve dizileri, en son izlediğinden başlayarak ana ekranda göster. Kapatıldığında şerit kaldırılır.',
  'homeSettings.aiRecommendations.title':
      'Yapay Zekâ Destekli Ana Ekran Önerileri',
  'homeSettings.aiRecommendations.sub':
      'Mina AI izleme alışkanlığını analiz eder; kategori ve saat dilimine göre 10 karma canlı/film/dizi önerir',
  'homeSettings.reduceBlur.title': 'Bulanıklığı Azalt (Hız)',
  'homeSettings.reduceBlur.sub':
      'Arka plan ve cam yüzeylerdeki bulanıklığı kapatır. Açıkken işlemci yükü ve ısınma azalır, kaydırmalar daha akıcı olur. Düşük donanımlı cihazlarda önerilir.',
  'homeSettings.dailyQuote.title': 'Günün Sözü',
  'homeSettings.dailyQuote.sub':
      'Ana ekranın üst kısmında haftanın gününe göre değişen kısa karşılama mesajını göster. Kapatıldığında şerit ve çevresindeki boşluk kaldırılır.',
  'homeSettings.dailyQuote.previewText': 'Haftaya enerjiyle başla!',
  'homeSettings.swipeEffect.title': 'Sürükleme Efekti',
  'homeSettings.swipeEffect.sub':
      'Ana ekrandaki kategori kartları arasında sağa/sola sürüklerken kullanılacak geçiş efektini seç.',
  'homeSettings.swipeEffect.default.title': 'Varsayılan',
  'homeSettings.swipeEffect.default.sub':
      'Yan kartlar küçülür ve hafif silikleşir — performansı en hafif geçiş.',
  'homeSettings.swipeEffect.blur.title': 'Bulanıklık Geçişi',
  'homeSettings.swipeEffect.blur.sub':
      'Geçiş anında çıkan kart bulanır (0→18 sigma), ortadaki kart net kalır.',
  'homeSettings.swipeEffect.tintSweep.title': 'Renk Süpürme',
  'homeSettings.swipeEffect.tintSweep.sub':
      'Geçiş yönüne göre tema renkli gradient yan kartların üzerinden kayar.',
  'homeSettings.swipeEffect.rubberBand.title': 'Lastik Bandı',
  'homeSettings.swipeEffect.rubberBand.sub':
      'Kart sayfa sonuna geldiğinde elastik şekilde geri çekilir, snap-back overshoot uygulanır.',
  'homeSettings.transitionEffect.title': 'Geçiş Efekti',
  'homeSettings.transitionEffect.sub':
      'Sayfalar arası geçiş animasyonunu seç.',
  'homeSettings.transitionEffect.ios.title': 'iOS',
  'homeSettings.transitionEffect.ios.sub':
      'iOS tarzı sağdan sola kaydırma geçişi.',
  'homeSettings.transitionEffect.fadeScale.title': 'Yumuşak',
  'homeSettings.transitionEffect.fadeScale.sub':
      'Yumuşak fade + scale geçişi.',
  'homeSettings.transitionEffect.jelly.title': 'Sallanan Pencereler',
  'homeSettings.transitionEffect.jelly.sub':
      'Linux Compiz tarzı sallanan, elastik pencere geçişi.',
  'homeSettings.frameStyle.title': 'Çerçeve Stili',
  'homeSettings.frameStyle.sub':
      'Ana ekrandaki kategori kartları, izlemeye devam et, Mina AI ve yüksek puanlı filmler şeritlerine ortak çerçeve görünümü uygula.',
  'homeSettings.frameStyle.classic.title': 'Klasik',
  'homeSettings.frameStyle.classic.sub':
      'Varsayılan cam çerçeve — ince beyaz kenarlık ve hafif gölge.',
  'homeSettings.frameStyle.neonGlow.title': 'Neon Parıltı',
  'homeSettings.frameStyle.neonGlow.sub':
      'Kartın etrafında tema renginde yumuşak ışık halesi ve ince primary kenarlık.',
  'homeSettings.frameStyle.embossed.title': 'Kabartmalı',
  'homeSettings.frameStyle.embossed.sub':
      'Üstte hafif beyaz ışık, altta belirgin gölge — içbükey 3D hissi veren modern stil.',
  'homeSettings.frameStyle.boldOutline.title': 'Kalın Kontur',
  'homeSettings.frameStyle.boldOutline.sub':
      'Kartın iç kenarında kalın tema renkli çerçeve — keskin ve net bir görünüm.',
  'setup.continueWatchingTitle': 'İzlemeye Devam Et',
  'setup.continueWatchingSub':
      'Yarıda bıraktığın film ve dizileri ana ekranda göster',
  'setup.aiRecommendationsTitle': 'Yapay Zekâ Destekli Ana Ekran Önerileri',
  'setup.aiRecommendationsSub':
      'Geçmiş izlemelere göre kişiselleştirilmiş 10 öneri (canlı, film, dizi) göster',
  'setup.filmDiziMode.title': 'Film & Dizi modu',
  'setup.filmDiziMode.sub':
      'Ana ekranda film ve dizileri nasıl göstereceğini seç — sonrasında ayarlardan değiştirebilirsin',
  'homeSettings.filmDiziMode.title': 'Film & Dizi modu',
  'homeSettings.filmDiziMode.sub':
      'Ana ekranda Film & Dizi, ayrı Filmler/Diziler veya her ikisini de göster',
  'homeSettings.filmDiziMode.modern.title': 'Modern (Film & Dizi)',
  'homeSettings.filmDiziMode.modern.sub':
      'Ana ekranda tek bir «Film & Dizi» kartı; filmler ve diziler bu kartın içinde tek sekme',
  'homeSettings.filmDiziMode.classic.title': 'Klasik (Ayrı Filmler/Diziler)',
  'homeSettings.filmDiziMode.classic.sub':
      'Ana ekranda «Filmler» ve «Diziler» kartları ayrı ayrı görünür',
  'homeSettings.filmDiziMode.both.title': 'Her İkisi',
  'homeSettings.filmDiziMode.both.sub':
      'Hem «Film & Dizi» hem de ayrı «Filmler» + «Diziler» kartları aynı anda görünür',
  'homeSettings.layoutStyle.title': 'Yerleşim modu',
  'homeSettings.layoutStyle.sub':
      'Ana ekranın görünümünü seç: tam özellikli kart düzeni ya da vitrin düzeni',
  'homeSettings.layoutStyle.standard.title': 'Kart Düzeni',
  'homeSettings.layoutStyle.standard.sub':
      'Şeritler, devam et ve tüm kartlarla tam ana ekran',
  'homeSettings.layoutStyle.showcase.title': 'Vitrin düzeni',
  'homeSettings.layoutStyle.showcase.sub':
      'Dikey kayan poster şeritleri + altta damla cam menü çubuğu (Canlı TV · Film & Dizi · EPG Mix · Mina Wrapped · Ayarlar). Yalnızca telefon/tablet.',
  'homeSettings.tvLayout.hint':
      'TV ana ekranında hangi düzeni kullanacağınızı seçin.',
  'homeSettings.tvLayout.title': 'Ana ekran düzeni',
  'homeSettings.tvLayout.sub':
      'Kartlı ana ekran veya yeni TV kabuğu (sol menü + paneller)',
  'homeSettings.tvLayout.classic.title': 'Kart Düzeni',
  'homeSettings.tvLayout.classic.sub':
      'Kategori kartları ve şeritlerle klasik ana ekran',
  'homeSettings.tvLayout.shell.title': 'TV modu',
  'homeSettings.tvLayout.shell.sub':
      'Sol menüden Canlı TV, Filmler, Diziler ve ayarlara hızlı erişim',
  'tvShell.section.search': 'Arama',
  'tvShell.section.live': 'Canlı TV',
  'tvShell.section.movies': 'Filmler',
  'tvShell.section.series': 'Diziler',
  'tvShell.section.playlists': 'Listeler',
  'tvShell.section.continueWatching': 'İzlemeye Devam Et',
  'tvShell.continueWatching.title': 'İzlemeye Devam Et',
  'tvShell.continueWatching.subtitle': 'Kanallar, watchlist, devam edenler ve izlenenler',
  'tvShell.continueWatching.empty': 'Yarıda bırakılmış film veya dizi bulunamadı.',
  'tvShell.playlists.subtitle':
      'Bir liste seçin; canlı TV, filmler ve diziler yalnızca o listenin içeriğini gösterir.',
  'tvShell.playlists.empty':
      'Henüz yüklü liste yok. Ayarlar → Playlist Yöneticisi bölümünden liste ekleyin.',
  'tvShell.playlists.active': 'Aktif',
  'tvShell.playlists.pleaseWait': 'Lütfen bekleyin…',
  'tvShell.section.settings': 'Ayarlar',
  'tvShell.rail.wrapper': 'Wrapper',
  'tvShell.rail.repeat': 'Tekrar',
  'tvShell.brand': 'Mina Player',
  'tvShell.category.empty': 'Kategori bulunamadı',
  'tvShell.category.allFilms': 'Tüm filmler',
  'tvShell.category.allSeries': 'Tüm diziler',
  'tvShell.category.favFilms': 'Favori filmler',
  'tvShell.category.favSeries': 'Favori diziler',
  'tvShell.category.popular50Films': 'Popüler 50 film',
  'tvShell.category.popular50Series': 'Popüler 50 dizi',
  'tvShell.hint.selectSection': 'Sol menüden bir bölüm seçin',
  'tvShell.live.channels': 'Kanallar',
  'tvShell.live.epg': 'EPG',
  'tvShell.live.noDescription': 'Program açıklaması yok',
  'tvShell.live.nextProgramme': 'Sıradaki',
  'tvShell.live.noEpg': 'Bu kanal için EPG bilgisi yok',
  'tvShell.live.pickChannel': 'Önizleme için bir kanal seçin',
  'tvShell.live.epgNotYet': 'EPG henüz bulunmuyor',
  'tvShell.touch.openMenu': 'Menü',
  'tvShell.movies.pickFilm': 'Önizleme için bir film seçin',
  'tvShell.movies.noFilms': 'Bu kategoride film yok',
  'tvShell.movies.upNext': 'Sıradaki filmler',
  'tvShell.movies.noPlot': 'Özet bilgisi yok',
  'tvShell.movies.play': 'Oynat',
  'tvShell.movies.externalPlayer': 'Harici oynatıcıda aç',
  'tvShell.movies.addFavorite': 'Favorilere ekle',
  'tvShell.series.pickSeries': 'Önizleme için bir dizi seçin',
  'tvShell.series.noSeries': 'Bu kategoride dizi yok',
  'tvShell.series.upNext': 'Sıradaki diziler',
  'tvShell.sort.title': 'Sırala',
  'tvShell.sort.alphabetical': 'Alfabetik',
  'tvShell.sort.rating': 'Puana göre (IMDb)',
  'tvShell.sort.random': 'Rastgele',
  'tvShell.sort.addedDate': 'Eklenme tarihi',
  'homeSettings.lockedByShowcase': 'Vitrin düzeninde kapalı',
  'home.continue_watching': 'İzlemeye Devam Et',
  'home.ai.title': 'Mina AI: Senin İçin Önerilenler',
  'home.ai.badge.live': 'Canlı',
  'home.ai.badge.film': 'Film',
  'home.ai.badge.series': 'Dizi',
  'homeCardOrder.title': 'Ana ekran kart sırası',
  'homeCardOrder.hint':
      'Kartları yukarı veya aşağı taşıyın. Kumanda: ▲ ▼ veya ◀ ▶ ile sıra değişir. Göz ikonuyla kartı ana ekrandan gizleyip yeniden gösterebilirsiniz.',
  'homeCardOrder.saved': 'Ana ekran kart sırası kaydedildi.',
  'homeCardOrder.reset': 'Varsayılan',
  'homeCardOrder.moveUp': 'Yukarı',
  'homeCardOrder.moveDown': 'Aşağı',
  'homeCardOrder.hideCard': 'Bu kartı ana ekrandan gizle',
  'homeCardOrder.showCard': 'Bu kartı ana ekranda göster',
  'homeCardOrder.hiddenBadge': 'Gizli',
  'homeCardOrder.card.live': 'Canlı TV',
  'homeCardOrder.card.films': 'Filmler',
  'homeCardOrder.card.series': 'Diziler',
  'homeCardOrder.card.recommendedFilms': 'Film & Dizi',
  'homeCardOrder.card.epgMix': 'EPG Mix',
  'homeCardOrder.card.minaAnalytics': 'Mina İzleme Analizi',
  'analytics.title': 'Mina Wrapped & İzleme Analitiği',
  'analytics.toggle.title': 'Mina Wrapped & İzleme Analitiği',
  'analytics.toggle.sub':
      'Cuma akşamları en çok hangi kanalı izlediğinizi şık grafiklerle keşfedin. Tüm veriler yalnızca cihazınızda kalır.',
  'analytics.toggle.previewHabit':
      'En çok Cuma akşamları ekrana kilitleniyorsunuz.',
  'analytics.entry.title': 'Mina Wrapped & İzleme Analitiği',
  'analytics.entry.sub': 'İzleme alışkanlıklarınızı şık grafiklerle özetleyin.',
  'analytics.entry.openTitle': 'Wrapped Özetini Aç',
  'analytics.entry.openSub':
      'Haftalık, aylık ve yıllık izleme özetinizi görüntüleyin.',
  'analytics.range.week': 'Haftalık',
  'analytics.range.month': 'Aylık',
  'analytics.range.year': 'Yıllık',
  'analytics.kind.live': 'Canlı TV',
  'analytics.kind.movie': 'Film',
  'analytics.kind.series': 'Dizi',
  'analytics.summary.title': 'Özet',
  'analytics.summary.body':
      'Bu dönemde toplam @live Canlı TV, @vod Dizi/Film izlediniz.',
  'analytics.breakdown.title': 'İzleme Dağılımı',
  'analytics.topChannels.title': 'En Çok İzlenen Kanallar',
  'analytics.topCategories.title': 'Favori Türler',
  'analytics.habit.title': 'Alışkanlığınız',
  'analytics.habit.body':
      'En çok @day günü, @period saatlerinde ekrana kilitleniyorsunuz.',
  'analytics.dailyBars.title': 'Günlük İzleme',
  'analytics.empty.summary':
      'Henüz veri yok. Birkaç bölüm izledikten sonra burada şık bir özet sizi bekliyor olacak.',
  'analytics.empty.channels': 'Henüz favori kanal verisi yok.',
  'analytics.empty.daily': 'Bu dönemde izleme yok.',
  'analytics.share.button': 'Özetimi Paylaş',
  'analytics.share.subject': 'Mina IPTV — İzleme Özetim',
  'analytics.share.text':
      'Mina IPTV ile bu @range tam @total ekran başında geçirdim! 📺 Canlı TV @live · Film/Dizi @vod 🚀',
  'analytics.privacy.title': 'Gizlilik',
  'analytics.privacy.collect.title': 'İzleme istatistiklerini topla',
  'analytics.privacy.collect.sub':
      'Tüm veriler sadece cihazınızda kalır; hiçbir sunucuya gönderilmez.',
  'analytics.privacy.clear': 'Verileri sıfırla',
  'analytics.privacy.clearConfirm.title': 'Tüm istatistikler silinsin mi?',
  'analytics.privacy.clearConfirm.body':
      'Mina Wrapped özetinizdeki tüm geçmiş izleme verileri kalıcı olarak silinecek. Bu işlem geri alınamaz.',
  'analytics.weekday.mon': 'Pazartesi',
  'analytics.weekday.tue': 'Salı',
  'analytics.weekday.wed': 'Çarşamba',
  'analytics.weekday.thu': 'Perşembe',
  'analytics.weekday.fri': 'Cuma',
  'analytics.weekday.sat': 'Cumartesi',
  'analytics.weekday.sun': 'Pazar',
  'analytics.period.morning': 'sabah',
  'analytics.period.afternoon': 'öğleden sonra',
  'analytics.period.evening': 'akşam',
  'analytics.period.night': 'gece',
  'analytics.wrapped.tag': 'MINA WRAPPED',
  'analytics.wrapped.youAre': 'SEN BİR',
  'analytics.wrapped.highlight': '@range toplam',
  'analytics.persona.newcomer.title': 'Yeni Başlayan',
  'analytics.persona.newcomer.tagline':
      'Mina Wrapped seni tanımak için sabırsızlanıyor. Birkaç içerik izle, sana özel profilin tam burada belirsin!',
  'analytics.persona.cinephile.title': 'Sinema Aşığı',
  'analytics.persona.cinephile.tagline':
      'Koca bir @hours’i filmlere ayırdın ve en çok @period saatlerinde perdeye kilitlendin. Tam bir sinema tutkunusun!',
  'analytics.persona.binger.title': 'Dizi Maratoncusu',
  'analytics.persona.binger.tagline':
      'Bölüm bölüm, @hours’lik bir maraton! @period saatleri senin dizi vaktin.',
  'analytics.persona.liveWire.title': 'Canlı Yayın Ustası',
  'analytics.persona.liveWire.tagline':
      'Canlı yayının nabzını tutuyorsun: @hours, çoğunlukla @period saatlerinde.',
  'analytics.persona.nightOwl.title': 'Gece Kuşu',
  'analytics.persona.nightOwl.tagline':
      'Gece sessizliğinde tam @hours izledin. Sen gerçek bir gece kuşusun!',
  'analytics.persona.explorer.title': 'Keşifçi İzleyici',
  'analytics.persona.explorer.tagline':
      'Canlı, film, dizi… hepsinden tadıyorsun. @hours boyunca sınır tanımadın!',
  'analytics.insight.period':
      'İzlemelerinin %@pct kadarı @period saatlerinde geçti.',
  'analytics.insight.topChannel': 'En sadık olduğun kanal: @channel (@hours).',
  'analytics.insight.peakDay': 'En aktif günün: @day.',
  'analytics.insight.topCategory': 'Favori türün: @category.',
  'analytics.timeline.title': 'İzleme Şeridi',
  'analytics.timeline.empty':
      'Henüz izleme geçmişin yok. İzledikçe burada belirecek.',
  'analytics.time.justNow': 'az önce',
  'analytics.time.minsAgo': '@n dk önce',
  'analytics.time.hoursAgo': '@n saat önce',
  'analytics.time.yesterday': 'dün',
  'analytics.time.daysAgo': '@n gün önce',
  'analytics.time.weeksAgo': '@n hafta önce',
  'settings.parental.title': 'Ebeveyn denetimi',
  'settings.parental.createIntro':
      '4–6 haneli bir PIN belirleyin. Kategori gizleme bu PIN ile açılır.',
  'settings.parental.verifyIntro':
      'Kategori ayarlarını açmak için PIN’inizi girin.',
  'settings.parental.pinNew': 'Yeni PIN',
  'settings.parental.pinConfirm': 'PIN tekrar',
  'settings.parental.pinEnter': 'PIN',
  'settings.parental.savePin': 'PIN’i kaydet',
  'settings.parental.unlock': 'Devam',
  'settings.parental.pinInvalid': 'PIN 4–6 rakam olmalıdır.',
  'settings.parental.pinMismatch': 'PIN’ler eşleşmiyor.',
  'settings.parental.pinWrong': 'PIN yanlış.',
  'settings.parental.pinSaved': 'PIN kaydedildi.',
  'settings.parental.next': 'İleri',
  'settings.parental.title.create': 'PIN oluştur',
  'settings.parental.title.confirm': 'PIN’i doğrula',
  'settings.parental.title.enter': 'PIN’i gir',
  'settings.parental.confirmIntro': 'Aynı PIN’i bir kez daha girin.',
  'settings.parental.reset': 'PIN’i sıfırla',
  'settings.parental.resetTitle': 'PIN’i sıfırla',
  'settings.parental.resetConfirm':
      'Mevcut PIN silinecek ve yeniden oluşturmanız gerekecek. Devam etmek istiyor musunuz?',
  'settings.parental.recoveryTitle': 'Kurtarma kelimesi belirle',
  'settings.parental.recoveryIntro':
      'PIN’i unutursan sıfırlamak için bu gizli kelimeyi gireceksin. Kimseyle paylaşma.',
  'settings.parental.recoveryLabel': 'Gizli kurtarma kelimesi',
  'settings.parental.recoveryHint': 'Hatırlayacağın gizli bir kelime',
  'settings.parental.recoveryTooShort':
      'Kurtarma kelimesi en az 3 karakter olmalı.',
  'settings.parental.recoveryWrong':
      'Kurtarma kelimesi yanlış. PIN sıfırlanamadı.',
  'settings.parental.recoveryPromptTitle': 'Kurtarma kelimesini gir',
  'settings.parental.recoveryPromptBody':
      'PIN’i sıfırlamak için belirlediğin gizli kurtarma kelimesini gir.',
  'settings.tile.sleepTimer': 'Uyku zamanlayıcısı',
  'settings.tile.clearAll': 'Tüm ayarları sil',
  'settings.tile.clearAll.sub': 'Playlist, önbellek ve tercihleri sıfırla',
  'settings.tile.theme': 'Tema',
  'settings.tile.subtitleOptions': 'Altyazı seçenekleri',
  'settings.tile.subtitleOptions.sub': '@pt pt',
  'settings.tile.subtitleOptions.summary': '@pt pt · @color · @font',
  'settings.tile.vodInfoEngine': 'Film Dizi Bilgi Motoru',
  'settings.tile.vodInfoEngine.hint':
      'Film ve dizi bilgilerinin kaynağını seçin',
  'settings.tile.vodInfoEngine.auto': 'Otomatik',
  'settings.tile.vodInfoEngine.xtreamOnly': 'Xtream Bilgileri',
  'settings.tile.vodInfoEngine.tmdbOmdbOnly': 'TMDB/OMDB Bilgileri',
  'settings.subtitle.title': 'Altyazı seçenekleri',
  'settings.subtitle.sectionAppearance': 'Görünüm',
  'settings.subtitle.sectionOpenSubtitles': 'OpenSubtitles hesabı',
  'settings.subtitle.size': 'Boyut',
  'settings.subtitle.color': 'Renk',
  'settings.subtitle.font': 'Yazı tipi',
  'settings.subtitle.fontHint': 'Altyazı metninde kullanılacak font.',
  'settings.subtitle.outline': 'Kontur (çerçeve)',
  'settings.subtitle.outlineHint':
      'Arka planda okunabilirlik için siyah kenarlık.',
  'settings.subtitle.previewSample': 'Altyazı önizlemesi',
  'settings.subtitle.color.white': 'Beyaz',
  'settings.subtitle.color.yellow': 'Sarı',
  'settings.subtitle.color.cyan': 'Camgöbeği',
  'settings.subtitle.color.green': 'Yeşil',
  'settings.subtitle.color.orange': 'Turuncu',
  'settings.subtitle.color.pink': 'Pembe',
  'settings.opensubtitles.title': 'OpenSubtitles',
  'settings.opensubtitles.hint':
      'opensubtitles.com hesabınızla giriş yapın. İndirme özelliği yakında eklenecek.',
  'settings.opensubtitles.username': 'Kullanıcı adı',
  'settings.opensubtitles.password': 'Şifre',
  'settings.opensubtitles.login': 'Giriş yap',
  'settings.opensubtitles.logout': 'Çıkış yap',
  'settings.opensubtitles.loggedIn': '@user olarak giriş yapıldı',
  'settings.opensubtitles.loginSuccess': 'Giriş başarılı',
  'settings.opensubtitles.logoutDone': 'Çıkış yapıldı',
  'settings.opensubtitles.noApiKeyBanner':
      'OpenSubtitles API anahtarı yapılandırılmadı. Geliştirici: ApiConstants.openSubtitlesApiKey',
  'settings.opensubtitles.errorNoApiKey': 'OpenSubtitles API anahtarı eksik.',
  'settings.opensubtitles.errorCredentials': 'Kullanıcı adı ve şifre gerekli.',
  'settings.opensubtitles.errorLogin':
      'Giriş başarısız. Bilgileri kontrol edin.',
  'settings.tile.layout': 'Yerleşim',
  'settings.tile.liveBuffer': 'Düşük Gecikme (Buffer)',
  'settings.tile.liveBuffer.sub': '@n saniye',
  'settings.tile.liveBuffer.auto': 'Otomatik',
  'settings.tile.volumeBoost': 'Ses Yükseltici',
  'settings.tile.volumeBoost.off': 'Kapalı — sistem ses seviyesi (max %100)',
  'settings.tile.volumeBoost.sub':
      'Üst sınır %@n — videoda kenardan kaydırınca veya ses tuşuyla bu seviyeye kadar çıkar',
  'settings.dialog.volumeBoost.title': 'Ses yükseltici',
  'settings.dialog.volumeBoost.hint':
      'Sistem ses seviyesi %100\'e ulaştığında oynatıcı ek kazanç uygular. MediaKit motoru etkin olduğunda çalışır; BetterPlayer\'da yalnız %100\'e kadar etki eder.',
  'settings.dialog.volumeBoost.off': 'Kapalı (max %100)',
  'settings.dialog.volumeBoost.option': 'Max %@n',
  'settings.tile.userAgent': 'User Agent',
  'settings.tile.userAgent.subCustom': 'Özel: @v',
  'settings.tile.userAgent.subCustomEmpty':
      'Özel (boş — varsayılan kullanılıyor)',
  'settings.dialog.userAgent.title': 'User Agent seçimi',
  'settings.dialog.userAgent.hint':
      'IPTV oynatıcı bu User-Agent başlığını gönderir. Stalker / Ministra panelleri belirli bir UA bekleyebilir.',
  'settings.dialog.userAgent.custom': 'Özel User Agent',
  'settings.dialog.userAgent.customLabel': 'Özel UA',
  'settings.dialog.userAgent.customHint': 'Örn. VLC/3.0.20 LibVLC/3.0.20',
  'settings.tile.epg': 'EPG',
  'settings.tile.epg.sub': 'Rehber, kaynak ve eşleştirme',
  'settings.epg.title': 'EPG ayarları',
  'settings.epg.enabled.title': 'EPG\'yi aç',
  'settings.epg.enabled.sub.on':
      'TV rehberi yenileniyor; canlı program bilgisi gösterilir.',
  'settings.epg.enabled.sub.off':
      'EPG kapalı. İndirme yapılmaz, canlı program bilgisi gizlenir.',
  'settings.epg.disabledHint': 'EPG KAPALI',
  'settings.epg.status': 'TV rehberi durumu',
  'settings.epg.status.sub.loaded': '@channels kanal · @programs program',
  'settings.epg.status.sub.empty': 'Rehber yüklenmedi',
  'settings.epg.status.sub.loading': 'Yükleniyor…',
  'settings.epg.refreshNow': 'Listeyi güncelle',
  'settings.epg.refreshFrequency': 'Rehber güncelleme sıklığı',
  'settings.epg.refreshFrequency.sub': '@n gün',
  'settings.epg.refreshFrequency.never':
      'Otomatik yenileme kapalı (yalnızca bir kez)',
  'settings.epg.timeFormat': 'Saat formatı',
  'settings.epg.timeFormat24': '24 saat',
  'settings.epg.timeFormat12': '12 saat (AM/PM)',
  'settings.epg.offset': 'EPG zaman ofseti',
  'settings.epg.offset.zero': 'Ofset yok (UTC±0)',
  'settings.epg.offset.pick': 'Ofset seçin',
  'settings.epg.manageSources': 'EPG kaynaklarını yönet',
  'settings.epg.manageSources.sub': 'XMLTV URL ve kanal eşleştirme',
  // EPG Kaynağı (Xtream / EPGShare01 yedek) seçim tile + dialog
  'settings.epg.sourcePref.title': 'EPG Kaynağı',
  'settings.epg.sourcePref.body':
      'Canlı TV rehberi nereden gelsin? Xtream sunucusu EPG döndürmüyorsa veya boş/eski veri veriyorsa EPGShare01 (Topluluk) yedeği kullanılabilir.',
  'settings.epg.sourcePref.badge.auto': 'OTOMATİK',
  'settings.epg.sourcePref.badge.xtream': 'XTREAM',
  'settings.epg.sourcePref.badge.github': 'EPGSHARE',
  'settings.epg.sourcePref.sub.xtreamOk': 'Xtream sunucusundan EPG çekiliyor.',
  'settings.epg.sourcePref.sub.xtreamOnlyFail':
      'Xtream sunucusu EPG göndermedi. EPGShare01 yedeği seçmeyi deneyin.',
  'settings.epg.sourcePref.sub.githubOk': 'EPGShare01 yedek EPG aktif.',
  'settings.epg.sourcePref.sub.githubLoading': 'EPGShare01 yedek yükleniyor…',
  'settings.epg.sourcePref.sub.githubFallback':
      'Xtream EPG vermedi; EPGShare01 yedek devreye girdi.',
  'settings.epg.sourcePref.sub.both': 'Xtream + EPGShare01 yedek birlikte aktif.',
  'settings.epg.sourcePref.sub.autoLoading': 'EPG yükleniyor…',
  'settings.epg.sourcePref.optAuto.title': 'Otomatik (önerilen)',
  'settings.epg.sourcePref.optAuto.desc':
      'Önce Xtream sunucusu, kanal eşleşmesi olmayanlar için EPGShare01 yedek.',
  'settings.epg.sourcePref.optXtream.title': 'Sadece Xtream sunucusu',
  'settings.epg.sourcePref.optXtream.desc':
      'EPGShare01 yedek kullanılmaz. Sunucu EPG göndermezse kanallarda program bilgisi olmaz.',
  'settings.epg.sourcePref.optGithub.title': 'Sadece EPGShare01 yedek',
  'settings.epg.sourcePref.optGithub.desc':
      'Xtream EPG isteği yapılmaz; doğrudan epgshare01.online tabanlı topluluk rehberi kullanılır.',
  'settings.epg.source.title': 'EPG kaynağını düzenle',
  'settings.epg.source.urlLabel': 'URL XMLTV',
  'settings.epg.source.urlHint':
      'Bu EPG için kategoriler veya kanallar seçin. Tüm kanallar için boş bırakın.',
  'settings.epg.source.tab.categories': 'Kategoriler',
  'settings.epg.source.tab.channels': 'Kanallar',
  'settings.epg.source.tab.matched': 'Eşleşenler (@n)',
  'settings.epg.source.tab.settings': 'Ayarlar',
  'settings.epg.source.search': 'Ara…',
  'settings.epg.source.pickXml': 'XMLTV kanalı seç',
  'settings.epg.source.unmatched': 'Eşleşme yok',
  'settings.epg.source.refreshEpg': 'EPG verisini yenile',
  'settings.tile.epgCache': 'EPG bilgileri güncelleme',
  'settings.tile.epgCache.sub': '@n gün',
  'settings.dialog.epgCacheTitle': 'EPG bilgileri güncelleme',
  'settings.dialog.epgCacheHint':
      'Tam EPG verisi yerelde saklanır; süre dolmadan yeniden indirilmez (veri tasarrufu).',
  'settings.dialog.epgCacheSlider': '@n gün',
  'settings.dialog.epgCacheNever':
      'Kapalı — rehber yalnızca bir kez yüklenir, otomatik yenilenmez',
  'settings.tile.adaptiveQuality': 'HLS kalite tavanı',
  'settings.dialog.adaptiveQualityTitle': 'Çoklu kalite (HLS)',
  'settings.adaptiveQuality.optionAuto':
      'Otomatik — ekran boyutuna göre (önerilen)',
  'settings.adaptiveQuality.option720': 'En fazla 720p',
  'settings.adaptiveQuality.option1080': 'En fazla 1080p',
  'settings.adaptiveQuality.option4k': 'En fazla 4K (2160p)',
  'settings.adaptiveQuality.shortAuto': 'Otomatik (cihaz)',
  'settings.adaptiveQuality.short720': 'En fazla 720p',
  'settings.adaptiveQuality.short1080': 'En fazla 1080p',
  'settings.adaptiveQuality.short4k': 'En fazla 4K',
  'settings.tile.catchUpUrl': 'EPG catch-up (panel şablonu)',
  'settings.dialog.catchUpTitle': 'Catch-up URL şablonu',
  'settings.catchUp.optionOff': 'Kapalı',
  'settings.catchUp.optionXtreamPath': 'Klasik timeshift yolu (çoğu Xtream)',
  'settings.catchUp.optionTimeshiftPhp': 'timeshift.php sorgusu',
  'settings.catchUp.optionCustom': 'Özel şablon',
  'settings.catchUp.shortOff': 'Kapalı',
  'settings.catchUp.shortXtreamPath': '/timeshift/…',
  'settings.catchUp.shortPhp': 'timeshift.php',
  'settings.catchUp.shortCustom': 'Özel',
  'settings.catchUp.customLabel': 'Tam adres satırı (yer tutucular {...})',
  'settings.catchUp.customHint': '{server}/timeshift/{username}/…',
  'settings.catchUp.help':
      '{server} {username} {password} {stream_id} {duration} {start_utc_ymd_hms} {start_local_ymd_hms} {start_unix} {extension} — sağlayıcınızın biçimine göre düzenleyin.',
  'settings.tile.launchBoot': 'Cihaz Açıldığında Başlat',
  'settings.tile.bgPlayback': 'Arka Planda Oynatma',
  'settings.tile.alarm': 'Alarm',
  'settings.tile.alarm.sub': 'Uyku zamanlayıcısı ve alarm',
  'settings.tile.miniPlayerHome': 'Küçük ekran (PiP)',
  'settings.tile.miniPlayerHome.subTv': 'Yalnızca telefon yerleşiminde',
  'settings.tile.miniPlayerHome.hintTv':
      'Bu özellik Android telefon yerleşiminde kullanılır.',
  'settings.tile.miniPlayerHome.subOn':
      'Açık — ana ekrana dönünce küçük pencerede izle (sürükle). Better/Exo.',
  'settings.tile.miniPlayerHome.subOff':
      'Kapalı — otomatik PiP yok; oynatıcı OSD düğmesiyle manuel açılabilir.',
  'settings.tile.miniPlayerHome.subMk':
      'MediaKit ile otomatik PiP yok; varsayılan oynatıcıda kullanın.',
  'settings.tile.reduceBlur': 'Bulanıklığı Kapat',
  'settings.tile.ignoreSsl': 'SSL/TLS doğrulamasını yoksay',
  'settings.tile.ignoreSsl.on':
      'Açık — geçersiz/self-signed sertifikalı yayınlara izin verilir (güvenlik azalır)',
  'settings.tile.ignoreSsl.off':
      'Kapalı — yalnızca geçerli sertifikalı HTTPS yayınlarına izin verilir. Sertifika hatası veren panellerde açın.',
  'settings.tile.landscapeStatusBar': 'Yatayda saat ve batarya',
  'settings.tile.landscapeStatusBar.on':
      'Açık · Yatay izlemede sağ üstte saat ve batarya yüzdesi',
  'settings.tile.landscapeStatusBar.off':
      'Kapalı · Yatay tam ekranda saat/batarya gösterilmez',
  'settings.tile.streamPreview': 'Yayın önizlemesi',
  'settings.tile.streamPreview.on':
      'Liste detayında sessiz önizleme (~1,8 sn sonra)',
  'settings.tile.streamPreview.off':
      'Kapalı — canlı / film / dizi listelerinde önizleme yok',
  'settings.tile.streamPreview.blockedLowEnd':
      'Açık — düşük donanım modu önizlemeyi devre dışı bırakıyor',
  'settings.tile.streamPreview.tvLocked':
      'TV’de de Ayarlar’dan açıp kapatabilirsiniz',
  'settings.tile.defaultPlayer': 'Varsayılan Oynatıcı',
  'settings.tile.filmVodPlayer': 'Film / dizi oynatıcı',
  'settings.tile.filmVodPlayer.subExo':
      'ExoPlayer (Better) — varsayılan; kod çözücü hatasında MediaKit’e geçilir',
  'settings.tile.filmVodPlayer.subMediaKit':
      'MediaKit (mpv) — doğrudan mpv ile oynat',
  'settings.tile.useMediaKit': 'MediaKit (mpv) kullan',
  'settings.tile.useMediaKit.subOn':
      'Açık — film ve dizi MediaKit ile; canlı TV her zaman Better Player ile başlar',
  'settings.tile.useMediaKit.subOff':
      'Kapalı — film, dizi ve canlı Better/Exo; MediaKit yalnızca OSD veya hata yedeği',
  'settings.tile.playerEngine': 'Oynatıcı motoru tercihleri',
  'settings.tile.playerEngine.sub': 'Canlı: @live · Film/Dizi: @vod',
  'settings.tile.smartPlayerSelection': 'Akıllı Oynatıcı Seçimi',
  'settings.tile.smartPlayerSelection.subOn':
      'Açık — MediaKit ile açılan kanal sonraki seferde hatırlanır',
  'settings.tile.smartPlayerSelection.subOff':
      'Kapalı — her seferinde seçilen motorla başlar (Better yedeği sürer)',
  'settings.dialog.smartPlayerSelection.title': 'Akıllı Oynatıcı Seçimi',
  'settings.dialog.smartPlayerSelection.body':
      'Better seçiliyken yayın her zaman Better → HLS/TS ↔ TS/HLS → gerekirse MediaKit sırasıyla denenir. Bu ayar açılırsa MediaKit ile başarıyla açılan kanal hafızaya alınır ve sonraki açılışta doğrudan MediaKit ile başlar. Kapalıyken her seferinde seçtiğiniz motorla başlar; kanal motoru hatırlanmaz.',
  'settings.dialog.smartPlayerSelection.switchOn': 'Kanal hafızası açık',
  'settings.dialog.smartPlayerSelection.switchOff': 'Kanal hafızası kapalı',
  'settings.playerEngine.title': 'Oynatıcı motoru tercihleri',
  'settings.playerEngine.hint':
      'Her içerik tipi için ana motoru seçin (Better veya MediaKit). Better seçiliyken açılmayan yayınlarda HLS↔TS ve MediaKit yedeği otomatik denenir. «Akıllı Oynatıcı Seçimi» yalnızca başarılı MediaKit kanalını hatırlar.',
  'settings.playerEngine.liveTitle': 'Canlı yayın motoru',
  'settings.playerEngine.vodTitle': 'Film / dizi oynatma',
  'settings.tile.tvOsdAutoHide': 'OSD panel gizleme süresi',
  'settings.tile.tvOsdAutoHide.sub': '@n saniye',
  'settings.dialog.osdHideTitle': 'OSD panel gizleme süresi',
  'settings.dialog.osdHideBody':
      'Dikey modda ve TV/tablet kumanda ekranında OSD ile alt kanal çubuğu bu süre sonunda gizlenir.',
  'settings.dialog.osdHideSeconds': '@n saniye',
  'settings.tile.mediaKitHwdec': 'Donanım hızlandırma (MediaKit)',
  'settings.tile.mediaKitHwdec.subBalanced':
      'Dengeli — mediacodec-copy (önerilen)',
  'settings.tile.mediaKitHwdec.subLowPower':
      'Düşük güç / eski TV kutusu — mediacodec',
  'settings.tile.videoDecoder': 'Video kod çözücü (Android)',
  'settings.tile.streamFormat': 'Yayın formatı',
  'settings.streamFormat.hlsShort': 'HLS (.m3u8) · kararlı',
  'settings.streamFormat.tsShort': 'MPEG-TS (.ts) · hızlı',
  'settings.streamFormat.autoShort': 'Otomatik · @fmt',
  'settings.streamFormat.autoTitle': 'Otomatik (önerilen)',
  'settings.streamFormat.autoDesc':
      'Liste adresindeki ipucuna göre biçimi kendiliğinden seçer (örn. output=ts → MPEG-TS). Çoğu kullanıcı için en doğru seçenek.',
  'settings.dialog.streamFormatTitle': 'Canlı yayın formatı',
  'settings.streamFormat.hlsTitle': 'HLS (.m3u8) — Kararlı',
  'settings.streamFormat.hlsDesc':
      'Daha kararlı oynatma ve çoklu kalite (HD/FHD) menüsü. Çoğu panelde önerilir.',
  'settings.streamFormat.tsTitle': 'MPEG-TS (.ts) — Hızlı',
  'settings.streamFormat.tsDesc':
      'Daha hızlı açılış ve düşük gecikme. Uyumsuz yayında oynatıcı otomatik olarak HLS\'e geçer.',
  'settings.tile.about': 'Hakkında',
  'settings.tile.about.loading': 'Sürüm yükleniyor…',
  'settings.tile.about.sub': 'Mina IPTV Player @v',
  'settings.tile.help': 'Telegram Adresimiz',
  'settings.tile.help.sub': 'Resmi Telegram kanalımız',
  'settings.tile.reportIssue': 'Sorun Bildir',
  'settings.tile.reportIssue.sub': 'E-posta ile sorununuzu bize iletin',
  'settings.tile.adminMessage': 'Admine Mesaj Gönder',
  'settings.tile.adminMessage.sub': 'Uygulama içi sohbetten yöneticiye yaz',
  'settings.tile.contactUs': 'Bize Ulaşın',
  'settings.tile.contactUs.sub': 'Telegram kanalımız ve sorun bildirimi',
  'settings.tile.setupWizard': 'Kurulum Sihirbazını Başlat',
  'settings.tile.setupWizard.sub': 'İlk kurulum adımlarını yeniden çalıştır',
  'settings.tile.faq': 'Sıkça Sorulan Sorular',
  'settings.tile.faq.sub': 'Özellikler ve oynatma ayarları için rehber',
  'faq.title': 'Sıkça Sorulan Sorular',
  'faq.searchHint': 'Soru ara…',
  'faq.empty': 'Aramanızla eşleşen soru bulunamadı.',
  'faq.entry.tsMode.q': 'MPEG-TS moduna ne zaman geçmeliyim?',
  'faq.entry.tsMode.a':
      'MPEG-TS, yayını tek parça kesintisiz akış olarak çeker; açılış hızlıdır ve birçok TV box ile uyumludur. Kanallar geç açılıyorsa, donanım kod çözücü hataları görüyorsanız veya yayın hiç başlamıyorsa MPEG-TS deneyin. Düşük donanımlı cihazlarda ve TV box\'larda uygulama bu modu otomatik olarak seçer.',
  'faq.entry.hlsMode.q': 'HLS (m3u8) moduna ne zaman geçmeliyim?',
  'faq.entry.hlsMode.a':
      'HLS yayını küçük parçalara (segment) böler ve çoğu panelde birden çok kalite (HD/FHD) sunar. İnternetiniz dalgalıysa HLS, kaliteyi otomatik düşürüp segment tamponu yaptığı için MPEG-TS\'e göre daha az donar. Çoklu kalite menüsü ve daha kararlı oynatma istiyorsanız HLS kullanın.',
  'faq.entry.autoTs.q': 'Uygulama neden cihazımda otomatik MPEG-TS\'e geçti?',
  'faq.entry.autoTs.a':
      'Cihazınız TV box veya düşük donanımlı olarak algılandığında, HLS\'in segment/kalite yükü bu cihazlarda takılmaya yol açabildiği için canlı yayın biçimi bir kez otomatik olarak MPEG-TS\'e ayarlanır. İsterseniz Ayarlar > Oynatma bölümünden tekrar HLS\'e dönebilirsiniz; tercihiniz korunur.',
  'faq.entry.buffer.q': 'Tampon (düşük gecikme) süresini neden ayarlamalıyım?',
  'faq.entry.buffer.a':
      'Tampon, oynatıcının önceden indirip beklettiği yayın süresidir. Düşük değer (1-2 sn) kanal geçişini hızlandırır ama dalgalı internette donma riskini artırır. Yüksek değer (5-10 sn) donmayı azaltır ama açılış ve zaplama biraz yavaşlar. İnternetiniz stabilse düşük, sık donuyorsa daha yüksek bir değer seçin.',
  'faq.entry.freezing.q':
      'Bir liste sürekli donuyor, başka liste sorunsuz. Neden?',
  'faq.entry.freezing.a':
      'Donmanın en sık nedeni sağlayıcının sunucusudur: yetersiz bant genişliği, uzak/yavaş sunucu, uzun segmentli yayın veya bağlantı limiti. Aynı cihaz ve internetle farklı bir liste sorunsuz çalışıyorsa, sorun büyük olasılıkla donan listenin altyapısındadır. Uygulama uzun segmentli/ABR\'siz yayınlarda tamponu otomatik artırarak yardımcı olur, ancak kaynak sunucu zayıfsa kalıcı çözüm sağlayıcı tarafındadır.',
  'faq.entry.playbackStops.q': 'Canlı yayın aniden durursa ne oluyor?',
  'faq.entry.playbackStops.a':
      'Yayın koparsa veya bağlantı limiti nedeniyle (örn. aynı hesabı başkası açtığında) durursa, oynatıcı kullanıcı duraklatmadığı sürece otomatik olarak yeniden bağlanmayı dener. Gerekirse HLS↔MPEG-TS biçim değişimi ve farklı oynatma motoru da denenir.',
  'faq.entry.engine.q':
      'Better Player ve MediaKit motorları arasındaki fark nedir?',
  'faq.entry.engine.a':
      'Better Player (ExoPlayer) çoğu cihazda donanım hızlandırmalı ve verimlidir. MediaKit (libmpv) ise zorlu codec\'ler ve sorunlu yayınlarda daha esnektir. Better Player bir yayını açamazsa uygulama otomatik olarak MediaKit\'e geçer. Ayarlardan tercih ettiğiniz motoru da seçebilirsiniz.',
  'faq.entry.softwareDecoder.q':
      'Yazılımsal video kod çözücü ne zaman kullanılmalı?',
  'faq.entry.softwareDecoder.a':
      'Donanım kod çözücü bazı cihazlarda belirli codec\'lerde yeşil/mor ekran, takılma veya hata verebilir. Görüntüde bozulma yaşıyorsanız yazılımsal kod çözücü daha uyumludur, ancak işlemciyi daha çok yorar ve düşük cihazlarda kasabilir. Sorun yoksa donanım (varsayılan) modda kalın.',
  'faq.entry.lowEndMode.q': 'Düşük donanım modu ne yapar?',
  'faq.entry.lowEndMode.a':
      'Blur, gölge ve ağır animasyonları kapatıp görsel önbelleği düşürür; arayüz zayıf cihazlarda daha akıcı çalışır. Yayın önizlemesi bu moddan etkilenmez — onu Ayarlar’dan ayrı açıp kapatabilirsiniz.',
  'faq.entry.tvLite.q': 'TV Lite (sade TV arayüzü) nedir?',
  'faq.entry.tvLite.a':
      'TV Lite artık «Düşük donanım» seçeneğinin parçasıdır. Ayarlar › Diğer araçlar veya kurulumda Düşük donanım’ı açınca sade grafik (blur/gölge kapalı) uygulanır.',
  'faq.entry.userAgent.q': 'User Agent ayarını ne zaman değiştirmeliyim?',
  'faq.entry.userAgent.a':
      'Bazı IPTV panelleri yalnızca belirli bir User-Agent başlığıyla yayın verir. Yayınlar açılmıyorsa veya panel sağlayıcınız özel bir User-Agent istiyorsa bu ayarı değiştirin. Emin değilseniz varsayılanı kullanın.',
  'faq.entry.cardSize.q': 'Ana ekran kart boyutunu nasıl değiştiririm?',
  'faq.entry.cardSize.a':
      'Ayarlar > Ana Ekran bölümünden kart boyutu kaydırıcısıyla kartları %80 ile %120 arasında ölçekleyebilirsiniz. Varsayılan %110\'dur. Daha büyük kartlar uzaktan okumayı kolaylaştırır, daha küçük kartlar ekrana daha fazla içerik sığdırır.',
  'faq.entry.epg.q': 'Program rehberi (EPG) nasıl çalışır?',
  'faq.entry.epg.a':
      'EPG, kanalların yayın akışını (şu an/sonraki program) gösterir. Veriler panelinizden veya eklediğiniz XMLTV kaynağından gelir. Rehber boş görünüyorsa Ayarlar > EPG bölümünden kaynağı ve yenileme sıklığını kontrol edin.',
  'faq.entry.ignoreSsl.q': '«SSL sertifikasını yoksay» seçeneği ne işe yarar?',
  'faq.entry.ignoreSsl.a':
      'Bazı IPTV panelleri geçersiz veya kendinden imzalı SSL sertifikası kullanır; bu durumda «sertifika doğrulanamadı» hatası alırsınız. Bu seçenek açıkken uygulama sertifikayı doğrulamadan kabul eder ve bu panellerden yayın/poster/EPG indirebilir.',
  'faq.entry.multiPlaylist.q':
      'Birden fazla liste (playlist) ekleyebilir miyim?',
  'faq.entry.multiPlaylist.a':
      'Evet. Birden çok liste kaydedip üstteki «Listeler» barından aralarında geçiş yapabilirsiniz. Her seferinde yalnızca aktif liste belleğe yüklenir; bu, performansı korur.',
  'faq.entry.backup.q': 'Ayarlarım yedeklenir mi? Yeni cihazda ne olur?',
  'faq.entry.backup.a':
      'Ayarlarınız Google yedeği ile bulutta saklanır ve yeni cihazda geri yüklenir. Ancak cihaza özel kararlar (TV box için MPEG-TS zorlaması, düşük donanım modu gibi) yeni cihazda o cihazın donanımına göre yeniden değerlendirilir; eski cihazın değerleri yeni cihazı ezmez.',
  'faq.entry.catchUp.q': 'Geçmiş yayınları (Tekrar / Catch-up) nasıl izlerim?',
  'faq.entry.catchUp.a':
      'Ana ekrandaki «Tekrar & EPG Mix» bölümünden, sağlayıcınız destekliyorsa geçmiş programları geri sarıp izleyebilirsiniz. Tekrar özelliği panelin catch-up/timeshift desteğine bağlıdır; programın yanında tekrar simgesi görünmüyorsa o yayın için arşiv sunulmuyordur.',
  'faq.entry.resumeAutoplay.q':
      'Film/diziler kaldığım yerden devam ediyor mu? Sonraki bölüm otomatik oynuyor mu?',
  'faq.entry.resumeAutoplay.a':
      'Evet. Bir filme veya bölüme tekrar girdiğinizde kaldığınız yerden devam etmeniz veya baştan başlamanız sorulur. Bölüm bitince birkaç saniyelik geri sayımla sıradaki bölüm otomatik başlar; istemezseniz geri sayımı iptal edebilirsiniz.',
  'faq.entry.smartCutter.q': '«Jeneriği Atla» (Akıllı Jenerik Atlatıcı) nedir?',
  'faq.entry.smartCutter.a':
      'Dizinin ilk bölümlerinde jeneriği elle ne kadar ileri sardığınızı öğrenir ve sonraki bölümlerde aynı noktada «Jeneriği Atla» düğmesi gösterir. Oynatma Ayarları bölümünden açıp kapatabilirsiniz.',
  'faq.entry.subtitles.q':
      'Altyazıları nasıl açar ve ayarlarım? OpenSubtitles nedir?',
  'faq.entry.subtitles.a':
      'Oynatıcıda altyazı düğmesinden gömülü veya harici altyazıları seçebilirsiniz. Altyazı Seçenekleri bölümünden yazı boyutu, rengi, yazı tipi ve kenarlığı ayarlanır. OpenSubtitles hesabınızla giriş yaparsanız çevrim içi altyazı arayıp indirebilirsiniz.',
  'faq.entry.audioTrack.q':
      'Yayının ses dilini (ses parçası) değiştirebilir miyim?',
  'faq.entry.audioTrack.a':
      'Yayında birden çok ses parçası varsa (örn. orijinal + dublaj) oynatıcıdaki ses parçası menüsünden dilediğinizi seçebilirsiniz. Tek ses parçası olan yayınlarda menü seçenek göstermez.',
  'faq.entry.volumeBoost.q': 'Sesi %100\'ün üzerine çıkarabilir miyim?',
  'faq.entry.volumeBoost.a':
      'Evet, Ses Yükseltici ile sistem sesi %100\'e ulaştıktan sonra ek kazanç uygulanır (üst sınırı ayardan belirlersiniz). Bu özellik en iyi MediaKit motorunda çalışır; çok yükseltmek seste bozulmaya yol açabilir.',
  'faq.entry.equalizer.q': 'Ekolayzer (ses dengeleyici) var mı?',
  'faq.entry.equalizer.a':
      'Evet, çok bantlı bir ekolayzer ve hazır profiller bulunur; oynatma sırasında gerçek zamanlı uygulanır. Oynatma Ayarları bölümünden açılır. Ekolayzer MediaKit motorunda etkilidir.',
  'faq.entry.externalPlayer.q':
      'Yayını VLC / MX Player gibi başka bir oynatıcıda açabilir miyim?',
  'faq.entry.externalPlayer.a':
      'Evet. Harici Oynatıcı seçeneğini açarsanız içerikler dahili oynatıcı yerine seçtiğiniz uygulamada açılır. Dahili özellikler (OSD, favori, kaldığın yerden devam) harici oynatıcıda çalışmaz.',
  'faq.entry.cast.q':
      'Yayını televizyona / başka cihaza gönderebilir miyim (Cast)?',
  'faq.entry.cast.a':
      'Oynatıcıdaki gönder simgesiyle yayın adresini BubbleUPnP, VLC gibi cast uygulamalarına aktarabilirsiniz. Bu, akışın URL\'sini harici cihaza iletir; uygulama içi DRM\'siz IPTV akışları için tasarlanmıştır.',
  'faq.entry.pipBackground.q':
      'Arka planda oynatma ve küçük ekran (PiP) nasıl çalışır?',
  'faq.entry.pipBackground.a':
      'Arka planda oynatma açıkken uygulamadan çıksanız da ses/görüntü devam eder. Küçük ekran (PiP) açıkken oynatıcıdan ana ekrana dönerken video küçük bir pencerede sürer (Android, destekleyen cihazlarda). İkisi de Oynatma Ayarları bölümündedir.',
  'faq.entry.playbackSpeed.q': 'Oynatma hızını değiştirebilir miyim?',
  'faq.entry.playbackSpeed.a':
      'Film ve dizilerde oynatma hızını 0.5× ile 2× arasında ayarlayabilirsiniz. Canlı yayınlarda hız değişimi geçerli değildir.',
  'faq.entry.zoomFit.q':
      'Görüntü ekrana tam sığmıyor / siyah çubuklar var. Ne yapmalıyım?',
  'faq.entry.zoomFit.a':
      'Oynatıcıdaki görüntü sığdırma seçeneğiyle «sığdır / doldur / kapla» modları arasında geçebilirsiniz. Mobil ve tablette ayrıca iki parmakla yakınlaştırıp (pinch-zoom) görüntüyü kaydırabilirsiniz.',
  'faq.entry.channelNumber.q':
      'Kumandayla kanal numarasını yazıp doğrudan geçebilir miyim?',
  'faq.entry.channelNumber.a':
      'Evet. Canlı yayın izlerken kumandadan kanal numarasını yazdığınızda o kanala doğrudan geçilir. Numara girişi kısa bir süre ekranda görünür ve onaylanır.',
  'faq.entry.favorites.q': 'Favorilere nasıl içerik eklerim?',
  'faq.entry.favorites.a':
      'Oynatıcıdaki kalp simgesiyle veya listelerdeki favori düğmesiyle kanal, film ve dizileri favorilere ekleyebilirsiniz. Favorileriniz Canlı TV ve Film/Dizi bölümlerindeki «Favoriler» sekmesinde toplanır.',
  'faq.entry.continueWatching.q': '«İzlemeye Devam Et» şeridi nasıl çalışır?',
  'faq.entry.continueWatching.a':
      'Yarım bıraktığınız film ve diziler, ilerleme çubuğuyla ana ekrandaki «İzlemeye Devam Et» şeridinde görünür ve tek dokunuşla kaldığınız yerden devam edersiniz. Şeridi Ana Ekran Ayarları\'ndan gizleyebilirsiniz.',
  'faq.entry.aiRecommend.q': 'Mina AI önerileri nedir, verilerim güvende mi?',
  'faq.entry.aiRecommend.a':
      'İzleme geçmişinize göre cihazınızda kişisel öneriler üretilir; bu işlem cihaz üzerinde yapılır. Öneri şeridini Ana Ekran Ayarları\'ndan kapatabilir, geçmişe dayalı önerileri sıfırlama menüsünden temizleyebilirsiniz.',
  'faq.entry.globalSearch.q':
      'Tüm içeriklerde tek seferde nasıl arama yaparım?',
  'faq.entry.globalSearch.a':
      'Ana ekrandaki arama ile canlı kanal, film ve dizilerde aynı anda arama yapabilirsiniz. Sonuçlar türlerine göre gruplanır; son aramalarınız da hatırlanır.',
  'faq.entry.downloads.q':
      'Film ve dizileri indirip çevrim dışı izleyebilir miyim?',
  'faq.entry.downloads.a':
      'Detay sayfasındaki indirme düğmesiyle film/bölümleri çevrim dışı izlemek için sıraya alabilirsiniz. İndirilenler «İndirilenler» bölümünde toplanır. Canlı yayınlar indirilemez; indirme sağlayıcının izin verdiği VOD içerikler için geçerlidir.',
  'faq.entry.homeLayout.q':
      'Ana ekran kartlarını yeniden sıralayıp gizleyebilir miyim?',
  'faq.entry.homeLayout.a':
      'Evet. Ana Ekran Ayarları\'ndan kart sırasını değiştirebilir, istemediğiniz kartları gizleyebilir; ayrıca varsayılan düzen ile vitrin düzeni arasında geçiş yapabilirsiniz.',
  'faq.entry.filmDiziMode.q':
      '«Film & Dizi» tek kart mı, ayrı Filmler/Diziler mi olsun?',
  'faq.entry.filmDiziMode.a':
      'Ana Ekran Ayarları\'ndan birleşik «Film & Dizi» kartını ya da ayrı «Filmler» ve «Diziler» kartlarını (klasik) seçebilir veya ikisini birlikte gösterebilirsiniz. Tercih tamamen görünüm içindir; içerikler aynıdır.',
  'faq.entry.theme.q': 'Uygulama temasını / görünümünü değiştirebilir miyim?',
  'faq.entry.theme.a':
      'Ayarlardan farklı temalar (Cam Gri, AMOLED Siyah vb.) seçebilirsiniz. AMOLED ekranlarda siyah tema pil tasarrufu sağlar; zayıf cihazlarda blur azaltma ile daha akıcı bir görünüm tercih edilebilir.',
  'faq.entry.analytics.q': 'Mina Analytics / Wrapped nedir?',
  'faq.entry.analytics.a':
      'İzleme alışkanlıklarınızın (toplam süre, en çok izlenen kanallar vb.) özetini gösterir. Veriler cihazınızda tutulur; istemiyorsanız analitik toplamayı ilgili ayardan kapatabilirsiniz.',
  'faq.entry.profiles.q': 'Birden fazla profil oluşturabilir miyim?',
  'faq.entry.profiles.a':
      'Evet, her kullanıcı için ayrı tercih ve geçmişle profiller oluşturabilirsiniz. Profilleri PIN ile kilitleyebilir, PIN\'i unutursanız belirlediğiniz kurtarma kelimesiyle açabilirsiniz.',
  'faq.entry.parental.q': 'Ebeveyn denetimi (PIN) nasıl kurulur?',
  'faq.entry.parental.a':
      'Ebeveyn Denetimi bölümünden 4-6 haneli bir PIN ve kurtarma kelimesi belirlersiniz. PIN, yetişkin içerik filtresi ve kategori gizleme gibi hassas ayarları korur. PIN\'i unutursanız kurtarma kelimesiyle sıfırlanır.',
  'faq.entry.sleepTimer.q':
      'Uyku zamanlayıcısı (belirli süre sonra kapat) var mı?',
  'faq.entry.sleepTimer.a':
      'Evet, «Diğer Araçlar» bölümünden uyku zamanlayıcısını ayarlarsanız seçtiğiniz süre sonunda oynatma durur. Gece uyurken yayının açık kalmaması için kullanışlıdır.',
  'faq.entry.channelEdit.q':
      'Kanal ve kategorileri düzenleyip gizleyebilir miyim?',
  'faq.entry.channelEdit.a':
      'Evet. Kategori göster/gizle ile istemediğiniz kategorileri listelerden kaldırabilir; Canlı Kanal Düzeni ile kanalları kategori içinde yeniden sıralayıp tek tek gizleyebilirsiniz. Bu, sağlayıcıdaki içeriği silmez; yalnızca sizin görünümünüzü düzenler.',
  'faq.entry.epgSettings.q':
      'Program rehberi (EPG) saatleri yanlış / boş. Nasıl düzeltirim?',
  'faq.entry.epgSettings.a':
      'EPG Ayarları\'ndan saat dilimi ofsetiyle kayan saatleri düzeltebilir, 12/24 saat biçimini seçebilir, yenileme sıklığını ayarlayabilir ve kendi XMLTV kaynağınızı ekleyebilirsiniz. Xtream hesaplarında API ile yedek kaynak arasında geçiş yapılabilir.',
  'faq.entry.speedTest.q':
      'Uygulama içinde internet hız testi yapabilir miyim?',
  'faq.entry.speedTest.a':
      'Evet, Hız Testi ekranından indirme/yükleme hızı ve gecikme (ping) ölçülür. Donma yaşıyorsanız bağlantınızın yayın için yeterli olup olmadığını görmek faydalıdır.',
  'faq.entry.cloudSync.q':
      'Ayarlarımı ve listelerimi bulutla eşitleyebilir miyim?',
  'faq.entry.cloudSync.a':
      'Google hesabınızla giriş yaparak ayarlarınızı ve listelerinizi buluta yedekleyip başka cihazda geri yükleyebilirsiniz. Son yedek tarihi ekranda görünür; yükleme (push) ve indirme (pull) işlemlerini elle yapabilirsiniz.',
  'faq.entry.demoPlaylist.q':
      'IPTV aboneliğim yok, uygulamayı deneyebilir miyim?',
  'faq.entry.demoPlaylist.a':
      'Evet, kurulum ekranındaki demo listeyle gerçek bir abonelik olmadan uygulamayı deneyebilirsiniz. Kendi içeriğiniz için M3U URL\'si, yerel dosya veya Xtream kullanıcı bilgileriyle liste ekleyebilirsiniz.',
  'faq.entry.chatSupport.q': 'Sohbet ve destek nasıl çalışır?',
  'faq.entry.chatSupport.a':
      'Google ile giriş yaparak dil odalarındaki topluluk sohbetine katılabilir, yöneticiye özel destek mesajı gönderebilirsiniz. Yayın durumu (akıyor/donuyor) etiketleriyle de sorun bildirebilirsiniz.',
  'faq.entry.language.q': 'Uygulama dilini değiştirebilir miyim?',
  'faq.entry.language.a':
      'Evet, Ayarlar\'daki dil seçiminden arayüz dilini değiştirebilirsiniz. Birçok dil desteklenir; film/dizi özetleri ve bölüm bilgileri de mümkün olduğunda cihaz dilinize çevrilir.',
  'faq.entry.showcaseMode.q': 'Vitrin düzeni nedir, nasıl açarım?',
  'faq.entry.showcaseMode.a':
      'Vitrin, mobil ve tabletler için sade ve modern bir ana ekran düzenidir. İzlemeye devam et, karışık canlı TV, son eklenen filmler ve karışık içerikler liquid glass çerçevelerle dikey bir akışta sıralanır; altta iOS tarzı damla efektli bir gezinme çubuğu bulunur. Ayarlar → Ana Ekran düzeninden veya kurulum sihirbazından seçebilirsiniz. TV\'de kullanılmaz.',
  'faq.entry.latestAdded.q':
      'Son eklenen filmleri ve dizileri nereden görürüm?',
  'faq.entry.latestAdded.a':
      'Film & Dizi modern bölümünde, film sekmesinde «Son Eklenen 50 Film», dizi sekmesinde «Son Eklenen 50 Dizi» kategorisi bulunur. Vitrin düzeninin ana ekranında da bu liste yer alır. Her kategoride olduğu gibi «Tümünü Gör» ile tam listeye geçebilirsiniz.',
  'faq.entry.imageSubtitles.q':
      'Altyazı tuşuna basıyorum ama seçenek çıkmıyor. Neden?',
  'faq.entry.imageSubtitles.a':
      'Bazı VOD yayınlarında altyazı resim tabanlıdır (PGS/HDMV, VobSub, DVB). Varsayılan oynatıcı (Better/ExoPlayer) bu tür altyazıları çizemez ve listede göstermez. Bu durumda altyazı menüsü size MediaKit (mpv) oynatıcısına geçmeyi önerir; onayladığınızda altyazılar görüntülenir. Metin tabanlı (SRT/VTT) altyazılar her iki oynatıcıda da çalışır.',
  'faq.entry.minaWrapper.q': 'Mina Wrapper nedir?',
  'faq.entry.minaWrapper.a':
      'Mina Wrapper, izleme geçmişinizi yapay zeka yardımıyla özetleyen kişisel bir bölümdür; en çok izlediğiniz türleri, zaman çizelgenizi ve size özel bir izleyici personası şık görsellerle sunar. Vitrin düzeninde alttaki gezinme çubuğundan, diğer düzenlerde ana ekrandan ulaşabilirsiniz.',
  'faq.entry.onlineCount.q':
      'Sohbette kaç kişinin çevrimiçi olduğunu görebilir miyim?',
  'faq.entry.onlineCount.a':
      'Evet, sohbet bölümünde anlık çevrimiçi kullanıcı sayısı küçük bir rozette gösterilir (örn. «55 Çevrimiçi»). Bu sayı yalnızca sohbette olanları değil, uygulamayı o anda kullanan kullanıcıları yansıtır. Kişisel kimlikler paylaşılmaz; yalnızca toplam sayı görünür.',
  'faq.entry.os27Theme.q': 'OS27 ve liquid glass temaları nedir?',
  'faq.entry.os27Theme.a':
      'OS27, iOS 27 esintili cam-damla (liquid glass) tasarımına sahip; mavi tonlu, parlak kenarlı şeffaf bir temadır ve yatay/dikey için ayrı duvar kâğıtları kullanır. TV\'ler için ise blur içermeyen, saf siyah AMOLED ve kırmızı vurgulu «TV Lite» teması önerilir. Temaları Ayarlar\'dan değiştirebilirsiniz.',
  'contactUs.title': 'Bize Ulaşın',
  'contactUs.hint':
      'Sorularınız ve sorun bildirimleriniz için aşağıdaki kanallardan bize ulaşabilirsiniz.',
  'settings.tile.privacy': 'Gizlilik politikası',
  'settings.tile.privacy.sub': 'GitHub: furkangumrukcu07/mina_iptv_player',
  'settings.snackbar.privacy': 'Gizlilik politikası',
  'settings.snackbar.privacyFail': 'Bağlantı açılamadı.',
  'settings.snackbar.privacyManual':
      'Tarayıcıdan şu adresi açmayı deneyin:\nhttps://github.com/furkangumrukcu07/mina_iptv_player',
  'settings.snackbar.aboutTitle': 'Hakkında',
  'settings.snackbar.aboutBody': 'Mina IPTV Player',
  'settings.dialog.aboutFeatures': 'Özellikler\n'
      '• Canlı TV, film ve dizi; M3U (URL/dosya) ve Xtream playlist\n'
      '• Android TV, telefon ve tablet yerleşimleri; çoklu dil arayüzü\n'
      '• Arama, kategori, favoriler; detayda sessiz yayın önizlemesi\n'
      '• Oynatıcı: canlıda Better Player (Exo); film/dizide varsayılan Exo (Better), isteğe MediaKit\n'
      '• XMLTV (EPG), canlı tampon, Android kod çözücü ve MediaKit donanım modu seçenekleri\n'
      '• Cam temalar, bulanık efekt; otomatik yenileme, arka plan oynatma, uyku zamanlayıcısı\n'
      '• PiP (Better, telefon), kayıt (desteklenen ortamlarda), VOD’da ses/altyazı (Better)\n'
      '• Play: galeri READ_MEDIA izinleri yok; varsayılan tema Varsayılan\n',
  'settings.dialog.sleepTimerTitle': 'Uyku zamanlayıcısı',
  'settings.sleepTimer.off': 'Kapalı',
  'settings.sleepTimer.optionMinutes': '@n dakika',
  'settings.sleepTimer.remaining': 'Yaklaşık @min dk kaldı',
  'settings.sleepTimer.title': 'Uyku zamanlayıcısı',
  'settings.sleepTimer.fired':
      'Süre doldu; oynatıcı kapatıldı, ana ekrana dönüldü.',
  'settings.sleepTimer.set': 'Zamanlayıcı @n dakika olarak ayarlandı.',
  'settings.sleepTimer.cleared': 'Uyku zamanlayıcısı kapatıldı.',
  'settings.bufferSecondsZero': '0 sn',
  'settings.bufferSeconds': '@n sn',
  'settings.decoder.software':
      'Yazılım önce — ExoPlayer (TS uyumluluğu). MediaKit: libmpv auto-safe.',
  'settings.decoder.hardware':
      'Donanım önce — ExoPlayer (varsayılan). MediaKit: libmpv auto-safe.',

  // Settings dialogs & snackbars (controller)
  'settings.dialog.languageTitle': 'Uygulama dili',
  'settings.dialog.themeTitle': 'Tema',
  'settings.dialog.subtitleTitle': 'Altyazı punto',
  'settings.dialog.subtitleHint':
      'ExoPlayer (Better Player) ve MediaKit gömülü altyazıları için punto. Kumanda ile listede gezinin; Kaydet altta.',
  'settings.dialog.subtitleChoice': '@pt pt',
  'settings.dialog.layoutTitle': 'Cihaz modu',
  'settings.dialog.refreshTitle': 'İçerikleri Yenile',
  'settings.dialog.refreshBody':
      'İçerikler şimdi yenilenecek. Ayrıca otomatik yenileme sıklığını seçmek ister misiniz?',
  'settings.dialog.refresh.autoOff': 'Otomatik yenileme kapalı',
  'settings.dialog.refresh.every3': '3 günde bir yenile',
  'settings.dialog.refresh.every7': 'Haftada bir yenile',
  'settings.dialog.refresh.every2h': '2 saatte bir yenile',
  'settings.dialog.refresh.every1d': 'Günde bir yenile',
  'settings.dialog.refresh.every2d': '2 günde bir yenile',
  'settings.dialog.refresh.every3d': '3 günde bir yenile',
  'settings.dialog.refresh.every1w': 'Haftada bir yenile',
  'settings.dialog.refresh.nowOnly': 'Sadece şimdi yenile',
  'settings.dialog.clearTitle': 'Tüm ayarları sil',
  'settings.dialog.clearBody':
      'Playlist bilgisi, önbellek, favoriler ve uygulama tercihleri sıfırlanacak. Emin misiniz?',
  'settings.reset.menuTitle': 'Neyi sıfırlamak istersin?',
  'settings.reset.menuHint':
      'Aşağıdan tek tek sıfırlayabilir veya en alttan tümünü sıfırlayabilirsin.',
  'settings.reset.watchHistory': 'Son izlenenler bilgisini sıfırla',
  'settings.reset.watchHistory.sub':
      'İzleme geçmişi ve "devam et" listesi temizlenir.',
  'settings.reset.ai': 'Mina AI önerilerini sıfırla',
  'settings.reset.ai.sub': '"Senin için önerilenler" yeniden oluşturulur.',
  'settings.reset.playlist': 'Playlist bilgilerini sıfırla',
  'settings.reset.playlist.sub':
      'Kayıtlı liste ve içerik önbelleği silinir; listeyi yeniden eklersin.',
  'settings.reset.everything': 'Tüm ayarları ve verileri sıfırla',
  'settings.reset.everything.sub':
      'Playlist, önbellek, favoriler ve tüm tercihler sıfırlanır.',
  'settings.reset.confirmBody': 'Bu işlem geri alınamaz. Emin misiniz?',
  'settings.reset.watchHistoryDone': 'Son izlenenler sıfırlandı.',
  'settings.reset.aiDone': 'Mina AI önerileri sıfırlandı.',
  'settings.reset.playlistDone': 'Playlist bilgileri sıfırlandı.',
  'settings.m3uEpg.defaultBadge': 'Varsayılan: iptv-org (guide.xml)',
  'settings.tile.m3uXmltvEpg': 'XMLTV (EPG rehberi)',
  'settings.dialog.xmltvTitle': 'XMLTV (EPG)',
  'settings.dialog.xmltv.body':
      'Özel adres boşsa iptv-org topluluk rehberi (guide.xml) kullanılır; günde bir kez güncellenir. Kanallar otomatik eşleştirilir; veriler SQLite ve yerel önbellekte tutulur.',
  'settings.dialog.xmltv.hint': 'https://…/epg.xml',
  'settings.dialog.xmltv.label': 'EPG URL',
  'settings.dialog.bufferTitle': 'Canlı yayın tamponu',
  'settings.tile.osdOpacity': 'Yatay OSD saydamlığı',
  'settings.tile.osdOpacity.sub': 'Arka plan: @n%',
  'settings.dialog.osdOpacityTitle': 'OSD arka plan saydamlığı',
  'settings.dialog.osdOpacitySlider': 'Saydamlık: @n%',
  'settings.dialog.osdOpacityHint':
      'Sadece OSD kapsülünün arka planı / kenarlığı / gölgesi etkilenir. Butonlar, ikonlar ve metinler değişmez.',
  'settings.tile.backup': 'Yedekleme / Geri Yükleme',
  'settings.tile.backup.sub':
      'Ayarlarını ve M3U bilgilerini yedekle veya bir yedek dosyasından geri yükle',
  'settings.dataUsage.title': 'Veri Kullanım Detayı',
  'settings.dataUsage.subtitle':
      'Bu cihazda uygulamanın kullandığı toplam mobil veri ve wifi trafiği',
  'settings.dataUsage.totalLabel': 'Genel toplam',

  // Downloads / İndirilenler
  'settings.downloads.title': 'İndirilenler',
  'settings.downloads.subtitle':
      'Telefonuna indirdiğin film ve dizi bölümlerini görüntüle, sil veya çevrimdışı oynat',
  'downloads.screen.title': 'İndirilenler',
  'downloads.section.active': 'AKTİF',
  'downloads.section.done': 'TAMAMLANANLAR',
  'downloads.empty.title': 'Henüz indirme yok',
  'downloads.empty.body':
      'Bir film veya dizi bölümünün detayına gidip "İndir" butonuna basarak başlayabilirsin. İndirilen içerikler çevrimdışı oynatılabilir.',
  'downloads.action.download': 'İndir',
  'downloads.action.downloaded': 'İndirildi',
  'downloads.action.retry': 'Tekrar dene',
  'downloads.cancelTitle': 'İndirmeyi iptal et?',
  'downloads.cancelBody':
      'Bu indirme iptal edilecek ve şu ana kadar indirilen veriler silinecek.',
  'downloads.cancel': 'İptal et',
  'downloads.deleteTitle': 'İndirilen dosyayı sil?',
  'downloads.deleteBody':
      'Dosya telefonundan kalıcı olarak silinecek. Geri almak istersen tekrar indirmen gerekir.',
  'downloads.delete': 'Sil',
  'downloads.status.queued': 'Sırada bekliyor…',
  'downloads.status.failed': 'İndirme başarısız oldu — tekrar dene',
  'downloads.status.cancelled': 'İptal edildi',
  'downloads.toast.completed': 'İndirme tamamlandı',
  'downloads.toast.completedNamed': '@title — indirildi',
  'downloads.toast.failed':
      'İndirme başarısız oldu — bağlantını kontrol edip tekrar dene',
  'downloads.toast.failedWithReason': 'İndirme başarısız: @reason',
  'downloads.action.errorTitle': 'İndirme hatası',
  'downloads.action.errorBody':
      'Dosya indirilemedi. Olası neden: @reason — Tekrar denemek için Yeniden Dene düğmesine basın.',
  'downloads.action.viewError': 'Hatayı Gör',
  'downloads.action.copyError': 'Hatayı Kopyala',
  'downloads.error.fileMissing':
      'Dosya bulunamadı — silinmiş veya taşınmış olabilir',
  'downloads.error.interrupted':
      'Uygulama kapanırken indirme yarıda kalmıştı; tekrar başlat',
  'settings.dataUsage.startedAt': 'Sayım başlangıcı: @date',
  'settings.dataUsage.wifi': 'Wifi',
  'settings.dataUsage.mobile': 'Mobil',
  'settings.dataUsage.rx': 'İndirilen',
  'settings.dataUsage.tx': 'Gönderilen',
  'settings.dataUsage.active': 'AKTİF',
  'settings.dataUsage.reset': 'Sıfırla',
  'settings.dataUsage.resetConfirm.title': 'Sayaçları sıfırla?',
  'settings.dataUsage.resetConfirm.body':
      'Wifi ve mobil veri sayaçları sıfırlansın mı? Bu işlem geri alınamaz.',
  'settings.dataUsage.note':
      'Hesaplama uygulamanın bu cihazdaki TrafficStats sayacını okur. Cihaz yeniden başlatıldığında sayaç ileriye doğru sayılmaya devam eder; arka planda kullanılan veri de dahildir. Telefon ayarlarındaki sistem ölçümünden ufak farklar olabilir.',
  'settings.dataUsage.unsupported':
      'Veri kullanım detayı yalnızca Android cihazlarda desteklenir.',
  'settings.dataUsage.preparing':
      'Sayaç başlatılıyor… Birkaç saniye sonra ölçümler güncellenmeye başlar.',
  'settings.tile.backupShare': 'Ayarları yedekle (paylaş)',
  'settings.tile.backupShare.sub':
      'Şifreli mina_backup.dat dosyasını sistem paylaşımıyla aktar',
  'settings.tile.backupRestore': 'Yedekten geri yükle',
  'settings.tile.backupRestore.sub':
      'Bir mina_backup.dat dosyası seç ve ayarları + M3U bilgilerini geri yükle',
  'backupRestore.title': 'Yedekleme / Geri Yükleme',
  'backupRestore.hint':
      'Tüm ayarların, favori listelerin, izleme geçmişin ve M3U/Xtream bilgilerin şifreli tek bir dosyada saklanır (mina_backup.dat). Aşağıdan dosyayı paylaşabilir veya daha önce kaydettiğin bir yedeği geri yükleyebilirsin.',
  'backupRestore.share.title': 'Ayarları yedekle',
  'backupRestore.share.body':
      'Şifrelenmiş mina_backup.dat dosyasını sistemin paylaşım sayfasıyla dışarı aktarır. Hiçbir özel depolama izni gerekmez.',
  'backupRestore.share.b1': 'AES‑256 ile şifrelenir; sadece Mina Pro açabilir',
  'backupRestore.share.b2':
      'Drive, WhatsApp, e‑posta, Bluetooth — istediğin yere gönder',
  'backupRestore.share.b3':
      'Cihazda kalıcı dosya bırakmaz; geçici klasör kullanılır',
  'backupRestore.share.action': 'Yedeği paylaş',
  'backupRestore.restore.title': 'Yedekten geri yükle',
  'backupRestore.restore.body':
      'Bir mina_backup.dat dosyası seç; ayarların, favorilerin ve M3U bilgilerin yedekteki haline döner.',
  'backupRestore.restore.b1':
      'Mevcut Mina ayarları temizlenip yedek üzerine yazılır',
  'backupRestore.restore.b2':
      'Xtream / M3U kimlik bilgileri güvenli depodan geri yüklenir',
  'backupRestore.restore.b3':
      'Geri yüklemeden önce onay sorulur; sonrasında uygulamayı yeniden başlat',
  'backupRestore.restore.action': 'Dosya seç ve geri yükle',
  'settings.backup.title': 'Yedekleme',
  'settings.backup.shared': 'Yedek paylaşıma gönderildi.',
  'settings.backup.error': 'Yedekleme işlemi başarısız.',
  'settings.backup.restore.confirmTitle': 'Yedekten geri yükle?',
  'settings.backup.restore.confirmBody':
      'Mevcut ayarların, favoriler, izleme geçmişi ve M3U/Xtream bilgilerin seçeceğin yedek dosyasıyla değiştirilecek. Devam edilsin mi?',
  'settings.backup.restore.confirmYes': 'Evet, geri yükle',
  'settings.backup.restore.doneTitle': 'Yedek geri yüklendi',
  'settings.backup.restore.doneBody':
      'Tüm ayarlar yüklendi. En sağlıklı sonuç için uygulamayı kapatıp tekrar açman önerilir.',
  'settings.backup.restoredSummary':
      '@prefs ayar, @sec gizli alan ve @m3u yerel playlist geri yüklendi.',
  'settings.dialog.bufferSlider': '@n saniye',
  'settings.dialog.bufferSlider.auto': 'Otomatik (Dinamik Ağ Adaptasyonu)',
  'settings.dialog.changelogTitle': 'Sürüm notları',
  'settings.dialog.adminButton': 'Yönetici',
  'settings.dialog.adminTitle': 'Yönetici',
  'settings.admin.role': 'Uygulama yöneticisi',
  'settings.admin.name': 'Furkan Gumrukcu',
  'settings.admin.whatsappLabel': 'WhatsApp',
  'settings.admin.whatsappNumber': '+90 544 645 06 07',
  'settings.admin.emailLabel': 'E-posta',
  'settings.admin.emailAddress': 'furkangumrukcu@outlook.com',
  'settings.admin.countryLabel': 'Ülke',
  'settings.admin.countryValue': 'Türkiye',
  'settings.admin.bio':
      'Bu uygulama tarafıma aittir. Yaşadığınız herhangi bir sorunla ilgili olarak bana iletebilirsiniz.',
  'settings.admin.whatsappFail': 'WhatsApp açılamadı.',
  'settings.admin.emailFail': 'E-posta uygulaması açılamadı.',
  'settings.update.check': 'Güncelleme denetle',
  'settings.update.checking': 'Denetleniyor…',
  'settings.update.openStore': 'Mağazada aç',
  'settings.update.availableTitle': 'Güncelleme mevcut',
  'settings.update.availableBody':
      'Yeni sürüm (@v) Play Store\'da yayınlandı. Şimdi güncellemek ister misiniz?',
  'settings.update.latestTitle': 'Güncelsiniz',
  'settings.update.latestBody': 'En güncel sürümü kullanıyorsunuz.',
  'settings.update.failTitle': 'Denetlenemedi',
  'settings.update.failBody':
      'Güncelleme bilgisi alınamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.',
  'settings.dialog.changelogBody': 'v2.17.33\n'
      '• Better (Exo / birincil motor): MediaSource ön-yükleme (zap hızı), canlı HTTP zaman aşımı, kare/buffering stall dedektörü, muhafazakâr yeniden bağlanma, targetBufferBytes tampon tavanları, canlı 1.0x hız kilidi, ses uyumluluk hafızası\n'
      '• Canlı HLS: bazı kanallarda otomatik HLS→MPEG-TS düşüşü (açılmama / gecikme eşiği, takılma kurtarması)\n'
      '• MediaKit (yedek motor): canlı mpv iyileştirmeleri — lavf reconnect, display-resample, untimed, cache-pause, 10 sn stall watchdog, HLS hls-bitrate profili\n'
      '• MediaKit VOD: canlı mpv bayraklarının sıfırlanması; hls-bitrate yalnızca HLS URL\'lerinde — film/dizi açılmama düzeltmesi\n'
      '• Oynatıcı motorları: VLC seçeneği geçici olarak kilitlendi (Better + MediaKit)\n\n'
      'v2.12.68\n'
      '• Yeni tema: «IOS 27» — iOS damla cam (Liquid Glass) tasarımı: saydam paneller, iOS mavisi vurgu, büyük yuvarlatılmış köşeler ve akışkan cam duvar kâğıdı (dikey + yatay). Kurulum sihirbazı ve Ayarlar → Tema\'dan seçilebilir\n'
      '• Yeni ana ekran düzeni: «Vitrin» — yalnızca telefon/tablet. Dikey kayan poster şeritleri (İzlemeye Devam Et, Canlı TV, IMDB Yüksek Puanlı Filmler, Son Eklenen 50 Film, Karışık Filmler/Diziler, M3U kategorileri) + en altta damla cam menü çubuğu (Canlı TV · Film & Dizi · EPG Mix · Mina Wrapped · Ayarlar). Her şeritte «Tümünü Gör» ve üstte arama\n\n'
      'v2.12.67\n'
      '• Film & Dizi: Film sekmesine «Son Eklenen 50 Film», Dizi sekmesine «Son Eklenen 50 Dizi» kategorisi eklendi — «Tümünü Gör» ile en yeni 50 içerik en yeniden eskiye listelenir\n'
      '• Altyazı: Desteklenmeyen yayınlarda «altyazı yok» uyarısı artık anında geliyor (eski 2-3 sn gecikme kaldırıldı)\n'
      '• Altyazı: Artık varsayılan KAPALI; kullanıcı seçmeden otomatik açılmıyor (hem Better Player hem MediaKit). Bir dil seçtiğinizde diğer filmlerde de o dil mevcutsa otomatik hatırlanıp uygulanır; «Kapalı» seçilirse hatırlama temizlenir\n\n'
      'v2.2.0\n'
      '• Play Store puanlama diyaloğu: «Daha sonra» + «Puan ver» düğmeleri dar ekranlarda taşmıyor. Sığmadığında dinamik olarak alt alta, sağa hizalı diziliyor; geniş ekranda eski yan yana düzen korunuyor\n'
      '• Film & Dizi detay — Hızlı Bilgi Paneli: fragmanların hemen altında Yönetmen + Tür satırları cam çerçevede tek bakışta görünüyor\n'
      '• Film & Dizi detay — İzle düğmesi: aynı ebatlarda kalıp arka planı poster bulanıklığı + tema gradient karışımıyla doluyor; her içerik kendi atmosferine uyumlu\n'
      '• Ana ekran — Günün Sözü: aktif dile karşılık gelen ülke bayrağı (17 dil) ufak cam rozet içinde, çerçeveye sığacak şekilde sonuna ekleniyor\n\n'
      'v2.1.x\n'
      '• Film & Dizi modu: Modern / Klasik / Her İkisi seçimi (kurulum sihirbazı + Ana Ekran Ayarları) — önizleme kartlarıyla\n'
      '• Ana ekran kartları için global boyut ayarı (slider ile küçült/büyüt)\n'
      '• Tüm kategori kartları (Canlı TV, Film&Dizi, Filmler, Diziler, Tekrar&EPG Mix, Favoriler) %15 küçültüldü\n'
      '• Film & Dizi hero: «İzle» direkt oynatır, «Detay» detay sayfasına gider (film + dizi)\n'
      '• Detay teknik pill\'leri (SD/H.264/Dolby vb.) tek satırda yatay kayan listeye dönüştü\n'
      '• Liste Yönetimi: 32\'ye kadar dinamik playlist slotu; playlist setup\'tan erişilir, ayarlardan kaldırıldı\n'
      '• M3U URL → Xtream dönüşümü her zaman önce denenir, Xtream API başarısız olursa otomatik ham M3U fallback\n'
      '• Tekrar & EPG Mix: «Tekrar» bölümünde geçmiş yayın oynatma düzeltildi (catchup template fallback)\n'
      '• OSD hız butonu: dikey modda da görünür; 2x → 3x → 5x → 10x → 1x döngüsü\n'
      '• Favori (kalp) butonu OSD\'den kaldırıldı (yatay + dikey)\n'
      '• +18 içerik gizle: ayarlarda + kurulum sihirbazında; uygulanırken cam yükleme popup\'ı, listede +18 yoksa hemen kapanır\n'
      '• Gizli kategori / kanal / +18 içerikler «İzlemeye Devam Et», «Senin İçin Önerilenler», «Karışık Canlı TV» şeritlerinden filtrelenir\n'
      '• Çoklu playlist birleştirme: ikinci ve sonraki kaynaklarda canlı TV + film + dizi birleştirilir\n\n'
      'v2.0.82\n'
      '• Yeni: Playlist yükleme özeti popup\'ı. M3U/Xtream başarılı yüklendiğinde ana ekrana atlamadan önce cam diyalog açılır: canlı kanal, film, dizi adetleri sırayla "yükleniyor → ✓" animasyonuyla görünür; Tamam butonu aşamalar bitince aktifleşir. 15 dilde tam çeviri\n\n'
      'v2.0.81\n'
      '• Ayarlar alt-sayfalarının arka planı artık aktif tema duvar kâğıdına uyumlu. Mina Glass → yeşilimsi cam tonu, Dark Flat → düz koyu zemin, SEMC/Fly UI → o temaya özel görsel. Kategori Gizleme, Canlı Kanal Düzeni, Ana Ekran Ayarları, Yedekleme/Geri Yükleme, Kanal Kategori Düzeni, Oynatma Ayarları, Kart Sırası, Altyazı, EPG ve Ebeveyn Kontrolü dahil hepsi tek bakışta tema ile uyumlu\n\n'
      'v2.0.80\n'
      '• Yüksek Puanlı Filmler: yıldız aralığı 7.0–10.0, aynı isimli filmler tekilleştirildi, içerik günlük rastgele karışıyor (her gün farklı 30 film, aynı gün boyunca tutarlı). Toplam film sayısı 30\n\n'
      'v2.0.79\n'
      '• Yeni: Ayarlar → «Oynatma Ayarları» alt-sayfası. MediaKit/MPV Kullan, Donanım Hızlandırma, Video Kod Çözücü ve Düşük Gecikme Buffer tek başlık altında\n\n'
      'v2.0.78\n'
      '• Ayarlar: «Kategori gizleme» ve «Canlı kanal düzeni» tek «Kanal Kategori Düzeni» girişinde birleştirildi. Alt sayfada her iki seçenek de büyük cam kartlar halinde\n\n'
      'v2.0.77\n'
      '• Ayarlar: «Yedekle» ve «Geri Yükle» tile\'ları tek «Yedekleme / Geri Yükleme» girişinde birleştirildi. Alt sayfada iki aksiyon büyük cam kartlar halinde, ne yaptıklarını açıklayan özetlerle sunuluyor\n\n'
      'v2.0.76\n'
      '• Yeni: «Ana Ekran Ayarları» alt-sayfası. Kart sırası, Karışık Canlı TV, Sıradaki Maçlar ve Yüksek Puanlı Filmler artık tek noktadan yönetiliyor; her satırın altında önizleme illüstrasyonu görüntülenir\n'
      '• Yüksek Puanlı Filmler için yeni anahtar (varsayılan açık, kurulum sihirbazında da var)\n\n'
      'v2.0.75\n'
      '• Ana ekran: yeni «Yüksek Puanlı Filmler» şeridi (İzlemeye Devam Et altında). IMDB puanına göre en yüksek 20 film, İzlemeye Devam Et kartlarıyla bire bir aynı boyutta posterler; sağ üstte cam tasarımda dairesel IMDB rozeti\n\n'
      'v2.0.74\n'
      '• Yeni: Ayarları + M3U bilgilerini yedekle ve geri yükle. Tüm ayarlar, favoriler, izleme geçmişi ve Xtream/M3U kimlik bilgileri AES‑256 ile şifrelenip mina_backup.dat olarak dışa aktarılır; sistemin paylaşım sayfasıyla Drive/WhatsApp/e‑posta ile gönderirsin\n'
      '• Geri yüklemede tehlikeli depolama izni istenmez; file_picker ile tek dosya seçilir\n\n'
      'v2.0.73\n'
      '• Ayarlar → «Yerleşim» seçeneği gizlendi (otomatik yönetiliyor)\n'
      '• Yeni: Yatay OSD arka plan saydamlığı (0–100). Sadece kapsülün arka planı/kenarı/gölgesi şeffaflaşır; butonlar, ikonlar ve logolar sabit kalır\n'
      '• Film/Dizi: altyazı artık varsayılan kapalı — OSD üzerinden manuel seçilir\n\n'
      'v2.0.72\n'
      '• OSD adaptif boyut (yatay mobil): küçük ekranlı telefonlarda oynatıcı OSD\'sinin sağ kontrol kapsülü taşmıyor; buton boyutu, butonlar arası boşluk, sol bilgi bloğu genişliği ve dikey ayraç ekrana göre 3 kademede otomatik küçülüyor (<600, <780, ≥780 dp)\n\n'
      'v2.0.71\n'
      '• Kanal ön eki: sadece ülke önekleri (TR:/BR:/EN:/US:) temizlenir; HD/SD/FHD/UHD/HEVC/4K/VIP gibi kalite ve etiket bilgileri olduğu gibi kalır (yayını açmadan kalite görünsün)\n\n'
      'v2.0.70 — Play Store sürümü\n'
      '• Film & Dizi tam modernizasyon paketi: sinematik Hero Banner carousel (Film + Dizi), buzlu cam kategori blokları + neon vurgu, kenar fade-in/out, 24dp boşluk\n'
      '• Yenilenen poster: IMDb rozeti afişin sağ-alt köşesinde (sarı yıldız + skor); favori kalp küçük, şeffaf, zarif; afiş altı tek-satır gri etiket\n'
      '• Sekme barında arama butonu: sadece film + dizi sonuçları; sonuç seçilince doğrudan yeni Film & Dizi detay sayfası açılır\n'
      '• Üstteki «Film & Dizi» başlığı yerine minimal cam geri pili\n\n'
      'v2.0.69\n'
      '• Film & Dizi araması: sekme barından açılan aramada bir sonuç seçildiğinde artık eski Browse listesi yerine doğrudan yeni Film & Dizi detay sayfası açılıyor\n\n'
      'v2.0.68\n'
      '• Film & Dizi araması: sekme barındaki arama butonu artık sadece film + dizi sonuçları gösteriyor (canlı TV sonuçları hariç tutuluyor)\n\n'
      'v2.0.67\n'
      '• Dizi sekmesi: Film sekmesindeki tüm yenilikler dizilere de uygulandı — üstte sinematik Hero Banner carousel\'i (ilk 5 yeni dizi), buzlu cam kategori panelleri, neon vurgu, kenar fade-in/out, kompakt poster etiketi\n\n'
      'v2.0.66\n'
      '• Film & Dizi: kategori blokları buzlu cam paneller + neon vurgu (eski yeşil kart yok); poster IMDB rozeti afişin sağ-alt köşesine taşındı (sarı yıldız + «IMDb» + puan); favori kalp daha küçük, şeffaf ve zarif\n\n'
      'v2.0.64\n'
      '• Film & Dizi: tam genişlikte sinematik Hero Banner carousel\'i (ilk 5 öne çıkan film, İzle/Detay), kategori başlıkları kartsız zarif tipografi, kenar fade-in/out, bloklar arası 24dp; poster altı tek-satır gri etiket\n\n'
      'v2.0.63\n'
      '• Film & Dizi: Film/Dizi sekme kapsüllerinin arasında küçük cam arama butonu — birleşik arama dialog\'u açar\n\n'
      'v2.0.62\n'
      '• Film & Dizi: üstteki «Film & Dizi» başlık çubuğu kaldırıldı; sol üst köşede minimal cam geri butonu kaldı, içerik için daha fazla yer\n\n'
      'v2.0.61\n'
      '• Oyuncu detay — Filmler: tıklama garantili (GestureDetector), tüm playlist taranır, Türkçe karakter + kelime kümesi eşleşmesi, eşleşme yoksa toast bildirim\n\n'
      'v2.0.60\n'
      '• Oyuncu detay: Filmler şeridindeki filme dokununca playlist\'te eşleşen içerik açılır\n\n'
      'v2.0.59\n'
      '• TV OSD otomatik gizleme: 3 sn seçeneği eklendi (3, 5, 7, 10, 15, 20). Varsayılan 7 sn.\n\n'
      'v2.0.58\n'
      '• Xtream EPG ilk yüklemede de aktif: playlist eklendiğinde (M3U → Xtream dönüşüm dahil) Xtream EPG\'si arka planda otomatik indirilir; yeniden başlatmaya gerek yok\n\n'
      'v2.0.57\n'
      '• Akıllı M3U → Xtream: M3U URL\'sinde username/password parametreleri varsa arka planda Xtream\'e dönüştürülüp Xtream API üzerinden yükleniyor (EPG/VOD/Series aktif). Düz M3U linkler eski davranışla devam.\n\n'
      'v2.0.56\n'
      '• Ayarlar: «01/02/03» yerine sol başta işlevsel ikonlar; cam kart opaklığı azaltıldı (duvar kağıdı daha görünür)\n'
      '• Film & Dizi detay: «İzle» düğmesinde oynat ikonu, yumuşak köşe ve neon gölge; oyuncu adı–rol arası boşluk; özet satır yüksekliği 1.4 (film + dizi)\n\n'
      'v2.0.55\n'
      '• Kanal ön eki temizliği: ülke kodlarına (TR:/BR:/EN:) ek olarak Full HD:/FHD:/HD:/SD:/UHD:/4K:/8K:/HEVC:/H.265:/H.264:/VIP:/LIVE:/SY:/BACKUP:/ALT:/MULTI:/PPV: önekleri ve sondaki [HD] gibi etiketler de kaldırılıyor\n'
      '• Uygulanan yerler: İzlemeye Devam Et kartları, Karışık Canlı TV şeridi, Canlı TV listesi — Ayarlar → «Kanal ön eki» tek anahtardan\n'
      '• Kurulum sihirbazı: «Kanal ön eki kaldır» anahtarı Özellikler bölümüne eklendi\n\n'
      'v2.0.54\n'
      '• Adaptive titreşim Samsung uyumu: One UI «titreşim yok» sorunu native Vibrator köprüsü ile çözüldü; A–Z hızlı kaydırma çubuğu da dahil\n'
      '• Performans (EPG dışı): ana ekran sayım getter\'ları, Karışık Canlı TV ve gizli kategori set\'leri için scope tabanlı cache; daha az jank ve GC baskısı\n\n'
      'v2.0.53\n'
      '• Play Store sürüm paketi\n\n'
      'v2.0.52\n'
      '• Canlı TV kanallar: EPG kanal adının altında; program + başlangıç saati\n\n'
      'v2.0.51\n'
      '• Canlı TV kanallar: EPG sağda (logo yönü), parantez yok, kanal adı ile boşluk\n\n'
      'v2.0.50\n'
      '• Canlı TV kanallar: kaydırma yalnızca (EPG programı); kanal adı sabit\n\n'
      'v2.0.49\n'
      '• Oynatıcı: parlaklık sol kenar, ses sağ kenar; ortada zoom; pinch iyileştirmesi\n'
      '• Canlı TV kanallar (portre): kanal + güncel program; uzun başlıkta kaydırma\n'
      '• Ayarlar: isteğe bağlı kanal ön eki gizleme (TR:, BR:…)\n\n'
      'v2.0.48\n'
      '• Film & Dizi: detay meta (süre, tür, SD/H.264…), IMDb, cam İzle; tümünü gör A–Z + harf balonu\n'
      '• Canlı TV EPG: ön ek yok, boş dilimde kutu yok, küçük yazı; portrede aynı kategori kanalları\n'
      '• Oynatıcı: mobil/tablette iki parmak zoom + yüzde/konum göstergesi\n'
      '• Ayarlar: EPG menüsü; bulanıklık kapat kaldırıldı; içerik yenile varsayılan haftada bir\n\n'
      'v2.0.35\n'
      '• Önerilen Filmler: üst kahraman posteri kaydırınca kaybolma düzeltildi\n'
      '• Önerilen Filmler: 4K / UHD satırı; tümünü gör başlık ve arama okunabilirliği\n'
      '• Play Store: puanlamayan kullanıcıya günde bir kez değerlendirme diyaloğu\n'
      '• Çeviriler: 17 dilde eksik metinler tamamlandı (FR, AR, ZH, RU, ES, JA, KO…)\n\n'
      'v2.0.23\n'
      '• EPG Mix: yayın hatırlatıcısı ve bildirim izinleri geçici olarak kaldırıldı\n\n'
      'v1.9.16\n'
      '• Ayarlar: 16. kartta Better Player / MediaKit seçimi metni sadeleştirildi\n'
      '• Ayarlar: yeni “Uygulama Fontu” menüsü eklendi (tüm uygulama geneline uygulanır)\n'
      '• Fontlar: Sony, Roboto, Noto Sans ve Monospace seçenekleri eklendi\n'
      '• TV: font seçim menüsünde D-pad odak/ok/OK akışı iyileştirildi\n'
      '• Dikey detay: önizleme üst köşe gölge katmanı düzeltildi\n'
      '• Dikey oynatıcı: yayın açılmasa bile mevcut OSD paneli + butonları görünür kalır\n'
      '• Ayarlar: 16/17 kart ikonları uygulama geneliyle tutarlı hale getirildi\n\n'
      'Detaylar için CHANGELOG.md dosyasına bakın.\n',
  'settings.dialog.developerTitle': 'Geliştirici',
  'settings.dialog.developerBody': 'Geliştirici: furkangumrukcu',
  'settings.snackbar.content': 'İçerik',
  'settings.snackbar.noPlaylist': 'Kayıtlı playlist yok. Önce playlist seçin.',
  'settings.snackbar.refreshOk': 'Playlist başarıyla güncellendi.',
  'settings.snackbar.error': 'Hata',
  'settings.snackbar.loadFailed': 'Yüklenemedi: @e',
  'settings.snackbar.info': 'Bilgi',
  'settings.snackbar.xtreamOnly': 'Bu özellik sadece Xtream hesapları içindir.',
  'settings.snackbar.xtreamFail': 'Hesap bilgileri sunucudan alınamadı.',
  'settings.snackbar.xtreamError': 'Bilgiler alınırken bir hata oluştu: @e',
  'settings.dialog.xtreamTitle': 'Xtream Hesap Bilgileri',
  'settings.xtream.user': 'Kullanıcı',
  'settings.xtream.status': 'Durum',
  'settings.xtream.expiry': 'Bitiş Tarihi',
  'settings.xtream.connections': 'Aktif / Maks. Bağlantı',
  'settings.xtream.trial': 'Deneme Hesabı',
  'settings.xtream.unlimited': 'Süresiz',
  // Yeni: detaylı Xtream Hesap dialogu (sunucu + abonelik)
  'xtream.info.section.subscription': 'ABONELİK',
  'xtream.info.section.server': 'SUNUCU',
  'xtream.info.password': 'Şifre',
  'xtream.info.authState': 'Doğrulama',
  'xtream.info.authOk': 'Başarılı',
  'xtream.info.authFail': 'Başarısız',
  'xtream.info.unknown': 'Bilinmiyor',
  'xtream.info.message': 'Mesaj',
  'xtream.info.createdAt': 'Oluşturuldu',
  'xtream.info.remaining': 'Kalan',
  'xtream.info.remainingDays': '@n gün',
  'xtream.info.expiredAgo': '@n gün önce sona erdi',
  'xtream.info.allowedOutputs': 'İzinli Formatlar',
  'xtream.info.userInfoMissing': 'Kullanıcı bilgisi alınamadı',
  'xtream.info.serverInfoMissing': 'Sunucu bilgisi alınamadı',
  'xtream.info.serverBaseUrl': 'Bağlantı URL',
  'xtream.info.serverHost': 'Sunucu',
  'xtream.info.serverProtocol': 'Protokol',
  'xtream.info.serverPort': 'HTTP Port',
  'xtream.info.serverHttpsPort': 'HTTPS Port',
  'xtream.info.serverRtmpPort': 'RTMP Port',
  'xtream.info.timezone': 'Saat Dilimi',
  'xtream.info.serverTime': 'Sunucu Saati',
  'xtream.info.serverProcess': 'Servis Durumu',
  'xtream.info.serverRevision': 'Sürüm',
  // Xtream giriş hatası (tekrar dene)
  'xtream.error.title': 'Xtream Giriş Hatası',
  'xtream.error.invalidCredentials':
      'Kullanıcı adı, şifre veya sunucu adresi hatalı. Lütfen bilgilerinizi kontrol edip tekrar deneyin.',
  'xtream.error.invalidCredentialsWithMsg':
      'Sunucu cevabı: @m\n\nLütfen kullanıcı adı, şifre ve sunucu adresinizi kontrol edip tekrar deneyin.',
  'xtream.error.credentialsEmpty':
      'Sunucu adresi, kullanıcı adı ve şifre alanlarının tamamı dolu olmalıdır.',
  'stalker.error.title': 'Stalker Portal Giriş Hatası',
  'stalker.error.credentialsEmpty':
      'Portal adresi ve MAC adresi alanlarının ikisi de dolu olmalıdır.',
  'stalker.error.invalidHandshake':
      'Portala bağlanılamadı. Adresi (ör. http://sunucu/c/) ve MAC adresini kontrol edin.',
  'stalker.error.invalidCredentials':
      'MAC adresi bu portalda yetkili değil veya oturum açılamadı.',
  'stalker.error.emptyCatalog':
      'Oturum açıldı ancak kanal/film listesi boş geldi. MAC yetkisini veya portal adresini kontrol edin.',
  'stalker.field.portalUrl': 'Stalker Portal URL',
  'stalker.field.mac': 'MAC Adresi',
  'stalker.chip.label': 'Stalker',
  'stalker.compat.title': 'Stalker uyumluluk',
  'stalker.compat.hint':
      'Bazı portallar MAG254 veya farklı donanım sürümü ister. Giriş başarısızsa başka ön ayar deneyin.',
  'stalker.compat.sslHint':
      'Geçersiz SSL için Ayarlar → «SSL/TLS doğrulamasını yoksay» seçeneğini kullanın.',
  'stalker.field.magPreset': 'MAG ön ayarı',
  'stalker.field.linkType': 'Bağlantı tipi',
  'stalker.field.hwVersion': 'hw_version (isteğe bağlı)',
  'stalker.preset.genericSafe': 'MAG250 (önerilen)',
  'stalker.preset.mag250Legacy': 'MAG250 eski',
  'stalker.preset.mag254Strict': 'MAG254',
  'stalker.preset.ministraModern': 'MAG322 / Ministra',
  'stalker.link.wifi': 'WiFi',
  'stalker.link.ethernet': 'Ethernet',
  'settings.xtreamFooter.line': 'Xtream: @user · @host',
  'settings.snackbar.settings': 'Ayarlar',
  'settings.snackbar.cleared': 'Tüm veriler temizlendi.',
  'settings.snackbar.clearFailed': 'Temizlenemedi: @e',
  'settings.snackbar.subtitles': 'Altyazı',
  'settings.snackbar.subtitlesSoon':
      'Altyazı görünümü özelleştirmesi yakında eklenecek.',
  'settings.snackbar.report': 'Sorun bildir',
  'settings.snackbar.reportFail':
      'E-posta uygulaması açılamadı. Adres: furkangumrukcu07@gmail.com',
  'settings.snackbar.reportManual':
      'furkangumrukcu07@gmail.com adresine yazabilirsiniz.',
  'settings.mail.subject': 'Mina IPTV — Sorun bildirimi',
  'settings.mail.body':
      '--- Otomatik tanı (mümkünse silmeyin) ---\n@diag\n---\n\nSorun açıklaması / adımlar:\n\n',

  // Playlist setup
  'playlist.title': 'Playlist kurulumu',
  'playlist.sourceTitle': 'Kaynak Seçimi',
  'playlist.sourceSubtitle': 'M3U URL, yerel dosya veya Xtream hesabı.',
  'playlist.loadList': 'Listeyi Yükle',
  'playlist.m3uUrl': 'M3U URL',
  'playlist.m3uUrlHint': 'https://example.com/playlist.m3u',
  'playlist.pasteUrl': 'Yapıştır',
  'playlist.pasteEmpty': 'Panoda metin yok',
  'playlist.pickFile': 'Dosya Seç',
  'playlist.m3uXtreamRecommendation':
      'Daha iyi verim ve deneyim için Xtream ile giriş yapmanızı öneririz.',
  'playlist.noFile': '.m3u / .m3u8 dosyası seçilmedi',
  'playlist.xtream.server': 'Sunucu Adresi',
  'playlist.xtream.serverPlaceholder': 'Sunucu URL (Host)',
  'playlist.xtream.user': 'Kullanıcı Adı',
  'playlist.xtream.pass': 'Şifre',
  'playlist.xtream.hint':
      'player_api.php içeren adresleri direkt yapıştırabilirsiniz.',
  'playlist.snackbar.file': 'Dosya',
  'playlist.snackbar.badExt':
      'Lütfen geçerli bir .m3u, .m3u8 veya .txt dosyası seçin.',
  'playlist.snackbar.readFail': 'Dosya okunamadı (path veya veri yok)',
  'playlist.snackbar.fileError': 'Hata: @e',
  'playlist.snackbar.m3u': 'M3U',
  'playlist.snackbar.setup': 'Kurulum',
  // Başarılı M3U/Xtream yüklemesi sonrası özet diyaloğu.
  'playlist.summary.title': 'Liste başarıyla yüklendi',
  'playlist.summary.titleLoading': 'Playlist yükleniyor',
  'playlist.summary.subtitle':
      'Aşağıda yüklenen içeriklerin özetini görebilirsiniz.',
  'playlist.summary.subtitleLoading':
      'Canlı kanallar, filmler ve diziler hazırlanıyor…',
  'playlist.summary.liveChannels': 'Canlı kanallar',
  'playlist.summary.films': 'Filmler',
  'playlist.summary.series': 'Diziler',
  'playlist.summary.loading': 'Yükleniyor…',
  'playlist.summary.itemsCount': '@n adet',
  'playlist.summary.ok': 'Tamam',
  'playlist.summary.okCountdown': 'Tamam (@n)',
  'playlist.summary.autoCloseHint':
      'Diyalog otomatik kapanacak. Birleştirme arka planda devam ediyor.',
  'playlist.summary.cancel': 'İptal',
  'playlist.summary.fixUrl': 'URL\'yi Düzelt',
  'playlist.summary.errorTitle': 'Liste yüklenemedi',
  'playlist.summary.errorSubtitle':
      'URL\'i kontrol edip yeniden deneyin. Aşağıdaki açıklama yardımcı olur.',
  'playlist.error.url.ssl':
      'HTTPS bağlantısı kurulamadı. Sertifika doğrulanamıyor veya sunucu HTTPS desteklemiyor olabilir.',
  'playlist.error.url.host':
      'Sunucu adı bulunamadı. URL\'deki host kısmını ve internet bağlantınızı kontrol edin.',
  'playlist.error.url.timeout':
      'Sunucu cevap vermedi (zaman aşımı). Sunucu yoğun olabilir; biraz bekleyip tekrar deneyin.',
  'playlist.error.url.refused':
      'Sunucu bağlantıyı reddetti. Port veya adres yanlış olabilir.',
  'playlist.error.url.auth':
      'Yetki reddedildi (401/403). Kullanıcı adı/şifre veya panel aboneliği geçerli mi kontrol edin.',
  'playlist.error.url.notFound':
      'URL bulunamadı (404). Playlist adresi taşınmış veya yanlış yazılmış olabilir.',
  'playlist.error.url.server':
      'Sunucu hatası (5xx). Panel geçici olarak erişilemiyor.',
  'playlist.error.url.empty':
      'Sunucudan boş yanıt geldi. URL doğru ama playlist içeriği yok.',
  'playlist.error.url.network':
      'Listeye ulaşılamadı. URL veya ağ bağlantısı sorunlu.',
  'playlist.error.hint.tryHttp':
      'İpucu: URL\'i `https://` yerine `http://` ile deneyin.',
  'playlist.error.hint.tryHttps':
      'İpucu: URL\'i `http://` yerine `https://` ile deneyin.',
  'playlist.error.hint.addScheme':
      'İpucu: URL\'in başında `http://` veya `https://` olmalı.',
  'playlist.label.localM3u': 'Yerel M3U',
  'playlist.error.emptyUrl': 'M3U URL boş olamaz',
  'playlist.error.xtream': 'Xtream bilgileri eksik',
  'playlist.merge.orphanCategory': 'Liste 2',
  'playlist.secondaryTitle': 'İkinci kaynak (isteğe bağlı)',
  'playlist.secondarySubtitle':
      'İkinci M3U veya Xtream yalnızca canlı TV kanallarını birincil listeye ekler; film/dizi birincil kaynaktan gelir.',
  'playlist.managerEntry.title': 'Liste Yönetimi',
  'playlist.managerEntry.body':
      'İstediğin kadar ek liste (M3U URL, M3U dosyası veya Xtream) ekle — canlı, film ve dizi tek kütüphanede birleşir',
  'playlist.qrEntry.title': 'Karekod ile yükle',
  'playlist.qrEntry.body':
      'Telefonunu kumanda gibi kullan: aynı Wi-Fi ağındaki cihazından karekodu tara, M3U veya Xtream bilgilerini gönder; TV listeyi anında alır.',
  'playlist.qr.title': 'Karekod ile Liste Ekle',
  'playlist.qr.subtitle':
      'Telefonunla karekodu tara, açılan formdan M3U veya Xtream gönder. Aynı Wi-Fi ağında olmanız yeterli.',
  'playlist.qr.waiting': 'Telefon bekleniyor…',
  'playlist.qr.hint':
      'Karekod sadece bu pencere açıkken çalışır; pencereyi kapatınca yerel sunucu durur. Veri bulutta değil, doğrudan cihazlar arasında akar.',
  'playlist.qr.urlCopied': 'Bağlantı kopyalandı',
  'playlist.qr.error.title': 'Yerel ağ bulunamadı',
  'playlist.qr.error.sub':
      'Wi-Fi veya Ethernet bağlı olmalı. Mobil veri tek başına yetmez — TV ile telefon aynı yerel ağda olmalı.',
  'playlist.secondaryEnable': 'İkinci listeyi etkinleştir',
  'playlist.secondaryUrlHint': 'İkinci M3U URL',
  'playlist.error.secondaryXtream': 'İkinci Xtream bilgileri eksik',
  'playlist.error.secondaryUrl': 'İkinci M3U URL boş olamaz',
  'playlist.demoList': 'Demo Liste (Test)',

  // Not: 'settings.tile.playlistsManager' tile'ı Ayarlar'dan kaldırıldı —
  // navigasyon artık PlaylistView içindeki entry card üzerinden yapılıyor.
  'playlistsManager.title': 'Liste Yönetimi',
  'playlistsManager.subtitle':
      'En fazla @max liste — canlı, film ve dizi birleşir',
  'playlistsManager.subtitle.unlimited': 'İstediğin kadar liste ekle',
  'playlistsManager.reorder.hint':
      'Sıralamak için tutamacı basılı tutup kaydırın',
  'playlistsManager.toast.reordered': 'Liste sırası güncellendi.',
  'playlistsManager.addNew.title': 'Yeni liste ekle',
  'playlistsManager.addNew.body':
      'M3U URL, M3U dosyası veya Xtream — @n. slot olarak eklenir',
  'playlistsManager.slot.primary': 'Birincil liste',
  'playlistsManager.slot.extra': '@n. liste',
  'playlistsManager.slot.empty': 'Boş — eklemek için + tuşuna basın',
  'playlistsManager.name.label': 'Liste adı (opsiyonel)',
  'playlistsManager.name.hint': 'Örn: Spor Paketi',
  'playlistsManager.name.helper':
      'Boş bırakırsanız varsayılan başlık kullanılır.',
  'playlistsManager.edit': 'Düzenle',
  'playlistsManager.remove': 'Sil',
  'playlistsManager.removeTitle': 'Listeyi sil',
  'playlistsManager.removeBody':
      '@n. listeyi kaldırmak istediğinize emin misiniz?',
  'playlistsManager.editor.primary': 'Birincil listeyi düzenle',
  'playlistsManager.editor.extra': '@n. listeyi düzenle',
  'playlistsManager.tab.url': 'M3U URL',
  'playlistsManager.tab.file': 'M3U Dosya',
  'playlistsManager.tab.xtream': 'Xtream',
  'playlistsManager.tab.demo': 'Demo',
  'setup.sourceDemo.sub':
      'Önceden tanımlı demo kanallarıyla uygulamayı hemen deneyin; sunucu bilgisi gerekmez.',
  'playlistsManager.file.pick': 'Dosya seç',
  'playlistsManager.file.replace': 'Başka dosya seç',
  'playlistsManager.reloading': 'Listeler birleştiriliyor…',
  'playlistsManager.syncing': 'İçerik güncelleniyor…',
  'playlistSwitcher.title': 'Listeler',
  'playlistSwitcher.sheetTitle': 'Liste Seç',
  'playlistSwitcher.kind.xtream': 'Xtream',
  'playlistSwitcher.kind.m3u': 'M3U',
  'playlistsManager.toast.enabling': '@n. liste açılıyor…',
  'playlistsManager.toast.disabling': '@n. liste devre dışı bırakılıyor…',
  'playlistsManager.status.enabling': 'Açılıyor…',
  'playlistsManager.status.disabling': 'Kapanıyor…',
  'playlistsManager.toast.saved': 'Liste kaydedildi.',
  'playlistsManager.toast.removed': 'Liste kaldırıldı.',
  'playlistsManager.toast.removedN': '@n. liste silindi.',
  'playlistsManager.toast.removing': '@n. liste siliniyor…',
  'playlistsManager.toast.refreshEmpty':
      'Boş slot yenilenemez. Önce bir liste ekle.',
  'playlistsManager.toast.refreshLocalUnsupported':
      'Yerel dosya listeleri yenilenemez. Dosyayı tekrar seçmen gerekir.',
  'playlistsManager.toast.refreshUnsupported': 'Bu kaynak yenilenemiyor.',
  'playlistsManager.refresh': 'Listeyi yenile',
  'playlistsManager.error.cannotRemovePrimary':
      'Birincil liste silinemez. Önce farklı bir kaynak seçin veya tüm listeleri sıfırlayın.',
  'playlistsManager.error.cannotRemoveLast':
      'En az bir liste kalmalı. Son listeyi silemezsiniz; içeriğini değiştirmek için "Düzenle" kullanın.',
  'playlistsManager.merge.orphanCategory': 'Liste @n',
  'playlistsManager.live.prefix.plain': 'Liste @n',
  'playlistsManager.live.prefix.named': 'Liste @n (@name)',
  'playlistsManager.merge.cta': 'Listeleri Birleştir (@n)',
  'playlistsManager.merge.cta.hint':
      'Tüm dolu listeleri aktifleştirir. Canlı TV kategorileri "Liste 1 (Ad) · Kategori" şeklinde gruplanır; film ve diziler tek karışık listede görünür.',
  'playlistsManager.merge.allActive': 'Tüm listeler birleştirildi (@n)',
  'playlistsManager.merge.allActive.hint':
      'Tüm dolu listelerin içeriği şu anda birlikte gösteriliyor. Tek liste kullanmak istersen ilgili listenin yanındaki göz simgesiyle devre dışı bırak.',
  'playlistsManager.toast.autoSolo':
      'Yeni liste eklendi: yalnızca @name aktif. Diğer listeleri eklemek için "Listeleri Birleştir" butonunu kullan.',
  'playlistsManager.toast.mergeDone': '@n liste birleştirildi.',
  'playlistsManager.toast.mergeNothing':
      'Birleştirilecek başka liste yok. Önce yeni bir liste ekle.',
  'playlistsManager.toast.mergeAlreadyAll':
      '@n liste zaten birleştirilmiş durumda.',
  'playlistsManager.disable': 'Devre dışı bırak',
  'playlistsManager.enable': 'Etkinleştir',
  'playlistsManager.badge.disabled': 'Devre dışı',
  'playlistsManager.toast.disabled': '@n. liste devre dışı bırakıldı',
  'playlistsManager.toast.enabled': '@n. liste etkinleştirildi',
  'playlistsManager.error.cannotDisableLast':
      'En az bir liste etkin kalmalı. Son aktif listeyi devre dışı bırakamazsınız.',
  'playlistsManager.error.mergeReloadFailed':
      'Liste durumu kaydedildi ancak kanallar yenilenemedi. Tekrar deneyin veya ana sayfadan çekerek yenileyin.',
  'playlistsManager.toast.mergeBackgroundFailed':
      'Arka plan birleştirme başarısız oldu. Ana sayfadan aşağı çekerek yenileyin.',

  // Player (TV / controls)
  'player.liveBadge': 'CANLI',
  'player.movieBadge': 'FİLM',
  'player.seriesBadge': 'DİZİ',
  'player.epgLoading': 'EPG yükleniyor…',
  'player.skip_intro': 'Jeneriği Atla',
  'player.channelNumberOutOfRange': 'Kanal @n bulunamadı (1–@total)',
  'setup.smartStreamCutterTitle': 'Akıllı Jenerik Atlatıcı',
  'setup.smartStreamCutterSub':
      'Xtream dizilerinde 1./2. bölümde manuel ileri sardığın süreyi öğrenir; sonraki bölümlerde "Jeneriği Atla" cam butonu otomatik çıkar.',
  'settings.smartStreamCutter.title': 'Akıllı Jenerik Atlatıcı',
  'settings.smartStreamCutter.sub':
      'Xtream dizilerinde ilk bölümlerdeki manuel ileri sarmayı hatırlar ve sonraki bölümlerde sağ alt köşede otomatik bir "Jeneriği Atla" butonu çıkarır. Sadece ilk 5 dakika içindeki 30 sn ve daha uzun ileri sarmaları öğrenir.',
  'player.fit.contain': 'Sığdır',
  'player.fit.cover': 'Doldur',
  'player.fit.fill': 'Ger',
  'player.fit.label': 'Görünüm',
  'player.vodAutoplay.titleEpisode': 'Sonraki bölüm',
  'player.vodAutoplay.titleMovie': 'Sıradaki film',
  'player.vodAutoplay.secondsHint': 'saniye sonra oynatılacak',
  'player.vodAutoplay.cancel': 'İptal',
  'player.vodAutoplay.playNow': 'Şimdi oynat',
  'player.vodAutoplay.backHint': 'Geri tuşu ile iptal',
  'player.vodRail.title': 'Bu kategoride',
  'player.vodRail.hint': 'OK ile seç · Geri ile devam',
  'player.vodRail.hintCategories': '◀ ▶ kategori · OK ile seç · Geri ile devam',
  'player.liveRail.title': 'Kanallar',
  'player.liveRail.hint': 'OK ile geç · Geri ile kapat',
  'player.liveRail.hintCategories':
      '◀ ▶ kategori · OK ile geç · Geri ile kapat',
  'player.tooltip.prevCh': 'Önceki kanal',
  'player.tooltip.nextCh': 'Sonraki kanal',
  'player.tooltip.rewind': '15 sn geri',
  'player.tooltip.forward': '15 sn ileri',
  'player.tooltip.pause': 'Duraklat',
  'player.tooltip.quickMenuHold': 'Hızlı liste: OK uzun bas',
  'player.tooltip.quickMenuOpen': 'Hızlı liste',
  'player.tooltip.play': 'Oynat',
  'player.tooltip.favOff': 'Favorilere ekle',
  'player.tooltip.favOn': 'Favorilerden çıkar',
  'player.tooltip.fit': 'Görünüm: @fit',
  'player.tooltip.quality': 'Yayın Kalitesi',
  'player.tooltip.audio': 'Ses Kaynağı',
  'player.tooltip.subtitle': 'Altyazı',
  'player.tooltip.speed': 'Hız: @ratex',
  'player.tooltip.speed.normal': 'Hız: Normal (1x)',
  'player.tooltip.volume': 'Ses Seviyesi',
  'player.tooltip.cast': 'Cast / TV\'ye gönder',
  'player.cast.title': 'Cast / TV\'ye gönder',
  'player.cast.systemChooser': 'Sistem seçici',
  'player.cast.systemChooserSub': 'Yüklü tüm video uygulamalarını göster',
  'player.cast.empty':
      'Cast destekli yüklü uygulama bulunamadı. Web Video Caster, Cast to TV, BubbleUPnP, AllCast veya Plex gibi bir uygulama yükleyin.',
  'player.cast.noStream': 'Aktif yayın bulunamadı.',
  'player.cast.notAvailable': 'Cast bu cihazda desteklenmiyor.',
  'player.cast.launchFailed': 'Uygulama başlatılamadı.',
  'player.tooltip.backupPlayer': 'Yedek oynatıcıya geç (MediaKit)',
  'player.tooltip.toMediaKit': 'MediaKit ile oynat (M)',
  'player.tooltip.toBetter': 'Better Player ile oynat (B)',
  'player.tooltip.liveEpg': 'Bu kanalın EPG rehberi',
  'player.tooltip.toPortrait': 'Dikey moda geç',
  'player.tooltip.toLandscape': 'Yatay izle (telefonu çevirin)',
  'player.engine.title': 'Oynatma motoru',
  'player.engine.toExo': 'Better Player (Exo) motoruna geç',
  'player.engine.toMediaKit': 'MediaKit (mpv) motoruna geç',
  'player.engine.switchedExo':
      'Bu yayın için Better Player (Exo) motoruna geçildi',
  'player.engine.switchedMediaKit':
      'Bu yayın için MediaKit (mpv) motoruna geçildi',
  'portraitPanel.channelCount': '@n kanal',
  'portraitPanel.live': 'DEVAM EDİYOR',
  'portraitPanel.noProgramme': 'Program mevcut değil',
  'portraitPanel.empty.categories': 'Hiç kategori bulunamadı',
  'portraitPanel.empty.channels': 'Bu kategoride canlı kanal yok',
  'portraitPanel.empty.epg': 'Bu kanal için EPG bilgisi bulunamadı',
  'portraitVodPanel.tab.films': 'Filmler',
  'portraitVodPanel.tab.series': 'Diziler',
  'portraitVodPanel.allFilms': 'Tüm filmler',
  'portraitVodPanel.allSeries': 'Tüm diziler',
  'portraitVodPanel.empty.items': 'Bu kategoride içerik yok',
  'portraitVodPanel.nowPlaying': 'OYNATILIYOR',
  'portraitSeriesPanel.tab.info': 'Dizi',
  'portraitSeriesPanel.tab.episodes': 'Bölümler',
  'portraitSeriesPanel.synopsis': 'Özet',
  'portraitSeriesPanel.cast': 'Oyuncular',
  'portraitSeriesPanel.imdb': 'IMDb',
  'portraitSeriesPanel.year': 'Yıl',
  'portraitSeriesPanel.runtime': 'Süre',
  'portraitSeriesPanel.genre': 'Tür',
  'portraitSeriesPanel.director': 'Yönetmen',
  'portraitSeriesPanel.empty.info': 'Dizi bilgisi şu anda yüklenemedi.',
  'portraitSeriesPanel.empty.episodes':
      'Bu dizi için bölüm listesi bulunamadı.',
  'portraitSeriesPanel.episodeLabel': 'S@s · B@e',
  'portraitSeriesPanel.nowPlaying': 'OYNATILIYOR',
  'portraitSeriesPanel.loading': 'Yükleniyor…',
  'player.engine.switchToBetter.title': 'Better Player (Exo) ile oynat?',
  'player.engine.switchToBetter.body':
      'Dizi akışlarında önerilen motor MediaKit’tir. ExoPlayer’a geçmek istediğinize emin misiniz?',
  'player.engine.better': 'Better Player',
  'player.engine.mediaKit': 'MediaKit',
  'player.engine.vlc': 'VLC',
  'player.engineFallback.toMediaKit': 'Yayın MediaKit ile tekrar deneniyor…',
  'player.engineFallback.toBetter': 'Yayın Better Player ile tekrar deneniyor…',
  'player.quality.title': 'Yayın kalitesi',
  'player.quality.noneShort': 'Bu yayın için kalite seçenekleri mevcut değil.',
  'player.quality.noneLong':
      'Bu yayın için çoklu kalite listesi yok. HD/FHD seçenekleri yalnızca sunucunun HLS master playlist (m3u8) ile birden fazla varyant sunduğu yayınlarda görünür; tek MPEG-TS (.ts) akışında veya tek çözünürlüklü m3u8’te menü dolmaz.',
  'player.audio.title': 'Ses kaynağı',
  'player.audio.noneShort':
      'Bu yayın için alternatif ses kaynağı mevcut değil.',
  'player.audio.noneLong': 'Bu yayın için alternatif ses kaynağı mevcut değil.',
  'player.sheet.audioTitle': 'Ses Kaynağı',
  'player.sheet.subtitleTitle': 'Altyazı',
  'player.sheet.qualityTitle': 'Yayın Kalitesi',
  'player.track.audio': 'Ses @n',
  'player.quality.auto': 'Otomatik (Oto)',
  'player.quality.unknown': 'Bilinmeyen Kalite',
  'player.quality.withFps': '@res · @fps fps',
  'player.loading.decoder': 'Kod çözücü hatası düzeltiliyor (Adım @step)...',
  'player.loading.stream': 'Akış açılıyor...',
  'player.pinchZoom.center': 'Merkez',
  'player.pinchZoom.left': 'Sol @n%',
  'player.pinchZoom.right': 'Sağ @n%',
  'player.pinchZoom.up': 'Yukarı @n%',
  'player.pinchZoom.down': 'Aşağı @n%',
  'player.pinchZoom.reset': 'Sıfırla (1:1)',
  'player.error.contentNotFound': 'İçerik sunucuda bulunamadı',
  'player.error.streamForbidden': 'Yayına erişim reddedildi (403)',
  'player.error.playbackGeneric': 'Yayın şu anda açılamıyor',
  'player.error.invalidStreamUrl': 'Geçersiz yayın adresi',
  'player.pip.unavailable':
      'Bu cihazda veya oynatıcıda küçük ekran (PiP) kullanılamıyor.',
  'player.pip.failed':
      'Küçük ekran (PiP) açılamadı. Sistem ayarlarından PiP iznini kontrol edin.',
  'player.pip.mediaKit':
      'MediaKit modunda PiP yok. Varsayılan oynatıcıya geçin.',
  'player.notReady': 'Oynatıcı hazır değil',
  'player.resume.title': 'Kaldığınız yerden devam?',
  'player.resume.body':
      'Bu içeriği daha önce izlemeye başlamıştınız. Nasıl devam etmek istersiniz?',
  'player.resume.fromLast': 'Kaldığım yerden',
  'player.resume.fromStart': 'Baştan başla',
  'player.warn.title': 'Uyarı',
  'player.warn.qualityShort':
      'Çoklu kalite yok: HD/FHD için HLS’te birden fazla varyant gerekir; saf .ts veya tek kaliteli akışta menü boş kalabilir.',
  'player.mobile.pickAudio': 'Ses kaynağı seçin',
  'player.mobile.pickSubtitle': 'Altyazı seçin',
  'player.subtitle.off': 'Kapalı',
  'player.subtitle.track': 'Altyazı',
  'player.subtitle.embedded': 'Gömülü (dosya içi)',
  'player.subtitle.noneShort': 'Bu yayın için altyazı seçeneği yok.',
  'player.subtitle.noneLong':
      'Manifestte veya akışta altyazı parçası yok; HLS/DASH ile sunulan altyazılar burada listelenir.',
  'player.subtitle.imageBasedTitle': 'Resim tabanlı altyazı',
  'player.subtitle.imageBasedBody':
      'Bu içeriğin gömülü altyazıları resim tabanlı (PGS/VobSub). Mevcut oynatıcı bunları gösteremez. MediaKit oynatıcısına geçilsin mi? Geçiş yalnızca bu yayın için geçerlidir.',
  'player.subtitle.imageBasedBodyTv':
      'Bu içeriğin gömülü altyazıları resim tabanlı (PGS/VobSub). Mevcut oynatıcı bunları gösteremez. MediaKit oynatıcısına geçince altyazı düğmesinden seçebilirsiniz.',
  'player.subtitle.switchToMediaKit': 'MediaKit\'e geç',
  'player.subtitle.switchingForSubs':
      'Altyazılar için MediaKit oynatıcısına geçiliyor…',
  'player.snackbar.audioChanged': 'Ses değiştirildi',
  'player.snackbar.subtitleChanged': 'Altyazı değiştirildi',
  'player.snackbar.qualityChanged': 'Kalite değiştirildi',
  'player.track.channel': 'Kanal @n',
  'externalPlayer.title': 'Harici Oynatıcı',
  'externalPlayer.sub':
      'Yayını VLC, MX Player veya Just Player gibi yüklü bir uygulamada aç.',
  'externalPlayer.picker.title': 'Oynatıcı Seç',
  'externalPlayer.picker.hint':
      'Cihazınızda yüklü video oynatıcılar listelenir. Kullanmak istediğinizi seçin.',
  'externalPlayer.picker.currentLabel': 'Seçili oynatıcı',
  'externalPlayer.picker.systemChooser': 'Her seferinde sor (Android seçici)',
  'externalPlayer.picker.empty': 'Yüklü oynatıcı bulunamadı',
  'externalPlayer.picker.emptyHint':
      'VLC, MX Player veya Just Player gibi bir video oynatıcı kurup tekrar deneyin.',
  'externalPlayer.picker.unsupported':
      'Bu cihazda harici oynatıcı desteklenmiyor.',
  'externalPlayer.picker.errorTitle': 'Oynatıcılar listelenemedi',
  'externalPlayer.picker.savedToast': '@name harici oynatıcı olarak ayarlandı',
  'externalPlayer.error.noStream': 'Geçerli bir akış URL\'si yok',
  'externalPlayer.error.launchFailed':
      'Harici oynatıcı açılamadı, dahili oynatıcıya dönüldü',
};

const Map<String, String> _en = {
  'app.title': 'Mina IPTV Player',
  'paywall.title': 'Mina IPTV Premium',
  'paywall.trial.expired': 'Your 2-day free trial has expired.',
  'paywall.trial.active': '@time remaining in your trial.',
  'paywall.feature.performance.title': 'Countless Themes & Personalization',
  'paywall.feature.performance.subtitle': 'Customize the look of the app to your taste, feel the difference with premium themes.',
  'paywall.feature.sync.title': 'Powerful Media Player',
  'paywall.feature.sync.subtitle': 'Uninterrupted playback experience with advanced hardware acceleration and wide format support.',
  'paywall.feature.keymapping.title': 'One Subscription, 3 Devices',
  'paywall.feature.keymapping.subtitle': 'Unlimited use on tablet, TV, and mobile devices with the same subscription.',
  'paywall.feature.introcutter.title': 'All Other Features',
  'paywall.feature.introcutter.subtitle': 'VOD Special Info, Cloud Backup, Different Designs, Lifetime Free Update Warranty.',
  'paywall.button.buy': 'Buy',
  'paywall.button.buy3devices': 'Add 3 More Devices',
  'paywall.button.coffee': 'Buy Me a Coffee ☕',
  'paywall.coffee.success.title': 'Thank You!',
  'paywall.coffee.success.body': 'Thank you so much for your support, you are awesome!',
  'paywall.button.connecting': 'Connecting...',
  'paywall.button.restore': 'Restore Purchase',
  'paywall.button.restoring': 'Querying...',
  'paywall.grandfather.prompt': 'Member before June 28, 2026?',
  'paywall.grandfather.button': 'Log in with Google to Activate Exemption',
  'paywall.grandfather.syncing': 'Verifying license…',
  'paywall.user.logged_in': 'Logged in as: @email',
  'paywall.error.title': 'Payment Failed',
  'paywall.error.body': 'Could not connect to Google Play Market or payment was cancelled.',
  'paywall.restore.title': 'No Purchase Found',
  'paywall.restore.body': 'No active purchase was found in your Google Play account.',
  'paywall.deviceLimit.title': 'Device Limit Reached',
  'paywall.deviceLimit.body': 'A license can be used on up to @max devices. Remove a registered device to continue.',
  'paywall.deviceLimit.count': 'Registered devices: @count / @max',
  'paywall.deviceLimit.thisDevice': 'This device',
  'paywall.deviceLimit.remove': 'Remove',
  'paywall.deviceLimit.retry': 'Try Again',
  'paywall.deviceLimit.removed': 'Device removed. Refreshing registration…',
  'paywall.deviceLimit.removeFailed': 'Could not remove device. Please try again.',
  'settings.tile.subscription': 'Subscription Status',
  'settings.tile.subscription.sub': 'License and trial period details',
  'settings.subscription.grandfathered': 'Lifetime Free Exemption (Legacy)',
  'settings.subscription.premiumActive': 'Mina Premium Active (Unlimited)',
  'settings.subscription.trialActive': 'Free Trial: @days Days Remaining',
  'settings.subscription.trialExpired': 'Trial Expired (Payment Required)',
  'settings.subscription.dialog.title': 'License Details',
  'settings.subscription.dialog.status': 'License Status: ',
  'settings.subscription.dialog.installDate': 'First Install Date: ',
  'settings.subscription.dialog.purchaseDate': 'License Purchase Date: ',
  'settings.subscription.dialog.trialEnd': 'Trial End Date: ',
  'settings.subscription.dialog.type': 'Package Type: ',
  'settings.subscription.dialog.grandfathered': 'Exemption Status: ',
  'settings.subscription.dialog.grandfathered.yes': 'Yes (Legacy Exemption)',
  'settings.subscription.dialog.grandfathered.no': 'No',
  'settings.subscription.dialog.devices': 'Registered Devices: ',
  'settings.subscription.deviceLimit': 'Device limit reached (@count/@max)',
  'dialog.exit.title': 'Exit Application?',
  'dialog.exit.body': 'Are you sure you want to exit?',
  'dialog.exit.seconds': 'seconds',
  'dialog.exit.yes': 'Yes',
  'dialog.exit.no': 'No',
  'home.refresh.done': 'Playlist refreshed',
  'home.refresh.failed': 'Refresh failed: @e',
  'playlist.refreshing': 'Refreshing playlist',
  'home.live': 'Live TV',
  'home.live.subtitle': 'Live broadcasts',
  'home.films': 'Movies',
  'home.films.subtitle': 'Movies & series',
  'home.series': 'Series',
  'home.series.subtitle': 'TV series',
  'home.recommendedFilms': 'Movies & Series',
  'home.recommendedFilms.subtitle': 'Explore',
  'filmDizi.tab.films': 'Movies',
  'filmDizi.tab.series': 'Series',
  'filmDizi.recentlyAddedFilms': 'Recently added movies',
  'filmDizi.recentlyAddedSeries': 'Recently added series',
  'filmDizi.empty': 'No movies or series found.',
  'filmDizi.emptyFilms': 'No movies found.',
  'filmDizi.emptySeries': 'No series found.',
  'filmDizi.loading': 'Loading content…',
  'filmDizi.searchHintFilms': 'Type a movie name…',
  'filmDizi.searchHintSeries': 'Type a series name…',
  'filmDizi.watch': 'Watch',
  'filmDizi.detail': 'Details',
  'filmDizi.series.startingFirstEpisode': 'Loading first episode…',
  'filmDizi.synopsis': 'Synopsis',
  'filmDizi.trailers': 'Trailers',
  'filmDizi.trailer.xtream': 'Xtream',
  'filmDizi.quickInfo.director': 'Director',
  'filmDizi.quickInfo.genre': 'Genre',
  'filmDizi.cast': 'Cast',
  'filmDizi.similar': 'You might also like',
  'filmDizi.noSynopsis': 'No synopsis available.',
  'filmDizi.actorBio': 'Biography',
  'filmDizi.actorFilms': 'Movies',
  'filmDizi.actorFilmNotFoundTitle': 'Film not found',
  'filmDizi.actorFilmNotFound': '@title was not found in your playlist.',
  'filmDizi.plotMore': 'Read more',
  'filmDizi.plotLess': 'Show less',
  'filmDizi.series.watchEpisode1': 'Watch episode 1',
  'filmDizi.series.seasons': 'Seasons',
  'filmDizi.series.seasonN': 'Season @n',
  'filmDizi.series.episodes': 'Episodes',
  'filmDizi.series.episodeN': 'Episode @n',
  'filmDizi.series.episodeLine': '@show · Season @season · Episode @episode',
  'filmDizi.series.downloadPick': 'Select episode to download',
  'filmDizi.series.release': 'Release: @date',
  'filmDizi.series.episodeCount': '@n Episodes',
  'filmDizi.series.meta.language': '@lang',
  'filmDizi.series.noEpisodes': 'No episodes found.',
  'filmDizi.series.loadFail': 'Could not load episodes.',
  'recommendedFilms.topRated': 'Top Rated',
  'recommendedFilms.recentlyAdded': 'Recently Added',
  'recommendedFilms.uhd4k': '4K / UHD',
  'recommendedFilms.nativeDub': 'Native Dubbed',
  'recommendedFilms.nativeSub': 'Native Subtitles',
  'recommendedFilms.seeAll': 'See All',
  'recommendedFilms.last50Films': 'Last 50 Added Movies',
  'recommendedFilms.last50Series': 'Last 50 Added Series',
  'recommendedFilms.recentlyWatched.title': 'Recently Watched',
  'recommendedFilms.recentlyWatched.empty':
      'You have not watched anything yet. Start watching and your recent picks will appear here.',
  'recommendedFilms.favorite': 'Favorite',
  'recommendedFilms.play': 'Play',
  'recommendedFilms.hrs': 'hrs',
  'recommendedFilms.min': 'min',
  'recommendedFilms.empty': 'No recommended movies found.',
  'recommendedFilms.loading': 'Loading movies…',
  'recommendedFilms.search': 'Search',
  'recommendedFilms.searchHint': 'Type a movie name…',
  'recommendedFilms.searchResults': '@count results: «@query»',
  'home.epgMix': 'Replay & EPG Mix',
  'home.epgMix.subtitle': 'Past and upcoming on TV',
  'home.minaAnalytics': 'Mina Watch Analytics',
  'home.minaAnalytics.subtitle': 'Your viewing stats and recap',
  'home.dock.live': 'Live TV',
  'home.dock.films': 'Movies & Series',
  'home.dock.replay': 'Replay & EPG',
  'home.dock.wrapper': 'Mina Wrapper',
  'home.chat': 'Chat',
  'home.chat.subtitle': 'Live chat in language rooms',
  'chat.title': 'Chat',
  'chat.online': '@n Online',
  'chat.signIn.title': 'Sign in to join the chat',
  'chat.signIn.body':
      'To join chat rooms and send messages, please sign in with Google and enable your backup.',
  'chat.signIn.action': 'Sign in with Google',
  'chat.signIn.busy': 'Signing in…',
  'chat.signIn.failed': 'Sign-in failed. Please try again.',
  'chat.room.subtitle': '@lang room',
  'chat.room.yourLanguage': 'Your language · room',
  'chat.room.headerSub': 'Live chat · last 100 messages',
  'chat.room.empty': 'No messages yet. Be the first to write!',
  'chat.composer.hint': 'Write a message…',
  'chat.composer.send': 'Send',
  'chat.msg.you': 'You',
  'chat.msg.copy': 'Copy',
  'chat.msg.copied': 'Message copied to clipboard',
  'chat.msg.reply': 'Reply',
  'chat.msg.delete': 'Delete',
  'chat.msg.deleteForAll': 'Delete for everyone',
  'chat.msg.deleteTitle': 'Delete message',
  'chat.msg.deleteBody':
      'This message will be permanently deleted for everyone. Are you sure?',
  'chat.msg.deleteFailed': 'Could not delete the message. Please try again.',
  'chat.role.admin': 'Admin',
  'chat.support.adminName': 'Admin',
  'chat.support.contactAdmin': 'Message the Admin',
  'chat.support.contactAdminSub':
      'Private chat with the admin for questions and issues',
  'chat.support.inboxTitle': 'User Messages',
  'chat.support.inboxSubtitle': 'View and reply to messages from users',
  'chat.support.inboxEmpty': 'No user messages yet.',
  'chat.support.userHeaderSub': 'Private chat with the admin',
  'chat.support.adminHeaderSub': 'Private chat with the user',
  'chat.support.emptyUser':
      'Write your first message to the admin. Only you and the admin can see it.',
  'chat.support.emptyAdmin': 'No messages with this user yet.',
  'chat.support.deleteThread': 'Delete chat',
  'chat.support.deleteTitle': 'Delete chat',
  'chat.support.deleteBody':
      'All messages in this conversation will be permanently deleted. This cannot be undone.',
  'chat.support.deleteFailed': 'Could not delete the chat. Please try again.',
  'chat.support.deleteEmpty': 'There is no conversation to delete yet.',
  'chat.support.deleted': 'Chat deleted.',
  'chat.tag.title': 'Stream status',
  'chat.tag.pick': 'Add stream status',
  'chat.tag.clear': 'Remove tag',
  'chat.tag.flowing': 'Stream is live',
  'chat.tag.noFreeze': 'No freezing',
  'chat.tag.freeze': 'Freezing',
  'chat.tag.down': 'Stream down',
  'epgMix.title': 'Replay & EPG Mix',
  'epgMix.cat.replay': 'Replay',
  'epgMix.cat.sport': 'Sports',
  'epgMix.cat.documentary': 'Documentary',
  'epgMix.cat.film': 'Movies',
  'epgMix.cat.series': 'Series',
  'epgMix.cat.news': 'News',
  'epgMix.schedule': '@start – @end',
  'epgMix.empty': 'No upcoming programmes matched EPG for this category.',
  'epgMix.replay.empty':
      'No recently ended programmes yet. Items will appear here as live channel EPG fills in.',
  'epgMix.replay.metaLine': 'Replay · @when',
  'epgMix.replay.justEnded': 'just ended',
  'epgMix.replay.minutesAgo': '@n min ago',
  'epgMix.replay.hoursAgo': '@n h ago',
  'epgMix.replay.yesterday': 'Yesterday',
  'epgMix.replay.error.title': 'Replay unavailable',
  'epgMix.replay.error.notXtream':
      'Replay is only supported when the active source is an Xtream panel.',
  'epgMix.replay.error.template':
      'Catch-up URL template is disabled. Turn it on under Settings > EPG > Catch-up URL.',
  'epgMix.replay.error.url':
      'Could not build a catch-up URL for this programme.',
  'epgMix.remind': 'Remind me',
  'epgMix.remind.cancel': 'Cancel reminder',
  'epgMix.remind.added':
      'Reminder added. You will be notified 30 minutes before it starts.',
  'epgMix.remind.removed': 'Reminder removed.',
  'epgMix.remind.scheduled':
      'You will be notified 30 minutes before it starts.',
  'epgMix.remind.active': 'Reminder on',
  'epgMix.remind.tooLate':
      'It is too late to set a reminder for this programme.',
  'epgMix.remind.permissionDenied':
      'Notification permission denied. Reminder was not set.',
  'epgMix.remind.permissionSettings':
      'Notifications are off. Notification settings opened — enable and try again.',
  'epgMix.remind.failed': 'Could not schedule the reminder. Please try again.',
  'epgMix.remind.title': 'Upcoming programme',
  'epgMix.remind.body': '@channel · starts in @minutes min',
  'settings.tile.upcomingMatches': 'Upcoming Matches',
  'settings.tile.upcomingMatches.subtitle':
      'Show sports EPG strip on the home screen',
  'settings.tile.adaptiveHaptics': 'Adaptive haptics',
  'settings.tile.adaptiveHaptics.subtitle':
      'Light vibration when scrolling lists and tapping items in mobile mode',
  'settings.lowEndMode.title': 'Low-end mode',
  'settings.lowEndMode.subOn':
      'On — flat graphics, blur/shadows off, memory first',
  'settings.lowEndMode.subOff':
      'Off — full visual effects (normal performance)',
  'settings.tvLite.title': 'TV Lite (flat graphics)',
  'settings.tvLite.subOn':
      'On — blur/shadows off, flat focus, fast animations (for TV)',
  'settings.tvLite.subOff':
      'Off — full glass design (blur, shadows, animations)',
  'lowEndMode.suggest.title': 'Performance issue detected',
  'lowEndMode.suggest.body':
      'Your device seems to be struggling to run the app smoothly. For a smoother experience you should switch to "Low-End Device Mode"; visual effects are reduced and performance is prioritized. You can change this anytime under Settings › Other Tools.',
  'lowEndMode.suggest.enable': 'Switch to low-end mode',
  'lowEndMode.suggest.later': 'Not now',
  'setup.upcomingMatchesTitle': 'Upcoming Matches',
  'setup.upcomingMatchesSub': 'Sports strip on home screen',
  'setup.adaptiveHapticsTitle': 'Adaptive haptics',
  'setup.adaptiveHapticsSub': 'Vibration on scroll and tap',
  'setup.mixedLiveTitle': 'Mixed Live TV',
  'setup.mixedLiveSub': 'Random channel strip on home',
  'setup.stripChannelPrefixTitle': 'Strip channel prefixes',
  'setup.stripChannelPrefixSub':
      'Strip country prefixes like TR:/BR:/EN:/US: (quality tags kept)',
  'setup.launchOnBootTitle': 'Launch on boot',
  'setup.launchOnBootSub': 'Open app when device starts',
  'setup.pipTitle': 'Mini player (PiP)',
  'setup.pipSub': 'Floating player when leaving home',
  'setup.inAppPipTitle': 'In-App PiP',
  'setup.inAppPipSub':
      'When you leave the player, the stream keeps playing in a small preview on home',
  'setup.inAppPipPreviewCaption':
      'Press back to return home — the stream plays in the corner (layout-dependent); tap to open full screen.',
  'setup.epgCacheTitle': 'EPG refresh',
  'setup.epgCacheSub': 'How often to refresh the TV guide',
  'setup.epgCacheDays': '@n d',
  'setup.epgCacheNever': 'Off',
  'setup.stepAppFont': 'App font',
  'setup.appFontHint': 'Choose the interface typeface.',
  'setup.featuresHint': 'Use the switch to turn each option on or off.',
  'setup.personalizationHint':
      'Pick the transition used when you swipe between home category cards, and the frame style applied to every card on the home screen. You can change both later from Settings > Home Screen.',
  'setup.stepFeatures': 'Features',
  'settings.tile.mixedLiveTv': 'Mixed Live TV',
  'settings.tile.hideLiveDetail': 'Hide Live TV detail tab (portrait)',
  'settings.tile.hideLiveDetail.on':
      'Detail tab hidden; selecting a channel opens the stream directly',
  'settings.tile.hideLiveDetail.off':
      'Selecting a channel opens the Detail preview first',
  'settings.tile.channelPrefix': 'Channel prefix',
  'settings.tile.channelPrefix.on':
      'Hides country prefixes like TR:/BR:/EN: (quality tags stay)',
  'settings.tile.channelPrefix.off': 'Original playlist names',
  'settings.dialog.channelPrefixTitle': 'Remove channel prefix',
  'settings.dialog.channelPrefixBody':
      'Country code prefixes (TR:, BR:, EN:, DE:, etc.) are hidden in Live TV channel lists, EPG rows, and related strips. Only the channel name is shown.',
  'settings.dialog.channelPrefixExample': 'Examples:',
  'settings.dialog.channelPrefixConfirm': 'Remove',
  'settings.snackbar.channelPrefixOn':
      'Channel prefixes will be hidden in Live TV lists.',
  'settings.snackbar.channelPrefixOff':
      'Channel names will match the playlist.',
  'settings.tile.mixedLiveTv.subtitle': 'Random live channel strip on home',
  'epgMix.loading': 'Loading EPG…',
  'home.mixed_live': 'Mixed Live TV',
  'home.showcase.topRatedFilms': 'Top IMDB Rated Movies',
  'home.showcase.becauseYouWatched': 'Because you watched @title',
  'home.showcase.mixedFilms': 'Mixed Movies',
  'home.showcase.mixedSeries': 'Mixed Series',
  'home.showcase.trendFilms': 'Trending Movies',
  'home.showcase.trendSeries': 'Trending Series',
  'home.showcase.favoriteSeries': 'Favorite Series',
  'home.showcase.favoriteChannels': 'Favorite Channels',
  'home.showcase.favoriteFilms': 'Favorite Movies',
  'home.showcase.suggest.title': 'New: Showcase layout',
  'home.showcase.suggest.body':
      'We added a new Showcase layout for the home screen: vertically scrolling poster rows with a «liquid glass» menu bar at the bottom. Want to try it now? You can switch back anytime from Settings > Home screen.',
  'home.showcase.suggest.tryIt': 'Try it now',
  'home.upcomingMatches': 'Upcoming Matches',
  'home.upcomingMatches.loading': 'Loading TV guide…',
  'marquee.monday': 'New week, new episodes! Enjoy with Mina.',
  'marquee.tuesday': 'Tuesday treat: your favorite series on Mina.',
  'marquee.wednesday': 'Midweek break time! Unwind with Mina.',
  'marquee.thursday': 'Weekend is near, get your watchlist ready.',
  'marquee.friday': 'It\'s Friday! Movie night on Mina tonight.',
  'marquee.saturday': 'Saturday: matches and movies, best on Mina.',
  'marquee.sunday': 'Have a peaceful Sunday, enjoy the show!',
  'home.header.brandTop': 'Mina',
  'home.header.brandBottom': 'IPTV Player',
  'home.search.hint': 'Search…',
  'home.search.dialogTitle': 'Search',
  'home.search.typeToSeeResults': 'Type to see results.',
  'home.search.sectionLive': 'Live TV',
  'home.search.sectionFilms': 'Movies',
  'home.search.sectionSeries': 'Series',
  'home.search.noResults': 'No matching results.',
  'splash.preparing': 'Preparing your library…',
  'splash.playlist': 'Loading playlist…',
  'splash.epg': 'Preparing TV guide…',
  'splash.finishing': 'Almost ready…',
  'setup.wizardTitle': 'Welcome',
  'setup.trialWelcome.title': 'Welcome!',
  'setup.trialWelcome.message': 'You can try and test Mina IPTV Player completely free for 2 days. If you wish, you can pay a one-time fee to use it lifetime. You can also purchase a premium license now or later from Settings > Subscription Info.',
  'setup.trialWelcome.autoClose': 'This notification will close automatically in @seconds seconds.',
  'setup.stepLanguage': 'Language',
  'setup.stepLayoutMode': 'Layout mode',
  'setup.stepTheme': 'Appearance',
  'setup.stepPlayer': 'Player',
  'setup.stepPerformance': 'Performance',
  'setup.stepSource': 'Playlist',
  'setup.layoutModeHint':
      'Choose the home screen layout. In the showcase layout some personalization options (card effects, frame style) are disabled.',
  'setup.tvLayoutModeHint':
      'Choose the TV home layout. TV mode opens the new rail shell; card layout is the classic card home screen.',
  'setup.performanceHint':
      'Choose a mode based on your device power. On devices with 2 GB RAM or less, Low-end mode runs more smoothly.',
  'setup.perfNormalTitle': 'Normal Performance Mode',
  'setup.perfNormalSub':
      'All visual effects on (blur, shadows). Recommended for powerful devices.',
  'setup.perfLowEndTitle': 'Low-end mode',
  'setup.perfLowEndSub':
      'Flat graphics: blur/shadows off, image quality and cache reduced. Recommended for 2 GB RAM or less.',
  'setup.next': 'Continue',
  'setup.back': 'Back',
  'setup.finish': 'Finish setup',
  'setup.finishRequiresSource':
      'Load your playlist first (M3U or Xtream credentials).',
  'setup.skip': 'Skip',
  'setup.sourceHint':
      'Enter your M3U or Xtream details; the app will open after the list loads.',
  'common.or': 'or',
  'cloud.googleSignInTitle': 'Sign in with Google and fetch your lists',
  'cloud.googleSignInSubtitle':
      'Get your playlists and settings automatically from the cloud; restore on new devices with one tap.',
  'cloud.signingIn': 'Signing in',
  'cloud.signedInContinue':
      'Signed in. Continue setup; your settings will be saved to the cloud when finished.',
  'cloud.restored': 'Your cloud backup has been restored.',
  'cloud.restoreFailed': 'Could not restore the cloud backup.',
  'cloud.signInFailed': 'Google sign-in failed.',
  'cloud.playServicesUnavailable':
      'Backup is not supported on this device because Google services are not available.',
  'cloud.signInBrowserOpening': 'Opening Google sign-in in your browser…',
  'cloud.signInBrowserHint':
      'On this device, your Google account will open in the browser.',
  'cloud.signInUnavailable':
      'Google sign-in is unavailable on this device. Google Play services must be installed and up to date, and at least one Google account must be added. Please update and try again.',
  'cloud.signInConfigError':
      'Google sign-in could not be completed (configuration/authentication error). Please try again in a few seconds.',
  'cloud.notConfigured':
      'Cloud feature is not configured in this build (Firebase required).',
  'cloud.title': 'Google Cloud Sync',
  'cloud.syncHint':
      'Your playlists and settings are backed up to your Google account; restore on a new device with one tap.',
  'cloud.status.unavailable': 'Cloud unavailable',
  'cloud.status.notSignedIn': 'Not signed in to Google',
  'cloud.status.notSignedInBody':
      'Sign in to back up your playlists and settings to the cloud.',
  'cloud.status.active': 'Sync active',
  'cloud.status.signedIn': 'Signed in as @email',
  'cloud.signIn.action': 'Sign in with Google',
  'cloud.signOut.action': 'Sign out of Google',
  'cloud.signedOut': 'Signed out of Google.',
  'cloud.backup.title': 'Back up to Google',
  'cloud.backup.body':
      'All M3U/Xtream lists (up to 32 slots), theme, font and PIN settings are saved to your Google account.',
  'cloud.backup.b1': 'Internet connection required',
  'cloud.backup.b2': 'Merges with any existing cloud backup',
  'cloud.backup.b3': 'Restore on a new device with the same Google account',
  'cloud.backup.action': 'Back up to Google',
  'cloud.lastBackup.title': 'Last backup',
  'cloud.lastBackup.loading': 'Loading backup info…',
  'cloud.lastBackup.none': 'You don\'t have a cloud backup yet.',
  'cloud.lastBackup.date': 'Date',
  'cloud.lastBackup.playlists': 'Playlists',
  'cloud.lastBackup.settings': 'Settings',
  'cloud.lastBackup.localM3u': 'Local M3U files',
  'cloud.lastBackup.device': 'Device',
  'cloud.backupDone': 'Backed up to the cloud.',
  'cloud.backupFailed': 'Could not back up to the cloud.',
  'cloud.backup.newerTitle': 'Newer backup in the cloud',
  'cloud.backup.newerBody':
      'There is a newer cloud backup from @date (likely from another device). Are you sure you want to overwrite it with this device\'s data?',
  'cloud.backup.overwrite': 'Overwrite',
  'cloud.delete.action': 'Delete cloud data',
  'cloud.delete.confirmTitle': 'Delete cloud data?',
  'cloud.delete.confirmBody':
      'Your entire cloud backup will be permanently deleted. Local data on this device is not affected. This cannot be undone.',
  'cloud.delete.confirmYes': 'Delete',
  'cloud.delete.done': 'Cloud data deleted.',
  'cloud.delete.failed': 'Could not delete cloud data.',
  'cloud.restore.title': 'Restore from Google',
  'cloud.restore.body':
      'Applies the latest cloud backup to this device; overwrites local settings.',
  'cloud.restore.b1': 'You must sign in with Google first',
  'cloud.restore.b2':
      'Local `mina_*` settings and playlist credentials will change',
  'cloud.restore.b3': 'Restarting the app after restore is recommended',
  'cloud.restore.action': 'Restore from Google',
  'cloud.restore.confirmTitle': 'Restore from cloud?',
  'cloud.restore.confirmBody':
      'Local settings and playlist credentials will be replaced with the cloud backup. Continue?',
  'cloud.restore.empty': 'No cloud backup found.',
  'cloud.restore.progress.title': 'Loading cloud backup',
  'cloud.restore.progress.titleDone': 'Backup restored',
  'cloud.restore.progress.subtitle':
      'Data from your Google account is being applied to this device',
  'cloud.restore.progress.autoClose': 'Closing in @n seconds',
  'cloud.restore.progress.row.download': 'Downloading from cloud',
  'cloud.restore.progress.row.playlists': '@n playlists',
  'cloud.restore.progress.row.settings': '@n settings',
  'cloud.restore.progress.row.localM3u': '@n local M3U files',
  'cloud.restore.progress.row.profiles': '@n profiles',
  'cloud.restore.progress.row.apply': 'Applying to device',
  'cloud.restore.partialPlaylistsTitle': 'Playlist restore warning',
  'cloud.restore.partialPlaylists':
      '@fail playlist(s) could not be loaded; @ok of @total installed successfully.',
  'cloud.restore.allPlaylistsFailed':
      'No playlists could be loaded. Your settings were restored; you can re-add playlists in Settings.',
  'cloud.signIn.title': 'Sign in with Google',
  'cloud.signIn.body':
      'Sign in with your Google account to back up your playlists and settings to the cloud and restore them on other devices.',
  'cloud.prompt.title': 'Back up your lists to the cloud',
  'cloud.prompt.body':
      'Sign in with Google to automatically back up all your lists and settings to the cloud, and restore them on a new device with a single tap.',
  'cloud.prompt.later': 'Later',
  'cloud.prompt.signedIn':
      'Signed in. Your lists and settings will be backed up to the cloud.',
  'cloud.prompt.loading': 'Loading your settings…',
  'cloud.prompt.loaded': 'Your cloud settings have been loaded.',
  // Profiles (Netflix-style)
  'settings.tile.profiles': 'Profiles',
  'settings.tile.profiles.sub': 'Separate preferences for each user',
  'settings.tile.profiles.active': 'Active: @name · @n profiles',
  'profiles.title': 'Profiles',
  'profiles.hint':
      'Each profile has its own theme, language, home screen and preferences. Playlists are shared across all profiles.',
  'profiles.manageHint': 'Tap a profile to edit it. Tap "Done" to exit.',
  'profiles.manage': 'Manage',
  'profiles.add': 'Add profile',
  'profiles.create': 'Create profile',
  'profiles.edit': 'Edit profile',
  'profiles.delete': 'Delete',
  'profiles.delete.confirmTitle': 'Delete profile?',
  'profiles.delete.confirmBody':
      'The "@name" profile and its preferences will be deleted. Playlists are not affected.',
  'profiles.name': 'Profile name',
  'profiles.nameRequired': 'Please enter a profile name.',
  'profiles.avatar': 'Avatar color',
  'profiles.picture': 'Profile picture',
  'profiles.lastOne': 'At least one profile must remain.',
  'profiles.switched': 'Switched to "@name".',
  'profiles.lock.title': 'PIN lock',
  'profiles.lock.on': 'This profile is protected with a PIN',
  'profiles.lock.off': 'This profile is unprotected',
  'profiles.lock.add': 'Set PIN',
  'profiles.lock.remove': 'Remove lock',
  'profiles.pin.enter': 'Enter PIN',
  'profiles.pin.set': 'Set a new PIN',
  'profiles.pin.confirm': 'Confirm PIN',
  'profiles.pin.wrong': 'Wrong PIN.',
  'profiles.pin.mismatch': 'PINs do not match.',
  'profiles.pin.digits4': 'Enter a 4-digit PIN',
  'profiles.pin.forgot': 'Forgot PIN',
  'profiles.pin.change': 'Change PIN',
  'profiles.pin.changedPending': 'New PIN ready. It will apply when you save.',
  'profiles.action.prompt': 'What would you like to do?',
  'profiles.action.switch': 'Switch to this profile',
  'profiles.action.edit': 'Edit',
  'profiles.recovery.set': 'Set a recovery key',
  'profiles.recovery.setHint':
      'If you forget your PIN, you can reset it with this key. Keep it in a safe place.',
  'profiles.recovery.hint': 'Your secret key',
  'profiles.recovery.enter': 'Enter recovery key',
  'profiles.recovery.enterHint':
      'Enter the key you set for "@name" to reset its PIN.',
  'profiles.recovery.wrong': 'Incorrect recovery key.',
  'profiles.recovery.notSet':
      'No recovery key is set for this profile. Edit the profile in Settings to reset.',
  'profiles.recovery.reset': 'Reset PIN with key',
  'profiles.recovery.resetDone': 'PIN was reset with your recovery key.',
  'profiles.recovery.ownerResetBody':
      'The "@name" profile has no recovery key. As the device owner, do you want to reset the lock by setting a new PIN?',
  'cloud.autoBackup.title': 'Automatic backup',
  'cloud.autoBackup.body':
      'Your settings and playlists are backed up to Google automatically in the background at the interval you choose.',
  'cloud.autoBackup.off': 'Off',
  'cloud.autoBackup.daily': 'Once a day',
  'cloud.autoBackup.weekly': 'Once a week',
  'backupRestore.localSection': 'Local file backup',
  'settings.tile.cloudSync': 'Google Cloud Sync',
  'setup.tvTitle': 'Enter your playlist',
  'setup.tv.brand': 'Mina Player TV',
  'setup.tv.welcome': 'Welcome to setup',
  'setup.tv.subtitle':
      'Choose a method below. The app will open after the playlist is added.',
  'setup.tv.methodUrl': '1. M3U URL',
  'setup.tv.methodFile': '2. M3U file',
  'setup.tv.methodXtream': '3. Xtream',
  'setup.tv.urlConnect': 'Connect with URL',
  'setup.tv.filePick': 'Choose file',
  'setup.tv.xtreamLogin': 'Sign in',
  'setup.tv.demo': 'Demo mode',
  'setup.tv.langLine': 'Language matches your device (automatic).',
  'setup.tv.xtreamServer': 'Server URL',
  'setup.tv.xtreamUser': 'Username',
  'setup.tv.xtreamPass': 'Password',
  'setup.tv.urlFieldHint': 'M3U playlist URL',
  'setup.playerExoTitle': 'Better / ExoPlayer',
  'setup.playerExoSub':
      'Lower latency, recommended on most devices for live and VOD.',
  'setup.playerMkvTitle': 'MediaKit (mpv)',
  'setup.playerMkvSub':
      'Alternative for difficult streams; you can change this later in settings.',
  'setup.playerVlcSub':
      'Third engine based on libVLC; may work better on some streams.',
  'integrity.dialog.title': 'Use the official version',
  'integrity.dialog.body':
      'This install doesn’t match a Google Play license. For the safest experience, we recommend installing the app from Google Play.',
  'integrity.dialog.later': 'Not now',
  'integrity.dialog.openPlay': 'Open in Google Play',
  'update.forced.title': 'Update required',
  'update.forced.body':
      'This version is no longer supported. Please update the app to the latest version to continue.',
  'update.forced.later': 'Later',
  'update.forced.update': 'Update now',
  'browse.films': 'Movies',
  'browse.series': 'Series',
  'browse.favorites': 'Favorites',
  'browse.empty': 'No results found.',
  'browse.pickItem': 'Select an item',
  'browse.tab.category': 'Category',
  'browse.tab.detail': 'Details',
  'browse.categoriesHeader': 'Categories',
  'browse.recentAdded': 'Recently Added',
  'browse.recentlyWatched': 'Recently Watched',
  'browse.seriesShort': 'Series',
  'browse.season': 'Season',
  'browse.episodes': 'Episodes',
  'browse.series.seasonLabel': 'Season @n',
  'browse.series.seasonCount': '@n Seasons',
  'browse.series.readMore': 'Read more',
  'browse.series.readLess': 'Show less',
  'browse.episode.number': 'Episode @n',
  'browse.castHeading': 'Cast',
  'browse.seriesEpgButton': 'Details',
  'browse.seriesEpgEmpty': 'No detailed information for this series.',
  'browse.playFullscreen': 'Play full screen',
  'browse.selectEpisode': 'Select an episode',
  'browse.notPlayable': 'Not playable',
  'browse.section.onNow': 'On now',
  'browse.badge.live': '• Live',
  'browse.section.movie': 'Movie',
  'browse.section.preview': 'Preview',
  'browse.favorite': 'Favorite',
  'browse.detail.epg':
      'No EPG feed is linked for this channel yet. When programme data is available, the title and summary will appear here.\n\nSelected: @title',
  'browse.detail.movie':
      'When the provider does not supply a synopsis, a short summary is shown here.\n\nDuration: @duration\nSelected: @name',
  'browse.duration.unknown': 'Duration unknown',
  'browse.duration.minutes': '@n min',
  'browse.vod.trailer': 'Trailer',
  'browse.vod.trailerMissing': 'No trailer link for this title.',
  'browse.vod.overview': 'Overview:',
  'browse.vod.shortInfo': 'Film details',
  'browse.vod.metaLine.genre': 'Genre: @v',
  'browse.vod.metaLine.director': 'Director: @v',
  'browse.vod.metaLine.cast': 'Cast: @v',
  'browse.vod.metaLine.release': 'Released: @v',
  'browse.vod.metaLine.rating': 'Rating: @v',
  'browse.vod.noSynopsis': 'No synopsis from the source.',
  'browse.vod.trailerOpenFail': 'Could not open the trailer.',
  'channels.search': 'Search channels…',
  'channels.searchDialogTitle': 'Search channels',
  'channels.searchSubmit': 'Search',

  // Recent searches (shown in live TV / browse / home search dialogs)
  'search.recent.title': 'Recent searches',
  'search.recent.clear': 'Clear',

  // Audio equalizer (Playback Settings → Audio Equalizer)
  'settings.tile.equalizer': 'Audio Equalizer',
  'settings.tile.equalizer.off': 'Off',
  'settings.tile.equalizer.sub': 'On · @p',
  'settings.equalizer.title': 'Audio Equalizer',
  'settings.equalizer.hint':
      '10-band graphic EQ. Applied in real time on the MediaKit (libmpv) engine; disabled on the BetterPlayer (ExoPlayer) engine.',
  'settings.equalizer.enable': 'Enable equalizer',
  'settings.equalizer.preamp': 'Preamp',
  'settings.equalizer.reset': 'Reset',
  'settings.equalizer.preset.title': 'Preset',
  'settings.equalizer.preset.flat': 'Flat',
  'settings.equalizer.preset.bassBoost': 'Bass Boost',
  'settings.equalizer.preset.trebleBoost': 'Treble Boost',
  'settings.equalizer.preset.vocal': 'Vocal',
  'settings.equalizer.preset.rock': 'Rock',
  'settings.equalizer.preset.pop': 'Pop',
  'settings.equalizer.preset.jazz': 'Jazz',
  'settings.equalizer.preset.classical': 'Classical',
  'settings.equalizer.preset.electronic': 'Electronic',
  'settings.equalizer.preset.acoustic': 'Acoustic',
  'settings.equalizer.preset.custom': 'Custom',
  'settings.equalizer.engine.mediaKit': 'MediaKit (mpv) — full support',
  'settings.equalizer.engine.betterPlayer': 'BetterPlayer (ExoPlayer)',
  'settings.equalizer.engine.betterPlayer.unsupported':
      'Android system equalizer is unavailable on this device (Android 9+ restriction). EQ won\'t apply to BetterPlayer streams.',
  'settings.equalizer.engine.betterPlayer.platform':
      'No BetterPlayer EQ bridge on this platform; EQ applies only to MediaKit streams.',
  'channels.title': 'Channels',
  'channels.empty': 'No channels found.',
  'channels.pick': 'Select a channel',
  'channels.tab.categories': 'Categories',
  'channels.tab.channels': 'Channels',
  'channels.tab.detail': 'Details',
  'channels.tab.epgTimeline': 'EPG',
  'channels.epgTimeline.title': 'EPG timeline',
  'channels.epgTimeline.axis': 'Time',
  'channels.epgTimeline.truncated':
      'Long list; showing only the first @n channels.',
  'channels.epgTimeline.upNext': 'Up next',
  'channels.epgTimeline.noSummary': 'No synopsis.',
  'channels.epgTimeline.playlistSource': 'Playlist',
  'channels.epgTimeline.noProgrammeInfo': 'No programme information',
  'channels.epgTimeline.minutesLeft': '@n min left',
  'channels.epgTimeline.endsUnderMinute': 'Less than a minute left',
  'channels.epgTimeline.metaGroup': 'Group: @name',
  'channels.allChannels': 'All channels',
  'channels.favoritesCategory': 'Favorites',
  'channels.recentlyWatchedCategory': 'Recently Watched',
  'channels.favoritesCategoryEmpty':
      'No favorite channels yet. Tap the heart icon to favorite a channel.',
  'channels.detail.sameCategory': 'Channels in this category',
  'channels.detail.sameCategoryNamed': '@name channels',
  'common.play': 'Play',
  'common.notPlayable': 'Not playable',
  'common.favorite': 'Favorite',
  'common.back': 'Back',
  'common.ok': 'OK',
  'common.later': 'Later',
  'common.success': 'Success',
  'common.error': 'An error occurred',
  'common.cancel': 'Cancel',
  'common.confirm': 'Confirm',
  'common.close': 'Close',
  'common.save': 'Save',
  'common.refreshNow': 'Refresh now',
  'common.delete': 'Delete',
  'common.done': 'Done',
  'common.clear': 'Clear',
  'common.retry': 'Retry',
  'common.active': 'On',
  'common.inactive': 'Off',
  'common.on': 'On',
  'common.off': 'Off',
  'common.loading': 'Loading…',
  'common.yes': 'Yes',
  'common.no': 'No',
  'common.fetching': 'Fetching…',
  'common.copy': 'Copy',
  'common.copied': 'Copied',
  'common.show': 'Show',
  'common.hide': 'Hide',

  'rateApp.title': 'Enjoying the app?',
  'rateApp.body':
      'Thanks for updating! A quick 5-star rating and a few words on Google Play really help us keep improving.',
  'rateApp.cta': 'Rate on Play Store',
  'rateApp.later': 'Not now',
  'common.lang.tr': 'Turkish',
  'common.lang.en': 'English',
  'common.lang.fr': 'French',
  'common.lang.ar': 'Arabic',
  'common.lang.zh': 'Chinese',
  'common.lang.ru': 'Russian',
  'common.lang.ja': 'Japanese',
  'common.lang.es': 'Spanish',
  'common.lang.ko': 'Korean',
  'common.lang.he': 'Hebrew',
  'common.lang.da': 'Danish',
  'common.lang.sv': 'Swedish',
  'common.lang.hi': 'Hindi',
  'common.lang.th': 'Thai',
  'common.lang.it': 'Italian',
  'common.lang.pt': 'Portuguese',
  'common.lang.id': 'Indonesian',
  'common.lang.de': 'German',
  'common.lang.fa': 'Persian',
  'common.lang.pl': 'Polish',
  'common.lang.nl': 'Dutch',
  'common.lang.uk': 'Ukrainian',
  'common.lang.vi': 'Vietnamese',
  'common.lang.el': 'Greek',
  'common.lang.ro': 'Romanian',
  'common.lang.sq': 'Albanian',

  // Speed Test
  'settings.speed_test.title': 'Speed Test',
  'settings.speed_test.start': 'Start Test',
  'settings.speed_test.testing': 'Testing...',
  'settings.speed_test.completed': 'Test Completed',
  'settings.speed_test.retry': 'Retry',
  'settings.speed_test.download': 'Download Speed',
  'settings.speed_test.last_result': 'Last Test Result',
  'settings.speed_test.info.title': 'Speed Limits',
  'settings.speed_test.threshold.very_slow':
      'Very Slow - You may experience buffering and freezes',
  'settings.speed_test.threshold.borderline':
      'Borderline - HD streams may have occasional stuttering',
  'settings.speed_test.threshold.excellent':
      'Excellent - You can enjoy seamless streaming',
  'settings.speed_test.message.very_slow':
      'Your internet speed is very low. Buffering is normal. Please check your network.',
  'settings.speed_test.message.borderline':
      'Your internet speed is borderline. HD streams may have occasional stuttering.',
  'settings.speed_test.message.excellent':
      'Your internet speed is excellent. You can enjoy seamless streaming.',
  'settings.speed_test.analysis.very_slow': 'Very Low Speed',
  'settings.speed_test.analysis.borderline': 'Borderline Speed',
  'settings.speed_test.analysis.excellent': 'Excellent Speed',
  'settings.speed_test.error.title': 'Error',
  'settings.speed_test.error.no_internet': 'Please connect to the internet',
  'settings.speed_test.error.test_failed': 'Test failed: @error',
  'settings.tile.speedTest': 'Speed Test',
  'settings.tile.speedTest.sub': 'Test your internet speed',
  'search.channel': 'Search channels…',
  'search.film': 'Search movies…',
  'search.series': 'Search series…',
  'search.favorite': 'Search favorites…',
  'layout.mobile': 'Mobile',
  'layout.tablet': 'Tablet',
  'layout.tv': 'TV',
  'layout.mobile.sub': 'Touch-friendly compact lists for phones.',
  'layout.tablet.sub': 'Wider layout with medium text and spacing.',
  'layout.tv.sub': 'Large text and focus for remotes and distance viewing.',
  'layout.dialog.phone.sub': 'Portrait and landscape allowed',
  'layout.dialog.tv.sub': 'Landscape lock (remote-focused)',
  'theme.defaultName': 'Default',
  'theme.darkGlass': 'Dark glass',
  'theme.amoledBlack': 'Amoled Black',
  'theme.glassmorphism': 'Glassmorphism',
  'theme.darkFlat': 'Dark Flat',
  'theme.glassGri': 'Glass Gri',
  'theme.flatBlack': 'Flat Black',
  'theme.minaGlass': 'Mina Glass',
  'theme.semcTheme': 'SEMC Theme',
  'theme.flyUi': 'Fly UI',
  'theme.flyUi.sub': 'Flyme-style frosted glass and blue accent',
  'theme.tvLite': 'TV Lite',
  'theme.ios27': 'OS27',
  'theme.ios27.sub':
      'iOS Liquid Glass: translucent panels, blue accent, fluid glass wallpaper',
  'theme.macTema': 'Mac Tema',
  'theme.macTema.sub':
      'macOS Tahoe: Apple dark glass panels, Apple blue accent, Tahoe wave wallpaper',
  'theme.mint': 'Mint',
  'theme.mint.sub': 'Linux Mint green accent, semi-transparent panels',
  'settings.title': 'Settings',
  'settings.language': 'App language',
  'settings.deviceMode': 'Device mode',
  'settings.phone': 'Phone',
  'settings.tv': 'TV',
  'settings.blurReduce': 'Reduce blur (performance)',
  'settings.blurReduce.subtitle': 'Lower GPU use by reducing blur effects',
  'settings.launchOnBoot': 'Launch on boot',
  'settings.launchOnBoot.subtitle': 'Open the app after the device restarts',
  'settings.section.general': 'General',
  'settings.section.about': 'About',
  'settings.tile.playlist': 'Playlist',
  'settings.tile.playlist.sub': 'View or change your source',
  'settings.tile.refresh': 'Refresh content',
  'settings.tile.refresh.loading': 'Refreshing…',
  'settings.tile.refresh.sub': 'Fetch the latest list from the server',
  'settings.tile.autoRefresh': 'Auto refresh',
  'settings.tile.autoRefresh.sub': 'Every @days days',
  'settings.tile.account': 'Account info',
  'settings.tile.account.sub': 'View Xtream subscription details',
  'settings.tile.parental': 'Parental controls',
  'settings.tile.parental.sub':
      'PIN protection; hide Xtream categories (live, movies, series)',
  'settings.tile.xtreamApiEpgOnly': 'Xtream API EPG only',
  'settings.tile.xtreamApiEpgOnly.on':
      'On: panel XMLTV skipped; get_all_live_epg only',
  'settings.tile.xtreamApiEpgOnly.off':
      'Off: panel XMLTV and API EPG together (parallel)',
  'settings.xtreamCategoryHide.title': 'Show / hide categories',
  'settings.xtreamCategoryHide.unavailable':
      'Load a playlist first (Xtream or M3U).',
  'settings.xtreamCategoryHide.tabLive': 'Live',
  'settings.xtreamCategoryHide.tabVod': 'Movies',
  'settings.xtreamCategoryHide.tabSeries': 'Series',
  'settings.xtreamCategoryHide.emptyLive': 'No live categories.',
  'settings.xtreamCategoryHide.emptyVod': 'No movie categories.',
  'settings.xtreamCategoryHide.emptySeries': 'No series categories.',
  'settings.xtreamCategoryHide.idLabel': 'ID: @id',
  'settings.xtreamCategoryHide.m3uNameHint':
      'M3U: by group-title name (persists after refresh)',
  'settings.xtreamCategoryHide.saved': 'Category hiding saved.',
  'settings.xtreamCategoryHide.reorderHint':
      'Drag the handle on the right to change the order.',
  'settings.xtreamCategoryHide.visibilityHint':
      'Switch on = category visible, off = hidden.',
  'settings.xtreamCategoryHide.hideAll': 'Hide all',
  'settings.xtreamCategoryHide.showAll': 'Show all',
  'settings.tile.categoryHide': 'Show / hide categories',
  'settings.tile.categoryHide.sub':
      'Show or hide categories for channels, movies and series',
  'settings.tile.channelLayout': 'Channel & Category Layout',
  'settings.tile.channelLayout.sub':
      'Hide categories and edit live channel layout (sort / remove) in one place',
  'settings.tile.playback': 'Playback Settings',
  'settings.tile.playback.sub':
      'Player engine, hardware acceleration, video decoder and low-latency buffer',
  'settings.tile.keyMapping': 'Remote Key Mapping',
  'settings.tile.keyMapping.sub':
      'Assign quick actions to your remote control keys',
  'settings.keyMapping.success.title': 'Success',
  'settings.keyMapping.success.msg': 'Key "{key}" has been assigned to "{action}".',
  'playbackSettings.title': 'Playback Settings',
  'playbackSettings.hint':
      'Player engine and low-level video options. If a stream stutters, try switching the engine or forcing the software decoder.',
  'playbackSettings.inAppPip.title': 'In-App PiP',
  'playbackSettings.inAppPip.subOn':
      'Playback continues in a small player when returning to home',
  'playbackSettings.inAppPip.subOff':
      'Playback stops when returning to home',
  'playbackSettings.inAppPip.handheldOnly':
      'Available on phones and tablets only',
  'playbackSettings.inAppPip.blockedLiveMediaKit':
      'In-app PiP is disabled while the live engine is MediaKit',
  'inAppPip.suggest.title': 'In-App PiP',
  'inAppPip.suggest.body':
      'When you return from the player, playback continues in a small preview on home (Showcase and Card layouts). Try it?',
  'inAppPip.suggest.enable': 'Turn on',
  'inAppPip.suggest.later': 'Later',
  'settings.tile.silentSync': 'Silent Background Sync',
  'settings.tile.silentSync.sub': 'Silently updates the playlist when app is closed',
  'settings.tile.silentSync.enabled': 'Enabled (Updates once a day)',
  'settings.tile.silentSync.disabled': 'Disabled',
  'settings.tile.otherTools': 'Other Tools',
  'settings.tile.otherTools.sub':
      'Sleep timer, EPG, theme, backup, speed test, haptics and font',
  'otherTools.title': 'Other Tools',
  'otherTools.hint':
      'Less frequently used helper tools, gathered in one place.',
  'otherTools.inAppPip.title': 'In-App PiP',
  'otherTools.inAppPip.subOn':
      'Mini player on showcase home while browsing',
  'otherTools.inAppPip.subOff':
      'Playback stops when returning to home',
  'channelLayout.title': 'Channel & Category Layout',
  'channelLayout.hint':
      'Hide categories and edit the order/contents of your live channel list. Each row opens its own editor; changes are reflected on the home screen when you go back.',
  'channelEditor.title': 'Live channel layout',
  'channelEditor.unavailable': 'Load a playlist first (Xtream or M3U).',
  'channelEditor.hint':
      'Pick a live category above. Remote: ◀ ▶ or ▲ ▼ reorder · Delete removes the channel.',
  'channelEditor.emptyCategory': 'No channels in this category.',
  'channelEditor.saved': 'Channel layout saved.',
  'channelEditor.removeTitle': 'Remove channel from list',
  'channelEditor.removeBody':
      'The channel will be hidden in the app. Reload the playlist or reset settings to restore.',
  'channelEditor.idLabel': 'ID: @id',
  'settings.tile.homeCardOrder': 'Home screen card order',
  'settings.tile.homeCardOrder.sub':
      'Order of Live TV, Movies, Series, Movies & Series, EPG Mix and Mina Watch Analytics',
  'settings.tile.homeSettings': 'Home screen settings',
  'settings.tile.homeSettings.sub':
      'Card order, mixed live TV and upcoming matches',
  'homeSettings.title': 'Home screen settings',
  'homeSettings.hint':
      'The switches below control which strips appear on the home screen. The preview under each row shows what will be added when it is enabled.',
  'homeSettings.cardOrder.title': 'Card order',
  'homeSettings.cardOrder.sub':
      'Reorder Live TV, Movies, Series, Favorites etc. big cards',
  'homeSettings.cardScale.title': 'Card size',
  'homeSettings.cardScale.sub':
      'Shrink or enlarge all cards and strips on the home screen',
  'homeSettings.cardScale.small': 'Small',
  'homeSettings.cardScale.standard': 'Standard',
  'homeSettings.cardScale.large': 'Large',
  'homeSettings.cardScale.tvHint':
      'Remote: ◀ ▶ changes size, ▲ ▼ moves to the next option',
  'homeSettings.mixedLive.title': 'Mixed Live TV',
  'homeSettings.mixedLive.sub':
      'When on, the home screen gets a random strip of live channels from different categories',
  'homeSettings.trendFilms.title': 'Trending Movies',
  'homeSettings.trendFilms.sub':
      'Showcase layout only: shows the top 50 movies rated IMDB 7 and above as a strip (refreshed at rare intervals)',
  'homeSettings.upcomingEpg.title': 'Upcoming Broadcasts (EPG)',
  'homeSettings.upcomingEpg.sub':
      'Showcase layout only: shows upcoming broadcast times and countdowns for popular channels',
  'showcase.upcomingEpg.header': 'Upcoming Broadcasts',
  'showcase.upcomingEpg.next': 'Up Next',
  'showcase.upcomingEpg.onAir': 'On Air',
  'showcase.upcomingEpg.starting': 'Starting',
  'showcase.upcomingEpg.ending': 'Ending',
  'homeSettings.trendSeries.title': 'Trending Series',
  'homeSettings.trendSeries.sub':
      'Showcase layout only: shows the top 50 series rated IMDB 7 and above as a strip (refreshed at rare intervals)',
  'homeSettings.favoriteFilms.title': 'Favorite Movies',
  'homeSettings.favoriteFilms.sub':
      'Showcase layout only: shows the movies you favorited as a strip on the home screen',
  'homeSettings.favoriteSeries.title': 'Favorite Series',
  'homeSettings.favoriteSeries.sub':
      'Showcase layout only: shows the series you favorited as a strip on the home screen',
  'homeSettings.mixedFilms.title': 'Mixed Movies',
  'homeSettings.mixedFilms.sub':
      'Showcase layout only: shows a random mix of movies from all categories as a strip on the home screen',
  'homeSettings.mixedSeries.title': 'Mixed Series',
  'homeSettings.mixedSeries.sub':
      'Showcase layout only: shows a random mix of series from all categories as a strip on the home screen',
  'homeSettings.lastWatchedButton.title': 'Last Watched Button',
  'homeSettings.lastWatchedButton.sub':
      'Show/hide the last watched circular button above the search button in showcase layout',
  'homeSettings.upcomingMatches.title': 'Upcoming Matches',
  'homeSettings.upcomingMatches.sub':
      'Show upcoming football / sports fixtures as a card strip on the home screen',
  'homeSettings.continueWatching.title': 'Continue Watching',
  'homeSettings.continueWatching.sub':
      'Show films and series you left unfinished on the home screen, starting from the most recently watched. Disabling it removes the strip.',
  'homeSettings.aiRecommendations.title': 'AI-Powered Home Recommendations',
  'homeSettings.aiRecommendations.sub':
      'Mina AI analyzes your viewing habits and suggests 10 mixed live / film / series picks based on category and time of day',
  'homeSettings.reduceBlur.title': 'Reduce Blur (Speed)',
  'homeSettings.reduceBlur.sub':
      'Turns off blur on backgrounds and glass surfaces. When on, CPU load and heat drop and scrolling feels smoother. Recommended on low-end devices.',
  'homeSettings.dailyQuote.title': 'Daily Quote',
  'homeSettings.dailyQuote.sub':
      'Show the short daily greeting strip at the top of the home screen. Disabling it removes the strip and its surrounding spacing.',
  'homeSettings.dailyQuote.previewText': 'Start the week with energy!',
  'homeSettings.swipeEffect.title': 'Swipe Effect',
  'homeSettings.swipeEffect.sub':
      'Choose the transition applied when swiping between category cards on the home screen.',
  'homeSettings.swipeEffect.default.title': 'Default',
  'homeSettings.swipeEffect.default.sub':
      'Side cards shrink and fade slightly — the lightest performance option.',
  'homeSettings.swipeEffect.blur.title': 'Blur Transition',
  'homeSettings.swipeEffect.blur.sub':
      'Outgoing cards blur (0→18 sigma) while the centered card stays sharp.',
  'homeSettings.swipeEffect.tintSweep.title': 'Tint Sweep',
  'homeSettings.swipeEffect.tintSweep.sub':
      'A primary-color gradient sweeps over the side cards in the swipe direction.',
  'homeSettings.swipeEffect.rubberBand.title': 'Rubber Band',
  'homeSettings.swipeEffect.rubberBand.sub':
      'Elastic snap-back when reaching the page edges with a slight overshoot on settle.',
  'homeSettings.transitionEffect.title': 'Transition Effect',
  'homeSettings.transitionEffect.sub':
      'Choose the page transition animation.',
  'homeSettings.transitionEffect.ios.title': 'iOS',
  'homeSettings.transitionEffect.ios.sub':
      'iOS-style right-to-left swipe transition.',
  'homeSettings.transitionEffect.fadeScale.title': 'Soft',
  'homeSettings.transitionEffect.fadeScale.sub':
      'Soft fade + scale transition.',
  'homeSettings.transitionEffect.jelly.title': 'Jelly Windows',
  'homeSettings.transitionEffect.jelly.sub':
      'Linux Compiz-style wobbling, elastic page transition.',
  'homeSettings.frameStyle.title': 'Frame Style',
  'homeSettings.frameStyle.sub':
      'Apply a unified frame look to category cards, Continue Watching, Mina AI and Top Rated Films strips on the home screen.',
  'homeSettings.frameStyle.classic.title': 'Classic',
  'homeSettings.frameStyle.classic.sub':
      'Default glass frame — thin white border with a subtle shadow.',
  'homeSettings.frameStyle.neonGlow.title': 'Neon Glow',
  'homeSettings.frameStyle.neonGlow.sub':
      'Soft theme-colored halo around the card plus a thin primary border.',
  'homeSettings.frameStyle.embossed.title': 'Embossed',
  'homeSettings.frameStyle.embossed.sub':
      'Light highlight on top, pronounced shadow on bottom — a modern recessed 3D feel.',
  'homeSettings.frameStyle.boldOutline.title': 'Bold Outline',
  'homeSettings.frameStyle.boldOutline.sub':
      'Thick theme-colored inner border for a crisp, defined look.',
  'setup.continueWatchingTitle': 'Continue Watching',
  'setup.continueWatchingSub':
      'Show films and series you left unfinished on the home screen',
  'setup.aiRecommendationsTitle': 'AI-Powered Home Recommendations',
  'setup.aiRecommendationsSub':
      'Show 10 personalized picks (live, film, series) based on your viewing history',
  'setup.filmDiziMode.title': 'Movies & Series mode',
  'setup.filmDiziMode.sub':
      'Choose how movies and series are shown on the home screen — you can change it later from Settings',
  'homeSettings.filmDiziMode.title': 'Movies & Series mode',
  'homeSettings.filmDiziMode.sub':
      'Show a single Movies & Series card, separate Movies/Series cards, or both',
  'homeSettings.filmDiziMode.modern.title': 'Modern (Movies & Series)',
  'homeSettings.filmDiziMode.modern.sub':
      'A single «Movies & Series» card on the home screen; movies and series live inside it as tabs',
  'homeSettings.filmDiziMode.classic.title': 'Classic (Separate Movies/Series)',
  'homeSettings.filmDiziMode.classic.sub':
      'Separate «Movies» and «Series» cards on the home screen',
  'homeSettings.filmDiziMode.both.title': 'Both',
  'homeSettings.filmDiziMode.both.sub':
      'Show «Movies & Series» plus separate «Movies» + «Series» cards together',
  'homeSettings.layoutStyle.title': 'Layout mode',
  'homeSettings.layoutStyle.sub':
      'Choose how the home screen looks: the full-featured card layout or the showcase layout',
  'homeSettings.layoutStyle.standard.title': 'Card Layout',
  'homeSettings.layoutStyle.standard.sub':
      'Full home screen with strips, continue watching and all cards',
  'homeSettings.layoutStyle.showcase.title': 'Showcase layout',
  'homeSettings.layoutStyle.showcase.sub':
      'Vertically scrolling poster rows + a liquid-glass dock at the bottom (Live TV · Movies & Series · EPG Mix · Mina Wrapped · Settings). Phone/tablet only.',
  'homeSettings.tvLayout.hint':
      'Choose which layout to use for the TV home screen.',
  'homeSettings.tvLayout.title': 'Home screen layout',
  'homeSettings.tvLayout.sub':
      'Card-based home or the new TV shell (left menu + panels)',
  'homeSettings.tvLayout.classic.title': 'Card Layout',
  'homeSettings.tvLayout.classic.sub':
      'Classic home with category cards and content strips',
  'homeSettings.tvLayout.shell.title': 'TV mode',
  'homeSettings.tvLayout.shell.sub':
      'Quick access to Live TV, Movies, Series and settings from the left menu',
  'tvShell.section.search': 'Search',
  'tvShell.section.live': 'Live TV',
  'tvShell.section.movies': 'Movies',
  'tvShell.section.series': 'Series',
  'tvShell.section.playlists': 'Playlists',
  'tvShell.section.continueWatching': 'Continue Watching',
  'tvShell.continueWatching.title': 'Continue Watching',
  'tvShell.continueWatching.subtitle': 'Channels, watchlist, continuing and watched titles',
  'tvShell.continueWatching.empty': 'No unfinished movies or series found.',
  'tvShell.playlists.subtitle':
      'Select a list; Live TV, movies and series show only that list\'s content.',
  'tvShell.playlists.empty':
      'No playlists loaded yet. Add one in Settings → Playlist Manager.',
  'tvShell.playlists.active': 'Active',
  'tvShell.playlists.pleaseWait': 'Please wait…',
  'tvShell.section.settings': 'Settings',
  'tvShell.rail.wrapper': 'Wrapper',
  'tvShell.rail.repeat': 'Repeat',
  'tvShell.brand': 'Mina Player',
  'tvShell.category.empty': 'No categories found',
  'tvShell.category.allFilms': 'All movies',
  'tvShell.category.allSeries': 'All series',
  'tvShell.category.favFilms': 'Favorite movies',
  'tvShell.category.favSeries': 'Favorite series',
  'tvShell.category.popular50Films': 'Top 50 movies',
  'tvShell.category.popular50Series': 'Top 50 series',
  'tvShell.hint.selectSection': 'Select a section from the left menu',
  'tvShell.live.channels': 'Channels',
  'tvShell.live.epg': 'EPG',
  'tvShell.live.noDescription': 'No programme description',
  'tvShell.live.nextProgramme': 'Up next',
  'tvShell.live.noEpg': 'No EPG data for this channel',
  'tvShell.live.pickChannel': 'Select a channel to preview',
  'tvShell.live.epgNotYet': 'EPG not available yet',
  'tvShell.touch.openMenu': 'Menu',
  'tvShell.movies.pickFilm': 'Select a movie to preview',
  'tvShell.movies.noFilms': 'No movies in this category',
  'tvShell.movies.upNext': 'Up next',
  'tvShell.movies.noPlot': 'No synopsis available',
  'tvShell.movies.play': 'Play',
  'tvShell.movies.externalPlayer': 'Open in external player',
  'tvShell.movies.addFavorite': 'Add to favorites',
  'tvShell.series.pickSeries': 'Select a series to preview',
  'tvShell.series.noSeries': 'No series in this category',
  'tvShell.series.upNext': 'Up next',
  'tvShell.sort.title': 'Sort',
  'tvShell.sort.alphabetical': 'Alphabetical',
  'tvShell.sort.rating': 'By rating (IMDb)',
  'tvShell.sort.random': 'Random',
  'tvShell.sort.addedDate': 'Date added',
  'homeSettings.lockedByShowcase': 'Disabled in showcase layout',
  'home.continue_watching': 'Continue Watching',
  'home.ai.title': 'Mina AI: Picks for You',
  'home.ai.badge.live': 'Live',
  'home.ai.badge.film': 'Film',
  'home.ai.badge.series': 'Series',
  'homeCardOrder.title': 'Home screen card order',
  'homeCardOrder.hint':
      'Move cards up or down. D-pad: ▲ ▼ or ◀ ▶ to reorder. Tap the eye icon to hide or show a card on the home screen.',
  'homeCardOrder.saved': 'Home card order saved.',
  'homeCardOrder.reset': 'Default',
  'homeCardOrder.moveUp': 'Move up',
  'homeCardOrder.moveDown': 'Move down',
  'homeCardOrder.hideCard': 'Hide this card from the home screen',
  'homeCardOrder.showCard': 'Show this card on the home screen',
  'homeCardOrder.hiddenBadge': 'Hidden',
  'homeCardOrder.card.live': 'Live TV',
  'homeCardOrder.card.films': 'Movies',
  'homeCardOrder.card.series': 'Series',
  'homeCardOrder.card.recommendedFilms': 'Movies & Series',
  'homeCardOrder.card.epgMix': 'EPG Mix',
  'homeCardOrder.card.minaAnalytics': 'Mina Watch Analytics',
  'analytics.title': 'Mina Wrapped & Watch Analytics',
  'analytics.toggle.title': 'Mina Wrapped & Watch Analytics',
  'analytics.toggle.sub':
      'Discover what you watch most on Friday evenings with beautiful charts. All data stays on your device.',
  'analytics.toggle.previewHabit': 'You mostly tune in on Friday evenings.',
  'analytics.entry.title': 'Mina Wrapped & Watch Analytics',
  'analytics.entry.sub': 'Get a beautiful summary of your viewing habits.',
  'analytics.entry.openTitle': 'Open Wrapped Recap',
  'analytics.entry.openSub':
      'View your weekly, monthly and yearly watch recap.',
  'analytics.range.week': 'Weekly',
  'analytics.range.month': 'Monthly',
  'analytics.range.year': 'Yearly',
  'analytics.kind.live': 'Live TV',
  'analytics.kind.movie': 'Movies',
  'analytics.kind.series': 'Series',
  'analytics.summary.title': 'Summary',
  'analytics.summary.body':
      'In this period you watched @live of Live TV and @vod of Movies & Series.',
  'analytics.breakdown.title': 'Viewing Breakdown',
  'analytics.topChannels.title': 'Top Channels',
  'analytics.topCategories.title': 'Favorite Genres',
  'analytics.habit.title': 'Your Habits',
  'analytics.habit.body': 'You mostly tune in on @day in the @period.',
  'analytics.dailyBars.title': 'Daily Watch Time',
  'analytics.empty.summary':
      'No data yet. Watch a few episodes and a beautiful recap will appear here.',
  'analytics.empty.channels': 'No favorite channel data yet.',
  'analytics.empty.daily': 'No watch activity in this period.',
  'analytics.share.button': 'Share My Wrapped',
  'analytics.share.subject': 'Mina IPTV — My Watch Recap',
  'analytics.share.text':
      'I spent a total of @total in front of Mina IPTV this @range! 📺 Live TV @live · Movies/Series @vod 🚀',
  'analytics.privacy.title': 'Privacy',
  'analytics.privacy.collect.title': 'Collect watch stats',
  'analytics.privacy.collect.sub':
      'Everything stays on your device; nothing is uploaded to any server.',
  'analytics.privacy.clear': 'Reset data',
  'analytics.privacy.clearConfirm.title': 'Reset all stats?',
  'analytics.privacy.clearConfirm.body':
      'All your Mina Wrapped history will be permanently deleted. This cannot be undone.',
  'analytics.weekday.mon': 'Monday',
  'analytics.weekday.tue': 'Tuesday',
  'analytics.weekday.wed': 'Wednesday',
  'analytics.weekday.thu': 'Thursday',
  'analytics.weekday.fri': 'Friday',
  'analytics.weekday.sat': 'Saturday',
  'analytics.weekday.sun': 'Sunday',
  'analytics.period.morning': 'morning',
  'analytics.period.afternoon': 'afternoon',
  'analytics.period.evening': 'evening',
  'analytics.period.night': 'night',
  'analytics.wrapped.tag': 'MINA WRAPPED',
  'analytics.wrapped.youAre': 'YOU ARE A',
  'analytics.wrapped.highlight': '@range total',
  'analytics.persona.newcomer.title': 'Just Getting Started',
  'analytics.persona.newcomer.tagline':
      'Mina Wrapped can’t wait to get to know you. Watch a few things and your personal profile will show up right here!',
  'analytics.persona.cinephile.title': 'Cinephile',
  'analytics.persona.cinephile.tagline':
      'You poured a whole @hours into movies, mostly locking onto the screen in the @period. A true film lover!',
  'analytics.persona.binger.title': 'Series Binger',
  'analytics.persona.binger.tagline':
      'Episode after episode — a @hours marathon! The @period is your binge time.',
  'analytics.persona.liveWire.title': 'Live TV Pro',
  'analytics.persona.liveWire.tagline':
      'You keep your finger on the live pulse: @hours, mostly during the @period.',
  'analytics.persona.nightOwl.title': 'Night Owl',
  'analytics.persona.nightOwl.tagline':
      'You watched a full @hours in the quiet of the night. A true night owl!',
  'analytics.persona.explorer.title': 'Explorer',
  'analytics.persona.explorer.tagline':
      'Live, movies, series… you taste it all. @hours of boundless exploring!',
  'analytics.insight.period':
      'About @pct% of your watching happened in the @period.',
  'analytics.insight.topChannel': 'Your most loyal channel: @channel (@hours).',
  'analytics.insight.peakDay': 'Your most active day: @day.',
  'analytics.insight.topCategory': 'Your favorite genre: @category.',
  'analytics.timeline.title': 'Watch Timeline',
  'analytics.timeline.empty':
      'No watch history yet. It will appear here as you watch.',
  'analytics.time.justNow': 'just now',
  'analytics.time.minsAgo': '@n min ago',
  'analytics.time.hoursAgo': '@n h ago',
  'analytics.time.yesterday': 'yesterday',
  'analytics.time.daysAgo': '@n days ago',
  'analytics.time.weeksAgo': '@n weeks ago',
  'settings.tile.channelListEdit': 'Live channel layout',
  'settings.tile.channelListEdit.sub':
      'Live TV only: pick a category and reorder or remove channels',
  'settings.parental.title': 'Parental controls',
  'settings.parental.createIntro':
      'Choose a 4–6 digit PIN. Category hiding opens with this PIN.',
  'settings.parental.verifyIntro': 'Enter your PIN to open category settings.',
  'settings.parental.pinNew': 'New PIN',
  'settings.parental.pinConfirm': 'Confirm PIN',
  'settings.parental.pinEnter': 'PIN',
  'settings.parental.savePin': 'Save PIN',
  'settings.parental.unlock': 'Continue',
  'settings.parental.pinInvalid': 'PIN must be 4–6 digits.',
  'settings.parental.pinMismatch': 'PINs do not match.',
  'settings.parental.pinWrong': 'Incorrect PIN.',
  'settings.parental.pinSaved': 'PIN saved.',
  'settings.parental.next': 'Next',
  'settings.parental.title.create': 'Create PIN',
  'settings.parental.title.confirm': 'Confirm PIN',
  'settings.parental.title.enter': 'Enter PIN',
  'settings.parental.confirmIntro': 'Enter the same PIN once more.',
  'settings.parental.reset': 'Reset PIN',
  'settings.parental.resetTitle': 'Reset PIN',
  'settings.parental.resetConfirm':
      'Your existing PIN will be cleared and you will have to create a new one. Continue?',
  'settings.parental.recoveryTitle': 'Set a recovery word',
  'settings.parental.recoveryIntro':
      'If you forget your PIN, you will enter this secret word to reset it. Do not share it with anyone.',
  'settings.parental.recoveryLabel': 'Secret recovery word',
  'settings.parental.recoveryHint': 'A secret word you will remember',
  'settings.parental.recoveryTooShort':
      'Recovery word must be at least 3 characters.',
  'settings.parental.recoveryWrong':
      'Incorrect recovery word. PIN was not reset.',
  'settings.parental.recoveryPromptTitle': 'Enter recovery word',
  'settings.parental.recoveryPromptBody':
      'Enter the secret recovery word you set to reset your PIN.',
  'settings.tile.sleepTimer': 'Sleep timer',
  'settings.tile.clearAll': 'Erase all settings',
  'settings.tile.clearAll.sub': 'Reset playlist, cache, and preferences',
  'settings.tile.theme': 'Theme',
  'settings.tile.subtitleOptions': 'Subtitle options',
  'settings.tile.subtitleOptions.sub': '@pt pt',
  'settings.tile.subtitleOptions.summary': '@pt pt · @color · @font',
  'settings.tile.vodInfoEngine': 'VOD Info Engine',
  'settings.tile.vodInfoEngine.hint':
      'Choose the source for movie and series information',
  'settings.tile.vodInfoEngine.auto': 'Auto',
  'settings.tile.vodInfoEngine.xtreamOnly': 'Xtream Info Only',
  'settings.tile.vodInfoEngine.tmdbOmdbOnly': 'TMDB/OMDB Info Only',
  'settings.subtitle.title': 'Subtitle options',
  'settings.subtitle.sectionAppearance': 'Appearance',
  'settings.subtitle.sectionOpenSubtitles': 'OpenSubtitles account',
  'settings.subtitle.size': 'Size',
  'settings.subtitle.color': 'Color',
  'settings.subtitle.font': 'Font',
  'settings.subtitle.fontHint': 'Font used for on-screen subtitles.',
  'settings.subtitle.outline': 'Outline',
  'settings.subtitle.outlineHint':
      'Black edge for readability on busy backgrounds.',
  'settings.subtitle.previewSample': 'Subtitle preview',
  'settings.subtitle.color.white': 'White',
  'settings.subtitle.color.yellow': 'Yellow',
  'settings.subtitle.color.cyan': 'Cyan',
  'settings.subtitle.color.green': 'Green',
  'settings.subtitle.color.orange': 'Orange',
  'settings.subtitle.color.pink': 'Pink',
  'settings.opensubtitles.title': 'OpenSubtitles',
  'settings.opensubtitles.hint':
      'Sign in with your opensubtitles.com account. Download support coming soon.',
  'settings.opensubtitles.username': 'Username',
  'settings.opensubtitles.password': 'Password',
  'settings.opensubtitles.login': 'Sign in',
  'settings.opensubtitles.logout': 'Sign out',
  'settings.opensubtitles.loggedIn': 'Signed in as @user',
  'settings.opensubtitles.loginSuccess': 'Signed in successfully',
  'settings.opensubtitles.logoutDone': 'Signed out',
  'settings.opensubtitles.noApiKeyBanner':
      'OpenSubtitles API key is not configured. Developer: ApiConstants.openSubtitlesApiKey',
  'settings.opensubtitles.errorNoApiKey': 'OpenSubtitles API key is missing.',
  'settings.opensubtitles.errorCredentials':
      'Username and password are required.',
  'settings.opensubtitles.errorLogin':
      'Sign-in failed. Check your credentials.',
  'settings.tile.layout': 'Layout',
  'settings.tile.liveBuffer': 'Low latency (buffer)',
  'settings.tile.liveBuffer.sub': '@n seconds',
  'settings.tile.liveBuffer.auto': 'Auto',
  'settings.tile.volumeBoost': 'Volume booster',
  'settings.tile.volumeBoost.off': 'Off — system volume (max 100%)',
  'settings.tile.volumeBoost.sub':
      'Cap @n% — edge swipe or volume keys can raise audio up to this level',
  'settings.dialog.volumeBoost.title': 'Volume booster',
  'settings.dialog.volumeBoost.hint':
      'When the system volume reaches 100%, the player applies extra gain. Works on the MediaKit engine; BetterPlayer is limited to 100%.',
  'settings.dialog.volumeBoost.off': 'Off (max 100%)',
  'settings.dialog.volumeBoost.option': 'Max @n%',
  'settings.tile.userAgent': 'User Agent',
  'settings.tile.userAgent.subCustom': 'Custom: @v',
  'settings.tile.userAgent.subCustomEmpty': 'Custom (empty — using default)',
  'settings.dialog.userAgent.title': 'User Agent',
  'settings.dialog.userAgent.hint':
      'The IPTV player sends this User-Agent header. Stalker / Ministra portals may require a specific value.',
  'settings.dialog.userAgent.custom': 'Custom user agent',
  'settings.dialog.userAgent.customLabel': 'Custom UA',
  'settings.dialog.userAgent.customHint': 'e.g. VLC/3.0.20 LibVLC/3.0.20',
  'settings.tile.epg': 'EPG',
  'settings.tile.epg.sub': 'Guide, source and matching',
  'settings.epg.title': 'EPG settings',
  'settings.epg.enabled.title': 'EPG enabled',
  'settings.epg.enabled.sub.on':
      'Programme guide refreshes; live "now" badges are shown.',
  'settings.epg.enabled.sub.off':
      'EPG turned off. No downloads, live programme info hidden.',
  'settings.epg.disabledHint': 'EPG OFF',
  'settings.epg.status': 'TV guide status',
  'settings.epg.status.sub.loaded': '@channels channels · @programs programmes',
  'settings.epg.status.sub.empty': 'Guide not loaded',
  'settings.epg.status.sub.loading': 'Loading…',
  'settings.epg.refreshNow': 'Refresh guide',
  'settings.epg.refreshFrequency': 'Guide refresh interval',
  'settings.epg.refreshFrequency.sub': '@n days',
  'settings.epg.refreshFrequency.never': 'Auto refresh off (load once only)',
  'settings.epg.timeFormat': 'Time format',
  'settings.epg.timeFormat24': '24-hour',
  'settings.epg.timeFormat12': '12-hour (AM/PM)',
  'settings.epg.offset': 'EPG time offset',
  'settings.epg.offset.zero': 'No offset (UTC±0)',
  'settings.epg.offset.pick': 'Choose offset',
  'settings.epg.manageSources': 'Manage EPG sources',
  'settings.epg.manageSources.sub': 'XMLTV URL and channel matching',
  // EPG source preference (Xtream / GitHub fallback) tile + dialog
  'settings.epg.sourcePref.title': 'EPG Source',
  'settings.epg.sourcePref.body':
      'Where should the live TV guide come from? When the Xtream server returns no/empty EPG, the GitHub community fallback can step in.',
  'settings.epg.sourcePref.badge.auto': 'AUTO',
  'settings.epg.sourcePref.badge.xtream': 'XTREAM',
  'settings.epg.sourcePref.badge.github': 'GITHUB',
  'settings.epg.sourcePref.sub.xtreamOk': 'EPG loaded from your Xtream server.',
  'settings.epg.sourcePref.sub.xtreamOnlyFail':
      'Xtream server returned no EPG. Try switching to GitHub fallback.',
  'settings.epg.sourcePref.sub.githubOk': 'GitHub fallback EPG active.',
  'settings.epg.sourcePref.sub.githubLoading': 'Loading GitHub fallback…',
  'settings.epg.sourcePref.sub.githubFallback':
      'Xtream gave no EPG; GitHub fallback took over.',
  'settings.epg.sourcePref.sub.both':
      'Xtream + GitHub fallback active together.',
  'settings.epg.sourcePref.sub.autoLoading': 'Loading EPG…',
  'settings.epg.sourcePref.optAuto.title': 'Automatic (recommended)',
  'settings.epg.sourcePref.optAuto.desc':
      'Xtream server first, GitHub fallback fills the channels with no match.',
  'settings.epg.sourcePref.optXtream.title': 'Xtream server only',
  'settings.epg.sourcePref.optXtream.desc':
      'No GitHub fallback. If the server has no EPG, channels stay empty.',
  'settings.epg.sourcePref.optGithub.title': 'GitHub fallback only',
  'settings.epg.sourcePref.optGithub.desc':
      'No Xtream EPG request; directly uses iptv-org / globetvapp based community guide.',
  'settings.epg.source.title': 'Edit EPG source',
  'settings.epg.source.urlLabel': 'XMLTV URL',
  'settings.epg.source.urlHint':
      'Pick categories or channels for this EPG. Leave empty for all channels.',
  'settings.epg.source.tab.categories': 'Categories',
  'settings.epg.source.tab.channels': 'Channels',
  'settings.epg.source.tab.matched': 'Matched (@n)',
  'settings.epg.source.tab.settings': 'Settings',
  'settings.epg.source.search': 'Search…',
  'settings.epg.source.pickXml': 'Pick XMLTV channel',
  'settings.epg.source.unmatched': 'No match',
  'settings.epg.source.refreshEpg': 'Refresh EPG data',
  'settings.tile.epgCache': 'EPG data refresh',
  'settings.tile.epgCache.sub': '@n-day cache',
  'settings.dialog.epgCacheTitle': 'EPG cache refresh interval',
  'settings.dialog.epgCacheHint':
      'Full EPG is stored locally and is not downloaded again until this interval elapses.',
  'settings.dialog.epgCacheSlider': '@n days',
  'settings.dialog.epgCacheNever':
      'Off — guide loads once and never auto-refreshes',
  'settings.tile.adaptiveQuality': 'HLS quality ceiling',
  'settings.dialog.adaptiveQualityTitle': 'Multi-quality streams (HLS)',
  'settings.adaptiveQuality.optionAuto':
      'Automatic — based on screen size (recommended)',
  'settings.adaptiveQuality.option720': 'Up to 720p',
  'settings.adaptiveQuality.option1080': 'Up to 1080p',
  'settings.adaptiveQuality.option4k': 'Up to 4K (2160p)',
  'settings.adaptiveQuality.shortAuto': 'Automatic (device)',
  'settings.adaptiveQuality.short720': 'Up to 720p',
  'settings.adaptiveQuality.short1080': 'Up to 1080p',
  'settings.adaptiveQuality.short4k': 'Up to 4K',
  'settings.tile.catchUpUrl': 'EPG catch-up URL template',
  'settings.dialog.catchUpTitle': 'Catch-up URL template',
  'settings.catchUp.optionOff': 'Off',
  'settings.catchUp.optionXtreamPath': 'Classic timeshift path (most Xtream)',
  'settings.catchUp.optionTimeshiftPhp': 'timeshift.php query',
  'settings.catchUp.optionCustom': 'Custom template',
  'settings.catchUp.shortOff': 'Off',
  'settings.catchUp.shortXtreamPath': '/timeshift/…',
  'settings.catchUp.shortPhp': 'timeshift.php',
  'settings.catchUp.shortCustom': 'Custom',
  'settings.catchUp.customLabel': 'Full URL line (placeholders in braces)',
  'settings.catchUp.customHint': '{server}/timeshift/{username}/…',
  'settings.catchUp.help':
      'Placeholders: {server} {username} {password} {stream_id} {duration} {start_utc_ymd_hms} {start_local_ymd_hms} {start_unix} {extension}. Match your provider.',
  'settings.tile.launchBoot': 'Launch when device starts',
  'settings.tile.bgPlayback': 'Background playback',
  'settings.tile.alarm': 'Alarm',
  'settings.tile.alarm.sub': 'Sleep timer and alarm',
  'settings.tile.miniPlayerHome': 'Mini player (PiP)',
  'settings.tile.miniPlayerHome.subTv': 'Phone layout only',
  'settings.tile.miniPlayerHome.hintTv':
      'This option is for Android phone layout.',
  'settings.tile.miniPlayerHome.subOn':
      'On — return home for a draggable mini window (Better/Exo).',
  'settings.tile.miniPlayerHome.subOff':
      'Off — no auto PiP; use the player OSD button for manual PiP.',
  'settings.tile.miniPlayerHome.subMk':
      'Auto PiP is not available with MediaKit; use the default player.',
  'settings.tile.reduceBlur': 'Reduce blur (speed)',
  'settings.tile.ignoreSsl': 'Ignore SSL/TLS verification',
  'settings.tile.ignoreSsl.on':
      'On — streams with invalid/self-signed certificates are allowed (reduces security)',
  'settings.tile.ignoreSsl.off':
      'Off — only HTTPS streams with valid certificates are allowed. Turn on for panels that throw certificate errors.',
  'settings.tile.landscapeStatusBar': 'Clock & battery in landscape',
  'settings.tile.landscapeStatusBar.on':
      'On · Clock and battery percentage in the top-right while watching in landscape',
  'settings.tile.landscapeStatusBar.off':
      'Off · No clock/battery in landscape fullscreen',
  'settings.tile.streamPreview': 'Stream preview',
  'settings.tile.streamPreview.on':
      'Silent preview in list details (~after 1.8 s)',
  'settings.tile.streamPreview.off':
      'Off — no preview in live / movie / series lists',
  'settings.tile.streamPreview.blockedLowEnd':
      'On — low-end device mode disables preview',
  'settings.tile.streamPreview.tvLocked':
      'On TV you can turn this on or off in Settings',
  'settings.tile.defaultPlayer': 'Default Player',
  'settings.tile.filmVodPlayer': 'Movies / series player',
  'settings.tile.filmVodPlayer.subExo':
      'ExoPlayer (Better) — default; switches to MediaKit on decoder failure',
  'settings.tile.filmVodPlayer.subMediaKit':
      'MediaKit (mpv) — play directly with mpv',
  'settings.tile.useMediaKit': 'Use MediaKit (mpv)',
  'settings.tile.useMediaKit.subOn':
      'On — movies & series use MediaKit; live TV always starts in Better Player',
  'settings.tile.useMediaKit.subOff':
      'Off — movies, series, and live use Better/Exo; MediaKit only as backup',
  'settings.tile.playerEngine': 'Player engine preferences',
  'settings.tile.playerEngine.sub': 'Live: @live · Movies/Series: @vod',
  'settings.tile.smartPlayerSelection': 'Smart player selection',
  'settings.tile.smartPlayerSelection.subOn':
      'On — channels that open with MediaKit are remembered next time',
  'settings.tile.smartPlayerSelection.subOff':
      'Off — always start with your selected engine (Better fallback still runs)',
  'settings.dialog.smartPlayerSelection.title': 'Smart player selection',
  'settings.dialog.smartPlayerSelection.body':
      'When Better is selected, streams are always tried as Better → HLS/TS ↔ TS/HLS → MediaKit if needed. Turning this setting on remembers channels that succeeded with MediaKit and opens them directly with MediaKit next time. When off, playback always starts with your selected engine and the channel engine is not remembered.',
  'settings.dialog.smartPlayerSelection.switchOn': 'Channel memory on',
  'settings.dialog.smartPlayerSelection.switchOff': 'Channel memory off',
  'settings.playerEngine.title': 'Player engine preferences',
  'settings.playerEngine.hint':
      'Choose the primary engine for each content type (Better or MediaKit). With Better selected, failed streams still try HLS↔TS and then MediaKit. Smart player selection only remembers successful MediaKit channels.',
  'settings.playerEngine.liveTitle': 'Live stream engine',
  'settings.playerEngine.vodTitle': 'Movies / series playback',
  'settings.tile.tvOsdAutoHide': 'OSD hide delay',
  'settings.tile.tvOsdAutoHide.sub': '@n seconds',
  'settings.dialog.osdHideTitle': 'OSD hide delay',
  'settings.dialog.osdHideBody':
      'In portrait and with TV/tablet remote controls, the player OSD and the channel bar hide after this delay.',
  'settings.dialog.osdHideSeconds': '@n seconds',
  'settings.tile.mediaKitHwdec': 'Hardware acceleration (MediaKit)',
  'settings.tile.mediaKitHwdec.subBalanced':
      'Balanced — mediacodec-copy (recommended)',
  'settings.tile.mediaKitHwdec.subLowPower':
      'Low power / older TV box — mediacodec',
  'settings.tile.videoDecoder': 'Video decoder (Android)',
  'settings.tile.streamFormat': 'Stream format',
  'settings.streamFormat.hlsShort': 'HLS (.m3u8) · stable',
  'settings.streamFormat.tsShort': 'MPEG-TS (.ts) · fast',
  'settings.streamFormat.autoShort': 'Automatic · @fmt',
  'settings.streamFormat.autoTitle': 'Automatic (recommended)',
  'settings.streamFormat.autoDesc':
      'Chooses the format automatically from the playlist URL hint (e.g. output=ts → MPEG-TS). The most reliable option for most users.',
  'settings.dialog.streamFormatTitle': 'Live stream format',
  'settings.streamFormat.hlsTitle': 'HLS (.m3u8) — Stable',
  'settings.streamFormat.hlsDesc':
      'More stable playback and a multi-quality (HD/FHD) menu. Recommended for most panels.',
  'settings.streamFormat.tsTitle': 'MPEG-TS (.ts) — Fast',
  'settings.streamFormat.tsDesc':
      'Faster start and lower latency. The player automatically falls back to HLS on incompatible streams.',
  'settings.tile.about': 'About',
  'settings.tile.about.loading': 'Loading version…',
  'settings.tile.about.sub': 'Mina IPTV Player @v',
  'settings.tile.help': 'Our Telegram',
  'settings.tile.help.sub': 'Official Telegram channel',
  'settings.tile.reportIssue': 'Report an issue',
  'settings.tile.reportIssue.sub': 'Send us an email',
  'settings.tile.adminMessage': 'Message the admin',
  'settings.tile.adminMessage.sub': 'Chat with the admin inside the app',
  'settings.tile.contactUs': 'Contact Us',
  'settings.tile.contactUs.sub': 'Our Telegram channel and issue reporting',
  'settings.tile.setupWizard': 'Start Setup Wizard',
  'settings.tile.setupWizard.sub': 'Run the initial setup steps again',
  'settings.tile.faq': 'Frequently Asked Questions',
  'settings.tile.faq.sub': 'Guide for features and playback settings',
  'faq.title': 'Frequently Asked Questions',
  'faq.searchHint': 'Search questions…',
  'faq.empty': 'No questions match your search.',
  'faq.entry.tsMode.q': 'When should I switch to MPEG-TS mode?',
  'faq.entry.tsMode.a':
      'MPEG-TS streams the channel as a single continuous flow; it starts fast and is compatible with many TV boxes. Try MPEG-TS if channels open slowly, you see hardware decoder errors, or playback never starts. On low-end devices and TV boxes the app selects this mode automatically.',
  'faq.entry.hlsMode.q': 'When should I switch to HLS (m3u8) mode?',
  'faq.entry.hlsMode.a':
      'HLS splits the stream into small segments and offers multiple qualities (HD/FHD) on most panels. If your internet is unstable, HLS freezes less than MPEG-TS because it can drop quality automatically and buffer segments. Use HLS if you want a multi-quality menu and more stable playback.',
  'faq.entry.autoTs.q':
      'Why did the app switch to MPEG-TS automatically on my device?',
  'faq.entry.autoTs.a':
      'When your device is detected as a TV box or low-end hardware, the live stream format is set to MPEG-TS once automatically, because HLS\'s segment/quality overhead can cause stuttering on these devices. You can switch back to HLS from Settings > Playback; your preference is preserved.',
  'faq.entry.buffer.q':
      'Why should I adjust the buffer (low latency) duration?',
  'faq.entry.buffer.a':
      'The buffer is how much stream the player downloads ahead of time. A low value (1-2 s) speeds up channel switching but increases the freeze risk on unstable internet. A high value (5-10 s) reduces freezing but makes startup and zapping a bit slower. Pick low if your internet is stable, higher if you freeze often.',
  'faq.entry.freezing.q':
      'One playlist keeps freezing while another works fine. Why?',
  'faq.entry.freezing.a':
      'The most common cause of freezing is the provider\'s server: insufficient bandwidth, a distant/slow server, long segments, or a connection limit. If a different playlist works fine on the same device and internet, the problem is most likely in the freezing playlist\'s infrastructure. The app helps by automatically increasing the buffer on long-segment/non-ABR streams, but if the source server is weak the lasting fix is on the provider side.',
  'faq.entry.playbackStops.q': 'What happens if a live stream suddenly stops?',
  'faq.entry.playbackStops.a':
      'If the stream drops or stops due to a connection limit (for example when someone else opens the same account), the player automatically tries to reconnect as long as you did not pause it. If needed, an HLS↔MPEG-TS format swap and a different playback engine are also tried.',
  'faq.entry.engine.q':
      'What is the difference between the Better Player and MediaKit engines?',
  'faq.entry.engine.a':
      'Better Player (ExoPlayer) is hardware-accelerated and efficient on most devices. MediaKit (libmpv) is more flexible with difficult codecs and problematic streams. If Better Player cannot open a stream, the app automatically falls back to MediaKit. You can also choose your preferred engine in Settings.',
  'faq.entry.softwareDecoder.q':
      'When should I use the software video decoder?',
  'faq.entry.softwareDecoder.a':
      'The hardware decoder can produce a green/purple screen, stuttering, or errors with certain codecs on some devices. If you see visual artifacts, the software decoder is more compatible, but it taxes the CPU more and may stutter on low-end devices. If there is no issue, keep the hardware (default) mode.',
  'faq.entry.lowEndMode.q': 'What does low-end mode do?',
  'faq.entry.lowEndMode.a':
      'It turns off blur, shadows and heavy animations and lowers image cache limits so the UI runs more smoothly on weak devices. Stream preview is not affected — you can toggle that separately in Settings.',
  'faq.entry.tvLite.q': 'What is TV Lite (simplified TV interface)?',
  'faq.entry.tvLite.a':
      'TV Lite is now part of Low-end mode. Turning on Low-end under Settings › Other tools or during setup applies flat graphics (blur/shadows off).',
  'faq.entry.userAgent.q': 'When should I change the User Agent setting?',
  'faq.entry.userAgent.a':
      'Some IPTV panels only serve streams with a specific User-Agent header. Change this setting if streams will not open or your panel provider requires a custom User-Agent. If unsure, use the default.',
  'faq.entry.cardSize.q': 'How do I change the home screen card size?',
  'faq.entry.cardSize.a':
      'In Settings > Home you can scale the cards between 80% and 120% with the card size slider. The default is 110%. Larger cards are easier to read from a distance; smaller cards fit more content on screen.',
  'faq.entry.epg.q': 'How does the program guide (EPG) work?',
  'faq.entry.epg.a':
      'The EPG shows each channel\'s schedule (now/next program). The data comes from your panel or an XMLTV source you add. If the guide looks empty, check the source and refresh frequency under Settings > EPG.',
  'faq.entry.ignoreSsl.q': 'What does the "Ignore SSL certificate" option do?',
  'faq.entry.ignoreSsl.a':
      'Some IPTV panels use an invalid or self-signed SSL certificate, which causes a "certificate could not be verified" error. When this option is on, the app accepts the certificate without verifying it and can download streams/posters/EPG from such panels.',
  'faq.entry.multiPlaylist.q': 'Can I add more than one playlist?',
  'faq.entry.multiPlaylist.a':
      'Yes. You can save multiple playlists and switch between them from the "Playlists" bar at the top. Only the active playlist is loaded into memory at a time, which preserves performance.',
  'faq.entry.backup.q':
      'Are my settings backed up? What happens on a new device?',
  'faq.entry.backup.a':
      'Your settings are stored in the cloud via Google Backup and restored on a new device. However, device-specific decisions (such as the MPEG-TS enforcement for TV boxes or low-end mode) are re-evaluated on the new device based on its hardware; the old device\'s values do not override the new one.',
  'faq.entry.catchUp.q': 'How do I watch past programs (Replay / Catch-up)?',
  'faq.entry.catchUp.a':
      'From the "Replay & EPG Mix" section on the home screen you can rewind and watch past programs, if your provider supports it. Catch-up depends on the panel\'s catch-up/timeshift support; if no replay icon appears next to a program, no archive is offered for that stream.',
  'faq.entry.resumeAutoplay.q':
      'Do movies/series resume where I left off? Does the next episode autoplay?',
  'faq.entry.resumeAutoplay.a':
      'Yes. When you reopen a movie or episode, you are asked to resume from where you left off or start over. When an episode ends, the next one starts automatically after a few-second countdown; you can cancel the countdown if you prefer.',
  'faq.entry.smartCutter.q': 'What is "Skip Intro" (Smart Stream Cutter)?',
  'faq.entry.smartCutter.a':
      'It learns how far you manually skip the intro in a series\' early episodes and then shows a "Skip Intro" button at the same point in later episodes. You can turn it on or off under Playback Settings.',
  'faq.entry.subtitles.q':
      'How do I enable and adjust subtitles? What is OpenSubtitles?',
  'faq.entry.subtitles.a':
      'In the player you can select embedded or external subtitles from the subtitle button. Subtitle Options lets you set size, color, font, and outline. If you log in with an OpenSubtitles account, you can search and download subtitles online.',
  'faq.entry.audioTrack.q':
      'Can I change the audio language (audio track) of a stream?',
  'faq.entry.audioTrack.a':
      'If a stream has multiple audio tracks (e.g. original + dub), you can pick any from the audio track menu in the player. For streams with a single audio track, the menu shows no options.',
  'faq.entry.volumeBoost.q': 'Can I raise the volume above 100%?',
  'faq.entry.volumeBoost.a':
      'Yes, with Volume Boost extra gain is applied once system volume reaches 100% (you set the upper limit in settings). This works best with the MediaKit engine; boosting too much may distort the audio.',
  'faq.entry.equalizer.q': 'Is there an equalizer?',
  'faq.entry.equalizer.a':
      'Yes, there is a multi-band equalizer with presets applied in real time during playback. Open it from Playback Settings. The equalizer is effective on the MediaKit engine.',
  'faq.entry.externalPlayer.q':
      'Can I open streams in another player like VLC / MX Player?',
  'faq.entry.externalPlayer.a':
      'Yes. If you enable External Player, content opens in your chosen app instead of the built-in player. Built-in features (OSD, favorites, resume) do not work in an external player.',
  'faq.entry.cast.q': 'Can I cast the stream to a TV / another device?',
  'faq.entry.cast.a':
      'With the cast icon in the player you can send the stream address to cast apps like BubbleUPnP or VLC. This forwards the stream URL to the external device and is intended for DRM-free IPTV streams.',
  'faq.entry.pipBackground.q':
      'How do background playback and Picture-in-Picture (PiP) work?',
  'faq.entry.pipBackground.a':
      'With background playback on, audio/video continues even if you leave the app. With PiP on, the video keeps playing in a small window when you return from the player to home (Android, on supported devices). Both are under Playback Settings.',
  'faq.entry.playbackSpeed.q': 'Can I change the playback speed?',
  'faq.entry.playbackSpeed.a':
      'For movies and series you can set playback speed between 0.5× and 2×. Speed change does not apply to live streams.',
  'faq.entry.zoomFit.q':
      'The video does not fit the screen / there are black bars. What can I do?',
  'faq.entry.zoomFit.a':
      'Use the fit option in the player to cycle between "contain / fill / cover" modes. On phones and tablets you can also pinch to zoom and pan the video.',
  'faq.entry.channelNumber.q':
      'Can I type a channel number on the remote to jump directly?',
  'faq.entry.channelNumber.a':
      'Yes. While watching live TV, typing a channel number on the remote jumps directly to that channel. The number entry appears briefly on screen and is confirmed.',
  'faq.entry.favorites.q': 'How do I add content to favorites?',
  'faq.entry.favorites.a':
      'You can add channels, movies, and series to favorites with the heart icon in the player or the favorite button in lists. Your favorites are collected under the "Favorites" tab in the Live TV and Films/Series sections.',
  'faq.entry.continueWatching.q':
      'How does the "Continue Watching" strip work?',
  'faq.entry.continueWatching.a':
      'Movies and series you left unfinished appear with a progress bar in the "Continue Watching" strip on the home screen, and you resume with one tap. You can hide the strip from Home Settings.',
  'faq.entry.aiRecommend.q':
      'What are Mina AI recommendations, and is my data safe?',
  'faq.entry.aiRecommend.a':
      'Personalized recommendations are generated on your device based on your watch history; this processing happens on-device. You can turn the strip off in Home Settings and clear history-based recommendations from the reset menu.',
  'faq.entry.globalSearch.q': 'How do I search all content at once?',
  'faq.entry.globalSearch.a':
      'The search on the home screen lets you search live channels, movies, and series at the same time. Results are grouped by type, and your recent searches are remembered.',
  'faq.entry.downloads.q': 'Can I download movies and series to watch offline?',
  'faq.entry.downloads.a':
      'With the download button on the detail page you can queue movies/episodes for offline viewing. Downloads are collected in the "Downloads" section. Live streams cannot be downloaded; downloading applies to VOD content the provider allows.',
  'faq.entry.homeLayout.q': 'Can I reorder and hide the home screen cards?',
  'faq.entry.homeLayout.a':
      'Yes. In Home Settings you can change the card order, hide cards you do not want, and switch between the default layout and the showcase layout.',
  'faq.entry.filmDiziMode.q':
      'Should "Films & Series" be one card or separate Films/Series?',
  'faq.entry.filmDiziMode.a':
      'In Home Settings you can choose the unified "Films & Series" card, separate "Films" and "Series" cards (classic), or show both together. The choice is purely visual; the content is the same.',
  'faq.entry.theme.q': 'Can I change the app theme / appearance?',
  'faq.entry.theme.a':
      'You can pick different themes (Glass Gray, AMOLED Black, etc.) in Settings. On AMOLED screens the black theme saves battery; on weak devices, reduced blur can give a smoother look.',
  'faq.entry.analytics.q': 'What is Mina Analytics / Wrapped?',
  'faq.entry.analytics.a':
      'It shows a summary of your viewing habits (total time, most-watched channels, etc.). The data is kept on your device; if you prefer, you can turn off analytics collection in the related setting.',
  'faq.entry.profiles.q': 'Can I create multiple profiles?',
  'faq.entry.profiles.a':
      'Yes, you can create profiles with separate preferences and history for each user. You can lock profiles with a PIN, and if you forget the PIN, unlock it with the recovery word you set.',
  'faq.entry.parental.q': 'How do I set up parental control (PIN)?',
  'faq.entry.parental.a':
      'In Parental Control you set a 4-6 digit PIN and a recovery word. The PIN protects sensitive settings such as the adult content filter and category hiding. If you forget the PIN, it is reset with the recovery word.',
  'faq.entry.sleepTimer.q': 'Is there a sleep timer (stop after a set time)?',
  'faq.entry.sleepTimer.a':
      'Yes, if you set the sleep timer under "Other Tools", playback stops at the end of the time you choose. Handy so the stream does not stay on while you sleep.',
  'faq.entry.channelEdit.q': 'Can I edit and hide channels and categories?',
  'faq.entry.channelEdit.a':
      'Yes. With show/hide categories you can remove unwanted categories from lists; with Live Channel Layout you can reorder channels within a category and hide them individually. This does not delete content on the provider; it only arranges your view.',
  'faq.entry.epgSettings.q':
      'The program guide (EPG) times are wrong / empty. How do I fix it?',
  'faq.entry.epgSettings.a':
      'In EPG Settings you can correct shifted times with the timezone offset, choose 12/24-hour format, set the refresh frequency, and add your own XMLTV source. For Xtream accounts you can switch between the API and a fallback source.',
  'faq.entry.speedTest.q': 'Can I run an internet speed test inside the app?',
  'faq.entry.speedTest.a':
      'Yes, the Speed Test screen measures download/upload speed and latency (ping). If you experience freezing, it helps to see whether your connection is sufficient for streaming.',
  'faq.entry.cloudSync.q': 'Can I sync my settings and playlists to the cloud?',
  'faq.entry.cloudSync.a':
      'By signing in with your Google account you can back up your settings and playlists to the cloud and restore them on another device. The last backup date is shown on screen; you can push (upload) and pull (download) manually.',
  'faq.entry.demoPlaylist.q': 'I have no IPTV subscription; can I try the app?',
  'faq.entry.demoPlaylist.a':
      'Yes, you can try the app with the demo playlist on the setup screen without a real subscription. For your own content, add a playlist via M3U URL, local file, or Xtream credentials.',
  'faq.entry.chatSupport.q': 'How do chat and support work?',
  'faq.entry.chatSupport.a':
      'By signing in with Google you can join the community chat in language rooms and send a private support message to the admin. You can also report issues with stream status (flowing/freezing) tags.',
  'faq.entry.language.q': 'Can I change the app language?',
  'faq.entry.language.a':
      'Yes, you can change the interface language from the language selection in Settings. Many languages are supported; movie/series overviews and episode info are also translated to your device language when possible.',
  'faq.entry.showcaseMode.q':
      'What is the Showcase layout and how do I enable it?',
  'faq.entry.showcaseMode.a':
      'Showcase is a clean, modern home layout for phones and tablets. Continue watching, mixed live TV, latest films and mixed content are arranged in a vertical feed with liquid glass frames, and a bottom navigation bar with an iOS-style droplet effect. You can choose it from Settings → Home layout or in the setup wizard. It is not used on TV.',
  'faq.entry.latestAdded.q':
      'Where can I see the latest added films and series?',
  'faq.entry.latestAdded.a':
      'In the Film & Series modern section, the films tab has a «Last 50 Added Films» category and the series tab has a «Last 50 Added Series» category. This list also appears on the Showcase home screen. As with every category, you can open the full list with «See All».',
  'faq.entry.imageSubtitles.q':
      'I press the subtitle button but no options appear. Why?',
  'faq.entry.imageSubtitles.a':
      'Some VOD streams have image-based subtitles (PGS/HDMV, VobSub, DVB). The default player (Better/ExoPlayer) cannot render these and does not list them. In that case the subtitle menu offers to switch to the MediaKit (mpv) player; once you confirm, the subtitles are displayed. Text-based (SRT/VTT) subtitles work in both players.',
  'faq.entry.minaWrapper.q': 'What is Mina Wrapper?',
  'faq.entry.minaWrapper.a':
      'Mina Wrapper is a personal section that summarizes your watch history with AI; it presents your most-watched genres, a timeline and a personalized viewer persona with elegant visuals. You can reach it from the bottom navigation bar in Showcase layout, or from the home screen in other layouts.',
  'faq.entry.onlineCount.q': 'Can I see how many people are online in chat?',
  'faq.entry.onlineCount.a':
      'Yes, the chat section shows the live number of online users in a small badge (e.g. «55 Online»). This count reflects people currently using the app, not only those in chat. No personal identities are shared; only the total count is visible.',
  'faq.entry.os27Theme.q': 'What are the OS27 and liquid glass themes?',
  'faq.entry.os27Theme.a':
      'OS27 is a translucent theme with an iOS 27-inspired liquid glass design, blue tones and bright edges, using separate wallpapers for landscape and portrait. For TVs, the blur-free, pure black AMOLED «TV Lite» theme with a red accent is recommended. You can switch themes from Settings.',
  'contactUs.title': 'Contact Us',
  'contactUs.hint':
      'For your questions and issue reports, you can reach us through the channels below.',
  'settings.tile.privacy': 'Privacy policy',
  'settings.tile.privacy.sub': 'GitHub: furkangumrukcu07/mina_iptv_player',
  'settings.snackbar.privacy': 'Privacy policy',
  'settings.snackbar.privacyFail': 'Could not open the link.',
  'settings.snackbar.privacyManual':
      'Try opening in a browser:\nhttps://github.com/furkangumrukcu07/mina_iptv_player',
  'settings.snackbar.aboutTitle': 'About',
  'settings.snackbar.aboutBody': 'Mina IPTV Player',
  'settings.dialog.aboutFeatures': 'Features\n'
      '• Live TV, movies, and series; M3U (URL/file) and Xtream playlists\n'
      '• Android TV, phone, and tablet layouts; multi-language UI\n'
      '• Search, categories, favorites; silent stream preview in details\n'
      '• Playback: live uses Better Player (Exo); VOD defaults to MediaKit (mpv, optional)\n'
      '• XMLTV (EPG), live buffer, Android decoder options, MediaKit hardware mode\n'
      '• Glass themes, blur; auto refresh, background playback, sleep timer\n'
      '• PiP (Better, phone), recording where supported; VOD audio/subtitles (Better)\n'
      '• Play: no READ_MEDIA gallery permissions; default theme is Default\n',
  'settings.dialog.sleepTimerTitle': 'Sleep timer',
  'settings.sleepTimer.off': 'Off',
  'settings.sleepTimer.optionMinutes': '@n minutes',
  'settings.sleepTimer.remaining': 'About @min min left',
  'settings.sleepTimer.title': 'Sleep timer',
  'settings.sleepTimer.fired':
      'Time is up; playback stopped and returned to home.',
  'settings.sleepTimer.set': 'Sleep timer set for @n minutes.',
  'settings.sleepTimer.cleared': 'Sleep timer turned off.',
  'settings.bufferSecondsZero': '0 s',
  'settings.bufferSeconds': '@n s',
  'settings.decoder.software':
      'Software first — ExoPlayer (TS compatibility). MediaKit: libmpv auto-safe.',
  'settings.decoder.hardware':
      'Hardware first — ExoPlayer (default). MediaKit: libmpv auto-safe.',
  'settings.dialog.languageTitle': 'App language',
  'settings.dialog.themeTitle': 'Theme',
  'settings.dialog.subtitleTitle': 'Subtitle size',
  'settings.dialog.subtitleHint':
      'Font size for embedded subtitles in ExoPlayer (Better Player) and MediaKit. Use the remote to move; Save is at the bottom.',
  'settings.dialog.subtitleChoice': '@pt pt',
  'settings.dialog.layoutTitle': 'Device mode',
  'settings.dialog.refreshTitle': 'Refresh content',
  'settings.dialog.refreshBody':
      'Content will refresh now. Do you also want to set how often to refresh automatically?',
  'settings.dialog.refresh.autoOff': 'Auto refresh off',
  'settings.dialog.refresh.every3': 'Refresh every 3 days',
  'settings.dialog.refresh.every7': 'Refresh every week',
  'settings.dialog.refresh.every2h': 'Refresh every 2 hours',
  'settings.dialog.refresh.every1d': 'Refresh every day',
  'settings.dialog.refresh.every2d': 'Refresh every 2 days',
  'settings.dialog.refresh.every3d': 'Refresh every 3 days',
  'settings.dialog.refresh.every1w': 'Refresh every week',
  'settings.dialog.refresh.nowOnly': 'Refresh once now',
  'settings.reset.menuTitle': 'What do you want to reset?',
  'settings.reset.menuHint':
      'Reset individual items below, or reset everything at the bottom.',
  'settings.reset.watchHistory': 'Reset recently watched',
  'settings.reset.watchHistory.sub':
      'Clears watch history and the "continue watching" list.',
  'settings.reset.ai': 'Reset Mina AI recommendations',
  'settings.reset.ai.sub': 'Regenerates "recommended for you".',
  'settings.reset.playlist': 'Reset playlist data',
  'settings.reset.playlist.sub':
      'Deletes the saved list and content cache; you re-add the list.',
  'settings.reset.everything': 'Reset all settings and data',
  'settings.reset.everything.sub':
      'Resets playlist, cache, favorites and all preferences.',
  'settings.reset.confirmBody': 'This cannot be undone. Are you sure?',
  'settings.reset.watchHistoryDone': 'Recently watched reset.',
  'settings.reset.aiDone': 'Mina AI recommendations reset.',
  'settings.reset.playlistDone': 'Playlist data reset.',
  'settings.dialog.clearTitle': 'Erase all settings',
  'settings.dialog.clearBody':
      'Playlist data, cache, favorites, and preferences will be reset. Continue?',
  'settings.m3uEpg.defaultBadge': 'Default: iptv-org (guide.xml)',
  'settings.tile.m3uXmltvEpg': 'XMLTV (EPG guide)',
  'settings.dialog.xmltvTitle': 'XMLTV (EPG)',
  'settings.dialog.xmltv.body':
      'If the URL is empty, the iptv-org community guide (guide.xml) is used and refreshed about once per day. Channels are matched automatically; data is kept in SQLite and on-disk cache.',
  'settings.dialog.xmltv.hint': 'https://…/epg.xml',
  'settings.dialog.xmltv.label': 'EPG URL',
  'settings.dialog.bufferTitle': 'Live stream buffer',
  'settings.tile.osdOpacity': 'Landscape OSD opacity',
  'settings.tile.osdOpacity.sub': 'Background: @n%',
  'settings.dialog.osdOpacityTitle': 'OSD background opacity',
  'settings.dialog.osdOpacitySlider': 'Opacity: @n%',
  'settings.dialog.osdOpacityHint':
      'Only the OSD capsule background / border / shadow is affected. Buttons, icons and text stay the same.',
  'settings.tile.backup': 'Backup / Restore',
  'settings.tile.backup.sub':
      'Back up your settings and M3U info or restore from a backup file',
  'settings.dataUsage.title': 'Data Usage Detail',
  'settings.dataUsage.subtitle':
      'Total mobile data and wifi traffic used by this app on this device',
  'settings.dataUsage.totalLabel': 'Total combined',

  // Downloads
  'settings.downloads.title': 'Downloads',
  'settings.downloads.subtitle':
      'View, delete or play offline films and series episodes you have downloaded',
  'downloads.screen.title': 'Downloads',
  'downloads.section.active': 'ACTIVE',
  'downloads.section.done': 'COMPLETED',
  'downloads.empty.title': 'No downloads yet',
  'downloads.empty.body':
      'Open a film or series episode and tap "Download" to start. Downloaded content can be played offline.',
  'downloads.action.download': 'Download',
  'downloads.action.downloaded': 'Downloaded',
  'downloads.action.retry': 'Retry',
  'downloads.cancelTitle': 'Cancel download?',
  'downloads.cancelBody':
      'This download will be cancelled and the partial file will be deleted.',
  'downloads.cancel': 'Cancel',
  'downloads.deleteTitle': 'Delete downloaded file?',
  'downloads.deleteBody':
      'The file will be permanently removed from your phone. You would need to re-download to restore it.',
  'downloads.delete': 'Delete',
  'downloads.status.queued': 'Queued…',
  'downloads.status.failed': 'Download failed — tap to retry',
  'downloads.status.cancelled': 'Cancelled',
  'downloads.toast.completed': 'Download completed',
  'downloads.toast.completedNamed': '@title — downloaded',
  'downloads.toast.failed':
      'Download failed — check your connection and try again',
  'downloads.toast.failedWithReason': 'Download failed: @reason',
  'downloads.action.errorTitle': 'Download error',
  'downloads.action.errorBody':
      'Couldn\'t download the file. Possible cause: @reason — Tap Retry to try again.',
  'downloads.action.viewError': 'View error',
  'downloads.action.copyError': 'Copy error',
  'downloads.error.fileMissing':
      'File not found — it may have been deleted or moved',
  'downloads.error.interrupted':
      'Download was interrupted when the app closed; restart it',
  'settings.dataUsage.startedAt': 'Counting since: @date',
  'settings.dataUsage.wifi': 'Wifi',
  'settings.dataUsage.mobile': 'Mobile',
  'settings.dataUsage.rx': 'Downloaded',
  'settings.dataUsage.tx': 'Uploaded',
  'settings.dataUsage.active': 'ACTIVE',
  'settings.dataUsage.reset': 'Reset',
  'settings.dataUsage.resetConfirm.title': 'Reset counters?',
  'settings.dataUsage.resetConfirm.body':
      'Reset wifi and mobile data counters? This cannot be undone.',
  'settings.dataUsage.note':
      'The numbers come from the app\'s TrafficStats counter on this device. The counter keeps increasing across reboots and includes background traffic. Slight differences from the phone\'s system data meter are normal.',
  'settings.dataUsage.unsupported':
      'Data usage detail is only available on Android devices.',
  'settings.dataUsage.preparing':
      'Initializing meter… Numbers will start updating in a few seconds.',
  'settings.tile.backupShare': 'Back up settings (share)',
  'settings.tile.backupShare.sub':
      'Export the encrypted mina_backup.dat via the system share sheet',
  'settings.tile.backupRestore': 'Restore from backup',
  'settings.tile.backupRestore.sub':
      'Pick a mina_backup.dat file and restore settings + M3U info',
  'backupRestore.title': 'Backup / Restore',
  'backupRestore.hint':
      'All your settings, favorites, watch history and M3U/Xtream info are stored in a single encrypted file (mina_backup.dat). From here you can share that file or restore a previously saved backup.',
  'backupRestore.share.title': 'Back up settings',
  'backupRestore.share.body':
      'Exports the encrypted mina_backup.dat through the system share sheet. No special storage permission is required.',
  'backupRestore.share.b1': 'Encrypted with AES‑256; only Mina Pro can open it',
  'backupRestore.share.b2':
      'Send to Drive, WhatsApp, email, Bluetooth — anywhere you like',
  'backupRestore.share.b3':
      'No permanent file is left on the device; only a temporary directory is used',
  'backupRestore.share.action': 'Share backup',
  'backupRestore.restore.title': 'Restore from backup',
  'backupRestore.restore.body':
      'Pick a mina_backup.dat file; your settings, favorites and M3U info will revert to the state saved in the backup.',
  'backupRestore.restore.b1':
      'Current Mina settings are cleared and replaced with the backup',
  'backupRestore.restore.b2':
      'Xtream / M3U credentials are restored to secure storage',
  'backupRestore.restore.b3':
      'You are asked to confirm before restoring; restart the app afterwards',
  'backupRestore.restore.action': 'Pick a file and restore',
  'settings.backup.title': 'Backup',
  'settings.backup.shared': 'Backup sent to share sheet.',
  'settings.backup.error': 'Backup operation failed.',
  'settings.backup.restore.confirmTitle': 'Restore from backup?',
  'settings.backup.restore.confirmBody':
      'Your current settings, favorites, watch history and M3U/Xtream info will be replaced with the contents of the selected backup. Continue?',
  'settings.backup.restore.confirmYes': 'Yes, restore',
  'settings.backup.restore.doneTitle': 'Backup restored',
  'settings.backup.restore.doneBody':
      'All settings have been imported. For the cleanest state, please restart the app.',
  'settings.backup.restoredSummary':
      'Restored @prefs settings, @sec secure entries and @m3u local playlists.',
  'settings.dialog.bufferSlider': '@n seconds',
  'settings.dialog.bufferSlider.auto': 'Auto (Dynamic)',
  'settings.dialog.changelogTitle': 'Release notes',
  'settings.dialog.adminButton': 'Administrator',
  'settings.dialog.adminTitle': 'Administrator',
  'settings.admin.role': 'App administrator',
  'settings.admin.name': 'Furkan Gumrukcu',
  'settings.admin.whatsappLabel': 'WhatsApp',
  'settings.admin.whatsappNumber': '+90 544 645 06 07',
  'settings.admin.emailLabel': 'Email',
  'settings.admin.emailAddress': 'furkangumrukcu@outlook.com',
  'settings.admin.countryLabel': 'Country',
  'settings.admin.countryValue': 'Turkey',
  'settings.admin.bio':
      'This app belongs to me. You can contact me about any issues you experience.',
  'settings.admin.whatsappFail': 'Could not open WhatsApp.',
  'settings.admin.emailFail': 'Could not open the email app.',
  'settings.update.check': 'Check for updates',
  'settings.update.checking': 'Checking…',
  'settings.update.openStore': 'Open in store',
  'settings.update.availableTitle': 'Update available',
  'settings.update.availableBody':
      'A new version (@v) is available on the Play Store. Would you like to update now?',
  'settings.update.latestTitle': 'You\'re up to date',
  'settings.update.latestBody': 'You are using the latest version.',
  'settings.update.failTitle': 'Check failed',
  'settings.update.failBody':
      'Could not retrieve update information. Check your internet connection and try again.',
  'settings.dialog.changelogBody': 'v2.17.33\n'
      '• Better (Exo / primary engine): MediaSource preload (faster zapping), live HTTP timeouts, frame/buffering stall detector, conservative reconnect, targetBufferBytes buffer caps, live 1.0x speed lock, audio compatibility memory\n'
      '• Live HLS: automatic HLS→MPEG-TS fallback on some channels (startup timeout, stall recovery)\n'
      '• MediaKit (backup engine): live mpv improvements — lavf reconnect, display-resample, untimed, cache-pause, 10s stall watchdog, HLS hls-bitrate profile\n'
      '• MediaKit VOD: live mpv flags reset on open; hls-bitrate only on HLS URLs — fixes movies/series not starting\n'
      '• Playback engines: VLC option temporarily locked (Better + MediaKit only)\n\n'
      'v2.12.68\n'
      '• New theme: "IOS 27" — iOS Liquid Glass design: translucent panels, iOS-blue accent, large rounded corners and a fluid glass wallpaper (portrait + landscape). Selectable from the setup wizard and Settings → Theme\n'
      '• New home layout: "Showcase" — phone/tablet only. Vertically scrolling poster rows (Continue Watching, Live TV, IMDB Top Rated Movies, Last 50 Added Movies, Mixed Movies/Series, M3U categories) + a bottom liquid-glass dock (Live TV · Movies & Series · EPG Mix · Mina Wrapped · Settings). Every row has «See All» and a search button up top\n\n'
      'v2.12.67\n'
      '• Movies & Series: Added «Last 50 Added Movies» to the Movies tab and «Last 50 Added Series» to the Series tab — «See All» lists the newest 50 items, newest first\n'
      '• Subtitles: The «no subtitles» notice now appears instantly on unsupported streams (previous 2-3s delay removed)\n'
      '• Subtitles: Now OFF by default; they no longer turn on automatically (both Better Player and MediaKit). Once you pick a language it is remembered and re-applied on other movies when that language is available; choosing «Off» clears the memory\n\n'
      'v2.2.0\n'
      '• Play Store rating dialog: "Later" + "Rate" buttons no longer overflow on narrow screens. When they don\'t fit on one row they stack vertically, right-aligned; wide screens keep the original side-by-side layout\n'
      '• Film & Series detail — Quick Info Panel: Director + Genre lines now appear right below the trailers in a clean glass frame, visible at a glance\n'
      '• Film & Series detail — Watch button: same dimensions, but the inner surface now blends a blurred poster projection with the theme gradient so each title gets its own colour mood\n'
      '• Home — Daily quote: a small flag badge of the user\'s selected language country (17 languages) is appended inside the frame without overflow\n\n'
      'v2.1.x\n'
      '• Film & Series mode: Modern / Classic / Both (setup wizard + Home Settings) with live preview cards\n'
      '• Global home card scale slider (shrink/enlarge every card)\n'
      '• All main category cards (Live TV, Film&Series, Films, Series, Replay&EPG Mix, Favorites) shrunk by 15%\n'
      '• Film & Series hero: "Watch" plays immediately, "Detail" opens the detail page (for both films and series)\n'
      '• Detail tech pills (SD/H.264/Dolby Digital…) now use a single horizontally-scrollable row\n'
      '• Playlist Manager: up to 32 dynamic playlist slots; entry moved to the playlist setup screen, removed from Settings\n'
      '• M3U URL → Xtream is always tried first; if the Xtream API fails it falls back to raw M3U automatically\n'
      '• Replay & EPG Mix: catch-up playback fixed (default Xtream timeshift template fallback)\n'
      '• OSD speed button visible in portrait too; cycle 2x → 3x → 5x → 10x → 1x\n'
      '• Favorite (heart) button removed from the OSD (landscape + portrait)\n'
      '• Hide +18 content: in settings + setup wizard; glass loading popup while applying, dismisses instantly if the library has no +18 content\n'
      '• Hidden categories / channels / +18 items filtered out of Continue Watching, AI Recommendations and Mixed Live TV\n'
      '• Multi-playlist merging: 2nd and further sources now merge live TV + films + series\n\n'
      'v2.0.82\n'
      '• New: Playlist load summary popup. After a successful M3U / Xtream load you now see a glass dialog before navigating home: live channels, films and series each animate from "loading…" to a coloured ✓ tick with the count. The OK button activates only after every stage completes. Full translation across 15 languages\n\n'
      'v2.0.81\n'
      '• Settings sub-page backgrounds now match the active theme wallpaper. Mina Glass → that greenish glass tone, Dark Flat → flat dark surface, SEMC/Fly UI → their own art. Hide categories, Live channel layout, Home screen settings, Backup/Restore, Channel & Category Layout, Playback Settings, Card order, Subtitles, EPG and Parental Control all picked up the change\n\n'
      'v2.0.80\n'
      '• Top Rated Films: rating range 7.0–10.0, duplicate-named films are deduped, the list is reshuffled every day with a fresh deterministic seed (consistent within the day, different 30 films the next day). Now showing 30 films\n\n'
      'v2.0.79\n'
      '• New: Settings → "Playback Settings" sub-page. MediaKit/MPV engine, Hardware acceleration, Video decoder and Low-latency buffer are grouped under one entry\n\n'
      'v2.0.78\n'
      '• Settings: "Hide categories" and "Live channel layout" are merged into one "Channel & Category Layout" entry. The sub-page shows both as large glass cards\n\n'
      'v2.0.77\n'
      '• Settings: "Back up" and "Restore" tiles are merged into a single "Backup / Restore" entry. The sub-page shows both actions as large glass cards with short descriptions of what each one does\n\n'
      'v2.0.76\n'
      '• New: "Home screen settings" sub-page. Card order, Mixed Live TV, Upcoming Matches and Top Rated Films are now managed in one place, with a small preview illustration under each row\n'
      '• Top Rated Films now has its own switch (default on, also added to the setup wizard)\n\n'
      'v2.0.75\n'
      '• Home: new "Top Rated Films" strip (right below Continue Watching). Top 20 films by IMDB rating, posters sized exactly like the Continue Watching cards, with a glass circular IMDb badge in the top-right corner\n\n'
      'v2.0.74\n'
      '• New: Back up settings + M3U info and restore them. All settings, favorites, watch history and Xtream/M3U credentials are AES‑256 encrypted into mina_backup.dat and exported via the system share sheet (Drive/WhatsApp/email)\n'
      '• Restore needs no dangerous storage permission — pick a single file via file_picker\n\n'
      'v2.0.73\n'
      '• Settings → "Layout" option hidden (now auto-managed)\n'
      '• New: Landscape OSD background opacity (0–100). Only the capsule background/border/shadow becomes transparent; buttons, icons and logos stay solid\n'
      '• Films & Series: subtitles now default to OFF — pick a track manually from the OSD\n\n'
      'v2.0.72\n'
      '• Adaptive OSD sizing (landscape mobile): on small-screen phones the player\'s right-side OSD capsule no longer overflows; button size, gap, left info-block width and the vertical divider auto-shrink in three tiers based on screen width (<600, <780, ≥780 dp)\n\n'
      'v2.0.71\n'
      '• Channel prefix: only country prefixes are stripped (TR:/BR:/EN:/US:); quality and tag info (HD/SD/FHD/UHD/HEVC/4K/VIP) is kept so users can see channel quality at a glance\n\n'
      'v2.0.70 — Play Store release\n'
      '• Films & Series full modernization bundle: cinematic Hero Banner carousel (Films + Series), frosted-glass category panels with neon accent, edge fade-in/out, 24dp spacing\n'
      '• Refreshed poster: IMDB pill at the bottom-right of the artwork (yellow star + score); smaller, transparent, elegant favorite heart; single-line gray caption\n'
      '• Tab-bar search button: only films + series in results; picking a hit opens the new Films & Series detail page directly\n'
      '• Minimal glass back pill replaces the old full-width "Films & Series" header\n\n'
      'v2.0.69\n'
      '• Films & Series search: picking a result from the tab-bar search now opens the new Films & Series detail page directly, instead of the old Browse list\n\n'
      'v2.0.68\n'
      '• Films & Series search: the search button in the tab bar now shows only films + series (live TV results are excluded)\n\n'
      'v2.0.67\n'
      '• Series tab: all the Film-tab modernizations now apply to series too — cinematic Hero Banner carousel at the top (first 5 new series), frosted-glass category panels, neon accent, edge fade-in/out, compact poster captions\n\n'
      'v2.0.66\n'
      '• Films & Series: category blocks now use a frosted-glass panel with a neon accent (no more dark cards); IMDB badge moved to poster bottom-right (yellow star + "IMDb" + score); favorite heart is smaller, transparent and elegant\n\n'
      'v2.0.64\n'
      '• Films & Series: full-width cinematic Hero Banner carousel (top 5 picks with Watch/Details), card-less category headers with refined typography, edge fade-in/out, 24dp section spacing; compact single-line gray poster captions\n\n'
      'v2.0.63\n'
      '• Films & Series: small glass search button between the Film/Dizi tab chips — opens the unified search dialog\n\n'
      'v2.0.62\n'
      '• Films & Series: removed top «Film & Dizi» header bar; minimal glass back button stays at top-left, more room for content\n\n'
      'v2.0.61\n'
      '• Actor detail — Movies: taps guaranteed via GestureDetector; entire playlist scanned (incl. hidden categories), Turkish char + word-set match, toast when no match\n\n'
      'v2.0.60\n'
      '• Actor detail: tapping a film in the filmography opens the matching title from your playlist\n\n'
      'v2.0.59\n'
      '• TV OSD auto-hide: added 3 s option (3, 5, 7, 10, 15, 20). Default stays at 7 s.\n\n'
      'v2.0.58\n'
      '• Xtream EPG on first load: when a playlist is added (incl. M3U → Xtream conversion), Xtream EPG now downloads automatically in the background — no restart needed\n\n'
      'v2.0.57\n'
      '• Smart M3U → Xtream: when an M3U URL carries username/password params, it is auto-converted to Xtream in the background and loaded via the Xtream API (EPG/VOD/Series available). Plain M3U links keep the existing behaviour.\n\n'
      'v2.0.56\n'
      '• Settings: functional icons instead of «01/02/03»; lighter glass tiles so wallpaper shows through\n'
      '• Films & Series detail: play icon on Watch button, softer corners, neon glow; cast name–role spacing; synopsis line height 1.4 (movie + series)\n\n'
      'v2.0.55\n'
      '• Channel prefix stripping: in addition to country codes (TR:/BR:/EN:), now also removes Full HD:/FHD:/HD:/SD:/UHD:/4K:/8K:/HEVC:/H.265:/H.264:/VIP:/LIVE:/SY:/BACKUP:/ALT:/MULTI:/PPV: prefixes and a single trailing [HD] tag\n'
      '• Applied across Continue Watching cards, Mixed Live TV strip, Live TV list — controlled by Settings → «Channel prefix»\n'
      '• Setup wizard: added «Strip channel prefixes» switch under Features\n\n'
      'v2.0.54\n'
      '• Adaptive haptics Samsung fix: One UI «no vibration» resolved via native Vibrator bridge; A–Z fast-scroll bar included\n'
      '• Performance (non-EPG): scope-cached home count getters, Mixed Live TV strip, hidden-category set sharing; less jank, less GC pressure\n\n'
      'v2.0.53\n'
      '• Play Store release bundle\n\n'
      'v2.0.52\n'
      '• Live TV channels: EPG under channel name; programme title + start time\n\n'
      'v2.0.51\n'
      '• Live TV channels: EPG right-aligned (logo side), no parentheses, gap after name\n\n'
      'v2.0.50\n'
      '• Live TV channels: marquee only for (EPG programme); channel name stays fixed\n\n'
      'v2.0.49\n'
      '• Player: brightness on left edge, volume on right; center pinch zoom improved\n'
      '• Live TV channels (portrait): channel + current programme; marquee on long titles\n'
      '• Settings: optional hide country channel prefix (TR:, BR:…)\n\n'
      'v2.0.48\n'
      '• Films & Series: detail meta, IMDb, glass Play; See All A–Z index with letter bubble\n'
      '• Live TV EPG: no country prefix, no empty slot boxes; same-category channels in portrait\n'
      '• Player: two-finger pinch zoom + scale/position HUD on mobile and tablet\n'
      '• Settings: EPG hub; blur-off removed; content refresh defaults to weekly\n\n'
      'v2.0.35\n'
      '• Recommended Movies: hero poster no longer disappears while scrolling\n'
      '• Recommended Movies: 4K / UHD row; See All header and search readability\n'
      '• Play Store: rate prompt once per day for users who have not rated\n'
      '• Translations: missing strings filled for all 17 app languages\n\n'
      'v2.0.23\n'
      '• EPG Mix: programme reminders and notification permissions removed for now\n\n'
      'v1.9.16\n'
      '• Settings: Better Player / MediaKit selection text is clearer\n'
      '• Settings: new “App Font” menu added (applies to the whole app)\n'
      '• Fonts: Sony, Roboto, Noto Sans, and Monospace options added\n'
      '• TV: D-pad focus and OK flow improved in font picker dialog\n'
      '• Portrait detail: sharp top-corner preview shadow layer fixed\n'
      '• Portrait player: default OSD panel/buttons stay visible even when stream fails\n'
      '• Settings: icons for tiles 16/17 aligned with the app-wide icon style\n\n'
      'See CHANGELOG.md for full details.\n',
  'settings.dialog.developerTitle': 'Developer',
  'settings.dialog.developerBody': 'Developer: furkangumrukcu',
  'settings.snackbar.content': 'Content',
  'settings.snackbar.noPlaylist': 'No saved playlist. Add one first.',
  'settings.snackbar.refreshOk': 'Playlist updated successfully.',
  'settings.snackbar.error': 'Error',
  'settings.snackbar.loadFailed': 'Could not load: @e',
  'settings.snackbar.info': 'Info',
  'settings.snackbar.xtreamOnly': 'This feature is only for Xtream accounts.',
  'settings.snackbar.xtreamFail':
      'Could not load account info from the server.',
  'settings.snackbar.xtreamError': 'Error while fetching info: @e',
  'settings.dialog.xtreamTitle': 'Xtream account',
  'settings.xtream.user': 'Username',
  'settings.xtream.status': 'Status',
  'settings.xtream.expiry': 'Expires',
  'settings.xtream.connections': 'Active / Max connections',
  'settings.xtream.trial': 'Trial account',
  'settings.xtream.unlimited': 'Unlimited',
  // Detailed Xtream account dialog (subscription + server)
  'xtream.info.section.subscription': 'SUBSCRIPTION',
  'xtream.info.section.server': 'SERVER',
  'xtream.info.password': 'Password',
  'xtream.info.authState': 'Auth',
  'xtream.info.authOk': 'Success',
  'xtream.info.authFail': 'Failed',
  'xtream.info.unknown': 'Unknown',
  'xtream.info.message': 'Message',
  'xtream.info.createdAt': 'Created',
  'xtream.info.remaining': 'Remaining',
  'xtream.info.remainingDays': '@n days',
  'xtream.info.expiredAgo': 'expired @n days ago',
  'xtream.info.allowedOutputs': 'Allowed formats',
  'xtream.info.userInfoMissing': 'User info unavailable',
  'xtream.info.serverInfoMissing': 'Server info unavailable',
  'xtream.info.serverBaseUrl': 'Connection URL',
  'xtream.info.serverHost': 'Host',
  'xtream.info.serverProtocol': 'Protocol',
  'xtream.info.serverPort': 'HTTP port',
  'xtream.info.serverHttpsPort': 'HTTPS port',
  'xtream.info.serverRtmpPort': 'RTMP port',
  'xtream.info.timezone': 'Timezone',
  'xtream.info.serverTime': 'Server time',
  'xtream.info.serverProcess': 'Service status',
  'xtream.info.serverRevision': 'Revision',
  // Xtream login error (retry)
  'xtream.error.title': 'Xtream login error',
  'xtream.error.invalidCredentials':
      'Username, password or server address is invalid. Please double-check and try again.',
  'xtream.error.invalidCredentialsWithMsg':
      'Server replied: @m\n\nPlease double-check your username, password and server address, then try again.',
  'xtream.error.credentialsEmpty':
      'Server address, username and password are all required.',
  'stalker.error.title': 'Stalker Portal login error',
  'stalker.error.credentialsEmpty':
      'Both portal URL and MAC address are required.',
  'stalker.error.invalidHandshake':
      'Could not connect to the portal. Check the URL (e.g. http://host/c/) and MAC address.',
  'stalker.error.invalidCredentials':
      'This MAC address is not authorized on the portal, or login failed.',
  'stalker.error.emptyCatalog':
      'Logged in but the channel/VOD list was empty. Check MAC authorization or portal URL.',
  'stalker.field.portalUrl': 'Stalker Portal URL',
  'stalker.field.mac': 'MAC Address',
  'stalker.chip.label': 'Stalker',
  'stalker.compat.title': 'Stalker compatibility',
  'stalker.compat.hint':
      'Some portals require MAG254 or a different hardware version. Try another preset if login fails.',
  'stalker.compat.sslHint':
      'For invalid SSL certificates, use Settings → “Ignore SSL/TLS verification”.',
  'stalker.field.magPreset': 'MAG preset',
  'stalker.field.linkType': 'Link type',
  'stalker.field.hwVersion': 'hw_version (optional)',
  'stalker.preset.genericSafe': 'MAG250 (recommended)',
  'stalker.preset.mag250Legacy': 'MAG250 legacy',
  'stalker.preset.mag254Strict': 'MAG254',
  'stalker.preset.ministraModern': 'MAG322 / Ministra',
  'stalker.link.wifi': 'WiFi',
  'stalker.link.ethernet': 'Ethernet',
  'settings.xtreamFooter.line': 'Xtream: @user · @host',
  'settings.snackbar.settings': 'Settings',
  'settings.snackbar.cleared': 'All data cleared.',
  'settings.snackbar.clearFailed': 'Could not clear: @e',
  'settings.snackbar.subtitles': 'Subtitles',
  'settings.snackbar.subtitlesSoon':
      'Subtitle appearance options are coming soon.',
  'settings.snackbar.report': 'Report issue',
  'settings.snackbar.reportFail':
      'Could not open email. Address: furkangumrukcu07@gmail.com',
  'settings.snackbar.reportManual': 'You can email furkangumrukcu07@gmail.com',
  'settings.mail.subject': 'Mina IPTV — Issue report',
  'settings.mail.body':
      '--- Auto diagnostics (please keep if possible) ---\n@diag\n---\n\nWhat happened? Steps:\n\n',
  'playlist.title': 'Playlist setup',
  'playlist.sourceTitle': 'Choose source',
  'playlist.sourceSubtitle': 'M3U URL, local file, or Xtream account.',
  'playlist.loadList': 'Load playlist',
  'playlist.m3uUrl': 'M3U URL',
  'playlist.m3uUrlHint': 'https://example.com/playlist.m3u',
  'playlist.pasteUrl': 'Paste',
  'playlist.pasteEmpty': 'Clipboard is empty',
  'playlist.pickFile': 'Choose file',
  'playlist.m3uXtreamRecommendation':
      'For better performance and features, we recommend signing in with Xtream.',
  'playlist.noFile': 'No .m3u / .m3u8 file selected',
  'playlist.xtream.server': 'Server URL',
  'playlist.xtream.serverPlaceholder': 'Server URL (host)',
  'playlist.xtream.user': 'Username',
  'playlist.xtream.pass': 'Password',
  'playlist.xtream.hint':
      'You can paste URLs that include player_api.php directly.',
  'playlist.summary.title': 'Playlist loaded',
  'playlist.summary.titleLoading': 'Loading playlist',
  'playlist.summary.subtitle': 'Here is a quick summary of what was imported.',
  'playlist.summary.subtitleLoading':
      'Preparing live channels, films, and series…',
  'playlist.summary.liveChannels': 'Live channels',
  'playlist.summary.films': 'Films',
  'playlist.summary.series': 'Series',
  'playlist.summary.loading': 'Loading…',
  'playlist.summary.itemsCount': '@n items',
  'playlist.summary.ok': 'OK',
  'playlist.summary.okCountdown': 'OK (@n)',
  'playlist.summary.autoCloseHint':
      'Dialog will close automatically. Merging continues in the background.',
  'playlist.summary.cancel': 'Cancel',
  'playlist.summary.fixUrl': 'Fix URL',
  'playlist.summary.errorTitle': 'Playlist could not be loaded',
  'playlist.summary.errorSubtitle':
      'Check the URL and try again. The hint below may help.',
  'playlist.error.url.ssl':
      'HTTPS connection failed. The certificate may be invalid or the server does not support HTTPS.',
  'playlist.error.url.host':
      'Server name could not be resolved. Check the host part of the URL and your internet connection.',
  'playlist.error.url.timeout':
      'The server did not respond in time. It may be busy — try again in a moment.',
  'playlist.error.url.refused':
      'The server refused the connection. The port or address may be wrong.',
  'playlist.error.url.auth':
      'Access denied (401/403). Check your username/password or panel subscription.',
  'playlist.error.url.notFound':
      'URL not found (404). The playlist address may have moved or been mistyped.',
  'playlist.error.url.server':
      'Server error (5xx). The panel is temporarily unavailable.',
  'playlist.error.url.empty':
      'The server returned an empty response. The URL is reachable but the playlist is empty.',
  'playlist.error.url.network':
      'Could not reach the playlist. URL or network connection is broken.',
  'playlist.error.hint.tryHttp':
      'Hint: try the URL with `http://` instead of `https://`.',
  'playlist.error.hint.tryHttps':
      'Hint: try the URL with `https://` instead of `http://`.',
  'playlist.error.hint.addScheme':
      'Hint: the URL must start with `http://` or `https://`.',
  'playlist.snackbar.file': 'File',
  'playlist.snackbar.badExt':
      'Please choose a valid .m3u, .m3u8, or .txt file.',
  'playlist.snackbar.readFail': 'Could not read file (no path or data)',
  'playlist.snackbar.fileError': 'Error: @e',
  'playlist.snackbar.m3u': 'M3U',
  'playlist.snackbar.setup': 'Setup',
  'playlist.label.localM3u': 'Local M3U',
  'playlist.error.emptyUrl': 'M3U URL cannot be empty',
  'playlist.error.xtream': 'Incomplete Xtream credentials',
  'playlist.merge.orphanCategory': 'List 2',
  'playlist.secondaryTitle': 'Second source (optional)',
  'playlist.secondarySubtitle':
      'A second M3U or Xtream adds live TV channels only; movies/series stay from the primary source.',
  'playlist.managerEntry.title': 'Playlists Manager',
  'playlist.managerEntry.body':
      'Add as many extra playlists as you like (M3U URL, M3U file or Xtream) — live, movies and series merged in one library',
  'playlist.qrEntry.title': 'Add via QR code',
  'playlist.qrEntry.body':
      'Use your phone as a remote: scan the QR from a device on the same Wi-Fi, send your M3U or Xtream credentials, and the TV loads the list instantly.',
  'playlist.qr.title': 'Add Playlist via QR',
  'playlist.qr.subtitle':
      'Scan the QR with your phone, then submit M3U or Xtream from the page that opens. Both devices must share the same Wi-Fi.',
  'playlist.qr.waiting': 'Waiting for the phone…',
  'playlist.qr.hint':
      'The QR works only while this window is open; closing it stops the local server. Data never goes through the cloud — only between your devices.',
  'playlist.qr.urlCopied': 'Link copied',
  'playlist.qr.error.title': 'No local network',
  'playlist.qr.error.sub':
      'Wi-Fi or Ethernet must be active. Mobile data alone is not enough — the TV and phone must share the same local network.',
  'playlist.secondaryEnable': 'Enable second playlist',
  'playlist.secondaryUrlHint': 'Second M3U URL',
  'playlist.error.secondaryXtream': 'Incomplete second Xtream credentials',
  'playlist.error.secondaryUrl': 'Second M3U URL cannot be empty',
  'playlist.demoList': 'Demo Playlist (Test)',

  // Note: 'settings.tile.playlistsManager' tile was removed from Settings —
  // navigation now happens via the entry card inside PlaylistView.
  'playlistsManager.title': 'Playlists Manager',
  'playlistsManager.subtitle':
      'Up to @max playlists — live, movies and series merged',
  'playlistsManager.subtitle.unlimited': 'Add as many playlists as you want',
  'playlistsManager.reorder.hint': 'Press and drag the handle to reorder',
  'playlistsManager.toast.reordered': 'Playlist order updated.',
  'playlistsManager.addNew.title': 'Add new playlist',
  'playlistsManager.addNew.body':
      'M3U URL, M3U file or Xtream — saved as slot #@n',
  'playlistsManager.slot.primary': 'Primary playlist',
  'playlistsManager.slot.extra': 'Playlist @n',
  'playlistsManager.slot.empty': 'Empty — tap + to add',
  'playlistsManager.name.label': 'Playlist name (optional)',
  'playlistsManager.name.hint': 'e.g. Sports Pack',
  'playlistsManager.name.helper': 'Leave empty to use the default heading.',
  'playlistsManager.edit': 'Edit',
  'playlistsManager.remove': 'Remove',
  'playlistsManager.removeTitle': 'Remove playlist',
  'playlistsManager.removeBody': 'Are you sure you want to remove playlist @n?',
  'playlistsManager.editor.primary': 'Edit primary playlist',
  'playlistsManager.editor.extra': 'Edit playlist @n',
  'playlistsManager.tab.url': 'M3U URL',
  'playlistsManager.tab.file': 'M3U File',
  'playlistsManager.tab.xtream': 'Xtream',
  'playlistsManager.tab.demo': 'Demo',
  'setup.sourceDemo.sub':
      'Try the app right away with built-in demo channels; no server credentials needed.',
  'playlistsManager.file.pick': 'Pick file',
  'playlistsManager.file.replace': 'Pick another file',
  'playlistsManager.reloading': 'Merging playlists…',
  'playlistsManager.syncing': 'Updating content…',
  'playlistSwitcher.title': 'Lists',
  'playlistSwitcher.sheetTitle': 'Select List',
  'playlistSwitcher.kind.xtream': 'Xtream',
  'playlistSwitcher.kind.m3u': 'M3U',
  'playlistsManager.toast.enabling': 'Enabling playlist @n…',
  'playlistsManager.toast.disabling': 'Disabling playlist @n…',
  'playlistsManager.status.enabling': 'Enabling…',
  'playlistsManager.status.disabling': 'Disabling…',
  'playlistsManager.toast.saved': 'Playlist saved.',
  'playlistsManager.toast.removed': 'Playlist removed.',
  'playlistsManager.toast.removedN': 'Playlist @n deleted.',
  'playlistsManager.toast.removing': 'Deleting playlist @n…',
  'playlistsManager.toast.refreshEmpty':
      'Cannot refresh an empty slot. Add a playlist first.',
  'playlistsManager.toast.refreshLocalUnsupported':
      'Local file playlists cannot be refreshed. Please pick the file again.',
  'playlistsManager.toast.refreshUnsupported':
      'This source cannot be refreshed.',
  'playlistsManager.refresh': 'Refresh playlist',
  'playlistsManager.error.cannotRemovePrimary':
      'Primary playlist cannot be removed. Pick a different source first, or reset all playlists.',
  'playlistsManager.error.cannotRemoveLast':
      'At least one playlist must remain. You cannot remove the last list; use "Edit" to change its content.',
  'playlistsManager.merge.orphanCategory': 'List @n',
  'playlistsManager.live.prefix.plain': 'List @n',
  'playlistsManager.live.prefix.named': 'List @n (@name)',
  'playlistsManager.merge.cta': 'Merge Playlists (@n)',
  'playlistsManager.merge.cta.hint':
      'Activates all populated playlists. Live TV categories are grouped as "List 1 (Name) · Category"; films and series become one mixed list.',
  'playlistsManager.merge.allActive': 'All playlists merged (@n)',
  'playlistsManager.merge.allActive.hint':
      'Content from all populated playlists is shown together. To use a single list, disable the others with the eye icon next to each row.',
  'playlistsManager.toast.autoSolo':
      'New playlist added: only @name is active. Use the "Merge Playlists" button to include the others.',
  'playlistsManager.toast.mergeDone': '@n playlists merged.',
  'playlistsManager.toast.mergeNothing':
      'Nothing to merge. Add a new playlist first.',
  'playlistsManager.toast.mergeAlreadyAll': '@n playlists are already merged.',
  'playlistsManager.disable': 'Disable',
  'playlistsManager.enable': 'Enable',
  'playlistsManager.badge.disabled': 'Disabled',
  'playlistsManager.toast.disabled': 'List @n disabled',
  'playlistsManager.toast.enabled': 'List @n enabled',
  'playlistsManager.error.cannotDisableLast':
      'At least one playlist must stay active. You cannot disable the last active list.',
  'playlistsManager.error.mergeReloadFailed':
      'Playlist status was saved but channels could not be refreshed. Try again or pull to refresh on the home screen.',
  'playlistsManager.toast.mergeBackgroundFailed':
      'Background merge failed. Pull to refresh on the home screen.',

  'player.liveBadge': 'LIVE',
  'player.movieBadge': 'MOVIE',
  'player.seriesBadge': 'SERIES',
  'player.epgLoading': 'Loading EPG…',
  'player.skip_intro': 'Skip Intro',
  'player.channelNumberOutOfRange': 'Channel @n not found (1–@total)',
  'setup.smartStreamCutterTitle': 'Smart Stream Cutter',
  'setup.smartStreamCutterSub':
      'Learns how far you fast-forward in episode 1 or 2 of Xtream series, then shows an automatic "Skip Intro" glass button in the next episodes.',
  'settings.smartStreamCutter.title': 'Smart Stream Cutter',
  'settings.smartStreamCutter.sub':
      'Remembers the manual fast-forward you do in the first episodes of Xtream series and automatically shows a "Skip Intro" button in the lower-right corner of later episodes. Only fast-forwards of 30 s or more within the first 5 minutes are learned.',
  'player.fit.contain': 'Fit',
  'player.fit.cover': 'Fill',
  'player.fit.fill': 'Stretch',
  'player.fit.label': 'View',
  'player.vodAutoplay.titleEpisode': 'Next episode',
  'player.vodAutoplay.titleMovie': 'Next movie',
  'player.vodAutoplay.secondsHint': 'seconds until playback',
  'player.vodAutoplay.cancel': 'Cancel',
  'player.vodAutoplay.playNow': 'Play now',
  'player.vodAutoplay.backHint': 'Press back to cancel',
  'player.vodRail.title': 'In this category',
  'player.vodRail.hint': 'OK to switch · Back to keep watching',
  'player.vodRail.hintCategories':
      '◀ ▶ category · OK to switch · Back to keep watching',
  'player.liveRail.title': 'Channels',
  'player.liveRail.hint': 'OK to switch · Back to close',
  'player.liveRail.hintCategories':
      '◀ ▶ category · OK to switch · Back to close',
  'player.tooltip.prevCh': 'Previous channel',
  'player.tooltip.nextCh': 'Next channel',
  'player.tooltip.rewind': '15 s back',
  'player.tooltip.forward': '15 s forward',
  'player.tooltip.pause': 'Pause',
  'player.tooltip.quickMenuHold': 'Quick list: long OK',
  'player.tooltip.quickMenuOpen': 'Quick list',
  'player.tooltip.play': 'Play',
  'player.tooltip.favOff': 'Add to favorites',
  'player.tooltip.favOn': 'Remove from favorites',
  'player.tooltip.fit': 'View: @fit',
  'player.tooltip.quality': 'Stream quality',
  'player.tooltip.audio': 'Audio track',
  'player.tooltip.subtitle': 'Subtitles',
  'player.tooltip.speed': 'Speed: @ratex',
  'player.tooltip.speed.normal': 'Speed: Normal (1x)',
  'player.tooltip.volume': 'Volume',
  'player.tooltip.cast': 'Cast / send to TV',
  'player.cast.title': 'Cast / send to TV',
  'player.cast.systemChooser': 'System chooser',
  'player.cast.systemChooserSub': 'Show every installed video app',
  'player.cast.empty':
      'No cast-capable app installed. Try Web Video Caster, Cast to TV, BubbleUPnP, AllCast or Plex.',
  'player.cast.noStream': 'No active stream.',
  'player.cast.notAvailable': 'Cast is not supported on this device.',
  'player.cast.launchFailed': 'Could not launch the selected app.',
  'player.tooltip.backupPlayer': 'Switch to backup player (MediaKit)',
  'player.tooltip.toMediaKit': 'Play with MediaKit (M)',
  'player.tooltip.toBetter': 'Play with Better Player (B)',
  'player.tooltip.liveEpg': 'This channel’s TV guide',
  'player.tooltip.toPortrait': 'Switch to portrait',
  'player.tooltip.toLandscape': 'Landscape: rotate your phone',
  'player.engine.title': 'Playback engine',
  'player.engine.toExo': 'Switch to Better Player (Exo) engine',
  'player.engine.toMediaKit': 'Switch to MediaKit (mpv) engine',
  'player.engine.switchedExo':
      'Switched to Better Player (Exo) for this stream',
  'player.engine.switchedMediaKit':
      'Switched to MediaKit (mpv) for this stream',
  'portraitPanel.channelCount': '@n channels',
  'portraitPanel.live': 'LIVE NOW',
  'portraitPanel.noProgramme': 'No programme available',
  'portraitPanel.empty.categories': 'No categories available',
  'portraitPanel.empty.channels': 'No live channels in this category',
  'portraitPanel.empty.epg': 'No EPG information for this channel',
  'portraitVodPanel.tab.films': 'Movies',
  'portraitVodPanel.tab.series': 'Series',
  'portraitVodPanel.allFilms': 'All movies',
  'portraitVodPanel.allSeries': 'All series',
  'portraitVodPanel.empty.items': 'No content in this category',
  'portraitVodPanel.nowPlaying': 'NOW PLAYING',
  'portraitSeriesPanel.tab.info': 'Series',
  'portraitSeriesPanel.tab.episodes': 'Episodes',
  'portraitSeriesPanel.synopsis': 'Synopsis',
  'portraitSeriesPanel.cast': 'Cast',
  'portraitSeriesPanel.imdb': 'IMDb',
  'portraitSeriesPanel.year': 'Year',
  'portraitSeriesPanel.runtime': 'Runtime',
  'portraitSeriesPanel.genre': 'Genre',
  'portraitSeriesPanel.director': 'Director',
  'portraitSeriesPanel.empty.info': 'Series info is not available yet.',
  'portraitSeriesPanel.empty.episodes': 'No episode list for this series.',
  'portraitSeriesPanel.episodeLabel': 'S@s · E@e',
  'portraitSeriesPanel.nowPlaying': 'NOW PLAYING',
  'portraitSeriesPanel.loading': 'Loading…',
  'player.engine.switchToBetter.title': 'Switch to Better Player (Exo)?',
  'player.engine.switchToBetter.body':
      'MediaKit is recommended for series streams. Are you sure you want to use ExoPlayer?',
  'player.engine.better': 'Better Player',
  'player.engine.mediaKit': 'MediaKit',
  'player.engine.vlc': 'VLC',
  'player.engineFallback.toMediaKit': 'Retrying the stream with MediaKit…',
  'player.engineFallback.toBetter': 'Retrying the stream with Better Player…',
  'player.quality.title': 'Stream quality',
  'player.quality.noneShort': 'No quality options for this stream.',
  'player.quality.noneLong':
      'No multi-quality menu is available for this stream. HD/FHD choices appear only when the server offers an HLS master playlist (m3u8) with multiple variants; a single MPEG-TS (.ts) feed or single-bitrate m3u8 will not populate the list.',
  'player.audio.title': 'Audio track',
  'player.audio.noneShort': 'No alternate audio tracks for this stream.',
  'player.audio.noneLong': 'No alternate audio tracks for this stream.',
  'player.sheet.audioTitle': 'Audio track',
  'player.sheet.subtitleTitle': 'Subtitles',
  'player.sheet.qualityTitle': 'Stream quality',
  'player.track.audio': 'Audio @n',
  'player.quality.auto': 'Auto',
  'player.quality.unknown': 'Unknown quality',
  'player.quality.withFps': '@res · @fps fps',
  'player.loading.decoder': 'Fixing decoder error (step @step)...',
  'player.loading.stream': 'Opening stream…',
  'player.pinchZoom.center': 'Center',
  'player.pinchZoom.left': 'Left @n%',
  'player.pinchZoom.right': 'Right @n%',
  'player.pinchZoom.up': 'Up @n%',
  'player.pinchZoom.down': 'Down @n%',
  'player.pinchZoom.reset': 'Reset (1:1)',
  'player.error.contentNotFound': 'Content was not found on the server',
  'player.error.streamForbidden': 'Stream access denied (403)',
  'player.error.playbackGeneric': 'Playback is unavailable right now',
  'player.error.invalidStreamUrl': 'Invalid stream address',
  'player.pip.unavailable':
      'Picture-in-Picture is not available on this device or player.',
  'player.pip.failed':
      'Could not start Picture-in-Picture. Check PiP permission in system settings.',
  'player.pip.mediaKit':
      'PiP is not available in MediaKit mode. Switch to the default player.',
  'player.notReady': 'Player is not ready',
  'player.resume.title': 'Resume where you left off?',
  'player.resume.body':
      'You have watched this title before. How would you like to continue?',
  'player.resume.fromLast': 'Resume',
  'player.resume.fromStart': 'Start over',
  'player.warn.title': 'Notice',
  'player.warn.qualityShort':
      'No multi-quality menu: HD/FHD needs multiple HLS variants; plain .ts or single-bitrate streams may leave the menu empty.',
  'player.mobile.pickAudio': 'Select audio track',
  'player.mobile.pickSubtitle': 'Select subtitles',
  'player.subtitle.off': 'Off',
  'player.subtitle.track': 'Subtitle',
  'player.subtitle.embedded': 'Embedded (in file)',
  'player.subtitle.noneShort': 'No subtitle tracks for this stream.',
  'player.subtitle.noneLong':
      'No subtitle renditions in the manifest or stream; HLS/DASH subtitle tracks appear here when offered.',
  'player.subtitle.imageBasedTitle': 'Image-based subtitles',
  'player.subtitle.imageBasedBody':
      'This title\'s embedded subtitles are image-based (PGS/VobSub). The current player can\'t display them. Switch to the MediaKit player? The switch applies to this stream only.',
  'player.subtitle.imageBasedBodyTv':
      'This title\'s embedded subtitles are image-based (PGS/VobSub). The current player can\'t display them. After switching to the MediaKit player, pick them from the subtitle button.',
  'player.subtitle.switchToMediaKit': 'Switch to MediaKit',
  'player.subtitle.switchingForSubs':
      'Switching to the MediaKit player for subtitles…',
  'player.snackbar.audioChanged': 'Audio changed',
  'player.snackbar.subtitleChanged': 'Subtitles changed',
  'player.snackbar.qualityChanged': 'Quality changed',
  'player.track.channel': 'Channel @n',
  'externalPlayer.title': 'External Player',
  'externalPlayer.sub':
      'Open streams in an installed app like VLC, MX Player, or Just Player.',
  'externalPlayer.picker.title': 'Choose Player',
  'externalPlayer.picker.hint':
      'Shows the video players installed on your device. Pick the one you want to use.',
  'externalPlayer.picker.currentLabel': 'Selected player',
  'externalPlayer.picker.systemChooser': 'Ask every time (Android chooser)',
  'externalPlayer.picker.empty': 'No installed players found',
  'externalPlayer.picker.emptyHint':
      'Install a video player such as VLC, MX Player, or Just Player and try again.',
  'externalPlayer.picker.unsupported':
      'External player is not supported on this device.',
  'externalPlayer.picker.errorTitle': 'Could not list players',
  'externalPlayer.picker.savedToast': '@name set as the external player',
  'externalPlayer.error.noStream': 'No valid stream URL',
  'externalPlayer.error.launchFailed':
      'External player could not start; falling back to built-in player',
};
