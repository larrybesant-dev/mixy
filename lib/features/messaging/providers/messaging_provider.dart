import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/telemetry/app_telemetry.dart';
import 'package:mixvy/features/messaging/models/message_model.dart';
import '../models/conversation_model.dart';
import '../../../services/moderation_service.dart';
import '../../../presentation/providers/user_provider.dart';

String _newClientmessageId() =>
  '${DateTime.now().microsecondsSinceEpoch}-${DateTime.now().millisecondsSinceEpoch}';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// Stream of all conversations for current user, filtered to exclude blocked users.
final conversationsStreamProvider =
    StreamProvider.family<List<Conversation>, String>((ref, userId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('conversations')
      .where('participantIds', arrayContains: userId)
      .where('isArchived', isEqualTo: false)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .asyncMap((snapshot) async {
    final allConversations = snapshot.docs
        .map((doc) => Conversation.fromJson(doc.data(), doc.id))
        // Exclude pending (message requests) from the main list.
        .where((c) => c.status != 'pending')
        .toList();
    // Remove conversations where the other participant is blocked (either direction).
    try {
      final moderationService = ModerationService();
      final excludedIds = await moderationService.getExcludedUserIds(userId);
      if (excludedIds.isEmpty) return allConversations;
      final visibleConversations = allConversations.where((conv) {
        final others = conv.participantIds.where((id) => id != userId);
        return !others.any((id) => excludedIds.contains(id));
      }).toList();
      visibleConversations.sort((left, right) => _compareConversationsForUser(
            left,
            right,
            userId,
          ));
      return visibleConversations;
    } catch (_) {
      allConversations.sort((left, right) => _compareConversationsForUser(
            left,
            right,
            userId,
          ));
      return allConversations;
    }
  });
});

int _compareConversationsForUser(
  Conversation left,
  Conversation right,
  String userId,
) {
  final leftPinned = left.isPinnedFor(userId);
  final rightPinned = right.isPinnedFor(userId);
  if (leftPinned != rightPinned) {
    return leftPinned ? -1 : 1;
  }

  final leftTimestamp = left.lastMessageAt ?? left.createdAt;
  final rightTimestamp = right.lastMessageAt ?? right.createdAt;
  return rightTimestamp.compareTo(leftTimestamp);
}

// Stream of pending message requests for the current user.
final requestsStreamProvider =
    StreamProvider.family<List<Conversation>, String>((ref, userId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('conversations')
      .where('participantIds', arrayContains: userId)
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Conversation.fromJson(doc.data(), doc.id))
          .toList());
});

// Stream of a single conversation document (used for read receipt tracking)
final conversationDocProvider =
    StreamProvider.family<Conversation?, String>((ref, conversationId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('conversations')
      .doc(conversationId)
      .snapshots()
      .map((snap) => snap.exists ? Conversation.fromJson(snap.data()!, snap.id) : null);
});

// Stream of message in a conversation
final messagestreamProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, conversationId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => MessageModel.fromJson(doc.data(), doc.id))
        .toList()
        .reversed
        .toList();
  });
});

// ── Paginated message history ──────────────────────────────────────────────
// Loads older message on demand (load-more). The live stream above covers the
// most recent 50; this provider fetches pages of 30 preceding those.

const _kmessagePageSize = 30;

class _Paginatedmessagestate {
  const _Paginatedmessagestate({
    this.oldermessage = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.oldestDoc,
  });

  final List<MessageModel> oldermessage;
  final bool isLoading;
  final bool hasMore;
  final DocumentSnapshot? oldestDoc;

  _Paginatedmessagestate copyWith({
    List<MessageModel>? oldermessage,
    bool? isLoading,
    bool? hasMore,
    DocumentSnapshot? oldestDoc,
    bool clearOldest = false,
  }) {
    return _Paginatedmessagestate(
      oldermessage: oldermessage ?? this.oldermessage,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      oldestDoc: clearOldest ? null : (oldestDoc ?? this.oldestDoc),
    );
  }
}

