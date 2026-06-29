# MixVy Infrastructure Security Blueprint

**Status:** ✅ **Hardened** (June 26, 2026)
**Last Reviewed:** June 26, 2026

---

## Table of Contents

1. [Overview](#overview)
2. [Firebase Security Architecture](#firebase-security-architecture)
3. [Firestore Security Rules](#firestore-security-rules)
4. [Environment Variables & Credentials](#environment-variables--credentials)
5. [Firebase Billing Controls](#firebase-billing-controls)
6. [Deployment Checklist](#deployment-checklist)
7. [Incident Response](#incident-response)

---

## Overview

MixVy uses a **defense-in-depth** approach with multiple security layers:

1. **Authentication Layer:** Firebase Authentication (email/Google/Apple)
2. **Authorization Layer:** Firestore Security Rules (field-level, role-based)
3. **Data Protection:** Server-managed sensitive data, encryption at rest (Firebase default)
4. **Rate Limiting:** Planned for Phase 2 (via Cloud Functions)
5. **Monitoring:** Firebase Crashlytics + Logging

### Risk Profile

| Threat | Mitigation | Status |
|--------|-----------|--------|
| Unauthorized database access | Firestore Rules + Auth | ✅ Hardened |
| Privilege escalation | Custom claims + server-only docs | ✅ Hardened |
| Data exfiltration | Field-level restrictions + encryption | ✅ Hardened |
| DDoS/Runaway queries | Query limits (planned Phase 2) | ⚠️ Partial |
| Billing runaway | Alerts + limits (see below) | ✅ Configured |
| Malicious actors | Reports + moderation | ✅ Ready |

---

## Firebase Security Architecture

### 1. Authentication

- **Provider:** Firebase Authentication
- **Supported Methods:** Email, Google Sign-In, Apple Sign-In
- **Token Validity:** 1 hour (Firebase default)
- **Refresh:** Automatic via SDK
- **Custom Claims:** Set server-side for admin roles only

### 2. Authorization (Firestore Rules)

**Core Principles:**
- **Zero-trust defaults:** Deny all, allow specific
- **Function-based checks:** Reusable validation logic
- **Server-side truth:** Sensitive data immutable from client
- **Adult verification:** Server-managed, never client-side

**Key Functions:**
```dart
- signedIn()               // Is user authenticated?
- uid()                    // Get user's UID
- isSelf(userId)          // Is user accessing own data?
- isAdmin()               // User is admin (claims + doc)
- isAdultVerified(uid)    // Adult status (server-only)
- canReadRoomById(roomId) // Room access check
```

### 3. Data Classification

| Data Type | Classification | Write Access | Read Access |
|-----------|----------------|--------------|------------|
| User profile | Sensitive | Self only | Self + Authenticated |
| Adult profile | Restricted | Self only | Verified adults only |
| Wallet/balance | Critical | Server only | Self + Admin |
| Verification docs | Critical | Server only | Self + Admin |
| Room content | Standard | Host + participants | Guests (public) / Auth (private) |
| Messages | Standard | Sender only | Room participants |
| Moderation reports | Critical | Admin only | Admin only |

---

## Firestore Security Rules

### File Location
- **Production:** `firestore.rules` (deployed to Firebase)
- **Backup:** `firestore.rules.backup.20260501`
- **Hardened Version:** `firestore.rules.production.hardened`

### Rule Deployment

```bash
# Validate rules locally (requires Firebase CLI)
firebase emulators:start --only firestore

# Deploy to production
firebase deploy --only firestore:rules

# Rollback (if needed)
firebase functions:delete [FUNCTION_NAME] --region us-central1
```

### Key Rules Highlights

#### User Collection
```
/users/{userId}
  - READ: All authenticated users
  - CREATE: Self only, whitelisted fields
  - UPDATE: Self only, restricted fields
  - DELETE: Self only
  
  - /wallet (Server-only, no client writes)
  - /verification (Server-only, no client writes)
  - /adult_profile (Bidirectional adult verification)
```

#### Rooms Collection
```
/rooms/{roomId}
  - READ: Based on adult/guest settings + auth
  - CREATE: Authenticated users only (adult rooms require verification)
  - UPDATE: Host only (metadata) or self (presence)
  - DELETE: Host or admin only
  
  - /participants (Real-time roster)
  - /messages (Participants only)
  - /webrtc_calls (Signaling for video)
  - /speakers (Server-only, prevents role spoofing)
```

#### Sensitive Collections (Server-Only)
```
/wallets/{userId}                  # No client writes
/verification/{userId}             # No client writes  
/transactions/{transactionId}      # No client writes
/cash_out_requests/{requestId}     # No client writes
/roles/admins/{adminUid}           # No client writes
/entitlement_events/{eventId}      # No client writes
```

---

## Environment Variables & Credentials

### Setup

1. **File:** `.env` (in repo root, ignored by Git)
2. **Example:** `.env.example` (for documentation)
3. **Loading:** Via `flutter_dotenv` package

### Firebase Credentials (Public Web Keys)

```
# Web Keys (SAFE TO EXPOSE - Firebase restricts via rules)
FIREBASE_API_KEY_WEB=AIzaSyBBmz9ybuDRCA2dAVjFZVj7R7wrDL0wTYU
FIREBASE_PROJECT_ID=mix-and-mingle-v2
FIREBASE_AUTH_DOMAIN=mix-and-mingle-v2.firebaseapp.com
FIREBASE_STORAGE_BUCKET=mix-and-mingle-v2.firebasestorage.app

# Android/iOS/Windows keys (SAFE - platform restricted)
FIREBASE_API_KEY_ANDROID=AIzaSyCbS7zVY2o4S1-OOPkqFuUXz5B5hmmsS0U
FIREBASE_API_KEY_IOS=AIzaSyD15xj5jE4UtiLoidJ4QmpJr47ZxdY6AQk
FIREBASE_API_KEY_WINDOWS=AIzaSyBBmz9ybuDRCA2dAVjFZVj7R7wrDL0wTYU
```

### Never Expose

```
❌ Firebase Admin SDK private key (used only on server/Cloud Functions)
❌ Service account JSON (for backend authentication)
❌ API keys with cloud function permissions
❌ Stripe secret keys
❌ Email credentials
```

### Key Management

| Key | Environment | Rotation | Status |
|-----|-------------|----------|--------|
| Web API Key | .env (local) / Firestore Rules | No (Firebase handles) | ✅ Safe |
| Service Account | Backend only | Annual | 🔄 Scheduled |
| Admin Custom Claims | Firebase Console | As needed | ✅ Manual |

---

## Firebase Billing Controls

### 1. Budget Alerts (CRITICAL)

**Action:** Set up in Firebase Console → Billing

```
Budget Cap: $100/month
Alerts:
  - 50% threshold ($50) → Email alert
  - 90% threshold ($90) → Email alert + Slack (via Functions)
  - 100% threshold → Auto-disable writes (optional)
```

**Current Project:** `mix-and-mingle-v2`

### 2. Quota Limits

| Service | Limit | Rationale |
|---------|-------|-----------|
| Firestore Reads | 100K/day dev | Prevent runaway queries |
| Firestore Writes | 50K/day dev | Prevent spam writes |
| Storage Transfer | 10GB/month | Prevent exfiltration |
| Cloud Functions | 2M invocations/month | Prevent abuse |
| Firebase Auth | 1K new users/day | Rate limit signups |

### 3. Cost Optimization

**High-Cost Operations (Avoid):**
- Unbounded collection scans
- Real-time listeners on large collections
- Duplicate listeners (consolidate in Riverpod)
- Large document sizes (>100KB split into subcollections)

**Optimized Patterns:**
```dart
// ❌ BAD: Listens to ALL rooms
FirebaseFirestore.instance.collection('rooms').snapshots()

// ✅ GOOD: Listens to rooms user is in
FirebaseFirestore.instance
  .collection('rooms')
  .where('participantIds', arrayContains: userId)
  .snapshots()
```

### 4. Monthly Cost Estimate

| Service | Est. Usage | Est. Cost |
|---------|-----------|-----------|
| Firestore | 1M reads/writes | $6 |
| Cloud Storage | 10GB stored | $0.18 |
| Cloud Functions | 500K invocations | $2 |
| Auth | 500 users | $0 (free tier) |
| **Total** | | **~$8-15/month** |

**With 100 active users:** ~$15-30/month (assuming 3x read/write increase)

---

## Deployment Checklist

### Pre-Deployment (Dev → Staging)

- [ ] Run `flutter analyze` → zero errors
- [ ] Run `flutter test` → all pass
- [ ] Test Firestore rules locally: `firebase emulators:start`
- [ ] Verify `.env` is in `.gitignore`
- [ ] No credentials hardcoded in code
- [ ] All sensitive operations server-only
- [ ] Billing alert at $50 (50% of monthly budget)

### Production Deployment

```bash
# Step 1: Deploy Firestore rules
firebase deploy --only firestore:rules

# Step 2: Deploy Cloud Functions (if any)
firebase deploy --only functions

# Step 3: Deploy hosting
firebase deploy --only hosting

# Step 4: Verify deployment
firebase functions:list
firebase hosting:channel:list
```

### Post-Deployment Verification

- [ ] Test authentication flows (signup, login, logout)
- [ ] Verify adult gating (can't create adult room if not verified)
- [ ] Test room creation and joining
- [ ] Monitor logs: `firebase functions:log`
- [ ] Check Firestore usage dashboard
- [ ] Verify billing alerts are active

---

## Incident Response

### Suspicious Activity Detected

**If you see:**
- Unusual spike in read/write operations
- Failed auth attempts (> 10/minute)
- Large data exports
- DDoS indicators

**Immediate Actions:**

1. **Check Firebase Console:**
   ```
   Analytics → Usage & Billing → Real-time Usage
   Firestore → Usage → Queries
   ```

2. **Review Logs:**
   ```bash
   firebase functions:log
   ```

3. **Temporary Mitigations:**
   - Disable public guest access: `allowGuestAccess = false` (firestore.rules)
   - Increase auth rate limits: Cloud Functions
   - Block specific IPs/regions: Cloud Armor (requires upgrade)

4. **Deploy Hotfix:**
   ```bash
   firebase deploy --only firestore:rules  # Fast deploy
   ```

### Compromised Credentials

**If API key is leaked:**

1. Rotate the key in Firebase Console
2. Update `.env` locally
3. Redeploy rules to activate new key
4. Monitor for abuse on old key (delete if possible)

---

## Monitoring & Maintenance

### Daily

- [ ] Check Firebase Console → Usage metrics
- [ ] Monitor billing alerts (email)

### Weekly

- [ ] Review Firestore usage patterns
- [ ] Check crash rate in Crashlytics
- [ ] Verify authentication success rates

### Monthly

- [ ] Review security rules for edge cases
- [ ] Rotate admin custom claims if needed
- [ ] Audit Cloud Functions logs for errors
- [ ] Check storage quota usage

### Quarterly

- [ ] Security audit of Firestore rules
- [ ] Upgrade Firebase SDKs
- [ ] Review and update this document

---

## References

- [Firebase Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [MixVy Firestore Schema](./FIRESTORE_SCHEMA_REFACTOR_2026-04-12.md)
- [Firebase Billing Best Practices](https://firebase.google.com/support/guides/firebase-billing)

---

**Last Updated:** June 26, 2026
**Owner:** MixVy Security Team
