import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/feed/providers/feed_providers.dart';
import 'package:mixvy/features/social/screens/live_floor_screen.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await testSetup();
  });

  testWidgets(
    'LiveFloorScreen avoids zero-state hero metrics before rooms load',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override the provider the screen actually watches.
            // While loading (AsyncLoading), the screen must not show '0 active rooms'.
            roomVisibilitySectionsProvider.overrideWith(
              (ref) => const AsyncValue.loading(),
            ),
          ],
          child: const MaterialApp(home: LiveFloorScreen()),
        ),
      );

      await tester.pump();

      expect(find.text('Loading live rooms'), findsOneWidget);
      expect(find.text('0 active rooms'), findsNothing);
    },
  );
}
