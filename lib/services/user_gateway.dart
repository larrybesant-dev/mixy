import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/firebase_providers.dart';

final userGatewayProvider = Provider<UserGateway>((ref) {
  return UserGateway(ref.watch(firestoreProvider));
});

class UserGateway {
  UserGateway(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> usersCollection() {
    return _firestore.collection('users');
  }

  DocumentReference<Map<String, dynamic>> userRef(String userId) {
    return usersCollection().doc(userId);
  }

  DocumentReference<Map<String, dynamic>> userPrivacyRef(String userId) {
    return userRef(userId).collection('privacy').doc('settings');
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String userId) {
    return userRef(userId).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserPrivacySettings(
    String userId,
  ) {
    return userPrivacyRef(userId).get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getPublicUsers({
    int limit = 40,
  }) {
    return usersCollection()
        .where('isPrivate', isEqualTo: false)
        .limit(limit)
        .get(const GetOptions(source: Source.server));
  }
  
  Future<QuerySnapshot<Map<String, dynamic>>> getNewMembers({
    int limit = 12,
  }) {
    return usersCollection()
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
  }
  
  Future<QuerySnapshot<Map<String, dynamic>>> getTrendingUsers({
    int limit = 10,
  }) {
    return usersCollection()
        .orderBy('balance', descending: true)
        .limit(limit)
        .get();
  }
}