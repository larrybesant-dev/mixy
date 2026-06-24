import 'package:flutter/material.dart';
import 'package:mixvy/shared/models/user_profile.dart';

/// ── LAYER 5: Safety / Control ──────────────────────────────────
/// Only visible to the profile owner.
/// Shows: DM restriction, hide distance, hide followers,
///        block users, restrict invites, 2FA status, report / moderation.
class LayerSafety extends StatelessWidget {
  final UserProfile p;

  /// Callbacks wired from parent
  final VoidCallback? onEditDmRestriction;
  final VoidCallback? onToggleHideDistance;
  final VoidCallback? onToggleHideFollowers;
  final VoidCallback? onToggleRestrictInvites;
  final VoidCallback? onBlockList;
  final VoidCallback? onSetup2FA;
  final VoidCallback? onContentModeration;
  final VoidCallback? onReport; // only shown on OTHER user's profile

  final bool isOwner;

  const LayerSafety({
    super.key,
    required this.p,
    this.isOwner = true,
    this.onEditDmRestriction,
    this.onToggleHideDistance,
    this.onToggleHideFollowers,
    this.onToggleRestrictInvites,
    this.onBlockList,
    this.onSetup2FA,
    this.onContentModeration,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    // Visitor safety actions (report / block)
    if (!isOwner) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              Icons.shield_outlined, 'Safety', const Color(0xFFFF4D4D)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _safetyButton(
                  Icons.block_outlined,
                  'Block User',
                  const Color(0xFFFF4D4D),
                  onReport ?? () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _safetyButton(
                  Icons.flag_outlined,
                  'Report',
                  const Color(0xFFFF9800),
                  onReport ?? () {},
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Owner safety control panel
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
            Icons.shield_outlined, 'Safety & Control', const Color(0xFF00E5CC)),
        const SizedBox(height: 12),

        // Status pills grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _statusPill(
              Icons.chat_outlined,
              'DMs: ${_dmLabel(p.dmRestriction)}',
              _dmColor(p.dmRestriction),
            ),
            _statusPill(
              Icons.location_off_outlined,
              p.hideDistance ? 'Distance Hidden' : 'Distance Visible',
              p.hideDistance
                  ? const Color(0xFF00C853)
                  : const Color(0xFF6B7280),
            ),
            _statusPill(
              Icons.visibility_off_outlined,
              p.hideFollowers ? 'Followers Hidden' : 'Followers Visible',
              p.hideFollowers
                  ? const Color(0xFF00C853)
                  : const Color(0xFF6B7280),
            ),
            _statusPill(
              Icons.do_not_disturb_outlined,
              p.restrictRoomInvites ? 'Invites Restricted' : 'Invites Open',
              p.restrictRoomInvites
                  ? const Color(0xFFFFAB00)
                  : const Color(0xFF6B7280),
            ),
            _statusPill(
              Icons.lock_outlined,
              p.twoFactorEnabled ? '2FA Enabled' : '2FA Off',
              p.twoFactorEnabled
                  ? const Color(0xFF00C853)
                  : const Color(0xFFFF4D4D),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Controls list
        _controlTile(Icons.chat_outlined, 'DM Restriction',
            _dmLabel(p.dmRestriction), onEditDmRestriction),
        _controlTile(Icons.my_location_outlined, 'Hide Distance', null,
            onToggleHideDistance,
            toggle: p.hideDistance),
        _controlTile(Icons.people_outline, 'Hide Follower Count', null,
            onToggleHideFollowers,
            toggle: p.hideFollowers),
        _controlTile(Icons.notifications_off_outlined, 'Restrict Room Invites',
            null, onToggleRestrictInvites,
            toggle: p.restrictRoomInvites),
        _controlTile(
            Icons.block_outlined, 'Blocked Users', 'Manage list', onBlockList),
        _controlTile(
          Icons.lock_outlined,
          'Two-Factor Authentication',
          p.twoFactorEnabled ? 'Enabled' : 'Set up now',
          onSetup2FA,
          valueColor: p.twoFactorEnabled
              ? const Color(0xFF00C853)
              : const Color(0xFFFF4D4D),
        ),
        if (p.isCreatorEnabled)
          _controlTile(Icons.content_paste_outlined, 'Content Moderation',
              'Review flagged content', onContentModeration),
      ],
    );
  }

  Widget _controlTile(
    IconData icon,
    String label,
    String? value,
    VoidCallback? onTap, {
    bool? toggle,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF00E5CC)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 14)),
                ),
                if (toggle != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: (toggle
                              ? const Color(0xFF00C853)
                              : const Color(0xFF6B7280))
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      toggle ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: toggle
                            ? const Color(0xFF00C853)
                            : const Color(0xFF6B7280),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ] else if (value != null) ...[
                  Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? const Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_ios,
                    size: 12, color: Color(0xFF374151)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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

  Widget _safetyButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
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

  String _dmLabel(String v) {
    switch (v) {
      case 'followers':
        return 'Followers Only';
      case 'nobody':
        return 'Nobody';
      default:
        return 'Everyone';
    }
  }

  Color _dmColor(String v) {
    switch (v) {
      case 'followers':
        return const Color(0xFFFFAB00);
      case 'nobody':
        return const Color(0xFFFF4D4D);
      default:
        return const Color(0xFF00C853);
    }
  }
}

