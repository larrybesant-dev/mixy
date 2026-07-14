# Authentication Flow & AppCheck Configuration

## Overview

This document outlines the MixVy authentication flow, AppCheck configuration, and how the reCAPTCHA v3 domain whitelist fix resolved the production room entry blocking issue.

## Problem Summary (Fixed)

### Issue
All users were blocked from entering live rooms with error:
```
AppCheck: ReCAPTCHA error (appCheck/recaptcha-error)
HTTP 400 net::ERR_ABORTED
```

### Root Cause
The app was configured to use an **old, unregistered reCAPTCHA v3 site key** whose domains were NOT whitelisted in Google's reCAPTCHA admin console, while the **correct key had proper domain registration**. This caused:

1. Firebase Auth's reCAPTCHA validation (independent from AppCheck) to attempt validation with the old key
2. Google API rejects requests from unregistered domains with 400 error
3. reCAPTCHA validation fails → AppCheck token generation fails → Firestore access denied → Room join blocked

### Why It Wasn't Caught Earlier
- The `window.__FIREBASE_DISABLE_APP_CHECK_ON_WEB = true` flag masked the issue in development
- Production deployment with AppCheck enabled exposed the misconfiguration
- reCAPTCHA configuration is separate from Firebase Authorized Domains (both must be correct)

## Solution Implemented

### Changes Made

#### 1. **lib/main.dart** (Lines 57-71)
Updated AppCheck initialization to use the correct reCAPTCHA v3 site key:

```dart
if (!kIsWeb) {
  // Android: Use Play Integrity provider
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: AndroidPlayIntegrityProvider(),
    );
  } catch (e) {
    debugPrint('[Firebase] App Check activation error on Android: $e');
  }
} else {
  // Web: Use reCAPTCHA v3 with CORRECT site key
  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaV3Provider('6LcxpForAAAAAIxMxD7uQ1Nnb8MgPqZtN9urp68f'),
    );
    debugPrint('[Firebase] App Check activated on web (reCAPTCHA v3)');
  } catch (e) {
    debugPrint('[Firebase] App Check activation error on web: $e');
  }
}
```

**Old (broken) key**: `6LfzB7cqAAAAABuHkIWz0rV0bHEaVMODQ5rj5TvU` (domains NOT whitelisted)
**New (correct) key**: `6LcxpForAAAAAIxMxD7uQ1Nnb8MgPqZtN9urp68f` (domains whitelisted)

#### 2. **web/index.html** (Line 85-88)
Removed the AppCheck disable flag and enabled AppCheck enforcement:

```html
<!-- BEFORE: AppCheck was disabled (masked the issue in development) -->
<!-- <script>window.__FIREBASE_DISABLE_APP_CHECK_ON_WEB = true;</script> -->

<!-- AFTER: AppCheck enabled with reCAPTCHA v3 -->
<!-- AppCheck uses reCAPTCHA v3 for token generation and validation -->
```

#### 3. **web/firebase-messaging-sw.js** (Line 1-4)
Removed service worker AppCheck disable flag to mirror main app configuration.

#### 4. **Firebase Console - App Check → reCAPTCHA v3 Provider**
Registered reCAPTCHA v3 provider with whitelisted domains:
- ✓ `mixvy-v2.web.app`
- ✓ `www.djmixandmingle.com`

**Status**: ✓ Registered (domains properly whitelisted)

## Authentication Architecture

### Flow Diagram

```
User Input (Email/Password)
        ↓
Firebase Auth.createUserWithEmailAndPassword()
        ↓
[reCAPTCHA Validation] ← This is where the 400 error was occurring
        ↓
[AppCheck Token Generation] ← Uses reCAPTCHA v3 provider
        ↓
Firestore Security Rules Check
        ↓
[Firestore Write]
        ↓
User Document Created
        ↓
Navigation to Home Screen
```

### Key Insight
**reCAPTCHA validation is independent from AppCheck.** Both are security layers:
- **reCAPTCHA v3**: Bot detection (happens at Firebase Auth level)
- **AppCheck**: Ensures requests are from legitimate app (happens at Firestore level)

The domain whitelist in Google reCAPTCHA Console must match your app's deployment domain(s).

## Testing

### 1. Automated Integration Tests

Run the comprehensive auth + AppCheck integration test:

```bash
# Test with Firebase emulators (local):
flutter test integration_test/auth_appcheck_integration_test.dart \
  --dart-define=RUN_FIREBASE_EMULATOR_TESTS=true

# Test against production Firebase (with AppCheck validation):
flutter test integration_test/auth_appcheck_integration_test.dart
```

**Test Coverage**:
- ✓ Sign up flow with AppCheck token generation
- ✓ Sign in with valid credentials
- ✓ Firestore access with AppCheck validation
- ✓ User session state management
- ✓ Error handling for invalid inputs
- ✓ Multiple concurrent user registrations
- ✓ AppCheck 400 error detection

### 2. Manual Testing (Production)

Visit https://mixvy-v2.web.app/auth and:

