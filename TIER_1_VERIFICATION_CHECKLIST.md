# Tier 1 Verification Checklist
**Status**: Pre-Rollout Validation  
**Date**: 2026-07-03  
**Objective**: Verify Gift Flow, Moderation, and Production Keys before inviting first wave of users

---

## 1. Production API Keys Verification

### 1.1 GIPHY API Key Status
- **Current Config**: `lib/config/app_env.dart` reads `GIPHY_API_KEY` via dart-define
- **How to Verify**:
  - [ ] Check `.github/workflows/deploy_firebase_hosting.yaml` for GIPHY_API_KEY env var
  - [ ] Confirm secret is marked as **production key** (not sandbox)
  - [ ] **Action**: If sandbox, request production key swap from GIPHY Dashboard
- **Expected**: 
  ```
  GIPHY_API_KEY=dc6zaTOxFJmzC (or your actual production key)
  ```
- **Impact**: Sandbox keys have rate limits and watermarks. Production keys required for rollout.

### 1.2 Stripe Production Status
- **Status**: ✅ Confirmed active (per your earlier statement)
- **Verification**: Check `stripe.com/dashboard` → API Keys for **Live** mode keys
- **Expected**: Using `pk_live_*` publishable keys, not `pk_test_*`

### 1.3 Agora Production Status
- **Status**: ✅ Confirmed live (app is currently operational)
- **Verification**: `lib/config/app_env.dart` → `agoraAppId`
- **Expected**: Points to live Agora RTC project, not sandbox

### 1.4 Firebase Production Status
- **Status**: ✅ Confirmed active billing + Firestore ops
- **Verification**: Already validated in previous conversations
- **Expected**: Production Firestore project (not emulator)

---

## 2. Gift Flow Verification

### 2.1 Backend Implementation ✅ CONFIRMED
**Code**: `functions/index.js` - `sendDirectGiftHandler()`
- ✅ Validates sender has sufficient coin balance
- ✅ Applies 15% platform fee
- ✅ Records transaction in `gift_events` collection
- ✅ Creates ledger entries (`wallet_ledger`)
- ✅ Updates both sender and receiver balances atomically

### 2.2 Frontend Implementation ✅ CONFIRMED
**Code**: `lib/widgets/gift_picker_sheet.dart`
- ✅ Gift grid UI with coin cost display
- ✅ Calls `FirebaseFunctions.instance.httpsCallable('sendDirectGift')`
- ✅ Passes: `receiverId`, `giftId`, `coinCost`, `senderName`
- ✅ Error handling for insufficient balance & failed sends

### 2.3 Notification System
- [ ] **Verify**: After sending gift, recipient receives notification
  - Check: `lib/services/push_messaging_service.dart` for gift notification triggers
  - Expected: FCM push when gift_events created
- [ ] **Test**: Send test gift → check device notifications
- [ ] **Fallback**: In-app notification in notifications screen

### 2.4 Coin Balance UI
- [ ] **Verify**: `lib/widgets/coin_balance_widget.dart` displays current balance
- [ ] **Test**: Send gift → balance decreases for sender, increases for receiver
- [ ] **Expected**: Instant UI update after function returns

### Manual Test Plan (30 minutes)
```
Prerequisite: Two test accounts (Account A: sender, Account B: receiver)
             Account A must have ≥100 coins

1. Login as Account A
2. Navigate to Account B's profile (via discovery or direct link)
3. Tap "Send Gift" button
4. Select a gift (e.g., 50-coin rose)
5. Confirm send
   - ✓ UI shows success
   - ✓ Coin balance decreases for Account A
   - ✓ No errors in console
6. Switch to Account B
7. Verify:
   - ✓ Coin balance increased
   - ✓ Notification received (FCM or in-app)
   - ✓ Gift visible in notifications/history
8. Check backend:
   - ✓ `firebase -> Firestore -> gift_events` has new record
   - ✓ `wallet_ledger` shows transaction
```

---

## 3. Moderation Flow Verification

