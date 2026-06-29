# 🚀 MixVy Propagation Phase - Execution Roadmap
**Complete Backend Validation Framework**  
**Date**: June 27, 2026  

---

## 📚 Documentation System Created

You now have a complete infrastructure audit toolkit:

| Document | Purpose | Time | Use Case |
|----------|---------|------|----------|
| **[INFRASTRUCTURE_DEPENDENCY_CHAIN.md](./INFRASTRUCTURE_DEPENDENCY_CHAIN.md)** | Complete architecture + data flows + test scenarios | 20 min | Deep dive: understand how each system piece connects |
| **[INFRASTRUCTURE_DEPENDENCY_CHAIN_DIAGRAMS.md](./INFRASTRUCTURE_DEPENDENCY_CHAIN_DIAGRAMS.md)** | Visual Mermaid diagrams + error cascades | 5 min | Quick reference: see the flow at a glance |
| **[PUBSPEC_BACKEND_ALIGNMENT.md](./PUBSPEC_BACKEND_ALIGNMENT.md)** | Dependency validation + alignment matrix | 30 min | Pre-deployment: ensure every package matches backend config |
| **[INFRASTRUCTURE_DEPENDENCY_CHAIN_EXECUTION_ROADMAP.md](./INFRASTRUCTURE_DEPENDENCY_CHAIN_EXECUTION_ROADMAP.md)** | This file: step-by-step action plan | N/A | Now → Execute |

---

## 🎯 Quick Start (5 Minutes)

### Step 1: Understand Your System
```
Read FIRST: INFRASTRUCTURE_DEPENDENCY_CHAIN_DIAGRAMS.md (5 min)
  ↓ Gives you the "big picture" visually
  ↓ Shows where failures typically happen
```

### Step 2: Identify Your Stack
```
Your current setup:
┌──────────────────────────────────────────────────────────┐
│ Flutter Web (Chrome) + Riverpod                          │
│   ↓                                                       │
│ Firebase Auth (Google OAuth) + Firestore Rules v2        │
│   ↓                                                       │
│ Cloud Functions (Stripe, Agora token generation)         │
│   ↓                                                       │
│ External APIs: Stripe, Agora RTC, Metered (TURN)        │
└──────────────────────────────────────────────────────────┘

Critical Data Flows:
1. Auth → Profile (isSelf() gate)
2. Room Join → WebRTC (TURN server cache)
3. Payment → Coins (Stripe webhook signature)
4. Adult Room → Verification (server-managed doc)
```

### Step 3: Run Validation Checks
```bash
# Check 1: No hardcoded Firebase singletons
grep -r "FirebaseAuth.instance\|FirebaseFirestore.instance" lib/
# Expected: EMPTY (all via providers)

# Check 2: Integration tests exist
ls -la integration_test/
# Expected: e2e_critical_flows_test.dart exists

# Check 3: Backend env vars set
firebase functions:config:get stripe.secret agora.app_id
# Expected: All keys present (masked values OK)

# Check 4: Cloud Functions deployed
firebase functions:list
# Expected: 5+ callable functions listed
```

---

## 🔍 Detailed Execution Plan

### Phase 1: Pre-Propagation Validation (1 Hour)

#### 1.1 Backend Configuration Audit
```bash
# TIME: 10 minutes

# Step 1: Verify Cloud Functions deployment
firebase functions:list
# Should show: ✅ onJoinRoom ✅ createCheckoutSession 
#              ✅ generateAgoraToken ✅ stripe webhook

# Step 2: Check environment variables
firebase functions:config:get
# Expected output:
# {
#   "stripe": { "secret": "sk_..." },
#   "agora": { "app_id": "12345", "app_certificate": "abc..." },
#   "metered": { "api_key": "xyz..." }
# }

# Step 3: Verify Firestore rules deployed
curl -s https://firestore.googleapis.com/v1/projects/mix-and-mingle-v2/databases/default
# Check: rules field contains your current firestore.rules

# Step 4: Check indexes
firebase firestore:indexes:list
# Look for:
#   ✓ (hostId, createdAt desc) → Status: ENABLED or CREATING
#   ✓ (participantIds, updatedAt) → Status: ENABLED or CREATING
#   ✓ (userId, createdAt desc) → Status: ENABLED or CREATING
```

