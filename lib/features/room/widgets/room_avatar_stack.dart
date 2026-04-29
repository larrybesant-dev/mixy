import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mixvy/core/theme.dart';

typedef RoomAvatarResolver = AsyncValue<String?> Function(
  WidgetRef ref,
  String userId,
);

/// Overlapping avatar circles for active users.
class RoomAvatarStack extends ConsumerWidget {
  const RoomAvatarStack({
    super.key,
    required this.uids,
    required this.resolveAvatar,
  });

  final List<String> uids;
  final RoomAvatarResolver resolveAvatar;

  static const _avatarSize = 26.0;
  static const _overlap = 16.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = uids.take(4).toList();
    final totalWidth = _avatarSize + (visible.length - 1) * _overlap;

    return SizedBox(
      width: totalWidth,
      height: _avatarSize,
      child: Stack(
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * _overlap,
              child: _RoomAvatarRing(
                uid: visible[i],
                resolveAvatar: resolveAvatar,
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomAvatarRing extends ConsumerWidget {
  const _RoomAvatarRing({required this.uid, required this.resolveAvatar});

  final String uid;
  final RoomAvatarResolver resolveAvatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarAsync = resolveAvatar(ref, uid);

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: VelvetNoir.surface, width: 1.5),
        color: VelvetNoir.surfaceHighest,
      ),
      child: ClipOval(
        child: avatarAsync.when(
          data: (url) => url != null
              ? CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      Container(color: VelvetNoir.surfaceHighest),
                )
              : Container(color: VelvetNoir.surfaceHighest),
          loading: () => Container(color: VelvetNoir.surfaceHighest),
          error: (_, _) => Container(color: VelvetNoir.surfaceHighest),
        ),
      ),
    );
  }
}
