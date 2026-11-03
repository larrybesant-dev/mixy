import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/network_image_url.dart';

Future<void> showProfilePhotoViewer({
  required BuildContext context,
  required String? imageUrl,
  required String displayName,
}) {
  final safeUrl = sanitizeNetworkImageUrl(imageUrl, preferredSize: 1024);
  if (safeUrl == null) {
    return Future<void>.value();
  }

  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xF2000000),
    builder: (dialogContext) {
      return Dialog.fullscreen(
        backgroundColor: const Color(0xFF000000),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: _ProfileViewerImage(
                      imageUrl: safeUrl,
                      displayName: displayName,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  tooltip: 'Close photo',
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ProfileViewerImage extends StatelessWidget {
  const _ProfileViewerImage({
    required this.imageUrl,
    required this.displayName,
  });

  final String imageUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final height = size.height;

    if (imageUrl.startsWith('asset:')) {
      return Image.asset(
        imageUrl.replaceFirst('asset:', ''),
        width: width,
        height: height,
        fit: BoxFit.contain,
        semanticLabel: '$displayName photo',
        errorBuilder: (context, error, stackTrace) => const _PhotoLoadFailure(),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.contain,
      imageBuilder: (context, provider) => Image(
        image: provider,
        width: width,
        height: height,
        fit: BoxFit.contain,
        semanticLabel: '$displayName photo',
      ),
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => const _PhotoLoadFailure(),
    );
  }
}

class _PhotoLoadFailure extends StatelessWidget {
  const _PhotoLoadFailure();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 48),
          SizedBox(height: 12),
          Text('Could not load this photo.'),
        ],
      ),
    );
  }
}
