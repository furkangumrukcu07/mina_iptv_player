import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Rect;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/playlist_storage.dart';
import 'mina_secure_storage.dart';

/// `mina_backup.dat` – Mina Pro ayarları + M3U/Xtream kimlik bilgileri + yerel
/// kaydedilmiş playlist dosyaları için AES‑256‑CBC ile şifrelenmiş tek dosyalık
/// yedek/geri yükleme altyapısı.
///
/// Tasarım hedefleri:
/// - **Hiçbir tehlikeli izin gerekmez**: yazma için `share_plus` (sistem
///   paylaşım sayfası), okuma için `file_picker` (kullanıcı tek dosya seçer).
/// - **Tek dosya, tek format**: `mina_backup.dat`. Magic: `MNB1` (4 bayt) +
///   IV (16 bayt) + AES‑256‑CBC ciphertext (PKCS7).
/// - **Hassas veri**: SecureStorage’daki Xtream/M3U kimlik bilgileri ve yerel
///   `saved_playlist*.m3u` dosyaları da yedeklenir.
class BackupService {
  BackupService({
    SharedPreferences? prefs,
    FlutterSecureStorage? storage,
  })  : _prefsOverride = prefs,
        _storage = storage ?? MinaSecureStorage.instance;

  final SharedPreferences? _prefsOverride;
  final FlutterSecureStorage _storage;

  /// Yedeklenen dosyanın varsayılan adı (`Share` sayfasında ve `file_picker`
  /// filtresinde kullanılır).
  static const String backupFileName = 'mina_backup.dat';

  /// Dosya başlığı – tipi anlamak ve geriye dönük uyumluluk için.
  static const String _magic = 'MNB1';
  static const int _backupSchemaVersion = 1;

  /// AES‑256 (32 byte) anahtarı için sabit tohum. Anahtar, bu tohumun SHA‑256
  /// özetidir; böylece düz metinde 32 byte rastgele görünümlü bir anahtar
  /// tutmuyoruz, üretim sırasında türetiyoruz. Cihaz dışı bir saldırgan bu
  /// uygulamayı tersine mühendislikle açabilirse dosyayı çözebilir; tüm amaç,
  /// dosyanın gözle / metin editörüyle okunmasını ve farkında olmayan
  /// kullanıcıların paylaştığı yedeklerde Xtream şifresinin ortaya çıkmasını
  /// önlemektir. **Anahtarı production’da değiştirme**, aksi halde mevcut
  /// yedekler bozulur.
  static const String _aesKeySeed = 'mina-pro::backup::v1::aes-256-cbc::seed';

  /// SharedPreferences içinden yedeğe dahil edilecek key prefix’i. Tüm Mina
  /// ayarları (favori listeleri, watch‑progress, kategori gizleme, OSD süresi,
  /// EPG, vs.) zaten bu prefix’i kullanıyor.
  static const String _prefsPrefix = 'mina_';

  /// Cihaza özgü anahtarlar — yedeğe **dahil edilmez** ve geri yüklemede
  /// **dokunulmaz**. Yerleşim modu (mobil/tablet/TV) cihaz türüne göre
  /// belirlenir; telefonda alınan yedeği TV'ye geri yüklerken TV'nin modunu
  /// yanlışlıkla "mobil"e düşürmemek için bu anahtar her cihazda kendi
  /// değerinde kalır.
  static const Set<String> _deviceLocalKeys = <String>{
    'mina_settings_layout_mode',
    // Oynatma motoru tercihleri
    'mina_settings_use_media_kit',
    'mina_settings_live_use_media_kit',
    'mina_settings_engine_user_chosen_v1',
    // Donanım hızlandırma
    'mina_settings_media_kit_low_power_hwdec',
    // Video kod çözücü
    'mina_settings_prefer_software_decoder',
    // Yayın formatı
    'mina_settings_live_stream_format_v1',
    'mina_settings_live_stream_format_auto_v1',
    'mina_settings_live_stream_format_ts_forced_lowend_v1',
    // TV Lite (sade grafik)
    'mina_settings_tv_lite',
    'mina_settings_tv_lite_tv_forced',
    // Düşük donanımlı cihaz modu
    'mina_settings_low_end_device_mode',
    'mina_settings_low_end_suggest_dismissed',
    // EPG Son Güncellenme zamanı cihaza özeldir, yedeğe dahil olmaz
    'mina_settings_last_refresh_time',
  };

