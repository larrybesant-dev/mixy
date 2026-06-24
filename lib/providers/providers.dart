import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../services/auth/auth_service.dart';
import '../services/infra/firestore_service.dart';
import '../services/analytics/analytics_service.dart';
// REMOVED: import '../services/agora_service.dart'; - Use AgoraVideoService instead
import '../services/messaging_service.dart';
import '../services/social/social_service.dart';
import '../services/payments/tipping_service.dart';
import '../services/storage/storage_service.dart';
import '../services/infra/token_service.dart';
import '../services/notification_service.dart';
import '../services/room/room_service.dart';
import '../services/moderation/moderation_service.dart';
import '../services/chat/typing_service.dart';
import '../services/payments/coin_economy_service.dart';
import '../services/payments/subscription_service.dart';
import '../shared/models/user.dart';
import '../shared/models/room.dart';
import '../shared/models/privacy_settings.dart';
import '../shared/models/direct_message.dart';
import '../shared/models/message.dart';
import '../shared/models/notification.dart' as app_notification;
import '../shared/models/tip.dart';

// Services
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());
final analyticsServiceProvider =
    Provider<AnalyticsService>((ref) => AnalyticsService());

// Placeholder service providers
// DEPRECATED: Use agoraVideoServiceProvider instead
// DISABLED: Commented out to prevent dual engine initialization
// final agoraServiceProvider = Provider<AgoraService>((ref) {
//   debugPrint('âš ï¸ agoraServiceProvider accessed - please use agoraVideoServiceProvider instead');
//   return AgoraService();
// });
final messagingServiceProvider =
    Provider<MessagingService>((ref) => MessagingService());
final socialServiceProvider = Provider<SocialService>((ref) => SocialService());
final tippingServiceProvider =
    Provider<TippingService>((ref) => TippingService());
final storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());
final tokenServiceProvider = Provider<TokenService>((ref) => TokenService());
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

// Mark notification as read
final markNotificationAsReadProvider =
    FutureProvider.family<void, String>((ref, notificationId) async {
  final notificationService = ref.watch(notificationServiceProvider);
  await notificationService.markAsRead(notificationId);
});

// Auth State
final authStateProvider = StreamProvider<firebase_auth.User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Current User
final currentUserProvider = StreamProvider<User?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.when(
    data: (user) {
      if (user != null) {
        return ref.watch(firestoreServiceProvider).getUserStream(user.uid);
      }
      return Stream.value(null);
    },
    loading: () => Stream.value(null),
    error: (error, stack) => Stream.value(null),
  );
});

// User by ID
final userProvider = StreamProvider.family<User?, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getUserStream(userId);
});

// Browse Rooms (with search)
final browseRoomsProvider =
    NotifierProvider<BrowseRoomsNotifier, List<Room>>(() {
  return BrowseRoomsNotifier();
});

class BrowseRoomsNotifier extends Notifier<List<Room>> {
  @override
  List<Room> build() {
    return [];
  }

  void loadRooms() {
    // This would normally watch the roomsProvider
    // For now, return empty list
  }

  void searchRooms(String query) {
    // Placeholder: Implement search logic here
    // For now, filter by room name
    state = []; // Would filter from actual rooms
  }
}

// Discover Users
final usersProvider = StreamProvider<List<User>>((ref) {
  return ref.watch(firestoreServiceProvider).getUsersStream();
});

final discoverUsersProvider =
    NotifierProvider<DiscoverUsersNotifier, List<User>>(() {
  return DiscoverUsersNotifier();
});

class DiscoverUsersNotifier extends Notifier<List<User>> {
  @override
  List<User> build() {
    return [];
  }

  void loadUsers() {
    // This would normally watch the usersProvider
    // For now, return empty list
  }

  void searchUsers(String query) {
    // Placeholder: Implement search logic here
    state = []; // Would filter from actual users
  }
}

// Messages
final conversationsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value([]);
  // Placeholder: Return empty list for now
  return Stream.value([]);
});

// Settings
final settingsProvider =
    NotifierProvider<SettingsNotifier, Map<String, dynamic>>(() {
  return SettingsNotifier();
});

class SettingsNotifier extends Notifier<Map<String, dynamic>> {
  @override
  Map<String, dynamic> build() {
    return {'notifications': true, 'privacy': 'public'};
  }

  void updateSetting(String key, dynamic value) {
    state = {...state, key: value};
  }
}

// Speed Dating - DISABLED FOR V1 LAUNCH
// final speedDatingSessionsProvider = StreamProvider<List<SpeedDatingSession>>((ref) {
//   // Placeholder: Return empty list for now
//   return Stream.value([]);
// });

// Video Service Provider (Agora)
// DEPRECATED: Use agoraVideoServiceProvider from all_providers.dart instead
// final videoServiceProvider = Provider<AgoraService>((ref) => AgoraService());

