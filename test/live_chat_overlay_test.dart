import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/room/widgets/chat_panel.dart';
import 'package:mixvy/features/messaging/models/message_model.dart';
import 'test_helpers.dart';

void main() {
  group('ChatPanel Performance & Stress Tests', () {
    setUpAll(() async {
      await testSetup();
    });

    testWidgets('Handles a chat storm (100 messages) without crashing', (tester) async {
      final messages = List.generate(
        100,
        (i) => MessageModel(
          id: 'msg_$i',
          senderId: 'user_$i',
          content: 'Message content $i',
          sentAt: DateTime.now(),
          type: 'text',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatPanel(
                messages: messages,
                isLoadingMessages: false,
                currentUserId: 'me',
                currentUsername: 'Me',
                isSending: false,
                cooldownMessage: '',
                isMuted: false,
                isBanned: false,
                allowChat: true,
                hasBlockedRelationship: false,
                showEmojiTray: false,
                onToggleEmojiTray: () {},
                onSendMessage: (_) async {},
                onTyping: () {},
                messageController: TextEditingController(),
                scrollController: ScrollController(),
                senderLabelResolver: (id) => 'User $id',
                senderVipLevelResolver: (_) => 0,
                senderAvatarResolver: (_) => null,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ChatPanel), findsOneWidget);
      // Verify virtualization: Not all 100 bubbles should be in the tree if space is limited
      // (Though in a test env the constraints might be large, we check for presence at least)
      expect(find.textContaining('Message content'), findsWidgets);
    });

    testWidgets('Gracefully handles null-like data in messages', (tester) async {
      final messages = [
        MessageModel(
          id: 'msg_1',
          senderId: '', // Empty sender
          content: '',  // Empty content
          sentAt: DateTime.fromMillisecondsSinceEpoch(0), // Epoch start
          type: 'text',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatPanel(
                messages: messages,
                isLoadingMessages: false,
                currentUserId: 'me',
                currentUsername: 'Me',
                isSending: false,
                cooldownMessage: '',
                isMuted: false,
                isBanned: false,
                allowChat: true,
                hasBlockedRelationship: false,
                showEmojiTray: false,
                onToggleEmojiTray: () {},
                onSendMessage: (_) async {},
                onTyping: () {},
                messageController: TextEditingController(),
                scrollController: ScrollController(),
                senderLabelResolver: (id) => '', // Resolver returns empty
                senderVipLevelResolver: (_) => 0,
                senderAvatarResolver: (_) => null,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ChatPanel), findsOneWidget);
      // Should not crash and should show fallback markers
      expect(find.byIcon(Icons.circle), findsNothing); // _LivePulseDot not in chat but used in profile
    });
  });
}
