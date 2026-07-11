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
const GRANDFATHER_CUTOFF_MS = Date.UTC(2026, 5, 29); // 29 Haziran 2026 00:00 UTC

function requireAuth(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Oturum açmanız gerekiyor.');
  }
  return request.auth.uid;
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
  if (data.isPremium !== true) return null;
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
      source: null,
      purchaseDate: null,
      deviceCount: 0,
      maxDevices: MAX_DEVICES,
    };
  }

  const devices = await listDevices(uid);
  return {
    isPremium: true,
    source: license.source || 'unknown',
    purchaseDate: license.purchaseDate || null,
    deviceCount: devices.length,
    maxDevices: MAX_DEVICES,
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
  if (productId !== PREMIUM_PRODUCT_ID) {
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
      maxDevices: MAX_DEVICES,
      devices,
      reused: true,
    };
  }

  const total = await countDevices(uid);
  if (total >= MAX_DEVICES) {
    throw new HttpsError(
      'resource-exhausted',
      'DEVICE_LIMIT_EXCEEDED',
      { maxDevices: MAX_DEVICES, deviceCount: total },
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
    maxDevices: MAX_DEVICES,
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
    maxDevices: MAX_DEVICES,
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
    maxDevices: MAX_DEVICES,
  };
});
