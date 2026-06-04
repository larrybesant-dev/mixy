import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mixvy/app/app.dart';
import 'package:mixvy/app/boot_state.dart';
import 'package:mixvy/app/boot_state_notifier.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/router/app_router.dart';
import 'package:mixvy/features/onboarding/onboarding_screen.dart';

class MockOnboardingAuthController extends AuthController {
  final AuthState mockState;
  MockOnboardingAuthController(this.mockState);

  @override
  AuthState build() => mockState;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('MixVy New User Onboarding E2E Flow Test', () {
    testWidgets(
      'Should step through all onboarding scenes, select interests, accept legal checkbox, and navigate to home',
      (WidgetTester tester) async {
        final mockUser = UserModel(
          id: 'new-user-101',
          username: 'mixvy_newbee',
          email: 'welcome@mixvy.com',
          createdAt: DateTime.now(),
          avatarUrl: null,
        );

        final mockAuthState = AuthState(
          uid: 'new-user-101',
          phase: AuthBootstrapPhase.authenticatedStable,
        );

        // 1. Act: Render the app under authenticated mock states
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bootStateProvider.overrideWith(
                (ref) => BootStateNotifier(initialState: BootState.ready),
              ),
              authControllerProvider.overrideWith(
                () => MockOnboardingAuthController(mockAuthState),
              ),
              userProvider.overrideWithValue(mockUser),
            ],
            child: const MixVyApp(),
          ),
        );

        await tester.pumpAndSettle();

        final container =
            ProviderScope.containerOf(tester.element(find.byType(MixVyApp)));
        final router = container.read(routerProvider);

        // 2. Action: Force routing directly to '/onboarding'
        router.go('/onboarding');
        await tester.pumpAndSettle();

        // 3. Verify: We are now on the Onboarding screen
        expect(find.byType(OnboardingScreen), findsOneWidget);

        // 4. Action: Tap the "CONTINUE" button to transition through Scene 1
        expect(find.text('CONTINUE'), findsOneWidget);
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();

        // 5. Action: Tap the "CONTINUE" button to transition through Scene 2
        expect(find.text('CONTINUE'), findsOneWidget);
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();

        // 6. Action: Tap the "CONTINUE" button to transition through Scene 3
        expect(find.text('CONTINUE'), findsOneWidget);
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();

        // 7. Verify: We should now be on the Interests & Vibe selection page
        expect(find.text('Choose the energy you want more of.'), findsOneWidget);

        // 8. Action: Tap some vibe/interest chips
        expect(find.text('music'), findsOneWidget);
        await tester.tap(find.text('music'));
        await tester.pumpAndSettle();

        expect(find.text('dating'), findsOneWidget);
        await tester.tap(find.text('dating'));
        await tester.pumpAndSettle();

        // 9. Action: Toggle the Terms and Legal checkbox
        final checkboxFinder = find.byType(Checkbox);
        expect(checkboxFinder, findsOneWidget);
        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();

        // 10. Action: Enter the application by tapping the "ENTER MIXVY" CTA
        expect(find.text('ENTER MIXVY'), findsOneWidget);
        await tester.tap(find.text('ENTER MIXVY'));
        await tester.pumpAndSettle();

        // 11. Verify: Assert the user is safely navigated to the Dashboard screen (/home)
        expect(router.routeInformationProvider.value.uri.path, equals('/home'));

        debugPrint('[QA][SUCCESS] New user onboarding E2E flow test passed successfully!');
      },
    );
  });
}
