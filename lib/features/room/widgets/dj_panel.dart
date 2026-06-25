import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mixvy/shared/providers/video_media_providers.dart';

/// Provider exposing the current DjState for a room (for Now Playing banner).
final djStateProvider = StreamProvider.family<DjState, String>((ref, roomId) {
  return FirebaseFirestore.instance
      .collection('rooms')
      .doc(roomId)
      .snapshots()
      .map((snap) {
    final djMap = snap.data()?['djState'];
    return djMap is Map<String, dynamic>
        ? DjState.fromMap(djMap)
        : const DjState();
  });
});

// ── DJ State model ──────────────────────────────────────────────────────────
class DjState {
  final bool isPlaying;
  final bool isPaused;
  final String? trackUrl;
  final int volume; // 0–100
  final String? djUserId;

  const DjState({
    this.isPlaying = false,
    this.isPaused = false,
    this.trackUrl,
    this.volume = 70,
    this.djUserId,
  });

  factory DjState.fromMap(Map<String, dynamic> m) => DjState(
        isPlaying: m['isPlaying'] as bool? ?? false,
        isPaused: m['isPaused'] as bool? ?? false,
        trackUrl: m['trackUrl'] as String?,
        volume: (m['volume'] as num?)?.toInt() ?? 70,
        djUserId: m['djUserId'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'isPlaying': isPlaying,
        'isPaused': isPaused,
        'trackUrl': trackUrl,
        'volume': volume,
        'djUserId': djUserId,
      };
}

// ── DJ Panel widget ─────────────────────────────────────────────────────────
/// Floating DJ panel for room hosts and admins.
/// Shows play/pause/stop controls and a URL input.
/// Syncs state to Firestore rooms/{roomId}/djState for all participants.
class DjPanel extends ConsumerStatefulWidget {
  final String roomId;
  final bool canControl; // true if user is host or co-host

  const DjPanel({
    super.key,
    required this.roomId,
    required this.canControl,
  });

  /// Show as a draggable bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String roomId,
    required bool canControl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DjPanel(roomId: roomId, canControl: canControl),
    );
  }

  @override
  ConsumerState<DjPanel> createState() => _DjPanelState();
}

class _DjPanelState extends ConsumerState<DjPanel> {
  final _urlCtrl = TextEditingController();
  DjState _djState = const DjState();
  StreamSubscription<DocumentSnapshot>? _sub;
  bool _loading = false;
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTimer;

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _pauseElapsedTimer() => _elapsedTimer?.cancel();

