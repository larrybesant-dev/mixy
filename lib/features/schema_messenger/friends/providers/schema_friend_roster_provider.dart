import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schema_friend_identity.dart';
import '../models/schema_friend_link.dart';
import '../models/schema_friend_presence.dart';
import 'schema_friend_links_providers.dart';
import 'schema_friend_presence_stability_provider.dart';
import 'schema_friend_selection_provider.dart';

const _rosterReorderHoldDuration = Duration(seconds: 2);

class SchemaResolvedFriendEntry {
  const SchemaResolvedFriendEntry({
    required this.link,
    required this.identity,
    required this.presence,
  });

  final SchemaFriendLink link;
  final SchemaFriendIdentity identity;
  final SchemaFriendPresence presence;

  String get friendId => identity.userId;

  DateTime? get activityAt =>
      presence.lastActiveAt ?? link.updatedAt ?? link.createdAt;
}

class SchemaResolvedAcceptedFriendsState {
  const SchemaResolvedAcceptedFriendsState({
    required this.entries,
    required this.loadingCount,
    required this.totalAcceptedCount,
  });

  final List<SchemaResolvedFriendEntry> entries;
  final int loadingCount;
  final int totalAcceptedCount;
}

class SchemaGroupedFriendRoster {
  const SchemaGroupedFriendRoster({
    required this.inRooms,
    required this.online,
    required this.offline,
    required this.loadingCount,
    required this.totalAcceptedCount,
  });

  final List<SchemaResolvedFriendEntry> inRooms;
  final List<SchemaResolvedFriendEntry> online;
  final List<SchemaResolvedFriendEntry> offline;
  final int loadingCount;
  final int totalAcceptedCount;

  int get liveCount => inRooms.length + online.length;
}

final schemaResolvedAcceptedFriendsProvider =
    Provider.autoDispose<SchemaResolvedAcceptedFriendsState>((ref) {
      final authUserId = ref.watch(schemaAuthUserIdProvider);
      final acceptedLinks = ref.watch(schemaAcceptedFriendLinksProvider);

      if (authUserId == null || authUserId.isEmpty) {
        return const SchemaResolvedAcceptedFriendsState(
          entries: <SchemaResolvedFriendEntry>[],
          loadingCount: 0,
          totalAcceptedCount: 0,
        );
      }

      final entries = <SchemaResolvedFriendEntry>[];
      var loadingCount = 0;

      for (final link in acceptedLinks) {
        final friendUserId = link.otherUserId(authUserId);
        if (friendUserId.isEmpty) {
          continue;
        }

        final identity = ref
            .watch(schemaFriendIdentityProvider(friendUserId))
            .valueOrNull;
        final presence = ref
            .watch(schemaStableFriendPresenceProvider(friendUserId))
            .valueOrNull;

        if (identity == null || presence == null) {
          loadingCount += 1;
          continue;
        }

        entries.add(
          SchemaResolvedFriendEntry(
            link: link,
            identity: identity,
            presence: presence,
          ),
        );
      }

      return SchemaResolvedAcceptedFriendsState(
        entries: List.unmodifiable(entries),
        loadingCount: loadingCount,
        totalAcceptedCount: acceptedLinks.length,
      );
    });

