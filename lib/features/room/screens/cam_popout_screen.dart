import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../presentation/providers/user_provider.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../services/room_service.dart';
import '../../../services/notification_service.dart';

/// Direct one-on-one video call screen.
///
/// When opened, it creates a private 2-person room, navigates the caller into
/// it, and sends an in-app notification to the target user with a deep link.
/// The target user joins the same room to connect.
class CamPopoutScreen extends ConsumerStatefulWidget {
  const CamPopoutScreen({super.key, required this.targetUserId});

  final String targetUserId;

  @override
  ConsumerState<CamPopoutScreen> createState() => _CamPopoutScreenState();
}

class _CamPopoutScreenState extends ConsumerState<CamPopoutScreen> {
  bool _calling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCall());
  }

  Future<void> _startCall() async {
    final caller = ref.read(userProvider);
    if (caller == null) {
      setState(() => _error = 'You must be logged in to make a call.');
      return;
    }

    setState(() {
      _calling = true;
      _error = null;
    });

    try {
      final roomService = ref.read(roomServiceProvider);
      final firestore = ref.read(firestoreProvider);
      final callerName = caller.username.trim().isEmpty
          ? 'Someone'
          : caller.username;

      // Fetch target user's display name for the room title.
      final targetDoc = await firestore
          .collection('users')
          .doc(widget.targetUserId)
          .get();
      final targetName = targetDoc.exists
          ? (targetDoc.data()?['username'] as String? ?? 'User').trim()
          : 'User';

      final roomId = await roomService.createRoom(
        hostId: caller.id,
        name: '$callerName & $targetName',
        description: 'Private video call',
        isLive: true,
        category: 'call',
      );

      // Set maxBroadcasters = 2 and flag as a direct call.
      await firestore.collection('rooms').doc(roomId).update({
        'maxBroadcasters': 2,
        'isDirectCall': true,
        'calleeId': widget.targetUserId,
        'ownerName': callerName,
      });

      await NotificationService(
        firestore: firestore,
      ).inAppNotification(
        widget.targetUserId,
        '📹 $callerName is calling you! Join at mixvy.app/room/$roomId',
      );

      if (!mounted) return;
      context.go('/room/$roomId');
    } catch (e) {
      if (mounted) {
        setState(() {
          _calling = false;
          _error = 'Could not start call: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPageScaffold(
      backgroundColor: Colors.black,
      body: _error != null
          ? AppErrorView(
              error: _error!,
              fallbackContext: 'Unable to start call.',
              onRetry: _startCall,
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _calling ? 'Starting call…' : 'Connecting…',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
