import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/services/connection_recovery_handler.dart';

/// State for connection recovery: tracks if we're recovering and how many attempts
class ConnectionRecoveryState {
  final RtcConnectionState state;
  final int attemptNumber;
  final int maxAttempts;
  final int nextRetryDelayMs;
  final String? lastErrorMessage;

  ConnectionRecoveryState({
    required this.state,
    this.attemptNumber = 0,
    this.maxAttempts = 3,
    this.nextRetryDelayMs = 0,
    this.lastErrorMessage,
  });

  ConnectionRecoveryState copyWith({
    RtcConnectionState? state,
    int? attemptNumber,
    int? maxAttempts,
    int? nextRetryDelayMs,
    String? lastErrorMessage,
  }) {
    return ConnectionRecoveryState(
      state: state ?? this.state,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      nextRetryDelayMs: nextRetryDelayMs ?? this.nextRetryDelayMs,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
    );
  }

  bool get isRecovering => state == RtcConnectionState.degraded || 
                           state == RtcConnectionState.reconnecting;
  bool get isFailed => state == RtcConnectionState.failed;
  bool get isConnected => state == RtcConnectionState.connected;
}

/// Notifier for managing connection recovery
class ConnectionRecoveryNotifier extends StateNotifier<ConnectionRecoveryState> {
  ConnectionRecoveryNotifier()
      : super(ConnectionRecoveryState(state: RtcConnectionState.idle)) {
    _initializeHandler();
  }

  late final ConnectionRecoveryHandler _handler;

  void _initializeHandler() {
    _handler = ConnectionRecoveryHandler(
      maxRetries: 3,
      baseDelayMs: 2000,
      onStateChange: (newState) {
        state = state.copyWith(
          state: newState,
          attemptNumber: newState == RtcConnectionState.reconnecting 
              ? state.attemptNumber + 1 
              : 0,
        );
      },
      onRetryAttempt: (attemptNum, delayMs) {
        state = state.copyWith(
          attemptNumber: attemptNum,
          nextRetryDelayMs: delayMs,
        );
      },
    );
  }

  /// Trigger recovery when connection is lost
  Future<void> beginRecovery({
    required Future<void> Function() onReconnect,
    String? errorMessage,
  }) async {
    state = state.copyWith(
      lastErrorMessage: errorMessage,
    );
    await _handler.beginRecovery(onReconnect: onReconnect);
  }

  /// Abort recovery and reset to idle
  Future<void> abort() async {
    await _handler.abort();
    state = ConnectionRecoveryState(state: RtcConnectionState.idle);
  }

  /// Reset state when connection succeeds
  void reset() {
    _handler.reset();
    state = ConnectionRecoveryState(state: RtcConnectionState.idle);
  }
}

/// Riverpod provider for connection recovery state management
final connectionRecoveryProvider =
    StateNotifierProvider<ConnectionRecoveryNotifier, ConnectionRecoveryState>(
  (ref) => ConnectionRecoveryNotifier(),
);
