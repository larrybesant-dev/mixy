import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/profile/widgets/profile_photo_viewer.dart';

void main() {
  testWidgets('opens and closes the fullscreen profile photo viewer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showProfilePhotoViewer(
                context: context,
                imageUrl: 'asset:assets/images/mixvy_logo.png',
                displayName: 'MixVy member',
              ),
              child: const Text('Open photo'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open photo'));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Close photo'), findsOneWidget);

    await tester.tap(find.byTooltip('Close photo'));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
  });
}
