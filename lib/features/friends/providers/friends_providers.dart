import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/friend_request_model.dart';
import '../../../models/presence_model.dart';
import '../../../models/user_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../services/friend_service.dart';
import '../../../services/presence_repository.dart';
import '../models/friend_roster_entry.dart';
import '../models/friendship_model.dart';

final friendFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService(firestore: ref.watch(friendFirestoreProvider));
});

final currentFriendUserIdProvider = Provider<String?>((ref) {
  return ref.watch(userProvider)?.id;
});

final friendSearchQueryProvider = StateProvider<String>((ref) => '');

final friendsProvider = StreamProvider.autoDispose<List<FriendshipModel>>((ref) {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) {
    return const Stream<List<FriendshipModel>>.empty();
  }
  return ref.watch(friendServiceProvider).watchAcceptedFriendships(userId);
});

final friendRosterProvider = StreamProvider.autoDispose<List<FriendRosterEntry>>((ref) {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) {
    return const Stream<List<FriendRosterEntry>>.empty();
  }
  return ref.watch(friendServiceProvider).watchFriendRoster(userId);
});

final onlineFriendsProvider = Provider.autoDispose<AsyncValue<List<FriendRosterEntry>>>((ref) {
  final rosterAsync = ref.watch(friendRosterProvider);
  return rosterAsync.whenData(
    (entries) => entries
        .where((entry) => entry.isOnline)
        .toList(growable: false),
  );
});

final inRoomFriendsProvider = Provider.autoDispose<AsyncValue<List<FriendRosterEntry>>>((ref) {
  final rosterAsync = ref.watch(friendRosterProvider);
  return rosterAsync.whenData(
    (entries) => entries
        .where((entry) => (entry.roomId ?? '').isNotEmpty)
        .toList(growable: false),
  );
});

final offlineFriendsProvider = Provider.autoDispose<AsyncValue<List<FriendRosterEntry>>>((ref) {
  final rosterAsync = ref.watch(friendRosterProvider);
  return rosterAsync.whenData(
    (entries) => entries
        .where((entry) => !entry.isOnline)
        .toList(growable: false),
  );
});

final currentFriendIdsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  bool disposed = false;
  ref.onDispose(() {
    disposed = true;
  });

  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) {
    return const <String>[];
  }

  final friendships = await ref.watch(friendsProvider.future);
  if (disposed) {
    return const <String>[];
  }

  return friendships
      .map((friendship) => friendship.otherUserId(userId))
      .where((friendId) => friendId.isNotEmpty)
      .toList(growable: false);
});

final friendsListProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return const Stream<List<UserModel>>.empty();
  return ref.watch(friendServiceProvider).watchFriends(userId);
});

class IncomingFriendRequestEntry {
  const IncomingFriendRequestEntry({required this.request, required this.fromUser});

  final FriendRequestModel request;
  final UserModel? fromUser;
}

final incomingFriendRequestsProvider = StreamProvider<List<IncomingFriendRequestEntry>>((ref) {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) {
    return const Stream<List<IncomingFriendRequestEntry>>.empty();
  }

  final service = ref.watch(friendServiceProvider);
  return service.incomingRequests(userId).asyncMap((requests) async {
    final users = await service.getUsersByIds(
      requests.map((request) => request.fromUserId).toList(growable: false),
    );
    final usersById = {for (final user in users) user.id: user};

    return requests
        .map(
          (request) => IncomingFriendRequestEntry(
            request: request,
            fromUser: usersById[request.fromUserId],
          ),
        )
        .toList(growable: false);
  });
});

final pendingOutgoingFriendRequestIdsProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) {
    return const Stream<Set<String>>.empty();
  }

  return ref.watch(friendServiceProvider).outgoingPendingRequestIds(userId).map(
        (ids) => ids.toSet(),
      );
});

final friendCandidateSearchProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  bool disposed = false;
  ref.onDispose(() {
    disposed = true;
  });

  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) {
    return const <UserModel>[];
  }

  final query = ref.watch(friendSearchQueryProvider);
  final service = ref.watch(friendServiceProvider);
  final friendIds = await ref.watch(currentFriendIdsProvider.future);
  if (disposed) return const <UserModel>[];

  final incomingRequesterIds = await service.getIncomingRequesterIds(userId);
  if (disposed) return const <UserModel>[];

  final outgoingPendingIds = await service.getOutgoingPendingRequestIds(userId);
  if (disposed) return const <UserModel>[];

  return service.searchUsers(
    query,
    currentUserId: userId,
    excludeUserIds: [...friendIds, ...incomingRequesterIds, ...outgoingPendingIds],
  );
});

final favoriteFriendIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return const <String>{};
  return ref.watch(friendServiceProvider).getFavoriteFriendIds(userId);
});

final friendPresenceProvider =
    StreamProvider.autoDispose.family<PresenceModel, String>((ref, friendId) {
  return ref.watch(presenceRepositoryProvider).watchUserPresence(friendId);
});

final currentUserPresenceProvider = StreamProvider.autoDispose<PresenceModel?>((ref) {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return const Stream<PresenceModel?>.empty();
  return ref.watch(presenceRepositoryProvider).watchUserPresence(userId).map((presence) => presence);
});

final friendSuggestionsProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return const <UserModel>[];
  return ref.watch(friendServiceProvider).getFriendSuggestions(userId, limit: 15);
});
