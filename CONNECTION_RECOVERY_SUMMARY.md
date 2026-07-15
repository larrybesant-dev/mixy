# Connection Recovery Refactoring — Executive Summary

**Document**: CONNECTION_RECOVERY_REFACTORING_GUIDE.md  
**Status**: Ready for implementation  
**Scope**: 4 phases, ~3-4 hours development + 2-3 hours testing  

---

## What We're Fixing

### Current Behavior
- ✗ Connection drops = immediate user-visible failure
- ✗ No automatic reconnection
- ✗ No retry strategy or feedback
- ✗ Logic scattered/absent (no recovery in service layer)

### After Implementation
- ✅ Connection drops trigger automatic reconnection
- ✅ Exponential backoff: 2s → 4s → 8s retry delays
- ✅ Max 3 attempts before giving up
- ✅ Rich state feedback: idle → connecting → degraded → reconnecting → ready/failed
- ✅ Clean UI feedback: "Reconnecting..." message + attempt counter
- ✅ Service-managed recovery (not UI-managed)

---

## Key Changes by File

| File | Change Type | Complexity | Lines |
|------|-------------|-----------|-------|
| `lib/services/rtc_room_service.dart` | Add enum + abstract methods | Low | ~15 |
| `lib/services/agora_service.dart` | Implement reconnection | Medium | ~80 |
| `lib/features/room/providers/room_webrtc_provider.dart` | Enhance state + callbacks | Low | ~30 |
| **Total** | | **Medium** | **~125** |

---

## Implementation Phases

### Phase 1: Abstract Layer (10 mins)
- Add `RtcConnectionState` enum
- Add `reconnect()`, `abortReconnection()` methods to interface
- Add `onConnectionStateChanged` callback

### Phase 2: Agora Implementation (60 mins)
- Add retry scheduling with exponential backoff
- Implement `reconnect()` using stored join credentials
- Wire up connection state transitions
- Add abort/cleanup logic

### Phase 3: Provider Integration (30 mins)
- Extend `RoomWebRTCState` with connection metadata
- Wire callbacks in `RoomWebRTCNotifier`
- Expose `isRecovering`, `reconnectAttemptCount`, `connectionState`

### Phase 4: UI Integration (30 mins)
- Observe `connectionState` in LiveRoomScreen
- Show "Reconnecting..." badge with attempt counter
- Show "Connection failed" error screen after max retries

### Phase 5: Testing (120 mins)
- Test normal join → connected
- Test network drop → auto-reconnect → recovered
- Test max retries → failed state
- Test user-initiated leave (no spurious reconnects)
- Verify UI feedback

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Infinite reconnect loop | Medium | Max retry count + user-initiated disconnect flag |
| Token expiration during retry | Low | Agora SDK handles token refresh automatically |
| Memory leak on failed reconnects | Low | Timers explicitly cancelled + state disposal |
| Breaking existing tests | Low | No changes to public API, only additions |
| Connection state conflicts | Low | Centralized state machine prevents race conditions |

**Overall Risk**: **LOW** — Changes are isolated to service layer, backward-compatible, with clear rollback path.

---

## Success Metrics

**Build**:
- ✅ `flutter analyze` → 0 errors
- ✅ `flutter pub get` → All dependencies resolved

**Functionality**:
- ✅ Automatic reconnection on network drop
- ✅ Exponential backoff validates (2s, 4s, 8s observed in logs)
- ✅ Max 3 attempts honored
- ✅ State transitions correct (idle → connecting → connected → degraded → reconnecting)

**User Experience**:
- ✅ "Reconnecting..." message visible during recovery
- ✅ Attempt counter shown (attempt 1/3, 2/3, 3/3)
- ✅ No false reconnects on user-initiated leave
- ✅ Clear error message after max retries

**Quality**:
- ✅ All existing tests still pass
- ✅ New recovery scenarios tested
- ✅ No spurious console errors/warnings

---

## Next Steps

### Option A: Implement Now
1. Read `CONNECTION_RECOVERY_REFACTORING_GUIDE.md` in full
2. Start with Phase 1 (abstract layer)
3. Work through phases sequentially
4. Test as you go

### Option B: Validate First
1. Review the proposed changes in detail
2. Identify any concerns or conflicts with current architecture
3. Propose modifications if needed
4. Then proceed with implementation

### Option C: Phased Rollout
1. Implement Phase 1-3 (service layer only)
2. Test the reconnection logic in isolation
3. Deploy without UI changes
4. Add UI feedback (Phase 4) in follow-up

---

## Files Involved

**To Modify**:
```
lib/services/rtc_room_service.dart
lib/services/agora_service.dart
lib/features/room/providers/room_webrtc_provider.dart
```

**To Review** (no changes needed):
```
lib/services/webrtc_room_service.dart (Phase 3 later)
lib/features/room/presentation/live_room_screen.dart (UI integration)
```

**No Changes to**:
```
lib/app/app.dart
lib/router/app_router.dart
lib/features/auth/ (auth is separate concern)
lib/features/payments/ (payments unrelated)
```

---

**Which approach appeals to you most?**
- Option A: Jump into implementation?
- Option B: Deeper validation first?
- Option C: Phased approach (service layer only)?
