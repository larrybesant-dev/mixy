import 'package:flutter/material.dart';
import 'package:mixvy/shared/models/user_profile.dart';

/// ── LAYER 2: Live Presence ─────────────────────────────────────
/// Competes with: Paltalk, Clubhouse
/// Shows: currently live badge, join button, rooms hosted, rating, category, upcoming events
class LayerLivePresence extends StatelessWidget {
  final UserProfile p;
  final VoidCallback? onJoinRoom;
  final VoidCallback? onViewEvents;

  const LayerLivePresence({
    super.key,
    required this.p,
    this.onJoinRoom,
    this.onViewEvents,
  });

  bool get _isLive => p.presenceStatus == 'in_room' && p.activeRoomId != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.broadcast_on_personal, 'Live Presence',
            const Color(0xFFFFAB00)),
        const SizedBox(height: 12),

        // LIVE NOW banner
        if (_isLive) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A0A00), Color(0xFF2D1500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFFAB00).withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFFFAB00).withValues(alpha: 0.2),
                    blurRadius: 20),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFAB00),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingDot(),
                      SizedBox(width: 6),
                      Text('LIVE NOW',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Currently hosting a live room',
                    style: TextStyle(color: Color(0xFFFFD07A), fontSize: 13),
                  ),
                ),
                GestureDetector(
                  onTap: onJoinRoom,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFAB00),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Join',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Stats grid
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E2D40)),
          ),
          child: Row(
            children: [
              _statCol('${p.roomsHostedCount}', 'Rooms Hosted',
                  const Color(0xFFFFAB00)),
              _divV(),
              _statCol(
                p.avgRoomRating > 0
                    ? '${p.avgRoomRating.toStringAsFixed(1)} ★'
                    : '—',
                'Avg Rating',
                const Color(0xFFFFD700),
              ),
              _divV(),
              _statCol(
                p.topCategory ?? '—',
                'Top Category',
                const Color(0xFF4A90FF),
              ),
            ],
          ),
        ),

        // Upcoming events
        if (p.eventsHostingCount > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1628),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF00E5CC).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5CC).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_outlined,
                      color: Color(0xFF00E5CC), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.eventsHostingCount} upcoming event${p.eventsHostingCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: Color(0xFF00E5CC),
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                        ),
                        const Text('Tap to view & RSVP',
                            style: TextStyle(
                                color: Color(0xFF6B7280), fontSize: 12)),
                      ]),
                ),
                GestureDetector(
                  onTap: onViewEvents,
                  child: const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Color(0xFF00E5CC)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _statCol(String val, String label, Color color) {
    return Expanded(
      child: Column(children: [
        Text(val,
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _divV() =>
      Container(width: 1, height: 36, color: const Color(0xFF1E2D40));

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
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration:
            const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
      ),
    );
  }
}

