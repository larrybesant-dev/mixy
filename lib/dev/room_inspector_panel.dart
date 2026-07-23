import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_debug_flags.dart';
import 'app_state_reasoning.dart';
import '../features/room/controllers/live_room_controller.dart';
import '../features/room/providers/room_live_state_provider.dart';
import '../features/room/controllers/room_state.dart';
import '../features/room/providers/participant_providers.dart';
import '../features/room/providers/room_policy_provider.dart';

/// Debug-only live inspector for a running room.
///
/// Shows room lifecycle state, participants+roles, mic seats, policy flags,
/// and the last 20 mod_log entries — all reactive via Riverpod streams.
///
/// Only renders in [kDebugMode]. In release builds the widget tree is empty.
class RoomInspectorPanel extends ConsumerWidget {
  const RoomInspectorPanel({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kEnableVisibilityDiagnostics) return const SizedBox.shrink();

    final roomState = ref.watch(liveRoomControllerProvider(roomId));
    final participantsAsync = ref.watch(participantsStreamProvider(roomId));
    final policyAsync = ref.watch(roomPolicyProvider(roomId));
    final modLogAsync = ref.watch(modLogStreamProvider(roomId));
    final liveStateAsync = ref.watch(roomLiveStateProvider(roomId));
    final roomSummary = explainLiveRoomHydration(
      lifecycleLabel: roomState.lifecycleState.name,
      userCount: roomState.userIds.length,
      pendingCount: roomState.pendingUserIds.length,
      errormessage: roomState.errormessage,
    );

    return Material(
      color: Colors.black.withValues(alpha: 0.88),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFFE0E0E0),
          fontSize: 11,
          fontFamily: 'monospace',
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            StateReasonCard(
              title: 'WHY THIS ROOM LOOKS THIS WAY',
              summary: roomSummary,
              metrics: [
                'state: ${roomSummary.stateLabel}',
                'users: ${roomState.userIds.length}',
                'pending: ${roomState.pendingUserIds.length}',
              ],
            ),
            const SizedBox(height: 8),
            _SectionHeader(
              label: 'ROOM STATE',
              color: _lifecycleColor(roomState.lifecycleState),
            ),
            _KV('lifecycle', roomState.lifecycleState.name),
            _KV('phase', roomState.phase.name),
            _KV('audio', roomState.audioState.name),
            _KV('hostId', roomState.hostId.isEmpty ? '—' : roomState.hostId),
            _KV(
              'currentUser',
              roomState.currentUserId?.isEmpty == false
                  ? roomState.currentUserId!
                  : '—',
            ),
            _KV('users', '${roomState.userIds.length}'),
            _KV('speakers', '${roomState.speakerIds.length}'),
            _KV('pending', '${roomState.pendingUserIds.length}'),
            if (roomState.errormessage?.isNotEmpty == true)
              _KV(
                'ERROR',
                roomState.errormessage!,
                valueColor: Colors.redAccent,
              ),
            const SizedBox(height: 8),

            // ── Pipeline / Contract (collapsed by default — detail view) ─────
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                iconColor: const Color(0xFFCE93D8),
                collapsedIconColor: const Color(0xFF78909C),
                title: const Text(
                  'PIPELINE',
                  style: TextStyle(
                    color: Color(0xFFCE93D8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                children: [
                  liveStateAsync.when(
                    data: (s) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _KV('title', s.title.isEmpty ? '(empty)' : s.title),
                        _KV('message', '${s.message.length}'),
                        _KV('participants', '${s.speakers.length + s.audience.length}'),
                        _KV('typing', '${s.typingUsers.length}'),
                        _KV('schema', 'v$kRoomSchemaVersion'),
                      ],
                    ),
                    loading: () => const _Pill('loading…'),
                    error: (e, _) =>
                        _Pill('pipeline error: $e', color: Colors.redAccent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ── Last Diff ────────────────────────────────────────────────────
            const _SectionHeader(label: 'LAST DIFF', color: Color(0xFFCE93D8)),
            Builder(
              builder: (context) {
                final diff = RoomContractGuard.lastDiff;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _KV(
                      'summary',
                      diff.summary,
                      valueColor: diff.hasChanges
                          ? const Color(0xFFCE93D8)
                          : null,
                    ),
                    _KV(
                      'msg\u0394',
                      _deltaStr(diff.messageCountDelta),
                      valueColor: _deltaColor(diff.messageCountDelta),
                    ),
                    _KV(
                      'part\u0394',
                      _deltaStr(diff.participantCountDelta),
                      valueColor: _deltaColor(diff.participantCountDelta),
                    ),
                    _KV(
                      'typ\u0394',
                      _deltaStr(diff.typingCountDelta),
                      valueColor: _deltaColor(diff.typingCountDelta),
                    ),
                    if (diff.titleChanged)
                      const _Pill('title changed', color: Color(0xFFCE93D8)),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),

            // ── Policy ──────────────────────────────────────────────────────
            const _SectionHeader(label: 'POLICY', color: Color(0xFF90CAF9)),
            policyAsync.when(
              data: (policy) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KV('allowChat', '${policy.allowChat}'),
                  _KV('allowGifts', '${policy.allowGifts}'),
                  _KV('allowMicReq', '${policy.allowMicRequests}'),
                  _KV('allowCamReq', '${policy.allowCamRequests}'),
                  _KV('micLimit', '${policy.micLimit}'),
                  _KV('camLimit', '${policy.camLimit}'),
                  if (policy.micTimerSeconds != null)
                    _KV('micTimer', '${policy.micTimerSeconds}s'),
                ],
              ),
              loading: () => const _Pill('loading…'),
              error: (e, _) =>
                  _Pill('policy error: $e', color: Colors.redAccent),
            ),
            const SizedBox(height: 8),

            // ── Participants ─────────────────────────────────────────────────
            const _SectionHeader(
              label: 'PARTICIPANTS',
              color: Color(0xFFA5D6A7),
            ),
            participantsAsync.when(
              data: (participants) {
                if (participants.isEmpty) {
                  return const _Pill('none');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: participants.map((p) {
                    final onMic = roomState.speakerIds.contains(p.userId);
                    final roleLabel = _roleLabel(
                      p.role,
                      isHost: p.userId == roomState.hostId,
                      onMic: onMic,
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              onMic ? '🎙' : ' ',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                          Text(
                            _shortId(p.userId),
                            style: const TextStyle(
                              color: Color(0xFFB0BEC5),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _RoleTag(label: roleLabel),
                          if (p.isMuted)
                            const _RoleTag(
                              label: 'muted',
                              color: Color(0xFFEF9A9A),
                            ),
                          if (p.isBanned)
                            const _RoleTag(
                              label: 'banned',
                              color: Colors.redAccent,
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const _Pill('loading…'),
              error: (e, _) => _Pill('error: $e', color: Colors.redAccent),
            ),
            const SizedBox(height: 8),

            // ── Mod Log ──────────────────────────────────────────────────────
            const _SectionHeader(
              label: 'MOD LOG (last 20)',
              color: Color(0xFFFFCC80),
            ),
            modLogAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const _Pill('no events yet');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.map((entry) {
                    final action = entry['action']?.toString() ?? '?';
                    final actor = _shortId(entry['actorId']?.toString() ?? '');
                    final target = _shortId(
                      entry['targetId']?.toString() ?? '',
                    );
                    final ts = _fmtTs(entry['ts']);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Text(
                        '[$ts] $actor → $action'
                        '${target.isNotEmpty ? ' ← $target' : ''}',
                        style: TextStyle(
                          color: _modActionColor(action),
                          fontSize: 10,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const _Pill('loading…'),
              error: (e, _) => _Pill('error: $e', color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _shortId(String id) {
    if (id.isEmpty) return '—';
    return id.length > 8 ? '${id.substring(0, 8)}…' : id;
  }

  static String _roleLabel(
    String role, {
    required bool isHost,
    required bool onMic,
  }) {
    if (isHost && role != 'host') return 'host*';
    return role.isEmpty ? 'audience' : role;
  }

  static Color _lifecycleColor(RoomLifecycleState state) {
    return switch (state) {
      RoomLifecycleState.active => const Color(0xFFA5D6A7),
      RoomLifecycleState.degraded => Colors.orangeAccent,
      RoomLifecycleState.ended => Colors.redAccent,
      _ => const Color(0xFFB0BEC5),
    };
  }

  static Color _modActionColor(String action) {
    if (action.contains('ban') || action.contains('kick')) {
      return Colors.redAccent;
    }
    if (action.contains('mute')) return Colors.orangeAccent;
    if (action.contains('promote')) return const Color(0xFFA5D6A7);
    if (action.contains('demote')) return const Color(0xFFEF9A9A);
    if (action.contains('force_release')) return Colors.orangeAccent;
    return const Color(0xFFE0E0E0);
  }

  static String _deltaStr(int delta) {
    if (delta == 0) return '0';
    return delta > 0 ? '+$delta' : '$delta';
  }

  static Color _deltaColor(int delta) {
    if (delta > 0) return const Color(0xFFA5D6A7); // green
    if (delta < 0) return Colors.orangeAccent; // orange
    return const Color(0xFF78909C); // grey
  }

  static String _fmtTs(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate().toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';
    }
    return '??:??:??';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 3),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.key_, this.value, {this.valueColor});
  final String key_;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              key_,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? const Color(0xFFE0E0E0),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 3),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: (color ?? const Color(0xFF37474F)).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? const Color(0xFF90CAF9),
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? const Color(0xFF78909C),
          fontSize: 10,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// Floating button that opens [RoomInspectorPanel] as a slide-in end-drawer.
/// Drop this anywhere in the widget tree — it's a no-op in release mode.
class RoomInspectorButton extends StatelessWidget {
  const RoomInspectorButton({super.key, required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context) {
    if (!kEnableVisibilityDiagnostics) return const SizedBox.shrink();
    return FloatingActionButton.small(
      heroTag: 'room_inspector_$roomId',
      tooltip: 'Room Inspector',
      backgroundColor: Colors.black87,
      foregroundColor: const Color(0xFFFFCC80),
      onPressed: () => _openInspector(context),
      child: const Icon(Icons.bug_report_outlined, size: 18),
    );
  }

  void _openInspector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: RoomInspectorPanel(roomId: roomId),
        ),
      ),
    );
  }
}



