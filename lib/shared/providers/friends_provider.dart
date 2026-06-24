// Friends List Provider - Manages friends with online/offline status, favorites, search
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_models.dart';

/// Mock data generator
List<Friend> _generateMockFriends() {
  return [
    Friend(
      id: '1',
      name: 'Alex Johnson',
      avatarUrl: 'https://i.pravatar.cc/150?u=alex',
      isOnline: true,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 2)),
      isFavorite: true,
      unreadMessages: 0,
    ),
    Friend(
      id: '2',
      name: 'Sarah Chen',
      avatarUrl: 'https://i.pravatar.cc/150?u=sarah',
      isOnline: true,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 15)),
      isFavorite: true,
      unreadMessages: 2,
    ),
    Friend(
      id: '3',
      name: 'Jordan Taylor',
      avatarUrl: 'https://i.pravatar.cc/150?u=jordan',
      isOnline: false,
      lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
      isFavorite: false,
      unreadMessages: 0,
    ),
    Friend(
      id: '4',
      name: 'Morgan Williams',
      avatarUrl: 'https://i.pravatar.cc/150?u=morgan',
      isOnline: true,
      lastSeen: DateTime.now(),
      isFavorite: false,
      unreadMessages: 5,
    ),
    Friend(
      id: '5',
      name: 'Casey Brown',
      avatarUrl: 'https://i.pravatar.cc/150?u=casey',
      isOnline: false,
      lastSeen: DateTime.now().subtract(const Duration(hours: 5)),
      isFavorite: true,
      unreadMessages: 1,
    ),
    Friend(
      id: '6',
      name: 'Riley Davis',
      avatarUrl: 'https://i.pravatar.cc/150?u=riley',
      isOnline: true,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 30)),
      isFavorite: false,
      unreadMessages: 0,
    ),
  ];
}

/// Friends list notifier
class FriendsNotifier extends Notifier<List<Friend>> {
  @override
  List<Friend> build() {
    return _generateMockFriends();
  }

  /// Toggle favorite status
  void toggleFavorite(String friendId) {
    state = state.map((friend) {
      if (friend.id == friendId) {
        return friend.copyWith(isFavorite: !friend.isFavorite);
      }
      return friend;
    }).toList();
  }

  /// Mark messages as read
  void markMessagesAsRead(String friendId) {
    state = state.map((friend) {
      if (friend.id == friendId) {
        return friend.copyWith(unreadMessages: 0);
      }
      return friend;
    }).toList();
  }

  /// Update online status
  void updateOnlineStatus(String friendId, bool isOnline) {
    state = state.map((friend) {
      if (friend.id == friendId) {
        return friend.copyWith(
          isOnline: isOnline,
          lastSeen: DateTime.now(),
        );
      }
      return friend;
    }).toList();
  }

  /// Add new message to friend
  void addUnreadMessage(String friendId) {
    state = state.map((friend) {
      if (friend.id == friendId) {
        return friend.copyWith(
          unreadMessages: friend.unreadMessages + 1,
        );
      }
      return friend;
    }).toList();
  }
}

/// Friends provider
final friendsProvider = NotifierProvider<FriendsNotifier, List<Friend>>(
  () => FriendsNotifier(),
);

/// Friend search query notifier
class FriendSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final friendSearchQueryProvider =
    NotifierProvider<FriendSearchQueryNotifier, String>(
  () => FriendSearchQueryNotifier(),
);

/// Filtered friends based on search
final filteredFriendsProvider = FutureProvider<List<Friend>>((ref) {
  final friends = ref.watch(friendsProvider);
  final query = ref.watch(friendSearchQueryProvider);

  return Future.value(
    friends
        .where((friend) =>
            friend.name.toLowerCase().contains(query.toLowerCase()) ||
            friend.id.toLowerCase().contains(query.toLowerCase()))
        .toList(),
  );
});

/// Online friends only
final onlineFriendsProvider = Provider<List<Friend>>((ref) {
  final friends = ref.watch(friendsProvider);
  return friends.where((friend) => friend.isOnline).toList();
});

/// Favorite friends
final favoriteFriendsProvider = Provider<List<Friend>>((ref) {
  final friends = ref.watch(friendsProvider);
  return friends.where((friend) => friend.isFavorite).toList();
});

/// Friends with unread messages
final friendsWithUnreadProvider = Provider<List<Friend>>((ref) {
  final friends = ref.watch(friendsProvider);
  return friends.where((friend) => friend.unreadMessages > 0).toList();
});

/// Total unread messages count
final totalUnreadMessagesProvider = Provider<int>((ref) {
  final friends = ref.watch(friendsProvider);
  return friends.fold<int>(0, (sum, friend) => sum + friend.unreadMessages);
});
