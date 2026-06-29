# ✅ pubspec.yaml ↔ Backend Services Alignment Validator
**Validation Guide for Propagation Phase**  
**Date**: June 27, 2026

---

## 📦 Dependency Alignment Matrix

### Tier 1: Critical Dependencies (Block Propagation if Missing)

| Package | Current | Backend Service | Validation | Status |
|---------|---------|-----------------|-----------|--------|
| `firebase_core` | ^4.11.0 | Firebase initialization | Must load before any Firebase calls | ✅ |
| `firebase_auth` | ^6.5.4 | Google OAuth 2.0 + ID Token | Provides `request.auth.uid` to Security Rules | ✅ |
| `cloud_firestore` | ^6.6.0 | Firestore Database | Security Rules v2 requires ≥6.0 | ✅ |
| `cloud_functions` | ^6.3.3 | Cloud Functions callable | Used for Agora tokens, Stripe checkouts | ✅ |
| `flutter_riverpod` | ^2.5.1 | State management | REQUIRED: All Firebase calls via providers | ✅ |

**Validation**: Run `flutter pub get` and confirm no version conflicts.

---

### Tier 2: Service-Specific Dependencies

#### Payment Processing (Stripe)
```yaml
flutter_stripe: ^12.0.0
├─ Purpose: Stripe Checkout Session hosting
├─ Backend dependency: Cloud Function createCheckoutSession
├─ Webhook expectation: Receives charge.succeeded
└─ Validation: Can user reach Stripe hosted checkout?
```

**Checklist**:
- [ ] `STRIPE_SECRET` environment variable set in Cloud Functions
- [ ] Stripe webhook endpoint registered: `https://project.cloudfunctions.net/webhooks/stripe-events`
- [ ] Webhook signature secret (`STRIPE_WEBHOOK_SECRET`) matches in Cloud Functions
- [ ] Test transaction in Stripe Dashboard creates `/payments/{uid}/transactions` docs

---

#### Real-Time Audio/Video (Agora)
```yaml
agora_rtc_engine: 6.5.4
├─ Purpose: WebRTC audio/video streaming
├─ Backend dependency: Cloud Function generateAgoraToken
├─ Token expiry: 2 hours (tokens regenerate on room re-join)
└─ Validation: Does Agora token contain correct roomId?
```

**Checklist**:
- [ ] `AGORA_APP_ID` set in Cloud Functions
- [ ] `AGORA_APP_CERTIFICATE` set in Cloud Functions (NOT hardcoded in Flutter)
- [ ] Cloud Function generateAgoraToken takes (roomId, role)
- [ ] Token includes correct channel ID (matches roomId)
- [ ] Test: Join room, verify audio transmission <2s latency

---

#### Real-Time Messaging (Firebase RTDB + Firestore)
```yaml
firebase_database: ^12.4.4
├─ Purpose: RTDB presence sync (optional, can be Firestore-only)
├─ Backend dependency: Cloud Function onJoinRoom updates participants
├─ Listener: Real-time participant list (who's in room)
└─ Validation: Does participant presence reflect actual joins?

cloud_firestore: ^6.6.0
├─ Purpose: Message storage + conversations
├─ Firestore rules: isConversationParticipant() gate
├─ TTL: Messages auto-deleted after 90 days
└─ Validation: Non-participants cannot read messages
```

**Checklist**:
- [ ] Firestore index: `(participantIds, updatedAt)` for conversation list
- [ ] Firestore index: `(hostId, createdAt desc)` for room list
- [ ] Cloud Function cleanupConversationMessages triggers daily (TTL cleanup)
- [ ] Test: Attempt to read conversation without participantIds in list → ❌ 403

---

#### Web-Specific Requirements
```yaml
flutter_web_plugins:
  sdk: flutter
web: any
├─ Purpose: Web platform support + browser plugins
├─ Backend dependency: Firebase Auth web SDK (same origin check)
└─ Validation: OAuth redirect works in web browser
```

