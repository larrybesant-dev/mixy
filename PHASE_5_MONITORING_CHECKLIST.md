# Phase 5: Beta Feedback Monitoring Checklist

**Campaign:** Network Health Widget Phase 5 Outreach  
**Start Date:** 2026-06-29 07:43 UTC  
**Feedback Deadline:** 2026-07-01 07:43 UTC (48-hour window)  
**Tester UID:** m6UqL501Z8ZJ0mvEHxvz7oX2wkm2  
**Tester Email:** larrybesant@gmail.com

---

## Real-Time Monitoring (Next 24-48 hours)

### 1. In-App Notification Reception
- [ ] Verify notification appears in tester's app
  - Check: Firestore > users/{uid}/notifications (should have doc created 2026-06-29T07:43:11Z)
  - Look for doc ID: `qJ72flLxDT5K1QPWSEg5`
  - Expected fields: `title: "🎯 Network Health Widget Live!"`, `read: false`
- [ ] Monitor when tester clicks notification (sets `read: true`)

### 2. Email Delivery
- [ ] Confirm email reaches larrybesant@gmail.com
  - Check email logs in Firebase Extensions or mail collection
  - Subject should include: "🎯 MIXVY Beta: Network Health Indicators Live"
- [ ] Verify no bounces or failures

### 3. Tester Activity in Live Rooms
- [ ] Monitor webrtc_sessions for tester presence
  - UID: m6UqL501Z8ZJ0mvEHxvz7oX2wkm2
  - Look for `participants/{uid}` documents
  - Check `lastSeen` timestamp during 48-hour window
- [ ] Observe session duration (longer = more data points)

### 4. WebRTC Latency Logs (Golden User)
- [ ] Filter console/logs by: `goldenUserTag.telemetryLabel = "golden-network-health-phase-5-2026-06-29"`
- [ ] Collect data points:
  - ICE Gathering times
  - Offer/Answer latency
  - Total E2E connection time
  - Connection state transitions
- [ ] Note any anomalies or spikes

### 5. Beta Feedback Submission
- [ ] Monitor Firestore path: `users/{uid}/beta_feedback/{autoId}`
  - Tester may submit: "I saw the indicator go 🟢 → 🟡 → 🔴 during a freeze"
  - Will contain: `checklist`, `fullReport`, `timestamp`
- [ ] Cross-reference feedback timestamp with WebRTC logs

---

## Correlation Analysis Template

Once feedback received, fill this in:

```
FEEDBACK ENTRY:
Date: [2026-06-XX]
Tester: m6UqL501Z8ZJ0mvEHxvz7oX2wkm2
Reported Feeling: [Excellent / Smooth / Connecting / Laggy / Poor]
Indicator Colors Observed: [🟢 / 🟡 / 🔴]

LATENCY DATA (Query logs):
Timestamp of Event: [UTC time from feedback]
ICE Gathering: [XXX ms]
Offer/Answer RTT: [XXX ms]
Total E2E: [XXX ms]
Status During Event: [CONNECTING / CONNECTED / COMPLETED / FAILED]

CORRELATION RESULT:
✅ MATCH: [e.g., "Yellow indicator appeared at 14:32:15Z, logs show 1850ms latency"]
⚠️ QUESTIONABLE: [e.g., "Red dot, but logs show 950ms - possible packet loss"]
❌ MISMATCH: [e.g., "Green indicator, but tester reported severe lag"]

HYPOTHESIS: [What could explain any misalignment?]
- Packet loss vs latency?
- Media rendering delay vs signaling delay?
- Browser throttling?
- Other network factors?
```

---

## Success Criteria

| Metric | Target | Status |
|--------|--------|--------|
| Feedback Received | Yes, within 48h | [ ] |
| Indicator Matches Experience | 80%+ correlation | [ ] |
| Latency Logs Captured | Complete trace | [ ] |
| Calibration Complete | All data correlated | [ ] |

---

## Action Items (Next 48 Hours)

### Day 1 (Today - 2026-06-29)
- [ ] Verify notifications sent successfully
- [ ] Check for any FCM token failures
- [ ] Confirm email delivery
- [ ] Take baseline screenshot of tester's app

### Day 2 (2026-06-30)
- [ ] Monitor webrtc_sessions for tester activity
- [ ] Collect any [WebRtcLatency] logs with golden-network-health-phase-5 tag
- [ ] Check Firestore for partial feedback submissions

### Day 3 (2026-07-01)
- [ ] Consolidate all feedback by 08:00 UTC
- [ ] Cross-reference with latency logs
- [ ] Complete correlation analysis
- [ ] Update beta-feedback-calibration-log.md with findings
- [ ] Decide: Proceed to Stability Baseline or Recalibrate?

---

## Decision Tree (By 2026-07-01)

```
IF feedback_accuracy >= 80%:
  → ✅ PROCEED TO STABILITY BASELINE (Phase 6)
  → Widget is trustworthy, ready for broader deployment
  → Lock thresholds: <1000ms=green, 1000-2000ms=yellow, >2000ms=red

ELSE IF feedback_accuracy >= 60%:
  → ⚠️ CONDITIONAL PASS - Refinement Needed
  → Adjust thresholds or add disclaimers
  → Re-test with same tester for validation
  → Then proceed to Phase 6

ELSE:
  → ❌ RECALIBRATE - Investigation Needed
  → Review thresholds in webrtc_latency_provider.dart
  → Check for off-by-one errors or edge cases
  → Re-instrument and re-test
```

---

## Notes

- Do NOT close the app or clear data during 48-hour window
- Golden User telemetry automatically tags all WebRTC metrics
- If tester has questions, respond via Settings > Beta Feedback
- All feedback responses automatically saved to Firestore
- Email any follow-up questions to larrybesant@gmail.com
