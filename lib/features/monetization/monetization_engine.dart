/// Monetization Engine
///
/// Advanced monetization system with dynamic pricing, surge pricing,
/// creator revenue share, VIP boosts, and seasonal adjustments.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/analytics/analytics_service.dart';

/// Pricing tier configuration
class PricingTier {
  final String id;
  final String name;
  final double basePrice;
  final double multiplier;
  final List<String> features;

  const PricingTier({
    required this.id,
    required this.name,
    required this.basePrice,
    this.multiplier = 1.0,
    this.features = const [],
  });

  double get effectivePrice => basePrice * multiplier;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'basePrice': basePrice,
        'multiplier': multiplier,
        'features': features,
      };

  factory PricingTier.fromMap(Map<String, dynamic> map) {
    return PricingTier(
      id: map['id'] as String,
      name: map['name'] as String,
      basePrice: (map['basePrice'] as num).toDouble(),
      multiplier: (map['multiplier'] as num?)?.toDouble() ?? 1.0,
      features: List<String>.from(map['features'] ?? []),
    );
  }
}

/// Surge pricing configuration
class SurgeConfig {
  final double lowThreshold;
  final double mediumThreshold;
  final double highThreshold;
  final double lowMultiplier;
  final double mediumMultiplier;
  final double highMultiplier;

  const SurgeConfig({
    this.lowThreshold = 0.5,
    this.mediumThreshold = 0.75,
    this.highThreshold = 0.9,
    this.lowMultiplier = 1.0,
    this.mediumMultiplier = 1.25,
    this.highMultiplier = 1.5,
  });
}

/// Creator revenue share configuration
class RevenueShareConfig {
  final String creatorTier;
  final double platformPercentage;
  final double creatorPercentage;
  final double minPayout;

  const RevenueShareConfig({
    required this.creatorTier,
    required this.platformPercentage,
    required this.creatorPercentage,
    this.minPayout = 10.0,
  });

  factory RevenueShareConfig.fromMap(Map<String, dynamic> map) {
    return RevenueShareConfig(
      creatorTier: map['creatorTier'] as String,
      platformPercentage: (map['platformPercentage'] as num).toDouble(),
      creatorPercentage: (map['creatorPercentage'] as num).toDouble(),
      minPayout: (map['minPayout'] as num?)?.toDouble() ?? 10.0,
    );
  }
}

/// VIP boost configuration
class VIPBoost {
  final String id;
  final String name;
  final BoostType type;
  final double multiplier;
  final Duration duration;
  final double price;
  final List<String> eligibleTiers;

  const VIPBoost({
    required this.id,
    required this.name,
    required this.type,
    required this.multiplier,
    required this.duration,
    required this.price,
    this.eligibleTiers = const ['vip', 'vip_plus'],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'multiplier': multiplier,
        'durationMinutes': duration.inMinutes,
        'price': price,
        'eligibleTiers': eligibleTiers,
      };

  factory VIPBoost.fromMap(Map<String, dynamic> map) {
    return VIPBoost(
      id: map['id'] as String,
      name: map['name'] as String,
      type: BoostType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => BoostType.visibility,
      ),
      multiplier: (map['multiplier'] as num).toDouble(),
      duration: Duration(minutes: map['durationMinutes'] as int? ?? 60),
      price: (map['price'] as num).toDouble(),
      eligibleTiers:
          List<String>.from(map['eligibleTiers'] ?? ['vip', 'vip_plus']),
    );
  }
}

enum BoostType {
  visibility,
  matching,
  earnings,
  engagement,
}

/// Seasonal pricing adjustment
class SeasonalAdjustment {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final double multiplier;
  final List<String> affectedProducts;
  final bool isActive;

