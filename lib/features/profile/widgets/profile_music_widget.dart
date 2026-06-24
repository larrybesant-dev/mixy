// lib/features/profile/widgets/profile_music_widget.dart
//
// ProfileMusicWidget – displays the user's favourite track preview on
// their profile with a mini animated neon visualizer.
//
// Two modes:
//   ProfileMusicBadge  – compact badge used on profile view (auto-plays)
//   ProfileMusicEditor – edit section inside the profile edit screen
// ─────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/profile_music_service.dart';
import '../../../core/theme/neon_colors.dart';
import '../../../core/motion/app_motion.dart';
import '../../../shared/models/user_profile.dart';

// ─────────────────────────────────────────────────────────────────
// Badge (shown on another user's profile view)
// ─────────────────────────────────────────────────────────────────
class ProfileMusicBadge extends ConsumerStatefulWidget {
  final UserProfile profile;

  const ProfileMusicBadge({super.key, required this.profile});

  @override
  ConsumerState<ProfileMusicBadge> createState() => _ProfileMusicBadgeState();
}

class _ProfileMusicBadgeState extends ConsumerState<ProfileMusicBadge> {
  @override
  void initState() {
    super.initState();
    // Auto-play when profile opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(profileMusicProvider.notifier)
          .playPreview(widget.profile.favoriteTrackPreviewUrl);
    });
  }

  @override
  void dispose() {
    // Stop on profile close
    ref.read(profileMusicProvider.notifier).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.profile.favoriteTrackTitle;
    final artist = widget.profile.favoriteTrackArtist;

    if (track == null || track.isEmpty) return const SizedBox.shrink();

    final svc = ref.watch(profileMusicProvider);
    final isPlaying = svc.isPlaying;

    return AppMotion.slideFadeIn(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: NeonColors.neonPurple.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: NeonColors.neonPurple.withValues(alpha: 0.25),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Source icon ────────────────────────────────────
            _sourceIcon(widget.profile.favoriteTrackSource),
            const SizedBox(width: 8),

            // ── Track info ────────────────────────────────────
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (artist != null)
                    Text(
                      artist,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ── Mini visualizer ───────────────────────────────
            _MiniVisualizer(isPlaying: isPlaying),
          ],
        ),
      ),
    );
  }

  Widget _sourceIcon(TrackSource? source) {
    IconData icon;
    Color color;
    switch (source) {
      case TrackSource.spotify:
        icon = Icons.music_note;
        color = const Color(0xFF1DB954);
      case TrackSource.appleMusic:
        icon = Icons.music_note;
        color = const Color(0xFFFC3C44);
      case TrackSource.soundcloud:
        icon = Icons.cloud;
        color = const Color(0xFFFF5500);
      default:
        icon = Icons.music_note;
        color = NeonColors.neonPurple;
    }
    return Icon(icon, color: color, size: 16);
  }
}

// ─────────────────────────────────────────────────────────────────
// Mini animated visualizer (5 bars that oscillate)
// ─────────────────────────────────────────────────────────────────
class _MiniVisualizer extends StatefulWidget {
  final bool isPlaying;
  const _MiniVisualizer({required this.isPlaying});

  @override
  State<_MiniVisualizer> createState() => _MiniVisualizerState();
}

