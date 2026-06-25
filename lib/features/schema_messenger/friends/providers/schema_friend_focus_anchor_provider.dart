import 'package:flutter_riverpod/flutter_riverpod.dart';

class SchemaFriendFocusAnchor {
  const SchemaFriendFocusAnchor({
    this.friendId,
    this.scrollOffset = 0,
    this.lastInteractionAt,
  });

  final String? friendId;
  final double scrollOffset;
  final DateTime? lastInteractionAt;

  SchemaFriendFocusAnchor copyWith({
    String? friendId,
    bool clearFriendId = false,
    double? scrollOffset,
    DateTime? lastInteractionAt,
    bool clearLastInteractionAt = false,
  }) {
    return SchemaFriendFocusAnchor(
      friendId: clearFriendId ? null : (friendId ?? this.friendId),
      scrollOffset: scrollOffset ?? this.scrollOffset,
      lastInteractionAt: clearLastInteractionAt
          ? null
          : (lastInteractionAt ?? this.lastInteractionAt),
    );
  }
}

class SchemaFriendFocusAnchorNotifier
    extends StateNotifier<SchemaFriendFocusAnchor> {
  SchemaFriendFocusAnchorNotifier() : super(const SchemaFriendFocusAnchor());

  void setFocusedFriend(String friendId, {bool updateInteractionTime = true}) {
    final normalizedFriendId = friendId.trim();
    if (normalizedFriendId.isEmpty) {
      return;
    }

    final shouldUpdateTime =
        updateInteractionTime ||
        state.friendId != normalizedFriendId ||
        state.lastInteractionAt == null;

    state = state.copyWith(
      friendId: normalizedFriendId,
      lastInteractionAt: shouldUpdateTime
          ? DateTime.now()
          : state.lastInteractionAt,
    );
  }

  void rememberScrollOffset(double offset) {
    if (offset.isNaN || !offset.isFinite || offset < 0) {
      return;
    }
    state = state.copyWith(scrollOffset: offset);
  }
}

final schemaFriendFocusAnchorProvider =
    StateNotifierProvider<
      SchemaFriendFocusAnchorNotifier,
      SchemaFriendFocusAnchor
    >((ref) => SchemaFriendFocusAnchorNotifier());




