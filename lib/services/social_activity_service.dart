import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/events/app_event.dart';
import '../models/social_activity_model.dart';

class SocialActivityService {
  SocialActivityService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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

    final activities = snapshot.docs
        .map((doc) => SocialActivity.fromJson(doc.id, doc.data()))
        .toList(growable: false)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return activities.take(limit).toList(growable: false);
  }

  Future<void> handleEvent(AppEvent event) async {
    if (event is FollowEvent) {
      await logActivity(
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
      await logActivity(
        userId: event.userId,
        type: 'updated_profile',
        occurredAt: event.timestamp,
        metadata: const <String, dynamic>{'detail': 'Updated profile details'},
      );
      return;
    }

    if (event is RoomJoinedEvent) {
      await logActivity(
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
      await logActivity(
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
      await logActivity(
        userId: event.userId,
        type: 'went_live',
        targetId: event.roomId,
        occurredAt: event.timestamp,
        metadata: const <String, dynamic>{'detail': 'Grabbed the mic'},
      );
      return;
    }

    if (event is CameraStateChangedEvent && event.isCameraOn) {
      await logActivity(
        userId: event.userId,
        type: 'went_live',
        targetId: event.roomId,
        occurredAt: event.timestamp,
        metadata: const <String, dynamic>{'detail': 'Turned on camera'},
      );
    }
  }

  Future<void> logActivity({
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
}