  void _resetElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsed = Duration.zero;
  }

  String get _elapsedLabel {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data();
      final djMap = data?['djState'];
      if (djMap is Map<String, dynamic>) {
        if (mounted) setState(() => _djState = DjState.fromMap(djMap));
      }
    });
    // Pre-fill the URL field if already playing
    _urlCtrl.text = _djState.trackUrl ?? '';
  }

  @override
  void dispose() {
    _sub?.cancel();
    _elapsedTimer?.cancel();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF8B5CF6), width: 1.5)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Title + status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.queue_music, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'DJ Room',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_djState.isPlaying)
                _pill(
                  '● LIVE',
                  _djState.isPaused
                      ? const Color(0xFFFFAB00)
                      : const Color(0xFF00E5CC),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Now playing
          if (_djState.trackUrl != null && _djState.trackUrl!.isNotEmpty) ...[
            const Text('Now Playing',
                style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
              _djState.trackUrl!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF8B5CF6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 14),
          ],

          // Elapsed time indicator (visible when playing)
          if (_djState.isPlaying) ...[
            Row(
              children: [
                Icon(
                  _djState.isPaused ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  size: 14,
                  color: _djState.isPaused
                      ? const Color(0xFFFFAB00)
                      : const Color(0xFF00E5CC),
                ),
                const SizedBox(width: 6),
                Text(
                  _elapsedLabel,
                  style: TextStyle(
                    color: _djState.isPaused
                        ? const Color(0xFFFFAB00)
                        : const Color(0xFF00E5CC),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: null, // indeterminate — we don't know track duration
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _djState.isPaused
                          ? const Color(0xFFFFAB00)
                          : const Color(0xFF8B5CF6),
                    ),
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          if (widget.canControl) ...[
            // URL input
            const Text('Audio Track URL',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _urlCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://example.com/track.mp3',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF1E2D40),
                prefixIcon: const Icon(Icons.link, color: Colors.white38, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2D3A50)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2D3A50)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            // Play controls row
            Row(
              children: [
                // PLAY or RESUME button
                if (!_djState.isPlaying || _djState.isPaused)
                  _controlBtn(
                    icon: Icons.play_arrow_rounded,
                    label: _djState.isPaused ? 'Resume' : 'Play',
                    color: const Color(0xFF00E5CC),
                    onTap: _djState.isPaused ? _resume : _play,
                  ),
                // PAUSE button
                if (_djState.isPlaying && !_djState.isPaused)
                  _controlBtn(
                    icon: Icons.pause_rounded,
                    label: 'Pause',
                    color: const Color(0xFFFFAB00),
                    onTap: _pause,
                  ),
                const SizedBox(width: 10),
                // STOP button
                if (_djState.isPlaying)
                  _controlBtn(
                    icon: Icons.stop_rounded,
                    label: 'Stop',
                    color: const Color(0xFFFF4D8B),
                    onTap: _stop,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Volume slider
            const Text('Volume',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.volume_mute, color: Colors.white38, size: 18),
                Expanded(
                  child: Slider(
                    value: _djState.volume.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    activeColor: const Color(0xFF8B5CF6),
                    inactiveColor: Colors.white12,
                    label: '${_djState.volume}%',
                    onChanged: (v) => _setVolume(v.round()),
                  ),
                ),
                const Icon(Icons.volume_up, color: Colors.white38, size: 18),
              ],
            ),
          ] else ...[
            // Viewer: show who is DJing
            if (_djState.djUserId != null)
              Text(
                'DJ is live in this room',
                style: TextStyle(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.8),
                    fontSize: 14),
              )
            else
              const Text(
                'No DJ active in this room',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
          ],

          if (_loading) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5A3A7E))),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      );

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Future<void> _play() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a valid audio URL to start your MIXVY Lounge soundtrack.')));
      return;
    }
    setState(() => _loading = true);
    try {
      final agora = ref.read(agoraVideoServiceProvider);
      final ok = await agora.startAudioMixing(url, loop: true);
      if (ok) {
        setState(() => _elapsed = Duration.zero);
        _startElapsedTimer();
        await _persistState(DjState(
          isPlaying: true,
          isPaused: false,
          trackUrl: url,
          volume: _djState.volume,
          djUserId: FirebaseAuth.instance.currentUser?.uid,
        ));
      } else {
        _snack('Failed to start audio mixing');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pause() async {
    setState(() => _loading = true);
    try {
      await ref.read(agoraVideoServiceProvider).pauseAudioMixing();
      _pauseElapsedTimer();
      await _persistState(DjState(
        isPlaying: true,
        isPaused: true,
        trackUrl: _djState.trackUrl,
        volume: _djState.volume,
        djUserId: _djState.djUserId,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resume() async {
    setState(() => _loading = true);
    try {
      await ref.read(agoraVideoServiceProvider).resumeAudioMixing();
      _startElapsedTimer();
      await _persistState(DjState(
        isPlaying: true,
        isPaused: false,
        trackUrl: _djState.trackUrl,
        volume: _djState.volume,
        djUserId: _djState.djUserId,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _loading = true);
    try {
      await ref.read(agoraVideoServiceProvider).stopAudioMixing();
      _resetElapsedTimer();
      await _persistState(const DjState());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setVolume(int v) async {
    await ref.read(agoraVideoServiceProvider).setAudioMixingVolume(v);
    await _persistState(DjState(
      isPlaying: _djState.isPlaying,
      isPaused: _djState.isPaused,
      trackUrl: _djState.trackUrl,
      volume: v,
      djUserId: _djState.djUserId,
    ));
  }

  Future<void> _persistState(DjState s) async {
    await FirebaseFirestore.instance
        .collection('rooms')
        .doc(widget.roomId)
        .update({'djState': s.toMap()});
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('MIXVY Audio: $m')));
  }
}