  /// FlutterSecureStorage’daki M3U / Xtream kimlik bilgisi anahtar tabanları
  /// (PlaylistRepositoryImpl ile birebir aynı – kaynak: o sınıfın `_k…`
  /// sabitleri). Her slot için bu tabanlardan üretilir.
  static const List<String> _secureSourceKeyBases = <String>[
    'mina_iptv_source_type',
    'mina_iptv_playlist_url',
    'mina_iptv_xtream_base_url',
    'mina_iptv_xtream_username',
    'mina_iptv_xtream_password',
  ];

  /// Slot başına devre dışı bayrağı ve kullanıcı etiketi — repo ile aynı
  /// adlandırma: slot N için `…_N` (slot 1 dahil `_1`).
  static const String _kSlotDisabled = 'mina_iptv_slot_disabled';
  static const String _kSlotName = 'mina_iptv_slot_name';

  /// Tüm slotlar (1..[kMaxPlaylistSlots]) için secure storage anahtarları.
  /// Slot 1 kaynak anahtarları sonek almaz; slot N≥2 `_N` sonekini alır —
  /// repo katmanıyla aynı. Devre dışı/etiket anahtarları her slotta `_N`.
  static List<String> get _secureKeys {
    final keys = <String>[];
    for (var slot = 1; slot <= kMaxPlaylistSlots; slot++) {
      final suffix = slot == 1 ? '' : '_$slot';
      for (final base in _secureSourceKeyBases) {
        keys.add('$base$suffix');
      }
      keys.add('${_kSlotDisabled}_$slot');
      keys.add('${_kSlotName}_$slot');
    }
    return keys;
  }

  /// Yerel olarak kaydedilmiş (local playlist sentinel) M3U dosya adı — slot
  /// başına `PlaylistRepositoryImpl._localM3uFileAt()` ile aynı.
  static String _localM3uFileNameForSlot(int slot) {
    final suffix = slot == 1 ? '' : '_$slot';
    return 'saved_playlist$suffix.m3u';
  }

  enc.Key get _aesKey =>
      enc.Key(Uint8List.fromList(sha256.convert(utf8.encode(_aesKeySeed)).bytes));

  /// Tüm yedek verisini JSON map olarak toplar (şifrelenmemiş). Bulut
  /// senkronu (AuthService → Firestore) bu map'i kullanır.
  Future<Map<String, dynamic>> collectBackupJson() => _collectBackupJson();

  /// JSON map'i yerel depolamaya (SharedPreferences + SecureStorage + yerel
  /// `.m3u`) uygular. Bulut geri yüklemesi (AuthService) bunu çağırır.
  Future<BackupImportSummary> applyBackupJson(Map<String, dynamic> data) =>
      _applyBackupJson(data);

  /// Tüm yedek verisini JSON’a topla.
  Future<Map<String, dynamic>> _collectBackupJson() async {
    final prefs = _prefsOverride ?? await SharedPreferences.getInstance();

    // SharedPreferences: sadece `mina_` prefix’li key’ler. Tip bilgisi de
    // restore sırasında doğru setter’ı çağırabilmek için tutuluyor.
    final prefsMap = <String, Map<String, Object?>>{};
    for (final k in prefs.getKeys()) {
      if (!k.startsWith(_prefsPrefix)) continue;
      if (_deviceLocalKeys.contains(k)) continue;
      final v = prefs.get(k);
      if (v == null) continue;
      if (v is bool) {
        prefsMap[k] = {'t': 'bool', 'v': v};
      } else if (v is int) {
        prefsMap[k] = {'t': 'int', 'v': v};
      } else if (v is double) {
        prefsMap[k] = {'t': 'double', 'v': v};
      } else if (v is String) {
        prefsMap[k] = {'t': 'string', 'v': v};
      } else if (v is List<String>) {
        prefsMap[k] = {'t': 'stringList', 'v': v};
      }
    }

    // SecureStorage: M3U/Xtream kimlik bilgileri + slot etiketleri / devre dışı
    // bayrakları. Tek `readAll()` turu — 32 slot × 7 anahtar için ayrı ayrı
    // okumaktan daha güvenilir (bazı cihazlarda keystore gecikmesi).
    final secureMap = <String, String>{};
    try {
      await MinaSecureStorage.ensureReady();
      final allSecure = await _storage.readAll();
      for (final k in _secureKeys) {
        final v = allSecure[k];
        if (v != null && v.isNotEmpty) secureMap[k] = v;
      }
    } catch (e) {
      debugPrint('BackupService: secure readAll failed, fallback: $e');
      for (final k in _secureKeys) {
        try {
          final v = await _storage.read(key: k);
          if (v != null && v.isNotEmpty) secureMap[k] = v;
        } catch (_) {}
      }
    }

    // Yerel `.m3u` dosyaları — slot 1..32 (yapıştırılmış / dosyadan içe aktarılan
    // listeler). Eski yedekler yalnızca slot 1–2 içeriyordu; geri yüklemede uyumluluk
    // korunur.
    final localM3uBySlot = <String, String>{};
    for (final slot in allPlaylistSlots()) {
      final body = await _readLocalM3uIfExists(_localM3uFileNameForSlot(slot));
      if (body != null) localM3uBySlot['$slot'] = body;
    }

    return <String, dynamic>{
      'v': _backupSchemaVersion,
      'app': 'mina_pro',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'prefs': prefsMap,
      'secure': secureMap,
      if (localM3uBySlot.isNotEmpty) 'localM3uBySlot': localM3uBySlot,
      // Eski yedek okuyucuları için slot 1–2 alanları (geriye dönük).
      if (localM3uBySlot.containsKey('1')) 'localM3u': localM3uBySlot['1'],
      if (localM3uBySlot.containsKey('2')) 'localM3u2': localM3uBySlot['2'],
    };
  }

