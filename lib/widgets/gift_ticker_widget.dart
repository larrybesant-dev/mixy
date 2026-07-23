import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/room/providers/room_gift_provider.dart';
import '../core/theme.dart';

/// Displays recent gift events at the bottom of the screen.
/// Shows sender name, gift emoji, and recipient name.
class GiftTickerWidget extends ConsumerWidget {
  final String roomId;
  final double bottomPadding;

  const GiftTickerWidget({
    Key? key,
    required this.roomId,
    this.bottomPadding = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giftsAsync = ref.watch(roomGiftFeedProvider(roomId));

    return giftsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return const SizedBox.shrink();
        }

        // Show latest 3-5 gifts
        final recentGifts = events.take(5).toList();

        return Positioned(
          bottom: bottomPadding,
          left: 12,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final gift in recentGifts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _GiftTickerItem(gift: gift),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _GiftTickerItem extends StatefulWidget {
  final RoomGiftEvent gift;

  const _GiftTickerItem({required this.gift});

  @override
  State<_GiftTickerItem> createState() => _GiftTickerItemState();
}

class _GiftTickerItemState extends State<_GiftTickerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 5), vsync: this);

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInExpo),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VelvetNoir.gold, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.gift.emoji,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '${widget.gift.senderName} sent ${widget.gift.emoji} to ${widget.gift.receiverName ?? 'guest'}',
                style: const TextStyle(
                  color: VelvetNoir.onSurface,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
