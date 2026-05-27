import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';
import 'package:mixvy/features/social/widgets/live_room_list.dart';
import 'package:mixvy/features/social/widgets/social_room_card.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/widgets/brand_ui_kit.dart';

void main() {
  group('LiveRoomList Widget and State Binding Tests', () {
    // Helper to generate dynamic mock room models for tests
    RoomModel createMockRoom({
      required String id,
      required String name,
      String category = 'chill',
      int memberCount = 10,
      List<String> stageUserIds = const ['user-1'],
      List<String> audienceUserIds = const ['user-2', 'user-3'],
    }) {
      return RoomModel(
        id: id,
        name: name,
        hostId: 'host-1',
        category: category,
        memberCount: memberCount,
        stageUserIds: stageUserIds,
        audienceUserIds: audienceUserIds,
        isLive: true,
      );
    }

    testWidgets('1. Loading State - Verifies that the pulsing shimmer column is shown', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomsStreamProvider.overrideWithValue(const AsyncValue.loading()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LiveRoomList(),
            ),
          ),
        ),
      );

      // Verify LiveRoomList widget is mounted
      expect(find.byType(LiveRoomList), findsOneWidget);

      // Verify the private _LoadingShimmerView is rendered using custom widget predicate matching
      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_LoadingShimmerView',
        ),
        findsOneWidget,
      );

      // Ensure no Empty State or Error State elements are rendered
      expect(find.text('The Lounge is Quiet'), findsNothing);
      expect(find.text('Connection Interrupted'), findsNothing);
    });

    testWidgets('2. Empty State - Verifies "The Lounge is Quiet" UI and CTA button', (tester) async {
      bool isStartRoomCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomsStreamProvider.overrideWithValue(const AsyncValue.data([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LiveRoomList(
                onStartRoomTap: () {
                  isStartRoomCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      // Verify the private _EmptyStateView is displayed
      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_EmptyStateView',
        ),
        findsOneWidget,
      );

      // Verify key theme elements and wording
      expect(find.text('The Lounge is Quiet'), findsOneWidget);
      expect(
        find.textContaining('No live rooms are active right now'),
        findsOneWidget,
      );

      // Verify that the premium action CTA button is rendered
      final buttonFinder = find.byType(MixvyGoldButton);
      expect(buttonFinder, findsOneWidget);
      expect(find.text('START THE FIRST ROOM'), findsOneWidget);

      // Tap on the "Start the First Room" CTA and verify trigger logic
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(isStartRoomCalled, isTrue);
    });

    testWidgets('3. Data State - Verifies dynamic SocialRoomCards render when data flows', (tester) async {
      final mockRooms = [
        createMockRoom(id: 'room-abc', name: 'Ambient Techno Beats', category: 'music'),
        createMockRoom(id: 'room-xyz', name: 'Speed Dating Lounge', category: 'dating'),
      ];

      RoomModel? tappedRoom;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomsStreamProvider.overrideWithValue(AsyncValue.data(mockRooms)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LiveRoomList(
                  onRoomTap: (room) {
                    tappedRoom = room;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Verify we find precisely 2 SocialRoomCard widgets
      expect(find.byType(SocialRoomCard), findsNWidgets(2));

      // Verify real, bound dynamic text from the data models displays without fallbacks
      expect(find.text('Ambient Techno Beats'), findsOneWidget);
      expect(find.text('Speed Dating Lounge'), findsOneWidget);

      // Verify action trigger on tapping a real card
      await tester.tap(find.text('Ambient Techno Beats'));
      await tester.pumpAndSettle();

      expect(tappedRoom, isNotNull);
      expect(tappedRoom!.id, 'room-abc');
      expect(tappedRoom!.name, 'Ambient Techno Beats');
    });

    testWidgets('4. Error State - Verifies "Connection Interrupted" UI and retry handler', (tester) async {
      bool isRetryCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomsStreamProvider.overrideWithValue(
              AsyncValue.error(Exception('Network timeout'), StackTrace.empty),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: LiveRoomList(
                // Invalidate logic defaults back to retry, we can trigger re-evaluation of stream
                onStartRoomTap: () {},
              ),
            ),
          ),
        ),
      );

      // Verify the private _ErrorStateView is rendered
      expect(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_ErrorStateView',
        ),
        findsOneWidget,
      );

      // Verify standard error texts
      expect(find.text('Connection Interrupted'), findsOneWidget);
      expect(
        find.textContaining('We could not load the active rooms stream'),
        findsOneWidget,
      );

      // Verify retry button exists
      expect(find.byType(MixvyGoldOutlineButton), findsOneWidget);
      expect(find.text('RETRY CONNECTION'), findsOneWidget);
    });
  });
}
