import 'package:flutter/material.dart';

/// Enhanced profile completion progress indicator with visual breakdown.
/// Shows both overall progress and which categories need attention.
class ProfileProgressIndicator extends StatelessWidget {
  final double strength; // 0.0 to 1.0
  final int completedItems;
  final int totalItems;
  final bool isLoading;
  final VoidCallback onSave;

  const ProfileProgressIndicator({
    super.key,
    required this.strength,
    required this.completedItems,
    required this.totalItems,
    required this.isLoading,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (strength * 100).round();
    final theme = Theme.of(context);
    
    // Determine color based on progress
    Color getProgressColor() {
      if (percentage >= 80) return const Color(0xFF4CAF50); // Green
      if (percentage >= 50) return const Color(0xFFFFC107); // Amber
      return const Color(0xFFEF5350); // Red
    }

    final progressColor = getProgressColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with progress percentage
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile readiness',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedItems of $totalItems essentials completed',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: progressColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$percentage%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar with gradient
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: strength,
              minHeight: 8,
              backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 12),
          // Helper text & save button
          Row(
            children: [
              Expanded(
                child: Text(
                  strength >= 1.0
                      ? '✨ Profile complete! You can still refine anytime.'
                      : percentage >= 50
                          ? 'Keep filling out fields to improve discoverability.'
                          : 'Add more details to complete your profile.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isLoading ? null : onSave,
                icon: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
