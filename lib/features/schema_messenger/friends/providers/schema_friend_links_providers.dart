import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/friend_service.dart';
import '../models/schema_friend_identity.dart';
import '../models/schema_friend_link.dart';
import '../models/schema_friend_presence.dart';

final schemaFriendFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final schemaAuthUserIdProvider = StreamProvider<String?>((ref) {
  return FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
});

final schemaFriendLinksProvider =
    StreamProvider.autoDispose<List<SchemaFriendLink>>((ref) {
  final userId = ref.watch(schemaAuthUserIdProvider).valueOrNull;

      if (userId == null || userId.isEmpty) {
        return const Stream<List<SchemaFriendLink>>.empty();
      }

      final friendService = FriendService(
        firestore: ref.watch(schemaFriendFirestoreProvider),
      );

      return friendService.watchFriendships(userId).map((friendships) {
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
  final userId = ref.watch(schemaAuthUserIdProvider).valueOrNull;
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
  final userId = ref.watch(schemaAuthUserIdProvider).valueOrNull;
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
  final userId = ref.watch(schemaAuthUserIdProvider).valueOrNull;
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
            .doc(friendId)
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
      final firestore = ref.watch(schemaFriendFirestoreProvider);

      return firestore
          .collectionGroup('participants')
          .where('userId', isEqualTo: friendId)
          .snapshots()
          .map(
            (snapshot) => SchemaFriendPresence.fromParticipantDocs(
              friendId,
              snapshot.docs,
            ),
          );
    });

final schemaFriendPresenceMapProvider =
    StreamProvider.autoDispose<Map<String, SchemaFriendPresence>>((ref) {
      final firestore = ref.watch(schemaFriendFirestoreProvider);
      final friendIds = ref.watch(schemaAcceptedFriendIdsProvider);

      if (friendIds.isEmpty) {
        return Stream.value(const <String, SchemaFriendPresence>{});
      }

      const whereInLimit = 30;
      List<List<String>> chunkIds(List<String> ids) {
        final chunks = <List<String>>[];
        for (var index = 0; index < ids.length; index += whereInLimit) {
          final end = (index + whereInLimit) > ids.length
              ? ids.length
              : index + whereInLimit;
          chunks.add(ids.sublist(index, end));
        }
        return chunks;
      }

      return Stream.multi((controller) {
        var disposed = false;
        final chunks = chunkIds(friendIds);
        final chunkMaps = List<Map<String, SchemaFriendPresence>>.generate(
          chunks.length,
          (_) => <String, SchemaFriendPresence>{},
        );
        final subscriptions =
            <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

        void emit() {
          if (disposed || controller.isClosed) return;
          final merged = <String, SchemaFriendPresence>{};
          for (final map in chunkMaps) {
            merged.addAll(map);
          }

          controller.add({
            for (final friendId in friendIds)
              friendId:
                  merged[friendId] ?? SchemaFriendPresence.offline(friendId),
          });
        }

        for (var index = 0; index < chunks.length; index += 1) {
          final idsChunk = chunks[index];
          final sub = firestore
              .collectionGroup('participants')
              .where('userId', whereIn: idsChunk)
              .snapshots()
              .listen((snapshot) {
                if (disposed || controller.isClosed) return;
                final grouped =
                    <
                      String,
                      List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    >{};
                for (final doc in snapshot.docs) {
                  final userId =
                      (doc.data()['userId'] as String?)?.trim() ?? '';
                  if (userId.isEmpty) continue;
                  grouped
                      .putIfAbsent(
                        userId,
                        () => <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                      )
                      .add(doc);
                }

                final presenceMap = <String, SchemaFriendPresence>{
                  for (final friendId in idsChunk)
                    friendId: SchemaFriendPresence.fromParticipantDocs(
                      friendId,
                      grouped[friendId] ?? const [],
                    ),
                };

                chunkMaps[index] = presenceMap;
                emit();
              }, onError: controller.addError);

          subscriptions.add(sub);
        }

        controller.onCancel = () async {
          disposed = true;
          for (final sub in subscriptions) {
            await sub.cancel();
          }
        };
      });
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
        FriendService(firestore: ref.watch(schemaFriendFirestoreProvider)),
      );
    });
