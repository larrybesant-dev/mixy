import 'package:cloud_firestore/cloud_firestore.dart';

class TopEightStreamService {
  TopEightStreamService({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTopFriends(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('top_friends')
        .orderBy('slotIndex')
        .limit(8)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchTopEightDoc(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }
}
