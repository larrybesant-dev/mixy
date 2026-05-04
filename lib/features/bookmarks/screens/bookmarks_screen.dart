import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/features/auth/controllers/auth_controller.dart';
import '../../../core/layout/app_layout.dart';
import '../providers/bookmark_provider.dart';
import '../../feed/models/post_model.dart';
import '../../feed/widgets/post_card.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';

class BookmarksScreen extends ConsumerWidget {
  final String userId;

  const BookmarksScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(bookmarkedPostsProvider(userId));
    final viewerId = ref.watch(authControllerProvider).uid ?? '';

    return AppPageScaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: AppAsyncValueView<List<Map<String, dynamic>>>(
        value: bookmarksAsync,
        fallbackContext: 'bookmarks',
        isEmpty: (posts) => posts.isEmpty,
        empty: const AppEmptyView(
          icon: Icons.bookmark_outline,
          title: 'No bookmarks yet',
          message: 'Save posts to view them later.',
        ),
        data: (posts) => ListView.separated(
          padding: EdgeInsets.fromLTRB(0, 8, 0, context.sectionSpacing * 3),
          itemCount: posts.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final raw = posts[index];
            final id = raw['id'] as String? ?? '';
            final post = PostModel.fromDoc(id, raw);
            return Stack(
              children: [
                PostCard(post: post, currentUserId: viewerId),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _BookmarkRemoveButton(
                    userId: userId,
                    bookmarkId: raw['bookmarkId'] as String? ?? '',
                    bookmarkController: ref.read(bookmarkControllerProvider),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BookmarkRemoveButton extends StatelessWidget {
  final String userId;
  final String bookmarkId;
  final BookmarkController bookmarkController;

  const _BookmarkRemoveButton({
    required this.userId,
    required this.bookmarkId,
    required this.bookmarkController,
  });

  @override
  Widget build(BuildContext context) {
    if (bookmarkId.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: IconButton(
        icon: const Icon(Icons.bookmark, color: Colors.blue),
        tooltip: 'Remove bookmark',
        onPressed: () => bookmarkController.removeBookmark(
          userId: userId,
          bookmarkId: bookmarkId,
        ),
      ),
    );
  }
}
