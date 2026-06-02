import 'package:flutter/material.dart';

class VerificationBadge extends StatelessWidget {
  final bool isVerified;
  final double size;

  const VerificationBadge({
    super.key,
    required this.isVerified,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: 'Verified account',
        child: Icon(Icons.verified, size: size, color: const Color(0xFFC45E7A)),
      ),
    );
  }
}

class VerificationBadgeRow extends StatelessWidget {
  final String username;
  final bool isVerified;
  final TextStyle? style;

  const VerificationBadgeRow({
    super.key,
    required this.username,
    required this.isVerified,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(username, style: style),
        if (isVerified)
          VerificationBadge(
            isVerified: true,
            size: (style?.fontSize ?? 14) * 0.8,
          ),
      ],
    );
  }
}
