import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/providers/cam_view_request_provider.dart';
import 'package:mixvy/features/room/widgets/cam_view_request_dialog.dart';

void main() {
  const request = CamViewRequest(
    id: 'request-1',
    requesterId: 'viewer-1',
    targetId: 'camera-owner',
    roomId: 'room-1',
    status: 'pending',
    requesterName: 'Harley',
  );

  testWidgets('shows requester identity and returns allow decision', (
    tester,
  ) async {
    bool? decision;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                decision = await showCamViewRequestDialog(
                  context,
                  request: request,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Camera view request'), findsOneWidget);
    expect(find.textContaining('Harley'), findsOneWidget);
    expect(find.textContaining('wants to view your camera'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();
    expect(decision, isTrue);
  });

  testWidgets('returns decline decision', (tester) async {
    bool? decision;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                decision = await showCamViewRequestDialog(
                  context,
                  request: request,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();

    expect(decision, isFalse);
  });
}
