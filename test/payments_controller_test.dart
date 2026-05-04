import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/payments/payments_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

class MockPaymentGateway extends Mock implements PaymentGateway {}

class MockUser extends Mock implements User {}

void main() {
  group('PaymentsController', () {
    late ProviderContainer container;
    late MockPaymentGateway gateway;
    late MockUser user;

    setUp(() {
      gateway = MockPaymentGateway();
      user = MockUser();

      when(() => user.uid).thenReturn('user-123');
      when(() => gateway.currentUser).thenReturn(user);
      when(() => gateway.sendPayment(any(), any())).thenAnswer((_) async {});
      when(
        () => gateway.requestPayment(any(), any(), any()),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          paymentControllerProvider.overrideWith(
            () => PaymentController(gateway: gateway),
          ),
        ],
      );
    });

    test('sendCoins sets success state', () async {
      final controller = container.read(paymentControllerProvider.notifier);
      await controller.sendCoins(receiverId: 'receiver-1', amount: 100);
      final state = container.read(paymentControllerProvider);
      expect(state.amount, 100);
      expect(state.successmessage, 'Payment sent successfully.');
      expect(state.isConfirmed, true);
      expect(state.error, isNull);
    });

    test('requestCoins sets success state', () async {
      final controller = container.read(paymentControllerProvider.notifier);
      await controller.requestCoins(targetId: 'target-7', amount: 25);
      final state = container.read(paymentControllerProvider);
      expect(state.amount, 25);
      expect(state.successmessage, 'Payment request sent successfully.');
      expect(state.isConfirmed, true);
      expect(state.error, isNull);
    });
  });
}
