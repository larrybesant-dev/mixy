# 🔗 MixVy Infrastructure Dependency Chain
**Propagation Phase Validation Guide**  
**Date**: June 27, 2026  
**Version**: 2.1  

---

## 📊 System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CLIENT LAYER                                │
│                    (Flutter Web - Chrome)                           │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Riverpod State Management                                   │  │
│  │ ├─ firebaseAuthProvider        (Auth state)                │  │
│  │ ├─ firestoreProvider           (Firestore instance)        │  │
│  │ ├─ currentUserProvider         (User profile)              │  │
│  │ ├─ liveRoomProvider            (Room state)                │  │
│  │ ├─ agoraSignalingProvider      (WebRTC signaling)          │  │
│  │ └─ stripeCheckoutProvider      (Payment state)             │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              │                                      │
│                              ▼                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Service Layer                                               │  │
│  │ ├─ firebase_auth_service       (Auth operations)           │  │
│  │ ├─ firestore_room_service      (Room queries/writes)       │  │
│  │ ├─ payment_api                 (Stripe calls)              │  │
│  │ ├─ agora_rtc_service           (WebRTC engine)             │  │
│  │ └─ real_time_messaging_service (RTDB listeners)            │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                              │                                      │
└──────────────────────┬───────┴───────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    FIREBASE AUTH LAYER                              │
│                     (Google OAuth 2.0)                              │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ Authentication Gates                                        │   │
│  │ • ID Token validation (request.auth != null)               │   │
│  │ • Custom claims (admin, vipLevel, verificationStatus)      │   │
│  │ • Session persistence (Web cookie storage)                 │   │
│  │ • Guest vs. Authenticated flow branching                   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  Outputs: request.auth.uid, request.auth.token.{custom claims}    │
└─────────────────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  SECURITY RULES GATE                                │
│                  (Firestore Rules v2)                               │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Collection-Level Access Control                             │  │
│  │                                                              │  │
│  │ /users/{uid}                                                │  │
│  │  ├─ [READ] isSelf(uid) OR isAdmin()                        │  │
│  │  ├─ [WRITE] isSelf(uid) + fieldMask validation             │  │
│  │  └─ [DELETE] Never allowed (server cleanup only)           │  │
│  │                                                              │  │
│  │ /rooms/{roomId}                                             │  │
│  │  ├─ [READ] Public OR (Adult + isAdultVerified(uid))        │  │
│  │  ├─ [WRITE] isRoomHost(roomId, uid)                        │  │
│  │  ├─ [CREATE] authenticated + role validation               │  │
│  │  └─ /rooms/{roomId}/participants/{uid} [WRITE] auto-join   │  │
│  │                                                              │  │
│  │ /conversations/{convId}                                     │  │
│  │  ├─ [READ] isConversationParticipant(convId)               │  │
│  │  ├─ [WRITE] Participants only (message create/delete)      │  │
│  │  └─ /messages/{msgId} [CREATE] rate-limit + content check  │  │
│  │                                                              │  │
│  │ /verification/{uid}                                         │  │
│  │  ├─ [READ] isSelf(uid) OR isAdmin()                        │  │
│  │  ├─ [WRITE] Server-side only (Cloud Function)              │  │
│  │  └─ Flags: isAdultVerified, verificationStatus, idToken    │  │
│  │                                                              │  │
│  │ /payments/{uid}/transactions/{txnId}                        │  │
│  │  ├─ [READ] isSelf(uid) + Firestore index: userId,date      │  │
│  │  ├─ [WRITE] Forbidden (server only via Stripe webhook)     │  │
│  │  └─ Triggers: Stripe → Cloud Function → Write transaction  │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  Failure Modes:                                                     │
│  • "Permission denied" = Auth token invalid or custom claim missing │
│  • "Insufficient permissions" = fieldMask denied or role mismatch   │
│  • "UNAUTHENTICATED" = !signedIn() or token expired                │
└─────────────────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 FIRESTORE DATA LAYER                                │
│             (Real-time synchronized database)                       │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Core Collections                                             │  │
│  │                                                              │  │
│  │ /users/{uid}                                                │  │
│  │  • profile, preferences, settings (sync on auth login)      │  │
│  │  • Indexes: uid (primary), usernameLower (search)           │  │
│  │                                                              │  │
│  │ /rooms/{roomId}                                             │  │
│  │  • title, hostId, isAdult, allowGuestAccess, createdAt      │  │
│  │  • /participants/{uid} → joined_at, role, isMuted           │  │
│  │  • /messages/{msgId} → sender, content, timestamp           │  │
│  │  • Compound indexes: hostId+createdAt (room list query)     │  │
│  │                                                              │  │
│  │ /conversations/{convId}                                     │  │
│  │  • participantIds[], lastMessage, updatedAt                 │  │
│  │  • /messages/{msgId} (subcollection, auto-archived @90d)    │  │
│  │  • Index: (participantIds, updatedAt) for conversation list │  │
│  │                                                              │  │
│  │ /verification/{uid}                                         │  │
│  │  • isAdultVerified, verificationStatus, idToken, expireAt   │  │
│  │  • Server-managed (Cloud Function populates)                │  │
│  │  • TTL: 365 days (triggers deletion function)               │  │
│  │                                                              │  │
│  │ /payments/{uid}/transactions/{txnId}                        │  │
│  │  • stripePaymentId, amount, status, createdAt               │  │
│  │  • populated by Stripe webhook → Cloud Function             │  │
│  │  • Query: (userId, createdAt desc) for transaction history  │  │
│  │                                                              │  │
│  │ /roles/admins/{uid}                                         │  │
│  │  • grantedAt, grantedBy (audit trail)                       │  │
│  │  • Server-maintained (never client-modified)                │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  Write Triggers:                                                    │
│  • Room update → invalidate roomListProvider                       │
│  • Participant join → sync presence + emit notification             │
│  • Message sent → update conversation.lastMessage                   │
│  • Adult verification → recompute isAdultVerified() gate            │
│  • Payment received → Cloud Function credits user coins             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────┐
│               CLOUD FUNCTIONS LAYER                                 │
│            (Backend compute & webhook handlers)                     │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Callable Functions (Client-invoked via Riverpod)            │  │
│  │                                                              │  │
│  │ onCreateRoom(roomData) → returns { roomId, signalToken }    │  │
│  │  • Validates role permissions + room config                 │  │
│  │  • Sets hostId, createdAt, moderationRules                  │  │
│  │                                                              │  │
│  │ onJoinRoom(roomId) → returns { iceServers, signalingUrl }   │  │
│  │  • Adds participant to /rooms/{roomId}/participants/{uid}   │  │
│  │  • Fetches TURN servers (Metered API, cached 60s)           │  │
│  │  • Returns WebRTC signaling endpoint                         │  │
│  │                                                              │  │
│  │ createCheckoutSession(checkoutData) → returns { sessionId } │  │
│  │  • Validates user + product (coins, premium)                │  │
│  │  • Calls Stripe API → creates hosted checkout session       │  │
│  │  • Returns Stripe redirect URL for payment                  │  │
│  │                                                              │  │
│  │ generateAgoraToken(roomId, role) → returns { token }        │  │
│  │  • Generates Agora RTC token (2-hour expiry)                │  │
│  │  • Role-based: 'host' OR 'audience'                         │  │
│  │                                                              │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │ HTTP Webhooks                                                │  │
│  │                                                              │  │
│  │ /webhooks/stripe-events (POST)                              │  │
│  │  • Receives Stripe charge.succeeded                         │  │
│  │  • Creates payments/{uid}/transactions/{txnId}              │  │
│  │  • Credits user coins: user.coins += productCoins           │  │
│  │  • Emits analytics event                                    │  │
│  │                                                              │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │ Background Triggers (Firestore-driven)                      │  │
│  │                                                              │  │
│  │ onVerificationRequested(uid) → triggers adult verification  │  │
│  │  • Watches /verification/{uid}/status == 'pending'          │  │
│  │  • Validates ID document + liveness check                   │  │
│  │  • Updates verification doc with result                     │  │
│  │                                                              │  │
│  │ onMessageCreated(messageId) → moderation gate               │  │
│  │  • Scans content for prohibited terms                       │  │
│  │  • Flags spam/abuse for moderator review                    │  │
│  │                                                              │  │
│  │ cleanupConversationMessages() (scheduled @midnight UTC)     │  │
│  │  • Deletes messages older than 90 days                      │  │
│  │  • Reduces Firestore storage + read costs                   │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  Error Handling:                                                    │
│  • HttpsError('unauthenticated') → Auth token invalid              │
│  • HttpsError('permission-denied') → User lacks required role      │
│  • HttpsError('resource-exhausted') → Rate limit exceeded          │
│  • HttpsError('internal') → Backend error (retry with exponential) │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
┌────────────────┬────────────────┬────────────────┐
│  STRIPE API    │   AGORA API    │   METERED API  │
│  (Payments)    │   (WebRTC)     │   (TURN srv)   │
│                │                │                │
│ • Checkout     │ • Token gen    │ • TURN server  │
│ • Webhooks     │ • Signaling    │   IP/password  │
│ • Refunds      │ • Recording    │   (cached 60s) │
└────────────────┴────────────────┴────────────────┘
```

---

## 🔄 Critical Data Flow Paths

### Path 1: Authentication → Profile Sync
```
1. User clicks "Sign In"
   ↓
