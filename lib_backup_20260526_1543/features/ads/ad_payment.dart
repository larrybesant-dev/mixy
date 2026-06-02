import 'package:flutter_stripe/flutter_stripe.dart';
// Handles business ad payments
// import '../payments/payment_intent_service.dart'; // Unused, can be removed
import '../../core/error_handler.dart';
import '../../core/logger.dart';
import '../../services/payment_api.dart';

class AdPayment {
  // Integrates Stripe for ad payments
  static Future<void> payForAd(String businessId, double amount) async {
    // Use PaymentApi to create a payment intent for ad payments
    try {
      final intent = await PaymentApi.createIntent(
        amount: amount,
        currency: 'usd',
        recipientId: businessId,
      );
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent.clientSecret,
          merchantDisplayName: 'MixVy',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      // Notify backend of successful payment so the transaction is recorded
      // and any reward/credit logic is applied server-side.
      await PaymentApi.notifySuccess(
        recipientId: businessId,
        amount: amount,
        paymentIntentId: intent.paymentIntentId,
        idempotencyKey: intent.idempotencyKey,
      );
      Logger.log('Payment successful for business: $businessId');
    } catch (e) {
      ErrorHandler.handle(e);
    }
  }
}
