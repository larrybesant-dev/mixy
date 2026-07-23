# Production Monitoring & Observability Plan
**MixVy Audit Remediation Deployment**  
**Effective Date:** Upon Production Rollout  
**Review Cadence:** Daily (first 7 days), Weekly (thereafter)

---

## 1. Key Performance Indicators (KPIs)

### 1.1 Firestore Quota Health

**Metric:** Read/Write Operations per Minute  
**Baseline (Pre-Audit):** 600-900 writes/min during peak (multi-room sessions)  
**Target (Post-Audit):** 500-650 writes/min (A-2 timer cleanup removes zombie heartbeats)  
**Alert Thresholds:**
- ⚠️ Yellow: >800 writes/min (10% above target)
- 🔴 Red: >1000 writes/min (zombie heartbeats detected)

**Monitoring:** Firebase Console → Firestore → Usage Tab  
**Frequency:** 5-minute intervals  
**Action:** If Red, trigger incident; investigate for timer leaks or Firestore rule bypass

---

**Metric:** Firestore Document Size  
**Target:** Sessions docs <5KB, Signaling docs <2KB  
**Alert Threshold:** Any single doc >10KB  
**Monitoring:** Firestore Rules simulator; test with sample load  
**Frequency:** Hourly  
**Action:** Indicates ICE candidate accumulation; may signal memory leak

---

### 1.2 WebRTC Connection Quality

**Metric:** E2E Signaling Latency  
**Baseline (from telemetry):** 500-1300ms average  
**Target (post-B-2/C-2):** <1200ms  
**Alert Thresholds:**
- ⚠️ Yellow: >1500ms
- 🔴 Red: >2000ms sustained (>30s)

**Monitoring:** Browser console → Filter `[WebRtcLatency]`  
**Collection:** Sample 5% of sessions; log to Analytics  
**Frequency:** Real-time per session; aggregate dashboard 1-min intervals  
**Action:** If Red, check TURN Cloud Function response time and Firestore region

---

**Metric:** Connection Establishment Success Rate  
**Target:** >98% connections succeed on first attempt  
**Alert Threshold:** <95%  
**Breakdown by failure type:**
- Offer/answer timeout (B-2 race detection)
- ICE candidate exhaustion (B-1 stale candidates)
- TURN credentials failure (C-2 Cloud Function error)
- Renderer initialization failure (A-1)

**Monitoring:** Analytics → WebRTC Events  
**Frequency:** Hourly aggregates  
**Action:** If <95%, drill into failure type; trigger page incident if specific failure >30%

---

### 1.3 UI Performance (Layout Stability)

**Metric:** Frame Rate During Peer Transitions  
**Baseline (Pre-A-4):** 50-100fps normal; 20-30fps on peer join  
**Target (Post-A-4):** 50-60fps sustained  
**Alert Thresholds:**
- ⚠️ Yellow: <45fps for >2 seconds
- 🔴 Red: <30fps for >5 seconds

**Monitoring:** Flutter DevTools FPS monitor (available in app if debug flag enabled)  
**Collection:** 1% of sessions; real-time dashboard  
**Frequency:** Per-session continuous; aggregate 5-min intervals  
**Action:** If Red, investigate for grid rebuild loops; check ValueKey implementation

---

**Metric:** Memory Usage on Room Join  
**Baseline:** ~40-60MB with 5 peers  
**Target:** Same or lower (A-2 cleanup, A-4 stable keys)  
**Alert Threshold:** >80MB with <5 peers  
**Monitoring:** DevTools Performance tab; Chrome Task Manager  
**Frequency:** Spot check during load tests; weekly on production sample  
**Action:** Indicates memory leak; profile and file regression ticket

---

### 1.4 Security Posture

**Metric:** Firebase App Check Token Success Rate  
**Target:** >95% tokens validated successfully  
**Alert Threshold:** <90%  
**Breakdown:**
- Web (ReCAPTCHA v3): Expect ~95-98%
- Android (Play Integrity): Expect >98%
- iOS (Device Check): Expect >98%

**Monitoring:** Firebase Console → App Check → Tokens  
**Frequency:** Hourly aggregates  
**Action:** If <90%, check if ReCAPTCHA service degraded or client configuration broken

---

**Metric:** TURN Credential Fetch Success Rate (Cloud Function)  
**Target:** >98%  
**Alert Threshold:** <95%  
**Metrics to track:**
- Latency: p50 <500ms, p95 <1000ms, p99 <2000ms
- Error rate: <2%
- Timeout rate: <1%

**Monitoring:** Cloud Functions Console → getTurnCredentials  
**Frequency:** Real-time; dashboard update 1-min intervals  
**Action:** If latency >1000ms, scale Cloud Function; if error >2%, check Metered.ca API

---

