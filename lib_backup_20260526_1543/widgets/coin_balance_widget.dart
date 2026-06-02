import 'package:flutter/material.dart';

class CoinBalanceWidget extends StatelessWidget {
  final int balance;

  const CoinBalanceWidget({required this.balance, super.key});

  String _formatBalance(int value) {
    if (value >= 100000000) {
      return '∞';
    }
    if (value >= 1000000) {
      final short = value / 1000000;
      return short == short.roundToDouble()
          ? '${short.toStringAsFixed(0)}M'
          : '${short.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final short = value / 1000;
      return short == short.roundToDouble()
          ? '${short.toStringAsFixed(0)}K'
          : '${short.toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.monetization_on,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            _formatBalance(balance),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
