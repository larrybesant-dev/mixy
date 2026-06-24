import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/room.dart';
import '../../core/utils/app_logger.dart';
import 'room_access_gate.dart';
import '../../core/design_system/design_constants.dart';
import 'live/live_room_screen.dart';

/// Wrapper that enforces room access gating
/// Checks auth â†’ profile â†’ room permissions before rendering RoomPage
class RoomAccessWrapper extends ConsumerWidget {
  final Room room;
  final String userId;

  const RoomAccessWrapper({
    super.key,
    required this.room,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessCheck = ref.watch(roomAccessCheckProvider((
      roomId: room.id,
      userId: userId,
    )));

    return accessCheck.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(room.name ?? room.title),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking room access...'),
            ],
          ),
        ),
      ),
      data: (hasAccess) {
        // Build display name from FirebaseAuth (already authenticated at this point)
        final fbUser = fb_auth.FirebaseAuth.instance.currentUser;
        final displayName = fbUser?.displayName?.trim().isNotEmpty == true
            ? fbUser!.displayName!
            : fbUser?.email?.split('@').first ?? userId;
        final avatarUrl = fbUser?.photoURL;

        return LiveRoomScreen(
          roomId: room.id,
          displayName: displayName,
          avatarUrl: avatarUrl,
        );
      },
      error: (error, stackTrace) {
        // Access denied - show appropriate error message
        var errorMessage = 'Access denied';

        if (error is RoomAccessDeniedException) {
          errorMessage = error.message;
          // TODO: Handle redirects based on error.state
          // - RoomAccessState.profileIncomplete -> redirect to profile completion
          // - RoomAccessState.unauthenticated -> redirect to login
        } else {
          AppLogger.error('Room access error: $error');
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(room.name ?? room.title),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 64, color: DesignColors.accent),
                const SizedBox(height: 24),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: DesignTypography.body,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
