import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../shared/models/direct_message.dart';
import '../../shared/models/message.dart';
import '../../shared/models/user.dart';
import '../analytics/analytics_service.dart';
import '../notifications/notification_service.dart';

/// Service for handling direct messaging between users
class MessagingService {
  static final MessagingService _instance = MessagingService._internal();
  factory MessagingService() => _instance;

  MessagingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AnalyticsService _analytics = AnalyticsService();
  final NotificationService _notificationService = NotificationService();

  /// Send a direct message to another user
  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
    DirectMessageType type = DirectMessageType.text,
    String? mediaUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final conversationId =
        DirectMessage.createConversationId(senderId, receiverId);

    final message = DirectMessage(
      id: '', // Will be set by Firestore
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      type: type,
      content: content,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      metadata: metadata,
      status: MessageStatus.sent,
      timestamp: DateTime.now(),
    );

    // Add message to Firestore
    await _firestore.collection('direct_messages').add(message.toMap());

    // Update conversation metadata
    await _updateConversationMetadata(
        conversationId, senderId, receiverId, content, DateTime.now());

    // Send push notification to receiver
    await _sendMessageNotification(
        conversationId, senderId, receiverId, content);

    // Track analytics
    _analytics.trackEngagement('direct_message_sent', parameters: {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message_type': type.name,
    });
  }

  /// Get messages for a conversation between two users (with pagination)
  Stream<List<DirectMessage>> getConversationMessages(
    String userId1,
    String userId2, {
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) {
    final conversationId = DirectMessage.createConversationId(userId1, userId2);

    var query = _firestore
        .collection('direct_messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => DirectMessage.fromMap(doc.data(), doc.id))
        .toList()
        .reversed
        .toList()); // Reverse to show oldest first
  }

  /// Get paginated messages for a conversation (one-time query for pagination)
  Future<(List<DirectMessage>, DocumentSnapshot?)> getPaginatedMessages(
    String userId1,
    String userId2, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    final conversationId = DirectMessage.createConversationId(userId1, userId2);

    var query = _firestore
        .collection('direct_messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final messages = snapshot.docs
        .map((doc) => DirectMessage.fromMap(doc.data(), doc.id))
        .toList()
        .reversed
        .toList(); // Reverse to show oldest first

    // Return the last document for pagination (the oldest message's document)
    final lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    return (messages, lastDocument);
  }

  /// Get all conversations for a user
  Stream<List<Map<String, dynamic>>> getUserConversations(String userId) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final conversations = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final otherUserId = (data['participants'] as List<dynamic>)
            .firstWhere((id) => id != userId);

        // Get other user's details
        final userDoc =
            await _firestore.collection('users').doc(otherUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          userData['id'] = userDoc.id;
          final user = User.fromMap(userData);
          conversations.add({
            'conversationId': doc.id,
            'otherUser': user,
            'lastMessage': data['lastMessage'],
            'lastMessageTime': (data['lastMessageTime'] as Timestamp).toDate(),
            'unreadCount': data['unreadCount_$userId'] ?? 0,
          });
        }
      }

      return conversations;
    });
  }

  /// Mark messages as read in a conversation
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    final batch = _firestore.batch();

    // Get unread messages
    final unreadMessages = await _firestore
        .collection('direct_messages')
        .where('conversationId', isEqualTo: conversationId)
        .where('receiverId', isEqualTo: userId)
        .where('status', isNotEqualTo: MessageStatus.read.name)
        .get();

    // Mark each message as read
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {
        'status': MessageStatus.read.name,
        'isRead': true, // Backward compatibility
        'readAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    // Reset unread count in conversation
    batch.update(
      _firestore.collection('conversations').doc(conversationId),
      {'unreadCount_$userId': 0},
    );

    await batch.commit();

    // Track analytics
    _analytics.trackEngagement('messages_marked_read', parameters: {
      'conversation_id': conversationId,
      'user_id': userId,
      'message_count': unreadMessages.docs.length,
    });
  }

  /// Get unread message count for a user
  Future<int> getTotalUnreadCount(String userId) async {
    final conversations = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .get();

    int totalUnread = 0;
    for (final doc in conversations.docs) {
      final data = doc.data();
      totalUnread += (data['unreadCount_$userId'] ?? 0) as int;
    }

    return totalUnread;
  }

  /// Delete a message (only sender can delete)
  Future<void> deleteMessage(String messageId, String userId) async {
    final doc =
        await _firestore.collection('direct_messages').doc(messageId).get();

    if (!doc.exists) {
      throw Exception('Message not found');
    }

    final message = DirectMessage.fromMap(doc.data()!, doc.id);
    if (message.senderId != userId) {
      throw Exception('Only sender can delete messages');
    }

    await doc.reference.delete();

    // Track analytics
    _analytics.trackEngagement('message_deleted', parameters: {
      'message_id': messageId,
      'user_id': userId,
    });
  }

  /// Edit a message (only sender can edit, within 15 minutes)
  Future<void> editMessage(
      String messageId, String userId, String newContent) async {
    final doc =
        await _firestore.collection('direct_messages').doc(messageId).get();

    if (!doc.exists) {
      throw Exception('Message not found');
    }

    final message = DirectMessage.fromMap(doc.data()!, doc.id);
    if (message.senderId != userId) {
      throw Exception('Only sender can edit messages');
    }

    // Check if message is within 15 minutes of sending
    final timeDiff = DateTime.now().difference(message.timestamp);
    if (timeDiff.inMinutes > 15) {
      throw Exception('Messages can only be edited within 15 minutes');
    }

    // Only allow editing text messages
    if (message.type != DirectMessageType.text) {
      throw Exception('Only text messages can be edited');
    }

    await doc.reference.update({
      'content': newContent,
      'editedAt': Timestamp.fromDate(DateTime.now()),
      'isEdited': true,
    });

    // Track analytics
    _analytics.trackEngagement('message_edited', parameters: {
      'message_id': messageId,
      'user_id': userId,
    });
  }

  /// Update conversation metadata when a new message is sent
  Future<void> _updateConversationMetadata(
    String conversationId,
    String senderId,
    String receiverId,
    String lastMessage,
    DateTime timestamp,
  ) async {
    final conversationRef =
        _firestore.collection('conversations').doc(conversationId);

    final conversationDoc = await conversationRef.get();

    if (!conversationDoc.exists) {
      // Create new conversation
      await conversationRef.set({
        'participants': [senderId, receiverId],
        'lastMessage': lastMessage,
        'lastMessageTime': Timestamp.fromDate(timestamp),
        'createdAt': Timestamp.fromDate(timestamp),
        'unreadCount_$senderId': 0,
        'unreadCount_$receiverId': 1,
      });
    } else {
      // Update existing conversation
      final data = conversationDoc.data()!;
      final currentUnreadForReceiver =
          (data['unreadCount_$receiverId'] ?? 0) as int;

      await conversationRef.update({
        'lastMessage': lastMessage,
        'lastMessageTime': Timestamp.fromDate(timestamp),
        'unreadCount_$receiverId': currentUnreadForReceiver + 1,
      });
    }
  }

  /// Get conversation ID for two users
  String getConversationId(String userId1, String userId2) {
    return DirectMessage.createConversationId(userId1, userId2);
  }

  /// Check if a conversation exists between two users
  Future<bool> conversationExists(String userId1, String userId2) async {
    final conversationId = getConversationId(userId1, userId2);
    final doc =
        await _firestore.collection('conversations').doc(conversationId).get();
    return doc.exists;
  }

  /// Send push notification for new message
  Future<void> _sendMessageNotification(String conversationId, String senderId,
      String receiverId, String content) async {
    try {
      // Get sender's details for notification
      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      if (!senderDoc.exists) return;

      final senderData = senderDoc.data()!;
      senderData['id'] = senderDoc.id;
      final sender = User.fromMap(senderData);

      // Get receiver's FCM token
      final receiverDoc =
          await _firestore.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) return;

      final receiverData = receiverDoc.data()!;
      final fcmToken = receiverData['fcmToken'] as String?;

      if (fcmToken != null && fcmToken.isNotEmpty) {
        // Send notification via Firebase Cloud Messaging
        // Note: In a production app, this would typically be done via Cloud Functions
        // For now, we'll use the notification service for local notifications
        await _notificationService.notifyNewDirectMessage(
            conversationId, sender.displayName ?? 'Unknown User', content);
      }
    } catch (e) {
      // Log error but don't fail the message sending
      debugPrint('Failed to send message notification: $e');
    }
  }

  /// Search messages by content across all user's conversations
  Future<List<Map<String, dynamic>>> searchMessagesByContent(
    String userId,
    String query, {
    DateTime? startDate,
    DateTime? endDate,
    DirectMessageType? messageType,
    int limit = 50,
  }) async {
    // Get all conversations for the user
    final conversationsSnapshot = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .get();

    final results = <Map<String, dynamic>>[];
    final queryLower = query.toLowerCase();

    for (final conversationDoc in conversationsSnapshot.docs) {
      final conversationId = conversationDoc.id;
      final conversationData = conversationDoc.data();
      final participants = conversationData['participants'] as List<dynamic>;
      final otherUserId = participants.firstWhere((id) => id != userId);

      // Get user details
      final userDoc =
          await _firestore.collection('users').doc(otherUserId).get();
      if (!userDoc.exists) continue;

      final userData = userDoc.data()!;
      userData['id'] = userDoc.id;
      final otherUser = User.fromMap(userData);

      // Search messages in this conversation
      var messagesQuery = _firestore
          .collection('direct_messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('content', isGreaterThanOrEqualTo: queryLower)
          .where('content', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .orderBy('content')
          .orderBy('timestamp', descending: true)
          .limit(limit);

      // Apply date filters
      if (startDate != null) {
        messagesQuery = messagesQuery.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        messagesQuery = messagesQuery.where('timestamp',
            isLessThanOrEqualTo:
                Timestamp.fromDate(endDate.add(const Duration(days: 1))));
      }

      // Apply message type filter
      if (messageType != null) {
        messagesQuery =
            messagesQuery.where('type', isEqualTo: messageType.name);
      }

      final messagesSnapshot = await messagesQuery.get();

      for (final messageDoc in messagesSnapshot.docs) {
        final messageData = messageDoc.data();
        final message = DirectMessage.fromMap(messageData, messageDoc.id);

        results.add({
          'message': message,
          'conversationId': conversationId,
          'otherUser': otherUser,
          'conversation': {
            'conversationId': conversationId,
            'otherUser': otherUser,
            'lastMessage': conversationData['lastMessage'],
            'lastMessageTime':
                (conversationData['lastMessageTime'] as Timestamp).toDate(),
            'unreadCount': conversationData['unreadCount_$userId'] ?? 0,
          },
        });
      }
    }

    // Sort by timestamp (most recent first)
    results.sort((a, b) {
      final messageA = a['message'] as DirectMessage;
      final messageB = b['message'] as DirectMessage;
      return messageB.timestamp.compareTo(messageA.timestamp);
    });

    return results.take(limit).toList();
  }

  /// Add a reaction to a message
  Future<void> addReaction(
      String messageId, String emoji, String userId) async {
    final doc =
        await _firestore.collection('direct_messages').doc(messageId).get();

    if (!doc.exists) {
      throw Exception('Message not found');
    }

    final message = DirectMessage.fromMap(doc.data()!, doc.id);
    final updatedMessage = message.addReaction(emoji, userId);

    await doc.reference.update({
      'reactions': updatedMessage.reactions,
    });

    // Track analytics
    _analytics.trackEngagement('message_reaction_added', parameters: {
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    });
  }

  /// Remove a reaction from a message
  Future<void> removeReaction(
      String messageId, String emoji, String userId) async {
    final doc =
        await _firestore.collection('direct_messages').doc(messageId).get();

    if (!doc.exists) {
      throw Exception('Message not found');
    }

    final message = DirectMessage.fromMap(doc.data()!, doc.id);
    final updatedMessage = message.removeReaction(emoji, userId);

    await doc.reference.update({
      'reactions': updatedMessage.reactions,
    });

    // Track analytics
    _analytics.trackEngagement('message_reaction_removed', parameters: {
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    });
  }

  /// Mark a message as delivered (when received by recipient's device)
  Future<void> markMessageAsDelivered(String messageId, String userId) async {
    final doc =
        await _firestore.collection('direct_messages').doc(messageId).get();

    if (!doc.exists) {
      throw Exception('Message not found');
    }

    final message = DirectMessage.fromMap(doc.data()!, doc.id);

    // Only update if message is sent and user is the receiver
    if (message.status == MessageStatus.sent && message.receiverId == userId) {
      await doc.reference.update({
        'status': MessageStatus.delivered.name,
      });

      // Track analytics
      _analytics.trackEngagement('message_delivered', parameters: {
        'message_id': messageId,
        'receiver_id': userId,
      });
    }
  }

  /// Mark a message as read (when viewed by recipient)
  Future<void> markMessageAsRead(String messageId, String userId) async {
    final doc =
        await _firestore.collection('direct_messages').doc(messageId).get();

    if (!doc.exists) {
      throw Exception('Message not found');
    }

    final message = DirectMessage.fromMap(doc.data()!, doc.id);

    // Only update if message is not already read and user is the receiver
    if (message.status != MessageStatus.read && message.receiverId == userId) {
      await doc.reference.update({
        'status': MessageStatus.read.name,
        'readAt': FieldValue.serverTimestamp(),
      });

      // Track analytics
      _analytics.trackEngagement('message_read', parameters: {
        'message_id': messageId,
        'receiver_id': userId,
      });
    }
  }

  /// Mark all messages in a conversation as read for a user
  Future<void> markConversationAsRead(
      String userId1, String userId2, String currentUserId) async {
    final conversationId = DirectMessage.createConversationId(userId1, userId2);

    final query = _firestore
        .collection('direct_messages')
        .where('conversationId', isEqualTo: conversationId)
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isNotEqualTo: MessageStatus.read.name);

    final snapshot = await query.get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': MessageStatus.read.name,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    if (snapshot.docs.isNotEmpty) {
      await batch.commit();

      // Track analytics
      _analytics.trackEngagement('conversation_marked_read', parameters: {
        'conversation_id': conversationId,
        'user_id': currentUserId,
        'messages_count': snapshot.docs.length,
      });
    }
  }
}

