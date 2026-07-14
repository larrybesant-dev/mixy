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

class _FakeHttpsCallable extends Fake implements HttpsCallable {
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    return _FakeHttpsCallableResult<T>() as HttpsCallableResult<T>;
  }
}

class _FakeHttpsCallableResult<T> extends Fake implements HttpsCallableResult<T> {}

CashOutService _buildService({
  required FakeFirebaseFirestore firestore,
  String? uid,
}) {
  final auth = _MockFirebaseAuth();
  final functions = _MockFirebaseFunctions();
  
  if (uid != null) {
    final user = _MockUser();
    when(() => user.uid).thenReturn(uid);
    when(() => auth.currentUser).thenReturn(user);
  } else {
    when(() => auth.currentUser).thenReturn(null);
  }
  
  when(() => functions.httpsCallable(any())).thenReturn(_FakeHttpsCallable());
  
  return CashOutService(firestore: firestore, auth: auth, functions: functions);
}

void main() {
  group('CashOutService', () {
    test(
      'requestsForCurrentUser returns empty stream when no user is signed in',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = _buildService(firestore: firestore);
        final requests = await service.requestsForCurrentUser().isEmpty;
        expect(requests, isTrue);
      },
    );

    test(
      'requestsForCurrentUser returns empty list when user has no requests',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = _buildService(firestore: firestore, uid: 'user-1');
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
        final service = _buildService(firestore: firestore, uid: 'user-1');
        final requests = await service.requestsForCurrentUser().first;
        expect(requests.length, 1);
        expect(requests.first.amount, 30.0);
      },
    );

    test('requestCashOut throws when user is not signed in', () async {
      final firestore = FakeFirebaseFirestore();
      final service = _buildService(firestore: firestore);
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
        final service = _buildService(firestore: firestore, uid: 'user-1');
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
        final service = _buildService(firestore: firestore, uid: 'user-1');
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
      'requestCashOut saves a pending request when conditions are met',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('wallets').doc('user-1').set({
          'cashBalance': 100.0,
        });
        final service = _buildService(firestore: firestore, uid: 'user-1');
        await service.requestCashOut(30);
        final snapshot = await firestore
            .collection('cash_out_requests')
            .where('userId', isEqualTo: 'user-1')
            .get();
        expect(snapshot.docs.length, 1);
        expect(snapshot.docs.first.data()['status'], 'pending');
        expect(snapshot.docs.first.data()['amount'], 30.0);
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
        final service = _buildService(firestore: firestore, uid: 'user-1');
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