#### 1.2 Dependency Alignment Check
```bash
# TIME: 15 minutes

# Read: PUBSPEC_BACKEND_ALIGNMENT.md → "Pre-Propagation Checklist"
# Go through each section:
#   ✅ Firebase Auth (6.5.4) aligns with OAuth
#   ✅ Cloud Firestore (6.6.0) aligns with Rules v2
#   ✅ Cloud Functions (6.3.3) can call backend
#   ✅ Agora RTC (6.5.4) ready for WebRTC
#   ✅ Flutter Stripe (12.0.0) can redirect to Checkout

# Run validation
flutter pub get
flutter analyze
# Expected: No errors
```

#### 1.3 Security Gate Validation
```bash
# TIME: 15 minutes

# Test 1: Firestore rules block unauthorized access
# Open DevTools Console in web app (private mode, not signed in)
firebase.firestore().collection('users').doc('any-uid').get()
  .then(() => console.log('❌ OPEN ACCESS - RULES BROKEN'))
  .catch((e) => console.log('✅ DENIED:', e.code));
# Expected: ❌ permission-denied error

# Test 2: Adult verification gate
# Sign in as unverified user
# Attempt to join room with isAdult=true
# Expected: Modal says "Age verification required"

# Test 3: Payment write protection
# Try direct Firestore write to /payments/{uid}
firebase.firestore()
  .collection('payments')
  .doc('test-uid')
  .set({ amount: 999 })  
  .then(() => console.log('❌ PAYMENT WRITE ALLOWED - RULES BROKEN'))
  .catch((e) => console.log('✅ DENIED:', e.code));
# Expected: ❌ permission-denied error
```

#### 1.4 Code Quality Gate
```bash
# TIME: 10 minutes

# Check for hardcoded singletons (should be ZERO)
echo "=== Checking for hardcoded Firebase instances ==="
SINGLETON_COUNT=$(grep -r "FirebaseAuth.instance\|FirebaseFirestore.instance\|FirebaseDatabase.instance" lib/ | wc -l)
echo "Found: $SINGLETON_COUNT instances"
if [ $SINGLETON_COUNT -eq 0 ]; then
  echo "✅ All Firebase access via Riverpod providers"
else
  echo "❌ REFACTOR REQUIRED: $SINGLETON_COUNT hardcoded instances found"
fi

# Run linter
flutter analyze
# Expected: No errors (0 issues)
```

**Checkpoint**: All 4 tests pass? → Continue to Phase 2

---

### Phase 2: Critical Flow Testing (1.5 Hours)

#### 2.1 Authentication Flow
```bash
# TIME: 15 minutes
# Document: INFRASTRUCTURE_DEPENDENCY_CHAIN.md → "Path 1: Auth"

STEPS:
1. Open browser → mixvy-v2.web.app
2. Click "SIGN IN"
3. Complete Google OAuth redirect
4. Verify: Home screen loads with your profile
5. Open DevTools → Application → Cookies
   → Check: __session (Firebase auth cookie)
6. Refresh page → Verify: Still authenticated
7. Open DevTools → Console:
   firebase.auth().currentUser
   # Should show: { uid, email, displayName, ... }

EXPECTED RESULTS:
✅ OAuth redirect successful
✅ Profile loads within 2 seconds
✅ Session persists across refresh
✅ Custom claims available in token
```

#### 2.2 Room Join → WebRTC Flow
```bash
# TIME: 20 minutes
# Document: INFRASTRUCTURE_DEPENDENCY_CHAIN.md → "Path 2: Room Join"

SETUP: Open 2 browser windows, both signed in

WINDOW 1: Host (creates room)
1. Click "CREATE ROOM"
2. Fill form: Title="Test Room", isAdult=false, allowGuests=true
3. Click "START"
4. Wait for: "Room created, waiting for participants"
5. DevTools → Application → Local Storage
   → Check: roomId exists

WINDOW 2: Guest (joins room)
1. Browse home → Find "Test Room"
2. Click "JOIN"
3. Wait max 5 seconds
4. Check: Audio/video toggles appear
5. DevTools → Network tab
   → Look for: Cloud Function call /onJoinRoom
   → Response should include: { iceServers, agoraToken }

VERIFICATION:
✅ Both users appear in "Participants" list
✅ Audio transmission: Host → Guest (<2s latency)
✅ No "WebRTC connection failed" errors
✅ Message sent in chat: Appears in real-time
```

