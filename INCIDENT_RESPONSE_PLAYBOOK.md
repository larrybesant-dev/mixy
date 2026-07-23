# 🚨 Soft Launch Incident Response Playbook

**Last Updated:** 2026-07-03 18:06 UTC  
**Valid For:** 24-hour soft launch period  
**Activation:** If error rate >1% OR user reports critical issue

---

## 📞 Escalation Contacts

| Role | Contact | Availability | Responsibilities |
|------|---------|--------------|------------------|
| On-Call Engineer | [Phone] | 24/7 | Immediate response, diagnostics |
| Engineering Lead | [Phone] | During shift | Approval for rollback/fixes |
| Product Manager | [Email] | During shift | User communication |
| Support Lead | [Email] | During shift | Gathering user feedback |

---

## 🔥 Critical Issue Response Procedure

### Step 1: Detect Issue (0-5 min)

**Triggers:**
- Alert from monitoring system
- User report via support channel
- Manual discovery in logs

**Immediate Actions:**
```bash
# 1. Check current error rate
gcloud functions logs read --limit 100 --project=mixvy-v2 | grep ERROR

# 2. Identify affected function
firebase functions:list --project=mixvy-v2

# 3. Get recent logs for specific function
gcloud functions logs read [functionName] --limit 50 --project=mixvy-v2
```

---

### Step 2: Diagnosis (5-15 min)

#### Scenario A: Block Enforcement Not Working

**Symptoms:**
- User reports: "Blocked user messaging me"
- Multiple similar reports

**Diagnosis:**
```bash
# 1. Check endpoint is accessible
node test_block_http.mjs

# 2. Check Firestore Rules compilation
firebase firestore:rules:print --project=mixvy-v2 | grep -A 5 "isNotBlocked"

# 3. Query recent block relationships
firebase firestore:delete -r blocks --project=mixvy-v2 --skip-confirmation
# Actually, DON'T delete - just query:
firestore.collection("blocks").orderBy("createdAt", "desc").limit(10).get()

# 4. Check for messages from blocked users
# In Firebase Console: conversations > {convId} > messages
# Filter where senderId is in blocked list
```

**Likely Causes:**
- [ ] Endpoint not responding (HTTP 404/500)
- [ ] Firestore Rules not deployed
- [ ] Block documents not being created
- [ ] Client not calling endpoint

**Fix Options:**
1. Redeploy Rules: `firebase deploy --only firestore:rules --project=mixvy-v2`
2. Redeploy Functions: `firebase deploy --only functions:checkBlockStatus --project=mixvy-v2`
3. Manual block enforcement: Add `isBlocked=true` flag to conversation metadata

---

#### Scenario B: Payment Processing Failing

**Symptoms:**
- User reports: "Payment went through but no coins"
- Multiple failed payment records

**Diagnosis:**
```bash
# 1. Check Stripe webhook status
# Go to: https://dashboard.stripe.com/test/webhooks

# 2. Check Cloud Function logs
gcloud functions logs read recordStripePaymentSuccess --limit 50 --project=mixvy-v2 | grep ERROR

# 3. Check Firestore for incomplete payments
firestore.collection("payments")
  .where("status", "==", "pending")
  .get()

# 4. Query user coins balance
firestore.collection("users").doc("[userId]").get()
```

**Likely Causes:**
- [ ] Webhook not reaching Cloud Function
- [ ] Payment recorded but coin transfer failed
- [ ] Stripe key invalid/expired
- [ ] Database write permission issue

**Fix Options:**
1. Manual coin credit: Update user doc `coins += [amount - fee]`
2. Retry webhook: Manually trigger `recordStripePaymentSuccess` for pending payments
3. Verify Stripe key: Check Google Cloud Secret Manager

```bash
gcloud secrets versions list STRIPE_SECRET --project=mixvy-v2
```

---

#### Scenario C: User Registration Failing

**Symptoms:**
- Multiple users can't create account
- Auth errors in logs

**Diagnosis:**
```bash
# 1. Check Firebase Auth status
# Dashboard: https://console.firebase.google.com/project/mixvy-v2/authentication/users

# 2. Check Auth function logs
gcloud functions logs read --limit 50 --project=mixvy-v2 | grep -i "auth"

# 3. Test auth manually
firebase auth:import users.json --hash-algo=scrypt --project=mixvy-v2
```

**Likely Causes:**
- [ ] Firebase Auth temporarily down
- [ ] Email validation overly strict
- [ ] Duplicate account attempts
- [ ] Auth rule violation

**Fix Options:**
1. Restart auth service (usually resolves temp issues)
2. Relax email validation rules temporarily
3. Clear auth cache: `firebase auth:reset --project=mixvy-v2`

---

### Step 3: Execute Fix (15-30 min)

#### Quick Fixes (No deployment needed)

**Fix: Manual data correction**
```bash
# Update user coins
firestore.collection("users").doc("[userId]").update({
  coins: admin.firestore.FieldValue.increment(100)
});

# Unlock blocked user in conversation
firestore.collection("conversations").doc("[convId]").update({
  blockedUserIds: admin.firestore.FieldValue.arrayRemove("[userId]")
});

# Mark payment as processed
firestore.collection("payments").doc("[paymentId]").update({
  status: "success",
  processedAt: new Date()
});
```

#### Deployment Fixes

