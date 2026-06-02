import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/mic_access_request_model.dart';
import '../../../services/notification_service.dart';
import 'room_firestore_provider.dart';

class MicAccessController {
  MicAccessController(this._db);

  static const Duration _kRequestTtl = Duration(minutes: 15);
  static const Duration _kRequeueCooldown = Duration(seconds: 20);

  final FirebaseFirestore _db;

  int _asInt(dynamic value, {int fallback = 100}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  String? _asNullableString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  CollectionReference<Map<String, dynamic>> _requestCollection(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('mic_access_requests');
  }

  String _requestDocId(String requesterId, String hostId) {
    return '${requesterId}_$hostId';
  }

  Future<void> _expireStalePendingRequests(String roomId) async {
    final now = DateTime.now();
    final pendingSnapshot = await _requestCollection(
      roomId,
    ).where('status', isEqualTo: 'pending').get();
    final staleDocs = pendingSnapshot.docs.where((doc) {
      final expiresAt = doc.data()['expiresAt'];
      if (expiresAt is! Timestamp) {
        return false;
      }
      return !expiresAt.toDate().isAfter(now);
    }).toList(growable: false);
    if (staleDocs.isEmpty) {
      return;
    }
    final batch = _db.batch();
    for (final staleDoc in staleDocs) {
      batch.update(staleDoc.reference, {
        'status': 'expired',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> requestAccess({
    required String roomId,
    required String requesterId,
    required String hostId,
    int? priority,
  }) async {
    try {
      await _expireStalePendingRequests(roomId);
    } catch (_) {
      // Best effort only.
    }

    final requestId = _requestDocId(requesterId, hostId);
    final requestRef = _requestCollection(roomId).doc(requestId);
    final now = DateTime.now();
    final requesterSnapshot = await _requestCollection(
      roomId,
    ).where('requesterId', isEqualTo: requesterId).get();
    final pendingSnapshot = await _requestCollection(
      roomId,
    ).where('status', isEqualTo: 'pending').get();

    final relatedDocs = requesterSnapshot.docs;
    final conflictingPendingDocs = relatedDocs.where((doc) {
      final data = doc.data();
      final status = _asNullableString(data['status']) ?? '';
      final expiresAt = _asDateTime(data['expiresAt']);
      return doc.id != requestId &&
          status == 'pending' &&
          (expiresAt == null || expiresAt.isAfter(now));
    }).toList(growable: false);

    final hasRecentClosedRequest = relatedDocs.any((doc) {
      final data = doc.data();
      final status = _asNullableString(data['status']) ?? '';
      final updatedAt = _asDateTime(data['updatedAt']);
      return status.isNotEmpty &&
          status != 'pending' &&
          updatedAt != null &&
          now.difference(updatedAt) < _kRequeueCooldown;
    });
    if (hasRecentClosedRequest) {
      throw StateError('Please wait a moment before raising your hand again.');
    }

    final highestPendingPriority = pendingSnapshot.docs.fold<int>(0, (
      maxPriority,
      doc,
    ) {
      final data = doc.data();
      final expiresAt = _asDateTime(data['expiresAt']);
      if (expiresAt != null && !expiresAt.isAfter(now)) {
        return maxPriority;
      }
      final docPriority = _asInt(data['priority'], fallback: 0);
      return docPriority > maxPriority ? docPriority : maxPriority;
    });

    bool shouldNotifyHost = false;

    await _db.runTransaction((tx) async {
      final existingSnapshot = await tx.get(requestRef);
      final existingData = existingSnapshot.data();
      final existingStatus = _asNullableString(existingData?['status']) ?? '';
      final expiresAt = _asDateTime(existingData?['expiresAt']);

      if (existingData != null &&
          existingStatus == 'pending' &&
          expiresAt != null &&
          expiresAt.isAfter(now)) {
        return;
      }

      final nextPriority = priority ?? highestPendingPriority + 1;

      for (final conflictingDoc in conflictingPendingDocs) {
        tx.set(
            conflictingDoc.reference,
            {
              'status': 'superseded',
              'updatedAt': FieldValue.serverTimestamp(),
              'expiresAt': Timestamp.fromDate(now),
            },
            SetOptions(merge: true));
      }

      shouldNotifyHost = true;
      tx.set(
          requestRef,
          {
            'id': requestId,
            'roomId': roomId,
            'requesterId': requesterId,
            'hostId': hostId,
            'status': 'pending',
            'priority': nextPriority,
            'expiresAt': Timestamp.fromDate(now.add(_kRequestTtl)),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });

    if (!shouldNotifyHost) {
      return;
    }

    await NotificationService(firestore: _db).inAppNotification(
      hostId,
      'New mic request from $requesterId in room $roomId.',
    );
  }

  Future<void> bumpPriority(String roomId, String requestId) async {
    final requestRef = _requestCollection(roomId).doc(requestId);
    final snapshot = await requestRef.get();
    if (!snapshot.exists) {
      return;
    }
    final current = _asInt(snapshot.data()?['priority']);
    final next = current <= 0 ? 0 : current - 10;
    await requestRef.update({
      'priority': next,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> lowerPriority(String roomId, String requestId) async {
    final requestRef = _requestCollection(roomId).doc(requestId);
    final snapshot = await requestRef.get();
    if (!snapshot.exists) {
      return;
    }
    final current = _asInt(snapshot.data()?['priority']);
    await requestRef.update({
      'priority': current + 10,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> expireNow(String roomId, String requestId) async {
    final requestRef = _requestCollection(roomId).doc(requestId);
    final snapshot = await requestRef.get();
    if (!snapshot.exists) {
      return;
    }
    final requesterId = _asNullableString(snapshot.data()?['requesterId']);
    await requestRef.update({
      'status': 'expired',
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now()),
    });
    if (requesterId != null && requesterId.isNotEmpty) {
      await NotificationService(firestore: _db).inAppNotification(
        requesterId,
        'Your mic access request expired in room $roomId.',
      );
    }
  }

  Future<void> cancelRequest(String roomId, String requestId) async {
    final requestRef = _requestCollection(roomId).doc(requestId);
    final snapshot = await requestRef.get();
    if (!snapshot.exists) {
      return;
    }
    await requestRef.update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Releases the mic by demoting the user from stage role.
  /// This is a safe operation: the user is releasing their own mic.
  Future<void> releaseMic({
    required String roomId,
    required String userId,
  }) async {
    try {
      await _db
          .collection('rooms')
          .doc(roomId)
          .collection('participants')
          .doc(userId)
          .set({
        'userId': userId,
        'role': 'member',
        'micOn': false,
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Best effort; if update fails, user remains in current state.
    }
  }

  Future<void> approveRequest(
    String roomId,
    MicAccessRequestModel request,
  ) async {
    await _requestCollection(roomId).doc(request.id).set({
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await NotificationService(firestore: _db).inAppNotification(
      request.requesterId,
      'Your mic access request was approved in room $roomId.',
    );
  }

  Future<void> denyRequest(String roomId, String requestId) async {
    final requestSnapshot = await _requestCollection(
      roomId,
    ).doc(requestId).get();
    final requesterId = _asNullableString(
      requestSnapshot.data()?['requesterId'],
    );
    await _requestCollection(roomId).doc(requestId).update({
      'status': 'denied',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (requesterId != null && requesterId.isNotEmpty) {
      await NotificationService(firestore: _db).inAppNotification(
        requesterId,
        'Your mic access request was denied in room $roomId.',
      );
    }
  }
}

final micAccessControllerProvider = Provider<MicAccessController>((ref) {
  return MicAccessController(ref.watch(roomFirestoreProvider));
});

final roomMicAccessRequestsProvider = StreamProvider.autoDispose
    .family<List<MicAccessRequestModel>, String>((ref, roomId) {
  final firestore = ref.watch(roomFirestoreProvider);
  return firestore
      .collection('rooms')
      .doc(roomId)
      .collection('mic_access_requests')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) {
    final requests = snapshot.docs
        .map(
          (doc) => MicAccessRequestModel.fromJson({
            'id': doc.id,
            ...doc.data(),
          }),
        )
        .where(
          (request) => !(request.status == 'pending' && request.isExpired),
        )
        .toList(growable: false);
    requests.sort((left, right) {
      if (left.status == 'pending' && right.status != 'pending') {
        return -1;
      }
      if (left.status != 'pending' && right.status == 'pending') {
        return 1;
      }
      final priorityCompare = left.priority.compareTo(right.priority);
      if (priorityCompare != 0) {
        return priorityCompare;
      }
      return left.createdAt.compareTo(right.createdAt);
    });
    return requests;
  });
});

final myMicAccessRequestProvider = StreamProvider.autoDispose
    .family<MicAccessRequestModel?, ({String roomId, String requesterId})>((
  ref,
  params,
) {
  return Stream.multi((controller) {
    final subscription = ref.listen(
      roomMicAccessRequestsProvider(params.roomId),
      (_, next) {
        if (controller.isClosed) return;
        next.whenData((requests) {
          final myRequests = requests
              .where((request) => request.requesterId == params.requesterId)
              .toList();
          if (myRequests.isEmpty) {
            controller.add(null);
          } else {
            controller.add(myRequests.first);
          }
        });
      },
    );
    controller.onCancel = subscription.close;
  });
});
