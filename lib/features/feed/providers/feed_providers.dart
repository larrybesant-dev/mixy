import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/logger.dart';
import 'package:mixvy/features/room/contracts/room_visibility_contract.dart';
import 'package:mixvy/features/room/contracts/room_with_visibility.dart';
import 'package:mixvy/features/room/providers/room_visibility_windows_provider.dart';
import 'package:mixvy/services/room_service.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/core/streams/stream_lifecycle_manager.dart';

import '../repository/feed_repository.dart';
import '../models/home_feed_snapshot.dart';
import '../models/post_model.dart';
import '../../../models/room_model.dart';
import '../../../models/social_activity_model.dart';
import '../../../models/user_model.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../services/presence_repository.dart';
import '../../../services/social_activity_service.dart';
import '../services/home_feed_service.dart';
import 'package:mixvy/models/models.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.read(firestoreProvider));
});

final postsFeedProvider = StreamProvider.autoDispose<List<PostModel>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final lifecycle = ref.watch(streamLifecycleManagerProvider);
  return lifecycle.bind(
    key: 'feed-posts:global',
    routePrefixes: const <String>['/home', '/trending'],
    create: () => firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => PostModel.fromDoc(d.id, d.data()))
              .toList(growable: false),
        ),
  );
});

final postsStreamProvider = FutureProvider.autoDispose<List<PostModel>>((ref) {
  return ref.read(feedRepositoryProvider).getPostsFeed();
});

final roomsWithVisibilityStreamProvider =
    StreamProvider.autoDispose<List<RoomWithVisibility>>((ref) {
      final lifecycle = ref.watch(streamLifecycleManagerProvider);
      return lifecycle.bind(
        key: 'rooms-with-visibility',
        routePrefixes: const <String>[
          '/home',
          '/rooms',
          '/explore',
          '/after-dark',
          '/trending',
        ],
        create: () => ref
            .watch(roomServiceProvider)
            .watchRoomsWithVisibility(limit: 50),
      );
    });

final userPostsStreamProvider = StreamProvider.autoDispose
    .family<List<PostModel>, String>((ref, userId) {
      final firestore = ref.watch(firestoreProvider);
  final lifecycle = ref.watch(streamLifecycleManagerProvider);
  return lifecycle.bind(
    key: 'feed-user-posts:$userId',
    routePrefixes: const <String>['/profile'],
    create: () => firestore
    .collection('posts')
    .where('authorId', isEqualTo: userId)
    .orderBy('createdAt', descending: true)
    .limit(30)
    .snapshots()
    .map(
      (snap) => snap.docs
      .map((d) => PostModel.fromDoc(d.id, d.data()))
      .toList(growable: false),
    ),
  );
    });

final roomsStreamProvider = Provider.autoDispose<AsyncValue<List<RoomModel>>>(
  (ref) {
    return ref.watch(roomsWithVisibilityStreamProvider).whenData((classified) {
      final sections = _toSections(classified);
      if (sections.primaryLive.isNotEmpty) {
        return sections.primaryLive
            .map((item) => item.room)
            .toList(growable: false);
      }

      return sections.cold.map((item) => item.room).toList(growable: false);
    });
  },
);

final roomsSnapshotProvider = FutureProvider.autoDispose<List<RoomModel>>((
  ref,
) async {
  final classified = await ref.watch(roomsWithVisibilityStreamProvider.future);
  final sections = _toSections(classified);
  if (sections.primaryLive.isNotEmpty) {
    return sections.primaryLive
        .map((item) => item.room)
        .toList(growable: false);
  }

  return sections.cold.map((item) => item.room).toList(growable: false);
});

class RoomVisibilitySections {
  const RoomVisibilitySections({
    required this.discoverable,
    required this.warm,
    required this.cold,
    required this.invalid,
  });

  final List<RoomWithVisibility> discoverable;
  final List<RoomWithVisibility> warm;
  final List<RoomWithVisibility> cold;
  final List<RoomWithVisibility> invalid;

  List<RoomWithVisibility> get primaryLive =>
      <RoomWithVisibility>[...discoverable, ...warm];
  List<RoomWithVisibility> get allVisible =>
      <RoomWithVisibility>[...discoverable, ...warm, ...cold];
  int get totalClassified => allVisible.length + invalid.length;
}

