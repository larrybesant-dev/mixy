import 'package:flutter/material.dart';

class RoomTile extends StatelessWidget {
  final String roomName;
  final VoidCallback? onTap;

  const RoomTile({required this.roomName, this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      title: Text(
        roomName,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: theme.colorScheme.surface,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 18,
        color: theme.colorScheme.primary,
      ),
    );
  }
}



