import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../observability/startup_timeline.dart';
import '../../feed/models/home_feed_snapshot.dart';

class SocialPulseSection extends StatelessWidget {
  const SocialPulseSection({
    super.key,
    required this.pulseItems,
    required this.onOpenPulseItem,
    required this.onOpenRooms,
    required this.onOpenDiscover,
    this.headline,
    this.subheadline,
    this.liveRoomCount = 0,
    this.suggestionCount = 0,
  });

  final List<PulseFeedItem> pulseItems;
  final ValueChanged<PulseFeedItem> onOpenPulseItem;
  final VoidCallback onOpenRooms;
  final VoidCallback onOpenDiscover;
  final String? headline;
  final String? subheadline;
  final int liveRoomCount;
  final int suggestionCount;

  @override
  Widget build(BuildContext context) {
    final hasActivity = pulseItems.any((item) => !item.isQuietState);

    // Record impression count for funnel analytics on each render.
    // This is idempotent-safe because the funnel accumulates across renders.
    if (pulseItems.isNotEmpty) {
      SessionFunnelTracker.instance.recordPulseImpression(pulseItems.length);
    }

    final titleText =
        headline ??
        (hasActivity
            ? 'Your people are moving right now'
            : 'Your circle is quiet right now.');
    final subtitleText =
        subheadline ??
        (hasActivity
            ? 'Room drops, follows, and profile moves show up here.'
            : 'Start the vibe and invite the next moment to happen.');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              VelvetNoir.surfaceHigh,
              VelvetNoir.secondary.withValues(alpha: 0.14),
            ],
          ),
          border: Border.all(color: VelvetNoir.primary.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: VelvetNoir.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: VelvetNoir.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Social Pulse',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: VelvetNoir.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        titleText,
                        style: GoogleFonts.raleway(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: VelvetNoir.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              subtitleText,
              style: GoogleFonts.raleway(
                fontSize: 12,
                color: VelvetNoir.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (liveRoomCount > 0 || suggestionCount > 0) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (liveRoomCount > 0)
                    _MetaPill(label: '$liveRoomCount live now'),
                  if (suggestionCount > 0)
                    _MetaPill(label: '$suggestionCount people to explore'),
                ],
              ),
            ],
            const SizedBox(height: 14),
            if (hasActivity)
              ...pulseItems
                  .take(3)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PulseItemRow(
                        item: item,
                        onTap: () => onOpenPulseItem(item),
                      ),
                    ),
                  )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Your circle is quiet right now.',
                  style: GoogleFonts.raleway(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: VelvetNoir.onSurface,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    StartupProfiler.instance.markFirstUserAction(
                      context: 'social_pulse_rooms_cta',
                    );
                    onOpenRooms();
                  },
                  icon: const Icon(Icons.mic_rounded, size: 16),
                  label: Text(hasActivity ? 'Join a room' : 'Start the vibe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VelvetNoir.primary,
                    foregroundColor: Colors.black,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    StartupProfiler.instance.markFirstUserAction(
                      context: 'social_pulse_discover_cta',
                    );
                    onOpenDiscover();
                  },
                  icon: const Icon(Icons.favorite_outline_rounded, size: 16),
                  label: const Text('Find people'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VelvetNoir.primary,
                    side: const BorderSide(color: VelvetNoir.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseItemRow extends StatelessWidget {
  const _PulseItemRow({required this.item, required this.onTap});

  final PulseFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          StartupProfiler.instance.markFirstUserAction(
            context: 'pulse_item_tap',
          );
          SessionFunnelTracker.instance.recordPulseTap();
          SessionFunnelTracker.instance.markFirstSuccessAction(
            action: 'pulse_item_tap',
          );
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _accentFor(item.type).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconFor(item.type),
                  color: _accentFor(item.type),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.raleway(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: VelvetNoir.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.detail,
                      style: GoogleFonts.raleway(
                        fontSize: 11,
                        color: VelvetNoir.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _relativeTime(item.timestamp),
                style: GoogleFonts.raleway(
                  fontSize: 10,
                  color: VelvetNoir.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'room_momentum':
        return Icons.mic_rounded;
      case 'followed_user':
        return Icons.favorite_rounded;
      case 'quiet_state':
        return Icons.nightlight_round;
      default:
        return Icons.bolt_rounded;
    }
  }

  Color _accentFor(String type) {
    switch (type) {
      case 'room_momentum':
        return VelvetNoir.liveGlow;
      case 'followed_user':
        return const Color(0xFF7C5FFF);
      case 'quiet_state':
        return VelvetNoir.primary;
      default:
        return VelvetNoir.secondary;
    }
  }

  String _relativeTime(DateTime timestamp) {
    final delta = DateTime.now().difference(timestamp);
    if (delta.inMinutes < 1) {
      return 'now';
    }
    if (delta.inHours < 1) {
      return '${delta.inMinutes}m';
    }
    if (delta.inDays < 1) {
      return '${delta.inHours}h';
    }
    return '${delta.inDays}d';
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VelvetNoir.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: VelvetNoir.outlineVariant),
      ),
      child: Text(
        label,
        style: GoogleFonts.raleway(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: VelvetNoir.onSurface,
        ),
      ),
    );
  }
}
