import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/app_layout.dart';
import '../../../core/firestore/firestore_error_utils.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../../../shared/widgets/async_state_view.dart';

import '../../feed/widgets/post_card.dart';
import '../providers/post_comments_providers.dart';

// ── Screen ───────────────────────────────────────────────────────────────────

class PostCommentsScreen extends ConsumerStatefulWidget {
  PostCommentsScreen({super.key, required this.postId, FirebaseAuth? auth})
    : auth = auth ?? FirebaseAuth.instance;

  final String postId;
  final FirebaseAuth auth;

  @override
  ConsumerState<PostCommentsScreen> createState() => _PostCommentsScreenState();
}

class _PostCommentsScreenState extends ConsumerState<PostCommentsScreen> {
  late final TextEditingController _ctrl;
  late final ScrollController _scroll;
  bool _clearScheduled = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _scroll = ScrollController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final user = widget.auth.currentUser;
    if (user == null) return;

    try {
      final now = FieldValue.serverTimestamp();
      final postRef = ref
          .read(firestoreProvider)
          .collection('posts')
          .doc(widget.postId);

      await postRef.collection('comments').add({
        'authorId': user.uid,
        'authorName': user.displayName ?? 'User',
        'authorAvatarUrl': user.photoURL,
        'text': text,
        'createdAt': now,
      });

      if (!_clearScheduled) {
        _clearScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ctrl.clear();
          _clearScheduled = false;
        });
      }

      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   if (_scroll.hasClients) {
      //     _scroll.animateTo(
      //       _scroll.position.maxScrollExtent,
      //       duration: const Duration(milliseconds: 300),
      //       curve: Curves.easeOut,
      //     );
      //   }
      // });
    } finally {
      // if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDocProvider(widget.postId));
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final currentUser = widget.auth.currentUser;

    return AppPageScaffold(
      appBar: AppBar(title: const Text('Comments')),
      body: Column(
        children: [
          // Post preview
          postAsync.when(
            data: (post) => post == null
                ? const SizedBox.shrink()
                : PostCard(post: post, currentUserId: currentUser?.uid ?? ''),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const Divider(height: 1),
          // Comment list
          Expanded(
            child: commentsAsync.when(
              data: (comments) {
                if (comments.isEmpty) {
                  return const AppEmptyView(
                    title: 'No comments yet',
                    message: 'Be the first to comment.',
                    icon: Icons.comment_bank_outlined,
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  itemCount: comments.length,
                  itemBuilder: (ctx, i) => _CommentTile(comment: comments[i]),
                );
              },
              loading: () => const AppLoadingView(label: 'Loading comments'),
              error: (e, _) => AppErrorView(
                error: friendlyFirestoreMessage(e, fallbackContext: 'comments'),
                fallbackContext: 'Unable to load comments.',
              ),
            ),
          ),
          // Input bar
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: context.pageHorizontalPadding,
                right: context.pageHorizontalPadding,
                top: 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                        hintText: 'Add a comment…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      maxLines: 1,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _submitComment,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final PostCommentEntry comment;

  @override
  Widget build(BuildContext context) {
    final initial = comment.authorName.isNotEmpty
        ? comment.authorName[0].toUpperCase()
        : '?';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: comment.authorAvatarUrl != null
                ? NetworkImage(comment.authorAvatarUrl!)
                : null,
            child: comment.authorAvatarUrl == null ? Text(initial) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _fmt(comment.createdAt),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.text),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
