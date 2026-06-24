# MIXVY End-to-End Test Plan - Manual UAT

**Purpose:** Validate critical user journeys after dependency refactoring
**Date:** 2026-06-24
**Tester:** [Your Name]
**Duration:** ~15-20 minutes

---

## Pre-Test Checklist

- [ ] Browser cache cleared (or incognito mode)
- [ ] Firebase project active and test users created
- [ ] Two test accounts available:
  - `testuser1@mixvy.test` (for auth flow)
  - `testuser2@mixvy.test` (for social connectivity testing)
- [ ] Browser DevTools open (F12) to monitor console for errors
- [ ] Network tab open to track Firestore/WebRTC calls
- [ ] At least two browser tabs/windows ready

---

## Test Flow 1: Onboarding & Authentication

### Scenario: New user signs in and lands on correct home screen

**Steps:**

1. **Navigate to app**
   - [ ] Open `https://mix-and-mingle-v2.web.app/` (or local dev URL)
   - **Expected:** Loading screen appears, then login/signup modal

2. **Sign Up (if first time)**
   - [ ] Click "SIGN UP" button
   - [ ] Enter email: `testuser1@mixvy.test`
   - [ ] Enter password: `TestPassword123!`
   - [ ] Click "Create Account"
   - **Expected:** Email verification sent (check console for success)

3. **Sign In**
   - [ ] If new account, complete email verification
   - [ ] Navigate to login screen
   - [ ] Enter credentials: `testuser1@mixvy.test` / `TestPassword123!`
   - [ ] Click "SIGN IN"
   - **Expected:**
     - [ ] Redirect to `/home` (or home screen)
     - [ ] Profile card visible (username, profile pic placeholder)
     - [ ] Bottom nav shows: Feed, Messages, Live Rooms, Dating, Profile
     - [ ] No console errors (check DevTools → Console tab)

4. **Verify Home Screen State**
   - [ ] Check "MIX / CONNECT / INDULGE" nav cards present (brand design)
   - [ ] Click "Feed" tab
   - **Expected:**
     - [ ] Feed loads with empty state (or test data)
     - [ ] No network errors in DevTools → Network tab
     - [ ] Firestore listener active (check `console.log` for "Firestore initialized")

5. **Verify Session Persistence**
   - [ ] Refresh page (Cmd+R / Ctrl+R)
   - **Expected:**
     - [ ] User remains logged in
     - [ ] Home screen loads immediately (no auth redirect)
     - [ ] Profile name matches

### ✅ Pass Criteria
- User successfully signs in
- Home screen renders with all nav elements
- No 401/403 auth errors in console
- Session persists across refresh

### ❌ Fail Criteria
- Auth modal appears after sign-in
- Profile data missing or mismatched
- Console errors: "Firebase auth failed", "Unauthorized"

---

## Test Flow 2: Room Engagement & Moderation Panel

### Scenario: User joins a room and tests moderation controls

**Prerequisites:**
- [ ] Signed in as `testuser1@mixvy.test`
- [ ] Have two browser windows/tabs open (to simulate multiple users in same room)

**Steps:**

1. **Navigate to Live Rooms**
   - [ ] Click "Live Rooms" in bottom nav
   - **Expected:**
     - [ ] Rooms list loads (should show recommended rooms or live sessions)
     - [ ] Each room card shows: room name, host avatar, listener count

2. **Create or Join a Test Room**
   - [ ] If no rooms exist, click "Create Room" button
     - [ ] Enter room name: "E2E Test Room"
     - [ ] Click "Start"
   - [ ] Alternatively, join an existing room by clicking its card
   - **Expected:**
     - [ ] Room page loads with video/audio controls
     - [ ] WebRTC connection initiates (check console: "WebRTC signaling established")
     - [ ] Room shows "1 listening" indicator

3. **Open Moderation Panel (Host Only)**
   - [ ] Look for gear icon or "Settings" button in room
   - [ ] Click to open moderation panel
   - **Expected:**
     - [ ] Panel shows controls: "Mute All", "Lock Mics", "Lock Cameras", "Kick User"
     - [ ] Controls are clickable (not grayed out)

4. **Test "Mute All" Control**
   - [ ] Click "Mute All Mics" button
   - [ ] In second browser tab (as listener), verify mic indicator changes
   - **Expected:**
     - [ ] Button shows loading state, then success state
     - [ ] Firestore `rooms/{roomId}` document updates (check Network tab)
     - [ ] UI reflects mute state immediately (no lag)
     - [ ] Console shows no errors like "Access denied" or "Permission denied"

5. **Test "Lock Cameras" Control**
   - [ ] Click "Lock Cameras" button
   - [ ] Verify second tab reflects camera lock
   - **Expected:**
     - [ ] State updates propagate (Riverpod listeners trigger)
     - [ ] Network call shows single Firestore write (no duplicate requests)
     - [ ] No console warnings: "deprecated_member_use", "invalid_use_of_protected_member"

