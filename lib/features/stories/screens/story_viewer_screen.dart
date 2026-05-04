import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../widgets/safe_network_avatar.dart';
import '../providers/story_provider.dart';

/// Full-screen story viewer for a single user's stories.
///
/// Route: /stories/:userId
/// Stories auto-advance every 5 seconds. Tap left/right halves to go
/// prev/next. Each story is marked viewed on display.
class StoryViewerScreen extends ConsumerStatefulWidget {
  final String userId;

  const StoryViewerScreen({super.key, required this.userId});

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _storyDuration = Duration(seconds: 5);

  int _index = 0;
  Timer? _timer;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController =
        AnimationController(vsync: this, duration: _storyDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _advance();
            }
          });
    _startProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _startProgress() {
    _progressController.forward(from: 0);
  }

  void _advance() {
    final stories = ref.read(myStoriesProvider(widget.userId)).asData?.value;
    if (stories == null) return;
    if (_index < stories.length - 1) {
      setState(() => _index++);
      _markCurrentViewed(stories[_index]);
      _startProgress();
    } else {
      if (mounted) context.pop();
    }
  }

  void _goBack() {
    if (_index > 0) {
      setState(() => _index--);
      _startProgress();
    }
  }

  void _markCurrentViewed(Story story) {
    final viewerId = FirebaseAuth.instance.currentUser?.uid;
    if (viewerId == null) return;
    if (story.viewedBy.contains(viewerId)) return;
    ref
        .read(storyControllerProvider)
        .markStoryAsViewed(
          userId: widget.userId,
          storyId: story.id,
          viewerId: viewerId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final storiesAsync = ref.watch(myStoriesProvider(widget.userId));

    return AppPageScaffold(
      backgroundColor: Colors.black,
      safeArea: false,
      body: storiesAsync.when(
        loading: () => const AppLoadingView(label: 'Loading stories'),
        error: (e, _) =>
            AppErrorView(error: e, fallbackContext: 'Unable to load stories.'),
        data: (stories) {
          final active = stories
              .where((s) => !s.isDeleted && !s.isExpired)
              .toList();
          if (active.isEmpty) {
            return const AppEmptyView(
              title: 'No stories to show',
              icon: Icons.auto_stories_outlined,
            );
          }

          // Clamp index in case stories list changed
          if (_index >= active.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.pop();
            });
            return const SizedBox.shrink();
          }

          final story = active[_index];

          // Mark viewed on first display
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _markCurrentViewed(story);
          });

          return Stack(
            fit: StackFit.expand,
            children: [
              // Background — image or solid colour
              _StoryBackground(story: story),

              // Text content overlay (when no image/video)
              if (story.imageUrl == null &&
                  story.videoUrl == null &&
                  story.content != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      story.content!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                      ),
                    ),
                  ),
                ),

              // Caption over image
              if (story.imageUrl != null && story.content != null)
                Positioned(
                  bottom: 80,
                  left: 16,
                  right: 16,
                  child: Text(
                    story.content!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
                    ),
                  ),
                ),

              // Tap areas for prev/next
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _goBack,
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _advance,
                      child: const ColoredBox(color: Colors.transparent),
                    ),
                  ),
                ],
              ),

              // Top bar: progress bars + avatar + close
              SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress bars
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: List.generate(active.length, (i) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: _ProgressBar(
                                filled: i < _index,
                                active: i == _index,
                                animation: _progressController,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // Author row
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          SafeNetworkAvatar(
                            radius: 18,
                            avatarUrl: story.userAvatarUrl,
                            backgroundColor: Colors.white24,
                            fallbackTextStyle: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              story.username,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            _formatAge(story.createdAt),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatAge(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StoryBackground extends StatelessWidget {
  final Story story;
  const _StoryBackground({required this.story});

  @override
  Widget build(BuildContext context) {
    if (story.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: story.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (_, _) => const ColoredBox(color: Colors.black),
        errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final bool filled;
  final bool active;
  final AnimationController animation;

  const _ProgressBar({
    required this.filled,
    required this.active,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2.5,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: filled
              ? 1.0
              : active
              ? null
              : 0.0,
          child: active
              ? AnimatedBuilder(
                  animation: animation,
                  builder: (_, _) => FractionallySizedBox(
                    widthFactor: animation.value,
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                )
              : Container(
                  height: 2.5,
                  color: filled ? Colors.white : Colors.transparent,
                ),
        ),
      ),
    );
  }
}
