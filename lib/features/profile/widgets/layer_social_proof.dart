import 'package:flutter/material.dart';
import 'package:mixvy/shared/models/user_profile.dart';

/// ── LAYER 3: Social Proof ───────────────────────────────────────
/// Competes with: Facebook
/// Shows: followers, following, mutuals, events attended, rating, activity
class LayerSocialProof extends StatelessWidget {
  final UserProfile p;
  final bool isOwner;
  final VoidCallback? onViewFollowers;
  final VoidCallback? onViewFollowing;

  const LayerSocialProof({
    super.key,
    required this.p,
    this.isOwner = false,
    this.onViewFollowers,
    this.onViewFollowing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.group_outlined, 'Social', const Color(0xFF4A90FF)),
        const SizedBox(height: 12),

        // Main stats
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E2D40)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: onViewFollowers,
                child: _bigStat(
                  _formatCount(
                      p.hideFollowers && !isOwner ? 0 : p.followersCount),
                  'Followers',
                  const Color(0xFF4A90FF),
                  hidden: p.hideFollowers && !isOwner,
                ),
              ),
              _divV(),
              GestureDetector(
                onTap: onViewFollowing,
                child: _bigStat(_formatCount(p.followingCount), 'Following',
                    const Color(0xFF9B59B6)),
              ),
              _divV(),
              _bigStat(_formatCount(p.mutualsCount), 'Mutuals',
                  const Color(0xFFFF4D8B)),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Activity stats
        Row(
          children: [
            Expanded(
              child: _activityCard(
                Icons.event_available_outlined,
                '${p.eventsAttended}',
                'Events\nAttended',
                const Color(0xFF00E5CC),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _activityCard(
                Icons.record_voice_over_outlined,
                '${p.totalRoomsJoined}',
                'Rooms\nJoined',
                const Color(0xFFFFAB00),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _activityCard(
                Icons.star_half_outlined,
                p.communityRating > 0
                    ? p.communityRating.toStringAsFixed(1)
                    : '—',
                'Community\nRating',
                const Color(0xFFFFD700),
              ),
            ),
          ],
        ),

        // Member since
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E2D40)),
          ),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 14, color: Color(0xFF6B7280)),
            const SizedBox(width: 8),
            Text(
              'Member since ${_formatJoined(p.createdAt)}',
              style: const TextStyle(color: Color(0xFF8892A4), fontSize: 12),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _bigStat(String val, String label, Color color,
      {bool hidden = false}) {
    return Column(children: [
      hidden
          ? const Icon(Icons.visibility_off_outlined,
              color: Color(0xFF6B7280), size: 18)
          : Text(val,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(label,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
    ]);
  }

  Widget _activityCard(IconData icon, String val, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(val,
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 10, height: 1.3)),
      ]),
    );
  }

  Widget _divV() =>
      Container(width: 1, height: 40, color: const Color(0xFF1E2D40));

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

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  String _formatJoined(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}

