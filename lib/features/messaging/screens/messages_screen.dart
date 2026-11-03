import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_layout.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../models/conversation_model.dart';
import '../panes/chat_pane_view.dart';
import '../panes/messages_pane_view.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  final String userId;
  final String username;

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  String? _selectedConversationId;

  @override
  Widget build(BuildContext context) {
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
                  userId: widget.userId,
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < AppBreakpoints.medium) {
            return MessagesPaneView(
              userId: widget.userId,
              username: widget.username,
              showHeader: false,
            );
          }

          return Row(
            children: [
              SizedBox(
                width: constraints.maxWidth < 1100 ? 390 : 440,
                child: MessagesPaneView(
                  userId: widget.userId,
                  username: widget.username,
                  showHeader: false,
                  onConversationSelected: _selectConversation,
                ),
              ),
              const VerticalDivider(width: 1, color: VelvetNoir.outlineVariant),
              Expanded(
                child: _selectedConversationId == null
                    ? AppEmptyView(
                        icon: Icons.forum_outlined,
                        title: 'Choose a conversation',
                        message:
                            'Open a conversation from the inbox or start a new one.',
                        action: FilledButton.icon(
                          onPressed: () => context.go('/messages/new'),
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('New message'),
                        ),
                      )
                    : ChatPaneView(
                        key: ValueKey<String>(_selectedConversationId!),
                        conversationId: _selectedConversationId!,
                        userId: widget.userId,
                        username: widget.username,
                        showHeader: true,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _selectConversation(Conversation conversation) {
    setState(() => _selectedConversationId = conversation.id);
  }
}
