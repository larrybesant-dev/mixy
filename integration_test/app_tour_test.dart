import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';
import 'package:mixvy/features/profile/profile_view_providers.dart';
import 'package:mixvy/features/profile/widgets/user_profile_bottom_sheet.dart';
import 'package:mixvy/features/social/widgets/live_room_list.dart';
import 'package:mixvy/features/social/widgets/social_room_card.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/models/user_presence.dart';
import 'package:mixvy/models/user_profile.dart';
import 'package:mixvy/widgets/brand_ui_kit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MixVy Live Visual Integration Tour', () {
    testWidgets('Step-by-step walkthrough of Live Rooms and Profile Sheets',
        (WidgetTester tester) async {
      // 1. Prepare fully bound mock payloads to prevent database state pollution on target device
      final mockRoom = RoomModel(
        id: 'room-integration-1',
        name: 'Electric Neon Lounge',
        hostId: 'user-abc',
        category: 'music',
        memberCount: 42,
        stageUserIds: const ['user-abc'],
        audienceUserIds: const ['user-xyz'],
        isLive: true,
      );

      final mockProfile = UserProfile(
        id: 'user-abc',
        username: 'neonrose',
        displayName: 'Aria Rose',
        bio: 'Pioneer of the digital premium lounge. Late night techno beats.',
        vipLevel: 5,
        followersCount: 8840,
      );

      final mockPresence = UserPresence(
        isOnline: true,
        lastSeen: DateTime.now(),
        currentRoomId: 'room-integration-1',
      );

      // 2. Open the app and land on our main screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomsStreamProvider
                .overrideWith((ref) => AsyncValue.data([mockRoom])),
            userProfileFutureProvider('user-abc')
                .overrideWith((ref) => mockProfile),
            userPresenceStreamProvider('user-abc')
                .overrideWith((ref) => Stream.value(mockPresence)),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor:
                  const Color(0xFF111319), // Digital Premium Lounge Background
              body: SafeArea(
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Text(
                          'Live Lounge Feed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: LiveRoomList(
                        onRoomTap: (room) {
                          // Wire room tap to trigger the glassmorphic UserProfileBottomSheet
                          UserProfileBottomSheet.show(
                            tester.element(find.byType(LiveRoomList)),
                            room.hostId,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // 3. Simulate a delay so we can inspect the UI layout bounds on-screen
      await tester.pump(const Duration(seconds: 2));

      // 4. Automatically click on a user avatar / room tile inside our new LiveRoomList
      final roomCardFinder = find.byType(SocialRoomCard);
      expect(roomCardFinder, findsOneWidget);

      await tester.tap(roomCardFinder);
      // Pump frames so the bottom sheet slides up smoothly
      await tester.pump(const Duration(milliseconds: 500));

      // 5. Verify that our glassmorphic UserProfileBottomSheet slides up smoothly
      expect(find.byType(UserProfileBottomSheet), findsOneWidget);
      expect(find.text('Aria Rose'), findsOneWidget);
      expect(find.text('@neonrose'), findsOneWidget);
      expect(find.text('Online Now'), findsOneWidget);

      // Short delay for on-screen inspection
      await tester.pump(const Duration(seconds: 1));

      // 6. Click the 'Follow' button on the profile card
      final followButtonFinder = find.byType(MixvyGoldButton);
      expect(followButtonFinder, findsOneWidget);
      expect(find.text('FOLLOW'), findsOneWidget);

      await tester.tap(followButtonFinder);
      // Wait for local state transition frame
      await tester.pump(const Duration(milliseconds: 250));

      // Verify button transforms to 'Unfollow'
      expect(find.byType(MixvyGoldOutlineButton), findsOneWidget);
      expect(find.text('UNFOLLOW'), findsOneWidget);

      // Short delay to appreciate follow success
      await tester.pump(const Duration(seconds: 1));

      // Close the sheet by popping the navigation stack
      Navigator.of(tester.element(find.byType(UserProfileBottomSheet))).pop();
      // Pump closing animation frames
      await tester.pump(const Duration(milliseconds: 500));

      // Verify bottom sheet has safely unmounted
      expect(find.byType(UserProfileBottomSheet), findsNothing);

      // Final short delay to complete the visual walkthrough cleanly
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
