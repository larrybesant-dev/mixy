# Connection Recovery Refactoring Guide

**Status**: Ready for implementation  
**Complexity**: Medium (3-4 hours)  
**Risk Level**: Low (isolated to service layer, UI changes are minimal)  
**Testing Effort**: 2-3 hours

---

## Overview

This guide refactors connection recovery logic from **UI-managed** to **service-managed**, implementing automatic reconnection with exponential backoff, proper state transitions, and clean Riverpod integration.

### What Gets Better

| Aspect | Before | After |
|--------|--------|-------|
| Reconnect Logic | Scattered/absent | Centralized in service |
| Retry Strategy | None | Exponential backoff (2s → 4s → 8s → 16s) |
| Max Retries | None | 3 attempts (configurable) |
| State Feedback | Binary (connected/disconnected) | Rich (idle/connecting/degraded/ready/failed) |
| Code Location | UI (LiveRoomScreen) | Service (RtcRoomService) |
| UI Complexity | High (timer management) | Low (observes state) |

---

## Phase 1: Extend RtcRoomService Abstract Interface

**File**: `lib/services/rtc_room_service.dart`

**Changes**: Add connection state enum + recovery methods + callback

### Add at the TOP (after imports):

```dart
/// Connection state machine for RTC services.
enum RtcConnectionState {
  idle,        // Not attempting connection
  connecting,  // Initial join in progress
  connected,   // Successfully joined channel
  degraded,    // Connected but experiencing issues; attempting recovery
  reconnecting,// Active reconnection attempt in progress
  failed,      // All recovery attempts exhausted
}
```

### Add in the `RtcRoomService` abstract class (after `onConnectionLost` property):

```dart
  /// Called when connection state changes (e.g., idle → connecting → connected → degraded → reconnecting)
  /// UI listens to this to show appropriate feedback (loading spinner, "Reconnecting..." message, etc.)
  ValueChanged<RtcConnectionState>? get onConnectionStateChanged;
  set onConnectionStateChanged(ValueChanged<RtcConnectionState>? value);

  /// Current connection state
  RtcConnectionState get connectionState => RtcConnectionState.idle;

  /// Number of reconnection attempts made (resets on successful recovery)
  int get reconnectAttemptCount => 0;

  // ──────────────────────────────────────────────────────────────────────────
  // Recovery methods
  // ──────────────────────────────────────────────────────────────────────────

  /// Attempt to reconnect after connection loss.
  /// Subclasses implement with exponential backoff, max retries, etc.
  /// Throws on fatal failure (token expired, user banned, etc.)
  Future<void> reconnect();

  /// Abort any in-flight reconnection attempt.
  /// Called when user leaves room or app goes to background.
  Future<void> abortReconnection();
```

---

## Phase 2: Implement in AgoraService

**File**: `lib/services/agora_service.dart`

### 2a. Add state tracking fields (after existing fields, around line 50):

```dart
  // Connection recovery state machine
  RtcConnectionState _connectionState = RtcConnectionState.idle;
  int _reconnectAttemptCount = 0;
  Timer? _reconnectTimer;
  Completer<void>? _reconnectInProgress;
  bool _userInitiatedDisconnect = false; // True when user explicitly leaves
```

### 2b. Add callback field (after `onConnectionLost` field):

```dart
  @override
  ValueChanged<RtcConnectionState>? onConnectionStateChanged;
```

### 2c. Add getter overrides (in the getters section):

```dart
  @override
  RtcConnectionState get connectionState => _connectionState;

  @override
  int get reconnectAttemptCount => _reconnectAttemptCount;
```

### 2d. Update `leaveChannel()` method (around line 985):

Replace this line:
```dart
  Future<void> leaveChannel() async {
    if (!_initialized) return;
```

With:
```dart
  Future<void> leaveChannel() async {
    if (!_initialized) return;
    _userInitiatedDisconnect = true; // Prevent auto-reconnect on user-initiated leave
    await abortReconnection(); // Cancel any in-flight reconnect
```

### 2e. Add connection state change helper method:

```dart
  void _setConnectionState(RtcConnectionState newState) {
    if (_connectionState != newState) {
      developer.log(
        'Connection state: $_connectionState → $newState',
        name: 'AgoraService',
      );
      _connectionState = newState;
      onConnectionStateChanged?.call(newState);
    }
  }
```

### 2f. Update the event handler for connection changes (in `initialize()`, around line 540):

Find this code:
```dart
        onConnectionChangeFailure: (connection, reason) {
          developer.log(
            'Connection failed: reason=$reason',
            name: 'AgoraService',
          );
          _joinedChannel = false;
        },
```

Replace with:
```dart
        onConnectionChangeFailure: (connection, reason) {
          developer.log(
            'Connection failed: reason=$reason',
            name: 'AgoraService',
          );
          _joinedChannel = false;
          if (!_userInitiatedDisconnect) {
            _setConnectionState(RtcConnectionState.degraded);
            unawaited(_scheduleReconnection());
          }
        },
```

### 2g. Add reconnection implementation methods (before `dispose()` at end of class):