1. **Check Network Tab** (DevTools → Network):
   - Look for requests to `identitytoolkit.googleapis.com` (Firebase Auth)
   - Confirm NO 400 responses
   - Look for AppCheck token in request headers

2. **Sign Up Flow**:
   - Enter email: `testuser-<timestamp>@mixvy.app`
   - Enter password: `TestPassword123!`
   - Verify successful navigation to home screen
   - Check browser console for "✓ AppCheck activated on web (reCAPTCHA v3)"

3. **Verify AppCheck Tokens**:
   - Right-click → Inspect → Console
   - Firebase SDK logs should show AppCheck initialization
   - No `recaptcha-error` messages

### 3. Create Test Accounts (Admin SDK)

```bash
# Create test user via Firebase CLI
firebase auth:create-user --email test@mixvy.app --password Test@12345!

# Or use the admin-create-test-account.js script:
cd functions
node scripts/admin-create-test-account.js
```

## Deployment Checklist

Before deploying AppCheck changes:

- [ ] Verify reCAPTCHA v3 site key is correct in code
- [ ] Confirm domains are whitelisted in Google reCAPTCHA Console
- [ ] Remove AppCheck disable flags from web entry points
- [ ] Test locally with Firebase emulators
- [ ] Run integration tests: `flutter test integration_test/auth_appcheck_integration_test.dart`
- [ ] Test in staging environment first
- [ ] Deploy to production
- [ ] Monitor Firebase Console for AppCheck failures
- [ ] Verify production users can authenticate without 400 errors

## Troubleshooting

### 400 Error During Authentication
**Cause**: reCAPTCHA site key is not whitelisted for the current domain

**Solution**:
1. Check current domain in browser: `window.location.origin`
2. Go to https://www.google.com/recaptcha/admin/
3. Find the site key being used
4. Verify the domain is in the whitelist
5. Add domain if missing
6. Wait ~5 minutes for Google to propagate changes
7. Rebuild and redeploy the app

### AppCheck Token Not Sent with Requests
**Cause**: AppCheck is disabled or initialization failed

**Solution**:
1. Check browser console: Look for "App Check activated on web"
2. Ensure `window.__FIREBASE_DISABLE_APP_CHECK_ON_WEB` is NOT set to true
3. Verify reCAPTCHA script loads successfully
4. Check Firebase console App Check dashboard for provider status

### Missing Domain in reCAPTCHA Whitelist
**Cause**: App was deployed to a new domain

**Solution**:
1. Identify new domain
2. Go to Google reCAPTCHA Console
3. Add domain to whitelist for the appropriate site key
4. Note: Different site keys must be used for different domains
5. Update app code with correct key for the domain
6. Redeploy

## Firebase Console Configuration

### Location 1: reCAPTCHA v3 Site Key Management
**URL**: https://www.google.com/recaptcha/admin/

Check: Domains whitelisted for site key `6LcxpForAAAAAIxMxD7uQ1Nnb8MgPqZtN9urp68f`:
- ✓ `mixvy-v2.web.app`
- ✓ `www.djmixandmingle.com`

### Location 2: Firebase App Check Provider Configuration
**URL**: https://console.firebase.google.com/project/mix-and-mingle-v2/appcheck/products

- **Provider**: reCAPTCHA v3
- **Status**: ✓ Registered
- **Site Key**: `6LcxpForAAAAAIxMxD7uQ1Nnb8MgPqZtN9urp68f`

### Location 3: Firestore Security Rules
**File**: `firestore.rules`

```dart
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null && hasValidAppCheck();
    }
  }
  
  function hasValidAppCheck() {
    // Soft-launch phase: returns true for all authenticated users
    // Will be fully enforced in production phase
    return true;
  }
}
```

**Note**: AppCheck validation is currently soft-launched (permissive). Full enforcement requires:
1. All clients updated and deployed
2. No critical device versions without AppCheck support
3. Monitoring dashboard shows healthy enforcement rates

## Related Documentation

- **Firebase AppCheck Setup**: https://firebase.google.com/docs/app-check/web/app-check-web
- **reCAPTCHA v3 Configuration**: https://developers.google.com/recaptcha/docs/v3
- **Firebase Authentication**: https://firebase.google.com/docs/auth/web/start
- **Firestore Security Rules**: https://firebase.google.com/docs/firestore/security/start

## Summary of Key Points

1. **The Fix**: Updated reCAPTCHA v3 site key and whitelisted deployment domains
2. **Why It Matters**: AppCheck + Auth security validation requires proper reCAPTCHA configuration
3. **Prevention**: Integration tests now validate AppCheck flow for future regressions
4. **Testing**: Run `flutter test integration_test/auth_appcheck_integration_test.dart` to verify
5. **Monitoring**: Watch Firebase Console App Check dashboard for validation failures

---

**Last Updated**: 2026-07-14  
**Status**: ✓ Fixed and Deployed  
**Verification**: Integration tests passing, production users can authenticate without AppCheck errors
