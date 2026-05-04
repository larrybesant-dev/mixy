import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/routing/redirect_logic.dart';

void main() {
  group('evaluateAppRedirect', () {
    test('returns null while auth is loading', () {
      final result = evaluateAppRedirect(
        matchedLocation: '/home',
        uid: null,
        authLoading: true,
        legalStateResolved: false,
        hasAcceptedLegal: false,
      );

      expect(result, isNull);
    });

    test('routes signed-out users to auth route', () {
      final result = evaluateAppRedirect(
        matchedLocation: '/home',
        uid: null,
        authLoading: false,
        legalStateResolved: false,
        hasAcceptedLegal: false,
      );

      expect(result, '/auth');
    });

    test('routes signed-in users away from auth route', () {
      final result = evaluateAppRedirect(
        matchedLocation: '/auth',
        uid: 'user-1',
        authLoading: false,
        legalStateResolved: true,
        hasAcceptedLegal: true,
      );

      expect(result, '/home');
    });

    test('keeps signed-in users on non-auth route', () {
      final result = evaluateAppRedirect(
        matchedLocation: '/speed-dating',
        uid: 'user-1',
        authLoading: false,
        legalStateResolved: true,
        hasAcceptedLegal: true,
      );

      expect(result, isNull);
    });

    test('keeps signed-out users on auth route', () {
      final result = evaluateAppRedirect(
        matchedLocation: '/auth',
        uid: null,
        authLoading: false,
        legalStateResolved: false,
        hasAcceptedLegal: false,
      );

      expect(result, isNull);
    });

    test('routes signed-out users away from onboarding route', () {
      final result = evaluateAppRedirect(
        matchedLocation: '/onboarding',
        uid: null,
        authLoading: false,
        legalStateResolved: false,
        hasAcceptedLegal: false,
      );

      expect(result, '/auth');
    });

    test(
      'keeps authenticated users on non-auth routes regardless of legal state',
      () {
        final result = evaluateAppRedirect(
          matchedLocation: '/speed-dating',
          uid: 'user-1',
          authLoading: false,
          legalStateResolved: false,
          hasAcceptedLegal: false,
        );

        expect(result, isNull);
      },
    );

    test(
      'keeps authenticated users on requested route when signed in',
      () {
        final result = evaluateAppRedirect(
          matchedLocation: '/speed-dating',
          uid: 'user-1',
          authLoading: false,
          legalStateResolved: true,
          hasAcceptedLegal: false,
        );

        expect(result, isNull);
      },
    );
  });
}
