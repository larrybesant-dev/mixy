# MIXVY E2E Testing - Complete Guide

**Status:** ✅ Post-Migration Testing Plan Ready
**Date:** 2026-06-24
**Purpose:** Validate critical user flows after dependency refactoring

---

## 📋 What You're Getting

Three testing documents have been created in your workspace:

| Document | Purpose | Time | Type |
|----------|---------|------|------|
| **TEST_PLAN_MANUAL_UAT.md** | Step-by-step manual tests for 3 critical flows | 15-20 min | Manual |
| **AUTOMATED_TESTING_SETUP.md** | Framework setup guide (integration_test + patrol) | 30-45 min | Setup |
| **integration_test/e2e_critical_flows_test.dart** | Ready-to-run automated test code | N/A | Automated |
| **integration_test/fixtures/test_data.dart** | Reusable test constants and helpers | N/A | Utilities |

---

## 🚀 Quick Start

### Step 1: Manual Testing (Do This First!)

```bash
# Open: TEST_PLAN_MANUAL_UAT.md
# Follow the 3 test flows:
# 1. Onboarding & Auth (5 min)
# 2. Room Engagement & Moderation (5 min)
# 3. Social Connectivity & State Sync (5-10 min)

# Use this checklist:
# - Open browser DevTools (F12)
# - Monitor Console for errors
# - Check Network tab for Firestore calls
# - Verify WebRTC signaling
```

### Step 2: Set Up Automated Testing

```bash
# Install dependencies (if not already done)
flutter pub get

# Run existing integration tests
flutter test integration_test/e2e_critical_flows_test.dart -d web

# Expected output:
# ✅ Flow 1: User can sign in...
# ✅ Flow 2: User can join room...
# ✅ Flow 3: Friends list updates...
```

### Step 3: Add to CI/CD (Optional)

```bash
# Create: .github/workflows/e2e-tests.yml
# (Template provided in AUTOMATED_TESTING_SETUP.md)

# Tests will run on every PR automatically
```

---

## 🧪 Three Critical Flows to Test

### Flow 1: Onboarding & Authentication

**What to verify:**
- ✅ User signs in successfully
- ✅ Firebase auth responds
- ✅ User redirects to home screen (not stuck on login)
- ✅ Profile name displays correctly
- ✅ Session persists after refresh

**Expected Console Output:**
```
[ROUTER][REDIRECT][session=mqseyskc #1] from=/ to=stay reason=allow_navigation
startup_metric name=first_frame_rendered_time launch_type=cold value_ms=1056
Firebase Initialized: OK
```

**Common Failures:**
- ❌ "Firebase auth failed" → Check Firebase credentials in .env
- ❌ User stuck on login → Check `lib/router.dart` redirect logic
- ❌ Profile data missing → Check Firestore rules and permissions

---

### Flow 2: Room Engagement & Moderation Panel

**What to verify:**
- ✅ User joins room successfully
- ✅ WebRTC signaling established
- ✅ Moderation panel opens
- ✅ "Mute All" control updates Firestore
- ✅ Chat messages sync in real-time
- ✅ No state management errors

**Expected Console Output:**
```
[WebRtcRoomService] ✅ Production ICE servers initialized successfully
[WebRtcRoomService] Joining room signaling: SQvScGzngFF4W3gtqekZ as 1132578696
Firestore Write: POST /google.firestore.v1.Firestore/Write
```

**Common Failures:**
- ❌ "Looking up a deactivated widget" → Riverpod listener issue
- ❌ WebRTC fails → Check Agora credentials and ICE server config
- ❌ Moderation controls don't update → Check `lib/services/moderation/` service

---

### Flow 3: Social Connectivity & State Sync

**What to verify:**
- ✅ Friends list loads with presence indicators
- ✅ Presence updates in real-time (no manual refresh needed)
- ✅ Feed refreshes and shows new content
- ✅ Profile completion bar updates live
- ✅ Riverpod listeners trigger rebuilds

**Expected Console Output:**
```
[Riverpod] Provider initialized: friendsProvider
[Firestore] Listener created for /users/{userId}/friends
Presence indicator: online (green dot)
```

**Common Failures:**
- ❌ Presence doesn't update → Check `social_providers.dart` listeners
- ❌ Feed shows stale data → Riverpod cache issue, clear state
- ❌ Duplicate Firestore listeners → Check provider dispose logic

---

## 🔍 What Each Test File Does

### `TEST_PLAN_MANUAL_UAT.md`
- **Pre-test checklist** (cache clear, test accounts setup)
- **Step-by-step flow instructions** with expected outcomes
- **Failure criteria** (what would make it FAIL)
- **Issue tracking table** to log bugs found
- **Sign-off section** for UAT documentation

**Use this if:**
- You want to manually validate before deployment
- You need to demo functionality to stakeholders
- You're debugging console errors

---

### `AUTOMATED_TESTING_SETUP.md`
- **Framework comparison** (integration_test vs patrol)
- **Installation steps** for both frameworks
- **Best practices** (finders, async handling, real-time testing)
- **CI/CD example** (GitHub Actions workflow)
- **Troubleshooting guide** for common test failures

**Use this if:**
- You want to set up automated tests for CI/CD
- You need to run tests on every PR
- You want visual regression testing (Patrol)

---

### `integration_test/e2e_critical_flows_test.dart`
- **4 complete test cases** (auth, room, social, error handling)
- **Widget finder patterns** for your app's UI
- **Async handling** for Firebase operations
- **Real-time sync verification** for Riverpod

