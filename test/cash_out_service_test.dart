import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/services/cash_out_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _MockHttpsCallable extends Mock implements HttpsCallable {}

class _MockHttpsCallableResult extends Mock
    implements HttpsCallableResult<Map<String, dynamic>> {}

CashOutService _buildService({
  required FakeFirebaseFirestore firestore,
  required FirebaseFunctions functions,
  String? uid,
}) {
  final auth = _MockFirebaseAuth();
  
  if (uid != null) {
    final user = _MockUser();
    when(() => user.uid).thenReturn(uid);
    when(() => auth.currentUser).thenReturn(user);
  } else {
    when(() => auth.currentUser).thenReturn(null);
  }

  return CashOutService(firestore: firestore, auth: auth, functions: functions);
}

_MockFirebaseFunctions _buildFunctionsReturningRequestId(String requestId) {
  final functions = _MockFirebaseFunctions();
  final callable = _MockHttpsCallable();
  final result = _MockHttpsCallableResult();

  when(() => functions.httpsCallable('requestCashOut')).thenReturn(callable);
  when(
    () => callable.call<Map<String, dynamic>>(any()),
  ).thenAnswer((_) async => result);
  when(() => result.data).thenReturn(<String, dynamic>{'requestId': requestId});

  return functions;
}

void main() {
  group('CashOutService', () {
    test(
      'requestsForCurrentUser returns empty stream when no user is signed in',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = _buildService(
          firestore: firestore,
          functions: _buildFunctionsReturningRequestId('req_1'),
        );
        final requests = await service.requestsForCurrentUser().isEmpty;
        expect(requests, isTrue);
      },
    );

    test(
      'requestsForCurrentUser returns empty list when user has no requests',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = _buildService(
          firestore: firestore,
          uid: 'user-1',
          functions: _buildFunctionsReturningRequestId('req_1'),
        );
        final requests = await service.requestsForCurrentUser().first;
        expect(requests, isEmpty);
      },
    );

    test(
      "requestsForCurrentUser returns only the current user's requests",
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('cash_out_requests').add({
          'userId': 'user-1',
          'amount': 30.0,
          'status': 'pending',
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
        // Another user's request — should not appear.
        await firestore.collection('cash_out_requests').add({
          'userId': 'user-2',
          'amount': 50.0,
          'status': 'pending',
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
        final service = _buildService(
          firestore: firestore,
          uid: 'user-1',
          functions: _buildFunctionsReturningRequestId('req_1'),
        );
        final requests = await service.requestsForCurrentUser().first;
        expect(requests.length, 1);
        expect(requests.first.amount, 30.0);
      },
    );

    test('requestCashOut throws when user is not signed in', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _buildService(
        firestore: firestore,
        functions: _buildFunctionsReturningRequestId('req_1'),
      );
      await expectLater(service.requestCashOut(30), throwsA(isA<Exception>()));
    });

    test(
      'requestCashOut throws when amount is below minimum payout threshold',
      () async {
        final firestore = FakeFirebaseFirestore();
        // Wallet has enough balance.
        await firestore.collection('wallets').doc('user-1').set({
          'cashBalance': 100.0,
        });
        final service = _buildService(
          firestore: firestore,
          uid: 'user-1',
          functions: _buildFunctionsReturningRequestId('req_1'),
        );
        // \$10 is below the \$25 minimum.
        await expectLater(
          service.requestCashOut(10),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Minimum cash-out'),
            ),
          ),
        );
      },
    );

    test(
      'requestCashOut throws when requested amount exceeds available balance',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('wallets').doc('user-1').set({
          'cashBalance': 30.0,
        });
        final service = _buildService(
          firestore: firestore,
          uid: 'user-1',
          functions: _buildFunctionsReturningRequestId('req_1'),
        );
        await expectLater(
          service.requestCashOut(50),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('exceeds available'),
            ),
          ),
        );
      },
    );

    test(
      'requestCashOut returns callable requestId when accepted',
      () async {
        final firestore = FakeFirebaseFirestore();
        final functions = _buildFunctionsReturningRequestId('req_abc123');
        await firestore.collection('wallets').doc('user-1').set({
          'cashBalance': 100.0,
        });
        final service = _buildService(
          firestore: firestore,
          uid: 'user-1',
          functions: functions,
        );
        final requestId = await service.requestCashOut(30);
        expect(requestId, 'req_abc123');
      },
    );

    test(
      'requestCashOut sends amount payload to callable',
      () async {
        final firestore = FakeFirebaseFirestore();
        final functions = _MockFirebaseFunctions();
        final callable = _MockHttpsCallable();
        final result = _MockHttpsCallableResult();

        await firestore.collection('wallets').doc('user-1').set({
          'cashBalance': 100.0,
        });

        when(() => functions.httpsCallable('requestCashOut')).thenReturn(callable);
        when(
          () => callable.call<Map<String, dynamic>>(any()),
        ).thenAnswer((_) async => result);
        when(() => result.data).thenReturn(<String, dynamic>{'requestId': 'req_42'});

        final service = _buildService(
          firestore: firestore,
          uid: 'user-1',
          functions: functions,
        );

        await service.requestCashOut(30);

        verify(
          () => callable.call<Map<String, dynamic>>(
            <String, dynamic>{'amount': 30.0},
          ),
        ).called(1);
      },
    );

    test(
      'requestCashOut accounts for pending requests when checking available balance',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('wallets').doc('user-1').set({
          'cashBalance': 60.0,
        });
        // Existing pending request of \$40 leaves only \$20 available.
        await firestore.collection('cash_out_requests').add({
          'userId': 'user-1',
          'amount': 40.0,
          'status': 'pending',
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
        final service = _buildService(
          firestore: firestore,
          uid: 'user-1',
          functions: _buildFunctionsReturningRequestId('req_1'),
        );
        await expectLater(
          service.requestCashOut(30),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('exceeds available'),
            ),
          ),
        );
      },
    );
  });
}