  SeasonalAdjustment({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.multiplier,
    this.affectedProducts = const [],
    this.isActive = true,
  });

  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && now.isAfter(startDate) && now.isBefore(endDate);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'multiplier': multiplier,
        'affectedProducts': affectedProducts,
        'isActive': isActive,
      };

  factory SeasonalAdjustment.fromMap(Map<String, dynamic> map) {
    return SeasonalAdjustment(
      id: map['id'] as String,
      name: map['name'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      multiplier: (map['multiplier'] as num).toDouble(),
      affectedProducts: List<String>.from(map['affectedProducts'] ?? []),
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}

/// Engine for advanced monetization features
class MonetizationEngine {
  static MonetizationEngine? _instance;
  static MonetizationEngine get instance =>
      _instance ??= MonetizationEngine._();

  MonetizationEngine._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // ignore: unused_field
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collections
  CollectionReference<Map<String, dynamic>> get _pricingCollection =>
      _firestore.collection('pricing_tiers');

  CollectionReference<Map<String, dynamic>> get _revenueShareCollection =>
      _firestore.collection('revenue_share_configs');

  CollectionReference<Map<String, dynamic>> get _boostsCollection =>
      _firestore.collection('vip_boosts');

  CollectionReference<Map<String, dynamic>> get _seasonalCollection =>
      _firestore.collection('seasonal_adjustments');

  CollectionReference<Map<String, dynamic>> get _transactionsCollection =>
      _firestore.collection('monetization_transactions');

  // Configuration
  SurgeConfig _surgeConfig = const SurgeConfig();

  // Cache
  final Map<String, PricingTier> _pricingTiers = {};
  final Map<String, RevenueShareConfig> _revenueShareConfigs = {};
  final Map<String, VIPBoost> _vipBoosts = {};
  final List<SeasonalAdjustment> _seasonalAdjustments = [];

  // Stream controllers
  final _priceChangeController =
      StreamController<Map<String, double>>.broadcast();

  /// Stream of price changes
  Stream<Map<String, double>> get priceChangeStream =>
      _priceChangeController.stream;

  /// Update surge config
  void updateSurgeConfig(SurgeConfig config) {
    _surgeConfig = config;
  }

  /// Initialize the engine
  Future<void> initialize() async {
    await _loadPricingTiers();
    await _loadRevenueShareConfigs();
    await _loadVIPBoosts();
    await _loadSeasonalAdjustments();

    AnalyticsService.instance.logEvent(
      name: 'monetization_engine_initialized',
      parameters: {
        'pricing_tiers': _pricingTiers.length,
        'vip_boosts': _vipBoosts.length,
      },
    );
  }

  /// Calculate dynamic price for a product
  Future<double> dynamicPricing({
    required String productId,
    required double basePrice,
    String? userId,
    Map<String, dynamic>? context,
  }) async {
    double finalPrice = basePrice;

    // Apply pricing tier multiplier
    final tier = _pricingTiers[productId];
    if (tier != null) {
      finalPrice = tier.effectivePrice;
    }

    // Apply seasonal adjustments
    for (final adjustment in _seasonalAdjustments) {
      if (adjustment.isCurrentlyActive) {
        if (adjustment.affectedProducts.isEmpty ||
            adjustment.affectedProducts.contains(productId)) {
          finalPrice *= adjustment.multiplier;
        }
      }
    }

    // Apply user-specific adjustments (loyalty discounts, etc.)
    if (userId != null) {
      final userDiscount = await _getUserLoyaltyDiscount(userId);
      finalPrice *= (1 - userDiscount);
    }

    // Round to 2 decimal places
    finalPrice = (finalPrice * 100).round() / 100;

    AnalyticsService.instance.logEvent(
      name: 'dynamic_price_calculated',
      parameters: {
        'product_id': productId,
        'base_price': basePrice,
        'final_price': finalPrice,
      },
    );

    return finalPrice;
  }

  /// Calculate surge pricing based on current demand
  Future<double> surgePricingForPeakHours({
    required double basePrice,
    required double currentDemand,
    required double maxCapacity,
  }) async {
    final utilizationRate = currentDemand / maxCapacity;

    double multiplier;
    if (utilizationRate >= _surgeConfig.highThreshold) {
      multiplier = _surgeConfig.highMultiplier;
    } else if (utilizationRate >= _surgeConfig.mediumThreshold) {
      multiplier = _surgeConfig.mediumMultiplier;
    } else if (utilizationRate >= _surgeConfig.lowThreshold) {
      multiplier = _surgeConfig.lowMultiplier;
    } else {
      multiplier = 1.0;
    }

    final surgePrice = basePrice * multiplier;

    AnalyticsService.instance.logEvent(
      name: 'surge_price_calculated',
      parameters: {
        'base_price': basePrice,
        'surge_price': surgePrice,
        'utilization': utilizationRate,
        'multiplier': multiplier,
      },
    );

    // Notify subscribers
    _priceChangeController.add({
      'basePrice': basePrice,
      'surgePrice': surgePrice,
      'multiplier': multiplier,
    });

    return surgePrice;
  }

  /// Calculate creator revenue share
  Future<Map<String, double>> creatorRevenueShare({
    required String creatorId,
    required double transactionAmount,
    required String transactionType,
  }) async {
    // Get creator's tier
    final creatorDoc =
        await _firestore.collection('creators').doc(creatorId).get();
    final creatorTier = creatorDoc.data()?['tier'] as String? ?? 'standard';

    // Get revenue share config for tier
    final config = _revenueShareConfigs[creatorTier] ??
        const RevenueShareConfig(
          creatorTier: 'standard',
          platformPercentage: 0.30,
          creatorPercentage: 0.70,
        );

    final creatorShare = transactionAmount * config.creatorPercentage;
    final platformShare = transactionAmount * config.platformPercentage;

    // Record the transaction
    await _transactionsCollection.add({
      'creatorId': creatorId,
      'transactionAmount': transactionAmount,
      'transactionType': transactionType,
      'creatorShare': creatorShare,
      'platformShare': platformShare,
      'creatorTier': creatorTier,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update creator's pending balance
    await _firestore.collection('creators').doc(creatorId).update({
      'pendingBalance': FieldValue.increment(creatorShare),
      'totalEarnings': FieldValue.increment(creatorShare),
    });

    AnalyticsService.instance.logEvent(
      name: 'creator_revenue_share',
      parameters: {
        'creator_id': creatorId,
        'amount': transactionAmount,
        'creator_share': creatorShare,
        'tier': creatorTier,
      },
    );

    return {
      'creatorShare': creatorShare,
      'platformShare': platformShare,
      'creatorPercentage': config.creatorPercentage,
    };
  }

  /// Apply VIP Plus boosts
  Future<Map<String, dynamic>> vipPlusBoosts({
    required String userId,
    required String boostId,
  }) async {
    final boost = _vipBoosts[boostId];
    if (boost == null) {
      return {'success': false, 'error': 'Boost not found'};
    }

    // Check user eligibility
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userTier = userDoc.data()?['membershipTier'] as String? ?? 'free';

    if (!boost.eligibleTiers.contains(userTier)) {
      return {
        'success': false,
        'error': 'User tier not eligible for this boost'
      };
    }

    // Check if user has balance
    final userBalance =
        (userDoc.data()?['coinBalance'] as num?)?.toDouble() ?? 0;
    if (userBalance < boost.price) {
      return {'success': false, 'error': 'Insufficient balance'};
    }

    // Apply the boost
    final boostEnd = DateTime.now().add(boost.duration);

    await _firestore.collection('user_boosts').add({
      'userId': userId,
      'boostId': boostId,
      'boostType': boost.type.name,
      'multiplier': boost.multiplier,
      'startedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(boostEnd),
      'status': 'active',
    });

    // Deduct balance
    await _firestore.collection('users').doc(userId).update({
      'coinBalance': FieldValue.increment(-boost.price),
    });

    AnalyticsService.instance.logEvent(
      name: 'vip_boost_applied',
      parameters: {
        'user_id': userId,
        'boost_id': boostId,
        'boost_type': boost.type.name,
        'price': boost.price,
      },
    );

    return {
      'success': true,
      'boost': boost.toMap(),
      'expiresAt': boostEnd.toIso8601String(),
    };
  }

  /// Get seasonal pricing adjustments
  Future<List<SeasonalAdjustment>> seasonalPricingAdjustments() async {
    await _loadSeasonalAdjustments();
    return _seasonalAdjustments.where((a) => a.isCurrentlyActive).toList();
  }

  /// Create a new seasonal adjustment
  Future<SeasonalAdjustment> createSeasonalAdjustment({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required double multiplier,
    List<String> affectedProducts = const [],
  }) async {
    final docRef = _seasonalCollection.doc();

    final adjustment = SeasonalAdjustment(
      id: docRef.id,
      name: name,
      startDate: startDate,
      endDate: endDate,
      multiplier: multiplier,
      affectedProducts: affectedProducts,
    );

    await docRef.set(adjustment.toMap());
    _seasonalAdjustments.add(adjustment);

    AnalyticsService.instance.logEvent(
      name: 'seasonal_adjustment_created',
      parameters: {
        'name': name,
        'multiplier': multiplier,
      },
    );

    return adjustment;
  }

  /// Get user's active boosts
  Future<List<Map<String, dynamic>>> getUserActiveBoosts(String userId) async {
    final snapshot = await _firestore
        .collection('user_boosts')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Calculate total boost multiplier for user
  Future<double> getTotalBoostMultiplier(String userId, BoostType type) async {
    final activeBoosts = await getUserActiveBoosts(userId);

    double totalMultiplier = 1.0;
    for (final boost in activeBoosts) {
      if (boost['boostType'] == type.name) {
        totalMultiplier *= (boost['multiplier'] as num).toDouble();
      }
    }

    return totalMultiplier;
  }

  /// Get pricing statistics
  Future<Map<String, dynamic>> getPricingStats() async {
    return {
      'pricingTiers': _pricingTiers.length,
      'vipBoosts': _vipBoosts.length,
      'activeSeasonalAdjustments':
          _seasonalAdjustments.where((a) => a.isCurrentlyActive).length,
      'revenueShareConfigs': _revenueShareConfigs.length,
    };
  }

  // Private methods

  Future<void> _loadPricingTiers() async {
    final snapshot = await _pricingCollection.get();

    _pricingTiers.clear();
    for (final doc in snapshot.docs) {
      final tier = PricingTier.fromMap(doc.data());
      _pricingTiers[tier.id] = tier;
    }

    // Add default tiers if none exist
    if (_pricingTiers.isEmpty) {
      _pricingTiers.addAll({
        'coins_small': const PricingTier(
          id: 'coins_small',
          name: '100 Coins',
          basePrice: 0.99,
          features: ['100 coins'],
        ),
        'coins_medium': const PricingTier(
          id: 'coins_medium',
          name: '500 Coins',
          basePrice: 4.99,
          multiplier: 0.95,
          features: ['500 coins', '5% bonus'],
        ),
        'coins_large': const PricingTier(
          id: 'coins_large',
          name: '1000 Coins',
          basePrice: 9.99,
          multiplier: 0.9,
          features: ['1000 coins', '10% bonus'],
        ),
        'vip_monthly': const PricingTier(
          id: 'vip_monthly',
          name: 'VIP Monthly',
          basePrice: 9.99,
          features: ['Ad-free', 'Priority matching', 'VIP badge'],
        ),
        'vip_plus_monthly': const PricingTier(
          id: 'vip_plus_monthly',
          name: 'VIP+ Monthly',
          basePrice: 19.99,
          features: ['All VIP features', 'Exclusive boosts', 'Creator support'],
        ),
      });
    }
  }

  Future<void> _loadRevenueShareConfigs() async {
    final snapshot = await _revenueShareCollection.get();

    _revenueShareConfigs.clear();
    for (final doc in snapshot.docs) {
      final config = RevenueShareConfig.fromMap(doc.data());
      _revenueShareConfigs[config.creatorTier] = config;
    }

    // Add default configs if none exist
    if (_revenueShareConfigs.isEmpty) {
      _revenueShareConfigs.addAll({
        'standard': const RevenueShareConfig(
          creatorTier: 'standard',
          platformPercentage: 0.30,
          creatorPercentage: 0.70,
        ),
        'verified': const RevenueShareConfig(
          creatorTier: 'verified',
          platformPercentage: 0.25,
          creatorPercentage: 0.75,
        ),
        'partner': const RevenueShareConfig(
          creatorTier: 'partner',
          platformPercentage: 0.20,
          creatorPercentage: 0.80,
        ),
        'elite': const RevenueShareConfig(
          creatorTier: 'elite',
          platformPercentage: 0.15,
          creatorPercentage: 0.85,
        ),
      });
    }
  }

  Future<void> _loadVIPBoosts() async {
    final snapshot = await _boostsCollection.get();

    _vipBoosts.clear();
    for (final doc in snapshot.docs) {
      final boost = VIPBoost.fromMap(doc.data());
      _vipBoosts[boost.id] = boost;
    }

    // Add default boosts if none exist
    if (_vipBoosts.isEmpty) {
      _vipBoosts.addAll({
        'visibility_1h': const VIPBoost(
          id: 'visibility_1h',
          name: 'Spotlight Hour',
          type: BoostType.visibility,
          multiplier: 2.0,
          duration: Duration(hours: 1),
          price: 50,
        ),
        'matching_boost': const VIPBoost(
          id: 'matching_boost',
          name: 'Priority Match',
          type: BoostType.matching,
          multiplier: 1.5,
          duration: Duration(hours: 2),
          price: 75,
        ),
        'earnings_boost': const VIPBoost(
          id: 'earnings_boost',
          name: 'Double Earnings',
          type: BoostType.earnings,
          multiplier: 2.0,
          duration: Duration(hours: 3),
          price: 100,
          eligibleTiers: ['vip_plus'],
        ),
      });
    }
  }

  Future<void> _loadSeasonalAdjustments() async {
    final snapshot = await _seasonalCollection.get();

    _seasonalAdjustments.clear();
    for (final doc in snapshot.docs) {
      _seasonalAdjustments.add(SeasonalAdjustment.fromMap(doc.data()));
    }
  }

  Future<double> _getUserLoyaltyDiscount(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) return 0.0;

    final data = userDoc.data()!;
    final purchaseCount = (data['purchaseCount'] as int?) ?? 0;
    final accountAge = data['createdAt'] != null
        ? DateTime.now()
            .difference((data['createdAt'] as Timestamp).toDate())
            .inDays
        : 0;

    // Calculate loyalty discount based on purchase history and account age
    double discount = 0.0;

    if (purchaseCount >= 50) {
      discount = 0.15;
    } else if (purchaseCount >= 20) {
      discount = 0.10;
    } else if (purchaseCount >= 10) {
      discount = 0.05;
    }

    // Additional discount for long-term users
    if (accountAge > 365) {
      discount += 0.05;
    } else if (accountAge > 180) {
      discount += 0.02;
    }

    return discount.clamp(0.0, 0.25); // Max 25% discount
  }

  /// Dispose resources
  void dispose() {
    _priceChangeController.close();
  }
}
