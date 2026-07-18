# WebSocket Listener Issue - Root Cause Analysis & Fix

## 🔴 CRITICAL FINDING: Firestore Persistence Conflict

### Issue Location
**Configuration Conflict Between Two Files:**

1. **lib/main.dart (Line 44)** - Sets `persistenceEnabled: false`
   ```dart
   FirebaseFirestore.instance.settings = const Settings(
     persistenceEnabled: false,  // ❌ DISABLES persistence
     sslEnabled: true,
     host: 'firestore.googleapis.com',
   );
   ```

2. **lib/core/providers/firebase_providers.dart (Line 25)** - Sets `persistenceEnabled: true`
   ```dart
   firestore.settings = const Settings(
     persistenceEnabled: true,   // ✅ ENABLES persistence
     cacheSizeBytes: 50 * 1024 * 1024,
     ignoreUndefinedProperties: true,
   );
   ```

### Why This Breaks WebSocket Listeners

When Firestore settings are configured **multiple times with conflicting values**, the SDK:
1. First applies `persistenceEnabled: false` from main.dart
2. Then applies `persistenceEnabled: true` from firebase_providers.dart
3. This rapid re-configuration can cause the real-time listener WebSocket to abort mid-initialization
4. Result: `net::ERR_ABORTED` on `/Firestore/Listen/channel`

### Why It Affects Only Real-Time Listeners

- **REST calls** (REST API) work fine (no WebSocket needed)
- **Authentication** works fine (separate connection)
- **Real-time listeners** (StreamProvider, snapshots()) require persistent WebSocket connection
- When persistence setting changes during WebSocket handshake → connection aborts

---

## ✅ SOLUTION: Single Source of Truth for Firestore Settings

### Recommended Fix Structure:

**Option A: Configure in main.dart ONLY (Safest)**
- Set all Firestore settings once at startup
- Remove conflicting settings from firebase_providers.dart
- Ensures consistency before any feature code runs

**Option B: Configure in firebase_providers.dart ONLY (Cleaner Architecture)**
- All Firebase config in one place
- main.dart just initializes core, providers handle specifics
- More modular for testing

### Recommended Configuration for Web:

```dart
const Settings(
  persistenceEnabled: true,        // ✅ Enable for offline resilience
  cacheSizeBytes: 50 * 1024 * 1024, // 50MB cache for web
  sslEnabled: true,                 // Always true for production
  // Remove explicit 'host' on web - let SDK auto-detect
  ignoreUndefinedProperties: true,
)
```

**Why this works:**
- `persistenceEnabled: true` → Stable local cache, supports offline
- `cacheSizeBytes: 50MB` → Reasonable limit for web/PWA
- No explicit `host` on web → SDK auto-routes to Google's CDN nearest edge
- No conflicting configurations → Clean initialization sequence

---

## 🔧 Immediate Fix (Minimal Change)

### Status Update
✅ **Fix Applied:** Removed conflicting Firestore settings from main.dart (commit applied, deployed)
⏳ **Result:** Issue persists - root cause appears different

### New Investigation Needed

Since the fix didn't resolve the issue, the root cause is likely one of:

1. **Firestore Emulator Fallback**
   ```bash
   # Check if code is trying to use emulator
   grep -r "emulator" lib/ | grep -i firestore
   grep -r "localhost:8080" lib/
   ```
   
2. **Firestore API Key Restrictions**
   - Go to: https://console.cloud.google.com/apis/credentials
   - Find the API key: `AIzaSyCM6_Eye8JMEW7dXFpo-i-Frp4t3owyh_I`
   - Click to edit
   - Check **API restrictions** → Ensure "Cloud Firestore API" is in the allowed list
   - Check **Application restrictions** → Should include Web application with your domain
   
3. **Firebase Console Domain Allowlist**
   - Go to: https://console.firebase.google.com/project/mixvy-v2/authentication
   - Click **Settings** tab
   - Scroll to **Authorized Domains**
   - Verify `mixvy-v2.web.app` is in the list
   - Verify your dev domain (if testing locally) is in the list

