import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/room_theme_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BackgroundPickerSheet
//
// Owner/co-host only UI for changing the live room's visual theme.
// Presented as a modal bottom sheet via [BackgroundPickerSheet.show].
// The caller receives the chosen [RoomTheme] in [onSelect]; it is NOT written
// to Firestore here – that responsibility stays in the controller layer.
// ─────────────────────────────────────────────────────────────────────────────

/// Describes a built-in background preset shown in the picker grid.
class _PresetEntry {
  const _PresetEntry({
    required this.preset,
    required this.label,
    required this.icon,
    required this.gradient,
  });

  final RoomVibePreset preset;
  final String label;
  final IconData icon;
  final List<Color> gradient;
}

const _kPresets = <_PresetEntry>[
  _PresetEntry(
    preset: RoomVibePreset.none,
    label: 'Default',
    icon: Icons.auto_awesome,
    gradient: [Color(0xFF0D0A0C), Color(0xFF1A1520)],
  ),
  _PresetEntry(
    preset: RoomVibePreset.club,
    label: 'Club',
    icon: Icons.local_bar_rounded,
    gradient: [Color(0xFF0A0020), Color(0xFF3D0070)],
  ),
  _PresetEntry(
    preset: RoomVibePreset.lounge,
    label: 'Lounge',
    icon: Icons.weekend_rounded,
    gradient: [Color(0xFF1A0A00), Color(0xFF3D200A)],
  ),
  _PresetEntry(
    preset: RoomVibePreset.neon,
    label: 'Neon',
    icon: Icons.flash_on_rounded,
    gradient: [Color(0xFF001A2E), Color(0xFF00204A)],
  ),
  _PresetEntry(
    preset: RoomVibePreset.hype,
    label: 'Hype',
    icon: Icons.bolt_rounded,
    gradient: [Color(0xFF1A0000), Color(0xFF5C0000)],
  ),
  _PresetEntry(
    preset: RoomVibePreset.space,
    label: 'Space',
    icon: Icons.rocket_launch_rounded,
    gradient: [Color(0xFF000015), Color(0xFF060618)],
  ),
  _PresetEntry(
    preset: RoomVibePreset.ocean,
    label: 'Ocean',
    icon: Icons.waves_rounded,
    gradient: [Color(0xFF001A2E), Color(0xFF003355)],
  ),
];

class BackgroundPickerSheet extends StatefulWidget {
  const BackgroundPickerSheet({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onReset,
  });

  /// Current theme applied to the room (used to show the active selection).
  final RoomTheme current;

  /// Called when the user confirms a new theme. The widget does NOT pop itself;
  /// the parent is expected to call [Navigator.pop] after writing the theme.
  final ValueChanged<RoomTheme> onSelect;

  /// Called when the user taps "Reset to Default".
  final VoidCallback onReset;

  static Future<void> show(
    BuildContext context, {
    required RoomTheme current,
    required ValueChanged<RoomTheme> onSelect,
    required VoidCallback onReset,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BackgroundPickerSheet(
        current: current,
        onSelect: onSelect,
        onReset: onReset,
      ),
    );
  }

  @override
  State<BackgroundPickerSheet> createState() => _BackgroundPickerSheetState();
}

class _BackgroundPickerSheetState extends State<BackgroundPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late RoomTheme _draft;
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _draft = widget.current;
    _tabs = TabController(length: 2, vsync: this);
    if (_draft.backgroundUrl != null) {
      _urlController.text = _draft.backgroundUrl!;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _selectPreset(_PresetEntry entry) {
    setState(() {
      _draft = RoomTheme(
        backgroundUrl: null,
        accentColor: _draft.accentColor,
        vibePreset: entry.preset,
      );
    });
  }

  void _applyCustomUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _draft = _draft.copyWith(
        backgroundUrl: url,
        vibePreset: RoomVibePreset.none,
      );
    });
  }

  void _confirm() {
    widget.onSelect(_draft);
    Navigator.of(context).pop();
  }

  void _reset() {
    widget.onReset();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFF10131A);
    const gold = Color(0xFFD4A853);
    const textMuted = Color(0xFF8E8E9A);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3D4A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.palette_rounded, color: gold, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Room Theme',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabs,
                labelColor: gold,
                unselectedLabelColor: textMuted,
                indicatorColor: gold,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.grid_view_rounded, size: 18),
                    text: 'Presets',
                  ),
                  Tab(
                    icon: Icon(Icons.link_rounded, size: 18),
                    text: 'Custom URL',
                  ),
                ],
              ),
              const Divider(height: 1, color: Color(0xFF2A2D3A)),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    // ── Preset grid ───────────────────────────────────────
                    GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _kPresets.length,
                      itemBuilder: (context, index) {
                        final entry = _kPresets[index];
                        final isSelected = _draft.vibePreset == entry.preset &&
                            !_draft.hasBackground;
                        return GestureDetector(
                          onTap: () => _selectPreset(entry),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: entry.gradient,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected ? gold : const Color(0xFF2A2D3A),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  entry.icon,
                                  color: isSelected ? gold : Colors.white70,
                                  size: 28,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  entry.label,
                                  style: TextStyle(
                                    color: isSelected ? gold : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (isSelected)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      color: gold,
                                      size: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // ── Custom URL tab ───────────────────────────────────
                    ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                          'Paste a direct image URL to use as your room background. '
                          'Use HTTPS links only. The image should be at least 1080 × 1920 px.',
                          style: TextStyle(color: textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _urlController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.url,
                          inputFormatters: [
                            // Block javascript: and data: URIs at input level.
                            _SafeUrlInputFormatter(),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Background image URL',
                            labelStyle: const TextStyle(color: textMuted),
                            hintText: 'https://example.com/image.jpg',
                            hintStyle: const TextStyle(
                              color: Color(0xFF5A5D6A),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1A1D2A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF3A3D4A),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF3A3D4A),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: gold),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.check_rounded,
                                color: gold,
                              ),
                              onPressed: _applyCustomUrl,
                            ),
                          ),
                          onSubmitted: (_) => _applyCustomUrl(),
                        ),
                        if (_draft.hasBackground) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _draft.backgroundUrl!,
                              height: 140,
                              fit: BoxFit.cover,
                              errorBuilder: (___, __, _) => Container(
                                height: 140,
                                color: const Color(0xFF1A1D2A),
                                child: const Center(
                                  child: Text(
                                    'Could not load image preview',
                                    style: TextStyle(color: textMuted),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── Action bar ───────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.paddingOf(context).bottom + 12,
                ),
                child: Row(
                  children: [
                    // Reset to default
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 16,
                        color: textMuted,
                      ),
                      label: const Text(
                        'Reset',
                        style: TextStyle(color: textMuted),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3A3D4A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _confirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Apply Theme',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Input formatter that blocks `javascript:` and `data:` URI schemes,
/// which could otherwise be injected as background URLs.
class _SafeUrlInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lower = newValue.text.trim().toLowerCase();
    if (lower.startsWith('javascript:') || lower.startsWith('data:')) {
      return oldValue;
    }
    return newValue;
  }
}
