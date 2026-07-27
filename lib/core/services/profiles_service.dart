import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profiles/mina_profile.dart';
import '../profiles/profile_pref_keys.dart';
import 'app_settings_service.dart';
import 'favorites_service.dart';
import 'watch_progress_service.dart';

/// Netflix tarzı çoklu profil yönetimi.
///
/// Her profil yalnızca **deneyim tercihlerini** (tema, dil, ana ekran düzeni,
/// +18 gizleme, altyazı, favoriler, izleme geçmişi) kendi içinde tutar;
/// M3U/Xtream listeleri ve kimlik bilgileri tüm profiller arasında paylaşılır.
///
/// Profil verisi `mina_*` SharedPreferences anahtarlarında saklandığından
/// mevcut bulut yedeği ([BackupService] → Firestore) ile **otomatik** senkron
/// olur; ayrı bir bulut şemasına gerek yoktur.
class ProfilesService extends GetxService {
  static const _kProfiles = 'mina_profiles_v1';
  static const _kActive = 'mina_active_profile_v1';
  static const _kSnapshotPrefix = 'mina_profile_data_'; // + profil id
  static const _salt = 'mina_iptv_profile|v1';

  final RxList<MinaProfile> profiles = <MinaProfile>[].obs;
  final RxnString activeId = RxnString();

  bool _inited = false;

  MinaProfile? byId(String? id) {
    if (id == null) return null;
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  MinaProfile? get activeProfile => byId(activeId.value);

  /// Birincil (ilk oluşturulan) profil — Google hesabıyla otomatik eşitlenen
  /// profil budur. En küçük `createdAt`'a sahip olan.
  MinaProfile? get primaryProfile {
    if (profiles.isEmpty) return null;
    var p = profiles.first;
    for (final e in profiles) {
      if (e.createdAt < p.createdAt) p = e;
    }
    return p;
  }

  static String hashPin(String pin) =>
      sha256.convert(utf8.encode('${pin.trim()}|$_salt')).toString();

  /// Kurtarma anahtarı hash'i. Kullanılabilirlik için normalize edilir
  /// (kırp + küçük harf + iç boşlukları sadeleştir).
  static String hashRecovery(String key) {
    final norm = key.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return sha256.convert(utf8.encode('$norm|recovery|$_salt')).toString();
  }

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    await _loadFromPrefs();
    if (profiles.isEmpty) {
      // İlk açılış: mevcut ayarlardan varsayılan bir profil oluştur ki mevcut
      // kullanıcıların deneyimi bozulmasın.
      final def = _newProfile(name: 'Profil 1', avatarId: 0);
      profiles.add(def);
      activeId.value = def.id;
      await _persistList();
      await _persistActive();
      await _snapshotCurrentInto(def.id);
    }
  }

  /// Bulut geri yüklemesi prefs'i değiştirdikten sonra: profilleri yeniden oku.
  Future<void> reload() async {
    _inited = true;
    await _loadFromPrefs();
    if (profiles.isEmpty) {
      _inited = false;
      await init();
    }
  }

  Future<void> _loadFromPrefs() async {
    final p = await SharedPreferences.getInstance();
    profiles.assignAll(MinaProfile.listFromJsonString(p.getString(_kProfiles)));
    final active = p.getString(_kActive);
    if (active != null && profiles.any((e) => e.id == active)) {
      activeId.value = active;
    } else {
      activeId.value = profiles.isNotEmpty ? profiles.first.id : null;
    }
  }

  MinaProfile _newProfile({
    required String name,
    required int avatarId,
    String? lockHash,
    String? recoveryHash,
  }) {
    final clean = name.trim().isEmpty ? 'Profil' : name.trim();
    return MinaProfile(
      id: 'p_${DateTime.now().microsecondsSinceEpoch}',
      name: clean,
      avatarId: avatarId,
      lockHash: lockHash,
      recoveryHash: recoveryHash,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _persistList() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kProfiles, MinaProfile.listToJsonString(profiles));
  }

