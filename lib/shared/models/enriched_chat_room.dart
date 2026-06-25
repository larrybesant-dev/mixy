/// 🔴 FIX #2: EnrichedChatRoom combines chat room data with user profile and presence
/// This model reduces provider subscriptions from 150+ to 1 for 50 chat items
/// Previously each chat item had:
///   - userProfileProvider(id) subscription
///   - presenceProvider(id) subscription
///   - isTypingProvider(id) subscription
/// Now all combined into single enrichedChatListProvider
class EnrichedChatRoom {
  // Chat room data
  final String id;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isTyping;
  final int unreadCount;

  // Other user profile data
  final String otherUserId;
  final String displayName;
  final String? username;
  final List<String> photos;

  // Presence/online status
  final bool isOnline;
  final DateTime? lastSeen;

  EnrichedChatRoom({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isTyping,
    required this.unreadCount,
    required this.otherUserId,
    required this.displayName,
    this.username,
    required this.photos,
    required this.isOnline,
    this.lastSeen,
  });

  /// Get first character of display name for avatar fallback
  String get displayNameInitial => displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

  /// Get primary avatar URL
  String? get avatarUrl => photos.isNotEmpty ? photos.first : null;
}
