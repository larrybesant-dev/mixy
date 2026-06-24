import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../core/design_system/design_constants.dart';
import '../../shared/models/post.dart';
import '../../shared/widgets/skeleton_loaders.dart';
import '../../services/social/social_feed_service.dart';
import 'create_post_dialog.dart';
import '../../core/analytics/analytics_service.dart';
import '../../app/app_routes.dart';

/// Social Feed Page
/// Three-tab Facebook-style feed: Global · Friends · Room Highlights
class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage>
    with SingleTickerProviderStateMixin {
  final SocialFeedService _feedService = SocialFeedService.instance;
  late final TabController _tabController;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
    AnalyticsService.instance.logScreenView(screenName: 'screen_feed');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreatePostDialog() {
    if (_currentUserId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => CreatePostDialog(userId: _currentUserId!),
    );
  }

  void _showComments(Post post) {
    AnalyticsService.instance.logFeedPostCommented(postId: post.id);
    showModalBottomSheet(
      context: context,
      backgroundColor: DesignColors.surfaceDefault,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CommentsSheet(post: post, userId: _currentUserId!),
    );
  }

  void _showTipDialog(Post post) {
    if (_currentUserId == null || _currentUserId == post.userId) return;
    showDialog(
      context: context,
      builder: (ctx) => _TipDialog(
        post: post,
        fromUserId: _currentUserId!,
        feedService: _feedService,
      ),
    );
  }

  Future<void> _toggleLike(Post post) async {
    if (_currentUserId == null) return;
    HapticFeedback.lightImpact();
    await _feedService.toggleLike(post.id, _currentUserId!);
    AnalyticsService.instance.logFeedPostLiked(postId: post.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: DesignColors.surfaceDefault,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'FEED',
          style: TextStyle(
            color: DesignColors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: DesignColors.accent,
          indicatorWeight: 3,
          labelColor: DesignColors.accent,
          unselectedLabelColor: DesignColors.textGray,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.public, size: 16), text: 'Global'),
            Tab(icon: Icon(Icons.group, size: 16), text: 'Friends'),
            Tab(icon: Icon(Icons.live_tv, size: 16), text: 'Rooms'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FeedTab(
            stream: _feedService.getGlobalFeedStream(),
            currentUserId: _currentUserId,
            onLike: _toggleLike,
            onComment: _showComments,
            onTip: _showTipDialog,
            emptyMessage: 'No posts yet — be the first!',
          ),
          _FeedTab(
            stream: _currentUserId != null
                ? _feedService.getFriendsFeedStream(_currentUserId!)
                : const Stream.empty(),
            currentUserId: _currentUserId,
            onLike: _toggleLike,
            onComment: _showComments,
            onTip: _showTipDialog,
            emptyMessage: 'Follow people to see their posts here.',
          ),
          _FeedTab(
            stream: _feedService.getRoomHighlightsFeedStream(),
            currentUserId: _currentUserId,
            onLike: _toggleLike,
            onComment: _showComments,
            onTip: _showTipDialog,
            emptyMessage: 'No room highlights yet.\nGo live and share the moment!',
          ),
        ],
      ),
      floatingActionButton: _NeonPulseFab(
        onTap: _showCreatePostDialog,
      ),
    );
  }
}


// ============================================================
// NEON PULSE FAB
// ============================================================

class _NeonPulseFab extends StatefulWidget {
  final VoidCallback onTap;
  const _NeonPulseFab({required this.onTap});

  @override
  State<_NeonPulseFab> createState() => _NeonPulseFabState();
}

class _NeonPulseFabState extends State<_NeonPulseFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = DesignColors.accent;
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          AnimatedBuilder(
            animation: _scaleAnim,
            builder: (_, __) => Transform.scale(
              scale: _scaleAnim.value,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(
                        alpha: (1.4 - _scaleAnim.value).clamp(0.0, 0.5)),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          // FAB core
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF4A90FF), Color(0xFFFF4D8B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// _FEED TAB — StreamBuilder-powered list for one tab
// ============================================================

class _FeedTab extends StatelessWidget {
  final Stream<List<Post>> stream;
  final String? currentUserId;
  final Future<void> Function(Post) onLike;
  final void Function(Post) onComment;
  final void Function(Post) onTip;
  final String emptyMessage;

  const _FeedTab({
    required this.stream,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onTip,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Post>>(
      stream: stream,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: 4,
            itemBuilder: (_, __) => const SkeletonTile(
              showAvatar: true,
              textLines: 3,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          );
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.feed_outlined,
                      size: 72,
                      color: DesignColors.textGray.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: DesignColors.textGray.withValues(alpha: 0.65),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => Future.delayed(const Duration(milliseconds: 300)),
          color: DesignColors.accent,
          backgroundColor: DesignColors.surfaceLight,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: posts.length,
            itemBuilder: (ctx, i) => _PostCard(
              post: posts[i],
              currentUserId: currentUserId,
              onLike: () => onLike(posts[i]),
              onComment: () => onComment(posts[i]),
              onTip: () => onTip(posts[i]),
            ),
          ),
        );
      },
    );
  }
}
// ============================================================
// POST CARD WIDGET
// ============================================================