#### 2.3 Payment → Coins Flow
```bash
# TIME: 20 minutes
# Document: INFRASTRUCTURE_DEPENDENCY_CHAIN.md → "Path 3: Payment"

SETUP: Signed-in user with initial coin balance

1. Click "Buy Coins"
2. Select: "70 Coins - $0.99"
3. Click "Checkout"
4. Redirected to Stripe → Use TEST card:
   Card: 4242 4242 4242 4242
   CVC: Any 3 digits
   Date: Any future date
5. Complete payment
6. Back to app
7. Wait max 30 seconds
8. Verify: Coin balance UPDATED in header

MONITORING:
# Cloud Functions logs (should show webhook receipt)
firebase functions:log | grep "stripe-events"
# Expected: stripe event received + coins credited

# Firestore verification (check transaction written)
firebase firestore --project mix-and-mingle-v2 query payments/{uid}/transactions
# Expected: Transaction doc with status="succeeded"

EXPECTED RESULTS:
✅ Stripe checkout loads
✅ Payment processed successfully
✅ Cloud Function webhook fires
✅ Coins credited within 30 seconds
✅ No "Permission denied" on transaction write
```

#### 2.4 Adult Verification Gate
```bash
# TIME: 10 minutes
# Document: INFRASTRUCTURE_DEPENDENCY_CHAIN.md → "Path 4: Adult Verification"

SETUP: Signed-in user (unverified)

1. Find room with isAdult=true in home feed
2. Click "JOIN"
3. Expected: Modal appears: "Age Verification Required"
4. Click "VERIFY NOW"
5. Follow ID verification process (may use test ID)
6. Wait for verification to complete
7. Return to room join
8. Expected: Room now accessible

FIRESTORE CHECK:
# Verify doc created
firebase firestore query verification/{uid}
# Expected: { isAdultVerified: true, verificationStatus: "verified", ... }

EXPECTED RESULTS:
✅ Adult rooms blocked before verification
✅ Verification modal appears
✅ After verification, adult rooms accessible
✅ No way to bypass (client-side verification ignored)
```

**Checkpoint**: All 4 flows complete? → Continue to Phase 3

---

### Phase 3: Security Hardening (30 Minutes)

#### 3.1 Attack Simulation (Firestore Rules)
```bash
# TIME: 15 minutes

# Setup test vectors
export TEST_UID="test-attacker-12345"
export OTHER_UID="legitimate-user-67890"

# Test 1: Cross-user profile read
# Attacker tries to read OTHER_UID's profile
firebase.firestore().collection('users').doc(OTHER_UID).get()
  # Expected: ❌ permission-denied

# Test 2: Conversation intercept
# Attacker tries to read conversation not in participantIds
firebase.firestore().collection('conversations').doc('conv-123').get()
  # Expected: ❌ permission-denied

# Test 3: Admin privilege escalation
# Attacker tries direct write to /roles/admins/{uid}
firebase.firestore().collection('roles').doc('admins').collection(TEST_UID).set({})
  # Expected: ❌ permission-denied

# Test 4: Payment fraud
# Attacker tries to write fake transaction
firebase.firestore()
  .collection('payments').doc(TEST_UID).collection('transactions').add({
    amount: 99999,
    status: 'succeeded'
  })
  # Expected: ❌ permission-denied
```

#### 3.2 Webhook Signature Validation
```bash
# TIME: 10 minutes

# Get your webhook secret
WEBHOOK_SECRET=$(firebase functions:config:get stripe.webhook_secret | jq -r .stripe.webhook_secret)

# Simulate Stripe webhook with INVALID signature
curl -X POST https://project.cloudfunctions.net/webhooks/stripe-events \
  -H "stripe-signature: invalid_signature_xyz" \
  -d '{"type":"charge.succeeded","data":...}' \
  # Expected: ❌ 401 Unauthorized

# Simulate with NO signature
curl -X POST https://project.cloudfunctions.net/webhooks/stripe-events \
  -d '{"type":"charge.succeeded","data":...}' \
  # Expected: ❌ 401 Unauthorized

# Only properly signed webhooks should work ✅
```

#### 3.3 Rate Limiting & DoS Protection
```bash
# TIME: 5 minutes

# Simulate rapid message creation (should rate-limit)
for i in {1..100}; do
  curl -X POST \
    -H "Authorization: Bearer $ID_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\":\"spam $i\"}" \
    https://project.cloudfunctions.net/sendMessage \
    &
done

# Expected: After ~10 requests:
#   ❌ resource-exhausted errors
#   (Rate limit: 10 messages/min/user)
```

**Checkpoint**: All security tests pass? → Continue to Phase 4

---

### Phase 4: Performance & Monitoring (1 Hour)

#### 4.1 Load Testing
```bash
# TIME: 20 minutes

# Test 1: Query latency with index
# Create 100+ rooms, then query room list
# Measure: Firebase Console → Logs → Query latency
# Expected: <2000ms (index hit)

# Test 2: WebRTC connection time
# Join room → measure time to audio/video ready
# Open DevTools → Performance tab
# Expected: <5000ms

# Test 3: Stripe redirect latency
# Click "Buy Coins" → measure time to Stripe Checkout load
# Expected: <2000ms
```

