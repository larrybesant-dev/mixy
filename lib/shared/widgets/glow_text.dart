import 'package:flutter/material.dart';
import 'package:mixvy/core/theme/colors.dart';

class GlowText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final Color? glowColor;
  final double? glowRadius;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const GlowText({
    super.key,
    required this.text,
    this.fontSize,
    this.fontWeight,
    this.color,
    this.glowColor,
    this.glowRadius,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? Colors.white;
    final glow = glowColor ?? ClubColors.glowingRed;
    final radius = glowRadius ?? 4.0;

    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: textColor,
        shadows: [
          Shadow(
            color: glow.withValues(alpha: 0.8),
            blurRadius: radius,
            offset: Offset.zero,
          ),
          Shadow(
            color: glow.withValues(alpha: 0.4),
            blurRadius: radius * 2,
            offset: Offset.zero,
          ),
        ],
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

