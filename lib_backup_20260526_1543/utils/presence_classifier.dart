/// Shared rules for interpreting presence timestamps.
///
/// All presence-state decisions (friends list, room participants, discovery
/// feed, DMs) must derive from this single classifier so time-window
/// definitions never drift between features.
///
/// Truth layers:
///   RTDB heartbeat  → raw `lastSeen` timestamp
///   PresenceModel   → `isOnline` / `isStale` (60 s system rule)
///   PresenceClassifier → UI-policy windows (this file)
class PresenceClassifier {
  PresenceClassifier._();

  /// A user whose heartbeat is this recent is shown as "Online".
  static const Duration onlineWindow = Duration(seconds: 60);

  /// A user whose heartbeat is this recent (but > [onlineWindow]) is shown as
  /// "Recently active" rather than immediately dropped to Offline.
  static const Duration recentlyActiveWindow = Duration(minutes: 5);

  /// A user whose heartbeat is this recent (but > [recentlyActiveWindow]) is
  /// shown as "Idle" rather than fully Offline.
  static const Duration idleWindow = Duration(minutes: 15);

  /// Returns true when [lastSeen] falls in the recently-active band:
  /// > 60 s but ≤ 5 min since last heartbeat.
  static bool isRecentlyActive(DateTime? lastSeen) {
    if (lastSeen == null) return false;
    final delta = DateTime.now().difference(lastSeen);
    return delta > onlineWindow && delta <= recentlyActiveWindow;
  }

  /// Returns true when [lastSeen] falls in the idle band:
  /// > 5 min but ≤ 15 min since last heartbeat.
  static bool isIdle(DateTime? lastSeen) {
    if (lastSeen == null) return false;
    final delta = DateTime.now().difference(lastSeen);
    return delta > recentlyActiveWindow && delta <= idleWindow;
  }

  /// Human-readable label for a non-online user, used across all features.
  static String lastSeenLabel(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';
    final delta = DateTime.now().difference(lastSeen);
    if (delta.inMinutes < 1) return 'Last seen just now';
    if (delta.inMinutes < 60) return 'Last seen ${delta.inMinutes}m ago';
    if (delta.inHours < 24) return 'Last seen ${delta.inHours}h ago';
    return 'Last seen ${delta.inDays}d ago';
  }
}
