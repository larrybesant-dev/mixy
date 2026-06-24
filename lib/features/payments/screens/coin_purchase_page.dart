import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/services/payments/payment_service.dart';
import 'package:mixvy/shared/providers/auth_providers.dart';

class CoinPurchasePage extends ConsumerStatefulWidget {
  const CoinPurchasePage({super.key});

  @override
  ConsumerState<CoinPurchasePage> createState() => _CoinPurchasePageState();
}

class _CoinPurchasePageState extends ConsumerState<CoinPurchasePage> {
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _coinPackages = [
    {'coins': 100, 'price': '\$0.99'},
    {'coins': 500, 'price': '\$4.99'},
    {'coins': 1000, 'price': '\$8.99'},
    {'coins': 5000, 'price': '\$39.99'},
  ];

  Future<void> _purchaseCoins(int coins) async {
    setState(() => _isLoading = true);

    try {
      final currentUserAsync = ref.read(currentUserProvider);
      final currentUser = currentUserAsync.value;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Simulate payment processing
      await Future.delayed(const Duration(seconds: 2));
      await _paymentService.addCoins(currentUser.id, coins);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully purchased $coins coins!')),
        );
        Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Coins'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _coinPackages.length,
              itemBuilder: (context, index) {
                final package = _coinPackages[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.monetization_on, size: 40),
                    title: Text(
                      '${package['coins']} Coins',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(package['price']),
                    trailing: ElevatedButton(
                      onPressed: () => _purchaseCoins(package['coins']),
                      child: const Text('Buy'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

