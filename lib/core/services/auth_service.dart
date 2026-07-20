import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'admin_analytics_service.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app_settings_service.dart';
import '../../domain/repositories/playlist_repository.dart';
import 'backup_service.dart';
import 'firebase_bootstrap.dart';
import 'mina_telemetry_service.dart';
import '../platform/android_playback_soc_hints.dart';
import 'profiles_service.dart';
import 'licensing_service.dart';
import 'toast_service.dart';
import '../utils/device_info_util.dart';

/// Google ile giriş akışının sonucu.
enum GoogleSignInOutcome { success, cancelled, notConfigured, failed }

class GoogleSignInResult {
  const GoogleSignInResult(this.outcome, {this.uid, this.error});

  const GoogleSignInResult.success(String uid)
      : this(GoogleSignInOutcome.success, uid: uid);
  const GoogleSignInResult.cancelled()
      : this(GoogleSignInOutcome.cancelled);
  const GoogleSignInResult.notConfigured()
      : this(GoogleSignInOutcome.notConfigured);
  const GoogleSignInResult.failed(String error)
      : this(GoogleSignInOutcome.failed, error: error);

  final GoogleSignInOutcome outcome;
  final String? uid;
  final String? error;

  bool get isSuccess => outcome == GoogleSignInOutcome.success;

  /// Başarısızlık nedenine göre kullanıcıya gösterilecek i18n anahtarı.
  /// "Hiçbir şey olmuyor" şikayetini önlemek için cihaz-spesifik (Play
  /// Hizmetleri eksik/eski, hesap yok, Credential Manager UI açılamadı)
  /// hatalarda yönlendirici bir mesaj döndürür.
  String get messageKey {
    switch (error) {
      // Google Play Hizmetleri olmayan cihaz (Fire TV / Amazon Appstore):
      // bulut yedekleme desteklenmiyor.
      case 'play-services-unavailable':
        return 'cloud.playServicesUnavailable';
      // Credential Manager / Play Services / cihaz desteği kaynaklı: kullanıcı
      // güncelleme veya hesap ekleme yönünde yönlendirilir.
      case 'platform-unsupported':
      case 'uiUnavailable':
      case 'timeout':
      case 'interrupted':
        return 'cloud.signInUnavailable';
      // Yapılandırma / token üretimi başarısız.
      case 'no-id-token':
      case 'no-uid':
      case 'clientConfigurationError':
      case 'providerConfigurationError':
        return 'cloud.signInConfigError';
      default:
        return 'cloud.signInFailed';
    }
  }
}

/// Google ile Firebase Auth oturumu + kullanıcı ayarlarının (32 slot M3U/Xtream
/// kimlik bilgileri, tema, font, PIN ve tüm `mina_*` tercihleri) Firestore'da
/// bulutta yedeklenmesi / geri yüklenmesi.
///
/// Yedek içeriği [BackupService] ile toplanır (uygulamada zaten kullanılan
/// şifreli yedek formatının aynısı) ve Firestore'da kullanıcının `uid`
/// dökümanı altında tek bir JSON string alanı olarak saklanır. Böylece
/// Firestore'un alan-adı kısıtlamalarına (`.`, `/`, `[` vb.) takılmadan,
/// iç içe `mina_*` anahtarları sorunsuz saklanır.
class AuthService extends GetxService {
  AuthService({BackupService? backupService}) : _backupOverride = backupService;

  final BackupService? _backupOverride;

  /// Oturum açık kullanıcı (null = oturum kapalı). UI reaktif dinleyebilir.
  final Rxn<User> currentUser = Rxn<User>();

  bool _googleInitialized = false;
  StreamSubscription<User?>? _authSub;

  static const String _usersCollection = 'users';
  static const String _dataField = 'data';
  static const String _updatedAtField = 'updatedAt';
  static const String _schemaField = 'schema';
  static const String _platformField = 'platform';
  static const int _schemaVersion = 1;

  /// Bulut özellikleri kullanılabilir mi? (Firebase yapılandırılmış + init OK)
  bool get isAvailable => gFirebaseReady;

  bool get isSignedIn => currentUser.value != null;

