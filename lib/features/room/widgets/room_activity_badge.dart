import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mixvy/core/theme.dart';

class RoomActivityBadge extends StatelessWidget {
  const RoomActivityBadge({
    super.key,
    required this.icon,
    required this.count,
    this.label = '',
  });

  final String icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final display = count > 999
        ? '${(count / 1000).toStringAsFixed(1)}k'
        : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x80161A21),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 3),
          Text(
            label.isEmpty ? display : '$display $label',
            style: GoogleFonts.raleway(
              fontSize: 10,
              color: VelvetNoir.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}