enum FeedHealthState {
  healthy,
  degraded,
  fallbackActive,
  configInvalid,
  presenceDesynced,
}

class FeedHealthSnapshot {
  const FeedHealthSnapshot({
    required this.sections,
    required this.reasonCounts,
    required this.tierCounts,
    required this.usingColdFallback,
    required this.state,
    required this.invalidRate,
    required this.staleRate,
    required this.policyState,
  });

  final RoomVisibilitySections sections;
  final Map<RoomVisibilityReasonCode, int> reasonCounts;
  final Map<RoomVisibilityTier, int> tierCounts;
  final bool usingColdFallback;
  final FeedHealthState state;
  final double invalidRate;
  final double staleRate;
  final RoomVisibilityPolicyState policyState;

  int get totalClassified => sections.totalClassified;
}

RoomVisibilitySections _toSections(List<RoomWithVisibility> rooms) {
  final discoverable = <RoomWithVisibility>[];
  final warm = <RoomWithVisibility>[];
  final cold = <RoomWithVisibility>[];
  final invalid = <RoomWithVisibility>[];

  for (final roomWithVisibility in rooms) {
    switch (roomWithVisibility.tier) {
      case RoomVisibilityTier.discoverable:
        discoverable.add(roomWithVisibility);
        break;
      case RoomVisibilityTier.warm:
        warm.add(roomWithVisibility);
        break;
      case RoomVisibilityTier.cold:
        cold.add(roomWithVisibility);
        break;
      case RoomVisibilityTier.invalid:
        invalid.add(roomWithVisibility);
        break;
    }
  }

  final partitionedTotal =
      discoverable.length + warm.length + cold.length + invalid.length;
  if (partitionedTotal != rooms.length) {
    Logger.error(
      'ROOM_VISIBILITY_INVARIANT_BROKEN partitioned=$partitionedTotal classified=${rooms.length}',
    );
  }

  return RoomVisibilitySections(
    discoverable: List<RoomWithVisibility>.unmodifiable(discoverable),
    warm: List<RoomWithVisibility>.unmodifiable(warm),
    cold: List<RoomWithVisibility>.unmodifiable(cold),
    invalid: List<RoomWithVisibility>.unmodifiable(invalid),
  );
}

final roomVisibilitySectionsProvider =
    Provider.autoDispose<AsyncValue<RoomVisibilitySections>>((ref) {
      return ref.watch(roomsWithVisibilityStreamProvider).whenData(_toSections);
    });

final feedHealthProvider =
    Provider.autoDispose<AsyncValue<FeedHealthSnapshot>>((ref) {
      final roomsAsync = ref.watch(roomsWithVisibilityStreamProvider);
      final policyState = ref.watch(roomVisibilityPolicyStateProvider);
      return roomsAsync.whenData((rooms) {
        final sections = _toSections(rooms);
        final reasonCounts = <RoomVisibilityReasonCode, int>{
          for (final reason in RoomVisibilityReasonCode.values) reason: 0,
        };
        final tierCounts = <RoomVisibilityTier, int>{
          for (final tier in RoomVisibilityTier.values) tier: 0,
        };

        for (final room in rooms) {
          reasonCounts[room.visibility.reasonCode] =
              (reasonCounts[room.visibility.reasonCode] ?? 0) + 1;
          tierCounts[room.tier] = (tierCounts[room.tier] ?? 0) + 1;
        }

        final usingColdFallback =
            sections.primaryLive.isEmpty && sections.cold.isNotEmpty;
        final totalClassified = sections.totalClassified;
        final staleCount =
            (reasonCounts[RoomVisibilityReasonCode.warmStale] ?? 0) +
            (reasonCounts[RoomVisibilityReasonCode.coldDormant] ?? 0);
        final invalidCount = sections.invalid.length;
        final staleRate = totalClassified == 0
          ? 0.0
          : staleCount / totalClassified;
        final invalidRate = totalClassified == 0
          ? 0.0
          : invalidCount / totalClassified;
        final warmUnknownFreshnessCount =
            reasonCounts[RoomVisibilityReasonCode.warmUnknownFreshness] ?? 0;
        final likelyPresenceDesync = totalClassified >= 4 &&
            warmUnknownFreshnessCount >= (totalClassified / 2).ceil();

        final state = !policyState.isConfigValid
            ? FeedHealthState.configInvalid
            : usingColdFallback
            ? FeedHealthState.fallbackActive
            : likelyPresenceDesync
            ? FeedHealthState.presenceDesynced
            : (invalidRate >= 0.25 || staleRate >= 0.70)
            ? FeedHealthState.degraded
            : FeedHealthState.healthy;

        if (state != FeedHealthState.healthy) {
          Logger.warning(
            'ROOM_FEED_HEALTH state=${state.name} discoverable=${sections.discoverable.length} warm=${sections.warm.length} cold=${sections.cold.length} invalid=${sections.invalid.length} staleRate=${staleRate.toStringAsFixed(3)} invalidRate=${invalidRate.toStringAsFixed(3)} policySource=${policyState.source.name}',
          );
        }

        return FeedHealthSnapshot(
          sections: sections,
          reasonCounts: Map<RoomVisibilityReasonCode, int>.unmodifiable(
            reasonCounts,
          ),
          tierCounts: Map<RoomVisibilityTier, int>.unmodifiable(tierCounts),
          usingColdFallback: usingColdFallback,
          state: state,
          invalidRate: invalidRate,
          staleRate: staleRate,
          policyState: policyState,
        );
      });
    });

