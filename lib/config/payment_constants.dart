import 'app_env.dart';

/// Loads Stripe publishable key from .env file using flutter_dotenv.
/// Ensure you call `await dotenv.load()` in main() before using this constant.
class PaymentConstants {
  static String get stripePublishableKey => AppEnv.stripePublishableKey;
}



