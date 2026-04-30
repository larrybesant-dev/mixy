import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../presentation/providers/user_provider.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/guest_auth_gate.dart';
import '../providers/messaging_provider.dart';
import 'chat_screen.dart';

/// A minimal standalone screen used when a whisper pop-out window is opened
/// on web. It resolves (or creates) the DM conversation with [targetUserId]
/// and then embeds `ChatScreen` in a bare scaffold (no app drawer/shell).
class WhisperPopoutScreen extends ConsumerStatefulWidget {
  const WhisperPopoutScreen({super.key, required this.targetUserId});

  final String targetUserId;

  @override
  ConsumerState<WhisperPopoutScreen> createState() =>
      _WhisperPopoutScreenState();
}

class _WhisperPopoutScreenState extends ConsumerState<WhisperPopoutScreen> {
  String? _conversationId;
  String? _currentUserId;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _resolve();
      }
    });
  }

  Future<void> _resolve() async {
    try {
      final allowed =
          await GuestAuthGate.requireConversationStart(context, ref);
      if (!allowed) {
        if (mounted) {
          setState(() {
            _error = 'Please sign in to start a whisper.';
            _loading = false;
          });
        }
        return;
      }

      final currentUser = ref.read(userProvider);
      if (currentUser == null) throw Exception('Not signed in.');
      final currentUserId = currentUser.id.trim();
      final targetUserId = widget.targetUserId.trim();
      if (currentUserId.isEmpty) throw Exception('Not signed in.');
      if (targetUserId.isEmpty) throw Exception('Missing whisper target user.');
      if (targetUserId == currentUserId) {
        throw Exception('Cannot open a whisper to yourself.');
      }

      final conversationId = await ref
          .read(messagingControllerProvider)
          .createDirectConversation(
            userId1: currentUserId,
            user1Name: currentUser.username,
            user1AvatarUrl: currentUser.avatarUrl,
            userId2: targetUserId,
            user2Name: '',
            user2AvatarUrl: null,
          );
      if (mounted) {
        setState(() {
          _conversationId = conversationId;
          _currentUserId = currentUserId;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppPageScaffold(
        body: AppLoadingView(label: 'Opening whisper'),
      );
    }
    if (_error != null) {
      return AppPageScaffold(
        body: AppErrorView(
          error: _error!,
          fallbackContext: 'Unable to open whisper.',
        ),
      );
    }
    return ChatScreen(
      conversationId: _conversationId!,
      userId: _currentUserId ?? '',
      username: '',
    );
  }
}

