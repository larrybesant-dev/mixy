# Writer Audit Map — Code Refactor Guide
**Date:** 2026-04-12  
**Purpose:** Map every user document write in the app to the correct domain after migration

---

## Summary

| Writer | Old Path | New Path | Status |
|--------|----------|----------|--------|
| **auth_controller** | users/<uid> (id, username, email, etc.) | users/<uid> (identity only) | ✅ ALREADY FIXED |
| **friend_service** | users/<uid> (favoriteFriendIds) | users/<uid> (favoriteFriendIds) | ✅ NO CHANGE |
| **after_dark_provider** | users/<uid> (adultModeEnabled, etc.) | users/<uid> (adultModeEnabled, adultConsentAccepted, etc.) | ✅ NO CHANGE |
| **verification_provider** | users/<uid> (isVerified, verifiedAt, verifiedBy) | users/<uid>/verification (status, verifiedAt, verifiedBy) | ⚠️ MUST REFACTOR |
| **profile_background** | users/<uid> (backgroundColor) | users/<uid>/preferences (backgroundColor) | ⚠️ MUST REFACTOR |
| **profile_music** | users/<uid> (musicUrl) | users/<uid>/preferences (profileMusicUrl) | ⚠️ MUST REFACTOR |
| **daily_checkin_service** | users/<uid> (lastCheckinDate, checkinStreak, balance, coinBalance) | users/<uid>/wallet (lastCheckinDate, checkinStreak, balance, coinBalance) | ⚠️ MUST REFACTOR |
| **profile_service** | users/<uid> (userData spread) | users/<uid>/profile_public (userData) | ⚠️ MUST REFACTOR |

---

## Writer Details & Refactor Instructions

### 1. **auth_controller.dart** — ALREADY FIXED ✅

**Current State After Earlier Patch:**
```dart
// Ensure user document (create or update)
// On create: id, username, usernameLower, email, avatarUrl, updatedAt, createdAt ✅
// On update: username, usernameLower, email, avatarUrl, updatedAt ✅
```

**Status:** ✅ No changes needed. Already follows identity domain only.

---

### 2. **friend_service.dart** (setFavorite) — NO CHANGE ✅

**Current Path:**
```dart
await _usersCollection.doc(userId).set({
  'favoriteFriendIds': isFavorite ? [...] : [...],
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
```

**Status:** ✅ `favoriteFriendIds` stays in core identity. No refactor needed.

---

### 3. **after_dark_provider.dart** (enable/disable) — NO CHANGE ✅

**Current Paths:**
```dart
// Line 40: enable()
collection('users').doc(uid).set({
  'adultModeEnabled': true,
  'adultConsentAccepted': true,
  'adultModeEnabledAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));

// Line 75: disable()
collection('users').doc(uid).set({
  'adultModeEnabled': false,
}, SetOptions(merge: true));
```

**Status:** ✅ `adultModeEnabled` + `adultConsentAccepted` stay in core identity. No refactor needed.

---

### 4. **verification_provider.dart** — MUST REFACTOR ⚠️

**Current Path:**
```dart
// Line 62: verifyUser()
await _firestore.collection('users').doc(userId).update({
  'isVerified': true,
  'verifiedAt': FieldValue.serverTimestamp(),
  'verifiedBy': verifiedBy,
});

// Line 70: unverifyUser()
await _firestore.collection('users').doc(userId).update({
  'isVerified': false,
  'verifiedAt': FieldValue.delete(),
  'verifiedBy': FieldValue.delete(),
});
```

**Refactor To:**
```dart
// verifyUser()
await _firestore.collection('users').doc(userId).collection('verification').doc('data').update({
  'status': 'verified', // NOT isVerified, but status enum
  'verifiedAt': FieldValue.serverTimestamp(),
  'verifiedBy': verifiedBy,
  'updatedAt': FieldValue.serverTimestamp(),
});

// unverifyUser()
await _firestore.collection('users').doc(userId).collection('verification').doc('data').update({
  'status': 'unverified',
  'verifiedAt': FieldValue.delete(),
  'verifiedBy': FieldValue.delete(),
  'updatedAt': FieldValue.serverTimestamp(),
});
```

**Files to Change:**
- `lib/features/verification/providers/verification_provider.dart`

