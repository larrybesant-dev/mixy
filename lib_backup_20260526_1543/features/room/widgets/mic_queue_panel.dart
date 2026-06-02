import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/mic_access_request_model.dart';
import '../providers/mic_access_provider.dart';

/// Paltalk-style mic queue panel.
/// Shows the pending hand-raise queue with position numbers, requester names,
/// a time-remaining countdown per request, and approve/deny buttons for hosts.
class MicQueuePanel extends ConsumerStatefulWidget {
  const MicQueuePanel({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.isHost,
    required this.displayNameById,
    this.onApprove,
    this.onDeny,
    this.onWithdraw,
  });

  final String roomId;
  final String currentUserId;

  /// Whether the viewer is a host/cohost/moderator.
  final bool isHost;

  /// Display names keyed by userId (same map used by UserListPanel).
  final Map<String, String> displayNameById;

  /// Called when the host taps Approve on a request.
  final void Function(MicAccessRequestModel request)? onApprove;

  /// Called when the host taps Deny on a request.
  final void Function(MicAccessRequestModel request)? onDeny;

  /// Called when the requester lowers their own hand.
  final void Function(MicAccessRequestModel request)? onWithdraw;

  @override
  ConsumerState<MicQueuePanel> createState() => _MicQueuePanelState();
}

class _MicQueuePanelState extends ConsumerState<MicQueuePanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Tick every second to update countdown displays.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _countdownLabel(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'expired';
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color _countdownColor(DateTime expiresAt) {
    final seconds = expiresAt.difference(DateTime.now()).inSeconds;
    if (seconds <= 30) return const Color(0xFFFF6E84);
    if (seconds <= 90) return const Color(0xFFFFA040);
    return const Color(0xFFC45E7A);
  }

  @override
  Widget build(BuildContext context) {
    const npSurfaceContainer = Color(0xFF161A21);
    const npSurfaceHigh = Color(0xFF241820);
    const npPrimary = Color(0xFFD4A853);
    const npOnVariant = Color(0xFFB09080);

    final requestsAsync = ref.watch(
      roomMicAccessRequestsProvider(widget.roomId),
    );

    return requestsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, e) => const SizedBox.shrink(),
      data: (requests) {
        final pending = requests
            .where((r) => r.status == 'pending' && !r.isExpired)
            .toList(growable: false);

        if (pending.isEmpty) return const SizedBox.shrink();

        return DecoratedBox(
          decoration: BoxDecoration(
            color: npSurfaceContainer,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                height: 28,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF140E22), Color(0xFF0B0A12)],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.waving_hand_outlined,
                      color: Color(0xFFD4A853),
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'WAITING TO SPEAK',
                        style: TextStyle(
                          color: Color(0xFFD4A853),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x50D4A853),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${pending.length}',
                        style: const TextStyle(
                          color: Color(0xFFD4A853),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Queue list (max 5 visible, scrollable)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: pending.length,
                  itemBuilder: (context, index) {
                    final req = pending[index];
                    final name = widget.displayNameById[req.requesterId] ??
                        req.requesterId;
                    final isMe = req.requesterId == widget.currentUserId;

                    return Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isMe
                            ? npPrimary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Position badge
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: npSurfaceHigh,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: npOnVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Hand raise icon
                          const Icon(
                            Icons.pan_tool_outlined,
                            color: Color(0xFFFFA040),
                            size: 13,
                          ),
                          const SizedBox(width: 6),
                          // Name
                          Expanded(
                            child: Text(
                              isMe ? '$name (you)' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isMe ? npPrimary : Colors.white,
                                fontSize: 12,
                                fontWeight:
                                    isMe ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                          // Countdown
                          Text(
                            _countdownLabel(req.expiresAt),
                            style: TextStyle(
                              color: _countdownColor(req.expiresAt),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          if (isMe && !widget.isHost) ...[
                            const SizedBox(width: 8),
                            _IconBtn(
                              icon: Icons.pan_tool_alt_outlined,
                              color: const Color(0xFFFFD166),
                              tooltip: 'Lower hand',
                              onTap: () => widget.onWithdraw?.call(req),
                            ),
                          ] else if (widget.isHost) ...[
                            const SizedBox(width: 8),
                            _IconBtn(
                              icon: Icons.check,
                              color: const Color(0xFF4CAF50),
                              tooltip: 'Approve',
                              onTap: () => widget.onApprove?.call(req),
                            ),
                            const SizedBox(width: 4),
                            _IconBtn(
                              icon: Icons.close,
                              color: const Color(0xFFFF6E84),
                              tooltip: 'Deny',
                              onTap: () => widget.onDeny?.call(req),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, color: color, size: 15),
        ),
      ),
    );
  }
}
