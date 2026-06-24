import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mixvy/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Integration Tests', () {
    testWidgets('Login page renders correctly with all form elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to login page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/login');
      await tester.pumpAndSettle();

      // Verify login page elements are present
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(TextField),
          findsNWidgets(2)); // Email and password fields
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
      expect(find.text('Don\'t have an account? Sign Up'), findsOneWidget);
    });

    testWidgets('Signup page renders correctly with all form elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to signup page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/signup');
      await tester.pumpAndSettle();

      // Verify signup page elements are present
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(TextField),
          findsNWidgets(3)); // Username, email, password fields
      expect(find.widgetWithText(ElevatedButton, 'Sign Up'), findsOneWidget);
      expect(find.text('Already have an account? Login'), findsOneWidget);
    });

    testWidgets('Login form validation - empty fields show error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to login page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/login');
      await tester.pumpAndSettle();

      // Try to login with empty fields
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();

      // Verify error message appears
      expect(find.text('Please fill all fields'), findsOneWidget);
    });

    testWidgets('Login form validation - invalid email shows error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to login page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/login');
      await tester.pumpAndSettle();

      // Fill form with invalid email
      final emailField = find.byType(TextField).at(0);
      final passwordField = find.byType(TextField).at(1);

      await tester.enterText(emailField, 'invalid-email');
      await tester.enterText(passwordField, 'password123');
      await tester.pump();

      // Try to login
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();

      // Verify error message appears
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('Signup form validation - password too short shows error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to signup page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/signup');
      await tester.pumpAndSettle();

      // Fill form with short password
      final usernameField = find.byType(TextField).at(0);
      final emailField = find.byType(TextField).at(1);
      final passwordField = find.byType(TextField).at(2);

      await tester.enterText(usernameField, 'testuser');
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, '123');
      await tester.pump();

      // Try to signup
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pump();

      // Verify error message appears
      expect(
          find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('Navigation between login and signup pages',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Start at login page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/login');
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Create Account'), findsNothing);

      // Navigate to signup
      await tester.tap(find.text('Don\'t have an account? Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Login'), findsNothing);

      // Navigate back to login
      await tester.tap(find.text('Already have an account? Login'));
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Create Account'), findsNothing);
    });
  });

  group('Profile Management Integration Tests', () {
    testWidgets('Profile edit page renders correctly with all form elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to profile edit page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/profile/edit');
      await tester.pumpAndSettle();

      // Verify profile edit page elements
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Display Name'), findsOneWidget);
      expect(find.text('Bio'), findsOneWidget);
      expect(find.text('Location'), findsOneWidget);
      expect(find.text('Interests'), findsOneWidget);
      expect(find.text('Change Profile Picture'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(
          find.widgetWithText(ElevatedButton, 'Save Profile'), findsOneWidget);
      expect(find.byType(TextFormField),
          findsNWidgets(4)); // Name, bio, location, interests
    });

    testWidgets('Profile editing validation - empty display name shows error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to profile edit page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/profile/edit');
      await tester.pumpAndSettle();

      // Clear display name field and try to save
      final displayNameField = find.byType(TextFormField).at(0);
      await tester.enterText(displayNameField, '');
      await tester.pump();

      // Try to save
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Profile'));
      await tester.pump();

      // Verify validation error
      expect(find.text('Display name is required'), findsOneWidget);
    });

    testWidgets('Profile editing - form accepts valid input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to profile edit page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/profile/edit');
      await tester.pumpAndSettle();

      // Fill all profile fields with valid data
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(4));

      await tester.enterText(textFields.at(0), 'John Doe');
      await tester.enterText(
          textFields.at(1), 'I love music and connecting with people!');
      await tester.enterText(textFields.at(2), 'New York, USA');
      await tester.enterText(textFields.at(3), 'Music, Travel, Technology');
      await tester.pump();

      // Verify the text was entered correctly
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('I love music and connecting with people!'),
          findsOneWidget);
      expect(find.text('New York, USA'), findsOneWidget);
      expect(find.text('Music, Travel, Technology'), findsOneWidget);
    });

    testWidgets('Profile picture UI elements are present and interactive',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to profile edit page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/profile/edit');
      await tester.pumpAndSettle();

      // Verify profile picture section exists
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.text('Change Profile Picture'), findsOneWidget);

      // Verify camera button is tappable
      final cameraButton = find.byIcon(Icons.camera_alt);
      await tester.tap(cameraButton);
      await tester.pump();

      // The tap should not crash the app (basic interaction test)
      expect(find.byType(CircleAvatar), findsOneWidget);
    });
  });

  group('App Navigation Integration Tests', () {
    testWidgets('Splash screen navigation flow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      // Verify splash screen appears
      expect(find.text('MIX & MINGLE'), findsOneWidget);
      expect(find.text('Where Music Meets Connection'), findsOneWidget);

      // Wait for splash timeout and navigation
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Should navigate away from splash (to login or home)
      expect(find.text('MIX & MINGLE'), findsNothing);
    });

    testWidgets('App bar navigation elements are present',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to home page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/home');
      await tester.pumpAndSettle();

      // Verify basic app structure
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.byType(AppBar), findsWidgets);
    });

    testWidgets('Profile page navigation works', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to profile page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/profile');
      await tester.pumpAndSettle();

      // Verify profile page loads
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('UI Responsiveness and Accessibility Tests', () {
    testWidgets('App handles keyboard input without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to login page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/login');
      await tester.pumpAndSettle();

      // Test keyboard navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      // App should still be functional
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Form fields handle text input correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to signup page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/signup');
      await tester.pumpAndSettle();

      // Test text input in all fields
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));

      await tester.enterText(textFields.at(0), 'testuser123');
      await tester.enterText(textFields.at(1), 'test@example.com');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.pump();

      // Verify text was entered
      expect(find.text('testuser123'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('Buttons are present and properly styled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MixMingleApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to login page
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pushNamed('/login');
      await tester.pumpAndSettle();

      // Verify button styling and presence
      final loginButton = find.widgetWithText(ElevatedButton, 'Login');
      expect(loginButton, findsOneWidget);

      // Verify button is enabled (not disabled)
      final buttonWidget = tester.widget<ElevatedButton>(loginButton);
      expect(buttonWidget.onPressed, isNotNull);
    });
  });
}

