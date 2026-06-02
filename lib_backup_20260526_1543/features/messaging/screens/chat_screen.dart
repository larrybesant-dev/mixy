import 'package:flutter/material.dart';

import '../panes/chat_pane_view.dart';

class ChatScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(username)),
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
