import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'schema_boot_timeline_provider.dart';
import 'schema_friend_focus_anchor_provider.dart';
import 'schema_friend_links_providers.dart';
import '../../messages/providers/schema_conversations_providers.dart';

final selectedSchemaFriendIdProvider = StateProvider<String?>((ref) => null);

class SchemaConversationBootTarget {
  const SchemaConversationBootTarget({
    required this.conversationId,
    required this.friendId,
  });

  final String conversationId;
  final String friendId;
}

enum SchemaConversationBootSource { appStart, authSwitch, unknown }

class SchemaConversationBootExecutionContext {
  const SchemaConversationBootExecutionContext({
    required this.bootId,
    required this.source,
    required this.createdAt,
    required this.target,
  });

  final String bootId;
  final SchemaConversationBootSource source;
  final DateTime createdAt;
  final SchemaConversationBootTarget target;
}

enum SchemaConversationBootPhase {
  idle,
  resolving,
  selecting,
  anchoring,
  routing,
  complete,
  failed,
}

class SchemaConversationBootState {
  const SchemaConversationBootState({
    required this.phase,
    this.target,
    this.executionContext,
    this.startedAt,
    this.completedAt,
  });

  final SchemaConversationBootPhase phase;
  final SchemaConversationBootTarget? target;
  final SchemaConversationBootExecutionContext? executionContext;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isTerminal =>
      phase == SchemaConversationBootPhase.complete ||
      phase == SchemaConversationBootPhase.failed;

  bool get isInFlight =>
      phase == SchemaConversationBootPhase.resolving ||
      phase == SchemaConversationBootPhase.selecting ||
      phase == SchemaConversationBootPhase.anchoring ||
      phase == SchemaConversationBootPhase.routing;

