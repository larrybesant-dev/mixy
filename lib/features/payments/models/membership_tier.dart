/// Membership Tier Model
///
/// Defines the three membership tiers: Free, VIP, VIP+
/// with their associated benefits and identifiers.
library;

import 'package:flutter/material.dart';
import '../../../core/design_system/design_constants.dart';
import '../../../core/theme/neon_colors.dart';

/// Membership tier enum
enum MembershipTier {
  free,
  vip,
  vipPlus;

  /// RevenueCat entitlement identifier
  String get entitlementId {
    switch (this) {
      case MembershipTier.free:
        return '';
      case MembershipTier.vip:
        return 'vip';
      case MembershipTier.vipPlus:
        return 'vip_plus';
    }
  }

  /// Firestore value
  String get firestoreValue {
    switch (this) {
      case MembershipTier.free:
        return 'free';
      case MembershipTier.vip:
        return 'vip';
      case MembershipTier.vipPlus:
        return 'vip_plus';
    }
  }

  /// Display name
  String get displayName {
    switch (this) {
      case MembershipTier.free:
        return 'Free';
      case MembershipTier.vip:
        return 'VIP';
      case MembershipTier.vipPlus:
        return 'VIP+';
    }
  }

  /// Description
  String get description {
    switch (this) {
      case MembershipTier.free:
        return 'Basic access to Mix & Mingle';
      case MembershipTier.vip:
        return 'Unlock the VIP experience';
      case MembershipTier.vipPlus:
        return 'The ultimate Mix & Mingle experience';
    }
  }

  /// Primary color for the tier
  Color get primaryColor {
    switch (this) {
      case MembershipTier.free:
        return DesignColors.textGray;
      case MembershipTier.vip:
        return NeonColors.neonOrange;
      case MembershipTier.vipPlus:
        return DesignColors.gold;
    }
  }

  /// Secondary color for gradients
  Color get secondaryColor {
    switch (this) {
      case MembershipTier.free:
        return DesignColors.textGray.withValues(alpha: 0.5);
      case MembershipTier.vip:
        return NeonColors.neonBlue;
      case MembershipTier.vipPlus:
        return NeonColors.neonOrange;
    }
  }

  /// Icon for the tier
  IconData get icon {
    switch (this) {
      case MembershipTier.free:
        return Icons.person_outline;
      case MembershipTier.vip:
        return Icons.star;
      case MembershipTier.vipPlus:
        return Icons.diamond;
    }
  }

  /// Benefits list
  List<TierBenefit> get benefits {
    switch (this) {
      case MembershipTier.free:
        return [
          const TierBenefit(
            title: 'Join Rooms',
            description: 'Up to 5 rooms per day',
            icon: Icons.meeting_room,
            isEnabled: true,
          ),
          const TierBenefit(
            title: 'Chat',
            description: 'Basic chat features',
            icon: Icons.chat_bubble_outline,
            isEnabled: true,
          ),
          const TierBenefit(
            title: 'Spotlight',
            description: 'No spotlight priority',
            icon: Icons.highlight,
            isEnabled: false,
          ),
          const TierBenefit(
            title: 'VIP Rooms',
            description: 'No access',
            icon: Icons.lock_outline,
            isEnabled: false,
          ),
        ];
      case MembershipTier.vip:
        return [
          const TierBenefit(
            title: 'Unlimited Rooms',
            description: 'Join unlimited rooms daily',
            icon: Icons.all_inclusive,
            isEnabled: true,
          ),
          const TierBenefit(
            title: 'Spotlight Priority',
            description: '2x spotlight visibility',
            icon: Icons.highlight,
            isEnabled: true,
          ),
          const TierBenefit(
            title: 'VIP Rooms',
            description: 'Access to VIP-only rooms',
            icon: Icons.stars,
            isEnabled: true,
          ),
          const TierBenefit(
            title: 'Monthly Gift Pack',
            description: '100 bonus coins monthly',
            icon: Icons.card_giftcard,
            isEnabled: true,
          ),
          const TierBenefit(
            title: 'VIP Badge',
            description: 'Show off your status',
            icon: Icons.verified,
            isEnabled: true,
          ),
        ];
      case MembershipTier.vipPlus:
        return [
          const TierBenefit(
            title: 'All VIP Perks',
            description: 'Everything from VIP tier',
            icon: Icons.check_circle,
            isEnabled: true,
          ),
          const TierBenefit(
            title: 'Double Spotlight',
            description: '4x spotlight visibility',
            icon: Icons.bolt,
            isEnabled: true,
          ),
          const TierBenefit(
            title: 'VIP+ Exclusive Rooms',
            description: 'Access to elite rooms',
            icon: Icons.diamond,
            isEnabled: true,
          ),
          const TierBenefit(
            title: 'Monthly Coin Bonus',
            description: '500 bonus coins monthly',
            icon: Icons.monetization_on,
            isEnabled: true,
          ),
          const TierBenefit(
            title: 'VIP+ Badge',
            description: 'Gold verified status',
            icon: Icons.workspace_premium,
            isEnabled: true,
          ),
          const TierBenefit(
            title: 'Priority Support',
            description: 'Fast-track customer support',
            icon: Icons.support_agent,
            isEnabled: true,
          ),
        ];
    }
  }

