import 'package:cloud_firestore/cloud_firestore.dart';

// Username uniqueness validator
class UsernameValidator {
  Future<bool> isUnique(String username) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }
}
