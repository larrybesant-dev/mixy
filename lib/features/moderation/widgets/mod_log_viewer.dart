import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/shared/models/moderation_action.dart';
import 'package:timeago/timeago.dart' as timeago;

class ModLogViewer extends StatelessWidget {
  final String roomId;

  const ModLogViewer({
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
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data!.docs
            .map((doc) => ModerationAction.fromFirestore(doc))
            .toList();

        if (logs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No moderation actions yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return _buildLogCard(context, log);
          },
        );
      },
    );
  }

  Widget _buildLogCard(BuildContext context, ModerationAction log) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: _getActionIcon(log.type),
        title: Text(
          '${log.type.name.toUpperCase()} - ${log.targetUserName}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By: ${log.moderatorName}'),
            if (log.reason.isNotEmpty) Text('Reason: ${log.reason}'),
            Text(timeago.format(log.timestamp)),
            if (log.expiresAt != null && log.isActive)
              Text(
                'Expires: ${timeago.format(log.expiresAt!)}',
                style: const TextStyle(color: Colors.orange),
              ),
            if (log.isExpired)
              const Text(
                'EXPIRED',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (log.isAutoModerated)
              const Chip(
                label: Text('AUTO', style: TextStyle(fontSize: 10)),
                backgroundColor: Colors.orange,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  Widget _getActionIcon(ModerationType type) {
    IconData icon;
    Color color;

    switch (type) {
      case ModerationType.ban:
      case ModerationType.tempBan:
        icon = Icons.block;
        color = Colors.red;
        break;
      case ModerationType.shadowBan:
        icon = Icons.visibility_off;
        color = Colors.purple;
        break;
      case ModerationType.kick:
        icon = Icons.exit_to_app;
        color = Colors.orange;
        break;
      case ModerationType.timeout:
        icon = Icons.schedule;
        color = Colors.amber;
        break;
      case ModerationType.warn:
        icon = Icons.warning;
        color = Colors.yellow;
        break;
      case ModerationType.lockdown:
        icon = Icons.lock;
        color = Colors.red;
        break;
      case ModerationType.unlock:
        icon = Icons.lock_open;
        color = Colors.green;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.2),
      child: Icon(icon, color: color),
    );
  }
}

