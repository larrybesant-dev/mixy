class PaymentService {
  static const bool _legacyPaymentServiceEnabled = false;

  Future<void> processPayment(double amount) async {
    if (!_legacyPaymentServiceEnabled) {
      return;
    }
  }
}
