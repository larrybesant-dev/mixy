import 'package:mixvy/core/logger.dart';
import 'package:mixvy/models/room_model.dart';

enum RoomVisibilityReasonCode {
  structuralOk,
  missingOwner,
  ended,
  stale,
  graceAllowed,
}

class RoomVisibilityDecision {
  const RoomVisibilityDecision({
    required this.visible,
    required this.reasonCode,
  });

  final bool visible;
  final RoomVisibilityReasonCode reasonCode;

  String get reasonLabel {
    switch (reasonCode) {
      case RoomVisibilityReasonCode.structuralOk:
        return 'STRUCTURAL_OK';
      case RoomVisibilityReasonCode.missingOwner:
        return 'MISSING_OWNER';
      case RoomVisibilityReasonCode.ended:
        return 'ENDED';
      case RoomVisibilityReasonCode.stale:
        return 'STALE';
      case RoomVisibilityReasonCode.graceAllowed:
        return 'GRACE_ALLOWED';
    }
  }
}

class RoomVisibilityContract {
  const RoomVisibilityContract._();

  static const Duration newRoomGraceWindow = Duration(minutes: 5);
  static const Duration liveVisibilityWindow = Duration(hours: 6);

  static RoomVisibilityDecision evaluate(
    RoomModel room, {
    DateTime? now,
    Duration graceWindow = liveVisibilityWindow,
  }) {
    final resolvedNow = now ?? DateTime.now();
    final hasOwner =
        room.ownerId.trim().isNotEmpty || room.hostId.trim().isNotEmpty;

    if (!hasOwner) {
      return const RoomVisibilityDecision(
        visible: false,
        reasonCode: RoomVisibilityReasonCode.missingOwner,
      );
    }

    if (room.endedAt != null || !room.isLive) {
      return const RoomVisibilityDecision(
        visible: false,
        reasonCode: RoomVisibilityReasonCode.ended,
      );
    }

    final createdAt = room.createdAt?.toDate();
    if (createdAt == null) {
      return const RoomVisibilityDecision(
        visible: false,
        reasonCode: RoomVisibilityReasonCode.stale,
      );
    }

    final age = resolvedNow.difference(createdAt);
    if (age <= newRoomGraceWindow) {
      return const RoomVisibilityDecision(
        visible: true,
        reasonCode: RoomVisibilityReasonCode.graceAllowed,
      );
    }

    if (createdAt.add(graceWindow).isAfter(resolvedNow)) {
      return const RoomVisibilityDecision(
        visible: true,
        reasonCode: RoomVisibilityReasonCode.structuralOk,
      );
    }

    return const RoomVisibilityDecision(
      visible: false,
      reasonCode: RoomVisibilityReasonCode.stale,
    );
  }

  static bool isVisible(RoomModel room, {DateTime? now}) {
    return evaluate(room, now: now).visible;
  }

  static void logDecision(RoomModel room, RoomVisibilityDecision decision) {
    Logger.info(
      'ROOM_VISIBILITY_DECISION roomId=${room.id} reasonCode=${decision.reasonLabel}',
    );
  }
}