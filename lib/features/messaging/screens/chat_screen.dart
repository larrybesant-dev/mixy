import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feed/providers/user_providers.dart' as feed_user;
import '../panes/chat_pane_view.dart';
import '../providers/messaging_provider.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.username,
    this.avatarUrl,
  });

  final String conversationId;
  final String userId;
  final String username;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref
        .watch(
          conversationDocProvider(conversationId),
        )
        .valueOrNull;
    final otherUserId = conversation?.participantIds.firstWhere(
      (participantId) => participantId != userId,
      orElse: () => '',
    );
    final peerUsername = otherUserId == null || otherUserId.isEmpty
        ? ''
        : ref
                .watch(feed_user.userProvider(otherUserId))
                .valueOrNull
                ?.username
                .trim() ??
            '';
    final storedDisplayName = conversation?.getDisplayName(userId).trim() ?? '';
    final displayName = conversation?.type == 'group'
        ? (conversation?.groupName?.trim().isNotEmpty ?? false)
            ? conversation!.groupName!.trim()
            : 'Group Chat'
        : peerUsername.isNotEmpty
            ? peerUsername
            : storedDisplayName.isNotEmpty &&
                    storedDisplayName != 'Unknown User'
                ? storedDisplayName
                : 'Chat';

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: ChatPaneView(
        conversationId: conversationId,
        userId: userId,
        username: username,
        avatarUrl: avatarUrl,
        showHeader: false,
      ),
    );
  }
}
