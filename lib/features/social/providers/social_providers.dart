import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';
import 'package:mixvy/features/follow/providers/follow_provider.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/services/room_service.dart';

// ── Following-live rooms ──────────────────────────────────────────────────────

/// Live rooms where the users that [userId] follows are currently hosting.
/// Reuses the shared live-rooms stream to avoid opening a second rooms listener.
final followingHostIdsProvider = Provider.autoDispose
    .family<AsyncValue<Set<String>>, String>((ref, userId) {
      if (userId.isEmpty) {
        return const AsyncValue.data(<String>{});
      }

      return ref
          .watch(rawFollowGraphStreamProvider(userId))
          .whenData(
            (ids) =>
                ids.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet(),
          );
    });

final followingLiveRoomsProvider = Provider.autoDispose
    .family<AsyncValue<List<RoomModel>>, String>((ref, userId) {
      if (userId.isEmpty) {
        return const AsyncValue.data(<RoomModel>[]);
      }

      final followedIdsAsync = ref.watch(followingHostIdsProvider(userId));
      final roomsAsync = ref.watch(roomsStreamProvider);

      if (followedIdsAsync.hasError) {
        return AsyncValue<List<RoomModel>>.error(
          followedIdsAsync.error!,
          followedIdsAsync.stackTrace!,
        );
      }
      if (roomsAsync.hasError) {
        return AsyncValue<List<RoomModel>>.error(
          roomsAsync.error!,
          roomsAsync.stackTrace!,
        );
      }
      if (followedIdsAsync.isLoading || roomsAsync.isLoading) {
        return const AsyncValue.loading();
      }

      final followedIds = followedIdsAsync.valueOrNull ?? const <String>{};
      final rooms = roomsAsync.valueOrNull ?? const <RoomModel>[];
      final filtered = followedIds.isEmpty
          ? const <RoomModel>[]
          : rooms
                .where((room) => followedIds.contains(room.hostId))
                .take(12)
                .toList(growable: false);
      return AsyncValue.data(filtered);
    });

// ── Following users list ──────────────────────────────────────────────────────

/// User profiles of everyone that [userId] follows (max 50).
final _followingUsersByKeyProvider = FutureProvider.autoDispose
    .family<List<UserModel>, String>((ref, key) async {
      if (key.isEmpty) {
        return const <UserModel>[];
      }

      final firestore = ref.watch(firestoreProvider);
      final ids = key
          .split('|')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      if (ids.isEmpty) {
        return const <UserModel>[];
      }

      final users = <UserModel>[];
      for (var i = 0; i < ids.length; i += 10) {
        final batch = ids.sublist(i, (i + 10).clamp(0, ids.length));
        try {
          final userSnap = await firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          for (final doc in userSnap.docs) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            users.add(UserModel.fromJson(data));
          }
        } on FirebaseException {
          continue;
        }
      }

      return users;
    });

final followingUsersProvider = Provider.autoDispose
    .family<AsyncValue<List<UserModel>>, String>((ref, userId) {
      if (userId.isEmpty) {
        return const AsyncValue.data(<UserModel>[]);
      }

      final followingIdsAsync = ref.watch(rawFollowGraphStreamProvider(userId));
      if (followingIdsAsync.hasError) {
        return AsyncValue<List<UserModel>>.error(
          followingIdsAsync.error!,
          followingIdsAsync.stackTrace!,
        );
      }
      if (followingIdsAsync.isLoading) {
        return const AsyncValue.loading();
      }

      final ids =
          (followingIdsAsync.valueOrNull ?? const <String>[])
              .where((id) => id.isNotEmpty)
              .take(50)
              .toList(growable: false)
            ..sort();
      final key = ids.join('|');
      return ref.watch(_followingUsersByKeyProvider(key));
    });

// ── For-You rooms ─────────────────────────────────────────────────────────────

/// Personalised live room suggestions based on the user's [interests].
/// Falls back to most-active rooms when no interests are stored.
final forYouRoomsProvider = FutureProvider.family
    .autoDispose<List<RoomModel>, String>((ref, userId) async {
      if (userId.isEmpty) return const [];
      final firestore = ref.watch(firestoreProvider);
      final roomService = ref.watch(roomServiceProvider);

      // Load user interests.
      List<String> interests = const [];
      try {
        final doc = await firestore.collection('users').doc(userId).get();
        interests = List<String>.from(doc.data()?['interests'] ?? const []);
      } on FirebaseException {
        // Fall through to generic rooms.
      }

      const validCats = {
        'music',
        'gaming',
        'dating',
        'talk',
        'art',
        'dance',
        'study',
        'chill',
      };
      final cats = interests
          .map((i) => i.toLowerCase().trim())
          .where(validCats.contains)
          .take(3)
          .toSet();

      final liveRooms = await roomService.getLiveRooms(
        limit: 60,
        includeAdultRooms: false,
      );

      if (cats.isEmpty) {
        final sorted = liveRooms.toList(growable: false)
          ..sort((a, b) {
            final memberCompare = b.memberCount.compareTo(a.memberCount);
            if (memberCompare != 0) {
              return memberCompare;
            }
            final updatedA =
                a.updatedAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final updatedB =
                b.updatedAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return updatedB.compareTo(updatedA);
          });
        return sorted.take(12).toList(growable: false);
      }

      final matched = liveRooms
          .where((room) {
            final roomCategory = room.category?.trim().toLowerCase();
            return roomCategory != null && cats.contains(roomCategory);
          })
          .toList(growable: false);

      if (matched.isEmpty) {
        return liveRooms.take(12).toList(growable: false);
      }

      matched.sort((a, b) {
        final memberCompare = b.memberCount.compareTo(a.memberCount);
        if (memberCompare != 0) {
          return memberCompare;
        }
        final updatedA =
            a.updatedAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        final updatedB =
            b.updatedAt?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
        return updatedB.compareTo(updatedA);
      });
      return matched.take(12).toList(growable: false);
    });

// ── New live rooms (recent) ───────────────────────────────────────────────────

/// Stream of live rooms ordered by creation time (newest first).
final newLiveRoomsProvider = Provider.autoDispose<AsyncValue<List<RoomModel>>>((
  ref,
) {
  return ref
      .watch(roomsStreamProvider)
      .whenData((rooms) => rooms.take(20).toList(growable: false));
});
