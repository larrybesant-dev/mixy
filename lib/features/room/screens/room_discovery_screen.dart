/// Room Discovery Screen
///
/// Lists all available rooms with:
/// - Room name
/// - Participant count
/// - Energy indicator (calm/active/buzzing)
/// - Tap to join
///
/// Usage:
/// ```dart
/// RoomDiscoveryScreen()
/// ```
///
/// Architecture:
/// - Streams rooms from Firestore (rooms collection)
/// - Consumes: RoomFirestoreService (via Provider)
/// - Navigation: Navigate to RoomScreen on join
///
/// Enforces: DESIGN_BIBLE.md (colors, spacing)
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/design_system/design_constants.dart';
import '../widgets/room_card_widget.dart';
import '../screens/room_by_id_page.dart';

// Simple Room model for discovery (minimal structure)
class Room {
  final String id;
  final String name;
  final int participantCount;
  final double energy;
  final DateTime createdAt;

  Room({
    required this.id,
    required this.name,
    required this.participantCount,
    required this.energy,
    required this.createdAt,
  });

  factory Room.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return Room(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Room',
      participantCount: (data['participantCount'] ?? 0) as int,
      energy: ((data['energy'] ?? 0.0) as num).toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class RoomDiscoveryScreen extends StatefulWidget {
  /// Optional: callback when room is created
  final VoidCallback? onRoomCreated;

  const RoomDiscoveryScreen({
    this.onRoomCreated,
    super.key,
  });

  @override
  State<RoomDiscoveryScreen> createState() => _RoomDiscoveryScreenState();
}

class _RoomDiscoveryScreenState extends State<RoomDiscoveryScreen> {
  late Stream<List<Room>> _roomsStream;

  @override
  void initState() {
    super.initState();
    _initializeRoomsStream();
  }

  void _initializeRoomsStream() {
    // Stream from Firestore: rooms collection
    _roomsStream = FirebaseFirestore.instance
        .collection('rooms')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Room.fromFirestore(doc))
          .where((room) => room.participantCount > 0) // Only show active rooms
          .toList();
    });
  }

  Future<void> _handleJoinRoom(Room room) async {
    if (!mounted) return;

    // Navigate to room screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomByIdPage(
          roomId: room.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // âœ… Use DesignColors.surfaceDefault background
      backgroundColor: DesignColors.surfaceDefault,

      appBar: AppBar(
        // âœ… Use DesignColors for app bar
        backgroundColor: DesignColors.surfaceDefault,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Discover Rooms',
          style: DesignTypography.heading,
        ),
        actions: [
          // Create new room button
          Padding(
            padding: const EdgeInsets.all(DesignSpacing.md),
            child: TextButton.icon(
              onPressed: _handleCreateRoom,
              label: Text(
                'Create',
                style: DesignTypography.body.copyWith(
                  color: DesignColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              icon: const Icon(
                Icons.add,
                color: DesignColors.accent,
              ),
            ),
          ),
        ],
      ),

      body: StreamBuilder<List<Room>>(
        stream: _roomsStream,
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(DesignColors.accent),
              ),
            );
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: DesignColors.accent,
                    size: 48,
                  ),
                  const SizedBox(height: DesignSpacing.lg),
                  const Text(
                    'Failed to load rooms',
                    style: DesignTypography.body,
                  ),
                  const SizedBox(height: DesignSpacing.md),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _initializeRoomsStream();
                      });
                    },
                    child: Text(
                      'Retry',
                      style: DesignTypography.body.copyWith(
                        color: DesignColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final rooms = snapshot.data ?? [];

          // Empty state
          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.meeting_room_outlined,
                    color: DesignColors.accent,
                    size: 48,
                  ),
                  const SizedBox(height: DesignSpacing.lg),
                  Text(
                    'No rooms yet',
                    style: DesignTypography.body.copyWith(
                      color: DesignColors.accent,
                    ),
                  ),
                  const SizedBox(height: DesignSpacing.md),
                  ElevatedButton(
                    onPressed: _handleCreateRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignColors.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignSpacing.lg,
                        vertical: DesignSpacing.md,
                      ),
                    ),
                    child: Text(
                      'Create a Room',
                      style: DesignTypography.body.copyWith(
                        color: DesignColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // List of rooms
          return Padding(
            padding: const EdgeInsets.all(DesignSpacing.lg),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 350,
                mainAxisSpacing: DesignSpacing.lg,
                crossAxisSpacing: DesignSpacing.lg,
                childAspectRatio: 1.4,
              ),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];

                return RoomCardWidget(
                  roomName: room.name,
                  participantCount: room.participantCount,
                  energy: room.energy,
                  onTap: () => _handleJoinRoom(room),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleCreateRoom() async {
    // TODO: Show create room dialog
    // For now, just show a placeholder dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Create New Room',
          style: DesignTypography.heading,
        ),
        content: const Text(
          'Room creation feature coming soon.',
          style: DesignTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: DesignTypography.body.copyWith(
                color: DesignColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
