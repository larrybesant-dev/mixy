import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'room_firestore_provider.dart';

class BuzzEvent {
  const BuzzEvent({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.sentAt,
  });

  final String id;
  final String fromUserId;
  final String toUserId;
  final DateTime sentAt;
}

class BuzzController {
  BuzzController(this._db);

  final FirebaseFirestore _db;

  /// Sends a buzz/nudge from [fromUserId] to [toUserId] in [roomId].
  Future<void> sendBuzz({
    required String roomId,
    required String fromUserId,
    required String toUserId,
  }) async {
    await _db.collection('rooms').doc(roomId).collection('buzz_events').add({
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }
}

final buzzControllerProvider = Provider<BuzzController>((ref) {
  return BuzzController(ref.watch(roomFirestoreProvider));
});

/// Stream of buzz events sent TO [currentUserId] in [roomId].
final incomingBuzzStreamProvider = StreamProvider.autoDispose
    .family<List<BuzzEvent>, ({String roomId, String currentUserId})>((
      ref,
      params,
    ) {
      final firestore = ref.watch(roomFirestoreProvider);
      // Only listen to buzzes from the last 60 seconds so we don't replay old ones.
      final since = DateTime.now().subtract(const Duration(seconds: 60));
      return firestore
          .collection('rooms')
          .doc(params.roomId)
          .collection('buzz_events')
          .where('toUserId', isEqualTo: params.currentUserId)
          .where('sentAt', isGreaterThan: Timestamp.fromDate(since))
          .limit(50)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((doc) {
                  final data = doc.data();
                  final sentAt = data['sentAt'];
                  return BuzzEvent(
                    id: doc.id,
                    fromUserId: data['fromUserId'] as String? ?? '',
                    toUserId: data['toUserId'] as String? ?? '',
                    sentAt: sentAt is Timestamp
                        ? sentAt.toDate()
                        : DateTime.now(),
                  );
                })
                .toList(growable: false),
          );
    });




