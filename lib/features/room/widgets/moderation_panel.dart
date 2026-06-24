import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/models/agora_participant.dart';
import 'package:mixmingle/shared/models/room_role.dart';
import 'package:mixmingle/shared/models/room.dart';
import '../services/moderation_service.dart';

/// Moderation panel for room hosts and co-hosts
/// Allows managing participants: kick, mute, promote, ban
class ModerationPanel extends ConsumerStatefulWidget {
  final Room room;
  final String currentUserId;
  final RoomRole currentUserRole;
  final Map<int, AgoraParticipant> participants;
  final VoidCallback? onClose;

  const ModerationPanel({
    super.key,
    required this.room,
    required this.currentUserId,
    required this.currentUserRole,
    required this.participants,
    this.onClose,
  });

  @override
  ConsumerState<ModerationPanel> createState() => _ModerationPanelState();
}

class _ModerationPanelState extends ConsumerState<ModerationPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  String _searchQuery = '';
  bool _showOnlyMuted = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _closePanel() {
    _slideController.reverse().then((_) {
      widget.onClose?.call();
    });
  }

  List<AgoraParticipant> get _filteredParticipants {
    var participants = widget.participants.values.toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      participants = participants
          .where((p) =>
              p.displayName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Filter by muted status
    if (_showOnlyMuted) {
      participants = participants.where((p) => !p.hasAudio).toList();
    }

    // Sort: host first, then co-hosts, then by join time
    participants.sort((a, b) {
      if (a.userId == widget.room.hostId) return -1;
      if (b.userId == widget.room.hostId) return 1;
      return a.joinedAt.compareTo(b.joinedAt);
    });

    return participants;
  }

  @override
  Widget build(BuildContext context) {
    final canModerate = widget.currentUserRole.canRemoveParticipants;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(context, canModerate),
            _buildSearchBar(),
            if (canModerate) _buildFilterOptions(),
            Expanded(child: _buildParticipantList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool canModerate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Row(
        children: [
          Icon(
            canModerate ? Icons.admin_panel_settings : Icons.people,
            color: canModerate ? Colors.amber : Colors.white70,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canModerate ? 'Moderation Panel' : 'Participants',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${widget.participants.length} ${widget.participants.length == 1 ? 'person' : 'people'}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: _closePanel,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search participants...',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.grey[850],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Show muted only'),
            selected: _showOnlyMuted,
            onSelected: (value) => setState(() => _showOnlyMuted = value),
            backgroundColor: Colors.grey[850],
            selectedColor: Colors.pinkAccent.withValues(alpha: 0.3),
            labelStyle: TextStyle(
              color: _showOnlyMuted ? Colors.white : Colors.grey[400],
              fontSize: 12,
            ),
            side: BorderSide(
              color: _showOnlyMuted ? Colors.pinkAccent : Colors.grey[700]!,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantList() {
    final participants = _filteredParticipants;

    if (participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[700]),
            const SizedBox(height: 12),
            Text(
              'No participants found',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: participants.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final participant = participants[index];
        return _buildParticipantItem(participant);
      },
    );
  }

  Widget _buildParticipantItem(AgoraParticipant participant) {
    final isHost = participant.userId == widget.room.hostId;
    final isCurrentUser = participant.userId == widget.currentUserId;
    final canModerate =
        widget.currentUserRole.canRemoveParticipants && !isCurrentUser;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.pinkAccent.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isHost ? Colors.amber[700] : Colors.grey[800],
              child: Text(
                participant.displayName.isNotEmpty
                    ? participant.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: isHost ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (participant.isSpeaking)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.greenAccent, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                participant.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isHost) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber[700],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HOST',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (isCurrentUser) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.pinkAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Icon(
              participant.hasAudio ? Icons.mic : Icons.mic_off,
              size: 14,
              color: participant.hasAudio ? Colors.green : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Icon(
              participant.hasVideo ? Icons.videocam : Icons.videocam_off,
              size: 14,
              color: participant.hasVideo ? Colors.blue : Colors.grey[600],
            ),
          ],
        ),
        trailing: canModerate ? _buildModerationActions(participant) : null,
      ),
    );
  }

  Widget _buildModerationActions(AgoraParticipant participant) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
      color: Colors.grey[850],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'mute',
          child: Row(
            children: [
              Icon(
                participant.hasAudio ? Icons.mic_off : Icons.mic,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(width: 12),
              Text(
                participant.hasAudio ? 'Mute' : 'Unmute',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'video',
          child: Row(
            children: [
              Icon(
                participant.hasVideo ? Icons.videocam_off : Icons.videocam,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(width: 12),
              Text(
                participant.hasVideo ? 'Stop video' : 'Start video',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        if (widget.currentUserRole == RoomRole.owner)
          PopupMenuItem(
            value: 'promote',
            child: Row(
              children: [
                const Icon(Icons.verified_user, size: 18, color: Colors.amber),
                const SizedBox(width: 12),
                Text(
                  'Promote to Co-Host',
                  style: TextStyle(color: Colors.amber[300]),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'kick',
          child: Row(
            children: [
              Icon(Icons.exit_to_app, size: 18, color: Colors.orange),
              SizedBox(width: 12),
              Text('Kick', style: TextStyle(color: Colors.orange)),
            ],
          ),
        ),
        if (widget.currentUserRole == RoomRole.owner)
          const PopupMenuItem(
            value: 'ban',
            child: Row(
              children: [
                Icon(Icons.block, size: 18, color: Colors.red),
                SizedBox(width: 12),
                Text('Ban', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
      onSelected: (action) => _handleModerationAction(action, participant),
    );
  }

  Future<void> _handleModerationAction(
      String action, AgoraParticipant participant) async {
    final moderationService = ref.read(moderationServiceProvider);

    try {
      switch (action) {
        case 'mute':
          await moderationService.toggleParticipantAudio(
            roomId: widget.room.id,
            participantId: participant.userId,
            mute: participant.hasAudio,
          );
          _showSnackBar(
              '${participant.displayName} ${participant.hasAudio ? 'muted' : 'unmuted'}');
          break;

        case 'video':
          await moderationService.toggleParticipantVideo(
            roomId: widget.room.id,
            participantId: participant.userId,
            disable: participant.hasVideo,
          );
          _showSnackBar(
              '${participant.displayName}\'s video ${participant.hasVideo ? 'stopped' : 'started'}');
          break;

        case 'promote':
          final confirmed = await _showConfirmDialog(
            'Promote ${participant.displayName}?',
            'This will give them moderation powers.',
          );
          if (confirmed) {
            await moderationService.promoteToCoHost(
              roomId: widget.room.id,
              participantId: participant.userId,
            );
            _showSnackBar('${participant.displayName} promoted to Co-Host');
          }
          break;

        case 'kick':
          final confirmed = await _showConfirmDialog(
            'Kick ${participant.displayName}?',
            'They can rejoin the room later.',
          );
          if (confirmed) {
            await moderationService.kickParticipant(
              roomId: widget.room.id,
              participantId: participant.userId,
            );
            _showSnackBar('${participant.displayName} kicked from room');
          }
          break;

        case 'ban':
          final confirmed = await _showConfirmDialog(
            'Ban ${participant.displayName}?',
            'They will not be able to rejoin this room.',
            isDestructive: true,
          );
          if (confirmed) {
            await moderationService.banParticipant(
              roomId: widget.room.id,
              participantId: participant.userId,
            );
            _showSnackBar('${participant.displayName} banned from room');
          }
          break;
      }
    } catch (e) {
      _showSnackBar('Failed to perform action: $e', isError: true);
    }
  }

  Future<bool> _showConfirmDialog(
    String title,
    String message, {
    bool isDestructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(title, style: const TextStyle(color: Colors.white)),
            content: Text(message, style: TextStyle(color: Colors.grey[400])),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    Text('Cancel', style: TextStyle(color: Colors.grey[400])),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  'Confirm',
                  style: TextStyle(
                    color: isDestructive ? Colors.red : Colors.pinkAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.grey[850],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Helper function to show moderation panel
void showModerationPanel(
  BuildContext context, {
  required Room room,
  required String currentUserId,
  required RoomRole currentUserRole,
  required Map<int, AgoraParticipant> participants,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Moderation Panel',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: ModerationPanel(
          room: room,
          currentUserId: currentUserId,
          currentUserRole: currentUserRole,
          participants: participants,
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    },
  );
}