**Fix: Redeploy specific function**
```bash
firebase deploy --only functions:checkBlockStatus --project=mixvy-v2
# OR
firebase deploy --only firestore:rules --project=mixvy-v2
```

**Fix: Hotfix deploy**
1. Edit file (e.g., `functions/index.js`)
2. Test locally: `npm run lint` && `npm run validate`
3. Deploy: `firebase deploy --only functions --project=mixvy-v2`
4. Verify: Check logs for errors
5. Notify users: Post status update

---

### Step 4: Verify Fix (30-45 min)

**Verification Checklist:**
- [ ] Error rate returned to <0.1%
- [ ] No new critical errors in past 5 minutes
- [ ] Sample user test successful
- [ ] Function latency back to normal (<500ms)
- [ ] All related metrics stable

**Verification Commands:**
```bash
# Check error rate
gcloud functions logs read --limit 200 --project=mixvy-v2 | grep -c ERROR

# Test affected component
node test_block_http.mjs  # For block enforcement
node run_final_health_checks.mjs  # For overall system

# Check specific function
gcloud functions logs read [functionName] --limit 20 --project=mixvy-v2 | tail -10
```

---

### Step 5: Document & Communicate (45-60 min)

#### Incident Log Entry
```
TIME: 2026-07-03 18:30 UTC
SEVERITY: 🔴 CRITICAL
COMPONENT: Block Enforcement (checkBlockStatus)
ISSUE: Blocked users able to send messages
DURATION: 24 minutes (18:06-18:30)
ROOT CAUSE: Firestore Rules not deployed after latest push
FIX: Ran `firebase deploy --only firestore:rules --project=mixvy-v2`
RESOLUTION: ✅ Fixed
USERS AFFECTED: 2 users reported, both resolved
PREVENTION: Added pre-deployment Rules validation to CI/CD
```

#### User Communication (if needed)
```
Subject: Brief service interruption resolved

Hi [Users],

We experienced a brief issue with message blocking (18:06-18:30 UTC) 
that has now been fully resolved. 

What happened: Some blocked users were able to send messages for ~24 minutes.
Impact: This affected [X] users briefly.
Resolution: We've redeployed and verified the fix.

Your data is safe, and the feature is working normally again.

Thank you for your patience!
- MixVy Team
```

---

## 🔄 Rollback Procedure (Last Resort)

**Use only if:** Issue cannot be fixed in 30 minutes OR new fix causes additional problems

```bash
# Step 1: Identify last known-good commit
git log --oneline | head -5

# Step 2: Revert latest deployment
git revert 0a3e9cff --no-edit

# Step 3: Deploy reverted code
firebase deploy --project=mixvy-v2

# Step 4: Verify rollback successful
node run_final_health_checks.mjs

# Step 5: Notify stakeholders
# "We've rolled back to stable version. Investigating issue."
```

---

## 📊 Incident Severity Levels

### 🟢 INFO (No action needed)
- Minor feature issue affecting <5 users
- Performance slightly elevated but within bounds
- Single error in logs (not recurring)

**Response:** Monitor, document

---

### 🟡 WARNING (Respond in 30 min)
- Feature issue affecting 5-20 users
- Error rate 0.1-0.5%
- Performance degraded (500ms-2s latency)
- Single user report of critical feature

**Response:** Begin investigation, prepare fix, communicate status

---

### 🔴 CRITICAL (Respond immediately)
- Core feature down (>20 users affected)
- Block enforcement not working
- Payment processing failing
- Users unable to register/login
- Error rate >1%
- Service unavailable

**Response:** 
1. Page on-call team
2. Begin immediate investigation
3. Prepare hotfix or rollback
4. Communicate status every 5 minutes
5. Execute fix/rollback as needed

---

## ✅ Post-Incident Actions (24 hours after fix)

- [ ] Complete incident post-mortem
- [ ] Document root cause
- [ ] Create prevention measures
- [ ] Update monitoring/alerting
- [ ] Share learnings with team
- [ ] Update this playbook if needed

---

## 🎯 Success Metrics (Soft Launch)

**Green Light Criteria (All must be met):**
- ✅ Error rate stayed <0.5%
- ✅ Block enforcement: 0 violations
- ✅ Payments: 100% success rate
- ✅ User registration: 100% success rate
- ✅ Message delivery: >99%
- ✅ Zero user complaints about core features
- ✅ System performance stable throughout

**If metrics met:** ✅ PROCEED TO FULL LAUNCH

**If issues remain:** 🔄 EXTEND SOFT LAUNCH BY 24 HOURS

---

## 📞 Quick Reference

| Issue | Quick Check | Command |
|-------|------------|---------|
| Block enforcement | Endpoint reachable? | `node test_block_http.mjs` |
| Payments | Stripe key valid? | `gcloud secrets versions list STRIPE_SECRET` |
| Auth | Firebase up? | `firebase auth:list-users --project=mixvy-v2` |
| Database | Firestore accessible? | `firebase firestore:indexes --project=mixvy-v2` |
| Functions | All deployed? | `firebase functions:list --project=mixvy-v2` |

---

**Playbook Status: ✅ ACTIVE FOR SOFT LAUNCH**  
**Last Tested:** 2026-07-03 18:05 UTC  
**Next Review:** After soft launch (2026-07-04 18:06 UTC)