class _PostCard extends StatelessWidget {
  final Post post;
  final String? currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onTip;

  const _PostCard({
    required this.post,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onTip,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = currentUserId != null && post.isLikedBy(currentUserId!);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: DesignColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DesignColors.accent.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: DesignColors.accent,
                  backgroundImage: post.userAvatar.isNotEmpty
                      ? NetworkImage(post.userAvatar)
                      : null,
                  child: post.userAvatar.isEmpty
                      ? Text(
                          post.userName.isNotEmpty
                              ? post.userName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: DesignColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(
                          color: DesignColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        post.timeAgo,
                        style: TextStyle(
                          color: DesignColors.textGray.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.type == PostType.roomShare)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: DesignColors.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.live_tv,
                          size: 14,
                          color: DesignColors.secondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: DesignColors.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              post.content,
              style: const TextStyle(
                color: DesignColors.white,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),

          // Reactions bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _EmojiReactionBar(postId: post.id),
          ),

          // Image (if any)
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    height: 200,
                    color: DesignColors.surfaceDefault,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: DesignColors.textGray,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _ActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  label: '${post.likeCount}',
                  color: isLiked ? DesignColors.error : DesignColors.textGray,
                  onTap: onLike,
                ),
                const SizedBox(width: 20),
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: '${post.commentCount}',
                  color: DesignColors.textGray,
                  onTap: onComment,
                ),
                const SizedBox(width: 20),
                _ActionButton(
                  icon: Icons.monetization_on_outlined,
                  label: post.tipCount > 0 ? '${post.tipCount}' : 'Tip',
                  color: DesignColors.gold,
                  onTap: onTip,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: DesignColors.surfaceDefault,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => _PostShareSheet(post: post),
                  ),
                  icon: const Icon(Icons.share_outlined),
                  color: DesignColors.textGray,
                  iconSize: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// COMMENTS SHEET
// ============================================================

class _CommentsSheet extends StatefulWidget {
  final Post post;
  final String? userId;

  const _CommentsSheet({required this.post, required this.userId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final SocialFeedService _feedService = SocialFeedService.instance;
  bool _isSubmitting = false;

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    await _feedService.addComment(
      postId: widget.post.id,
      userId: widget.userId!,
      content: content,
    );

    _commentController.clear();
    setState(() => _isSubmitting = false);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: DesignColors.divider),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(
                    color: DesignColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: DesignColors.textGray),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: _feedService.getCommentsStream(widget.post.id),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: DesignColors.accent),
                  );
                }