  /// Parse from Firestore value
  static MembershipTier fromFirestore(String? value) {
    switch (value) {
      case 'vip':
        return MembershipTier.vip;
      case 'vip_plus':
        return MembershipTier.vipPlus;
      default:
        return MembershipTier.free;
    }
  }

  /// Check if this tier is higher than another
  bool isHigherThan(MembershipTier other) {
    return index > other.index;
  }

  /// Check if this tier includes another (same or higher)
  bool includes(MembershipTier other) {
    return index >= other.index;
  }

  /// Get pricing for this tier (null for free)
  TierPricing? get pricing {
    switch (this) {
      case MembershipTier.free:
        return null;
      case MembershipTier.vip:
        return TierPricing.vip;
      case MembershipTier.vipPlus:
        return TierPricing.vipPlus;
    }
  }
}

/// Benefit item for displaying tier features
class TierBenefit {
  final String title;
  final String description;
  final IconData icon;
  final bool isEnabled;

  const TierBenefit({
    required this.title,
    required this.description,
    required this.icon,
    required this.isEnabled,
  });
}

/// Membership tier pricing
class TierPricing {
  final MembershipTier tier;
  final String monthlyPrice;
  final String yearlyPrice;
  final String? savings;
  final String productIdMonthly;
  final String productIdYearly;

  const TierPricing({
    required this.tier,
    required this.monthlyPrice,
    required this.yearlyPrice,
    this.savings,
    required this.productIdMonthly,
    required this.productIdYearly,
  });

  /// Display-formatted monthly price
  String get monthlyPriceDisplay => monthlyPrice;

  /// Display-formatted yearly price
  String get yearlyPriceDisplay => yearlyPrice;

  /// Yearly savings percentage
  int get yearlySavingsPercent {
    // Extract numeric values for calculation
    final monthlyNum =
        double.tryParse(monthlyPrice.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    final yearlyNum =
        double.tryParse(yearlyPrice.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    if (monthlyNum == 0) return 0;
    final fullYear = monthlyNum * 12;
    return ((fullYear - yearlyNum) / fullYear * 100).round();
  }

  /// VIP tier pricing
  static const vip = TierPricing(
    tier: MembershipTier.vip,
    monthlyPrice: '\$9.99',
    yearlyPrice: '\$79.99',
    savings: 'Save 33%',
    productIdMonthly: 'vip_monthly',
    productIdYearly: 'vip_yearly',
  );

  /// VIP+ tier pricing
  static const vipPlus = TierPricing(
    tier: MembershipTier.vipPlus,
    monthlyPrice: '\$19.99',
    yearlyPrice: '\$149.99',
    savings: 'Save 37%',
    productIdMonthly: 'vip_plus_monthly',
    productIdYearly: 'vip_plus_yearly',
  );
}
