import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schema_friend_presence.dart';
import 'schema_friend_links_providers.dart';

const _presenceDebounceDuration = Duration(milliseconds: 700);
const _presenceHoldDuration = Duration(seconds: 2);

final schemaStableFriendPresenceProvider = StreamProvider.autoDispose
    .family<SchemaFriendPresence, String>((ref, friendId) {
  return Stream.multi((controller) {
    bool disposed = false;
    bool hasEmittedInitialState = false;
    Timer? debounceTimer;
    Timer? pendingTransitionTimer;
    SchemaFriendPresence? stablePresence;
    SchemaFriendPresence? pendingPresence;

    void emitStable() {
      if (disposed || controller.isClosed || stablePresence == null) {
        return;
      }
      controller.add(stablePresence!);
    }

    void applyPresence(SchemaFriendPresence nextPresence) {
      final normalizedPresence = nextPresence.normalized();
      final currentStablePresence = stablePresence;
      if (currentStablePresence == null) {
        stablePresence = normalizedPresence;
        emitStable();
        return;
      }

      if (_hasEquivalentPlacement(
        currentStablePresence,
        normalizedPresence,
      )) {
        pendingPresence = null;
        pendingTransitionTimer?.cancel();
        if (!_hasEquivalentPayload(
          currentStablePresence,
          normalizedPresence,
        )) {
          stablePresence = normalizedPresence;
          emitStable();
        }
        return;
      }

      if (_isPromotion(currentStablePresence, normalizedPresence)) {
        pendingPresence = null;
        pendingTransitionTimer?.cancel();
        stablePresence = normalizedPresence;
        emitStable();
        return;
      }

      if (pendingPresence != null &&
          _hasEquivalentPayload(pendingPresence!, normalizedPresence)) {
        return;
      }

      pendingPresence = normalizedPresence;
      pendingTransitionTimer?.cancel();
      pendingTransitionTimer = Timer(_presenceHoldDuration, () {
        if (disposed || controller.isClosed || pendingPresence == null) {
          return;
        }
        stablePresence = pendingPresence;
        pendingPresence = null;
        emitStable();
      });
    }

    void handlePresence(SchemaFriendPresence nextPresence) {
      if (disposed || controller.isClosed) {
        return;
      }

      final normalizedPresence = nextPresence.normalized();
      if (!hasEmittedInitialState) {
        hasEmittedInitialState = true;
        stablePresence = normalizedPresence;
        emitStable();
        return;
      }

      debounceTimer?.cancel();
      debounceTimer = Timer(_presenceDebounceDuration, () {
        applyPresence(normalizedPresence);
      });
    }

    ref.listen<AsyncValue<SchemaFriendPresence>>(
      schemaFriendPresenceProvider(friendId),
      (_, next) {
        next.when(
          data: handlePresence,
          loading: () {},
          error: (error, stackTrace) => controller.addError(error, stackTrace),
        );
      },
      fireImmediately: true,
    );

    controller.onCancel = () {
      disposed = true;
      debounceTimer?.cancel();
      pendingTransitionTimer?.cancel();
    };
  });
});