                final comments = snapshot.data!;
                if (comments.isEmpty) {
                  return Center(
                    child: Text(
                      'No comments yet',
                      style: TextStyle(
                        color: DesignColors.textGray.withValues(alpha: 0.7),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (ctx, i) => _CommentTile(comment: comments[i]),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: DesignColors.surfaceLight,
              border: Border(
                top: BorderSide(color: DesignColors.divider),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: DesignColors.white),
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: TextStyle(
                        color: DesignColors.textGray.withValues(alpha: 0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: DesignColors.surfaceDefault,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSubmitting ? null : _submitComment,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DesignColors.accent,
                          ),
                        )
                      : const Icon(Icons.send, color: DesignColors.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: DesignColors.accent,
            backgroundImage: comment.userAvatar.isNotEmpty
                ? NetworkImage(comment.userAvatar)
                : null,
            child: comment.userAvatar.isEmpty
                ? Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: DesignColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        color: DesignColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.timeAgo,
                      style: TextStyle(
                        color: DesignColors.textGray.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(
                    color: DesignColors.textLightGray,
                    fontSize: 14,
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

// ============================================================
// TIP DIALOG
// ============================================================

class _TipDialog extends StatefulWidget {
  final Post post;
  final String fromUserId;
  final SocialFeedService feedService;

  const _TipDialog({
    required this.post,
    required this.fromUserId,
    required this.feedService,
  });

  @override
  State<_TipDialog> createState() => _TipDialogState();
}

class _TipDialogState extends State<_TipDialog> {
  int _selectedAmount = 10;
  bool _isSending = false;

  final List<int> _tipAmounts = [5, 10, 25, 50, 100];

  Future<void> _sendTip() async {
    setState(() => _isSending = true);

    final success = await widget.feedService.tipPost(
      postId: widget.post.id,
      fromUserId: widget.fromUserId,
      coinAmount: _selectedAmount,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Sent $_selectedAmount coins to ${widget.post.userName}!'
                : 'Failed to send tip. Check your balance.',
          ),
          backgroundColor: success ? DesignColors.success : DesignColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DesignColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monetization_on,
              color: DesignColors.gold,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'Tip ${widget.post.userName}',
              style: const TextStyle(
                color: DesignColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tipAmounts.map((amount) {
                final isSelected = amount == _selectedAmount;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAmount = amount),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? DesignColors.gold
                          : DesignColors.surfaceDefault,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? DesignColors.gold
                            : DesignColors.divider,
                      ),
                    ),
                    child: Text(
                      '$amount',
                      style: TextStyle(
                        color: isSelected
                            ? DesignColors.surfaceDefault
                            : DesignColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: DesignColors.textGray),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSending ? null : _sendTip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignColors.gold,
                    foregroundColor: DesignColors.surfaceDefault,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Send $_selectedAmount'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// EMOJI REACTION BAR  (local state — 4 emoji reactions per post)
// ============================================================

class _EmojiReactionBar extends StatefulWidget {
  final String postId;
  const _EmojiReactionBar({required this.postId});

  @override
  State<_EmojiReactionBar> createState() => _EmojiReactionBarState();
}

class _EmojiReactionBarState extends State<_EmojiReactionBar> {
  static const _emojis = ['❤️', '😂', '🔥', '😮'];
  final Map<String, int> _counts = {'❤️': 0, '😂': 0, '🔥': 0, '😮': 0};
  String? _mine;

  void _react(String emoji) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_mine == emoji) {
        // un-react
        _counts[emoji] = (_counts[emoji]! - 1).clamp(0, 9999);
        _mine = null;
      } else {
        if (_mine != null) _counts[_mine!] = (_counts[_mine!]! - 1).clamp(0, 9999);
        _counts[emoji] = _counts[emoji]! + 1;
        _mine = emoji;
      }
    });
    AnalyticsService.instance.logEvent(
      name: 'feed_reaction_tapped',
      parameters: {'post_id': widget.postId, 'emoji': emoji},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: _emojis.map((e) {
          final count = _counts[e]!;
          final isActive = _mine == e;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _react(e),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? DesignColors.accent.withValues(alpha: 0.18)
                      : DesignColors.surfaceDefault,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive
                        ? DesignColors.accent.withValues(alpha: 0.55)
                        : DesignColors.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e, style: const TextStyle(fontSize: 14)),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style: TextStyle(
                          color: isActive
                              ? DesignColors.accent
                              : DesignColors.textGray,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// POST SHARE SHEET  (Share to Chat / Share to Room)
// ============================================================

class _PostShareSheet extends StatelessWidget {
  final Post post;
  const _PostShareSheet({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Share Post',
                style: TextStyle(
                  color: DesignColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: DesignColors.textGray),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ShareOption(
            icon: Icons.chat_bubble_outline,
            color: const Color(0xFF4A90FF),
            label: 'Share to Chat',
            subtitle: 'Send this post to a friend',
            onTap: () {
              Navigator.pop(context);
              AnalyticsService.instance.logEvent(
                name: 'feed_share_to_chat',
                parameters: {'post_id': post.id},
              );
              Navigator.pushNamed(context, AppRoutes.chats);
            },
          ),
          const SizedBox(height: 10),
          _ShareOption(
            icon: Icons.graphic_eq,
            color: const Color(0xFFFF4D8B),
            label: 'Share to Room',
            subtitle: 'Drop this post into a live room',
            onTap: () {
              Navigator.pop(context);
              AnalyticsService.instance.logEvent(
                name: 'feed_share_to_room',
                parameters: {'post_id': post.id},
              );
              Navigator.pushNamed(context, AppRoutes.discoverRooms);
            },
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: DesignColors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          color:
                              DesignColors.textGray.withValues(alpha: 0.7),
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