#### 4.2 Error Monitoring Setup
```bash
# TIME: 15 minutes

# Enable Firebase Crashlytics if not already
# Check: Firebase Console → Crashlytics

# Verify error reporting
# Trigger test error:
throw Exception("Test error for Crashlytics");
# Check: Error appears in Crashlytics dashboard within 30 seconds

# Set up alerts:
# Firebase Console → Alerts → Create new alert
# Condition: Crash-free rate < 99%
# Notification: Email your team
```

#### 4.3 Analytics Dashboard
```bash
# TIME: 10 minutes

# Verify key metrics are tracked
firebase.analytics().logEvent('room_created', {
  roomId: 'test-room-123',
  isAdult: false
});

# Check Firebase Console → Analytics → Events
# Expected: room_created event appears within 1 minute

# Add custom events tracking:
# - auth_success
# - room_join_time
# - payment_completed
# - verification_completed
```

#### 4.4 Cost Monitoring
```bash
# TIME: 15 minutes

# Check current costs
firebase billing
# Estimate: Should be <$100/month for first 25 users

# Monitor Firestore costs
firebase firestore collections list
# Check: storage size, read/write volumes

# Optimize if needed:
# - Add indexes (reduces reads)
# - Enable RTDB for presence (cheaper than Firestore listeners)
# - Implement message TTL (auto-delete @90 days)
```

**Checkpoint**: Performance acceptable? → Continue to Phase 5

---

### Phase 5: Go-Live Checklist (30 Minutes)

#### 5.1 Final Pre-Launch Verification
```bash
# TIME: 20 minutes

# Checklist from PUBSPEC_BACKEND_ALIGNMENT.md → "Pre-Propagation Checklist"

FIREBASE AUTH:
[✅] firebase_auth: ^6.5.4 installed
[✅] Google OAuth callback URL correct
[✅] Custom claims set by Cloud Function
[✅] ID token expires in <1 hour
[✅] Test: Sign in works

CLOUD FIRESTORE:
[✅] cloud_firestore: ^6.6.0 installed
[✅] firestore.rules deployed
[✅] Indexes deployed (status: ENABLED)
[✅] Rules compile without errors
[✅] Test: Unauthenticated user → 403

CLOUD FUNCTIONS:
[✅] cloud_functions: ^6.3.3 installed
[✅] functions deployed
[✅] Env vars set (STRIPE_SECRET, AGORA_*)
[✅] Callable functions: 5/5 deployed
[✅] Webhook endpoint active
[✅] Test: generateAgoraToken works

PAYMENT (STRIPE):
[✅] flutter_stripe: ^12.0.0 installed
[✅] Stripe API key in functions
[✅] Webhook secret matches
[✅] Test: charge.succeeded → coins credited
[✅] /payments/{uid} write-protected

WEBRTC (AGORA):
[✅] agora_rtc_engine: 6.5.4 installed
[✅] AGORA_APP_ID in functions
[✅] AGORA_APP_CERTIFICATE (not public)
[✅] TURN/STUN servers returned
[✅] Test: Join room → audio works

STATE MANAGEMENT (RIVERPOD):
[✅] flutter_riverpod: ^2.5.1 installed
[✅] All Firebase via providers (no singletons)
[✅] Providers support .overrideWithValue()
[✅] Integration tests pass

HOSTING:
[✅] firebase.json CORS headers
[✅] Web app deployed
[✅] Service worker cache correct
[✅] Test: OAuth redirect works

OVERALL: ════════════════════════════════════ 100% ✅
```

#### 5.2 Rollout Strategy
```bash
# TIME: 10 minutes

# Option 1: Immediate (Full Propagation)
firebase deploy --only firestore:rules,functions,hosting
# Risk: HIGH (if issues, affects all users immediately)

# Option 2: Staged (Recommended)
# Phase A: Deploy functions → test for 1 hour
firebase deploy --only functions
# Phase B: Deploy rules → test for 1 hour  
firebase deploy --only firestore:rules
# Phase C: Deploy hosting (UI) → live
firebase deploy --only hosting
# Risk: MEDIUM (rollback at each phase)

# Option 3: Canary (Safest)
# Use Firebase Remote Config to route 5% of traffic to new backend
firebase remoteconfig:get
# Edit: Add feature flag "use_new_backend: false" (0% users)
# Gradually increase: 5% → 25% → 50% → 100%
# Monitor errors at each step
# Risk: LOW (can rollback instantly)

RECOMMENDED: Use Option 2 (Staged) for your case
```

