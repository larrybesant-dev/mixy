import 'package:flutter/material.dart';

class FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onPressed;

  const FollowButton({
    required this.isFollowing,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isFollowing ? theme.colorScheme.surface : theme.colorScheme.primary,
        foregroundColor: isFollowing
            ? theme.colorScheme.primary
            : theme.colorScheme.onPrimary,
        side: isFollowing
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: onPressed,
      child: Text(isFollowing ? 'Unfollow' : 'Follow'),
    );
  }
}
