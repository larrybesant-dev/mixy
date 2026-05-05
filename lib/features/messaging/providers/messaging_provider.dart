import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/firestore/firestore_error_utils.dart';
import 'package:mixvy/core/telemetry/app_telemetry.dart';
import 'package:mixvy/core/services/feature_gate_service.dart';
import 'package:mixvy/models/presence_model.dart';
import 'package:mixvy/features/messaging/models/message_model.dart';
import '../../../services/presence_repository.dart';
import '../models/conversation_model.dart';
import '../../../services/moderation_service.dart';
import '../../../presentation/providers/user_provider.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import '../../../core/constants/query_policy.dart';
import 'package:mixvy/core/streams/stream_lifecycle_manager.dart';

// Include userId and a random suffix to prevent cross-user collisions when
// two senders hit the same microsecond (e.g. in FloatingWhisperPanel paths).
String _newClientmessageId(String userId) {
  final rnd = math.Random().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
  return '${DateTime.now().microsecondsSinceEpoch}-${userId.hashCode.toUnsigned(32).toRadixString(16)}-$rnd';
}

String _effectiveMessagingUserId(String userId) {
  String? authUid;
  try {
    authUid = FirebaseAuth.instance.currentUser?.uid.trim();
  } catch (_) {
    // Auth platform unavailable (e.g. unit test environment).
  }
  if (authUid != null && authUid.isNotEmpty) {
    return authUid;
  }
  return userId.trim();
}

String _validatedMessagingActorId(String candidateUserId) {
  final normalizedCandidate = candidateUserId.trim();
  String? authUid;
  try {
    authUid = FirebaseAuth.instance.currentUser?.uid.trim();
  } catch (_) {
    // Auth platform unavailable (e.g. unit test environment).
  }

  if (normalizedCandidate.isEmpty) {
    throw Exception('Not signed in.');
  }

  if (authUid != null && authUid.isNotEmpty) {
    if (normalizedCandidate != authUid) {
      throw Exception('Identity mismatch for messaging actor.');
    }
  }

  return normalizedCandidate;
}

// Single raw realtime stream for all conversation documents of a user.
final rawConversationsStreamProvider = StreamProvider.autoDispose
    .family<List<Conversation>, String>((ref, userId) {
      final firestore = ref.watch(firestoreProvider);
      final lifecycle = ref.watch(streamLifecycleManagerProvider);
      final resolvedUserId = _effectiveMessagingUserId(userId);
      return lifecycle.bind(
        key: 'conversations:$resolvedUserId',
        routePrefixes: const <String>['/messages', '/new-message', '/chat'],
        create: () => firestore
            .collection('conversations')
            .where('participantIds', arrayContains: resolvedUserId)
            .orderBy('lastMessageAt', descending: true)
            .limit(QueryPolicy.conversationsLimit)
            .snapshots()
            .handleError((error, stackTrace) {
              logFirestoreError(
                context: 'messaging.rawConversationsStreamProvider',
                error: error,
                stackTrace: stackTrace,
              );
            })
            .map(
              (snapshot) => snapshot.docs
                  .map((doc) => Conversation.fromJson(doc.data(), doc.id))
                  .toList(growable: false),
            ),
      );
    });

