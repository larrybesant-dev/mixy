import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/room_policy_model.dart';
import '../../../services/notification_service.dart';
import 'room_firestore_provider.dart';

class CamAccessController {
  CamAccessController(this._db);

  final FirebaseFirestore _db;

  String? _asNullableString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  CollectionReference<Map<String, dynamic>> _requestCollection(String roomId) {
    return _db
        .collection('rooms')
        .doc(roomId)
        .collection('cam_access_requests');
  }

  String _requestDocId(String requesterId, String broadcasterId) {
    return '${requesterId}_$broadcasterId';
  }

  Future<void> requestAccess({
    required String roomId,
    required String requesterId,
    required String broadcasterId,
  }) async {
    final requestId = _requestDocId(requesterId, broadcasterId);
    final requestRef = _requestCollection(roomId).doc(requestId);
    final existingSnapshot = await requestRef.get();
    final existingData = existingSnapshot.data();
    if (existingData != null &&
        _asNullableString(existingData['status']) == 'pending') {
      return;
    }

    await requestRef.set({
      'id': requestId,
      'roomId': roomId,
      'requesterId': requesterId,
      'broadcasterId': broadcasterId,
      'status': 'pending',
      'decisionScope': 'single_session',
      'participantIds': [requesterId, broadcasterId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await NotificationService(firestore: _db).inAppNotification(
      broadcasterId,
      'New stage access request from $requesterId in room $roomId.',
    );
  }

  Future<void> approveRequest(
    String roomId,
    CamAccessRequestModel request,
  ) async {
    final batch = _db.batch();
    batch.update(_requestCollection(roomId).doc(request.id), {
      'status': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _db
          .collection('rooms')
          .doc(roomId)
          .collection('participants')
          .doc(request.requesterId),
      {
        'userId': request.requesterId,
        'role': 'cohost',
        'lastActiveAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    await NotificationService(firestore: _db).inAppNotification(
      request.requesterId,
      'Your stage access request was approved in room $roomId.',
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
        'Your stage access request was denied in room $roomId.',
      );
    }
  }
}

final camAccessControllerProvider = Provider<CamAccessController>((ref) {
  return CamAccessController(ref.watch(roomFirestoreProvider));
});

final roomCamAccessRequestsProvider = StreamProvider.autoDispose
    .family<List<CamAccessRequestModel>, String>((ref, roomId) {
      final firestore = ref.watch(roomFirestoreProvider);
      return firestore
          .collection('rooms')
          .doc(roomId)
          .collection('cam_access_requests')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(
                  (doc) => CamAccessRequestModel.fromJson({
                    'id': doc.id,
                    ...doc.data(),
                  }),
                )
                .toList(growable: false),
          );
    });

final myCamAccessRequestProvider = StreamProvider.autoDispose
    .family<CamAccessRequestModel?, ({String roomId, String requesterId})>((
      ref,
      params,
    ) {
      return Stream.multi((controller) {
        final subscription = ref.listen(
          roomCamAccessRequestsProvider(params.roomId),
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




