import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/feed/screens/discovery_feed_screen.dart';
import 'package:mixvy/features/social/screens/live_floor_screen.dart';
import 'package:mixvy/shared/widgets/ui_stability_contract.dart';

void main() {
  testWidgets('home feed surfaces a clear live pulse banner', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeLivePulseSection(
            liveRoomCount: 3,
            activeListenerCount: 41,
            featuredRoomCount: 2,
          ),
        ),
      ),
    );

    expect(find.byType(HomeLivePulseSection), findsOneWidget);
    expect(find.byKey(HomeLayoutV1.livePulseKey), findsOneWidget);
    expect(find.text('Live Pulse'), findsOneWidget);
    expect(find.text('3 rooms live'), findsOneWidget);
    expect(find.text('41 listening now'), findsOneWidget);
    expect(find.text('2 featured'), findsOneWidget);
    expect(find.text('Go to Rooms'), findsOneWidget);
    expect(find.text('Live energy is moving right now.'), findsOneWidget);
  });

  testWidgets('home feed uses locked section widgets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HomeLivePulseSection(
                liveRoomCount: 3,
                activeListenerCount: 41,
                featuredRoomCount: 2,
              ),
              HomeFeaturedRoomsSection(
                hasRooms: true,
                child: SizedBox(height: 40),
              ),
              HomeDiscoverySection(
                child: SizedBox(height: 40),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(HomeLivePulseSection), findsOneWidget);
    expect(find.byType(HomeFeaturedRoomsSection), findsOneWidget);
    expect(find.byType(HomeDiscoverySection), findsOneWidget);
  });

  testWidgets('rooms visibility inspector explains empty-state causes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoomsVisibilityDebugPanel(
            streamStateLabel: 'empty',
            roomCount: 0,
            visibleRoomCount: 0,
            sortLabel: 'Most Active',
            hint: 'No rooms currently match live visibility rules.',
          ),
        ),
      ),
    );

    expect(find.text('Rooms Inspector'), findsOneWidget);
    expect(find.text('stream: empty'), findsOneWidget);
    expect(find.text('visible rooms: 0'), findsOneWidget);
    expect(
      find.textContaining('No live rooms are currently available from the backend.'),
      findsOneWidget,
    );
  });

  testWidgets('rooms tab opens with an entry-focused hero state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomsLayoutShell(
            hero: LiveFloorHeroBanner(
              key: RoomLayoutV1.heroKey,
              roomCount: 5,
              listenerCount: 84,
              sortLabel: 'Most Active',
              onQuickJoin: () {},
              onStartRoom: () {},
            ),
            controls: const RoomsControlsSection(
              sortLabel: 'Most Active',
            ),
            roomList: const RoomsListSection(
              child: SizedBox(height: 120),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(RoomsLayoutShell), findsOneWidget);
    expect(find.byType(RoomsControlsSection), findsOneWidget);
    expect(find.byType(RoomsListSection), findsOneWidget);
    expect(find.byKey(RoomLayoutV1.heroKey), findsOneWidget);
    expect(find.byKey(RoomLayoutV1.quickJoinKey), findsOneWidget);
    expect(find.text('Jump into a live room'), findsOneWidget);
    expect(find.text('5 active rooms'), findsOneWidget);
    expect(find.text('84 listening live'), findsOneWidget);
    expect(find.text('Sorted by Most Active'), findsWidgets);
    expect(find.text('Quick Join'), findsOneWidget);
    expect(find.text('Start a Room'), findsOneWidget);
  });
}
