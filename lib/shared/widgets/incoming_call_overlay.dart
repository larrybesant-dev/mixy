import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/features/room/providers/message_providers.dart';

// ── Widget ───────────────────────────────────────────────────────────────────

/// Wraps [child] and shows a full-screen incoming-call dialog whenever
/// another user places a direct video call to the authenticated user.
class IncomingCallOverlay extends ConsumerStatefulWidget {
  const IncomingCallOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IncomingCallOverlay> createState() =>
      _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends ConsumerState<IncomingCallOverlay> {
  String? _activeCallRoomId;
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      pendingDirectCallRoomProvider,
      (_, next) {
        final callRoom = next.valueOrNull;
        if (callRoom == null) {
          // Call was cancelled/accepted by another device — dismiss dialog.
          if (_dialogShown) {
            _dialogShown = false;
            Navigator.of(context, rootNavigator: true).maybePop();
          }
          _activeCallRoomId = null;
          return;
        }
        final roomId = callRoom['id'] as String? ?? '';
        if (roomId.isEmpty || roomId == _activeCallRoomId) return;
        _activeCallRoomId = roomId;
        _showCallDialog(context, callRoom);
      },
    );

    return widget.child;
  }

  void _showCallDialog(BuildContext context, Map<String, dynamic> callRoom) {
    final roomId = callRoom['id'] as String? ?? '';
    final callerName = callRoom['ownerName'] as String? ?? 'Someone';

    _dialogShown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => _IncomingCallDialog(
        callerName: callerName,
        roomId: roomId,
        onAccept: () {
          _dialogShown = false;
          _activeCallRoomId = null;
          Navigator.of(context, rootNavigator: true).pop();
          context.go('/room/$roomId');
        },
        onDecline: () async {
          _dialogShown = false;
          _activeCallRoomId = null;
          Navigator.of(context, rootNavigator: true).pop();
          try {
            await ref
                .read(firestoreProvider)
                .collection('rooms')
                .doc(roomId)
                .update({
                  'callDeclined': true,
                  'callDeclinedAt': FieldValue.serverTimestamp(),
                });
          } catch (e) {
            developer.log(
              'Failed to decline call: $e',
              name: 'IncomingCallOverlay',
            );
          }
        },
      ),
    ).whenComplete(() {
      _dialogShown = false;
    });
  }
}

// ── Dialog UI ────────────────────────────────────────────────────────────────

class _IncomingCallDialog extends StatelessWidget {
  const _IncomingCallDialog({
    required this.callerName,
    required this.roomId,
    required this.onAccept,
    required this.onDecline,
  });

  final String callerName;
  final String roomId;
  final VoidCallback onAccept;
  final Future<void> Function() onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer,
            ),
            child: Icon(
              Icons.videocam_rounded,
              size: 36,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Incoming video call',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            callerName,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDecline,
                  icon: const Icon(Icons.call_end_rounded),
                  label: const Text('Decline'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.videocam_rounded),
                  label: const Text('Accept'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
