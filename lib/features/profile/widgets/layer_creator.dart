import 'package:flutter/material.dart';
import 'package:mixvy/shared/models/user_profile.dart';

/// ── LAYER 4: Creator Monetization (18+) ────────────────────────
/// Competes with: OnlyFans
/// Edge: two-way live interaction + community, not just paywalled content
///
/// PUBLIC view: Subscribe button, tier, tipping, exclusive features
/// PRIVATE (owner) view: Earnings dashboard, subscriber count, withdraw
class LayerCreator extends StatelessWidget {
  final UserProfile p;
  final bool isOwner;
  final VoidCallback? onSubscribe;
  final VoidCallback? onTip;
  final VoidCallback? onJoinPaidRoom;
  final VoidCallback? onViewVault;
  final VoidCallback? onWithdraw;

  const LayerCreator({
    super.key,
    required this.p,
    this.isOwner = false,
    this.onSubscribe,
    this.onTip,
    this.onJoinPaidRoom,
    this.onViewVault,
    this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    if (!p.isCreatorEnabled) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(),
        const SizedBox(height: 12),
        isOwner ? _ownerView() : _publicView(),
      ],
    );
  }

  // ── PUBLIC: what visitors see ──────────────────────────────────
  Widget _publicView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Creator headline
        if (p.creatorHeadline != null && p.creatorHeadline!.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0F00),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFFAB00).withValues(alpha: 0.4)),
            ),
            child: Text(
              p.creatorHeadline!,
              style: const TextStyle(
                  color: Color(0xFFFFD07A), fontSize: 14, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 18+ adult content gate notice
        if (p.isAdultContentEnabled) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0008),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFFF1744).withValues(alpha: 0.5)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF1744), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Adult content — 18+ verified users only. You must verify your age to access exclusive content.',
                  style: TextStyle(
                      color: Color(0xFFFF8A80), fontSize: 12, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // Subscribe CTA
        GestureDetector(
          onTap: onSubscribe,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A0F00), Color(0xFF2D1900)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFFAB00).withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFFFAB00).withValues(alpha: 0.15),
                    blurRadius: 20),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFAB00).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star_outline_rounded,
                      color: Color(0xFFFFAB00), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Subscribe for Exclusive Access',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p.subscriptionPrice != null
                              ? '\$${p.subscriptionPrice!.toStringAsFixed(2)} / month'
                              : 'Price TBD',
                          style: const TextStyle(
                              color: Color(0xFFFFAB00),
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_formatCount(p.subscriberCount)} subscriber${p.subscriberCount != 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: Color(0xFF8892A4), fontSize: 12),
                        ),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFAB00),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('SUBSCRIBE',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 12)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Tip + Paid rooms + Vault row
        Row(
          children: [
            if (onTip != null)
              Expanded(
                  child: _smallAction(Icons.volunteer_activism_outlined, 'Tip',
                      const Color(0xFFFF4D8B), onTip!)),
            if (onTip != null && (p.hasPaidRooms || p.hasContentVault))
              const SizedBox(width: 8),
            if (p.hasPaidRooms)
              Expanded(
                  child: _smallAction(Icons.lock_outline, 'Paid Room',
                      const Color(0xFF9B59B6), onJoinPaidRoom ?? () {})),
            if (p.hasPaidRooms && p.hasContentVault) const SizedBox(width: 8),
            if (p.hasContentVault)
              Expanded(
                  child: _smallAction(Icons.photo_library_outlined, 'Vault',
                      const Color(0xFF00E5CC), onViewVault ?? () {})),
          ],
        ),
      ],
    );
  }

  // ── PRIVATE OWNER DASHBOARD ─────────────────────────────────────
  Widget _ownerView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CreatorOwnerBanner(),
        const SizedBox(height: 12),

        // Revenue stats
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B1A0A), Color(0xFF122012)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF00C853).withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _earningsStat('\$${p.totalEarnings.toStringAsFixed(2)}',
                    'Total Earned', const Color(0xFF00C853)),
                _divV(),
                _earningsStat('${p.subscriberCount}', 'Subscribers',
                    const Color(0xFFFFAB00)),
                _divV(),
                _earningsStat(
                  p.subscriptionPrice != null
                      ? '\$${p.subscriptionPrice!.toStringAsFixed(2)}'
                      : '—',
                  'Price/mo',
                  const Color(0xFF4A90FF),
                ),
              ]),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onWithdraw,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF00C853).withValues(alpha: 0.7)),
                  ),
                  child: const Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.account_balance_wallet_outlined,
                          color: Color(0xFF00C853), size: 16),
                      SizedBox(width: 8),
                      Text('Withdraw Earnings',
                          style: TextStyle(
                              color: Color(0xFF00C853),
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),
        const _CreatorManageRow(),
      ],
    );
  }

  Widget _sectionHeader() {
    const color = Color(0xFFFFAB00);
    return Row(children: [
      const Icon(Icons.monetization_on_outlined, size: 16, color: color),
      const SizedBox(width: 7),
      const Text('Creator',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Color(0x88FFAB00), blurRadius: 10)],
          )),
      if (p.isAdultContentEnabled) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFF1744).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: const Color(0xFFFF1744).withValues(alpha: 0.6)),
          ),
          child: const Text('18+',
              style: TextStyle(
                  color: Color(0xFFFF1744),
                  fontSize: 10,
                  fontWeight: FontWeight.w900)),
        ),
      ],
      const SizedBox(width: 8),
      Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.2))),
    ]);
  }

  Widget _smallAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _earningsStat(String val, String label, Color color) {
    return Column(children: [
      Text(val,
          style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(label,
          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
    ]);
  }

  Widget _divV() =>
      Container(width: 1, height: 36, color: const Color(0xFF1E2D40));

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _CreatorOwnerBanner extends StatelessWidget {
  const _CreatorOwnerBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0F00),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFFFFAB00).withValues(alpha: 0.4)),
      ),
      child: const Row(children: [
        Icon(Icons.lock_outlined, size: 14, color: Color(0xFFFFAB00)),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Creator dashboard — visible to you only',
            style: TextStyle(color: Color(0xFFFFD07A), fontSize: 12),
          ),
        ),
      ]),
    );
  }
}

class _CreatorManageRow extends StatelessWidget {
  const _CreatorManageRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _tile(Icons.analytics_outlined, 'Analytics',
                const Color(0xFF4A90FF))),
        const SizedBox(width: 8),
        Expanded(
            child: _tile(
                Icons.people_outline, 'Subscribers', const Color(0xFF9B59B6))),
        const SizedBox(width: 8),
        Expanded(
            child: _tile(
                Icons.settings_outlined, 'Settings', const Color(0xFF6B7280))),
      ],
    );
  }

  Widget _tile(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