  Future<String?> _readLocalM3uIfExists(String name) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/$name');
      if (!await f.exists()) return null;
      final body = await f.readAsString();
      if (body.trim().isEmpty) return null;
      return body;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLocalM3u(String name, String content) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/$name');
      await f.parent.create(recursive: true);
      await f.writeAsString(content, flush: true);
    } catch (e) {
      debugPrint('BackupService: local M3U write failed: $e');
    }
  }

  /// JSON → AES‑256‑CBC ciphertext (random IV). Çıktı bayt yığını:
  /// `MNB1` (4) + IV (16) + ciphertext (n).
  Uint8List _encryptJson(Map<String, dynamic> data) {
    final plain = utf8.encode(jsonEncode(data));
    final iv = _randomIv();
    final encrypter = enc.Encrypter(enc.AES(_aesKey, mode: enc.AESMode.cbc));
    final cipher = encrypter.encryptBytes(plain, iv: iv);

    final out = BytesBuilder(copy: false);
    out.add(utf8.encode(_magic));
    out.add(iv.bytes);
    out.add(cipher.bytes);
    return out.toBytes();
  }

  enc.IV _randomIv() {
    final rnd = Random.secure();
    return enc.IV(Uint8List.fromList(
      List<int>.generate(16, (_) => rnd.nextInt(256)),
    ));
  }

  /// `MNB1` + IV + ciphertext → JSON map. Format / şifre yanlışsa
  /// [BackupFormatException] fırlatılır.
  Map<String, dynamic> _decryptToJson(Uint8List bytes) {
    if (bytes.length < 4 + 16 + 16) {
      throw const BackupFormatException('Yedek dosyası çok küçük / bozuk.');
    }
    final magic = utf8.decode(bytes.sublist(0, 4), allowMalformed: true);
    if (magic != _magic) {
      throw const BackupFormatException(
        'Geçersiz yedek dosyası başlığı (Mina yedeği değil).',
      );
    }
    final iv = enc.IV(Uint8List.fromList(bytes.sublist(4, 20)));
    final cipher = enc.Encrypted(Uint8List.fromList(bytes.sublist(20)));
    final encrypter = enc.Encrypter(enc.AES(_aesKey, mode: enc.AESMode.cbc));
    try {
      final plain = encrypter.decryptBytes(cipher, iv: iv);
      final text = utf8.decode(plain);
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupFormatException('Yedek içeriği beklenmiyor.');
      }
      return decoded;
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException(
        'Yedek çözülemedi. Dosya bozuk olabilir veya başka bir uygulamadan.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Şifrelenmiş yedeği geçici dosyaya yazıp Android/iOS yerel paylaşım
  /// sayfasını aç. Kullanıcı dosyayı Drive’a, WhatsApp’a, e‑postaya, vb.
  /// gönderebilir – ek izin gerekmez.
  ///
  /// Geri dönen [BackupShareResult.status] ile UI mesajı verilebilir.
  Future<BackupShareResult> exportToShareSheet({
    Rect? sharePositionOrigin,
    String? subject,
  }) async {
    try {
      final data = await _collectBackupJson();
      final bytes = _encryptJson(data);

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$backupFileName');
      await file.writeAsBytes(bytes, flush: true);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              name: backupFileName,
              mimeType: 'application/octet-stream',
            ),
          ],
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      switch (result.status) {
        case ShareResultStatus.success:
          return const BackupShareResult.success();
        case ShareResultStatus.dismissed:
          return const BackupShareResult.dismissed();
        case ShareResultStatus.unavailable:
          return const BackupShareResult.failure(
            'Sistem paylaşım sayfası kullanılamıyor.',
          );
      }
    } catch (e, st) {
      debugPrint('BackupService.export failed: $e\n$st');
      return BackupShareResult.failure(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// `file_picker` üzerinden kullanıcıya tek bir `.dat` dosyası seçtir, çöz ve
  /// SharedPreferences + SecureStorage + yerel `.m3u` dosyalarını geri yükle.
  ///
  /// İptal edilirse [BackupImportResult.cancelled] döner.
  Future<BackupImportResult> importFromUserPickedFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
        dialogTitle: 'Mina yedeğini seç (.dat)',
      );
      if (picked == null || picked.files.isEmpty) {
        return const BackupImportResult.cancelled();
      }

      final f = picked.files.single;
      // Hem `withData` (mobil) hem path tabanlı (desktop) okuma fallback’i.
      Uint8List? bytes = f.bytes;
      if (bytes == null && f.path != null) {
        try {
          bytes = await File(f.path!).readAsBytes();
        } catch (_) {}
      }
      if (bytes == null || bytes.isEmpty) {
        return const BackupImportResult.failure(
          'Seçilen dosya okunamadı veya boş.',
        );
      }

      final data = _decryptToJson(bytes);
      final summary = await _applyBackupJson(data);
      return BackupImportResult.success(summary);
    } on BackupFormatException catch (e) {
      return BackupImportResult.failure(e.message);
    } catch (e, st) {
      debugPrint('BackupService.import failed: $e\n$st');
      return BackupImportResult.failure(e.toString());
    }
  }

  /// JSON map’i SharedPreferences + SecureStorage + yerel `.m3u` dosyalarına
  /// uygula. Mevcut `mina_*` anahtarları önce temizlenir – böylece eski
  /// yedekte olmayan bir ayar üzerine yazılmaz.
  Future<BackupImportSummary> _applyBackupJson(Map<String, dynamic> data) async {
    try {
      final prefs = _prefsOverride ?? await SharedPreferences.getInstance();

      var prefsCount = 0;
      var secureCount = 0;
      var m3uCount = 0;

    // 1) SharedPreferences: önce mevcut `mina_*` key’leri temizle. Cihaza özgü
    // anahtarlar (yerleşim modu) korunur — geri yükleme cihaz türünü
    // değiştirmemeli.
    final oldKeys = prefs
        .getKeys()
        .where((k) => k.startsWith(_prefsPrefix))
        .where((k) => !_deviceLocalKeys.contains(k))
        .toList(growable: false);
    for (final k in oldKeys) {
      await prefs.remove(k);
    }

    final prefsRaw = data['prefs'];
    if (prefsRaw is Map) {
      for (final entry in prefsRaw.entries) {
        final key = entry.key.toString();
        if (!key.startsWith(_prefsPrefix)) continue;
        if (_deviceLocalKeys.contains(key)) continue;
        final v = entry.value;
        if (v is! Map) continue;
        final type = v['t']?.toString();
        final value = v['v'];
        try {
          switch (type) {
            case 'bool':
              if (value is bool) {
                await prefs.setBool(key, value);
                prefsCount++;
              }
              break;
            case 'int':
              if (value is int) {
                await prefs.setInt(key, value);
                prefsCount++;
              } else if (value is num) {
                await prefs.setInt(key, value.toInt());
                prefsCount++;
              }
              break;
            case 'double':
              if (value is num) {
                await prefs.setDouble(key, value.toDouble());
                prefsCount++;
              }
              break;
            case 'string':
              if (value is String) {
                await prefs.setString(key, value);
                prefsCount++;
              }
              break;
            case 'stringList':
              if (value is List) {
                await prefs.setStringList(
                  key,
                  value.map((e) => e.toString()).toList(),
                );
                prefsCount++;
              }
              break;
          }
        } catch (e) {
          debugPrint('BackupService: skip key=$key err=$e');
        }
      }
    }

    // 2) SecureStorage: M3U / Xtream kimlik bilgileri.
    final secureRaw = data['secure'];
    if (secureRaw is Map) {
      await MinaSecureStorage.ensureReady();
      for (final k in _secureKeys) {
        try {
          final v = secureRaw[k];
          if (v is String && v.isNotEmpty) {
            await _storage.write(key: k, value: v);
            secureCount++;
          } else {
            await _storage.delete(key: k);
          }
        } catch (e) {
          debugPrint('BackupService: secure write failed $k err=$e');
        }
      }
    }

    // 3) Yerel `.m3u` dosyaları (varsa) — tüm slotlar.
    final restoredLocalSlots = <int>{};

    Future<void> restoreLocalSlot(int slot, String content) async {
      if (content.trim().isEmpty) return;
      await _writeLocalM3u(_localM3uFileNameForSlot(slot), content);
      restoredLocalSlots.add(slot);
      m3uCount++;
      // Büyük M3U yedeklerinde TV kutusunda UI thread'i nefes alsın.
      await Future<void>.delayed(Duration.zero);
    }

    final bySlotRaw = data['localM3uBySlot'];
    if (bySlotRaw is Map) {
      for (final entry in bySlotRaw.entries) {
        final slot = int.tryParse(entry.key.toString());
        final content = entry.value;
        if (slot == null || slot < 1 || slot > kMaxPlaylistSlots) continue;
        if (content is! String) continue;
        await restoreLocalSlot(slot, content);
      }
    } else {
      // Eski yedek formatı: yalnızca slot 1–2.
      final m3u1 = data['localM3u'];
      if (m3u1 is String) await restoreLocalSlot(1, m3u1);
      final m3u2 = data['localM3u2'];
      if (m3u2 is String) await restoreLocalSlot(2, m3u2);
    }

    // Yedekte olmayan slotların eski yerel dosyalarını temizle (tam geri yükleme).
    for (final slot in allPlaylistSlots()) {
      if (restoredLocalSlots.contains(slot)) continue;
      try {
        final dir = await getApplicationSupportDirectory();
        final f = File('${dir.path}/${_localM3uFileNameForSlot(slot)}');
        if (await f.exists()) await f.delete();
      } catch (e) {
        debugPrint('BackupService: local M3U cleanup slot=$slot err=$e');
      }
    }

    return BackupImportSummary(
      prefsCount: prefsCount,
      secureCount: secureCount,
      localM3uCount: m3uCount,
      createdAt: _parseCreatedAt(data['createdAt']),
    );
    } catch (e, st) {
      debugPrint('BackupService._applyBackupJson failed: $e\n$st');
      rethrow;
    }
  }

  DateTime? _parseCreatedAt(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatException: $message';
}