  /// Android'de Google Play Hizmetleri kullanılabilir mi? Fire TV / Amazon
  /// Appstore gibi GMS'siz cihazlarda `false`. iOS ve diğer platformlarda
  /// Google Sign-In GMS gerektirmediği için `true` kabul edilir. UI bu bayrağı
  /// `Obx` ile dinleyip butonu gizleyebilir.
  final RxBool playServicesAvailable = true.obs;

  /// Bu cihazda Google bulut yedekleme/giriş kullanılabilir mi?
  /// Firebase hazırsa evet — GMS olmasa veya Meizu gibi cihazlarda native
  /// giriş çalışmasa bile tarayıcı OAuth yedek akışı denenebilir.
  bool get isCloudBackupSupported => isAvailable;

  /// Android'de Credential Manager / native Google girişi denenebilir mi?
  bool get canTryNativeGoogleSignIn =>
      !_isAndroidPlatform || playServicesAvailable.value;

  static const Duration _nativeSignInTimeout = Duration(seconds: 25);
  static const Duration _browserSignInTimeout = Duration(seconds: 180);

  bool get _isAndroidPlatform => defaultTargetPlatform == TargetPlatform.android;

  BackupService get _backup {
    if (_backupOverride != null) return _backupOverride;
    if (Get.isRegistered<BackupService>()) return Get.find<BackupService>();
    return BackupService();
  }

  void _syncLicenseAfterGoogleSignIn() {
    if (!Get.isRegistered<LicensingService>()) return;
    unawaited(Get.find<LicensingService>().syncLicenseFromAccount());
  }

