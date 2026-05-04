import 'package:flutter/material.dart';

/// A beautiful, reusable empty-state component.
/// Shows a large emoji/icon, heading, subtitle, and optional CTA button.
class FeedEmptyState extends StatelessWidget {
  final String message;
  final String? emoji;
  final String? heading;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FeedEmptyState({
    required this.message,
    this.emoji,
    this.heading,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            if (heading != null)
              Text(
                heading!,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
