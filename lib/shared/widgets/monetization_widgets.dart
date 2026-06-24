import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/models/subscription.dart';
import 'package:mixvy/shared/providers/gamification_payment_providers.dart';
import 'package:mixvy/shared/providers/auth_providers.dart';
import 'package:mixvy/services/payments/coin_economy_service.dart'
    show CoinEconomyService;

/// Coin shop widget
class CoinShop extends ConsumerStatefulWidget {
  const CoinShop({super.key});

  @override
  ConsumerState<CoinShop> createState() => _CoinShopState();
}

class _CoinShopState extends ConsumerState<CoinShop> {
  bool _isLoading = false;

  final List<Map<String, dynamic>> _coinPackages = const [
    {
      'id': 'starter',
      'name': 'Starter Pack',
      'coins': 100,
      'price': 0.99,
      'bonus': 0,
      'popular': false,
      'color': Colors.blue,
    },
    {
      'id': 'popular',
      'name': 'Popular Pack',
      'coins': 250,
      'price': 1.99,
      'bonus': 25,
      'popular': true,
      'color': Colors.green,
    },
    {
      'id': 'value',
      'name': 'Value Pack',
      'coins': 500,
      'price': 3.99,
      'bonus': 75,
      'popular': false,
      'color': Colors.orange,
    },
    {
      'id': 'premium',
      'name': 'Premium Pack',
      'coins': 1000,
      'price': 6.99,
      'bonus': 200,
      'popular': false,
      'color': Colors.purple,
    },
    {
      'id': 'ultimate',
      'name': 'Ultimate Pack',
      'coins': 2500,
      'price': 14.99,
      'bonus': 625,
      'popular': false,
      'color': Colors.red,
    },
  ];

