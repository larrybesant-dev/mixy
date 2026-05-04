import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dockable_panel.dart';

/// Paltalk/Yahoo Messenger-style three-panel room layout.
///
/// Desktop (width ≥ 900):  [Cams panel] | [Chat panel] | [Users panel]
/// Mobile: bottom-nav tabs switching between Cams / Chat / Users.
///
/// Each panel can be minimized via its title-bar chevron.
/// The cams panel and users panel are resizable by drag on desktop.
/// Private message (whisper) windows float as draggable overlays.
class RoomPanelLayout extends ConsumerStatefulWidget {
  const RoomPanelLayout({
    super.key,
    required this.camPanel,
    required this.chatPanel,
    required this.usersPanel,
    required this.overlays,
    this.initialCamWidth = 300.0,
    this.initialUsersWidth = 200.0,
    this.minCamWidth = 160.0,
    this.minUsersWidth = 160.0,
    this.minChatWidth = 200.0,
  });

  /// The camera grid widget (CameraWall or equivalent).
  final Widget camPanel;

  /// The chat message + input widget.
  final Widget chatPanel;

  /// The user roster widget.
  final Widget usersPanel;

  /// Additional widgets rendered above all panels (floating windows, toasts,
  /// gift overlays, etc.). These are rendered in a top-level Stack.
  final List<Widget> overlays;

  final double initialCamWidth;
  final double initialUsersWidth;
  final double minCamWidth;
  final double minUsersWidth;
  final double minChatWidth;

  @override
  ConsumerState<RoomPanelLayout> createState() => _RoomPanelLayoutState();
}

class _RoomPanelLayoutState extends ConsumerState<RoomPanelLayout> {
  late double _camWidth;
  late double _usersWidth;
  bool _camMinimized = false;
  bool _usersMinimized = false;
  int _mobileTab = 0; // 0=cams, 1=chat, 2=users

  @override
  void initState() {
    super.initState();
    _camWidth = widget.initialCamWidth;
    _usersWidth = widget.initialUsersWidth;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        if (isDesktop) {
          return _buildDesktopLayout(constraints);
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  // ── Desktop: three resizable columns ─────────────────────────────────────

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    const dividerWidth = 4.0;
    final totalWidth = constraints.maxWidth;

    // Clamp widths so panels don't overflow
    final effectiveCamWidth = _camMinimized
        ? 0.0
        : _camWidth.clamp(
            widget.minCamWidth,
            totalWidth -
                widget.minChatWidth -
                widget.minUsersWidth -
                dividerWidth * 2,
          );
    final effectiveUsersWidth = _usersMinimized
        ? 0.0
        : _usersWidth.clamp(
            widget.minUsersWidth,
            totalWidth -
                effectiveCamWidth -
                widget.minChatWidth -
                dividerWidth * 2,
          );

    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cams panel ───────────────────────────────────────────────
            if (!_camMinimized)
              SizedBox(
                width: effectiveCamWidth,
                child: DockablePanel(
                  title: 'Camera Windows',
                  icon: Icons.videocam_outlined,
                  initiallyMinimized: false,
                  onMinimizedChanged: (min) =>
                      setState(() => _camMinimized = min),
                  child: widget.camPanel,
                ),
              )
            else
              _MinimizedTabButton(
                icon: Icons.videocam_outlined,
                label: 'Cams',
                onRestore: () => setState(() => _camMinimized = false),
              ),

            // ── Cam resize handle ─────────────────────────────────────────
            if (!_camMinimized)
              _ResizeDivider(
                onDelta: (delta) {
                  setState(() {
                    _camWidth = (_camWidth + delta).clamp(
                      widget.minCamWidth,
                      totalWidth -
                          widget.minChatWidth -
                          effectiveUsersWidth -
                          dividerWidth * 2,
                    );
                  });
                },
              ),

            // ── Chat panel (takes remaining width) ───────────────────────
            Expanded(
              child: DockablePanel(
                title: 'Room Chat',
                icon: Icons.chat_bubble_outline,
                child: widget.chatPanel,
              ),
            ),

            // ── Users resize handle ─────────────────────────────────────
            if (!_usersMinimized)
              _ResizeDivider(
                onDelta: (delta) {
                  setState(() {
                    _usersWidth = (_usersWidth - delta).clamp(
                      widget.minUsersWidth,
                      totalWidth -
                          effectiveCamWidth -
                          widget.minChatWidth -
                          dividerWidth * 2,
                    );
                  });
                },
              ),

            // ── Users panel ───────────────────────────────────────────────
            if (!_usersMinimized)
              SizedBox(
                width: effectiveUsersWidth,
                child: DockablePanel(
                  title: 'Users',
                  icon: Icons.people_outline,
                  initiallyMinimized: false,
                  onMinimizedChanged: (min) =>
                      setState(() => _usersMinimized = min),
                  child: widget.usersPanel,
                ),
              )
            else
              _MinimizedTabButton(
                icon: Icons.people_outline,
                label: 'Users',
                onRestore: () => setState(() => _usersMinimized = false),
              ),
          ],
        ),
        // ── Floating windows / overlays ──────────────────────────────────
        ...widget.overlays,
      ],
    );
  }

  // ── Mobile: tabbed layout ─────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    const npSurfaceHigh = Color(0xFF241820);
    const npPrimary = Color(0xFFD4A853);
    const npOnVariant = Color(0xFFB09080);

    final tabs = [
      (icon: Icons.videocam_outlined, label: 'Cams'),
      (icon: Icons.chat_bubble_outline, label: 'Chat'),
      (icon: Icons.people_outline, label: 'Users'),
    ];

    return Stack(
      children: [
        Column(
          children: [
            // Content area
            Expanded(
              child: IndexedStack(
                index: _mobileTab,
                children: [
                  widget.camPanel,
                  widget.chatPanel,
                  widget.usersPanel,
                ],
              ),
            ),
            // Bottom nav bar (Paltalk-style tab strip)
            Container(
              height: 48,
              color: npSurfaceHigh,
              child: Row(
                children: List.generate(tabs.length, (i) {
                  final tab = tabs[i];
                  final selected = _mobileTab == i;
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _mobileTab = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            tab.icon,
                            size: 18,
                            color: selected ? npPrimary : npOnVariant,
                          ),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: selected ? npPrimary : npOnVariant,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        // Floating windows / overlays
        ...widget.overlays,
      ],
    );
  }
}

// ── Internal helper widgets ──────────────────────────────────────────────────

/// A thin draggable divider for resizing two adjacent panels.
class _ResizeDivider extends StatelessWidget {
  const _ResizeDivider({required this.onDelta});

  final void Function(double delta) onDelta;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) => onDelta(details.delta.dx),
        child: Container(width: 4, color: const Color(0x20D4A853)),
      ),
    );
  }
}

/// A collapsed-panel tab button for the desktop layout.
class _MinimizedTabButton extends StatelessWidget {
  const _MinimizedTabButton({
    required this.icon,
    required this.label,
    required this.onRestore,
  });

  final IconData icon;
  final String label;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Restore $label panel',
      child: InkWell(
        onTap: onRestore,
        child: Container(
          width: 24,
          color: const Color(0xFF241820),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: const Color(0xFFD4A853)),
              const SizedBox(height: 8),
              RotatedBox(
                quarterTurns: 1,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
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