final schemaStableFriendPresenceMapProvider =
    StreamProvider.autoDispose<Map<String, SchemaFriendPresence>>((ref) {
  return Stream.multi((controller) {
    bool disposed = false;
    bool hasEmittedInitialState = false;
    Timer? debounceTimer;
    final Map<String, SchemaFriendPresence> stablePresenceMap =
        <String, SchemaFriendPresence>{};
    Map<String, SchemaFriendPresence> latestRawPresenceMap =
        <String, SchemaFriendPresence>{};
    final pendingTransitions = <String, _PendingPresenceTransition>{};

    void emitStableMap() {
      if (disposed || controller.isClosed) {
        return;
      }
      controller.add(
        Map<String, SchemaFriendPresence>.unmodifiable(stablePresenceMap),
      );
    }

    void cancelPendingTransition(String friendId) {
      final pendingTransition = pendingTransitions.remove(friendId);
      pendingTransition?.timer.cancel();
    }

    void applySnapshot(Map<String, SchemaFriendPresence> snapshot) {
      bool didChange = false;
      final normalizedSnapshot = {
        for (final entry in snapshot.entries)
          entry.key: entry.value.normalized(),
      };

      final removedFriendIds = stablePresenceMap.keys
          .where((friendId) => !normalizedSnapshot.containsKey(friendId))
          .toList(growable: false);
      for (final friendId in removedFriendIds) {
        cancelPendingTransition(friendId);
        stablePresenceMap.remove(friendId);
        didChange = true;
      }

      for (final entry in normalizedSnapshot.entries) {
        final friendId = entry.key;
        final nextPresence = entry.value;
        final currentStablePresence = stablePresenceMap[friendId];

        if (currentStablePresence == null) {
          cancelPendingTransition(friendId);
          stablePresenceMap[friendId] = nextPresence;
          didChange = true;
          continue;
        }

        if (_hasEquivalentPlacement(currentStablePresence, nextPresence)) {
          cancelPendingTransition(friendId);
          if (!_hasEquivalentPayload(currentStablePresence, nextPresence)) {
            stablePresenceMap[friendId] = nextPresence;
            didChange = true;
          }
          continue;
        }

        if (_isPromotion(currentStablePresence, nextPresence)) {
          cancelPendingTransition(friendId);
          stablePresenceMap[friendId] = nextPresence;
          didChange = true;
          continue;
        }

        final pendingTransition = pendingTransitions[friendId];
        if (pendingTransition != null &&
            _hasEquivalentPayload(pendingTransition.target, nextPresence)) {
          continue;
        }

        cancelPendingTransition(friendId);
        pendingTransitions[friendId] = _PendingPresenceTransition(
          target: nextPresence,
          timer: Timer(_presenceHoldDuration, () {
            if (disposed || controller.isClosed) {
              return;
            }
            pendingTransitions.remove(friendId);
            stablePresenceMap[friendId] = nextPresence;
            emitStableMap();
          }),
        );
      }

      if (didChange) {
        emitStableMap();
      }
    }

    void handleSnapshot(Map<String, SchemaFriendPresence> snapshot) {
      if (disposed || controller.isClosed) {
        return;
      }

      latestRawPresenceMap = snapshot;
      if (!hasEmittedInitialState) {
        hasEmittedInitialState = true;
        applySnapshot(snapshot);
        return;
      }

      debounceTimer?.cancel();
      debounceTimer = Timer(_presenceDebounceDuration, () {
        applySnapshot(latestRawPresenceMap);
      });
    }

    ref.listen<AsyncValue<Map<String, SchemaFriendPresence>>>(
      schemaFriendPresenceMapProvider,
      (_, next) {
        next.when(
          data: handleSnapshot,
          loading: () {},
          error: (error, stackTrace) => controller.addError(error, stackTrace),
        );
      },
      fireImmediately: true,
    );

    controller.onCancel = () {
      disposed = true;
      debounceTimer?.cancel();
      for (final transition in pendingTransitions.values) {
        transition.timer.cancel();
      }
      pendingTransitions.clear();
    };
  });
});

bool _hasEquivalentPlacement(
  SchemaFriendPresence left,
  SchemaFriendPresence right,
) {
  return left.group == right.group;
}

bool _hasEquivalentPayload(
  SchemaFriendPresence left,
  SchemaFriendPresence right,
) {
  return left.friendId == right.friendId &&
      left.group == right.group &&
      left.roomId == right.roomId &&
      left.isOnline == right.isOnline &&
      left.lastActiveAt == right.lastActiveAt;
}

bool _isPromotion(SchemaFriendPresence current, SchemaFriendPresence next) {
  return _presenceGroupRank(next.group) < _presenceGroupRank(current.group);
}

int _presenceGroupRank(SchemaFriendPresenceGroup group) {
  switch (group) {
    case SchemaFriendPresenceGroup.inRoom:
      return 0;
    case SchemaFriendPresenceGroup.online:
      return 1;
    case SchemaFriendPresenceGroup.offline:
      return 2;
  }
}

class _PendingPresenceTransition {
  const _PendingPresenceTransition({required this.target, required this.timer});

  final SchemaFriendPresence target;
  final Timer timer;
}
