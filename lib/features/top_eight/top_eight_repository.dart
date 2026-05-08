import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/firebase_providers.dart';
import '../../models/user_model.dart';

final topEightRepositoryProvider = Provider((ref) {
  return TopEightRepository(ref.watch(firestoreProvider));
});

class TopEightRepository {
  final FirebaseFirestore _firestore;

  TopEightRepository(this._firestore);

  /// Fetches the list of UIDs for a user's Top 8.
  Stream<List<String>> watchTopEightIds(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          if (data == null) return [];
          return List<String>.from(data['topEightIds'] ?? []);
        });
  }

  /// Fetches full [UserModel] objects for a list of IDs.
  Future<List<UserModel>> getUsersFromIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    
    // Firestore 'in' queries are limited to 10 items, which works perfectly for a "Top 8".
    final snapshots = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: ids)
        .get();

    final users = snapshots.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .toList();

    // Re-sort to match the order of IDs provided (since 'whereIn' doesn't guarantee order)
    return ids.map((id) => users.firstWhere((u) => u.id == id)).toList();
  }

  /// Updates the user's Top 8 list.
  Future<void> updateTopEight(String userId, List<String> topEightIds) async {
    await _firestore.collection('users').doc(userId).update({
      'topEightIds': topEightIds,
    });
  }
}