**Checklist**:
- [ ] `firebase.json` contains CORS headers for web hosting
- [ ] OAuth redirect URI includes web domain (Firebase Console → Auth → Settings)
- [ ] Service worker caches correctly (no-cache for .js files)
- [ ] Test: Sign in → verify ID token stored in browser localStorage

---

### Tier 3: Development & Testing Dependencies

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.0
  fake_cloud_firestore: ^4.0.0
  patrol: ^4.3.0

Purpose:
  - integration_test: End-to-end testing (matches production backend)
  - flutter_test: Unit tests (use fake_cloud_firestore for mocks)
  - mocktail: Mock HTTP calls (Stripe webhook simulation)
  - patrol: Robust UI testing (alternative to integration_test)

Validation:
  ✅ Are Riverpod providers injectable for testing?
  ✅ Do tests use FakeFirebaseFirestore (not live database)?
  ✅ Can tests mock Stripe webhook responses?
```

**Checklist**:
- [ ] All Firebase-dependent Riverpod providers support `.overrideWithValue()`
- [ ] Integration tests run against Firestore emulator locally
- [ ] Test fixtures include adult/non-adult rooms, verified/unverified users
- [ ] Run: `flutter test integration_test/ -d web` → all pass ✅

---

## 🔐 Security-Critical Alignments

### Authorization: Firebase Auth ↔ Firestore Rules

**Dependency Chain**:
```
1. User signs in → Firebase Auth issues ID token
2. Token contains: request.auth.uid, request.auth.token.{custom claims}
3. Client makes Firestore query
4. Firestore Security Rules EVALUATE request.auth.uid
5. Rule logic: isSelf(uid), isAdmin(), isAdultVerified(uid)
```

**Validation Checklist**:

#### Custom Claims Propagation
```dart
// ❌ WRONG: Relying on client-side flags
if (user.isAdmin) { /* access granted */ }

// ✅ CORRECT: Firestore rule checks server-side custom claim
// isAdmin() → request.auth.token.admin == true
```

**Action Required**:
- [ ] Delete all client-side role/admin/verification flags
- [ ] Verify custom claims set in Cloud Functions (via admin SDK)
- [ ] Test: Non-admin user cannot trigger admin-only functions

#### Adult Verification Gate
```dart
// ❌ WRONG: Checking client-side provider state
if (userProvider.isAdultVerified) { /* allow access */ }

// ✅ CORRECT: Firestore rule fetches verification doc
// isAdultVerified(uid) → get(/verification/{uid}).data.isAdultVerified
```

**Action Required**:
- [ ] Verification status ONLY read from `/verification/{uid}` doc (server-managed)
- [ ] No custom claim for adult status (can expire)
- [ ] Cloud Function handles verification expiry (TTL: 365 days)
- [ ] Test: Unverified user attempts adult room → ❌ 403

---

## 💳 Payment Integrity: Stripe ↔ Cloud Functions

**Dependency Chain**:
```
1. Client calls Cloud Function: createCheckoutSession(productId)
   ↓
2. Cloud Function validates productId against CHECKOUT_PRODUCTS config
3. Calls Stripe API → creates session
4. Returns sessionId to client
   ↓
5. Client redirects to Stripe Hosted Checkout
6. User enters payment details
   ↓
7. Stripe processes charge → fires charge.succeeded webhook
   ↓
8. Cloud Function receives webhook (signature-verified)
9. Extracts: userId, productType, amount
10. Writes to Firestore: /payments/{userId}/transactions/{txnId}
11. Updates: user.coins += coinCount
    ↓
