import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/utils/network_image_url.dart';

class ProfileAvatar extends StatelessWidget {
  final String? profilePictureUrl;
  const ProfileAvatar({super.key, this.profilePictureUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeImageUrl = sanitizeNetworkImageUrl(profilePictureUrl);
    return CircleAvatar(
      backgroundColor: theme.colorScheme.surface,
      radius: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        child: safeImageUrl != null
            ? ClipOval(
                child: CachedNetworkImage(
                  imageUrl: safeImageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Icon(
                    Icons.person,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                ),
              )
            : Icon(Icons.person, color: theme.colorScheme.primary, size: 32),
      ),
    );
  }
}
