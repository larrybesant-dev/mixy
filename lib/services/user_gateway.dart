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

  Future<DocumentSnapshot<Map<String, dynamic>>> getUser(String userId) {
    return userRef(userId).get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getPublicUsers({
    int limit = 40,
  }) {
    return usersCollection()
        .where('isPrivate', isEqualTo: false)
        .limit(limit)
        .get(const GetOptions(source: Source.server));
  }
}