// Active conversations derived from the single raw stream.
final conversationsStreamProvider = Provider.autoDispose
    .family<AsyncValue<List<Conversation>>, String>((ref, userId) {
      final resolvedUserId = _effectiveMessagingUserId(userId);
      return ref.watch(rawConversationsStreamProvider(userId)).whenData((all) {
        final active = all
            .where((c) => !c.isArchived && c.status != 'pending')
            .toList();
        active.sort(
          (left, right) =>
              _compareConversationsForUser(left, right, resolvedUserId),
        );
        return active;
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
final requestsStreamProvider = Provider.autoDispose
    .family<AsyncValue<List<Conversation>>, String>((ref, userId) {
      return ref.watch(rawConversationsStreamProvider(userId)).whenData((all) {
        final pending = all
            .where((c) => !c.isArchived && c.status == 'pending')
            .toList();
        pending.sort(
          (left, right) => right.createdAt.compareTo(left.createdAt),
        );
        return pending;
      });
    });

// Stream of a single conversation document (used for read receipt tracking)
final conversationDocProvider = StreamProvider.autoDispose
    .family<Conversation?, String>((ref, conversationId) {
      final firestore = ref.watch(firestoreProvider);
      final lifecycle = ref.watch(streamLifecycleManagerProvider);
      return lifecycle.bind(
        key: 'conversation-doc:$conversationId',
        routePrefixes: const <String>['/chat'],
        create: () => firestore
            .collection('conversations')
            .doc(conversationId)
            .snapshots()
            .map((snap) {
              if (!snap.exists) {
                return null;
              }
              final data = snap.data();
              if (data == null) {
                return null;
              }
              return Conversation.fromJson(data, snap.id);
            }),
      );
    });

// Stream of messages in a conversation.
// createdAt is a server timestamp, so Firestore is the ordering authority.
// During the pending-write window (before server ack), Firestore's local SDK
// estimates the server timestamp from device time for ordering \u2014 this is
// correct behavior. We sort stable-ly so pending writes stay in send order.
final messageStreamProvider = StreamProvider.autoDispose
    .family<List<MessageModel>, String>((ref, conversationId) {
      final firestore = ref.watch(firestoreProvider);
      final lifecycle = ref.watch(streamLifecycleManagerProvider);
      return lifecycle.bind(
        key: 'messages:$conversationId',
        routePrefixes: const <String>['/chat'],
        create: () => firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .orderBy('createdAt', descending: false)
            .limit(QueryPolicy.messagesLimit)
            .snapshots(includeMetadataChanges: true)
            .handleError((error, stackTrace) {
              logFirestoreError(
                context: 'messaging.messageStreamProvider',
                error: error,
                stackTrace: stackTrace,
              );
            })
            .map((snapshot) {
              final docs = snapshot.docs.toList()
                ..sort((a, b) {
                  final aData = a.data();
                  final bData = b.data();
                  final aCreatedAt = aData['createdAt'];
                  final bCreatedAt = bData['createdAt'];

                  if (aCreatedAt is Timestamp && bCreatedAt is Timestamp) {
                    final cmp = aCreatedAt.compareTo(bCreatedAt);
                    if (cmp != 0) return cmp;
                  }

                  final aClient = aData['clientSentAt'];
                  final bClient = bData['clientSentAt'];
                  if (aClient is Timestamp && bClient is Timestamp) {
                    final cmp = aClient.compareTo(bClient);
                    if (cmp != 0) return cmp;
                  }

                  return a.id.compareTo(b.id);
                });

              return docs
                  .map((doc) => MessageModel.fromJson(doc.data(), doc.id))
                  .toList(growable: false);
            }),
      );
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

class _PaginatedmessageNotifier extends StateNotifier<_Paginatedmessagestate> {
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
        oldestDoc: snapshot.docs.isNotEmpty
            ? snapshot.docs.last
            : state.oldestDoc,
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
final messagingControllerProvider = Provider<MessagingController>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return MessagingController(
    firestore: firestore,
    isMessagingEnabled: () {
      try {
        return ref.read(featureGateControllerProvider).enableMessaging;
      } on AssertionError {
        return true;
      }
    },
  );
});

class ConversationScrollMemoryNotifier
    extends StateNotifier<Map<String, double>> {
  ConversationScrollMemoryNotifier() : super(const <String, double>{});

  void setOffset(String conversationId, double offset) {
    state = <String, double>{...state, conversationId: offset};
  }
}

final conversationScrollMemoryProvider =
    StateNotifierProvider<
      ConversationScrollMemoryNotifier,
      Map<String, double>
    >((ref) => ConversationScrollMemoryNotifier());

String buildPresenceBatchKey(Iterable<String> userIds) {
  final normalized =
      userIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
  return normalized.join('|');
}

final batchedPresenceProvider = StreamProvider.autoDispose
    .family<Map<String, PresenceModel>, String>((ref, batchKey) {
      if (batchKey.trim().isEmpty) {
        return Stream<Map<String, PresenceModel>>.value(
          const <String, PresenceModel>{},
        );
      }

      final userIds = batchKey
          .split('|')
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      if (userIds.isEmpty) {
        return Stream<Map<String, PresenceModel>>.value(
          const <String, PresenceModel>{},
        );
      }

      return ref.watch(presenceRepositoryProvider).watchUsersPresence(userIds);
    });

// ── Draft message cache ───────────────────────────────────────────────────────
// Persists unsent message text keyed by conversationId across tab switches.
// NOT autoDispose — must survive the chat pane being disposed when the user
// navigates away, so the draft is restored when they return.
class DraftCacheNotifier extends StateNotifier<Map<String, String>> {
  DraftCacheNotifier() : super(const <String, String>{});

  void setDraft(String conversationId, String text) {
    if (text.isEmpty) {
      // Remove empty drafts to keep the map small.
      if (!state.containsKey(conversationId)) return;
      final updated = Map<String, String>.of(state)..remove(conversationId);
      state = updated;
    } else {
      if (state[conversationId] == text) return;
      state = <String, String>{...state, conversationId: text};
    }
  }

  String getDraft(String conversationId) => state[conversationId] ?? '';

  void clearDraft(String conversationId) {
    if (!state.containsKey(conversationId)) return;
    final updated = Map<String, String>.of(state)..remove(conversationId);
    state = updated;
  }
}

final draftCacheProvider =
    StateNotifierProvider<DraftCacheNotifier, Map<String, String>>(
      (ref) => DraftCacheNotifier(),
    );

class MessagingController {
  static const int messageRetentionDays = 90;
  final FirebaseFirestore _firestore;
  final bool Function()? _isMessagingEnabled;

  MessagingController({
    required FirebaseFirestore firestore,
    bool Function()? isMessagingEnabled,
  }) : _firestore = firestore,
       _isMessagingEnabled = isMessagingEnabled;

  bool _messagingEnabled() {
    final resolver = _isMessagingEnabled;
    if (resolver == null) {
      return true;
    }

    try {
      return resolver();
    } on AssertionError {
      return true;
    }
  }

  Future<void> sendmessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
    required String content,
    String? clientmessageId,
  }) async {
    if (!_messagingEnabled()) {
      AppTelemetry.logAction(
        level: 'warning',
        domain: 'control_plane',
        action: 'feature_blocked',
        message: 'Messaging send blocked by runtime gate.',
        roomId: conversationId,
        userId: senderId,
        result: 'blocked',
        metadata: <String, Object?>{'feature': 'messaging'},
      );
      throw StateError('Messaging is temporarily disabled for maintenance.');
    }

    final authoritativeSenderId = _validatedMessagingActorId(senderId);

    AppTelemetry.logAction(
      domain: 'messaging',
      action: 'send_message',
      message: 'Message send started.',
      roomId: conversationId,
      userId: authoritativeSenderId,
      result: 'start',
    );

    final resolvedClientmessageId =
        clientmessageId ?? _newClientmessageId(authoritativeSenderId);
    // expiresAt is a retention deadline — compute from client time is acceptable.
    final expiresAt = DateTime.now().add(
      const Duration(days: messageRetentionDays),
    );
    final convRef = _firestore.collection('conversations').doc(conversationId);
    final messageRef = convRef.collection('messages').doc();

    try {
      // Atomic batch: message write + conversation metadata update in one commit.
      // If either write fails the entire operation is rolled back, preventing
      // orphaned message documents with a stale conversation lastMessageAt.
      final batch = _firestore.batch();

      // Add message to message subcollection.
      // createdAt uses FieldValue.serverTimestamp() so Firestore is the
      // ordering authority — eliminates client clock skew and burst reordering.
      batch.set(messageRef, {
        'conversationId': conversationId,
        'senderId': authoritativeSenderId,
        'senderName': senderName,
        'senderAvatarUrl': senderAvatarUrl,
        'content': content,
        'clientmessageId': resolvedClientmessageId,
        'createdAt': FieldValue.serverTimestamp(),
        'clientSentAt': Timestamp.now(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'isDeleted': false,
        'readBy': [authoritativeSenderId],
      });

      // Update conversation with last message info.
      // lastMessageAt uses serverTimestamp so conversation list sorts correctly
      // even when messages arrive from multiple devices simultaneously.
      batch.update(convRef, {
        'lastMessageId': messageRef.id,
        'lastMessagePreview': content,
        'lastMessageSenderId': authoritativeSenderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageClientMessageId': resolvedClientmessageId,
      });

      await batch.commit();

      AppTelemetry.logAction(
        domain: 'messaging',
        action: 'send_message',
        message: 'Message send completed.',
        roomId: conversationId,
        userId: authoritativeSenderId,
        result: 'success',
      );
    } catch (error, stackTrace) {
      AppTelemetry.logAction(
        level: 'error',
        domain: 'messaging',
        action: 'send_message',
        message: 'Message send failed.',
        roomId: conversationId,
        userId: authoritativeSenderId,
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
    if (!_messagingEnabled()) {
      AppTelemetry.logAction(
        level: 'warning',
        domain: 'control_plane',
        action: 'feature_blocked',
        message: 'Direct conversation creation blocked by runtime gate.',
        userId: userId1,
        result: 'blocked',
        metadata: <String, Object?>{'feature': 'messaging'},
      );
      throw StateError('Messaging is temporarily disabled for maintenance.');
    }

    final currentUserId = _validatedMessagingActorId(userId1);
    final targetUserId = userId2.trim();
    if (targetUserId.isEmpty) throw Exception('Target user is required.');
    if (currentUserId == targetUserId) {
      throw Exception('Cannot start a conversation with yourself.');
    }

    // Prevent messaging blocked users.
    final isBlocked = await ModerationService().hasBlockingRelationship(
      currentUserId,
      targetUserId,
    );
    if (isBlocked) {
      throw Exception('Cannot start a conversation with this user.');
    }

    // Deterministic conversation ID: sort participant UIDs so both orderings
    // produce the same document path. Using set() with merge:true makes this
    // fully idempotent — concurrent calls from different devices cannot create
    // duplicate conversation documents (eliminates the prior TOCTOU race).
    final sortedIds = ([currentUserId, targetUserId]..sort());
    final deterministicId = 'dm_${sortedIds[0]}_${sortedIds[1]}';
    final convRef = _firestore.collection('conversations').doc(deterministicId);

    await convRef.set({
      'type': 'direct',
      'participantIds': [currentUserId, targetUserId],
      'participantNames': {currentUserId: user1Name, targetUserId: user2Name},
      'createdAt': FieldValue.serverTimestamp(),
      'lastReadAt': {
        currentUserId: FieldValue.serverTimestamp(),
        targetUserId: FieldValue.serverTimestamp(),
      },
      'isArchived': false,
      'status': 'active',
    }, SetOptions(merge: true));

    return deterministicId;
  }

  Future<String> createGroupConversation({
    required String groupName,
    required String? groupAvatarUrl,
    required List<String> participantIds,
    required Map<String, String> participantNames,
  }) async {
    if (!_messagingEnabled()) {
      AppTelemetry.logAction(
        level: 'warning',
        domain: 'control_plane',
        action: 'feature_blocked',
        message: 'Group conversation creation blocked by runtime gate.',
        result: 'blocked',
        metadata: <String, Object?>{'feature': 'messaging'},
      );
      throw StateError('Messaging is temporarily disabled for maintenance.');
    }

    final lastReadAt = <String, dynamic>{
      for (final id in participantIds) id: FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore.collection('conversations').add({
      'type': 'group',
      'groupName': groupName,
      'groupAvatarUrl': groupAvatarUrl,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'createdAt': FieldValue.serverTimestamp(),
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
    final actorUserId = _validatedMessagingActorId(userId);
    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);
    try {
      await conversationRef.update({
        'lastReadAt.$actorUserId': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error, stackTrace) {
      if (error.code != 'not-found') {
        rethrow;
      }
      AppTelemetry.logAction(
        level: 'warning',
        domain: 'messaging',
        action: 'mark_as_read_conversation_missing',
        message: 'Conversation document missing while marking as read.',
        roomId: conversationId,
        userId: actorUserId,
        error: error,
        stackTrace: stackTrace,
      );
      await conversationRef.set({
        'lastReadAt': {actorUserId: FieldValue.serverTimestamp()},
        'participantIds': [actorUserId],
      }, SetOptions(merge: true));
    }
  }

  Future<void> deletemessage({
    required String conversationId,
    required String messageId,
  }) async {
    // Client deletes are blocked by Firestore rules in MVP.
    // Keep this as a no-op to avoid user-facing permission failures.
    return;
  }

  Future<void> archiveConversation({required String conversationId}) async {
    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);
    try {
      await conversationRef.update({
        'isArchived': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error, stackTrace) {
      if (error.code != 'not-found') {
        rethrow;
      }
      AppTelemetry.logAction(
        level: 'warning',
        domain: 'messaging',
        action: 'archive_conversation_missing',
        message: 'Conversation document missing while archiving.',
        roomId: conversationId,
        error: error,
        stackTrace: stackTrace,
      );
      throw StateError('Cannot archive missing conversation: $conversationId');
    }
  }

  Future<void> setConversationPinned({
    required String conversationId,
    required String userId,
    required bool pinned,
  }) async {
    // Pinned metadata requires a rule update to allow updating 'pinnedBy' field.
    // For now, keeping as no-op until rules are refined for engagement features.
    return;
  }

  Future<void> acceptmessageRequest({required String conversationId}) async {
    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);
    try {
      await conversationRef.update({
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error, stackTrace) {
      if (error.code != 'not-found') {
        rethrow;
      }
      AppTelemetry.logAction(
        level: 'warning',
        domain: 'messaging',
        action: 'accept_request_conversation_missing',
        message: 'Conversation document missing while accepting request.',
        roomId: conversationId,
        error: error,
        stackTrace: stackTrace,
      );
      throw StateError(
        'Cannot accept request for missing conversation: $conversationId',
      );
    }
  }

  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String currentUserId,
    required String emoji,
  }) async {
    final actorUserId = _validatedMessagingActorId(currentUserId);
    final reactionRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .collection('reactions')
        .doc(actorUserId);

    final snap = await reactionRef.get();
    if (snap.exists && snap.data()?['emoji'] == emoji) {
      await reactionRef.delete();
    } else {
      await reactionRef.set({
        'emoji': emoji,
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
    final actorUserId = _validatedMessagingActorId(userId);
    final docRef = _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('ephemeral')
        .doc('typing');

    if (isTyping) {
      await docRef.set({
        'users': {actorUserId: FieldValue.serverTimestamp()},
      }, SetOptions(merge: true));
    } else {
      await docRef.set({
        'users.$actorUserId': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
  }
}

// ── Typing status ─────────────────────────────────────────────────────────

/// Reactions on a message keyed by userId → emoji string.
final messageReactionsProvider = StreamProvider.autoDispose
    .family<Map<String, String>, ({String conversationId, String messageId})>((
      ref,
      params,
    ) {
      final firestore = ref.watch(firestoreProvider);
      final lifecycle = ref.watch(streamLifecycleManagerProvider);
      return lifecycle.bind(
        key: 'message-reactions:${params.conversationId}:${params.messageId}',
        routePrefixes: const <String>['/chat'],
        create: () => firestore
            .collection('conversations')
            .doc(params.conversationId)
            .collection('messages')
            .doc(params.messageId)
            .collection('reactions')
            .limit(QueryPolicy.messageReactionsLimit)
            .snapshots()
            .map((snap) {
              final result = <String, String>{};
              for (final doc in snap.docs) {
                final emoji = doc.data()['emoji'] as String?;
                if (emoji != null) result[doc.id] = emoji;
              }
              return result;
            }),
      );
    });

/// Emits the set of user IDs that are currently typing in [conversationId].
/// Subscribes to the lightweight `ephemeral/typing` subcollection doc so
/// message sends (which mutate the parent conversation doc) do not trigger
/// unnecessary re-emits here.
final typingUsersProvider = StreamProvider.autoDispose.family<Set<String>, String>((
  ref,
  conversationId,
) {
  final firestore = ref.watch(firestoreProvider);
  final lifecycle = ref.watch(streamLifecycleManagerProvider);
  return lifecycle.bind(
    key: 'typing:$conversationId',
    routePrefixes: const <String>['/chat'],
    create: () => firestore
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
                  return now.difference(ts.toDate()).inSeconds < 10;
                }
                return false;
              })
              .map((e) => e.key)
              .toSet();
        }),
  );
});

/// Count of conversations that have at least one unread message for the current
/// user. Derived from the live conversations stream — stays real-time.
final unreadmessageCountProvider = Provider.autoDispose<int>((ref) {
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

/// Optimized provider that filters conversations by the user's block list.
/// Hardening: separates the raw Firestore stream from the expensive moderation logic.
final filteredConversationsProvider =
    Provider.autoDispose.family<AsyncValue<List<Conversation>>, String>((ref, userId) {
  final allAsync = ref.watch(rawConversationsStreamProvider(userId));
  final excludedAsync = ref.watch(excludedUserIdsProvider(userId));

  return allAsync.when(
    data: (all) {
      return excludedAsync.when(
        data: (excludedIds) {
          final active = all.where((c) => c.status != 'pending');

          if (excludedIds.isEmpty) {
            final sorted = active.toList();
            sorted.sort((left, right) => _compareConversationsForUser(left, right, userId));
            return AsyncValue.data(sorted);
          }

          final visible = active.where((conv) {
            final others = conv.participantIds.where((id) => id != userId);
            return !others.any((id) => excludedIds.contains(id));
          }).toList();

          visible.sort((left, right) => _compareConversationsForUser(left, right, userId));
          return AsyncValue.data(visible);
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.data(
          all
              .where((c) => c.status != 'pending')
              .toList()
            ..sort((left, right) => _compareConversationsForUser(left, right, userId)),
        ),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Watches the excluded user IDs for a given user, used for filtering conversations.
final excludedUserIdsProvider =
    FutureProvider.autoDispose.family<Set<String>, String>((ref, userId) async {
  return ModerationService().getExcludedUserIds(userId);
});
