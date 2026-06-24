import 'package:flutter/material.dart';
import 'package:mixmingle/core/theme/colors.dart';

/// Mix & Mingle logo widget matching the flyer design
/// "MIX" in coral orange + treble clef + "MINGLE" in blue
class MixMingleLogo extends StatelessWidget {
  final double fontSize;
  final bool showIcon;

  const MixMingleLogo({
    super.key,
    this.fontSize = 32,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // "MIX" in coral orange
        Text(
          'MIX',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: ClubColors.mixOrange,
            letterSpacing: 2,
          ),
        ),

        if (showIcon) ...[
          SizedBox(width: fontSize * 0.2),
          // Treble clef music note
          Icon(
            Icons.music_note,
            color: ClubColors.mixOrange,
            size: fontSize * 1.2,
          ),
          SizedBox(width: fontSize * 0.2),
        ],

        // "MINGLE" in blue
        Text(
          'MINGLE',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: ClubColors.mingleBlue,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

/// Compact version for small spaces (just text, no icon)
class MixMingleLogoCompact extends StatelessWidget {
  final double fontSize;

  const MixMingleLogoCompact({
    super.key,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return MixMingleLogo(
      fontSize: fontSize,
      showIcon: false,
    );
  }
}
