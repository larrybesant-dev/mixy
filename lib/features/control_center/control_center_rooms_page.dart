// lib/features/control_center/control_center_rooms_page.dart
//
// Admin view of live rooms: force-end rooms, view participant count.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixvy/core/design_system/design_constants.dart';
import 'package:mixvy/features/control_center/providers/control_center_providers.dart';
import 'package:mixvy/features/control_center/services/audit_log_service.dart';

class ControlCenterRoomsPage extends ConsumerWidget {
  const ControlCenterRoomsPage({super.key});

  Future<void> _endRoom(
      BuildContext context, WidgetRef ref, Map<String, dynamic> room) async {
    final roomId = room['id'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: DesignColors.surfaceLight,
        title: const Text('Force-end room?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'This will immediately end "${room['name'] ?? roomId}" for all participants.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Room',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(roomId)
        .update({'isLive': false, 'endedAt': FieldValue.serverTimestamp()});

    await AuditLogService.instance.logAction(
      actionType: ActionType.endRoom,
      targetId: roomId,
      metadata: {'name': room['name'] ?? roomId},
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room ended'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(allLiveRoomsProvider);

    return roomsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.red))),
      data: (rooms) {
        if (rooms.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.meeting_room, color: Colors.white24, size: 64),
                SizedBox(height: 16),
                Text('No live rooms',
                    style: TextStyle(color: Colors.white54, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rooms.length,
          itemBuilder: (context, i) {
            final room = rooms[i];
            final name = room['name'] as String? ?? 'Unnamed Room';
            final ownerUid = room['hostId'] as String? ??
                room['ownerId'] as String? ??
                '—';
            final participants =
                (room['participantIds'] as List?)?.length ?? 0;
            final genre = room['genre'] as String? ?? '';

            return Card(
              color: DesignColors.surfaceLight,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: DesignColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: DesignColors.accent, width: 1),
                      ),
                      child: const Icon(Icons.radio,
                          color: DesignColors.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            '$participants listener${participants == 1 ? '' : 's'}'
                            '${genre.isNotEmpty ? ' • $genre' : ''}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                          Text(
                            'Host: $ownerUid',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop_circle,
                          color: Colors.red, size: 28),
                      tooltip: 'Force-end room',
                      onPressed: () => _endRoom(context, ref, room),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

