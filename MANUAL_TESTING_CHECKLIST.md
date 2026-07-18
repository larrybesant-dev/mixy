# MixVy Manual Testing Checklist (July 16, 2026)

## ✅ Pre-Testing Verification (Already Completed)
- ✅ Firestore rules updated: Removed `hasValidAppCheck()` requirement  
- ✅ Room join architecture fixed: Using RoomController properly  
- ✅ All 25 core tests passing  
- ✅ Web build successful (68.8s, 0 errors)  
- ✅ Firestore users collection accessible via auth  

---

## 📋 Manual Testing Steps

### **Phase 1: Authentication** 
**Goal:** Verify user can login successfully

**Test Accounts Created:**
- **Account A:** `test_a_prod@example.com` / `ProdTest@2026!`  
- **Account B:** `test_b_prod@example.com` / `ProdTest@2026!`  
- **Account C:** `test_c_prod@example.com` / `ProdTest@2026!`

Use Account A for testing

**Steps:**
1. Open https://mixvy-v2.web.app in browser
2. Enter email: `test-ci-mixvy@local.test`
3. Enter password: `Test123!`
4. Click **SIGN IN** (gold button)

**Expected Result:**
- ✅ Login succeeds
- ✅ Redirected to home screen (not login screen)
- ✅ User profile loads (no crash)

**Failure Handling:**
- If login fails → Check browser console for error
- If stuck on login screen → Refresh page
- If redirected back to login → Check Firebase Auth is working

---

### **Phase 2: Home Screen Navigation**
**Goal:** Verify home screen loads and displays live rooms

**Steps:**
1. From home screen, look at the top navigation cards:
   - MIX
   - CONNECT
   - INDULGE

2. Look at the live rooms list below

**Expected Result:**
- ✅ Home screen renders without errors
- ✅ Navigation cards visible
- ✅ Live rooms displayed (count should match Firebase)
- ✅ No "Member ABC" placeholders (user names should show)

**Failure Handling:**
- If rooms don't load → Check Firestore console for rooms collection
- If names show as "Member ABC" → Indicates RoomSessionProvider issue

---

### **Phase 3: Room Join Flow** ⭐ CRITICAL TEST
**Goal:** Verify room join works and real-time features activate

**Steps:**
1. Click **JOIN** button on any active live room
2. Wait for room UI to load (should see host frame, participant count, etc.)
3. Check the **participant count** at the top
4. Stay in room for ~10 seconds

**Expected Result:**
- ✅ Room loads without errors
- ✅ Participant count displays (should be ≥ 1)
- ✅ Real-time participant updates visible (if other users join/leave)
- ✅ Host frame visible (gold border)
- ✅ Can see participant list with actual user names

**What This Tests:**
- RoomController.joinRoom() working
- Session initialization via RoomSessionService
- Real-time Firestore streams active
- Participant hydration (no "Member ABC" placeholders)

**Failure Handling:**
- If room join fails → Check browser console for error
- If participant count stuck at 0 → RoomController not updating UI
- If names show as "Member ABC" → User profile data not loading from Firestore

---

### **Phase 4: Real-Time Features**
**Goal:** Verify live room features work correctly

**Test 4a: Participant Count Updates**
1. From room, have another browser tab login and join same room
2. Check participant count in first tab updates in real-time

**Expected:** Count increases immediately

**Test 4b: Audio/Video (if applicable)**
1. Check if **On Mic** indicator appears (wine red badge)
2. Check if host has gold frame

**Expected:** Real-time indicators update correctly

**Test 4c: Gift Sending (if available)**
1. Click gift button (if visible)
2. Select a gift and send

**Expected:**
- ✅ Gift sends without error
- ✅ Coin allowance decrements
- ✅ No "permission denied" errors

---

### **Phase 5: Profile & Settings**
**Goal:** Verify user profile is accessible

**Steps:**
1. Click profile/settings icon (usually top-right or menu)
2. Check profile information loads

**Expected Result:**
- ✅ Profile loads without error
- ✅ User email and name display correctly
- ✅ Avatar loads (or placeholder if not set)

---

## 🔴 Critical Issues to Watch For

| Issue | Symptom | Root Cause |
|-------|---------|-----------|
| **Room join fails** | Error on join button click | RoomController not initialized |
| **Participant count stuck** | Always shows 1 or 0 | Real-time stream not active |
| **Member ABC placeholders** | Names show as "Member ABC" | Firestore user data not hydrating |
| **Permission denied errors** | Can't join/send gifts | Firestore rules issue |
| **Crash on home screen** | App becomes unresponsive | Layout/widget issue |

---

## 📊 Test Summary Format

**When Complete, Provide:**
```
✅ Phase 1 (Auth): [PASS/FAIL] - Details: ___
✅ Phase 2 (Home): [PASS/FAIL] - Details: ___
✅ Phase 3 (Join): [PASS/FAIL] - Details: ___
✅ Phase 4 (Real-time): [PASS/FAIL] - Details: ___
✅ Phase 5 (Profile): [PASS/FAIL] - Details: ___

Critical Issues Found: (list any)
Console Errors: (list any)
```

---

## 🔍 Debugging Resources

**If You Encounter Errors:**

1. **Open Browser Console** (F12 → Console)
   - Look for red errors
   - Check for Firebase warnings
   - Note any error messages

2. **Check Firestore Console**
   - https://console.firebase.google.com/project/mixvy-v2/firestore/databases
   - Verify users collection has data
   - Check rooms collection structure

3. **Check Firebase Auth Users**
   - https://console.firebase.google.com/project/mixvy-v2/authentication/users
   - Verify test account exists
   - Check if user is enabled

---

## ✨ Success Criteria

**Complete Success:**
- ✅ Login works with test-ci-mixvy@local.test
- ✅ Home screen loads and displays live rooms
- ✅ Room join succeeds without errors
- ✅ Participant count updates in real-time
- ✅ User names display (not "Member ABC")
- ✅ No permission-denied or crash errors

**If All Above Pass:** System is production-ready for soft launch! 🎉
