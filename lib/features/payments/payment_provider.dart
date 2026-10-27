import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_env.dart';
import '../../core/flags/feature_flags.dart';
import 'payment_service.dart';
import 'payments_controller.dart';

/// Stripe publishable key from compile-time configuration or dotenv.
final stripePublishableKeyProvider = FutureProvider<String>((ref) async {
  final key = AppEnv.stripePublishableKey.trim();
  if (key.isEmpty) {
    throw StateError(
      'Stripe is enabled but STRIPE_PUBLISHABLE_KEY is not configured.',
    );
  }
  if (!key.startsWith('pk_test_') && !key.startsWith('pk_live_')) {
    throw StateError('STRIPE_PUBLISHABLE_KEY has an invalid format.');
  }
  return key;
});

/// Stripe payment service provider
final stripePaymentServiceProvider = Provider<StripePaymentService>((ref) {
  return StripePaymentService();
});

/// Initialize Stripe on app startup
final stripeInitializationProvider = FutureProvider<void>((ref) async {
  if (!kPaymentsEnabled) return;
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
