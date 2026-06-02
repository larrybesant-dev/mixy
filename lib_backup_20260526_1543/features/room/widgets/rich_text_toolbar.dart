import 'package:flutter/material.dart';

/// Parses a simple markup string into a [TextSpan] tree.
///
/// Supported tags (case-insensitive, nestable):
///   [b]...[/b]         — bold
///   [i]...[/i]         — italic
///   [u]...[/u]         — underline
///   [s]...[/s]         — strikethrough
///   [color=RRGGBB]...[/color]  — hex colour (6 chars, no #)
///   [color=#RRGGBB]...[/color] — hex colour with leading #
///
/// All other text is rendered as plain text with the provided base style.
class RichTextParser {
  RichTextParser._();

  // Regex that matches an opening or closing tag.
  static final _tagRe = RegExp(
    r'\[(/?)(?:(b|i|u|s)|color(?:=([#0-9a-fA-F]{6,7}))?)\]',
    caseSensitive: false,
  );

  static TextSpan parse(String input, {required TextStyle baseStyle}) {
    final spans = <TextSpan>[];
    _parseSegment(input, 0, baseStyle, spans);
    return TextSpan(children: spans);
  }

  static void _parseSegment(
    String input,
    int depth,
    TextStyle style,
    List<TextSpan> out,
  ) {
    final matches = _tagRe.allMatches(input).toList();
    int cursor = 0;

    for (final match in matches) {
      // Plain text before this tag
      if (match.start > cursor) {
        out.add(
          TextSpan(text: input.substring(cursor, match.start), style: style),
        );
      }
      cursor = match.end;

      final isClose = match.group(1) == '/';
      final tagName = match.group(2)?.toLowerCase();
      final colorValue = match.group(3);

      if (isClose) {
        // Closing tag — the recursive call will have already consumed content.
        // We just advance cursor and return to parent.
        return;
      }

      // Determine the style to apply for this tag.
      TextStyle nextStyle = style;
      String closingTag;
      if (tagName == 'b') {
        nextStyle = style.copyWith(fontWeight: FontWeight.bold);
        closingTag = '[/b]';
      } else if (tagName == 'i') {
        nextStyle = style.copyWith(fontStyle: FontStyle.italic);
        closingTag = '[/i]';
      } else if (tagName == 'u') {
        nextStyle = style.copyWith(decoration: TextDecoration.underline);
        closingTag = '[/u]';
      } else if (tagName == 's') {
        nextStyle = style.copyWith(decoration: TextDecoration.lineThrough);
        closingTag = '[/s]';
      } else {
        // [color=...] tag
        if (colorValue != null) {
          final hex =
              colorValue.startsWith('#') ? colorValue.substring(1) : colorValue;
          final parsed = int.tryParse(hex, radix: 16);
          if (parsed != null) {
            nextStyle = style.copyWith(color: Color(0xFF000000 | parsed));
          }
        }
        closingTag = '[/color]';
      }

      // Find the matching closing tag (simple: find the next occurrence).
      final closeIdx = input.indexOf(closingTag, cursor);
      if (closeIdx == -1) {
        // No closing tag — treat rest as styled text.
        final rest = input.substring(cursor);
        final inner = <TextSpan>[];
        _parseSegment(rest, depth + 1, nextStyle, inner);
        out.addAll(inner);
        cursor = input.length;
        break;
      }

      final innerText = input.substring(cursor, closeIdx);
      if (innerText.isNotEmpty) {
        final inner = <TextSpan>[];
        _parseSegment(innerText, depth + 1, nextStyle, inner);
        out.addAll(inner);
      }
      cursor = closeIdx + closingTag.length;
    }

    // Remaining plain text after last tag.
    if (cursor < input.length) {
      out.add(TextSpan(text: input.substring(cursor), style: style));
    }
  }
}

/// A text formatter toolbar widget for the chat input.
/// Wraps selected text in bold/italic/colour markup.
class RichTextToolbar extends StatefulWidget {
  const RichTextToolbar({
    super.key,
    required this.controller,
    this.onChanged,
    this.pendingColorHex,
    this.onPendingColorChanged,
  });

