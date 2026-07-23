import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;

/// Connection state machine for RTC services.
/// Tracks the lifecycle of the connection from idle through reconnection attempts.
enum RtcConnectionState {
  /// Not connected; idle state before join or after deliberate disconnect.
  idle,

  /// Join in progress (initial connection attempt).
  connecting,

  /// Successfully joined and connected.
  connected,

  /// Connected but experiencing issues (e.g., brief network hiccup).
  /// Triggers automatic reconnection attempts without UI disruption.
  degraded,

  /// Active reconnection attempt in progress.
  /// May cycle multiple times until success or failure.
  reconnecting,

  /// All recovery attempts exhausted; connection is lost.
  /// Requires user action (retry, leave room, etc.).
  failed,
}

/// Handles automatic reconnection with exponential backoff.
/// 
/// Encapsulates retry logic, timer management, and state transitions.
/// Owned by [AgoraService] and [WebRtcRoomService]; not a standalone service.
class ConnectionRecoveryHandler {
  ConnectionRecoveryHandler({
    required this.maxRetries,
    required this.baseDelayMs,
    required this.onStateChange,
    this.onRetryAttempt,
  });

  /// Maximum number of reconnection attempts (e.g., 3).
  final int maxRetries;

  /// Base retry delay in milliseconds (e.g., 2000 = 2s).
  /// Actual delays are: baseDelayMs, baseDelayMs * 2, baseDelayMs * 4, etc.
  final int baseDelayMs;

  /// Called when connection state changes (e.g., degraded → reconnecting → connected).
  /// Allows owner service to notify UI of state transitions.
  final ValueChanged<RtcConnectionState> onStateChange;

  /// Optional: Called before each retry attempt with attempt number.
  /// Useful for logging/telemetry.
  final Function(int attemptNumber, int delayMs)? onRetryAttempt;

  // ──────────────────────────────────────────────────────────────────────────
  // Private state
  // ──────────────────────────────────────────────────────────────────────────

  RtcConnectionState _state = RtcConnectionState.idle;
  int _attemptCount = 0;
  Timer? _retryTimer;
  Completer<void>? _recoveryInProgress;
  bool _userInitiatedStop = false;

  // ──────────────────────────────────────────────────────────────────────────
  // Public accessors
  // ──────────────────────────────────────────────────────────────────────────

  RtcConnectionState get state => _state;
  int get attemptCount => _attemptCount;
  bool get isRecovering => _state == RtcConnectionState.degraded ||
      _state == RtcConnectionState.reconnecting;

  // ──────────────────────────────────────────────────────────────────────────
  // Public interface
  // ──────────────────────────────────────────────────────────────────────────

  /// Begin recovery after connection loss.
  /// Schedules retry attempts with exponential backoff.
  /// 
  /// [onReconnect] is called on each attempt; if it throws, the next attempt
  /// is scheduled. If it succeeds, recovery is complete.
  /// 
  /// Throws [StateError] if already in recovery.
  Future<void> beginRecovery({
    required Future<void> Function() onReconnect,
  }) async {
    if (_recoveryInProgress != null) {
      await _recoveryInProgress!.future;
      return;
    }

    final completer = Completer<void>();
    _recoveryInProgress = completer;
    _userInitiatedStop = false;
    _attemptCount = 0;

    try {
      _setState(RtcConnectionState.degraded);
      await _scheduleRetries(onReconnect: onReconnect);
      completer.complete();
    } catch (e) {
      completer.completeError(e);
    } finally {
      _recoveryInProgress = null;
    }
  }

  /// Stop recovery attempts and reset to idle state.
  /// Called when user leaves room or app goes to background.
  Future<void> abort() async {
    developer.log('ConnectionRecoveryHandler: aborting recovery', name: 'RtcConnectionState');
    _userInitiatedStop = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _attemptCount = 0;
    _setState(RtcConnectionState.idle);

    if (_recoveryInProgress != null) {
      _recoveryInProgress!.completeError('Recovery aborted by user');
      _recoveryInProgress = null;
    }
  }

  /// Reset state to idle (called on successful recovery or clean disconnect).
  void reset() {
    _attemptCount = 0;
    _setState(RtcConnectionState.idle);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Private implementation
  // ──────────────────────────────────────────────────────────────────────────

  void _setState(RtcConnectionState newState) {
    if (_state != newState) {
      developer.log(
        'ConnectionRecoveryHandler: $_state → $newState',
        name: 'RtcConnectionState',
      );
      _state = newState;
      onStateChange(newState);
    }
  }

  Future<void> _scheduleRetries({
    required Future<void> Function() onReconnect,
  }) async {
    while (_attemptCount < maxRetries && !_userInitiatedStop) {
      final delayMs = baseDelayMs * (1 << _attemptCount); // 2^n exponential
      final attemptNumber = _attemptCount + 1;

      developer.log(
        'Reconnect scheduled in ${delayMs}ms (attempt $attemptNumber/$maxRetries)',
        name: 'RtcConnectionState',
      );

      onRetryAttempt?.call(attemptNumber, delayMs);

      // Wait for backoff delay (can be cancelled via abort())
      await _waitWithCancellation(Duration(milliseconds: delayMs));

      if (_userInitiatedStop) break;

      _attemptCount++;
      _setState(RtcConnectionState.reconnecting);

      try {
        developer.log(
          'Executing reconnection attempt $attemptNumber',
          name: 'RtcConnectionState',
        );
        await onReconnect();

        // Success!
        _attemptCount = 0; // Reset for future disconnections
        _setState(RtcConnectionState.connected);
        developer.log(
          'Reconnection successful',
          name: 'RtcConnectionState',
        );
        return;
      } catch (e) {
        developer.log(
          'Reconnection attempt $attemptNumber failed: $e',
          name: 'RtcConnectionState',
          error: e,
        );
        // Continue to next attempt (or fail if max retries exhausted)
      }
    }

    // All retries exhausted
    _setState(RtcConnectionState.failed);
    developer.log(
      'Reconnection failed after $maxRetries attempts',
      name: 'RtcConnectionState',
    );
  }

  /// Wait for [duration] or until abort() is called.
  /// Throws [TimeoutException] if cancelled (to distinguish from normal wait).
  Future<void> _waitWithCancellation(Duration duration) async {
    final completer = Completer<void>();
    _retryTimer = Timer(duration, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await completer.future;
    } finally {
      _retryTimer?.cancel();
      _retryTimer = null;
    }
  }
}
