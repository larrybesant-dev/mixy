import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/room/widgets/camera_wall.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'test_helpers.dart';

ProviderScope _testScope({required Widget child}) {
  return ProviderScope(
    overrides: [
      userProvider.overrideWith(
        (ref) => UserModel(
          id: 'test-user',
          email: 'test@example.com',
          username: 'Test User',
          avatarUrl: null,
          createdAt: DateTime(2026, 1, 1),
        ),
      ),
    ],
    child: child,
  );
}

void main() {
  group('CameraWall Layout Tests', () {
    setUpAll(() async {
      await testSetup();
    });

    testWidgets('Renders correctly with 0 speakers', (tester) async {
      await tester.pumpWidget(
        _testScope(
          child: MaterialApp(
            home: Scaffold(
              body: CameraWall(
                roomId: 'test-room',
                roomName: 'Test Room',
                localLabel: 'You',
                localSpeaking: false,
                showLocalTile: false,
                localTile: const SizedBox.shrink(),
                remoteTiles: const [],
                remoteTileBuilder: (_) => const SizedBox.shrink(),
                onSubscriptionPlanChanged: (_, __, ___) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CameraWall), findsOneWidget);
    });

    testWidgets('Renders correctly with 12 speakers (chaos scenario)', (tester) async {
      final remoteTiles = List.generate(
        12,
        (i) => CameraWallRemoteTileData(
          uid: i + 1,
          label: 'User $i',
          canView: true,
          isSpeaking: i % 3 == 0,
        ),
      );

      await tester.pumpWidget(
        _testScope(
          child: MaterialApp(
            home: Scaffold(
              body: CameraWall(
                roomId: 'test-room',
                roomName: 'Test Room',
                localLabel: 'You',
                localSpeaking: true,
                showLocalTile: true,
                localTile: const Placeholder(),
                remoteTiles: remoteTiles,
                remoteTileBuilder: (tile) => Text(tile.label),
                onSubscriptionPlanChanged: (_, __, ___) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CameraWall), findsOneWidget);
      // Main grid limit is 8 on mobile, so we expect local + some remotes
    });

    testWidgets('Handles extreme aspect ratios and small constraints', (tester) async {
      await tester.pumpWidget(
        _testScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 50, // Extremely narrow
                  height: 1000,
                  child: CameraWall(
                    roomId: 'test-room',
                    roomName: 'Test Room',
                    localLabel: 'You',
                    localSpeaking: false,
                    showLocalTile: true,
                    localTile: const SizedBox.shrink(),
                    remoteTiles: const [],
                    remoteTileBuilder: (_) => const SizedBox.shrink(),
                    onSubscriptionPlanChanged: (_, __, ___) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CameraWall), findsOneWidget);
    });

    testWidgets('Handles zero width/height constraints', (tester) async {
      await tester.pumpWidget(
        _testScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 0,
                  height: 0,
                  child: CameraWall(
                    roomId: 'test-room',
                    roomName: 'Test Room',
                    localLabel: 'You',
                    localSpeaking: false,
                    showLocalTile: true,
                    localTile: const SizedBox.shrink(),
                    remoteTiles: const [],
                    remoteTileBuilder: (_) => const SizedBox.shrink(),
                    onSubscriptionPlanChanged: (_, __, ___) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CameraWall), findsOneWidget);
    });
  });
}
