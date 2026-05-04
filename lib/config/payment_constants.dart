import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads Stripe publishable key from .env file using flutter_dotenv.
/// Ensure you call `await dotenv.load()` in main() before using this constant.
class PaymentConstants {
  static String get stripePublishableKey =>
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
}
