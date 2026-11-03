import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/utils/avatar_url_resolver.dart';
import '../../../models/user_model.dart';
import '../../../widgets/safe_network_avatar.dart';

class RoomShareSheet extends StatefulWidget {
  const RoomShareSheet({
    super.key,
    required this.roomName,
    required this.friends,
    required this.onShareExternally,
    required this.onCopyLink,
    required this.onSendInvites,
    required this.onRetry,
  });

  final String roomName;
  final AsyncValue<List<UserModel>> friends;
  final Future<void> Function() onShareExternally;
  final Future<void> Function() onCopyLink;
  final Future<void> Function(List<String> friendIds) onSendInvites;
  final VoidCallback onRetry;

  @override
  State<RoomShareSheet> createState() => _RoomShareSheetState();
}

class _RoomShareSheetState extends State<RoomShareSheet> {
  final Set<String> _selectedFriendIds = <String>{};
  bool _isSending = false;

  @override
  void didUpdateWidget(RoomShareSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final availableIds =
        widget.friends.valueOrNull?.map((friend) => friend.id).toSet() ??
            const <String>{};
    _selectedFriendIds.removeWhere((id) => !availableIds.contains(id));
  }

  Future<void> _sendInvites() async {
    if (_selectedFriendIds.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await widget.onSendInvites(_selectedFriendIds.toList(growable: false));
      if (!mounted) return;
      final count = _selectedFriendIds.length;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? 'Room invite sent.'
                : 'Room invites sent to $count friends.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send room invites: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: VelvetNoir.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Share room',
                          style: TextStyle(
                            color: VelvetNoir.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.roomName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: VelvetNoir.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onShareExternally,
                    icon: const Icon(Icons.ios_share_outlined),
                    label: const Text('Share outside MixVy'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: widget.onCopyLink,
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Copy room link'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Send to friends on MixVy',
                style: TextStyle(
                  color: VelvetNoir.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(child: _buildFriends()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: FilledButton.icon(
                onPressed: _selectedFriendIds.isEmpty || _isSending
                    ? null
                    : _sendInvites,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _selectedFriendIds.isEmpty
                      ? 'Select friends'
                      : 'Send invite (${_selectedFriendIds.length})',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriends() {
    return widget.friends.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load your friends.',
                style: TextStyle(color: VelvetNoir.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: widget.onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
      data: (friends) {
        if (friends.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Add friends to send room invites inside MixVy.',
                textAlign: TextAlign.center,
                style: TextStyle(color: VelvetNoir.onSurfaceVariant),
              ),
            ),
          );
        }

        final allSelected =
            friends.every((friend) => _selectedFriendIds.contains(friend.id));

        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    if (allSelected) {
                      _selectedFriendIds.clear();
                    } else {
                      _selectedFriendIds
                        ..clear()
                        ..addAll(friends.map((friend) => friend.id));
                    }
                  });
                },
                child: Text(allSelected ? 'Clear all' : 'Select all'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  final selected = _selectedFriendIds.contains(friend.id);
                  final avatarUrl = resolveAvatarUrl(
                    directAvatarUrl: friend.avatarUrl,
                  );

                  return CheckboxListTile(
                    value: selected,
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selectedFriendIds.add(friend.id);
                        } else {
                          _selectedFriendIds.remove(friend.id);
                        }
                      });
                    },
                    secondary: SafeNetworkAvatar(
                      radius: 20,
                      avatarUrl: avatarUrl,
                      fallbackText: friend.username.isEmpty
                          ? '?'
                          : friend.username[0].toUpperCase(),
                    ),
                    title: Text(
                      friend.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
