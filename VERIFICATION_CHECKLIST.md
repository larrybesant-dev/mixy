# Connection Recovery Verification Checklist

## Purpose
Manual verification that `ConnectionRecoveryHandler` is executing its exponential backoff retry logic during a live session, without relying on production build logs.

---

## Pre-Test Setup

### 1. **Enable Debug Logging in Main**
Edit [lib/main.dart](lib/main.dart) and add this in `main()` before `runApp()`:

```dart
void main() {
  // Route production logs to Firebase Crashlytics
  DiagnosticLogger.setProductionHandler((log) {
    // For testing: also print to console even in release mode
    if (log.severity == 'ERROR' || log.severity == 'CRIT') {
      debugPrint('[REMOTE] ${log.category} ${log.severity}: ${log.message}');
    }
  });
  
  runApp(const MixVyApp());
}
```

### 2. **Verify ConnectionRecoveryHandler Logging**
Check [lib/services/connection_recovery_handler.dart](lib/services/connection_recovery_handler.dart) contains these logs:

- ✅ `logInfo('Recovery started', metadata: {'maxRetries': $maxRetries, 'baseDelayMs': $baseDelayMs})`
- ✅ `logInfo('Reconnect scheduled in ${delay}ms', metadata: {'attemptNumber': $_attemptCount})`
- ✅ `logError('Max retries exceeded', error: Exception('Failed after $maxRetries attempts'))`

### 3. **Build for Testing**
```bash
flutter clean
flutter pub get
flutter run -d chrome  # or your target device
```

---

## Test Sequence

### **Test 1: Verify Service Initialization Logs**

**Step 1:** Start app on target device (web/iOS/Android)

**Expected Log (Dev Console or Firebase Dashboard):**
```
[MIXVY_DEBUG:AgoraService][INFO] Recovery started | metadata={'maxRetries': 3, 'baseDelayMs': 2000}
```

**Verification:** ✅ If log appears, service layer logging is working

---

### **Test 2: Simulate Connection Loss (Web - Chrome DevTools)**

**Step 1:** Join a live room
- Navigate to home screen → select any room → wait for video to start

**Step 2:** Trigger offline mode
- Press **F12** (DevTools)
- Go to **Network** tab
- Throttling dropdown → select **"Offline"**

**Step 3:** Watch Console for recovery sequence
- Open **Console** tab in DevTools
- Look for logs matching this pattern:

```
[MIXVY_DEBUG:ConnectionRecoveryHandler][INFO] Reconnect scheduled in 2000ms | metadata={'attemptNumber': 1}
[MIXVY_DEBUG:WebRtcRoomService][INFO] Attempting reconnect (1/3)...
[MIXVY_DEBUG:ConnectionRecoveryHandler][INFO] Reconnect scheduled in 4000ms | metadata={'attemptNumber': 2}
[MIXVY_DEBUG:WebRtcRoomService][INFO] Attempting reconnect (2/3)...
[MIXVY_DEBUG:ConnectionRecoveryHandler][INFO] Reconnect scheduled in 8000ms | metadata={'attemptNumber': 3}
[MIXVY_DEBUG:WebRtcRoomService][INFO] Attempting reconnect (3/3)...
[MIXVY_DEBUG:ConnectionRecoveryHandler][ERROR] Max retries exceeded | error=Failed after 3 attempts
```

**Verification:** ✅ If all 3 retry attempts logged, recovery logic is executing correctly

**Time Analysis:**
- Attempt 1 fires at: **T+2s** (2000ms delay)
- Attempt 2 fires at: **T+6s** (2000ms + 4000ms)
- Attempt 3 fires at: **T+14s** (2000ms + 4000ms + 8000ms)
- **Total recovery window: ~14 seconds**

---

### **Test 3: Verify UI Recovery Badge Appears**

**Step 1:** Stay in offline mode from Test 2

**Step 2:** Observe UI
- **Expected behavior:** Red container with gold spinner appears in video area
- **Text:** "Reconnecting... (1/3)" → updates to (2/3) → (3/3)
- **Animation:** Opacity pulses (fade in/out every 1.5s)

**Step 3:** Take screenshot for documentation
```bash
# Example: DevTools Network tab showing 0 requests during recovery
# Live room screen showing RecoveryBadge + media controls
```

**Verification:** ✅ If badge appears and updates, UI layer is reactive

---

### **Test 4: Verify Connection Failed Overlay**

**Step 1:** Allow recovery to exhaust (stay offline for ~15 seconds)

**Step 2:** Observe UI transformation
- **Recovery badge disappears**
- **Full-screen overlay appears** with:
  - Cloud icon (animated)
  - Headline: "Connection Lost"
  - Description: "Unable to establish connection after 3 attempts"
  - Two buttons: "Retry Connection" + "Leave Room"

**Verification:** ✅ If overlay renders correctly, failure handling works

