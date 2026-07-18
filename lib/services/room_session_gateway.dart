import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/firebase_providers.dart';

final roomSessionGatewayProvider = Provider<RoomSessionGateway>((ref) {
  return RoomSessionGateway(ref.watch(firestoreProvider));
});

class RoomSessionGateway {
  RoomSessionGateway(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> roomRef(String roomId) {
    return _firestore.collection('rooms').doc(roomId);
  }

  DocumentReference<Map<String, dynamic>> participantRef(
    String roomId,
    String userId,
  ) {
    return roomRef(roomId).collection('participants').doc(userId);
  }

  CollectionReference<Map<String, dynamic>> participantsRef(String roomId) {
    return roomRef(roomId).collection('participants');
  }

  DocumentReference<Map<String, dynamic>> memberRef(String roomId, String userId) {
    return roomRef(roomId).collection('members').doc(userId);
  }

  DocumentReference<Map<String, dynamic>> typingRef(String roomId, String userId) {
    return roomRef(roomId).collection('typing').doc(userId);
  }

  DocumentReference<Map<String, dynamic>> userRef(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  DocumentReference<Map<String, dynamic>> verificationRef(String userId) {
    return _firestore.collection('verification').doc(userId);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getRoom(String roomId) {
    return roomRef(roomId).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String userId) {
    return userRef(userId).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getVerification(String userId) {
    return verificationRef(userId).get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getParticipants(String roomId) {
    return participantsRef(roomId).get();
  }

  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler,
  ) {
    return _firestore.runTransaction(transactionHandler);
  }
}
