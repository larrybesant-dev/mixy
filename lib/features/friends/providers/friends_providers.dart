import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/friend_request_model.dart';
import '../../../models/presence_model.dart';
import '../../../models/user_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../services/friend_service.dart';
import '../../../services/presence_repository.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/streams/stream_lifecycle_manager.dart';
import '../models/friend_roster_entry.dart';
import '../models/friendship_model.dart';

// Canonical Firestore provider
final friendFirestoreProvider = firestoreProvider;

final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService(
    firestore: ref.watch(friendFirestoreProvider),
    streamLifecycleManager: ref.watch(streamLifecycleManagerProvider),
  );
});

final currentFriendUserIdProvider = Provider<String?>((ref) {
  return ref.watch(userProvider)?.id;
});

final friendSearchQueryProvider = StateProvider<String>((ref) => '');

// ─────────────────────────────────────────────────────────────────────────────
// RAW FIRESTORE STREAMS (Provider<Stream<T>>)
// ─────────────────────────────────────────────────────────────────────────────

final rawAllFriendshipsStreamProvider = Provider.autoDispose
    .family<Stream<List<FriendshipModel>>, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(const <FriendshipModel>[]);
  return ref.watch(friendServiceProvider).watchFriendships(userId);
});

final rawAcceptedFriendshipsStreamProvider = Provider.autoDispose
    .family<Stream<List<FriendshipModel>>, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value(const <FriendshipModel>[]);
  return ref.watch(friendServiceProvider).watchAcceptedFriendships(userId);
});

// ─────────────────────────────────────────────────────────────────────────────
// DERIVED PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final friendsProvider = StreamProvider.autoDispose<List<FriendshipModel>>((
  ref,
) {
  final userId = ref.watch(currentFriendUserIdProvider) ?? '';
  if (userId.isEmpty) return Stream.value(const <FriendshipModel>[]);
  return ref.watch(rawAcceptedFriendshipsStreamProvider(userId));
});

final friendRosterProvider =
    StreamProvider.autoDispose<List<FriendRosterEntry>>((ref) {
  final userId = ref.watch(currentFriendUserIdProvider) ?? '';
  if (userId.isEmpty) return Stream.value(const <FriendRosterEntry>[]);

  final acceptedStream = ref.watch(
    rawAcceptedFriendshipsStreamProvider(userId),
  );

  return ref
      .watch(friendServiceProvider)
      .watchFriendRosterFromFriendships(userId, acceptedStream);
});

final onlineFriendsProvider =
    Provider.autoDispose<AsyncValue<List<FriendRosterEntry>>>((ref) {
  final roster = ref.watch(friendRosterProvider);
  return roster.whenData(
    (entries) =>
        entries.where((entry) => entry.isOnline).toList(growable: false),
  );
});

final inRoomFriendsProvider =
    Provider.autoDispose<AsyncValue<List<FriendRosterEntry>>>((ref) {
  final roster = ref.watch(friendRosterProvider);
  return roster.whenData(
    (entries) => entries
        .where((entry) => (entry.roomId ?? '').isNotEmpty)
        .toList(growable: false),
  );
});

final offlineFriendsProvider =
    Provider.autoDispose<AsyncValue<List<FriendRosterEntry>>>((ref) {
  final roster = ref.watch(friendRosterProvider);
  return roster.whenData(
    (entries) =>
        entries.where((entry) => !entry.isOnline).toList(growable: false),
  );
});

final currentFriendIdsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  bool disposed = false;
  ref.onDispose(() => disposed = true);

  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return const <String>[];

  final friendships = await ref.watch(friendsProvider.future);
  if (disposed) return const <String>[];

  return friendships
      .map((f) => f.otherUserId(userId))
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
});

final friendsListProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  final userId = ref.watch(currentFriendUserIdProvider) ?? '';
  if (userId.isEmpty) return Stream.value(const <UserModel>[]);

  final acceptedStream = ref.watch(
    rawAcceptedFriendshipsStreamProvider(userId),
  );

  return ref
      .watch(friendServiceProvider)
      .watchFriendsFromFriendships(userId, acceptedStream);
});

// ─────────────────────────────────────────────────────────────────────────────
// INCOMING FRIEND REQUESTS
// ─────────────────────────────────────────────────────────────────────────────

class IncomingFriendRequestEntry {
  const IncomingFriendRequestEntry({
    required this.request,
    required this.fromUser,
  });

  final FriendRequestModel request;
  final UserModel? fromUser;
}

