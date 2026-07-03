# Firebase Emulator Testing - Quick Start Guide
**Date:** 2026-07-03  
**Purpose:** Validate App Check and room join permissions before production  
**Status:** Ready to test

---

## 📋 What's Included

Your emulator testing suite now includes:

| File | Purpose | Platform |
|------|---------|----------|
| `tools/run_emulator_tests.ps1` | Quick-start emulator (PowerShell) | Windows ✅ |
| `tools/run_emulator_tests.sh` | Quick-start emulator (Bash) | Mac/Linux |
| `tools/emulator_test_runner.html` | Interactive browser test UI | All |
| `FIREBASE_EMULATOR_TEST_PLAN_2026-07-03.md` | Full test documentation | Reference |

---

## 🚀 Getting Started (5 minutes)

### Option 1: Interactive Browser Testing (Recommended)

#### Step 1: Start Emulator
```powershell
# Windows PowerShell
powershell -ExecutionPolicy Bypass -File tools/run_emulator_tests.ps1

# Or manually
firebase emulators:start --project=mixvy-rules-test --only=firestore,auth
```

**Expected Output:**
```
✓ Emulator Suite Ready
Emulator Dashboard: http://localhost:4000
Firestore Emulator: 127.0.0.1:8085
Auth Emulator: 127.0.0.1:9099
```

#### Step 2: Open Test Runner
```
1. Open browser: http://localhost:8000/tools/emulator_test_runner.html
   (or save the file locally and open with file:// protocol)
2. Click "Connect to Emulator"
3. Follow the on-screen test sequence
```

#### Step 3: Run Tests
**Setup Phase:**
1. Click "Create testuser1@mixvy.local"
2. Click "Create testuser2@mixvy.local"
3. Click "Create Non-Adult Room"

**Permission Tests:**
- Run individual tests or "Execute Full Test Suite"
- Watch results update in real-time

---

## 🧪 Test Scenarios

### ✅ Scenario 1: User Joins Room (Should Pass)
**What it tests:** Authenticated user can join a room they have access to  
**Expected result:** Participant doc created successfully  
**If it fails:** Check `canReadRoomById()` rule logic

### ✅ Scenario 2: User 2 Joins (Should Pass)
**What it tests:** Different authenticated user can join same room  
**Expected result:** Both users in participants collection  
**If it fails:** Check room accessibility logic

### ❌ Scenario 3: Guest Access (Should Fail)
**What it tests:** Unauthenticated user cannot access room data  
**Expected result:** `permission-denied` error  
**If it passes:** Rules are too permissive (fix needed)

### ✅ Scenario 4: Read Participants (Should Pass)
**What it tests:** Authenticated user can read participant roster  
**Expected result:** List of participant docs  
**If it fails:** Check participant read rules

### ✅ Scenario 5: Update Own State (Should Pass)
**What it tests:** User can update their own participant state (mic, camera)  
**Expected result:** Participant doc updated  
**If it fails:** Check participant update rules

### ❌ Scenario 6: Adult Room (Should Fail)
**What it tests:** Unverified user cannot create adult rooms  
**Expected result:** `permission-denied` error  
**If it passes:** Rules are not checking adult verification

---

## 📊 Test Results Interpretation

| Result | Meaning | Action |
|--------|---------|--------|
| ✅ PASS | Rule allows the operation | No action needed |
| ❌ FAIL | Rule rejects the operation | Check rule logic |
| ⏭️ SKIP | Test setup incomplete | Complete setup first |

---

## 🔍 Understanding Your Firestore Rules

Your updated rules structure:

```
canReadRoomById(roomId) {
  // 1. Check room exists (lightweight)
  exists(/rooms/{roomId})
  
  // 2. Check room is readable by requester
  roomReadableByRequester(roomData)
  // → Not adult OR user is verified
  // → OR guest access allowed AND not adult
}

participants/{participantId} {
  create: if signedIn()
    && participantId == uid()
    && exists(/rooms/{roomId})      // Room must exist
    && canReadRoomById(roomId)      // User must be able to read room
    && request.resource.data...     // Validate fields
}
```

**Key Flow:**
1. User attempts to join room → create participant doc
2. Firestore evaluates: `canReadRoomById(roomId)`
3. If true → participant created ✅
4. If false → `permission-denied` ❌

---

## 🛠️ Debugging Failed Tests

### Problem: Test shows ❌ FAIL but should ✅ PASS

**Step 1: Check Emulator Logs**
```
In PowerShell terminal running emulator, look for:
- "ALLOW" (rule passed)
- "DENY" (rule rejected)
- Error messages
```

**Step 2: Check Browser Console**
```
F12 → Console → Look for:
- Firebase auth state
- Error messages
- Network requests
```

**Step 3: Verify Test Data**
```
Open Emulator UI: http://localhost:4000
Firestore → Collections → rooms → {roomId}
Verify room data exists and is correct
```

**Step 4: Review Rule Logic**
```
Check relevant rule in firestore.rules:
- Search for function name causing issue
- Review condition logic
- Test with browser console manually
```

