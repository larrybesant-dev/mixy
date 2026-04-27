import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/router/app_router.dart';

void main() {
  group('evaluateAppRedirect', () {
    test('holds user on splash while auth is loading', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/app',
        uid: null,
        authLoading: true,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
      );

      expect(result, '/splash');
    });

    test('routes signed-out users to auth', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/app',
        uid: null,
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
      );

      expect(result, '/auth');
    });

    test('routes signed-in incomplete users to onboarding', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/app',
        uid: 'user-1',
        authLoading: false,
        isFirstRun: () async => true,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
      );

      expect(result, '/onboarding');
    });

    test('routes ready users from gate pages to app', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/auth',
        uid: 'user-1',
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
      );

      expect(result, '/app');
    });

    test('keeps ready users in app paths', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/messages/new',
        uid: 'user-1',
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
      );

      expect(result, isNull);
    });

    test('redirects messaging paths when messaging gate is off', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/messages/new',
        uid: 'user-1',
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
        enableMessaging: false,
      );

      expect(result, '/status/messaging-unavailable');
    });

    test('redirects room paths when rooms gate is off', () async {
      final result = await evaluateAppRedirect(
        matchedLocation: '/room/abc123',
        uid: 'user-1',
        authLoading: false,
        isFirstRun: () async => false,
        isProfileComplete: (_) async => true,
        isLegalAccepted: () async => true,
        enableLiveRooms: false,
      );

      expect(result, '/status/rooms-unavailable');
    });
  });
}