class _MiniVisualizerState extends State<_MiniVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.isPlaying) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_MiniVisualizer old) {
    super.didUpdateWidget(old);
    if (old.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
        _ctrl.value = 0.3;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return SizedBox(
          width: 20,
          height: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(5, (i) {
              final phase = (i / 5) * math.pi * 2;
              final t = (math.sin(_ctrl.value * math.pi * 2 + phase) + 1) / 2;
              final h = widget.isPlaying ? (4 + t * 12) : 3.0;
              return Container(
                width: 2,
                height: h.clamp(2, 16),
                decoration: BoxDecoration(
                  color: NeonColors.neonPurple.withValues(
                    alpha: widget.isPlaying ? 0.8 + t * 0.2 : 0.4,
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Editor section for profile edit screen
// ─────────────────────────────────────────────────────────────────
class ProfileMusicEditor extends StatelessWidget {
  final UserProfile profile;
  final void Function(String? previewUrl, String? title, String? artist,
      TrackSource? source) onTrackChanged;
  final VoidCallback onRemove;

  const ProfileMusicEditor({
    super.key,
    required this.profile,
    required this.onTrackChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasTrack = profile.favoriteTrackPreviewUrl?.isNotEmpty == true ||
        profile.favoriteTrackTitle?.isNotEmpty == true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15192D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NeonColors.neonPurple.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.music_note,
                  color: NeonColors.neonPurple, size: 18),
              SizedBox(width: 8),
              Text(
                'Profile Music',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Current track or empty state
          if (hasTrack) ...[
            _SelectedTrackRow(profile: profile),
            const SizedBox(height: 10),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Add a track others will hear when they view your profile.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),

          // Actions
          Row(
            children: [
              Expanded(
                child: _OutlineButton(
                  label: hasTrack ? 'Change track' : 'Choose a track',
                  icon: Icons.search,
                  onTap: () => _showTrackPicker(context),
                ),
              ),
              if (hasTrack) ...[
                const SizedBox(width: 8),
                _OutlineButton(
                  label: 'Remove',
                  icon: Icons.close,
                  onTap: onRemove,
                  color: NeonColors.errorRed,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showTrackPicker(BuildContext context) {
    // Opens a bottom sheet where the user can paste a preview URL manually.
    // In a full integration, this would open Spotify/Apple Music pickers.
    _TrackPickerSheet.show(context, onSave: onTrackChanged);
  }
}

class _SelectedTrackRow extends StatelessWidget {
  final UserProfile profile;
  const _SelectedTrackRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.music_note,
            color: _sourceColor(profile.favoriteTrackSource), size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.favoriteTrackTitle ?? 'Unknown title',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (profile.favoriteTrackArtist != null)
                Text(
                  profile.favoriteTrackArtist!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _sourceColor(TrackSource? s) {
    switch (s) {
      case TrackSource.spotify:
        return const Color(0xFF1DB954);
      case TrackSource.appleMusic:
        return const Color(0xFFFC3C44);
      case TrackSource.soundcloud:
        return const Color(0xFFFF5500);
      default:
        return NeonColors.neonPurple;
    }
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = NeonColors.neonPurple,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Simple track picker bottom sheet (URL-based for now)
// ─────────────────────────────────────────────────────────────────
class _TrackPickerSheet extends StatefulWidget {
  final void Function(
      String? url, String? title, String? artist, TrackSource? source) onSave;

  const _TrackPickerSheet({required this.onSave});

  static Future<void> show(
    BuildContext context, {
    required void Function(String?, String?, String?, TrackSource?) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15192D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TrackPickerSheet(onSave: onSave),
    );
  }

  @override
  State<_TrackPickerSheet> createState() => _TrackPickerSheetState();
}

class _TrackPickerSheetState extends State<_TrackPickerSheet> {
  final _urlCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  TrackSource _source = TrackSource.other;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom + 24;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, pad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Profile Music',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          const SizedBox(height: 16),
          _field('Track title', _titleCtrl),
          const SizedBox(height: 10),
          _field('Artist', _artistCtrl),
          const SizedBox(height: 10),
          _field('Preview URL (MP3/AAC)', _urlCtrl, hint: 'https://...'),
          const SizedBox(height: 10),
          // Source picker
          DropdownButtonFormField<TrackSource>(
            initialValue: _source,
            dropdownColor: const Color(0xFF1A1F3A),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Source',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: NeonColors.neonPurple.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: TrackSource.values
                .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name,
                        style: const TextStyle(color: Colors.white))))
                .toList(),
            onChanged: (v) => setState(() => _source = v ?? _source),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: NeonColors.neonPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                widget.onSave(
                  _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
                  _titleCtrl.text.trim().isEmpty
                      ? null
                      : _titleCtrl.text.trim(),
                  _artistCtrl.text.trim().isEmpty
                      ? null
                      : _artistCtrl.text.trim(),
                  _source,
                );
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        enabledBorder: OutlineInputBorder(
          borderSide:
              BorderSide(color: NeonColors.neonPurple.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: NeonColors.neonPurple),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
