import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/firebase_providers.dart';

final presenceGatewayProvider = Provider<PresenceGateway>((ref) {
  return PresenceGateway(ref.watch(firestoreProvider));
});

class PresenceGateway {
  PresenceGateway(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> presenceCollection() {
    return _firestore.collection('presence');
  }

  DocumentReference<Map<String, dynamic>> presenceRef(String userId) {
    return presenceCollection().doc(userId);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchPresence(String userId) {
    return presenceRef(userId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPresenceBatch(
    List<String> userIds,
  ) {
    return presenceCollection()
        .where(FieldPath.documentId, whereIn: userIds)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getPresence(String userId) {
    return presenceRef(userId).get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getPresenceBatch(
    List<String> userIds,
  ) {
    return presenceCollection()
        .where(FieldPath.documentId, whereIn: userIds)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> countOnlinePresence({
    int limit = 500,
  }) {
    return presenceCollection()
        .where('isOnline', isEqualTo: true)
        .limit(limit + 1)
        .get();
  }
}