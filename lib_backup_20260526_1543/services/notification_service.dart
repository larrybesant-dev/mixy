import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/events/app_event.dart';
import '../core/streams/stream_lifecycle_manager.dart';
import '../models/notification_model.dart';

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    StreamLifecycleManager? streamLifecycleManager,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _streamLifecycleManager = streamLifecycleManager;

  final FirebaseFirestore _firestore;
  final StreamLifecycleManager? _streamLifecycleManager;

  String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  String _safeActorId(String fallbackUserId) {
    try {
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid != null && authUid.trim().isNotEmpty) {
        return authUid.trim();
      }
    } catch (_) {
      // FirebaseAuth may be unavailable in unit tests.
    }
    final fallback = fallbackUserId.trim();
    return fallback.isEmpty ? 'system' : fallback;
  }

  Future<void> handleEvent(AppEvent event) async {
    if (event is! FollowEvent) {
      return;
    }

    final actorId = event.fromUserId.trim();
    final userId = event.toUserId.trim();
    if (actorId.isEmpty || userId.isEmpty) {
      return;
    }

    final actorName = _asString(event.fromUsername, fallback: 'Someone');
    await _firestore.collection('notifications').add({
      'userId': userId,
      'actorId': actorId,
      'type': 'follow',
      'content': '$actorName started following you.',
      'isRead': false,
      'createdAt': Timestamp.fromDate(event.timestamp),
    });
  }

  Stream<List<NotificationModel>> notificationsForUser(String userId) {
    final snapshots = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();

    final managed = _streamLifecycleManager != null
        ? _streamLifecycleManager.bind<QuerySnapshot<Map<String, dynamic>>>(
            key: 'notifications/$userId',
            create: () => snapshots,
          )
        : snapshots;

    return managed.map(
      (snapshot) => snapshot.docs
          .map((doc) => NotificationModel.fromJson(doc.id, doc.data()))
          .toList(growable: false),
    );
  }

  Future<void> markAllRead(String userId) async {
    // Firestore batch writes are capped at 500 operations. Paginate through
    // unread notifications in pages of 500 to avoid a hard crash when a user
    // has accumulated many notifications.
    const int batchSize = 500;
    QueryDocumentSnapshot? lastDoc;

    while (true) {
      Query query = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .limit(batchSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (snapshot.docs.length < batchSize) break;
      lastDoc = snapshot.docs.last;
    }
  }

  Future<void> markRead(String userId, String notificationId) async {
    final ref = _firestore.collection('notifications').doc(notificationId);
    final snap = await ref.get();
    if (!snap.exists) {
      return;
    }

    final data = snap.data() ?? <String, dynamic>{};
    if (_asString(data['userId']) != userId.trim()) {
      return;
    }

    await ref.update({'isRead': true, 'readAt': FieldValue.serverTimestamp()});
  }

  Future<void> pushNotification(String userId, String message) async {
    final actorId = _safeActorId(userId);
    await _firestore.collection('notifications').add({
      'userId': userId,
      'actorId': actorId,
      'type': 'push',
      'content': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> inAppNotification(String userId, String message) async {
    final actorId = _safeActorId(userId);
    await _firestore.collection('notifications').add({
      'userId': userId,
      'actorId': actorId,
      'type': 'in_app',
      'content': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sends a room-invite in-app notification to each [friendIds] entry.
  /// [inviterName] is shown in the notification text.
  /// [roomId] / [roomName] are stored so the FCM deep-link can navigate
  /// directly to the room when the notification is tapped.
  Future<void> sendRoomInviteToFriends({
    required List<String> friendIds,
    required String inviterId,
    required String inviterName,
    required String roomId,
    required String roomName,
  }) async {
    if (friendIds.isEmpty) return;
    final batch = _firestore.batch();
    for (final friendId in friendIds) {
      final ref = _firestore.collection('notifications').doc();
      batch.set(ref, {
        'userId': friendId,
        'actorId': inviterId,
        'type': 'room_invite',
        'content':
            '$inviterName invited you to join "$roomName" — tap to join!',
        'roomId': roomId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    developer.log(
      'room_invite_sent inviterId=$inviterId roomId=$roomId recipients=${friendIds.length}',
      name: 'NotificationService',
    );
  }
}
