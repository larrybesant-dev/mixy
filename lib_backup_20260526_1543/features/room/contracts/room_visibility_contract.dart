import 'package:mixvy/core/logger.dart';
import 'package:mixvy/models/room_model.dart';

enum RoomVisibilityTier { discoverable, warm, cold, invalid }

enum RoomVisibilityReasonCode {
  discoverableFresh,
  discoverableHysteresisHold,
  warmStale,
  warmHysteresisHold,
  warmUnknownFreshness,
  coldEndedRecently,
  coldHysteresisHold,
  coldDormant,
  missingOwner,
  invalidEnded,
  invalidNotLive,
}

class RoomVisibilityResult {
  const RoomVisibilityResult({
    required this.tier,
    required this.reasonCode,
    this.staleness,
  });

  final RoomVisibilityTier tier;
  final RoomVisibilityReasonCode reasonCode;
  final Duration? staleness;

  bool get isVisible => tier != RoomVisibilityTier.invalid;

  String get reasonLabel {
    switch (reasonCode) {
      case RoomVisibilityReasonCode.discoverableFresh:
        return 'DISCOVERABLE_FRESH';
      case RoomVisibilityReasonCode.discoverableHysteresisHold:
        return 'DISCOVERABLE_HYSTERESIS_HOLD';
      case RoomVisibilityReasonCode.warmStale:
        return 'WARM_STALE';
      case RoomVisibilityReasonCode.warmHysteresisHold:
        return 'WARM_HYSTERESIS_HOLD';
      case RoomVisibilityReasonCode.warmUnknownFreshness:
        return 'WARM_UNKNOWN_FRESHNESS';
      case RoomVisibilityReasonCode.coldEndedRecently:
        return 'COLD_ENDED_RECENTLY';
      case RoomVisibilityReasonCode.coldHysteresisHold:
        return 'COLD_HYSTERESIS_HOLD';
      case RoomVisibilityReasonCode.coldDormant:
        return 'COLD_DORMANT';
      case RoomVisibilityReasonCode.missingOwner:
        return 'MISSING_OWNER';
      case RoomVisibilityReasonCode.invalidEnded:
        return 'INVALID_ENDED';
      case RoomVisibilityReasonCode.invalidNotLive:
        return 'INVALID_NOT_LIVE';
    }
  }

  String get tierLabel {
    switch (tier) {
      case RoomVisibilityTier.discoverable:
        return 'DISCOVERABLE';
      case RoomVisibilityTier.warm:
        return 'WARM';
      case RoomVisibilityTier.cold:
        return 'COLD';
      case RoomVisibilityTier.invalid:
        return 'INVALID';
    }
  }
}

class RoomVisibilityWindows {
  const RoomVisibilityWindows({
    required this.discoverableWindow,
    required this.warmWindow,
    required this.coldEndedWindow,
  });

  static const RoomVisibilityWindows defaults = RoomVisibilityWindows(
    discoverableWindow: Duration(minutes: 15),
    warmWindow: Duration(hours: 6),
    coldEndedWindow: Duration(hours: 12),
  );

  final Duration discoverableWindow;
  final Duration warmWindow;
  final Duration coldEndedWindow;
}

class RoomVisibilityContract {
  const RoomVisibilityContract._();

  static RoomVisibilityResult evaluate(
    RoomModel room, {
    DateTime? now,
    RoomVisibilityWindows windows = RoomVisibilityWindows.defaults,
  }) {
    final resolvedNow = now ?? DateTime.now();
    final hasOwner =
        room.ownerId.trim().isNotEmpty || room.hostId.trim().isNotEmpty;

    if (!hasOwner) {
      return const RoomVisibilityResult(
        tier: RoomVisibilityTier.invalid,
        reasonCode: RoomVisibilityReasonCode.missingOwner,
      );
    }

    final endedAt = room.endedAt?.toDate();
    if (endedAt != null) {
      final sinceEnded = resolvedNow.difference(endedAt);
      if (sinceEnded <= windows.coldEndedWindow) {
        return RoomVisibilityResult(
          tier: RoomVisibilityTier.cold,
          reasonCode: RoomVisibilityReasonCode.coldEndedRecently,
          staleness: sinceEnded,
        );
      }
      return RoomVisibilityResult(
        tier: RoomVisibilityTier.invalid,
        reasonCode: RoomVisibilityReasonCode.invalidEnded,
        staleness: sinceEnded,
      );
    }

    if (!room.isLive) {
      final activityAt = room.updatedAt?.toDate() ?? room.createdAt?.toDate();
      if (activityAt == null) {
        return const RoomVisibilityResult(
          tier: RoomVisibilityTier.invalid,
          reasonCode: RoomVisibilityReasonCode.invalidNotLive,
        );
      }

      final staleness = resolvedNow.difference(activityAt);
      if (staleness <= windows.warmWindow) {
        return RoomVisibilityResult(
          tier: RoomVisibilityTier.cold,
          reasonCode: RoomVisibilityReasonCode.coldDormant,
          staleness: staleness,
        );
      }

      return RoomVisibilityResult(
        tier: RoomVisibilityTier.invalid,
        reasonCode: RoomVisibilityReasonCode.invalidNotLive,
        staleness: staleness,
      );
    }

    final freshnessAnchor =
        room.updatedAt?.toDate() ?? room.createdAt?.toDate();
    if (freshnessAnchor == null) {
      return const RoomVisibilityResult(
        tier: RoomVisibilityTier.warm,
        reasonCode: RoomVisibilityReasonCode.warmUnknownFreshness,
      );
    }

    final staleness = resolvedNow.difference(freshnessAnchor);
    if (staleness <= windows.discoverableWindow) {
      return RoomVisibilityResult(
        tier: RoomVisibilityTier.discoverable,
        reasonCode: RoomVisibilityReasonCode.discoverableFresh,
        staleness: staleness,
      );
    }

    if (staleness <= windows.warmWindow) {
      return RoomVisibilityResult(
        tier: RoomVisibilityTier.warm,
        reasonCode: RoomVisibilityReasonCode.warmStale,
        staleness: staleness,
      );
    }

    return RoomVisibilityResult(
      tier: RoomVisibilityTier.cold,
      reasonCode: RoomVisibilityReasonCode.coldDormant,
      staleness: staleness,
    );
  }

  static RoomVisibilityTier tierFor(
    RoomModel room, {
    DateTime? now,
    RoomVisibilityWindows windows = RoomVisibilityWindows.defaults,
  }) {
    return evaluate(room, now: now, windows: windows).tier;
  }

  static bool isVisible(
    RoomModel room, {
    DateTime? now,
    RoomVisibilityWindows windows = RoomVisibilityWindows.defaults,
  }) {
    return evaluate(room, now: now, windows: windows).isVisible;
  }

  static int tierPriority(RoomVisibilityTier tier) {
    switch (tier) {
      case RoomVisibilityTier.discoverable:
        return 0;
      case RoomVisibilityTier.warm:
        return 1;
      case RoomVisibilityTier.cold:
        return 2;
      case RoomVisibilityTier.invalid:
        return 3;
    }
  }

  static void logDecision(RoomModel room, RoomVisibilityResult decision) {
    final stalenessMs = decision.staleness?.inMilliseconds;
    Logger.info(
      'ROOM_VISIBILITY_DECISION roomId=${room.id} tier=${decision.tierLabel} reasonCode=${decision.reasonLabel} stalenessMs=${stalenessMs ?? -1}',
    );
  }
}
