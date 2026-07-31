String roomAvatarInitials(String value, {String fallback = '?'}) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return fallback;
  }

  final parts = normalized
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (parts.length == 1) {
    final single = parts.first;
    return single.length == 1
        ? single.toUpperCase()
        : single.substring(0, 1).toUpperCase();
  }

  final first = parts.first.substring(0, 1).toUpperCase();
  final last = parts.last.substring(0, 1).toUpperCase();
  return '$first$last';
}
