import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mixmingle/shared/models/room.dart';
import 'package:mixmingle/shared/providers/room_providers.dart';
import 'package:mixmingle/shared/providers/video_media_providers.dart';

class VoiceRoomControls extends ConsumerWidget {
  final Room room;
  final String currentUserId;
  final int speakerTimeRemaining;
  final VoidCallback? onExtendTime;
  final VoidCallback? onSkipSpeaker;

  const VoiceRoomControls({
    super.key,
    required this.room,
    required this.currentUserId,
    this.speakerTimeRemaining = 0,
    this.onExtendTime,
    this.onSkipSpeaker,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomService = ref.read(roomServiceProvider);
    final agoraService = ref.watch(agoraVideoServiceProvider);
    final theme = Theme.of(context);

    final isHost = currentUserId == room.hostId;
    final isModerator = room.moderators.contains(currentUserId);
    final isSpeaker = room.speakers.contains(currentUserId);
    final isListener = room.listeners.contains(currentUserId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Room Status
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: room.isLive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                room.isLive ? 'Live' : 'Ended',
                style: TextStyle(
                  color: room.isLive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              // Speaker timer countdown (turn-based mode)
              if (room.turnBased && speakerTimeRemaining > 0)
                _buildCountdownWidget(theme)
              else
                Text(
                  '${room.viewerCount} listeners',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Voice Controls
          if (room.isLive) ...[
            const Text(
              'Voice Controls',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Mute/Unmute Button
                Expanded(
                  child: Tooltip(
                    message: agoraService.isMicMuted
                        ? 'Unmute your microphone (Ctrl+M)'
                        : 'Mute your microphone (Ctrl+M)',
                    child: ElevatedButton.icon(
                      onPressed: () => agoraService.toggleMic(),
                      icon: Icon(
                        agoraService.isMicMuted ? Icons.mic_off : Icons.mic,
                        color: theme.colorScheme.onPrimary,
                      ),
                      label: Text(
                        agoraService.isMicMuted ? 'Unmute' : 'Mute',
                        style: TextStyle(color: theme.colorScheme.onPrimary),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: agoraService.isMicMuted
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Speaker/Listener Toggle
                if (isSpeaker)
                  Expanded(
                    child: room.turnBased
                        ? Tooltip(
                            message: 'End your speaking turn',
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _endTurn(context, roomService, currentUserId),
                              icon: Icon(Icons.stop_circle_outlined,
                                  color: theme.colorScheme.onError),
                              label: Text(
                                'End Turn',
                                style:
                                    TextStyle(color: theme.colorScheme.onError),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.error
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        : Tooltip(
                            message: 'Stop speaking and become a listener',
                            child: ElevatedButton.icon(
                              onPressed: () => roomService.stopSpeaking(
                                  room.id, currentUserId),
                              icon: Icon(Icons.headphones,
                                  color: theme.colorScheme.onPrimary),
                              label: Text(
                                'Stop Speaking',
                                style: TextStyle(
                                    color: theme.colorScheme.onPrimary),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                  )
                else if (isListener)
                  Expanded(
                    child: room.turnBased
                        ? _buildRaiseHandButton(
                            context, roomService, currentUserId, room, theme)
                        : Tooltip(
                            message: 'Request permission to speak in this room',
                            child: ElevatedButton.icon(
                              onPressed: () => roomService.requestToSpeak(
                                  room.id, currentUserId),
                              icon: Icon(Icons.mic,
                                  color: theme.colorScheme.onPrimary),
                              label: Text(
                                'Request to Speak',
                                style: TextStyle(
                                    color: theme.colorScheme.onPrimary),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.tertiary,
                              ),
                            ),
                          ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Moderator Controls
          if (isModerator) ...[
            const Text(
              'Moderator Controls',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // End Room (Host only)
                if (isHost)
                  Tooltip(
                    message: 'Close this room for all participants',
                    child: ElevatedButton.icon(
                      onPressed: () => _showEndRoomDialog(context, roomService),
                      icon: Icon(Icons.stop, color: theme.colorScheme.onError),
                      label: Text(
                        'End Room',
                        style: TextStyle(color: theme.colorScheme.onError),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ),

                // Grant Turn (Turn-based mode)
                if (room.turnBased) ...[
                  // Extend Time
                  if (speakerTimeRemaining > 0)
                    Tooltip(
                      message: 'Give the current speaker 30 more seconds',
                      child: ElevatedButton.icon(
                        onPressed: onExtendTime,
                        icon: Icon(Icons.add_circle_outline,
                            color: theme.colorScheme.onPrimary),
                        label: Text(
                          'Extend +30s',
                          style: TextStyle(color: theme.colorScheme.onPrimary),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  // Skip Speaker
                  if (speakerTimeRemaining > 0)
                    Tooltip(
                      message: 'Move to the next speaker in queue',
                      child: ElevatedButton.icon(
                        onPressed: onSkipSpeaker,
                        icon: Icon(Icons.fast_forward,
                            color: theme.colorScheme.onPrimary),
                        label: Text(
                          'Skip',
                          style: TextStyle(color: theme.colorScheme.onPrimary),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                      ),
                    ),
                  // Grant Next from Queue
                  if (room.speakerQueue.isNotEmpty)
                    Tooltip(
                      message:
                          'Grant speaking turn to next person in queue (${room.speakerQueue.length} waiting)',
                      child: ElevatedButton.icon(
                        onPressed: () => _grantNextSpeaker(
                            context, roomService, currentUserId),
                        icon: Icon(Icons.skip_next,
                            color: theme.colorScheme.onPrimary),
                        label: Text(
                          'Next Speaker',
                          style: TextStyle(color: theme.colorScheme.onPrimary),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                        ),
                      ),
                    ),
                  // Manual Grant Turn
                  Tooltip(
                    message:
                        'Manually grant speaking turn to a specific person',
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showGrantTurnDialog(context, roomService),
                      icon: Icon(Icons.pan_tool,
                          color: theme.colorScheme.onPrimary),
                      label: Text(
                        'Grant Turn',
                        style: TextStyle(color: theme.colorScheme.onPrimary),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],

                // Invite People
                Tooltip(
                  message: 'Invite people to join this room',
                  child: ElevatedButton.icon(
                    onPressed: () => _showInviteDialog(context),
                    icon: Icon(Icons.person_add,
                        color: theme.colorScheme.onPrimary),
                    label: Text(
                      'Invite',
                      style: TextStyle(color: theme.colorScheme.onPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ),

                // Room Settings
                Tooltip(
                  message: 'Configure room settings and preferences',
                  child: ElevatedButton.icon(
                    onPressed: () => _showRoomSettings(context, ref),
                    icon: Icon(Icons.settings,
                        color: theme.colorScheme.onSurface),
                    label: Text(
                      'Settings',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Leave Room Button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Tooltip(
              message: 'Leave this room and return to the home page',
              child: OutlinedButton.icon(
                onPressed: () => _leaveRoom(context, roomService),
                icon: const Icon(Icons.exit_to_app, color: Colors.red),
                label: const Text(
                  'Leave Room',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEndRoomDialog(BuildContext context, dynamic roomService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Room'),
        content: const Text(
            'Are you sure you want to end this room? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await roomService.endVoiceRoom(room.id);
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop();
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room ended successfully')),
                );
                // Navigate back to home or room list
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop();
              } catch (e) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error ending room: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('End Room'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite People'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this room link with others:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'https://mix-and-mingle.web.app/room/${room.id}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // ignore: deprecated_member_use
              Share.share(
                'Join my room on Mix & Mingle: https://mix-and-mingle.web.app/room/${room.id}',
              );
              Navigator.of(context).pop();
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }

  void _showRoomSettings(BuildContext context, WidgetRef ref) {
    final roomService = ref.read(roomServiceProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Room Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Room Title'),
              subtitle: Text(room.title),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final newTitle = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    final controller = TextEditingController(text: room.title);
                    return AlertDialog(
                      title: const Text('Edit Room Title'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          labelText: 'Room Title',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text.trim()),
                          child: const Text('Save'),
                        ),
                      ],
                    );
                  },
                );

                if (newTitle != null && newTitle.isNotEmpty) {
                  await roomService.updateRoomTitle(room.id, newTitle);
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Room title updated successfully')),
                  );
                }
              },
            ),
            ListTile(
              title: const Text('Room Description'),
              subtitle: Text(room.description),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final newDescription = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    final controller =
                        TextEditingController(text: room.description);
                    return AlertDialog(
                      title: const Text('Edit Room Description'),
                      content: TextField(
                        controller: controller,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Room Description',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text.trim()),
                          child: const Text('Save'),
                        ),
                      ],
                    );
                  },
                );

                if (newDescription != null) {
                  await roomService.updateRoomDescription(
                      room.id, newDescription);
                  // Refresh or notify
                }
              },
            ),
            SwitchListTile(
              title: const Text('Allow Speaker Requests'),
              value: room.allowSpeakerRequests,
              onChanged: (value) async {
                await roomService.updateAllowSpeakerRequests(room.id, value);
                // Refresh or notify
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _leaveRoom(BuildContext context, dynamic roomService) async {
    try {
      await roomService.leaveVoiceRoom(room.id, currentUserId);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Left room successfully')),
      );
      // Navigate back
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop();
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error leaving room: $e')),
      );
    }
  }

  void _showGrantTurnDialog(BuildContext context, dynamic roomService) {
    final speakersNotHavingTurn =
        room.speakers.where((s) => s != room.currentSpeakerId).toList();

    if (speakersNotHavingTurn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No speakers available to grant turn')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grant Speaking Turn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a speaker to grant the turn:'),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: speakersNotHavingTurn.length,
                itemBuilder: (context, index) {
                  final userId = speakersNotHavingTurn[index];
                  return ListTile(
                    title:
                        Text(userId), // In production, resolve to display name
                    trailing: const Icon(Icons.check_circle_outline),
                    onTap: () async {
                      try {
                        await roomService.grantTurn(
                            room.id, currentUserId, userId);
                        // ignore: use_build_context_synchronously
                        Navigator.of(context).pop();
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Turn granted successfully')),
                        );
                      } catch (e) {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error granting turn: $e')),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _endTurn(
      BuildContext context, dynamic roomService, String userId) async {
    try {
      await roomService.endTurn(room.id, userId);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Turn ended successfully')),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error ending turn: $e')),
      );
    }
  }

  Widget _buildRaiseHandButton(
    BuildContext context,
    dynamic roomService,
    String userId,
    Room room,
    ThemeData theme,
  ) {
    final hasHandRaised = room.raisedHands.contains(userId);

    return ElevatedButton.icon(
      onPressed: () async {
        try {
          if (hasHandRaised) {
            await roomService.lowerHand(room.id, userId);
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Hand lowered')),
            );
          } else {
            await roomService.raiseHand(room.id, userId);
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Hand raised - waiting for moderator')),
            );
          }
        } catch (e) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      },
      icon: Icon(
        hasHandRaised ? Icons.pan_tool : Icons.pan_tool_alt,
        color: theme.colorScheme.onPrimary,
      ),
      label: Text(
        hasHandRaised ? 'Lower Hand' : 'Raise Hand',
        style: TextStyle(color: theme.colorScheme.onPrimary),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            hasHandRaised ? Colors.red.shade700 : theme.colorScheme.tertiary,
      ),
    );
  }

  Future<void> _grantNextSpeaker(
      BuildContext context, dynamic roomService, String userId) async {
    try {
      await roomService.grantTurnFromQueue(room.id, userId);
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Next speaker in queue has the floor')),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error granting turn: $e')),
      );
    }
  }

  Widget _buildCountdownWidget(ThemeData theme) {
    final minutes = speakerTimeRemaining ~/ 60;
    final seconds = speakerTimeRemaining % 60;
    final isLowTime = speakerTimeRemaining <= 10;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isLowTime ? Colors.red.shade700 : Colors.blue.shade700,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'â±ï¸',
                style:
                    TextStyle(fontSize: 12, color: theme.colorScheme.onPrimary),
              ),
              const SizedBox(width: 4),
              Text(
                '$minutes:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
