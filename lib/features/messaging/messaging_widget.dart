// Basic UI widget for Messaging
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'messaging_provider.dart';

class MessagingWidget extends ConsumerWidget {
  const MessagingWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(messagingProvider);
    if (messages.isEmpty) {
      return const Center(child: Text('No messages'));
    }
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return ListTile(
          title: Text('From: ${message.senderId}'),
          subtitle: Text(message.content),
        );
      },
    );
  }
}
