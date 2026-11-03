import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_layout.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../theme/after_dark_theme.dart';

class AfterDarkSafetyScreen extends StatelessWidget {
  const AfterDarkSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      backgroundColor: EmberDark.surface,
      appBar: AppBar(
        backgroundColor: EmberDark.surface,
        foregroundColor: EmberDark.onSurface,
        title: const Text('After Dark Safety'),
      ),
      body: ListView(
        padding: EdgeInsets.all(context.pageHorizontalPadding),
        children: [
          _SafetyCard(
            icon: Icons.verified_user_outlined,
            title: 'Your current verification',
            message:
                'After Dark currently uses explicit 18+ consent, account authentication, and a private PIN. Government-ID verification is not active until a vetted provider is configured.',
          ),
          const SizedBox(height: 12),
          const _SafetyCard(
            icon: Icons.handshake_outlined,
            title: 'Consent is mandatory',
            message:
                'Never share content involving coercion, non-consensual activity, exploitation, or anyone under 18. Consent can be withdrawn at any time.',
          ),
          const SizedBox(height: 12),
          const _SafetyCard(
            icon: Icons.no_photography_outlined,
            title: 'Protect private content',
            message:
                'Do not capture, save, repost, or distribute private subscriber content without clear permission from everyone shown.',
          ),
          const SizedBox(height: 12),
          const _SafetyCard(
            icon: Icons.report_outlined,
            title: 'Report unsafe content',
            message:
                'Use the flag beside subscriber-only updates. For immediate account or safety concerns, contact support. Reports are reviewed without notifying the reported creator who submitted them.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => context.push('/support'),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Contact support'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push('/legal/terms'),
            icon: const Icon(Icons.gavel_outlined),
            label: const Text('Review terms and content rules'),
          ),
        ],
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EmberDark.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EmberDark.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: EmberDark.secondary, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: EmberDark.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: EmberDark.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
