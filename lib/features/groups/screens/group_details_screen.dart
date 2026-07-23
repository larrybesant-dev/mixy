import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/layout/app_layout.dart';
import '../models/group_model.dart';
import '../providers/groups_provider.dart';
import '../../feed/models/post_model.dart';
import '../../feed/widgets/post_card.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';

class GroupDetailsScreen extends ConsumerWidget {
  final String groupId;
  final String userId;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupDetailsProvider(groupId));
    final postsAsync = ref.watch(groupPostsProvider(groupId));

    return AppPageScaffold(
      appBar: AppBar(
        title:
            groupAsync.whenOrNull(
              data: (g) => g == null
                  ? null
                  : Text(
                      g.name,
                      style: const TextStyle(
                        color: VelvetNoir.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
            ) ??
            const Text(
              'Group',
              style: TextStyle(
                color: VelvetNoir.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
      ),
      body: AppAsyncValueView(
        value: groupAsync,
        fallbackContext: 'group details',
        isEmpty: (group) => group == null,
        empty: const AppEmptyView(title: 'Group not found'),
        data: (group) {
          final resolvedGroup = group!;

          final isMember = resolvedGroup.isMember(userId);

          return Column(
            children: [
              // Group header banner
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  context.pageHorizontalPadding + 4,
                  16,
                  context.pageHorizontalPadding + 4,
                  20,
                ),
                color: VelvetNoir.surfaceContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolvedGroup.name,
                      style: const TextStyle(
                        color: VelvetNoir.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (resolvedGroup.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        resolvedGroup.description,
                        style: const TextStyle(
                          color: VelvetNoir.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          color: VelvetNoir.onSurfaceVariant,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${resolvedGroup.memberCount} members',
                          style: const TextStyle(
                            color: VelvetNoir.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            if (isMember) {
                              ref
                                  .read(groupsControllerProvider)
                                  .leaveGroup(
                                    groupId: resolvedGroup.id,
                                    userId: userId,
                                  );
                            } else {
                              ref
                                  .read(groupsControllerProvider)
                                  .joinGroup(
                                    groupId: resolvedGroup.id,
                                    userId: userId,
                                  );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMember
                                ? VelvetNoir.surfaceBright
                                : VelvetNoir.primaryDim,
                            foregroundColor: VelvetNoir.onSurface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(isMember ? 'Leave' : 'Join Group'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: VelvetNoir.outlineVariant.withValues(alpha: 0.5),
              ),
              // Posts section label
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pageHorizontalPadding + 4,
                  16,
                  context.pageHorizontalPadding + 4,
                  8,
                ),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Posts',
                    style: TextStyle(
                      color: VelvetNoir.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AppAsyncValueView<List<GroupPost>>(
                  value: postsAsync,
                  fallbackContext: 'posts',
                  isEmpty: (posts) => posts.isEmpty,
                  empty: const AppEmptyView(
                    title: 'No posts in this group yet',
                  ),
                  data: (posts) => ListView.builder(
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
                          likedBy: post.likedBy,
                          createdAt: post.createdAt,
                        ),
                        currentUserId: userId,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}



