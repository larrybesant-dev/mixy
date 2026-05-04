import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meta/meta.dart';

import '../models/moderation_model.dart';

class ModerationService {
  ModerationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;

  // In-memory cache: userId → (result, fetchedAt). Blocks rarely change so
  // caching for 5 minutes eliminates repeated Firestore reads on every
  // conversations snapshot event.
  @visibleForTesting
  static final Map<String, ({Set<String> ids, DateTime fetchedAt})>
  excludedCache = {};

  static void clearCache() => excludedCache.clear();

  String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  String get _currentUserId {
    final userId = (_auth ?? FirebaseAuth.instance).currentUser?.uid;
    if (userId == null || userId.isEmpty) {
      throw Exception('User not logged in');
    }
    return userId;
  }

  Future<void> blockUser(String blockedUserId) async {
    final blockerUserId = _currentUserId;
    if (blockedUserId.trim().isEmpty || blockedUserId == blockerUserId) {
      return;
    }

    final docId = '${blockerUserId}_$blockedUserId';
    final block = BlockRecordModel(
      id: docId,
      blockerUserId: blockerUserId,
      blockedUserId: blockedUserId,
      createdAt: DateTime.now().toUtc(),
    );

    await _firestore
        .collection('blocks')
        .doc(docId)
        .set(block.toJson(), SetOptions(merge: true));
  }

  Future<void> unblockUser(String blockedUserId) async {
    final blockerUserId = _currentUserId;
    final docId = '${blockerUserId}_$blockedUserId';
    await _firestore.collection('blocks').doc(docId).delete();
  }

  Future<bool> isBlocked(String otherUserId) async {
    final blockerUserId = _currentUserId;
    final docId = '${blockerUserId}_$otherUserId';
    final snapshot = await _firestore.collection('blocks').doc(docId).get();
    return snapshot.exists;
  }

  Future<void> reportTarget({
    required String targetId,
    required ReportTargetType targetType,
    required String reason,
    String? details,
  }) async {
    final reporterUserId = _currentUserId;
    final reportRef = _firestore.collection('reports').doc();
    final report = ReportRecordModel(
      id: reportRef.id,
      reporterUserId: reporterUserId,
      targetId: targetId,
      targetType: targetType,
      reason: reason.trim(),
      details: details?.trim().isEmpty == true ? null : details?.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    await reportRef.set(report.toJson());
  }

  Stream<List<ReportRecordModel>> watchRecentReports({int limit = 100}) {
    final cappedLimit = limit <= 0 ? 25 : limit;

    return _firestore
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(cappedLimit)
        .snapshots()
        .map((snapshot) {
          final reports = snapshot.docs
              .map((doc) => ReportRecordModel.fromJson(doc.data()))
              .toList(growable: false);
          return reports;
        });
  }

  Future<void> updateReportStatus({
    required String reportId,
    required ModerationStatus status,
  }) async {
    final normalizedReportId = reportId.trim();
    if (normalizedReportId.isEmpty) {
      throw Exception('reportId is required');
    }

    await _firestore.collection('reports').doc(normalizedReportId).set({
      'status': status.name,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<Set<String>> getExcludedUserIds(String userId) async {
    if (userId.trim().isEmpty) {
      return const <String>{};
    }

    final cached = excludedCache[userId];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt).inMinutes < 5) {
      return cached.ids;
    }

    final results = await Future.wait([
      _firestore
          .collection('blocks')
          .where('blockerUserId', isEqualTo: userId)
          .limit(500)
          .get(),
      _firestore
          .collection('blocks')
          .where('blockedUserId', isEqualTo: userId)
          .limit(500)
          .get(),
    ]);

    final blockedByCurrent = results[0];
    final blockingCurrent = results[1];

    final ids = <String>{
      ...blockedByCurrent.docs
          .map((doc) => _asString(doc.data()['blockedUserId']))
          .where((id) => id.isNotEmpty),
      ...blockingCurrent.docs
          .map((doc) => _asString(doc.data()['blockerUserId']))
          .where((id) => id.isNotEmpty),
    };
    excludedCache[userId] = (ids: ids, fetchedAt: DateTime.now());
    return ids;
  }

  Future<bool> hasBlockingRelationship(
    String firstUserId,
    String secondUserId,
  ) async {
    final excludedUserIds = await getExcludedUserIds(firstUserId);
    return excludedUserIds.contains(secondUserId);
  }
}
