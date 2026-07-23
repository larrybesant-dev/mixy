# MixVy Production Rollout: DevOps Operational Plan

**Status**: 🟡 PARTIALLY READY (Awaiting IAM Permission Fix)  
**Target**: First 50 users soft launch by 2026-07-04  
**Last Updated**: 2026-07-03  
**Role**: DevOps/QA Lead  

---

## Executive Summary

✅ **Code is production-ready**  
✅ **Integration tests passing (33 seconds)**  
✅ **Firestore rules deployed with moderation foundation**  
❌ **Cloud Functions blocked by GCP IAM permissions**  
⏳ **Awaiting project owner to grant service account permissions**  

**Time to Soft Launch**: ~2-3 hours (1 hour for IAM fix + 1-2 hours for verification)

---

## Critical Path to Launch

### Step 1: Fix IAM Permissions (15 minutes) - **PROJECT OWNER ONLY**

**File**: `DEPLOYMENT_GUIDE.md` → "Phase 1: Cloud Functions IAM Fix"

**Action**: Project owner copies and pastes these 3 gcloud commands:
```bash
gcloud projects add-iam-policy-binding mixvy-v2 \
  --member=serviceAccount:service-770164332233@gcp-sa-pubsub.iam.gserviceaccount.com \
  --role=roles/iam.serviceAccountTokenCreator

gcloud projects add-iam-policy-binding mixvy-v2 \
  --member=serviceAccount:770164332233-compute@developer.gserviceaccount.com \
  --role=roles/run.invoker

gcloud projects add-iam-policy-binding mixvy-v2 \
  --member=serviceAccount:770164332233-compute@developer.gserviceaccount.com \
  --role=roles/eventarc.eventReceiver
```

**Verification**: After running, check:
```bash
gcloud projects get-iam-policy mixvy-v2
```

Should show the three new service account entries.

**Time**: 5 minutes (command execution) + 5 minutes (verification)

---

### Step 2: Deploy Cloud Functions (10 minutes)

**After IAM fix is confirmed**, run:

```bash
cd c:\Users\LARRY\MIXVY
firebase deploy --only functions
```

**Expected Output**:
```
✅ validateMessageBlockEnforcement deployed
✅ validateConversationBlockEnforcement deployed
```

**Verification**: 
```bash
firebase functions:list
```

Should show both functions in the list.

**Time**: 10 minutes (includes Google Cloud build time)

---

### Step 3: Run Post-Deployment Verification (5 minutes)

**File**: `tools/verify_production_deployment.ps1`

```powershell
cd c:\Users\LARRY\MIXVY
.\tools\verify_production_deployment.ps1
```

**Expected Output**:
```
✅ READY FOR SOFT LAUNCH
✅ All Firebase services responding normally
✅ All critical Cloud Functions deployed
✅ Block enforcement active
```

If you see 🟡 or 🔴, review the script output for next steps.

**Time**: 2 minutes

---

### Step 4: Run Production Health Checklist (10 minutes)

**File**: `PRODUCTION_VERIFICATION_CHECKLIST.md`

This is a **manual workflow test** you perform in the browser as a real user:

1. **Register** a fresh account
2. **Purchase coins** via Stripe
3. **Send a gift** (verifies balance tracking)
4. **Send a message**
5. **Block a user** and verify enforcement (check Firebase logs)
6. **Test GIPHY** integration (if using GIFs)

Each test takes 1-2 minutes. Total: 10 minutes.

**Success Criteria**:
- ✅ All 5 core tests pass
- ✅ Coins deducted from wallet (verify in Firestore)
- ✅ Messages appear in conversation thread
- ✅ Block enforcement logs appear in Cloud Functions logs

**Time**: 10 minutes

---

### Step 5: Audit Production Keys (5 minutes)

**File**: `PRODUCTION_KEY_AUDIT.md`

Quick verification that you're using **production keys**, not sandbox:

- ✅ GIPHY key = production (not sandbox)
- ✅ Stripe = `sk_live_` (not `sk_test_`)
- ✅ Agora = production credentials
- ✅ Firebase = mixvy-v2 project
- ✅ Auth domain = production domain

**Time**: 5 minutes

---

## Operational Documents

All files are **read-only** and safe to run multiple times. No modifications to code or production data.

| Document | Purpose | Time | Role |
|----------|---------|------|------|
| `DEPLOYMENT_GUIDE.md` | IAM fix + Cloud Functions deployment | 25 min | Project Owner + DevOps |
| `PRODUCTION_KEY_AUDIT.md` | Verify production credentials | 5 min | DevOps/QA |
| `PRODUCTION_VERIFICATION_CHECKLIST.md` | Manual health check | 10 min | QA/You |
| `tools/verify_production_deployment.ps1` | Automated endpoint verification | 5 min | DevOps |

---

## Go/No-Go Decision Points

### ✅ GO FOR SOFT LAUNCH IF:

- [ ] Cloud Functions deployed successfully (both functions appear in Firebase Console)
- [ ] `verify_production_deployment.ps1` shows 🟢 **READY FOR SOFT LAUNCH**
- [ ] All 5 tests in `PRODUCTION_VERIFICATION_CHECKLIST.md` pass
- [ ] Production keys audit passes (no sandbox keys)
- [ ] Block enforcement triggered in Firebase logs

**Result**: → Invite first 50 users

### ⚠️ CONDITIONAL LAUNCH IF:

- [ ] Core services healthy but GIPHY/Agora optional features unavailable
- [ ] All payment/moderation flows working but video optional

**Result**: → Soft launch, fix video/GIFs in background

### ❌ HOLD IF:

