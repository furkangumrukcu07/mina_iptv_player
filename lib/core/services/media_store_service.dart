import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Android `MediaStore.Video` köprüsü — kayıt/indirme tamamlandığında
/// dosyayı Galeri uygulamalarının görebildiği public `Movies/MinaIPTV`
/// dizinine kopyalar.
///
/// * Android 10+ (Q): scoped storage; `WRITE_EXTERNAL_STORAGE` izni
///   gerektirmez. Play Store policy review'da risk yok.
/// * Android 9 ve altı: `MediaScannerConnection` ile mevcut app-scoped
///   yolu tarayıcıya bildirir; gerçek kopyalama yok (kullanıcı
///   genelde Dosyalar uygulamasından erişir).
class MediaStoreService extends GetxService {
  static MediaStoreService get to => Get.find<MediaStoreService>();

  static const _channel = MethodChannel('mina.player/media_store');

  /// Dosyayı public Movies/[subFolder] altına kopyalar.
  /// Döner: kullanıcı-dostu hedef yol (`Movies/MinaIPTV/REC_...`) ya da
  /// işlem başarısızsa null.
  Future<String?> saveVideoToGallery({
    required String sourcePath,
    required String displayName,
    String subFolder = 'MinaIPTV',
    String? mimeType,
  }) async {
    try {
      final res = await _channel.invokeMethod<String?>('saveToGallery', {
        'sourcePath': sourcePath,
        'displayName': displayName,
        'subFolder': subFolder,
        if (mimeType != null) 'mimeType': mimeType,
      });
      return res;
    } on PlatformException {
      return null;
    }
  }

  /// Sistem paylaş menüsünü açar — WhatsApp, Drive, Google Photos vb.
  Future<bool> shareFile({
    required String path,
    String? title,
    String? mimeType,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareFile', {
        'path': path,
        if (title != null) 'title': title,
        if (mimeType != null) 'mimeType': mimeType,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Dosyayı sistem `Intent.ACTION_VIEW` ile açar — Android seçicisi
  /// çıkar, kullanıcı VLC / MX Player / Galeri vb. seçer. FileProvider
  /// content URI kullanılır (Android 7+ FileUriExposedException'a takılmaz).
  Future<bool> openFile({
    required String path,
    String? title,
    String? mimeType,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openFile', {
        'path': path,
        if (title != null) 'title': title,
        if (mimeType != null) 'mimeType': mimeType,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Bir klasörü Files / DocumentsUI uygulamasında açar.
  /// Android'in SAF API'sini kullanır — `ACTION_OPEN_DOCUMENT_TREE`
  /// veya intent başarısız olursa `ACTION_VIEW` ile dener.
  Future<bool> openFolder({required String path}) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openFolder', {
        'path': path,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }
}
