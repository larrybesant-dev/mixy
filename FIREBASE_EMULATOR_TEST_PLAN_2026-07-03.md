# Firebase Emulator Testing Plan - Room Join Permission Fixes
**Date:** 2026-07-03  
**Objective:** Validate App Check and Firestore room join permissions before production deployment  
**Estimated Time:** 30 minutes

---

## Prerequisites

✅ **Already Configured in Your Project:**
- Firebase Emulator Suite in `firebase.json` (auth port 9099, firestore port 8085)
- Emulator bootstrap class: `lib/dev/firebase_emulator_bootstrap.dart`
- Firestore rules: `firestore.rules` (updated with new App Check logic)

✅ **System Requirements:**
- Java 21+ (for Firestore emulator)
- Node.js 18+ (for Firebase CLI)
- Firebase CLI: `npm install -g firebase-tools`

---

## Phase 1: Start Emulator Suite (5 min)

### Step 1.1: Verify Java Installation
```powershell
java -version
# Should output Java 21+
```

### Step 1.2: Start Firebase Emulators
```bash
firebase emulators:start --project=mixvy-rules-test --only=firestore,auth
```

**Expected Output:**
```
✅ Firestore emulator started (listening on 127.0.0.1:8085)
✅ Auth emulator started (listening on 127.0.0.1:9099)
ℹ Emulator UI started (listening on 127.0.0.1:4000)
```

**Emulator Dashboard:** Open browser to `http://localhost:4000`

---

## Phase 2: Load Test Data (5 min)

### Step 2.1: Create Test User
Use Emulator UI or run:
```javascript
// In browser console (http://localhost:4000)
firebase.auth().createUserWithEmailAndPassword("testuser@mixvy.local", "TestPass123!")
  .then(user => console.log("✅ User created:", user.uid));
```

**Expected Output:**
```
✅ User created: test-uid-12345
```

### Step 2.2: Create Test Room
```javascript
// In browser console
const testRoom = {
  hostId: firebase.auth().currentUser.uid,
  ownerId: firebase.auth().currentUser.uid,
  name: "Test Room",
  isAdult: false,
  isLive: true,
  memberCount: 1,
  audienceUserIds: [firebase.auth().currentUser.uid],
  stageUserIds: [],
  adminUserIds: [],
  category: "general",
  allowGuestAccess: true
};

firebase.firestore()
  .collection("rooms")
  .add(testRoom)
  .then(ref => {
    window.testRoomId = ref.id;
    console.log("✅ Room created:", ref.id);
  });
```

**Expected Output:**
```
✅ Room created: test-room-abc123
```

---

## Phase 3: Test Permission Scenarios (15 min)

### Scenario A: ✅ User Joins Non-Adult Room (Should Pass)

```javascript
// Join room as participant
const userId = firebase.auth().currentUser.uid;
const roomId = window.testRoomId;

firebase.firestore()
  .collection("rooms")
  .doc(roomId)
  .collection("participants")
  .doc(userId)
  .set({
    userId: userId,
    role: "audience",
    isMuted: false,
    isBanned: false,
    camOn: false,
    userStatus: "online",
    joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
    lastActiveAt: firebase.firestore.FieldValue.serverTimestamp()
  })
  .then(() => console.log("✅ PASS: Participant created"))
  .catch(err => console.error("❌ FAIL:", err.message));
```

**Expected Result:** ✅ PASS
**Error Message:** None

---

### Scenario B: ❌ Guest Tries to Join (Should Fail - No App Check Token)

```javascript
// Sign out current user
await firebase.auth().signOut();

// Try to access room as guest
firebase.firestore()
  .collection("rooms")
  .doc(window.testRoomId)
  .get()
  .then(doc => console.log("✅ Room readable by guest:", doc.exists))
  .catch(err => {
    if (err.code === "permission-denied") {
      console.log("✅ EXPECTED: Guest cannot read (no auth)");
    } else {
      console.error("❌ Unexpected error:", err.message);
    }
  });
```

**Expected Result:** ✅ `permission-denied` (guests need authentication)

---

### Scenario C: ✅ Different User Joins Same Room (Should Pass)

```javascript
// Create second user
firebase.auth().createUserWithEmailAndPassword("testuser2@mixvy.local", "TestPass123!")
  .then(async user2 => {
    const user2Id = user2.user.uid;
    const roomId = window.testRoomId;
    
    // User 2 joins as audience
    await firebase.firestore()
      .collection("rooms")
      .doc(roomId)
      .collection("participants")
      .doc(user2Id)
      .set({
        userId: user2Id,
        role: "audience",
        isMuted: false,
        isBanned: false,
        camOn: false,
        userStatus: "online",
        joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        lastActiveAt: firebase.firestore.FieldValue.serverTimestamp()
      });
    
    console.log("✅ PASS: User 2 joined room");
  })
  .catch(err => console.error("❌ FAIL:", err.message));
```

**Expected Result:** ✅ PASS

---

### Scenario D: ❌ Adult Room Without Verification (Should Fail)

