import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/speed_dating/services/speed_dating_service.dart';
import 'package:mixvy/services/moderation_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _MockHttpsCallable extends Mock implements HttpsCallable {}

class _MockCallableResult extends Mock
    implements HttpsCallableResult<Map<String, dynamic>> {}

SpeedDatingService _buildService(
  FakeFirebaseFirestore firestore, {
  List<Map<String, dynamic>> candidates = const [],
}) {
  final functions = _MockFirebaseFunctions();
  final callable = _MockHttpsCallable();
  final result = _MockCallableResult();
  when(() => functions.httpsCallable(any())).thenReturn(callable);
  when(
    () => callable.call<Map<String, dynamic>>(),
  ).thenAnswer((_) async => result);
  when(() => result.data).thenReturn({'candidates': candidates});
  return SpeedDatingService(
    firestore: firestore,
    moderationService: ModerationService(firestore: firestore),
    functions: functions,
  );
}

void main() {
  group('SpeedDatingService', () {
    test('candidatesStream emits empty list when no users exist', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _buildService(firestore);
      final candidates = await service
          .candidatesStream(currentUserId: 'user-1')
          .first;
      expect(candidates, isEmpty);
    });

    test('candidatesStream excludes the current user from results', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _buildService(
        firestore,
        candidates: [
          {'id': 'user-1', 'username': 'Me'},
          {'id': 'user-2', 'username': 'Alice'},
        ],
      );
      final candidates = await service
          .candidatesStream(currentUserId: 'user-1')
          .first;
      final ids = candidates.map((c) => c.id).toList();
      expect(ids, contains('user-2'));
      expect(ids, isNot(contains('user-1')));
    });

    test('candidatesStream maps distance from the callable result', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _buildService(
        firestore,
        candidates: [
          {'id': 'user-2', 'username': 'Alice', 'distanceKm': 3.25},
          {'id': 'user-3', 'username': 'Bo'},
        ],
      );
      final candidates = await service
          .candidatesStream(currentUserId: 'user-1')
          .first;
      expect(candidates.map((c) => c.id), ['user-2', 'user-3']);
      expect(candidates.first.distanceKm, 3.25);
      expect(candidates.last.distanceKm, isNull);
    });

    test(
      'submitDecision returns no match when other user has not liked back',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = _buildService(firestore);
        final result = await service.submitDecision(
          fromUserId: 'user-1',
          toUserId: 'user-2',
          liked: true,
          sessionSeconds: 30,
        );
        expect(result.isMatch, isFalse);
      },
    );

    test('submitDecision returns no match on pass', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _buildService(firestore);
      final result = await service.submitDecision(
        fromUserId: 'user-1',
        toUserId: 'user-2',
        liked: false,
        sessionSeconds: 10,
      );
      expect(result.isMatch, isFalse);
    });

    test(
      'submitDecision returns match when both users like each other',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = _buildService(firestore);

        // user-2 liked user-1 first
        await firestore
            .collection('speed_dating_actions')
            .doc('user-2_user-1')
            .set({
              'decision': 'like',
              'fromUserId': 'user-2',
              'toUserId': 'user-1',
            });

        // user-1 now likes user-2 → mutual match
        final result = await service.submitDecision(
          fromUserId: 'user-1',
          toUserId: 'user-2',
          liked: true,
          sessionSeconds: 45,
        );

        expect(result.isMatch, isTrue);
        expect(result.matchId, isNotNull);
      },
    );

    test('matchesStream emits empty list when no matches exist', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _buildService(firestore);
      final matches = await service.matchesStream('user-1').first;
      expect(matches, isEmpty);
    });

    test('matchesStream emits matches for the given user', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('speed_dating_matches').doc('match-1').set({
        'participantIds': ['user-1', 'user-2'],
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      final service = _buildService(firestore);
      final matches = await service.matchesStream('user-1').first;
      expect(matches.length, 1);
      expect(matches.first.id, 'match-1');
    });
  });
}
