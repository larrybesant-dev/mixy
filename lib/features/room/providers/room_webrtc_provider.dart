import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/rtc_room_service.dart';
import '../../../services/connection_recovery_handler.dart';
import '../controllers/webrtc_controller.dart';
import '../../auth/controllers/auth_controller.dart';

/// Represents the state of WebRTC for a single room
class RoomWebRTCState {
  final String roomId;
  final String userId;
  final bool isConnected;
  final List<int> remoteUserUids;
  final bool isLocalVideoCapturing;
  final bool isLocalAudioMuted;
  final RtcConnectionState connectionState;
  final int reconnectAttemptCount;
  final RtcRoomService? service;
  final String? error;

  RoomWebRTCState({
    required this.roomId,
    required this.userId,
    this.isConnected = false,
    this.remoteUserUids = const [],
    this.isLocalVideoCapturing = false,
    this.isLocalAudioMuted = true,
    this.connectionState = RtcConnectionState.idle,
    this.reconnectAttemptCount = 0,
    this.service,
    this.error,
  });

  RoomWebRTCState copyWith({
    String? roomId,
    String? userId,
    bool? isConnected,
    List<int>? remoteUserUids,
    bool? isLocalVideoCapturing,
    bool? isLocalAudioMuted,
    RtcConnectionState? connectionState,
    int? reconnectAttemptCount,
    RtcRoomService? service,
    String? error,
  }) {
    return RoomWebRTCState(
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      isConnected: isConnected ?? this.isConnected,
      remoteUserUids: remoteUserUids ?? this.remoteUserUids,
      isLocalVideoCapturing: isLocalVideoCapturing ?? this.isLocalVideoCapturing,
      isLocalAudioMuted: isLocalAudioMuted ?? this.isLocalAudioMuted,
      connectionState: connectionState ?? this.connectionState,
      reconnectAttemptCount: reconnectAttemptCount ?? this.reconnectAttemptCount,
      service: service ?? this.service,
      error: error ?? this.error,
    );
  }
}

/// Family-based provider: Creates and manages WebRTC service for a specific room
/// Usage: ref.watch(roomWebRTCProvider(roomId))
final roomWebRTCProvider = FutureProvider.family<RoomWebRTCState, String>((ref, roomId) async {
  final authState = ref.watch(authControllerProvider);
  final webrtcController = ref.watch(webrtcControllerProvider);

  final userId = authState.uid ?? 'anonymous';

  try {
    // Create transport layer (WebRTC service) for this room
    final transport = await webrtcController.createTransport(userId: userId);

    return RoomWebRTCState(
      roomId: roomId,
      userId: userId,
      service: transport,
      isConnected: false,
    );
  } catch (e) {
    return RoomWebRTCState(
      roomId: roomId,
      userId: userId,
      error: e.toString(),
    );
  }
});

/// StateNotifier for managing active room WebRTC session
class RoomWebRTCNotifier extends StateNotifier<RoomWebRTCState?> {
  final Ref ref;
  final String roomId;

  RoomWebRTCNotifier(this.ref, this.roomId) : super(null) {
    _initialize();
  }

  Future<void> _initialize() async {
    final webrtcData = await ref.read(roomWebRTCProvider(roomId).future);
    if (webrtcData.error == null && webrtcData.service != null) {
      state = webrtcData;

      // Set up callbacks
      _setupCallbacks(webrtcData.service!);

      // Initialize production networking (fetch TURN credentials)
      // Note: WebRtcRoomService initializes TURN credentials internally
    } else {
      state = webrtcData;
    }
  }

  void _setupCallbacks(RtcRoomService service) {
    service.onLocalVideoCaptureChanged = () {
      state = state?.copyWith(isLocalVideoCapturing: service.isLocalVideoCapturing);
    };

    service.onRemoteUserJoined = () {
      state = state?.copyWith(remoteUserUids: service.remoteUids);
    };

    service.onRemoteUserLeft = () {
      state = state?.copyWith(remoteUserUids: service.remoteUids);
    };

    service.onConnectionLost = () {
      state = state?.copyWith(isConnected: false);
    };

    /// Wire connection recovery state changes so UI can observe recovery progress
    service.onConnectionStateChanged = (newState) {
      state = state?.copyWith(
        connectionState: newState,
        reconnectAttemptCount: service.reconnectAttemptCount,
        // Auto-transition isConnected based on final state
        isConnected: newState == RtcConnectionState.connected,
      );
    };
  }

  Future<void> joinAsAudience() async {
    if (state?.service == null) return;

    try {
      final service = state!.service!;

      // Enable video/audio
      await service.enableVideo(true, publishMicrophoneTrack: true);
      await service.mute(false);

      state = state?.copyWith(
        isConnected: true,
        isLocalVideoCapturing: service.isLocalVideoCapturing,
        isLocalAudioMuted: false,
      );
    } catch (e) {
      state = state?.copyWith(error: 'Failed to join: $e');
    }
  }

  Future<void> toggleVideo(bool enabled) async {
    if (state?.service == null) return;

    try {
      await state!.service!.enableVideo(enabled);
      state = state?.copyWith(isLocalVideoCapturing: enabled);
    } catch (e) {
      state = state?.copyWith(error: 'Failed to toggle video: $e');
    }
  }

  Future<void> toggleAudio(bool enabled) async {
    if (state?.service == null) return;

    try {
      await state!.service!.mute(!enabled);
      state = state?.copyWith(isLocalAudioMuted: !enabled);
    } catch (e) {
      state = state?.copyWith(error: 'Failed to toggle audio: $e');
    }
  }

  Future<void> toggleSystemAudioSharing(bool enabled) async {
    if (state?.service == null) return;

    try {
      await state!.service!.shareSystemAudio(enabled);
      // No state change needed - the UI watches isSharingSystemAudio on the service
    } catch (e) {
      state = state?.copyWith(error: 'Failed to toggle system audio: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (state?.service == null) return;

    try {
      await state!.service!.dispose();
      state = null;
    } catch (e) {
      state = state?.copyWith(error: 'Failed to disconnect: $e');
    }
  }
}

/// StateNotifier provider for managing active WebRTC session
final activeRoomWebRTCProvider = StateNotifierProvider.autoDispose.family<
    RoomWebRTCNotifier,
    RoomWebRTCState?,
    String>((ref, roomId) {
  return RoomWebRTCNotifier(ref, roomId);
});
