import 'package:get/get.dart';

import 'locale_partials.dart';
import 'translation_merge.dart';

/// Locales: `tr_TR`, `en_US`, plus `fr_FR`, `ar_SA`, `zh_CN`, `ru_RU` (merged over English).
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'tr_TR': _tr,
        'en_US': _en,
        'fr_FR': mergeTranslations(_en, kLocalePartialFr),
        'ar_SA': mergeTranslations(_en, kLocalePartialAr),
        'zh_CN': mergeTranslations(_en, kLocalePartialZh),
        'ru_RU': mergeTranslations(_en, kLocalePartialRu),
      };
}

const Map<String, String> _tr = {
  // App / home
  'app.title': 'Mina IPTV Player',
  'home.live': 'Canlı Yayınlar',
  'home.live.subtitle': 'Canlı TV',
  'home.films': 'Filmler',
  'home.films.subtitle': 'Film / dizi',
  'home.series': 'Diziler',
  'home.series.subtitle': 'Dizi',
  'home.favorites': 'Favori',
  'home.header.brandTop': 'Mina',
  'home.header.brandBottom': 'IPTV Player',
  'splash.preparing': 'Kütüphane hazırlanıyor…',

  // Browse
  'browse.films': 'Filmler',
  'browse.series': 'Diziler',
  'browse.favorites': 'Favoriler',
  'browse.empty': 'Sonuç bulunamadı.',
  'browse.pickItem': 'Bir öğe seçin',
  'browse.tab.category': 'Kategori',
  'browse.tab.detail': 'Detay',
  'browse.categoriesHeader': 'Kategoriler',
  'browse.seriesShort': 'Dizi',
  'browse.season': 'Sezon',
  'browse.episodes': 'Bölümler',
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

  // Channels
  'channels.search': 'Kanal ara…',
  'channels.searchDialogTitle': 'Kanal ara',
  'channels.searchSubmit': 'Ara',
  'channels.title': 'Kanallar',
  'channels.empty': 'Kanal bulunamadı.',
  'channels.pick': 'Kanal seçin',
  'channels.tab.categories': 'Kategoriler',
  'channels.tab.channels': 'Kanallar',
  'channels.tab.detail': 'Detay',
  'channels.allChannels': 'Tüm kanallar',

  // Common
  'common.play': 'Oynat',
  'common.notPlayable': 'Oynatılamıyor',
  'common.favorite': 'Favori',
  'common.back': 'Geri',
  'common.ok': 'Tamam',
  'common.cancel': 'İptal',
  'common.close': 'Kapat',
  'common.save': 'Kaydet',
  'common.delete': 'Sil',
  'common.clear': 'Temizle',
  'common.active': 'Aktif',
  'common.inactive': 'Pasif',
  'common.off': 'Kapalı',
  'common.loading': 'Yükleniyor…',
  'common.yes': 'Evet',
  'common.no': 'Hayır',
  'common.fetching': 'Alınıyor…',
  'common.lang.tr': 'Türkçe',
  'common.lang.en': 'İngilizce',
  'common.lang.fr': 'Fransızca',
  'common.lang.ar': 'Arapça',
  'common.lang.zh': 'Çince',
  'common.lang.ru': 'Rusça',

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
  'theme.blueGlass': 'Mavi Cam',
  'theme.greenGlass': 'Yeşil Cam',
  'theme.redGlass': 'Kırmızı Cam',
  'theme.purpleGlass': 'Mor Cam',
  'theme.darkGlass': 'Koyu Cam',

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
  'settings.tile.alarm': 'Alarm kur',
  'settings.tile.sleepTimer': 'Uyku zamanlayıcısı',
  'settings.tile.clearAll': 'Tüm ayarları sil',
  'settings.tile.clearAll.sub': 'Playlist, önbellek ve tercihleri sıfırla',
  'settings.tile.theme': 'Tema',
  'settings.tile.layout': 'Yerleşim',
  'settings.tile.liveBuffer': 'Düşük Gecikme (Buffer)',
  'settings.tile.liveBuffer.sub': '@n saniye',
  'settings.tile.launchBoot': 'Cihaz Açıldığında Başlat',
  'settings.tile.bgPlayback': 'Arka Planda Oynatma',
  'settings.tile.miniPlayerHome': 'Küçük ekran (PiP)',
  'settings.tile.miniPlayerHome.subTv': 'Yalnızca telefon yerleşiminde',
  'settings.tile.miniPlayerHome.hintTv':
      'Bu özellik Android telefon yerleşiminde kullanılır.',
  'settings.tile.miniPlayerHome.subOn':
      'Açık — ana ekrana dönünce küçük pencerede izle (sürükle). Better/Exo.',
  'settings.tile.miniPlayerHome.subOff':
      'Kapalı — arka plana geçince yayın duraklar (arka plan oynatma ayrı).',
  'settings.tile.miniPlayerHome.subMk':
      'MediaKit ile otomatik PiP yok; varsayılan oynatıcıda kullanın.',
  'settings.tile.reduceBlur': 'Bulanıklığı Azalt (Hız)',
  'settings.tile.streamPreview': 'Yayın önizlemesi',
  'settings.tile.streamPreview.on':
      'Liste detayında sessiz önizleme (~1,8 sn sonra)',
  'settings.tile.streamPreview.off':
      'Kapalı — canlı / film / dizi listelerinde önizleme yok',
  'settings.tile.streamPreview.tvLocked':
      'TV’de de Ayarlar’dan açıp kapatabilirsiniz',
  'settings.tile.defaultPlayer': 'Varsayılan Oynatıcı',
  'settings.tile.useMediaKit': 'MediaKit (mpv) kullan',
  'settings.tile.useMediaKit.subOn':
      'Açık — film ve dizi MediaKit ile; canlı TV her zaman Better Player ile başlar',
  'settings.tile.useMediaKit.subOff':
      'Kapalı — film, dizi ve canlı Better/Exo; MediaKit yalnızca OSD veya hata yedeği',
  'settings.tile.mediaKitHwdec': 'Donanım hızlandırma (MediaKit)',
  'settings.tile.mediaKitHwdec.subBalanced':
      'Dengeli — mediacodec-copy (önerilen)',
  'settings.tile.mediaKitHwdec.subLowPower':
      'Düşük güç / eski TV kutusu — mediacodec',
  'settings.tile.videoDecoder': 'Video kod çözücü (Android)',
  'settings.tile.about': 'Hakkında',
  'settings.tile.about.loading': 'Sürüm yükleniyor…',
  'settings.tile.about.sub': 'Mina IPTV Player @v',
  'settings.tile.help': 'Yardım & Destek',
  'settings.tile.help.sub': 'Sorun bildirin veya yardım alın',
  'settings.tile.privacy': 'Gizlilik politikası',
  'settings.tile.privacy.sub':
      'GitHub: furkangumrukcu07/mina_iptv_player',
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
      '• Oynatıcı: canlıda Better Player (Exo); film/dizide varsayılan MediaKit (mpv, ayarlanabilir)\n'
      '• XMLTV (EPG), canlı tampon, Android kod çözücü ve MediaKit donanım modu seçenekleri\n'
      '• Cam temalar, bulanık efekt; otomatik yenileme, arka plan oynatma, uyku zamanlayıcısı, alarm\n'
      '• PiP (Better, telefon), kayıt (desteklenen ortamlarda), VOD’da ses/altyazı (Better)\n'
      '• Play: galeri READ_MEDIA izinleri yok; varsayılan tema Varsayılan\n',
  'settings.alarmNotSet': 'Kurulu değil',
  'settings.alarmDailyAt': 'Her gün @time',
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
  'settings.dialog.layoutTitle': 'Cihaz modu',
  'settings.dialog.refreshTitle': 'İçerikleri Yenile',
  'settings.dialog.refreshBody':
      'İçerikler şimdi yenilenecek. Ayrıca otomatik yenileme sıklığını seçmek ister misiniz?',
  'settings.dialog.refresh.autoOff': 'Otomatik yenileme kapalı',
  'settings.dialog.refresh.every3': '3 günde bir yenile',
  'settings.dialog.refresh.every7': 'Haftada bir yenile',
  'settings.dialog.refresh.nowOnly': 'Sadece şimdi yenile',
  'settings.dialog.alarmTitle': 'Alarm',
  'settings.dialog.alarmBody':
      'Uygulama içi hatırlatıcı saati seçin. Sistem alarmı için cihaz saat uygulamasını da kullanabilirsiniz.',
  'settings.dialog.alarmRemove': 'Kaldır',
  'settings.dialog.alarmPick': 'Saat seç',
  'settings.dialog.clearTitle': 'Tüm ayarları sil',
  'settings.dialog.clearBody':
      'Playlist bilgisi, önbellek, favoriler ve uygulama tercihleri sıfırlanacak. Emin misiniz?',
  'settings.dialog.xmltvTitle': 'XMLTV (EPG)',
  'settings.dialog.xmltv.hint': 'https://…/epg.xml',
  'settings.dialog.xmltv.label': 'EPG URL',
  'settings.dialog.bufferTitle': 'Canlı yayın tamponu',
  'settings.dialog.bufferSlider': '@n saniye',
  'settings.dialog.changelogTitle': 'Sürüm notları',
  'settings.dialog.changelogBody': 'v1.2.7\n'
      '• Oynatıcı: canlı yayınlar Better Player; film/dizi varsayılan olarak MediaKit (mpv) — ayarla kapatılabilir\n'
      '• MediaKit (Android): VideoController kurulum sırası düzeltildi (VOD çökme riski azaltıldı)\n'
      '• MediaKit: donanım çözücü modu (Dengeli / Düşük güç), libmpv performans ve tampon ayarları\n'
      '• Ayarlar: MediaKit ve yayın önizlemesi varsayılan açık; “tüm ayarları sil” sonrası da açık kalır\n'
      '• Canlı + Better OSD: ses ve altyazı düğmeleri yalnızca VOD’da\n\n'
      'Uygulama özellikleri (güncel)\n'
      '• Canlı TV, film ve dizi; M3U (URL/dosya) ve Xtream (player_api) playlist\n'
      '• Android TV, telefon ve tablet yerleşimleri; çoklu dil (TR/EN ve ek yerelleştirmeler)\n'
      '• Kanal ve VOD listelerinde arama, kategori, favoriler\n'
      '• Liste detayında sessiz yayın önizlemesi; tam ekran oynatıcı (Better + isteğe bağlı MediaKit)\n'
      '• Canlıda Better; VOD’da MediaKit (ayar açıkken), OSD’den yedek motora geçiş, TV canlıda takılma yedeği\n'
      '• XMLTV (EPG), canlı tampon, Android yazılım/donanım kod çözücü tercihleri\n'
      '• Cam temalar, bulanık cam; otomatik içerik yenileme, arka planda oynatma\n'
      '• Uyku zamanlayıcısı, uygulama içi alarm; PiP (Better, telefon)\n'
      '• Kayıt (desteklenen ortamlarda); VOD’da Better ile ses/altyazı izi seçimi\n'
      '• Play: READ_MEDIA galeri izinleri yok; özel galeri arka planı kaldırıldı; varsayılan tema Varsayılan\n\n'
      'Önceki sürümler\n'
      'v1.2.6 — READ_MEDIA manifest kaldırma, özel arka plan kaldırıldı, varsayılan tema Varsayılan\n'
      'v1.1.0 — package_info sürümü; canlı kesilince Oynat ile aynı kanal; ses/parlaklık jesti ve OSD\n'
      'v1.0.7 — Glass diyaloglar; TV canlı tampon ve MediaKit yedek\n'
      'v1.0.5 — TV odak ve kaydırma; üst çubuk geri kaldırıldı\n'
      'v1.0.0 — İlk sürüm, cam arayüz\n',
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
  'settings.xtream.user': 'Kullanıcı:',
  'settings.xtream.status': 'Durum:',
  'settings.xtream.expiry': 'Bitiş Tarihi:',
  'settings.xtream.connections': 'Aktif Bağlantı:',
  'settings.xtream.trial': 'Deneme Hesabı:',
  'settings.xtream.unlimited': 'Süresiz',
  'settings.xtreamFooter.line': 'Xtream: @user · @host',
  'settings.snackbar.alarm': 'Alarm',
  'settings.snackbar.alarmSaved':
      'Hatırlatıcı kaydedildi. Sistem alarmı için cihazınızın saat uygulamasını da kullanabilirsiniz.',
  'settings.snackbar.alarmCleared': 'Alarm kaldırıldı.',
  'settings.snackbar.settings': 'Ayarlar',
  'settings.snackbar.cleared': 'Tüm veriler temizlendi.',
  'settings.snackbar.clearFailed': 'Temizlenemedi: @e',
  'settings.snackbar.subtitles': 'Altyazı',
  'settings.snackbar.subtitlesSoon':
      'Altyazı görünümü özelleştirmesi yakında eklenecek.',
  'settings.snackbar.report': 'Sorun bildir',
  'settings.snackbar.reportFail':
      'E-posta uygulaması açılamadı. Adres: furkangumrukcu@gmail.com',
  'settings.snackbar.reportManual':
      'furkangumrukcu@gmail.com adresine yazabilirsiniz.',
  'settings.mail.subject': 'Mina IPTV — Sorun bildirimi',
  'settings.mail.body': 'Cihaz / sürüm:\n\nSorun açıklaması:\n',

  // Playlist setup
  'playlist.title': 'Playlist kurulumu',
  'playlist.sourceTitle': 'Kaynak Seçimi',
  'playlist.sourceSubtitle': 'M3U URL, yerel dosya veya Xtream hesabı.',
  'playlist.loadList': 'Listeyi Yükle',
  'playlist.m3uUrl': 'M3U URL',
  'playlist.pickFile': 'Dosya Seç',
  'playlist.noFile': '.m3u / .m3u8 dosyası seçilmedi',
  'playlist.xtream.server': 'Sunucu Adresi',
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
  'playlist.label.localM3u': 'Yerel M3U',
  'playlist.error.emptyUrl': 'M3U URL boş olamaz',
  'playlist.error.xtream': 'Xtream bilgileri eksik',
  'playlist.merge.orphanCategory': 'Liste 2',
  'playlist.secondaryTitle': 'İkinci kaynak (isteğe bağlı)',
  'playlist.secondarySubtitle':
      'İkinci M3U veya Xtream yalnızca canlı TV kanallarını birincil listeye ekler; film/dizi birincil kaynaktan gelir.',
  'playlist.secondaryEnable': 'İkinci listeyi etkinleştir',
  'playlist.secondaryUrlHint': 'İkinci M3U URL',
  'playlist.error.secondaryXtream': 'İkinci Xtream bilgileri eksik',
  'playlist.error.secondaryUrl': 'İkinci M3U URL boş olamaz',

  // Player (TV / controls)
  'player.liveBadge': 'CANLI',
  'player.epgLoading': 'EPG yükleniyor…',
  'player.fit.contain': 'Sığdır',
  'player.fit.cover': 'Doldur',
  'player.fit.fill': 'Ger',
  'player.fit.label': 'Görünüm',
  'player.tooltip.prevCh': 'Önceki kanal',
  'player.tooltip.nextCh': 'Sonraki kanal',
  'player.tooltip.rewind': '15 sn geri',
  'player.tooltip.forward': '15 sn ileri',
  'player.tooltip.pause': 'Duraklat',
  'player.tooltip.play': 'Oynat',
  'player.tooltip.favOff': 'Favorilere ekle',
  'player.tooltip.favOn': 'Favorilerden çıkar',
  'player.tooltip.fit': 'Görünüm: @fit',
  'player.tooltip.quality': 'Yayın Kalitesi',
  'player.tooltip.audio': 'Ses Kaynağı',
  'player.tooltip.subtitle': 'Altyazı',
  'player.tooltip.volume': 'Ses Seviyesi',
  'player.tooltip.record': 'Yayın Kaydet',
  'player.tooltip.recordStop': 'Kaydı Durdur',
  'player.tooltip.backupPlayer': 'Yedek oynatıcıya geç (MediaKit)',
  'player.tooltip.toMediaKit': 'MediaKit ile oynat (M)',
  'player.tooltip.toBetter': 'Better Player ile oynat (B)',
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
  'player.loading.decoder': 'Kod çözücü hatası düzeltiliyor (Adım @step)...',
  'player.loading.stream': 'Akış açılıyor...',
  'player.notReady': 'Oynatıcı hazır değil',
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
  'player.snackbar.audioChanged': 'Ses değiştirildi',
  'player.snackbar.subtitleChanged': 'Altyazı değiştirildi',
  'player.snackbar.qualityChanged': 'Kalite değiştirildi',
  'player.track.channel': 'Kanal @n',
};

