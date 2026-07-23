# MixVy Beta Launch Safety Plan (First 100 Users)

This plan ensures a controlled, crash-resistant launch for the first 100 testers.

## 1. Gradual Traffic Ramping
- **Cohort A (1-10 Users):** Internal testers. Focus on **State Recovery** logic. Force-kill the app mid-room and verify the "Rejoin" prompt works.
- **Cohort B (11-50 Users):** Friends & Family. Focus on **Concurrent Messaging**. Monitor `AppTelemetry` for "zombie_listeners" or "duplicate_join_storm" alerts.
- **Cohort C (51-100 Users):** External Beta. Focus on **Cost Caps**. Check the `analyze_session_cost.dart` metrics daily against the real Firebase bill.

## 2. Real-Time Monitoring Thresholds
Set these alerts in the MixVy Debug Overlay:
- **Critical:** > 50 Firestore Reads per minute per user. (Indicates a runaway listener).
- **Warning:** > 10 self-healing corrections (ghost speaker removals) in 60 seconds.
- **Action:** If `room_health_score` < 80, investigate the `presence_sync` Cloud Function logs.

## 3. Disaster Recovery (Kill Switches)
If system instability is detected:
1. **Disable Speed Dating:** Matchmaking creates the most "hot" queries.
2. **Limit Room Capacity:** Cap `maxBroadcasters` to 2 via Remote Config.
3. **Mute Global Chat:** Fallback to 1:1 DMs only.

## 4. Feedback Collection
Use the integrated **Beta Feedback Overlay** for all Cohort C users. Prioritize reports tagged with `reconnect` or `crash`.
