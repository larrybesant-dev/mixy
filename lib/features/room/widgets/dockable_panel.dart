import 'package:flutter/material.dart';

/// A panel that can be minimized, is optionally detachable, and has a
/// drag-handle title bar — matching the Paltalk/Yahoo Messenger panel style.
class DockablePanel extends StatefulWidget {
  const DockablePanel({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.minWidth = 200.0,
    this.initiallyMinimized = false,
    this.actions = const [],
    this.onDetach,
    this.onMinimizedChanged,
    this.backgroundColor = const Color(0xFF10131A),
    this.headerColor = const Color(0xFF241820),
    this.borderColor = const Color(0x30D4A853),
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final double minWidth;
  final bool initiallyMinimized;
  final List<Widget> actions;

  /// Called when the user clicks the "detach" button. If null, no detach
  /// button is shown.
  final VoidCallback? onDetach;
  final void Function(bool minimized)? onMinimizedChanged;
  final Color backgroundColor;
  final Color headerColor;
  final Color borderColor;

  @override
  State<DockablePanel> createState() => _DockablePanelState();
}

class _DockablePanelState extends State<DockablePanel> {
  late bool _minimized;

  @override
  void initState() {
    super.initState();
    _minimized = widget.initiallyMinimized;
  }

  void _toggleMinimized() {
    setState(() => _minimized = !_minimized);
    widget.onMinimizedChanged?.call(_minimized);
  }

  @override
  Widget build(BuildContext context) {
    const headerHeight = 32.0;
    const npOnVariant = Color(0xFFB09080);
    const npPrimary = Color(0xFFD4A853);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Title bar ──────────────────────────────────────────────────
          GestureDetector(
            onDoubleTap: _toggleMinimized,
            child: Container(
              height: headerHeight,
              decoration: BoxDecoration(
                color: widget.headerColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(8),
                  topRight: const Radius.circular(8),
                  bottomLeft:
                      _minimized ? const Radius.circular(8) : Radius.zero,
                  bottomRight:
                      _minimized ? const Radius.circular(8) : Radius.zero,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: npPrimary, size: 14),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...widget.actions,
                  if (widget.onDetach != null)
                    _HeaderIconButton(
                      tooltip: 'Detach panel',
                      icon: Icons.open_in_new,
                      onTap: widget.onDetach!,
                    ),
                  _HeaderIconButton(
                    tooltip: _minimized ? 'Restore' : 'Minimize',
                    icon: _minimized
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: npOnVariant,
                    onTap: _toggleMinimized,
                  ),
                ],
              ),
            ),
          ),
          // ── Content ────────────────────────────────────────────────────
          if (!_minimized) Expanded(child: widget.child),
        ],
      ),
    );
  }
}

/// Compact icon button for panel title bars.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.color = const Color(0xFFB09080),
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

/// A detached (floating) version of a [DockablePanel]. Rendered inside a
/// Stack and can be repositioned by dragging the title bar.
class FloatingDockablePanel extends StatefulWidget {
  const FloatingDockablePanel({
    super.key,
    required this.title,
    required this.child,
    this.panelId,
    this.position,
    this.size,
    this.minimized,
    this.onMove,
    this.onResize,
    this.onMinimizedChanged,
    this.icon,
    this.initialOffset = const Offset(80, 120),
    this.width = 320.0,
    this.height = 260.0,
    this.onClose,
    this.backgroundColor = const Color(0xFF10131A),
    this.headerColor = const Color(0xFF241820),
    this.borderColor = const Color(0x30D4A853),
    this.actions = const [],
    this.onReattach,
  });

  final String title;
  final Widget child;
  final String? panelId;
  final Offset? position;
  final Size? size;
  final bool? minimized;
  final ValueChanged<Offset>? onMove;
  final ValueChanged<Offset>? onResize;
  final ValueChanged<bool>? onMinimizedChanged;
  final IconData? icon;
  final Offset initialOffset;
  final double width;
  final double height;
  final VoidCallback? onClose;
  final VoidCallback? onReattach;
  final Color backgroundColor;
  final Color headerColor;
  final Color borderColor;
  final List<Widget> actions;

  @override
  State<FloatingDockablePanel> createState() => _FloatingDockablePanelState();
}

class _FloatingDockablePanelState extends State<FloatingDockablePanel> {
  late Offset _position;
  late Size _size;
  late bool _minimized;

  @override
  void initState() {
    super.initState();
    _position = widget.position ?? widget.initialOffset;
    _size = widget.size ?? Size(widget.width, widget.height);
    _minimized = widget.minimized ?? false;
  }

  @override
  void didUpdateWidget(FloatingDockablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != null) _position = widget.position!;
    if (widget.size != null) _size = widget.size!;
    if (widget.minimized != null) _minimized = widget.minimized!;
  }

  void _move(Offset delta) {
    widget.onMove?.call(delta);
    if (widget.position == null) {
      setState(() => _position += delta);
    }
  }

  void _resize(Offset delta) {
    widget.onResize?.call(delta);
    if (widget.size == null) {
      setState(() {
        _size = Size(
          (_size.width + delta.dx).clamp(200.0, 800.0),
          (_size.height + delta.dy).clamp(150.0, 600.0),
        );
      });
    }
  }

  void _setMinimized(bool minimized) {
    widget.onMinimizedChanged?.call(minimized);
    if (widget.minimized == null) {
      setState(() => _minimized = minimized);
    }
  }

  @override
  Widget build(BuildContext context) {
    const npOnVariant = Color(0xFFB09080);
    const npPrimary = Color(0xFFD4A853);
    const headerHeight = 32.0;
    final panelHeight = _minimized
        ? headerHeight
        : (_size.height.isFinite ? _size.height : 260.0);
    final panelId = widget.panelId ?? widget.title;

    return Positioned(
      left: _position.dx.isFinite ? _position.dx : 80.0,
      top: _position.dy.isFinite ? _position.dy : 120.0,
      width: _size.width.isFinite ? _size.width : 320.0,
      height: panelHeight,
      child: Material(
        color: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: widget.borderColor),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    key: ValueKey('floating_panel_header_$panelId'),
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: () => _setMinimized(!_minimized),
                    onPanUpdate: (details) => _move(details.delta),
                    child: Container(
                      height: headerHeight,
                      decoration: BoxDecoration(
                        color: widget.headerColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(8),
                          topRight: const Radius.circular(8),
                          bottomLeft: _minimized
                              ? const Radius.circular(8)
                              : Radius.zero,
                          bottomRight: _minimized
                              ? const Radius.circular(8)
                              : Radius.zero,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.drag_indicator,
                            color: npOnVariant,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: npPrimary, size: 14),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...widget.actions,
                          if (widget.onReattach != null)
                            _HeaderIconButton(
                              tooltip: 'Dock panel',
                              icon: Icons.picture_in_picture_alt,
                              onTap: widget.onReattach!,
                            ),
                          _HeaderIconButton(
                            tooltip: _minimized ? 'Restore' : 'Minimize',
                            icon: _minimized
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            color: npOnVariant,
                            onTap: () => _setMinimized(!_minimized),
                          ),
                          if (widget.onClose != null)
                            _HeaderIconButton(
                              tooltip: 'Close',
                              icon: Icons.close,
                              color: const Color(0xFFFF6E84),
                              onTap: widget.onClose!,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (!_minimized) Expanded(child: widget.child),
                ],
              ),
              if (!_minimized)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    key: ValueKey('floating_panel_resize_$panelId'),
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) => _resize(details.delta),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0x50D4A853),
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: const Icon(
                          Icons.south_east,
                          size: 9,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
