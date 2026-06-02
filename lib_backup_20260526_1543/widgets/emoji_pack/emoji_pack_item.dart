enum EmojiCategory {
  flirty,
  party,
  meme,
  romantic,
  gesture;

  String get label => switch (this) {
        EmojiCategory.flirty => '😏 Flirty',
        EmojiCategory.party => '🎉 Party',
        EmojiCategory.meme => '😂 Meme',
        EmojiCategory.romantic => '💕 Romantic',
        EmojiCategory.gesture => '🙌 Gestures',
      };

  /// Categories that require adult mode to be enabled.
  bool get isAdultOnly =>
      this == EmojiCategory.flirty || this == EmojiCategory.meme;
}

class EmojiPackItem {
  final String id;
  final String name;
  final EmojiCategory category;
  final List<String> tags;

  /// Asset path (`assets/emojis/…`).
  /// Null when this item is a live GIF — use [gifQuery] instead.
  final String? path;

  /// Tenor search query used to load a live GIF at runtime.
  /// Non-null only when [isGif] is true.
  final String? gifQuery;

  /// Whether this item is loaded as a live GIF via Tenor.
  final bool isGif;

  const EmojiPackItem({
    required this.id,
    required this.name,
    required this.category,
    required this.tags,
    this.path,
    this.gifQuery,
    this.isGif = false,
  }) : assert(
          isGif ? gifQuery != null : path != null,
          'Provide path for asset items and gifQuery for GIF items.',
        );

  bool get isAsset => !isGif;
  bool get isAdultOnly => category.isAdultOnly;

  // ── message encoding ──────────────────────────────────────────────────────

  static const _prefix = '__emoji__:';

  /// Encodes this item so it can be stored as a chat message `content` value.
  /// GIF items encode the query so the receiver can re-fetch the URL.
  String get messageContent =>
      isGif ? '${_prefix}gif:${gifQuery!}' : '$_prefix${path!}';

  /// Returns `true` when a message `content` string was produced by
  /// [messageContent].
  static bool isEmojiContent(String content) => content.startsWith(_prefix);

  /// Returns `(isGif, pathOrQuery)` from encoded content.
  static (bool isGif, String value) decodeContent(String content) {
    final raw = content.substring(_prefix.length);
    if (raw.startsWith('gif:')) return (true, raw.substring(4));
    return (false, raw);
  }
}
