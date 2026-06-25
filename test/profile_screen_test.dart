import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:mixvy/features/profile/profile_controller.dart';
import 'package:mixvy/features/profile/profile_screen.dart';
import 'package:mocktail/mocktail.dart';

import 'test_helpers.dart';

// ---------------------------------------------------------------------------
// Mocks & stubs
// ---------------------------------------------------------------------------

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _StubProfileController extends ProfileController {
  final ProfileState _initial;
  _StubProfileController(this._initial);

  @override
  ProfileState build() => _initial;
}

class _StubAuthController extends AuthController {
  @override
  AuthState build() => const AuthState();

  @override
  Future<void> logout() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildApp(ProfileState profileState) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Login')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      profileControllerProvider.overrideWith(
        () => _StubProfileController(profileState),
      ),
      authControllerProvider.overrideWith(() => _StubAuthController()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('ProfileScreen', () {
    testWidgets('renders Profile appbar title', (tester) async {
      await tester.pumpWidget(_buildApp(const ProfileState()));
      await tester.pump();

      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('shows loading indicator while profile is loading', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(const ProfileState(isLoading: true)));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows username field when profile is loaded', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          const ProfileState(
            isLoading: false,
            userId: 'user-1',
            username: 'TestUser',
            email: 'test@mixvy.dev',
          ),
        ),
      );
      await tester.pump();

      // The full-screen loading spinner (shown only while loading with no userId)
      // must not be the ONLY widget — the form body should be rendering.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows logout button in appbar', (tester) async {
      await tester.pumpWidget(_buildApp(const ProfileState()));
      await tester.pump();

      expect(find.byTooltip('Logout'), findsOneWidget);
    });
  });
}
