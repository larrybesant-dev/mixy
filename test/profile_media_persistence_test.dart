import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import 'package:mixvy/features/profile/profile_controller.dart';
import 'package:mixvy/services/profile_service.dart';

import 'test_helpers.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _AuthenticatedController extends AuthController {
  @override
  AuthState build() => const AuthState(uid: 'tester');
}

class _FailOnceService extends ProfileService {
  _FailOnceService({required super.firestore, required super.auth});
  bool fail = true;

  @override
  Future<void> saveProfile({
    required String userId,
    required Map<String, dynamic> userData,
    required bool privacy,
    required bool adultProfile,
  }) async {
    if (fail) {
      fail = false;
      throw StateError('Test save failure');
    }
    await super.saveProfile(
      userId: userId,
      userData: userData,
      privacy: privacy,
      adultProfile: adultProfile,
    );
  }
}

void main() {
  setUpAll(testSetup);

  test('avatar, cover and gallery survive a save and fresh editor reload',
      () async {
    final firestore = FakeFirebaseFirestore();
    final auth = _Auth();
    when(() => auth.currentUser).thenReturn(null);
    final client = MockClient((_) async => http.Response('', 503));
    addTearDown(client.close);
    final service = ProfileService(
      firestore: firestore,
      auth: auth,
      httpClient: client,
    );
    ProviderContainer container() => ProviderContainer(overrides: [
          profileServiceProvider.overrideWithValue(service),
          authControllerProvider.overrideWith(_AuthenticatedController.new),
        ]);
    final first = container();
    addTearDown(first.dispose);
    const profile = ProfileState(
      userId: 'tester',
      username: 'Tester',
      avatarUrl: 'https://storage.example.test/avatar.jpg',
      coverPhotoUrl: 'https://storage.example.test/cover.jpg',
      galleryUrls: [
        'https://storage.example.test/gallery-1.jpg',
        'https://storage.example.test/gallery-2.jpg',
      ],
      aboutMe: 'Existing profile text',
      interests: ['Music'],
      vibePrompt: 'Existing prompt',
    );
    await first.read(profileControllerProvider.notifier).updateProfile(profile);
    expect(first.read(profileControllerProvider).error, isNull);

    final fresh = container();
    addTearDown(fresh.dispose);
    final controller = fresh.read(profileControllerProvider.notifier);
    await controller.loadCurrentProfile();
    final loaded = fresh.read(profileControllerProvider);
    expect(loaded.error, isNull);
    expect(loaded.avatarUrl, profile.avatarUrl);
    expect(loaded.coverPhotoUrl, profile.coverPhotoUrl);
    expect(loaded.galleryUrls, profile.galleryUrls);
    expect(loaded.aboutMe, profile.aboutMe);
    expect(loaded.interests, profile.interests);
    expect(loaded.vibePrompt, profile.vibePrompt);

    await controller.updateProfile(loaded.copyWith(bio: 'Edited bio'));
    final saved =
        await firestore.collection('profile_public').doc('tester').get();
    expect(saved.data()?['galleryUrls'], profile.galleryUrls);
    expect(saved.data()?['coverPhotoUrl'], profile.coverPhotoUrl);
  });

  test('successful retry clears the previous save error', () async {
    final firestore = FakeFirebaseFirestore();
    final auth = _Auth();
    when(() => auth.currentUser).thenReturn(null);
    final service = _FailOnceService(firestore: firestore, auth: auth);
    final container = ProviderContainer(overrides: [
      profileServiceProvider.overrideWithValue(service),
      authControllerProvider.overrideWith(_AuthenticatedController.new),
    ]);
    addTearDown(container.dispose);
    final controller = container.read(profileControllerProvider.notifier);
    await controller.updateProfile(const ProfileState(username: 'Tester'));
    final failed = container.read(profileControllerProvider);
    expect(failed.error, contains('Test save failure'));
    await controller.updateProfile(failed.copyWith(
      username: 'Tester',
      avatarUrl: 'https://storage.example.test/avatar.jpg',
    ));
    expect(container.read(profileControllerProvider).error, isNull);
    expect(container.read(profileControllerProvider).isLoading, isFalse);
  });

  test('copyWith preserves an error unless explicitly cleared', () {
    const state = ProfileState(error: 'Save failed');
    expect(state.copyWith(bio: 'Draft').error, 'Save failed');
    expect(state.copyWith(error: null).error, isNull);
  });
}