**Use this by running:**
```bash
flutter test integration_test/e2e_critical_flows_test.dart -d web
```

---

### `integration_test/fixtures/test_data.dart`
- **Test credentials** (testuser1@mixvy.test, etc.)
- **Test UI element names** (button labels, field IDs)
- **Test timeouts** (Firebase usually needs 5 sec)
- **Test data generators** (for unique room names, messages)

**Use this in your tests:**
```dart
import 'fixtures/test_data.dart';

// In test:
await tester.enterText(
  find.byType(TextField),
  TestUserCredentials.testEmail1,
);
```

---

## ✅ Validation Checklist

Before considering this migration "Done", verify:

- [ ] **Manual UAT Passed**
  - [ ] Auth flow works (sign-in redirects to home)
  - [ ] Room join works (WebRTC signaling established)
  - [ ] Moderation panel updates state
  - [ ] Chat syncs real-time
  - [ ] Friends list shows presence

- [ ] **Zero Console Errors**
  - [ ] No "deactivated widget" errors
  - [ ] No Firebase auth failures
  - [ ] No "invalid_use_of_protected_member" warnings
  - [ ] No duplicate Firestore listeners

- [ ] **Riverpod State Management**
  - [ ] Providers rebuild when expected
  - [ ] Listeners don't fire on dispose
  - [ ] Cache invalidation works
  - [ ] No state leaks between tests

- [ ] **Performance**
  - [ ] First frame rendered <2s
  - [ ] Room join <5s (WebRTC + Firestore)
  - [ ] Moderation updates <1s (Firestore write)

- [ ] **Automated Tests Run**
  - [ ] `flutter test integration_test/ -d web` passes
  - [ ] All 4 test cases green ✅
  - [ ] No flaky failures (runs 3x consistently)

---

## 🐛 If You Find Issues

### Issue: Presence indicators don't update
**Check:**
1. Open `lib/shared/providers/social_providers.dart`
2. Verify Firestore listener is active in DevTools → Network
3. Check `ref.listen()` in widget is not disposed prematurely

**Fix Reference:**
```dart
// ❌ WRONG: Listener called in dispose
void dispose() {
  ref.read(presenceProvider); // ← Can throw error
  super.dispose();
}

// ✅ RIGHT: Cache listener early
@override
void initState() {
  super.initState();
  _presence = ref.read(presenceProvider); // Cache it here
}
```

### Issue: Chat messages don't sync
**Check:**
1. DevTools → Network → Look for Firestore Write calls
2. Verify no 401 errors (auth issue)
3. Check Firestore rules allow user to write to messages collection

### Issue: Moderation controls lag
**Check:**
1. Open DevTools → Network → Filter for "Firestore"
2. Look for multiple writes (should be 1, not duplicated)
3. Check `lib/services/moderation/moderation_service.dart` for batch calls

### Issue: WebRTC ICE Gathering Failure (Network/Firewall)
**Console Error:**
```
Pre-flight Alert ICE Gathering failure: Possible restrictive corporate firewall
or UDP blockage: TimeoutException after 0.00'15.000000: Future not completed
```

**What it means:**
- UDP is blocked (corporate firewall, ISP, restricted network)
- STUN/TURN servers unreachable
- WebRTC can't establish P2P connection

**Check:**
1. Verify network allows UDP (not just TCP/HTTP)
2. Test on different network (mobile hotspot, home WiFi)
3. Check firewall rules allow port 19302+ (Agora ICE)

**What happens:**
- ✅ Chat still works (uses Firestore over HTTPS)
- ✅ Room loads successfully
- ✅ UI displays gracefully with error alert
- ❌ Video/audio streaming unavailable
- ❌ Real-time signaling disabled

**This is NOT a bug** — it's a real-world network constraint. App handles it well by:
- Showing clear error message to user
- Allowing chat/messaging to continue
- Graceful degradation (no crash)

**For testing:** Try room on multiple networks to verify this scenario

---

## 📚 Reference Docs

- **Flutter Testing:** https://flutter.dev/docs/testing
- **Patrol Framework:** https://patrol.leancode.co/docs/
- **Riverpod Testing:** https://riverpod.dev/docs/essentials/testing
- **Firebase Testing:** https://firebase.flutter.dev/docs/testing/
- **Integration Tests:** https://flutter.dev/docs/testing/integration-tests

---

## 🎯 Next Steps

1. **This Week:**
   - [ ] Run manual UAT (15 min)
   - [ ] Document any issues found
   - [ ] Record final "PASS" or list bugs

2. **Next Week:**
   - [ ] Expand `e2e_critical_flows_test.dart` with edge cases
   - [ ] Set up GitHub Actions CI/CD (see AUTOMATED_TESTING_SETUP.md)
   - [ ] Add visual regression tests with Patrol

3. **Ongoing:**
   - [ ] Run tests on every PR
   - [ ] Monitor test flakiness
   - [ ] Add tests for new features

---

## 💡 Pro Tips

- **Use `pumpAndSettle()`** liberally (5+ seconds for Firestore operations)
- **Enable DevTools logging** to catch state management issues early
- **Take screenshots on failure** for bug reports
- **Run tests in CI before merging** PRs
- **Test with real Firebase**, not emulator (for auth + WebRTC)

---

**Questions?** Check individual test files or refer to framework documentation.

**Ready to test?** Start with `TEST_PLAN_MANUAL_UAT.md` — takes 15 minutes! 🚀
