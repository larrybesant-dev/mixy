import 'package:flutter_riverpod/flutter_riverpod.dart';

// Tracks which bottom tab is currently selected
final selectedTabIndexProvider = StateProvider<int>((ref) {
  return 0; // Default to Feed (home)
});
