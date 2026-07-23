import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'payment_service.dart';
import 'payments_controller.dart';

/// Stripe publishable key from .env
final stripePublishableKeyProvider = FutureProvider<String>((ref) async {
  final key = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
  if (key == null || key.isEmpty) {
    throw Exception('STRIPE_PUBLISHABLE_KEY not found in .env');
  }
  return key;
});

/// Stripe payment service provider
final stripePaymentServiceProvider =
    Provider<StripePaymentService>((ref) {
  return StripePaymentService();
});

/// Initialize Stripe on app startup
final stripeInitializationProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(stripePaymentServiceProvider);
  final publishableKey = await ref.watch(stripePublishableKeyProvider.future);
  await service.initialize(publishableKey);
});

/// Payment state notifier provider using Riverpod
final paymentControllerProvider =
    NotifierProvider<PaymentController, PaymentState>(
  PaymentController.new,
);

/// Async payment status (completes when payment processing finishes)
final processPaymentProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, packageId) async {
  final service = ref.watch(stripePaymentServiceProvider);
  final controller = ref.read(paymentControllerProvider.notifier);

  try {
    controller.updateLoading(true);
    final result = await service.createCheckoutSession(packageId);
    if (result == null) {
      throw Exception('Failed to create checkout session');
    }
    return {'success': true, 'checkoutUrl': result};
  } catch (e) {
    controller.updateError(e.toString());
    return {'success': false, 'error': e.toString()};
  } finally {
    controller.updateLoading(false);
  }
});




