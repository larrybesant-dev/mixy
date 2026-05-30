import 'package:flutter/material.dart';
// Granular selector providers for room render-surface optimization.
//
// These providers derive narrow slices from the existing layered state so that
// individual UI widgets (message list, coach panel) only rebuild when their
// specific slice changes — not on every combined-state emission from
// roomLiveStateProvider.
//
// TYPING INDICATOR: use the existing roomTypingUserIdsProvider in
// message_providers.dart (StreamProvider<List<String>> family).
//
// CONTRACT:
//   - Providers here must NEVER own a Firestore listener directly.
//   - They derive from existing stream providers (participantsStreamProvider,
//     messagetreamProvider, roomActivityStateProvider, roomDocStreamProvider).
//   - All returned value types must implement operator== so Riverpod can
//     suppress redundant notifications.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/room_participant_model.dart';
import 'package:mixvy/features/feed/providers/typing_providers.dart';
import 'message_providers.dart';
import 'participant_providers.dart';
// ─────────────────────────────────────────────────────────────────────────────
// COACH METRICS VALUE CLASS
//
// Immutable scalar snapshot consumed by _FirstThirtySecondsCoach.
// operator== prevents the coach from rebuilding when numbers haven't changed.
// ─────────────────────────────────────────────────────────────────────────────

class RoomCoachMetrics {
  final String roomTitle;
  final int participantCount;
  final int messageCount;
  final int typingCount;
  final bool hostActive;
  final int onMicCount;

  const RoomCoachMetrics({
    required this.roomTitle,
    required this.participantCount,
    required this.messageCount,
    required this.typingCount,
    required this.hostActive,
    required this.onMicCount,
  });

  const RoomCoachMetrics.empty()
    : roomTitle = '',
      participantCount = 0,
      messageCount = 0,
      typingCount = 0,
      hostActive = false,
      onMicCount = 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoomCoachMetrics &&
        other.roomTitle == roomTitle &&
        other.participantCount == participantCount &&
        other.messageCount == messageCount &&
        other.typingCount == typingCount &&
        other.hostActive == hostActive &&
        other.onMicCount == onMicCount;
  }

  @override
  int get hashCode => Object.hash(
    roomTitle,
    participantCount,
    messageCount,
    typingCount,
    hostActive,
    onMicCount,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// COACH METRICS PROVIDER
//
// Derives all scalars needed by _FirstThirtySecondsCoach from already-active
// stream providers.  Because RoomCoachMetrics implements operator==, Riverpod
// will only notify the coach widget when the numbers actually change.
// ─────────────────────────────────────────────────────────────────────────────

final roomCoachMetricsProvider = Provider.autoDispose
    .family<RoomCoachMetrics, String>((ref, roomId) {
      final roomDoc =
          ref.watch(roomDocStreamProvider(roomId)).valueOrNull ?? {};
      final participants =
          ref.watch(participantsStreamProvider(roomId)).valueOrNull ??
          const <RoomParticipantModel>[];
      final messages =
          ref.watch(roomMessageStreamProvider(roomId)).valueOrNull ??
          const <dynamic>[];
      // Watch typingStreamProvider directly — bypasses the participant-hydration
      // gate in roomActivityStateProvider so typing is visible immediately.
      final typingMap =
          ref.watch(typingStreamProvider(roomId)).valueOrNull ?? const {};

      final typingCount = typingMap.values.where((v) => v == true).length;

      final hostActive = participants.any(
        (p) =>
            (p.role == 'host' || p.role == 'cohost') &&
            (p.micOn ||
                DateTime.now().difference(p.lastActiveAt).inSeconds <= 25),
      );

      final onMicCount = participants
          .where((p) => roomParticipantCanBeShownAsTalking(p))
          .length;

      // Prefer 'name' (room doc field) then 'title' as fallback.
      final rawTitle = (roomDoc['name'] ?? roomDoc['title'] ?? '')
          .toString()
          .trim();

      return RoomCoachMetrics(
        roomTitle: rawTitle,
        participantCount: participants.length,
        messageCount: messages.length,
        typingCount: typingCount,
        hostActive: hostActive,
        onMicCount: onMicCount,
      );
    });




