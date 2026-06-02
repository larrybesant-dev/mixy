import 'package:cloud_firestore/cloud_firestore.dart';

// Username uniqueness validator
class UsernameValidator {
  UsernameValidator({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<bool> isUnique(String username) async {
    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }
}
