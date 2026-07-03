# Fix reCAPTCHA Domain Whitelisting - Production Issue

**Status:** 🔴 **BLOCKING PRODUCTION**  
**Root Cause:** Domain `mixvy-v2.web.app` not whitelisted in reCAPTCHA settings  
**Evidence:** Console error: `appCheck/recaptcha-error` with 400 status code

---

## 🔍 What's Happening

```
Browser Console Shows:
❌ Error while retrieving App Check token: FirebaseError: AppCheck: ReCAPTCHA error
❌ POST request to https://www.google.com/recaptcha/api2/clr failed: "net::ERR_ABORTED"
❌ Error joining room: [cloud_firestore/permission-denied] Missing or insufficient permissions
```

**Flow:**
1. User tries to join room on `mixvy-v2.web.app`
2. App tries to generate reCAPTCHA v3 token
3. Google rejects the request (domain not whitelisted)
4. App Check token generation fails (400 error)
5. Firestore request fails (permission-denied) because no App Check token

---

## ✅ Fix: Add Domain to reCAPTCHA Whitelist

### Step 1: Sign Into Google Cloud Console

1. Open: https://console.cloud.google.com
2. Sign in with your Google account
3. Select project: **mix-and-mingle-v2**

### Step 2: Navigate to reCAPTCHA Settings

1. Go to: **Security → reCAPTCHA Enterprise** (or **reCAPTCHA Admin Console** if on legacy)
2. Find your reCAPTCHA key: `6LfzB7cqAAAAABuHkIWz0rV0bHEaVMODQ5rj5TvU`
3. Click to edit the key

### Step 3: Add Production Domain

In the **Domains** section:

```
Current domains (add to these):
✅ localhost
✅ 127.0.0.1
❌ mixvy-v2.web.app  ← ADD THIS

Steps:
1. Click "+ Add Domain"
2. Enter: mixvy-v2.web.app
3. Click "Add"
4. Save changes
```

### Step 4: Verify Configuration

After adding domain, verify in console:

```
reCAPTCHA Settings:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Display Name: MixVy Web App
Keys: 
  - Public Key: 6LfzB7cqAAAAABuHkIWz0rV0bHEaVMODQ5rj5TvU
  - Secret Key: 6LfzB7cqA...
Platforms: 
  ✅ Web
Domains:
  ✅ localhost
  ✅ 127.0.0.1
  ✅ mixvy-v2.web.app  ← NEWLY ADDED
Allowed URLs: 
  ✅ https://mixvy-v2.web.app/*
```

### Step 5: Clear Browser Cache & Test

```bash
1. Close browser tab: https://mixvy-v2.web.app
2. Hard refresh (Ctrl+Shift+R) or clear cache
3. Reload: https://mixvy-v2.web.app
4. Try joining a room
5. Should see: No more "appCheck/recaptcha-error"
```

---

## 🧪 Verification After Fix

### Check 1: Browser Console (F12)
```javascript
// Should NOT see:
❌ "appCheck/recaptcha-error"
❌ "POST request to https://www.google.com/recaptcha/api2/clr failed"

// Should see:
✅ "[Firebase] App Check activated"
✅ App Check token generation successful
```

### Check 2: Room Join Test
```
1. Navigate to: https://mixvy-v2.web.app
2. Try joining a room
3. Expected: No red error bar at bottom
4. Expected: Participant doc created in Firestore
```

### Check 3: Firebase Console Logs
```
1. Open: https://console.firebase.google.com/project/mixvy-v2/logging
2. Filter: severity >= ERROR
3. Expected: 0 "permission-denied" errors
4. Expected: 0 "appCheck/recaptcha-error" errors
```

---

## 🔄 Alt Fix: Disable App Check Temporarily (If Urgent)

If you cannot access Google Cloud Console immediately, temporarily disable App Check:

**File:** `lib/main.dart` (Lines 43-60)

```dart
// DISABLE App Check temporarily
if (false && kIsWeb) {  // Add false &&
  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaV3Provider('6LfzB7cqAAAAABuHkIWz0rV0bHEaVMODQ5rj5TvU'),
  );
} else {
  debugPrint('[Firebase] App Check disabled (dev mode)');
}

// Also update firestore.rules (Lines 96-104)
function hasValidAppCheck() {
  return request.auth != null;  // Remove " || true" fallback
}
```

Then redeploy:
```bash
flutter build web --release --base-href '/'
firebase deploy --only hosting
firebase deploy --only firestore:rules
```

**⚠️ WARNING:** This disables reCAPTCHA protection! Only use as temporary fix while configuring domain whitelist.

---

## 📚 Reference Links

| Resource | URL |
|----------|-----|
| Google Cloud Console | https://console.cloud.google.com |
| reCAPTCHA Admin | https://console.cloud.google.com/security/recaptcha |
| Firebase Project | https://console.firebase.google.com/project/mixvy-v2 |
| reCAPTCHA Key Config | https://cloud.google.com/recaptcha-enterprise/docs/verify-domains |

---

## 🎯 Expected Timeline

- **Domain Whitelist Update:** ~1 minute
- **Browser Cache Clear:** ~30 seconds
- **Propagation to Google:** Usually immediate, max 5 minutes
- **App Check Token Generation:** Should work on next request

**Total Time to Fix:** ~5 minutes

---

## ❓ If It Still Doesn't Work

1. **Check Key is Correct**
   - Verify public key matches: `6LfzB7cqAAAAABuHkIWz0rV0bHEaVMODQ5rj5TvU`
   - Check Firebase Console → App Check → reCAPTCHA v3 config

2. **Verify Domain Format**
   - Add without `https://` or trailing slash
   - Correct: `mixvy-v2.web.app`
   - Wrong: `https://mixvy-v2.web.app/`

3. **Check reCAPTCHA Version**
   - Your key is v3 (site key visible in public)
   - Verify settings are for v3, not v2

4. **Review Firestore Rules**
   - Ensure `hasValidAppCheck()` includes fallback for dev
   - Current rule: `|| true` (allows without token in dev)

5. **Contact Firebase Support**
   - If domain whitelisting doesn't work after 15 minutes
   - Provide reCAPTCHA key: `6LfzB7cqAAAAABuHkIWz0rV0bHEaVMODQ5rj5TvU`

---

## 📝 Notes

- **Emulator tests passed** because they don't use real reCAPTCHA
- **Production fails** because real reCAPTCHA validates domain whitelist
- **This is by design** - Google restricts API keys to authorized domains only
- **Once fixed**, domain will work permanently for all future deployments

---

**Action Required:** Update reCAPTCHA domain whitelist in Google Cloud Console  
**Urgency:** HIGH - Blocks all room join operations  
**Expected Difficulty:** Low - Single configuration change