```javascript
// Sign in as test user 1
await firebase.auth().signInWithEmailAndPassword("testuser@mixvy.local", "TestPass123!");

// Create adult room WITHOUT user being verified
const adultRoom = {
  hostId: firebase.auth().currentUser.uid,
  ownerId: firebase.auth().currentUser.uid,
  name: "Adult Test Room",
  isAdult: true,  // <-- Adult flag
  isLive: true,
  memberCount: 1,
  audienceUserIds: [firebase.auth().currentUser.uid],
  stageUserIds: [],
  adminUserIds: [],
  category: "adult",
  allowGuestAccess: false
};

firebase.firestore()
  .collection("rooms")
  .add(adultRoom)
  .then(() => console.log("❌ UNEXPECTED: Created adult room without verification"))
  .catch(err => {
    if (err.code === "permission-denied") {
      console.log("✅ EXPECTED: Cannot create adult room (not verified)");
    } else {
      console.error("Unexpected error:", err.message);
    }
  });
```

**Expected Result:** ✅ `permission-denied` (user not adult-verified)

---

## Phase 4: Validate Firestore Rules (3 min)

### Check Rules in Emulator

1. Open Emulator Dashboard: `http://localhost:4000`
2. Navigate to **Firestore** tab
3. Look at your test data:
   - `rooms/{roomId}` (room created)
   - `rooms/{roomId}/participants/{userId}` (join successful)

### Export Rules for Review
```bash
firebase firestore:indexes --pretty
firebase emulators:export ./emulator-backup
```

---

## Phase 5: End-to-End Flutter Test (5 min)

### Step 5.1: Run Flutter with Emulator
```bash
# Terminal 1: Start emulators
firebase emulators:start --project=mixvy-rules-test --only=firestore,auth

# Terminal 2: Run Flutter app pointing to emulator
flutter run -d chrome \
  -DUSE_FIREBASE_EMULATORS=true \
  -DFIREBASE_EMULATOR_HOST=localhost \
  -DFIREBASE_AUTH_EMULATOR_PORT=9099 \
  -DFIRESTORE_EMULATOR_PORT=8085
```

### Step 5.2: Test Login & Room Join
1. Open app at `http://localhost:port`
2. Sign up with email: `testuser@mixvy.local`
3. Navigate to home screen
4. Try joining a test room
5. Check browser console for errors:
   - `[RoomJoinError]` ← Should NOT appear
   - `permission-denied` ← Should NOT appear
   - Participant doc created ← Should see this

### Step 5.3: Monitor Firestore Emulator
In Emulator UI (http://localhost:4000):
1. Click **Firestore** → **Collections**
2. Navigate to `rooms → {roomId} → participants`
3. You should see participant docs appear in real-time

---

## Expected Test Results

| Test Case | Status | Notes |
|-----------|--------|-------|
| Non-adult room join | ✅ PASS | No permission errors |
| Guest access | ✅ permission-denied | Expected (guests need auth) |
| Multi-user join | ✅ PASS | Different users can join |
| Adult room (unverified) | ✅ permission-denied | Expected (need verification) |
| Flutter login | ✅ PASS | No reCAPTCHA errors |
| Flutter room join | ✅ PASS | Participant doc created |

---

## Troubleshooting

### Issue: "Firestore emulator not running"
```bash
# Kill existing processes
Get-Process java | Stop-Process -Force

# Restart emulator with verbose logging
firebase emulators:start --project=mixvy-rules-test --only=firestore,auth --debug
```

### Issue: "App Check token validation fails in Flutter"
This is EXPECTED in emulator mode. The emulator bypasses App Check validation.
- In production: Real App Check tokens will be used
- In emulator: App Check is disabled

### Issue: "Permission denied on participant create"
Check emulator logs for:
1. User is authenticated? (`request.auth != null`)
2. Room exists? (`exists(/rooms/{roomId})`)
3. User can read room? (`canReadRoomById(roomId)`)

---

## Cleanup

### Stop Emulator
```bash
# In Terminal 1 (emulator): Press Ctrl+C
```

### Export Backup (Optional)
```bash
firebase emulators:export ./emulator-backup
```

### Clean All Emulator Data
```bash
firebase emulators:start --project=mixvy-rules-test --only=firestore,auth --export-on-exit ./emulator-backup --import ./emulator-backup
```

---

## Next Steps After Testing

### ✅ If All Tests Pass
1. Deploy Firestore rules to production:
   ```bash
   firebase deploy --only firestore:rules
   ```
2. Build & deploy web app:
   ```bash
   flutter build web --release --base-href '/'
   firebase deploy
   ```
3. Monitor production logs for 24 hours

### ❌ If Tests Fail
1. Check specific error in Firestore emulator logs
2. Review the relevant rule block (participant/member create)
3. Fix rule logic
4. Re-test in emulator
5. Repeat until passing

---

## Monitoring Production After Deployment

Once deployed, monitor these metrics:

**Firebase Console → Logging**
- Filter: `severity >= ERROR AND jsonPayload.code = "permission-denied"`
- Track count and patterns over 24 hours

**Browser Console** (after deploying Flutter app)
- Filter: `[RoomJoinError]`
- Should see ZERO if deployment successful

**Firebase Firestore UI**
- Monitor participant doc creation rate
- Verify room joins are persisting

---

**Status:** Ready to execute  
**Confidence Level:** High (emulator validates rules before production)  
**Risk Level:** Low (local testing, no production impact)

Execute phases 1-4 now, then decide on production deployment based on test results.
