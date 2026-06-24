import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/shared/models/moderation_action.dart';

class ModStatsCard extends StatelessWidget {
  final String roomId;

  const ModStatsCard({
    super.key,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('moderation_logs')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data!.docs
            .map((doc) => ModerationAction.fromFirestore(doc))
            .toList();

        final stats = _calculateStats(logs);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatRow('Total Actions', stats['total'].toString()),
              _buildStatRow('Bans', stats['bans'].toString()),
              _buildStatRow('Temp Bans', stats['tempBans'].toString()),
              _buildStatRow('Shadow Bans', stats['shadowBans'].toString()),
              _buildStatRow('Kicks', stats['kicks'].toString()),
              _buildStatRow('Timeouts', stats['timeouts'].toString()),
              _buildStatRow('Warnings', stats['warnings'].toString()),
              _buildStatRow('Auto-Moderated', stats['autoMod'].toString()),
              _buildStatRow('Active Bans', stats['activeBans'].toString()),
              const Divider(height: 32),
              _buildTopModerators(logs),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _buildTopModerators(List<ModerationAction> logs) {
    final modCounts = <String, int>{};
    for (final log in logs) {
      modCounts[log.moderatorName] = (modCounts[log.moderatorName] ?? 0) + 1;
    }

    final sorted = modCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Moderators',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...sorted.take(5).map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Chip(
                        label: Text(entry.value.toString()),
                        backgroundColor: Colors.blue.shade100,
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Map<String, int> _calculateStats(List<ModerationAction> logs) {
    return {
      'total': logs.length,
      'bans': logs.where((l) => l.type == ModerationType.ban).length,
      'tempBans': logs.where((l) => l.type == ModerationType.tempBan).length,
      'shadowBans':
          logs.where((l) => l.type == ModerationType.shadowBan).length,
      'kicks': logs.where((l) => l.type == ModerationType.kick).length,
      'timeouts': logs.where((l) => l.type == ModerationType.timeout).length,
      'warnings': logs.where((l) => l.type == ModerationType.warn).length,
      'autoMod': logs.where((l) => l.isAutoModerated).length,
      'activeBans':
          logs.where((l) => l.isActive && l.type == ModerationType.ban).length,
    };
  }
}