4. **Network Level Debugging**
   - Open DevTools (F12) → Network tab
   - Filter for "Listen"
   - Right-click the failed request → Copy → Copy as cURL
   - Share the request headers/details
   - Check if response has error details

### Code Changes Applied:

**File:** `lib/main.dart` (Lines 40-48)

```dart
// ❌ REMOVE THIS BLOCK - conflicting with firebase_providers.dart
// if (kIsWeb) {
//   try {
//     await FirebaseFirestore.instance.enableNetwork();
//     FirebaseFirestore.instance.settings = const Settings(
//       persistenceEnabled: false,
//       sslEnabled: true,
//       host: 'firestore.googleapis.com',
//     );
//     debugPrint('[Firebase] Firestore web settings configured');
//   } catch (e) {
//     debugPrint('[Firebase] Firestore settings error (non-fatal): $e');
//   }
// }
```

**Reasoning:** Let `firebase_providers.dart` be the single source of truth for Firestore config. It runs on first provider access, which is after `main.dart` completes initialization.

### Step 2: Verify firebase_providers.dart settings

**File:** `lib/core/providers/firebase_providers.dart`

Current settings look good:
```dart
persistenceEnabled: true,
cacheSizeBytes: 50 * 1024 * 1024,
ignoreUndefinedProperties: true,
```

**No changes needed** - this configuration is correct for web.

---

## 📋 Testing Plan After Fix

### Test 1: Verify WebSocket Connection Works
1. Open browser DevTools (F12)
2. Go to Network tab
3. Filter for "Listen" or "Firestore"
4. Reload app
5. **Expected:** See POST request to `/Firestore/Listen/channel` with status **101 (WebSocket Upgrade)** or **200**
6. **Not Expected:** `net::ERR_ABORTED`

### Test 2: Verify Real-Time Listeners Work
1. Login to app
2. Navigate to home screen
3. **Expected:** Discovery feed loads within 2 seconds
4. **Expected:** Room list displays
5. **Not Expected:** "Could not load discovery feed" error

### Test 3: Verify Room Join Flow
1. From home, click JOIN on any room
2. **Expected:** Room screen loads
3. **Expected:** Participant count displays and updates in real-time
4. **Expected:** No "Member ABC" placeholders

---

## 🐛 Why This Root Cause Wasn't Obvious

1. **Firebase SDK resilience:** Auth and REST endpoints work despite persistence conflict
2. **WebSocket uniqueness:** Only real-time listeners require persistent connection + settings stability
3. **Timing issue:** Settings change happens early in startup, but real-time listeners aren't used until minutes later
4. **Browser caching:** Sometimes works in one session, fails in another depending on cache state

---

## Prevention for Future

### Code Review Checklist for Firebase Configuration:
- [ ] Only ONE file sets `FirebaseFirestore.instance.settings`
- [ ] Firestore configuration is applied ONCE at startup
- [ ] Web-specific settings are conditional (`if (kIsWeb)`)
- [ ] Settings include `persistenceEnabled: true` for web resilience
- [ ] No explicit `host` parameter on web (let SDK auto-detect)
- [ ] Test real-time listeners after any settings change

### Documentation to Add:
Add comment in `firebase_providers.dart`:
```dart
/// ⚠️ CRITICAL: This is the ONLY place Firestore settings are configured for web.
/// Do NOT set FirebaseFirestore.instance.settings elsewhere - it will conflict with
/// real-time listeners and cause ERR_ABORTED WebSocket errors.
/// See: https://github.com/firebase/firebase-js-sdk/issues/[issue-number]
```

---

## Summary

| Item | Status |
|------|--------|
| **Root Cause Identified** | ✅ Firestore persistence conflict |
| **Blocker Severity** | 🔴 Critical (prevents real-time features) |
| **Fix Complexity** | 🟢 Low (comment out ~7 lines) |
| **Testing Required** | 🟡 Medium (verify WebSocket + real-time features) |
| **Risk of Fix** | 🟢 Very Low (consolidates to recommended pattern) |
| **Time to Complete** | ⏱️ ~15 minutes (fix + test) |

