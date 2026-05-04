import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_layout.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/guest_auth_gate.dart';
import '../controllers/messaging_search_controller.dart';
import '../providers/messaging_provider.dart';

class NewMessageScreen extends StatelessWidget {
  final String userId;
  final String username;
  final String? avatarUrl;

  const NewMessageScreen({
    super.key,
    required this.userId,
    required this.username,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(title: const Text('New message')),
      body: NewMessagePaneView(
        userId: userId,
        username: username,
        avatarUrl: avatarUrl,
        showHeader: false,
      ),
    );
  }
}

class NewMessagePaneView extends ConsumerStatefulWidget {
  final String userId;
  final String username;
  final String? avatarUrl;
  final bool showHeader;

  const NewMessagePaneView({
    super.key,
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.showHeader = true,
  });

  @override
  ConsumerState<NewMessagePaneView> createState() => _NewMessagePaneViewState();
}

class _NewMessagePaneViewState extends ConsumerState<NewMessagePaneView> {
  static const int _minSearchChars = 3;

  late TextEditingController _searchController;
  late MessagingSearchController _messagingSearchController;
  List<Map<String, String>> _searchResults = [];
  bool _isSearching = false;
  bool _isStartingConversation = false;

  String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _messagingSearchController = MessagingSearchController(
      minChars: _minSearchChars,
      debounceDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _messagingSearchController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startConversation(
    String otherUserId,
    String otherUsername,
    String? otherAvatarUrl,
  ) async {
    final allowed = await GuestAuthGate.requireConversationStart(context, ref);
    if (!allowed) return;

    if (_isStartingConversation) {
      return;
    }

    setState(() {
      _isStartingConversation = true;
    });

    try {
      final conversationId = await ref
          .read(messagingControllerProvider)
          .createDirectConversation(
            userId1: widget.userId,
            user1Name: widget.username,
            user1AvatarUrl: widget.avatarUrl,
            userId2: otherUserId,
            user2Name: otherUsername,
            user2AvatarUrl: otherAvatarUrl,
          );

      if (!mounted) return;
      context.go('/chat/$conversationId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting conversation: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isStartingConversation = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    _messagingSearchController.search<Map<String, String>>(
      query: query,
      fetch: _searchUsers,
      onThresholdNotMet: () {
        if (!mounted) return;
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      },
      onSearchStart: () {
        if (!mounted) return;
        setState(() {
          _isSearching = true;
        });
      },
      onSearchSuccess: (matches) {
        if (!mounted) return;
        setState(() {
          _searchResults = matches;
          _isSearching = false;
        });
      },
      onSearchError: (error) {
        if (!mounted) return;
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search failed: $error')));
      },
    );
  }

  Future<List<Map<String, String>>> _searchUsers(String query) async {
    final normalized = query.trim();
    final snapshot = await ref.read(firestoreProvider)
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: normalized)
        .where('username', isLessThanOrEqualTo: '$normalized\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs
        .where((doc) => doc.id != widget.userId)
        .map((doc) {
          final data = doc.data();
          final username = _asString(data['username']);
          return {
            'id': doc.id,
            'name': username.isEmpty ? doc.id : username,
            'avatar': _asString(data['avatarUrl']),
          };
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showHeader)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.pageHorizontalPadding,
              24,
              context.pageHorizontalPadding,
              8,
            ),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'New message',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.all(context.pageHorizontalPadding),
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: VelvetNoir.secondary,
                  child: const Icon(Icons.group_add, color: Colors.white),
                ),
                title: const Text('Create Group Chat'),
                onTap: () => context.push('/create-group-chat'),
              ),
              const Divider(),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search people (min $_minSearchChars chars)...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ],
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: AppLoadingView(label: 'Searching users'),
          )
        else if (_searchController.text.trim().length < _minSearchChars)
          const Padding(
            padding: EdgeInsets.all(16),
            child: AppEmptyView(
              title: 'Type at least 3 characters',
              icon: Icons.short_text_rounded,
            ),
          )
        else if (_searchResults.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: AppEmptyView(
              title: 'No users found',
              icon: Icons.search_off_rounded,
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: _searchResults.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final userId = (user['id'] ?? '').trim();
                final userName = (user['name'] ?? '').trim();
                final safeName = userName.isEmpty ? 'Unknown' : userName;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(safeName.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(safeName),
                  trailing: _isStartingConversation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: userId.isEmpty || _isStartingConversation
                      ? null
                      : () => _startConversation(
                          userId,
                          safeName,
                          user['avatar'],
                        ),
                );
              },
            ),
          ),
      ],
    );
  }
}
