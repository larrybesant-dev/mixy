import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mixvy/features/room/presentation/live_room_screen.dart';
import 'package:mixvy/features/room/providers/message_providers.dart';
import 'package:mixvy/features/room/providers/room_firestore_provider.dart';
import 'package:mixvy/features/room/providers/participant_providers.dart';
import 'package:mixvy/features/room/providers/host_provider.dart';
import 'package:mixvy/features/room/providers/room_session_provider.dart';
import 'package:mixvy/features/room/providers/room_webrtc_provider.dart';
import 'package:mixvy/features/room/providers/webrtc_latency_provider.dart';
import 'package:mixvy/models/room_participant_model.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/services/connection_health_check.dart';
import 'package:mixvy/services/presence_controller.dart';
import 'package:mixvy/services/rtc_room_service.dart';
import 'test_helpers.dart';

class _MockRtcRoomService extends Mock implements RtcRoomService {}

class _StubPresenceController extends PresenceController {
  @override
  PresenceControllerState build() => const PresenceControllerState();
}

void main() {
  test('desktop room defaults to the dense reference layout', () {
    expect(liveRoomDefaultGridSlotCount, 16);
    expect(liveRoomDesktopChatWidth, 280);
    expect(liveRoomDesktopRosterWidth, 184);
  });

  test('camera presets use fitted desktop matrices', () {
    expect(liveRoomGridColumnCount(4, 680), 2);
    expect(liveRoomGridColumnCount(8, 680), 4);
    expect(liveRoomGridColumnCount(12, 680), 4);
    expect(liveRoomGridColumnCount(16, 680), 4);
    expect(liveRoomGridColumnCount(20, 680), 5);
  });

  test('camera matrix reduces columns on narrow screens', () {
    expect(liveRoomGridColumnCount(12, 500), 3);
    expect(liveRoomGridColumnCount(12, 350), 2);
  });

  test('live camera grid supports expansion without scrolling', () {
    final source = File(
      'lib/features/room/presentation/live_room_screen.dart',
    ).readAsStringSync();

    expect(source, contains('NeverScrollableScrollPhysics'));
    expect(
        source,
        contains(
            "tooltip: expanded\n                                    ? 'Return to camera grid'"));
    expect(source, contains(": 'Expand camera'"));
  });

  test('live room identity never falls back to real profile names', () {
    final source = File(
      'lib/features/room/presentation/live_room_screen.dart',
    ).readAsStringSync();
    final resolverStart = source.indexOf(
      'Future<String> _getUserDisplayName(String uid)',
    );
    final resolverEnd = source.indexOf(
      'bool _isPlaceholderIdentity(String value)',
      resolverStart,
    );
    final resolver = source.substring(resolverStart, resolverEnd);

    expect(resolverStart, greaterThanOrEqualTo(0));
    expect(resolverEnd, greaterThan(resolverStart));
    expect(resolver, contains("data?['username']"));
    expect(resolver, isNot(contains("data?['displayName']")));
    expect(resolver, isNot(contains('authUser.displayName')));
  });

  setUpAll(() async {
    await testSetup();
  });

  testWidgets('desktop controls and all camera presets fit without scrolling', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1228, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final firestore = FakeFirebaseFirestore();
    final rtcService = _MockRtcRoomService();
    when(() => rtcService.remoteUids).thenReturn([]);
    when(() => rtcService.isSharingSystemAudio).thenReturn(false);
    when(() => rtcService.supportsCameraSwitch).thenReturn(false);
    await firestore.collection('rooms').doc('room-a').set({
      'hostId': 'host-1',
      'isLocked': false,
      'slowModeSeconds': 0,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          networkHealthStatusProvider.overrideWith(
            (ref) => Stream.value(
              NetworkHealthStatus(
                latencyMs: 0,
                status: HealthStatus.excellent,
                timestamp: DateTime(2026, 1, 1),
              ),
            ),
          ),
          connectionHealthServiceProvider.overrideWithValue(
            ConnectionHealthCheckService(firestore),
          ),
          presenceControllerProvider.overrideWith(
            () => _StubPresenceController(),
          ),
          userProvider.overrideWithValue(
            UserModel(
              id: 'user-1',
              email: 'user1@mixvy.com',
              username: 'User One',
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
          currentParticipantProvider.overrideWith(
            (ref, params) => Stream.value(
              RoomParticipantModel(
                userId: 'user-1',
                role: 'audience',
                joinedAt: DateTime(2026, 1, 1),
                lastActiveAt: DateTime(2026, 1, 1),
              ),
            ),
          ),
          participantsStreamProvider.overrideWith(
            (ref, roomId) => Stream.value([]),
          ),
          participantCountProvider.overrideWith((ref, roomId) => 1),
          roomMessageStreamProvider
              .overrideWith((ref, roomId) => Stream.value([])),
          hostProvider.overrideWith(
            (ref, roomId) => Stream.value(Host('host-1')),
          ),
          coHostsProvider.overrideWith((ref, roomId) => const <Cohost>[]),
          roomSessionProvider.overrideWith((ref, roomId) {
            final notifier = RoomSessionNotifier();
            notifier.setJoined(true);
            return notifier;
          }),
          roomWebRTCProvider.overrideWith(
            (ref, roomId) async => RoomWebRTCState(
              roomId: roomId,
              userId: 'user-1',
              service: rtcService,
            ),
          ),
        ],
        child: const MaterialApp(home: LiveRoomScreen(roomId: 'room-a')),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LiveRoomScreen), findsOneWidget);
    expect(find.text('Join Queue to Talk'), findsOneWidget);
    expect(find.text('LEAVE'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final size in [
      const Size(1228, 768),
      const Size(1440, 900),
      const Size(1228, 500),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pump();
      for (final count in [4, 8, 12, 16, 20, 4]) {
      await tester.tap(find.text('$count'));
      await tester.pump();

      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsOneWidget);
      final grid = tester.widget<GridView>(gridFinder);
      expect(grid.childrenDelegate.estimatedChildCount, count);
      final slots = find.descendant(
        of: gridFinder,
        matching: find.byIcon(Icons.person),
      );
      expect(slots, findsNWidgets(count));
      final viewport = tester.getRect(gridFinder);
      for (final slot in slots.evaluate()) {
        final rect = tester.getRect(find.byWidget(slot.widget));
        expect(rect.left, greaterThanOrEqualTo(viewport.left));
        expect(rect.top, greaterThanOrEqualTo(viewport.top));
        expect(rect.right, lessThanOrEqualTo(viewport.right + 0.01));
        expect(rect.bottom, lessThanOrEqualTo(viewport.bottom + 0.01));
      }
      expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('missing room offers retry and back to rooms', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final firestore = FakeFirebaseFirestore();
    final router = GoRouter(
      initialLocation: '/room/deleted-room',
      routes: [
        GoRoute(
          path: '/room/:id',
          builder: (_, state) => LiveRoomScreen(
            roomId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/rooms',
          builder: (_, __) => const Scaffold(body: Text('Rooms browser')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          presenceControllerProvider.overrideWith(
            () => _StubPresenceController(),
          ),
          userProvider.overrideWithValue(
            UserModel(
              id: 'user-1',
              email: 'user1@mixvy.com',
              username: 'User One',
              createdAt: DateTime(2026, 1, 1),
            ),
          ),
          currentParticipantProvider.overrideWith(
            (ref, params) => Stream.value(null),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.text('Room not found. It may have ended or been removed.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Back to Rooms'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Back to Rooms'), findsOneWidget);

    await tester.tap(find.text('Back to Rooms'));
    await tester.pumpAndSettle();
    expect(find.text('Rooms browser'), findsOneWidget);
  });
}