// Room Messaging Functionality
extension RoomMessaging on MessagingService {
  /// Send a message to a room
  Future<void> sendRoomMessage({
    required String senderId,
    required String senderName,
    required String senderAvatarUrl,
    required String roomId,
    required String content,
    String type = 'text',
    String? mediaUrl,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final message = Message(
      id: '', // Will be set by Firestore
      roomId: roomId,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      type: type,
      content: content,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      metadata: metadata,
      mentionedUserIds: [], // TODO: Parse mentions from content
      reactions: [],
      isEdited: false,
      isTyping: false,
      status: MessageStatus.sent,
      timestamp: DateTime.now(),
    );

    // Add message to Firestore (using subcollection)
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .add(message.toMap());

    // Track analytics
    _analytics.trackEngagement('room_message_sent', parameters: {
      'room_id': roomId,
      'sender_id': senderId,
      'message_type': type,
    });
  }

  /// Get messages for a room
  Stream<List<Message>> getRoomMessages(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromMap(doc.data())).toList();
    });
  }

  /// Delete a room message
  Future<void> deleteRoomMessage(
      String roomId, String messageId, String senderId) async {
    final docRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId);
    final doc = await docRef.get();

    if (doc.exists) {
      final message = Message.fromMap(doc.data()!);
      if (message.senderId == senderId) {
        await docRef.delete();

        // Track analytics
        _analytics.trackEngagement('room_message_deleted', parameters: {
          'message_id': messageId,
          'room_id': message.roomId,
          'sender_id': senderId,
        });
      }
    }
  }

  /// Edit a room message
  Future<void> editRoomMessage(String roomId, String messageId, String senderId,
      String newContent) async {
    final docRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId);
    final doc = await docRef.get();

    if (doc.exists) {
      final message = Message.fromMap(doc.data()!);
      if (message.senderId == senderId) {
        await docRef.update({
          'content': newContent,
          'isEdited': true,
          'editedAt': Timestamp.fromDate(DateTime.now()),
        });

        // Track analytics
        _analytics.trackEngagement('room_message_edited', parameters: {
          'message_id': messageId,
          'room_id': message.roomId,
          'sender_id': senderId,
        });
      }
    }
  }

  /// Get typing users in a room
  Stream<List<String>> getTypingUsers(String roomId) {
    return _firestore
        .collection('room_typing')
        .doc(roomId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['typingUsers'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      }
      return [];
    });
  }
}
