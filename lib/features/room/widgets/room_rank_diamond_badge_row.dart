import 'package:flutter/material.dart';

class RoomRankDiamondBadgeRow extends StatelessWidget {
  const RoomRankDiamondBadgeRow({
    super.key,
    required this.rankTier,
    required this.diamondLevel,
    this.compact = true,
  });

  final int rankTier;
  final int diamondLevel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (rankTier <= 0 && diamondLevel <= 0) {
      return const SizedBox.shrink();
    }

    final fontSize = compact ? 9.0 : 10.0;
    final vert = compact ? 1.0 : 2.0;
    final horz = compact ? 4.0 : 6.0;

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (rankTier > 0)
          _BadgePill(
            icon: Icons.workspace_premium_rounded,
            text: 'R$rankTier',
            bg: const Color(0x22D4AF37),
            fg: const Color(0xFFD4AF37),
            fontSize: fontSize,
            vert: vert,
            horz: horz,
          ),
        if (diamondLevel > 0)
          _BadgePill(
            icon: Icons.diamond_rounded,
            text: 'D$diamondLevel',
            bg: const Color(0x224AC6FF),
            fg: const Color(0xFF4AC6FF),
            fontSize: fontSize,
            vert: vert,
            horz: horz,
          ),
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.icon,
    required this.text,
    required this.bg,
    required this.fg,
    required this.fontSize,
    required this.vert,
    required this.horz,
  });

  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;
  final double fontSize;
  final double vert;
  final double horz;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horz, vertical: vert),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 1, color: fg),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