final eventsStreamProvider = FutureProvider.autoDispose<List<EventModel>>((
  ref,
) {
  return ref.read(feedRepositoryProvider).getEventsFeed();
});

/// Dashboard metrics do not need live Firestore listeners on every page load.
/// Fetch them once and refresh when the screen is re-entered or manually pulled.
final onlineUsersCountProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(presenceRepositoryProvider).countOnlineUsers();
});

final liveRoomsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final rooms = await ref
      .watch(roomServiceProvider)
      .getRoomsWithVisibility(limit: 50);
  final sections = _toSections(rooms);
  return sections.primaryLive.length;
});

final newMembersStreamProvider = FutureProvider.autoDispose<List<UserModel>>((
  ref,
) async {
  final firestore = ref.watch(firestoreProvider);
  final snapshot = await firestore
      .collection('users')
      .orderBy('createdAt', descending: true)
      .limit(12)
      .get();
  return snapshot.docs
      .map((d) {
        final data = d.data();
        data['id'] = d.id;
        return UserModel.fromJson(data);
      })
      .toList(growable: false);
});

final trendingUsersStreamProvider = FutureProvider.autoDispose<List<UserModel>>(
  (ref) async {
    final snapshot = await ref
        .watch(firestoreProvider)
        .collection('users')
        .orderBy('balance', descending: true)
        .limit(10)
        .get();
    return snapshot.docs
        .map((d) => UserModel.fromJson({'id': d.id, ...d.data()}))
        .toList(growable: false);
  },
);

final socialActivityServiceProvider = Provider<SocialActivityService>((ref) {
  return SocialActivityService(firestore: ref.watch(firestoreProvider));
});

final homeFeedServiceProvider = Provider<HomeFeedService>((ref) {
  return const HomeFeedService();
});

final currentUserActivitiesProvider =
    FutureProvider.autoDispose<List<SocialActivity>>((ref) async {
      final currentUser = ref.watch(userProvider);
      final userId = currentUser?.id ?? '';
      return ref
          .watch(socialActivityServiceProvider)
          .getUserActivities(userId, limit: 12);
    });

final homeFeedSnapshotProvider =
    Provider.autoDispose<AsyncValue<HomeFeedSnapshot>>((ref) {
      final activitiesAsync = ref.watch(currentUserActivitiesProvider);
      final roomsAsync = ref.watch(roomsStreamProvider);
      final usersAsync = ref.watch(trendingUsersStreamProvider);

      if (activitiesAsync.isLoading &&
          roomsAsync.isLoading &&
          usersAsync.isLoading) {
        return const AsyncValue.loading();
      }

      return AsyncValue.data(
        ref
            .watch(homeFeedServiceProvider)
            .buildSnapshot(
              activities:
                  activitiesAsync.valueOrNull ?? const <SocialActivity>[],
              liveRooms: roomsAsync.valueOrNull ?? const <RoomModel>[],
              suggestedUsers: usersAsync.valueOrNull ?? const <UserModel>[],
            ),
      );
    });