**Metric:** Firestore Security Rule Violations  
**Target:** 0 permission denied errors from legitimate users  
**Alert Threshold:** >10 violations/hour  
**Breakdown by rule:**
- App Check missing (hasValidAppCheck failure)
- Auth missing (signedIn failure)
- Role-based denial (canManageRoom failure)

**Monitoring:** Firestore Rules Debug Mode or Cloud Logging  
**Frequency:** Real-time; aggregate hourly  
**Action:** If violations >10/hr, investigate; may indicate broken client logic or compromised token

---

## 2. Application Logs & Event Tracking

### 2.1 Critical Events to Log

**Event: RoomController.onDispose**
```
[room_controller] onDispose: roomId={}, userId={}, sessionId={}, 
  phase={}, uptime_seconds={}
```
**Purpose:** Verify A-2 timer cleanup; ensure clean session end  
**Frequency:** Once per room session end  
**Alert if:** Missing from logs >5 sec after room.close()

---

**Event: WebRtcLatency.recordOfferAnswerSent**
```
[WebRtcLatency] offer_answer_sent: peerId={}, type={offer|answer}, 
  latency_ms={}, timestamp={}
```
**Purpose:** Detect B-2 offer/answer races  
**Frequency:** Once per peer connection  
**Alert if:** Type mismatch detected (offer from non-offerer, answer from offerer)

---

**Event: WebRtcLatency.recordStaleCandidate**
```
[WebRtcLatency] stale_candidate_skipped: peerId={}, age_seconds={}, 
  reason={ttl_exceeded}
```
**Purpose:** Verify B-1 ice candidate filtering  
**Frequency:** Per candidate; aggregate count per session  
**Alert if:** >50% of candidates are stale (indicates Firestore batch latency issues)

---

**Event: CameraWall.ValueKey**
```
[CameraWall] tile_key_change: roomId={}, uid={}, key_type={local|remote}, 
  stable=true
```
**Purpose:** Verify A-4 stable keys; detect key churn  
**Frequency:** Per tile lifecycle  
**Alert if:** Same uid appears with different keys (indicates rebuild loop)

---

**Event: FirebaseAppCheck.activate**
```
[Firebase] App Check activated successfully | 
[Firebase] App Check activation warning: {}
```
**Purpose:** Confirm App Check initialization (C-4)  
**Frequency:** Once per app session  
**Alert if:** Warning appears >5% of sessions

---

### 2.2 Error Tracking

**Error: RTCVideoRenderer disposal exception**
```
Exception: Looking up a deactivated widget
Stack trace: _cleanupPeer() → renderer.dispose()
```
**Pre-Audit Frequency:** ~2-5% of multi-peer sessions  
**Target Frequency:** <0.1%  
**Monitoring:** Sentry, Firebase Crashlytics  
**Action:** If frequency >0.1%, revert A-1 fix and investigate

---

**Error: ICE candidate addition failure**
```
[WebRtcRoomService] Failed to add ICE candidate for {}: {}
```
**Purpose:** Detect connection degradation  
**Target:** <1% of candidates fail  
**Alert Threshold:** >5% failure rate  
**Action:** Investigate; may indicate TURN server unavailability

---

**Error: Cloud Function getTurnCredentials timeout**
```
FirebaseFunctionsException: DEADLINE_EXCEEDED | INTERNAL
```
**Target:** <1% of calls  
**Alert Threshold:** >3%  
**Action:** Scale Cloud Function or investigate Metered.ca API latency

---

## 3. Dashboard Setup

### 3.1 Real-Time Monitoring Dashboard

**Location:** Firebase Console custom dashboard + external tool (Grafana/Looker)  
**Update Frequency:** 1-minute aggregates  
**Audience:** On-call engineers

**Panels:**
1. **Firestore Quota** — Writes/min, reads/min, growth trend
2. **WebRTC Health** — Connection success rate, avg latency, by percentile
3. **UI Performance** — FPS trend, memory usage, layout rebuild count
4. **Security** — App Check token rate, rule violations, TURN errors
5. **Logs Stream** — Real-time tail of critical events

### 3.2 Post-Deployment Checklist Dashboard

**Purpose:** Verify each sprint fix is working as expected  
**Duration:** 7 days post-deploy  
**Metrics:**

- ✅ A-1 Fix: Renderer crash rate <0.1%
- ✅ B-1 Fix: Connection recovery <5s on network switch
- ✅ C-4 Fix: App Check token success >95%
- ✅ B-2 Fix: No offer/answer race logs detected
- ✅ C-2 Fix: 0 HTTP calls to metered.ca (all via Cloud Function)
- ✅ A-2 Fix: Firestore writes <650/min (baseline met)
- ✅ A-4 Fix: FPS ≥50 during peer transitions

**Sign-off:** All 7 ✅ required before marking deployment as success

---

## 4. Alerting Rules

