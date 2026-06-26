import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/profile/edit_profile_screen.dart';
import 'package:mixvy/features/profile/profile_controller.dart';
import 'package:mixvy/models/profile_privacy_model.dart';


/// Stub [ProfileController] that returns a fixed [ProfileState] without
/// requiring Firebase or Firestore.
class _StubProfileController extends ProfileController {
  final ProfileState _initial;
  _StubProfileController(this._initial);

  @override
  ProfileState build() => _initial;
}

Widget _buildScreen(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    // Wrap in Navigator so context.pop() works without needing go_router.
    child: MaterialApp(
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const Scaffold(body: EditProfileScreen()),
        ),
      ),
    ),
  );
}

void main() {
  group('EditProfileScreen — private-account toggle', () {
    testWidgets('shows "Anyone can view" subtitle when isPrivate=false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen([
          profileControllerProvider.overrideWith(
            () => _StubProfileController(
              const ProfileState(
                followers: [],
                privacy: ProfilePrivacyModel(isPrivate: false),
              ),
            ),
          ),
        ]),
      );
      await tester.pump();

      expect(find.text('Private account'), findsOneWidget);
      expect(find.text('Anyone can view your profile'), findsOneWidget);
      expect(find.text('Only followers can view your profile'), findsNothing);
    });

    testWidgets(
      'shows "Only followers can view" subtitle when isPrivate=true',
      (tester) async {
        await tester.pumpWidget(
          _buildScreen([
            profileControllerProvider.overrideWith(
              () => _StubProfileController(
                const ProfileState(
                  followers: [],
                  privacy: ProfilePrivacyModel(isPrivate: true),
                ),
              ),
            ),
          ]),
        );
        await tester.pump();

        expect(
          find.text('Only followers can view your profile'),
          findsOneWidget,
        );
        expect(find.text('Anyone can view your profile'), findsNothing);
      },
    );

    testWidgets('tapping switch updates subtitle from public to private', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen([
          profileControllerProvider.overrideWith(
            () => _StubProfileController(
              const ProfileState(
                followers: [],
                privacy: ProfilePrivacyModel(isPrivate: false),
              ),
            ),
          ),
        ]),
      );
      await tester.pump();

      // Precondition: public subtitle visible.
      expect(find.text('Anyone can view your profile'), findsOneWidget);

      // Tap the adaptive switch.
      await tester.tap(find.byType(Switch).first);
      await tester.pump();

      // Subtitle flips to private.
      expect(find.text('Only followers can view your profile'), findsOneWidget);
      expect(find.text('Anyone can view your profile'), findsNothing);
    });
  });

  group('EditProfileScreen — avatar section', () {
    testWidgets('shows person icon when no avatar URL is set', (tester) async {
      await tester.pumpWidget(
        _buildScreen([
          profileControllerProvider.overrideWith(
            () => _StubProfileController(
              const ProfileState(followers: [], avatarUrl: null),
            ),
          ),
        ]),
      );
      await tester.pump();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('no upload spinner visible when not uploading', (tester) async {
      await tester.pumpWidget(
        _buildScreen([
          profileControllerProvider.overrideWith(
            () => _StubProfileController(const ProfileState(followers: [])),
          ),
        ]),
      );
      await tester.pump();

      // CircularProgressIndicator inside a SizedBox(28×28) should be absent.
      expect(
        find.descendant(
          of: find.byType(CircleAvatar),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    });
  });

  group('EditProfileScreen — save button state', () {
    testWidgets('Save button is enabled when not loading', (tester) async {
      await tester.pumpWidget(
        _buildScreen([
          profileControllerProvider.overrideWith(
            () => _StubProfileController(
              const ProfileState(followers: [], isLoading: false),
            ),
          ),
        ]),
      );
      await tester.pump();

      final saveButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('Save button is disabled when isLoading=true', (tester) async {
      await tester.pumpWidget(
        _buildScreen([
          profileControllerProvider.overrideWith(
            () => _StubProfileController(
              const ProfileState(followers: [], isLoading: true),
            ),
          ),
        ]),
      );
      await tester.pump();

      final saveButton = tester.widget<TextButton>(
        find.byType(TextButton).first,
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('error text is displayed when state.error is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen([
          profileControllerProvider.overrideWith(
            () => _StubProfileController(
              const ProfileState(followers: [], error: 'Something went wrong'),
            ),
          ),
        ]),
      );
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
    });
  });
}
