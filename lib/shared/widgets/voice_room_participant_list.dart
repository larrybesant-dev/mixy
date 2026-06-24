import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/models/room.dart';
import 'package:mixmingle/shared/providers/providers.dart';
import 'package:mixmingle/shared/providers/user_display_name_provider.dart';

class VoiceRoomParticipantList extends ConsumerWidget {
  final Room room;
  final String currentUserId;

  const VoiceRoomParticipantList({
    super.key,
    required this.room,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    final roomService = ref.watch(roomServiceProvider);
    final theme = Theme.of(context);

    return Container(
      width: 300,
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.people, color: theme.colorScheme.onPrimary),
                const SizedBox(width: 8),
                Text(
                  'Participants (${room.participantIds.length})',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Participants List
          Expanded(
            child: ListView(
              children: [
                // Speakers Section
                if (room.speakers.isNotEmpty) ...[
                  _buildSectionHeader(
                      'Speakers', Icons.mic, theme.colorScheme.primary, theme),
                  ...room.speakers.map((userId) => _buildParticipantTile(
                        userId,
                        firestoreService,
                        roomService,
                        isSpeaker: true,
                      )),
                ],

                // Listeners Section
                if (room.listeners.isNotEmpty) ...[
                  _buildSectionHeader('Listeners', Icons.headphones,
                      theme.colorScheme.secondary, theme),
                  ...room.listeners.map((userId) => _buildParticipantTile(
                        userId,
                        firestoreService,
                        roomService,
                        isSpeaker: false,
                      )),
                ],

                // Moderators Section
                if (room.moderators.length > 1) ...[
                  _buildSectionHeader('Moderators', Icons.admin_panel_settings,
                      theme.colorScheme.tertiary, theme),
                  ...room.moderators.where((id) => id != room.hostId).map(
                        (userId) => _buildParticipantTile(
                          userId,
                          firestoreService,
                          roomService,
                          isModerator: true,
                        ),
                      ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, IconData icon, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(
          left: BorderSide(color: color, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(
    String userId,
    dynamic firestoreService,
    dynamic roomService, {
    bool isSpeaker = false,
    bool isModerator = false,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        final userAsync = ref.watch(userProvider(userId));
        final displayNameAsync = ref.watch(userDisplayNameProvider(userId));

        final isCurrentUser = userId == currentUserId;
        final isHost = userId == room.hostId;
        final canModerate = room.moderators.contains(currentUserId) && !isHost;
        final theme = Theme.of(context);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundImage: userAsync.value?.photoUrl != null &&
                        userAsync.value?.photoUrl?.isNotEmpty == true
                    ? NetworkImage(userAsync.value!.photoUrl!)
                    : null,
                child: userAsync.value?.photoUrl == null
                    ? displayNameAsync.when(
                        data: (name) => Text(
                          getDisplayNameInitial(name),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        loading: () => const Text('?'),
                        error: (_, __) => const Text('?'),
                      )
                    : null,
              ),

              const SizedBox(width: 12),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        displayNameAsync.when(
                          data: (name) => Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          loading: () => const Text(
                            'Loading...',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          error: (_, __) => const Text(
                            'Unknown User',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isHost) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Host',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (isModerator && !isHost) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Mod',
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        // Current speaker indicator (turn-based mode)
                        if (room.turnBased &&
                            room.currentSpeakerId == userId) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🎤',
                                  style: TextStyle(fontSize: 10),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Speaking',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Hand raised indicator
                        if (room.turnBased &&
                            room.raisedHands.contains(userId)) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade600,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🖐️',
                                  style: TextStyle(fontSize: 10),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  'Hand',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (userAsync.value?.bio != null &&
                        userAsync.value!.bio.isNotEmpty)
                      Text(
                        userAsync.value!.bio,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Action Buttons
              if (isCurrentUser && !isSpeaker) ...[
                IconButton(
                  icon: Icon(Icons.mic, color: theme.colorScheme.primary),
                  onPressed: () => roomService.requestToSpeak(room.id, userId),
                  tooltip: 'Request to speak',
                ),
              ] else if (isCurrentUser && isSpeaker) ...[
                IconButton(
                  icon: Icon(Icons.mic_off, color: theme.colorScheme.error),
                  onPressed: () => roomService.stopSpeaking(room.id, userId),
                  tooltip: 'Stop speaking',
                ),
              ] else if (canModerate && !isCurrentUser) ...[
                PopupMenuButton<String>(
                  onSelected: (action) => _handleModeratorAction(
                    action,
                    userId,
                    roomService,
                  ),
                  itemBuilder: (context) => [
                    if (!room.moderators.contains(userId))
                      const PopupMenuItem(
                        value: 'make_mod',
                        child: Text('Make Moderator'),
                      ),
                    if (room.moderators.contains(userId) &&
                        userId != room.hostId)
                      const PopupMenuItem(
                        value: 'remove_mod',
                        child: Text('Remove Moderator'),
                      ),
                    const PopupMenuItem(
                      value: 'kick',
                      child: Text('Kick User'),
                    ),
                    const PopupMenuItem(
                      value: 'ban',
                      child: Text('Ban User'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _handleModeratorAction(
    String action,
    String targetUserId,
    dynamic roomService,
  ) async {
    try {
      switch (action) {
        case 'make_mod':
          await roomService.makeModerator(room.id, currentUserId, targetUserId);
          // Note: SnackBar will be shown by parent widget or through a callback
          break;
        case 'remove_mod':
          await roomService.removeModerator(
              room.id, currentUserId, targetUserId);
          break;
        case 'kick':
          await roomService.kickUser(room.id, currentUserId, targetUserId);
          break;
        case 'ban':
          await roomService.banUser(room.id, currentUserId, targetUserId);
          break;
      }
    } catch (e) {
      // Error handling without context - could be handled by parent or through callback
      debugPrint('Moderator action error: $e');
    }
  }
}
