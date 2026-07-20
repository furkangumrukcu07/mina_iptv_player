const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');
const { google } = require('googleapis');

admin.initializeApp();

setGlobalOptions({ region: 'europe-west1', maxInstances: 20 });

const db = admin.firestore();
const auth = admin.auth();

const MAX_DEVICES = 3;
const PACKAGE_NAME = 'com.mina.iptv.mina_iptv_player';
const PREMIUM_PRODUCT_ID = 'mina_premium_lifetime';
const PLUS3_PRODUCT_ID = 'mina_total_6devices';
const GRANDFATHER_CUTOFF_MS = Date.UTC(2026, 5, 29); // 29 Haziran 2026 00:00 UTC

function requireAuth(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Oturum açmanız gerekiyor.');
  }
  return request.auth.uid;
}

const ADMIN_EMAILS = ['furkangumrukcu07@gmail.com'];

function requireAdmin(request) {
  const uid = requireAuth(request);
  const email = request.auth?.token?.email;
  if (!email || !ADMIN_EMAILS.includes(email.toLowerCase())) {
    throw new HttpsError('permission-denied', 'Bu işlem için yönetici yetkisi gereklidir.');
  }
  return uid;
}

function normalizeEmail(email) {
  if (!email || typeof email !== 'string') return null;
  const trimmed = email.trim().toLowerCase();
  return trimmed.length > 0 ? trimmed : null;
}

function parseIsoDate(value) {
  if (!value || typeof value !== 'string') return null;
  const d = new Date(value.trim());
  return Number.isNaN(d.getTime()) ? null : d;
}

function licenseRef(uid) {
  return db.collection('user_licenses').doc(uid);
}

function devicesCol(uid) {
  return licenseRef(uid).collection('devices');
}

async function readLicense(uid) {
  const snap = await licenseRef(uid).get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  if (data.isPremium !== true && data.isBanned !== true) return null;
  return data;
}

async function migrateLegacyEmailLicense(uid, email) {
  const normalized = normalizeEmail(email);
  if (!normalized) return null;

  const legacySnap = await db.collection('user_licenses').doc(normalized).get();
  if (!legacySnap.exists) return null;

  const legacy = legacySnap.data() || {};
  if (legacy.isPremium !== true) return null;

  const purchaseDate =
    parseIsoDate(legacy.purchaseDate) ||
    parseIsoDate(legacy.updatedAt) ||
    new Date();

  const payload = {
    uid,
    email: normalized,
    isPremium: true,
    source: legacy.source || 'legacy_email',
    purchaseDate: purchaseDate.toISOString(),
    updatedAt: new Date().toISOString(),
    migratedFromEmail: normalized,
  };

  await licenseRef(uid).set(payload, { merge: true });
  return payload;
}

async function grantGrandfatherAccount(uid, email, creationTime) {
  if (!creationTime) return null;
  const createdMs = creationTime.getTime();
  if (createdMs >= GRANDFATHER_CUTOFF_MS) return null;

  const payload = {
    uid,
    email: normalizeEmail(email),
    isPremium: true,
    source: 'grandfather_account',
    purchaseDate: creationTime.toISOString(),
    updatedAt: new Date().toISOString(),
  };
  await licenseRef(uid).set(payload, { merge: true });
  return payload;
}

