import 'package:flutter/material.dart';
import '../../providers/room_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './_create_room_dialog.dart';

class RoomListPage extends ConsumerWidget {
  const RoomListPage({super.key});

  Color getMoodColor(String mood) {
    switch (mood) {
      case 'Chill': return const Color(0xFF16213e);
      case 'After Hours': return const Color(0xFF1a1a2e);
      case 'Debate': return const Color(0xFF22223b);
      case 'Game Night': return const Color(0xFF6C63FF);
      case 'Storytime': return const Color(0xFFFFD700);
      default: return Colors.grey[900]!;
    }
  }

  Color getMoodAccent(String mood) {
    switch (mood) {
      case 'Chill': return const Color(0xFF6C63FF);
      case 'After Hours': return const Color(0xFFFFD700);
      case 'Debate': return Colors.redAccent;
      case 'Game Night': return const Color(0xFF6C63FF);
      case 'Storytime': return const Color(0xFFFFD700);
      default: return Colors.white;
    }
  }

  IconData getMoodIcon(String mood) {
    switch (mood) {
      case 'Chill': return Icons.spa;
      case 'After Hours': return Icons.nightlife;
      case 'Debate': return Icons.record_voice_over;
      case 'Game Night': return Icons.videogame_asset;
      case 'Storytime': return Icons.menu_book;
      default: return Icons.chat;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsAsync = ref.watch(roomListProvider);
    String selectedCategory = 'All';
    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const CreateRoomDialog(),
          );
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: selectedCategory,
              items: ['All', 'Chill', 'After Hours', 'Game Night']
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      ))
                  .toList(),
              onChanged: (cat) {
                if (cat != null) {
                  selectedCategory = cat;
                }
              },
            ),
          ),
          Expanded(
            child: roomsAsync.when(
              data: (rooms) {
                final filtered = selectedCategory == 'All'
                    ? rooms
                    : rooms.where((r) => r.category == selectedCategory).toList();
                return filtered.isEmpty
                    ? const Center(child: Text('No rooms available'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final room = filtered[index];
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: ListTile(
                              tileColor: getMoodColor(room.mood),
                              title: Row(
                                children: [
                                  Icon(getMoodIcon(room.mood), color: getMoodAccent(room.mood)),
                                  const SizedBox(width: 8),
                                  Text(room.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Mood: ${room.mood}'),
                                  Text('Music: ${room.musicType}'),
                                  Wrap(
                                    spacing: 4,
                                    children: room.vibeTags.map((tag) => Chip(label: Text(tag))).toList(),
                                  ),
                                  Text('Category: ${room.category}'),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('${room.activeUserCount} online'),
                                ],
                              ),
                              onTap: () {
                                Navigator.pushNamed(context, '/roomDetails', arguments: room.id);
                              },
                            ),
                          );
                        },
                      );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error loading rooms: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
