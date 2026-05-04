import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/friend_request_model.dart';
import '../../../models/presence_model.dart';
import '../../../models/user_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../services/friend_service.dart';
import '../../../services/presence_repository.dart';
import '../../../core/providers/firebase_providers.dart';
import '../models/friend_roster_entry.dart';
import '../models/friendship_model.dart';

// Route through the canonical provider so test overrides work.
final friendFirestoreProvider = firestoreProvider;

final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService(firestore: ref.watch(friendFirestoreProvider));
});

final currentFriendUserIdProvider = Provider<String?>((ref) {
  return ref.watch(userProvider)?.id;
});

final friendSearchQueryProvider = StateProvider<String>((ref) => '');

// ─── Canonical friendship streams ────────────────────────────────────────────
// Riverpod deduplicates family instances by userId.
// One userId = one Firestore subscription, regardless of how many derived
// providers are mounted simultaneously.

/// All-status friendship stream (accepted + pending + blocked).
/// 3 Firestore listeners: friendships.userA, friendships.userB, friend_links.
final rawAllFriendshipsStreamProvider = StreamProvider.autoDispose
    .family<List<FriendshipModel>, String>((ref, userId) {
      if (userId.isEmpty) return const Stream<List<FriendshipModel>>.empty();
      return ref.watch(friendServiceProvider).watchFriendships(userId);
    });

/// Accepted-only friendship stream (includes user-doc fallback for legacy data).
/// 4 Firestore listeners: userA+accepted, userB+accepted, friend_links+accepted,
/// plus the user-doc friends-array fallback stream.
final rawAcceptedFriendshipsStreamProvider = StreamProvider.autoDispose
    .family<List<FriendshipModel>, String>((ref, userId) {
      if (userId.isEmpty) return const Stream<List<FriendshipModel>>.empty();
      return ref.watch(friendServiceProvider).watchAcceptedFriendships(userId);
    });

// ─── Derived providers ────────────────────────────────────────────────────────

/// Derived: zero new Firestore streams — broadcasts rawAcceptedFriendshipsStreamProvider.
final friendsProvider = StreamProvider.autoDispose<List<FriendshipModel>>((
  ref,
) {
  final userId = ref.watch(currentFriendUserIdProvider) ?? '';
  return ref.watch(rawAcceptedFriendshipsStreamProvider(userId).stream);
});

/// Derived: shares the canonical accepted stream; opens user-docs + presence streams.
final friendRosterProvider =
    StreamProvider.autoDispose<List<FriendRosterEntry>>((ref) {
      final userId = ref.watch(currentFriendUserIdProvider) ?? '';
      if (userId.isEmpty) return const Stream<List<FriendRosterEntry>>.empty();
      return ref
          .watch(friendServiceProvider)
          .watchFriendRosterFromFriendships(
            userId,
            ref.watch(rawAcceptedFriendshipsStreamProvider(userId).stream),
          );
    });

final onlineFriendsProvider =
    Provider.autoDispose<AsyncValue<List<FriendRosterEntry>>>((ref) {
      final rosterAsync = ref.watch(friendRosterProvider);
      return rosterAsync.whenData(
        (entries) =>
            entries.where((entry) => entry.isOnline).toList(growable: false),
      );
    });

final inRoomFriendsProvider =
    Provider.autoDispose<AsyncValue<List<FriendRosterEntry>>>((ref) {
      final rosterAsync = ref.watch(friendRosterProvider);
      return rosterAsync.whenData(
        (entries) => entries
            .where((entry) => (entry.roomId ?? '').isNotEmpty)
            .toList(growable: false),
      );
    });

final offlineFriendsProvider =
    Provider.autoDispose<AsyncValue<List<FriendRosterEntry>>>((ref) {
      final rosterAsync = ref.watch(friendRosterProvider);
      return rosterAsync.whenData(
        (entries) =>
            entries.where((entry) => !entry.isOnline).toList(growable: false),
      );
    });

final currentFriendIdsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
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

/// Derived: shares canonical accepted stream; opens user-docs stream only.
final friendsListProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  final userId = ref.watch(currentFriendUserIdProvider) ?? '';
  if (userId.isEmpty) return const Stream<List<UserModel>>.empty();
  return ref
      .watch(friendServiceProvider)
      .watchFriendsFromFriendships(
        userId,
        ref.watch(rawAcceptedFriendshipsStreamProvider(userId).stream),
      );
});

class IncomingFriendRequestEntry {
  const IncomingFriendRequestEntry({
    required this.request,
    required this.fromUser,
  });

  final FriendRequestModel request;
  final UserModel? fromUser;
}

/// Derived: shares canonical all-status stream — no new Firestore streams.
final incomingFriendRequestsProvider =
    StreamProvider.autoDispose<List<IncomingFriendRequestEntry>>((ref) {
      final userId = ref.watch(currentFriendUserIdProvider);
      if (userId == null) {
        return const Stream<List<IncomingFriendRequestEntry>>.empty();
      }

      final service = ref.watch(friendServiceProvider);
      return ref
          .watch(rawAllFriendshipsStreamProvider(userId).stream)
          .map(
            (friendships) =>
                friendships
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

/// Derived: shares canonical all-status stream — no new Firestore streams.
final pendingOutgoingFriendRequestIdsProvider =
    StreamProvider.autoDispose<Set<String>>((ref) {
      final userId = ref.watch(currentFriendUserIdProvider);
      if (userId == null) {
        return const Stream<Set<String>>.empty();
      }

      return ref
          .watch(rawAllFriendshipsStreamProvider(userId).stream)
          .map(
            (friendships) => friendships
                .where((f) => f.status == 'pending' && f.requestedBy == userId)
                .map((f) => f.otherUserId(userId))
                .where((id) => id.isNotEmpty)
                .toSet(),
          );
    });

final friendCandidateSearchProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) async {
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

final favoriteFriendIdsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return const <String>{};
  return ref.watch(friendServiceProvider).getFavoriteFriendIds(userId);
});

final friendPresenceProvider = StreamProvider.autoDispose
    .family<PresenceModel, String>((ref, friendId) {
      return ref.watch(presenceRepositoryProvider).watchUserPresence(friendId);
    });

final currentUserPresenceProvider = StreamProvider.autoDispose<PresenceModel?>((
  ref,
) {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return const Stream<PresenceModel?>.empty();
  return ref
      .watch(presenceRepositoryProvider)
      .watchUserPresence(userId)
      .map((presence) => presence);
});

final friendSuggestionsProvider = FutureProvider.autoDispose<List<UserModel>>((
  ref,
) async {
  final userId = ref.watch(currentFriendUserIdProvider);
  if (userId == null) return const <UserModel>[];
  return ref
      .watch(friendServiceProvider)
      .getFriendSuggestions(userId, limit: 15);
});
