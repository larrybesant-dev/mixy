import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/profile/profile_controller.dart';
import 'package:mixvy/features/profile/models/user_model.dart' as profile_model;
import 'package:mixvy/models/profile_privacy_model.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late MockUser user;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    user = MockUser();

    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('user123');
    when(() => user.email).thenReturn('user@example.com');
    when(() => user.displayName).thenReturn('username');
    when(() => user.photoURL).thenReturn('');
    when(() => user.reload()).thenAnswer((_) async {});
    when(() => user.updateDisplayName(any())).thenAnswer((_) async {});
    when(() => user.updatePhotoURL(any())).thenAnswer((_) async {});
  });

  group('ProfileController', () {
    test(
      'profile user model falls back to displayName when username is absent',
      () {
        final user = profile_model.UserModel.fromJson({
          'id': 'user123',
          'email': 'user@example.com',
          'displayName': 'Larry Besant',
        });

        expect(user.username, 'Larry Besant');
      },
    );

    test('fetchProfile loads the Firestore user document', () async {
      await firestore.collection('users').doc('user123').set({
        'id': 'user123',
        'username': 'username',
        'email': 'user@example.com',
        'avatarUrl': '',
        'coinBalance': 10,
        'membershipLevel': 'Premium',
        'followers': <String>[],
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      });

      final container = ProviderContainer(
        overrides: [
          profileControllerProvider.overrideWith(
            () => ProfileController(firestore: firestore, auth: auth),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);
      await controller.fetchProfile('user123');

      final state = container.read(profileControllerProvider);
      expect(state.userId, 'user123');
      expect(state.username, 'username');
      expect(state.email, 'user@example.com');
      expect(state.membershipLevel, 'Premium');
    });

    test('updateProfile saves against the authenticated uid', () async {
      final container = ProviderContainer(
        overrides: [
          profileControllerProvider.overrideWith(
            () => ProfileController(firestore: firestore, auth: auth),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);
      await controller.updateProfile(
        const ProfileState(
          username: 'testuser',
          email: 'test@mixvy.com',
          avatarUrl: '',
          coinBalance: 10,
          membershipLevel: 'Premium',
          followers: [],
        ),
      );

      final snapshot = await firestore.collection('users').doc('user123').get();
      final data = snapshot.data();
      expect(data, isNotNull);
      expect(data!['username'], 'testuser');
      expect(data['email'], 'test@mixvy.com');

      final state = container.read(profileControllerProvider);
      expect(state.userId, 'user123');
      expect(state.username, 'testuser');
      expect(state.error, isNull);
    });

    test('updateProfile persists isPrivate=true to Firestore', () async {
      final container = ProviderContainer(
        overrides: [
          profileControllerProvider.overrideWith(
            () => ProfileController(firestore: firestore, auth: auth),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);
      await controller.updateProfile(
        const ProfileState(
          username: 'testuser',
          email: 'test@mixvy.com',
          avatarUrl: '',
          coinBalance: 0,
          membershipLevel: 'Free',
          followers: [],
          privacy: ProfilePrivacyModel(isPrivate: true),
        ),
      );

      final snapshot = await firestore.collection('users').doc('user123').get();
      expect(snapshot.data()!['isPrivate'], isTrue);

      final state = container.read(profileControllerProvider);
      expect(state.privacy.isPrivate, isTrue);
      expect(state.error, isNull);
    });

    test('updateProfile persists isPrivate=false to Firestore', () async {
      final container = ProviderContainer(
        overrides: [
          profileControllerProvider.overrideWith(
            () => ProfileController(firestore: firestore, auth: auth),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(profileControllerProvider.notifier);
      await controller.updateProfile(
        const ProfileState(
          username: 'testuser',
          email: 'test@mixvy.com',
          avatarUrl: '',
          coinBalance: 0,
          membershipLevel: 'Free',
          followers: [],
        ),
      );

      final snapshot = await firestore.collection('users').doc('user123').get();
      expect(snapshot.data()!['isPrivate'], isFalse);

      final state = container.read(profileControllerProvider);
      expect(state.privacy.isPrivate, isFalse);
    });

    test(
      'updateProfile keeps extended profile fields out of the core users doc',
      () async {
        final container = ProviderContainer(
          overrides: [
            profileControllerProvider.overrideWith(
              () => ProfileController(firestore: firestore, auth: auth),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(profileControllerProvider.notifier);
        await controller.updateProfile(
          const ProfileState(
            username: 'curve',
            email: 'curve@mixvy.com',
            avatarUrl: 'https://cdn.mixvy.test/avatar.png',
            coverPhotoUrl: 'https://cdn.mixvy.test/cover.png',
            aboutMe: 'Velvet Noir energy.',
            themeId: 'gold-night',
            followers: [],
          ),
        );

        final userDoc = await firestore
            .collection('users')
            .doc('user123')
            .get();
        final profilePublicDoc = await firestore
            .collection('profile_public')
            .doc('user123')
            .get();
        final preferencesDoc = await firestore
            .collection('preferences')
            .doc('user123')
            .get();

        expect(userDoc.data()!['username'], 'curve');
        expect(userDoc.data(), isNot(contains('coverPhotoUrl')));
        expect(userDoc.data(), isNot(contains('aboutMe')));
        expect(
          profilePublicDoc.data()!['coverPhotoUrl'],
          'https://cdn.mixvy.test/cover.png',
        );
        expect(profilePublicDoc.data()!['aboutMe'], 'Velvet Noir energy.');
        expect(preferencesDoc.data()!['themeId'], 'gold-night');
      },
    );
  });
}
