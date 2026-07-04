# Firebase Permission-Denied Debug (MIXVY Soft Launch)

## Issue Summary
Users getting `[cloud_firestore/permission-denied]` when trying to join rooms, even though:
- ✅ User is authenticated
- ✅ App successfully initializes
- ✅ Router reaches the room screen

## Root Cause Analysis

### 1. Participant Creation Payload ✅ VERIFIED
**Current payload being sent** (from `_joinRoom` in `live_room_screen.dart`):
```dart
await roomRef.collection('participants').doc(uid).set({
  'userId': uid,
  'role': 'audience',
  'micOn': true,
  'cameraOn': true,
  'camOn': true,
  'isMuted': false,
  'isBanned': false,
  'userStatus': 'joined',
  'displayName': username,
  'joinedAt': FieldValue.serverTimestamp(),
  'lastActiveAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
```

✅ **ALL required fields are present** — rules check passes

### 2. Firestore Rules Bottleneck ⚠️ LIKELY CULPRIT
The participant create rule requires (line ~510 in `firestore.rules`):
```firestore
allow create: if signedIn()
  && participantId == uid()
  && exists(/databases/$(database)/documents/rooms/$(roomId))
  && canReadRoomById(roomId)    ← **THIS IS THE BLOCKER**
  && request.resource.data.userId == uid()
  && request.resource.data.role in ['audience', 'host', 'cohost', 'stage']
  && request.resource.data.isMuted is bool
  && request.resource.data.isBanned is bool
  && request.resource.data.camOn is bool
  && request.resource.data.userStatus is string
  && request.resource.data.joinedAt is timestamp
  && request.resource.data.lastActiveAt is timestamp;
```

### 3. The canReadRoomById Chain
```firestore
function canReadRoomById(roomId) {
  return exists(/databases/$(database)/documents/rooms/$(roomId))
    && roomReadableByRequester(roomData);
}

function roomReadableByRequester(roomData) {
  return (
    signedIn() && (
      !('isAdult' in roomData && roomData.isAdult == true)
      || isAdultVerified(uid())  ← **FAILS IF: room is adult BUT user NOT verified**
    )
  );
}

function isAdultVerified(userId) {
  return signedIn()
    && exists(/databases/$(database)/documents/verification/$(userId))
    && verificationDoc(userId).data.isAdultVerified == true
    && verificationDoc(userId).data.verificationStatus == 'verified';
}
```

## Most Likely Failure Points (Priority Order)

### 🔴 **#1: Room marked as `isAdult: true` but user NOT verified** (70% probability)
- Room creation defaults to `isAdult: false` ✅
- BUT: If any room WAS created with `isAdult: true`, joining fails
- **Test:** Check Firebase → Firestore → rooms → YOUR_ROOM_ID → scroll to `isAdult` field

### 🟡 **#2: Missing verification document** (20% probability)
- User authenticated but NO `verification/{uid}` document exists
- **Test:** Check Firebase → Firestore → verification → YOUR_UID
- If empty → verification flow was skipped

### 🟢 **#3: Room doesn't exist or malformed roomId** (10% probability)
- Navigation passed wrong roomId or room was deleted
- **Test:** Check Firestore → rooms → search for the roomId in URL

## Quick Manual Tests

### Test 1: Check Room Document
1. Go to **Firebase Console** → **Firestore**
2. Navigate to: `rooms` → [YOUR_ROOM_ID]
3. **Look for:**
   - `isAdult` field → should be `false`
   - `ownerId` field → should match your userId
   - Room exists? ✅

### Test 2: Check Your Verification Status
1. Go to **Firestore** → `verification` → [YOUR_UID]
2. **Should show:**
   ```
   isAdultVerified: false (or true if you did age gate)
   verificationStatus: "verified" (or "pending")
   ```
3. If document DOESN'T exist → create a dummy one:
   ```firestore
   verification/{uid}:
   {
     "isAdultVerified": false,
     "verificationStatus": "verified",
     "createdAt": now()
   }
   ```

### Test 3: Temporary Rules Override (DEV ONLY)
Replace the `isAdultVerified` function in `firestore.rules`:

```firestore
// TEMPORARY DEV BYPASS
function isAdultVerified(userId) {
  return true;  // ← Bypass verification
}
```

Then:
1. Deploy updated rules to Firebase
2. Try joining room again
3. **If error disappears** → It's the adult verification block
4. **If error persists** → Different issue (payload validation, etc.)

## Recommended Fix

### Option A: Quick Fix (Testing)
Update `firestore.rules` line ~51:
```firestore
// Bypass adult verification for SOFT LAUNCH testing
function isAdultVerified(userId) {
  return true;
}
```

### Option B: Proper Fix (Production)
Ensure:
1. Create automatic `verification/{uid}` on user signup (Cloud Function)
2. Set `isAdultVerified: false` and `verificationStatus: "verified"` by default
3. Only set `isAdultVerified: true` after server-side age verification

## Files to Check
- **Participant creation:** `lib/features/room/presentation/live_room_screen.dart` line 63-90
- **Firestore rules:** `firestore.rules` lines 51-80 (isAdultVerified function)
- **Room creation:** `lib/services/room_service.dart` line 930 (isAdult defaults to false ✅)

---

## Next Steps
1. Check your room document in Firebase Console for `isAdult` field
2. Check your verification document exists
3. Apply temporary bypass and test
4. Report findings with exact isAdult value and verification status
