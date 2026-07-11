import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../providers/discovery_provider.dart';
import '../../../presentation/providers/user_provider.dart';
import '../../../core/theme.dart';
import '../widgets/discovery_filter_sheet.dart';

/// Persistent discovery screen - placeholder for future candidate swiping
class PersistentDiscoveryScreen extends ConsumerWidget {
  const PersistentDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(userProvider);
    final userId = currentUser?.id ?? '';

    if (userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Discover')),
        body: const Center(child: Text('Please log in')),
      );
    }

    final preferencesAsync = ref.watch(discoveryPreferencesProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            onPressed: () => _showFilterSheet(context, ref, userId),
            tooltip: 'Filter Preferences',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfo(context),
            tooltip: 'About Discovery',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_outline,
              size: 64,
              color: VelvetNoir.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              'Discovery Coming Soon',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Browse profiles and discover connections that match your preferences.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 24),
            preferencesAsync.when(
              data: (prefs) => ElevatedButton.icon(
                onPressed: () => _showFilterSheet(context, ref, userId),
                icon: const Icon(Icons.tune),
                label: const Text('Set Preferences'),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error loading preferences'),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VelvetNoir.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: VelvetNoir.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    '✨ New Features Available',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Photo Messaging\n• Online Status\n• Match History\n• Read Receipts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Discovery'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💚 Like — Show interest and start chatting if they like you back'),
            SizedBox(height: 12),
            Text('👋 Pass — Skip to the next profile'),
            SizedBox(height: 12),
            Text('Set your preferences to find people you\'ll connect with.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref, String userId) {
    final preferencesAsync = ref.watch(discoveryPreferencesProvider(userId));

    preferencesAsync.whenData((prefs) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DiscoveryFilterSheet(
          userId: userId,
          preferences: prefs,
          onApply: () {
            unawaited(ref.refresh(discoveryPreferencesProvider(userId)));
          },
        ),
      );
    });
  }
}
