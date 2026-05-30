import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mixvy/core/theme.dart';
import 'package:mixvy/models/room_model.dart';

class RoomIdentityChip extends StatelessWidget {
  const RoomIdentityChip({super.key, required this.room, this.small = false});

  final RoomModel room;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final topTag = room.tags.isNotEmpty ? room.tags.first.trim() : '';
    final category = (room.category ?? '').trim();

    final String label;
    final IconData icon;
    final Color chipColor;

    if (topTag.isNotEmpty) {
      label = topTag;
      icon = Icons.auto_awesome_rounded;
      chipColor = VelvetNoir.secondaryBright;
    } else if (category.isNotEmpty) {
      label = category;
      icon = Icons.verified_user_rounded;
      chipColor = VelvetNoir.primary;
    } else if (room.isAdult) {
      label = '18+';
      icon = Icons.local_fire_department_rounded;
      chipColor = VelvetNoir.liveGlow;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: BoxConstraints(maxWidth: small ? 130 : 170),
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: chipColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: small ? 11 : 12, color: chipColor),
          SizedBox(width: small ? 3 : 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.raleway(
                fontSize: small ? 9 : 10,
                fontWeight: FontWeight.w700,
                color: chipColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



