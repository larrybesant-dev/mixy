// Room & Video Participant Provider - Manages active video rooms and participants

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_models.dart';

/// Active room notifier
class ActiveRoomIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setRoomId(String? roomId) => state = roomId;
  void clearRoom() => state = null;
}

final activeRoomIdProvider = NotifierProvider<ActiveRoomIdNotifier, String?>(
  () => ActiveRoomIdNotifier(),
);

/// Mock participants generator
List<VideoParticipant> _generateMockParticipants(String roomId) {
  return [
    VideoParticipant(
      userId: 'user1',
      userName: 'Alex Johnson',
      avatarUrl: 'https://i.pravatar.cc/150?u=alex',
      isAudioEnabled: true,
      isVideoEnabled: true,
      isScreenSharing: false,
      joinedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      cameraApprovalStatus: 'approved',
    ),
    VideoParticipant(
      userId: 'user2',
      userName: 'Sarah Chen',
      avatarUrl: 'https://i.pravatar.cc/150?u=sarah',
      isAudioEnabled: true,
      isVideoEnabled: true,
      isScreenSharing: false,
      joinedAt: DateTime.now().subtract(const Duration(minutes: 3)),
      cameraApprovalStatus: 'approved',
    ),
    VideoParticipant(
      userId: 'user3',
      userName: 'Jordan Taylor',
      avatarUrl: 'https://i.pravatar.cc/150?u=jordan',
      isAudioEnabled: false,
      isVideoEnabled: true,
      isScreenSharing: false,
      joinedAt: DateTime.now().subtract(const Duration(minutes: 1)),
      cameraApprovalStatus: 'approved',
    ),
  ];
}

/// Participants notifier for active room
class ParticipantsNotifier extends Notifier<List<VideoParticipant>> {
  @override
  List<VideoParticipant> build() {
    final roomId = ref.watch(activeRoomIdProvider);
    return roomId != null ? _generateMockParticipants(roomId) : [];
  }

  /// Add participant
  void addParticipant(VideoParticipant participant) {
    if (!state.any((p) => p.userId == participant.userId)) {
      state = [...state, participant];
    }
  }

  /// Remove participant
  void removeParticipant(String userId) {
    state = state.where((p) => p.userId != userId).toList();
  }

  /// Toggle audio
  void toggleAudio(String userId, bool enabled) {
    state = state.map((participant) {
      if (participant.userId == userId) {
        return participant.copyWith(isAudioEnabled: enabled);
      }
      return participant;
    }).toList();
  }

  /// Toggle video
  void toggleVideo(String userId, bool enabled) {
    state = state.map((participant) {
      if (participant.userId == userId) {
        return participant.copyWith(isVideoEnabled: enabled);
      }
      return participant;
    }).toList();
  }

  /// Toggle screen share
  void toggleScreenShare(String userId, bool enabled) {
    state = state.map((participant) {
      if (participant.userId == userId) {
        return participant.copyWith(isScreenSharing: enabled);
      }
      return participant;
    }).toList();
  }

  /// Update camera approval status
  void updateCameraApprovalStatus(String userId, String status) {
    state = state.map((participant) {
      if (participant.userId == userId) {
        return participant.copyWith(cameraApprovalStatus: status);
      }
      return participant;
    }).toList();
  }

  /// Clear all (when leaving room)
  void clearAll() {
    state = [];
  }
}

/// Participants provider
final participantsProvider =
    NotifierProvider<ParticipantsNotifier, List<VideoParticipant>>(
  () => ParticipantsNotifier(),
);

/// Participants with video enabled
final videoParticipantsProvider = Provider<List<VideoParticipant>>((ref) {
  final participants = ref.watch(participantsProvider);
  return participants
      .where((p) => p.isVideoEnabled && p.cameraApprovalStatus == 'approved')
      .toList();
});

/// Participants count
final participantsCountProvider = Provider<int>((ref) {
  return ref.watch(participantsProvider).length;
});

/// Audio enabled participants
final audioParticipantsProvider = Provider<List<VideoParticipant>>((ref) {
  final participants = ref.watch(participantsProvider);
  return participants.where((p) => p.isAudioEnabled).toList();
});

/// Screen sharing participant
final screenShareParticipantProvider = Provider<VideoParticipant?>((ref) {
  final participants = ref.watch(participantsProvider);
  try {
    return participants.firstWhere((p) => p.isScreenSharing);
  } catch (e) {
    return null;
  }
});
