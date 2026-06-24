import 'package:flutter/material.dart';
import 'package:mixmingle/features/payments/screens/coin_purchase_page.dart';
import 'package:mixmingle/core/theme/colors.dart';

/// Reusable widget for displaying coin balance and buy button
/// Add this to your app bar, profile, or anywhere else
class CoinBalanceWidget extends StatelessWidget {
  final int coinBalance;
  final VoidCallback? onTap;

  const CoinBalanceWidget({
    super.key,
    required this.coinBalance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CoinPurchasePage(),
              ),
            );
          },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ClubColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ClubColors.goldenYellow.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monetization_on,
              color: ClubColors.goldenYellow,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              coinBalance.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.add_circle_outline,
              color: ClubColors.mingleBlue,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating action button for buying coins
class BuyCoinsFloatingButton extends StatelessWidget {
  const BuyCoinsFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'coin_purchase_fab',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CoinPurchasePage(),
          ),
        );
      },
      backgroundColor: ClubColors.goldenYellow,
      icon: const Icon(Icons.add_shopping_cart, color: Colors.black),
      label: const Text(
        'Buy Coins',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Example: Add to AppBar
///
/// ```dart
/// AppBar(
///   title: Text('Mix & Mingle'),
///   actions: [
///     StreamBuilder<int>(
///       stream: PaymentService().coinBalanceStream(),
///       builder: (context, snapshot) {
///         return CoinBalanceWidget(
///           coinBalance: snapshot.data ?? 0,
///         );
///       },
///     ),
///     SizedBox(width: 16),
///   ],
/// )
/// ```
