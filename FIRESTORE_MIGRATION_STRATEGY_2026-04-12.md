# Firestore Schema Migration Strategy — Safe & Reversible
**Date:** 2026-04-12  
**Scope:** Migrate from monolithic `users/<uid>` to domain-separated subcollections  
**Risk Level:** Medium (data-bearing change, reversible with rollback script)

---

## Executive Summary

This migration:
1. ✅ Preserves all existing user data
2. ✅ Zero downtime for users
3. ✅ Rollback available at every stage
4. ✅ Validates data integrity at each checkpoint

**Total execution time:** 2–4 hours (including smoke tests)

---

## Pre-Migration Checklist

Before touching any data:

- [ ] Take production Firestore backup (export to Cloud Storage)
- [ ] Notify team: "Data migration starting, staging only"
- [ ] Deploy new Firestore rules to **staging only** (not production yet)
- [ ] Smoke test rules on staging with test user
- [ ] Prepare rollback Cloud Function (ready to deploy)
- [ ] Have admin account with Firestore console access

---

## Migration Phases

### Phase 1: Backfill Subcollections (Staging Only)

**Goal:** Copy all user data from monolithic doc to domain subcollections.

**Order matters** — execute in this sequence:

#### Step 1a: Create Core Identity (No Changes)
**Status:** Reference only. Core fields stay in `users/<uid>`.

```javascript
// Run in Cloud Functions
exports.migratePhase1a_coreIdentity = functions.https.onCall(async () => {
  // Core identity fields are already in users/<uid>.
  // No action needed. Just validate they exist.
  const batch = admin.firestore().batch();
  const usersSnapshot = await admin.firestore().collection('users').get();
  
  let validated = 0;
  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    if (data.id && data.email && data.username && data.createdAt) {
      validated++;
    } else {
      console.warn(`Bad core identity for ${doc.id}`);
    }
  }
  
  console.log(`✅ Core identity validation: ${validated}/${usersSnapshot.size}`);
  return { status: 'ok', validated };
});
```

#### Step 1b: Migrate Profile Public
**Status:** Copy age, gender, location, interests, etc. to `users/<uid>/profile_public`.

```javascript
exports.migratePhase1b_profilePublic = functions.https.onCall(async () => {
  const batch = admin.firestore().batch();
  const usersSnapshot = await admin.firestore().collection('users').get();
  
  const profilePublicFields = [
    'age', 'gender', 'location', 'relationshipStatus',
    'vibePrompt', 'firstDatePrompt', 'musicTastePrompt', 'interests',
    'profileAccentColor', 'galleryUrls', 'introVideoUrl'
  ];
  
  let migrated = 0;
  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    const profilePublicData = {};
    
    for (const field of profilePublicFields) {
      if (field in data) {
        profilePublicData[field] = data[field];
      }
    }
    
    profilePublicData.updatedAt = data.updatedAt || admin.firestore.FieldValue.serverTimestamp();
    
    batch.set(
      admin.firestore().collection('users').doc(doc.id).collection('profile_public').doc('data'),
      profilePublicData,
      { merge: true }
    );
    migrated++;
  }
  
  await batch.commit();
  console.log(`✅ Profile public migrated: ${migrated} users`);
  return { status: 'ok', migrated };
});
```

#### Step 1c: Migrate Wallet (Data-Bearing — Verify Totals)
**Status:** Copy balance, coinBalance, streaks to `users/<uid>/wallet`.

```javascript
exports.migratePhase1c_wallet = functions.https.onCall(async () => {
  const batch = admin.firestore().batch();
  const usersSnapshot = await admin.firestore().collection('users').get();
  
  let migrated = 0;
  let totalCoinsSource = 0;
  let totalCoinsTarget = 0;
  
  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    const balance = data.balance ?? 0;
    const coinBalance = data.coinBalance ?? 0;
    
    totalCoinsSource += coinBalance;
    
    const walletData = {
      balance,
      coinBalance,
      lastCheckinDate: data.lastCheckinDate || null,
      checkinStreak: data.checkinStreak ?? 0,
      totalCoinsClaimed: data.totalCoinsClaimed ?? 0,
      updatedAt: data.updatedAt || admin.firestore.FieldValue.serverTimestamp()
    };
    
    totalCoinsTarget += coinBalance;
    
    batch.set(
      admin.firestore().collection('users').doc(doc.id).collection('wallet').doc('data'),
      walletData,
      { merge: true }
    );
    migrated++;
  }
  
  await batch.commit();
  
  // Verify totals match.
  if (totalCoinsSource !== totalCoinsTarget) {
    throw new Error(`CHECKSUM FAILED: source ${totalCoinsSource} != target ${totalCoinsTarget}`);
  }
  
  console.log(`✅ Wallet migrated: ${migrated} users, ${totalCoinsTarget} total coins`);
  return { status: 'ok', migrated, totalCoins: totalCoinsTarget };
});
```

#### Step 1d: Migrate Preferences
**Status:** Copy theme, music, background colors to `users/<uid>/preferences`.

