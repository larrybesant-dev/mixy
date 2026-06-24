import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/social/friend_service.dart';
import '../../shared/models/friend_request.dart';
import 'auth_providers.dart';

// ── Service provider ──────────────────────────────────────────────────────────

final friendServiceProvider = Provider<FriendService>((ref) => FriendService.instance);

// ── Friend status with a specific user ───────────────────────────────────────

final friendStatusProvider =
    StreamProvider.family<bool, String>((ref, userId) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(false);
  final service = ref.read(friendServiceProvider);
  // Check if already a friend
  return service.streamFriends().map((friends) =>
      friends.any((f) => f.uid == userId));
});

// ── Incoming friend requests ──────────────────────────────────────────────────

final incomingFriendRequestsProvider =
    StreamProvider<List<FriendRequest>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value([]);
  return ref.read(friendServiceProvider).streamIncomingRequests();
});

/// Count for badge indicators on nav bar / friend list tab.
final pendingFriendRequestCountProvider = Provider<int>((ref) {
  return ref.watch(incomingFriendRequestsProvider).maybeWhen(
    data: (reqs) => reqs.length,
    orElse: () => 0,
  );
});

// ── Friend IDs stream ──────────────────────────────────────────────────────────

final friendIdsProvider = StreamProvider<List<String>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value([]);
  return ref.read(friendServiceProvider).streamFriends().map(
      (friends) => friends.map((f) => f.uid).toList());
});

/// Streams friend IDs for any arbitrary [userId] (used on profile pages).
final friendIdsOfUserProvider =
    StreamProvider.family<List<String>, String>((ref, userId) {
  return ref
      .read(friendServiceProvider)
      .streamFriends(userId)
      .map((friends) => friends.map((f) => f.uid).toList());
});

// ── Is blocked by me ───────────────────────────────────────────────────────────
/// Streams true if the current user has blocked [targetUserId].
/// TODO: Implement blocking functionality in FriendService
final isBlockedByMeProvider =
    StreamProvider.family<bool, String>((ref, targetUserId) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value(false);
  return Stream.value(false); // TODO: Implement block checking
});

// ── Mutual friends ─────────────────────────────────────────────────────────────
/// Fetches friend IDs shared between the current user and [otherUserId].
final mutualFriendsProvider =
    FutureProvider.family<List<String>, String>((ref, otherUserId) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return [];

  final service = ref.read(friendServiceProvider);
  final myFriends = await ref.watch(friendIdsProvider.future);
  final theirFriends = await service.streamFriends(otherUserId)
      .first
      .then((friends) => friends.map((f) => f.uid).toList());

  return myFriends.toSet().intersection(theirFriends.toSet()).toList();
});

// ── Friend suggestions ─────────────────────────────────────────────────────────
/// Friends-of-friends who are not yet friends with the current user.
final friendSuggestionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return [];

  final myIds = await ref.watch(friendIdsProvider.future);
  if (myIds.isEmpty) return [];

  final svc = ref.read(friendServiceProvider);
  // Collect friends-of-friends
  final candidateCounts = <String, int>{};

  for (final friendId in myIds.take(20)) {
    final theirFriends = await svc
        .streamFriends(friendId)
        .first
        .then((friends) => friends.map((f) => f.uid).toList());

    for (final id in theirFriends) {
      if (id != currentUser.id && !myIds.contains(id)) {
        candidateCounts[id] = (candidateCounts[id] ?? 0) + 1;
      }
    }
  }

  final sorted = candidateCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted
      .take(20)
      .map((e) => {'uid': e.key, 'mutualCount': e.value})
      .toList();
});