  Future<void> _purchaseCoins(Map<String, dynamic> package) async {
    setState(() => _isLoading = true);

    try {
      // Get actual user ID from auth provider
      final authAsync = ref.watch(authStateProvider);
      final authUser = authAsync.maybeWhen(
        data: (user) => user,
        orElse: () => null,
      );
      if (authUser == null) {
        throw Exception('User not authenticated');
      }
      final userId = authUser.uid;

      final coinService = CoinEconomyService();
      await coinService.purchaseCoins(
        userId: userId,
        coinAmount: package['coins'] + package['bonus'],
        usdAmount: package['price'],
        paymentMethod: 'firebase', // Firebase payment integration
        transactionId: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Successfully purchased ${package['coins'] + package['bonus']} coins!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userBalanceAsync = ref.watch(userCoinBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coin Shop'),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber),
                const SizedBox(width: 4),
                userBalanceAsync.when(
                  data: (balance) => Text(
                    '$balance',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  loading: () => const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => const Text('0'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Choose Your Package',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Purchase coins to send gifts, boost your profile, and unlock premium features',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ..._coinPackages.map((package) => _buildPackageCard(package)),
                const SizedBox(height: 24),
                _buildEarningSection(),
              ],
            ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> package) {
    final isPopular = package['popular'] as bool;
    final color = package['color'] as Color;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isPopular ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPopular ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            if (isPopular)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'MOST POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.monetization_on, size: 32, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${package['coins']} coins',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (package['bonus'] > 0)
                        Text(
                          '+ ${package['bonus']} bonus coins',
                          style: TextStyle(
                            fontSize: 14,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${package['price']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${((package['coins'] + package['bonus']) / package['price']).toStringAsFixed(1)} coins/\$',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _purchaseCoins(package),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Purchase',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Earn Free Coins',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildEarningItem(
              icon: Icons.login,
              title: 'Daily Login',
              description: 'Log in every day',
              coins: '10 coins',
            ),
            _buildEarningItem(
              icon: Icons.mic,
              title: 'Voice Participation',
              description: 'Spend time in voice rooms',
              coins: '1 coin per 5 min',
            ),
            _buildEarningItem(
              icon: Icons.message,
              title: 'Active Messaging',
              description: 'Send messages regularly',
              coins: '1 coin per 10 msgs',
            ),
            _buildEarningItem(
              icon: Icons.emoji_events,
              title: 'Achievements',
              description: 'Complete challenges and earn badges',
              coins: '5-100 coins',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // Navigate to achievements/earning page
                },
                child: const Text('View All Ways to Earn'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningItem({
    required IconData icon,
    required String title,
    required String description,
    required String coins,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              coins,
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subscription management widget
class SubscriptionManager extends ConsumerStatefulWidget {
  const SubscriptionManager({super.key});

  @override
  ConsumerState<SubscriptionManager> createState() =>
      _SubscriptionManagerState();
}

class _SubscriptionManagerState extends ConsumerState<SubscriptionManager> {
  bool _isLoading = false;

  final List<Map<String, dynamic>> _subscriptionPlans = const [
    {
      'tier': 'free',
      'name': 'Free',
      'price': 0,
      'features': [
        'Basic messaging',
        'Join public rooms',
        'Limited gifts',
      ],
      'color': Colors.grey,
      'popular': false,
    },
    {
      'tier': 'basic',
      'name': 'Basic',
      'price': 4.99,
      'period': 'month',
      'features': [
        'Priority matching',
        'Advanced filters',
        'Read receipts',
        'Typing indicators',
        'Custom profile themes',
        'HD voice quality',
      ],
      'color': Colors.blue,
      'popular': false,
    },
    {
      'tier': 'premium',
      'name': 'Premium',
      'price': 9.99,
      'period': 'month',
      'features': [
        'All Basic features',
        'Unlimited rooms',
        'Screen sharing',
        'Gift animations',
        'Badge showcase',
        'Early access to features',
      ],
      'color': Colors.green,
      'popular': true,
    },
    {
      'tier': 'vip',
      'name': 'VIP',
      'price': 19.99,
      'period': 'month',
      'features': [
        'All Premium features',
        'Exclusive badges',
        'Priority support',
        'Custom emojis',
        'Ad-free experience',
        'VIP-only rooms',
      ],
      'color': Colors.purple,
      'popular': false,
    },
  ];

  Future<void> _subscribeToPlan(Map<String, dynamic> plan) async {
    if (plan['tier'] == 'free') return;

    setState(() => _isLoading = true);

    try {
      // Get actual user ID from auth provider
      final authAsync = ref.watch(authStateProvider);
      final authUser = authAsync.maybeWhen(
        data: (user) => user,
        orElse: () => null,
      );
      if (authUser == null) {
        throw Exception('User not authenticated');
      }
      final userId = authUser.uid;

      final subscriptionService = ref.read(subscriptionServiceProvider);
      await subscriptionService.subscribe(
        userId: userId,
        package: SubscriptionPackage(
          id: plan['tier'],
          tier: SubscriptionTier.values.firstWhere(
            (e) => e.name == plan['tier'],
          ),
          duration: SubscriptionDuration.values.firstWhere(
            (e) => e.name == (plan['period'] ?? 'monthly'),
            orElse: () => SubscriptionDuration.monthly,
          ),
          price: plan['price'].toDouble(),
          features: List<String>.from(plan['features']),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Successfully subscribed to ${plan['name']}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Subscription failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userSubscriptionAsync = ref.watch(userSubscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Plans'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlock premium features and enhance your experience',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                userSubscriptionAsync.when(
                  data: (subscription) {
                    if (subscription != null && subscription.isActive) {
                      return Card(
                        color: Colors.purple.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.star,
                                      color: Colors.purple.shade700, size: 32),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Current: ${subscription.tier.name.toUpperCase()}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade900,
                                          ),
                                        ),
                                        Text(
                                          '${subscription.daysRemaining} days left',
                                          style: TextStyle(
                                              color: Colors.purple.shade700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
                ..._subscriptionPlans.map((plan) => _buildPlanCard(plan)),
              ],
            ),
    );
  }

  // ignore: unused_element
  Widget _buildCurrentSubscriptionCard(UserSubscription subscription) {
    return Card(
      color: Colors.blue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Current Plan: ${subscription.tier.name.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subscription.isActive
                  ? 'Active until ${subscription.endDate.toString().split(' ')[0]}'
                  : 'Subscription expired',
              style: TextStyle(
                color: subscription.isActive ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final isPopular = plan['popular'] as bool;
    final color = plan['color'] as Color;
    final isFree = plan['tier'] == 'free';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isPopular ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPopular ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            if (isPopular)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'RECOMMENDED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              plan['name'],
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isFree
                  ? 'Free forever'
                  : '\$${plan['price']}/${plan['period'] ?? 'month'}',
              style: TextStyle(
                fontSize: 20,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ...List<String>.from(plan['features']).map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check, color: color, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _subscribeToPlan(plan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFree ? Colors.grey : color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isFree ? 'Current Plan' : 'Subscribe',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

