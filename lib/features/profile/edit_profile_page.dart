import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_profile_model.dart';
import '../../services/profile_service.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  final String userId;
  const EditProfilePage({super.key, required this.userId});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _displayNameController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _bioController = TextEditingController();
  final _interestsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: 'Display Name'),
            ),
            TextField(
              controller: _avatarUrlController,
              decoration: const InputDecoration(labelText: 'Avatar URL'),
            ),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            TextField(
              controller: _interestsController,
              decoration: const InputDecoration(labelText: 'Interests (comma separated)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final profile = UserProfile(
                  id: widget.userId,
                  displayName: _displayNameController.text,
                  avatarUrl: _avatarUrlController.text,
                  bio: _bioController.text,
                  interests: _interestsController.text.split(',').map((s) => s.trim()).toList(),
                  createdAt: DateTime.now() as dynamic,
                );
                await ProfileService().updateProfile(profile);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