12. Firestore listener fires → Riverpod invalidates userBalanceProvider
13. UI updates coin balance in real-time
```

**Validation Checklist**:

- [ ] `CHECKOUT_PRODUCTS` config in `functions/index.js` is complete
  ```javascript
  coins_70: { unitAmount: 99, coins: "70" },
  coins_350: { unitAmount: 499, coins: "350" },
  // ...
  ```

- [ ] `STRIPE_SECRET` environment variable matches actual Stripe API key
  ```bash
  firebase functions:config:set stripe.secret="sk_..."
  ```

- [ ] Webhook signature validation active in Cloud Function
  ```javascript
  const signature = req.get('stripe-signature');
  const event = stripe.webhooks.constructEvent(
    req.rawBody,
    signature,
    STRIPE_WEBHOOK_SECRET // MUST match Stripe Dashboard
  );
  ```

- [ ] Firestore Security Rules block direct writes to `/payments`
  ```
  /payments/{userId}/transactions/{txnId} {
    allow read: if request.auth.uid == userId;
    allow write: if false; // Cloud Function only
  }
  ```

- [ ] Payment transaction doc created with correct fields:
  ```
  {
    stripePaymentId: "ch_...",
    amount: 499,
    currency: "usd",
    productType: "coin_package",
    coins: 350,
    status: "succeeded",
    createdAt: timestamp
  }
  ```

- [ ] Test webhook: 
  ```bash
  # Get test event from Stripe CLI
  stripe trigger charge.succeeded --api-key sk_test_...
  
  # Verify coins credited in Firestore
  ```

---

## 🎤 WebRTC Signaling: Agora ↔ Cloud Functions

**Dependency Chain**:
```
1. Client calls Cloud Function: generateAgoraToken(roomId, role)
   ↓
2. Cloud Function builds Agora RTC token:
   - Channel: roomId (must match Flutter channel)
   - Role: 'host' (can publish) OR 'audience' (listen only)
   - Expiry: 2 hours
   - App ID + Certificate (from environment)
   ↓
3. Returns token to client
   ↓
4. Client initializes RTCEngine with token
5. Flutter_webrtc creates RTCPeerConnection
6. TURN/STUN servers injected (from Cloud Function onJoinRoom)
   ↓
7. ICE candidate gathering begins
8. Audio/Video stream established (if hardware available)
```

**Validation Checklist**:

- [ ] `AGORA_APP_ID` set in Cloud Functions
  ```bash
  firebase functions:config:set agora.app_id="123456"
  ```

- [ ] `AGORA_APP_CERTIFICATE` set in Cloud Functions (NOT public)
  ```bash
  firebase functions:config:set agora.app_certificate="abc123..."
  ```

- [ ] Cloud Function RtcTokenBuilder includes:
  ```javascript
  const token = RtcTokenBuilder.buildTokenWithUid(
    AGORA_APP_ID,
    AGORA_APP_CERTIFICATE,
    roomId,        // Channel name
    uid,           // Unique user ID
    role,          // RtcRole.PUBLISHER or RtcRole.SUBSCRIBER
    3600 * 2       // 2-hour expiry
  );
  ```

- [ ] TURN/STUN servers returned from onJoinRoom:
  ```javascript
  const iceServers = [
    { urls: ["stun:stun.l.google.com:19302"] },
    // Metered TURN servers (cached 60s)
  ];
  ```

- [ ] Test: Join room → receive token → check token.channel == roomId
  ```dart
  final token = await ref.read(agoraTokenProvider(roomId).future);
  expect(token.channel, equals(roomId));
  ```

---

## 📋 Firestore Indexes: Query Performance Validation

**Critical Indexes for Propagation**:

| Collection | Fields | Purpose | Status |
|-----------|--------|---------|--------|
| `rooms` | `(hostId, createdAt desc)` | Room list by host + time | ⏳ Building |
| `conversations` | `(participantIds, updatedAt)` | Conversation list for user | ⏳ Building |
| `payments` | `(userId, createdAt desc)` | Transaction history | ⏳ Building |
| `rooms` | `(isAdult, allowGuestAccess)` | Filter public adult rooms | ⏳ Building |

**Validation Checklist**:

- [ ] Indexes deployed: `firebase deploy --only firestore:indexes`
- [ ] Check Firebase Console → Firestore → Indexes
  - [ ] All indexes show "Enabled" (not "Creating")
  - [ ] Build progress: 0% → 100%
- [ ] Monitor query latency:
  ```dart
  final stopwatch = Stopwatch()..start();
  final rooms = await ref.watch(roomListProvider).future;
  print('Room list query: ${stopwatch.elapsedMilliseconds}ms');
  // Expected: <2000ms (2 seconds)
  ```
- [ ] If index shows "Creating", queries will be slow until complete

---

## 🔗 Riverpod Provider Architecture Validation

**Correct Pattern** (All Firebase access through providers):
```dart
// ✅ lib/config/firebase_providers.dart
final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);
final firebaseAuthProvider = Provider((ref) => FirebaseAuth.instance);

