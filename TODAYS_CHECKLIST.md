# 📋 TODAY'S EXECUTION CHECKLIST — Both Paths

**Date:** June 25, 2026
**Target:** Complete both PATH A + PATH B + Mandatory tasks by 5pm
**Status:** 🟡 IN PROGRESS

---

## 🎯 PHASE 1: MANDATORY TASKS (1 hour) — DO FIRST

### ✅ Crashlytics User ID Verification (30 min)

- [ ] Found auth login file (`auth_gate.dart` or `neon_login_page.dart`)
- [ ] Located `FirebaseAuth.instance.signInWithEmailAndPassword(...)`
- [ ] Added `CrashlyticsService.instance.setUserId(uid)` after successful auth
- [ ] Compiled without errors: `flutter pub get && flutter build web`
- [ ] Tested: Threw intentional error on debug device
- [ ] Verified: Error appears in Firebase Crashlytics dashboard (wait 1 min)
- [ ] **STATUS:** ✅ COMPLETE or 🔴 NEED HELP?

### ✅ Firestore Security Rules Review (15 min)

- [ ] Located `firestore.rules` in project root
- [ ] Opened and reviewed rules (≤ 2 min scan)
- [ ] Verified: NOT `allow read,write;` (that's a security hole)
- [ ] Confirmed: Users can only read/write their own data
- [ ] Confirmed: Rooms enforce access control (users in room)
- [ ] Validated: `firebase deploy --only firestore:rules` shows no errors
- [ ] **STATUS:** ✅ COMPLETE or 🔴 NEED HELP?

### ✅ Smoke Test (15 min)

- [ ] Opened `https://mixvy.web.app` in Incognito window
- [ ] Signed up with new test email
- [ ] Created profile
- [ ] Created a test room
- [ ] Joined the room
- [ ] Sent a test message
- [ ] Left the room
- [ ] Opened Console (F12) — no red errors
- [ ] No 5xx network failures in Network tab
- [ ] Page load time < 3 seconds
- [ ] Checked Crashlytics dashboard — 0 new crashes
- [ ] **STATUS:** ✅ COMPLETE or 🔴 NEED HELP?

---

## 🚀 PHASE 2A: PATH B — CI/CD SETUP (17 min)

### Setup Steps

- [ ] **Step 1:** Opened terminal, ran `firebase login:ci`
  - [ ] Browser opened Firebase login
  - [ ] Signed in with Google account
  - [ ] Approved "Firebase CLI" access
  - [ ] Got token (40+ character string)
  - [ ] **SAVED TOKEN SOMEWHERE SAFE** ⚠️ Don't lose this

- [ ] **Step 2:** Added token to GitHub Secrets
  - [ ] Went to https://github.com/[REPO]/settings/secrets/actions
  - [ ] Clicked "New repository secret"
  - [ ] Name: `FIREBASE_TOKEN`
  - [ ] Value: Pasted token from Step 1
  - [ ] Clicked "Add secret"

- [ ] **Step 3:** Verified workflow file exists
  - [ ] File `.github/workflows/deploy-to-firebase.yml` exists ✅
  - [ ] Can see it in VS Code file explorer
  - [ ] Contains: `flutter build web --release` ✅
  - [ ] Contains: `firebase deploy` ✅

### Testing

- [ ] **Test #1:** Made test commit to main
  ```bash
  echo "# CI/CD Test" >> TEST.md
  git add TEST.md
  git commit -m "Test CI/CD"
  git push origin main
  ```

- [ ] **Test #2:** Watched GitHub Actions
  - [ ] Went to repo → Actions tab
  - [ ] Saw workflow "🚀 Deploy to Firebase Hosting" in progress
  - [ ] Watched all steps complete
  - [ ] Final step: ✅ Green checkmark

- [ ] **Test #3:** Verified deployment
  - [ ] Opened `https://mixvy.web.app`
  - [ ] Page loaded successfully
  - [ ] No 403/404 errors
  - [ ] Deployment timestamp is recent (last 5 minutes)

### Verification

- [ ] **Final Checks:**
  - [ ] GitHub Actions shows: ✅ Last run successful
  - [ ] Firebase Console Hosting shows: ✅ Latest deployment recent
  - [ ] `https://mixvy.web.app` loads: ✅ No errors
  - [ ] Can confirm: "PATH B is working"

- [ ] **STATUS:** ✅ COMPLETE or 🔴 NEED HELP?

---

## 🎨 PHASE 2B: PATH A — UX POLISH (2.5 hours)

### Dependency Setup (5 min)

- [ ] Added shimmer package:
  ```bash
  flutter pub add shimmer:2.0.0
  ```
- [ ] Ran `flutter pub get`
- [ ] No version conflicts
- [ ] No errors in pubspec.yaml

### File Creation (Already Done ✅)

- [ ] `lib/widgets/empty_states.dart` exists
  - [ ] 4 empty states: NoRooms, NoBuddies, NoMessages, NoParticipants
  - [ ] Each uses MixvyGoldButton + MIXVY brand colors

- [ ] `lib/widgets/skeleton_loaders.dart` exists
  - [ ] 6 skeleton types: RoomCard, Buddy, Message, Participant, etc.
  - [ ] Shimmer animations configured
  - [ ] Uses MIXVY color scheme

### Integration: Home Screen (30 min)

**File:** `lib/features/home/screens/home_screen.dart`

- [ ] Added imports:
  ```dart
  import 'package:mixvy/widgets/empty_states.dart';
  import 'package:mixvy/widgets/skeleton_loaders.dart';
  ```

- [ ] Updated loading state:
  ```dart
  loading: () => const RoomListSkeleton(),
  ```

- [ ] Updated empty data:
  ```dart
  if (rooms.isEmpty) {
    return EmptyStateNoRooms(
      onCreateRoom: () => context.push('/create-room'),
    );
  }
  ```

- [ ] Compiled without errors: `flutter pub get`
- [ ] **STATUS:** ✅ COMPLETE or 🔴 NEED HELP?

### Integration: Buddies Screen (20 min)

**File:** `lib/features/buddies/screens/buddies_screen.dart`

- [ ] Added imports
- [ ] Updated loading state to show `BuddyCardSkeleton` list
- [ ] Updated empty data to show `EmptyStateNoBuddies`
- [ ] Added `onAddBuddy` callback
- [ ] Compiled without errors
- [ ] **STATUS:** ✅ COMPLETE or 🔴 NEED HELP?

### Integration: Messages Screen (20 min)

**File:** `lib/features/messages/screens/messages_screen.dart`

- [ ] Added imports
- [ ] Updated loading state to show `MessageSkeleton` list
- [ ] Updated empty data to show `EmptyStateNoMessages`
- [ ] Compiled without errors
- [ ] **STATUS:** ✅ COMPLETE or 🔴 NEED HELP?

### Integration: Room Members Screen (20 min)

**File:** `lib/features/room/screens/room_members_screen.dart`

- [ ] Added imports
- [ ] Updated loading state to show `ParticipantSkeleton` list
- [ ] Updated empty data to show `EmptyStateNoParticipants`
- [ ] Compiled without errors
- [ ] **STATUS:** ✅ COMPLETE or 🔴 NEED HELP?

### Testing: Chrome (15 min)

```bash
flutter run -d chrome --profile
```

- [ ] App launched without errors
- [ ] Opened browser console (F12) — no red errors
- [ ] Navigated to Home screen:
  - [ ] No rooms showing = Empty state appears ✅
  - [ ] Empty state has CTA button ✅
  - [ ] Button works (clickable) ✅

- [ ] Navigated to Buddies screen:
  - [ ] No buddies = Empty state appears ✅
  - [ ] Skeleton loaders visible during load ✅
  - [ ] Animations smooth (not janky) ✅

- [ ] Navigated to Messages screen:
  - [ ] Empty state shows ✅
  - [ ] No console errors ✅

- [ ] Page load times: All < 3 seconds ✅
- [ ] **STATUS:** ✅ COMPLETE or 🔴 NEED HELP?

### Testing: Safari (15 min)

```bash
flutter run -d macos
# OR open in Safari on macOS
# OR visit https://localhost:7357 on same machine
```

- [ ] App loaded in Safari
- [ ] Console: No compatibility errors
- [ ] Empty states: Display correctly
- [ ] Skeleton animations: Smooth in Safari
- [ ] Colors: Render the same as Chrome
  - [ ] Gold (#D4AF37) = correct
  - [ ] Wine Red (#9B2535) = correct
  - [ ] Soft Cream (#F7EDE2) = correct
- [ ] Buttons: Tappable/clickable
- [ ] Layout: No unexpected breaks
- [ ] **STATUS:** ✅ COMPLETE or 🔴 NEED HELP?

---

## ✅ FINAL VERIFICATION (30 min)

### Quality Gate: All Checklist Items

**Mandatory Tasks:**
- [ ] Crashlytics user ID: ✅ VERIFIED
- [ ] Firestore rules: ✅ REVIEWED
- [ ] Smoke test: ✅ PASSED

**PATH B (CI/CD):**
- [ ] GitHub Actions: ✅ WORKING
- [ ] Auto-deploy: ✅ TESTED
- [ ] Firebase Hosting: ✅ LIVE

**PATH A (UX):**
- [ ] Empty states: ✅ SHOWING
- [ ] Skeleton loaders: ✅ ANIMATING
- [ ] Chrome: ✅ PERFECT
- [ ] Safari: ✅ COMPATIBLE

---

## 📊 PROGRESS TRACKER

| Phase | Task | Time | Start | End | Status |
|-------|------|------|-------|-----|--------|
| **Phase 1** | Mandatory | 1h | — | — | 🔴 TODO |
| Phase 1.1 | Crashlytics | 30m | — | — | 🔴 TODO |
| Phase 1.2 | Firestore | 15m | — | — | 🔴 TODO |
| Phase 1.3 | Smoke test | 15m | — | — | 🔴 TODO |
| **Phase 2A** | PATH B | 17m | — | — | 🔴 TODO |
| Phase 2A.1 | Gen token | 5m | — | — | 🔴 TODO |
| Phase 2A.2 | Add secret | 2m | — | — | 🔴 TODO |
| Phase 2A.3 | Test deploy | 10m | — | — | 🔴 TODO |
| **Phase 2B** | PATH A | 2.5h | — | — | 🔴 TODO |
| Phase 2B.1 | Add shimmer | 5m | — | — | 🔴 TODO |
| Phase 2B.2 | Home screen | 30m | — | — | 🔴 TODO |
| Phase 2B.3 | Buddies | 20m | — | — | 🔴 TODO |
| Phase 2B.4 | Messages | 20m | — | — | 🔴 TODO |
| Phase 2B.5 | Room members | 20m | — | — | 🔴 TODO |
| Phase 2B.6 | Chrome test | 15m | — | — | 🔴 TODO |
| Phase 2B.7 | Safari test | 15m | — | — | 🔴 TODO |
| **Verification** | Final check | 30m | — | — | 🔴 TODO |
| **TOTAL** | All tasks | 4h | — | — | 🔴 TODO |

---

## 🚨 BLOCKERS & HELP

### If Stuck, Check Here

| Blocker | Document | Time to Fix |
|---------|----------|------------|
| "Don't know where auth flow is" | [PATH_A_IMPLEMENTATION.md](PATH_A_IMPLEMENTATION.md#step-2-empty-states--where--how-to-use) | 5 min |
| "Firebase token won't generate" | [PATH_B_IMPLEMENTATION.md](PATH_B_IMPLEMENTATION.md#troubleshooting) | 10 min |
| "Empty states not showing" | [PATH_A_IMPLEMENTATION.md](PATH_A_IMPLEMENTATION.md#-troubleshooting) | 10 min |
| "Skeleton loaders too slow" | [PATH_A_IMPLEMENTATION.md](PATH_A_IMPLEMENTATION.md#-troubleshooting) | 5 min |
| "Safari looks broken" | [PATH_A_IMPLEMENTATION.md](PATH_A_IMPLEMENTATION.md#-troubleshooting) | 15 min |

### Need Help?

Reply with:
- ✅ "Checkpoint [number] complete"
- ❌ "[Phase] stuck on [issue]"
- 🤔 "Question about [file/step]"

---

## 🎯 SUCCESS = All ✅

```
Mandatory Tasks      ✅ ✅ ✅
PATH B (CI/CD)       ✅ ✅ ✅ ✅
PATH A (UX)          ✅ ✅ ✅ ✅ ✅ ✅ ✅
Final Verification   ✅ ✅ ✅

= LAUNCH READY 🚀
```

---

**Current Status:** 🔴 Not started
**Updated:** Check in as you complete each phase
**Target Completion:** Today 5:00 PM
**Next: Tomorrow 9:00 AM — Final go-live prep**

🚀 **LET'S GO!**
