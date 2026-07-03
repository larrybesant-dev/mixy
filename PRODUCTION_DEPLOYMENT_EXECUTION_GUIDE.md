# Production Deployment Execution Guide (Post-IAM Fix)

**Status**: Ready to Execute  
**Trigger**: When project owner confirms "IAM fix complete"  
**Estimated Time**: 1 hour (45 min deployment + 15 min verification)  
**Date**: 2026-07-03  

---

## 🚀 EXECUTION TIMELINE

Once you receive confirmation **"IAM fix complete"** from project owner, follow this exact sequence:

### Phase 1: Deploy Cloud Functions (10 minutes)

```bash
cd c:\Users\LARRY\MIXVY

# Step 1: Deploy functions with updated IAM permissions
firebase deploy --only functions

# Expected output:
# ✅ validateMessageBlockEnforcement deployed
# ✅ validateConversationBlockEnforcement deployed
# ✅ Deploy complete!
```

**What to watch for**:
- ✅ No errors about "IAM policy"
- ✅ Both functions show as deployed
- ✅ No "permission denied" messages

**If it fails**: Review `DEPLOYMENT_GUIDE.md` Phase 1 troubleshooting section.

---

### Phase 2: Verify Deployment (5 minutes)

```powershell
# Run the automated verification script
cd c:\Users\LARRY\MIXVY
.\tools\verify_production_deployment.ps1

# Expected output:
# 🟢 READY FOR SOFT LAUNCH
# ✅ All Firebase services responding normally
# ✅ All critical Cloud Functions deployed
# ✅ Block enforcement active and enforced
```

**If you see 🟡 or 🔴**: Check the script output for diagnostics before proceeding to health checks.

---

### Phase 3: Rebuild Web App with GIPHY Key (5 minutes)

Before running manual tests, rebuild the web app with the GIPHY API key:

```bash
# Get your GIPHY production API key from https://developers.giphy.com/dashboard

# Build web app with GIPHY key
flutter build web --release \
  --dart-define=GIPHY_API_KEY='your_production_key_here' \
  --base-href '/'

# This will take ~5 minutes. Expected output:
# ✅ Building for web...
# ✅ Compiling application...
# ✅ Built build/web
```

**Note**: Replace `your_production_key_here` with actual GIPHY API key.

---

### Phase 4: Manual Health Check (10-15 minutes)

Follow **`PRODUCTION_VERIFICATION_CHECKLIST.md`** step-by-step:

1. **Register fresh account** (2 min)
   - Open app at production URL
   - Sign up with test email
   - Verify email

2. **Test Stripe integration** (3 min)
   - Navigate to wallet
   - Purchase 70 coins ($0.99)
   - Use test card: `4242 4242 4242 4242`
   - Verify coins appear in wallet
   - ✅ Confirms: Stripe is production key

3. **Test gift flow** (2 min)
   - Send a gift to another user
   - Verify coin balance decreased
   - Check Firestore: wallet_ledger shows transaction
   - ✅ Confirms: Balance tracking working

4. **Test messaging & block enforcement** (3 min)
   - Send message to another user
   - Block the user
   - Try to send another message
   - Check Firebase logs: `Message from blocked user deleted`
   - ✅ Confirms: Block enforcement active

5. **Test GIPHY (optional)** (2 min)
   - In message compose, look for GIF button
   - Search for "celebration"
   - Send GIF
   - ✅ Confirms: GIPHY key is production

---

### Phase 5: Final Go/No-Go Decision (2 minutes)

**✅ GO FOR SOFT LAUNCH if ALL pass:**
- ✅ Cloud Functions deployed without errors
- ✅ `verify_production_deployment.ps1` returned 🟢
- ✅ Fresh account registration works
- ✅ Stripe coin purchase succeeded (real charge)
- ✅ Gift sent and balance updated in Firestore
- ✅ Messages sent successfully
- ✅ Block enforcement triggered in logs
- ✅ GIFs loading (if tested)

**Result**: Proceed to invite first 50 users

**⚠️ CONDITIONAL GO if 1-2 failures:**
- Minor feature broken (e.g., GIPHY not loading)
- Core services (Stripe, Auth, Firestore) working
- Block enforcement active