// ✅ lib/features/room/providers/room_list_provider.dart
final roomListProvider = FutureProvider.autoDispose((ref) async {
  final firestore = ref.watch(firestoreProvider);
  final rooms = await firestore.collection('rooms').get();
  return rooms.docs.map((doc) => Room.fromDoc(doc)).toList();
});

// ✅ In widget
class RoomListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomListProvider);
    // Use roomsAsync, never call FirebaseFirestore.instance directly
  }
}
```

**Incorrect Pattern** (Hardcoded singletons):
```dart
// ❌ lib/features/room/screens/live_room.dart
class LiveRoomScreen extends StatefulWidget {
  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  @override
  void initState() {
    super.initState();
    // ❌ Direct singleton access
    final db = FirebaseFirestore.instance;
    db.collection('rooms').doc(roomId).snapshots().listen(...);
  }
}
```

**Validation Checklist**:
- [ ] Run: `grep -r "FirebaseFirestore.instance\|FirebaseAuth.instance\|FirebaseDatabase.instance" lib/`
- [ ] Result should be EMPTY (or only in `lib/config/firebase_providers.dart`)
- [ ] All Firebase access goes through Riverpod providers
- [ ] All providers are `FutureProvider` or `StreamProvider`
- [ ] All providers support `.overrideWithValue()` for testing

---

## 🧪 Integration Test Alignment

**Test Dependencies** (from pubspec.yaml):
```yaml
integration_test:
  sdk: flutter
mocktail: ^1.0.0
fake_cloud_firestore: ^4.0.0
```

**Validation Checklist**:

- [ ] Test fixtures in `integration_test/fixtures/test_data.dart` include:
  ```dart
  const testUser = {
    'uid': 'test-uid-123',
    'username': 'testuser',
    'isAdultVerified': true,
    'verificationStatus': 'verified'
  };
  
  const testRoom = {
    'roomId': 'room-123',
    'hostId': 'test-uid-123',
    'isAdult': false,
    'allowGuestAccess': true
  };
  ```

- [ ] Integration tests mock:
  ```dart
  setUp(() {
    FirebaseAuth.instance = MockFirebaseAuth();
    FirebaseFirestore.instance = FakeFirebaseFirestore();
  });
  ```

- [ ] Critical flows tested:
  1. Auth login → profile load
  2. Room join → participant added to Firestore
  3. Stripe webhook → coins credited
  4. Adult room → verification gate enforced

- [ ] Run: `flutter test integration_test/ -d web`
  - Expected: ✅ All tests pass

---

## 🚀 Pre-Propagation Checklist (Final)

```
┌─────────────────────────────────────────────────────────────┐
│ FIREBASE AUTH                                               │
├─────────────────────────────────────────────────────────────┤
│ [ ] firebase_auth: ^6.5.4 installed                         │
│ [ ] Google OAuth callback URL correct (Firebase Console)    │
│ [ ] Custom claims set by Cloud Function (admin, vipLevel)   │
│ [ ] ID token expires in <1 hour (standard expiry)           │
│ [ ] Test: Sign in works, token contains uid                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ CLOUD FIRESTORE                                             │
├─────────────────────────────────────────────────────────────┤
│ [ ] cloud_firestore: ^6.6.0 installed                       │
│ [ ] firestore.rules deployed to production                  │
│ [ ] 3 critical indexes deployed (building status OK)        │
│ [ ] Security rules compile without syntax errors            │
│ [ ] Test: Unauthenticated user → 403 on all reads           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ CLOUD FUNCTIONS                                             │
├─────────────────────────────────────────────────────────────┤
│ [ ] cloud_functions: ^6.3.3 installed                       │
│ [ ] functions/index.js deployed (firebase deploy)           │
│ [ ] Environment variables set (STRIPE_SECRET, AGORA_*)      │
│ [ ] Callable functions list: 5/5 deployed                   │
│ [ ] Webhook endpoint active (/webhooks/stripe-events)       │
│ [ ] Test: Call generateAgoraToken → returns valid token    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ PAYMENT GATEWAY (STRIPE)                                    │
├─────────────────────────────────────────────────────────────┤
│ [ ] flutter_stripe: ^12.0.0 installed                       │
│ [ ] Stripe API key in Cloud Functions                       │
│ [ ] Webhook secret matches (STRIPE_WEBHOOK_SECRET)          │
│ [ ] Test transaction: charge.succeeded → coins credited     │
│ [ ] Firestore rule: /payments/{uid} write-protected         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ WEBRTC SIGNALING (AGORA)                                    │
├─────────────────────────────────────────────────────────────┤
│ [ ] agora_rtc_engine: 6.5.4 installed                       │
│ [ ] AGORA_APP_ID in Cloud Functions                         │
│ [ ] AGORA_APP_CERTIFICATE in Cloud Functions (NOT public)   │
│ [ ] TURN/STUN servers returned from onJoinRoom              │
│ [ ] Test: Join room → Agora token received → audio streams  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ STATE MANAGEMENT (RIVERPOD)                                 │
├─────────────────────────────────────────────────────────────┤
│ [ ] flutter_riverpod: ^2.5.1 installed                       │
│ [ ] All Firebase calls via providers (NOT singletons)        │
│ [ ] Providers support .overrideWithValue() for tests         │
│ [ ] Test: flutter test integration_test/ -d web → all pass   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ WEB HOSTING & CORS                                          │
├─────────────────────────────────────────────────────────────┤
│ [ ] firebase.json CORS headers correct                       │
│ [ ] Web app deployed (firebase deploy --only hosting)        │
│ [ ] Service worker caches .html + .js (no-cache headers)     │
│ [ ] Test: Sign in → OAuth redirect works → auth persists     │
└─────────────────────────────────────────────────────────────┘

