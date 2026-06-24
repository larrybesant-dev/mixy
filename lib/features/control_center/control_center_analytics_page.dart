// lib/features/control_center/control_center_analytics_page.dart
//
// Real-time platform analytics dashboard + recent audit log entries.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/design_system/design_constants.dart';
import 'package:mixvy/features/control_center/providers/control_center_providers.dart';
import 'package:mixvy/features/control_center/services/audit_log_service.dart';
import 'package:intl/intl.dart';

class ControlCenterAnalyticsPage extends ConsumerWidget {
  const ControlCenterAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(platformAnalyticsProvider);
    final auditAsync = ref.watch(auditLogProvider);
    final liveRoomsAsync = ref.watch(allLiveRoomsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Stats grid ────────────────────────────────────────────────────
          liveRoomsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (rooms) => _StatsRow(liveRoomCount: rooms.length),
          ),
          const SizedBox(height: 8),
          analyticsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Analytics unavailable: $e',
                style: const TextStyle(color: Colors.white54)),
            data: (data) => _AnalyticsGrid(data: data),
          ),
          const SizedBox(height: 24),

          // ── Recent audit log ──────────────────────────────────────────────
          const Text(
            'Recent Admin Actions',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          auditAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Audit log unavailable: $e',
                style: const TextStyle(color: Colors.white54)),
            data: (entries) {
              if (entries.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No audit entries yet',
                        style: TextStyle(color: Colors.white38)),
                  ),
                );
              }
              return Column(
                children: entries
                    .map((e) => _AuditTile(entry: e))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.liveRoomCount});
  final int liveRoomCount;

  @override
  Widget build(BuildContext context) {
    return _StatCard(
      icon: Icons.radio,
      label: 'Live Rooms',
      value: '$liveRoomCount',
      color: DesignColors.accent,
    );
  }
}

class _AnalyticsGrid extends StatelessWidget {
  const _AnalyticsGrid({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final stats = <(String, dynamic, IconData, Color)>[
      (
        'Total Users',
        data['totalUsers'] ?? '—',
        Icons.people,
        DesignColors.accent
      ),
      (
        'Active Today',
        data['activeToday'] ?? '—',
        Icons.trending_up,
        Colors.green
      ),
      (
        'Messages / Day',
        data['messagesPerDay'] ?? '—',
        Icons.chat_bubble,
        DesignColors.secondary
      ),
      (
        'New Today',
        data['newUsersToday'] ?? '—',
        Icons.person_add,
        DesignColors.tertiary
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.0,
      children: stats
          .map((s) => _StatCard(
                icon: s.$3,
                label: s.$1,
                value: '${s.$2}',
                color: s.$4,
              ))
          .toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DesignColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 22)),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});
  final AuditLogEntry entry;

  static final _fmt = DateFormat('MMM d, HH:mm');

  IconData get _icon => switch (entry.actionType) {
        ActionType.setRole => Icons.manage_accounts,
        ActionType.banUser => Icons.block,
        ActionType.unbanUser => Icons.check_circle,
        ActionType.kickUser => Icons.logout,
        ActionType.muteUser => Icons.mic_off,
        ActionType.endRoom => Icons.stop_circle,
        ActionType.resolveReport => Icons.gavel,
        ActionType.dismissReport => Icons.cancel,
        ActionType.deleteContent => Icons.delete,
      };

  Color get _color => switch (entry.actionType) {
        ActionType.banUser || ActionType.endRoom => Colors.red,
        ActionType.unbanUser => Colors.green,
        ActionType.resolveReport => Colors.orange,
        ActionType.setRole => DesignColors.tertiary,
        _ => Colors.white54,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.actionType.value
                      .replaceAll('_', ' ')
                      .toUpperCase(),
                  style: TextStyle(
                      color: _color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
                Text(
                  'Target: ${entry.targetId}',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'By: ${entry.performedBy}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            _fmt.format(entry.timestamp),
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