**Result**: Proceed with known issue, fix in background

**❌ HOLD if 3+ failures or critical issues:**
- Stripe charge failed (sandbox key?)
- Block enforcement not triggering
- Messages not sending
- Cloud Functions not deployed

**Result**: Investigate, fix, re-run Phase 2-5 before launch

---

## 📋 COMPLETE EXECUTION CHECKLIST

Copy this and check off as you progress:

```
PRE-EXECUTION (Wait for project owner)
  [ ] Project owner confirms: "IAM fix complete"
  [ ] Note the time received

PHASE 1: DEPLOY (10 min)
  [ ] Run: firebase deploy --only functions
  [ ] ✅ Both functions deployed successfully
  [ ] ✅ No permission errors

PHASE 2: VERIFY (5 min)
  [ ] Run: .\tools\verify_production_deployment.ps1
  [ ] ✅ Returns: 🟢 READY FOR SOFT LAUNCH
  [ ] ✅ Note any warnings (optional features)

PHASE 3: REBUILD (5 min)
  [ ] Obtain GIPHY production API key
  [ ] Run: flutter build web --release --dart-define=GIPHY_API_KEY='...' --base-href '/'
  [ ] ✅ Build completes: "Built build/web"

PHASE 4: HEALTH CHECK (10-15 min)
  [ ] Test 1: Register new account → ✅ Success
  [ ] Test 2: Purchase coins → ✅ Stripe charged
  [ ] Test 3: Send gift → ✅ Balance decreased
  [ ] Test 4: Message + block → ✅ Enforcement triggered
  [ ] Test 5: GIF (optional) → ✅ Loading (or skipped)

PHASE 5: GO/NO-GO (2 min)
  [ ] Count passing tests: ___ / 5 core tests
  [ ] Decision: ✅ GO / 🟡 CONDITIONAL / ❌ HOLD
  [ ] Document result in ROLLOUT_STATUS.txt

POST-EXECUTION
  [ ] If GO: Send first 50 user invite list
  [ ] If CONDITIONAL: Document known issues
  [ ] If HOLD: Create ticket for investigation
```

---

## 🔑 GIPHY Key Setup Detail

### Get Your GIPHY Production Key