final schemaStickyGroupedFriendRosterProvider =
    StreamProvider.autoDispose<SchemaGroupedFriendRoster>((ref) {
      return Stream.multi((controller) {
        var disposed = false;
        Timer? reorderTimer;
        SchemaGroupedFriendRoster? stableRoster;
        SchemaGroupedFriendRoster? pendingRoster;
        String? lastSelectedFriendId;
        var lastResolvedState = const SchemaResolvedAcceptedFriendsState(
          entries: <SchemaResolvedFriendEntry>[],
          loadingCount: 0,
          totalAcceptedCount: 0,
        );

        void emitRoster(SchemaGroupedFriendRoster roster) {
          if (disposed || controller.isClosed) {
            return;
          }
          controller.add(roster);
        }

        SchemaGroupedFriendRoster targetRosterFor(
          SchemaResolvedAcceptedFriendsState resolvedState,
          String? selectedFriendId,
        ) {
          return _buildTargetRoster(
            entries: resolvedState.entries,
            selectedFriendId: selectedFriendId,
            loadingCount: resolvedState.loadingCount,
            totalAcceptedCount: resolvedState.totalAcceptedCount,
          );
        }

        void handleInputs(
          SchemaResolvedAcceptedFriendsState resolvedState,
          String? selectedFriendId,
        ) {
          if (disposed || controller.isClosed) {
            return;
          }

          lastResolvedState = resolvedState;
          final targetRoster = targetRosterFor(resolvedState, selectedFriendId);
          final currentStableRoster = stableRoster;

          if (currentStableRoster == null) {
            pendingRoster = null;
            reorderTimer?.cancel();
            stableRoster = targetRoster;
            lastSelectedFriendId = selectedFriendId;
            emitRoster(targetRoster);
            return;
          }

          final selectionChanged = lastSelectedFriendId != selectedFriendId;
          lastSelectedFriendId = selectedFriendId;

          if (!_hasSameGroupMembers(currentStableRoster, targetRoster) ||
              selectionChanged) {
            pendingRoster = null;
            reorderTimer?.cancel();
            stableRoster = targetRoster;
            emitRoster(targetRoster);
            return;
          }

          if (_hasSameOrderedIds(currentStableRoster, targetRoster)) {
            pendingRoster = null;
            reorderTimer?.cancel();
            final refreshedRoster = _projectRosterOntoOrder(
              orderSource: currentStableRoster,
              entries: resolvedState.entries,
              selectedFriendId: selectedFriendId,
              loadingCount: resolvedState.loadingCount,
              totalAcceptedCount: resolvedState.totalAcceptedCount,
            );
            stableRoster = refreshedRoster;
            emitRoster(refreshedRoster);
            return;
          }

          pendingRoster = targetRoster;
          reorderTimer?.cancel();

          final holdingRoster = _projectRosterOntoOrder(
            orderSource: currentStableRoster,
            entries: resolvedState.entries,
            selectedFriendId: selectedFriendId,
            loadingCount: resolvedState.loadingCount,
            totalAcceptedCount: resolvedState.totalAcceptedCount,
          );
          stableRoster = holdingRoster;
          emitRoster(holdingRoster);

          reorderTimer = Timer(_rosterReorderHoldDuration, () {
            if (disposed || controller.isClosed || pendingRoster == null) {
              return;
            }
            stableRoster = pendingRoster;
            pendingRoster = null;
            emitRoster(stableRoster!);
          });
        }

        ref.listen<SchemaResolvedAcceptedFriendsState>(
          schemaResolvedAcceptedFriendsProvider,
          (_, next) => handleInputs(
            next,
            ref.read(effectiveSelectedSchemaFriendIdProvider),
          ),
          fireImmediately: true,
        );

        ref.listen<String?>(
          effectiveSelectedSchemaFriendIdProvider,
          (_, next) => handleInputs(lastResolvedState, next),
          fireImmediately: true,
        );

        controller.onCancel = () {
          disposed = true;
          reorderTimer?.cancel();
        };
      });
    });

SchemaGroupedFriendRoster _buildTargetRoster({
  required List<SchemaResolvedFriendEntry> entries,
  required String? selectedFriendId,
  required int loadingCount,
  required int totalAcceptedCount,
}) {
  final inRooms = <SchemaResolvedFriendEntry>[];
  final online = <SchemaResolvedFriendEntry>[];
  final offline = <SchemaResolvedFriendEntry>[];

  for (final entry in entries) {
    switch (entry.presence.group) {
      case SchemaFriendPresenceGroup.inRoom:
        inRooms.add(entry);
      case SchemaFriendPresenceGroup.online:
        online.add(entry);
      case SchemaFriendPresenceGroup.offline:
        offline.add(entry);
    }
  }

  int compareEntries(
    SchemaResolvedFriendEntry left,
    SchemaResolvedFriendEntry right,
  ) {
    final leftSelected = left.friendId == selectedFriendId;
    final rightSelected = right.friendId == selectedFriendId;
    if (leftSelected != rightSelected) {
      return leftSelected ? -1 : 1;
    }

    final leftActivity = left.activityAt;
    final rightActivity = right.activityAt;
    if (leftActivity != null && rightActivity != null) {
      final activityCompare = rightActivity.compareTo(leftActivity);
      if (activityCompare != 0) {
        return activityCompare;
      }
    } else if (leftActivity != null || rightActivity != null) {
      return rightActivity == null ? -1 : 1;
    }

    return left.identity.username.toLowerCase().compareTo(
      right.identity.username.toLowerCase(),
    );
  }

  inRooms.sort(compareEntries);
  online.sort(compareEntries);
  offline.sort(compareEntries);

  return SchemaGroupedFriendRoster(
    inRooms: List.unmodifiable(inRooms),
    online: List.unmodifiable(online),
    offline: List.unmodifiable(offline),
    loadingCount: loadingCount,
    totalAcceptedCount: totalAcceptedCount,
  );
}

