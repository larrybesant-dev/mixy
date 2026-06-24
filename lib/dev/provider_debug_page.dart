/// lib/dev/provider_debug_page.dart
///
/// Developer-only screen that shows realtime state of key Riverpod providers.
/// Access: Navigate to AppRoutes.providerDebug (/dev/providers) or via
/// the hidden 5-tap gesture on the Settings page version number.
///
/// Add more providers to _sections as the app grows.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/providers/all_providers.dart';

class ProviderDebugPage extends ConsumerWidget {
  const ProviderDebugPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final authState   = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1520),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🔬 Provider Debug',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            Text(
              'DEV ONLY — realtime provider state',
              style: TextStyle(color: Color(0xFF8A99B0), fontSize: 11),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProviderTile(
            name: 'authStateProvider',
            state: authState,
            valueDisplay: (v) => v?.uid ?? 'null — not signed in',
          ),
          _ProviderTile(
            name: 'currentUserProvider',
            state: currentUser,
            valueDisplay: (v) => v == null
                ? 'null'
                : '${v.displayName ?? v.id} (id: ${v.id})',
          ),
          const _SectionHeader('FollowButton Fix Validation'),
          const _InfoTile(
            info: 'isFollowingProvider now uses String key (targetUserId) '
                'via social_graph_providers.dart. Map<String,String> keys '
                'have been removed. No more permanent loading state.',
          ),
          const _SectionHeader('Friend System'),
          const _InfoTile(
            info: 'friendStatusProvider(userId) watches FriendService.'
                'watchFriendStatus — returns none/sent/received/friends.',
          ),
          const _SectionHeader('Stability Notes'),
          const _InfoTile(
            info: 'See lib/shared/providers/social_graph_providers.dart '
                'for the stable isFollowingProvider(String targetUserId).',
          ),
          const _InfoTile(
            info: 'See lib/shared/providers/friend_request_provider.dart '
                'for friendStatusProvider, friendServiceProvider, etc.',
          ),
        ],
      ),
    );
  }
}

// ── Internal widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF4A90FF),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final String info;
  const _InfoTile({required this.info});

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF0F1520),
        margin: const EdgeInsets.only(bottom: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(info,
              style: const TextStyle(color: Color(0xFF8A99B0), fontSize: 12)),
        ),
      );
}

class _ProviderTile<T> extends StatelessWidget {
  final String name;
  final AsyncValue<T> state;
  final String Function(T) valueDisplay;

  const _ProviderTile({
    required this.name,
    required this.state,
    required this.valueDisplay,
  });

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel, detail) = switch (state) {
      AsyncLoading() => (
          const Color(0xFFFFB700),
          'LOADING',
          'Waiting for data...',
        ),
      AsyncError(:final error) => (
          Colors.redAccent,
          'ERROR',
          error.toString(),
        ),
      AsyncData(:final value) => (
          const Color(0xFF00E5CC),
          'DATA',
          valueDisplay(value),
        ),
    };

    return Card(
      color: const Color(0xFF0F1520),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace')),
            ),
          ]),
          const SizedBox(height: 6),
          Text(detail,
              style: const TextStyle(
                  color: Color(0xFF8A99B0), fontSize: 11)),
        ]),
      ),
    );
  }
}

