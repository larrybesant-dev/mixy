import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/room_policy_model.dart';
import 'room_firestore_provider.dart';

class RoomPolicyController {
  RoomPolicyController(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> updatePolicy(String roomId, Map<String, dynamic> values) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('policies')
        .doc('settings')
        .set({
      ...values,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> setMicLimit(String roomId, int limit) {
    return updatePolicy(roomId, {'micLimit': limit});
  }

  Future<void> setMicTimer(String roomId, int? seconds) {
    return updatePolicy(roomId, {'micTimerSeconds': seconds});
  }

  Future<void> setCamLimit(String roomId, int limit) {
    return updatePolicy(roomId, {'camLimit': limit});
  }

  Future<void> setDefaultCamViewPolicy(String roomId, CamViewPolicy policy) {
    return updatePolicy(roomId, {'defaultCamViewPolicy': policy.name});
  }

  Future<void> setVisibility(String roomId, MixVyRoomVisibility visibility) {
    return updatePolicy(roomId, {'visibility': visibility.name});
  }
}

final roomPolicyControllerProvider = Provider<RoomPolicyController>((ref) {
  return RoomPolicyController(ref.watch(roomFirestoreProvider));
});

final roomPolicyProvider =
    StreamProvider.autoDispose.family<RoomPolicyModel, String>((ref, roomId) {
  final firestore = ref.watch(roomFirestoreProvider);
  final roomRef = firestore.collection('rooms').doc(roomId);
  final policyRef = roomRef.collection('policies').doc('settings');

  // Single-document read — .limit(1) not applicable for document snapshots.
  return policyRef.snapshots().map((snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};
    if (data.isEmpty) {
      return RoomPolicyModel(roomId: roomId);
    }

    return RoomPolicyModel.fromJson({...data, 'roomId': roomId});
  });
});