SchemaGroupedFriendRoster _projectRosterOntoOrder({
  required SchemaGroupedFriendRoster orderSource,
  required List<SchemaResolvedFriendEntry> entries,
  required String? selectedFriendId,
  required int loadingCount,
  required int totalAcceptedCount,
}) {
  final entryMap = {for (final entry in entries) entry.friendId: entry};

  List<SchemaResolvedFriendEntry> projectGroup(
    List<SchemaResolvedFriendEntry> currentOrder,
    SchemaFriendPresenceGroup group,
  ) {
    final projected = <SchemaResolvedFriendEntry>[];
    final usedIds = <String>{};

    for (final orderedEntry in currentOrder) {
      final nextEntry = entryMap[orderedEntry.friendId];
      if (nextEntry == null || nextEntry.presence.group != group) {
        continue;
      }
      projected.add(nextEntry);
      usedIds.add(nextEntry.friendId);
    }

    final remaining =
        entries
            .where(
              (entry) =>
                  entry.presence.group == group &&
                  !usedIds.contains(entry.friendId),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final leftSelected = left.friendId == selectedFriendId;
            final rightSelected = right.friendId == selectedFriendId;
            if (leftSelected != rightSelected) {
              return leftSelected ? -1 : 1;
            }
            final leftActivity = left.activityAt;
            final rightActivity = right.activityAt;
            if (leftActivity != null && rightActivity != null) {
              final compare = rightActivity.compareTo(leftActivity);
              if (compare != 0) {
                return compare;
              }
            } else if (leftActivity != null || rightActivity != null) {
              return rightActivity == null ? -1 : 1;
            }
            return left.identity.username.toLowerCase().compareTo(
              right.identity.username.toLowerCase(),
            );
          });

    return List.unmodifiable(<SchemaResolvedFriendEntry>[
      ...projected,
      ...remaining,
    ]);
  }

  return SchemaGroupedFriendRoster(
    inRooms: projectGroup(
      orderSource.inRooms,
      SchemaFriendPresenceGroup.inRoom,
    ),
    online: projectGroup(orderSource.online, SchemaFriendPresenceGroup.online),
    offline: projectGroup(
      orderSource.offline,
      SchemaFriendPresenceGroup.offline,
    ),
    loadingCount: loadingCount,
    totalAcceptedCount: totalAcceptedCount,
  );
}

bool _hasSameGroupMembers(
  SchemaGroupedFriendRoster left,
  SchemaGroupedFriendRoster right,
) {
  return _sameIdsUnordered(left.inRooms, right.inRooms) &&
      _sameIdsUnordered(left.online, right.online) &&
      _sameIdsUnordered(left.offline, right.offline);
}

bool _hasSameOrderedIds(
  SchemaGroupedFriendRoster left,
  SchemaGroupedFriendRoster right,
) {
  return _sameIdsOrdered(left.inRooms, right.inRooms) &&
      _sameIdsOrdered(left.online, right.online) &&
      _sameIdsOrdered(left.offline, right.offline);
}

bool _sameIdsOrdered(
  List<SchemaResolvedFriendEntry> left,
  List<SchemaResolvedFriendEntry> right,
) {
  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index += 1) {
    if (left[index].friendId != right[index].friendId) {
      return false;
    }
  }
  return true;
}

bool _sameIdsUnordered(
  List<SchemaResolvedFriendEntry> left,
  List<SchemaResolvedFriendEntry> right,
) {
  if (left.length != right.length) {
    return false;
  }

  final leftIds = left.map((entry) => entry.friendId).toSet();
  final rightIds = right.map((entry) => entry.friendId).toSet();
  return leftIds.length == rightIds.length && leftIds.containsAll(rightIds);
}
