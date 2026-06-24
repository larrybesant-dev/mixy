/// Agora Room Controller
///
/// High-level orchestration of:
/// - Join flow state machine (JoinFlowController)
/// - Agora SDK operations (AgoraService)
/// - Firestore presence sync (RoomFirestoreService)
/// - Participant list management
/// - Energy level calculation
///
/// Reference: DESIGN_BIBLE.md Section G (Complete Integration)
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import './join_flow_controller.dart';
import '../../../shared/models/participant.dart';
import '../../../services/agora/agora_service.dart';
import '../../../services/room/room_firestore_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/agora_provider.dart';

/// Exception thrown when room operations fail
class RoomControllerException implements Exception {
  final String message;
  final Object? originalError;

  RoomControllerException(this.message, [this.originalError]);

  @override
  String toString() => 'RoomControllerException: $message';
}

/// Immutable state for the Agora room
class AgoraRoomState {
  final List<Participant> participants;
  final double energy;
  final bool isInRoom;
  final bool isMicMuted;
  final bool isVideoMuted;
  final String hostId;

  const AgoraRoomState({
    this.participants = const [],
    this.energy = 0.0,
    this.isInRoom = false,
    this.isMicMuted = false,
    this.isVideoMuted = false,
    this.hostId = '',
  });

  AgoraRoomState copyWith({
    List<Participant>? participants,
    double? energy,
    bool? isInRoom,
    bool? isMicMuted,
    bool? isVideoMuted,
    String? hostId,
  }) {
    return AgoraRoomState(
      participants: participants ?? this.participants,
      energy: energy ?? this.energy,
      isInRoom: isInRoom ?? this.isInRoom,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
      hostId: hostId ?? this.hostId,
    );
  }
}

/// Riverpod provider for RoomFirestoreService singleton
final roomFirestoreServiceProvider = Provider<RoomFirestoreService>((ref) {
  return RoomFirestoreService();
});

/// Riverpod notifier managing Agora room state
class AgoraRoomNotifier extends Notifier<AgoraRoomState> {
  late final AgoraService _agora;
  late final RoomFirestoreService _firestore;
  String _roomId = '';
  String _userId = '';
  String _userName = '';
  StreamSubscription? _participantsSubscription;

  @override
  AgoraRoomState build() {
    _agora = ref.watch(agoraServiceProvider);
    _firestore = ref.read(roomFirestoreServiceProvider);
    ref.onDispose(_cleanup);
    return const AgoraRoomState();
  }

  void _cleanup() {
    _participantsSubscription?.cancel();
    _leaveRoomSilent();
  }

  /// Set room context — must be called before joinRoom()
  void setRoomContext({
    required String roomId,
    required String userId,
    required String userName,
    String hostId = '',
  }) {
    _roomId = roomId;
    _userId = userId;
    _userName = userName;
    state = state.copyWith(hostId: hostId);
    _participantsSubscription?.cancel();
    _initializeListeners();
  }

  void _initializeListeners() {
    if (_roomId.isEmpty) return;
    _participantsSubscription = _firestore.participantsStream(_roomId).listen(
      (participants) {
        final energy = _calculateEnergy(participants);
        state = state.copyWith(participants: participants, energy: energy);
        if (kDebugMode) {
          print(
              '[RoomNotifier] Participants: ${participants.length}, Energy: ${energy.toStringAsFixed(1)}');
        }
      },
      onError: (e) {
        if (kDebugMode) print('[RoomNotifier] Participant stream error: $e');
      },
    );
  }

  double _calculateEnergy(List<Participant> participants) {
    if (participants.isEmpty) return 0.0;
    final speakingCount = participants.where((p) => p.isSpeaking).length;
    final totalCount = participants.length;
    return ((speakingCount / totalCount) * 5.0 + (totalCount * 0.5))
        .clamp(0.0, 10.0);
  }

  String getEnergyLabel() {
    final e = state.energy;
    if (e < 2) return 'Calm';
    if (e < 5) return 'Active';
    return 'Buzzing';
  }

  Future<void> joinRoom({required String agoraToken}) async {
    if (state.isInRoom) return;
    try {
      await ref.read(joinFlowProvider.notifier).startJoinFlow();
      if (!_agora.isInitialized) await _agora.initialize();
      await _agora.joinChannel(
          token: agoraToken, channelId: _roomId, uid: _userId);
      final selfParticipant = Participant(
          uid: _userId, name: _userName, isSpeaking: false, isPresent: true);
      await _firestore.updateParticipant(_roomId, selfParticipant);
      state = state.copyWith(isInRoom: true);
      if (kDebugMode) {
        print('[RoomNotifier] Joined room: $_roomId as $_userName');
      }
    } catch (e) {
      ref.read(joinFlowProvider.notifier).setError(e.toString());
      if (kDebugMode) print('[RoomNotifier] Join failed: $e');
      throw RoomControllerException('Failed to join room', e);
    }
  }

  Future<void> leaveRoom() async {
    if (!state.isInRoom) return;
    try {
      await _agora.leaveChannel();
      await _firestore.removeParticipant(_roomId, _userId);
      state = state.copyWith(isInRoom: false);
      ref.read(joinFlowProvider.notifier).reset();
      if (kDebugMode) print('[RoomNotifier] Left room: $_roomId');
    } catch (e) {
      if (kDebugMode) print('[RoomNotifier] Leave failed: $e');
    }
  }

  Future<void> toggleMicrophone() async {
    try {
      final newMicMuted = !state.isMicMuted;
      await _agora.setMicrophoneMuted(newMicMuted);
      state = state.copyWith(isMicMuted: newMicMuted);
      if (kDebugMode) {
        print('[RoomNotifier] Mic: ${newMicMuted ? "MUTED" : "ACTIVE"}');
      }
    } catch (e) {
      if (kDebugMode) print('[RoomNotifier] Mic toggle failed: $e');
      throw RoomControllerException('Failed to toggle microphone', e);
    }
  }

  Future<void> toggleVideo() async {
    try {
      final newVideoMuted = !state.isVideoMuted;
      await _agora.setVideoCameraMuted(newVideoMuted);
      state = state.copyWith(isVideoMuted: newVideoMuted);
      if (kDebugMode) {
        print('[RoomNotifier] Video: ${newVideoMuted ? "DISABLED" : "ACTIVE"}');
      }
    } catch (e) {
      if (kDebugMode) print('[RoomNotifier] Video toggle failed: $e');
      throw RoomControllerException('Failed to toggle video', e);
    }
  }

  Future<void> setSpeaking(bool speaking) async {
    try {
      final self = state.participants.firstWhere(
        (p) => p.uid == _userId,
        orElse: () =>
            Participant(uid: _userId, name: _userName, isSpeaking: speaking),
      );
      if (self.isSpeaking != speaking) {
        await _firestore.updateParticipant(
            _roomId, self.copyWith(isSpeaking: speaking));
      }
    } catch (e) {
      if (kDebugMode) print('[RoomNotifier] Set speaking failed: $e');
    }
  }

  Future<void> _leaveRoomSilent() async {
    try {
      await leaveRoom();
    } catch (e) {
      if (kDebugMode) print('[RoomNotifier] Cleanup error: $e');
    }
  }
}

/// Provider for Agora room state
final agoraRoomProvider = NotifierProvider<AgoraRoomNotifier, AgoraRoomState>(
  AgoraRoomNotifier.new,
);