1. Go to [GIPHY Developers](https://developers.giphy.com/dashboard)
2. Sign in with your account
3. Click **Apps** → Your app name
4. Copy the **API Key** shown
5. ⚠️ **Verify** it does NOT say "sandbox" or "test" in the key or description

### Build with GIPHY Key

```bash
cd c:\Users\LARRY\MIXVY

# Option A: Inline (recommended for one-off builds)
flutter build web --release \
  --dart-define=GIPHY_API_KEY='pk_xxxxxxxxxxxxxxxx' \
  --base-href '/'

# Option B: Via file (if you have many dart-define values)
# Create file: giphy_keys.txt
# Content: GIPHY_API_KEY=pk_xxxxxxxxxxxxxxxx
flutter build web --release \
  --dart-define-from-file=giphy_keys.txt \
  --base-href '/'

# Option C: Via .env (if flutter_dotenv is set up)
# Add to .env: GIPHY_API_KEY=pk_xxxxxxxxxxxxxxxx
# (Already configured in lib/config/app_env.dart)
flutter build web --release --base-href '/'
```

### Verification

After build completes:
1. Open `build/web/index.html` locally
2. Navigate to message compose
3. Look for GIF button/icon
4. Search for a GIF
5. If GIF loads, GIPHY key is working ✅

---

## 🐛 Troubleshooting Quick Reference

### If Cloud Functions Won't Deploy

**Error**: "IAM policy failed" or "permission denied"
- **Cause**: Project owner didn't run gcloud commands OR ran them wrong
- **Fix**: Review `PROJECT_OWNER_QUICK_START.md`, have owner re-run commands

**Error**: "Function update failed"
- **Cause**: Syntax error in `functions/index.js`
- **Fix**: Run `npm test` in functions/ directory to check syntax

**Error**: "Timeout deploying functions"
- **Cause**: Large functions package or network issue
- **Fix**: Wait 5 minutes, try again. Check `firebase functions:log`

### If Verification Script Shows 🔴

**Common Issues**:
1. **"Cloud Functions not deployed"** → Run Phase 1 again
2. **"Firebase not responding"** → Check internet connection
3. **"Invalid project ID"** → Verify `.firebaserc` has `mix-and-mingle-v2`

### If Health Check Fails

**Stripe purchase fails**:
- [ ] Check if you're using real card vs test card
- [ ] Verify no billing address issues
- [ ] Check Stripe dashboard for errors
- [ ] Confirm `sk_live_` key (not `sk_test_`)

**Messages not sending**:
- [ ] Check Firestore rules: go to [Firebase Console → Firestore → Rules](https://console.firebase.google.com/project/mix-and-mingle-v2/firestore/rules)
- [ ] Look for permission denials in logs
- [ ] Verify user is authenticated

**Block enforcement not triggering**:
- [ ] Check Cloud Functions are deployed: `firebase functions:list`
- [ ] Check logs: [Firebase Console → Functions → Logs](https://console.firebase.google.com/project/mix-and-mingle-v2/functions/list)
- [ ] Verify blocks collection exists in Firestore

---

## 📞 Decision Point: After All Phases Complete

### If All Tests Pass ✅

**Message to send to stakeholders:**
```
🚀 MixVy Production Ready for Soft Launch

Cloud Functions deployed ✅
Security enforcement active ✅
Payment processing verified ✅
All core features tested ✅

Status: Ready to invite first 50 users

First user cohort selected. Invitations going out now.
Monitoring period: 24 hours
```

### If Issues Found ⚠️

**Document the issue:**
- What failed?
- When did it fail (Phase 1, 2, 3, 4, or 5)?
- What was the exact error?
- Screenshot of the error if possible

**Then either:**
1. Fix the issue and re-run from that phase
2. Investigate offline and try again tomorrow
3. Roll back: `git revert dd3b15fb && firebase deploy --only functions`

---

## 🎯 Success Criteria

You'll know you're ready for soft launch when:

| Criterion | Result |
|-----------|--------|
| Cloud Functions deployed | ✅ Both functions in Firebase Console |
| Verification script | 🟢 **READY FOR SOFT LAUNCH** |
| Fresh account registration | ✅ New user created, email verified |
| Stripe payment | ✅ Real charge appears on card |
| Coin balance | ✅ Coins added to wallet, visible in Firestore |
| Gift transaction | ✅ Balance decreased, gift_events recorded |
| Message delivery | ✅ Message sent, received by recipient |
| Block enforcement | ✅ Blocked message deleted, logs show deletion |
| GIFs (optional) | ✅ GIF loads from GIPHY CDN |

**All criteria met = 🟢 GO FOR SOFT LAUNCH**

---

## ⏱️ Timeline Summary

| Phase | Duration | Blocker | Status |
|-------|----------|---------|--------|
| **Await IAM Fix** | ~5 min (external) | Project Owner | ⏳ Waiting |
| **Phase 1: Deploy** | 10 min | None | ✅ Ready |
| **Phase 2: Verify** | 5 min | Phase 1 | ✅ Ready |
| **Phase 3: Rebuild** | 5 min | Phase 2 | ✅ Ready |
| **Phase 4: Health Check** | 10-15 min | Phase 3 | ✅ Ready |
| **Phase 5: Decision** | 2 min | Phase 4 | ✅ Ready |
| **TOTAL** | **~45 min** | Owner's IAM fix | ⏳ Waiting |

---

## 📝 Final Notes

- **No code changes needed** - Only deployment + configuration
- **All operations are non-destructive** - Can be repeated safely
- **Everything is reversible** - Can rollback if needed
- **Fully documented** - Each step has clear success criteria
- **Ready to execute** - All tools and scripts prepared

**You are fully prepared for production deployment.** 🚀

The moment you receive confirmation from the project owner, execute this guide in order and you'll be soft-launching within 1 hour.

---

**Document Version**: 1.0  
**Created**: 2026-07-03  
**Status**: READY TO EXECUTE
