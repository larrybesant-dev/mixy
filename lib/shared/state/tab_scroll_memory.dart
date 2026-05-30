import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists the outer scroll offset for each AppShell tab across tab switches.
/// Key: tab index (0–4). Value: scroll offset in logical pixels.
///
/// NOT autoDispose — must survive tab disposal so offsets are restored when
/// the user returns to a previously visited tab.
class TabScrollMemoryNotifier extends StateNotifier<Map<int, double>> {
  TabScrollMemoryNotifier() : super(const {});

  void setOffset(int tabIndex, double offset) {
    if (state[tabIndex] == offset) return;
    state = {...state, tabIndex: offset};
  }

  double? getOffset(int tabIndex) => state[tabIndex];
}

final tabScrollMemoryProvider =
    StateNotifierProvider<TabScrollMemoryNotifier, Map<int, double>>(
      (ref) => TabScrollMemoryNotifier(),
    );



