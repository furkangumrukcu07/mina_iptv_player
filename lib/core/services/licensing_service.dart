import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'mina_telemetry_service.dart';
import 'firebase_bootstrap.dart';

class LicensingService extends GetxService {
  static LicensingService get to => Get.find<LicensingService>();

  static const String channelName = 'mina.device/info';
  static const String getInstallTimeMethod = 'getFirstInstallTime';
  static const String premiumProductId = 'mina_premium_lifetime';
  static const String coffeeProductId = 'mina_buy_coffee';

  static final int grandfatherCutoffMs = DateTime.utc(2026, 6, 29).millisecondsSinceEpoch;

  final RxBool isPremium = false.obs;
  final RxBool isGrandfathered = false.obs;
  final Rxn<DateTime> trialExpirationDate = Rxn<DateTime>();
  final Rxn<DateTime> purchaseDate = Rxn<DateTime>(); // Satın alma tarihi
  final RxBool isTrialActive = true.obs;
  final RxBool isBillingAvailable = false.obs;
  final RxBool purchaseCompleted = false.obs; // Satın alım tamamlandığında true
  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialization => _initCompleter.future;

  /// Deneme süresi kalan süresini formatlı string olarak döndürür
  /// Örnek: "1 gün 12 saat", "23 saat", "2 gün"
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

  @override
  void onInit() {
    super.onInit();
    // 1. Ödeme sistemini dinlemeye başla
    _initBilling();
    // 2. İlk yükleme tarihi ve deneme süresi kontrolü
    unawaited(_checkLicenseStatus());
  }

  @override
  void onClose() {
    _purchaseSub?.cancel();
    _authWorker?.dispose();
    super.onClose();
  }

  void _initBilling() {
    // IAP Güncellemelerini dinle
    final purchaseUpdated = InAppPurchase.instance.purchaseStream;
    _purchaseSub = purchaseUpdated.listen(
      _onPurchaseUpdated,
      onError: (err) {
        debugPrint('[LicensingService] Purchase stream error: $err');
      },
    );

    // Google Play Billing kullanılabilirliğini kontrol et
    unawaited(InAppPurchase.instance.isAvailable().then((available) {
      isBillingAvailable.value = available;
      if (available) {
        // Satın almaları geri yükle / sorgula
        unawaited(_restorePurchasesSilently());
      }
    }));
  }

