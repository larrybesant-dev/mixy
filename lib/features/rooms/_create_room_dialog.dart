import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/room_model.dart';
import '../../services/room_service.dart';

class CreateRoomDialog extends ConsumerStatefulWidget {
  const CreateRoomDialog({super.key});

  @override
  ConsumerState<CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends ConsumerState<CreateRoomDialog> {
  final _titleController = TextEditingController();
  String _category = 'Chill';
  String _mood = 'Chill';
  String _musicType = 'R&B';
  final List<String> _vibeTags = [];
  bool _isPrivate = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Room'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Room Title'),
            ),
            DropdownButton<String>(
              value: _category,
              items: ['Chill', 'After Hours', 'Game Night']
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      ))
                  .toList(),
              onChanged: (cat) {
                if (cat != null) setState(() => _category = cat);
              },
            ),
            DropdownButton<String>(
              value: _mood,
              items: ['Chill', 'After Hours', 'Debate', 'Game Night', 'Storytime']
                  .map((mood) => DropdownMenuItem(
                        value: mood,
                        child: Text(mood),
                      ))
                  .toList(),
              onChanged: (mood) {
                if (mood != null) setState(() => _mood = mood);
              },
            ),
            DropdownButton<String>(
              value: _musicType,
              items: ['R&B', 'Afrobeats', 'Lo-fi', 'House']
                  .map((music) => DropdownMenuItem(
                        value: music,
                        child: Text(music),
                      ))
                  .toList(),
              onChanged: (music) {
                if (music != null) setState(() => _musicType = music);
              },
            ),
            Wrap(
              spacing: 8,
              children: ['Intimate', 'Open', 'Wild', 'Deep Talk', 'Networking']
                  .map((tag) => ChoiceChip(
                        label: Text(tag),
                        selected: _vibeTags.contains(tag),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _vibeTags.add(tag);
                            } else {
                              _vibeTags.remove(tag);
                            }
                          });
                        },
                      ))
                  .toList(),
            ),
            CheckboxListTile(
              value: _isPrivate,
              onChanged: (val) {
                if (val != null) setState(() => _isPrivate = val);
              },
              title: const Text('Private Room'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final room = Room(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: _titleController.text,
              hostId: 'currentUser', // Replace with actual user ID
              category: _category,
              mood: _mood,
              musicType: _musicType,
              vibeTags: _vibeTags,
              isPrivate: _isPrivate,
              createdAt: DateTime.now() as dynamic,
              activeUserCount: 1,
            );
            await RoomService().createRoom(room);
            if (mounted) Navigator.pop(context);
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
