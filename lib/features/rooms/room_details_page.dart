import 'package:flutter/material.dart';
import '../../providers/room_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import './room_page.dart';

class RoomDetailsPage extends ConsumerWidget {
  final String roomId;
  const RoomDetailsPage({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(roomProvider(roomId));
    return Scaffold(
      appBar: AppBar(title: const Text('Room Details')),
      body: roomAsync.when(
        data: (room) => room == null
            ? const Center(child: Text('Room not found'))
            : Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.all(16),
                color: _getMoodColor(room.mood),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_getMoodIcon(room.mood), color: _getMoodAccent(room.mood)),
                          const SizedBox(width: 8),
                          Text(room.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Host: ${room.hostId}'),
                      Text('Mood: ${room.mood}'),
                      Text('Music: ${room.musicType}'),
                      Wrap(
                        spacing: 4,
                        children: room.vibeTags.map((tag) => Chip(label: Text(tag))).toList(),
                      ),
                      Text('Category: ${room.category}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RoomPage(roomId: room.id),
                            ),
                          );
                        },
                        child: const Text('Join Room'),
                      ),
                    ],
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading room: $e')),
      ),
    );
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'Chill': return const Color(0xFF16213e);
      case 'After Hours': return const Color(0xFF1a1a2e);
      case 'Debate': return const Color(0xFF22223b);
      case 'Game Night': return const Color(0xFF6C63FF);
      case 'Storytime': return const Color(0xFFFFD700);
      default: return Colors.grey[900]!;
    }
  }

  Color _getMoodAccent(String mood) {
    switch (mood) {
      case 'Chill': return const Color(0xFF6C63FF);
      case 'After Hours': return const Color(0xFFFFD700);
      case 'Debate': return Colors.redAccent;
      case 'Game Night': return const Color(0xFF6C63FF);
      case 'Storytime': return const Color(0xFFFFD700);
      default: return Colors.white;
    }
  }

  IconData _getMoodIcon(String mood) {
    switch (mood) {
      case 'Chill': return Icons.spa;
      case 'After Hours': return Icons.nightlife;
      case 'Debate': return Icons.record_voice_over;
      case 'Game Night': return Icons.videogame_asset;
      case 'Storytime': return Icons.menu_book;
      default: return Icons.chat;
    }
  }
}