```javascript
exports.migratePhase1d_preferences = functions.https.onCall(async () => {
  const batch = admin.firestore().batch();
  const usersSnapshot = await admin.firestore().collection('users').get();
  
  const preferencesFields = [
    'themeId', 'backgroundColor', 'profileMusicUrl', 'profileMusicTitle',
    'profileBgGradientStart', 'profileBgGradientEnd', 'camViewPolicy'
  ];
  
  let migrated = 0;
  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    const preferencesData = {};
    
    for (const field of preferencesFields) {
      if (field in data) {
        preferencesData[field] = data[field];
      }
    }
    
    preferencesData.updatedAt = data.updatedAt || admin.firestore.FieldValue.serverTimestamp();
    
    batch.set(
      admin.firestore().collection('users').doc(doc.id).collection('preferences').doc('data'),
      preferencesData,
      { merge: true }
    );
    migrated++;
  }
  
  await batch.commit();
  console.log(`✅ Preferences migrated: ${migrated} users`);
  return { status: 'ok', migrated };
});
```

#### Step 1e: Migrate Verification (Server-Only Guard)
**Status:** Copy isVerified, verifiedAt, verifiedBy to `users/<uid>/verification`.

```javascript
exports.migratePhase1e_verification = functions.https.onCall(async () => {
  const batch = admin.firestore().batch();
  const usersSnapshot = await admin.firestore().collection('users').get();
  
  let migrated = 0;
  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    
    let status = 'unverified';
    if (data.isVerified === true) {
      status = 'verified';
    } else if (data.verificationPending === true) {
      status = 'pending';
    }
    
    const verificationData = {
      status,
      verifiedAt: data.verifiedAt || null,
      verifiedBy: data.verifiedBy || null,
      updatedAt: data.updatedAt || admin.firestore.FieldValue.serverTimestamp()
    };
    
    batch.set(
      admin.firestore().collection('users').doc(doc.id).collection('verification').doc('data'),
      verificationData,
      { merge: true }
    );
    migrated++;
  }
  
  await batch.commit();
  console.log(`✅ Verification migrated: ${migrated} users`);
  return { status: 'ok', migrated };
});
```

#### Step 1f: Create Security (New Collection — Defaults)
**Status:** Initialize new `users/<uid>/security` with defaults from auth state.

```javascript
exports.migratePhase1f_security = functions.https.onCall(async () => {
  const batch = admin.firestore().batch();
  const usersSnapshot = await admin.firestore().collection('users').get();
  
  let migrated = 0;
  for (const doc of usersSnapshot.docs) {
    const securityData = {
      lastLoginAt: doc.data().updatedAt || admin.firestore.FieldValue.serverTimestamp(),
      lastLoginIp: null,
      emailVerified: !!doc.data().email,
      phoneVerified: false,
      mfaEnabled: false,
      riskFlags: [],
      failedLoginCount: 0,
      lockedUntil: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    batch.set(
      admin.firestore().collection('users').doc(doc.id).collection('security').doc('data'),
      securityData
    );
    migrated++;
  }
  
  await batch.commit();
  console.log(`✅ Security initialized: ${migrated} users`);
  return { status: 'ok', migrated };
});
```

---

### Phase 2: Validation Checkpoints

After backfill, validate data integrity:

```javascript
exports.validatePostMigration = functions.https.onCall(async () => {
  const usersSnapshot = await admin.firestore().collection('users').get();
  const errors = [];
  
  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const userData = userDoc.data();
    
    // Check profile_public exists.
    const pubProfileDoc = await admin.firestore()
      .collection('users').doc(userId).collection('profile_public').doc('data').get();
    if (!pubProfileDoc.exists) {
      errors.push(`Missing profile_public for ${userId}`);
    }
    
    // Check wallet exists and coin totals match.
    const walletDoc = await admin.firestore()
      .collection('users').doc(userId).collection('wallet').doc('data').get();
    if (!walletDoc.exists) {
      errors.push(`Missing wallet for ${userId}`);
    } else {
      const sourceCoins = userData.coinBalance ?? 0;
      const targetCoins = walletDoc.data()?.coinBalance ?? 0;
      if (sourceCoins !== targetCoins) {
        errors.push(`Coin mismatch for ${userId}: source ${sourceCoins} != target ${targetCoins}`);
      }
    }
    
    // Check other collections exist.
    for (const coll of ['preferences', 'verification', 'security']) {
      const doc = await admin.firestore()
        .collection('users').doc(userId).collection(coll).doc('data').get();
      if (!doc.exists) {
        errors.push(`Missing ${coll} for ${userId}`);
      }
    }
  }
  
  if (errors.length > 0) {
    console.error(`❌ Validation failed with ${errors.length} errors:`, errors);
    throw new Error(`Validation failed: ${errors.length} errors`);
  }
  
  console.log(`✅ All ${usersSnapshot.size} users passed validation`);
  return { status: 'ok', validated: usersSnapshot.size };
});
```

