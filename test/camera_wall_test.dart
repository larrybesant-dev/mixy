import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mixvy/features/room/widgets/camera_wall.dart';
import 'package:mixvy/services/rtc_room_service.dart';
import 'test_helpers.dart';

class MockRtcRoomService extends Mock implements RtcRoomService {}

void main() {
  group('CameraWall Widget Tests', () {
    setUpAll(() async {
      await testSetup();
    });
    testWidgets('renders local tile when showLocalTile is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CameraWall(
                roomId: 'test-room',
                localLabel: 'You',
                localSpeaking: false,
                showLocalTile: true,
                localTile: const Text('Local Video'),
                remoteTiles: const [],
                remoteTileBuilder: (_) => const SizedBox.shrink(),
                onSubscriptionPlanChanged: (_, __, ___) {},
                roomName: 'Test Room',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Local Video'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('handles extreme small constraints without crashing', (WidgetTester tester) async {
      // Test zero width/height
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 0,
                height: 0,
                child: CameraWall(
                  roomId: 'test-room',
                  localLabel: 'You',
                  localSpeaking: false,
                  showLocalTile: true,
                  localTile: const SizedBox.shrink(),
                  remoteTiles: List.generate(10, (i) => CameraWallRemoteTileData(
                    uid: i,
                    label: 'User $i',
                    canView: true,
                    isSpeaking: false,
                  )),
                  remoteTileBuilder: (_) => const SizedBox.shrink(),
                  onSubscriptionPlanChanged: (_, __, ___) {},
                  roomName: 'Test Room',
                ),
              ),
            ),
          ),
        ),
      );

      // Should not throw or crash.
      expect(tester.takeException(), isNull);
    });

    testWidgets('calculates grid correctly for many users', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                height: 800,
                child: CameraWall(
                  roomId: 'test-room',
                  localLabel: 'You',
                  localSpeaking: false,
                  showLocalTile: true,
                  localTile: const SizedBox.shrink(),
                  remoteTiles: List.generate(15, (i) => CameraWallRemoteTileData(
                    uid: i,
                    label: 'User $i',
                    canView: true,
                    isSpeaking: i % 2 == 0,
                  )),
                  remoteTileBuilder: (tile) => Text('Video ${tile.uid}'),
                  onSubscriptionPlanChanged: (_, __, ___) {},
                  roomName: 'Test Room',
                ),
              ),
            ),
          ),
        ),
      );

      // Verify that at least some remote videos are rendered
      expect(find.textContaining('Video'), findsAtLeastNWidgets(1));
    });
  });
}