**Checklist:**
- [ ] Change `isVerified` → `status`
- [ ] Ensure status is one of: `unverified`, `pending`, `verified`, `rejected`
- [ ] Always write to `users/<uid>/verification/data` (not core identity)
- [ ] Add `updatedAt` to all writes
- [ ] Test that verify/unverify operations work on new path

---

### 5. **profile_background.dart** — MUST REFACTOR ⚠️

**Current Path:**
```dart
// Line 9: setBackgroundColor()
await firestore.collection('users').doc(userId).update({
  'backgroundColor': colorHex,
});
```

**Refactor To:**
```dart
// setBackgroundColor()
await firestore.collection('users').doc(userId).collection('preferences').doc('data').update({
  'backgroundColor': colorHex,
  'updatedAt': FieldValue.serverTimestamp(),
});
```

**Also Update Read Path:**
```dart
// Line 15: getBackgroundColor()
// OLD:
// final doc = await firestore.collection('users').doc(userId).get();
// return doc.data()?['backgroundColor'];

// NEW:
final doc = await firestore.collection('users').doc(userId)
    .collection('preferences').doc('data').get();
return doc.data()?['backgroundColor'];
```

**Files to Change:**
- `lib/features/profile/profile_background.dart`

**Checklist:**
- [ ] Update write path to `users/<uid>/preferences/data`
- [ ] Update read path to `users/<uid>/preferences/data`
- [ ] Add `updatedAt` to write

---

### 6. **profile_music.dart** — MUST REFACTOR ⚠️

**Current Path:**
```dart
// Line 8: uploadMusic()
await firestore.collection('users').doc(userId).update({
  'musicUrl': url,
});

// Line 14: getMusicUrl()
final doc = await firestore.collection('users').doc(userId).get();
return doc.data()?['musicUrl'];
```

**Refactor To:**
```dart
// uploadMusic()
await firestore.collection('users').doc(userId).collection('preferences').doc('data').update({
  'profileMusicUrl': url, // NOTE: RENAME field
  'updatedAt': FieldValue.serverTimestamp(),
});

// getMusicUrl()
final doc = await firestore.collection('users').doc(userId)
    .collection('preferences').doc('data').get();
return doc.data()?['profileMusicUrl']; // NOTE: RENAMED field
```

**Files to Change:**
- `lib/features/profile/profile_music.dart`

**Checklist:**
- [ ] Update write path to `users/<uid>/preferences/data`
- [ ] Update read path to `users/<uid>/preferences/data`
- [ ] Rename field from `musicUrl` → `profileMusicUrl` (matches schema)
- [ ] Add `updatedAt` to write
- [ ] Update all UI code that references `musicUrl` to use `profileMusicUrl`

---

### 7. **daily_checkin_service.dart** — MUST REFACTOR ⚠️

**Current Path:**
```dart
// Line 80: claim()
await _db.collection('users').doc(uid).update({
  'lastCheckinDate': FieldValue.serverTimestamp(),
  'checkinStreak': status.streak,
  'balance': FieldValue.increment(status.reward),
  'coinBalance': FieldValue.increment(status.reward),
});
```

**Refactor To:**
```dart
// claim()
await _db.collection('users').doc(uid).collection('wallet').doc('data').update({
  'lastCheckinDate': FieldValue.serverTimestamp(),
  'checkinStreak': status.streak,
  'balance': FieldValue.increment(status.reward),
  'coinBalance': FieldValue.increment(status.reward),
  'updatedAt': FieldValue.serverTimestamp(),
});
```

**Also Update Read Path:**
```dart
// Line 30: getStatus()
// OLD:
// final doc = await _db.collection('users').doc(uid).get();

// NEW:
final walletDoc = await _db.collection('users').doc(uid)
    .collection('wallet').doc('data').get();
if (!walletDoc.exists) {
  return const DailyCheckinStatus(claimed: false, streak: 0, reward: 10);
}
final data = walletDoc.data() ?? const <String, dynamic>{};
```

**Files to Change:**
- `lib/services/daily_checkin_service.dart`

**Checklist:**
- [ ] Update write path to `users/<uid>/wallet/data`
- [ ] Update read path to `users/<uid>/wallet/data`
- [ ] All four fields (lastCheckinDate, checkinStreak, balance, coinBalance) move to wallet
- [ ] Add `updatedAt` to write
- [ ] Validate coin increment logic still works (using FieldValue.increment)

