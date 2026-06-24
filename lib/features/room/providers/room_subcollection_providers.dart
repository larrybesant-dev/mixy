import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/models/room_role.dart';
import 'package:mixvy/shared/models/chat_message.dart';
import 'package:mixvy/shared/models/room_event.dart';

/// Firestore instance provider
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Participants subcollection stream provider
/// rooms/{roomId}/participants/{userId}
final roomParticipantsFirestoreProvider =
    StreamProvider.family<List<RoomParticipant>, String>(
  (ref, roomId) {
    final firestore = ref.watch(firestoreProvider);
    return firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RoomParticipant.fromFirestore(doc.data()))
          .toList();
    });
  },
);

/// Messages subcollection stream provider
/// rooms/{roomId}/messages/{messageId}
final roomMessagesFirestoreProvider =
    StreamProvider.family<List<ChatMessage>, String>(
  (ref, roomId) {
    final firestore = ref.watch(firestoreProvider);
    return firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(200)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ChatMessage.fromDocument(doc)).toList();
    });
  },
);

/// Events subcollection stream provider
/// rooms/{roomId}/events/{eventId}
final roomEventsFirestoreProvider =
    StreamProvider.family<List<RoomEvent>, String>(
  (ref, roomId) {
    final firestore = ref.watch(firestoreProvider);
    return firestore
        .collection('rooms')
        .doc(roomId)
        .collection('events')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RoomEvent.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  },
);

/// Repository for managing room subcollections
class RoomSubcollectionRepository {
  final FirebaseFirestore _firestore;

  RoomSubcollectionRepository(this._firestore);

  // ==================== Participants ====================

  /// Add or update a participant in a room
  Future<void> addParticipant({
    required String roomId,
    required RoomParticipant participant,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(participant.userId)
        .set(participant.toFirestore());
  }

  /// Remove a participant from a room
  Future<void> removeParticipant({
    required String roomId,
    required String userId,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(userId)
        .delete();
  }

  /// Update participant fields
  Future<void> updateParticipant({
    required String roomId,
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(userId)
        .update(updates);
  }

  /// Set participant isOnCam status and update room camCount
  Future<void> setParticipantOnCam({
    required String roomId,
    required String userId,
    required bool isOnCam,
  }) async {
    final batch = _firestore.batch();

    // Update participant
    final participantRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(userId);
    batch.update(participantRef, {'isOnCam': isOnCam});

    // Update room camCount atomically
    final roomRef = _firestore.collection('rooms').doc(roomId);
    batch.update(roomRef, {
      'camCount': FieldValue.increment(isOnCam ? 1 : -1),
    });

    await batch.commit();
  }

  /// Update participant lastActiveAt timestamp
  Future<void> updateParticipantActivity({
    required String roomId,
    required String userId,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('participants')
        .doc(userId)
        .update({'lastActiveAt': DateTime.now().millisecondsSinceEpoch});
  }

  // ==================== Messages ====================

  /// Send a message to room chat
  Future<String> sendMessage({
    required String roomId,
    required ChatMessage message,
  }) async {
    final docRef = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .add(message.toMap());

    return docRef.id;
  }

  /// Delete a message (soft delete)
  Future<void> deleteMessage({
    required String roomId,
    required String messageId,
  }) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .update({'isDeleted': true});
  }

  // ==================== Events ====================

  /// Log an event in the room
  Future<String> logEvent({
    required String roomId,
    required RoomEvent event,
  }) async {
    final docRef = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('events')
        .add(event.toFirestore());

    return docRef.id;
  }

  /// Get recent events for a room
  Future<List<RoomEvent>> getRecentEvents({
    required String roomId,
    int limit = 50,
  }) async {
    final snapshot = await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('events')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => RoomEvent.fromFirestore(doc.id, doc.data()))
        .toList();
  }
}

/// Repository provider
final roomSubcollectionRepositoryProvider =
    Provider<RoomSubcollectionRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return RoomSubcollectionRepository(firestore);
});

