# Firebase Billing Security & Cost Control

**Project:** MixVy (`mix-and-mingle-v2`)
**Last Updated:** June 26, 2026
**Status:** ✅ Configured

---

## Critical: Billing Alerts Setup

### Step 1: Enable Budget Alerts in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com) → `mix-and-mingle-v2`
2. Click **Billing** (left sidebar)
3. Click **Budgets and Alerts**
4. Click **CREATE BUDGET**

### Step 2: Configure Alert Thresholds

```
Budget Name: MixVy Development
Budgeted Amount: $100/month
Alert Thresholds:
  ✅ 50% ($50) → Email alert
  ✅ 90% ($90) → Email alert
  ✅ 100% ($100) → Block writes (optional, but recommended)
```

### Step 3: Enable Email Notifications

- [ ] Email alerts to: `your-email@example.com`
- [ ] Secondary email: `ops@example.com` (if available)

---

## Billing Breakdown

### Current Costs (Estimated Monthly)

| Service | Free Tier | Usage | Cost |
|---------|-----------|-------|------|
| **Firestore** | 1GB storage + 50K read/write | 1M ops/month | $6 |
| **Cloud Storage** | 5GB/month transfer | 10GB stored | $0.18 |
| **Cloud Functions** | 2M free/month | 500K invocations | $2 |
| **Firebase Auth** | 50K free users | 100 users | $0 (free) |
| **Real-Time Database** | 100MB stored | Not used | $0 |
| **Cloud Messaging** | Free | 10K messages | $0 |
| **Analytics** | Free | ∞ events | $0 |
| **Crashlytics** | Free | ∞ events | $0 |
| **Remote Config** | Free | ∞ | $0 |
| | | **TOTAL** | **~$8/month** |

### Cost by Active Users

| Users | Firestore Ops | Est. Cost |
|-------|---------------|-----------|
| 10 | 100K/month | $1 |
| 50 | 500K/month | $5 |
| 100 | 1M/month | $10 |
| 500 | 5M/month | $40 |
| 1000+ | 10M+/month | $100+ ⚠️ |

---

## High-Cost Operations (Avoid!)

### ❌ BAD: Unbounded Collection Scans

```dart
// Scans ALL rooms every time (expensive!)
final rooms = await FirebaseFirestore.instance
  .collection('rooms')
  .get();  // Read cost: X documents
```

**Cost:** 1 read per document in collection (even if you only show 10)

### ✅ GOOD: Filtered Queries

```dart
// Only reads rooms user is in
final rooms = await FirebaseFirestore.instance
  .collection('rooms')
  .where('participantIds', arrayContains: userId)
  .limit(20)
  .get();  // Read cost: ≤20 documents
```

**Cost:** Only reads what you display

---

### ❌ BAD: Real-Time Listeners Everywhere

```dart
// Each screen has a listener = multiple duplicates
@override
void initState() {
  _listener = FirebaseFirestore.instance
    .collection('rooms')
    .snapshots()
    .listen((_) {});  // Real-time updates = $0.06 per 100K reads
}
```

**Cost:** 1 read per update across all listeners

### ✅ GOOD: Riverpod-Managed Listeners

```dart
// Single listener, shared across app
final roomsProvider = StreamProvider<List<Room>>((ref) {
  return FirebaseFirestore.instance
    .collection('rooms')
    .where('participantIds', arrayContains: uid)
    .snapshots()
    .map((snapshot) => snapshot.docs.map(Room.fromFirestore).toList());
});
```

**Cost:** 1 listener, all widgets consume same stream

---

### ❌ BAD: Large Documents (> 100KB)

```dart
// Storing entire conversation history in one doc
rooms/{roomId}/all_messages: [
  { message: "...", timestamp: ... },  // 500K messages = 100+ MB
  ...
]
```

**Cost:** 1 read = entire 100MB document = excessive bandwidth

### ✅ GOOD: Subcollections with Pagination

```dart
// Messages in subcollection, load on demand
rooms/{roomId}/messages/{messageId}
  .limit(50)
  .get()  // Only load first 50
```

**Cost:** 1 read per message (not per document)

---

## Cost Optimization Checklist

- [ ] All listeners managed by Riverpod (no duplicates)
- [ ] Queries use `.where()` and `.limit()` filters
- [ ] Document size < 100KB (use subcollections for bulk data)
- [ ] No polling loops (use real-time listeners instead)
- [ ] Firestore indexes optimized (check console)
- [ ] Unused listeners cleaned up in `.dispose()`

---

## Monitoring & Alerting

### Daily

1. Check Firebase Console → **Usage & Billing**
2. Look for unusual spikes in reads/writes
3. Review **Top queries** for slow/expensive ones

### Weekly

1. Export usage CSV: Console → Billing → Download
2. Compare to budget forecast
3. Alert if trending above estimate

### Emergency Response

**If over 50% budget:**

1. Check what changed (new feature? bug?)
2. Review Firestore queries in Chrome DevTools
3. Disable high-cost operations temporarily
4. Deploy hotfix

**If approaching 100%:**

1. Immediately disable writes (if critical)
2. Reduce collection sync frequency
3. Contact Firebase support for review

---

## Deployment Verification Checklist

Before deploying to production:

- [ ] Run `flutter analyze` (catches inefficient code)
- [ ] Test on slow network (3G) to measure real costs
- [ ] Load test: simulate 100 concurrent users
- [ ] Monitor for 24 hours post-deploy
- [ ] Budget alerts active in Firebase Console
- [ ] Have rollback plan ready

---

## Contact & Escalation

| Issue | Action |
|-------|--------|
| Bill spike (>$50) | Check logs, disable writes if needed |
| Service disabled | Check Firebase Console, review rules |
| Suspicious activity | Enable Security Rules audit logging |
| Need emergency cap | Contact Firebase Support (premium feature) |

---

**References:**
- [Firebase Pricing](https://firebase.google.com/pricing)
- [Firestore Costs Explained](https://firebase.google.com/docs/firestore/pricing)
- [Cloud Functions Pricing](https://cloud.google.com/functions/pricing)