---

### 8. **profile_service.dart** — MUST REFACTOR ⚠️

**Current Path:**
```dart
// Line 54-62: saveProfile()
batch.set(
  userRef,
  {
    ...userData,
    'updatedAt': FieldValue.serverTimestamp(),
  },
  SetOptions(merge: true),
);
```

**Problem:** `userData` is unconstrained spread. Could contain wallet fields, security fields, etc.

**Refactor To:**
```dart
// Separate writes by domain

// 1. Save core identity fields only
batch.set(
  userRef,
  {
    'username': userData['username'],
    'usernameLower': userData['usernameLower'],
    'email': userData['email'],
    'bio': userData['bio'],
    'isPrivate': userData['isPrivate'],
    'updatedAt': FieldValue.serverTimestamp(),
  },
  SetOptions(merge: true),
);

// 2. Save profile_public separately
batch.set(
  userRef.collection('profile_public').doc('data'),
  {
    'age': userData['age'],
    'gender': userData['gender'],
    'location': userData['location'],
    'relationshipStatus': userData['relationshipStatus'],
    'vibePrompt': userData['vibePrompt'],
    'firstDatePrompt': userData['firstDatePrompt'],
    'musicTastePrompt': userData['musicTastePrompt'],
    'interests': userData['interests'],
    'profileAccentColor': userData['profileAccentColor'],
    'galleryUrls': userData['galleryUrls'],
    'introVideoUrl': userData['introVideoUrl'],
    'updatedAt': FieldValue.serverTimestamp(),
  },
  SetOptions(merge: true),
);

// 3. Privacy and adult_profile saved separately (already isolated)
```

**Files to Change:**
- `lib/services/profile_service.dart`

**Checklist:**
- [ ] Split `userData` spread into identity + profile_public batches
- [ ] Explicitly list allowed fields per domain (no spreads)
- [ ] Add `updatedAt` to all batch writes
- [ ] Update read path: `loadProfile()` should still work (reads all subcollections)
- [ ] Test batch commits successfully (atomicity preserved)

---

## Implementation Order (Recommended)

Do in this sequence to minimize risk:

1. ✅ **auth_controller.dart** — Already fixed, no action
2. ✅ **friend_service.dart** — No change needed, confirms no other writes
3. ✅ **after_dark_provider.dart** — No change needed, confirms adult mode stays in identity
4. **1. verification_provider.dart** — Refactor to users/<uid>/verification
5. **2. profile_background.dart** — Refactor to users/<uid>/preferences
6. **3. profile_music.dart** — Refactor to users/<uid>/preferences
7. **4. daily_checkin_service.dart** — Refactor to users/<uid>/wallet
8. **5. profile_service.dart** — Split into multi-domain batch

---

## Validation After Each Refactor

After each file change:

```bash
# 1. Compile Dart (catch syntax errors)
flutter pub get
flutter analyze

# 2. Run unit tests for that service
flutter test test/path_to_service_test.dart

# 3. Smoke test on staging
# - Sign in
# - Trigger the modified flow
# - Check logs for permission-denied errors
```

---

## Parallel Testing Strategy

While migrating, you can:

1. Deploy new rules to staging (backward compatible)
2. Backfill staging data to new schema
3. Update code paths one feature at a time
4. Test each feature on staging before production deploy

This minimizes risk and allows rollback if needed.

---

## Regression Risk Map

| Risk | Mitigation |
|------|-----------|
| Orphaned old fields left in core identity | Cleanup script runs post-migration |
| Coin totals corrupted in wallet | Validation checksum at each step |
| Users can't read their own wallet/verification | Test read permissions in each rule |
| Backfill incomplete → data loss | Rollback script ready + staging validation |
| Code writes to old path after migration | Linting rule to catch `users/<uid>.update` only for identity fields |

---

## Sign-Off Checklist

Before considering migration complete:

- [ ] All 5 writers refactored + tested
- [ ] Firestore rules deployed to production
- [ ] Backfill scripts executed + validated
- [ ] Chaos tests pass on new schema
- [ ] No permission-denied errors for valid writes
- [ ] Data integrity verified (coins, verification status, etc.)
- [ ] Old fields removed from core identity
- [ ] Team trained on new schema architecture
