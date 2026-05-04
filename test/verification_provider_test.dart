import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/verification/providers/verification_provider.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('VerificationController', () {
    late FakeFirebaseFirestore firestore;
    late VerificationController controller;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      controller = VerificationController(firestore: firestore);
    });

    test(
      'verifyUser is blocked on client and must use Cloud Functions',
      () async {
        await firestore.collection('users').doc('user-1').set({
          'username': 'jazzfan',
        });

        expect(
          () => controller.verifyUser(userId: 'user-1', verifiedBy: 'admin'),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );

    test(
      'unverifyUser is blocked on client and must use Cloud Functions',
      () async {
        await firestore.collection('verification').doc('user-1').set({
          'userId': 'user-1',
          'isVerified': true,
          'verifiedBy': 'admin',
        });

        expect(
          () => controller.unverifyUser(userId: 'user-1'),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );
  });

  group('userVerificationProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(firestore)],
      );
    });

    tearDown(() => container.dispose());

    test('returns false when user document does not exist', () async {
      final value = await container.read(
        userVerificationProvider('ghost-user').future,
      );
      expect(value, isFalse);
    });

    test('returns false when isVerified is not set', () async {
      await firestore.collection('users').doc('user-1').set({
        'username': 'jazzfan',
      });

      final value = await container.read(
        userVerificationProvider('user-1').future,
      );
      expect(value, isFalse);
    });

    test('returns true when isVerified is true', () async {
      await firestore.collection('users').doc('user-1').set({
        'username': 'jazzfan',
        'isVerified': true,
      });

      final value = await container.read(
        userVerificationProvider('user-1').future,
      );
      expect(value, isTrue);
    });

    test('reflects updated isVerified value in a fresh read', () async {
      await firestore.collection('users').doc('user-1').set({
        'username': 'jazzfan',
        'isVerified': false,
      });

      // First read — unverified
      final before = await container.read(
        userVerificationProvider('user-1').future,
      );
      expect(before, isFalse);

      // Update the document, then read via a fresh container
      await firestore.collection('users').doc('user-1').update({
        'isVerified': true,
      });

      final freshContainer = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(firestore)],
      );
      addTearDown(freshContainer.dispose);

      final after = await freshContainer.read(
        userVerificationProvider('user-1').future,
      );
      expect(after, isTrue);
    });
  });

  group('verifiedUsersProvider', () {
    late FakeFirebaseFirestore firestore;
    late ProviderContainer container;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      container = ProviderContainer(
        overrides: [firestoreProvider.overrideWithValue(firestore)],
      );
    });

    tearDown(() => container.dispose());

    test('returns empty list when no verified users', () async {
      final ids = await container.read(verifiedUsersProvider.future);
      expect(ids, isEmpty);
    });

    test('returns only verified user IDs', () async {
      await firestore.collection('verification').doc('user-1').set({
        'isVerified': true,
      });
      await firestore.collection('verification').doc('user-2').set({
        'isVerified': false,
      });
      await firestore.collection('verification').doc('user-3').set({
        'isVerified': true,
      });

      final ids = await container.read(verifiedUsersProvider.future);
      expect(ids, containsAll(['user-1', 'user-3']));
      expect(ids, isNot(contains('user-2')));
    });
  });
}