2. Google OAuth redirect → Firebase Auth
   ↓
3. Firebase returns: request.auth.uid + custom claims (role, admin, vipLevel)
   ↓
4. Riverpod: currentUserProvider = ref.watch(firebaseAuthProvider)
   ↓
5. Firestore Security Rules gate: isSelf(uid) → allow read /users/{uid}
   ↓
6. Firestore: GET /users/{uid} → profile object
   ↓
7. Riverpod rebuilds userProfileProvider
   ↓
8. UI renders home screen with user profile
```

**Failure Points:**
- ❌ `FirebaseAuth.instance` singleton instead of provider → test failures
- ❌ Missing custom claims in Firebase → isAdultVerified() check fails
- ❌ Firestore rule: isSelf() checks wrong field → "Permission denied" error
- ❌ Network disconnect → onError listener must retry with exponential backoff

---

### Path 2: Room Join → WebRTC Signaling
```
1. User clicks room tile
   ↓
2. Riverpod calls: ref.read(onJoinRoomFunction).call({ roomId })
   ↓
3. Cloud Function:
   a) Validates user auth + room permissions
   b) Gets TURN servers from Metered API (or cache)
   c) Creates /rooms/{roomId}/participants/{uid} document
   d) Returns { iceServers, signalingUrl }
   ↓