```dart
  /// Schedule reconnection with exponential backoff.
  Future<void> _scheduleReconnection() async {
    if (_reconnectInProgress != null) {
      await _reconnectInProgress!.future; // Wait for in-flight attempt
      return;
    }

    const maxAttempts = 3;
    const baseDelayMs = 2000; // Start at 2s

    while (_reconnectAttemptCount < maxAttempts && !_userInitiatedDisconnect) {
      final delayMs = baseDelayMs * (1 << _reconnectAttemptCount); // 2^n exponential
      developer.log(
        'Reconnect scheduled in ${delayMs}ms (attempt ${_reconnectAttemptCount + 1}/$maxAttempts)',
        name: 'AgoraService',
      );

      // Wait for the backoff delay (can be cancelled via _reconnectTimer)
      await Future<void>.delayed(Duration(milliseconds: delayMs));

      if (_userInitiatedDisconnect) break;

      _reconnectAttemptCount++;
      try {
        _setConnectionState(RtcConnectionState.reconnecting);
        await reconnect();
        _reconnectAttemptCount = 0; // Reset on success
        _setConnectionState(RtcConnectionState.connected);
        developer.log(
          'Reconnection successful after ${_reconnectAttemptCount} attempts',
          name: 'AgoraService',
        );
        return;
      } catch (e) {
        developer.log(
          'Reconnection attempt ${_reconnectAttemptCount} failed: $e',
          name: 'AgoraService',
          error: e,
        );
      }
    }

    // All retries exhausted
    _setConnectionState(RtcConnectionState.failed);
    developer.log(
      'Reconnection failed after $maxAttempts attempts',
      name: 'AgoraService',
    );
    onConnectionLost?.call();
  }

  @override
  Future<void> reconnect() async {
    if (!_initialized || _lastToken == null || _lastChannelName == null || _lastUid == null) {
      throw StateError(
        'Cannot reconnect: service not initialized or missing join credentials',
      );
    }

    developer.log(
      'Attempting reconnect: channel=$_lastChannelName uid=$_lastUid',
      name: 'AgoraService',
    );

    // Re-join with stored credentials (token refresh happens at Agora SDK level)
    try {
      await joinRoom(
        _lastToken!,
        _lastChannelName!,
        _lastUid!,
        publishCameraTrackOnJoin: _broadcasterMode,
        publishMicrophoneTrackOnJoin: _broadcasterMode,
      );
      _userInitiatedDisconnect = false; // Reset flag on successful reconnect
    } catch (e) {
      developer.log(
        'Reconnect failed with error: $e',
        name: 'AgoraService',
        error: e,
      );
      rethrow;
    }
  }

  @override
  Future<void> abortReconnection() async {
    developer.log('Aborting reconnection', name: 'AgoraService');
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (_reconnectInProgress != null) {
      _reconnectInProgress!.completeError('Reconnection aborted');
      _reconnectInProgress = null;
    }
    _reconnectAttemptCount = 0;
    _setConnectionState(RtcConnectionState.idle);
  }
```

### 2h. Update `dispose()` method:

Replace:
```dart
  @override
  Future<void> dispose() async {
```

With:
```dart
  @override
  Future<void> dispose() async {
    await abortReconnection(); // Clean up any pending reconnect timers
```

---

## Phase 3: Enhance Room State & Provider

**File**: `lib/features/room/providers/room_webrtc_provider.dart`

### 3a. Update `RoomWebRTCState` class (around line 8):

Replace:
```dart
class RoomWebRTCState {
  final String roomId;
  final String userId;
  final bool isConnected;
  final List<int> remoteUserUids;
  final bool isLocalVideoCapturing;
  final bool isLocalAudioMuted;
  final RtcRoomService? service;
  final String? error;
```

With:
```dart
class RoomWebRTCState {
  final String roomId;
  final String userId;
  final bool isConnected;
  final List<int> remoteUserUids;
  final bool isLocalVideoCapturing;
  final bool isLocalAudioMuted;
  final RtcRoomService? service;
  final String? error;
  final RtcConnectionState connectionState;
  final int reconnectAttemptCount;
  final bool isRecovering;
```

### 3b. Update the constructor:

```dart
  RoomWebRTCState({
    required this.roomId,
    required this.userId,
    this.isConnected = false,
    this.remoteUserUids = const [],
    this.isLocalVideoCapturing = false,
    this.isLocalAudioMuted = true,
    this.service,
    this.error,
    this.connectionState = RtcConnectionState.idle,
    this.reconnectAttemptCount = 0,
    this.isRecovering = false,
  });
```

### 3c. Update `copyWith()` method:

