import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/agora_service.dart';
import '../../../services/rtc_room_service.dart';
import '../../../services/webrtc_room_service_shim.dart';
import '../providers/room_firestore_provider.dart';
import '../../../core/streams/stream_lifecycle_manager.dart';

class WebRtcController {
  WebRtcController(this._firestore, this._ref);

  final FirebaseFirestore _firestore;
  final Ref _ref;

  Future<RtcRoomService> createTransport({
    required String userId,
    List<Map<String, dynamic>>? iceServers,
  }) async {
    if (kIsWeb) {
      return WebRtcRoomService(
        firestore: _firestore,
        localUserId: userId,
        streamLifecycleManager: _ref.read(streamLifecycleManagerProvider),
        iceServers: iceServers,
      );
    }
    return AgoraService();
  }
}

final webrtcControllerProvider = Provider<WebRtcController>((ref) {
  return WebRtcController(ref.watch(roomFirestoreProvider), ref);
});
