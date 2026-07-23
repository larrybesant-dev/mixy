# Firestore Schema Refactor — Production Blueprint
**Date:** 2026-04-12  
**Owner:** Architecture  
**Status:** Design Phase (Ready for Implementation)

---

## Overview

Move from monolithic `users/<uid>` document to **domain-separated subcollection model** to eliminate rule conflicts, prevent cross-writes, and enable clean security boundaries.

---

## Final Clean Domain Model

```
users/<uid>
├── profile_public/
├── wallet/
├── preferences/
├── profile_private/ (optional, future)
├── verification/
├── security/
├── adult_content/ (existing structure, kept)
└── (core identity fields only)
```

---

## Domain Definitions

### 1. `users/<uid>` — Core Identity (Immutable-ish)

**Purpose:** Authentication + basic profile identity  
**Write Authority:** Client (self-update) + Cloud Functions (bootstrap)  
**Immutability:** High (changes indicate data corruption)

**Fields:**
```
{
  "id": uid,
  "email": string,
  "username": string,
  "usernameLower": string,
  "avatarUrl": string (nullable),
  "coverPhotoUrl": string (nullable),
  "bio": string,
  "isPrivate": bool,
  "followers": array<uid>,
  "following": array<uid>,
  "updatedAt": timestamp,
  "createdAt": timestamp (immutable)
}
```

**Write Rule:**
```
- Create: isSelf(userId) && (!membershipLevel || membershipLevel == 'basic')
- Update: isSelf(userId) && only_identity_fields_allowed
- Delete: isSelf(userId)
```

**Allowed update fields:**
```
username, usernameLower, email, bio, isPrivate, updatedAt
```

---

### 2. `users/<uid>/profile_public` — Social Profile Data

**Purpose:** User-visible social metadata  
**Write Authority:** Client (self-update)  
**Immutability:** Low (cosmetic fields)

**Fields:**
```
{
  "age": int (nullable),
  "gender": string (nullable),
  "location": string (nullable),
  "relationshipStatus": string (nullable),
  "vibePrompt": string (nullable),
  "firstDatePrompt": string (nullable),
  "musicTastePrompt": string (nullable),
  "interests": array<string>,
  "profileAccentColor": string (nullable),
  "galleryUrls": array<string>,
  "introVideoUrl": string (nullable),
  "updatedAt": timestamp
}
```

**Write Rule:**
```
- Create: isSelf(userId)
- Update: isSelf(userId) && only_profile_public_fields_allowed
- Delete: false (maintain history)
```

---

### 3. `users/<uid>/wallet` — Economy/Transactional

**Purpose:** Currency, streaks, rewards  
**Write Authority:** Cloud Functions (transactions/claims) + Client (nil)  
**Immutability:** Very High (financial data)

**Fields:**
```
{
  "balance": int,
  "coinBalance": int,
  "lastCheckinDate": timestamp (nullable),
  "checkinStreak": int,
  "totalCoinsClaimed": int,
  "transactionLog": array<{date, amount, type}> (optional),
  "updatedAt": timestamp
}
```

**Write Rule:**
```
- Create: Server only (admin or Cloud Function)
- Update: Server only (Cloud Functions for claim, payment, transfers)
- Delete: false
```

**Note:** Client never writes directly. All mutations go through Cloud Functions.

---

### 4. `users/<uid>/preferences` — Client UI/UX State

**Purpose:** User settings, theme, cosmetic preferences  
**Write Authority:** Client (self-update)  
**Immutability:** Low (user-driven changes)

**Fields:**
```
{
  "themeId": string (nullable),
  "backgroundColor": string (nullable),
  "profileMusicUrl": string (nullable),
  "profileMusicTitle": string (nullable),
  "profileBgGradientStart": string (nullable),
  "profileBgGradientEnd": string (nullable),
  "camViewPolicy": string (nullable: 'public' | 'friends' | 'private'),
  "updatedAt": timestamp
}
```

**Write Rule:**
```
- Create: isSelf(userId)
- Update: isSelf(userId) && only_preferences_fields_allowed
- Delete: false
```

---

### 5. `users/<uid>/verification` — Verification State (NEW)

**Purpose:** Account verification status + metadata  
**Write Authority:** Cloud Functions (admin tools) + Server  
**Immutability:** Very High (security-sensitive)

**Fields:**
```
{
  "status": enum ('unverified' | 'pending' | 'verified' | 'rejected'),
  "method": string (nullable: 'selfie' | 'id' | 'other'),
  "verifiedAt": timestamp (nullable),
  "verifiedBy": uid (nullable, admin who verified),
  "rejectionReason": string (nullable),
  "updatedAt": timestamp
}
```

**Write Rule:**
```
- Create: Server only (Cloud Function)
- Update: Server only (Cloud Functions, admin tools)
- Delete: false (audit trail)
```

**Key:** Client cannot write this. Ever. Verification flows must go through backend API endpoints.

---

### 6. `users/<uid>/security` — Auth/Security State (NEW)

**Purpose:** Login state, risk flags, session metadata  
**Write Authority:** Cloud Functions (auth service)  
**Immutability:** Very High (security-sensitive)