6. **Test Real-Time Chat in Room**
   - [ ] Scroll to chat panel (right side or bottom)
   - [ ] Type message: "E2E test message"
   - [ ] Click "Send"
   - **Expected:**
     - [ ] Message appears immediately in chat
     - [ ] In second tab, message appears in real-time (no refresh needed)
     - [ ] Firestore write confirmed in Network tab

7. **Leave Room**
   - [ ] Click "Leave" or back button
   - [ ] Verify redirect to rooms list
   - **Expected:**
     - [ ] No console errors like "deactivated widget"
     - [ ] Resources cleaned up (WebRTC connections closed)

### ✅ Pass Criteria
- Room joins successfully with WebRTC signaling
- Moderation controls are responsive and update Firestore
- Chat messages appear in real-time across tabs
- No state management errors (Riverpod rebuilds work)

### ❌ Fail Criteria
- Console errors: "Looking up a deactivated widget"
- Moderation controls don't update second tab
- Chat messages not synced in real-time
- Network shows duplicate Firestore writes

### ⚠️ Edge Case: Network/Firewall Issues
**You may see:** "Pre-flight Alert ICE Gathering failure: UDP blockage"
- This is **NOT a bug** in the app
- It means your network blocks UDP (corporate firewall, ISP, etc.)
- Chat will still work, but video/audio won't (graceful degradation)
- **Test on different network** (mobile hotspot) to verify this scenario
- **Pass if:** Error alert displays clearly and app doesn't crash

---

## Test Flow 3: Social Connectivity & State Sync

### Scenario: User navigates to Friends list and refreshes feed with Riverpod sync

**Prerequisites:**
- [ ] Signed in as `testuser1@mixvy.test`
- [ ] Second account `testuser2@mixvy.test` is a "friend" (or follow)

**Steps:**

1. **Navigate to Profile Tab**
   - [ ] Click "Profile" in bottom nav
   - **Expected:**
     - [ ] Profile page loads with user info
     - [ ] "Profile Completion" bar visible (0-100%)
     - [ ] Edit button clickable

2. **Navigate to Friends List**
   - [ ] Look for "Friends" or "Connections" section
   - [ ] Click to open friends list
   - **Expected:**
     - [ ] List of friends loads (or empty state if no friends)
     - [ ] Each friend card shows: avatar, name, status (online/offline)
     - [ ] "Presence indicator" shows green dot if online

3. **Test Presence Sync**
   - [ ] In second browser tab, sign in as `testuser2@mixvy.test`
   - [ ] In first tab, check if `testuser2` presence changes to "online"
   - **Expected:**
     - [ ] First tab's friends list updates **without page refresh** (Riverpod listeners)
     - [ ] Presence indicator turns green in <1 second
     - [ ] Console shows Firestore listener callback (check "presence_listeners")

4. **Navigate to Feed**
   - [ ] Click "Feed" tab
   - [ ] Wait 1-2 seconds for feed to load
   - **Expected:**
     - [ ] Feed items appear
     - [ ] If `testuser2` posted content, it appears in feed
     - [ ] No repeated API calls (check Network tab for batching)

5. **Trigger Feed Refresh**
   - [ ] In second tab, create a post or action (e.g., post story)
   - [ ] In first tab, pull-to-refresh or click refresh button
   - [ ] Verify new content appears
   - **Expected:**
     - [ ] New post/content appears in feed
     - [ ] Riverpod providers trigger rebuild (check console for provider logs)
     - [ ] No duplicates or stale data

6. **Test Profile Completion Bar Update**
   - [ ] In second tab, edit profile (add bio, change avatar)
   - [ ] Return to first tab's Profile
   - [ ] Verify profile completion bar updates
   - **Expected:**
     - [ ] Bar reflects new completion percentage
     - [ ] Real-time sync (no manual refresh needed)
     - [ ] No console errors like "invalid_use_of_protected_member"

7. **Sign Out**
   - [ ] Click "Sign Out" button (usually in Profile menu)
   - **Expected:**
     - [ ] Redirect to login page
     - [ ] Session cleared (localStorage empty)
     - [ ] No console errors on logout

### ✅ Pass Criteria
- Friends list loads with real-time presence
- Presence indicator updates without page refresh
- Feed syncs in real-time when second user posts
- Riverpod state management works seamlessly
- Profile completion bar reflects changes immediately

### ❌ Fail Criteria
- Presence indicators don't update (manual refresh required)
- Feed shows stale data or duplicates
- Console errors: "Looking up a deactivated widget's ancestor is unsafe"
- Multiple duplicate Firestore listeners

---

## Issue Tracking

| Issue | Severity | Console Error | Resolution |
|-------|----------|---------------|-----------|
| [Example] Presence not updating | High | - | Check Riverpod listener in social_providers.dart |
| [Example] Moderation panel lag | Medium | - | Optimize Firestore writes (batch updates) |

---

## Summary

**Date Tested:** ______________
**Tester:** ______________
**Overall Result:** ☐ PASS ☐ FAIL
**Critical Issues Found:** _____ (0 = pass)
**Minor Issues Found:** _____

**Sign-off:** Tested and verified by __________________ on ______________