4. Firestore Security Rules check: isRoomParticipant(roomId, uid)
   ↓
5. WebRTC engine (flutter_webrtc) initializes:
   a) Creates RTCPeerConnection with ICE servers
   b) Opens ICE candidate gathering
   c) Waits for signaling messages (via Agora or WebSocket)
   ↓
6. Agora RTC Engine boots up (audio/video stream)
   ↓
7. Firestore listener on /rooms/{roomId}/participants/{uid}
   → Triggers presence updates (who is in the room)
   ↓
8. Message collection synced in real-time
```

**Failure Points:**
- ❌ TURN server cache expired → ICE candidates never gathered
- ❌ `allowGuestAccess = false` but rules don't enforce → guest joins successfully
- ❌ Agora token expired → audio/video fails silently
- ❌ Cloud Function timeout (>60s) → client never gets response

---

### Path 3: Payment Flow → Coin Credit
```
1. User clicks "Buy Coins"
   ↓
2. Riverpod calls: ref.read(checkoutProvider).call({ productId: 'coins_350' })
   ↓
3. Cloud Function (createCheckoutSession):
   a) Validates user exists + not blocked
   b) Maps productId → Stripe product config
   c) Calls Stripe API → creates checkout session
   d) Returns { sessionId, redirectUrl }
   ↓
4. Client redirects to Stripe Hosted Checkout
   ↓
5. User enters payment info + completes checkout
   ↓
6. Stripe fires webhook: charge.succeeded
   ↓
7. Cloud Function (stripe-webhook):
   a) Verifies webhook signature (STRIPE_WEBHOOK_SECRET)
   b) Gets metadata { userId, productType, coins }
   c) Creates: /payments/{uid}/transactions/{txnId}
   d) Updates: user.coins += coinCount
   ↓
8. Firestore Security Rules:
   a) [READ] isSelf(uid) → user can view own transactions
   b) [WRITE] Server-only (Cloud Function has admin access)
   ↓
9. Riverpod listener on user.coins → invalidates userBalanceProvider
   ↓
10. UI updates coin balance in real-time
```

**Failure Points:**
- ❌ `STRIPE_SECRET` not in Cloud Functions environment → all payments fail
- ❌ Webhook signature validation skipped → fraudulent charges accepted
- ❌ Firestore rules allow direct write to /payments/... → client can fake transactions
- ❌ Stripe metadata missing productType → coins not credited

---

### Path 4: Adult Verification Gate
```
1. User attempts to join adult-only room
   ↓
