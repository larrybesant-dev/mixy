import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/providers/providers.dart';
import 'package:mixvy/shared/providers/room_providers.dart'
    as room_providers;
import '../../../shared/club_background.dart';
import '../../../shared/glow_text.dart';
import '../../../shared/neon_button.dart';
import '../../../shared/loading_widgets.dart';

class CreateRoomPage extends ConsumerStatefulWidget {
  const CreateRoomPage({super.key});

  @override
  ConsumerState<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends ConsumerState<CreateRoomPage> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPrivate = false;
  bool _showDJPrefix = true;
  bool _isLoading = false;

  Future<void> _createRoom() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(createRoomProvider({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'isPrivate': _isPrivate,
        'showDJPrefix': _showDJPrefix,
      }).future);

      if (mounted) {
        // Navigate back to home and refresh the rooms list
        ref.invalidate(room_providers.roomsProvider);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create room: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      loadingMessage: 'Creating your room...',
      child: ClubBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const GlowText(
              text: 'Go Live - Create Room',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFFD700),
              glowColor: Color(0xFFFF4C4C),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GlowText(
                  text: 'Start Your DJ Session',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                  glowColor: Color(0xFFFF4C4C),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a room and start streaming to the world',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Room Name',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4C4C).withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                    ),
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Private Room',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      'Only invited users can join',
                      style: TextStyle(color: Colors.white70),
                    ),
                    value: _isPrivate,
                    onChanged: (value) => setState(() => _isPrivate = value),
                    activeThumbColor: const Color(0xFFFF4C4C),
                    activeTrackColor:
                        const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Show DJ Prefix',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      'Display "DJ" before your name',
                      style: TextStyle(color: Colors.white70),
                    ),
                    value: _showDJPrefix,
                    onChanged: (value) => setState(() => _showDJPrefix = value),
                    activeThumbColor: const Color(0xFFFF4C4C),
                    activeTrackColor:
                        const Color(0xFFFF4C4C).withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 32),
                Semantics(
                  label: 'Go Live - Create Room',
                  button: true,
                  child: NeonButton(
                    onPressed: _createRoom,
                    child: const Text('Go Live'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

