import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../../services/messaging_presence_gateway.dart';
import '../models/user_presence.dart';

class PresenceService {
  PresenceService({
    required FirebaseFirestore firestore,
    MessagingPresenceGateway? gateway,
  }) : _gateway = gateway ?? MessagingPresenceGateway(firestore);

  final MessagingPresenceGateway _gateway;
  Timer? _presenceTimer;

  /// Start tracking user presence - updates every 30 seconds
  Future<void> startPresenceTracking(String userId) async {
    await _updatePresence(userId, isOnline: true);

    // Update presence every 30 seconds
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updatePresence(userId, isOnline: true);
    });
  }

  /// Stop tracking user presence
  Future<void> stopPresenceTracking(String userId) async {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    await _updatePresence(userId, isOnline: false);
  }

  /// Update user's last active timestamp
  Future<void> _updatePresence(
    String userId, {
    required bool isOnline,
    String? activity,
  }) async {
    try {
      await _gateway.updateUserPresence(userId, {
        'presence.lastActiveAt': FieldValue.serverTimestamp(),
        'presence.isOnline': isOnline,
        if (activity != null) 'presence.currentActivity': activity,
      }).onError((error, stackTrace) {
        // If document doesn't exist, create it
        return _gateway.setUserPresenceMerge(userId, {
          'presence': {
            'lastActiveAt': FieldValue.serverTimestamp(),
            'isOnline': isOnline,
            'currentActivity': activity,
          },
        });
      });
    } catch (e) {
      // Silently fail - presence is not critical
    }
  }

  /// Get a user's presence
  Future<UserPresence?> getUserPresence(String userId) async {
    try {
      final doc = await _gateway.getUser(userId);
      if (!doc.exists) return null;

      final presenceData = doc['presence'] as Map<String, dynamic>?;
      if (presenceData == null) return null;

      return UserPresence(
        userId: userId,
        lastActiveAt:
            (presenceData['lastActiveAt'] as Timestamp?)?.toDate() ??
                DateTime.now(),
        isOnline: presenceData['isOnline'] as bool? ?? false,
        currentActivity: presenceData['currentActivity'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Stream user's presence
  Stream<UserPresence?> getUserPresenceStream(String userId) {
    return Stream.periodic(const Duration(seconds: 10))
        .startWith(0)
        .asyncMap((_) async {
          try {
            final doc = await _gateway.getUser(userId);
            if (!doc.exists) return null;

            final presenceData = doc['presence'] as Map<String, dynamic>?;
            if (presenceData == null) return null;

            return UserPresence(
              userId: userId,
              lastActiveAt:
                  (presenceData['lastActiveAt'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
              isOnline: presenceData['isOnline'] as bool? ?? false,
              currentActivity: presenceData['currentActivity'] as String?,
            );
          } catch (_) {
            return null;
          }
        });
  }

  /// Mark a message as delivered
  Future<void> markMessageDelivered(
    String conversationId,
    String messageId,
  ) async {
    try {
      await _gateway.updateMessage(conversationId, messageId, {
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Fail silently
    }
  }

  /// Mark a message as read
  Future<void> markMessageRead(
    String conversationId,
    String messageId,
  ) async {
    try {
      await _gateway.updateMessage(conversationId, messageId, {
        'readAt': FieldValue.serverTimestamp(),
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Fail silently
    }
  }

  /// Mark conversation as read
  Future<void> markConversationRead(
    String conversationId,
    String userId,
  ) async {
    try {
      await _gateway
          .getMessagesFromOthers(conversationId, userId)
          .then((snapshot) async {
            for (final doc in snapshot.docs) {
              await markMessageRead(conversationId, doc.id);
            }
          });
    } catch (_) {
      // Fail silently
    }
  }

  /// Set typing indicator
  Future<void> setTyping(
    String conversationId,
    String userId,
    bool isTyping,
  ) async {
    try {
      if (isTyping) {
        await _gateway.updateConversation(conversationId, {
          'typingUsers': FieldValue.arrayUnion([userId]),
        });
      } else {
        await _gateway.updateConversation(conversationId, {
          'typingUsers': FieldValue.arrayRemove([userId]),
        });
      }
    } catch (_) {
      // Fail silently
    }
  }

  /// Stream typing users in a conversation
  Stream<List<String>> getTypingUsersStream(String conversationId) {
    return Stream.periodic(const Duration(seconds: 3))
        .startWith(0)
        .asyncMap((_) async {
          try {
            final doc = await _gateway.getConversation(conversationId);
            if (!doc.exists) return const <String>[];
            final typingUsers = doc.data()?['typingUsers'] as List?;
            return typingUsers?.cast<String>() ?? const <String>[];
          } catch (_) {
            return const <String>[];
          }
        });
  }

  void dispose() {
    _presenceTimer?.cancel();
  }
}

extension _StreamStartWith<T> on Stream<T> {
  Stream<T> startWith(T value) async* {
    yield value;
    yield* this;
  }
}