**Fields:**
```
{
  "lastLoginAt": timestamp,
  "lastLoginIp": string (nullable),
  "emailVerified": bool,
  "phoneVerified": bool,
  "mfaEnabled": bool,
  "riskFlags": array<string>, // (e.g., "suspicious_login_attempt")
  "failedLoginCount": int,
  "lockedUntil": timestamp (nullable),
  "updatedAt": timestamp
}
```

**Write Rule:**
```
- Create: Server only (Cloud Function on user creation)
- Update: Server only (auth service, security monitoring)
- Delete: false
```

---

### 7. `users/<uid>/adult_content` — Adult Profile (KEEP EXISTING)

**Purpose:** Age-gated profile data  
**Write Authority:** Client (self-update)  
**Immutability:** Medium (user-driven, privacy-sensitive)

**Existing structure maintained.** No changes in this refactor phase.

---

## Write Authority Summary

| Domain | Client | Cloud Functions | Admin |
|--------|--------|-----------------|-------|
| Core Identity | ✅ Self-update | ✅ Bootstrap | ❌ |
| profile_public | ✅ Self-update | ❌ | ❌ |
| wallet | ❌ | ✅ Transactions | ✅ |
| preferences | ✅ Self-update | ❌ | ❌ |
| verification | ❌ | ✅ | ✅ |
| security | ❌ | ✅ | ✅ |
| adult_content | ✅ Self-update | ❌ | ❌ |

---

## Field Migration Map

**Source (old monolithic `users/<uid>`)** → **Target (new domains)**

```
Core Identity:
- id → users/<uid>.id
- email → users/<uid>.email
- username → users/<uid>.username
- usernameLower → users/<uid>.usernameLower
- avatarUrl → users/<uid>.avatarUrl
- coverPhotoUrl → users/<uid>.coverPhotoUrl
- bio → users/<uid>.bio
- isPrivate → users/<uid>.isPrivate
- updatedAt → users/<uid>.updatedAt
- createdAt → users/<uid>.createdAt

Profile Public:
- age → users/<uid>/profile_public.age
- gender → users/<uid>/profile_public.gender
- location → users/<uid>/profile_public.location
- relationshipStatus → users/<uid>/profile_public.relationshipStatus
- vibePrompt → users/<uid>/profile_public.vibePrompt
- firstDatePrompt → users/<uid>/profile_public.firstDatePrompt
- musicTastePrompt → users/<uid>/profile_public.musicTastePrompt
- interests → users/<uid>/profile_public.interests
- profileAccentColor → users/<uid>/profile_public.profileAccentColor
- galleryUrls → users/<uid>/profile_public.galleryUrls
- introVideoUrl → users/<uid>/profile_public.introVideoUrl

Wallet:
- lastCheckinDate → users/<uid>/wallet.lastCheckinDate
- checkinStreak → users/<uid>/wallet.checkinStreak
- balance → users/<uid>/wallet.balance
- coinBalance → users/<uid>/wallet.coinBalance

Preferences:
- themeId → users/<uid>/preferences.themeId
- backgroundColor → users/<uid>/preferences.backgroundColor
- profileMusicUrl → users/<uid>/preferences.profileMusicUrl
- profileMusicTitle → users/<uid>/preferences.profileMusicTitle
- profileBgGradientStart → users/<uid>/preferences.profileBgGradientStart
- profileBgGradientEnd → users/<uid>/preferences.profileBgGradientEnd
- camViewPolicy → users/<uid>/preferences.camViewPolicy

Verification:
- isVerified → users/<uid>/verification.status
- verifiedAt → users/<uid>/verification.verifiedAt
- verifiedBy → users/<uid>/verification.verifiedBy
```

---

## What Stays Unchanged

- `users/<uid>/stories/{storyId}` (independent collection)
- `users/<uid>/followers/{followerId}` (independent collection)
- `users/<uid>/following/{followingId}` (independent collection)
- `users/<uid>/bookmarks/{bookmarkId}` (independent collection)
- `users/<uid>/privacy/{documentId}` (already isolated)
- `users/<uid>/adult_profile/{documentId}` (already isolated)

---

## Implementation Phases

### Phase 1: Schema Lock (This Document)
✅ Define all domains
✅ Define field ownership
✅ Define write authority

### Phase 2: Firestore Rules Rewrite
- Write new rules (see separate document)
- Deploy in staging
- Validate on test accounts

### Phase 3: Migration Script + Backfill
- Create backfill Cloud Function
- Dry-run on test data
- Execute with rollback plan

### Phase 4: Writer Code Refactor
- Update all 5 app code systems
- Map each to correct domain
- Deploy with feature flags (optional)

### Phase 5: Data Cleanup
- Remove old fields from `users/<uid>`
- Archive migration logs
- Production sign-off

---

## Validation Checklist

Before moving to Phase 2:

- [ ] All fields accounted for (no orphaned fields)
- [ ] Write authority clear per domain (no ambiguity)
- [ ] No cross-domain reads required (if needed, document explicitly)
- [ ] Verification is server-only (client cannot bypass)
- [ ] Wallet is server-only (no client coin injection)
- [ ] Security is server-only (no client session manipulation)
