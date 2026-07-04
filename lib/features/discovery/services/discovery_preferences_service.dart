import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/discovery_preferences.dart';

class DiscoveryPreferencesService {
  DiscoveryPreferencesService({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  /// Get user's discovery preferences
  Stream<DiscoveryPreferences> preferencesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('discoveryPreferences')
        .snapshots()
        .map((doc) {
          if (!doc.exists) {
            // Return defaults if not set
            return DiscoveryPreferences(userId: userId);
          }
          return DiscoveryPreferences.fromFirestore(doc);
        });
  }

  /// Save user's discovery preferences
  Future<void> savePreferences(DiscoveryPreferences prefs) async {
    await _firestore
        .collection('users')
        .doc(prefs.userId)
        .collection('settings')
        .doc('discoveryPreferences')
        .set(prefs.toFirestore());
  }

  /// Update just the age range
  Future<void> updateAgeRange(String userId, int minAge, int maxAge) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('discoveryPreferences')
        .update({
          'minAge': minAge,
          'maxAge': maxAge,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .catchError((_) {
          // If document doesn't exist, create it
          return _firestore
              .collection('users')
              .doc(userId)
              .collection('settings')
              .doc('discoveryPreferences')
              .set({
                'userId': userId,
                'minAge': minAge,
                'maxAge': maxAge,
                'interestTags': [],
                'updatedAt': FieldValue.serverTimestamp(),
              });
        });
  }

  /// Update interest tags
  Future<void> updateInterestTags(String userId, List<String> tags) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('discoveryPreferences')
        .update({
          'interestTags': tags,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .catchError((_) {
          return _firestore
              .collection('users')
              .doc(userId)
              .collection('settings')
              .doc('discoveryPreferences')
              .set({
                'userId': userId,
                'minAge': 18,
                'maxAge': 99,
                'interestTags': tags,
                'updatedAt': FieldValue.serverTimestamp(),
              });
        });
  }
}
