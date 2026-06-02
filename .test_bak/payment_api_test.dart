import 'package:firebase_auth/firebase_auth.dart';
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
    Map<String, dynamic> payload) async {
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

void main() {
  late MockUser mockUser;

  setUp(() {
    mockUser = MockUser();
    when(() => mockUser.uid).thenReturn('user-123');
  });

  tearDown(() {
    PaymentApi.resetForTesting();
  });

  test(
    'createIntent calls createPaymentIntent with expected payload',
    () async {
      final gateway = FakePaymentFunctionsGateway(
        responses: const <String, dynamic>{
          'clientSecret': 'secret_abc',
          'paymentIntentId': 'pi_123',
        });
      PaymentApi.configureForTesting(
        functionsGateway: gateway,
        authGateway: FakePaymentAuthGateway(mockUser));

      final result = await PaymentApi.createIntent(
        amount: 12.5,
        currency: 'usd',
        recipientId: 'receiver-1');

      expect(result.clientSecret, 'secret_abc');
      expect(result.paymentIntentId, 'pi_123');
      expect(result.idempotencyKey, startsWith('intent_'));
      expect(gateway.calls, hasLength(1));
      expect(gateway.calls.single.name, 'createPaymentIntent');
      expect(gateway.calls.single.payload['amount'], 12.5);
      expect(gateway.calls.single.payload['currency'], 'usd');
      expect(gateway.calls.single.payload['recipientId'], 'receiver-1');
      expect(
        gateway.calls.single.payload['idempotencyKey'] as String,
        startsWith('intent_'));
    });

  test('notifySuccess requires authenticated user', () async {
    PaymentApi.configureForTesting(
      functionsGateway: FakePaymentFunctionsGateway(),
      authGateway: FakePaymentAuthGateway(null));

    await expectLater(
      () => PaymentApi.notifySuccess(
        recipientId: 'receiver-1',
        amount: 5,
        paymentIntentId: 'pi_missing_auth'),
      throwsA(isA<Exception>()));
  });

  test('sendPayment calls sendCoinTransfer callable', () async {
    final gateway = FakePaymentFunctionsGateway();
    PaymentApi.configureForTesting(
      functionsGateway: gateway,
      authGateway: FakePaymentAuthGateway(mockUser));

    await PaymentApi.sendPayment('receiver-9', 42);

    expect(gateway.calls, hasLength(1));
    expect(gateway.calls.single.name, 'sendCoinTransfer');
    expect(gateway.calls.single.payload['receiverId'], 'receiver-9');
    expect(gateway.calls.single.payload['amount'], 42.0);
    expect(
      gateway.calls.single.payload['idempotencyKey'] as String,
      startsWith('send_'));
  });

  test('requestPayment rejects mismatched requesterId', () async {
    final gateway = FakePaymentFunctionsGateway();
    PaymentApi.configureForTesting(
      functionsGateway: gateway,
      authGateway: FakePaymentAuthGateway(mockUser));

    await expectLater(
      () => PaymentApi.requestPayment('other-user', 'target-1', 9),
      throwsA(isA<Exception>()));
    expect(gateway.calls, isEmpty);
  });

  test(
    'requestPayment calls requestCoinTransfer for authenticated requester',
    () async {
      final gateway = FakePaymentFunctionsGateway();
      PaymentApi.configureForTesting(
        functionsGateway: gateway,
        authGateway: FakePaymentAuthGateway(mockUser));

      await PaymentApi.requestPayment('user-123', 'target-1', 9);

      expect(gateway.calls, hasLength(1));
      expect(gateway.calls.single.name, 'requestCoinTransfer');
      expect(gateway.calls.single.payload['targetId'], 'target-1');
      expect(gateway.calls.single.payload['amount'], 9.0);
      expect(
        gateway.calls.single.payload['idempotencyKey'] as String,
        startsWith('request_'));
    });

  test(
    'requestRefund validates reason length before calling backend',
    () async {
      final gateway = FakePaymentFunctionsGateway();
      PaymentApi.configureForTesting(
        functionsGateway: gateway,
        authGateway: FakePaymentAuthGateway(mockUser));

      await expectLater(
        () => PaymentApi.requestRefund(transactionId: 'tx-1', reason: 'short'),
        throwsA(isA<Exception>()));
      expect(gateway.calls, isEmpty);
    });

  test(
    'requestRefund calls requestRefund callable with expected payload',
    () async {
      final gateway = FakePaymentFunctionsGateway();
      PaymentApi.configureForTesting(
        functionsGateway: gateway,
        authGateway: FakePaymentAuthGateway(mockUser));

      await PaymentApi.requestRefund(
        transactionId: 'tx-55',
        reason: 'Duplicate charge due to retry flow.');

      expect(gateway.calls, hasLength(1));
      expect(gateway.calls.single.name, 'requestRefund');
      expect(gateway.calls.single.payload, <String, dynamic>{
        'transactionId': 'tx-55',
        'reason': 'Duplicate charge due to retry flow.',
      });
    });
}










