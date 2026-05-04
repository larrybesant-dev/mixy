import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../messaging/providers/messaging_provider.dart';
import '../../../messaging/models/conversation_model.dart';
import '../models/schema_conversation.dart';

import '../../friends/providers/schema_friend_links_providers.dart'
    show schemaAuthUserIdProvider;

SchemaConversation _toSchemaConversation(Conversation conversation) {
  return SchemaConversation(
    id: conversation.id,
    participantIds: conversation.participantIds,
    type: conversation.type,
    status: conversation.status,
    createdAt: conversation.createdAt,
    isArchived: conversation.isArchived,
    pinnedBy: conversation.pinnedBy,
    lastReadAt: conversation.lastReadAt,
    lastMessageAt: conversation.lastMessageAt,
    lastMessagePreview: conversation.lastMessagePreview,
    lastMessageSenderId: conversation.lastMessageSenderId,
    lastMessageId: conversation.lastMessageId,
    groupName: conversation.groupName,
    groupAvatarUrl: conversation.groupAvatarUrl,
  );
}

/// Stream of all non-archived [SchemaConversation] documents for [userId],
/// ordered by most-recent message activity.
final schemaConversationsProvider = StreamProvider.autoDispose
    .family<List<SchemaConversation>, String>((ref, userId) {
      if (userId.isEmpty) {
        return const Stream<List<SchemaConversation>>.empty();
      }

      return ref.watch(rawConversationsStreamProvider(userId).stream).map((
        all,
      ) {
        return all
            .where((c) => !c.isArchived)
            .map(_toSchemaConversation)
            .toList(growable: false);
      });
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
      final userId = ref.watch(schemaAuthUserIdProvider).valueOrNull;
      if (userId == null || userId.isEmpty) {
        return const AsyncData(<SchemaConversation>[]);
      }
      return ref.watch(schemaConversationsProvider(userId));
    });
