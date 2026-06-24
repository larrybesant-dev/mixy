import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/shared/models/moderation_action.dart';
import '../widgets/mod_log_viewer.dart';
import '../widgets/mod_actions_panel.dart';
import '../widgets/mod_stats_card.dart';
import 'package:flutter/services.dart';

class ModeratorDashboardPage extends ConsumerStatefulWidget {
  final String roomId;

  const ModeratorDashboardPage({
    super.key,
    required this.roomId,
  });

  @override
  ConsumerState<ModeratorDashboardPage> createState() =>
      _ModeratorDashboardPageState();
}

class _ModeratorDashboardPageState extends ConsumerState<ModeratorDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderator Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportLogs(context),
            tooltip: 'Export Logs',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Live Logs', icon: Icon(Icons.list)),
            Tab(text: 'Actions', icon: Icon(Icons.shield)),
            Tab(text: 'Statistics', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ModLogViewer(roomId: widget.roomId),
          ModActionsPanel(roomId: widget.roomId),
          ModStatsCard(roomId: widget.roomId),
        ],
      ),
    );
  }

  Future<void> _exportLogs(BuildContext context) async {
    try {
      // Fetch all logs
      final snapshot = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('moderation_logs')
          .orderBy('timestamp', descending: true)
          .limit(1000)
          .get();

      final logs = snapshot.docs
          .map((doc) => ModerationAction.fromFirestore(doc))
          .toList();

      // Convert to CSV
      final csv = _convertToCSV(logs);

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: csv));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Moderation logs copied to clipboard (CSV format)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _convertToCSV(List<ModerationAction> logs) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
        'Timestamp,Type,Target User,Moderator,Reason,Expires At,Auto-Moderated');

    // Data rows
    for (final log in logs) {
      buffer.writeln([
        log.timestamp.toIso8601String(),
        log.type.name,
        log.targetUserName,
        log.moderatorName,
        '"${log.reason}"',
        log.expiresAt?.toIso8601String() ?? 'N/A',
        log.isAutoModerated,
      ].join(','));
    }

    return buffer.toString();
  }
}