---

### **Test 5: Verify Recovery Succeeds When Network Restored**

**Step 1:** From Test 2 state (offline, recovery badge visible)

**Step 2:** Restore network in DevTools
- Throttling dropdown → select **"No throttling"** or **"Fast 3G"**

**Step 3:** Watch logs for recovery success
```
[MIXVY_DEBUG:WebRtcRoomService][INFO] Connection restored!
[MIXVY_DEBUG:ConnectionRecoveryHandler][INFO] Recovery aborted, connection restored
```

**Step 4:** Verify UI updates
- Recovery badge disappears
- Overlay closes
- Video/audio controls return
- Live indicators show connection stable

**Verification:** ✅ If UI returns to normal state, recovery success logic works

---

### **Test 6: Native Platform Verification (iOS/Android)**

**For iOS (Xcode Console):**
```bash
# Run on simulator
flutter run

# In Xcode: Product → Scheme → Edit Scheme → Run → Diagnostics
# Enable: OS Log (captures developer.log() output)
# Filter by: [MIXVY_DEBUG]
```

**For Android (adb logcat):**
```bash
adb logcat | grep MIXVY_DEBUG

# Expected output:
# I [MIXVY_DEBUG:AgoraService][INFO]: Recovery started | metadata={'maxRetries': 3, 'baseDelayMs': 2000}
# I [MIXVY_DEBUG:ConnectionRecoveryHandler][INFO]: Reconnect scheduled in 2000ms
```

**Verification:** ✅ If logs appear, recovery system is logging on native platforms

---

## Troubleshooting Guide

### **Issue: No logs appear in console**

**Diagnosis 1:** Production build is minified
- **Solution:** Add `debugPrintBeginFrame(true)` to main, or check Firebase Crashlytics dashboard

**Diagnosis 2:** DiagnosticLogger not attached to services
- **Check:** [lib/services/agora_service.dart](lib/services/agora_service.dart) and [lib/services/webrtc_room_service.dart](lib/services/webrtc_room_service.dart)
- **Verify:** Both classes have `with DiagnosticLogger` mixin
- **Fix:** Add mixin if missing: `class AgoraService with DiagnosticLogger { ... }`

**Diagnosis 3:** Connection already lost before test starts
- **Solution:** Verify room connection is stable (check video/audio indicators are active) before going offline

---

### **Issue: Recovery logs appear but badge doesn't show**

**Diagnosis:** UI not watching Riverpod state
- **Check:** [lib/features/room/presentation/live_room_screen.dart](lib/features/room/presentation/live_room_screen.dart)
- **Verify:** `ref.watch(activeRoomWebRTCProvider(widget.roomId))` is present in build method
- **Fix:** Ensure `_buildVideoArea()` has conditional rendering for `RecoveryBadge`

```dart
// live_room_screen.dart - verify this exists
if (webrtcState.connectionState == RtcConnectionState.reconnecting)
  RecoveryBadge(attemptNumber: webrtcState.reconnectAttemptCount, maxAttempts: 3),
```

---

### **Issue: Overlay appears but "Retry" button doesn't work**

**Diagnosis:** Notifier method not properly wired
- **Check:** [lib/features/room/providers/room_webrtc_provider.dart](lib/features/room/providers/room_webrtc_provider.dart)
- **Verify:** `disconnect()` and `reconnect()` methods exist on `RoomWebRTCNotifier`
- **Fix:** Call manual recovery restart if needed:

```dart
// In connection_failed_overlay.dart onRetry callback
onRetry: () {
  ref.read(activeRoomWebRTCProvider(roomId).notifier).reconnect();
},
```

---

## Sign-Off Checklist

After completing all 6 tests, verify:

- [ ] Test 1: Service initialization logs appear in console
- [ ] Test 2: All 3 retry attempts logged with correct exponential backoff timings
- [ ] Test 3: Recovery badge appears and animates correctly
- [ ] Test 4: Connection failed overlay renders after max retries
- [ ] Test 5: Recovery succeeds and UI returns to normal when network restored
- [ ] Test 6: Logs visible on native platform (iOS/Android) via Xcode/adb
- [ ] DiagnosticLogger mixin attached to AgoraService and WebRtcRoomService
- [ ] Firebase Crashlytics or Sentry configured for production log routing
- [ ] No build errors: `flutter analyze` → "No issues found"

**Verified By:** ___________________  
**Date:** ___________________  
**Notes:** ___________________

---

## Next Steps

Once verification is complete:

1. **Commit recovery system to production:** `git commit -m "feat: complete 3-phase connection recovery system"`
2. **Deploy to Firebase Hosting:** `firebase deploy --only hosting`
3. **Monitor production logs:** Set up alert in Sentry/Crashlytics for `[MIXVY_DEBUG]` errors
4. **Add health check feature:** See `connection_health_check.dart` for proactive monitoring
