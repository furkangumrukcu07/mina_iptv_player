import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'firebase_bootstrap.dart';
import 'license_device_service.dart';
import 'mina_telemetry_service.dart';
import '../utils/device_info_util.dart';
import '../i18n/app_locale.dart';
import '../routes/app_routes.dart';
import 'package:intl/intl.dart';

class LicensingService extends GetxService with WidgetsBindingObserver {
  static LicensingService get to => Get.find<LicensingService>();

  static const String channelName = 'mina.device/info';
  static const String getInstallTimeMethod = 'getFirstInstallTime';
  static const String premiumProductId = 'mina_premium_lifetime';
  static const String plus3DevicesProductId = 'mina_total_6devices';

  static const String coffeeProductId = 'mina_buy_coffee';
  static const String functionsRegion = 'europe-west1';

  static final int grandfatherCutoffMs =
      DateTime.utc(2026, 6, 29).millisecondsSinceEpoch;

  final RxBool isPremium = false.obs;
  final RxBool isBanned = false.obs;
  final RxBool licenseEntitled = false.obs;
  final RxBool deviceAccessGranted = false.obs;
  final RxBool deviceLimitExceeded = false.obs;
  final RxBool isGrandfathered = false.obs;
  final Rxn<DateTime> trialExpirationDate = Rxn<DateTime>();
  final Rxn<DateTime> purchaseDate = Rxn<DateTime>();
  final RxBool isTrialActive = false.obs;
  final RxBool isBillingAvailable = false.obs;
  final RxBool purchaseCompleted = false.obs;
  final RxInt deviceCount = 0.obs;
  final RxInt maxDevices = 3.obs;
  final RxList<LicenseDeviceEntry> registeredDevices = <LicenseDeviceEntry>[].obs;
  final RxnString currentDeviceId = RxnString();

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialization => _initCompleter.future;

  String get trialRemainingFormatted {
    final expire = trialExpirationDate.value;
    if (expire == null) return '';

    final now = DateTime.now();
    if (now.isAfter(expire)) return '';

    final diff = expire.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours % 24;

    if (days > 0 && hours > 0) {
      return '$days gün $hours saat';
    } else if (days > 0) {
      return '$days gün';
    } else {
      return '$hours saat';
    }
  }

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Worker? _authWorker;
  Completer<void>? _billingRestoreRound;

  FirebaseFunctions? get _functions {
    if (!gFirebaseReady) return null;
    return FirebaseFunctions.instanceFor(region: functionsRegion);
  }

  static String? _normalizedLicenseEmail(String? email) {
    final trimmed = email?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.toLowerCase();
  }

  Future<bool> syncLicenseFromAccount({User? user}) async {
    if (user == null && Get.isRegistered<AuthService>()) {
      user = Get.find<AuthService>().currentUser.value;
    }
    if (user == null) return isPremium.value;

    user = await _reloadAuthUser(user);

    final synced = await _syncEntitlementsFromServer(user: user);
    if (synced) return true;

    await _ensureBillingReady();
    if (isBillingAvailable.value) {
      await _awaitBillingRestoreRound();
      if (licenseEntitled.value) {
        await _ensureDeviceRegistration();
      }
    }
    return isPremium.value;
  }

