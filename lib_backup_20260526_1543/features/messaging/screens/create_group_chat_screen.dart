import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../core/providers/firebase_providers.dart';
import '../providers/messaging_provider.dart';

class CreateGroupChatScreen extends ConsumerStatefulWidget {
  final String userId;
  final String username;

  const CreateGroupChatScreen({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  ConsumerState<CreateGroupChatScreen> createState() =>
      _CreateGroupChatScreenState();
}

class _CreateGroupChatScreenState extends ConsumerState<CreateGroupChatScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selectedUserIds = {};
  final Map<String, String> _selectedUserNames = {};
  List<Map<String, String>> _searchResults = [];
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final snapshot = await ref
          .read(firestoreProvider)
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(15)
          .get();

      final matches = snapshot.docs
          .where((doc) => doc.id != widget.userId)
          .map(
            (doc) => {
              'id': doc.id,
              'name': (doc.data()['username'] as String? ?? doc.id),
            },
          )
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = matches;
        });
      }
    } catch (_) {
      // Keep the current result set on search errors.
    }
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty || _selectedUserIds.isEmpty) return;
    setState(() => _isCreating = true);
    try {
      final participantIds = [widget.userId, ..._selectedUserIds];
      final participantNames = {
        widget.userId: widget.username,
        ..._selectedUserNames,
      };

      final convId =
          await ref.read(messagingControllerProvider).createGroupConversation(
                groupName: _nameController.text.trim(),
                groupAvatarUrl: null,
                participantIds: participantIds,
                participantNames: participantNames,
              );
      if (mounted) context.go('/messages/chat/$convId');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(
        title: const Text('New Group Chat'),
        actions: [
          TextButton(
            onPressed:
                (_nameController.text.isNotEmpty && _selectedUserIds.isNotEmpty)
                    ? _createGroup
                    : null,
            child: _isCreating
                ? const CircularProgressIndicator()
                : const Text('Create'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'Enter group name...',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search people to add...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _searchUsers,
            ),
          ),
          if (_selectedUserIds.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _selectedUserIds
                    .map(
                      (id) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Chip(
                          label: Text(_selectedUserNames[id] ?? id),
                          onDeleted: () => setState(() {
                            _selectedUserIds.remove(id);
                            _selectedUserNames.remove(id);
                          }),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (ctx, i) {
                final user = _searchResults[i];
                final id = user['id'] ?? '';
                final name = user['name'] ?? id;
                if (id.isEmpty) {
                  return const SizedBox.shrink();
                }
                final isSelected = _selectedUserIds.contains(id);
                return ListTile(
                  title: Text(name),
                  trailing: Icon(
                    isSelected ? Icons.check_circle : Icons.add_circle_outline,
                  ),
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedUserIds.remove(id);
                      _selectedUserNames.remove(id);
                    } else {
                      _selectedUserIds.add(id);
                      _selectedUserNames[id] = name;
                    }
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
