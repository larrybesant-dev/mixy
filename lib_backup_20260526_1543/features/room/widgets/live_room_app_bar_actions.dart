import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../widgets/coin_balance_widget.dart';
import '../../../widgets/friends_panel_button.dart';
import 'live_room_media_action_strip.dart';

class LiveRoomAppBarActions extends StatelessWidget {
  const LiveRoomAppBarActions({
    super.key,
    required this.isCallReady,
    required this.isMicMuted,
    required this.isVideoEnabled,
    required this.isSharingSystemAudio,
    required this.isMicActionInFlight,
    required this.isVideoActionInFlight,
    required this.isSystemAudioActionInFlight,
    required this.localAudioLevel,
    required this.showVolumeControls,
    required this.hasParticipants,
    required this.pendingMicCount,
    required this.isOnMic,
    required this.isMicFree,
    this.hasPendingMicRequest = false,
    required this.onToggleMic,
    required this.onToggleVideo,
    required this.onLongPressVideo,
    required this.onToggleSystemAudio,
    this.onGrabMicAction,
    required this.onToggleVolumeControls,
    required this.onGoHome,
    required this.onOpenPeople,
    required this.onLeaveRoom,
    required this.onInviteFriends,
    required this.onShowOnlineFriends,
    required this.onShareRoom,
    required this.onReportRoom,
    required this.onReportIssue,
    required this.onEditProfile,
    this.coinBalance,
  });

  final bool isCallReady;
  final bool isMicMuted;
  final bool isVideoEnabled;
  final bool isSharingSystemAudio;
  final bool isMicActionInFlight;
  final bool isVideoActionInFlight;
  final bool isSystemAudioActionInFlight;
  final double localAudioLevel;
  final bool showVolumeControls;
  final bool hasParticipants;
  final int pendingMicCount;
  final bool isOnMic;
  final bool isMicFree;
  final bool hasPendingMicRequest;
  final VoidCallback? onToggleMic;
  final Future<void> Function() onToggleVideo;
  final VoidCallback? onLongPressVideo;
  final VoidCallback? onToggleSystemAudio;
  final VoidCallback? onGrabMicAction;
  final VoidCallback onToggleVolumeControls;
  final Future<void> Function() onGoHome;
  final VoidCallback? onOpenPeople;
  final Future<void> Function() onLeaveRoom;
  final VoidCallback onInviteFriends;
  final VoidCallback onShowOnlineFriends;
  final VoidCallback onShareRoom;
  final VoidCallback onReportRoom;
  final VoidCallback onReportIssue;
  final VoidCallback onEditProfile;
  final int? coinBalance;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 640;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiveRoomMediaActionStrip(
          isCallReady: isCallReady,
          isMicMuted: isMicMuted,
          isVideoEnabled: isVideoEnabled,
          isSharingSystemAudio: isSharingSystemAudio,
          isMicActionInFlight: isMicActionInFlight,
          isVideoActionInFlight: isVideoActionInFlight,
          isSystemAudioActionInFlight: isSystemAudioActionInFlight,
          localAudioLevel: localAudioLevel,
          onToggleMic: onToggleMic,
          onToggleVideo: onToggleVideo,
          onLongPressVideo: onLongPressVideo,
          showSystemAudioButton: kIsWeb,
          showGrabMicButton: true,
          isOnMic: isOnMic,
          isMicFree: isMicFree,
          hasPendingMicRequest: hasPendingMicRequest,
          onGrabMicAction: onGrabMicAction,
          onToggleSystemAudio: onToggleSystemAudio,
        ),
        if (!isCompact)
          IconButton(
            tooltip: 'Volume controls',
            icon: Icon(
              showVolumeControls ? Icons.volume_up : Icons.volume_up_outlined,
              color: showVolumeControls ? VelvetNoir.primary : Colors.white70,
            ),
            onPressed: onToggleVolumeControls,
          ),
        if (!isCompact)
          IconButton(
            tooltip: 'Go to Home',
            icon: const Icon(Icons.home_rounded),
            onPressed: onGoHome,
          ),
        if (!isCompact) const FriendsPanelButton(iconColor: Colors.white),
        if (!isCompact && coinBalance != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(child: CoinBalanceWidget(balance: coinBalance!)),
          ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: 'People in room',
              onPressed: hasParticipants ? onOpenPeople : null,
              icon: const Icon(Icons.people_alt_outlined),
            ),
            if (pendingMicCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4A853),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$pendingMicCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          tooltip: 'Leave Room',
          onPressed: onLeaveRoom,
          icon: const Icon(Icons.logout),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'home':
                onGoHome();
              case 'invite':
                onInviteFriends();
              case 'online_friends':
                onShowOnlineFriends();
              case 'edit_profile':
                onEditProfile();
              case 'share':
                onShareRoom();
              case 'report_room':
                onReportRoom();
              case 'report_issue':
                onReportIssue();
              case 'coins':
                break;
            }
          },
          itemBuilder: (context) => [
            if (isCompact)
              const PopupMenuItem<String>(
                value: 'home',
                child: ListTile(
                  leading: Icon(Icons.home_rounded),
                  title: Text('Go home'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            if (isCompact && coinBalance != null)
              PopupMenuItem<String>(
                enabled: false,
                value: 'coins',
                child: ListTile(
                  leading: const Icon(Icons.monetization_on_outlined),
                  title: Text('Coins: $coinBalance'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            PopupMenuItem<String>(
              value: 'invite',
              child: ListTile(
                leading: Icon(Icons.group_add_outlined),
                title: Text('Invite friends'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            PopupMenuItem<String>(
              value: 'online_friends',
              child: ListTile(
                leading: Icon(Icons.people_outline),
                title: Text('Online friends'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            PopupMenuItem<String>(
              value: 'edit_profile',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit profile'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            PopupMenuItem<String>(
              value: 'share',
              child: ListTile(
                leading: Icon(Icons.share_outlined),
                title: Text('Share room'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            PopupMenuItem<String>(
              value: 'report_room',
              child: ListTile(
                leading: Icon(Icons.flag_outlined),
                title: Text('Report room'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            PopupMenuItem<String>(
              value: 'report_issue',
              child: ListTile(
                leading: Icon(Icons.bug_report_outlined),
                title: Text('Report issue'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
