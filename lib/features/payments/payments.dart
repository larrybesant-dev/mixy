/// Payments Feature
///
/// Exports all payments-related functionality:
/// - Membership tiers and benefits
/// - Coin economy and packages
/// - RevenueCat integration
/// - Paywall and coin store screens
/// - Membership badges and widgets
library;

// Models
export 'models/membership_tier.dart';
export 'models/coin_package.dart';

// Services
export 'package:mixvy/services/payments/revenuecat_service.dart';
export 'services/membership_service.dart';

// Controllers
export 'controllers/coin_controller.dart';

// Widgets
export 'widgets/membership_badge.dart';
export 'widgets/neon_tier_card.dart';
export 'widgets/neon_coin_package_card.dart';

// Screens
export 'screens/paywall_screen.dart';
export 'screens/coin_store_screen.dart';
export 'screens/wallet_page.dart';