2. Firestore Security Rules check:
   roomReadableByRequester(roomData):
     if (room.isAdult && !isAdultVerified(uid))
       → DENY access
   ↓
3. If denied → Cloud Function triggers verification flow:
   a) Client redirects to /verification screen
   b) User uploads ID document + selfie (liveness)
   c) Cloud Function processes: calls ID verification API
   d) Updates /verification/{uid}:
      { isAdultVerified: true, verificationStatus: 'verified', expireAt: +365d }
   ↓
4. On next room join attempt:
   a) Firestore rule re-evaluates isAdultVerified(uid)
   b) Now returns TRUE
   c) User gains access to adult rooms
```

**Failure Points:**
- ❌ Verification doc written by client → bypassed by direct Firestore write
- ❌ verificationStatus field missing → rule defaults to allow (open door)
- ❌ Custom claim not set by server → isAdultVerified() doesn't use verified fact
- ❌ No TTL on verification doc → expired verification never cleaned up

---

## 🧪 Test Scenarios for Propagation Phase

### Scenario 1: Auth Bypass Detection
```
Test: Can unauthenticated user read /users collection?
Expected: ✅ Permission denied
Implementation:
  1. Open web app in private/incognito mode
  2. Open DevTools → Console
  3. Execute: firebase.firestore().collection('users').get()
  4. Verify: Error "Missing or insufficient permissions"
```

### Scenario 2: Adult Gate Enforcement
```
Test: Can non-verified user join adult room?
Expected: ✅ Access denied until verified
Implementation:
  1. Sign in as test user (non-verified)
  2. Attempt to join room with isAdult=true
  3. Verify: "Adult verification required" prompt appears
  4. After verification, retry
  5. Verify: ✅ Room accessible
```

### Scenario 3: WebRTC Signaling Path
```
Test: Can user join room and receive ICE servers?
Expected: ✅ Connected peer within 5 seconds
Implementation:
  1. Sign in as 2 users (in separate browsers)
  2. Both join same room
  3. Open DevTools → Network tab
  4. Verify: Cloud Function call returns iceServers
  5. Verify: WebRTC console shows "connected" state
  6. Play audio → verify cross-browser transmission
```

### Scenario 4: Payment Webhook Integrity
```
Test: Can fraudulent webhook credit coins?
Expected: ✅ Only signed Stripe webhooks processed
Implementation:
  1. Capture webhook signature from Stripe test account
  2. Attempt POST to /webhooks/stripe-events with:
     a) Valid signature → coins credited ✅
     b) Invalid signature → rejected ❌
     c) Tampered payload → signature fails ❌
```

### Scenario 5: Firestore Index Performance
```
Test: Room list query returns in <2 seconds?
Expected: ✅ Compound index: (hostId, createdAt)
Implementation:
  1. Create room
  2. Open DevTools → Performance tab
  3. Trigger room list fetch
  4. Measure: /rooms query duration
  5. Verify: <2s (index hit) or >10s (full scan)
