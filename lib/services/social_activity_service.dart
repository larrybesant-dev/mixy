import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/events/app_event.dart';
import '../models/social_activity_model.dart';

class SocialActivityService {
  SocialActivityService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Internal buffer for activity logs to reduce Firestore write volume.
  final List<Map<String, dynamic>> _buffer = [];
  Timer? _flushTimer;

  static const int _kMaxBufferSize = 15;
  static const Duration _kFlushInterval = Duration(seconds: 45);

  Stream<List<SocialActivity>> watchUserActivities(
    String userId, {
    int limit = 6,
  }) {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Stream.value(const <SocialActivity>[]);
    }

    return _firestore
        .collection('activity_feed')
        .where('userId', isEqualTo: normalizedUserId)
        .limit(limit * 3)
        .snapshots()
        .map((snapshot) {
          final activities =
              snapshot.docs
                  .map((doc) => SocialActivity.fromJson(doc.id, doc.data()))
                  .toList(growable: false)
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return activities.take(limit).toList(growable: false);
        });
  }

  Future<List<SocialActivity>> getUserActivities(
    String userId, {
    int limit = 6,
  }) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return const <SocialActivity>[];
    }

    final snapshot = await _firestore
        .collection('activity_feed')
        .where('userId', isEqualTo: normalizedUserId)
        .limit(limit * 3)
        .get();

    final activities =
        snapshot.docs
            .map((doc) => SocialActivity.fromJson(doc.id, doc.data()))
            .toList(growable: false)
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities.take(limit).toList(growable: false);
  }

  Future<List<SocialActivity>> getGlobalActivities({
    int limit = 12,
  }) async {
    final snapshot = await _firestore
        .collection('activity_feed')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => SocialActivity.fromJson(doc.id, doc.data()))
        .toList(growable: false);
  }

  Future<void> handleEvent(AppEvent event) async {
    if (event is FollowEvent) {
      await _writeActivity(
        userId: event.fromUserId,
        type: 'followed_user',
        targetId: event.toUserId,
        occurredAt: event.timestamp,
        metadata: <String, dynamic>{
          'targetUsername': (event.toUsername ?? '').trim().isEmpty
              ? event.toUserId
              : event.toUsername!.trim(),
        },
      );
      return;
    }

    if (event is ProfileUpdatedEvent) {
      await _writeActivity(
        userId: event.userId,
        type: 'updated_profile',
        occurredAt: event.timestamp,
        metadata: const <String, dynamic>{'detail': 'Updated profile details'},
      );
      return;
    }

    if (event is RoomJoinedEvent) {
      await _writeActivity(
        userId: event.userId,
        type: 'joined_room',
        targetId: event.roomId,
        occurredAt: event.timestamp,
        metadata: <String, dynamic>{
          'detail': 'Entered a live room',
          if ((event.roomName ?? '').trim().isNotEmpty)
            'roomName': event.roomName!.trim(),
        },
      );
      return;
    }

    if (event is RoomLeftEvent) {
      await _writeActivity(
        userId: event.userId,
        type: 'left_room',
        targetId: event.roomId,
        occurredAt: event.timestamp,
        metadata: <String, dynamic>{
          'detail': 'Exited a live room',
          if ((event.roomName ?? '').trim().isNotEmpty)
            'roomName': event.roomName!.trim(),
        },
      );
      return;
    }

    if (event is MicStateChangedEvent && event.isSpeaker) {
      await _writeActivity(
        userId: event.userId,
        type: 'went_live',
        targetId: event.roomId,
        occurredAt: event.timestamp,
        metadata: <String, dynamic>{
          'detail': 'Grabbed the mic',
          if ((event.roomName ?? '').trim().isNotEmpty)
            'roomName': event.roomName!.trim(),
        },
      );
      return;
    }

    if (event is CameraStateChangedEvent && event.isCameraOn) {
      await _writeActivity(
        userId: event.userId,
        type: 'went_live',
        targetId: event.roomId,
        occurredAt: event.timestamp,
        metadata: <String, dynamic>{
          'detail': 'Turned on camera',
          if ((event.roomName ?? '').trim().isNotEmpty)
            'roomName': event.roomName!.trim(),
        },
      );
    }
  }

  Future<void> _writeActivity({
    required String userId,
    required String type,
    String? targetId,
    Map<String, dynamic>? metadata,
    DateTime? occurredAt,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedType = type.trim();
    if (normalizedUserId.isEmpty || normalizedType.isEmpty) {
      return;
    }

    await _firestore.collection('activity_feed').add({
      'userId': normalizedUserId,
      'type': normalizedType,
      'targetId': (targetId ?? '').trim().isEmpty ? null : targetId!.trim(),
      'timestamp': occurredAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(occurredAt),
      'metadata': metadata ?? const <String, dynamic>{},
    });
  }

  /// Queues an activity for background batching.
  /// Returns immediately to avoid blocking UI or event pipeline.
  void logActivity({
    required String userId,
    required String type,
    String? targetId,
    Map<String, dynamic>? metadata,
    DateTime? occurredAt,
  }) {
    final normalizedUserId = userId.trim();
    final normalizedType = type.trim();
    if (normalizedUserId.isEmpty || normalizedType.isEmpty) {
      return;
    }

    final data = {
      'userId': normalizedUserId,
      'type': normalizedType,
      'targetId': (targetId ?? '').trim().isEmpty ? null : targetId!.trim(),
      'timestamp': occurredAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(occurredAt),
      'metadata': metadata ?? const <String, dynamic>{},
    };

    _buffer.add(data);

    if (_buffer.length >= _kMaxBufferSize) {
      unawaited(flush());
    } else {
      _startFlushTimer();
    }
  }

  /// Commits all buffered activities to Firestore in a single WriteBatch.
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_buffer.isEmpty) return;

    final batch = _firestore.batch();
    final activitiesToCommit = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    for (final data in activitiesToCommit) {
      final docRef = _firestore.collection('activity_feed').doc();
      batch.set(docRef, data);
    }

    try {
      await batch.commit();
    } catch (e) {
      // Best effort for activity logs. In production, we'd log this to telemetry.
    }
  }

  void _startFlushTimer() {
    _flushTimer ??= Timer(_kFlushInterval, () => unawaited(flush()));
  }

  Future<void> dispose() async {
    await flush();
  }
}



