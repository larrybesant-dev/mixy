# MIXVY Testing Quick Reference

## 📱 Manual Testing (UAT)

```bash
# Open and follow:
TEST_PLAN_MANUAL_UAT.md

# Pre-test setup:
1. Clear browser cache (Cmd+Shift+Delete or Ctrl+Shift+Delete)
2. Open DevTools (F12)
3. Create test accounts:
   - testuser1@mixvy.test / TestPassword123!
   - testuser2@mixvy.test / TestPassword123!
4. Have two browser tabs ready

# Expected time: 15-20 minutes
# Expected result: 3 critical flows PASS
```

---

## 🤖 Automated Testing Commands

### Setup
```bash
flutter pub get
```

### Run Integration Tests
```bash
# Web (fastest for development)
flutter test integration_test/ -d web

# Specific test
flutter test integration_test/e2e_critical_flows_test.dart -d web

# With verbose output (debugging)
flutter test integration_test/ -d web -v

# Android emulator
flutter test integration_test/ -d emulator-5554

# Windows desktop
flutter test integration_test/ -d windows
```

### Coverage & Reports
```bash
# Generate coverage report
flutter test integration_test/ --coverage

# View coverage (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html  # macOS
```

### Patrol Tests (if installed)
```bash
patrol test -d web
patrol test -d android
patrol test -d web --verbose
```

---

## 🔍 Debugging Guide

### Browser DevTools
```
1. Press F12 to open DevTools
2. Console tab → Check for errors like:
   ❌ "Looking up a deactivated widget's ancestor"
   ❌ "Firebase auth failed"
   ❌ "Permission denied"

3. Network tab → Check for:
   ✅ Firestore Write calls (should be there)
   ✅ No 401/403 errors
   ✅ WebRTC ICE candidate exchanges

4. Application tab → Check:
   ✅ LocalStorage has user token
   ✅ IndexedDB has Firestore cache
```

### Flutter Logging
```dart
// Add to test to see logs:
import 'dart:developer' as developer;

testWidgets('Example', (WidgetTester tester) async {
  developer.log('Test started', name: 'E2E_TEST');
  // ... test code ...
});

// Run with: flutter test -d web -v
```

### Firestore Debugging
```javascript
// In browser console while app runs:
console.log('Checking Firestore listeners...');

// View active listeners in Firebase Console:
// Dashboard → Firestore → Indexes (check listener count)
```

---

## ✅ Pre-Deployment Checklist

- [ ] **Manual UAT Passed**
  - Auth flow: ✅
  - Room engagement: ✅
  - Social connectivity: ✅

- [ ] **Console Clean**
  - No error red text
  - Only warnings/info allowed

- [ ] **Automated Tests Green**
  - `flutter test integration_test/ -d web` → All 4 tests PASS

- [ ] **Performance OK**
  - First frame: <2s
  - Room join: <5s
  - Moderation updates: <1s

- [ ] **Zero State Leaks**
  - Refresh page → Still logged in
  - Leave room → No listeners active
  - Sign out → State cleared

---

## 🗂️ Test File Reference

| File | Contains | Run With |
|------|----------|----------|
| `TEST_PLAN_MANUAL_UAT.md` | Step-by-step manual tests | Browser + checklist |
| `AUTOMATED_TESTING_SETUP.md` | Framework setup guide | Read + follow steps |
| `e2e_critical_flows_test.dart` | 4 automated test cases | `flutter test integration_test/` |
| `test_data.dart` | Reusable test constants | Import in tests |
| `E2E_TESTING_COMPLETE_GUIDE.md` | This full guide | Reference |

---

## 🐛 Common Issues & Fixes

| Problem | Console Error | Fix |
|---------|---------------|-----|
| User stuck on login | Firebase auth failed | Check credentials, Firebase project active |
| Presence not updating | None (silent fail) | Check Riverpod listeners in social_providers.dart |
| WebRTC fails | ICE candidate issue | Verify Agora credentials, network open |
| Chat doesn't sync | Permission denied | Check Firestore security rules |
| UI doesn't respond | Deactivated widget | Use `pumpAndSettle(Duration(seconds: 5))` |
| Moderation lags | None (slow network) | Check Firestore batch writes, no duplicates |
| ICE Gathering fails | UDP blockage timeout | Not a bug! Network blocks UDP (try different WiFi) |

---

## 💬 Example Test Session

```bash
# 1. Start web server
flutter run -d web

# 2. In another terminal, run tests
flutter test integration_test/e2e_critical_flows_test.dart -d web

# 3. Expected output:
# ✓ Flow 1: User can sign in and land on home screen (5s)
# ✓ Flow 2: User can join room and test moderation controls (8s)
# ✓ Flow 3: Friends list updates in real-time via Riverpod (6s)
# ✓ Flow 4: No critical console errors during navigation (3s)
#
# All tests passed! (22s total)

# 4. If test fails:
flutter test integration_test/e2e_critical_flows_test.dart -d web -v

# 5. Check output for:
# - Which test failed
# - Which widget not found
# - Error message
```

---

## 📞 Support

- **Flutter Testing Docs:** https://flutter.dev/docs/testing
- **Riverpod Testing:** https://riverpod.dev/docs/essentials/testing
- **Firebase Console:** https://console.firebase.google.com/
- **Agora Console:** https://console.agora.io/

---

**Last Updated:** 2026-06-24
**Status:** Ready for UAT ✅
