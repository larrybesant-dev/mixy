import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

class RoomBrowserSkeletonBlock extends StatelessWidget {
  const RoomBrowserSkeletonBlock(
      {super.key, required this.height, required this.radius});
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceBright.withValues(alpha: 0.55),
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      ),
    );
  }
}

class RoomBrowserSkeletonLine extends StatelessWidget {
  const RoomBrowserSkeletonLine({super.key, required this.widthFactor});
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceBright.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class RoomBrowserSkeletonPill extends StatelessWidget {
  const RoomBrowserSkeletonPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 42,
        height: 18,
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceBright.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
