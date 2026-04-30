/// Global Firestore Query Policy Layer.
/// Standardizes fetch boundaries to prevent cost spikes and client crashes.
class QueryPolicy {
  const QueryPolicy._();

  // ── Messaging ──────────────────────────────────────────────────────────────
  static const int conversationsLimit = 100;
  static const int messagesLimit = 50;
  static const int messageReactionsLimit = 20;
  static const int typingUsersLimit = 10;

  // ── Rooms & Participants ───────────────────────────────────────────────────
  static const int roomParticipantsLimit = 100;
  static const int roomMembersLimit = 100;
  static const int roomSpeakersLimit = 8;
  static const int roomPresenceLimit = 150;
  static const int modLogLimit = 20;

  // ── Social & Discovery ─────────────────────────────────────────────────────
  static const int friendsLimit = 200;
  static const int friendRequestsLimit = 50;
  static const int friendSuggestionsLimit = 15;
  static const int discoveryRoomsLimit = 50;
  static const int trendingPostsLimit = 30;
  static const int searchResultsLimit = 20;

  // ── Notifications ──────────────────────────────────────────────────────────
  static const int notificationsLimit = 50;
}