```

---

## ✅ Propagation Validation Checklist

### A. Firestore Security Rules
- [ ] `firestore.rules` deployed to production ✅
- [ ] All helper functions compile without syntax errors
- [ ] `isSelf()` gate blocks cross-user reads
- [ ] `isAdultVerified()` reads from verification doc (not custom claim alone)
- [ ] Payment transactions write-protected (server-only)
- [ ] Room `allowGuestAccess` respected in read rules
- [ ] Test: Unauthenticated user → `permission_denied` on all reads

### B. Cloud Functions Deployment
- [ ] `functions/index.js` deployed (firebase deploy --only functions)
- [ ] Environment variables set:
  - [ ] `STRIPE_SECRET`
  - [ ] `STRIPE_WEBHOOK_SECRET`
  - [ ] `AGORA_APP_ID`
  - [ ] `AGORA_APP_CERTIFICATE`
  - [ ] `METERED_API_KEY`
- [ ] Callable functions tested (createCheckoutSession, generateAgoraToken, etc.)
- [ ] Webhook signature validation active
- [ ] Test: `curl -X POST /webhooks/stripe-events` with mock event

### C. Firestore Indexes
- [ ] `firestore.indexes.json` deployed
- [ ] Compound index: `(hostId, createdAt desc)` for room list
- [ ] Compound index: `(participantIds, updatedAt)` for conversation list
- [ ] Compound index: `(userId, createdAt desc)` for transaction history
- [ ] Monitor index build progress in Firebase Console

### D. pubspec.yaml Alignment
- [ ] `cloud_firestore: ^6.6.0` → matches Security Rules v2
- [ ] `firebase_auth: ^6.5.4` → supports custom claims
- [ ] `flutter_stripe: ^12.0.0` → compatible with Stripe webhook
- [ ] `agora_rtc_engine: 6.5.4` → WebRTC signaling functional
- [ ] `flutter_riverpod: ^2.5.1` → provider system ready
- [ ] **No singleton static `FirebaseAuth.instance`** in source (only via providers)

### E. Runtime Configuration
- [ ] `.env` file populated with Firebase project ID, API keys
- [ ] `web/index.html` includes Firebase config (initializeApp)
- [ ] App Check token configured (optional but recommended)
- [ ] Analytics enabled for tracking propagation events

### F. Network & CORS
- [ ] Firebase Hosting CORS headers configured ✅ (in firebase.json)
- [ ] Cross-Origin-Opener-Policy: same-origin-allow-popups
- [ ] Cross-Origin-Embedder-Policy: unsafe-none
- [ ] Service worker caching headers: no-cache for .js files

### G. Test Coverage
- [ ] ✅ Manual E2E tests pass (3 flows: Auth, Room, Payment)
- [ ] ✅ Integration tests: `flutter test integration_test/ -d web`
- [ ] ✅ Security rule simulation tests (use `firestore.rules` emulator locally first)

---

## 📋 Immediate Action Items

### 1. Pre-Propagation Audit (30 min)
```bash
# Run linter to catch any Dart issues
flutter analyze

# Verify no direct Firebase.instance usage
grep -r "FirebaseAuth.instance" lib/
grep -r "FirebaseFirestore.instance" lib/

# Check firestore.rules syntax
firebase emulators:start --only firestore,auth
```

### 2. Deploy to Production (10 min)
```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Cloud Functions
firebase deploy --only functions

# Deploy indexes
firebase deploy --only firestore:indexes

# Verify deployment
firebase functions:list
```

### 3. Smoke Test (15 min)
Run the **3 critical flows** from `TEST_PLAN_MANUAL_UAT.md`:
1. **Onboarding & Auth** — Sign in, verify profile loads
2. **Room Engagement** — Join room, hear audio, send message
3. **Payment** — Buy coins, verify balance updated

### 4. Monitor Propagation (ongoing)
- Watch Firebase Console → Firestore → Indexes (build progress)
- Check Cloud Functions → Logs for any deployment errors
- Monitor Stripe webhook delivery (Dashboard → Logs)
- Track Agora signaling latency (expect <100ms)

---

## 🛡️ Common Failure Modes & Fixes

| Symptom | Root Cause | Fix |
|---------|-----------|-----|
| "Permission denied" on all reads | Firestore rules not deployed | `firebase deploy --only firestore:rules` |
| Coins not credited after payment | Webhook signature validation failed | Check `STRIPE_WEBHOOK_SECRET` in env |
| WebRTC connection hangs | TURN servers not returned from Cloud Function | Check Metered API key + TURN cache logic |
| UI shows stale profile | Riverpod provider not invalidated after auth | Add `ref.invalidate(currentUserProvider)` |
| Adult room accessible to minors | isAdultVerified() checks custom claim instead of doc | Rule: `verificationDoc(uid).data.isAdultVerified` |
| Firestore index not used (slow queries) | Indexes not deployed or built | Check Firebase Console → Build status |

---

## 📞 Escalation Contacts

| Issue | Contact | Link |
|-------|---------|------|
| Firestore rule logic | Use `firestore.rules` emulator locally | `firebase emulators:start` |
| Cloud Function timeout | Check function logs | Firebase Console → Functions → Logs |
| Stripe webhook not firing | Verify endpoint + signature in Stripe Dashboard | Settings → Webhooks |
| Agora token generation | Check auth token + RTC role in logs | Agora Console → Projects |

---

## 🎯 Success Criteria

✅ **Propagation phase complete when:**
1. All 4 test scenarios pass without errors
2. Firestore rules block unauthorized access
3. Payment flow credits coins within 30 seconds
4. WebRTC peer connection established <5 seconds
5. Adult verification gate enforces age restrictions
6. No "Permission denied" errors in production logs

---

**Next Steps**: Run the manual E2E tests → automated tests → monitor production logs for 24 hours.
