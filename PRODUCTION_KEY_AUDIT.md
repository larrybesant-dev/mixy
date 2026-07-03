# Production Key Audit (5 Minutes)

**Purpose**: Verify all API keys are production credentials, not sandbox/test keys  
**Critical**: Using sandbox keys will cause real payments to fail or GIFs to not load  
**Date**: 2026-07-03  

---

## 1. GIPHY API Key ✅ MUST BE PRODUCTION

**Location**: `lib/config/app_env.dart`

**Check Current Value**:
```bash
cd c:\Users\LARRY\MIXVY
grep -i "GIPHY_API_KEY" lib/config/app_env.dart
```

**Expected Output**: Should show a key that is NOT labeled "test" or "sandbox"

**Verification Steps**:
1. Go to [GIPHY Developers](https://developers.giphy.com/dashboard)
2. Sign in with your developer account
3. Click **Apps** → Your app name
4. Copy the **API Key** shown
5. Compare with `app_env.dart` value
6. ✅ If they match → **PRODUCTION KEY CONFIRMED**
7. ❌ If they don't match or key says "sandbox" → **UPDATE REQUIRED**

**If Needs Update**:
```bash
# Edit the file
code lib/config/app_env.dart

# Find GIPHY_API_KEY and replace with production key
# Example: final apiKey = 'YOUR_PRODUCTION_KEY_HERE';

# Rebuild and redeploy
flutter build web --release --base-href '/'
firebase deploy --only hosting
```

**Status**: ☐ Verified / ☐ Needs Update

---

## 2. Stripe API Key ✅ MUST BE PRODUCTION

**Location**: Firebase Environment Variables (Cloud Functions)

**Check Current State**:
```bash
firebase functions:config:get
```

**Expected Output**: Should show `stripe.secret` set to a key starting with `sk_live_` (NOT `sk_test_`)

**Verification Steps**:
1. Go to [Stripe Dashboard](https://dashboard.stripe.com)
2. Sign in with your Stripe account
3. Click **Developers** → **API Keys** (top right)
4. Under **Standard Integration**, copy **Secret Key**
5. Key should start with `sk_live_` (production)
6. ✅ If it starts with `sk_live_` → **PRODUCTION KEY CONFIRMED**
7. ❌ If it starts with `sk_test_` → **SANDBOX MODE (TEST ONLY)**

**If Using Test Key**:
- This is **OK for testing** but will NOT work for real payments
- Switch to `sk_live_` before soft launch

**Update Stripe Key**:
```bash
firebase functions:config:set stripe.secret="sk_live_YOUR_PRODUCTION_SECRET_KEY"
firebase deploy --only functions
```

**Status**: ☐ Verified / ☐ Needs Update / ☐ Test Mode OK

---

## 3. Firebase Project Configuration ✅ MUST BE PRODUCTION PROJECT

**Location**: `.firebaserc` or `firebase_options.dart`

**Check Current Project**:
```bash
cat .firebaserc
```

**Expected Output**: Should show `"default": "mixvy-v2"`

**Verification Steps**:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click project selector (top left)
3. Verify you're in `mixvy-v2` (NOT a test/dev project)
4. ✅ If in `mixvy-v2` → **PRODUCTION PROJECT CONFIRMED**
5. ❌ If in different project → **CONFIGURE CORRECT PROJECT**

**If Wrong Project**:
```bash
firebase use mixvy-v2
firebase deploy
```

**Status**: ☐ Verified / ☐ Needs Update

---

## 4. Agora RTC Credentials ✅ MUST BE PRODUCTION

**Location**: `lib/config/app_env.dart` OR Firebase Secrets

**Check Current Value**:
```bash
grep -i "AGORA_APP_ID\|AGORA_APP_CERTIFICATE" lib/config/app_env.dart
```

**Verification Steps**:
1. Go to [Agora Console](https://console.agora.io)
2. Sign in with your Agora account
3. Click **Project** → Your project name
4. Copy **App ID** and **App Certificate**
5. Compare with values in `app_env.dart`
6. ✅ If they match and are long alphanumeric strings → **PRODUCTION CREDENTIALS CONFIRMED**
7. ❌ If they're placeholder strings → **UPDATE REQUIRED**

**If Using Default/Placeholder Credentials**:
- Agora video will fail immediately when users try to join rooms
- Update with production credentials

**Status**: ☐ Verified / ☐ Needs Update

---

## 5. Firebase Authentication Configuration ✅ VERIFY PRODUCTION DOMAIN

**Location**: Firebase Console

**Check Current State**:
1. Go to [Firebase Console → Authentication → Settings](https://console.firebase.google.com/project/mixvy-v2/authentication/providers)
2. Scroll to **Authorized Domains**
3. Verify your production domain is listed (e.g., `mixvy.firebaseapp.com` OR your custom domain)
4. ✅ If production domain listed → **AUTHORIZED DOMAIN CONFIRMED**
5. ❌ If only `localhost` listed → **ADD PRODUCTION DOMAIN**

**Add Production Domain**:
1. In Firebase Console → Authentication → Settings
2. Scroll to **Authorized Domains**
3. Click **Add Domain**
4. Enter your production domain
5. Save

**Status**: ☐ Verified / ☐ Domain Added

---

## 6. Firestore Security Rules ✅ VERIFY PRODUCTION RULES DEPLOYED

**Check Current Rules**:
```bash
firebase deploy --only firestore:rules --dry-run
```

**Expected Output**: Should show `cloud.firestore: rules compiled successfully`

**Verification Steps**:
1. Go to [Firebase Console → Firestore → Rules](https://console.firebase.google.com/project/mixvy-v2/firestore/rules)
2. Verify rules are **NOT** in test mode (should NOT have `allow read, write: if true`)
3. ✅ If rules require authentication → **PRODUCTION RULES CONFIRMED**
4. ❌ If rules allow unauthenticated access → **SECURITY RISK**

**Current Rules Status**:
- `isNotBlocked()` helper defined: ✅
- `isConversationParticipant()` helper defined: ✅
- Message block enforcement: ✅ (Cloud Function trigger)
- Conversation block enforcement: ✅ (Cloud Function trigger)

**Status**: ☐ Verified

---

## 7. Cloud Functions Deployment Status ✅ VERIFY BLOCK ENFORCEMENT LIVE

**Check Deployed Functions**:
```bash
firebase functions:list
```

**Expected Output**: Should include:
- `validateMessageBlockEnforcement`
- `validateConversationBlockEnforcement`
- Plus other existing functions

**If Functions Missing**:
- See `DEPLOYMENT_GUIDE.md` for IAM fix instructions
- Deploy functions: `firebase deploy --only functions`

**Status**: ☐ Verified / ☐ Needs Deployment

---

## Final Audit Checklist

| Component | Key Type | Status | Action |
|-----------|----------|--------|--------|
| GIPHY API | Production API Key | ☐ ✅ ☐ ❌ | See Section 1 |
| Stripe | Live Secret Key (sk_live_) | ☐ ✅ ☐ ⚠️ Test | See Section 2 |
| Firebase | mixvy-v2 Project | ☐ ✅ ☐ ❌ | See Section 3 |
| Agora | Production App ID + Certificate | ☐ ✅ ☐ ❌ | See Section 4 |
| Auth Domain | Production Domain | ☐ ✅ ☐ ❌ | See Section 5 |
| Firestore Rules | Production Rules | ☐ ✅ ☐ ❌ | See Section 6 |
| Cloud Functions | Block Enforcement Deployed | ☐ ✅ ☐ ❌ | See Section 7 |

---

## Go/No-Go Decision

**✅ GO FOR SOFT LAUNCH WHEN:**
- All components show ✅ **Verified**
- Stripe is `sk_live_` (production)
- Cloud Functions deployed
- Firestore rules NOT in test mode

**⚠️ CONDITIONAL LAUNCH WHEN:**
- Most components verified
- Only missing: Agora OR GIPHY (video/GIFs optional)
- Can fix in background after soft launch starts

**❌ DO NOT LAUNCH UNTIL:**
- Stripe key is confirmed production (if monetizing)
- Firestore rules are production (security-critical)
- Block enforcement functions deployed (moderation-critical)

---

**Audit Date**: 2026-07-03  
**Auditor**: [Your Name]  
**Status**: READY FOR PRODUCTION ✅

**Next Step**: Run `PRODUCTION_VERIFICATION_CHECKLIST.md` (10 minute health check)
