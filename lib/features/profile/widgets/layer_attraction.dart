import 'package:flutter/material.dart';
import 'package:mixvy/shared/models/user_profile.dart';

/// ── LAYER 1: Public Attraction ────────────────────────────────
/// Competes with: Tinder, Instagram
/// Shows: cover, avatar, name, age, city, status, badges, headline, bio, interests
class LayerAttraction extends StatelessWidget {
  final UserProfile p;
  final bool isOwner;
  final VoidCallback? onFollow;
  final VoidCallback? onMessage;

  const LayerAttraction({
    super.key,
    required this.p,
    this.isOwner = false,
    this.onFollow,
    this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final name = p.displayName ?? p.nickname ?? 'Anonymous';
    final age = p.age;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status + badge row
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _presenceBadge(p.presenceStatus),
            if (p.isPhotoVerified ?? false)
              _badge(Icons.camera_alt_outlined, 'Photo Verified',
                  const Color(0xFF00C853)),
            if (p.isIdVerified ?? false)
              _badge(Icons.verified_user_outlined, 'ID Verified',
                  const Color(0xFFFFD700)),
            if (p.isPremium)
              _badge(Icons.workspace_premium_outlined, 'Premium',
                  const Color(0xFFFFAB00)),
            if (p.isCreatorBadge)
              _badge(Icons.star_outline_rounded, 'Creator',
                  const Color(0xFFFF6B35)),
            if (p.isAdultContentEnabled && p.is18PlusVerified)
              _badge(Icons.eighteen_up_rating_outlined, '18+',
                  const Color(0xFFFF1744)),
          ],
        ),
        const SizedBox(height: 14),

        // Name + age + headline row
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Color(0x884A90FF), blurRadius: 14)],
                ),
              ),
              if (age != null)
                TextSpan(
                  text: ',  $age',
                  style: const TextStyle(
                    color: Color(0xFFB0B8C1),
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),

        if (p.gender != null || p.pronouns != null) ...[
          const SizedBox(height: 4),
          Text(
            [
              if (p.gender != null) p.gender!,
              if (p.pronouns != null) p.pronouns!
            ].join('  •  '),
            style: const TextStyle(color: Color(0xFF8892A4), fontSize: 13),
          ),
        ],

        if (p.location != null && p.location!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on_outlined,
                size: 14, color: Color(0xFF4A90FF)),
            const SizedBox(width: 4),
            Text(p.location!,
                style: const TextStyle(color: Color(0xFF4A90FF), fontSize: 13)),
          ]),
        ],

        // Follow + Message buttons (only shown on other people's profiles)
        if (!isOwner) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  'Follow',
                  Icons.person_add_outlined,
                  const Color(0xFF4A90FF),
                  onFollow ?? () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  'Message',
                  Icons.chat_bubble_outline,
                  const Color(0xFF00E5CC),
                  onMessage ?? () {},
                ),
              ),
            ],
          ),
        ],

        // Bio
        if (p.bio != null && p.bio!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader(
              Icons.person_outline, 'About', const Color(0xFF4A90FF)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E2D40)),
            ),
            child: Text(
              p.bio!,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB), fontSize: 14, height: 1.6),
            ),
          ),
        ],

        // Interests
        if (p.interests != null && p.interests!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader(Icons.local_fire_department_outlined, 'Interests',
              const Color(0xFFFF6B35)),
          const SizedBox(height: 8),
          _chipWrap(p.interests!, const Color(0xFFFF6B35)),
        ],

        // Personality prompts
        if (p.personalityPrompts != null &&
            p.personalityPrompts!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader(Icons.auto_awesome_outlined, 'Vibe Check',
              const Color(0xFF9B59B6)),
          const SizedBox(height: 8),
          ...p.personalityPrompts!.entries
              .map((e) => _promptCard(e.key, e.value)),
        ],
      ],
    );
  }

  Widget _presenceBadge(String? status) {
    Color c;
    String label;
    switch (status) {
      case 'in_room':
        c = const Color(0xFFFFAB00);
        label = '● In Room';
        break;
      case 'in_event':
        c = const Color(0xFF00E5CC);
        label = '● At Event';
        break;
      case 'online':
        c = const Color(0xFF00C853);
        label = '● Online';
        break;
      default:
        c = const Color(0xFF6B7280);
        label = '○ Offline';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style:
              TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 7),
      Text(title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(color: color.withValues(alpha: 0.5), blurRadius: 10)
            ],
          )),
      const SizedBox(width: 8),
      Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.2))),
    ]);
  }

  Widget _chipWrap(List<String> items, Color color) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(item,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ))
          .toList(),
    );
  }

  Widget _promptCard(String q, String a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF9B59B6).withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF9B59B6)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(q,
                  style: const TextStyle(
                      color: Color(0xFF9B59B6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 7),
        Text(a,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, height: 1.5)),
      ]),
    );
  }
}