### 3.1 Backend Implementation Status ⚠️ PARTIAL
**Frontend Code**: `lib/services/moderation_service.dart`
- ✅ `blockUser(targetId)` - writes to `blocks` collection
- ✅ `isBlocked(targetId)` - checks if user is blocked
- ✅ `reportTarget(targetId, reason, details)` - writes to `reports` collection
- ✅ `watchRecentReports()` - streams reports for dashboard

**Backend Code**: `functions/index.js`
- ✅ `classifyNewReport()` - text classification on new reports
- ⚠️ **MISSING**: No explicit enforcement of blocks in messaging/rooms

### 3.2 Block Enforcement Gap Analysis ⚠️ CRITICAL GAP FOUND
**Current**: Blocks are recorded in `blocks` collection but NOT enforced in Firestore rules
**Risk**: User A blocks User B, but User B can still:
  - Send messages to User A (rules don't check blocks on message create)
  - Join rooms with User A (rules don't check blocks)
  - Appear in User A's conversations (rules don't check blocks)

**Root Cause**: 
- `isConversationParticipant()` in `firestore.rules` only checks if user is in `participantIds`
- No call to check if blocked between participants
- Same gap in room access rules

**Fix Required**: (2-3 hours)
Add `isNotBlocked()` helper to `firestore.rules`:
```firestore
function isNotBlocked(otherUserId) {
  return !(
    exists(/databases/$(database)/documents/blocks/$(uid())_$(otherUserId))
    || exists(/databases/$(database)/documents/blocks/$(otherUserId)_$(uid()))
  );
}
```

Then update conversation/room rules to check:
- `canAccessConversationById()` → add `&& isNotBlocked(...)`
- Room read/join → add block check
- Message create → add block check

**Action Items** (BLOCKING FOR ROLLOUT):
- [ ] Review and confirm gap in `firestore.rules` (lines 102-110)
- [ ] Implement `isNotBlocked()` helper
- [ ] Add block checks to:
  - Message create rule (line 884)
  - Conversation read rule (line 873)
  - Room read/join rules
- [ ] Deploy updated rules to Firebase
- [ ] Test: Blocked user cannot message/create conversation
- [ ] Re-verify manual test after fix

### 3.3 Report Moderation UI ✅ CONFIRMED
**Code**: `lib/presentation/screens/moderation_dashboard_screen.dart`
- ✅ Dashboard accessible from drawer
- ✅ Can filter reports by status (pending, approved, rejected)
- ✅ Can update report status
- ✅ Shows report details (reason, target, reporter)

### 3.4 Moderation Triggers
- [ ] **Verify**: User can tap "Block" on another user's profile
- [ ] **Verify**: User can tap "Report" on profile/room/message
- [ ] **Verify**: Reports auto-classified by `classifyModerationText()`

### Manual Test Plan (20 minutes)
```
Prerequisite: Two test accounts (Account A: reporter, Account B: target)

Flow 1: Block User
1. Login as Account A
2. View Account B's profile
3. Tap "Block User" button
   - ✓ Button state changes to "Unblock"
   - ✓ Account B removed from feed/suggestions
4. Check Firestore:
   - ✓ `blocks` collection has entry: `${accountAId}_${accountBId}`

Flow 2: Report User
1. View Account B's profile
2. Tap "Report" (usually 3-dot menu)
3. Select reason (e.g., "Inappropriate behavior")
4. Add details
5. Submit
   - ✓ Success message shown
   - ✓ No console errors
6. Check Firestore:
   - ✓ `reports` collection has new record
   - ✓ `moderationReview` field populated with classification
7. Login to moderation dashboard
   - ✓ Can see report in list
   - ✓ Can filter/search
   - ✓ Can update status to "approved" or "rejected"
```

---

## 4. Production Readiness Outcomes

| Component | Status | Confidence | Action Required |
|-----------|--------|------------|-----------------|
| Gift Flow (Backend) | ✅ Ready | High | Test manually (30 min) |
| Gift Flow (Frontend) | ✅ Ready | High | Test manually (30 min) |
| Moderation Flow (Blocks) | ❌ **BROKEN** | Critical | **Implement block enforcement in Firestore rules (2-3 hours)** |
| Moderation Flow (Reports) | ✅ Ready | High | Test manually (20 min) |
| GIPHY API Key | ❓ Unknown | Low | Verify in CI secrets |
| Stripe Integration | ✅ Ready | High | Already live |
| Agora Integration | ✅ Ready | High | Already live |

---

## 5. Success Criteria for Rollout

- [ ] ✅ Gift sent successfully (balance transfers, ledger updated)
- [ ] ✅ **Block enforcement works** (blocked user cannot message/create conversation)
- [ ] ✅ Report triggers classification and appears in dashboard
- [ ] ✅ GIPHY key is production (not sandbox)
- [ ] ✅ No console errors during manual testing
- [ ] ✅ Notifications deliver on all devices (iOS, Android, Web)

---

## 6. CRITICAL FIX: Block Enforcement in Firestore Rules

### Problem
Blocks are UI+data, but not enforced by Firestore security rules. A user who is blocked can still message you or create conversations with you.

### Implementation (2-3 hours)

**File**: `firestore.rules`

**Step 1**: Add helper function (after line 110, before room rules)
```firestore
function isNotBlocked(otherUserId) {
  // Returns true if current user is NOT blocked by otherUserId and vice versa
  return !(
    exists(/databases/$(database)/documents/blocks/$(uid())_$(otherUserId))
    || exists(/databases/$(database)/documents/blocks/$(otherUserId)_$(uid()))
  );
}
```

**Step 2**: Update conversation access (line 108-110)
```firestore
function canAccessConversationById(conversationId) {
  return exists(/databases/$(database)/documents/conversations/$(conversationId))
    && isConversationParticipant(conversationDoc(conversationId).data)
    && conversationDoc(conversationId).data.participantIds.all((pid) => 
         pid == uid() || isNotBlocked(pid)
       );
}
```

**Step 3**: Message create - add block check (line 884)
```firestore
allow create: if signedIn()
  && canAccessConversationById(conversationId)
  && isNotBlocked(resource.data.recipientId) // Add this
  && ... rest of conditions
```

**Step 4**: Deploy & Test
```bash
firebase deploy --only firestore:rules
# Test: blocked user tries to message → denied with permission-denied error
```

### Test After Fix
```
1. Login as User A
2. Block User B (User A blocks B)
3. Login as User B in different browser
4. Try to send message to User A → Should fail with "permission-denied"
5. Try to create conversation with User A → Should fail
6. Unblock from User A's side
7. Try again → Should succeed
```

---

## 7. Rollout Decision Tree

```
Start: Fix block enforcement in firestore.rules (2-3 hours)
  │
  ├─ Block fix deployed?
  │  ├─ YES → Run manual tests (1 hour total)
  │  └─ NO  → Block everything until fixed (critical safety issue)
  │
  ├─ All manual tests pass?
  │  ├─ YES → Gift flow + Moderation ready
  │  │       Ready for TIER 2: Dismissed card persistence
  │  │       Schedule rollout for end of week
  │  │
  │  └─ NO → Document failures
  │         Prioritize by user impact
  │         Fix + retest before rollout
  │
  └─ GIPHY key is production?
     ├─ YES → Proceed
     └─ NO  → Swap to production key + rebuild + retest
```

---

## 8. Notes & Actions

**IMMEDIATE - BLOCKING (Before any rollout)** 🚨:
- [ ] **Implement block enforcement** in `firestore.rules` (see Section 6)
- [ ] Deploy updated rules: `firebase deploy --only firestore:rules`
- [ ] Test: Blocked user cannot message → Permission denied
- [ ] **ETA: 2-3 hours**

**Today - Pre-Rollout Verification**:
- [ ] Check GIPHY key status in GitHub secrets
- [ ] Verify block enforcement deployed successfully
- [ ] Run manual gift flow test (30 min)
- [ ] Run manual moderation + report test (20 min)

**This Week - Before Rollout**:
- [ ] If issues found, fix + retest
- [ ] Final sign-off on all infrastructure
- [ ] Brief your support team on moderation dashboard

**Week 2 - Post-Rollout**:
- [ ] Implement dismissed cards state persistence (Tier 2)
- [ ] Monitor logs for first 48 hours
- [ ] Be ready to escalate if critical issue found
