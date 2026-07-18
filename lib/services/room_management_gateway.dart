import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/firebase_providers.dart';
import '../models/room_model.dart';

final roomManagementGatewayProvider = Provider<RoomManagementGateway>((ref) {
  return RoomManagementGateway(ref.watch(firestoreProvider));
});

class RoomManagementGateway {
  RoomManagementGateway(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _roomRef(String roomId) {
    return _firestore.collection('rooms').doc(roomId);
  }

  Future<RoomModel?> getRoomModel(String roomId) async {
    final roomDoc = await _roomRef(roomId).get();
    if (!roomDoc.exists) {
      return null;
    }
    final data = roomDoc.data();
    if (data == null) {
      return null;
    }
    return RoomModel.fromJson(data, roomId);
  }

  Future<void> updateRoom(String roomId, Map<String, dynamic> updates) {
    return _roomRef(roomId).update(updates);
  }

  Future<void> addRoomPhoto({
    required String roomId,
    required String photoUrl,
    String? caption,
    required String uploadedBy,
  }) {
    return _roomRef(roomId).collection('photos').add({
      'url': photoUrl,
      'caption': caption,
      'uploadedBy': uploadedBy,
      'uploadedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeRoomPhoto({
    required String roomId,
    required String photoId,
  }) {
    return _roomRef(roomId).collection('photos').doc(photoId).delete();
  }

  Future<void> removeParticipant({
    required String roomId,
    required String userId,
  }) {
    return _roomRef(roomId).collection('participants').doc(userId).delete();
  }
}
