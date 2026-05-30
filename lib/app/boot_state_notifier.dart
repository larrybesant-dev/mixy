import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'boot_state.dart';

/// Manages app boot state as a reactive notifier.
/// Transitions through: loading → ready/degraded/failed
class BootStateNotifier extends StateNotifier<BootState> {
  BootStateNotifier({BootState initialState = BootState.loading})
    : super(initialState);

  bool get isLoadingState => state == BootState.loading;

  /// Move boot flow back into loading state for explicit retry attempts.
  void setLoading() {
    state = BootState.loading;
  }

  /// Mark boot as successful and ready.
  void setReady() {
    if (state == BootState.loading) {
      state = BootState.ready;
    }
  }

  /// Mark boot as partially failed; app continues in degraded mode.
  void setDegraded() {
    state = BootState.degraded;
  }

  /// Mark boot as fatally failed; app cannot proceed.
  void setFailed() {
    state = BootState.failed;
  }
}

/// Reactive boot state provider. Watch this to respond to state changes in real-time.
final bootStateProvider = StateNotifierProvider<BootStateNotifier, BootState>((
  ref,
) {
  return BootStateNotifier();
});