// Message providers
final sendMessageProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final messagingService = ref.read(messagingServiceProvider);
  await messagingService.sendMessage(
    senderId: params['senderId'],
    receiverId: params['receiverId'],
    content: params['content'],
  );
});

// Room message providers
final sendRoomMessageProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  final messagingService = ref.read(messagingServiceProvider);
  await messagingService.sendRoomMessage(
    senderId: currentUser.id,
    senderName: currentUser.displayName ?? 'Unknown User',
    senderAvatarUrl: currentUser.avatarUrl,
    roomId: params['roomId'],
    content: params['content'],
  );
});

final messagesProvider =
    StreamProvider.family<List<Message>, String>((ref, roomId) {
  final messagingService = ref.read(messagingServiceProvider);
  return messagingService.getRoomMessages(roomId);
});

// Placeholder providers for "coming soon" features
final followProvider = FutureProvider.family<void, String>((ref, userId) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  final socialService = ref.read(socialServiceProvider);
  await socialService.followUser(currentUser.id, userId);
});

final messageProvider =
    FutureProvider.family<void, String>((ref, userId) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  // This provider is for initiating a conversation, not sending a message
  // The actual message sending is handled by sendDirectMessageProvider
});

// DISABLED FOR V1 - Speed Dating Lobby State
// class SpeedDatingLobbyState {
//   final bool isSearching;
//   final SpeedDatingSession? currentSession;
//   final String? error;
//   SpeedDatingLobbyState({required this.isSearching, this.currentSession, this.error});
// }

// Placeholder providers for missing functionality
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() {
  return SearchQueryNotifier();
});

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) {
    state = query;
  }
}

final isFollowingProvider =
    FutureProvider.family<bool, Map<String, String>>((ref, params) async {
  final socialService = ref.read(socialServiceProvider);
  return await socialService.isFollowing(
      params['followerId']!, params['followingId']!);
});

final followersProvider =
    StreamProvider.family<List<User>, String>((ref, userId) {
  final socialService = ref.read(socialServiceProvider);
  return socialService.getFollowersStream(userId);
});

final followingProvider =
    StreamProvider.family<List<User>, String>((ref, userId) {
  final socialService = ref.read(socialServiceProvider);
  return socialService.getFollowingStream(userId);
});

final userConversationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value([]);

  final messagingService = ref.read(messagingServiceProvider);
  return messagingService.getUserConversations(currentUser.id);
});

final totalUnreadMessagesProvider = FutureProvider<int>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Future.value(0);

  final messagingService = ref.read(messagingServiceProvider);
  return messagingService.getTotalUnreadCount(currentUser.id);
});

final conversationMessagesProvider =
    StreamProvider.family<List<DirectMessage>, Map<String, String>>(
        (ref, params) {
  final messagingService = ref.read(messagingServiceProvider);
  return messagingService.getConversationMessages(
      params['userId1']!, params['userId2']!);
});

final sendDirectMessageProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  final messagingService = ref.read(messagingServiceProvider);
  await messagingService.sendMessage(
    senderId: currentUser.id,
    receiverId: params['receiverId'],
    content: params['content'],
    type: params['type'] ?? DirectMessageType.text,
    mediaUrl: params['mediaUrl'],
    thumbnailUrl: params['thumbnailUrl'],
    metadata: params['metadata'],
  );
});

final markMessagesReadProvider =
    FutureProvider.family<void, String>((ref, conversationId) async {
  // Placeholder: Do nothing
});

final markMessageAsDeliveredProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  // Placeholder: Do nothing
});

final editMessageProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  final messagingService = ref.read(messagingServiceProvider);
  await messagingService.editMessage(
      params['messageId'], currentUser.id, params['newContent']);
});

final deleteMessageProvider =
    FutureProvider.family<void, Map<String, String>>((ref, params) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  final messagingService = ref.read(messagingServiceProvider);
  await messagingService.deleteMessage(params['messageId']!, currentUser.id);
});

final addReactionProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  final messagingService = ref.read(messagingServiceProvider);
  await messagingService.addReaction(
      params['messageId'], currentUser.id, params['emoji']);
});

final removeReactionProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  final messagingService = ref.read(messagingServiceProvider);
  await messagingService.removeReaction(
      params['messageId'], currentUser.id, params['emoji']);
});

final markConversationAsReadProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  // Placeholder: Do nothing
});

final privacySettingsProvider = StreamProvider<PrivacySettings?>((ref) {
  // Placeholder: Return null
  return Stream.value(null);
});

final notificationsProvider =
    StreamProvider.family<List<app_notification.Notification>, String>(
        (ref, userId) {
  // Placeholder: Return empty list
  return Stream.value([]);
});

final userTipsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  // Placeholder: Return empty list
  return Stream.value([]);
});

final userMediaProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  // Placeholder: Return empty list
  return Stream.value([]);
});

final createRoomProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final currentUser = ref.watch(authStateProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  // Fetch user profile to get displayName
  final userProfile =
      await ref.read(firestoreServiceProvider).getUser(currentUser.uid);
  final displayName =
      userProfile?.displayName ?? userProfile?.username ?? 'Unknown User';

  final firestoreService = ref.read(firestoreServiceProvider);
  final room = Room(
    id: '', // Will be set by Firestore
    title: params['name'],
    description: params['description'] ?? '',
    tags: [], // Empty tags for now
    category: 'general', // Default category
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    isLive: true,
    viewerCount: 1,
    hostId: currentUser.uid,
    hostName: params['showDJPrefix'] == true ? 'DJ $displayName' : displayName,
    participantIds: [currentUser.uid],
    privacy: params['isPrivate'] == true ? 'private' : 'public',
    status: 'live',
    name: params['name'], // Use name as title
  );
  await firestoreService.createRoom(room);
});

final sendTipProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, params) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  final tippingService = ref.read(tippingServiceProvider);
  await tippingService.sendTip(
    Tip(
      id: '', // Will be set by the service
      senderId: currentUser.id,
      senderName: currentUser.displayName ?? 'Unknown User',
      receiverId: params['receiverId'],
      receiverName: params['receiverName'] ?? 'Unknown User',
      amount: params['amount'],
      message: params['message'] ?? '',
      roomId: params['roomId'],
      timestamp: DateTime.now(),
    ),
  );
});

final followUserProvider =
    FutureProvider.family<void, String>((ref, targetUserId) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  final socialService = ref.read(socialServiceProvider);
  await socialService.followUser(currentUser.id, targetUserId);
});

final unfollowUserProvider =
    FutureProvider.family<void, String>((ref, targetUserId) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) throw Exception('User not authenticated');

  final socialService = ref.read(socialServiceProvider);
  await socialService.unfollowUser(currentUser.id, targetUserId);
});

final userRoomsProvider =
    StreamProvider.family<List<Room>, String>((ref, userId) {
  // Placeholder: Return empty list
  return Stream.value([]);
});

final userActivityProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, userId) {
  // Placeholder: Return empty list
  return Stream.value([]);
});

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setTheme(ThemeMode theme) {
    state = theme;
  }
}

// DISABLED FOR V1 LAUNCH - Speed Dating providers
// final speedDatingTimerProvider = NotifierProvider<SpeedDatingTimerNotifier, Duration>(() {
//   return SpeedDatingTimerNotifier();
// });

// class SpeedDatingTimerNotifier extends Notifier<Duration> {
//   @override
//   Duration build() => const Duration(minutes: 10);
//   void startTimer() { state = const Duration(minutes: 10); }
//   void updateTimer(Duration remaining) { state = remaining; }
//   void resetTimer() { state = const Duration(minutes: 10); }
// }

// final speedDatingLobbyProvider = NotifierProvider<SpeedDatingLobbyNotifier, SpeedDatingLobbyState>(() {
//   return SpeedDatingLobbyNotifier();
// });

// class SpeedDatingLobbyNotifier extends Notifier<SpeedDatingLobbyState> {
//   StreamSubscription<SpeedDatingSession?>? _sessionSubscription;
//
//   @override
//   SpeedDatingLobbyState build() => SpeedDatingLobbyState(isSearching: false, currentSession: null, error: null);
//
//   Future<void> joinLobby() async { /* disabled */ }
//   Future<void> leaveLobby() async { /* disabled */ }
//   void _startListeningToSession(String sessionId) { /* disabled */ }
// }

// DISABLED FOR V1: Speed Dating providers reference disabled types
/*
final speedDatingSessionProvider = StreamProvider.family<SpeedDatingSession?, String>((ref, sessionId) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getSpeedDatingSessionStream(sessionId);
});

final speedDatingMatchesProvider = StreamProvider<List<SpeedDatingMatch>>((ref) {
  // Placeholder: Return empty list
  return Stream.value([]);
});
*/

// ============================================================================
// MISSING PROVIDER STUBS (Round 10 Fixes)
// ============================================================================

/// Moderation service provider
final moderationServiceProvider = Provider<ModerationService>((ref) {
  return ModerationService();
});

/// Typing service provider
final typingServiceProvider = Provider<TypingService>((ref) {
  return TypingService();
});

/// Coin economy service provider
final coinEconomyServiceProvider = Provider<CoinEconomyService>((ref) {
  return CoinEconomyService();
});

/// Subscription service provider
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

/// Room service provider
final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService();
});
