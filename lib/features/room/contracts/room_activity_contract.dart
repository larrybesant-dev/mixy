import '../providers/presence_provider.dart';

class RoomActivityContract {
  /// Returns true when the UI should rebuild.
  ///
  /// Uses structural comparison for both typing and presence to avoid
  /// string allocation on every check and to be resilient to Map
  /// insertion-order differences.
  static bool shouldRebuild(
    List<RoomPresenceModel> oldPresence,
    List<RoomPresenceModel> newPresence,
    Map<String, bool> oldTyping,
    Map<String, bool> newTyping,
  ) {
    // Typing: check length then per-key values.
    if (oldTyping.length != newTyping.length) return true;
    for (final entry in newTyping.entries) {
      if (oldTyping[entry.key] != entry.value) return true;
    }
    // Presence: check length then per-user online state.
    if (oldPresence.length != newPresence.length) return true;
    final oldById = <String, RoomPresenceModel>{
      for (final p in oldPresence) p.userId: p,
    };
    for (final p in newPresence) {
      final old = oldById[p.userId];
      if (old == null || old.isOnline != p.isOnline) return true;
    }
    return false;
  }
}
