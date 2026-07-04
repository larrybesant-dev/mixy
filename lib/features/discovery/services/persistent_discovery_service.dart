import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../services/moderation_service.dart';
import '../models/speed_dating_models.dart';

/// Persistent discovery service — handles infinite swipe discovery, not time-limited.
/// Unlike Speed Dating (90-second sessions), this allows users to swipe continuously.
class PersistentDiscoveryService {
  PersistentDiscoveryService({
    required FirebaseFirestore firestore,
    ModerationService? moderationService,
    FirebaseFunctions? functions,
  })  : _firestore = firestore,
        _moderationService =
            moderationService ?? ModerationService(firestore: firestore),
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final ModerationService _moderationService;
  final FirebaseFunctions _functions;

  /// Get all available candidates for discovery, excluding:
  /// - Current user
  /// - Blocked users
  /// - Users already swiped on (in current session)
  Stream<List<SpeedDateCandidate>> candidatesStream({
    required String currentUserId,
    required Set<String> alreadySwiped,
  }) {
    return _firestore
        .collection('users')
        .where('username', isGreaterThan: '')
        .orderBy('username')
        .snapshots()
        .asyncMap((snapshot) async {
          final blockedIds = await _moderationService.getExcludedUserIds(
            currentUserId,
          );
          return snapshot.docs
              .where((doc) => doc.id != currentUserId)
              .where((doc) => !blockedIds.contains(doc.id))
              .where((doc) => !alreadySwiped.contains(doc.id))
              .map(SpeedDateCandidate.fromDoc)
              .where((candidate) => candidate.username.trim().isNotEmpty)
              .toList();
        });
  }

  /// Record a like/pass swipe for persistent discovery
  /// Stores in /users/{userId}/discovery/{candidateId}
  Future<void> recordSwipe({
    required String userId,
    required String candidateId,
    required bool isLike,
  }) async {
    final batch = _firestore.batch();
    final swipeDoc = _firestore
        .collection('users')
        .doc(userId)
        .collection('discovery')
        .doc(candidateId);

    batch.set(
      swipeDoc,
      {
        'candidateId': candidateId,
        'isLike': isLike,
        'timestamp': FieldValue.serverTimestamp(),
      },
    );

    // If this is a like, check if other user also liked back (mutual match)
    if (isLike) {
      final otherUserSwipe = await _firestore
          .collection('users')
          .doc(candidateId)
          .collection('discovery')
          .doc(userId)
          .get();

      if (otherUserSwipe.exists && otherUserSwipe.get('isLike') == true) {
        // Mutual match! Create match record
        final matchId = _generateMatchId(userId, candidateId);
        final matchDoc = _firestore.collection('matches').doc(matchId);

        batch.set(
          matchDoc,
          {
            'participantIds': [userId, candidateId],
            'createdAt': FieldValue.serverTimestamp(),
            'source': 'persistent_discovery',
          },
          SetOptions(merge: true),
        );
      }
    }

    await batch.commit();
  }

  /// Get all mutual matches from persistent discovery
  Stream<List<SpeedDatingMatch>> matchesStream(String currentUserId) {
    return _firestore
        .collection('matches')
        .where('participantIds', arrayContains: currentUserId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SpeedDatingMatch.fromDoc)
              .toList(),
        );
  }

  /// Get user's swipe history (likes only)
  Stream<Set<String>> userSwipesStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('discovery')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((doc) => doc.get('isLike') == true)
              .map((doc) => doc.id)
              .toSet(),
        );
  }

  /// Generate consistent match ID from two user IDs
  String _generateMatchId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}
