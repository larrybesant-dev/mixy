import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/profile/profile_view_providers.dart';
import 'package:mixvy/features/profile/widgets/user_profile_bottom_sheet.dart';
import 'package:mixvy/models/user_presence.dart';
import 'package:mixvy/models/user_profile.dart';
import 'package:mixvy/widgets/brand_ui_kit.dart';

void main() {
  group('UserProfileBottomSheet Widget and State Binding Tests', () {
    const String testUserId = 'user-abc';

    UserProfile createMockProfile({
      required String id,
      required String username,
      required String displayName,
      String? bio,
      int vipLevel = 0,
      int followersCount = 0,
    }) {
      return UserProfile(
        id: id,
        username: username,
        displayName: displayName,
        bio: bio,
        vipLevel: vipLevel,
        followersCount: followersCount,
      );
    }

    testWidgets('1. Loading State - Verifies that the pulsing glassmorphic shimmer layout is shown', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileFutureProvider(testUserId).overrideWith((_) async => throw Exception('Loading')),
            userPresenceStreamProvider(testUserId).overrideWith((_) => Stream.value(const UserPresence(isOnline: false))),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: UserProfileBottomSheet(userId: testUserId),
            ),
          ),
        ),
      );

      // Verify widget mounts cleanly
      expect(find.byType(UserProfileBottomSheet), findsOneWidget);

      // Verify shimmer state mounts cleanly via predicate matching
      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_LoadingSheetState',
        ),
        findsOneWidget,
      );

      // Verify main details or error widgets are absent
      expect(find.text('About Me'), findsNothing);
      expect(find.text('Could Not Load Profile'), findsNothing);
    });

    testWidgets('2. Data State - Verifies dynamic profile data & interactive Follow/Unfollow toggle', (tester) async {
      final mockProfile = createMockProfile(
        id: testUserId,
        username: 'velvethost',
        displayName: 'Aria Rose',
        bio: 'Set the mood, play the music, vibe all night.',
        vipLevel: 3,
        followersCount: 1240,
      );

      final mockPresence = UserPresence(
        isOnline: true,
        lastSeen: DateTime.now(),
        currentRoomId: 'room-111',
      );

      bool? isFollowingOutput;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileFutureProvider(testUserId).overrideWith((_) async => mockProfile),
            userPresenceStreamProvider(testUserId).overrideWith((_) => Stream.value(mockPresence)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: UserProfileBottomSheet(
                userId: testUserId,
                onFollowChanged: (isFollowing) {
                  isFollowingOutput = isFollowing;
                },
              ),
            ),
          ),
        ),
      );

      // Verify that full content is built successfully
      expect(find.text('Aria Rose'), findsOneWidget);
      expect(find.text('@velvethost'), findsOneWidget);
      expect(find.text('Online Now'), findsOneWidget);
      expect(find.text('About Me'), findsOneWidget);
      expect(find.text('Set the mood, play the music, vibe all night.'), findsOneWidget);
      expect(find.text('1240 followers'), findsOneWidget);
      expect(find.text('VIP Level 3'), findsOneWidget);

      // Find the Follow action button and toggle it
      final followButtonFinder = find.byType(MixvyGoldButton);
      expect(followButtonFinder, findsOneWidget);
      expect(find.text('FOLLOW'), findsOneWidget);

      // Click to Follow - uses fixed duration frame pumping to prevent infinite animation hangs
      await tester.tap(followButtonFinder);
      await tester.pump(const Duration(milliseconds: 250));

      expect(isFollowingOutput, isTrue);
      expect(find.byType(MixvyGoldOutlineButton), findsOneWidget);
      expect(find.text('UNFOLLOW'), findsOneWidget);

      // Click to Unfollow
      await tester.tap(find.byType(MixvyGoldOutlineButton));
      await tester.pump(const Duration(milliseconds: 250));

      expect(isFollowingOutput, isFalse);
      expect(find.byType(MixvyGoldButton), findsOneWidget);
      expect(find.text('FOLLOW'), findsOneWidget);
    });

    testWidgets('3. Error State - Verifies user friendly recovery dialog displays', (tester) async {
      bool isClosed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileFutureProvider(testUserId).overrideWith((_) async => throw Exception('Firestore security rule check failed')),
            userPresenceStreamProvider(testUserId).overrideWith((_) => Stream.value(const UserPresence(isOnline: false))),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: UserProfileBottomSheet(
                userId: testUserId,
                onClose: () {
                  isClosed = true;
                },
              ),
            ),
          ),
        ),
      );

      // Verify that the private _ErrorSheetState is built
      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_ErrorSheetState',
        ),
        findsOneWidget,
      );

      expect(find.text('Could Not Load Profile'), findsOneWidget);
      expect(find.textContaining('We encountered an error loading this member\'s profile'), findsOneWidget);

      // Verify that close/retry options work cleanly
      final closeButtonFinder = find.byType(MixvyGoldOutlineButton);
      expect(closeButtonFinder, findsOneWidget);
      expect(find.text('CLOSE'), findsOneWidget);

      await tester.tap(closeButtonFinder);
      await tester.pump(const Duration(milliseconds: 250));

      expect(isClosed, isTrue);
    });
  });
}
