import 'package:flutter/material.dart';

// Font fallback list for emoji and symbol support
// Note: Only include fonts where all necessary weights (Regular, Bold) are available
const List<String> mixvyFontFamilyFallback = [
  'NotoColorEmoji',     // For color emoji support
  'NotoSansSymbols',    // For unicode symbols
  'NotoSansSymbols2',   // Extended symbols
  'Segoe UI Emoji',     // Windows fallback
  'Apple Color Emoji',  // iOS fallback
];

TextStyle withMixvyFontFallback(TextStyle style) {
  return style.copyWith(fontFamilyFallback: mixvyFontFamilyFallback);
}



