String? sanitizeNetworkImageUrl(String? rawUrl) {
  final trimmed = rawUrl?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  // Handle local assets prefixed with 'asset:'
  if (trimmed.startsWith('asset:')) {
    return trimmed;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    return null;
  }

  switch (uri.scheme.toLowerCase()) {
    case 'http':
    case 'https':
      // Normalize Google user-content avatar URLs.  The transformation
      // parameters after '=' (e.g. '=s96-c') are unstable: they can change
      // format, expire, or return a WebP variant that Chrome's ImageDecoder
      // rejects on Flutter Web.  Strip them and force a stable 128-px JPEG.
      if (uri.host.endsWith('googleusercontent.com')) {
        final eqIdx = trimmed.indexOf('=');
        final base = eqIdx >= 0 ? trimmed.substring(0, eqIdx) : trimmed;
        return '$base=s128-c';
      }
      return trimmed;
    default:
      return null;
  }
}