  Future<void> _checkLicenseStatus() async {
    try {
      // 0. Önce kaydedilmiş premium durumunu kontrol et (local fallback)
      final savedPremium = await _getSavedPremiumStatus();
      if (savedPremium) {
        debugPrint('[LicensingService] User has saved premium status (local).');
        isPremium.value = true;
        isTrialActive.value = false;
        trialExpirationDate.value = null;
        // purchaseDate yoksa install time'ı fallback olarak kullan
        if (purchaseDate.value == null) {
          final installTime = await _getFirstInstallTime();
          purchaseDate.value = DateTime.fromMillisecondsSinceEpoch(installTime);
        }
        
        // Firebase Auth ile oturum açıksa ve Firestore'da lisans yoksa migrate et
        if (Get.isRegistered<AuthService>()) {
          final auth = Get.find<AuthService>();
          final user = auth.currentUser.value;
          if (user != null && user.email != null) {
            final firestoreLicense = await _checkLicenseFromFirestore(user.email!);
            if (!firestoreLicense) {
              // Local'de lisans var ama Firestore'da yok → migrate et
              debugPrint('[LicensingService] Migrating local license to Firestore for: ${user.email}');
              await _saveLicenseToFirestore(user.email!, purchaseDate.value);
            }
          }
        }
        return;
      }

      // 0.1 Firebase Auth hesabı varsa Firestore'dan lisans kontrolü yap (multi-device sync)
      if (Get.isRegistered<AuthService>()) {
        final auth = Get.find<AuthService>();
        final user = auth.currentUser.value;
        if (user != null && user.email != null) {
          final firestoreLicense = await _checkLicenseFromFirestore(user.email!);
          if (firestoreLicense) {
            debugPrint('[LicensingService] User has premium license from Firestore.');
            isPremium.value = true;
            isTrialActive.value = false;
            trialExpirationDate.value = null;
            // Local'e de kaydet (offline fallback)
            await _savePremiumStatus(true);
            return;
          }
        }
      }

      // 0.2 Firebase Auth hesabı varsa ve eski kullanıcıysa grandfathering yap
      if (Get.isRegistered<AuthService>()) {
        final auth = Get.find<AuthService>();
        final user = auth.currentUser.value;
        if (user != null && user.metadata.creationTime != null) {
          final creationTime = user.metadata.creationTime!;
          if (creationTime.isBefore(DateTime.utc(2026, 6, 29))) {
            debugPrint('[LicensingService] User is grandfathered via Firebase Account creation date (startup).');
            isGrandfathered.value = true;
            isPremium.value = true;
            isTrialActive.value = false;
            trialExpirationDate.value = null;
            return;
          }
        }
      }

      // 0.3 Firebase Anonymous Auth kullanarak deneme süresi takibi
      if (gFirebaseReady && Get.isRegistered<AuthService>()) {
        final auth = Get.find<AuthService>();
        if (auth.currentUser.value == null) {
          // Kullanıcı oturum açmamışsa anonim kullanıcı oluştur
          try {
            await auth.signInAnonymously();
            debugPrint('[LicensingService] Anonymous user created for trial tracking');
          } catch (e) {
            debugPrint('[LicensingService] Anonymous auth failed: $e');
          }
        }
      }

      // 1. Cihaz ilk yükleme tarihini sorgula
      final int installTime = await _getFirstInstallTime();
      debugPrint('[LicensingService] First install time: ${DateTime.fromMillisecondsSinceEpoch(installTime)}');

      // 2. Eğer ilk kurulum 29 Haziran 2026'dan önceyse, eski kullanıcıdır ve muaf tutulur.
      if (installTime < grandfatherCutoffMs) {
        debugPrint('[LicensingService] User is grandfathered via install date.');
        isGrandfathered.value = true;
        isPremium.value = true;
        isTrialActive.value = false;
        trialExpirationDate.value = null;
        purchaseDate.value = DateTime.fromMillisecondsSinceEpoch(installTime); // Install time'ı satın alma tarihi olarak kaydet
        return;
      }

      // 3. Değilse, deneme süresi hesaplanır (Yükleme tarihinden itibaren 2 gün)
      final installDateTime = DateTime.fromMillisecondsSinceEpoch(installTime);
      final expireDateTime = installDateTime.add(const Duration(days: 2));
      trialExpirationDate.value = expireDateTime;

      final now = DateTime.now();
      if (now.isAfter(expireDateTime)) {
        isTrialActive.value = false;
        debugPrint('[LicensingService] Trial expired.');
      } else {
        isTrialActive.value = true;
        debugPrint('[LicensingService] Trial active. Remaining: ${trialRemainingFormatted}');
      }

      // 4. Firebase Auth dinleyicisi ekleyerek kullanıcı Google ile giriş yaparsa
      // hesap oluşturma tarihi üzerinden de Grandfathering kontrolü yap.
      if (Get.isRegistered<AuthService>()) {
        final auth = Get.find<AuthService>();
        _authWorker = ever(auth.currentUser, (user) {
          if (user != null && user.metadata.creationTime != null) {
            final creationTime = user.metadata.creationTime!;
            if (creationTime.isBefore(DateTime.utc(2026, 6, 29))) {
              debugPrint('[LicensingService] User is grandfathered via Firebase Account creation date.');
              isGrandfathered.value = true;
              isPremium.value = true;
              isTrialActive.value = false;
              trialExpirationDate.value = null;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[LicensingService] Error checking license: $e');
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  Future<int> _getFirstInstallTime() async {
    // Native install time'ı sorgula (Android'in sistem kayıtlarından)
    int? installTime;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        const channel = MethodChannel(channelName);
        final dynamic raw = await channel.invokeMethod<dynamic>(getInstallTimeMethod);
        if (raw is int) {
          installTime = raw;
        } else if (raw != null) {
          // Java long bazen String olarak gelebilir
          installTime = int.tryParse(raw.toString());
        }
      }
    } catch (e) {
      debugPrint('[LicensingService] MethodChannel invoke error: $e');
    }

    // Native'den alınabildiyse dön
    if (installTime != null && installTime > 0) {
      debugPrint('[LicensingService] Native install time: ${DateTime.fromMillisecondsSinceEpoch(installTime)}');
      return installTime;
    }

    // Native'den alınamazsa SharedPreferences cache'e bak (fallback)
    final prefs = await SharedPreferences.getInstance();
    const key = 'mina_first_open_time';
    final int? cached = prefs.getInt(key);
    if (cached != null && cached > 0) {
      debugPrint('[LicensingService] Using cached install time (fallback): ${DateTime.fromMillisecondsSinceEpoch(cached)}');
      return cached;
    }

    // Son çare: şu anki zamanı kaydet
    debugPrint('[LicensingService] WARNING: Could not get native install time, using DateTime.now()');
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(key, now);
    return now;
  }

  Future<void> _restorePurchasesSilently() async {
    try {
      // Not: in_app_purchase kütüphanesi restorePurchases() çağrıldığında purchaseStream üzerinden güncellemeleri tetikler.
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('[LicensingService] Restore purchases failed: $e');
    }
  }

  Future<void> triggerRestore() async {
    await _restorePurchasesSilently();
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
        debugPrint('[LicensingService] Billing not available.');
        _logPurchaseAttempt(premiumProductId, false, 'Billing not available');
        return false;
      }

      final response = await InAppPurchase.instance.queryProductDetails({premiumProductId});
      if (response.notFoundIDs.contains(premiumProductId) || response.productDetails.isEmpty) {
        debugPrint('[LicensingService] Premium product not found in Google Play.');
        _logPurchaseAttempt(premiumProductId, false, 'Product not found');
        return false;
      }

      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);
      final result = await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
      _logPurchaseAttempt(premiumProductId, result, null, product.price, product.currencyCode);
      return result;
    } catch (e) {
      debugPrint('[LicensingService] Purchase flow error: $e');
      _logPurchaseAttempt(premiumProductId, false, e.toString());
      return false;
    }
  }

  Future<bool> buyCoffeeProduct() async {
    try {
      if (!isBillingAvailable.value) {
        debugPrint('[LicensingService] Billing not available.');
        _logPurchaseAttempt(coffeeProductId, false, 'Billing not available');
        return false;
      }

      final response = await InAppPurchase.instance.queryProductDetails({coffeeProductId});
      if (response.notFoundIDs.contains(coffeeProductId) || response.productDetails.isEmpty) {
        debugPrint('[LicensingService] Coffee product not found in Google Play.');
        _logPurchaseAttempt(coffeeProductId, false, 'Product not found');
        return false;
      }

      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);
      final result = await InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
      _logPurchaseAttempt(coffeeProductId, result, null, product.price, product.currencyCode);
      return result;
    } catch (e) {
      debugPrint('[LicensingService] Coffee purchase flow error: $e');
      _logPurchaseAttempt(coffeeProductId, false, e.toString());
      return false;
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        // Satın alım başarılı! Premium kilidini aç.
        isPremium.value = true;
        isTrialActive.value = false;
        trialExpirationDate.value = null;
        purchaseDate.value = DateTime.now(); // Satın alma tarihini kaydet
        purchaseCompleted.value = true; // Satın alım tamamlandı event'i
        debugPrint('[LicensingService] Premium unlocked via Google Play purchase: ${purchase.productID}');

        // Satın alma durumunu kalıcı olarak kaydet
        await _savePremiumStatus(true);

        // Google Play faturalandırma kuralları gereği satın alımın onaylanması (completePurchase) gerekir.
        if (purchase.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('[LicensingService] Purchase error: ${purchase.error}');
      }
    }
  }

  Future<void> _savePremiumStatus(bool isPremium) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('mina_premium_purchased', isPremium);
      // purchaseDate'i de sakla
      if (isPremium && purchaseDate.value != null) {
        await prefs.setInt('mina_premium_purchase_date', purchaseDate.value!.millisecondsSinceEpoch);
      }
      debugPrint('[LicensingService] Premium status saved locally: $isPremium');
      
      // Firebase Auth ile oturum açıksa Firestore'a da kaydet (multi-device sync)
      if (isPremium && Get.isRegistered<AuthService>()) {
        final auth = Get.find<AuthService>();
        final user = auth.currentUser.value;
        if (user != null && user.email != null) {
          await _saveLicenseToFirestore(user.email!, purchaseDate.value);
        }
      }
    } catch (e) {
      debugPrint('[LicensingService] Error saving premium status: $e');
    }
  }

  Future<void> _saveLicenseToFirestore(String email, DateTime? purchaseDate) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection('user_licenses').doc(email);
      
      await docRef.set({
        'email': email,
        'isPremium': true,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      
      debugPrint('[LicensingService] License saved to Firestore for: $email');
    } catch (e) {
      debugPrint('[LicensingService] Error saving license to Firestore: $e');
    }
  }

  Future<bool> _checkLicenseFromFirestore(String email) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection('user_licenses').doc(email);
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final isPremium = data['isPremium'] as bool? ?? false;
        if (isPremium) {
          final purchaseDateStr = data['purchaseDate'] as String?;
          if (purchaseDateStr != null) {
            purchaseDate.value = DateTime.parse(purchaseDateStr);
          }
          debugPrint('[LicensingService] License found in Firestore for: $email');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[LicensingService] Error checking license from Firestore: $e');
      return false;
    }
  }

  Future<bool> _getSavedPremiumStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('mina_premium_purchased') ?? false;
      // purchaseDate'i yükle
      if (isPremium) {
        final savedDate = prefs.getInt('mina_premium_purchase_date');
        if (savedDate != null) {
          purchaseDate.value = DateTime.fromMillisecondsSinceEpoch(savedDate);
        }
      }
      return isPremium;
    } catch (e) {
      debugPrint('[LicensingService] Error getting saved premium status: $e');
      return false;
    }
  }
}
