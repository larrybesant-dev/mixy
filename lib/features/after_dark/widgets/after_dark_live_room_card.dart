import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/room_model.dart';
import '../theme/after_dark_theme.dart';

class AfterDarkLiveRoomCard extends StatelessWidget {
  final RoomModel room;
  final VoidCallback onTap;

  const AfterDarkLiveRoomCard({
    super.key,
    required this.room,
    required this.onTap,
  });

  static const Map<String, List<Color>> _fallbackGradients = {
    'romance': [Color(0xFF4A1020), Color(0xFF1B0910)],
    'roleplay': [Color(0xFF351327), Color(0xFF16070F)],
    'chat': [Color(0xFF3E1020), Color(0xFF12060A)],
    'couples': [Color(0xFF542033), Color(0xFF1B0910)],
    'dating': [Color(0xFF641A2F), Color(0xFF1A0810)],
    'party': [Color(0xFF5C1628), Color(0xFF15060C)],
  };

  static const Map<String, String> _categoryGlyphs = {
    'romance': 'Velvet',
    'roleplay': 'Fantasy',
    'chat': 'Whispers',
    'couples': 'Couples',
    'dating': 'Flirt',
    'party': 'After Hours',
  };

  @override
  Widget build(BuildContext context) {
    final memberCount = room.memberCount > 0
        ? room.memberCount
        : room.stageUserIds.length + room.audienceUserIds.length;
    final categoryKey = room.category?.toLowerCase() ?? 'chat';
    final gradientColors =
        _fallbackGradients[categoryKey] ??
        const [Color(0xFF461424), Color(0xFF14070C)];
    final moodLabel = _categoryGlyphs[categoryKey] ?? 'Late Night';
    final accent = room.isLocked ? EmberDark.secondary : EmberDark.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: EmberDark.surfaceHigh,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: EmberDark.outlineVariant.withValues(alpha: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 112,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if ((room.thumbnailUrl ?? '').isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: room.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (context, error, stackTrace) =>
                          _LoungeFallback(
                            label: moodLabel,
                            gradientColors: gradientColors,
                          ),
                    )
                  else
                    _LoungeFallback(
                      label: moodLabel,
                      gradientColors: gradientColors,
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.10),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _Pill(
                      icon: Icons.favorite_rounded,
                      label: 'LIVE',
                      background: EmberDark.primary.withValues(alpha: 0.88),
                      foreground: Colors.white,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _Pill(
                      icon: Icons.people_alt_rounded,
                      label: '$memberCount',
                      background: Colors.black.withValues(alpha: 0.45),
                      foreground: EmberDark.secondary,
                    ),
                  ),
                  if (room.isLocked)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: _Pill(
                        icon: Icons.lock_outline_rounded,
                        label: 'PRIVATE',
                        background: EmberDark.secondary.withValues(alpha: 0.18),
                        foreground: EmberDark.secondary,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name.isNotEmpty ? room.name : 'Velvet Lounge',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: EmberDark.onSurface,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      room.description?.trim().isNotEmpty == true
                          ? room.description!.trim()
                          : 'Soft lighting, grown energy, and a room built for chemistry.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.raleway(
                        fontSize: 11,
                        height: 1.35,
                        color: EmberDark.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _TagChip(label: moodLabel),
                        if ((room.category ?? '').isNotEmpty)
                          _TagChip(label: room.category!.toUpperCase()),
                        if (room.tags.isNotEmpty)
                          _TagChip(label: room.tags.first.toUpperCase()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoungeFallback extends StatelessWidget {
  final String label;
  final List<Color> gradientColors;

  const _LoungeFallback({required this.label, required this.gradientColors});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -18,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EmberDark.secondary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: 14,
            left: 14,
            child: Text(
              label,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  const _Pill({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.raleway(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: EmberDark.surfaceHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: EmberDark.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.raleway(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: EmberDark.onSurfaceVariant,
        ),
      ),
    );
  }
}



