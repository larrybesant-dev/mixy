import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:mixvy/shared/models/room.dart';
import '../room_access_wrapper.dart';
import 'package:mixvy/shared/widgets/loading_widgets.dart';
import 'package:mixvy/features/error/error_page.dart';

/// Loads a room by Firestore document ID and routes through RoomAccessWrapper
/// (which gates access and renders LiveRoomScreen).
class RoomByIdPage extends ConsumerStatefulWidget {
  final String roomId;
  const RoomByIdPage({super.key, required this.roomId});

  @override
  ConsumerState<RoomByIdPage> createState() => _RoomByIdPageState();
}

class _RoomByIdPageState extends ConsumerState<RoomByIdPage> {
  // Stored as a field so Flutter doesn't re-fetch on every rebuild.
  late final Future<Room?> _roomFuture;

  @override
  void initState() {
    super.initState();
    _roomFuture = _fetchRoom();
  }

  Future<Room?> _fetchRoom() async {
    final doc = await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .get();
    if (!doc.exists) return null;
    return Room.fromDocument(doc);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Room?>(
      future: _roomFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: LoadingSpinner()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: ErrorPage(errorMessage: 'Failed to load room'),
          );
        }
        final room = snapshot.data;
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
    );
  }
}

