import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../core/utils/network_image_url.dart';

class TrendingUserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const TrendingUserCard({required this.user, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final profilePictureUrl = sanitizeNetworkImageUrl(user.avatarUrl);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.2),
            child: profilePictureUrl == null
                ? const Icon(Icons.person)
                : ClipOval(
                    child: profilePictureUrl.startsWith('asset:')
                        ? Image.asset(
                            profilePictureUrl.replaceFirst('asset:', ''),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: profilePictureUrl,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.person),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            user.username,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${user.coinBalance} coins',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}



