import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical Firestore stream gateway for discovery and speed-dating domains.
///
/// Feature-layer services should compose these streams instead of opening
/// `.snapshots()` directly, keeping subscription ownership in `lib/services/`.
class DiscoveryStreamService {
  DiscoveryStreamService({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<QuerySnapshot<Map<String, dynamic>>> fetchPersistentCandidates({
    int limit = 200,
  }) {
    return _firestore
        .collection('users')
        .where('username', isGreaterThan: '')
        .orderBy('username')
        .limit(limit)
        .get();
  }

  DocumentReference<Map<String, dynamic>> discoverySwipeRef(
    String ownerUserId,
    String candidateId,
  ) {
    return _firestore
        .collection('users')
        .doc(ownerUserId)
        .collection('discovery')
        .doc(candidateId);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDiscoverySwipe(
    String ownerUserId,
    String candidateId,
  ) {
    return discoverySwipeRef(ownerUserId, candidateId).get();
  }

  DocumentReference<Map<String, dynamic>> persistentMatchRef(String matchId) {
    return _firestore.collection('matches').doc(matchId);
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchUserDiscoverySwipes(
    String userId, {
    int limit = 500,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('discovery')
        .limit(limit)
        .get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDiscoveryPreferencesDoc(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('discoveryPreferences')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchProfileViews(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('profileViews')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSwipeHistory(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('discovery')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSpeedDatingCandidates({
    int limit = 40,
  }) {
    return _firestore
        .collection('users')
        .where('username', isGreaterThan: '')
        .orderBy('username')
        .limit(limit)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSpeedDatingMatches(
    String userId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('speed_dating_matches')
        .where('participantIds', arrayContains: userId)
        .limit(limit)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchQueueEntry(String userId) {
    return _firestore.collection('speed_dating_queue').doc(userId).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchSession(String sessionId) {
    return _firestore
        .collection('speed_dating_sessions')
        .doc(sessionId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPersistentMatches(
    String userId, {
    int limit = 200,
  }) {
    return _firestore
        .collection('matches')
        .where('participantIds', arrayContains: userId)
        .limit(limit)
        .snapshots();
  }
}
