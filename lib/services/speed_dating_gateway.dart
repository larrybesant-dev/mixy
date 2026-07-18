import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/firebase_providers.dart';

final speedDatingGatewayProvider = Provider<SpeedDatingGateway>((ref) {
  return SpeedDatingGateway(ref.watch(firestoreProvider));
});

class SpeedDatingGateway {
  SpeedDatingGateway(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> speedDatingActionRef(String actionId) {
    return _firestore.collection('speed_dating_actions').doc(actionId);
  }

  DocumentReference<Map<String, dynamic>> speedDatingMatchRef(String matchId) {
    return _firestore.collection('speed_dating_matches').doc(matchId);
  }

  DocumentReference<Map<String, dynamic>> notificationRef() {
    return _firestore.collection('notifications').doc();
  }

  DocumentReference<Map<String, dynamic>> newRoomRef() {
    return _firestore.collection('rooms').doc();
  }

  Future<T> runTransaction<T>(TransactionHandler<T> transactionHandler) {
    return _firestore.runTransaction(transactionHandler);
  }
}
