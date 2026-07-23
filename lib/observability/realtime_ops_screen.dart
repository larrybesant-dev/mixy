import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/core/theme.dart';
import 'package:mixvy/observability/realtime_ops_providers.dart';
import 'package:mixvy/shared/widgets/app_page_scaffold.dart';

class RealtimeOpsScreen extends ConsumerWidget {
  const RealtimeOpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opsAsync = ref.watch(realtimeOpsSnapshotProvider);

    return AppPageScaffold(
      backgroundColor: VelvetNoir.surface,
      appBar: AppBar(title: const Text('Realtime Ops')),
      body: opsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load realtime ops metrics.',
              style: GoogleFonts.raleway(color: VelvetNoir.onSurfaceVariant),
            ),
          ),
        ),
        data: (ops) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionCard(
                title: 'Presence',
                accent: const Color(0xFFD4AF37),
                metrics: [
                  _Metric('Firestore online', '${ops.firestoreOnlineUsers}'),
                  _Metric('Parity mismatches', '${ops.parityMismatchCount}'),
                  _Metric('Zombie listeners', '${ops.zombieListenerCount}'),
                  _Metric('Reconnect bursts', '${ops.reconnectBurstCount}'),
                ],
              ),
              _SectionCard(
                title: 'Rooms',
                accent: const Color(0xFF9B2535),
                metrics: [
                  _Metric('Discoverable', '${ops.discoverableCount}'),
                  _Metric('Warm', '${ops.warmCount}'),
                  _Metric('Cold', '${ops.coldCount}'),
                  _Metric('Invalid', '${ops.invalidCount}'),
                  _Metric(
                    'Orphan participants',
                    '${ops.orphanParticipantCount}',
                  ),
                  _Metric('Warnings', '${ops.warningAlertCount}'),
                  _Metric('Criticals', '${ops.criticalAlertCount}'),
                ],
              ),
              _SectionCard(
                title: 'Feed',
                accent: const Color(0xFFE2A85A),
                metrics: [
                  _Metric('Health state', ops.feedHealthState.name),
                  _Metric(
                    'Cold fallback active',
                    ops.coldFallbackActive ? 'true' : 'false',
                  ),
                  _Metric('Invariant issues', '${ops.invariantIssueCount}'),
                  _Metric(
                    'Hidden direct calls',
                    '${ops.hiddenPendingDirectCallCount}',
                  ),
                ],
              ),
              _SectionCard(
                title: 'Ownership',
                accent: const Color(0xFF5C7CFA),
                metrics: [
                  _Metric('Host conflict', ops.hostConflict ? 'true' : 'false'),
                  _Metric('Host missing', ops.hostMissing ? 'true' : 'false'),
                  _Metric('Host transfers', '${ops.ownershipTransferCount}'),
                  _Metric(
                    'Moderator promotions',
                    '${ops.moderatorPromotionCount}',
                  ),
                  _Metric('Duplicate joins', '${ops.duplicateJoinCount}'),
                ],
              ),
              _SectionCard(
                title: 'Listeners',
                accent: const Color(0xFF2E7D32),
                metrics: [
                  _Metric('Active listeners', '${ops.activeListenerCount}'),
                  _Metric(
                    'Duplicate listener keys',
                    '${ops.duplicateListenerCount}',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.accent,
    required this.metrics,
  });

  final String title;
  final Color accent;
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: VelvetNoir.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...metrics.map(
            (metric) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      metric.label,
                      style: GoogleFonts.raleway(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: VelvetNoir.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    metric.value,
                    style: GoogleFonts.raleway(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: VelvetNoir.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value);

  final String label;
  final String value;
}



