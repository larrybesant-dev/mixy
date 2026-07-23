import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/discovery_stream_service.dart';
import '../../../services/moderation_service.dart';
import '../models/speed_dating_models.dart';

/// Persistent discovery service — handles infinite swipe discovery, not time-limited.
/// Unlike Speed Dating (90-second sessions), this allows users to swipe continuously.
class PersistentDiscoveryService {
  PersistentDiscoveryService({
    required FirebaseFirestore firestore,
    ModerationService? moderationService,
    DiscoveryStreamService? streamService,
  })  : _firestore = firestore,
        _moderationService =
            moderationService ?? ModerationService(firestore: firestore),
        _streamService =
            streamService ?? DiscoveryStreamService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final ModerationService _moderationService;
  final DiscoveryStreamService _streamService;

  /// Get all available candidates for discovery, excluding:
  /// - Current user
  /// - Blocked users
  /// - Users already swiped on (in current session)
  Stream<List<SpeedDateCandidate>> candidatesStream({
    required String currentUserId,
    required Set<String> alreadySwiped,
  }) {
    return Stream.periodic(const Duration(seconds: 10))
        .startWith(0)
        .asyncMap((_) async {
          final snapshot = await _streamService.fetchPersistentCandidates(
            limit: 200,
          );
          final blockedIds = await _moderationService.getExcludedUserIds(
            currentUserId,
          );
          return snapshot.docs
              .where((doc) => doc.id != currentUserId)
              .where((doc) => !blockedIds.contains(doc.id))
              .where((doc) => !alreadySwiped.contains(doc.id))
              .map(SpeedDateCandidate.fromDoc)
              .where((candidate) => candidate.username.trim().isNotEmpty)
              .toList(growable: false);
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
    final swipeDoc = _streamService.discoverySwipeRef(userId, candidateId);

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
      final otherUserSwipe = await _streamService.getDiscoverySwipe(
        candidateId,
        userId,
      );

      if (otherUserSwipe.exists && otherUserSwipe.get('isLike') == true) {
        // Mutual match! Create match record
        final matchId = _generateMatchId(userId, candidateId);
        final matchDoc = _streamService.persistentMatchRef(matchId);

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
    return _streamService
        .watchPersistentMatches(currentUserId, limit: 200)
        .map(
          (snapshot) => snapshot.docs
              .map(SpeedDatingMatch.fromDoc)
              .toList(),
        );
  }

  /// Get user's swipe history (likes only)
  Stream<Set<String>> userSwipesStream(String userId) {
    return Stream.periodic(const Duration(seconds: 10))
      .startWith(0)
      .asyncMap((_) async {
        final snapshot = await _streamService.fetchUserDiscoverySwipes(
          userId,
          limit: 500,
        );
        return snapshot.docs
          .where((doc) => doc.get('isLike') == true)
          .map((doc) => doc.id)
          .toSet();
      });
  }

  /// Generate consistent match ID from two user IDs
  String _generateMatchId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}

extension _StreamStartWith<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
