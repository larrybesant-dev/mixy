# 🔍 Soft Launch Monitoring Plan - 24-Hour Critical Watch

**Launch Date:** July 3, 2026  
**Duration:** 24 hours (continuous monitoring)  
**Target Users:** 50 beta testers  
**Status:** Active

---

## 📊 Real-Time Monitoring Checklist

### Cloud Logs - Real-Time
- [ ] **Firebase Console URL:** https://console.firebase.google.com/project/mixvy-v2/functions/logs
- [ ] Set filter: `severity >= ERROR`
- [ ] Watch for: Unhandled exceptions, timeouts, permission errors
- [ ] Action: Alert immediately if error rate spikes >1% of requests

### Function-Specific Monitoring

#### 🔐 Block Enforcement (`checkBlockStatus`)
- **Type:** HTTP Callable
- **Critical Metric:** Error rate
- **Watch For:**
  - `UNAUTHENTICATED` (auth token issues)
  - `PERMISSION_DENIED` (Firestore Rules blocking)
  - `NOT_FOUND` (conversation doesn't exist)
- **Action:** Log any failures with conversation ID for debugging
- **Logs:** https://console.firebase.google.com/project/mixvy-v2/functions/logs?functionName=checkBlockStatus

#### 💳 Payment Processing (`recordStripePaymentSuccess`)
- **Type:** Firestore Trigger
- **Critical Metric:** Success rate (should be 100%)
- **Watch For:**
  - Stripe webhook failures
  - Database write errors
  - Amount/fee calculation errors
- **Action:** Flag any payment that doesn't complete
- **Logs:** https://console.firebase.google.com/project/mixvy-v2/functions/logs?functionName=recordStripePaymentSuccess

#### 🎁 Gift Transfers (`sendDirectGift`)
- **Type:** Cloud Function
- **Critical Metric:** Transaction completion
- **Watch For:**
  - Insufficient balance errors
  - Recipient not found
  - Fee calculation errors
- **Action:** Each failed gift transfer needs investigation
- **Logs:** https://console.firebase.google.com/project/mixvy-v2/functions/logs?functionName=sendDirectGift

#### 👤 User Registration
- **Type:** Firebase Auth
- **Critical Metric:** Account creation success
- **Watch For:**
  - Email validation failures
  - Duplicate account attempts
  - Auth state inconsistencies
- **Action:** Monitor auth dashboard for anomalies
- **Dashboard:** https://console.firebase.google.com/project/mixvy-v2/authentication/users

---

## 🚨 Early Warning Signs

| Signal | Severity | Action | Response Time |
|--------|----------|--------|----------------|
| Error rate >1% | 🔴 CRITICAL | Page on-call engineer | Immediate |
| Block enforcement fails | 🔴 CRITICAL | Investigate w/ checkBlockStatus logs | 5 min |
| Payment processing errors | 🔴 CRITICAL | Stripe webhook audit + manual reconciliation | 15 min |
| Auth token failures | 🟡 WARNING | Check Firebase token expiry settings | 30 min |
| Slow function responses (>2s) | 🟡 WARNING | Check Firestore query performance | 30 min |
| High memory usage (>300MB) | 🟡 WARNING | Check for memory leaks | 1 hour |

---

## 📋 User Feedback Protocol

### Block Enforcement Incidents
**If user reports:** "I can message someone who blocked me" or "A blocked user messaged me"

**Immediate Action:**
1. Get conversation ID from user
2. Check Firebase Functions logs for `checkBlockStatus` call
3. Look for error responses or calls not being made
4. Verify block relationship exists in Firestore
5. Check Firestore Rules deployment status
6. Run diagnostic: `node test_block_http.mjs`

**Debug Command:**
```bash
gcloud functions logs read checkBlockStatus --limit 50 --project=mixvy-v2
```

### Payment Issues
**If user reports:** "My payment didn't go through" or "Coins not received"

**Immediate Action:**
1. Check Stripe dashboard for transaction record
2. Query Firestore payments collection for user
3. Check Cloud Function logs for `recordStripePaymentSuccess`
4. Verify coin balance in user profile
5. Run manual reconciliation if needed

**Debug Command:**
```bash
gcloud functions logs read recordStripePaymentSuccess --limit 50 --project=mixvy-v2
```

### Registration/Auth Issues
**If user reports:** "Can't create account" or "Login not working"

**Immediate Action:**
1. Check Firebase Authentication users dashboard
2. Look for failed auth events in Console Logs
3. Verify email isn't already registered
4. Check for auth rule violations
5. Restart auth flow with user

**Debug URL:**
```
https://console.firebase.google.com/project/mixvy-v2/authentication/users
```

---

## 🔧 Quick Diagnostic Commands

### Check Block Enforcement Endpoint
```bash
node test_block_http.mjs
```

### View Recent Function Errors
```bash
gcloud functions logs read --limit 100 --project=mixvy-v2 | grep ERROR
```

### Check Firestore Rules Status
```bash
firebase firestore:rules:print --project=mixvy-v2
```

### List Active Functions
```bash
firebase functions:list --project=mixvy-v2
```

### Deploy Hotfix (if needed)
```bash
firebase deploy --only functions:functionName --project=mixvy-v2
```

---

## 📈 Metrics to Track

### Every 1 Hour
- [ ] Function error rate (target: <0.1%)
- [ ] Average function latency (target: <500ms)
- [ ] Firestore quota usage (watch for anomalies)
- [ ] Auth success rate (target: >99.9%)

### Every 4 Hours
- [ ] User count growth (should be steady ramp up)
- [ ] Payment success rate (target: 100%)
- [ ] Block enforcement incidents (target: 0)
- [ ] Message delivery success (target: >99%)

### Every 8 Hours
- [ ] Cumulative error count
- [ ] Most common error types
- [ ] Feature usage patterns
- [ ] Performance trend analysis

---

## 🚨 Escalation Path

### Level 1: Minor Issue (Resolve in 30 min)
- Single user report of non-critical feature
- Warning-level logs appearing
- Performance slightly degraded but within bounds

**Response:** Check logs, verify system state, communicate with user

### Level 2: Moderate Issue (Resolve in 15 min)
- Multiple users reporting same issue
- Core feature affected (messaging, payments)
- Error rate 0.5-1%

**Response:** Immediate investigation, prepare hotfix, notify stakeholders

### Level 3: Critical Issue (Resolve in 5 min)
- Entire feature down (block enforcement, payments)
- Error rate >1%
- Users unable to register or login

**Response:** Immediate action, page on-call team, consider rollback

### Rollback Decision
If critical issue cannot be fixed in 30 minutes:
1. Stop new user invitations
2. Notify existing users
3. Prepare rollback to previous deployment
4. Execute rollback if necessary

**Rollback Command:**
```bash
git revert 0a3e9cff --no-edit  # Revert latest deployment
firebase deploy --project=mixvy-v2
```

---

## 📊 Success Criteria (First 24 Hours)

- ✅ 50 users onboarded successfully
- ✅ 0 critical errors in production
- ✅ Block enforcement: 0 false positives/negatives
- ✅ Payment success rate: 100%
- ✅ Message delivery: >99%
- ✅ Auth success rate: >99.9%
- ✅ Average latency: <500ms
- ✅ No user-reported issues with core features

---

## 🔗 Important Links

| Resource | URL |
|----------|-----|
| Firebase Console | https://console.firebase.google.com/project/mixvy-v2 |
| Functions Logs | https://console.firebase.google.com/project/mixvy-v2/functions/logs |
| Authentication | https://console.firebase.google.com/project/mixvy-v2/authentication/users |
| Firestore Database | https://console.firebase.google.com/project/mixvy-v2/firestore |
| Cloud Scheduler | https://console.cloud.google.com/cloudscheduler?project=mixvy-v2 |
| Stripe Dashboard | https://dashboard.stripe.com/test/dashboard |
| App URL | https://mixvy-v2.web.app |

---

## 📝 Incident Log Template

**Time:** [HH:MM UTC]  
**Severity:** 🔴 CRITICAL / 🟡 WARNING / 🟢 INFO  
**Component:** [Function/Service]  
**Issue:** [Description]  
**Logs:** [Firebase console filter/grep command]  
**Action Taken:** [What was done]  
**Resolution:** [Fixed? Monitoring? Escalated?]  
**Root Cause:** [If determined]  

---

## ✅ Monitoring Shift Schedule

**Shift 1 (00:00-08:00 UTC):** Engineer A  
**Shift 2 (08:00-16:00 UTC):** Engineer B  
**Shift 3 (16:00-24:00 UTC):** Engineer C  

**Handoff Protocol:**
- Review incident log from previous shift
- Check current metrics
- Run diagnostic suite
- Acknowledge shift takeover

---

**Status: MONITORING ACTIVE** 🟢  
**Last Updated:** 2026-07-03 18:06 UTC  
**Next Review:** 2026-07-04 18:06 UTC (Post-Launch Retrospective)
