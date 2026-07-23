import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/services/payment_api.dart';
import 'package:mocktail/mocktail.dart';

class MockUser extends Mock implements User {}

class FakePaymentFunctionsGateway extends Fake
    implements PaymentFunctionsGateway {
  final List<({String name, Map<String, dynamic> payload})> calls = [];
  final Map<String, dynamic> responses;
  final Object? error;

  FakePaymentFunctionsGateway({
    this.responses = const <String, dynamic>{'clientSecret': 'secret_123'},
    this.error,
  });

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    calls.add((name: name, payload: Map<String, dynamic>.from(payload)));
    if (error != null) {
      throw error!;
    }
    return responses;
  }
}

class FakePaymentAuthGateway extends Fake implements PaymentAuthGateway {
  FakePaymentAuthGateway(this._currentUser);

  final User? _currentUser;

  @override
  User? get currentUser => _currentUser;
}

class MockRef extends Mock implements Ref {}

void main() {
  late MockUser mockUser;

  setUp(() {
    mockUser = MockUser();
    when(() => mockUser.uid).thenReturn('user-123');
  });

  test(
    'createIntent calls createPaymentIntent with expected payload',
    () async {
      final functionsGateway = FakePaymentFunctionsGateway(
        responses: const <String, dynamic>{
          'clientSecret': 'secret_abc',
          'paymentIntentId': 'pi_123',
        },
      );
      final authGateway = FakePaymentAuthGateway(mockUser);
      final mockRef = MockRef();

      final paymentApi = PaymentApi(
        mockRef,
        functionsGateway: functionsGateway,
        authGateway: authGateway,
      );

      final result = await paymentApi.createIntent(
        amount: 12.5,
        currency: 'usd',
        recipientId: 'receiver-1',
      );

      expect(result.clientSecret, 'secret_abc');
      expect(result.paymentIntentId, 'pi_123');
      expect(result.idempotencyKey, startsWith('intent_'));
      expect(functionsGateway.calls, hasLength(1));
      expect(functionsGateway.calls.single.name, 'createPaymentIntent');
      expect(functionsGateway.calls.single.payload['amount'], 12.5);
      expect(functionsGateway.calls.single.payload['currency'], 'usd');
      expect(functionsGateway.calls.single.payload['recipientId'], 'receiver-1');
      expect(
        functionsGateway.calls.single.payload['idempotencyKey'] as String,
        startsWith('intent_'),
      );
    },
  );

  test('notifySuccess requires authenticated user', () async {
    final functionsGateway = FakePaymentFunctionsGateway();
    final authGateway = FakePaymentAuthGateway(null);
    final mockRef = MockRef();

    final paymentApi = PaymentApi(
      mockRef,
      functionsGateway: functionsGateway,
      authGateway: authGateway,
    );

    await expectLater(
      () => paymentApi.notifySuccess(
        recipientId: 'receiver-1',
        amount: 5,
        paymentIntentId: 'pi_missing_auth',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('sendPayment calls sendCoinTransfer callable', () async {
    final functionsGateway = FakePaymentFunctionsGateway();
    final authGateway = FakePaymentAuthGateway(mockUser);
    final mockRef = MockRef();

    final paymentApi = PaymentApi(
      mockRef,
      functionsGateway: functionsGateway,
      authGateway: authGateway,
    );

    await paymentApi.sendPayment('receiver-9', 42);

    expect(functionsGateway.calls, hasLength(1));
    expect(functionsGateway.calls.single.name, 'sendCoinTransfer');
    expect(functionsGateway.calls.single.payload['receiverId'], 'receiver-9');
    expect(functionsGateway.calls.single.payload['amount'], 42.0);
    expect(
      functionsGateway.calls.single.payload['idempotencyKey'] as String,
      startsWith('send_'),
    );
  });

  test('requestPayment rejects mismatched requesterId', () async {
    final functionsGateway = FakePaymentFunctionsGateway();
    final authGateway = FakePaymentAuthGateway(mockUser);
    final mockRef = MockRef();

    final paymentApi = PaymentApi(
      mockRef,
      functionsGateway: functionsGateway,
      authGateway: authGateway,
    );

    await expectLater(
      () => paymentApi.requestPayment('other-user', 'target-1', 9),
      throwsA(isA<Exception>()),
    );
    expect(functionsGateway.calls, isEmpty);
  });

  test(
    'requestPayment calls requestCoinTransfer for authenticated requester',
    () async {
      final functionsGateway = FakePaymentFunctionsGateway();
      final authGateway = FakePaymentAuthGateway(mockUser);
      final mockRef = MockRef();

      final paymentApi = PaymentApi(
        mockRef,
        functionsGateway: functionsGateway,
        authGateway: authGateway,
      );

      await paymentApi.requestPayment('user-123', 'target-1', 9);

      expect(functionsGateway.calls, hasLength(1));
      expect(functionsGateway.calls.single.name, 'requestCoinTransfer');
      expect(functionsGateway.calls.single.payload['targetId'], 'target-1');
      expect(functionsGateway.calls.single.payload['amount'], 9.0);
      expect(
        functionsGateway.calls.single.payload['idempotencyKey'] as String,
        startsWith('request_'),
      );
    },
  );

  test(
    'requestRefund validates reason length before calling backend',
    () async {
      final functionsGateway = FakePaymentFunctionsGateway();
      final authGateway = FakePaymentAuthGateway(mockUser);
      final mockRef = MockRef();

      final paymentApi = PaymentApi(
        mockRef,
        functionsGateway: functionsGateway,
        authGateway: authGateway,
      );

      await expectLater(
        () => paymentApi.requestRefund(transactionId: 'tx-1', reason: 'short'),
        throwsA(isA<Exception>()),
      );
      expect(functionsGateway.calls, isEmpty);
    },
  );

  test(
    'requestRefund calls requestRefund callable with expected payload',
    () async {
      final functionsGateway = FakePaymentFunctionsGateway();
      final authGateway = FakePaymentAuthGateway(mockUser);
      final mockRef = MockRef();

      final paymentApi = PaymentApi(
        mockRef,
        functionsGateway: functionsGateway,
        authGateway: authGateway,
      );

      await paymentApi.requestRefund(
        transactionId: 'tx-55',
        reason: 'Duplicate charge due to retry flow.',
      );

      expect(functionsGateway.calls, hasLength(1));
      expect(functionsGateway.calls.single.name, 'requestRefund');
      expect(functionsGateway.calls.single.payload, <String, dynamic>{
        'transactionId': 'tx-55',
        'reason': 'Duplicate charge due to retry flow.',
      });
    },
  );
}
