import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mixvy/core/utils/app_logger.dart';
import '../models/match_model.dart';

/// Service for managing user matches and likes
class MatchService {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  MatchService(this._db, this._functions);

  /// Generate fresh matches for current user
  /// Calls Cloud Function that scores potential matches
  Future<Map<String, dynamic>> generateMatches() async {
    try {
      final callable = _functions.httpsCallable('generateUserMatches');
      final result = await callable.call();
      return {
        'success': true,
        'count': result.data['count'] ?? 0,
        'message': result.data['message'] ?? 'Matches generated',
      };
    } catch (e) {
      AppLogger.warning('[MatchService] Error generating matches: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Watch generated matches for a user (real-time)
  Stream<List<MatchModel>> watchGeneratedMatches(String uid) {
    return _db
        .collection('matches')
        .doc(uid)
        .collection('generated')
        .where('status', whereIn: ['new', 'viewed'])
        .orderBy('score', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) => MatchModel.fromDoc(doc)).toList();
        });
  }

  /// Get generated matches once (no stream)
  Future<List<MatchModel>> getGeneratedMatches(String uid) async {
    try {
      final snap = await _db
          .collection('matches')
          .doc(uid)
          .collection('generated')
          .where('status', whereIn: ['new', 'viewed'])
          .orderBy('score', descending: true)
          .limit(50)
          .get();

      return snap.docs.map((doc) => MatchModel.fromDoc(doc)).toList();
    } catch (e) {
      AppLogger.warning('[MatchService] Error getting matches: $e');
      return [];
    }
  }

  /// Like a user (swipe right)
  /// Returns true if mutual like detected
  Future<Map<String, dynamic>> likeUser(String targetUserId) async {
    try {
      final callable = _functions.httpsCallable('handleLike');
      final result = await callable.call({'targetUserId': targetUserId});

      return {
        'success': true,
        'isMutualLike': result.data['isMutualLike'] ?? false,
        'message': result.data['message'] ?? 'Like sent',
      };
    } catch (e) {
      AppLogger.warning('[MatchService] Error liking user: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Pass on a user (swipe left)
  Future<Map<String, dynamic>> passUser(String targetUserId) async {
    try {
      final callable = _functions.httpsCallable('handlePass');
      final result = await callable.call({'targetUserId': targetUserId});

      return {
        'success': true,
        'message': result.data['message'] ?? 'Pass recorded',
      };
    } catch (e) {
      AppLogger.warning('[MatchService] Error passing user: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Mark match as viewed
  Future<void> markMatchViewed(String uid, String matchUserId) async {
    try {
      await _db
          .collection('matches')
          .doc(uid)
          .collection('generated')
          .doc(matchUserId)
          .update({'status': 'viewed'});
    } catch (e) {
      AppLogger.warning('[MatchService] Error marking match viewed: $e');
    }
  }

  /// Get match history (liked, passed, mutual likes)
  Stream<List<MatchHistoryModel>> watchMatchHistory(String uid) {
    return _db
        .collection('matches')
        .doc(uid)
        .collection('history')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => MatchHistoryModel.fromDoc(doc)).toList();
    });
  }

  /// Get mutual matches only
  Stream<List<MatchHistoryModel>> watchMutualMatches(String uid) {
    return _db
        .collection('matches')
        .doc(uid)
        .collection('history')
        .where('outcome', isEqualTo: 'mutual_like')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => MatchHistoryModel.fromDoc(doc)).toList();
    });
  }
}