async function getAndroidPublisher() {
  const authClient = await google.auth.getClient({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  return google.androidpublisher({ version: 'v3', auth: authClient });
}

async function verifyPlayProductPurchase(productId, purchaseToken) {
  const publisher = await getAndroidPublisher();
  const res = await publisher.purchases.products.get({
    packageName: PACKAGE_NAME,
    productId,
    token: purchaseToken,
  });
  const data = res.data || {};
  // purchaseState: 0 = purchased, 1 = canceled
  if (data.purchaseState !== 0) {
    throw new HttpsError('failed-precondition', 'Satın alım geçerli değil.');
  }
  return data;
}

function sanitizeDeviceId(deviceId) {
  if (!deviceId || typeof deviceId !== 'string') return null;
  const trimmed = deviceId.trim();
  if (trimmed.length < 8 || trimmed.length > 128) return null;
  if (!/^[a-zA-Z0-9._-]+$/.test(trimmed)) return null;
  return trimmed;
}

function sanitizeDeviceLabel(label) {
  if (!label || typeof label !== 'string') return 'Cihaz';
  const trimmed = label.trim().slice(0, 80);
  return trimmed.length > 0 ? trimmed : 'Cihaz';
}

async function listDevices(uid) {
  const snap = await devicesCol(uid).get();
  return snap.docs.map((doc) => {
    const d = doc.data() || {};
    return {
      deviceId: doc.id,
      label: d.label || 'Cihaz',
      registeredAt: d.registeredAt || null,
      lastSeenAt: d.lastSeenAt || null,
    };
  });
}

async function countDevices(uid) {
  const snap = await devicesCol(uid).count().get();
  return snap.data().count || 0;
}

/**
 * Oturum açmış kullanıcı için lisans durumunu sunucuda çözümler.
 * İstemci artık user_licenses belgesine doğrudan yazamaz.
 */
exports.syncLicenseEntitlements = onCall(async (request) => {
  const uid = requireAuth(request);
  const token = request.auth.token || {};
  const email = token.email || null;

  let license = await readLicense(uid);

  if (!license) {
    license = await migrateLegacyEmailLicense(uid, email);
  }

  if (!license) {
    try {
      const user = await auth.getUser(uid);
      license = await grantGrandfatherAccount(
        uid,
        user.email,
        user.metadata?.creationTime ? new Date(user.metadata.creationTime) : null,
      );
    } catch (e) {
      console.warn('syncLicenseEntitlements:getUser', e);
    }
  }

  if (!license) {
    return {
      isPremium: false,
      isBanned: false,
      source: null,
      purchaseDate: null,
      deviceCount: 0,
      maxDevices: MAX_DEVICES,
    };

  }

  const devices = await listDevices(uid);
  return {
    isPremium: true,
    isBanned: license.isBanned === true,
    source: license.source || 'unknown',
    purchaseDate: license.purchaseDate || null,
    deviceCount: devices.length,
    maxDevices: license.maxDevices || MAX_DEVICES,
    devices,
  };
});

/**
 * Google Play satın alımını doğrular ve lisansı sunucuda yazar.
 */
exports.activatePremiumFromPlay = onCall(async (request) => {
  const uid = requireAuth(request);
  const purchaseToken = request.data?.purchaseToken;
  const productId = request.data?.productId || PREMIUM_PRODUCT_ID;

  if (!purchaseToken || typeof purchaseToken !== 'string') {
    throw new HttpsError('invalid-argument', 'purchaseToken gerekli.');
  }
  if (productId !== PREMIUM_PRODUCT_ID && productId !== PLUS3_PRODUCT_ID) {
    throw new HttpsError('invalid-argument', 'Geçersiz ürün kimliği.');
  }

  let playData;
  try {
    playData = await verifyPlayProductPurchase(productId, purchaseToken);
  } catch (e) {
    console.error('activatePremiumFromPlay:verify', e);
    if (e instanceof HttpsError) throw e;
    throw new HttpsError(
      'failed-precondition',
      'Google Play doğrulaması başarısız. Play Console hizmet hesabı bağlı mı?',
    );
  }

  const purchaseTimeMs = Number(playData.purchaseTimeMillis || Date.now());
  const purchaseDate = new Date(
    Number.isFinite(purchaseTimeMs) ? purchaseTimeMs : Date.now(),
  );

  const email = normalizeEmail(request.auth.token?.email);
  const payload = {
    uid,
    email,
    isPremium: true,
    source: 'play',
    productId,
    playOrderId: playData.orderId || null,
    purchaseDate: purchaseDate.toISOString(),
    updatedAt: new Date().toISOString(),
  };

  if (productId === PLUS3_PRODUCT_ID) {
    payload.maxDevices = 6;
  }

  await licenseRef(uid).set(payload, { merge: true });

  return {
    isPremium: true,
    source: 'play',
    purchaseDate: payload.purchaseDate,
    playOrderId: payload.playOrderId,
  };
});

/**
 * Kurulum tarihi muafiyeti — yalnızca sunucuda kayıt (istemci doğrudan yazamaz).
 */
exports.claimInstallGrandfather = onCall(async (request) => {
  const uid = requireAuth(request);
  const firstInstallMs = Number(request.data?.firstInstallTimeMs);
  if (!Number.isFinite(firstInstallMs) || firstInstallMs <= 0) {
    throw new HttpsError('invalid-argument', 'firstInstallTimeMs gerekli.');
  }
  if (firstInstallMs >= GRANDFATHER_CUTOFF_MS) {
    throw new HttpsError('failed-precondition', 'Kurulum tarihi muafiyet kapsamında değil.');
  }

  const existing = await readLicense(uid);
  if (existing) {
    return {
      isPremium: true,
      source: existing.source || 'unknown',
      purchaseDate: existing.purchaseDate || null,
      alreadyGranted: true,
    };
  }

  const purchaseDate = new Date(firstInstallMs);
  const email = normalizeEmail(request.auth.token?.email);
  const payload = {
    uid,
    email,
    isPremium: true,
    source: 'grandfather_install',
    purchaseDate: purchaseDate.toISOString(),
    updatedAt: new Date().toISOString(),
  };
  await licenseRef(uid).set(payload, { merge: true });

  return {
    isPremium: true,
    source: 'grandfather_install',
    purchaseDate: payload.purchaseDate,
    alreadyGranted: false,
  };
});

/**
 * Premium lisanslı kullanıcı için cihaz kaydı (en fazla 3).
 */
exports.registerLicenseDevice = onCall(async (request) => {
  const uid = requireAuth(request);
  const deviceId = sanitizeDeviceId(request.data?.deviceId);
  const deviceLabel = sanitizeDeviceLabel(request.data?.deviceLabel);

  if (!deviceId) {
    throw new HttpsError('invalid-argument', 'Geçersiz deviceId.');
  }

  const license = await readLicense(uid);
  if (!license) {
    throw new HttpsError('permission-denied', 'Aktif premium lisans bulunamadı.');
  }

  const deviceRef = devicesCol(uid).doc(deviceId);
  const existing = await deviceRef.get();
  const now = new Date().toISOString();

  const maxDevicesAllowed = license.maxDevices || MAX_DEVICES;

  if (existing.exists) {
    await deviceRef.set(
      {
        label: deviceLabel,
        lastSeenAt: now,
      },
      { merge: true },
    );
    const devices = await listDevices(uid);
    return {
      registered: true,
      deviceId,
      deviceCount: devices.length,
      maxDevices: maxDevicesAllowed,
      devices,
      reused: true,
    };
  }

  const total = await countDevices(uid);
  if (total >= maxDevicesAllowed) {
    throw new HttpsError(
      'resource-exhausted',
      'DEVICE_LIMIT_EXCEEDED',
      { maxDevices: maxDevicesAllowed, deviceCount: total },
    );
  }

  await deviceRef.set({
    label: deviceLabel,
    registeredAt: now,
    lastSeenAt: now,
  });

  const devices = await listDevices(uid);
  return {
    registered: true,
    deviceId,
    deviceCount: devices.length,
    maxDevices: maxDevicesAllowed,
    devices,
    reused: false,
  };
});

exports.listLicenseDevices = onCall(async (request) => {
  const uid = requireAuth(request);
  const license = await readLicense(uid);
  if (!license) {
    return { devices: [], maxDevices: MAX_DEVICES, deviceCount: 0 };
  }
  const devices = await listDevices(uid);
  return {
    devices,
    maxDevices: license.maxDevices || MAX_DEVICES,
    deviceCount: devices.length,
  };
});

exports.removeLicenseDevice = onCall(async (request) => {
  const uid = requireAuth(request);
  const deviceId = sanitizeDeviceId(request.data?.deviceId);
  if (!deviceId) {
    throw new HttpsError('invalid-argument', 'Geçersiz deviceId.');
  }

  const license = await readLicense(uid);
  if (!license) {
    throw new HttpsError('permission-denied', 'Aktif premium lisans bulunamadı.');
  }

  await devicesCol(uid).doc(deviceId).delete();
  const devices = await listDevices(uid);
  return {
    removed: true,
    deviceId,
    devices,
    deviceCount: devices.length,
    maxDevices: license.maxDevices || MAX_DEVICES,
  };
});

exports.redeemLicenseCode = onCall(async (request) => {
  const uid = requireAuth(request);
  const code = request.data?.code;
  if (!code || typeof code !== 'string' || code.trim() === '') {
    throw new HttpsError('invalid-argument', 'Geçersiz lisans kodu.');
  }

  const codeId = code.trim().toUpperCase();
  const codeRef = db.collection('license_codes').doc(codeId);

  return await db.runTransaction(async (transaction) => {
    const codeDoc = await transaction.get(codeRef);
    if (!codeDoc.exists) {
      throw new HttpsError('not-found', 'Bu lisans kodu geçersiz veya bulunamadı.');
    }

    const codeData = codeDoc.data();
    if (codeData.is_used) {
      throw new HttpsError('already-exists', 'Bu lisans kodu daha önce kullanılmış.');
    }

    // Mark as used
    transaction.update(codeRef, {
      is_used: true,
      used_by: uid,
      used_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Grant premium
    const userLicenseRef = licenseRef(uid);
    transaction.set(userLicenseRef, {
      isPremium: true,
      purchaseDate: admin.firestore.FieldValue.serverTimestamp(),
      platform: 'manual_code',
      premiumProductId: 'mina_premium_lifetime',
    }, { merge: true });

    return { success: true };
  });
});

exports.sendBroadcastNotification = onCall(async (request) => {
  requireAdmin(request);
  const { title, body } = request.data || {};
  if (!title || !body) {
    throw new HttpsError('invalid-argument', 'Başlık ve içerik gereklidir.');
  }
  
  try {
    const message = {
      topic: 'all',
      notification: {
        title,
        body
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default'
          }
        }
      }
    };
    
    await admin.messaging().send(message);
    return { success: true };
  } catch (error) {
    console.error('Push notification error:', error);
    throw new HttpsError('internal', 'Bildirim gönderilemedi.');
  }
});

/**
 * Admin: Tüm kullanıcıları listele (Auth üzerinden).
 * Auth üzerindeki tüm kullanıcıları sayfa sayfa çekip users ve user_licenses koleksiyonları ile birleştirir.
 */
exports.adminListAllUsers = onCall(async (request) => {
  requireAdmin(request);

  let allAuthUsers = [];
  let pageToken;
  try {
    do {
      const listUsersResult = await admin.auth().listUsers(1000, pageToken);
      allAuthUsers.push(...listUsersResult.users);
      pageToken = listUsersResult.pageToken;
    } while (pageToken);
  } catch (error) {
    console.error('List users error:', error);
    throw new HttpsError('internal', 'Firebase Auth kullanıcıları çekilemedi.');
  }

  const uids = allAuthUsers.map(u => u.uid);

  const licenseMap = {};
  const userMap = {};

  if (uids.length > 0) {
    const chunks = [];
    for (let i = 0; i < uids.length; i += 30) {
      chunks.push(uids.slice(i, i + 30));
    }
    
    for (const chunk of chunks) {
      const licSnap = await db.collection('user_licenses')
        .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
        .get();
      licSnap.docs.forEach(d => { licenseMap[d.id] = d.data(); });

      const uSnap = await db.collection('users')
        .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
        .get();
      uSnap.docs.forEach(d => { userMap[d.id] = d.data(); });
    }
  }

  const results = allAuthUsers.map(authUser => {
    const u = userMap[authUser.uid] || {};
    const lic = licenseMap[authUser.uid] || {};
    return {
      uid: authUser.uid,
      email: authUser.email || u.email || lic.email || null,
      displayName: authUser.displayName || u.displayName || null,
      photoUrl: authUser.photoUrl || u.photoUrl || null,
      lastLoginAt: u.lastLoginAt ? u.lastLoginAt.toMillis() : (authUser.metadata.lastSignInTime ? new Date(authUser.metadata.lastSignInTime).getTime() : null),
      lastDeviceName: u.lastDeviceName || null,
      lastDeviceOS: u.lastDeviceOS || null,
      isPremium: lic.isPremium === true,
      isBanned: lic.isBanned === true,
      premiumSource: lic.source || null,
      purchaseDate: lic.purchaseDate || null,
      maxDevices: lic.maxDevices || 3,
      isAnonymous: !authUser.email && !u.email && !lic.email,
    };
  });

  // Son giriş yapanlar en üstte
  results.sort((a, b) => {
    const tA = a.lastLoginAt || 0;
    const tB = b.lastLoginAt || 0;
    return tB - tA;
  });

  return { users: results, total: results.length };
});

exports.adminManageUser = onCall(async (request) => {
  requireAdmin(request);
  const { targetUid, action, limit } = request.data || {};
  if (!targetUid || !action) {
    throw new HttpsError('invalid-argument', 'Hedef UID ve aksiyon gereklidir.');
  }

  const targetLicenseRef = licenseRef(targetUid);
  
  try {
    if (action === 'ban') {
      await targetLicenseRef.set({ isBanned: true }, { merge: true });
      return { success: true, action: 'ban' };
    } else if (action === 'unban') {
      await targetLicenseRef.set({ isBanned: false }, { merge: true });
      return { success: true, action: 'unban' };
    } else if (action === 'reset_devices') {
      const snap = await devicesCol(targetUid).get();
      const batch = db.batch();
      snap.docs.forEach(doc => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      return { success: true, action: 'reset_devices' };
    } else if (action === 'set_device_limit') {
      if (typeof limit !== 'number' || limit < 0) {
        throw new HttpsError('invalid-argument', 'Geçerli bir limit değeri girilmelidir.');
      }
      await targetLicenseRef.set({ maxDevices: limit }, { merge: true });
      return { success: true, action: 'set_device_limit' };
    } else {
      throw new HttpsError('invalid-argument', 'Geçersiz aksiyon.');
    }
  } catch (error) {
    console.error('adminManageUser error:', error);
    throw new HttpsError('internal', 'İşlem başarısız oldu.');
  }
});

// ─── Admin: Son Siparişler (Satın Alımlar) ────────────────────────────────────
exports.adminGetLatestOrders = onCall(async (request) => {
  requireAdmin(request);
  const { limitCount = 100 } = request.data || {};

  try {
    const snap = await db.collection('user_licenses')
      .where('isPremium', '==', true)
      .get();

    let orders = [];
    snap.docs.forEach(doc => {
      const data = doc.data();
      if (data.purchaseDate) {
        orders.push({ ...data, uid: doc.id });
      }
    });

    // Sort by purchaseDate descending (newest first)
    orders.sort((a, b) => new Date(b.purchaseDate).getTime() - new Date(a.purchaseDate).getTime());
    orders = orders.slice(0, Math.min(limitCount, 500));

    // Fetch user details for these UIDs in chunks of 30
    const userMap = {};
    if (orders.length > 0) {
      const chunks = [];
      for (let i = 0; i < orders.length; i += 30) {
        chunks.push(orders.map(o => o.uid).slice(i, i + 30));
      }
      for (const chunk of chunks) {
        const usersSnap = await db.collection('users')
          .where(admin.firestore.FieldPath.documentId(), 'in', chunk)
          .get();
        usersSnap.docs.forEach(u => {
          userMap[u.id] = u.data();
        });
      }
    }

    // Merge user data
    const finalOrders = orders.map(o => {
      const uData = userMap[o.uid] || {};
      return {
        uid: o.uid,
        email: o.email || uData.email || null,
        displayName: uData.displayName || null,
        source: o.source || 'Bilinmiyor',
        purchaseDate: o.purchaseDate,
        productId: o.productId || null,
        playOrderId: o.playOrderId || null,
        adminNote: o.adminNote || null,
      };
    });

    return { orders: finalOrders };
  } catch (error) {
    console.error('adminGetLatestOrders error:', error);
    throw new HttpsError('internal', 'Siparişler alınamadı.');
  }
});

// ─── Admin: Kullanıcı Detayı ──────────────────────────────────────────────────
exports.adminGetUserDetail = onCall(async (request) => {
  requireAdmin(request);
  const { targetUid } = request.data || {};
  if (!targetUid) throw new HttpsError('invalid-argument', 'targetUid gerekli.');

  try {
    const [userDoc, licenseDoc] = await Promise.all([
      db.collection('users').doc(targetUid).get(),
      db.collection('user_licenses').doc(targetUid).get()
    ]);

    let userData = userDoc.exists ? userDoc.data() : {};
    let licenseData = licenseDoc.exists ? licenseDoc.data() : {};

    return {
      uid: targetUid,
      ...userData,
      ...licenseData
    };
  } catch (error) {
    console.error('adminGetUserDetail error:', error);
    throw new HttpsError('internal', 'Kullanıcı verisi alınamadı.');
  }
});

// ─── Admin: Premium Manuel Ver ────────────────────────────────────────────────
exports.adminGrantPremium = onCall(async (request) => {
  requireAdmin(request);
  const { targetUid, durationDays = 0, note = '' } = request.data || {};
  if (!targetUid) throw new HttpsError('invalid-argument', 'targetUid gerekli.');

  const now = new Date();
  const payload = {
    uid: targetUid,
    isPremium: true,
    isBanned: false,
    source: 'admin_grant',
    purchaseDate: now.toISOString(),
    updatedAt: now.toISOString(),
    adminNote: note || '',
  };

  if (durationDays > 0) {
    const expiry = new Date(now.getTime() + durationDays * 86400000);
    payload.expiresAt = expiry.toISOString();
  }

  await licenseRef(targetUid).set(payload, { merge: true });
  await db.collection('admin_action_logs').add({
    action: 'grant_premium',
    targetUid,
    durationDays,
    note,
    performedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

// ─── Admin: Premium İptal Et ──────────────────────────────────────────────────
exports.adminRevokePremium = onCall(async (request) => {
  requireAdmin(request);
  const { targetUid, note = '' } = request.data || {};
  if (!targetUid) throw new HttpsError('invalid-argument', 'targetUid gerekli.');

  await licenseRef(targetUid).set({
    isPremium: false,
    updatedAt: new Date().toISOString(),
    revokedAt: new Date().toISOString(),
    adminNote: note || '',
  }, { merge: true });

  await db.collection('admin_action_logs').add({
    action: 'revoke_premium',
    targetUid,
    note,
    performedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

// ─── Admin: Belirli Kullanıcıya FCM Gönder ────────────────────────────────────
exports.adminSendUserNotification = onCall(async (request) => {
  requireAdmin(request);
  const { targetUid, title, body } = request.data || {};
  if (!targetUid || !title || !body)
    throw new HttpsError('invalid-argument', 'targetUid, title ve body gerekli.');

  const userDoc = await db.collection('users').doc(targetUid).get();
  const fcmToken = userDoc.exists ? (userDoc.data().fcmToken || null) : null;

  // 1. Send FCM if possible
  let fcmSent = false;
  if (fcmToken) {
    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
        android: { priority: 'high', notification: { sound: 'default' } },
      });
      fcmSent = true;
    } catch (e) {
      console.error('FCM Error:', e);
    }
  }

  // 2. Insert into support_threads for In-App Popup
  const now = admin.firestore.FieldValue.serverTimestamp();
  const uid = request.auth.uid; // Admin UID
  const messageText = `[Bildirim] ${title}\n${body}`;

  const msgRef = db.collection('support_threads').doc(targetUid).collection('messages').doc();
  const threadRef = db.collection('support_threads').doc(targetUid);

  const batch = db.batch();
  batch.set(msgRef, {
    senderId: uid,
    senderName: 'Yönetici',
    senderRole: 'admin',
    messageText: messageText,
    timestamp: now,
  });

  batch.set(threadRef, {
    userId: targetUid,
    lastMessage: messageText,
    lastTimestamp: now,
    lastSenderId: uid,
    unreadCountUser: admin.firestore.FieldValue.increment(1),
  }, { merge: true });

  // 3. Insert into notification_history
  const historyRef = db.collection('notification_history').doc();
  batch.set(historyRef, {
    type: 'user',
    targetUid,
    title,
    body,
    createdAt: now,
  });

  await batch.commit();

  return { success: true, fcmSent };
});

// ─── Admin: Segmentli Bildirim ─────────────────────────────────────────────────
exports.adminSendSegmentedNotification = onCall(async (request) => {
  requireAdmin(request);
  const { segment = 'all', title, body, translations } = request.data || {};
  if (!title || !body) throw new HttpsError('invalid-argument', 'title ve body gerekli.');

  const topicMap = {
    all: 'all',
    premium: 'premium_users',
    trial: 'trial_users',
    tv: 'tv_users',
    mobile: 'mobile_users',
  };

  const baseTopic = topicMap[segment] || 'all';

  if (translations && typeof translations === 'object') {
    const promises = [];
    for (const [lang, trans] of Object.entries(translations)) {
      if (trans.title && trans.body) {
        promises.push(
          admin.messaging().send({
            topic: `${baseTopic}_${lang}`,
            notification: { title: trans.title, body: trans.body },
            android: { priority: 'high', notification: { sound: 'default' } },
          }).catch(e => console.error(`[MinaPush] Failed to send to ${baseTopic}_${lang}:`, e))
        );
      }
    }
    // Ana kanala (eski sürümler için fallback) gönder:
    promises.push(
      admin.messaging().send({
        topic: baseTopic,
        notification: { title, body },
        android: { priority: 'high', notification: { sound: 'default' } },
      }).catch(e => console.error(`[MinaPush] Failed to send to ${baseTopic}:`, e))
    );
    await Promise.all(promises);
  } else {
    await admin.messaging().send({
      topic: baseTopic,
      notification: { title, body },
      android: { priority: 'high', notification: { sound: 'default' } },
    });
  }

  await db.collection('notification_history').add({
    type: 'segmented',
    segment,
    topic: baseTopic,
    title,
    body,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'sent',
  });

  return { success: true, topic: baseTopic };
});

// ─── Admin: Zamanlanmış Bildirim Planla ───────────────────────────────────────
exports.adminScheduleNotification = onCall(async (request) => {
  requireAdmin(request);
  const { title, body, segment = 'all', scheduledAtMs, translations } = request.data || {};
  if (!title || !body || !scheduledAtMs)
    throw new HttpsError('invalid-argument', 'title, body ve scheduledAtMs gerekli.');
  if (scheduledAtMs <= Date.now())
    throw new HttpsError('invalid-argument', 'Zamanlama gelecekte olmalı.');

  const docRef = await db.collection('scheduled_notifications').add({
    title,
    body,
    segment,
    translations: translations || null,
    scheduledAtMs,
    scheduledAt: new Date(scheduledAtMs).toISOString(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'pending',
  });

  return { success: true, id: docRef.id };
});

// ─── Admin: Banner Yönetimi ────────────────────────────────────────────────────
exports.adminManageBanner = onCall(async (request) => {
  requireAdmin(request);
  const { action, bannerId, title, subtitle, imageUrl, targetUrl,
          backgroundColor, textColor, priority = 0, expiresAtMs = 0 } = request.data || {};

  if (action === 'create') {
    if (!title) throw new HttpsError('invalid-argument', 'title gerekli.');
    const docRef = await db.collection('app_banners').add({
      title,
      subtitle: subtitle || '',
      imageUrl: imageUrl || '',
      targetUrl: targetUrl || '',
      backgroundColor: backgroundColor || '#1E3A5F',
      textColor: textColor || '#FFFFFF',
      priority,
      isActive: true,
      expiresAt: expiresAtMs > 0 ? new Date(expiresAtMs).toISOString() : null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { success: true, id: docRef.id };

  } else if (action === 'toggle') {
    if (!bannerId) throw new HttpsError('invalid-argument', 'bannerId gerekli.');
    const bannerRef = db.collection('app_banners').doc(bannerId);
    const snap = await bannerRef.get();
    if (!snap.exists) throw new HttpsError('not-found', 'Banner bulunamadı.');
    const newState = !snap.data().isActive;
    await bannerRef.update({ isActive: newState });
    return { success: true, isActive: newState };

  } else if (action === 'delete') {
    if (!bannerId) throw new HttpsError('invalid-argument', 'bannerId gerekli.');
    await db.collection('app_banners').doc(bannerId).delete();
    return { success: true };

  } else {
    throw new HttpsError('invalid-argument', 'Geçersiz aksiyon.');
  }
});

// ─── Admin: Analitik Özeti ─────────────────────────────────────────────────────
exports.adminGetAnalytics = onCall(async (request) => {
  requireAdmin(request);

  try {
    const [usersSnap, licSnap, bannerSnap, notifSnap] = await Promise.all([
      db.collection('users').count().get(),
      db.collection('user_licenses').where('isPremium', '==', true).count().get(),
      db.collection('app_banners').where('isActive', '==', true).count().get(),
      db.collection('notification_history').orderBy('sentAt', 'desc').limit(5).get(),
    ]);

    const sevenDaysAgo = new Date(Date.now() - 7 * 86400000).toISOString();
    const newPremiumSnap = await db.collection('user_licenses')
      .where('isPremium', '==', true)
      .where('purchaseDate', '>=', sevenDaysAgo)
      .count()
      .get();

    const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 30 * 86400000)
    );
    const newUsersSnap = await db.collection('users')
      .where('createdAt', '>=', thirtyDaysAgo)
      .count()
      .get();

    const recentNotifs = notifSnap.docs.map(d => {
      const data = d.data();
      return {
        id: d.id,
        title: data.title,
        type: data.type,
        segment: data.segment || null,
        sentAt: data.sentAt ? data.sentAt.toMillis() : null,
      };
    });

    return {
      totalUsers: usersSnap.data().count,
      totalPremium: licSnap.data().count,
      activeBanners: bannerSnap.data().count,
      newPremiumLast7Days: newPremiumSnap.data().count,
      newUsersLast30Days: newUsersSnap.data().count,
      recentNotifications: recentNotifs,
    };
  } catch (error) {
    console.error('adminGetAnalytics ERROR:', error);
    throw new HttpsError('internal', `Detaylı Hata: ${error.message}`);
  }
});

// ─── Admin: Toplu Lisans Kodu Üretimi ──────────────────────────────────────────
exports.adminGenerateLicenseCodes = onCall(async (request) => {
  requireAdmin(request);
  const { count = 100 } = request.data || {};
  
  if (count < 1 || count > 5000) {
    throw new HttpsError('invalid-argument', 'Count must be between 1 and 5000.');
  }

  const batchList = [];
  let currentBatch = db.batch();
  let operationCount = 0;

  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  const codes = [];

  for (let i = 0; i < count; i++) {
    let code = '';
    for (let j = 0; j < 12; j++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    
    const formattedCode = `${code.slice(0,4)}-${code.slice(4,8)}-${code.slice(8,12)}`;
    
    const docRef = db.collection('license_codes').doc(formattedCode);
    currentBatch.set(docRef, {
      code: formattedCode,
      is_used: false,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      created_by: request.auth.uid,
    });
    codes.push(formattedCode);
    operationCount++;

    if (operationCount === 490) {
      batchList.push(currentBatch);
      currentBatch = db.batch();
      operationCount = 0;
    }
  }

  if (operationCount > 0) {
    batchList.push(currentBatch);
  }

  for (const batch of batchList) {
    await batch.commit();
  }

  return { success: true, count };
});
