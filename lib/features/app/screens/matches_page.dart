// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/widgets/club_background.dart';
import 'package:mixvy/features/matching/providers/matching_providers.dart';
import 'package:mixvy/features/matching/models/match_model.dart';
import 'package:mixvy/shared/providers/auth_providers.dart';

class MatchesPage extends ConsumerStatefulWidget {
  const MatchesPage({super.key});
  @override
  ConsumerState<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends ConsumerState<MatchesPage> {
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Generate matches on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateMatches();
    });
  }

  Future<void> _generateMatches() async {
    if (_isGenerating) return;

    setState(() => _isGenerating = true);

    try {
      final service = ref.read(matchServiceProvider);
      final result = await service.generateMatches();

      if (mounted && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Matches generated!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating matches: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _handleLike(String matchUserId) async {
    try {
      final service = ref.read(matchServiceProvider);
      final result = await service.likeUser(matchUserId);

      if (mounted && result['success'] == true) {
        if (result['isMutualLike'] == true) {
          // Show match dialog
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('ðŸŽ‰ It\'s a Match!'),
              content: const Text('You both liked each other!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Awesome!'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Like sent! â¤ï¸'),
              duration: Duration(seconds: 1),
            ),
          );
        }
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
    }
  }

  Future<void> _handlePass(String matchUserId) async {
    try {
      final service = ref.read(matchServiceProvider);
      await service.passUser(matchUserId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Riverpod provider for reactive auth state
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    // Watch generated matches stream
    final matchesAsync = ref.watch(generatedMatchesProvider);

    // Show loading while auth is initializing
    if (authState.isLoading) {
      return ClubBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Matches'),
            backgroundColor: Colors.transparent,
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Handle unauthenticated state
    if (user == null) {
      return ClubBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Matches'),
            backgroundColor: Colors.transparent,
          ),
          body: const Center(
            child: Text('Please log in to view matches'),
          ),
        ),
      );
    }

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Matches'),
          backgroundColor: Colors.transparent,
          actions: [
            if (_isGenerating)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _generateMatches,
                tooltip: 'Generate new matches',
              ),
          ],
        ),
        body: matchesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading matches: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _generateMatches,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
          data: (matches) {
            if (matches.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_outline,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No matches yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap refresh to find new people!',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _generateMatches,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Find Matches'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: matches.length,
              itemBuilder: (ctx, i) {
                final match = matches[i];
                return _MatchCard(
                  match: match,
                  onLike: () => _handleLike(match.matchUserId),
                  onPass: () => _handlePass(match.matchUserId),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Match card widget with swipe actions
class _MatchCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onLike;
  final VoidCallback onPass;

  const _MatchCard({
    required this.match,
    required this.onLike,
    required this.onPass,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile image
          if (match.photoUrl != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                match.photoUrl!,
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  height: 300,
                  color: Colors.grey[300],
                  child: const Icon(Icons.person, size: 80),
                ),
              ),
            )
          else
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Icons.person, size: 80, color: Colors.grey),
              ),
            ),

          // User info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        match.displayName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${match.score.toInt()}% Match',
                        style: const TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (match.age != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${match.age} years old',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (match.bio != null && match.bio!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    match.bio!,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPass,
                    icon: const Icon(Icons.close, color: Colors.grey),
                    label: const Text('Pass'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onLike,
                    icon: const Icon(Icons.favorite, color: Colors.white),
                    label: const Text('Like'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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

