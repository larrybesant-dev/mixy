import 'network_image_url.dart';

String? resolveAvatarUrl({
  String? directAvatarUrl,
  String? persistedProfileAvatarUrl,
  String? authPhotoUrl,
  String? cachedAvatarUrl,
  int preferredSize = 128,
}) {
  for (final candidate in <String?>[
    directAvatarUrl,
    persistedProfileAvatarUrl,
    authPhotoUrl,
    cachedAvatarUrl,
  ]) {
    final resolved = sanitizeNetworkImageUrl(
      candidate,
      preferredSize: preferredSize,
    );
    if (resolved != null) return resolved;
  }
  return null;
}
