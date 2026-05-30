import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/mic_access_request_model.dart';
import '../../../models/room_participant_model.dart';
import '../../../core/theme.dart';
import '../controllers/live_room_controller.dart';
import '../controllers/room_state.dart';
import '../providers/mic_access_provider.dart';
import '../providers/room_policy_provider.dart';
import '../providers/participant_providers.dart';
import '../../feed/providers/host_controls_providers.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../services/room_audio_cues.dart';
import 'background_picker_sheet.dart';
import '../models/room_theme_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point: show the host control panel as a draggable bottom sheet.
// ─────────────────────────────────────────────────────────────────────────────

class RoomHostControlPanel {
  static Future<void> show(
    BuildContext context, {
    required String roomId,
    required String currentUserId,
    required bool isOwner,
    double micVolume = 1.0,
    double speakerVolume = 1.0,
    ValueChanged<double>? onMicVolumeChanged,
    ValueChanged<double>? onSpeakerVolumeChanged,
    int initialTabIndex = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoomHostControlPanelSheet(
        roomId: roomId,
        currentUserId: currentUserId,
        isOwner: isOwner,
        micVolume: micVolume,
        speakerVolume: speakerVolume,
        onMicVolumeChanged: onMicVolumeChanged,
        onSpeakerVolumeChanged: onSpeakerVolumeChanged,
        initialTabIndex: initialTabIndex,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal sheet widget
// ─────────────────────────────────────────────────────────────────────────────

class _RoomHostControlPanelSheet extends ConsumerStatefulWidget {
  const _RoomHostControlPanelSheet({
    required this.roomId,
    required this.currentUserId,
    required this.isOwner,
    required this.micVolume,
    required this.speakerVolume,
    this.onMicVolumeChanged,
    this.onSpeakerVolumeChanged,
    this.initialTabIndex = 0,
  });

  final String roomId;
  final String currentUserId;
  final bool isOwner;
  final double micVolume;
  final double speakerVolume;
  final ValueChanged<double>? onMicVolumeChanged;
  final ValueChanged<double>? onSpeakerVolumeChanged;
  final int initialTabIndex;

  @override
  ConsumerState<_RoomHostControlPanelSheet> createState() =>
      _RoomHostControlPanelSheetState();
}

class _RoomHostControlPanelSheetState
    extends ConsumerState<_RoomHostControlPanelSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late double _micVolume;
  late double _speakerVolume;
  @override
  void initState() {
    super.initState();
    _micVolume = widget.micVolume;
    _speakerVolume = widget.speakerVolume;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(liveRoomControllerProvider(widget.roomId).notifier)
          .hydrateCurrentUser(
            widget.currentUserId,
            role: widget.isOwner ? 'host' : null,
          );
    });
    // Owners get all 6 tabs; mods/cohosts skip the Moderators tab (5 tabs).
    final tabCount = widget.isOwner ? 6 : 5;
    _tabs = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, tabCount - 1),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Drag handle ────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.settings_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text('Room Control Panel', style: tt.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // ── Tab bar ────────────────────────────────────────────────────
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  const Tab(icon: Icon(Icons.tune, size: 18), text: 'Room'),
                  const Tab(icon: Icon(Icons.mic, size: 18), text: 'Stage'),
                  const Tab(
                    icon: Icon(Icons.volume_up, size: 18),
                    text: 'Audio',
                  ),
                  const Tab(icon: Icon(Icons.people, size: 18), text: 'People'),
                  const Tab(
                    icon: Icon(Icons.palette_rounded, size: 18),
                    text: 'Theme',
                  ),
                  if (widget.isOwner)
                    const Tab(
                      icon: Icon(Icons.admin_panel_settings, size: 18),
                      text: 'Mods',
                    ),
                ],
              ),
              const Divider(height: 1),
              // ── Tab views ──────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _RoomSettingsTab(
                      roomId: widget.roomId,
                      isOwner: widget.isOwner,
                      scrollController: scrollController,
                    ),
                    _StageControlsTab(
                      roomId: widget.roomId,
                      currentUserId: widget.currentUserId,
                      isOwner: widget.isOwner,
                      scrollController: scrollController,
                    ),
                    _AudioControlsTab(
                      micVolume: _micVolume,
                      speakerVolume: _speakerVolume,
                      onMicChanged: (v) {
                        setState(() => _micVolume = v);
                        widget.onMicVolumeChanged?.call(v);
                      },
                      onSpeakerChanged: (v) {
                        setState(() => _speakerVolume = v);
                        widget.onSpeakerVolumeChanged?.call(v);
                      },
                      scrollController: scrollController,
                    ),
                    _PeopleTab(
                      roomId: widget.roomId,
                      currentUserId: widget.currentUserId,
                      scrollController: scrollController,
                    ),
                    _ThemeTab(
                      roomId: widget.roomId,
                      scrollController: scrollController,
                    ),
                    if (widget.isOwner)
                      _ModeratorsTab(
                        roomId: widget.roomId,
                        currentUserId: widget.currentUserId,
                        scrollController: scrollController,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Room Settings
// ─────────────────────────────────────────────────────────────────────────────

class _RoomSettingsTab extends ConsumerWidget {
  const _RoomSettingsTab({
    required this.roomId,
    required this.scrollController,
    this.isOwner = false,
  });

  final String roomId;
  final ScrollController scrollController;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomController = ref.read(
      liveRoomControllerProvider(roomId).notifier,
    );
    final roomPolicyAsync = ref.watch(roomPolicyProvider(roomId));
    final roomAsync = ref.watch(feedRoomStreamProvider(roomId));
    final isLocked = roomAsync.valueOrNull?.isLocked ?? false;
    final currentName = roomAsync.valueOrNull?.name ?? '';
    final currentDescription = roomAsync.valueOrNull?.description ?? '';
    final currentCategory = roomAsync.valueOrNull?.category ?? '';
    final allowChat = roomPolicyAsync.valueOrNull?.allowChat ?? true;
    final allowGifts = roomPolicyAsync.valueOrNull?.allowGifts ?? true;
    final allowMicRequests =
        roomPolicyAsync.valueOrNull?.allowMicRequests ?? true;
    final allowCamRequests =
        roomPolicyAsync.valueOrNull?.allowCamRequests ?? true;

    // Slow mode comes from the room doc.
    final slowMode = roomAsync.valueOrNull?.slowModeSeconds ?? 0;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // ── Owner-only: Edit room info ────────────────────────────────────
        if (isOwner) ...[
          _SectionHeader('Room Info'),
          _ControlTile(
            title: 'Edit name, description & category',
            subtitle: currentName.isNotEmpty ? currentName : 'Tap to edit',
            icon: Icons.edit_rounded,
            trailing: const Icon(Icons.chevron_right, size: 20),
          ),
          // Inline tappable area on the tile triggers the edit dialog.
          Builder(
            builder: (ctx) {
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showEditRoomInfoDialog(
                  ctx,
                  roomId: roomId,
                  currentName: currentName,
                  currentDescription: currentDescription,
                  currentCategory: currentCategory,
                  onSave:
                      ({String? name, String? description, String? category}) {
                        return roomController.setRoomInfo(
                          name: name,
                          description: description,
                          category: category,
                        );
                      },
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: Color(0xFFD4A853),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Open room info editor',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
        _SectionHeader('Chat & Interaction'),
        _ControlTile(
          title: 'Lock room',
          subtitle: isLocked ? 'New listeners blocked' : 'Room is open',
          icon: isLocked ? Icons.lock : Icons.lock_open,
          trailing: Switch.adaptive(
            value: isLocked,
            onChanged: (_) => roomController.toggleLockRoom(),
          ),
        ),
        _ControlTile(
          title: 'Allow chat',
          subtitle: allowChat ? 'Chat is enabled' : 'Chat is paused',
          icon: Icons.chat_bubble_outline,
          trailing: Switch.adaptive(
            value: allowChat,
            onChanged: (_) => roomController.toggleAllowChat(),
          ),
        ),
        _ControlTile(
          title: 'Allow gifts',
          subtitle: allowGifts ? 'Gifts enabled' : 'Gifts paused',
          icon: Icons.card_giftcard,
          trailing: Switch.adaptive(
            value: allowGifts,
            onChanged: (_) => roomController.toggleAllowGifts(),
          ),
        ),
        _ControlTile(
          title: 'Mic requests',
          subtitle: allowMicRequests
              ? 'Users can request stage'
              : 'Requests paused',
          icon: Icons.mic_none,
          trailing: Switch.adaptive(
            value: allowMicRequests,
            onChanged: (_) => roomController.toggleAllowMicRequests(),
          ),
        ),
        _ControlTile(
          title: 'Cam requests',
          subtitle: allowCamRequests
              ? 'Users can request camera'
              : 'Cam requests paused',
          icon: Icons.videocam_outlined,
          trailing: Switch.adaptive(
            value: allowCamRequests,
            onChanged: (_) => roomController.toggleAllowCamRequests(),
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader('Slow Mode'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: DropdownButtonFormField<int>(
            initialValue: [0, 5, 10, 30, 60].contains(slowMode) ? slowMode : 0,
            decoration: const InputDecoration(
              labelText: 'Slow mode delay',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 0, child: Text('Off')),
              DropdownMenuItem(value: 5, child: Text('5 seconds')),
              DropdownMenuItem(value: 10, child: Text('10 seconds')),
              DropdownMenuItem(value: 30, child: Text('30 seconds')),
              DropdownMenuItem(value: 60, child: Text('60 seconds')),
            ],
            onChanged: (val) {
              if (val != null) roomController.toggleSlowMode(val);
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Stage Controls (mic seats, cam seats, mic queue)
// ─────────────────────────────────────────────────────────────────────────────

class _StageControlsTab extends ConsumerStatefulWidget {
  const _StageControlsTab({
    required this.roomId,
    required this.currentUserId,
    required this.isOwner,
    required this.scrollController,
  });

  final String roomId;
  final String currentUserId;
  final bool isOwner;
  final ScrollController scrollController;

  @override
  ConsumerState<_StageControlsTab> createState() => _StageControlsTabState();
}

class _StageControlsTabState extends ConsumerState<_StageControlsTab> {
  int _lastPendingCount = 0;
  // ignore: prefer_final_fields

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(liveRoomControllerProvider(widget.roomId).notifier)
          .hydrateCurrentUser(
            widget.currentUserId,
            role: widget.isOwner ? 'host' : null,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomController = ref.read(
      liveRoomControllerProvider(widget.roomId).notifier,
    );
    final roomPolicyAsync = ref.watch(roomPolicyProvider(widget.roomId));
    final micRequestsAsync = ref.watch(
      roomMicAccessRequestsProvider(widget.roomId),
    );

    final micLimit = roomPolicyAsync.valueOrNull?.micLimit ?? 4;
    final camLimit = roomPolicyAsync.valueOrNull?.camLimit ?? 6;
    final micTimerSeconds = roomPolicyAsync.valueOrNull?.micTimerSeconds;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader('Mic Seats on Stage'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.mic, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '$micLimit ${micLimit == 1 ? 'person' : 'people'} on mic at once',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              Slider.adaptive(
                value: micLimit.toDouble(),
                min: 1,
                max: 4,
                divisions: 3,
                label: '$micLimit',
                onChanged: (v) {
                  final val = v.round();
                  roomController.hydrateCurrentUser(
                    widget.currentUserId,
                    role: widget.isOwner ? 'host' : null,
                  );
                  roomController.setMaxBroadcasters(val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _SectionHeader('Mic Play Time'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    micTimerSeconds == null
                        ? 'Unlimited mic time'
                        : '${micTimerSeconds}s per turn',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<int?>(
                segments: const [
                  ButtonSegment(value: 30, label: Text('30s')),
                  ButtonSegment(value: 60, label: Text('60s')),
                  ButtonSegment(value: null, label: Text('Unlimited')),
                ],
                selected: {micTimerSeconds},
                onSelectionChanged: (selection) {
                  roomController.hydrateCurrentUser(
                    widget.currentUserId,
                    role: widget.isOwner ? 'host' : null,
                  );
                  roomController.setMicTimer(selection.first);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _SectionHeader('Camera Seats'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.videocam, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '$camLimit camera ${camLimit == 1 ? 'slot' : 'slots'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              Slider.adaptive(
                value: camLimit.toDouble(),
                min: 1,
                max: 12,
                divisions: 11,
                label: '$camLimit',
                onChanged: (v) {
                  roomController.hydrateCurrentUser(
                    widget.currentUserId,
                    role: widget.isOwner ? 'host' : null,
                  );
                  roomController.setCamLimit(v.round());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader('Mic Request Queue'),
        micRequestsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator.adaptive(),
            ),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (requests) {
            final pending = requests
                .where((r) => r.status == 'pending')
                .toList(growable: false);

            if (pending.length > _lastPendingCount) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                RoomAudioCues.instance.playHandRaised();
              });
            }
            _lastPendingCount = pending.length;

            if (pending.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No pending mic requests.',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            return Column(
              children: pending
                  .map(
                    (req) =>
                        _MicRequestCard(request: req, roomId: widget.roomId),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _MicRequestCard extends ConsumerWidget {
  const _MicRequestCard({required this.request, required this.roomId});

  final MicAccessRequestModel request;
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomController = ref.read(
      liveRoomControllerProvider(roomId).notifier,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(request.requesterId),
        subtitle: Text('Priority ${request.priority}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Approve',
              icon: const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
              ),
              onPressed: () => roomController.approveMicRequest(request),
            ),
            IconButton(
              tooltip: 'Deny',
              icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
              onPressed: () => roomController.denyMicRequest(request.id),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Audio Controls (mic volume + speaker volume)
// ─────────────────────────────────────────────────────────────────────────────

class _AudioControlsTab extends StatelessWidget {
  const _AudioControlsTab({
    required this.micVolume,
    required this.speakerVolume,
    required this.onMicChanged,
    required this.onSpeakerChanged,
    required this.scrollController,
  });

  final double micVolume;
  final double speakerVolume;
  final ValueChanged<double> onMicChanged;
  final ValueChanged<double> onSpeakerChanged;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader('My Microphone Volume'),
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'Controls how loud your mic input is sent to the room.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        _VolumeSliderRow(
          icon: Icons.mic,
          label: '${(micVolume * 100).round()}%',
          value: micVolume,
          min: 0.0,
          max: 2.0,
          divisions: 40,
          activeColor: const Color(0xFF7C5FFF),
          onChanged: onMicChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('0%', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text(
              '100% (default)',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text('200%', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 24),
        _SectionHeader('Speaker Volume'),
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'Controls the playback volume of other participants in the room.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        _VolumeSliderRow(
          icon: Icons.volume_up,
          label: '${(speakerVolume * 100).round()}%',
          value: speakerVolume,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          activeColor: VelvetNoir.primary,
          onChanged: onSpeakerChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Mute', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text(
              '100% (default)',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _VolumeSliderRow extends StatelessWidget {
  const _VolumeSliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.activeColor,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(activeTrackColor: activeColor),
            child: Slider.adaptive(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: label,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            label,
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4 — People (participant management)
// ─────────────────────────────────────────────────────────────────────────────

class _PeopleTab extends ConsumerWidget {
  const _PeopleTab({
    required this.roomId,
    required this.currentUserId,
    required this.scrollController,
  });

  final String roomId;
  final String currentUserId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(participantsStreamProvider(roomId));

    return participantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (participants) {
        final sorted = List<RoomParticipantModel>.from(participants)
          ..sort((a, b) {
            const order = ['host', 'cohost', 'moderator', 'audience'];
            final ai = order.indexOf(a.role).let((i) => i < 0 ? 99 : i);
            final bi = order.indexOf(b.role).let((i) => i < 0 ? 99 : i);
            return ai.compareTo(bi);
          });

        if (sorted.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No participants yet.'),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: sorted.length,
          itemBuilder: (context, i) => _ParticipantTile(
            participant: sorted[i],
            roomId: roomId,
            currentUserId: currentUserId,
          ),
        );
      },
    );
  }
}

class _ParticipantTile extends ConsumerWidget {
  const _ParticipantTile({
    required this.participant,
    required this.roomId,
    required this.currentUserId,
  });

  final RoomParticipantModel participant;
  final String roomId;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomController = ref.read(
      liveRoomControllerProvider(roomId).notifier,
    );
    final isSelf = participant.userId == currentUserId;
    final displayName = resolvePublicUsername(uid: participant.userId);

    final roleColor = switch (participant.role) {
      'host' => const Color(0xFFFFD700),
      'cohost' => const Color(0xFF7C5FFF),
      'moderator' => VelvetNoir.secondary,
      _ => Colors.grey,
    };

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: roleColor.withValues(alpha: 0.3),
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(displayName, overflow: TextOverflow.ellipsis)),
          if (isSelf)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'you',
                style: TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ),
        ],
      ),
      subtitle: Text(
        participant.role.toUpperCase() +
            (participant.isMuted ? ' · MUTED' : '') +
            (participant.isBanned ? ' · BANNED' : ''),
        style: TextStyle(fontSize: 11, color: roleColor),
      ),
      trailing: isSelf
          ? null
          : PopupMenuButton<_ParticipantAction>(
              icon: const Icon(Icons.more_vert, size: 20),
              itemBuilder: (_) => [
                if (participant.isMuted)
                  const PopupMenuItem(
                    value: _ParticipantAction.unmute,
                    child: ListTile(
                      leading: Icon(Icons.volume_up_outlined),
                      title: Text('Unmute chat'),
                      dense: true,
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: _ParticipantAction.mute,
                    child: ListTile(
                      leading: Icon(Icons.volume_off_outlined),
                      title: Text('Mute chat'),
                      dense: true,
                    ),
                  ),
                if (normalizeRoomRole(participant.role) != roomRoleModerator)
                  const PopupMenuItem(
                    value: _ParticipantAction.promote,
                    child: ListTile(
                      leading: Icon(Icons.shield_outlined),
                      title: Text('Make moderator'),
                      dense: true,
                    ),
                  ),
                if ({
                  roomRoleModerator,
                  roomRoleCohost,
                }.contains(normalizeRoomRole(participant.role)))
                  const PopupMenuItem(
                    value: _ParticipantAction.demote,
                    child: ListTile(
                      leading: Icon(Icons.person_outline),
                      title: Text('Demote to audience'),
                      dense: true,
                    ),
                  ),
                if (!isHostLikeRole(participant.role))
                  const PopupMenuItem(
                    value: _ParticipantAction.kick,
                    child: ListTile(
                      leading: Icon(
                        Icons.exit_to_app,
                        color: Colors.orangeAccent,
                      ),
                      title: Text(
                        'Kick from room',
                        style: TextStyle(color: Colors.orangeAccent),
                      ),
                      dense: true,
                    ),
                  ),
                if (!participant.isBanned)
                  const PopupMenuItem(
                    value: _ParticipantAction.ban,
                    child: ListTile(
                      leading: Icon(Icons.block, color: Colors.redAccent),
                      title: Text(
                        'Ban',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      dense: true,
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: _ParticipantAction.unban,
                    child: ListTile(
                      leading: Icon(Icons.undo, color: Colors.greenAccent),
                      title: Text(
                        'Unban',
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                      dense: true,
                    ),
                  ),
              ],
              onSelected: (action) async {
                switch (action) {
                  case _ParticipantAction.mute:
                    await roomController.muteUser(participant.userId);
                  case _ParticipantAction.unmute:
                    await roomController.unmuteUser(participant.userId);
                  case _ParticipantAction.promote:
                    await roomController.promoteToModerator(participant.userId);
                  case _ParticipantAction.demote:
                    await roomController.demoteToAudience(participant.userId);
                  case _ParticipantAction.kick:
                    await roomController.removeUser(participant.userId);
                  case _ParticipantAction.ban:
                    await roomController.banUser(participant.userId);
                  case _ParticipantAction.unban:
                    await roomController.unbanUser(participant.userId);
                }
              },
            ),
    );
  }
}

enum _ParticipantAction { mute, unmute, promote, demote, kick, ban, unban }

// ─────────────────────────────────────────────────────────────────────────────
// Tab 5 — Moderators (owner-only: promote/demote mods, transfer host)
// ─────────────────────────────────────────────────────────────────────────────

class _ModeratorsTab extends ConsumerWidget {
  const _ModeratorsTab({
    required this.roomId,
    required this.currentUserId,
    required this.scrollController,
  });

  final String roomId;
  final String currentUserId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participantsAsync = ref.watch(participantsStreamProvider(roomId));
    final roomController = ref.read(
      liveRoomControllerProvider(roomId).notifier,
    );

    return participantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (participants) {
        final mods = participants.where((p) {
          final role = normalizeRoomRole(p.role, fallbackRole: '');
          return role == roomRoleModerator || role == roomRoleCohost;
        }).toList();
        final eligible = participants
            .where(
              (p) =>
                  normalizeRoomRole(p.role, fallbackRole: roomRoleAudience) ==
                      roomRoleAudience &&
                  !p.isBanned &&
                  p.userId != currentUserId,
            )
            .toList();

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            _SectionHeader('Current Moderators & Co-Hosts'),
            if (mods.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No moderators assigned yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...mods.map((p) {
                final displayName = resolvePublicUsername(uid: p.userId);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          normalizeRoomRole(p.role, fallbackRole: '') ==
                              roomRoleCohost
                          ? const Color(0x337C5FFF)
                          : const Color(0x3300D4AA),
                      child: Icon(
                        normalizeRoomRole(p.role, fallbackRole: '') ==
                                roomRoleCohost
                            ? Icons.supervisor_account
                            : Icons.shield,
                        size: 18,
                        color:
                            normalizeRoomRole(p.role, fallbackRole: '') ==
                                roomRoleCohost
                            ? const Color(0xFF7C5FFF)
                            : VelvetNoir.secondary,
                      ),
                    ),
                    title: Text(displayName),
                    subtitle: Text(
                      p.role.toUpperCase(),
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Transfer host button (only for cohosts)
                        if (normalizeRoomRole(p.role, fallbackRole: '') ==
                            roomRoleCohost)
                          IconButton(
                            tooltip: 'Transfer host',
                            icon: const Icon(
                              Icons.swap_horiz,
                              color: Colors.orangeAccent,
                            ),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Transfer host?'),
                                  content: Text(
                                    'Make $displayName the new room host? You will become co-host.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Transfer'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await roomController.transferHost(
                                  targetUserId: p.userId,
                                );
                              }
                            },
                          ),
                        // Remove mod role
                        IconButton(
                          tooltip: 'Demote to audience',
                          icon: const Icon(
                            Icons.person_remove_outlined,
                            color: Colors.redAccent,
                          ),
                          onPressed: () =>
                              roomController.demoteToAudience(p.userId),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            _SectionHeader('Add Moderator'),
            if (eligible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No eligible audience members to promote.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...eligible.map((p) {
                final displayName = resolvePublicUsername(uid: p.userId);
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Text(displayName),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.shield_outlined, size: 16),
                        label: const Text('Mod'),
                        onPressed: () =>
                            roomController.promoteToModerator(p.userId),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.supervisor_account_outlined,
                          size: 16,
                        ),
                        label: const Text('Co-host'),
                        onPressed: () =>
                            roomController.promoteToCohost(p.userId),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 32),
            // ── Danger Zone: End Room ──────────────────────────────────────
            _SectionHeader('Danger Zone'),
            Card(
              color: const Color(0xFF2A0F0F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0x60FF6E84)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.stop_circle_outlined,
                      color: Color(0xFFFF6E84),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Room',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF6E84),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Closes the room for all participants. This cannot be undone.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF6E84),
                        side: const BorderSide(color: Color(0xFFFF6E84)),
                      ),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('End Room?'),
                            content: const Text(
                              'This will close the room for everyone. Are you sure?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6E84),
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('End Room'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await roomController.endRoom();
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      child: const Text('End'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ControlTile extends StatelessWidget {
  const _ControlTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, size: 22),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing,
    );
  }
}

// Dart 3 extension for let-style chaining used in sort.
extension _LetExt<T> on T {
  R let<R>(R Function(T it) block) => block(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 6 — Room Theme (host & co-host only)
// Shows current theme state and opens BackgroundPickerSheet.
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeTab extends ConsumerWidget {
  const _ThemeTab({required this.roomId, required this.scrollController});

  final String roomId;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(feedRoomStreamProvider(roomId));
    final roomController = ref.read(
      liveRoomControllerProvider(roomId).notifier,
    );
    final currentTheme = roomAsync.valueOrNull?.theme;
    final preset = currentTheme?.vibePreset;
    final hasCustomBg = currentTheme?.hasBackground ?? false;

    String presetLabel() {
      if (preset == null) return 'Default';
      return switch (preset.name) {
        'club' => 'Club',
        'lounge' => 'Lounge',
        'neon' => 'Neon',
        'hype' => 'Hype',
        'space' => 'Space',
        'ocean' => 'Ocean',
        _ => 'Default',
      };
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _SectionHeader('Current Theme'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.palette_rounded,
                  color: Color(0xFFD4A853),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasCustomBg
                            ? 'Custom image'
                            : 'Preset: ${presetLabel()}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (hasCustomBg)
                        Text(
                          currentTheme!.backgroundUrl!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        )
                      else
                        const Text(
                          'Tap Change to pick a background',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader('Actions'),
        _ControlTile(
          title: 'Change background',
          subtitle: 'Pick a preset or paste a custom image URL',
          icon: Icons.image_rounded,
          trailing: const Icon(Icons.chevron_right, size: 20),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => BackgroundPickerSheet.show(
            context,
            current: currentTheme ?? RoomTheme.defaultTheme,
            onSelect: (theme) {
              roomController.updateRoomTheme(theme).catchError((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not update theme.')),
                  );
                }
              });
            },
            onReset: () {
              roomController.resetRoomTheme().catchError((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not reset theme.')),
                  );
                }
              });
            },
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 4),
                const Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: Color(0xFFD4A853),
                ),
                const SizedBox(width: 6),
                Text(
                  'Open theme picker',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (currentTheme != null && !currentTheme.isDefault) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              roomController.resetRoomTheme().catchError((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not reset theme.')),
                  );
                }
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset to Default Theme'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              side: const BorderSide(color: Color(0xFF3A3D4A)),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Owner-only: Edit room info dialog
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _showEditRoomInfoDialog(
  BuildContext context, {
  required Future<void> Function({
    String? name,
    String? description,
    String? category,
  })
  onSave,
  required String roomId,
  required String currentName,
  required String currentDescription,
  required String currentCategory,
}) async {
  final nameCtrl = TextEditingController(text: currentName);
  final descCtrl = TextEditingController(text: currentDescription);
  final catCtrl = TextEditingController(text: currentCategory);
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit_rounded, size: 20),
          SizedBox(width: 8),
          Text('Edit Room Info'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Room name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.room_preferences_outlined),
                ),
                maxLength: 60,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (ticker)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_rounded),
                  helperText: 'Shown as a scrolling banner at the top',
                ),
                maxLength: 120,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: catCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category / topic',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
                maxLength: 40,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.save_rounded, size: 16),
          label: const Text('Save'),
          onPressed: () async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(ctx);
            try {
              await onSave(
                name: nameCtrl.text,
                description: descCtrl.text,
                category: catCtrl.text,
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
              }
            }
          },
        ),
      ],
    ),
  );
  nameCtrl.dispose();
  descCtrl.dispose();
  catCtrl.dispose();
}