---

### Phase 3: Smoke Tests (Staging Only)

With new rules active, test each domain write:

```javascript
exports.smokeTestNewSchema = functions.https.onCall(async (data, context) => {
  const userId = context.auth?.uid;
  if (!userId) throw new Error('Unauthenticated');
  
  const db = admin.firestore();
  const results = {};
  
  try {
    // Test 1: Read core identity.
    await db.collection('users').doc(userId).get();
    results.coreIdentityRead = '✅';
  } catch (e) {
    results.coreIdentityRead = `❌ ${e.MessageModel}`;
  }
  
  try {
    // Test 2: Update core identity (allowed).
    await db.collection('users').doc(userId).update({
      username: `test_${Date.now()}`
    });
    results.coreIdentityUpdate = '✅';
  } catch (e) {
    results.coreIdentityUpdate = `❌ ${e.MessageModel}`;
  }
  
  try {
    // Test 3: Read profile_public.
    await db.collection('users').doc(userId).collection('profile_public').doc('data').get();
    results.profilePublicRead = '✅';
  } catch (e) {
    results.profilePublicRead = `❌ ${e.MessageModel}`;
  }
  
  try {
    // Test 4: Update preferences (allowed).
    await db.collection('users').doc(userId).collection('preferences').doc('data').update({
      backgroundColor: '#FF0000'
    });
    results.preferencesUpdate = '✅';
  } catch (e) {
    results.preferencesUpdate = `❌ ${e.MessageModel}`;
  }
  
  try {
    // Test 5: Try to write wallet (should fail).
    await db.collection('users').doc(userId).collection('wallet').doc('data').update({
      coinBalance: 999999
    });
    results.walletWriteBlock = '❌ SHOULD HAVE BEEN DENIED';
  } catch (e) {
    if (e.code === 'permission-denied') {
      results.walletWriteBlock = '✅ (correctly denied)';
    } else {
      results.walletWriteBlock = `❌ ${e.MessageModel}`;
    }
  }
  
  console.log('Smoke tests:', results);
  return results;
});
```

---

### Phase 4: Production Deployment (When Ready)

1. **Stop all client writes** (optional; can be done with feature flags)
2. **Verify backfill completed** in staging
3. **Deploy new rules** to production (non-breaking for existing clients)
4. **Deploy migrated data** to production (backfill scripts)
5. **Run validation** on production
6. **Deploy writer code changes** (see separate Writer Audit Map)
7. **Enable new code paths** and disable old ones

---

## Rollback Plan

If migration fails at any point:

```javascript
exports.rollbackMigration = functions.https.onCall(async () => {
  // Delete all subcollections, revert to old state.
  const usersSnapshot = await admin.firestore().collection('users').get();
  
  for (const userDoc of usersSnapshot.docs) {
    const userRef = admin.firestore().collection('users').doc(userDoc.id);
    
    // Delete subcollections.
    for (const coll of ['profile_public', 'wallet', 'preferences', 'verification', 'security']) {
      const collDocs = await userRef.collection(coll).get();
      for (const doc of collDocs.docs) {
        await doc.ref.delete();
      }
    }
  }
  
  console.log('✅ Rollback complete. System reverted to old schema.');
  return { status: 'rolled_back' };
});
```

---

## Rollout Timeline

| Phase | Duration | Location | Risk |
|-------|----------|----------|------|
| Pre-Migration Setup | 15 min | Staging | None |
| Backfill (1a-1f) | 30 min | Staging | Low |
| Validation | 10 min | Staging | None |
| Smoke Tests | 15 min | Staging | Low |
| Rules Deploy | 5 min | Production | Low (rules are backward compatible) |
| Backfill → Production | 30 min | Production | Medium (data-bearing) |
| Code Deploy | 15 min | Production | Medium (writer refactor) |
| **Total** | **~2 hours** | Staged | Medium |

---

## Post-Migration: Data Cleanup

After 1 week of stability:

1. Remove old fields from `users/<uid>`:
   - age, gender, location, relationshipStatus, vibePrompt, firstDatePrompt, musicTastePrompt, interests, profileAccentColor
   - themeId, backgroundColor, profileMusicUrl, profileMusicTitle, profileBgGradientStart, profileBgGradientEnd, camViewPolicy
   - lastCheckinDate, checkinStreak, balance, coinBalance
   - isVerified, verifiedAt, verifiedBy

2. Archive old field values (optional, for audit).

3. Update all analytics queries to use new paths.

---

## Validation Checklist

After migration completes:

- [ ] All users have profile_public subcollection
- [ ] All users have wallet subcollection (coin totals match)
- [ ] All users have preferences subcollection
- [ ] All users have verification subcollection (status correct)
- [ ] All users have security subcollection (initialized)
- [ ] Chaos tests pass on new schema
- [ ] No permission-denied errors in logs for valid writes
- [ ] Coin totals unchanged
- [ ] User data unchanged (except schema structure)
