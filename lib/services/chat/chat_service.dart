// lib/services/chat_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/models/chat_message.dart';
import '../../shared/models/chat_room.dart';
import '../../features/match_inbox/services/match_inbox_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get chat rooms for current user
  Future<List<ChatRoom>> getUserChatRooms() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // Get all chat rooms for the user
      final query = _firestore
          .collection('chatRooms')
          .where('participants', arrayContains: user.uid);

      final snapshot = await query.get();
      final rooms = snapshot.docs
          .map((doc) => ChatRoom.fromMap(doc.data()..['id'] = doc.id))
          .toList();

      // Sort by last message time in memory
      rooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      return rooms;
    } catch (e) {
      // Return empty list instead of throwing to avoid errors on empty database
      return [];
    }
  }

  // Get or create chat room between two users
  Future<ChatRoom> getOrCreateChatRoom(String otherUserId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final participants = [user.uid, otherUserId]..sort();
    final roomId = participants.join('_');

    try {
      final docRef = _firestore.collection('chatRooms').doc(roomId);
      final doc = await docRef.get();

      if (doc.exists) {
        return ChatRoom.fromMap(doc.data()!..['id'] = doc.id);
      } else {
        // Create new chat room
        final newRoom = ChatRoom(
          id: roomId,
          participants: participants,
          lastMessage: '',
          lastMessageTime: DateTime.now(),
          unreadCounts: {user.uid: 0, otherUserId: 0},
          isTyping: false,
        );

        await docRef.set(newRoom.toMap());
        return newRoom;
      }
    } catch (e) {
      throw Exception('Failed to get or create chat room: $e');
    }
  }

  // Send message
  Future<void> sendMessage(String roomId, String content,
      {String? imageUrl, String senderName = 'Unknown User'}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final message = ChatMessage(
        id: _firestore
            .collection('chatRooms')
            .doc(roomId)
            .collection('messages')
            .doc()
            .id,
        roomId: roomId,
        senderId: user.uid,
        senderName: senderName,
        content: content,
        imageUrl: imageUrl,
        timestamp: DateTime.now(),
        isRead: false,
      );

      // Add message to subcollection
      await _firestore
          .collection('chatRooms')
          .doc(roomId)
          .collection('messages')
          .doc(message.id)
          .set(message.toMap());

      // Update chat room's last message.
      // Derive the receiver's UID from the roomId (format: "uid1_uid2", sorted).
      // Only the receiver's unread count is incremented; the sender's stays at 0.
      final parts = roomId.split('_');
      final receiverUid =
          parts.length == 2 ? parts.firstWhere((p) => p != user.uid, orElse: () => parts[0]) : null;

      final updatePayload = <String, dynamic>{
        'lastMessage': content,
        'lastMessageTime': Timestamp.fromDate(message.timestamp),
      };
      if (receiverUid != null && receiverUid.isNotEmpty) {
        updatePayload['unreadCounts.$receiverUid'] = FieldValue.increment(1);
      }

      await _firestore.collection('chatRooms').doc(roomId).update(updatePayload);

      // ── Update match inbox last-interaction timestamp (non-blocking) ──────
      // Only applies to DM rooms (format: uid1_uid2). Keeps MatchTile timeago fresh.
      if (receiverUid != null && receiverUid.isNotEmpty) {
        MatchInboxService.instance
            .updateLastInteraction(user.uid, receiverUid)
            .catchError((_) {});
      }
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // Get messages for a chat room
  Future<List<ChatMessage>> getMessages(String roomId, {int limit = 50}) async {
    try {
      final query = _firestore
          .collection('chatRooms')
          .doc(roomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data()..['id'] = doc.id))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      throw Exception('Failed to get messages: $e');
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String roomId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();

      final unreadMessages = await _firestore
          .collection('chatRooms')
          .doc(roomId)
          .collection('messages')
          .where('senderId', isNotEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      // Reset unread count for current user
      await _firestore.collection('chatRooms').doc(roomId).update({
        'unreadCounts.${user.uid}': 0,
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  // Update typing status
  Future<void> updateTypingStatus(String roomId, bool isTyping) async {
    try {
      await _firestore.collection('chatRooms').doc(roomId).update({
        'isTyping': isTyping,
      });
    } catch (e) {
      throw Exception('Failed to update typing status: $e');
    }
  }

  // Stream chat rooms for current user (real-time, no composite index needed)
  Stream<List<ChatRoom>> streamUserChatRooms() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    // Use a StreamController so we can swallow permission / empty-collection
    // errors and emit an empty list instead of propagating an error event.
    final controller = StreamController<List<ChatRoom>>.broadcast();

    final sub = _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .listen(
      (snapshot) {
        try {
          final rooms = snapshot.docs
              .map((doc) => ChatRoom.fromMap(doc.data()..['id'] = doc.id))
              .toList();
          rooms.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
          controller.add(rooms);
        } catch (e) {
          controller.add([]);
        }
      },
      onError: (_) => controller.add([]),
      onDone: () => controller.close(),
    );

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  // Stream messages for a chat room
  Stream<List<ChatMessage>> streamMessages(String roomId) {
    return _firestore
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data()..['id'] = doc.id))
            .toList());
  }

  // Stream typing status for a chat room
  Stream<bool> streamTypingStatus(String roomId) {
    return _firestore
        .collection('chatRooms')
        .doc(roomId)
        .snapshots()
        .map((doc) => doc.data()?['isTyping'] as bool? ?? false);
  }

  // Delete message (for current user only - marks as deleted)
  Future<void> deleteMessage(String roomId, String messageId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('chatRooms')
          .doc(roomId)
          .collection('messages')
          .doc(messageId)
          .update({
        'deletedBy': FieldValue.arrayUnion([user.uid]),
      });
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  // Report message
  Future<void> reportMessage(
      String roomId, String messageId, String reason) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('reportedMessages').add({
        'roomId': roomId,
        'messageId': messageId,
        'reportedBy': user.uid,
        'reason': reason,
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to report message: $e');
    }
  }

  // Convenience alias for common naming pattern
  Stream<List<ChatMessage>> messagesStream(String roomId) =>
      streamMessages(roomId);

  // Stream pinned messages for a chat room
  Stream<List<ChatMessage>> streamPinnedMessages(String roomId) {
    return _firestore
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .where('isPinned', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data()..['id'] = doc.id))
            .toList());
  }

  // Get chat settings for a room
  Future<Map<String, dynamic>> getChatSettings(String roomId) async {
    try {
      final doc = await _firestore.collection('chatRooms').doc(roomId).get();
      return doc.data()?['settings'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {};
    }
  }

  // Get message count for a chat room
  Future<int> getMessageCount(String roomId) async {
    try {
      final snapshot = await _firestore
          .collection('chatRooms')
          .doc(roomId)
          .collection('messages')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Update user presence (online/offline status)
  Future<void> updatePresence(String userId, {required bool isOnline}) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to update presence: $e');
    }
  }

  // Set user online
  Future<void> setUserOnline(String userId) async {
    await updatePresence(userId, isOnline: true);
  }

  // Set user offline
  Future<void> setUserOffline(String userId) async {
    await updatePresence(userId, isOnline: false);
  }
}