- [ ] Stripe keys are sandbox (`sk_test_`)
- [ ] Block enforcement not triggering (moderation blocker)
- [ ] Firestore rules in test mode
- [ ] More than 2 functions not deployed

**Result**: → Continue investigation, do not launch

---

## Timeline: Best Case Scenario

| Task | Duration | Status |
|------|----------|--------|
| IAM permission fix (gcloud) | 15 min | ⏳ Awaiting project owner |
| Cloud Functions deployment | 10 min | ⏳ Pending IAM fix |
| Post-deployment verification script | 5 min | ✅ Ready to run |
| Production key audit | 5 min | ✅ Ready to run |
| Health check + manual tests | 10 min | ✅ Ready to run |
| **Total Time to Soft Launch** | **~45 min** | ⏳ In progress |

**Earliest soft launch**: 2026-07-03 end-of-day (today) or 2026-07-04 morning

---

## Risk Mitigation

### If IAM Fix Fails

**Plan B**: Deploy via Firebase Console
1. Go to [Firebase Console → Functions](https://console.firebase.google.com/project/mixvy-v2/functions/list)
2. Functions should appear as "pending"
3. Click each → **Deploy**
4. Monitor deployment status

### If Deployment Still Blocks

**Plan C**: Rollback (no impact to users)
```bash
git revert dd3b15fb
firebase deploy --only functions
```

This removes block enforcement functions but keeps everything else working.

### If Verification Fails

**Checklist**:
- [ ] Run `firebase functions:log` to check for function errors
- [ ] Check [Firebase Console → Firestore → Rules](https://console.firebase.google.com/project/mixvy-v2/firestore/rules) for rule errors
- [ ] Verify project ID correct: `cat .firebaserc`
- [ ] Verify authentication: `firebase login`

---

## Soft Launch Strategy (First 50 Users)

Once operational checks pass:

1. **Invite 50 trusted people** (friends, team, early adopters)
2. **Monitor Firestore logs** for errors (first 24 hours)
3. **Watch for report** of:
   - Payment failures
   - Video latency/drops
   - Moderation blocks failing
   - App crashes
4. **Be ready to rollback** if critical issue found
5. **Track metrics**: DAU, feature usage, errors

---

## Monitoring & Support

### During Soft Launch (First 24 Hours)

- [ ] Monitor [Firebase Console → Logs](https://console.firebase.google.com/project/mixvy-v2/functions/list)
- [ ] Check error rate in Cloud Functions
- [ ] Monitor Firestore read/write quota
- [ ] Respond quickly to user reports

### Key Logs to Watch

**Block Enforcement Logs**:
```
Cloud Functions → validateMessageBlockEnforcement → Logs
Search: "Message from blocked user deleted"
```

**Payment Logs**:
```
Cloud Functions → sendDirectGift → Logs
Search: "transaction" or "error"
```

**Auth Logs**:
```
Firebase Console → Authentication → Activity
Monitor for login errors
```

---

## Communication to Project Owner

**For the project owner** — provide them with this message:

> To proceed with MixVy soft launch, please run these 3 gcloud commands (takes 5 minutes):
> 
> ```bash
> gcloud projects add-iam-policy-binding mixvy-v2 \
>   --member=serviceAccount:service-770164332233@gcp-sa-pubsub.iam.gserviceaccount.com \
>   --role=roles/iam.serviceAccountTokenCreator
> 
> gcloud projects add-iam-policy-binding mixvy-v2 \
>   --member=serviceAccount:770164332233-compute@developer.gserviceaccount.com \
>   --role=roles/run.invoker
> 
> gcloud projects add-iam-policy-binding mixvy-v2 \
>   --member=serviceAccount:770164332233-compute@developer.gserviceaccount.com \
>   --role=roles/eventarc.eventReceiver
> ```
> 
> After running, reply with: "IAM fix complete"
> 
> Then we'll deploy and soft-launch within 1 hour.

---

## Rollout Verification Readiness: Summary

| Component | Status | Action | Blocker |
|-----------|--------|--------|---------|
| Code ready | ✅ | None | No |
| Integration tests | ✅ Passing (33s) | None | No |
| Firestore rules | ✅ Deployed | None | No |
| Cloud Functions (code) | ✅ Committed | Deploy | **YES** |
| Cloud Functions (IAM) | ❌ Pending | gcloud commands | **YES** |
| Stripe integration | ✅ Ready | Verify keys | No |
| Agora integration | ✅ Ready | Verify keys | No |
| GIPHY integration | ✅ Ready | Verify keys | No |
| Moderation | ✅ Ready | Verify logs | No |
| Block enforcement | ✅ Implemented | Deploy functions | **YES** |
| Production URL | ✅ Live | Test access | No |

**Blockers**: 1 item (Cloud Functions IAM) - depends on project owner action

---

## Next Action Item

**Immediate Task** (for you):
1. Send the IAM fix commands to the project owner
2. Bookmark these operational documents:
   - `DEPLOYMENT_GUIDE.md`
   - `PRODUCTION_VERIFICATION_CHECKLIST.md`
   - `PRODUCTION_KEY_AUDIT.md`
   - `tools/verify_production_deployment.ps1`
3. Wait for project owner to respond "IAM fix complete"

**Once Approved**:
1. Run `firebase deploy --only functions`
2. Run `.\tools\verify_production_deployment.ps1`
3. Run manual health checks from `PRODUCTION_VERIFICATION_CHECKLIST.md`
4. Report back: "Ready for soft launch" or "Issues found"

---

**DevOps Lead Approval**: _________________ (you)  
**Date**: 2026-07-03  
**Next Review**: 2026-07-04 (post-deployment)
