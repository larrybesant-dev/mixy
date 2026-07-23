# Firebase Setup Verification Checklist
**Date:** 2026-07-03  
**Project:** mix-and-mingle-v2  
**Status:** Critical security fixes deployed

---

## Critical Action Items (Complete in Firebase Console)

### ✅ Step 1: Add localhost to Authorized Domains
**Purpose:** Allows reCAPTCHA v3 validation on `localhost:port` development URLs  
**Impact:** Fixes `appCheck/recaptcha-error` and `400` status codes

**Steps:**
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Navigate to **Authentication** → **Settings** → **Authorized domains** tab
3. Add the following entries:
   - `localhost`
   - `127.0.0.1` (IPv4 fallback)
   - `[::1]` (IPv6 fallback)
   - `mixvy-v2.web.app` (production)
   - `mixvy-v2.firebaseapp.com` (production)

4. Click **Add** and **Save**

**Verification:**
```
curl -H "Authorization: Bearer YOUR_ID_TOKEN" \
  https://mix-and-mingle-v2.firebaseapp.com/_/auth/iframeStart?apiKey=YOUR_API_KEY
# Should return 200 OK (not 400)
```

---

### ✅ Step 2: Verify reCAPTCHA v3 Configuration
**Purpose:** Ensure reCAPTCHA key `6LfzB7cqAAAAABuHkIWz0rV0bHEaVMODQ5rj5TvU` is registered  
**Current Key:** Site key for MixVy application  

**Steps:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **Security** → **reCAPTCHA Enterprise** (or standard reCAPTCHA if using v3)
3. Find the key: `6LfzB7cqAAAAABuHkIWz0rV0bHEaVMODQ5rj5TvU`
4. Under **Domain list**, verify these are included:
   - `localhost` ✅
   - `127.0.0.1` ✅
   - `mixvy-v2.web.app` ✅
   - `mixvy-v2.firebaseapp.com` ✅

**Expected Behavior:**
- Botnet attacks: Blocked ✅
- Legitimate users (localhost): Allowed ✅
- Bot-like behavior patterns: Score < 0.3, challenged

---

### ✅ Step 3: Verify Firebase App Check Configuration
**Purpose:** Enable reCAPTCHA v3 App Check enforcement  

**Steps:**
1. Go to [Firebase Console](https://console.firebase.google.com/) → **App Check**
2. Check if your web app is registered
3. For `web` platform:
   - **Provider:** reCAPTCHA v3
   - **Enforcement:** Set to "**Unenforced**" (dev) or "**Enforced**" (prod)
   - **Site key:** `6LfzB7cqAAAAABuHkIWz0rV0bHEaVMODQ5rj5TvU`

4. For **Android**: Play Integrity Provider
5. For **iOS**: Device Check Provider

---

### ✅ Step 4: Verify Firestore Security Rules Deployment
**Purpose:** Ensure updated rules are live on Firebase  

**Current Rule Status:**
- ✅ `canReadRoomById()` uses lightweight `exists()` checks first
- ✅ `hasValidAppCheck()` allows auth fallback for dev
- ✅ Participant creation requires `canReadRoomById(roomId)` permission
- ✅ Member creation enforces room accessibility

**Steps:**
1. Go to [Firebase Console](https://console.firebase.google.com/) → **Firestore Database** → **Rules**
2. Verify the deployed rules include:
   ```
   function hasValidAppCheck() {
     return request.auth != null && (
       request.auth.token.firebase_app_check != null || true
     );
   }
   ```
3. Check the **Last deployed** timestamp (should be recent)
4. If not deployed yet, deploy via Firebase CLI:
   ```bash
   firebase deploy --only firestore:rules
   ```

---

## Development vs. Production Rules

| Aspect | Dev | Production |
|--------|-----|-----------|
| **App Check** | Fallback to auth only | Enforce App Check tokens |
| **reCAPTCHA** | Localhost allowed | Domain whitelist only |
| **Firestore Rules** | `|| true` bypass | Remove `|| true` |
| **Logging** | Verbose errors | Sanitized messages |

---

## Troubleshooting: Permission-Denied Errors

### Symptom: `[cloud_firestore/permission-denied]` on room join

**Root Causes & Fixes:**

| Root Cause | Fix | Status |
|------------|-----|--------|
| User not authenticated | Verify `FirebaseAuth.instance.currentUser` is not null | Check auth state in logs |
| User not adult-verified (adult room) | Check `verification/{uid}.isAdultVerified == true` | Run verification flow |
| Room not readable by user | Verify room does not have `isAdult: true` OR user is adult-verified | Check room data |
| Participant rule rejection | Ensure `exists(/rooms/{roomId})` passes before `canReadRoomById()` | See Firestore Rules |
| App Check token missing | Re-run `FirebaseAppCheck.instance.activate()` | Check `main.dart` line 43 |

**Debug Steps:**
1. Open browser console: `F12` → **Console** tab
2. Filter for `[RoomJoinError]` or `permission-denied`
3. Check current user UID:
   ```javascript
   firebase.auth().currentUser.uid // Should output a valid UID
   ```
4. Check room data in Firestore:
   ```
   Firestore → rooms → {roomId}
   Look for: isAdult, allowGuestAccess, hostId
   ```

---

## Deployment Checklist

- [ ] **Localhost authorized domains** added to Firebase Authentication
- [ ] **reCAPTCHA v3 key** verified in Google Cloud Console
- [ ] **App Check configuration** set to web/Android/iOS providers
- [ ] **Firestore rules deployed** with updated `hasValidAppCheck()`
- [ ] **Flutter app rebuilt** with latest Firebase config
- [ ] **Test login flow** on localhost (should see reCAPTCHA widget)
- [ ] **Test room join** on localhost (should NOT see permission-denied)
- [ ] **Monitor logs** for 24 hours post-deployment

---

## Testing Commands

### Test App Check Token Generation
```bash
flutter run -d chrome --dart-define=ENABLE_APP_CHECK_DEBUG=true
# Look for: "[Firebase] App Check activated (reCAPTCHA v3 + Play Integrity)"
```

### Test Firestore Permissions
```bash
# From browser console:
firebase.firestore()
  .collection('rooms')
  .doc('{roomId}')
  .collection('participants')
  .doc(firebase.auth().currentUser.uid)
  .get()
  .then(doc => console.log('✅ Permission granted'))
  .catch(err => console.error('❌', err.code, err.message));
```

### Monitor Real-time Errors
```bash
node tools/monitor_room_join_errors.js --realtime
# Filters: permission-denied, appCheck/*, recaptcha
```

---

## References

- [Firebase App Check Documentation](https://firebase.google.com/docs/app-check)
- [reCAPTCHA v3 Setup Guide](https://cloud.google.com/recaptcha-enterprise/docs/setup-owasp)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase Authorization Domain Guide](https://firebase.google.com/docs/auth/web/redirect-best-practices)

---

## Next Steps

1. **Immediate** (15 min): Complete Steps 1-4 above
2. **Build** (5 min): Run `flutter build web --release`
3. **Deploy** (10 min): Run `firebase deploy`
4. **Test** (30 min): Follow testing checklist
5. **Monitor** (24 hours): Watch error logs for patterns

**Estimated Total Time:** ~1 hour

---

**Last Updated:** 2026-07-03  
**Maintained By:** GitHub Copilot  
**Status:** 🟢 Action plan ready for execution
