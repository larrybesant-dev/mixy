import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:mixvy/core/theme.dart';

class RoomAvatarStack extends StatelessWidget {
  const RoomAvatarStack({
    super.key,
    required this.uids,
    this.avatarUrls = const [],
  });

  final List<String> uids;
  final List<String> avatarUrls;

  static const _avatarSize = 26.0;
  static const _overlap = 16.0;

  @override
  Widget build(BuildContext context) {
    // Combine explicit URLs with UIDs (fallback)
    final count = math.min(uids.length, 4);
    final totalWidth = _avatarSize + (count - 1) * _overlap;

    return SizedBox(
      width: totalWidth,
      height: _avatarSize,
      child: Stack(
        children: [
          for (int i = 0; i < count; i++)
            Positioned(
              left: i * _overlap,
              child: _RoomAvatarRing(
                uid: uids[i],
                url: i < avatarUrls.length ? avatarUrls[i] : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _RoomAvatarRing extends StatelessWidget {
  const _RoomAvatarRing({required this.uid, this.url});

  final String uid;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: VelvetNoir.surface, width: 1.5),
        color: VelvetNoir.surfaceHighest,
      ),
      child: ClipOval(
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (___, __, _) =>
                    Container(color: VelvetNoir.surfaceHighest),
              )
            : Container(color: VelvetNoir.surfaceHighest),
      ),
    );
  }
}



