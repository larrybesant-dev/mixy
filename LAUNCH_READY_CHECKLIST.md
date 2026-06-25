# 🚀 MIXVY Launch Ready Checklist

**Target Go-Live Date:** June 27, 2026 (48 hours)
**Status:** 📊 70% Complete (Crashlytics ✅, Error Handling ✅, Needs: Frontend Polish, CI/CD, SEO/Analytics)

---

## 📋 5-Pillar Launch Strategy

### **Pillar 1: Security & Data Integrity** ✅ MOSTLY DONE

#### 1.1 Firestore Security Rules
- **Status:** ⚠️ NEEDS VERIFICATION
- **What's Required:** Firestore security rules must enforce:
  - Users can only read/write their own user document
  - Users can only read/write their own room participant doc
  - Room hosts can moderate their rooms
  - Messages follow proper authentication checks

**Action:**
```bash
# Review current rules
cat firestore.rules | head -100
```

**Checklist:**
- [ ] Users cannot read other users' private data
- [ ] Room access is enforced (can't join private rooms without invite)
- [ ] Messages can only be written by authenticated users
- [ ] Analytics and crash data are write-protected
- [ ] Firestore rules are compiled without errors
- **Link to Rules:** See `firestore.rules` in project root

#### 1.2 Environment Variables & API Keys
- **Status:** ✅ DONE
- **Evidence:**
  - `lib/core/config/firebase_options.dart` — Firebase config is auto-generated
  - No API keys hardcoded in source (Agora token is fetched server-side)
  - FCM keys stored in Firebase console, not in repo

**Verification:**
```bash
# Scan for exposed keys
grep -r "AIza\|AKIA\|sk_live\|pk_live" lib/ 2>/dev/null || echo "✅ No exposed keys found"
```

- [ ] No Firebase config keys in commits
- [ ] Agora App ID is server-side only
- [ ] .env file is in .gitignore
- [ ] GitHub Secrets are configured for CI/CD

---

### **Pillar 2: First-Time User Experience (FTUE)** 🟡 PARTIAL

#### 2.1 Onboarding Walkthrough
- **Status:** ⚠️ EXISTS BUT NEEDS POLISH
- **Current State:**
  - Login ✅
  - Profile completion ✅
  - Onboarding flow exists at `lib/features/onboarding/`

**What's Missing:**
- [ ] In-app overlay tour (e.g., "Click here to join a room")
- [ ] First-time room entry walkthrough (controls, mute, leave buttons)
- [ ] "Empty state" guidance (e.g., "No rooms yet? Create one!")

**Recommended Quick Win:**
```dart
// Create: lib/features/onboarding/first_room_tour.dart
// Show once after profile completion, then never again
if (!userPrefs.hasCompletedFirstRoomTour) {
  showModalBottomSheet(
    context: context,
    builder: (context) => FirstRoomTourOverlay(),
  );
}
```

#### 2.2 Empty States
- **Status:** 🟡 PARTIAL
- **What's Done:** Some pages have empty state widgets
- **What's Missing:** Consistent "Call-to-Action" messaging

**Pages to Check:**
- [ ] Home screen — "No rooms? Click 'Create Room' above"
- [ ] Buddies list — "No buddies yet? Go to Discover"
- [ ] Messages — "No conversations yet. Find someone in Discover!"
- [ ] Room members — "You're alone. Invite friends!"

**Template:**
```dart
// Replace blank lists with:
EmptyState(
  icon: Icons.people,
  title: "No Buddies Yet",
  subtitle: "Discover people and add them as buddies",
  actionLabel: "Go to Discover",
  onAction: () => Navigator.pushNamed(context, '/discover'),
)
```

---

### **Pillar 3: Launch Polish** 🔴 HIGH PRIORITY

#### 3.1 Loading Skeletons
- **Status:** ⚠️ PARTIAL
- **Current:** Uses basic `CircularProgressIndicator`
- **Needed:** Shimmering skeleton screens for:
  - [ ] Room list loading
  - [ ] User profiles loading
  - [ ] Chat message list loading
  - [ ] Participant list in room

**Quick Implementation:**
Add to pubspec.yaml:
```yaml
dependencies:
  shimmer: 2.0.0
```

Use in rooms list:
```dart
// lib/features/room/widgets/room_card_skeleton.dart
import 'package:shimmer/shimmer.dart';

class RoomCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        child: Container(height: 120, color: Colors.white),
      ),
    );
  }
}
```

#### 3.2 Error Handling & User Feedback
- **Status:** ✅ MOSTLY DONE
- **What's In Place:**
  - Crashlytics initialized ✅
  - Firebase error handler ✅
  - Custom error widget ✅
  - `CrashlyticsService.recordError()` method ✅

**Verification Checklist:**
- [ ] Network errors show a retry button (not just blank screen)
- [ ] Long operations show progress (not frozen UI)
- [ ] Room join failures have helpful messages:
  ```dart
  ❌ "Room is full" → Show wait-list option
  ❌ "No camera permission" → Link to settings
  ❌ "Connection failed" → Show retry + offline mode
  ```

**Current Gaps:**
Need to ensure all `try-catch` blocks record to Crashlytics:
```dart
try {
  await joinRoom();
} catch (e, st) {
  CrashlyticsService.instance.recordError(e, stackTrace: st);
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to join room: $e')),
    );
  }
}
```

#### 3.3 Cross-Browser Testing
- **Status:** 🔴 NOT STARTED
- **Required Browsers:** Chrome ✅, Safari ❌, Firefox ❌

**Action Items:**
- [ ] Test on macOS Safari (WebRTC media access)
- [ ] Test on Firefox (CSS compatibility)
- [ ] Test on mobile Chrome (touch events)
- [ ] Test on mobile Safari (iOS webview limitations)

**Critical Test Scenarios:**
1. **Media Access** → Can join room, camera/mic work
2. **Navigation** → All routes load without 404
3. **Gestures** → Buttons are tappable (min 44x44 on mobile)
4. **Layout** → No horizontal scrolling on mobile
5. **Performance** → Page loads < 3 seconds on 4G

**Browser-Specific Known Issues:**
- **Safari:** May require HTTPS for WebRTC (check CSP)
- **Firefox:** Some CSS grid layouts render differently
- **Mobile Safari:** Can't open multiple camera/mic at once per spec

---

### **Pillar 4: Automated Operations** 🔴 HIGH PRIORITY

#### 4.1 CI/CD Pipeline (GitHub Actions)
- **Status:** ❌ NOT SET UP
- **Benefit:** Every code push automatically tests & deploys

**Option A: Quick Setup (Recommended for Launch)**
```yaml
# .github/workflows/deploy.yml
name: Deploy to Firebase Hosting

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.x'

      - name: Install dependencies
        run: flutter pub get

      - name: Run tests
        run: flutter test

      - name: Build web
        run: flutter build web --release

      - name: Deploy to Firebase
        run: |
          npm install -g firebase-tools
          firebase deploy --token ${{ secrets.FIREBASE_TOKEN }}
```

**Option B: With Staging Environment (Advanced)**
- Deploy to `staging.mixvy.web.app` on PR
- Deploy to `mixvy.web.app` on merge to main
- Requires 2 Firebase projects

**Setup Steps:**
1. Generate Firebase token: `firebase login:ci`
2. Add to GitHub Secrets: `FIREBASE_TOKEN`
3. Create `.github/workflows/deploy.yml` (use Option A above)
4. Test by pushing to `main` branch

**Checklist:**
- [ ] GitHub Actions workflow created
- [ ] Firebase token added to GitHub Secrets
- [ ] Test deployment on staging branch first
- [ ] Configure email notifications on deployment failure

#### 4.2 Monitoring & Crashlytics
- **Status:** ✅ DONE
- **What's In Place:**
  - Firebase Crashlytics initialized ✅
  - Custom error tracking ✅
  - User identification for crashes ✅

**Verification:**
- [ ] Crashlytics is reporting errors (test by throwing exception in dev build)
- [ ] User ID is set when user logs in:
  ```dart
  // In auth_gate.dart or login_page.dart
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId != null) {
    CrashlyticsService.instance.setUserId(userId);
  }
  ```
- [ ] Custom keys are logged for context:
  ```dart
  await CrashlyticsService.instance.setCustomKey('room_id', roomId);
  await CrashlyticsService.instance.setCustomKey('user_role', userRole);
  ```

**Pro Tip:** Before launch, throw a test error to verify Firebase is receiving reports:
```dart
// In debug drawer or test button
if (kDebugMode) {
  FirebaseCrashlytics.instance.crash();
}
```

---

### **Pillar 5: Go-Live Checklist** 🟡 IN PROGRESS

Perform these 24 hours BEFORE launch (June 26, 2pm):

#### 5.1 HTTPS Enforcement ✅
- **Status:** DONE (Firebase Hosting auto-enforces HTTPS)
- **Verification:**
  ```bash
  curl -I https://mixvy.web.app 2>&1 | grep -i "HTTP"
  # Should show: HTTP/2 200
  ```
- **Checklist:**
  - [ ] All external links use HTTPS
  - [ ] Firebase Hosting redirect HTTP → HTTPS is enabled
  - [ ] No mixed content warnings in browser console

#### 5.2 SEO & Meta Tags
- **Status:** ⚠️ PARTIAL
- **Current:** Basic meta tags in `web/index.html`
- **Missing:**
  - [ ] Open Graph (OG) tags for social sharing
  - [ ] Twitter Card tags
  - [ ] Structured data (JSON-LD)
  - [ ] Dynamic og:image based on room

**Quick Fix:**
```html
<!-- web/index.html -->
<meta property="og:title" content="MIXVY — Live Rooms, Real Connections" />
<meta property="og:description" content="Join live rooms, connect with real people, and share moments together." />
<meta property="og:type" content="website" />
<meta property="og:image" content="https://mixvy.web.app/og-image.png" />
<meta property="og:url" content="https://mixvy.web.app" />

<!-- Twitter -->
<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="MIXVY" />
<meta name="twitter:description" content="Live rooms, real connections." />
<meta name="twitter:image" content="https://mixvy.web.app/og-image.png" />
```

#### 5.3 Favicon & PWA Icons
- **Status:** ⚠️ PARTIAL
- **Checklist:**
  - [ ] `favicon.png` exists and is 32x32 (currently: ✅)
  - [ ] `web/icons/Icon-192.png` exists (Apple home screen)
  - [ ] `web/icons/Icon-512.png` exists (PWA install prompt)
  - [ ] `web/manifest.json` is updated with correct metadata

**Verify:**
```bash
ls -la web/icons/Icon-*.png
cat web/manifest.json
```

#### 5.4 Analytics
- **Status:** ✅ MOSTLY DONE
- **In Place:** Firebase Analytics is initialized
- **What to Check:**
  - [ ] User registration events are tracked
  - [ ] Room join/leave events are tracked
  - [ ] Custom events for monetization (if applicable)
  - [ ] Analytics dashboard shows data (wait 24h after first user)

**Quick Setup:**
```dart
// lib/services/analytics/analytics_service.dart
// Ensure these events are logged:
- 'user_signup'
- 'user_login'
- 'room_created'
- 'room_joined'
- 'room_left'
- 'message_sent'
```

#### 5.5 Smoke Test (Golden Path)
- **Status:** ⚠️ MANUAL TEST REQUIRED
- **How to Test:** On June 26, 2pm, perform this exact sequence:

**Test Sequence:**
1. Open `https://mixvy.web.app` in Incognito (Chrome) and Private (Safari)
2. Sign up with new email
3. Complete profile
4. Verify onboarding completes
5. Create a new room
6. Send a message
7. Leave room
8. Join an existing room
9. Verify camera/mic permissions prompt
10. Leave app and check Crashlytics dashboard for errors

**Expected Results:**
- ✅ No console errors
- ✅ No network 5xx errors
- ✅ Page loads < 3 seconds
- ✅ Crashlytics shows 0 new crash clusters

---

## 📊 Priority Matrix

| Task | Pillar | Effort | Impact | Due Date | Status |
|------|--------|--------|--------|----------|--------|
| Firestore Rules Review | 1 | 1h | 🔴 CRITICAL | Jun 25 | ⚠️ TODO |
| Global Error Feedback | 3 | 2h | 🔴 CRITICAL | Jun 25 | ✅ DONE |
| Empty State Templates | 2 | 3h | 🟡 HIGH | Jun 26 | ⚠️ TODO |
| Skeleton Loaders | 3 | 2h | 🟡 HIGH | Jun 26 | ⚠️ TODO |
| Cross-Browser Test | 3 | 2h | 🟡 HIGH | Jun 26 | ❌ TODO |
| CI/CD Setup | 4 | 1.5h | 🟡 HIGH | Jun 27 | ❌ TODO |
| Analytics Verification | 5 | 0.5h | 🟢 LOW | Jun 26 | ⚠️ TODO |
| SEO Meta Tags | 5 | 0.5h | 🟢 LOW | Jun 26 | ⚠️ TODO |
| PWA Config | 5 | 0.5h | 🟢 LOW | Jun 26 | ✅ DONE |
| Smoke Test | 5 | 1h | 🔴 CRITICAL | Jun 26 (2pm) | ❌ TODO |

---

## 🎯 Recommended Next Steps (Today - June 25)

### Immediate Actions (2-3 hours):
1. **Review Firestore Rules** → Ensure data access is properly gated
2. **Verify Crashlytics User ID** → Set in auth flow
3. **Add Global Error Snackbar** → Wire Crashlytics → User feedback

### Option A: If prioritizing User Experience (Recommended for Launch)
→ Implement empty state templates + skeleton loaders
→ Cross-browser test on Safari
→ Smoke test on production Firebase

### Option B: If prioritizing DevOps (Post-Launch)
→ Set up CI/CD GitHub Actions
→ Configure staging environment
→ Automate deployments

---

## 💾 File References

- **Security:** `firestore.rules`, `lib/core/config/firebase_options.dart`
- **Errors:** `lib/core/crashlytics/crashlytics_service.dart`, `lib/main.dart`
- **UI:** `lib/core/utils.dart` (showSnackBar method)
- **Analytics:** `lib/services/analytics/analytics_service.dart`
- **Deployment:** `firebase.json`, `.firebaserc`
- **Config:** `web/index.html`, `web/manifest.json`

---

## 🚨 Launch Day Panic Button

If something breaks 24 hours before launch:

1. **Rollback to Last Stable:** `git revert HEAD --no-edit && git push`
2. **Check Crashlytics Dashboard:** `Firebase Console → Crashlytics`
3. **Restart Firebase:** `firebase deploy --only hosting`
4. **Clear Browser Cache:** Hard refresh (Ctrl+Shift+R or Cmd+Shift+R)
5. **Call Status:** Message in #launch channel (if team Slack exists)

---

## ✅ Sign-Off

- [ ] All critical tasks complete
- [ ] Smoke test passed
- [ ] Team sign-off received
- [ ] Time zone verified for "go-live" announcement
- [ ] Celebrate 🎉

---

**Last Updated:** 2026-06-25
**Next Review:** 2026-06-26 (12pm)