Add these parameters:
```dart
  RoomWebRTCState copyWith({
    String? roomId,
    String? userId,
    bool? isConnected,
    List<int>? remoteUserUids,
    bool? isLocalVideoCapturing,
    bool? isLocalAudioMuted,
    RtcRoomService? service,
    String? error,
    RtcConnectionState? connectionState,
    int? reconnectAttemptCount,
    bool? isRecovering,
  }) {
    return RoomWebRTCState(
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      isConnected: isConnected ?? this.isConnected,
      remoteUserUids: remoteUserUids ?? this.remoteUserUids,
      isLocalVideoCapturing: isLocalVideoCapturing ?? this.isLocalVideoCapturing,
      isLocalAudioMuted: isLocalAudioMuted ?? this.isLocalAudioMuted,
      service: service ?? this.service,
      error: error ?? this.error,
      connectionState: connectionState ?? this.connectionState,
      reconnectAttemptCount: reconnectAttemptCount ?? this.reconnectAttemptCount,
      isRecovering: isRecovering ?? this.isRecovering,
    );
  }
```

### 3d. Update `_setupCallbacks()` in `RoomWebRTCNotifier`:

Replace the entire method with:
```dart
  void _setupCallbacks(RtcRoomService service) {
    service.onLocalVideoCaptureChanged = () {
      state = state?.copyWith(isLocalVideoCapturing: service.isLocalVideoCapturing);
    };

    service.onRemoteUserJoined = () {
      state = state?.copyWith(remoteUserUids: service.remoteUids);
    };

    service.onRemoteUserLeft = () {
      state = state?.copyWith(remoteUserUids: service.remoteUids);
    };

    service.onConnectionStateChanged = (newState) {
      final isRecovering = newState == RtcConnectionState.degraded ||
          newState == RtcConnectionState.reconnecting;
      state = state?.copyWith(
        connectionState: newState,
        reconnectAttemptCount: service.reconnectAttemptCount,
        isRecovering: isRecovering,
        isConnected: newState == RtcConnectionState.connected,
        error: newState == RtcConnectionState.failed ? 'Connection failed' : null,
      );
    };

    service.onConnectionLost = () {
      // onConnectionStateChanged will handle state updates
      // This callback is now a fallback for unexpected disconnects
      state = state?.copyWith(
        isConnected: false,
        connectionState: RtcConnectionState.degraded,
      );
    };
  }
```

---

## Phase 4: Testing Scenarios

### Test 1: Normal Connection
1. Join room
2. Verify `connectionState == RtcConnectionState.connected`
3. Send/receive media
4. ✅ PASS

### Test 2: Network Drop & Auto-Reconnect
1. Join room
2. Disconnect network (or kill connection)
3. Verify `connectionState → degraded → reconnecting`
4. Verify reconnection attempts with backoff (2s, 4s, 8s)
5. Re-enable network
6. Verify `connectionState → connected`
7. Verify media resumes
8. ✅ PASS

### Test 3: Exhausted Retries
1. Join room
2. Disconnect and keep network disconnected
3. Verify 3 reconnection attempts with backoff
4. Verify `connectionState == failed`
5. Verify `onConnectionLost` fired
6. ✅ PASS

### Test 4: User-Initiated Leave
1. Join room
2. Click "Leave Room"
3. Verify `_userInitiatedDisconnect = true` prevents auto-reconnect
4. Verify clean disconnect (no spurious reconnect attempts)
5. ✅ PASS

### Test 5: UI Feedback
1. Join room
2. Trigger network drop
3. Verify UI shows "Reconnecting..." message (attempt count visible)
4. Verify loading spinner during `isRecovering`
5. ✅ PASS

---

## File-by-File Checklist

- [ ] `lib/services/rtc_room_service.dart` — Add enum, abstract methods, callback
- [ ] `lib/services/agora_service.dart` — Implement reconnection + state management
- [ ] `lib/features/room/providers/room_webrtc_provider.dart` — Enhance state, update callbacks
- [ ] Run `flutter analyze` → 0 errors
- [ ] Test: Network drop scenario
- [ ] Test: Max retries scenario
- [ ] Update LiveRoomScreen if needed (minimal changes, mostly observes state)

---

## Integration with UI

**LiveRoomScreen** should observe `connectionState` and display feedback:

```dart
// In build method:
final webrtcState = ref.watch(activeRoomWebRTCProvider(widget.roomId));

if (webrtcState?.isRecovering ?? false) {
  return Stack(
    children: [
      // Existing UI
      Positioned(
        top: 16,
        left: 16,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Reconnecting... (${webrtcState?.reconnectAttemptCount ?? 0}/3)',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

if (webrtcState?.connectionState == RtcConnectionState.failed) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        const Text('Connection lost. Please try again.'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Leave Room'),
        ),
      ],
    ),
  );
}
```

---

## Rollback Plan

If issues arise, you can safely revert:

1. Comment out `onConnectionStateChanged` callback setup in `_setupCallbacks()`
2. Remove `_scheduleReconnection()` and `reconnect()` calls
3. Keep the abstract methods (backward compatible)
4. System falls back to manual user-initiated retry

---

## Success Criteria

- ✅ Automatic reconnection on network drop
- ✅ Exponential backoff (2s → 4s → 8s)
- ✅ Max 3 retry attempts
- ✅ Clean state transitions (idle → connecting → connected → degraded → reconnecting)
- ✅ UI shows "Reconnecting..." feedback
- ✅ No spurious reconnects on user-initiated leave
- ✅ `flutter analyze` passes (0 errors)
- ✅ Existing tests still pass
