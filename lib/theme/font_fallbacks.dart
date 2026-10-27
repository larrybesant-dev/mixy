import 'package:flutter/material.dart';

// Font fallback list for emoji and symbol support
// Note: Only include fonts where all necessary weights (Regular, Bold) are available
const List<String> mixvyFontFamilyFallback = [
  'NotoSans',
  'NotoEmoji',
  'NotoColorEmoji',
  'NotoSansSymbols',
  'NotoSansSymbols2',
  'Segoe UI Emoji',
  'Apple Color Emoji',
];

TextStyle withMixvyFontFallback(TextStyle style) {
  return style.copyWith(fontFamilyFallback: mixvyFontFamilyFallback);
}
