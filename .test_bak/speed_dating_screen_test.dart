import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/speed_dating/services/speed_dating_service.dart';
import 'package:mixvy/services/moderation_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

SpeedDatingService _buildService(FakeFirebaseFirestore firestore) {
  return SpeedDatingService(
    
    moderationService: ModerationService(),
    functions: _MockFirebaseFunctions());
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
      await firestore.collection('users').doc('user-1').set({'username': 'Me'});
      await firestore.collection('users').doc('user-2').set({
        'username': 'Alice',
      });
      final service = _buildService(firestore);
      final candidates = await service
          .candidatesStream(currentUserId: 'user-1')
          .first;
      final ids = candidates.map((c) => c.id).toList();
      expect(ids, contains('user-2'));
      expect(ids, isNot(contains('user-1')));
    });

    test('candidatesStream excludes users with empty username', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('user-2').set({
        'username': 'Alice',
      });
      await firestore.collection('users').doc('user-3').set({'username': ''});
      final service = _buildService(firestore);
      final candidates = await service
          .candidatesStream(currentUserId: 'user-1')
          .first;
      final ids = candidates.map((c) => c.id).toList();
      expect(ids, contains('user-2'));
      expect(ids, isNot(contains('user-3')));
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
          sessionSeconds: 30);
        expect(result.isMatch, isFalse);
      });

    test('submitDecision returns no match on pass', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _buildService(firestore);
      final result = await service.submitDecision(
        fromUserId: 'user-1',
        toUserId: 'user-2',
        liked: false,
        sessionSeconds: 10);
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
          sessionSeconds: 45);

        expect(result.isMatch, isTrue);
        expect(result.matchId, isNotNull);
      });

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










