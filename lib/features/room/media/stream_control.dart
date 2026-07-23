import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/rtc_room_service.dart';
import '../controllers/live_room_media_controller.dart';
import '../providers/rtc_service_provider.dart';
import 'room_media_tier.dart';
import 'participant_media_state.dart';

/// Wires media tier decisions into the live RTC service.
///
/// On each rebalance tick, call [applyTiers] with the full sorted state list.
/// This class:
///   1. Calls [RtcRoomService.setRemoteVideoSubscription] for any uid whose
///      subscription state changed.
///   2. Updates [LiveRoomMediaController.updateRequestedRemoteQualities] so
///      the existing controller state stays consistent.
///
/// The [uidForUserId] map bridges Firestore userId ↔ RTC integer uid.
/// For Agora: populate from the `onUserJoined` callback.
/// For WebRTC: [RtcRoomService.userIdForUid] provides the reverse lookup.
class StreamControl {
  StreamControl({required this.roomId, required this.ref});

  final String roomId;
  final Ref ref;

  /// userId → RTC uid mapping.  Caller must keep this updated on join/leave.
  final Map<String, int> uidForUserId = {};

  // Track last applied tier per userId so we only call SDK on changes.
  final Map<String, MediaTier> _appliedTiers = {};

  // ── Public entry point ────────────────────────────────────────────────────

  /// Apply updated tiers to the live RTC service.  Safe to call every tick.
  void applyTiers(List<ParticipantMediaState> states) {
    final service = ref.read(rtcServiceProvider(roomId));
    if (service == null) return; // RTC not yet connected

    final highQuality = <int>{};
    final lowQuality = <int>{};

    for (final participant in states) {
      final uid = _resolveUid(service, participant.userId);
      if (uid == null) continue;

      final newTier = participant.tier;
      final prevTier = _appliedTiers[participant.userId];

      if (prevTier == newTier) {
        // No change — still bucket into quality sets for controller sync.
        _bucketUid(uid, newTier, highQuality, lowQuality);
        continue;
      }

      _applyTierToService(service, participant.userId, uid, newTier);
      _appliedTiers[participant.userId] = newTier;
      _bucketUid(uid, newTier, highQuality, lowQuality);
    }

    // Keep LiveRoomMediaController in sync so existing UI consumers are consistent.
    ref
        .read(liveRoomMediaControllerProvider(roomId).notifier)
        .updateRequestedRemoteQualities(
          highQualityUids: highQuality,
          lowQualityUids: lowQuality,
        );
  }

  /// Register a user's RTC uid on join.
  void registerUid(String userId, int uid) {
    uidForUserId[userId] = uid;
  }

  /// Remove a user's mapping on leave.
  void unregisterUid(String userId) {
    uidForUserId.remove(userId);
    _appliedTiers.remove(userId);
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  int? _resolveUid(RtcRoomService service, String userId) {
    // WebRTC: service has an explicit uid→userId map; reverse it.
    // Agora: caller must have populated uidForUserId.
    final fromService = service.userIdForUid(0); // probe availability
    if (fromService != null) {
      // WebRTC path — scan remoteUids for a matching userId.
      for (final uid in service.remoteUids) {
        if (service.userIdForUid(uid) == userId) return uid;
      }
      return null;
    }
    return uidForUserId[userId];
  }

  void _applyTierToService(
    RtcRoomService service,
    String userId,
    int uid,
    MediaTier tier,
  ) {
    switch (tier) {
      case MediaTier.fullVideo:
        service
            .setRemoteVideoSubscription(uid, subscribe: true, highQuality: true)
            .then(
              (_) {},
              onError: (Object e) {
                developer.log(
                  'StreamControl: fullVideo failed uid=$uid userId=$userId',
                  name: 'StreamControl',
                  error: e,
                );
              },
            );
      case MediaTier.lowVideo:
        service
            .setRemoteVideoSubscription(
              uid,
              subscribe: true,
              highQuality: false,
            )
            .then(
              (_) {},
              onError: (Object e) {
                developer.log(
                  'StreamControl: lowVideo failed uid=$uid userId=$userId',
                  name: 'StreamControl',
                  error: e,
                );
              },
            );
      case MediaTier.audioOnly:
        service
            .setRemoteVideoSubscription(uid, subscribe: false)
            .then(
              (_) {},
              onError: (Object e) {
                developer.log(
                  'StreamControl: audioOnly failed uid=$uid userId=$userId',
                  name: 'StreamControl',
                  error: e,
                );
              },
            );
    }
  }

  void _bucketUid(int uid, MediaTier tier, Set<int> high, Set<int> low) {
    if (tier == MediaTier.fullVideo) {
      high.add(uid);
    } else if (tier == MediaTier.lowVideo) {
      low.add(uid);
    }
  }
}




