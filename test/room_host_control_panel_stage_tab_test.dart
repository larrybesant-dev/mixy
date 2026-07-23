import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/providers/mic_access_provider.dart';
import 'package:mixvy/features/room/providers/room_firestore_provider.dart';
import 'package:mixvy/features/room/providers/room_policy_provider.dart';
import 'package:mixvy/features/room/widgets/room_host_control_panel.dart';
import 'package:mixvy/models/mic_access_request_model.dart';
import 'package:mixvy/models/room_policy_model.dart';

void main() {
  Future<void> configureViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('RoomHostControlPanel — Stage tab', () {
    testWidgets('renders 30s / 60s / Unlimited SegmentedButton segments', (
      WidgetTester tester,
    ) async {
      await configureViewport(tester);
      final controllerFirestore = FakeFirebaseFirestore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomFirestoreProvider.overrideWithValue(controllerFirestore),
            roomPolicyProvider.overrideWith(
              (ref, roomId) => Stream.value(
                RoomPolicyModel(roomId: roomId, micTimerSeconds: 30),
              ),
            ),
            roomMicAccessRequestsProvider.overrideWith(
              (ref, roomId) => Stream.value(const <MicAccessRequestModel>[]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  child: const Text('Open Panel'),
                  onPressed: () => RoomHostControlPanel.show(
                    ctx,
                    roomId: 'room-1',
                    currentUserId: 'host-1',
                    isOwner: true,
                    initialTabIndex: 1, // Stage tab
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Panel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // All three SegmentedButton options must be visible.
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('60s'), findsOneWidget);
      expect(find.text('Unlimited'), findsOneWidget);
    });

    testWidgets('displays policy label reflecting current micTimerSeconds', (
      WidgetTester tester,
    ) async {
      await configureViewport(tester);
      final controllerFirestore = FakeFirebaseFirestore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomFirestoreProvider.overrideWithValue(controllerFirestore),
            roomPolicyProvider.overrideWith(
              (ref, roomId) => Stream.value(
                RoomPolicyModel(roomId: roomId, micTimerSeconds: 60),
              ),
            ),
            roomMicAccessRequestsProvider.overrideWith(
              (ref, roomId) => Stream.value(const <MicAccessRequestModel>[]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  child: const Text('Open Panel'),
                  onPressed: () => RoomHostControlPanel.show(
                    ctx,
                    roomId: 'room-1',
                    currentUserId: 'host-1',
                    isOwner: true,
                    initialTabIndex: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Panel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Label should reflect 60s timer.
      expect(find.text('60s per turn'), findsOneWidget);
    });

    testWidgets('displays "Unlimited mic time" when micTimerSeconds is null', (
      WidgetTester tester,
    ) async {
      await configureViewport(tester);
      final controllerFirestore = FakeFirebaseFirestore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomFirestoreProvider.overrideWithValue(controllerFirestore),
            roomPolicyProvider.overrideWith(
              (ref, roomId) => Stream.value(
                RoomPolicyModel(roomId: roomId), // micTimerSeconds: null
              ),
            ),
            roomMicAccessRequestsProvider.overrideWith(
              (ref, roomId) => Stream.value(const <MicAccessRequestModel>[]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  child: const Text('Open Panel'),
                  onPressed: () => RoomHostControlPanel.show(
                    ctx,
                    roomId: 'room-1',
                    currentUserId: 'host-1',
                    isOwner: true,
                    initialTabIndex: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Panel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Unlimited mic time'), findsOneWidget);
    });

    testWidgets('tapping a segment writes micTimerSeconds to Firestore', (
      WidgetTester tester,
    ) async {
      await configureViewport(tester);
      final controllerFirestore = FakeFirebaseFirestore();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roomFirestoreProvider.overrideWithValue(controllerFirestore),
            roomPolicyProvider.overrideWith(
              (ref, roomId) => Stream.value(
                RoomPolicyModel(roomId: roomId, micTimerSeconds: 30),
              ),
            ),
            roomMicAccessRequestsProvider.overrideWith(
              (ref, roomId) => Stream.value(const <MicAccessRequestModel>[]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  child: const Text('Open Panel'),
                  onPressed: () => RoomHostControlPanel.show(
                    ctx,
                    roomId: 'room-1',
                    currentUserId: 'host-1',
                    isOwner: true,
                    initialTabIndex: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Panel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the 60s segment.
      await tester.tap(find.text('60s'));
      await tester.pump();

      // Verify the controller wrote micTimerSeconds: 60 to Firestore.
      final policySnap = await controllerFirestore
          .collection('rooms')
          .doc('room-1')
          .collection('policies')
          .doc('settings')
          .get();
      expect(policySnap.data()?['micTimerSeconds'], 60);
    });
  });
}
