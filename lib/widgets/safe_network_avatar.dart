import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/utils/network_image_url.dart';

/// Drop-in replacement for `CircleAvatar(backgroundImage: CachedNetworkImageProvider(...))`.
///
/// Uses [CachedNetworkImage] with a proper `errorWidget` so that broken,
/// expired, or format-incompatible URLs (common with Google avatar links on
/// Flutter Web) degrade gracefully instead of throwing an `EncodingError`.
///
/// The [avatarUrl] is passed through [sanitizeNetworkImageUrl], which also
/// normalises Google user-content URLs to a stable 128-px JPEG variant.
class SafeNetworkAvatar extends StatelessWidget {
  const SafeNetworkAvatar({
    super.key,
    required this.radius,
    this.avatarUrl,
    this.fallbackText,
    this.backgroundColor,
    this.fallbackTextStyle,
  });

  final double radius;
  final String? avatarUrl;

  /// First character to show when the image is absent or fails.
  /// Falls back to a person icon when null.
  final String? fallbackText;

  final Color? backgroundColor;
  final TextStyle? fallbackTextStyle;

  Widget _fallback(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ??
          Theme.of(context).colorScheme.surfaceContainerHighest,
      child: fallbackText != null
          ? Text(fallbackText!, style: fallbackTextStyle)
          : Icon(
              Icons.person,
              size: radius,
              color: Theme.of(context).colorScheme.primary,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeUrl = sanitizeNetworkImageUrl(avatarUrl);
    if (safeUrl == null) return _fallback(context);

    // Handle local assets
    if (safeUrl.startsWith('asset:')) {
      final assetPath = safeUrl.replaceFirst('asset:', '');
      return ClipOval(
        child: Image.asset(
          assetPath,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(context),
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: safeUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => _fallback(context),
        errorWidget: (context, url, error) => _fallback(context),
      ),
    );
  }
}