  Future<void> _persistActive() async {
    final p = await SharedPreferences.getInstance();
    final id = activeId.value;
    if (id == null) {
      await p.remove(_kActive);
    } else {
      await p.setString(_kActive, id);
    }
  }

  /// Mevcut (canlı) profile-özel ayarları belirtilen profilin snapshot'i
  /// olarak kaydeder.
  Future<void> _snapshotCurrentInto(String id) async {
    final p = await SharedPreferences.getInstance();
    final snap = snapshotProfilePrefs(p);
    await p.setString('$_kSnapshotPrefix$id', jsonEncode(snap));
  }

  // ---- CRUD ----------------------------------------------------------------

  /// Yeni profil oluşturur. Snapshot'i mevcut (aktif) ayarların kopyasıyla
  /// başlatır — kullanıcı sıfırdan kurmasın.
  Future<MinaProfile> createProfile({
    required String name,
    int avatarId = 0,
    String? pin,
    String? recoveryKey,
  }) async {
    final locked = pin != null && pin.isNotEmpty;
    final prof = _newProfile(
      name: name,
      avatarId: avatarId,
      lockHash: locked ? hashPin(pin) : null,
      recoveryHash: (locked && recoveryKey != null && recoveryKey.isNotEmpty)
          ? hashRecovery(recoveryKey)
          : null,
    );
    profiles.add(prof);
    await _persistList();
    await _snapshotCurrentInto(prof.id);
    return prof;
  }

  Future<void> rename(String id, String name) async {
    final i = profiles.indexWhere((e) => e.id == id);
    if (i < 0) return;
    profiles[i] = profiles[i].copyWith(name: name.trim());
    profiles.refresh();
    await _persistList();
  }

  Future<void> setAvatar(String id, int avatarId) async {
    final i = profiles.indexWhere((e) => e.id == id);
    if (i < 0) return;
    profiles[i] = profiles[i].copyWith(avatarId: avatarId);
    profiles.refresh();
    await _persistList();
  }

  /// Birincil profili Google hesabıyla eşitler: isim + profil fotoğrafı.
  /// Kullanıcı birincil profili manuel düzenlediyse (`googleLinked == false`)
  /// hiçbir şey yapmaz. Oturum açıldığında [AuthService] tarafından çağrılır.
  Future<void> syncPrimaryFromGoogle({
    String? displayName,
    String? photoUrl,
  }) async {
    final primary = primaryProfile;
    if (primary == null) return;
    if (primary.googleLinked == false) return; // kullanıcı manuel ayırdı

    final name = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : primary.name;
    final photo = (photoUrl != null && photoUrl.trim().isNotEmpty)
        ? photoUrl.trim()
        : null;

    // Değişiklik yoksa diske yazma (gereksiz refresh/IO).
    if (primary.name == name &&
        primary.photoUrl == photo &&
        primary.googleLinked == true) {
      return;
    }

    final i = profiles.indexWhere((e) => e.id == primary.id);
    if (i < 0) return;
    profiles[i] = primary.copyWith(
      name: name,
      photoUrl: photo,
      clearPhoto: photo == null,
      googleLinked: true,
    );
    profiles.refresh();
    await _persistList();
  }

  /// Kullanıcı birincil profili manuel düzenlediğinde otomatik Google
  /// eşitlemesini durdurur ve isteğe bağlı olarak fotoğrafı günceller/temizler.
  Future<void> detachPrimaryFromGoogle(String id, {String? photoUrl}) async {
    final i = profiles.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;
    profiles[i] = profiles[i].copyWith(
      photoUrl: hasPhoto ? photoUrl.trim() : null,
      clearPhoto: !hasPhoto,
      googleLinked: false,
    );
    profiles.refresh();
    await _persistList();
  }

  /// Oturum kapandığında birincil profilin Google fotoğrafını temizler
  /// (URL'ler süreli; ayrıca artık o hesaba bağlı değiliz).
  Future<void> clearGoogleLinkOnSignOut() async {
    final primary = primaryProfile;
    if (primary == null) return;
    if (primary.googleLinked != true) return;
    final i = profiles.indexWhere((e) => e.id == primary.id);
    if (i < 0) return;
    profiles[i] = primary.copyWith(clearPhoto: true, googleLinked: null);
    profiles.refresh();
    await _persistList();
  }

