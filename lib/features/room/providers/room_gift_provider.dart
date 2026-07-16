import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../features/room/providers/room_firestore_provider.dart';
import '../models/room_gift_catalog.dart';
import '../models/room_gift_event.dart';

export '../models/room_gift_catalog.dart';
export '../models/room_gift_event.dart';

/// Stream of the most recent 20 gift events for a room, newest first.
final roomGiftStreamProvider = StreamProvider.autoDispose
    .family<List<RoomGiftEvent>, String>((ref, roomId) {
      if (roomId.isEmpty) return const Stream.empty();
      final firestore = ref.watch(roomFirestoreProvider);
      return firestore
          .collection('rooms')
          .doc(roomId)
          .collection('gift_events')
          .orderBy('sentAt', descending: true)
          .limit(20)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((doc) => RoomGiftEvent.fromJson(doc.id, doc.data()))
                .toList(),
          );
    });

/// Top 5 gifters aggregated from recent gift events.
final topGiftersProvider = Provider.autoDispose
    .family<List<RoomTopGifter>, String>((ref, roomId) {
      final eventsAsync = ref.watch(roomGiftStreamProvider(roomId));
      return eventsAsync.when(
        data: (events) {
          final totals = <String, int>{};
          final names = <String, String>{};
          for (final e in events) {
            if (e.senderId.isEmpty) continue;
            totals[e.senderId] = (totals[e.senderId] ?? 0) + e.coinCost;
            if (e.senderName.isNotEmpty) names[e.senderId] = e.senderName;
          }
          final sorted = totals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return sorted
              .take(5)
              .map(
                (entry) => RoomTopGifter(
                  userId: entry.key,
                  displayName: names[entry.key] ?? entry.key,
                  totalCoins: entry.value,
                ),
              )
              .toList();
        },
        loading: () => const [],
        error: (_, errorStack) => const [],
      );
    });

class RoomGiftController {
  /// Sends a gift in [roomId] to [receiverId].
  /// [senderName] and [receiverName] are included for fast display without extra Firestore reads.
  Future<void> sendGift({
    required String roomId,
    required String receiverId,
    required String senderName,
    required String receiverName,
    required RoomGiftItem gift,
  }) async {
    if (roomId.isEmpty || receiverId.isEmpty) {
      throw Exception('Invalid room or receiver.');
    }
    final callable = FirebaseFunctions.instance.httpsCallable('sendRoomGift');
    await callable.call<Map<String, dynamic>>({
      'roomId': roomId,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'giftId': gift.id,
      'coinCost': gift.coinCost,
      'senderName': senderName,
      'emoji': gift.emoji,
    });
  }
}

final roomGiftControllerProvider = Provider.autoDispose<RoomGiftController>(
  (ref) => RoomGiftController(),
);