  Future<User> _reloadAuthUser(User user) async {
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null) return refreshed;
    } catch (e) {
      debugPrint('[LicensingService] user.reload failed: $e');
    }
    return user;
  }

  Future<void> _ensureBillingReady() async {
    if (isBillingAvailable.value) return;
    try {
      final available = await InAppPurchase.instance.isAvailable();
      isBillingAvailable.value = available;
    } catch (e) {
      debugPrint('[LicensingService] Billing availability check: $e');
    }
  }

  Future<User?> _awaitRestoredAuthUser() async {
    if (!gFirebaseReady) return null;
    try {
      final immediate = FirebaseAuth.instance.currentUser;
      if (immediate != null) return immediate;
      // TV ve yavaş Android cihazlarda Google Play Services auth oturumu geç
      // restore olabilir (özellikle soğuk başlatmada). 8 saniye bekliyoruz.
      return await FirebaseAuth.instance
          .authStateChanges()
          .where((u) => u != null)
          .map((u) => u!)
          .first
          .timeout(const Duration(milliseconds: 8000));
    } catch (_) {
      return FirebaseAuth.instance.currentUser;
    }
  }

  Future<void> _awaitInitialBillingRestoreIfNeeded() async {
    if (!isBillingAvailable.value || isPremium.value) return;
    await _awaitBillingRestoreRound();
  }

  Future<void> _awaitBillingRestoreRound() async {
    if (!isBillingAvailable.value || licenseEntitled.value) return;

    final existing = _billingRestoreRound;
    if (existing != null && !existing.isCompleted) {
      try {
        await existing.future.timeout(
          const Duration(seconds: 12),
          onTimeout: () {},
        );
      } catch (e) {
        debugPrint('[LicensingService] Billing restore join wait: $e');
      }
      return;
    }

    final round = Completer<void>();
    _billingRestoreRound = round;
    try {
      await InAppPurchase.instance.restorePurchases();
      await round.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('[LicensingService] Billing restore wait: $e');
    } finally {
      if (identical(_billingRestoreRound, round)) {
        _billingRestoreRound = null;
      }
    }
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _initBilling();
    unawaited(_checkLicenseStatus());
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _purchaseSub?.cancel();
    _authWorker?.dispose();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(revalidateRuntimeAccess());
    }
  }

  Future<void> revalidateRuntimeAccess() async {
    _reevaluateTrialState();

    // Premium veya trial aktifse sunucudan sync dene (oturum açıksa).
    // TV'lerde uygulama foreground'a döndüğünde oturum yüklenmiş olabilir.
    if (Get.isRegistered<AuthService>()) {
      final user = Get.find<AuthService>().currentUser.value;
      if (user != null && gFirebaseReady) {
        await _syncEntitlementsFromServer(user: user, silent: true);
        // Sync sonrası durumu yeniden değerlendir
        _reevaluateTrialState();
      }
    }

    if (!isPremium.value && !isTrialActive.value) {
      if (Get.currentRoute != AppRoutes.paywall &&
          Get.currentRoute != AppRoutes.splash) {
        Get.offAllNamed(AppRoutes.paywall);
      }
    }
  }

  void _reevaluateTrialState() {
    if (isPremium.value || isGrandfathered.value) return;
    final expire = trialExpirationDate.value;
    if (expire == null) {
      isTrialActive.value = false;
      return;
    }
    isTrialActive.value = !DateTime.now().isAfter(expire);
  }

  void _initBilling() {
    final purchaseUpdated = InAppPurchase.instance.purchaseStream;
    _purchaseSub = purchaseUpdated.listen(
      _onPurchaseUpdated,
      onError: (err) {
        debugPrint('[LicensingService] Purchase stream error: $err');
      },
    );

    unawaited(InAppPurchase.instance.isAvailable().then((available) {
      isBillingAvailable.value = available;
      if (available) {
        unawaited(_restorePurchasesSilently());
      }
    }));
  }

  Future<void> _checkLicenseStatus() async {
    try {
      // 1. Load locally cached premium status first as a fallback/fast-load for offline support.
      final prefs = await SharedPreferences.getInstance();
      final localPremium = prefs.getBool('mina_premium_purchased') ?? false;
      if (localPremium) {
        final localPurchaseMs = prefs.getInt('mina_premium_purchase_date');
        _applyLocalPremium(
          sourceGrandfather: prefs.getBool('mina_premium_grandfathered') ?? false,
          resolvedPurchaseDate: localPurchaseMs != null && localPurchaseMs > 0
              ? DateTime.fromMillisecondsSinceEpoch(localPurchaseMs).toLocal()
              : null,
        );
        // Continue to sync in background if online to update device list and confirm status.
        if (gFirebaseReady) {
          unawaited(_awaitRestoredAuthUser().then((authUser) {
            if (authUser != null) {
              unawaited(_syncEntitlementsFromServer(user: authUser, silent: true));
            }
          }));
        }
        return;
      }

      final authUser = await _awaitRestoredAuthUser();
      if (authUser != null && gFirebaseReady) {
        final synced = await _syncEntitlementsFromServer(user: authUser);
        if (synced) {
          // Premium başarıyla alındı. Auth değişimlerini izlemeye devam et
          // (cihaz limiti ve lisans iptali durumları için).
          _registerAuthWorker();
          return;
        }
      }

      if (gFirebaseReady && Get.isRegistered<AuthService>()) {
        final auth = Get.find<AuthService>();
        if (auth.currentUser.value == null) {
          try {
            await auth.signInAnonymously();
            debugPrint(
              '[LicensingService] Anonymous user created for trial tracking',
            );
          } catch (e) {
            debugPrint('[LicensingService] Anonymous auth failed: $e');
          }
        }
      }

      final int packageInstallMs = await _getPackageInstallTimeMs();
      final int trialStartMs = await _getTrialStartTimeMs();
      debugPrint(
        '[LicensingService] Package install: ${DateTime.fromMillisecondsSinceEpoch(packageInstallMs)}, '
        'trial start: ${DateTime.fromMillisecondsSinceEpoch(trialStartMs)}',
      );

      if (packageInstallMs < grandfatherCutoffMs) {
        final claimed = await _claimInstallGrandfatherOnServer(packageInstallMs);
        if (claimed) {
          _registerAuthWorker();
          return;
        }

        debugPrint(
          '[LicensingService] User is grandfathered via install date (offline fallback).',
        );
        _applyLocalPremium(
          sourceGrandfather: true,
          resolvedPurchaseDate:
              DateTime.fromMillisecondsSinceEpoch(packageInstallMs).toLocal(),
        );
        _registerAuthWorker();
        return;
      }

      final trialStartDateTime =
          DateTime.fromMillisecondsSinceEpoch(trialStartMs);
      final expireDateTime = trialStartDateTime.add(const Duration(days: 2));
      trialExpirationDate.value = expireDateTime;

      final now = DateTime.now();
      if (now.isAfter(expireDateTime)) {
        isTrialActive.value = false;
        debugPrint('[LicensingService] Trial expired.');
      } else {
        isTrialActive.value = true;
        debugPrint(
          '[LicensingService] Trial active. Remaining: $trialRemainingFormatted',
        );
      }

      unawaited(_awaitInitialBillingRestoreIfNeeded());

      // [Kritik]: Trial moduna düşsek bile auth değişimlerini izle.
      // TV'lerde Google oturumu splash'ten sonra yüklenebilir; oturum açılınca
      // lisans anında sunucudan senkronize edilir ve trial iptal olur.
      _registerAuthWorker();
    } catch (e) {
      debugPrint('[LicensingService] Error checking license: $e');
      isTrialActive.value = false;
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  /// Auth kullanıcı değişimlerini izleyen worker'ı (yeniden) kaydeder.
  /// Mevcut worker varsa önce onu temizler. Her auth değişiminde (giriş /
  /// çıkış / token yenileme) sunucudan lisans senkronizasyonu tetiklenir.
  void _registerAuthWorker() {
    if (!Get.isRegistered<AuthService>()) return;
    final auth = Get.find<AuthService>();
    _authWorker?.dispose();
    _authWorker = ever(auth.currentUser, (user) {
      unawaited(syncLicenseFromAccount(user: user));
    });
  }

  Future<bool> _syncEntitlementsFromServer({
    required User user,
    bool silent = false,
  }) async {
    final String? normalizedEmail = _normalizedLicenseEmail(user.email);
    final List<String> manualPremiums = [
      'furkangumrukcu07@gmail.com',
      'allachehata@gmail.com',
    ];

    if (normalizedEmail != null && manualPremiums.contains(normalizedEmail)) {
      licenseEntitled.value = true;
      isPremium.value = true;
      deviceAccessGranted.value = true;
      deviceLimitExceeded.value = false;
      maxDevices.value = 999;
      return true;
    }

    final fn = _functions;
    if (fn == null) return false;

    try {
      final callable = fn.httpsCallable('syncLicenseEntitlements');
      final result = await callable
          .call<Map<String, dynamic>>()
          .timeout(const Duration(seconds: 20));
      final data = Map<String, dynamic>.from(result.data);

      if (data['isPremium'] == true) {
        if (data['isBanned'] == true) {
           isBanned.value = true;
           isPremium.value = false;
           licenseEntitled.value = false;
           deviceAccessGranted.value = false;
           if (Get.isRegistered<AuthService>()) {
             await Get.find<AuthService>().signOut();
           }
           return false;
        }
        isBanned.value = false;
        final source = data['source'] as String? ?? '';
        isGrandfathered.value = source.startsWith('grandfather');
        final parsed = _parseIsoDate(data['purchaseDate'] as String?);
        if (parsed != null) {
          purchaseDate.value = parsed.toLocal();
        }
        licenseEntitled.value = true;
        deviceCount.value = data['deviceCount'] as int? ?? 0;
        maxDevices.value = data['maxDevices'] as int? ?? 3;
        registeredDevices.assignAll(
          LicenseDeviceService.parseDevices(data['devices']),
        );
        await _savePremiumStatusLocally(true);
        await _ensureDeviceRegistration();
        if (!silent) {
          debugPrint(
            '[LicensingService] Premium unlocked via server sync for uid: ${user.uid}',
          );
        }
        return isPremium.value;
      }

      licenseEntitled.value = false;
      deviceAccessGranted.value = false;
      deviceLimitExceeded.value = false;
      isPremium.value = false;
      isBanned.value = data['isBanned'] == true;
      if (isBanned.value) {
        if (Get.isRegistered<AuthService>()) {
          await Get.find<AuthService>().signOut();
        }
      }
      return false;
    } catch (e) {
      debugPrint('[LicensingService] syncLicenseEntitlements failed: $e');
      return false;
    }
  }

  Future<bool> _claimInstallGrandfatherOnServer(int installMs) async {
    final fn = _functions;
    if (fn == null) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final callable = fn.httpsCallable('claimInstallGrandfather');
      final result = await callable.call<Map<String, dynamic>>({
        'firstInstallTimeMs': installMs,
      });
      final data = Map<String, dynamic>.from(result.data);
      if (data['isPremium'] == true) {
        final source = data['source'] as String? ?? 'grandfather_install';
        isGrandfathered.value = source.startsWith('grandfather');
        final parsed = _parseIsoDate(data['purchaseDate'] as String?);
        _applyLocalPremium(
          sourceGrandfather: true,
          resolvedPurchaseDate: parsed?.toLocal() ??
              DateTime.fromMillisecondsSinceEpoch(installMs).toLocal(),
        );
        await _ensureDeviceRegistration();
        return true;
      }
    } catch (e) {
      debugPrint('[LicensingService] claimInstallGrandfather failed: $e');
    }
    return false;
  }

  Future<bool> _activatePremiumOnServer(PurchaseDetails purchase) async {
    final fn = _functions;
    if (fn == null) return false;
    if (FirebaseAuth.instance.currentUser == null) return false;

    final token = _extractAndroidPurchaseToken(purchase);
    if (token == null || token.isEmpty) {
      debugPrint('[LicensingService] Missing purchase token for server verify.');
      return false;
    }

    try {
      final callable = fn.httpsCallable('activatePremiumFromPlay');
      final result = await callable.call<Map<String, dynamic>>({
        'purchaseToken': token,
        'productId': purchase.productID,
      });
      final data = Map<String, dynamic>.from(result.data);
      if (data['isPremium'] == true) {
        licenseEntitled.value = true;
        isGrandfathered.value = false;
        final parsed = _parseIsoDate(data['purchaseDate'] as String?);
        if (parsed != null) {
          purchaseDate.value = parsed.toLocal();
        }
        await _savePremiumStatusLocally(true);
        await _ensureDeviceRegistration();
        return true;
      }
    } catch (e) {
      debugPrint('[LicensingService] activatePremiumFromPlay failed: $e');
    }
    return false;
  }

  String? _extractAndroidPurchaseToken(PurchaseDetails purchase) {
    final raw = purchase.verificationData.serverVerificationData.trim();
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final token = decoded['purchaseToken'];
        if (token is String && token.isNotEmpty) return token;
      }
    } catch (_) {}
    if (raw.length > 20 && !raw.startsWith('{')) return raw;
    return null;
  }

  Future<bool> _ensureDeviceRegistration() async {
    if (Get.isRegistered<AuthService>()) {
      final user = Get.find<AuthService>().currentUser.value;
      if (_normalizedLicenseEmail(user?.email) == 'furkangumrukcu07@gmail.com') {
        deviceLimitExceeded.value = false;
        deviceAccessGranted.value = true;
        isPremium.value = true;
        isTrialActive.value = false;
        trialExpirationDate.value = null;
        maxDevices.value = 999;
        return true;
      }
    }

    if (!licenseEntitled.value) {
      deviceAccessGranted.value = false;
      isPremium.value = false;
      return false;
    }

    final registration = await LicenseDeviceService.registerCurrentDevice();
    currentDeviceId.value = await LicenseDeviceService.getOrCreateDeviceId();
    deviceCount.value = registration.deviceCount;
    maxDevices.value = registration.maxDevices;
    if (registration.devices.isNotEmpty) {
      registeredDevices.assignAll(registration.devices);
    }

    if (registration.deviceLimitExceeded) {
      deviceLimitExceeded.value = true;
      deviceAccessGranted.value = false;
      isPremium.value = false;
      isTrialActive.value = false;
      debugPrint(
        '[LicensingService] Device limit exceeded (${registration.deviceCount}/${registration.maxDevices}).',
      );
      return false;
    }

    if (registration.registered) {
      deviceLimitExceeded.value = false;
      deviceAccessGranted.value = true;
      isPremium.value = true;
      isTrialActive.value = false;
      trialExpirationDate.value = null;
      return true;
    }

    // Kayıt başarısız ve limit aşımı değil — soft-fail yalnızca güvenliyse.
    // 1) Bu cihaz zaten listede → geçici ağ hatası, erişimi koru.
    // 2) Liste dolu ve bu cihaz yok → muhtemel limit; kilitle (fail-closed).
    // 3) Liste boş/kısa + geçici hata → entitled kullanıcıyı kilitleme.
    final currentId = currentDeviceId.value;
    var devices = registration.devices;
    if (devices.isEmpty) {
      devices = await LicenseDeviceService.listDevices();
      if (devices.isNotEmpty) {
        registeredDevices.assignAll(devices);
        deviceCount.value = devices.length;
      }
    }
    final alreadyRegistered = currentId != null &&
        devices.any((d) => d.deviceId == currentId);
    final atCapacity = devices.length >= maxDevices.value &&
        maxDevices.value > 0 &&
        !alreadyRegistered;

    if (atCapacity) {
      deviceLimitExceeded.value = true;
      deviceAccessGranted.value = false;
      isPremium.value = false;
      isTrialActive.value = false;
      debugPrint(
        '[LicensingService] Device register soft-fail treated as limit '
        '(${devices.length}/${maxDevices.value}, device not in list).',
      );
      return false;
    }

    if (alreadyRegistered || deviceAccessGranted.value) {
      deviceLimitExceeded.value = false;
      deviceAccessGranted.value = true;
      isPremium.value = true;
      isTrialActive.value = false;
      trialExpirationDate.value = null;
      debugPrint(
        '[LicensingService] Device register soft-fail '
        '(${registration.errorCode}: ${registration.errorMessage}); '
        'premium kept (device already known or prior grant).',
      );
      return true;
    }

    // İlk kayıt + sunucu entitled + geçici hata: kısa erişim ver, sonra retry.
    final code = registration.errorCode ?? '';
    final transient = code == 'firebase_unavailable' ||
        code == 'unavailable' ||
        code == 'deadline-exceeded' ||
        code == 'internal' ||
        code == 'unknown';
    if (transient) {
      deviceLimitExceeded.value = false;
      deviceAccessGranted.value = true;
      isPremium.value = true;
      isTrialActive.value = false;
      trialExpirationDate.value = null;
      debugPrint(
        '[LicensingService] Device register soft-fail transient '
        '($code); premium unlocked pending retry.',
      );
      return true;
    }

    deviceAccessGranted.value = false;
    isPremium.value = false;
    debugPrint(
      '[LicensingService] Device register hard-fail '
      '($code: ${registration.errorMessage}); premium locked.',
    );
    return false;
  }

  Future<bool> retryDeviceRegistration() async {
    final ok = await _ensureDeviceRegistration();
    if (ok && purchaseCompleted.value == false) {
      purchaseCompleted.value = true;
    }
    return ok;
  }

  Future<bool> removeRegisteredDevice(String deviceId) async {
    final removed = await LicenseDeviceService.removeDevice(deviceId);
    if (!removed) return false;
    await refreshRegisteredDevices();
    unawaited(retryDeviceRegistration());
    return true;
  }

  Future<void> refreshRegisteredDevices() async {
    final devices = await LicenseDeviceService.listDevices();
    registeredDevices.assignAll(devices);
    deviceCount.value = devices.length;
  }

  void _applyLocalPremium({
    required bool sourceGrandfather,
    DateTime? resolvedPurchaseDate,
  }) {
    licenseEntitled.value = true;
    isGrandfathered.value = sourceGrandfather;
    if (resolvedPurchaseDate != null) {
      purchaseDate.value = resolvedPurchaseDate;
    }
    isPremium.value = true;
    isTrialActive.value = false;
    trialExpirationDate.value = null;
    deviceAccessGranted.value = true;
    deviceLimitExceeded.value = false;
    unawaited(_savePremiumStatusLocally(true));
  }

  Future<int> _getPackageInstallTimeMs() async {
    int? installTime;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        const channel = MethodChannel(channelName);
        final dynamic raw =
            await channel.invokeMethod<dynamic>(getInstallTimeMethod);
        if (raw is int) {
          installTime = raw;
        } else if (raw != null) {
          installTime = int.tryParse(raw.toString());
        }
      }
    } catch (e) {
      debugPrint('[LicensingService] MethodChannel invoke error: $e');
    }

    if (installTime != null && installTime > 0) {
      return installTime;
    }

    final prefs = await SharedPreferences.getInstance();
    const legacyKey = 'mina_first_open_time';
    final int? cached = prefs.getInt(legacyKey);
    if (cached != null && cached > 0) {
      return cached;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(legacyKey, now);
    return now;
  }

  Future<int> _getTrialStartTimeMs() async {
    final prefs = await SharedPreferences.getInstance();
    const trialKey = 'mina_trial_start_ms';
    final int? cached = prefs.getInt(trialKey);

    try {
      if (gFirebaseReady) {
        final hardwareId = await DeviceInfoUtil.getHardwareDeviceId();
        final docRef = FirebaseFirestore.instance.collection('device_trials').doc(hardwareId);
        
        // Timeout ensures we don't block forever if offline
        final docSnap = await docRef.get().timeout(const Duration(seconds: 10));
        
        if (docSnap.exists) {
          final data = docSnap.data();
          if (data != null && data['trialStartMs'] is int) {
            final int serverStartMs = data['trialStartMs'] as int;
            // Sync local cache with server truth
            if (cached != serverStartMs) {
              await prefs.setInt(trialKey, serverStartMs);
            }
            return serverStartMs;
          }
        } else {
          // Document does not exist. Use cached if it exists (e.g. they started trial offline), else generate new
          final int startMs = cached ?? DateTime.now().millisecondsSinceEpoch;
          
          await docRef.set({
            'trialStartMs': startMs,
            'createdAt': FieldValue.serverTimestamp(),
          });
          
          if (cached != startMs) {
            await prefs.setInt(trialKey, startMs);
          }
          return startMs;
        }
      }
    } catch (e) {
      debugPrint('[LicensingService] Firebase trial check failed (offline?): $e');
      // If error (e.g., no internet), it will fall through and use cached or create new locally
    }

    // Fallback: use locally cached trial time
    if (cached != null && cached > 0) {
      return cached;
    }

    // Completely offline and first time ever
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(trialKey, now);
    return now;
  }

  Future<void> _restorePurchasesSilently() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('[LicensingService] Restore purchases failed: $e');
    }
  }

  Future<void> triggerRestore() async {
    if (isBillingAvailable.value) {
      await _awaitBillingRestoreRound();
    }
    if (Get.isRegistered<AuthService>()) {
      await syncLicenseFromAccount(
        user: Get.find<AuthService>().currentUser.value,
      );
    }
    await refreshLicenseAcquisitionDate();
  }

  Future<void> refreshLicenseAcquisitionDate() async {
    if (!licenseEntitled.value && !isPremium.value) return;

    DateTime? resolved;

    try {
      final prefs = await SharedPreferences.getInstance();
      final localMs = prefs.getInt('mina_premium_purchase_date');
      if (localMs != null && localMs > 0) {
        resolved = DateTime.fromMillisecondsSinceEpoch(localMs);
      }

      if (Get.isRegistered<AuthService>()) {
        final auth = Get.find<AuthService>();
        final user = auth.currentUser.value;
        if (user != null && gFirebaseReady) {
          final cloud = await _fetchPurchaseDateFromFirestore(user.uid);
          if (cloud != null) {
            resolved = cloud;
          } else {
            final email = user.email?.trim();
            if (email != null && email.isNotEmpty) {
              final legacy = await _fetchPurchaseDateFromLegacyEmailDoc(email);
              if (legacy != null) resolved = legacy;
            } else if (isGrandfathered.value &&
                user.metadata.creationTime != null) {
              resolved = user.metadata.creationTime;
            }
          }
        }
      }

      if (resolved == null && isGrandfathered.value) {
        final installTime = await _getPackageInstallTimeMs();
        resolved = DateTime.fromMillisecondsSinceEpoch(installTime);
      }

      if (resolved != null) {
        final local = resolved.toLocal();
        purchaseDate.value = local;
        await prefs.setInt(
          'mina_premium_purchase_date',
          local.millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      debugPrint('[LicensingService] refreshLicenseAcquisitionDate: $e');
    }
  }

  String? formatLicenseAcquisitionDate(String languageCode) {
    final d = purchaseDate.value;
    if (d == null) return null;
    final loc = materialLocaleFromLanguageCode(languageCode);
    return DateFormat.yMMMd(loc.toString()).add_Hm().format(d.toLocal());
  }

  void _logPurchaseAttempt(
    String productId,
    bool success,
    String? errorMessage, [
    String? price,
    String? currency,
  ]) {
    try {
      final telemetry = Get.isRegistered<MinaTelemetryService>()
          ? Get.find<MinaTelemetryService>()
          : null;
      telemetry?.logPurchase(
        productId: productId,
        success: success,
        price: price,
        currency: currency,
        errorMessage: errorMessage,
      );
    } catch (e) {
      debugPrint('[LicensingService] Telemetry log error: $e');
    }
  }

  Future<bool> buyPremiumProduct() async {
    try {
      if (!isBillingAvailable.value) {
        _logPurchaseAttempt(premiumProductId, false, 'Billing not available');
        return false;
      }

      final response =
          await InAppPurchase.instance.queryProductDetails({premiumProductId});
      if (response.notFoundIDs.contains(premiumProductId) ||
          response.productDetails.isEmpty) {
        _logPurchaseAttempt(premiumProductId, false, 'Product not found');
        return false;
      }

      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);
      final result = await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: purchaseParam);
      _logPurchaseAttempt(
        premiumProductId,
        result,
        null,
        product.price,
        product.currencyCode,
      );
      return result;
    } catch (e) {
      debugPrint('[LicensingService] Purchase flow error: $e');
      _logPurchaseAttempt(premiumProductId, false, e.toString());
      return false;
    }
  }

  Future<bool> buyPlus3DevicesProduct() async {
    try {
      if (!isBillingAvailable.value) {
        _logPurchaseAttempt(plus3DevicesProductId, false, 'Billing not available');
        return false;
      }

      final response =
          await InAppPurchase.instance.queryProductDetails({plus3DevicesProductId});
      if (response.notFoundIDs.contains(plus3DevicesProductId) ||
          response.productDetails.isEmpty) {
        _logPurchaseAttempt(plus3DevicesProductId, false, 'Product not found');
        return false;
      }

      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);
      final result = await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: purchaseParam);
      _logPurchaseAttempt(
        plus3DevicesProductId,
        result,
        null,
        product.price,
        product.currencyCode,
      );
      return result;
    } catch (e) {
      debugPrint('[LicensingService] +3 Devices Purchase flow error: $e');
      _logPurchaseAttempt(plus3DevicesProductId, false, e.toString());
      return false;
    }
  }


  Future<bool> buyCoffeeProduct() async {
    try {
      if (!isBillingAvailable.value) {
        _logPurchaseAttempt(coffeeProductId, false, 'Billing not available');
        return false;
      }

      final response =
          await InAppPurchase.instance.queryProductDetails({coffeeProductId});
      if (response.notFoundIDs.contains(coffeeProductId) ||
          response.productDetails.isEmpty) {
        _logPurchaseAttempt(coffeeProductId, false, 'Product not found');
        return false;
      }

      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);
      final result = await InAppPurchase.instance
          .buyConsumable(purchaseParam: purchaseParam);
      _logPurchaseAttempt(
        coffeeProductId,
        result,
        null,
        product.price,
        product.currencyCode,
      );
      return result;
    } catch (e) {
      debugPrint('[LicensingService] Coffee purchase flow error: $e');
      _logPurchaseAttempt(coffeeProductId, false, e.toString());
      return false;
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != premiumProductId &&
          purchase.productID != coffeeProductId &&
          purchase.productID != plus3DevicesProductId) {
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (purchase.productID == premiumProductId || purchase.productID == plus3DevicesProductId) {
          if (purchase.productID == premiumProductId) {
            purchaseDate.value =
                _transactionDateFromPurchase(purchase) ?? DateTime.now().toLocal();
          }

          final serverOk = await _activatePremiumOnServer(purchase);
          if (serverOk || licenseEntitled.value) {
            await _ensureDeviceRegistration();
          }

          if (isPremium.value) {
            purchaseCompleted.value = true;
            debugPrint(
              '[LicensingService] Product unlocked via Google Play: ${purchase.productID}',
            );
          } else if (deviceLimitExceeded.value) {
            debugPrint(
              '[LicensingService] Premium verified but device limit reached.',
            );
          } else {
            debugPrint(
              '[LicensingService] Purchase received but server verification pending/failed.',
            );
          }
          _billingRestoreRound?.complete();
        }

        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('[LicensingService] Purchase error: ${purchase.error}');
      }
    }
  }

  Future<void> _savePremiumStatusLocally(bool premium) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('mina_premium_purchased', premium);
      if (premium && purchaseDate.value != null) {
        await prefs.setInt(
          'mina_premium_purchase_date',
          purchaseDate.value!.millisecondsSinceEpoch,
        );
      }
      await prefs.setBool('mina_premium_grandfathered', isGrandfathered.value);
    } catch (e) {
      debugPrint('[LicensingService] Error saving premium status: $e');
    }
  }

  Future<DateTime?> _fetchPurchaseDateFromFirestore(String uid) async {
    if (!gFirebaseReady) return null;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('user_licenses').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null || (data['isPremium'] as bool? ?? false) == false) {
        return null;
      }
      return _parseIsoDate(data['purchaseDate'] as String?) ??
          _parseIsoDate(data['updatedAt'] as String?);
    } catch (e) {
      debugPrint('[LicensingService] _fetchPurchaseDateFromFirestore: $e');
      return null;
    }
  }

  Future<DateTime?> _fetchPurchaseDateFromLegacyEmailDoc(String email) async {
    if (!gFirebaseReady) return null;
    final normalized = _normalizedLicenseEmail(email);
    if (normalized == null) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_licenses')
          .doc(normalized)
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null || (data['isPremium'] as bool? ?? false) == false) {
        return null;
      }
      return _parseIsoDate(data['purchaseDate'] as String?) ??
          _parseIsoDate(data['updatedAt'] as String?);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseIsoDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  DateTime? _transactionDateFromPurchase(PurchaseDetails purchase) {
    final raw = purchase.transactionDate;
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    final ms = int.tryParse(trimmed);
    if (ms != null && ms > 0) {
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return DateTime.tryParse(trimmed);
  }

  Future<void> redeemManualLicense(String code) async {
    try {
      final fn = FirebaseFunctions.instanceFor(region: functionsRegion)
          .httpsCallable('redeemLicenseCode');
      final result = await fn.call({'code': code});
      if (result.data['success'] == true) {
        licenseEntitled.value = true;
        isPremium.value = true;
        isTrialActive.value = false;
        await _savePremiumStatusLocally(true);

        final ok = await _ensureDeviceRegistration();
        if (ok) {
          purchaseCompleted.value = true;
          Get.snackbar('Başarılı', 'Lisansınız başarıyla etkinleştirildi.',
              backgroundColor: const Color(0xFF4ADE80), colorText: const Color(0xFF0F172A));
        } else {
          Get.snackbar('Hata', 'Lisans onaylandı ancak cihaz kaydı başarısız oldu. Lütfen uygulamayı yeniden başlatın.',
              backgroundColor: const Color(0xFFEF4444), colorText: const Color(0xFFFFFFFF));
        }
      }
    } catch (e) {
      Get.snackbar('Hata', 'Lisans kodu geçersiz veya kullanılmış.\n${e.toString()}',
          backgroundColor: const Color(0xFFEF4444), colorText: const Color(0xFFFFFFFF));
      debugPrint('[LicensingService] redeemManualLicense error: $e');
      throw e;
    }
  }
}