const Map<String, String> _en = {
  'app.title': 'Mina IPTV Player',
  'home.live': 'Live TV',
  'home.live.subtitle': 'Live broadcasts',
  'home.films': 'Movies',
  'home.films.subtitle': 'Movies & series',
  'home.series': 'Series',
  'home.series.subtitle': 'TV series',
  'home.favorites': 'Favorites',
  'home.header.brandTop': 'Mina',
  'home.header.brandBottom': 'IPTV Player',
  'splash.preparing': 'Preparing your library…',
  'browse.films': 'Movies',
  'browse.series': 'Series',
  'browse.favorites': 'Favorites',
  'browse.empty': 'No results found.',
  'browse.pickItem': 'Select an item',
  'browse.tab.category': 'Category',
  'browse.tab.detail': 'Details',
  'browse.categoriesHeader': 'Categories',
  'browse.seriesShort': 'Series',
  'browse.season': 'Season',
  'browse.episodes': 'Episodes',
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
  'channels.search': 'Search channels…',
  'channels.searchDialogTitle': 'Search channels',
  'channels.searchSubmit': 'Search',
  'channels.title': 'Channels',
  'channels.empty': 'No channels found.',
  'channels.pick': 'Select a channel',
  'channels.tab.categories': 'Categories',
  'channels.tab.channels': 'Channels',
  'channels.tab.detail': 'Details',
  'channels.allChannels': 'All channels',
  'common.play': 'Play',
  'common.notPlayable': 'Not playable',
  'common.favorite': 'Favorite',
  'common.back': 'Back',
  'common.ok': 'OK',
  'common.cancel': 'Cancel',
  'common.close': 'Close',
  'common.save': 'Save',
  'common.delete': 'Delete',
  'common.clear': 'Clear',
  'common.active': 'On',
  'common.inactive': 'Off',
  'common.off': 'Off',
  'common.loading': 'Loading…',
  'common.yes': 'Yes',
  'common.no': 'No',
  'common.fetching': 'Fetching…',
  'common.lang.tr': 'Turkish',
  'common.lang.en': 'English',
  'common.lang.fr': 'French',
  'common.lang.ar': 'Arabic',
  'common.lang.zh': 'Chinese',
  'common.lang.ru': 'Russian',
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
  'theme.blueGlass': 'Blue glass',
  'theme.greenGlass': 'Green glass',
  'theme.redGlass': 'Red glass',
  'theme.purpleGlass': 'Purple glass',
  'theme.darkGlass': 'Dark glass',
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
  'settings.tile.alarm': 'Alarm',
  'settings.tile.sleepTimer': 'Sleep timer',
  'settings.tile.clearAll': 'Erase all settings',
  'settings.tile.clearAll.sub': 'Reset playlist, cache, and preferences',
  'settings.tile.theme': 'Theme',
  'settings.tile.layout': 'Layout',
  'settings.tile.liveBuffer': 'Low latency (buffer)',
  'settings.tile.liveBuffer.sub': '@n seconds',
  'settings.tile.launchBoot': 'Launch when device starts',
  'settings.tile.bgPlayback': 'Background playback',
  'settings.tile.miniPlayerHome': 'Mini player (PiP)',
  'settings.tile.miniPlayerHome.subTv': 'Phone layout only',
  'settings.tile.miniPlayerHome.hintTv':
      'This option is for Android phone layout.',
  'settings.tile.miniPlayerHome.subOn':
      'On — return home for a draggable mini window (Better/Exo).',
  'settings.tile.miniPlayerHome.subOff':
      'Off — playback pauses when leaving the app (unless background playback is on).',
  'settings.tile.miniPlayerHome.subMk':
      'Auto PiP is not available with MediaKit; use the default player.',
  'settings.tile.reduceBlur': 'Reduce blur (speed)',
  'settings.tile.streamPreview': 'Stream preview',
  'settings.tile.streamPreview.on':
      'Silent preview in list details (~after 1.8 s)',
  'settings.tile.streamPreview.off':
      'Off — no preview in live / movie / series lists',
  'settings.tile.streamPreview.tvLocked':
      'On TV you can turn this on or off in Settings',
  'settings.tile.defaultPlayer': 'Default Player',
  'settings.tile.useMediaKit': 'Use MediaKit (mpv)',
  'settings.tile.useMediaKit.subOn':
      'On — movies & series use MediaKit; live TV always starts in Better Player',
  'settings.tile.useMediaKit.subOff':
      'Off — movies, series, and live use Better/Exo; MediaKit only as backup',
  'settings.tile.mediaKitHwdec': 'Hardware acceleration (MediaKit)',
  'settings.tile.mediaKitHwdec.subBalanced':
      'Balanced — mediacodec-copy (recommended)',
  'settings.tile.mediaKitHwdec.subLowPower':
      'Low power / older TV box — mediacodec',
  'settings.tile.videoDecoder': 'Video decoder (Android)',
  'settings.tile.about': 'About',
  'settings.tile.about.loading': 'Loading version…',
  'settings.tile.about.sub': 'Mina IPTV Player @v',
  'settings.tile.help': 'Help & support',
  'settings.tile.help.sub': 'Report issues or get help',
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
      '• Glass themes, blur; auto refresh, background playback, sleep timer, alarm\n'
      '• PiP (Better, phone), recording where supported; VOD audio/subtitles (Better)\n'
      '• Play: no READ_MEDIA gallery permissions; default theme is Default\n',
  'settings.alarmNotSet': 'Not set',
  'settings.alarmDailyAt': 'Every day at @time',
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
  'settings.dialog.layoutTitle': 'Device mode',
  'settings.dialog.refreshTitle': 'Refresh content',
  'settings.dialog.refreshBody':
      'Content will refresh now. Do you also want to set how often to refresh automatically?',
  'settings.dialog.refresh.autoOff': 'Auto refresh off',
  'settings.dialog.refresh.every3': 'Refresh every 3 days',
  'settings.dialog.refresh.every7': 'Refresh every week',
  'settings.dialog.refresh.nowOnly': 'Refresh once now',
  'settings.dialog.alarmTitle': 'Alarm',
  'settings.dialog.alarmBody':
      'Pick an in-app reminder time. You can also use the system clock app for alarms.',
  'settings.dialog.alarmRemove': 'Remove',
  'settings.dialog.alarmPick': 'Pick time',
  'settings.dialog.clearTitle': 'Erase all settings',
  'settings.dialog.clearBody':
      'Playlist data, cache, favorites, and preferences will be reset. Continue?',
  'settings.dialog.xmltvTitle': 'XMLTV (EPG)',
  'settings.dialog.xmltv.hint': 'https://…/epg.xml',
  'settings.dialog.xmltv.label': 'EPG URL',
  'settings.dialog.bufferTitle': 'Live stream buffer',
  'settings.dialog.bufferSlider': '@n seconds',
  'settings.dialog.changelogTitle': 'Release notes',
  'settings.dialog.changelogBody': 'v1.2.7\n'
      '• Playback: live TV uses Better Player; movies/series default to MediaKit (mpv) — optional in Settings\n'
      '• MediaKit (Android): fixed VideoController init order (reduced VOD crash risk)\n'
      '• MediaKit: hardware decoder mode (Balanced / Low power), libmpv performance and buffer tuning\n'
      '• Settings: MediaKit and stream preview default ON; stay ON after “erase all settings”\n'
      '• Live + Better OSD: audio and subtitle buttons only for VOD\n\n'
      'App features (current)\n'
      '• Live TV, movies, and series; M3U (URL/file) and Xtream (player_api) playlists\n'
      '• Android TV, phone, and tablet layouts; multi-language (EN/TR and partial locales)\n'
      '• Channel and VOD lists: search, categories, favorites\n'
      '• Silent stream preview in details; fullscreen player (Better + optional MediaKit)\n'
      '• Live: Better; VOD: MediaKit when enabled, OSD backup engine switch, TV live stall fallback\n'
      '• XMLTV (EPG), live buffer, Android software/hardware decoder options\n'
      '• Glass themes and blur; automatic content refresh, background playback\n'
      '• Sleep timer, in-app alarm; PiP (Better, phone)\n'
      '• Recording where supported; VOD audio/subtitle tracks with Better\n'
      '• Play: no READ_MEDIA gallery permissions; custom gallery background removed; default theme Default\n\n'
      'Earlier releases\n'
      'v1.2.6 — READ_MEDIA manifest removal, custom background removed, default theme Default\n'
      'v1.1.0 — package_info version; Play reloads same live channel; volume/brightness gestures\n'
      'v1.0.7 — Glass dialogs; TV live buffering and MediaKit fallback\n'
      'v1.0.5 — TV focus/scrolling; top-bar back removed\n'
      'v1.0.0 — Initial glass UI release\n',
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
  'settings.xtream.user': 'User:',
  'settings.xtream.status': 'Status:',
  'settings.xtream.expiry': 'Expires:',
  'settings.xtream.connections': 'Active connections:',
  'settings.xtream.trial': 'Trial account:',
  'settings.xtream.unlimited': 'Unlimited',
  'settings.xtreamFooter.line': 'Xtream: @user · @host',
  'settings.snackbar.alarm': 'Alarm',
  'settings.snackbar.alarmSaved':
      'Reminder saved. You can also use your device clock app for system alarms.',
  'settings.snackbar.alarmCleared': 'Alarm removed.',
  'settings.snackbar.settings': 'Settings',
  'settings.snackbar.cleared': 'All data cleared.',
  'settings.snackbar.clearFailed': 'Could not clear: @e',
  'settings.snackbar.subtitles': 'Subtitles',
  'settings.snackbar.subtitlesSoon':
      'Subtitle appearance options are coming soon.',
  'settings.snackbar.report': 'Report issue',
  'settings.snackbar.reportFail':
      'Could not open email. Address: furkangumrukcu@gmail.com',
  'settings.snackbar.reportManual': 'You can email furkangumrukcu@gmail.com',
  'settings.mail.subject': 'Mina IPTV — Issue report',
  'settings.mail.body': 'Device / version:\n\nDescribe the issue:\n',
  'playlist.title': 'Playlist setup',
  'playlist.sourceTitle': 'Choose source',
  'playlist.sourceSubtitle': 'M3U URL, local file, or Xtream account.',
  'playlist.loadList': 'Load playlist',
  'playlist.m3uUrl': 'M3U URL',
  'playlist.pickFile': 'Choose file',
  'playlist.noFile': 'No .m3u / .m3u8 file selected',
  'playlist.xtream.server': 'Server URL',
  'playlist.xtream.user': 'Username',
  'playlist.xtream.pass': 'Password',
  'playlist.xtream.hint':
      'You can paste URLs that include player_api.php directly.',
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
  'playlist.secondaryEnable': 'Enable second playlist',
  'playlist.secondaryUrlHint': 'Second M3U URL',
  'playlist.error.secondaryXtream': 'Incomplete second Xtream credentials',
  'playlist.error.secondaryUrl': 'Second M3U URL cannot be empty',
  'player.liveBadge': 'LIVE',
  'player.epgLoading': 'Loading EPG…',
  'player.fit.contain': 'Fit',
  'player.fit.cover': 'Fill',
  'player.fit.fill': 'Stretch',
  'player.fit.label': 'View',
  'player.tooltip.prevCh': 'Previous channel',
  'player.tooltip.nextCh': 'Next channel',
  'player.tooltip.rewind': '15 s back',
  'player.tooltip.forward': '15 s forward',
  'player.tooltip.pause': 'Pause',
  'player.tooltip.play': 'Play',
  'player.tooltip.favOff': 'Add to favorites',
  'player.tooltip.favOn': 'Remove from favorites',
  'player.tooltip.fit': 'View: @fit',
  'player.tooltip.quality': 'Stream quality',
  'player.tooltip.audio': 'Audio track',
  'player.tooltip.subtitle': 'Subtitles',
  'player.tooltip.volume': 'Volume',
  'player.tooltip.record': 'Record broadcast',
  'player.tooltip.recordStop': 'Stop recording',
  'player.tooltip.backupPlayer': 'Switch to backup player (MediaKit)',
  'player.tooltip.toMediaKit': 'Play with MediaKit (M)',
  'player.tooltip.toBetter': 'Play with Better Player (B)',
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
  'player.loading.decoder': 'Fixing decoder error (step @step)...',
  'player.loading.stream': 'Opening stream…',
  'player.notReady': 'Player is not ready',
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
  'player.snackbar.audioChanged': 'Audio changed',
  'player.snackbar.subtitleChanged': 'Subtitles changed',
  'player.snackbar.qualityChanged': 'Quality changed',
  'player.track.channel': 'Channel @n',
};
