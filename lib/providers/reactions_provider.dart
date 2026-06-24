import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReactionsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};

  void addReaction(String reactionType) {
    state = {
      ...state,
      reactionType: (state[reactionType] ?? 0) + 1,
    };
  }

  void removeReaction(String reactionType) {
    final updated = {...state};
    final current = updated[reactionType] ?? 0;
    if (current > 1) {
      updated[reactionType] = current - 1;
    } else {
      updated.remove(reactionType);
    }
    state = updated;
  }

  void clearReactions() {
    state = {};
  }

  // Compatibility method for update-based code
  void update(Map<String, int> Function(Map<String, int>) callback) {
    state = callback(state);
  }
}

final reactionsProvider = NotifierProvider<ReactionsNotifier, Map<String, int>>(
  () => ReactionsNotifier(),
);
// Key: reaction type, Value: count
