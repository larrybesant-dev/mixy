import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/schema_conversation.dart';

// Re-use the auth provider already declared in the friends module to avoid
// creating a duplicate FirebaseAuth stream. If the schema_messenger layer
// ever gets a shared auth barrel, consolidate there.
import '../../friends/providers/schema_friend_links_providers.dart'
    show schemaAuthUserIdProvider;

final _schemaConversationsFirestoreProvider = Provider<FirebaseFirestore>((
  ref,
) {
  return FirebaseFirestore.instance;
});

/// Stream of all non-archived [SchemaConversation] documents for [userId],
/// ordered by most-recent message activity.
final schemaConversationsProvider = StreamProvider.autoDispose
    .family<List<SchemaConversation>, String>((ref, userId) {
      if (userId.isEmpty) {
        return const Stream<List<SchemaConversation>>.empty();
      }

      final firestore = ref.watch(_schemaConversationsFirestoreProvider);
      return firestore
          .collection('conversations')
          .where('participantIds', arrayContains: userId)
          .where('isArchived', isEqualTo: false)
          .orderBy('lastMessageAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map(SchemaConversation.fromDoc)
                .toList(growable: false),
          );
    });

/// Active (non-pending) conversations for [userId].
final schemaActiveConversationsProvider = Provider.autoDispose
    .family<List<SchemaConversation>, String>((ref, userId) {
      final convs =
          ref.watch(schemaConversationsProvider(userId)).valueOrNull ??
          const <SchemaConversation>[];
      return convs.where((c) => c.isActive).toList(growable: false);
    });

/// Map of {conversationId: hasUnread} for [userId].
/// A conversation has unread when [SchemaConversation.hasUnreadFor] returns true.
final schemaConversationUnreadFlagsProvider = Provider.autoDispose
    .family<Map<String, bool>, String>((ref, userId) {
      final convs =
          ref.watch(schemaConversationsProvider(userId)).valueOrNull ??
          const <SchemaConversation>[];
      return {for (final c in convs) c.id: c.hasUnreadFor(userId)};
    });

/// Authenticated user's conversations (convenience — infers userId from
/// auth state so callers do not need to thread userId manually).
final schemaMyConversationsProvider =
    Provider.autoDispose<AsyncValue<List<SchemaConversation>>>((ref) {
      final userId = ref.watch(schemaAuthUserIdProvider).value;
      if (userId == null || userId.isEmpty) {
        return const AsyncData(<SchemaConversation>[]);
      }
      return ref.watch(schemaConversationsProvider(userId));
    });
