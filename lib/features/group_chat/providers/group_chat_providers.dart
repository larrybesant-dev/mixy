import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/services/agora/agora_video_service.dart';
import 'package:mixmingle/shared/providers/all_providers.dart';
import '../models/group_chat_message.dart';
import '../models/group_chat_participant.dart';
import '../models/group_chat_room.dart';
import '../services/group_chat_service.dart';

final groupChatServiceProvider = Provider<GroupChatService>((ref) {
  return GroupChatService();
});

// REMOVED: Separate Agora engine instance for group chat
// Use the shared agoraVideoServiceProvider from all_providers instead
// Creating multiple engine instances causes:
// - createIrisApiEngine errors on web
// - Double channel joins
// - Double camera toggles
// - TypeError crashes

final groupRoomProvider =
    StreamProvider.family<GroupChatRoom?, String>((ref, roomId) {
  return ref.watch(groupChatServiceProvider).watchRoom(roomId);
});

final groupParticipantsProvider =
    StreamProvider.family<List<GroupChatParticipant>, String>((ref, roomId) {
  return ref.watch(groupChatServiceProvider).watchParticipants(roomId);
});

final groupMessagesProvider =
    StreamProvider.family<List<GroupChatMessage>, String>((ref, roomId) {
  return ref.watch(groupChatServiceProvider).watchMessages(roomId);
});

class GroupCallState {
  final bool isInitialized;
  final bool isInChannel;
  final bool isMicMuted;
  final bool isVideoMuted;
  final List<int> remoteUids;

  const GroupCallState({
    required this.isInitialized,
    required this.isInChannel,
    required this.isMicMuted,
    required this.isVideoMuted,
    required this.remoteUids,
  });

  // Initial state factory
  factory GroupCallState.initial() {
    return const GroupCallState(
      isInitialized: false,
      isInChannel: false,
      isMicMuted: true,
      isVideoMuted: true,
      remoteUids: [],
    );
  }

  factory GroupCallState.fromService(AgoraVideoService service) {
    return GroupCallState(
      isInitialized: service.isInitialized,
      isInChannel: service.isInChannel,
      isMicMuted: service.isMicMuted,
      isVideoMuted: service.isVideoMuted,
      remoteUids: List<int>.from(service.remoteUsers),
    );
  }
}

// Group call state management
final groupCallControllerProvider =
    NotifierProvider.autoDispose<GroupCallStateNotifier, GroupCallState>(
  GroupCallStateNotifier.new,
);

class GroupCallStateNotifier extends Notifier<GroupCallState> {
  late final AgoraVideoService _service;

  @override
  GroupCallState build() {
    // Import required: import 'package:mixmingle/shared/providers/all_providers.dart';
    _service = ref.watch(agoraVideoServiceProvider);
    return GroupCallState.fromService(_service);
  }

  Future<void> initializeAndJoin(String roomId) async {
    if (!_service.isInitialized) {
      await _service.initialize();
    }
    await _service.joinRoom(roomId);
    state = GroupCallState.fromService(_service);
  }

  Future<void> leaveRoom() async {
    await _service.leaveRoom();
    state = GroupCallState.fromService(_service);
  }

  Future<void> toggleMic({String? roomId}) async {
    final wasMuted = _service.isMicMuted;
    await _service.toggleMic();
    state = GroupCallState.fromService(_service);
    if (roomId != null) {
      await _syncMediaState(roomId,
          micMuted: _service.isMicMuted, previous: wasMuted);
    }
  }

  Future<void> toggleVideo({String? roomId}) async {
    final wasVideoMuted = _service.isVideoMuted;
    await _service.toggleVideo();
    state = GroupCallState.fromService(_service);
    if (roomId != null) {
      await _syncMediaState(roomId,
          videoMuted: _service.isVideoMuted, previous: wasVideoMuted);
    }
  }

  RtcEngine? get engine => _service.engine;

  Future<void> _syncMediaState(String roomId,
      {bool? micMuted, bool? videoMuted, bool? previous}) async {
    // Avoid Firestore churn on unchanged values
    final changedMic = micMuted != null && micMuted != previous;
    final changedVideo = videoMuted != null && videoMuted != previous;
    if (!changedMic && !changedVideo) return;

    await ref.read(groupChatServiceProvider).updateMediaState(roomId,
        isMuted: micMuted, isCameraOn: videoMuted != true);
  }
}
