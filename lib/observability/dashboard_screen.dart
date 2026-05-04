import 'dart:async';

import 'package:flutter/material.dart';

import '../core/telemetry/telemetry_config.dart';
import 'firestore_call_tracker.dart';
import 'production_alerts.dart';
import 'runtime_telemetry.dart';
import 'webrtc_telemetry.dart';

// ─── Dashboard entry point ─────────────────────────────────────────────────

class ProductionDashboard extends StatefulWidget {
  const ProductionDashboard({super.key});

  @override
  State<ProductionDashboard> createState() => _ProductionDashboardState();
}

class _ProductionDashboardState extends State<ProductionDashboard> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 2 s so counters stay live without stream overhead.
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = TelemetryConfig.mode;
    final session =
        WebRtcTelemetry.currentSession ?? WebRtcTelemetry.lastSession;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Observability'),
        actions: [
          _ModeChip(mode: mode),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: mode == TelemetryMode.off
          ? const _OffPanel()
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (session != null) ...[
                  _SessionDrillDown(session: session),
                  const SizedBox(height: 8),
                ],
                _FirestorePanel(
                  reads: FirestoreCallTracker.snapshotReads(),
                  writes: FirestoreCallTracker.snapshotWrites(),
                  totalReads: FirestoreCallTracker.totalReads,
                  totalWrites: FirestoreCallTracker.totalWrites,
                ),
                const SizedBox(height: 8),
                _RebuildPanel(rebuilds: RuntimeTelemetry.rebuilds),
                const SizedBox(height: 8),
                _ListenerPanel(listeners: RuntimeTelemetry.listeners),
                const SizedBox(height: 8),
                _AlertsPanel(alerts: ProductionAlertSystem.alerts),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

// ─── Mode chip ─────────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode});
  final TelemetryMode mode;

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      TelemetryMode.off => 'OFF',
      TelemetryMode.standard => 'STD',
      TelemetryMode.debug => 'DBG',
    };
    final color = switch (mode) {
      TelemetryMode.off => Colors.grey,
      TelemetryMode.standard => Colors.blue,
      TelemetryMode.debug => Colors.orange,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: PopupMenuButton<TelemetryMode>(
        tooltip: 'Telemetry mode',
        child: Chip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          backgroundColor: color.withAlpha(30),
          side: BorderSide(color: color),
        ),
        onSelected: (m) => TelemetryConfig.setRuntimeOverride(m),
        itemBuilder: (_) => [
          const PopupMenuItem(value: TelemetryMode.off, child: Text('Off')),
          const PopupMenuItem(
            value: TelemetryMode.standard,
            child: Text('Standard'),
          ),
          const PopupMenuItem(value: TelemetryMode.debug, child: Text('Debug')),
        ],
      ),
    );
  }
}

// ─── Off state ────────────────────────────────────────────────────────────

class _OffPanel extends StatelessWidget {
  const _OffPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Telemetry is OFF',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 4),
          Text(
            'Tap the mode chip in the AppBar to enable.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ─── Session drill-down ────────────────────────────────────────────────────

class _SessionDrillDown extends StatelessWidget {
  const _SessionDrillDown({required this.session});
  final WebRtcSessionSnapshot session;

  @override
  Widget build(BuildContext context) {
    final duration = session.sessionDuration;
    final durationLabel = duration != null
        ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
        : 'active';

    return _Panel(
      title: 'WebRTC Session — ${session.roomId}',
      icon: Icons.videocam,
      color: Colors.teal,
      children: [
        _StatRow('Duration', durationLabel),
        _StatRow('Offers sent', '${session.offersSent}'),
        _StatRow('Answers received', '${session.answersReceived}'),
        _StatRow('ICE candidates (sampled)', '${session.iceCandidatesSent}'),
        _StatRow(
          'Reconnects',
          '${session.reconnectAttempts}',
          alert: session.reconnectAttempts >= 5,
        ),
        _StatRow(
          'Peer failures',
          '${session.peerFailures}',
          alert: session.peerFailures > 0,
        ),
        _StatRow('Stream refreshes', '${session.streamRefreshes}'),
      ],
    );
  }
}

// ─── Firestore panel ──────────────────────────────────────────────────────

class _FirestorePanel extends StatelessWidget {
  const _FirestorePanel({
    required this.reads,
    required this.writes,
    required this.totalReads,
    required this.totalWrites,
  });

  final Map<String, int> reads;
  final Map<String, int> writes;
  final int totalReads;
  final int totalWrites;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Firestore — $totalReads reads / $totalWrites writes',
      icon: Icons.storage,
      color: Colors.orange,
      children: [
        if (reads.isEmpty && writes.isEmpty)
          const _EmptyState('No Firestore activity recorded this session.')
        else ...[
          if (reads.isNotEmpty) ...[
            const _SubHeader('Reads by collection'),
            ...reads.entries.map((e) => _StatRow(e.key, '${e.value} reads')),
          ],
          if (writes.isNotEmpty) ...[
            const _SubHeader('Writes by collection'),
            ...writes.entries.map((e) => _StatRow(e.key, '${e.value} writes')),
          ],
        ],
      ],
    );
  }
}

// ─── Rebuild panel ────────────────────────────────────────────────────────

class _RebuildPanel extends StatelessWidget {
  const _RebuildPanel({required this.rebuilds});
  final Map<String, int> rebuilds;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Provider Rebuilds',
      icon: Icons.refresh,
      color: Colors.purple,
      children: rebuilds.isEmpty
          ? [const _EmptyState('No rebuild activity recorded.')]
          : rebuilds.entries
                .map((e) => _StatRow(e.key, 'x${e.value}', alert: e.value > 80))
                .toList(),
    );
  }
}

// ─── Listener panel ───────────────────────────────────────────────────────

class _ListenerPanel extends StatelessWidget {
  const _ListenerPanel({required this.listeners});
  final Map<String, int> listeners;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Active Listeners',
      icon: Icons.hearing,
      color: Colors.blue,
      children: listeners.isEmpty
          ? [const _EmptyState('No active listeners.')]
          : listeners.entries
                .map((e) => _StatRow(e.key, 'x${e.value}', alert: e.value > 20))
                .toList(),
    );
  }
}

// ─── Alerts panel ─────────────────────────────────────────────────────────

class _AlertsPanel extends StatelessWidget {
  const _AlertsPanel({required this.alerts});
  final List<ProductionAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'System Alerts (${alerts.length})',
      icon: Icons.warning_amber,
      color: Colors.red,
      children: alerts.isEmpty
          ? [const _EmptyState('No alerts — system is clean.')]
          : alerts.reversed
                .take(20)
                .map(
                  (a) => ListTile(
                    dense: true,
                    leading: Icon(
                      a.level == AlertLevel.critical
                          ? Icons.error
                          : a.level == AlertLevel.warning
                          ? Icons.warning
                          : Icons.info_outline,
                      color: a.level == AlertLevel.critical
                          ? Colors.red
                          : a.level == AlertLevel.warning
                          ? Colors.orange
                          : Colors.blue,
                      size: 18,
                    ),
                    title: Text(
                      a.message,
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                      '${a.level.name} · ${_ago(a.timestamp)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                )
                .toList(),
    );
  }

  static String _ago(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ─── Shared primitives ────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        initiallyExpanded: true,
        children: children,
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value, {this.alert = false});
  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 12)),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 12,
          color: alert ? Colors.red : null,
          fontWeight: alert ? FontWeight.bold : null,
        ),
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
    );
  }
}
