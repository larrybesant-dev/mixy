import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/streams/stream_lifecycle_manager.dart';
import '../../../services/agora_service.dart';
import '../../../services/rtc_room_service.dart';
import '../../../services/webrtc_room_service_shim.dart';
import '../providers/room_firestore_provider.dart';

class WebRtcController {
  WebRtcController(this._firestore, this._streamManager);

  final FirebaseFirestore _firestore;
  final StreamLifecycleManager _streamManager;

  Future<RtcRoomService> createTransport({
    required String userId,
    List<Map<String, dynamic>>? iceServers,
  }) async {
    if (!kIsWeb) {
      return AgoraService();
    }

    return WebRtcRoomService(
      firestore: _firestore,
      localUserId: userId,
      streamLifecycleManager: _streamManager,
      iceServers: iceServers,
    );
  }
}

final webrtcControllerProvider = Provider<WebRtcController>((ref) {
  return WebRtcController(
    ref.watch(roomFirestoreProvider),
    ref.watch(streamLifecycleManagerProvider),
  );
});



