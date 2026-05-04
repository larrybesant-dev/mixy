import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trending_provider.dart';
import '../../feed/models/post_model.dart';
import '../../feed/widgets/post_card.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../widgets/brand_ui_kit.dart';

class TrendingScreen extends ConsumerStatefulWidget {
  const TrendingScreen({super.key});

  @override
  ConsumerState<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends ConsumerState<TrendingScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppPageScaffold(
        appBar: AppBar(
          title: const MixvyAppBarLogo(fontSize: 20),
          bottom: const TabBar(
            indicatorColor: VelvetNoir.primary,
            labelColor: VelvetNoir.primary,
            unselectedLabelColor: VelvetNoir.onSurfaceVariant,
            indicatorWeight: 2,
            tabs: [
              Tab(text: 'Posts'),
              Tab(text: 'Hashtags'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildTrendingPosts(), _buildTrendingHashtags()],
        ),
      ),
    );
  }

  Widget _buildTrendingPosts() {
    final postsAsync = ref.watch(trendingPostsProvider);

    return AppAsyncValueView<List<TrendingPost>>(
      value: postsAsync,
      fallbackContext: 'trending posts',
      isEmpty: (posts) => posts.isEmpty,
      empty: const AppEmptyView(
        icon: Icons.local_fire_department_outlined,
        title: 'No trending posts yet',
        message: 'Trending content will appear here once posts gain momentum.',
      ),
      data: (posts) => ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 80),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
          return PostCard(
            post: PostModel(
              id: post.id,
              userId: post.authorId,
              text: post.content,
              authorName: post.authorName,
              authorAvatarUrl: post.authorAvatarUrl,
              likeCount: post.likeCount,
              commentCount: post.commentCount,
              createdAt: post.createdAt,
            ),
            currentUserId: uid,
          );
        },
      ),
    );
  }

  Widget _buildTrendingHashtags() {
    // Snapshot the current time once so the provider key stays stable
    // for the lifetime of the widget tree (avoids rebuilding on every frame).
    final now = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final hashtagsAsync = ref.watch(trendingHashtagsProvider(now));

    return AppAsyncValueView<List<Map<String, dynamic>>>(
      value: hashtagsAsync,
      fallbackContext: 'hashtags',
      isEmpty: (hashtags) => hashtags.isEmpty,
      empty: const AppEmptyView(
        icon: Icons.tag_outlined,
        title: 'No trending hashtags yet',
        message:
            'Popular hashtags will appear here when conversations build up.',
      ),
      data: (hashtags) {
        return ListView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: context.pageHorizontalPadding,
            vertical: 12,
          ),
          itemCount: hashtags.length,
          itemBuilder: (context, index) {
            final tag = hashtags[index];
            final rank = index + 1;
            return GestureDetector(
              onTap: () {
                final hashtag = tag['hashtag'];
                if (hashtag is String) _showHashtagPosts(hashtag);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: VelvetNoir.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: VelvetNoir.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: VelvetNoir.primaryDim.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#$rank',
                        style: const TextStyle(
                          color: VelvetNoir.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${tag['hashtag']}',
                            style: const TextStyle(
                              color: VelvetNoir.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${tag['postCount']} posts',
                            style: const TextStyle(
                              color: VelvetNoir.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: VelvetNoir.onSurfaceVariant,
                      size: 18,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showHashtagPosts(String hashtag) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetNoir.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          return Consumer(
            builder: (ctx, ref, _) {
              final postsAsync = ref.watch(hashtagPostsProvider(hashtag));
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: VelvetNoir.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ShaderMask(
                    shaderCallback: (rect) =>
                        VelvetNoir.primaryGradient.createShader(rect),
                    blendMode: BlendMode.srcIn,
                    child: Text(
                      '#$hashtag',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AppAsyncValueView<List<TrendingPost>>(
                      value: postsAsync,
                      fallbackContext: 'hashtag posts',
                      isEmpty: (posts) => posts.isEmpty,
                      empty: const AppEmptyView(
                        icon: Icons.forum_outlined,
                        title: 'No posts with this hashtag',
                      ),
                      data: (posts) {
                        final uid =
                            FirebaseAuth.instance.currentUser?.uid ?? '';
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final post = posts[index];
                            return PostCard(
                              post: PostModel(
                                id: post.id,
                                userId: post.authorId,
                                text: post.content,
                                authorName: post.authorName,
                                authorAvatarUrl: post.authorAvatarUrl,
                                likeCount: post.likeCount,
                                commentCount: post.commentCount,
                                createdAt: post.createdAt,
                              ),
                              currentUserId: uid,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
