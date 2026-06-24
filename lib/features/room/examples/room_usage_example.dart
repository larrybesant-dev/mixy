import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/models/room.dart';
import '../providers/room_providers.dart';

/// Example: Creating a Room with Tags
///
/// This example shows how to create a room using the createRoomProvider.
class CreateRoomExample extends ConsumerStatefulWidget {
  const CreateRoomExample({super.key});

  @override
  ConsumerState<CreateRoomExample> createState() => _CreateRoomExampleState();
}

class _CreateRoomExampleState extends ConsumerState<CreateRoomExample> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _createRoom() async {
    final notifier = ref.read(createRoomProvider.notifier);

    await notifier.createRoom(
      title: _titleController.text,
      description: _descriptionController.text,
      hostId: 'current-user-id', // Replace with actual user ID
      tags: _tags,
    );
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createRoomProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Room')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      labelText: 'Add Tag',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTag,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _tags
                  .map(
                    (tag) => Chip(
                      label: Text(tag),
                      onDeleted: () => _removeTag(tag),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            if (_tags.isNotEmpty)
              Text(
                'Predicted Category: ${ref.watch(categoryServiceProvider).classifyRoom(_tags)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: createState.isLoading ? null : _createRoom,
              child: createState.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Create Room'),
            ),
            if (createState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Error: ${createState.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (createState.hasValue && createState.value != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Room created: ${createState.value!.title}\nCategory: ${createState.value!.category}',
                  style: const TextStyle(color: Colors.green),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Example: Fetching Rooms by Category
///
/// This example shows how to fetch and display rooms filtered by category.
class RoomsByCategoryExample extends ConsumerWidget {
  final String category;

  const RoomsByCategoryExample({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomsByCategoryProvider(category));

    return Scaffold(
      appBar: AppBar(title: Text('$category Rooms')),
      body: roomsAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return const Center(
              child: Text('No rooms found in this category'),
            );
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return RoomListTile(room: room);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}

/// Example: Category Tabs with Room Lists
///
/// This example shows a tabbed interface for browsing rooms by category.
class CategoryTabsExample extends ConsumerWidget {
  const CategoryTabsExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return DefaultTabController(
      length: categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Browse Rooms'),
          bottom: TabBar(
            isScrollable: true,
            tabs: categories.map((category) => Tab(text: category)).toList(),
          ),
        ),
        body: TabBarView(
          children: categories
              .map(
                (category) => RoomsByCategoryExample(category: category),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// Example: Live Rooms Feed
///
/// This example shows how to display live rooms sorted by viewer count.
class LiveRoomsFeedExample extends ConsumerWidget {
  const LiveRoomsFeedExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveRoomsAsync = ref.watch(liveRoomsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Live Rooms')),
      body: liveRoomsAsync.when(
        data: (rooms) {
          if (rooms.isEmpty) {
            return const Center(
              child: Text('No live rooms at the moment'),
            );
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return RoomListTile(room: room, showLiveBadge: true);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }
}

/// Reusable Room List Tile Widget
class RoomListTile extends StatelessWidget {
  final Room room;
  final bool showLiveBadge;

  const RoomListTile({
    super.key,
    required this.room,
    this.showLiveBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(room.title)),
            if (showLiveBadge && room.isLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(room.description),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                Chip(
                  label: Text(room.category),
                  backgroundColor: _getCategoryColor(room.category),
                  labelStyle: const TextStyle(fontSize: 12),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                ...room.tags.map(
                  (tag) => Chip(
                    label: Text(tag),
                    labelStyle: const TextStyle(fontSize: 12),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            if (room.viewerCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${room.viewerCount} viewers',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Music':
        return Colors.purple.shade100;
      case 'Gaming':
        return Colors.blue.shade100;
      case 'Chat':
        return Colors.green.shade100;
      case 'Live':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}

/// Usage Instructions:
///
/// 1. Create a Room:
/// ```dart
/// final notifier = ref.read(createRoomProvider.notifier);
/// await notifier.createRoom(
///   title: 'My Music Room',
///   description: 'A place for music lovers',
///   hostId: 'user123',
///   tags: ['music', 'dj', 'beats'],
/// );
/// ```
///
/// 2. Fetch Rooms by Category:
/// ```dart
/// final musicRooms = ref.watch(roomsByCategoryProvider('Music'));
/// ```
///
/// 3. Fetch All Rooms:
/// ```dart
/// final allRooms = ref.watch(allRoomsProvider);
/// ```
///
/// 4. Fetch Live Rooms:
/// ```dart
/// final liveRooms = ref.watch(liveRoomsProvider);
/// ```
///
/// 5. Update Room Live Status:
/// ```dart
/// final notifier = ref.read(updateRoomProvider.notifier);
/// await notifier.updateLiveStatus(roomId, true);
/// ```

