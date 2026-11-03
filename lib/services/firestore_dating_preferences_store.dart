import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/speed_dating/models/dating_preferences.dart';
import 'dating_preferences_store.dart';

/// Stores dating filters in the owner-only `users/{uid}/private/dating` doc.
class FirestoreDatingPreferencesStore implements DatingPreferencesStore {
  FirestoreDatingPreferencesStore(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('private')
        .doc('dating');
  }

  @override
  Future<DatingPreferences> load(String userId) async {
    final snapshot = await _doc(userId).get();
    return DatingPreferences.fromFirestore(snapshot.data());
  }

  @override
  Future<void> save(String userId, DatingPreferences preferences) {
    return _doc(userId).set({
      ...preferences.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> clear(String userId) => _doc(userId).delete();
}