  /// PIN (4 hane) belirler. [recoveryKey] verilirse kurtarma anahtarı da
  /// güncellenir; verilmezse mevcut kurtarma anahtarı korunur.
  Future<void> setLock(String id, String pin, {String? recoveryKey}) async {
    final i = profiles.indexWhere((e) => e.id == id);
    if (i < 0 || pin.isEmpty) return;
    final current = profiles[i];
    final String? nextRecovery;
    if (recoveryKey != null && recoveryKey.trim().isNotEmpty) {
      nextRecovery = hashRecovery(recoveryKey);
    } else {
      nextRecovery = current.recoveryHash;
    }
    profiles[i] = current.copyWith(
      lockHash: hashPin(pin),
      recoveryHash: nextRecovery,
    );
    profiles.refresh();
    await _persistList();
  }

  Future<void> clearLock(String id) async {
    final i = profiles.indexWhere((e) => e.id == id);
    if (i < 0) return;
    profiles[i] = profiles[i].copyWith(clearLock: true);
    profiles.refresh();
    await _persistList();
  }

  bool verifyLock(String id, String pin) {
    final prof = byId(id);
    if (prof == null || !prof.isLocked) return true;
    return prof.lockHash == hashPin(pin);
  }

  /// Kurtarma anahtarını doğrular.
  bool verifyRecovery(String id, String key) {
    final prof = byId(id);
    if (prof == null || !prof.hasRecovery) return false;
    return prof.recoveryHash == hashRecovery(key);
  }

  /// Profili siler. En az bir profil her zaman kalır. Aktif profil silinirse
  /// kalan ilk profile geçilir.
  Future<void> delete(String id) async {
    if (profiles.length <= 1) return;
    final wasActive = activeId.value == id;
    profiles.removeWhere((e) => e.id == id);
    final p = await SharedPreferences.getInstance();
    await p.remove('$_kSnapshotPrefix$id');
    await _persistList();
    if (wasActive && profiles.isNotEmpty) {
      await switchTo(profiles.first.id, force: true);
    }
  }

  // ---- Profil değiştirme ---------------------------------------------------

  /// Aktif profilin güncel ayarlarını snapshot'lar, hedef profilin snapshot'ini
  /// uygular ve bağımlı servisleri bellekte yeniler.
  ///
  /// [force] true ise aktif profile geçişte bile (silme sonrası) snapshot
  /// uygulanır. Kilitli profillerde PIN doğrulaması ÇAĞIRANIN sorumluluğudur.
  Future<bool> switchTo(String id, {bool force = false}) async {
    if (!force && id == activeId.value) return true;
    final target = byId(id);
    if (target == null) return false;

    final p = await SharedPreferences.getInstance();

    // 1) Aktif profilin canlı ayarlarını sakla.
    final cur = activeId.value;
    if (cur != null && cur != id) {
      await _snapshotCurrentInto(cur);
    }

    // 2) Hedef snapshot'ı uygula.
    final raw = p.getString('$_kSnapshotPrefix$id');
    var snap = <String, dynamic>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw);
        if (d is Map) snap = Map<String, dynamic>.from(d);
      } catch (_) {}
    }
    await applyProfilePrefs(p, snap);

    // 3) Aktif id'yi yaz.
    activeId.value = id;
    await _persistActive();

    // 4) Bellekteki servisleri diskten yenile.
    await _refreshServices();
    return true;
  }

  Future<void> _refreshServices() async {
    try {
      if (Get.isRegistered<AppSettingsService>()) {
        await Get.find<AppSettingsService>().reloadAllFromPrefs();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ProfilesService] settings reload error: $e');
    }
    try {
      if (Get.isRegistered<FavoritesService>()) {
        await Get.find<FavoritesService>().reload();
      }
    } catch (_) {}
    try {
      if (Get.isRegistered<WatchProgressService>()) {
        await Get.find<WatchProgressService>().reload();
      }
    } catch (_) {}
  }
}
