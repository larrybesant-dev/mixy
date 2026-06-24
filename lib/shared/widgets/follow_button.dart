import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/profile_controller.dart';

class FollowButton extends ConsumerStatefulWidget {
  final String currentUserId;
  final String targetUserId;
  final VoidCallback? onFollowStateChanged;

  const FollowButton({
    super.key,
    required this.currentUserId,
    required this.targetUserId,
    this.onFollowStateChanged,
  });

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _isLoading = false;

  Future<void> _toggleFollow(bool isCurrentlyFollowing) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final controller = ref.read(profileControllerProvider);

      if (isCurrentlyFollowing) {
        await controller.unfollowUser(
            widget.currentUserId, widget.targetUserId);
      } else {
        await controller.followUser(widget.currentUserId, widget.targetUserId);
      }

      widget.onFollowStateChanged?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                isCurrentlyFollowing ? 'Unfollowed successfully' : 'Following'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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
    final isFollowingAsync = ref.watch(isFollowingProvider({
      'followerId': widget.currentUserId,
      'followingId': widget.targetUserId,
    }));

    return isFollowingAsync.when(
      data: (isFollowing) {
        return ElevatedButton.icon(
          onPressed: _isLoading ? null : () => _toggleFollow(isFollowing),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isFollowing ? Colors.grey[700] : Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Icon(isFollowing ? Icons.person_remove : Icons.person_add),
          label: Text(isFollowing ? 'Unfollow' : 'Follow'),
        );
      },
      loading: () => ElevatedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Loading'),
      ),
      error: (_, __) => ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.error),
        label: const Text('Error'),
      ),
    );
  }
}
