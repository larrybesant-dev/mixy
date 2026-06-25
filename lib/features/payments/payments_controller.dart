import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/payment_api.dart';

abstract class PaymentGateway {
  User? get currentUser;

  Future<void> sendPayment(String receiverId, double amount);

  Future<void> requestPayment(
    String requesterId,
    String targetId,
    double amount,
  );
}

class PaymentApiGateway implements PaymentGateway {
  @override
  User? get currentUser => FirebaseAuth.instance.currentUser;

  @override
  Future<void> sendPayment(String receiverId, double amount) {
    return PaymentApi.sendPayment(receiverId, amount);
  }

  @override
  Future<void> requestPayment(
    String requesterId,
    String targetId,
    double amount,
  ) {
    return PaymentApi.requestPayment(requesterId, targetId, amount);
  }
}

class PaymentState {
  final bool isLoading;
  final String? error;
  final double? amount;
  final String? successmessage;
  final bool isConfirmed;

  static const Object _unset = Object();

  const PaymentState({
    this.isLoading = false,
    this.error,
    this.amount,
    this.successmessage,
    this.isConfirmed = false,
  });

  PaymentState copyWith({
    bool? isLoading,
    Object? error = _unset,
    double? amount,
    Object? successmessage = _unset,
    bool? isConfirmed,
  }) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unset) ? this.error : error as String?,
      amount: amount ?? this.amount,
      successmessage: identical(successmessage, _unset)
          ? this.successmessage
          : successmessage as String?,
      isConfirmed: isConfirmed ?? this.isConfirmed,
    );
  }
}

class PaymentController extends Notifier<PaymentState> {
  PaymentController({PaymentGateway? gateway})
    : _gateway = gateway ?? PaymentApiGateway();

  final PaymentGateway _gateway;

  @override
  PaymentState build() => const PaymentState();

  Future<void> sendCoins({
    required String receiverId,
    required double amount,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      successmessage: null,
      amount: amount,
      isConfirmed: false,
    );

    try {
      await _gateway.sendPayment(receiverId, amount);
      state = state.copyWith(
        isLoading: false,
        error: null,
        successmessage: 'Payment sent successfully.',
        isConfirmed: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        successmessage: null,
        isConfirmed: false,
      );
    }
  }

  Future<void> requestCoins({
    required String targetId,
    required double amount,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      successmessage: null,
      amount: amount,
      isConfirmed: false,
    );

    final user = _gateway.currentUser;
    if (user == null) {
      state = state.copyWith(isLoading: false, error: 'User not logged in');
      return;
    }

    try {
      await _gateway.requestPayment(user.uid, targetId, amount);
      state = state.copyWith(
        isLoading: false,
        error: null,
        successmessage: 'Payment request sent successfully.',
        isConfirmed: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        successmessage: null,
        isConfirmed: false,
      );
    }
  }

  void updateLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void updateError(String? error) {
    state = state.copyWith(error: error);
  }

  void clearState() {
    state = const PaymentState();
  }
}

final paymentControllerProvider =
    NotifierProvider<PaymentController, PaymentState>(
      () => PaymentController(),
    );




