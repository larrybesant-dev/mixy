# 🧪 PRODUCTION HEALTH CHECK - EXECUTION GUIDE

**Date**: July 3, 2026  
**Objective**: Verify production readiness before 50-user soft launch

---

## ✅ VERIFIED (NO ACTION NEEDED)

✅ **All Cloud Functions Deployed & Live**
```
firebase functions:list
Result: 33/33 functions active, including:
  - validateMessageBlockEnforcement (Firestore trigger)
  - validateConversationBlockEnforcement (Firestore trigger)
```

✅ **Infrastructure Ready**
- Firestore database: Online
- Firebase Hosting: Online (mixvy-v2.web.app)
- Firebase Auth: Configured
- Stripe API: Production key in Secret Manager (sk_live_)
- Agora RTC: Configured (v6.5.4)
- GIPHY API: Deployed (4Isdjl1CFKmyTwW9R67RTFvzX2GEAfLCk)

---

## 🔧 TEST SETUP (Manual - Via Firebase Console)

### Step 1: Create Test Accounts
1. Go to https://console.firebase.google.com/project/mixvy-v2/authentication/users
2. Click **"Add User"** (top right)
3. Create 3 accounts:

| # | Email | Password | Role |
|---|-------|----------|------|
| A | test_a_prod@example.com | ProdTest@2026! | Blocker |
| B | test_b_prod@example.com | ProdTest@2026! | Blocked |
| C | test_c_prod@example.com | ProdTest@2026! | Gift Recipient |

---

## 📝 TEST EXECUTION (5 Tests)

### **Test 1: Registration Pipeline** ✅ DOMAIN VERIFIED
- **What**: User account creation flow
- **Status**: Firebase Auth configured and running
- **Verification**: Accounts created in Step 1 above confirm pipeline works
- **Pass Criteria**: Accounts appear in Firebase Console

---

### **Test 2: Stripe Payment** 🔑 CRITICAL
**Objective**: Confirm production-level Stripe integration (sk_live_)

**Steps**:
1. Log in with Test Account A (test_a_prod@example.com)
2. Navigate to **Wallet** / **Buy Coins**
3. Use test card: `4242 4242 4242 4242`
4. Expiry: `12/25`
5. CVC: `123`
6. **Expected**:
   - ✅ Payment processes immediately
   - ✅ Coins appear in wallet
   - ✅ Transaction logged in Firestore `walletBalances` collection

**Verification Commands**:
```bash
# Check Stripe transactions
firebase firestore:describe walletBalances/test_a_prod@example.com

# Check payment logs
firebase functions:log | grep "recordStripePaymentSuccess"
```

---

### **Test 3: Gift Transaction** 💝
**Objective**: Verify Firestore balance tracking

**Steps**:
1. Logged in as Test Account A
2. Find Test Account C in app
3. Send gift (1 coin) to Account C
4. **Expected**:
   - ✅ A's balance decreases by 1 coin
   - ✅ C's balance increases by 1 coin (minus 15% platform fee)
   - ✅ `giftTransactions` collection logs entry

**Verification**:
```bash
firebase firestore:describe giftTransactions
```

---

### **Test 4: Block Enforcement** 🚨 CRITICAL - NEW FEATURE

**Objective**: Verify automatic block enforcement via Cloud Functions

**Prerequisites**:
- Test Account A logged in
- Test Account B exists
- A shared conversation/room for A and B

**Steps**:

1. **Setup**: A and B in same conversation
2. **Send message**: B sends message → ✅ appears
3. **Block user**: A blocks B (via Moderation Service)
4. **Attempt message**: B tries to send message

**Monitoring** (Real-time):
```bash
# Terminal 1: Watch Cloud Function logs
firebase functions:log --only validateMessageBlockEnforcement

# Expected output:
# INFO: validateMessageBlockEnforcement triggered
# INFO: Sender test_b_prod@example.com blocked by participant test_a_prod@example.com
# INFO: Message deleted (enforcement)
```

**Verification**:
- [ ] Message sent by B does NOT appear in Firestore
- [ ] Cloud Function log shows deletion
- [ ] No errors in function execution

**Pass Criteria**:
```
Function execution: SUCCESS
Block enforcement: TRIGGERED
Message deletion: CONFIRMED
```

---

### **Test 5: GIPHY Integration** 🖼️

**Objective**: Verify GIF loading works

**Steps**:
1. Open message composer in any conversation
2. Click **GIF icon**
3. Search for "hello"
4. **Expected**:
   - ✅ GIFs load from GIPHY API
   - ✅ Grid displays thumbnails
   - ✅ Can select and send GIF

**Verification**:
```bash
# Check GIPHY API calls in logs
firebase functions:log | grep -i "giphy"
```

---

## 🎯 GO/NO-GO DECISION

### ✅ **GO FOR SOFT LAUNCH IF**:
- [ ] Test 1: Firebase Auth working (confirmed by account creation)
- [ ] Test 2: Stripe charge succeeds with real production key
- [ ] Test 3: Gift balance transfers correctly
- [ ] Test 4: Block enforcement deletes messages (watch Cloud Function logs)
- [ ] Test 5: GIFs load from GIPHY API

### 🟡 **PROCEED WITH CAUTION IF**:
- [ ] GIPHY rate-limited (100 calls/hour on Beta) → upgrade tier
- [ ] One non-critical test fails → can fix with hotfix

### ❌ **ABORT IF**:
- [ ] Test 2: Stripe payment FAILS (production key issue)
- [ ] Test 4: Block enforcement doesn't trigger (Cloud Function broken)
- [ ] Multiple critical features broken

---

## 📊 TEST RESULTS TEMPLATE

**Date/Time**: ______________  
**Tester**: ______________

| # | Test | Status | Notes |
|---|------|--------|-------|
| 1 | Registration | ⏳ Pass / ⏳ Fail | |
| 2 | Stripe Payment | ⏳ Pass / ⏳ Fail | Amount: $_____ |
| 3 | Gift Transaction | ⏳ Pass / ⏳ Fail | Coins: _____ |
| 4 | Block Enforcement | ⏳ Pass / ⏳ Fail | Function triggered: Y/N |
| 5 | GIPHY | ⏳ Pass / ⏳ Fail | |

**Overall**: 🟢 GO / 🟡 CAUTION / 🔴 NO-GO

---

## 🔍 MONITORING DURING SOFT LAUNCH

Keep these tabs open for first 24 hours:

1. **Cloud Function Logs**:
   ```bash
   firebase functions:log --follow
   ```

2. **Firestore Activity**:
   https://console.firebase.google.com/project/mixvy-v2/firestore/data

3. **Stripe Dashboard**:
   https://dashboard.stripe.com/payments (production)

4. **Error Tracking**:
   ```bash
   firebase functions:log | grep -i "error"
   ```

---

## 🚨 QUICK ROLLBACK PLAN

If critical issues found:

```bash
# Revert web app
cd build/
git checkout main  # Restore previous build

# Revert Cloud Functions
firebase deploy --only functions --force
```

---

## ✉️ NEXT STEPS

1. **CREATE ACCOUNTS** (Step 1 above via Firebase Console)
2. **RUN TESTS 1-5** (Follow execution guide)
3. **COLLECT RESULTS** (Use test results template)
4. **MAKE GO/NO-GO CALL** (Based on results)
5. **LAUNCH TO 50 USERS** (If GO decision)

---

**Prepared by**: GitHub Copilot  
**Status**: Ready for manual execution
**Time Est**: 15-20 minutes for all 5 tests
