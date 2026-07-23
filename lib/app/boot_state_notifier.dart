import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'boot_state.dart';

/// Manages app boot state as a reactive notifier.
/// Transitions through: loading → ready/degraded/failed
class BootStateNotifier extends StateNotifier<BootState> {
  Timer? _bootstrapTimeout;
  
  BootStateNotifier({BootState initialState = BootState.loading})
    : super(initialState) {
    // PRAGMATIC WORKAROUND: Force app to ready after 3 seconds
    // Auth bootstrap sometimes hangs on web; this prevents indefinite loading screen
    _bootstrapTimeout = Timer(const Duration(seconds: 3), () {
      if (state == BootState.loading) {
        state = BootState.ready;
      }
    });
  }

  bool get isLoadingState => state == BootState.loading;

  /// Move boot flow back into loading state for explicit retry attempts.
  void setLoading() {
    state = BootState.loading;
  }

  /// Mark boot as successful and ready.
  void setReady() {
    _bootstrapTimeout?.cancel();
    if (state == BootState.loading) {
      state = BootState.ready;
    }
  }

  /// Mark boot as partially failed; app continues in degraded mode.
  void setDegraded() {
    _bootstrapTimeout?.cancel();
    state = BootState.degraded;
  }

  /// Mark boot as fatally failed; app cannot proceed.
  void setFailed() {
    _bootstrapTimeout?.cancel();
    state = BootState.failed;
  }
  
  @override
  void dispose() {
    _bootstrapTimeout?.cancel();
    super.dispose();
  }
}

/// Reactive boot state provider. Watch this to respond to state changes in real-time.
final bootStateProvider = StateNotifierProvider<BootStateNotifier, BootState>((
  ref,
) {
  return BootStateNotifier();
});



