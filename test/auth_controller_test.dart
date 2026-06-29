import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mixvy/services/schema_mutation_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'test_helpers.dart';

class _MockSchemaMutationService extends Mock
    implements SchemaMutationService {}

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('AuthController', () {
    late ProviderContainer container;
    late User? currentUser;
    late _MockSchemaMutationService mockSchemaMutationService;

    setUp(() {
      currentUser = mockUser;
      mockSchemaMutationService = _MockSchemaMutationService();
      when(
        () => mockSchemaMutationService.createUserProfile(
          user: any(named: 'user'),
          preferredUsername: any(named: 'preferredUsername'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockAuth.currentUser).thenAnswer((_) => currentUser);
      when(
        () => mockAuth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {
        currentUser = mockUser;
        emitAuthState(mockUser);
        return mockUserCredential;
      });
      when(
        () => mockAuth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {
        currentUser = mockUser;
        emitAuthState(mockUser);
        return mockUserCredential;
      });
      when(() => mockAuth.signOut()).thenAnswer((_) async {
        currentUser = null;
        emitAuthState(null);
      });

      container = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          authControllerProvider.overrideWith(
            () => AuthController(
              firestore: mockFirestore,
              unregisterToken: () async {},
              schemaMutationService: mockSchemaMutationService,
            ),
          ),
        ],
      );
    });

    test('login sets user state', () async {
      final controller = container.read(authControllerProvider.notifier);
      await controller.login('test@example.com', 'password');
      final state = container.read(authControllerProvider);
      expect(state.uid, isNotNull);
      expect(state.error, isNull);
    });

    test('logout clears user state', () async {
      final controller = container.read(authControllerProvider.notifier);
      await controller.login('test@example.com', 'password');
      await controller.logout();
      // Wait for the authStateChanges stream to emit null and update state
      for (int i = 0; i < 20; i++) {
        final state = container.read(authControllerProvider);
        if (state.uid == null) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 10));
      }
      final state = container.read(authControllerProvider);
      expect(state.uid, isNull);
    });

    test('signup sets user state when username is provided', () async {
      final controller = container.read(authControllerProvider.notifier);
      await controller.signup('new@example.com', 'password', 'VelvetNoir');
      final state = container.read(authControllerProvider);
      expect(state.uid, isNotNull);
      expect(state.error, isNull);
    });

    test('signup persists the chosen username', () async {
      final controller = container.read(authControllerProvider.notifier);

      await controller.signup('new@example.com', 'password', 'VelvetNoir');

      verify(
        () => mockSchemaMutationService.createUserProfile(
          user: any(named: 'user'),
          preferredUsername: 'VelvetNoir',
        ),
      ).called(1);
    });

    test('signup rejects blank usernames', () async {
      final controller = container.read(authControllerProvider.notifier);
      await controller.signup('new@example.com', 'password', '   ');
      final state = container.read(authControllerProvider);
      expect(state.error, isNotNull);
      expect(state.error, contains('username'));
    });

    test('anonymous session is rejected on startup', () async {
      when(() => mockUser.isAnonymous).thenReturn(true);
      currentUser = mockUser;
      when(() => mockAuth.currentUser).thenAnswer((_) => currentUser);

      final localContainer = ProviderContainer(
        overrides: [
          firebaseAuthProvider.overrideWithValue(mockAuth),
          authControllerProvider.overrideWith(
            () => AuthController(
              firestore: mockFirestore,
              unregisterToken: () async {},
              schemaMutationService: mockSchemaMutationService,
            ),
          ),
        ],
      );
      addTearDown(localContainer.dispose);

      localContainer.read(authControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      verify(() => mockAuth.signOut()).called(greaterThanOrEqualTo(1));
    });
  });
}
