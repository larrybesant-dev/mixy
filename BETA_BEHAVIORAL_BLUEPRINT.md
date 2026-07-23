# MixVy Beta Behavioral Success Blueprint

This document defines the "Social Success" metrics for the first 24-48 hours of user activity.

## 1. Primary Behavioral Signals (High Intent)
- **Day 1 Retention (D1):** Do users who sign up in the first 20-user cohort return within 24 hours? 
    - *Success Target:* > 40%.
- **Match-to-Chat Conversion:** Of users who find a match in Speed Dating, how many send at least 3 messages?
    - *Success Target:* > 60%.
- **Room Stability:** Do created rooms stay active for > 5 minutes with at least 2 participants?
    - *Success Target:* > 70%.

## 2. Low-Friction Success Signals
- **Profile Customization:** Do users set an accent color or music within their first session?
- **Mutual Following:** Do users follow someone they met in a Live Room?

## 3. Observability Dashboard (Debug Overlay)
Use the **Operational Debug Overlay** (6-tap trigger) to monitor:
- `active_rooms`: Total live sessions.
- `match_success`: Real-time reciprocated likes.
- `avg_room_mins`: User stickiness in voice/video sessions.

## 4. Failure Modes (Action Required)
- **Signal:** High Match Failures but High Swipes.
    - *Interpretation:* The candidate pool is too small or filtering is too aggressive.
    - *Action:* Adjust `candidatesStream` limit from 40 to 100.
- **Signal:** High Room Drop-off (< 30s).
    - *Interpretation:* WebRTC/Agora connection lag or "Empty Room" social anxiety.
    - *Action:* Enable "System Audio" background music for empty rooms.
