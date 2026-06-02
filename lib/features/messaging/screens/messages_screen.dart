import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../panes/messages_pane_view.dart';
import '../providers/messaging_provider.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  final String userId;
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(requestsStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'New message',
            onPressed: () => context.go('/messages/new'),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: 'message requests',
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: VelvetNoir.surface,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => MessageRequestsSheet(
                  userId: userId,
                ),
              );
            },
          ),
        ],
      ),
      body: MessagesPaneView(
        userId: userId,
        username: username,
        showHeader: false,
      ),
    );
  }
}