class _PaginatedmessageNotifier
    extends StateNotifier<_Paginatedmessagestate> {
  _PaginatedmessageNotifier(this._firestore, this._conversationId)
      : super(const _Paginatedmessagestate());

  final FirebaseFirestore _firestore;
  final String _conversationId;

  Future<void> loadMore(DocumentSnapshot? liveAnchor) async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    try {
      // Start after the earliest doc we already have, or the live-stream anchor.
      final cursor = state.oldestDoc ?? liveAnchor;
      var query = _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(_kmessagePageSize);

      if (cursor != null) query = query.startAfterDocument(cursor);

      final snapshot = await query.get();
      final fetched = snapshot.docs
          .map((doc) => MessageModel.fromJson(doc.data(), doc.id))
          .toList()
          .reversed
          .toList();

      state = state.copyWith(
        oldermessage: [...fetched, ...state.oldermessage],
        isLoading: false,
        hasMore: snapshot.docs.length == _kmessagePageSize,
        oldestDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : state.oldestDoc,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final paginatedmessageProvider = StateNotifierProvider.autoDispose
    .family<_PaginatedmessageNotifier, _Paginatedmessagestate, String>(
  (ref, conversationId) => _PaginatedmessageNotifier(
    ref.watch(firestoreProvider),
    conversationId,
  ),
);

// Controller for sending message
final messagingControllerProvider =
    Provider<MessagingController>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return MessagingController(firestore: firestore);
});

class ConversationScrollMemoryNotifier
    extends StateNotifier<Map<String, double>> {
  ConversationScrollMemoryNotifier() : super(const <String, double>{});

  void setOffset(String conversationId, double offset) {
    state = <String, double>{
      ...state,
      conversationId: offset,
    };
  }
}

final conversationScrollMemoryProvider = StateNotifierProvider<
    ConversationScrollMemoryNotifier, Map<String, double>>(
  (ref) => ConversationScrollMemoryNotifier(),
);

class MessagingController {
  static const int messageRetentionDays = 90;
  final FirebaseFirestore _firestore;

  MessagingController({required FirebaseFirestore firestore}) : _firestore = firestore;

  Future<void> sendmessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
    required String content,
    String? clientmessageId,
  }) async {
    AppTelemetry.logAction(
      domain: 'messaging',
      action: 'send_message',
      message: 'Message send started.',
      roomId: conversationId,
      userId: senderId,
      result: 'start',
    );

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: messageRetentionDays));
    final resolvedClientmessageId = clientmessageId ?? _newClientmessageId();
    final messageRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc();

    try {
      // Add message to message subcollection
      await messageRef.set({
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatarUrl': senderAvatarUrl,
        'content': content,
        'clientmessageId': resolvedClientmessageId,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isDeleted': false,
        'readBy': [senderId],
      });

      // Update conversation with last message info
      final convRef = _firestore.collection('conversations').doc(conversationId);
      await convRef.update({
        'lastMessageId': messageRef.id,
        'lastMessagePreview': content,
        'lastMessageSenderId': senderId,
        'lastMessageAt': Timestamp.fromDate(now),
        'lastMessageClientMessageId': resolvedClientmessageId,
      });

      AppTelemetry.logAction(
        domain: 'messaging',
        action: 'send_message',
        message: 'Message send completed.',
        roomId: conversationId,
        userId: senderId,
        result: 'success',
      );
    } catch (error, stackTrace) {
      AppTelemetry.logAction(
        level: 'error',
        domain: 'messaging',
        action: 'send_message',
        message: 'Message send failed.',
        roomId: conversationId,
        userId: senderId,
        result: 'failure',
        metadata: <String, Object?>{
          'client_message_id': resolvedClientmessageId,
        },
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<String> createDirectConversation({
    required String userId1,
    required String user1Name,
    required String? user1AvatarUrl,
    required String userId2,
    required String user2Name,
    required String? user2AvatarUrl,
  }) async {
    // Prevent messaging blocked users.
    final isBlocked = await ModerationService().hasBlockingRelationship(userId1, userId2);
    if (isBlocked) throw Exception('Cannot start a conversation with this user.');

    // Check if conversation already exists
    final existing = await _firestore
        .collection('conversations')
        .where('type', isEqualTo: 'direct')
        .where('participantIds', arrayContains: userId1)
        .get();

    for (final doc in existing.docs) {
      final conv = Conversation.fromJson(doc.data(), doc.id);
      if (conv.participantIds.contains(userId2)) {
        return doc.id;
      }
    }

    // Create new conversation
    final now = DateTime.now();
    final docRef = await _firestore.collection('conversations').add({
      'type': 'direct',
      'participantIds': [userId1, userId2],
      'participantNames': {
        userId1: user1Name,
        userId2: user2Name,
      },
      'createdAt': Timestamp.fromDate(now),
      'lastReadAt': {
        userId1: Timestamp.fromDate(now),
        userId2: Timestamp.fromDate(now),
      },
      'isArchived': false,
      'status': 'active',
    });

    return docRef.id;
  }

  Future<String> createGroupConversation({
    required String groupName,
    required String? groupAvatarUrl,
    required List<String> participantIds,
    required Map<String, String> participantNames,
  }) async {
    final now = DateTime.now();
    final lastReadAt = <String, dynamic>{};
    for (final id in participantIds) {
      lastReadAt[id] = Timestamp.fromDate(now);
    }

    final docRef = await _firestore.collection('conversations').add({
      'type': 'group',
      'groupName': groupName,
      'groupAvatarUrl': groupAvatarUrl,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'createdAt': Timestamp.fromDate(now),
      'lastReadAt': lastReadAt,
      'isArchived': false,
      'status': 'active',
    });

    return docRef.id;
  }

  Future<void> markAsRead({
    required String conversationId,
    required String userId,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({
      'lastReadAt.$userId': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deletemessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'isDeleted': true});
  }

  Future<void> archiveConversation({
    required String conversationId,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({'isArchived': true});
  }

  Future<void> setConversationPinned({
    required String conversationId,
    required String userId,
    required bool pinned,
  }) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'pinnedBy': pinned
          ? FieldValue.arrayUnion([userId])
          : FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> acceptmessageRequest({
    required String conversationId,
  }) async {
    await _firestore
        .collection('conversations')
        .doc(conversationId)
        .update({'status': 'active'});
  }

  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String currentUserId,
    required String emoji,
  }) async {
    final docRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .doc(currentUserId);
    final existing = await docRef.get();
    if (existing.exists && existing.data()?['emoji'] == emoji) {
      await docRef.delete();
    } else {
      await docRef.set({'emoji': emoji, 'createdAt': FieldValue.serverTimestamp()});
    }
  }

  /// Updates the typing heartbeat for [userId] in [conversationId].
  /// Writes to a lightweight ephemeral subcollection instead of the
  /// conversation document so message sends do not trigger the typing stream.
  Future<void> updateTypingStatus({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) async {
    final typingRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('ephemeral')
        .doc('typing');
    if (isTyping) {
      await typingRef.set(
        {'users.$userId': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } else {
      await typingRef.update({'users.$userId': FieldValue.delete()});
    }
  }
}

// ── Typing status ─────────────────────────────────────────────────────────

/// Reactions on a message keyed by userId → emoji string.
final messageReactionsProvider = StreamProvider.family<Map<String, String>,
    ({String conversationId, String messageId})>((ref, params) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('conversations')
      .doc(params.conversationId)
      .collection('messages')
      .doc(params.messageId)
      .collection('reactions')
      .snapshots()
      .map((snap) {
    final result = <String, String>{};
    for (final doc in snap.docs) {
      final emoji = doc.data()['emoji'] as String?;
      if (emoji != null) result[doc.id] = emoji;
    }
    return result;
  });
});

/// Emits the set of user IDs that are currently typing in [conversationId].
/// Subscribes to the lightweight `ephemeral/typing` subcollection doc so
/// message sends (which mutate the parent conversation doc) do not trigger
/// unnecessary re-emits here.
final typingUsersProvider =
    StreamProvider.autoDispose.family<Set<String>, String>((ref, conversationId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('conversations')
      .doc(conversationId)
      .collection('ephemeral')
      .doc('typing')
      .snapshots()
      .map((doc) {
    final raw = doc.data()?['users'] as Map<String, dynamic>?;
    if (raw == null) return <String>{};
    final now = DateTime.now();
    return raw.entries
        .where((e) {
          final ts = e.value;
          if (ts is Timestamp) {
            // Write timeout is 4 s + up to ~2 s network round-trip.
            // Read TTL must be > write timeout to prevent premature flicker.
            return now.difference(ts.toDate()).inSeconds < 10;
          }
          return false;
        })
        .map((e) => e.key)
        .toSet();
  });
});

/// Count of conversations that have at least one unread message for the current
/// user. Derived from the live conversations stream — stays real-time.
final unreadmessageCountProvider = Provider<int>((ref) {
  final user = ref.watch(userProvider);
  if (user == null) return 0;
  return ref
      .watch(conversationsStreamProvider(user.id))
      .whenData(
        (convs) => convs.where((c) => c.hasUnreadmessage(user.id)).length,
      )
      .valueOrNull ??
      0;
});
