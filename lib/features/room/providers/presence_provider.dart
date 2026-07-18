import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/room_participant_model.dart';
import '../controllers/room_state.dart';
import 'participant_providers.dart';

class RoomPresenceModel {
  const RoomPresenceModel({
    required this.userId,
    required this.isOnline,
    required this.lastHeartbeatAt,
    required this.lastSeenAt,
    this.customStatus,
    this.userStatus,
  });

  final String userId;
  final bool isOnline;
  final DateTime? lastHeartbeatAt;
  final DateTime? lastSeenAt;

  /// Optional free-text status/away message set by the user.
  final String? customStatus;

  /// Enum status: 'online' | 'away' | 'dnd' | 'offline'
  final String? userStatus;

  factory RoomPresenceModel.fromMap(String userId, Map<String, dynamic> data) {
    DateTime? toDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    bool toBool(dynamic value) {
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') {
          return true;
        }
      }
      return false;
    }

    return RoomPresenceModel(
      userId: userId,
      isOnline: toBool(data['isOnline']),
      lastHeartbeatAt: toDate(data['lastHeartbeatAt']),
      lastSeenAt: toDate(data['lastSeenAt']),
      customStatus: data['customStatus'] as String?,
      userStatus: data['userStatus'] as String?,
    );
  }
}

const Duration _kRoomPresenceFreshnessWindow = Duration(seconds: 90);

bool _isRoomParticipantActive(
  RoomParticipantModel participant, {
  DateTime? now,
}) {
  final normalizedRole = normalizeRoomRole(participant.role, fallbackRole: '');
  final hasActiveSeat =
      canManageStageRole(normalizedRole) ||
      normalizedRole == roomRoleStage ||
      participant.camOn ||
      participant.micOn;
  if (hasActiveSeat) {
    return true;
  }

  final normalizedStatus = participant.userStatus?.trim().toLowerCase() ?? '';
  if (normalizedStatus == 'offline') {
    return false;
  }

  final currentTime = now ?? DateTime.now();
  return currentTime.difference(participant.lastActiveAt) <=
      _kRoomPresenceFreshnessWindow;
}

final roomPresenceStreamProvider = StreamProvider.autoDispose
    .family<List<RoomPresenceModel>, String>((ref, roomId) {
      return Stream.multi((controller) {
        final subscription = ref.listen(participantsStreamProvider(roomId), (
          _,
          next,
        ) {
          if (controller.isClosed) return;
          next.whenData((participants) {
            final now = DateTime.now();
            controller.add(
              participants
                  .map((participant) {
                    final userId = participant.userId.trim();
                    final participantRoomMatch = _isRoomParticipantActive(
                      participant,
                      now: now,
                    );
                    return RoomPresenceModel(
                      userId: userId,
                      isOnline: participantRoomMatch,
                      lastHeartbeatAt: participant.lastActiveAt,
                      lastSeenAt: participant.lastActiveAt,
                      customStatus: participant.customStatus,
                      userStatus:
                          participant.userStatus ??
                          (participantRoomMatch ? 'online' : 'offline'),
                    );
                  })
                  .where((presence) => presence.userId.isNotEmpty)
                  .toList(growable: false),
            );
          });
        });
        controller.onCancel = subscription.close;
      });
    });

/// Alias for non-canonical consumers to avoid direct `*StreamProvider`
/// identifier references while still deriving from the canonical stream.
final roomPresenceLiveProvider = roomPresenceStreamProvider;