---

## 📝 Manual Testing via Browser Console

If the HTML test runner doesn't work, test manually in browser console:

### Test 1: Create Room
```javascript
const userId = await firebase.auth().createUserWithEmailAndPassword(
  "test@mixvy.local", "Test123"
).then(u => u.user.uid);

const roomRef = await firebase.firestore().collection('rooms').add({
  hostId: userId,
  ownerId: userId,
  name: "Test",
  isAdult: false,
  isLive: true,
  memberCount: 1,
  audienceUserIds: [userId],
  stageUserIds: [],
  adminUserIds: [],
  allowGuestAccess: true,
  createdAt: firebase.firestore.FieldValue.serverTimestamp(),
  updatedAt: firebase.firestore.FieldValue.serverTimestamp()
});

window.testRoomId = roomRef.id;
console.log("Room created:", window.testRoomId);
```

### Test 2: Join Room
```javascript
const userId = firebase.auth().currentUser.uid;

firebase.firestore()
  .collection('rooms')
  .doc(window.testRoomId)
  .collection('participants')
  .doc(userId)
  .set({
    userId: userId,
    role: 'audience',
    isMuted: false,
    isBanned: false,
    camOn: false,
    userStatus: 'online',
    joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
    lastActiveAt: firebase.firestore.FieldValue.serverTimestamp()
  })
  .then(() => console.log("✅ Joined successfully"))
  .catch(err => console.error("❌ Join failed:", err.code, err.message));
```

---

## ✅ Success Criteria

After running all tests, you should see:

- ✅ Test 1: PASS (User joins room)
- ✅ Test 2: PASS (User 2 joins)
- ✅ Test 3: FAIL (Permission-denied for guest) ← This should fail!
- ✅ Test 4: PASS (Read participants)
- ✅ Test 5: PASS (Update participant state)
- ✅ Test 6: FAIL (Permission-denied for unverified adult room) ← This should fail!

**If all matches above:** ✅ Rules are correct, ready for production
**If any mismatch:** ❌ Rules need adjustment before production

---

## 🚀 After Testing: Deploy to Production

### If Tests Pass ✅

```bash
# 1. Deploy Firestore rules
firebase deploy --only firestore:rules

# 2. Build Flutter app
flutter build web --release --base-href '/'

# 3. Deploy hosting
firebase deploy

# 4. Monitor logs for 24 hours
# Firebase Console → Logging → Filter permission-denied
```

### If Tests Fail ❌

1. Identify which rule is too strict/permissive
2. Update rule in `firestore.rules`
3. Re-test in emulator (no redeploy needed)
4. Repeat until all tests pass
5. Then deploy to production

---

## 📊 Monitoring After Deployment

**Real-time Error Tracking:**
```bash
# From your project root
node tools/monitor_room_join_errors.js --realtime
```

**Firebase Console Monitoring:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. **Logging** → Filter: `severity=ERROR AND code=permission-denied`
3. Track count and patterns over 24 hours

**Browser Console Monitoring (After App Deployed):**
```javascript
// Run in browser console of deployed app
window.addEventListener('error', (e) => {
  if (e.message.includes('permission-denied')) {
    console.error('[RoomJoinError] Permission denied:', e);
  }
});
```

---

## ⏱️ Estimated Timeline

| Phase | Time | Task |
|-------|------|------|
| Setup | 5 min | Start emulator, load test runner |
| Test Setup | 2 min | Create users and room |
| Permission Tests | 5 min | Run all test scenarios |
| Analysis | 3 min | Review results |
| Troubleshooting | 5-15 min | Fix any failing tests |
| **Total** | **20-35 min** | **Full validation** |

---

## 📞 Support

**If emulator won't start:**
- Ensure Java 21+ installed: `java -version`
- Ensure Firebase CLI installed: `firebase --version`
- Kill existing Java processes: `Get-Process java | Stop-Process -Force`
- Try manual start: `firebase emulators:start --only firestore,auth --debug`

**If tests show permission-denied unexpectedly:**
- Check user is authenticated: `firebase.auth().currentUser.uid`
- Check room exists: Open Emulator UI → Firestore → rooms
- Review rule logic in `firestore.rules`
- Run manual test in browser console (see above)

---

## 🎯 Next Steps

1. **Start emulator:** `powershell -ExecutionPolicy Bypass -File tools/run_emulator_tests.ps1`
2. **Open test runner:** `http://localhost:8000/tools/emulator_test_runner.html`
3. **Run tests:** Click buttons in order
4. **Review results:** Should see all PASS except tests 3 & 6 (FAIL)
5. **Deploy:** If successful, run `firebase deploy`

---

**Status:** ✅ Testing infrastructure complete  
**Confidence:** High (validated locally before production)  
**Risk Level:** Low (emulator = safe testing)  
**Estimated Deployment Risk:** <5% (assuming tests pass)

Ready to proceed? Start with emulator in next section.