### 4.1 Alert Severity Levels

| Level | Response Time | Escalation | Example |
|-------|----------------|-----------|---------|
| **Critical** | <5 min | Page on-call | >1000 writes/min (quota drain) |
| **High** | <15 min | Slack alert | Crash rate >1% |
| **Medium** | <1 hour | Ticket created | Latency >1500ms |
| **Low** | <24 hours | Weekly review | Minor telemetry mismatches |

### 4.2 Specific Alerts

```yaml
alerts:
  - name: "Firestore Writes Spike"
    condition: writes_per_min > 1000
    duration: 2 minutes
    severity: CRITICAL
    action: "Investigate timer leaks; page on-call"
    
  - name: "App Check Failures"
    condition: app_check_success_rate < 90%
    duration: 5 minutes
    severity: CRITICAL
    action: "Check ReCAPTCHA service; investigate client token generation"
    
  - name: "Connection Establishment Failure"
    condition: connection_success_rate < 95%
    duration: 10 minutes
    severity: HIGH
    action: "Check TURN Cloud Function; investigate offer/answer logs"
    
  - name: "Layout Jank Detected"
    condition: fps < 30 for > 5 seconds
    duration: per session
    severity: MEDIUM
    action: "Profile session; check for ValueKey regression"
    
  - name: "High Latency"
    condition: p95_latency_ms > 1500
    duration: 5 minutes
    severity: MEDIUM
    action: "Check TURN latency; investigate Firestore region"
```

---

## 5. Load Testing Results Baseline

### Before Sprint Remediation
- **10 concurrent users, 5 minutes:**
  - Firestore writes: 850/min avg (spike to 1200/min on joins)
  - Memory per client: 70-90MB (memory leak on exit)
  - FPS: 45 avg, dips to 15-20fps on peer join
  - Connection success: 94%
  - Crash rate: 2-3% (renderer disposal)

### After Sprint Remediation (Target)
- **10 concurrent users, 5 minutes:**
  - Firestore writes: 580/min avg (no spike on joins)
  - Memory per client: 50-65MB (stable on exit)
  - FPS: 55 avg, maintains 50+ on peer join
  - Connection success: >99%
  - Crash rate: <0.1%

**Test Protocol:**
```bash
# Automated load test
pytest tests/load_test_10_users.py \
  --duration 300s \
  --firestore-monitoring \
  --webrtc-latency-tracking \
  --ui-performance-profiling
```

---

## 6. Weekly Monitoring Cadence

### Monday (Post-Deploy)
- Review all 7 sprint fix metrics
- Check for any regressions vs baseline
- Create incident if any metric >5% off target

### Wednesday
- Cross-browser validation (Chrome, Safari, Firefox)
- Network condition testing (Slow 3G, 4G, High Latency)
- Security audit: verify App Check enforcement

### Friday
- Weekly metrics summary to stakeholders
- Identify trends (improving/degrading)
- Plan any follow-up investigation or optimization

---

## 7. Rollback Decision Tree

**Decision Point:** If ANY critical metric violates threshold

```
Is crash rate > 1%?
  YES → Immediate rollback
  NO ↓

Are Firestore writes > 1200/min sustained?
  YES → Rollback (likely A-2 timer fix regression)
  NO ↓

Is connection success rate < 90%?
  YES → Rollback (likely B-2 offer/answer or C-2 TURN regression)
  NO ↓

Is FPS < 25 for >10 seconds sustained?
  YES → Rollback (likely A-4 ValueKey regression)
  NO ↓

→ Continue monitoring; fix any issues in hot patch
```

**Rollback Command:**
```bash
gcloud app versions delete [broken-version-id]
gcloud app versions traffic-split --splits=[previous-version]=1.0
# Or: firebase hosting:channel:delete [broken-channel]
```

**Post-Rollback:** Root cause analysis; file ticket for regression fix

---

## 8. Success Criteria

**Deployment is successful if, after 7 days:**

1. ✅ Crash rate **<0.1%** (was 2-3%)
2. ✅ Firestore quota **<650 writes/min** (was 850/min avg)
3. ✅ Layout jank **eliminated** (FPS ≥50 during transitions)
4. ✅ Network recovery **<5s** (was 30+s)
5. ✅ Connection success **>98%** (was 94%)
6. ✅ App Check enforcement **100% on rooms** (was 0%)
7. ✅ Zero new issues introduced; no regression alerts

**Sign-off:** Engineering Lead + Platform Lead approval before marking as production-ready

---

## Escalation Contacts

- **Critical (On-Call):** [Phone/Slack]
- **Engineering Lead:** [Email/Slack]
- **Platform Lead:** [Email/Calendar]
- **Vendor Support (Metered.ca):** [Support URL]

---

*This plan is living documentation. Update weekly based on monitoring results.*
