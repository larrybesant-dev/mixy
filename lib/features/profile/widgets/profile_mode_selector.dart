import 'package:flutter/material.dart';
import 'package:mixvy/shared/models/user_profile.dart';

/// Profile mode tab bar — rendered below the identity card.
/// Tapping a mode visually reorders profile sections.
class ProfileModeSelector extends StatelessWidget {
  final ProfileMode selected;
  final ValueChanged<ProfileMode> onChanged;
  final bool isOwner;

  const ProfileModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.isOwner = false,
  });

  static const _modes = [
    (ProfileMode.social, Icons.people_outline, 'Social'),
    (ProfileMode.dating, Icons.favorite_border, 'Dating'),
    (ProfileMode.creator, Icons.monetization_on_outlined, 'Creator'),
    (ProfileMode.eventHost, Icons.event_outlined, 'Events'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2D40)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: _modes.map((tuple) {
          final (mode, icon, label) = tuple;
          final active = selected == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active
                      ? _modeColor(mode).withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: active
                      ? Border.all(
                          color: _modeColor(mode).withValues(alpha: 0.6))
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 18,
                        color: active
                            ? _modeColor(mode)
                            : const Color(0xFF6B7280)),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                        color:
                            active ? _modeColor(mode) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static Color _modeColor(ProfileMode m) {
    switch (m) {
      case ProfileMode.social:
        return const Color(0xFF4A90FF);
      case ProfileMode.dating:
        return const Color(0xFFFF4D8B);
      case ProfileMode.creator:
        return const Color(0xFFFFAB00);
      case ProfileMode.eventHost:
        return const Color(0xFF00E5CC);
    }
  }
}

