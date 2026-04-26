import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/router/app_router.dart';

void main() {
  group('evaluateAppRedirect', () {
    test('routes first-run users to onboarding', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/',
        uid: null,
        authLoading: false,
        isFirstRun: () async => true,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => false,
      );

      expect(result, '/onboarding');
    });

    test('waits on splash while auth is still restoring', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/',
        uid: null,
        authLoading: true,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
      );

      expect(result, '/splash');
    });

    test('routes logged-out users to login after onboarding', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/',
        uid: null,
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
      );

      expect(result, '/login');
    });

    test('routes splash directly to login after auth restore', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/splash',
        uid: null,
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
      );

      expect(result, '/login');
    });

    test('routes splash directly to onboarding for first run', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/splash',
        uid: null,
        authLoading: false,
        isFirstRun: () async => true,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
      );

      expect(result, '/onboarding');
    });

    test('routes logged-in users with incomplete profile to profile', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/',
        uid: 'user-1',
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => false,
        isLegalAccepted: () async => true,
      );

      expect(result, '/profile');
    });

    test('keeps logged-in user on profile when incomplete', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/profile',
        uid: 'user-1',
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => false,
        isLegalAccepted: () async => true,
      );

      expect(result, isNull);
    });

    test('routes logged-in users away from login', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/login',
        uid: 'user-1',
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
      );

      expect(result, '/discover');
    });

    test('routes users to legal terms when current legal is not accepted', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/login',
        uid: null,
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => false,
      );

      expect(result, '/legal/terms');
    });

    test('encodes deep link in from-param when auth is loading', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/room/abc123',
        uid: null,
        authLoading: true,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
      );

      expect(result, '/splash?from=%2Froom%2Fabc123');
    });

    test('restores deep link from from-param after auth resolves on splash',
        () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/splash',
        uid: 'user-1',
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
        redirectFrom: '/room/abc123',
      );

      expect(result, '/room/abc123');
    });

    test('does not restore from-param when destination is an auth route',
        () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/splash',
        uid: 'user-1',
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
        redirectFrom: '/login',
      );

      // /login is blocked — falls back to /discover
      expect(result, '/discover');
    });

    test('redirects live routes when live rooms are remotely disabled',
        () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/room/abc123',
        uid: 'user-1',
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
        enableLiveRooms: false,
      );

      expect(result, '/discover');
    });

    test('redirects messaging routes when messaging is remotely disabled',
        () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/messages',
        uid: 'user-1',
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
        enableMessaging: false,
      );

      expect(result, '/social');
    });
  });
}
