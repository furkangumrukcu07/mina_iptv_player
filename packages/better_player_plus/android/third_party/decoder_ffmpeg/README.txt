FFmpeg ses uzantısı (AndroidX Media3, resmi repo — Jellyfin Maven değil)
================================================================================

Google, `media3-decoder-ffmpeg` modülünü Maven’da yayınlamıyor. Bu klasöre,
androidx/media deposundan kendiniz derlediğiniz AAR dosyasını koyun.

Sürüm: better_player_plus/android/build.gradle.kts içindeki media3Version ile
aynı release etiketini kullanın (ör. 1.8.0).

1) Depoyu klonlayın (örnek):
   git clone https://github.com/androidx/media.git
   cd media && git checkout release

2) libraries/decoder_ffmpeg/README.md adımlarını izleyin:
   - Android NDK (README’de önerilen sürüm)
   - FFMPEG_MODULE_PATH, NDK_PATH, HOST_PLATFORM, ANDROID_ABI
   - ENABLED_DECODERS — IPTV ses için örnek:
     ac3 eac3 dts opus vorbis flac aac mp3
   - Donanımın 4K/H.264’te zorlandığı cihazlarda (ör. bazı Xiaomi telefonlar) yazılım video için
     Media3’ün yüklemeyi denediği ExperimentalFfmpegVideoRenderer kullanılabilir; build_ffmpeg.sh
     içinde video codec’lerini ekleyin (ör. h264 hevc — bellek ve CPU maliyeti yüksek).
   - jni/build_ffmpeg.sh çalıştırın

3) Media3 kökünden decoder modülünü derleyin; çıkan AAR’ı buraya kopyalayın:
   Örnek hedef dosya adı (Gradle otomatik tanır):
   lib-decoder-ffmpeg-release.aar
   veya
   decoder-ffmpeg-release.aar

   Gradle çıktısı genelde şu dizindedir:
   libraries/decoder_ffmpeg/build/outputs/aar/

4) Projeyi yeniden derleyin. AAR yoksa oynatıcı yine çalışır; FFmpeg yolu
   yalnızca AAR classpath’e eklendiğinde kullanılır.

Lisans: FFmpeg ve bu modül için androidx/media ve FFmpeg lisanslarını okuyun.
