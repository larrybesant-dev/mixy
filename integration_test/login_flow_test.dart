import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/app/app.dart';

void main() {
  testWidgets('Login flow widget test', (WidgetTester tester) async {
    // Build the app and trigger a frame
    await tester.pumpWidget(const MixMingleApp());

    // Wait for the app to settle
    await tester.pumpAndSettle();

    // Verify we're on the login page (should show login form)
    expect(find.text('Login'), findsOneWidget);

    // Enter email
    await tester.enterText(
        find.byKey(const Key('emailField')), 'testuser+auth@example.com');
    await tester.pump();

    // Enter password
    await tester.enterText(find.byKey(const Key('passwordField')), 'Test123!!');
    await tester.pump();

    // Tap login button
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();

    // Wait for authentication and navigation
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Check if login was successful - should navigate away from login page
    // The exact success indicator depends on your app's home page content
    // This could be checking for specific text, widgets, or URL changes

    // For now, let's check that we're no longer on the login page
    // (This assumes successful login navigates to a different page)
    expect(find.text('Login'), findsNothing);

    // You might want to check for specific home page content instead:
    // expect(find.text('Welcome'), findsOneWidget);
    // or
    // expect(find.byType(HomePage), findsOneWidget);
  });
}