  SchemaConversationBootState copyWith({
    SchemaConversationBootPhase? phase,
    SchemaConversationBootTarget? target,
    bool clearTarget = false,
    SchemaConversationBootExecutionContext? executionContext,
    bool clearExecutionContext = false,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return SchemaConversationBootState(
      phase: phase ?? this.phase,
      target: clearTarget ? null : (target ?? this.target),
      executionContext: clearExecutionContext
          ? null
          : (executionContext ?? this.executionContext),
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}

class SchemaConversationBootStateNotifier
    extends StateNotifier<SchemaConversationBootState> {
  int _bootGeneration = 0;

  SchemaConversationBootStateNotifier()
    : super(
        const SchemaConversationBootState(
          phase: SchemaConversationBootPhase.idle,
        ),
      );

  void reset() {
    state = const SchemaConversationBootState(
      phase: SchemaConversationBootPhase.idle,
    );
  }

  SchemaConversationBootExecutionContext beginBoot({
    required SchemaConversationBootTarget target,
    required SchemaConversationBootSource source,
  }) {
    _bootGeneration += 1;
    final context = SchemaConversationBootExecutionContext(
      bootId:
          'schema-boot-$_bootGeneration-${DateTime.now().microsecondsSinceEpoch}',
      source: source,
      createdAt: DateTime.now(),
      target: target,
    );

    state = SchemaConversationBootState(
      phase: SchemaConversationBootPhase.resolving,
      target: target,
      executionContext: context,
      startedAt: DateTime.now(),
    );
    return context;
  }

  void markSelecting(SchemaConversationBootTarget target) {
    state = state.copyWith(
      phase: SchemaConversationBootPhase.selecting,
      target: target,
      startedAt: state.startedAt ?? DateTime.now(),
      clearCompletedAt: true,
    );
  }

  void markAnchoring(SchemaConversationBootTarget target) {
    state = state.copyWith(
      phase: SchemaConversationBootPhase.anchoring,
      target: target,
      startedAt: state.startedAt ?? DateTime.now(),
      clearCompletedAt: true,
    );
  }

  void markRouting(SchemaConversationBootTarget target) {
    state = state.copyWith(
      phase: SchemaConversationBootPhase.routing,
      target: target,
      startedAt: state.startedAt ?? DateTime.now(),
      clearCompletedAt: true,
    );
  }

  void markComplete(SchemaConversationBootTarget target) {
    state = state.copyWith(
      phase: SchemaConversationBootPhase.complete,
      target: target,
      startedAt: state.startedAt ?? DateTime.now(),
      completedAt: DateTime.now(),
    );
  }

  void markFailed(SchemaConversationBootTarget? target) {
    state = state.copyWith(
      phase: SchemaConversationBootPhase.failed,
      target: target,
      startedAt: state.startedAt ?? DateTime.now(),
      completedAt: DateTime.now(),
    );
  }
}

final schemaConversationBootStateProvider =
    StateNotifierProvider<
      SchemaConversationBootStateNotifier,
      SchemaConversationBootState
    >((ref) => SchemaConversationBootStateNotifier());

final schemaConversationBootConsumedProvider = Provider<bool>((ref) {
  return ref.watch(schemaConversationBootStateProvider).phase ==
      SchemaConversationBootPhase.complete;
});

class SchemaBootScopedWriteGuard {
  const SchemaBootScopedWriteGuard(this._ref);

  final Ref _ref;

  bool canMutateForBootId(String bootId) {
    final bootState = _ref.read(schemaConversationBootStateProvider);
    final activeBootId = bootState.executionContext?.bootId;
    return activeBootId == bootId && bootState.isInFlight;
  }

  bool trySetSelectedFriendFromBoot({
    required String bootId,
    required String friendId,
  }) {
    if (!canMutateForBootId(bootId)) {
      return false;
    }

    _ref.read(selectedSchemaFriendIdProvider.notifier).state = friendId;
    return true;
  }

  bool trySetFocusAnchorFromBoot({
    required String bootId,
    required String friendId,
  }) {
    if (!canMutateForBootId(bootId)) {
      return false;
    }

    _ref
        .read(schemaFriendFocusAnchorProvider.notifier)
        .setFocusedFriend(friendId, updateInteractionTime: false);
    return true;
  }

  bool tryCommitBootFocusState({
    required String bootId,
    required String friendId,
  }) {
    if (!canMutateForBootId(bootId)) {
      return false;
    }

    _ref.read(selectedSchemaFriendIdProvider.notifier).state = friendId;
    _ref
        .read(schemaFriendFocusAnchorProvider.notifier)
        .setFocusedFriend(friendId, updateInteractionTime: false);
    return true;
  }
}

final schemaBootScopedWriteGuardProvider = Provider<SchemaBootScopedWriteGuard>(
  (ref) => SchemaBootScopedWriteGuard(ref),
);

class SchemaConversationBootEngine {
  const SchemaConversationBootEngine(this._ref);

  final Ref _ref;

  void startConversationBoot({
    required SchemaConversationBootTarget target,
    required SchemaConversationBootSource source,
    required Future<void> Function(String conversationId) navigate,
  }) {
    final bootState = _ref.read(schemaConversationBootStateProvider);
    if (bootState.isTerminal || bootState.isInFlight) {
      _recordTimeline(
        bootId: 'none',
        source: source,
        phase: bootState.phase,
        level: SchemaBootTimelineLevel.warning,
        message: 'Boot start ignored: phase=${bootState.phase.name}',
      );
      return;
    }

    final notifier = _ref.read(schemaConversationBootStateProvider.notifier);
    final writeGuard = _ref.read(schemaBootScopedWriteGuardProvider);

    final bootContext = notifier.beginBoot(target: target, source: source);
    developer.log(
      'bootTargetResolved bootId=${bootContext.bootId} source=${bootContext.source.name} '
      'conversationId=${target.conversationId} friendId=${target.friendId}',
      name: 'FriendsSchemaBridgeBoot',
    );
    _recordTimeline(
      bootId: bootContext.bootId,
      source: bootContext.source,
      phase: SchemaConversationBootPhase.resolving,
      message:
          'Resolved target conversation=${target.conversationId} friend=${target.friendId}',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final afterResolve = _ref.read(schemaConversationBootStateProvider);
      if (!_isActiveBoot(
        afterResolve,
        bootContext.bootId,
        SchemaConversationBootPhase.resolving,
      )) {
        _recordTimeline(
          bootId: bootContext.bootId,
          source: bootContext.source,
          phase: afterResolve.phase,
          level: SchemaBootTimelineLevel.warning,
          message: 'Resolve frame skipped due to inactive boot context',
        );
        return;
      }

      final stagedFriendId = target.friendId;

      try {
        notifier.markSelecting(target);
        _recordTimeline(
          bootId: bootContext.bootId,
          source: bootContext.source,
          phase: SchemaConversationBootPhase.selecting,
          message: 'Selection phase entered',
        );

        notifier.markAnchoring(target);
        _recordTimeline(
          bootId: bootContext.bootId,
          source: bootContext.source,
          phase: SchemaConversationBootPhase.anchoring,
          message: 'Anchor phase entered',
        );

        developer.log(
          'bootShadowPrepared bootId=${bootContext.bootId} friendId=$stagedFriendId',
          name: 'FriendsSchemaBridgeBoot',
        );
        _recordTimeline(
          bootId: bootContext.bootId,
          source: bootContext.source,
          phase: SchemaConversationBootPhase.anchoring,
          message: 'Shadow state prepared friend=$stagedFriendId',
        );
      } catch (error) {
        notifier.markFailed(target);
        developer.log(
          'bootSelectionFailed bootId=${bootContext.bootId} error=$error',
          name: 'FriendsSchemaBridgeBoot',
          error: error,
        );
        _recordTimeline(
          bootId: bootContext.bootId,
          source: bootContext.source,
          phase: SchemaConversationBootPhase.failed,
          level: SchemaBootTimelineLevel.error,
          message: 'Selection/anchor failed: $error',
        );
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final beforeRoute = _ref.read(schemaConversationBootStateProvider);
        if (!_isActiveBoot(
          beforeRoute,
          bootContext.bootId,
          SchemaConversationBootPhase.anchoring,
        )) {
          _recordTimeline(
            bootId: bootContext.bootId,
            source: bootContext.source,
            phase: beforeRoute.phase,
            level: SchemaBootTimelineLevel.warning,
            message: 'Route frame skipped due to inactive boot context',
          );
          return;
        }

        try {
          if (stagedFriendId.isEmpty) {
            notifier.markFailed(target);
            developer.log(
              'bootCommitRejected bootId=${bootContext.bootId} reason=missing_staged_friend',
              name: 'FriendsSchemaBridgeBoot',
            );
            _recordTimeline(
              bootId: bootContext.bootId,
              source: bootContext.source,
              phase: SchemaConversationBootPhase.failed,
              level: SchemaBootTimelineLevel.error,
              message: 'Commit rejected: missing staged friend',
            );
            return;
          }

          notifier.markRouting(target);
          _recordTimeline(
            bootId: bootContext.bootId,
            source: bootContext.source,
            phase: SchemaConversationBootPhase.routing,
            message: 'Routing phase entered',
          );

          final committed = writeGuard.tryCommitBootFocusState(
            bootId: bootContext.bootId,
            friendId: stagedFriendId,
          );
          if (!committed) {
            notifier.markFailed(target);
            developer.log(
              'bootCommitRejected bootId=${bootContext.bootId} reason=stale_boot',
              name: 'FriendsSchemaBridgeBoot',
            );
            _recordTimeline(
              bootId: bootContext.bootId,
              source: bootContext.source,
              phase: SchemaConversationBootPhase.failed,
              level: SchemaBootTimelineLevel.error,
              message: 'Commit rejected: stale boot ownership',
            );
            return;
          }
          _recordTimeline(
            bootId: bootContext.bootId,
            source: bootContext.source,
            phase: SchemaConversationBootPhase.routing,
            message: 'Focus state committed atomically',
          );

          await navigate(target.conversationId);
          notifier.markComplete(target);
          developer.log(
            'navigationTriggered bootId=${bootContext.bootId} '
            'conversationId=${target.conversationId} bootCompleted=true',
            name: 'FriendsSchemaBridgeBoot',
          );
          _recordTimeline(
            bootId: bootContext.bootId,
            source: bootContext.source,
            phase: SchemaConversationBootPhase.complete,
            message: 'Navigation triggered and boot completed',
          );
        } catch (error) {
          notifier.markFailed(target);
          developer.log(
            'bootNavigationFailed bootId=${bootContext.bootId} error=$error',
            name: 'FriendsSchemaBridgeBoot',
            error: error,
          );
          _recordTimeline(
            bootId: bootContext.bootId,
            source: bootContext.source,
            phase: SchemaConversationBootPhase.failed,
            level: SchemaBootTimelineLevel.error,
            message: 'Navigation failed: $error',
          );
        }
      });
    });
  }

  void _recordTimeline({
    required String bootId,
    required SchemaConversationBootSource source,
    required SchemaConversationBootPhase phase,
    required String message,
    SchemaBootTimelineLevel level = SchemaBootTimelineLevel.info,
  }) {
    if (!kDebugMode) {
      return;
    }

    _ref
        .read(schemaBootTimelineProvider.notifier)
        .record(
          SchemaBootTimelineEvent(
            timestamp: DateTime.now(),
            bootId: bootId,
            source: source,
            phase: phase,
            level: level,
            message: message,
          ),
        );
  }

  bool _isActiveBoot(
    SchemaConversationBootState state,
    String bootId,
    SchemaConversationBootPhase expectedPhase,
  ) {
    return state.phase == expectedPhase &&
        state.executionContext?.bootId == bootId;
  }
}

final schemaConversationBootEngineProvider =
    Provider<SchemaConversationBootEngine>(
      (ref) => SchemaConversationBootEngine(ref),
    );

final schemaConversationFirstBootTargetProvider =
    Provider.autoDispose<SchemaConversationBootTarget?>((ref) {
      final authUserId = ref.watch(schemaAuthUserIdProvider).valueOrNull;
      if (authUserId == null || authUserId.isEmpty) {
        return null;
      }

      final conversations =
          ref.watch(schemaMyConversationsProvider).valueOrNull ?? const [];

      for (final conversation in conversations) {
        if (!conversation.isDirect || !conversation.isActive) {
          continue;
        }
        if (conversation.id.isEmpty) {
          continue;
        }

        for (final participantId in conversation.participantIds) {
          if (participantId != authUserId && participantId.isNotEmpty) {
            return SchemaConversationBootTarget(
              conversationId: conversation.id,
              friendId: participantId,
            );
          }
        }
      }

      return null;
    });

final effectiveSelectedSchemaFriendIdProvider = Provider.autoDispose<String?>((
  ref,
) {
  final explicitSelection = ref.watch(selectedSchemaFriendIdProvider);
  if (explicitSelection != null && explicitSelection.isNotEmpty) {
    return explicitSelection;
  }

  final anchoredFriendId = ref.watch(schemaFriendFocusAnchorProvider).friendId;
  if (anchoredFriendId != null && anchoredFriendId.isNotEmpty) {
    return anchoredFriendId;
  }

  final authUserId = ref.watch(schemaAuthUserIdProvider).valueOrNull;
  if (authUserId == null || authUserId.isEmpty) {
    return null;
  }

  final conversations =
      ref.watch(schemaMyConversationsProvider).valueOrNull ?? const [];
  for (final conversation in conversations) {
    if (!conversation.isDirect || !conversation.isActive) {
      continue;
    }

    for (final participantId in conversation.participantIds) {
      if (participantId != authUserId && participantId.isNotEmpty) {
        return participantId;
      }
    }
  }

  return null;
});
