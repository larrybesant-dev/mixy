import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/feed/widgets/post_card.dart';
import 'package:mixvy/features/feed/models/post_model.dart';
import 'package:mixvy/features/profile/profile_view_providers.dart';
import 'package:mixvy/models/user_profile.dart';
import 'test_helpers.dart';

void main() {
  group('PostCard Widget Tests', () {
    setUpAll(() async {
      await testSetup();
    });

    testWidgets('renders post content correctly', (WidgetTester tester) async {
      final post = PostModel(
        id: 'post-1',
        userId: 'user-1',
        text: 'Hello MixVy!',
        createdAt: DateTime.now(),
        authorName: 'Test Author',
        likeCount: 5,
        commentCount: 2,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostCard(post: post, currentUserId: 'user-2'),
            ),
          ),
        ),
      );

      expect(find.text('Hello MixVy!'), findsOneWidget);
      expect(find.text('Test Author'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('handles empty author name and userId gracefully',
        (WidgetTester tester) async {
      final post = PostModel(
        id: 'post-2',
        userId: '',
        text: 'Empty author test',
        createdAt: DateTime.now(),
        authorName: '',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostCard(post: post, currentUserId: 'user-2'),
            ),
          ),
        ),
      );

      expect(find.text('Empty author test'), findsOneWidget);
      // Fallback for empty author name/userId is 'MixVy User' in PostCard
      expect(find.text('MixVy User'), findsOneWidget);
    });

    testWidgets('prefers the current profile name over a stored placeholder',
        (WidgetTester tester) async {
      final post = PostModel(
        id: 'post-3',
        userId: 'EL9KnmDMZGhES8yNYThQdjg3ya03',
        text: 'Current profile name test',
        createdAt: DateTime.now(),
        authorName: 'Member EL9K',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileFutureProvider(post.userId).overrideWith(
              (ref) async => const UserProfile(
                id: 'EL9KnmDMZGhES8yNYThQdjg3ya03',
                username: 'CURVE',
                displayName: 'CURVE',
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PostCard(post: post, currentUserId: post.userId),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('CURVE'), findsOneWidget);
      expect(find.text('Member EL9K'), findsNothing);
    });
  });
}