  /// Paywall / ayarlar: giriş sonrası senkron bitene kadar bekler.
  Future<bool> syncLicenseAfterGoogleSignInAndWait() async {
    if (!Get.isRegistered<LicensingService>()) return false;
    final licensing = Get.find<LicensingService>();

    await licensing.initialization;

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
        await user.getIdToken(true);
        user = FirebaseAuth.instance.currentUser ?? user;
      } catch (e) {
        debugPrint('[AuthService] post-sign-in user refresh: $e');
      }
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      final ok = await licensing.syncLicenseFromAccount(user: user);
      if (ok || licensing.isPremium.value) return true;
      if (attempt < 2) {
        await Future<void>.delayed(
          Duration(milliseconds: 900 * (attempt + 1)),
        );
      }
    }
    return licensing.isPremium.value;
  }

  @override
  void onInit() {
    super.onInit();
    // Play Hizmetleri durumunu erkenden öğren (UI butonu gizleyebilsin).
    unawaited(refreshPlayServicesAvailability());
    if (!gFirebaseReady) return;
    try {
      currentUser.value = FirebaseAuth.instance.currentUser;
      if (currentUser.value == null) {
        unawaited(signInAnonymously());
      }
      _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
        currentUser.value = u;
        if (u != null) {
          try {
            FirebaseCrashlytics.instance.setUserIdentifier(u.email ?? u.uid);
          } catch (_) {}
          // Birincil profilin isim + fotoğrafını Google hesabından eşitle.
          _syncPrimaryProfile(u);
          _syncLicenseAfterGoogleSignIn();
          unawaited(_recordActivityLog(u));
          // Oturum hazır → zamanı geldiyse sessiz otomatik yedek (kısa gecikme
          // ile, açılış yükünü engellememek için).
          Future<void>.delayed(const Duration(seconds: 5), () {
            unawaited(maybeAutoBackup());
          });
        }
      });
    } catch (e) {
      debugPrint('[AuthService] authState listen failed: $e');
    }
    unawaited(_ensureGoogleInitialized());
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }

  Future<void> _recordActivityLog(User u) async {
    try {
      final doc = FirebaseFirestore.instance.collection(_usersCollection).doc(u.uid);
      final os = DeviceInfoUtil.getDeviceOS();
      final name = await DeviceInfoUtil.getDeviceName();
      await doc.set({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastDeviceOS': os,
        'lastDeviceName': name,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AuthService] _recordActivityLog failed: $e');
    }
  }

  /// Firebase Console'daki Web istemci kimliği (google-services.json →
  /// oauth_client, client_type 3). Android'de Credential Manager üzerinden
  /// güvenilir `idToken` üretimi için serverClientId olarak verilir.
  static const String _serverClientId =
      '678971140280-jd0cui664nf6bp9bnfegt24j1609bcga.apps.googleusercontent.com';

  /// google_sign_in v7: tüm çağrılardan önce bir kez `initialize()` şart.
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    try {
      await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
      _googleInitialized = true;
    } catch (e) {
      debugPrint('[AuthService] GoogleSignIn.initialize failed: $e');
    }
  }

  /// Play Hizmetleri durumunu (Android) sorgular ve [playServicesAvailable]
  /// bayrağını günceller. GMS yoksa / eski / devre dışıysa `false` yazar.
  /// Android dışı platformlarda veya sorgu hata verirse `true` kabul edilir
  /// (gerçek başarısızlık [signInWithGoogle] tarafından yakalanır).
  Future<bool> refreshPlayServicesAvailability() async {
    if (!_isAndroidPlatform) {
      playServicesAvailable.value = true;
      return true;
    }
    try {
      final status = await GoogleApiAvailability.instance
          .checkGooglePlayServicesAvailability();
      final ok = status == GooglePlayServicesAvailability.success;
      playServicesAvailable.value = ok;
      return ok;
    } catch (e) {
      debugPrint('[AuthService] play services check failed: $e');
      playServicesAvailable.value = true;
      return true;
    }
  }

  /// Firebase Anonymous Auth ile oturum açar (deneme süresi takibi için)
  Future<void> signInAnonymously() async {
    if (!gFirebaseReady) {
      debugPrint('[AuthService] Firebase not ready, cannot sign in anonymously');
      return;
    }
    try {
      await FirebaseAuth.instance.signInAnonymously();
      AdminAnalyticsService.incrementNewUsers();
      debugPrint('[AuthService] Anonymous sign-in successful');
    } catch (e) {
      debugPrint('[AuthService] Anonymous sign-in failed: $e');
    }
  }

  /// Google hesabı ile Firebase Auth oturumu açar.
  ///
  /// Android:
  /// - GMS varsa → yalnızca native (Credential Manager); başarısız olsa bile
  ///   tarayıcı açılmaz, hata döndürülür.
  /// - GMS yoksa (Fire TV / Amazon Appstore / GMS'siz cihazlar) →
  ///   [signInWithGoogleViaBrowser] (Custom Tab / tarayıcı OAuth) devreye girer.
  Future<GoogleSignInResult> signInWithGoogle() async {
    if (!gFirebaseReady) {
      return const GoogleSignInResult.notConfigured();
    }

    if (_isAndroidPlatform) {
      await AndroidPlaybackSocHints.ensureLoaded();
      await refreshPlayServicesAvailability();
      await _ensureGoogleInitialized();

      // GMS yoksa tarayıcı OAuth tek seçenektir.
      if (!playServicesAvailable.value) {
        debugPrint(
          '[AuthService] Play Services unavailable, falling back to browser OAuth.',
        );
        return signInWithGoogleViaBrowser();
      }

      // GMS mevcut: sadece native dene.
      // Native başarısız olsa bile tarayıcı açılmaz; hata doğrudan döner.
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        debugPrint(
          '[AuthService] supportsAuthenticate() = false, cannot sign in natively.',
        );
        return const GoogleSignInResult.failed('platform-unsupported');
      }

      return _signInWithGoogleNative();
    }

    return _signInWithGoogleNative();
  }

  /// Credential Manager / google_sign_in ile native oturum açma.
  Future<GoogleSignInResult> _signInWithGoogleNative() async {
    try {
      await _ensureGoogleInitialized();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return const GoogleSignInResult.failed('platform-unsupported');
      }
      final account = await GoogleSignIn.instance
          .authenticate(scopeHint: const <String>['email'])
          .timeout(_nativeSignInTimeout);
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return const GoogleSignInResult.failed('no-id-token');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      currentUser.value = user;
      final uid = user?.uid;
      if (uid == null) {
        return const GoogleSignInResult.failed('no-uid');
      }
      if (user != null) _syncPrimaryProfile(user);
      _syncLicenseAfterGoogleSignIn();
      return GoogleSignInResult.success(uid);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const GoogleSignInResult.cancelled();
      }
      debugPrint(
        '[AuthService] GoogleSignInException: ${e.code} ${e.description}',
      );
      return GoogleSignInResult.failed(e.code.name);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException: ${e.code}');
      return GoogleSignInResult.failed(e.code);
    } on TimeoutException catch (e) {
      debugPrint('[AuthService] native sign-in timeout: $e');
      return const GoogleSignInResult.failed('timeout');
    } catch (e, st) {
      debugPrint('[AuthService] native sign-in error: $e\n$st');
      return GoogleSignInResult.failed(e.toString());
    }
  }

  /// Tarayıcı / Custom Tab üzerinden Firebase [signInWithProvider] OAuth.
  /// GMS olmayan veya native girişin çalışmadığı Android cihazlar için yedek.
  Future<GoogleSignInResult> signInWithGoogleViaBrowser() async {
    if (Get.isRegistered<ToastService>()) {
      Get.find<ToastService>().show('cloud.signInBrowserOpening'.tr);
    }
    try {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.setCustomParameters({'prompt': 'select_account'});
      final userCred = await FirebaseAuth.instance
          .signInWithProvider(provider)
          .timeout(_browserSignInTimeout);
      final user = userCred.user;
      currentUser.value = user;
      final uid = user?.uid;
      if (uid == null) {
        return const GoogleSignInResult.failed('no-uid');
      }
      if (user != null) _syncPrimaryProfile(user);
      _syncLicenseAfterGoogleSignIn();
      return GoogleSignInResult.success(uid);
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] browser sign-in FirebaseAuthException: ${e.code}');
      if (_isAuthCancelledCode(e.code)) {
        return const GoogleSignInResult.cancelled();
      }
      // "missing initial state" vb. ortam hatalarında oturum aslında açılmış
      // olabilir — önce gerçekten giriş yapılmış mı diye bak.
      if (_isIgnorableRedirectStateError('${e.code} ${e.message}')) {
        final recovered = await _recoverSignedInAfterError();
        if (recovered != null) return recovered;
      }
      return GoogleSignInResult.failed(e.code);
    } on TimeoutException catch (e) {
      debugPrint('[AuthService] browser sign-in timeout: $e');
      final recovered = await _recoverSignedInAfterError();
      if (recovered != null) return recovered;
      return const GoogleSignInResult.failed('timeout');
    } catch (e) {
      debugPrint('[AuthService] browser sign-in error: $e');
      if (_isIgnorableRedirectStateError(e.toString())) {
        final recovered = await _recoverSignedInAfterError();
        if (recovered != null) return recovered;
      }
      return GoogleSignInResult.failed(e.toString());
    }
  }

  bool _isAuthCancelledCode(String code) {
    final c = code.toLowerCase();
    return c.contains('cancel') || c == 'user-cancelled';
  }

  /// Bazı WebView / storage-partitioned tarayıcı ortamlarında (ör. bazı Meizu
  /// cihazları) `signInWithProvider` redirect sonucunu işlerken
  /// "missing initial state" / "web-storage-unsupported" hatası fırlatır —
  /// ancak oturum aslında açılmış olur. Bu hatalar kullanıcıya gösterilmemeli.
  bool _isIgnorableRedirectStateError(String raw) {
    final s = raw.toLowerCase();
    return s.contains('missing initial state') ||
        s.contains('missing-initial-state') ||
        s.contains('web-storage-unsupported') ||
        s.contains('web storage') ||
        s.contains('sessionstorage') ||
        s.contains('session storage');
  }

  /// Hata sonrası oturumun gerçekten açılıp açılmadığını kısa süre bekleyerek
  /// kontrol eder. Açıldıysa [GoogleSignInResult.success], aksi halde `null`.
  Future<GoogleSignInResult?> _recoverSignedInAfterError() async {
    for (var i = 0; i < 6; i++) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        currentUser.value = user;
        _syncPrimaryProfile(user);
        return GoogleSignInResult.success(user.uid);
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    return null;
  }

  /// Oturumu kapatır (hem Firebase hem Google).
  Future<void> signOut() async {
    if (!gFirebaseReady) return;
    try {
      await FirebaseAuth.instance.signOut();
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      currentUser.value = null;
      // Birincil profilin Google fotoğrafını temizle (artık bağlı değiliz).
      if (Get.isRegistered<ProfilesService>()) {
        unawaited(Get.find<ProfilesService>().clearGoogleLinkOnSignOut());
      }
    } catch (e) {
      debugPrint('[AuthService] signOut error: $e');
    }
  }

  /// Birincil (ilk) profilin adını ve profil fotoğrafını Google hesabından
  /// günceller. Profil servisi hazır değilse (çok erken) sessizce atlanır;
  /// `authStateChanges` tekrar tetiklenmese bile giriş akışı da çağırır.
  void _syncPrimaryProfile(User user) {
    if (!Get.isRegistered<ProfilesService>()) return;
    unawaited(
      Get.find<ProfilesService>().syncPrimaryFromGoogle(
        displayName: user.displayName,
        photoUrl: user.photoURL,
      ),
    );
  }

  DocumentReference<Map<String, dynamic>>? _userDoc() {
    final uid = currentUser.value?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection(_usersCollection).doc(uid);
  }

  /// Firestore döküman/alan üst sınırı 1 MiB; `data` string'ini güvenli bir
  /// eşikte tutarız (rules da ~2 MB sınırlar). Aşılırsa yazım reddedilir.
  static const int _maxBackupBytes = 900000; // ~0.9 MB

  void _logBackup({required bool success, int? sizeBytes, String? reason}) {
    if (!Get.isRegistered<MinaTelemetryService>()) return;
    unawaited(
      Get.find<MinaTelemetryService>().logCloudBackup(
        success: success,
        sizeBytes: sizeBytes,
        reason: reason,
      ),
    );
  }

  /// Kullanıcının 32 slot M3U/Xtream listelerini, tema/font/PIN ve tüm `mina_*`
  /// ayarlarını Firestore'a `SetOptions(merge: true)` ile yazar.
  Future<bool> saveUserSettingsToCloud() async {
    if (!gFirebaseReady) return false;
    final doc = _userDoc();
    if (doc == null) return false;
    try {
      final backup = await _backup.collectBackupJson();
      final payload = jsonEncode(backup);
      final sizeBytes = utf8.encode(payload).length;
      if (sizeBytes > _maxBackupBytes) {
        debugPrint(
          '[AuthService] backup too large: $sizeBytes B > $_maxBackupBytes B',
        );
        _logBackup(success: false, sizeBytes: sizeBytes, reason: 'too_large');
        return false;
      }
      await doc.set(
        <String, dynamic>{
          _dataField: payload,
          _schemaField: _schemaVersion,
          _platformField: defaultTargetPlatform.name,
          _updatedAtField: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (Get.isRegistered<AppSettingsService>()) {
        await Get.find<AppSettingsService>().updateLastCloudBackupTime();
      }
      _logBackup(success: true, sizeBytes: sizeBytes);
      return true;
    } catch (e) {
      debugPrint('[AuthService] saveUserSettingsToCloud error: $e');
      _logBackup(success: false, reason: 'error');
      return false;
    }
  }

  /// Buluttaki son yedeğin özetini döndürür: boyut (bayt), güncelleme zamanı,
  /// platform ve içerik sayıları (liste / ayar / yerel M3U). Döküman/veri yoksa
  /// `null`. Yedek paneli bunu gösterir.
  Future<CloudBackupInfo?> fetchCloudBackupInfo() async {
    if (!gFirebaseReady) return null;
    final doc = _userDoc();
    if (doc == null) return null;
    try {
      final snap = await doc.get();
      if (!snap.exists) return null;
      final docData = snap.data();
      final raw = docData?[_dataField];
      if (raw is! String || raw.trim().isEmpty) return null;

      final sizeBytes = utf8.encode(raw).length;
      var updatedAtMs = 0;
      final ts = docData?[_updatedAtField];
      if (ts is Timestamp) updatedAtMs = ts.millisecondsSinceEpoch;
      final platform = docData?[_platformField]?.toString();

      var playlists = 0;
      var settings = 0;
      var localM3u = 0;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          playlists = countCloudBackupPlaylistSources(map);
          final prefs = map['prefs'];
          if (prefs is Map) settings = prefs.length;
          final bySlot = map['localM3uBySlot'];
          if (bySlot is Map) {
            localM3u = bySlot.length;
          } else {
            if (map['localM3u'] is String) localM3u++;
            if (map['localM3u2'] is String) localM3u++;
          }
        }
      } catch (_) {}

      return CloudBackupInfo(
        sizeBytes: sizeBytes,
        updatedAtMs: updatedAtMs,
        platform: platform,
        playlistCount: playlists,
        settingsCount: settings,
        localM3uCount: localM3u,
      );
    } catch (e) {
      debugPrint('[AuthService] fetchCloudBackupInfo error: $e');
      return null;
    }
  }

  /// Bulut yedeğinin son güncelleme zamanını (epoch ms) döndürür. Döküman/veri
  /// yoksa `null`. Çok cihazlı çakışma kontrolü için kullanılır.
  Future<int?> fetchCloudUpdatedAtMs() async {
    if (!gFirebaseReady) return null;
    final doc = _userDoc();
    if (doc == null) return null;
    try {
      final snap = await doc.get();
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null || data[_dataField] is! String) return null;
      final ts = data[_updatedAtField];
      if (ts is Timestamp) return ts.millisecondsSinceEpoch;
      return null;
    } catch (e) {
      debugPrint('[AuthService] fetchCloudUpdatedAtMs error: $e');
      return null;
    }
  }

  /// Kullanıcının buluttaki tüm yedek verisini siler (GDPR / hesabı temizleme).
  /// Oturum açık kalır; istenirse ayrıca [signOut] çağrılır.
  Future<bool> deleteCloudData() async {
    if (!gFirebaseReady) return false;
    final doc = _userDoc();
    if (doc == null) return false;
    try {
      await doc.delete();
      if (Get.isRegistered<AppSettingsService>()) {
        await Get.find<AppSettingsService>().resetLastCloudBackupTime();
      }
      if (Get.isRegistered<MinaTelemetryService>()) {
        unawaited(Get.find<MinaTelemetryService>().logCloudDelete(success: true));
      }
      return true;
    } catch (e) {
      debugPrint('[AuthService] deleteCloudData error: $e');
      if (Get.isRegistered<MinaTelemetryService>()) {
        unawaited(
          Get.find<MinaTelemetryService>().logCloudDelete(success: false),
        );
      }
      return false;
    }
  }

  /// Hesabı ve bulut verisini tamamen siler.
  Future<bool> deleteAccount() async {
    if (!gFirebaseReady) return false;
    final user = currentUser.value;
    if (user == null) return false;

    try {
      // 1. Önce bulut verisini sil
      await deleteCloudData();

      // 2. Firebase Auth hesabını sil
      await user.delete();

      // 3. Yerel oturumu kapat
      await signOut();

      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('requires-recent-login');
      }
      debugPrint('[AuthService] deleteAccount error: $e');
      return false;
    } catch (e) {
      debugPrint('[AuthService] deleteAccount error: $e');
      return false;
    }
  }

  /// Firestore'dan kullanıcının yedek JSON'ını çeker. Veri yoksa `null` döner.
  Future<Map<String, dynamic>?> loadUserSettingsFromCloud() async {
    if (!gFirebaseReady) return null;
    final doc = _userDoc();
    if (doc == null) return null;
    try {
      final snap = await doc.get();
      if (!snap.exists) return null;
      final raw = snap.data()?[_dataField];
      if (raw is! String || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('[AuthService] loadUserSettingsFromCloud error: $e');
      return null;
    }
  }

  bool _autoBackupRunning = false;

  /// Otomatik bulut yedeği: oturum açık + Firebase hazır + ayarlanan aralık
  /// dolmuşsa sessizce buluta yedekler. Uygulama açılışında ve giriş sonrası
  /// güvenle çağrılabilir; zamanı gelmediyse hiçbir şey yapmaz.
  Future<void> maybeAutoBackup() async {
    if (_autoBackupRunning) return;
    if (!gFirebaseReady || !isSignedIn) return;
    if (!Get.isRegistered<AppSettingsService>()) return;
    final app = Get.find<AppSettingsService>();
    if (!app.shouldAutoBackupCloud()) return;

    // Kiritik Düzeltme: Eğer cihazda hiç playlist yoksa (yeni kurulum) otomatik
    // yedeklemeyi başlatma. Aksi halde buluttaki dolu yedeğin üzerine 0 playlist
    // olarak yazar ve kullanıcının verilerini kaybeder.
    if (Get.isRegistered<PlaylistRepository>()) {
      try {
        final sources = await Get.find<PlaylistRepository>().readAllSources();
        if (sources.isEmpty) {
          debugPrint('[AuthService] maybeAutoBackup aborted: Local device has 0 playlists. Preventing cloud overwrite.');
          return;
        }
      } catch (_) {}
    }

    _autoBackupRunning = true;
    try {
      await saveUserSettingsToCloud().timeout(
        const Duration(seconds: 30),
        onTimeout: () => false,
      );
    } catch (e) {
      debugPrint('[AuthService] maybeAutoBackup error: $e');
    } finally {
      _autoBackupRunning = false;
    }
  }

  /// Buluttan çekilen yedeği yerel depolamaya (SharedPreferences + SecureStorage
  /// + yerel M3U) uygular. [BackupService] ile aynı geri yükleme mantığı.
  Future<bool> applyCloudSettingsLocally(Map<String, dynamic> data) async {
    try {
      await _backup.applyBackupJson(data);
      return true;
    } catch (e) {
      debugPrint('[AuthService] applyCloudSettingsLocally error: $e');
      return false;
    }
  }

  /// Yedek JSON'da en az bir M3U/Xtream kaynağı veya yerel M3U içeriği var mı?
  bool cloudBackupHasPlaylistSource(Map<String, dynamic> data) =>
      countCloudBackupPlaylistSources(data) > 0;
}

