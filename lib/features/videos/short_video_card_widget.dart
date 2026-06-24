import 'package:flutter/material.dart';
import '../../core/design_system/design_constants.dart';
import '../../services/social/short_video_service.dart';

/// Full-viewport short video card. Used inside a vertical PageView.
/// Displays a thumbnail/placeholder, overlay controls, and metadata.
class ShortVideoCardWidget extends StatelessWidget {
  final ShortVideo video;
  final bool isActive;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onProfile;
  final VoidCallback onShare;

  const ShortVideoCardWidget({
    super.key,
    required this.video,
    required this.isActive,
    required this.isLiked,
    required this.onLike,
    required this.onProfile,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video / thumbnail layer
        _buildVideoLayer(),
        // Dark gradient at bottom for text legibility
        _buildBottomGradient(),
        // Right-side action rail
        Positioned(
          right: 12,
          bottom: 120,
          child: _buildActionRail(),
        ),
        // Bottom metadata
        Positioned(
          left: 16,
          right: 80,
          bottom: 24,
          child: _buildMetadata(),
        ),
      ],
    );
  }

  // ── Layers ─────────────────────────────────────────────────────────────────

  Widget _buildVideoLayer() {
    // When a real video player is available, swap Image.network for it.
    // For now we display the thumbnail or a tinted placeholder.
    if (video.thumbnailUrl != null) {
      return Image.network(
        video.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: DesignColors.background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_outline,
              size: 72, color: DesignColors.textGray.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            video.userName ?? 'User',
            style: const TextStyle(color: DesignColors.textGray, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomGradient() {
    return const Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 280,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
      ),
    );
  }

  // ── Action rail ────────────────────────────────────────────────────────────

  Widget _buildActionRail() {
    return Column(
      children: [
        // Avatar
        GestureDetector(
          onTap: onProfile,
          child: CircleAvatar(
            radius: 24,
            backgroundColor: DesignColors.surfaceLight,
            backgroundImage: video.userAvatar != null
                ? NetworkImage(video.userAvatar!)
                : null,
            child: video.userAvatar == null
                ? Text(
                    (video.userName ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: DesignColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 20),
        // Like
        _ActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: _formatCount(video.likeCount),
          color: isLiked ? Colors.redAccent : Colors.white,
          onTap: onLike,
        ),
        const SizedBox(height: 16),
        // Comment (navigate to detail)
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          label: _formatCount(video.commentCount),
          color: Colors.white,
          onTap: () {}, // Comment sheet can be added
        ),
        const SizedBox(height: 16),
        // Share
        _ActionButton(
          icon: Icons.share_outlined,
          label: _formatCount(video.shareCount),
          color: Colors.white,
          onTap: onShare,
        ),
      ],
    );
  }

  // ── Metadata ───────────────────────────────────────────────────────────────

  Widget _buildMetadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onProfile,
          child: Text(
            '@${video.userName ?? 'user'}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        if (video.caption != null) ...[
          const SizedBox(height: 4),
          Text(
            video.caption!,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (video.tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: video.tags
                .take(3)
                .map((t) => Text('#$t',
                    style: const TextStyle(
                        color: DesignColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)))
                .toList(),
          ),
        ],
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30,
              shadows: const [Shadow(color: Colors.black26, blurRadius: 4)]),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 4)])),
        ],
      ),
    );
  }
}
