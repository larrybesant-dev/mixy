import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mixvy/features/room/widgets/camera_wall.dart';
import 'package:mixvy/services/rtc_room_service.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';

class MockRtcRoomService extends Mock implements RtcRoomService {}

void main() {
  group('CameraWall Widget Tests', () {
    testWidgets('renders local tile when showLocalTile is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProvider.overrideWithValue(null),
          ],
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
                onSubscriptionPlanChanged: (force, high, low) {},
                roomName: 'Test Room')))));

      expect(find.text('Local Video'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('handles extreme small constraints without crashing', (WidgetTester tester) async {
      // Test zero width/height
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OverflowBox(
                maxWidth: 0,
                maxHeight: 0,
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
                    isSpeaking: false)),
                  remoteTileBuilder: (_) => const SizedBox.shrink(),
                  onSubscriptionPlanChanged: (force, high, low) {},
                  roomName: 'Test Room'))))));

      // Should not throw or crash.
      expect(tester.takeException(), isNull);
    });

    testWidgets('calculates grid correctly for many users', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProvider.overrideWithValue(null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CameraWall(
                roomId: 'test-room',
                localLabel: 'You',
                localSpeaking: false,
                showLocalTile: true,
                localTile: const SizedBox.shrink(),
                remoteTiles: List.generate(15, (i) => CameraWallRemoteTileData(
                  uid: i,
                  label: 'User $i',
                  canView: true,
                  isSpeaking: i % 2 == 0)),
                remoteTileBuilder: (tile) => Text('Video ${tile.uid}'),
                onSubscriptionPlanChanged: (force, high, low) {},
                roomName: 'Test Room')))));

      // Verify that at least some remote videos are rendered
      expect(find.textContaining('Video'), findsAtLeastNWidgets(1));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}