#### 5.3 Live Monitoring (First 24 Hours)
```bash
# TIME: Ongoing

# 1. Set up console alerts
firebase functions:log | grep ERROR
# Watch: Any unexpected errors?

# 2. Monitor Stripe webhooks
# Stripe Dashboard → Logs → Check webhook delivery rate
# Expected: 100% success rate

# 3. Monitor Agora latency
# Agora Dashboard → Quality Data
# Expected: <100ms RTT (round trip time)

# 4. Check Firestore costs
# Firebase Console → Firestore → Usage
# Expected: No sudden spikes

# 5. Verify user reports
# Check support channel for issues
# Common issues:
#   - "Can't join room" → Check Agora token expiry
#   - "Payment not credited" → Check webhook logs
#   - "Adult room access denied" → Check verification status

# If CRITICAL issue: Immediate rollback
firebase deploy --only functions --rollback
```

---

## 🎯 Success Criteria

You'll know propagation is complete when:

✅ **All 4 Critical Flows Pass**
- Auth → Profile loads
- Room join → WebRTC audio/video works
- Payment → Coins credited within 30 seconds
- Adult verification → Gate enforces age restrictions

✅ **Security Gates Hold**
- Unauthenticated users get 403 on all reads
- Non-verified users cannot join adult rooms
- Attackers cannot write to payment docs
- Webhook signatures must be valid

✅ **Performance Meets SLA**
- Room list query: <2 seconds
- WebRTC connection: <5 seconds
- Payment processing: <30 seconds
- Stripe webhook delivery: 100%

✅ **Monitoring Active**
- Crashlytics reports errors
- Analytics events tracked
- Cost monitoring enabled
- Team alerts configured

✅ **Production Ready**
- No hardcoded Firebase singletons
- All Riverpod providers injectable
- Integration tests pass
- Documentation complete

---

## 🚨 If Something Goes Wrong

### Recovery Protocol

```bash
# Step 1: Identify the issue
firebase functions:log | tail -20
firebase firestore:backups:list
firebase billing

# Step 2: Rollback
# Option A: Rollback last deployment
firebase deploy --rollback

# Option B: Rollback specific component
firebase deploy --only functions --rollback
firebase deploy --only firestore:rules --rollback

# Step 3: Communicate
# - Post status update to #dev-alerts
# - Notify users if service impacted
# - Schedule post-mortem review

# Step 4: Debug & Redeploy
# Fix the issue locally
# Re-test all 4 critical flows
# Deploy again (staged approach)
```

---

## 📞 Quick Reference

| File | Purpose | Read Time |
|------|---------|-----------|
| INFRASTRUCTURE_DEPENDENCY_CHAIN.md | Deep dive: understand system architecture | 20 min |
| INFRASTRUCTURE_DEPENDENCY_CHAIN_DIAGRAMS.md | Quick visual reference | 5 min |
| PUBSPEC_BACKEND_ALIGNMENT.md | Pre-deployment validation checklist | 30 min |
| INFRASTRUCTURE_DEPENDENCY_CHAIN_EXECUTION_ROADMAP.md | This file: step-by-step execution plan | 10 min |

---

## 🎬 Next Actions (Choose Your Path)

### Path A: Deep Understanding First
```
1. Read: INFRASTRUCTURE_DEPENDENCY_CHAIN_DIAGRAMS.md (5 min)
2. Read: INFRASTRUCTURE_DEPENDENCY_CHAIN.md (20 min)
3. Execute Phase 1 (Pre-Propagation Validation)
4. Move to Phase 2-5
```

### Path B: Fast Track (Experienced Team)
```
1. Run: Pre-propagation checklist commands
2. Execute Phase 2 (Critical Flows)
3. Execute Phase 5 (Go-Live)
```

### Path C: Cautious Approach
```
1. Read: All 4 documentation files (1 hour)
2. Execute all phases sequentially with team review at each checkpoint
3. 24-hour post-launch monitoring
```

---

**Ready to begin? Start with:**
```bash
# Quick overview (5 minutes)
cat INFRASTRUCTURE_DEPENDENCY_CHAIN_DIAGRAMS.md

# Then run first validation
grep -r "FirebaseAuth.instance\|FirebaseFirestore.instance" lib/
firebase functions:list
flutter analyze
```

**Questions?** Refer back to the documentation index above or check the specific data flow section in INFRASTRUCTURE_DEPENDENCY_CHAIN.md.

---

**Status**: 🟢 **System Ready for Propagation**
