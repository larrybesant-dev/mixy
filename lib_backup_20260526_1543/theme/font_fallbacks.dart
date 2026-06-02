import 'package:flutter/material.dart';

const List<String> mixvyFontFamilyFallback = [
  'NotoColorEmoji',
  'NotoSans',
  'NotoSansSymbols',
  'NotoSansSymbols2',
  'Segoe UI Emoji',
  'Apple Color Emoji',
  'Noto Emoji',
];

TextStyle withMixvyFontFallback(TextStyle style) {
  return style.copyWith(fontFamilyFallback: mixvyFontFamilyFallback);
}