/// Yedek JSON'da yapılandırılmış oynatma listesi kaynağı sayısı.
int countCloudBackupPlaylistSources(Map<String, dynamic> data) {
  var playlists = 0;
  final secure = data['secure'];
  if (secure is Map) {
    for (final entry in secure.entries) {
      final k = entry.key.toString();
      if (!k.startsWith('mina_iptv_source_type')) continue;
      final v = entry.value;
      if (v is String && v.trim().isNotEmpty) playlists++;
    }
  }
  if (playlists > 0) return playlists;

  final bySlot = data['localM3uBySlot'];
  if (bySlot is Map) {
    for (final v in bySlot.values) {
      if (v is String && v.trim().isNotEmpty) return 1;
    }
  }
  final m3u1 = data['localM3u'];
  if (m3u1 is String && m3u1.trim().isNotEmpty) return 1;
  final m3u2 = data['localM3u2'];
  if (m3u2 is String && m3u2.trim().isNotEmpty) return 1;
  return 0;
}

/// Buluttaki son yedeğin özeti — boyut ve içerik dökümü (Bulut Senkronu
/// panelinde gösterilir).
class CloudBackupInfo {
  const CloudBackupInfo({
    required this.sizeBytes,
    required this.updatedAtMs,
    required this.playlistCount,
    required this.settingsCount,
    required this.localM3uCount,
    this.platform,
  });

  final int sizeBytes;

  /// Yedeğin sunucu güncelleme zamanı (epoch ms). 0 = bilinmiyor.
  final int updatedAtMs;

  /// Yedeği yazan cihaz platformu (`android`, `iOS`, ...). Null olabilir.
  final String? platform;

  /// Yapılandırılmış M3U/Xtream liste sayısı.
  final int playlistCount;

  /// Yedeklenen `mina_*` ayar anahtarı sayısı.
  final int settingsCount;

  /// Yedekteki yerel (yapıştırılmış/dosyadan) M3U dosyası sayısı.
  final int localM3uCount;

  /// İnsan-okur boyut etiketi (KB / MB).
  String get sizeLabel {
    if (sizeBytes <= 0) return '0 KB';
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(2)} MB';
    final kb = sizeBytes / 1024;
    return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
  }

  DateTime? get updatedAt => updatedAtMs > 0
      ? DateTime.fromMillisecondsSinceEpoch(updatedAtMs)
      : null;
}
