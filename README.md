# Mina IPTV Player

Android TV ve telefon için Flutter ile geliştirilmiş IPTV oynatıcı. M3U / M3U8 URL veya yerel dosya, Xtream Codes API, canlı TV, VOD, dizi gözatma, XMLTV (EPG), Better Player (ExoPlayer) ve MediaKit desteği sunar.

## Gereksinimler

- [Flutter](https://docs.flutter.dev/get-started/install) (SDK sürümü `pubspec.yaml` ile uyumlu)
- Android: API ve Gradle sürümleri `android/` yapılandırmasında tanımlıdır

## Çalıştırma

```bash
flutter pub get
flutter run
```

Release APK örneği:

```bash
flutter build apk --release
```

## Gizlilik

Ayrıntılar için depo kökündeki [GIZLILIK_POLITIKASI.md](GIZLILIK_POLITIKASI.md) dosyasına bakın.

## Yerel paket

`better_player_plus` bu repoda `packages/better_player_plus` altında yol bağımlılığı olarak kullanılır.

## Lisans

Apache License 2.0 — ayrıntılar için [LICENSE](LICENSE) dosyası.