OVERALL STATUS:  ════════════════════════════════════════ 100% ✅

READY FOR PROPAGATION: YES ✅
```

---

## 🎯 Success Metrics Post-Propagation

Once propagation is complete, monitor these:

| Metric | Target | Monitor Method |
|--------|--------|----------------|
| Auth success rate | >99% | Firebase Console → Authentication → Events |
| Firestore rule denials | <1% | Firestore → Indexes → Query cost analysis |
| Cloud Function latency | <1s | Cloud Functions → Logs → Duration |
| Stripe webhook delivery | 100% | Stripe Dashboard → Logs → Delivered |
| WebRTC connection time | <5s | Client-side performance monitoring |
| Payment confirmation lag | <30s | Firestore transaction timestamps vs. UI update |

---

## 📞 Rollback Plan

If issues arise during propagation:

```bash
# Disable Firestore rules (allow all)
firebase deploy --only firestore:rules
# (With rules: { match /{document=**} { allow read, write; } })

# Disable Cloud Functions temporarily
firebase deploy --remove-functions

# Revert to previous rules version
git checkout HEAD~1 firestore.rules
firebase deploy --only firestore:rules
```

**Never push breaking changes without a rollback plan.**

---

## ✅ Validation Command Reference

```bash
# Check Flutter dependencies
flutter pub get
flutter pub outdated

# Analyze Dart code (catches null safety issues, unused imports)
flutter analyze

# Check for hardcoded Firebase instances
grep -r "FirebaseAuth.instance\|FirebaseFirestore.instance" lib/

# Run integration tests
flutter test integration_test/ -d web

# Lint Cloud Functions
cd functions && npm run lint

# Deploy (in order)
firebase deploy --only firestore:rules
firebase deploy --only functions
firebase deploy --only firestore:indexes
firebase deploy --only hosting
```

---

**Next**: Run the final validation checklist and execute the deployment commands above.
