import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../../../core/telemetry/app_telemetry.dart';
import '../../../services/discovery_stream_service.dart';
import '../../../services/moderation_service.dart';
import '../models/speed_dating_models.dart';

class SpeedDatingService {
  SpeedDatingService({
    required FirebaseFirestore firestore,
    ModerationService? moderationService,
    FirebaseFunctions? functions,
    DiscoveryStreamService? streamService,
  }) : _firestore = firestore,
       _moderationService =
           moderationService ?? ModerationService(firestore: firestore),
       _functions = functions ?? FirebaseFunctions.instance,
       _streamService =
           streamService ?? DiscoveryStreamService(firestore: firestore);

  final FirebaseFirestore _firestore;
  final ModerationService _moderationService;
  final FirebaseFunctions _functions;
  final DiscoveryStreamService _streamService;
  static const Uuid _uuid = Uuid();

  Stream<List<SpeedDateCandidate>> candidatesStream({
    required String currentUserId,
  }) {
    // Query only users who have a non-empty username — avoids a full-collection
    // scan and filters out incomplete accounts server-side. Limit to 40 so the
    // Dart-side block filter still leaves a useful candidate set.
    return _streamService
        .watchSpeedDatingCandidates(limit: 40)
        .asyncMap((snapshot) async {
          final blockedIds = await _moderationService.getExcludedUserIds(
            currentUserId,
          );
          return snapshot.docs
              .where((doc) => doc.id != currentUserId)
              .where((doc) => !blockedIds.contains(doc.id))
              .map(SpeedDateCandidate.fromDoc)
              .where((candidate) => candidate.username.trim().isNotEmpty)
              .toList();
        });
  }

  Stream<List<SpeedDatingMatch>> matchesStream(String currentUserId) {
    return _streamService
        .watchSpeedDatingMatches(currentUserId, limit: 50)
        .map(
          (snapshot) => snapshot.docs.map(SpeedDatingMatch.fromDoc).toList(),
        );
  }

  Future<SpeedDateDecisionResult> submitDecision({
    required String fromUserId,
    required String toUserId,
    required bool liked,
    required int sessionSeconds,
  }) async {
    if (await _moderationService.hasBlockingRelationship(
      fromUserId,
      toUserId,
    )) {
      throw Exception('Cannot interact with a blocked user.');
    }

    final actionId = '${fromUserId}_$toUserId';
    final reciprocalActionId = '${toUserId}_$fromUserId';

    // 1. Record the decision
    await _firestore.collection('speed_dating_actions').doc(actionId).set({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'decision': liked ? 'like' : 'pass',
      'sessionSeconds': sessionSeconds,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!liked) {
      return const SpeedDateDecisionResult(isMatch: false);
    }

    // 2. Atomically check for reciprocal like and create match
    final sorted = [fromUserId, toUserId]..sort();
    final matchId = '${sorted.first}_${sorted.last}';
    final matchRef = _firestore.collection('speed_dating_matches').doc(matchId);

    return await _firestore.runTransaction((txn) async {
      final reciprocalDoc = await txn.get(
        _firestore.collection('speed_dating_actions').doc(reciprocalActionId),
      );
      final reciprocalData = reciprocalDoc.data();
      final reciprocalLiked =
          reciprocalData != null && reciprocalData['decision'] == 'like';

      if (!reciprocalLiked) {
        return const SpeedDateDecisionResult(isMatch: false);
      }

      final matchSnap = await txn.get(matchRef);
      if (matchSnap.exists) {
        // Match already exists, just return it
        return SpeedDateDecisionResult(isMatch: true, matchId: matchId);
      }

      // Create match document
      txn.set(matchRef, {
        'participantIds': sorted,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActionBy': fromUserId,
      });

      // Add notification for the other user
      txn.set(_firestore.collection('notifications').doc(), {
        'userId': toUserId,
        'actorId': fromUserId,
        'type': 'speed_dating_match',
        'content': 'You have a new speed dating match.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      AppTelemetry.logAction(
        domain: 'speed_dating',
        action: 'match_success',
        message: 'A new match was created.',
        userId: fromUserId,
        result: 'success',
        metadata: {'matchId': matchId, 'targetUserId': toUserId},
      );

      return SpeedDateDecisionResult(isMatch: true, matchId: matchId);
    });
  }

  Future<String> startLiveDateRoom({
    required String hostUserId,
    required String targetUserId,
    required String matchId,
    int durationSeconds = 300,
  }) async {
    final matchRef = _firestore.collection('speed_dating_matches').doc(matchId);

    return await _firestore.runTransaction((txn) async {
      final matchSnap = await txn.get(matchRef);
      final data = matchSnap.data();

      // If a room already exists for this match, reuse it instead of creating a duplicate.
      if (data != null && data['latestRoomId'] != null) {
        return data['latestRoomId'] as String;
      }

      final roomRef = _firestore.collection('rooms').doc();
      final expiresAt = DateTime.now().add(Duration(seconds: durationSeconds));

      txn.set(roomRef, {
        'name': 'Speed Date',
        'meta': <String, dynamic>{'title': 'Speed Date'},
        'description': 'Private speed date session',
        'hostId': hostUserId,
        'isLive': true,
        'isAdult': false,
        'isLocked': true,
        'category': 'speed_dating',
        'memberCount': 2,
        'stageUserIds': [hostUserId, targetUserId],
        'audienceUserIds': <String>[],
        'coHosts': <String>[],
        'tags': ['speed_dating', 'private'],
        'expiresAt': Timestamp.fromDate(expiresAt),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      txn.set(matchRef, {
        'latestRoomId': roomRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return roomRef.id;
    });
  }

  String randomSessionId() => _uuid.v4();

  // ── Queue-based matchmaking (server-side) ────────────────────────────────

  /// Enters the server-side matchmaking queue via Cloud Function.
  /// Returns a [SpeedDatingQueueResult] indicating whether a partner was
  /// immediately found and the resulting session details.
  Future<SpeedDatingQueueResult> joinQueue() async {
    final result = await _functions
        .httpsCallable('joinSpeedDatingQueue')
        .call<Map<String, dynamic>>();
    final data = Map<String, dynamic>.from(result.data as Map);
    return SpeedDatingQueueResult(
      matched: data['matched'] as bool? ?? false,
      sessionId: data['sessionId'] as String?,
      partnerId: data['partnerId'] as String?,
    );
  }

  /// Removes the current user from the matchmaking queue.
  Future<void> leaveQueue() async {
    await _functions.httpsCallable('leaveSpeedDatingQueue').call();
  }

  /// Watches the live queue entry for the current user so the UI can react
  /// when the server matches them to a partner.
  Stream<SpeedDatingQueueResult?> watchQueueEntry(String userId) {
    return _streamService
        .watchQueueEntry(userId)
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data();
          if (data == null) return null;
          return SpeedDatingQueueResult(
            matched: data['matched'] as bool? ?? false,
            sessionId: data['sessionId'] as String?,
            partnerId: null,
          );
        });
  }

  /// Watches a specific speed dating session doc (active + expiresAt).
  Stream<Map<String, dynamic>?> watchSession(String sessionId) {
    return _streamService
        .watchSession(sessionId)
        .map((doc) => doc.exists ? doc.data() : null);
  }
}




