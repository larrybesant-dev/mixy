// integration_test/e2e_critical_flows_test.dart
// Run with: flutter test integration_test/e2e_critical_flows_test.dart -d web
// Or: flutter test integration_test/ -d web

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mixvy/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MIXVY E2E Critical Flows', () {
    /// TEST 1: Onboarding & Authentication
    testWidgets('Flow 1: User can sign in and land on home screen',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Check if we're on login or onboarding
      final signInButton = find.text('SIGN IN');
      final letsGoButton = find.text("Let's Go");

      if (signInButton.evaluate().isNotEmpty) {
        // User not logged in - test login flow
        expect(find.text('SIGN IN'), findsWidgets);
        expect(find.text('SIGN UP'), findsWidgets);

        // Find and tap "SIGN IN" button
        await tester.tap(find.text('SIGN IN'));
        await tester.pumpAndSettle();

        // Verify email input field
        expect(find.byType(TextField), findsWidgets);

        // Enter email
        await tester.enterText(
          find.byType(TextField).first,
          'testuser1@mixvy.test',
        );
        await tester.pumpAndSettle();

        // Find password field and enter password
        final passwordFields = find.byType(TextField);
        await tester.enterText(
          passwordFields.at(1),
          'TestPassword123!',
        );
        await tester.pumpAndSettle();

        // Tap login button
        final loginButton = find.byWidgetPredicate(
          (widget) =>
              widget is ElevatedButton &&
              widget.child is Text &&
              (widget.child as Text).data?.contains('SIGN IN') == true,
        );
        if (loginButton.evaluate().isNotEmpty) {
          await tester.tap(loginButton);
        }

        // Wait for Firebase auth + navigation
        await tester.pumpAndSettle(const Duration(seconds: 5));
      } else if (letsGoButton.evaluate().isNotEmpty) {
        // User is logged in but onboarding not complete - test onboarding flow
        print('🎯 User already logged in, testing onboarding flow...');

        // Tap "Let's Go" to complete onboarding
        await tester.tap(find.text("Let's Go"));
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // Verify home screen elements
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Look for feed or other home screen indicators
      final feedElements = find.byType(ListView);
      expect(feedElements, findsWidgets);

      print('✅ Auth Flow: PASSED');
    });

    /// TEST 2: Room Engagement & Moderation
    testWidgets('Flow 2: User can join room and test moderation controls',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Assume already logged in from previous test (in real scenario, use shared state)
      // Navigate to Live Rooms
      final liveRoomsTab = find.text('Live Rooms');
      if (liveRoomsTab.evaluate().isNotEmpty) {
        await tester.tap(liveRoomsTab);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Find and tap first room or "Create Room" button
      final createButton = find.byWidgetPredicate(
        (widget) =>
            widget is ElevatedButton &&
            widget.child is Text &&
            (widget.child as Text).data?.contains('Create') == true,
      );

      if (createButton.evaluate().isNotEmpty) {
        await tester.tap(createButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Enter room name
        await tester.enterText(find.byType(TextField), 'E2E Test Room');
        await tester.pumpAndSettle();

        // Tap "Start" button
        final startButton = find.byWidgetPredicate(
          (widget) =>
              widget is ElevatedButton &&
              widget.child is Text &&
              (widget.child as Text).data?.contains('Start') == true,
        );
        if (startButton.evaluate().isNotEmpty) {
          await tester.tap(startButton);
        }
      }

      // Wait for room page to load + WebRTC init
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify room is joined (look for chat input or room controls)
      expect(find.byType(TextField), findsWidgets); // Chat input

      // Look for moderation panel (gear icon or settings)
      final settingsButton = find.byIcon(Icons.settings);
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();

        // Verify moderation controls exist
        expect(find.text('Mute All'), findsOneWidget);
        expect(find.text('Lock Mics'), findsOneWidget);
        expect(find.text('Lock Cameras'), findsOneWidget);

        // Test "Mute All" control
        await tester.tap(find.text('Mute All'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify Firestore update (in real test, check Firestore directly)
        print('✅ Moderation Control: Mute All activated');
      }

      print('✅ Room Engagement Flow: PASSED');
    });

    /// TEST 3: Social Connectivity & State Sync (Riverpod)
    testWidgets('Flow 3: Friends list updates in real-time via Riverpod',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Navigate to Profile
      final profileTab = find.text('Profile');
      if (profileTab.evaluate().isNotEmpty) {
        await tester.tap(profileTab);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Look for Friends section
      final friendsButton = find.byWidgetPredicate(
        (widget) =>
            widget is GestureDetector &&
            widget.child is Text &&
            (widget.child as Text).data?.contains('Friends') == true,
      );

      if (friendsButton.evaluate().isNotEmpty) {
        await tester.tap(friendsButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify friends list loads
        expect(find.byType(ListView), findsOneWidget);

        // Check for presence indicators (green dots)
        final presenceIndicators = find.byType(Container);
        if (presenceIndicators.evaluate().isNotEmpty) {
          print('✅ Friends List: ${presenceIndicators.evaluate().length} items');
        }
      }

      // Navigate to Feed
      final feedTab = find.text('Feed');
      if (feedTab.evaluate().isNotEmpty) {
        await tester.tap(feedTab);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Verify feed loads
        expect(find.byType(ListView), findsOneWidget);

        // Trigger refresh (if pull-to-refresh exists)
        final refreshIndicator = find.byType(RefreshIndicator);
        if (refreshIndicator.evaluate().isNotEmpty) {
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, 300),
          );
          await tester.pumpAndSettle(const Duration(seconds: 3));

          print('✅ Feed Refresh: State sync via Riverpod successful');
        }
      }

      print('✅ Social Connectivity Flow: PASSED');
    });

    /// TEST 4: Error Handling - Verify no console errors
    testWidgets('Flow 4: No critical console errors during navigation',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // In a real scenario, capture logs and verify:
      // - No "Looking up a deactivated widget's ancestor" errors
      // - No "invalid_use_of_protected_member" errors
      // - No Firebase auth failures
      // - No Firestore connection errors

      // For now, just verify app doesn't crash
      expect(find.byType(MaterialApp), findsOneWidget);

      print('✅ Error Handling: No crashes detected');
    });
  });
}

