import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mixmingle/core/pagination/pagination_controller.dart';
import 'package:mixmingle/shared/models/room.dart';
import 'package:mixmingle/shared/widgets/paginated_list_view.dart';

/// Example implementation of paginated rooms browse page
/// This shows how to use PaginationController with the reusable PaginatedListView widget
class BrowseRoomsPaginatedPage extends ConsumerStatefulWidget {
  const BrowseRoomsPaginatedPage({super.key});

  @override
  ConsumerState<BrowseRoomsPaginatedPage> createState() =>
      _BrowseRoomsPaginatedPageState();
}

class _BrowseRoomsPaginatedPageState
    extends ConsumerState<BrowseRoomsPaginatedPage> {
  late PaginationController<Room> _controller;

  @override
  void initState() {
    super.initState();

    // Initialize the pagination controller with Firestore query
    _controller = PaginationController<Room>(
      pageSize: 20,
      queryBuilder: () {
        return FirebaseFirestore.instance
            .collection('rooms')
            .orderBy('createdAt', descending: true);
      },
      fromDocument: (doc) => Room.fromMap(doc.data() as Map<String, dynamic>),
    );

    // Load initial page
    _controller.loadInitial();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filter options
            },
          ),
        ],
      ),
      body: PaginatedListView<Room>(
        controller: _controller,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, room, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: ListTile(
                title: Text(room.name ?? room.title),
                subtitle: Text(
                    '${room.participantIds.length} members â€¢ ${room.viewerCount} viewers'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  // Navigate to room details
                  // Navigator.pushNamed(context, '/room/${room.id}');
                },
              ),
            ),
          );
        },
        emptyWidget: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.meeting_room, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No rooms available',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to create a room!',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        errorBuilder: (error) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load rooms',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _controller.refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'browse_create_room_fab',
        onPressed: () {
          // Navigate to create room
          // Navigator.pushNamed(context, '/create-room');
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Room'),
      ),
    );
  }
}