/// Paylaşım sayfası sonucu.
class BackupShareResult {
  const BackupShareResult._(this.status, [this.message]);
  const BackupShareResult.success() : this._(BackupShareStatus.success);
  const BackupShareResult.dismissed() : this._(BackupShareStatus.dismissed);
  const BackupShareResult.failure(String message)
      : this._(BackupShareStatus.failure, message);

  final BackupShareStatus status;
  final String? message;
}

enum BackupShareStatus { success, dismissed, failure }

/// Geri yükleme sonucu.
class BackupImportResult {
  const BackupImportResult._(this.status, {this.message, this.summary});
  const BackupImportResult.cancelled()
      : this._(BackupImportStatus.cancelled);
  const BackupImportResult.success(BackupImportSummary summary)
      : this._(BackupImportStatus.success, summary: summary);
  const BackupImportResult.failure(String message)
      : this._(BackupImportStatus.failure, message: message);

  final BackupImportStatus status;
  final String? message;
  final BackupImportSummary? summary;
}

enum BackupImportStatus { success, cancelled, failure }

class BackupImportSummary {
  const BackupImportSummary({
    required this.prefsCount,
    required this.secureCount,
    required this.localM3uCount,
    this.createdAt,
  });

  final int prefsCount;
  final int secureCount;
  final int localM3uCount;
  final DateTime? createdAt;
}
