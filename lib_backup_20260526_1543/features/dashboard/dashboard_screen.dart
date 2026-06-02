import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

// ... (Rest of your DashboardScreen class stays here)

// Ensure this helper is correctly defined in your file:
class _StatsBarWidget extends StatelessWidget {
  final AsyncValue<int> onlineAsync;
  final AsyncValue<int> liveAsync;
  final bool isFirstSession;

  const _StatsBarWidget({
    required this.onlineAsync,
    required this.liveAsync,
  });

  @override
  Widget build(BuildContext context) {
    // Accessing .value directly in Riverpod 2.5.1
    final online = onlineAsync.value ?? 0;
    final live = liveAsync.value ?? 0;
    final isLoading = onlineAsync.isLoading || liveAsync.isLoading;

    final onlineLabel = isLoading
        ? '...'
        : (online <= 0 || isFirstSession)
            ? 'new'
            : (online >= 500 ? '500+' : '$online');
    final liveLabel = isLoading
        ? '...'
        : (live <= 0 || isFirstSession)
            ? 'fresh'
            : '$live';

    return Row(
      children: [
        _StatPill(
          dot: VelvetNoir.primary,
          label: onlineLabel,
          tooltip: 'online now',
          onTap: () => context.go('/home/search'),
        ),
        const SizedBox(width: 6),
        _StatPill(
          dot: VelvetNoir.liveGlow,
          label: liveLabel,
          tooltip: 'live rooms',
          onTap: () => context.go('/rooms'),
        ),
      ],
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Stat Pill used by _StatsBarWidget
// ─────────────────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final Color dot;
  final String label;
  final String tooltip;
  final VoidCallback? onTap;

  const _StatPill({
    required this.dot,
    required this.label,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: VelvetNoir.surfaceHigh,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: VelvetNoir.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: VelvetNoir.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
