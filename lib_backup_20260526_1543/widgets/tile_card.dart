import 'package:flutter/material.dart';

class TileCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const TileCard({required this.child, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16.0), child: child),
      ),
    );
  }
}
