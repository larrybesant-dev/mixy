import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../room_access_wrapper.dart';
import 'package:mixvy/shared/widgets/loading_widgets.dart';
import 'package:mixvy/features/error/error_page.dart';
import '../../../providers/room_provider.dart';

/// 🔴 FIX #1: Loads a room by Firestore document ID with REAL-TIME updates
/// Now uses StreamProvider instead of FutureBuilder to enable live room data
/// (member counts, status changes, chat messages, etc.)
///
/// Renders through RoomAccessWrapper (which gates access and renders LiveRoomScreen).
class RoomByIdPage extends ConsumerWidget {
  final String roomId;
  const RoomByIdPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔴 FIX: Watch the room stream for real-time updates
    // This replaces FutureBuilder pattern - automatically rebuilds when Firestore data changes
    final roomStream = ref.watch(roomStreamProvider(roomId));

    return roomStream.when(
      // ✅ Data loaded - render the room with access control
      data: (room) {
        if (room == null) {
          return const Scaffold(
            body: Center(child: Text('Room not found')),
          );
        }
        return RoomAccessWrapper(
          room: room,
          userId: fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '',
        );
      },
      // ✅ Still loading - show spinner
      loading: () => const Scaffold(
        body: Center(child: LoadingSpinner()),
      ),
      // ✅ Error occurred - show error page with retry
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ErrorPage(errorMessage: 'Failed to load room'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Refresh the room stream to retry loading
                  // ignore: unused_result
                  ref.refresh(roomStreamProvider(roomId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