final incomingFriendRequestsProvider =
    StreamProvider.autoDispose<List<IncomingFriendRequestEntry>>((ref) {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) {
    return Stream.value(const <IncomingFriendRequestEntry>[]);
  }

  final service = ref.watch(friendServiceProvider);
  final allFriendshipsStream = ref.watch(
    rawAllFriendshipsStreamProvider(userId),
  );

  return allFriendshipsStream
      .map(
    (friendships) => friendships
        .where(
          (f) => f.status == 'pending' && f.requestedBy != userId,
        )
        .map(
          (f) => FriendRequestModel(
            id: f.id,
            fromUserId: f.requestedBy ?? f.userA,
            toUserId: userId,
            status: f.status,
            createdAt: f.createdAt,
          ),
        )
        .toList(growable: false)
      ..sort((l, r) => r.createdAt.compareTo(l.createdAt)),
  )
      .asyncMap((requests) async {
    final users = await service.getUsersByIds(
      requests.map((r) => r.fromUserId).toList(growable: false),
    );
    final usersById = {for (final u in users) u.id: u};
    return requests
        .map(
          (r) => IncomingFriendRequestEntry(
            request: r,
            fromUser: usersById[r.fromUserId],
          ),
        )
        .toList(growable: false);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// OUTGOING PENDING REQUESTS
// ─────────────────────────────────────────────────────────────────────────────

class OutgoingFriendRequestEntry {
  const OutgoingFriendRequestEntry({
    required this.friendship,
    required this.toUser,
  });

  final FriendshipModel friendship;
  final UserModel? toUser;
}

final outgoingFriendRequestsProvider =
    StreamProvider.autoDispose<List<OutgoingFriendRequestEntry>>((ref) {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) {
    return Stream.value(const <OutgoingFriendRequestEntry>[]);
  }

  final service = ref.watch(friendServiceProvider);
  final allFriendshipsStream = ref.watch(
    rawAllFriendshipsStreamProvider(userId),
  );

  return allFriendshipsStream
      .map(
    (friendships) => friendships
        .where(
          (friendship) =>
              friendship.status == 'pending' &&
              friendship.requestedBy == userId,
        )
        .toList(growable: false)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt)),
  )
      .asyncMap((friendships) async {
    final recipientIds = friendships
        .map((friendship) => friendship.otherUserId(userId))
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final users = await service.getUsersByIds(recipientIds);
    final usersById = {for (final user in users) user.id: user};
    return friendships
        .map(
          (friendship) => OutgoingFriendRequestEntry(
            friendship: friendship,
            toUser: usersById[friendship.otherUserId(userId)],
          ),
        )
        .toList(growable: false);
  });
});

final pendingOutgoingFriendRequestIdsProvider =
    StreamProvider.autoDispose<Set<String>>((ref) {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return Stream.value(const <String>{});

  final allFriendshipsStream = ref.watch(
    rawAllFriendshipsStreamProvider(userId),
  );

  return allFriendshipsStream.map(
    (friendships) => friendships
        .where((f) => f.status == 'pending' && f.requestedBy == userId)
        .map((f) => f.otherUserId(userId))
        .where((id) => id.isNotEmpty)
        .toSet(),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH CANDIDATES
// ─────────────────────────────────────────────────────────────────────────────

final friendCandidateSearchProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) async {
  bool disposed = false;
  ref.onDispose(() => disposed = true);

  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return const <UserModel>[];

  final query = ref.watch(friendSearchQueryProvider);
  final service = ref.watch(friendServiceProvider);

  final friendIds = await ref.watch(currentFriendIdsProvider.future);
  if (disposed) return const <UserModel>[];

  final incomingRequesterIds = await service.getIncomingRequesterIds(
    userId,
  );
  if (disposed) return const <UserModel>[];

  final outgoingPendingIds = await service.getOutgoingPendingRequestIds(
    userId,
  );
  if (disposed) return const <UserModel>[];

  return service.searchUsers(
    query,
    currentUserId: userId,
    excludeUserIds: [
      ...friendIds,
      ...incomingRequesterIds,
      ...outgoingPendingIds,
    ],
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// FAVORITES
// ─────────────────────────────────────────────────────────────────────────────

final favoriteFriendIdsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return const <String>{};
  return ref.watch(friendServiceProvider).getFavoriteFriendIds(userId);
});

// ─────────────────────────────────────────────────────────────────────────────
// PRESENCE
// ─────────────────────────────────────────────────────────────────────────────

final friendPresenceProvider =
    StreamProvider.autoDispose.family<PresenceModel, String>((ref, friendId) {
  return ref.watch(presenceRepositoryProvider).watchUserPresence(friendId);
});

String buildFriendPresenceBatchKey(Iterable<String> userIds) {
  final normalized = userIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false)
    ..sort();
  return normalized.join('|');
}

final friendPresenceBatchProvider = StreamProvider.autoDispose
    .family<Map<String, PresenceModel>, String>((ref, batchKey) {
  final userIds = batchKey
      .split('|')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (userIds.isEmpty) {
    return Stream.value(const <String, PresenceModel>{});
  }
  return ref.watch(presenceRepositoryProvider).watchUsersPresence(userIds);
});

final currentUserPresenceProvider = StreamProvider.autoDispose<PresenceModel?>((
  ref,
) {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return Stream.value(null);
  return ref
      .watch(presenceRepositoryProvider)
      .watchUserPresence(userId)
      .map((p) => p);
});

// ─────────────────────────────────────────────────────────────────────────────
// SUGGESTIONS
// ─────────────────────────────────────────────────────────────────────────────

final friendSuggestionsProvider = FutureProvider.autoDispose<List<UserModel>>((
  ref,
) async {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return const <UserModel>[];
  return ref
      .watch(friendServiceProvider)
      .getFriendSuggestions(userId, limit: 15);
});
