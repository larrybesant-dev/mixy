import 'package:flutter/material.dart';

import '../../core/theme.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.title = 'Loading your space',
    this.subtitle = 'Getting everything ready for you.',
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VelvetNoir.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 110,
            height: 14,
            decoration: BoxDecoration(
              color: VelvetNoir.onSurface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: VelvetNoir.onSurface.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 220,
            height: 12,
            decoration: BoxDecoration(
              color: VelvetNoir.onSurface.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: VelvetNoir.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: VelvetNoir.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.onCta,
    this.icon = Icons.auto_awesome_rounded,
  });

  final String title;
  final String message;
  final String ctaLabel;
  final VoidCallback onCta;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VelvetNoir.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: VelvetNoir.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: VelvetNoir.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: VelvetNoir.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onCta,
            style: FilledButton.styleFrom(
              backgroundColor: VelvetNoir.primary,
              foregroundColor: Colors.black,
            ),
            child: Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.onCta,
  });

  final String title;
  final String message;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VelvetNoir.secondary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.wifi_tethering_error_rounded,
            color: VelvetNoir.secondary,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: VelvetNoir.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: VelvetNoir.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onCta,
            style: OutlinedButton.styleFrom(
              foregroundColor: VelvetNoir.primary,
              side: const BorderSide(color: VelvetNoir.primary),
            ),
            child: Text(ctaLabel),
          ),
        ],
      ),
    );
  }
}



