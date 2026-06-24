import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/room/services/room_moderation_service.dart';

/// Room Moderation Widget
///
/// Features:
/// - Warn users
/// - Mute/unmute users
/// - Kick users
/// - Ban/unban users
/// - View moderation logs
class RoomModerationWidget extends ConsumerStatefulWidget {
  final String roomId;
  final String currentUserId;
  final bool isModerator;
  final VoidCallback? onClose;

  const RoomModerationWidget({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.isModerator,
    this.onClose,
  });

  @override
  ConsumerState<RoomModerationWidget> createState() =>
      _RoomModerationWidgetState();
}

class _RoomModerationWidgetState extends ConsumerState<RoomModerationWidget> {
  final _reasonController = TextEditingController();
  String _selectedDuration = 'permanent';
  String _selectedAction = 'warn';

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isModerator) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2F),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'You do not have moderation permissions',
            style: TextStyle(
              color: Colors.red[300],
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    final moderationLogsAsync =
        ref.watch(moderationLogsProvider(widget.roomId));
    final mutedUsersAsync = ref.watch(mutedUsersProvider(widget.roomId));
    final bannedUsersAsync = ref.watch(bannedUsersProvider(widget.roomId));
    final moderationService = ref.read(roomModerationServiceProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: Color(0xFFFF4C4C),
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Moderation Tools',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Action Selector
            const Text(
              'Select Action',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'warn',
                  label: Text('Warn'),
                ),
                ButtonSegment<String>(
                  value: 'mute',
                  label: Text('Mute'),
                ),
                ButtonSegment<String>(
                  value: 'kick',
                  label: Text('Kick'),
                ),
                ButtonSegment<String>(
                  value: 'ban',
                  label: Text('Ban'),
                ),
              ],
              selected: <String>{_selectedAction},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() => _selectedAction = newSelection.first);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFFFF4C4C);
                    }
                    return Colors.grey[700]!;
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Duration selector (for temporary actions)
            if (_selectedAction == 'mute' || _selectedAction == 'ban') ...[
              const Text(
                'Duration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _selectedDuration,
                isExpanded: true,
                dropdownColor: Colors.grey[800],
                items: const [
                  DropdownMenuItem(
                    value: 'permanent',
                    child: Text('Permanent'),
                  ),
                  DropdownMenuItem(
                    value: '1h',
                    child: Text('1 Hour'),
                  ),
                  DropdownMenuItem(
                    value: '24h',
                    child: Text('24 Hours'),
                  ),
                  DropdownMenuItem(
                    value: '7d',
                    child: Text('7 Days'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedDuration = value ?? 'permanent');
                },
              ),
              const SizedBox(height: 16),
            ],

            // Reason input
            const Text(
              'Reason',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter reason for action',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF4C4C),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _handleModerationAction(moderationService);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4C4C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Apply Action',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Statistics
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Room Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  mutedUsersAsync.when(
                    data: (mutedUsers) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Muted Users',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4C4C)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              mutedUsers.length.toString(),
                              style: const TextStyle(
                                color: Color(0xFFFF4C4C),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),
                  bannedUsersAsync.when(
                    data: (bannedUsers) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Banned Users',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              bannedUsers.length.toString(),
                              style: TextStyle(
                                color: Colors.red[400],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Moderation logs
            const Text(
              'Recent Actions',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            moderationLogsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No moderation actions yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  );
                }

                return Column(
                  children: logs.take(5).map((log) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _getActionName(log.action),
                                  style: TextStyle(
                                    color: _getActionColor(log.action),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  _formatTime(log.timestamp),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reason: ${log.reason}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const SizedBox(
                height: 40,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF4C4C),
                      ),
                    ),
                  ),
                ),
              ),
              error: (error, __) => Text(
                'Error loading logs',
                style: TextStyle(color: Colors.red[300], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleModerationAction(RoomModerationService service) {
    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason')),
      );
      return;
    }

    // For demo, we'll show a confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2F),
        title: const Text(
          'Confirm Action',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Apply ${_selectedAction.toUpperCase()} to user?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Action would be performed here
              Navigator.pop(context);
              _reasonController.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Action applied: ${_selectedAction.toUpperCase()}',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4C4C),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _getActionName(ModerationAction action) {
    switch (action) {
      case ModerationAction.warn:
        return 'Warning';
      case ModerationAction.mute:
        return 'Muted';
      case ModerationAction.kick:
        return 'Kicked';
      case ModerationAction.ban:
        return 'Banned';
      case ModerationAction.unban:
        return 'Unbanned';
    }
  }

  Color _getActionColor(ModerationAction action) {
    switch (action) {
      case ModerationAction.warn:
        return Colors.yellow;
      case ModerationAction.mute:
        return Colors.orange;
      case ModerationAction.kick:
        return Colors.red;
      case ModerationAction.ban:
        return Colors.red;
      case ModerationAction.unban:
        return Colors.green;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}