  final TextEditingController controller;
  final VoidCallback? onChanged;
  final String? pendingColorHex;
  final ValueChanged<String?>? onPendingColorChanged;

  @override
  State<RichTextToolbar> createState() => _RichTextToolbarState();
}

class _RichTextToolbarState extends State<RichTextToolbar> {
  // Saved selection so we can apply markup even after the TextField loses focus
  // (common on web: clicking a toolbar button defocuses the TextField first).
  TextSelection? _savedSelection;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(RichTextToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    final sel = widget.controller.selection;
    // Save any valid, non-collapsed selection (i.e. actual text highlighted).
    if (sel.isValid && !sel.isCollapsed) {
      _savedSelection = sel;
    }
  }

  void _wrapSelection(String open, String close) {
    final controller = widget.controller;
    final text = controller.text;
    // Use the current selection if valid; fall back to the last saved one.
    TextSelection sel = controller.selection;
    if (!sel.isValid || sel.start < 0) {
      sel = _savedSelection ?? const TextSelection.collapsed(offset: 0);
    }
    // Clamp to text length in case the text changed while selection was stale.
    int start = sel.start.clamp(0, text.length);
    int end = sel.end.clamp(start, text.length);
    // If nothing is selected and there is text, wrap ALL of the text.
    if (start == end && text.isNotEmpty) {
      start = 0;
      end = text.length;
    }
    final selected = text.substring(start, end);
    final newText = text.replaceRange(start, end, '$open$selected$close');
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selected.isEmpty
            ? start + open.length
            : start + open.length + selected.length + close.length,
      ),
    );
    _savedSelection = null;
    widget.onChanged?.call();
  }

  void _insertColor(String colorHex) {
    final controller = widget.controller;
    TextSelection sel = controller.selection;
    if (!sel.isValid || sel.start < 0) {
      sel = _savedSelection ?? const TextSelection.collapsed(offset: 0);
    }
    if (!sel.isCollapsed) {
      _wrapSelection('[color=$colorHex]', '[/color]');
      widget.onPendingColorChanged?.call(null);
      return;
    }
    final nextPending = widget.pendingColorHex == colorHex ? null : colorHex;
    widget.onPendingColorChanged?.call(nextPending);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    const npOnVariant = Color(0xFFB09080);
    const npSurfaceHigh = Color(0xFF241820);

    return Container(
      height: 32,
      color: npSurfaceHigh,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ToolBtn(
              label: 'B',
              bold: true,
              tooltip: 'Bold [b]...[/b]',
              onTap: () => _wrapSelection('[b]', '[/b]'),
            ),
            _ToolBtn(
              label: 'I',
              italic: true,
              tooltip: 'Italic [i]...[/i]',
              onTap: () => _wrapSelection('[i]', '[/i]'),
            ),
            _ToolBtn(
              label: 'U',
              underline: true,
              tooltip: 'Underline [u]...[/u]',
              onTap: () => _wrapSelection('[u]', '[/u]'),
            ),
            const SizedBox(width: 4),
            // Quick colour swatches
            for (final hex in _presetColors)
              _ColorSwatch(
                hex: hex,
                selected: widget.pendingColorHex == hex,
                onTap: () => _insertColor(hex),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8),
              child: Text(
                widget.pendingColorHex == null
                    ? 'Rich text'
                    : 'Next text #${widget.pendingColorHex}',
                style: TextStyle(color: npOnVariant, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _presetColors = [
    'FF6E84', // blush
    'FFA040', // orange
    'D4A853', // champagne gold
    'C45E7A', // rose wine
    'F2EBE0', // warm cream
    '4CAF50', // green
  ];
}

class _ToolBtn extends StatelessWidget {
  const _ToolBtn({
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline ? TextDecoration.underline : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.hex,
    required this.onTap,
    this.selected = false,
  });
  final String hex;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = Color(0xFF000000 | int.parse(hex, radix: 16));
    return Tooltip(
      message: '#$hex',
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.25),
              width: selected ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
