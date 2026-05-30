import 'package:flutter/material.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/services/friend_service.dart';

import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/streams/stream_lifecycle_manager.dart';
import '../../../../services/presence_repository.dart';
import '../../../friends/providers/friends_providers.dart'
    show rawAllFriendshipsStreamProvider;
import '../models/schema_friend_identity.dart';
import '../models/schema_friend_link.dart';
import '../models/schema_friend_presence.dart';

// Route through canonical providers so test overrides work.
final schemaFriendFirestoreProvider = firestoreProvider;

/// Exposes the authenticated user's UID from canonical [authStateProvider]
/// without opening a duplicate authStateChanges() stream.
final schemaAuthUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user?.uid;
});

/// Derived: shares the canonical [rawAllFriendshipsStreamProvider] with the
/// friends module — no new Firestore subscription is opened here.
/// When both the friends panel and the schema messenger are mounted for the same
/// userId, Riverpod's family deduplication guarantees ONE underlying stream.
final schemaFriendLinksProvider =
    StreamProvider.autoDispose<List<SchemaFriendLink>>((ref) {
      final userId = ref.watch(schemaAuthUserIdProvider) ?? '';
      if (userId.isEmpty) {
        return const Stream<List<SchemaFriendLink>>.empty();
      }

      return ref.watch(rawAllFriendshipsStreamProvider(userId)).map((
        friendships,
      ) {
        final links =
            friendships
                .map(
                  (friendship) => SchemaFriendLink(
                    id: friendship.id,
                    users: <String>[friendship.userA, friendship.userB],
                    status: friendship.status,
                    requestedBy: friendship.requestedBy ?? friendship.userA,
                    createdAt: friendship.createdAt,
                    updatedAt: friendship.updatedAt,
                  ),
                )
                .where((link) => link.includesUser(userId))
                .toList(growable: false)
              ..sort((a, b) {
                final right =
                    b.updatedAt ??
                    b.createdAt ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final left =
                    a.updatedAt ??
                    a.createdAt ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return right.compareTo(left);
              });
        return links;
      });
    });

final schemaAcceptedFriendLinksProvider =
    Provider.autoDispose<List<SchemaFriendLink>>((ref) {
      final links =
          ref.watch(schemaFriendLinksProvider).valueOrNull ??
          const <SchemaFriendLink>[];
      return links.where((link) => link.isAccepted).toList(growable: false);
    });

final schemaAcceptedFriendIdsProvider = Provider.autoDispose<List<String>>((
  ref,
) {
  final userId = ref.watch(schemaAuthUserIdProvider);
  final links = ref.watch(schemaAcceptedFriendLinksProvider);
  if (userId == null || userId.isEmpty) return const <String>[];

  return links
      .map((link) => link.otherUserId(userId))
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);
});

final schemaIncomingFriendRequestsProvider =
    Provider.autoDispose<List<SchemaFriendLink>>((ref) {
      final userId = ref.watch(schemaAuthUserIdProvider);
      final links =
          ref.watch(schemaFriendLinksProvider).valueOrNull ??
          const <SchemaFriendLink>[];
      if (userId == null || userId.isEmpty) return const <SchemaFriendLink>[];

      return links
          .where((link) => link.isPending && link.requestedBy != userId)
          .toList(growable: false);
    });

final schemaOutgoingFriendRequestsProvider =
    Provider.autoDispose<List<SchemaFriendLink>>((ref) {
      final userId = ref.watch(schemaAuthUserIdProvider);
      final links =
          ref.watch(schemaFriendLinksProvider).valueOrNull ??
          const <SchemaFriendLink>[];
      if (userId == null || userId.isEmpty) return const <SchemaFriendLink>[];

      return links
          .where((link) => link.isPending && link.requestedBy == userId)
          .toList(growable: false);
    });

final schemaFriendIdentityProvider = StreamProvider.autoDispose
    .family<SchemaFriendIdentity?, String>((ref, friendId) {
      final firestore = ref.watch(schemaFriendFirestoreProvider);

      return Stream.multi((controller) {
        var disposed = false;
        Map<String, dynamic>? userData;
        Map<String, dynamic>? profileData;
        StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? userSub;
        StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? profileSub;

        void emit() {
          if (disposed || controller.isClosed) return;
          if (userData == null) return;
          controller.add(
            SchemaFriendIdentity.fromMaps(
              userId: friendId,
              userData: userData!,
              profilePublicData: profileData,
            ),
          );
        }

        userSub = firestore
            .collection('users')
            .doc(
              friendId,
            ) // Single-document read — .limit(1) not applicable for document snapshots.
            .snapshots()
            .listen((snapshot) {
              if (disposed || controller.isClosed) return;
              if (!snapshot.exists) {
                userData = const <String, dynamic>{};
              } else {
                userData = snapshot.data() ?? const <String, dynamic>{};
              }
              emit();
            }, onError: controller.addError);

        profileSub = firestore
            .collection('users')
            .doc(friendId)
            .collection('profile_public')
            .limit(1)
            .snapshots()
            .listen((snapshot) {
              if (disposed || controller.isClosed) return;
              profileData = snapshot.docs.isEmpty
                  ? null
                  : snapshot.docs.first.data();
              emit();
            }, onError: controller.addError);

        controller.onCancel = () async {
          disposed = true;
          await userSub?.cancel();
          await profileSub?.cancel();
        };
      });
    });

final schemaFriendPresenceProvider = StreamProvider.autoDispose
    .family<SchemaFriendPresence, String>((ref, friendId) {
      return ref
          .watch(presenceRepositoryProvider)
          .watchUserPresence(friendId)
          .map(
            (presence) => SchemaFriendPresence(
              friendId: friendId,
              isOnline: presence.isOnline == true,
              roomId: presence.roomId,
              lastActiveAt: presence.lastSeen,
            ),
          );
    });

final schemaFriendPresenceMapProvider =
    StreamProvider.autoDispose<Map<String, SchemaFriendPresence>>((ref) {
      final friendIds = ref.watch(schemaAcceptedFriendIdsProvider);

      if (friendIds.isEmpty) {
        return Stream.value(const <String, SchemaFriendPresence>{});
      }

      return ref
          .watch(presenceRepositoryProvider)
          .watchUsersPresence(friendIds)
          .map(
            (presenceById) => {
              for (final friendId in friendIds)
                friendId: SchemaFriendPresence(
                  friendId: friendId,
                  isOnline: presenceById[friendId]?.isOnline == true,
                  roomId: presenceById[friendId]?.roomId,
                  lastActiveAt: presenceById[friendId]?.lastSeen,
                ),
            },
          );
    });

class SchemaFriendLinksController {
  SchemaFriendLinksController(this._friendService);

  final FriendService _friendService;

  Future<void> sendRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    await _friendService.sendFriendRequest(fromUserId, toUserId);
  }

  Future<void> acceptRequest({required String linkId}) async {
    await _friendService.acceptFriendRequest(linkId);
  }
}

final schemaFriendLinksControllerProvider =
    Provider<SchemaFriendLinksController>((ref) {
      return SchemaFriendLinksController(
        FriendService(
          firestore: ref.watch(schemaFriendFirestoreProvider),
          streamLifecycleManager: ref.watch(streamLifecycleManagerProvider),
        ),
      );
    });




