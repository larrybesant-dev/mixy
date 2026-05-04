import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/notification_service.dart';
import 'room_firestore_provider.dart';

class CamViewRequest {
  const CamViewRequest({
    required this.id,
    required this.requesterId,
    required this.targetId,
    required this.roomId,
    required this.status,
    this.requesterName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String requesterId;
  final String targetId;
  final String roomId;
  final String status;
  final String? requesterName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get normalizedStatus => status.trim().toLowerCase();

  bool get isPending => normalizedStatus == 'pending';

  DateTime get sortTime =>
      updatedAt ?? createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  factory CamViewRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return CamViewRequest(
      id: doc.id,
      requesterId: (data['requesterId'] as String?) ?? '',
      targetId: (data['targetId'] as String?) ?? '',
      roomId: (data['roomId'] as String?) ?? '',
      status: (data['status'] as String?) ?? '',
      requesterName: (data['requesterName'] as String?)?.trim(),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }
}

class CamViewRequestController {
  CamViewRequestController(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String roomId) =>
      _db.collection('rooms').doc(roomId).collection('cam_view_requests');

  /// Sends a cam-view request from [requesterId] to [targetId] in [roomId].
  /// Each send creates a fresh pending request and supersedes any older pending one.
  Future<void> sendRequest({
    required String roomId,
    required String requesterId,
    required String targetId,
    String? requesterName,
  }) async {
    final normalizedRoomId = roomId.trim();
    final normalizedRequesterId = requesterId.trim();
    final normalizedTargetId = targetId.trim();
    final normalizedRequesterName = requesterName?.trim() ?? '';
    if (normalizedRoomId.isEmpty ||
        normalizedRequesterId.isEmpty ||
        normalizedTargetId.isEmpty) {
      return;
    }

    final existingSnapshot = await _col(
      normalizedRoomId,
    ).where('targetId', isEqualTo: normalizedTargetId).get();
    final pendingToSupersede = existingSnapshot.docs
        .where((doc) {
          final data = doc.data();
          final requester = (data['requesterId'] as String? ?? '').trim();
          final status = (data['status'] as String? ?? '').trim().toLowerCase();
          return requester == normalizedRequesterId && status == 'pending';
        })
        .toList(growable: false);

    final requestRef = _col(normalizedRoomId).doc();
    final batch = _db.batch();
    for (final doc in pendingToSupersede) {
      batch.update(doc.reference, {
        'status': 'superseded',
        'supersededBy': requestRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(requestRef, {
      'id': requestRef.id,
      'roomId': normalizedRoomId,
      'requesterId': normalizedRequesterId,
      'targetId': normalizedTargetId,
      'requesterName': normalizedRequesterName.isEmpty
          ? normalizedRequesterId
          : normalizedRequesterName,
      'requestKey': '$normalizedRequesterId:$normalizedTargetId',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    final requesterLabel = normalizedRequesterName.isEmpty
        ? normalizedRequesterId
        : normalizedRequesterName;
    await NotificationService(firestore: _db).inAppNotification(
      normalizedTargetId,
      pendingToSupersede.isNotEmpty
          ? '$requesterLabel wants to view your camera in room $normalizedRoomId again.'
          : '$requesterLabel wants to view your camera in room $normalizedRoomId.',
    );
  }

  /// Marks a cam-view request as approved or denied.
  Future<void> respondToRequest({
    required String roomId,
    required String requestId,
    required bool approved,
  }) async {
    final requestRef = _col(roomId).doc(requestId);
    final snapshot = await requestRef.get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final requesterId = (data['requesterId'] as String?)?.trim() ?? '';

    await requestRef.update({
      'status': approved ? 'approved' : 'denied',
      'resolvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (requesterId.isNotEmpty) {
      await NotificationService(firestore: _db).inAppNotification(
        requesterId,
        approved
            ? 'Your cam request was approved in room $roomId.'
            : 'Your cam request was denied in room $roomId.',
      );
    }
  }
}

final camViewRequestControllerProvider = Provider<CamViewRequestController>((
  ref,
) {
  return CamViewRequestController(ref.watch(roomFirestoreProvider));
});

/// Streams pending cam-view requests directed at [targetId] in [roomId].
/// Only queries by targetId (no composite index needed); status is filtered
/// client-side.
final pendingCamViewRequestsProvider = StreamProvider.autoDispose
    .family<List<CamViewRequest>, ({String roomId, String targetId})>((
      ref,
      params,
    ) {
      final firestore = ref.watch(roomFirestoreProvider);
      return firestore
          .collection('rooms')
          .doc(params.roomId)
          .collection('cam_view_requests')
          .where('targetId', isEqualTo: params.targetId)
          .limit(50)
          .snapshots()
          .map((qs) {
            final requests =
                qs.docs
                    .map(CamViewRequest.fromDoc)
                    .where((r) => r.isPending)
                    .toList(growable: true)
                  ..sort((a, b) => b.sortTime.compareTo(a.sortTime));
            return requests.toList(growable: false);
          });
    });
