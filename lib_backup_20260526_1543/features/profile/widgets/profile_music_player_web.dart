// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';

/// MySpace-style profile music player. Renders an in-page audio player
/// using the browser's native <audio> element via dart:html.
class ProfileMusicPlayer extends StatefulWidget {
  const ProfileMusicPlayer({
    super.key,
    required this.musicUrl,
    required this.musicTitle,
  });

  final String musicUrl;
  final String musicTitle;

  @override
  State<ProfileMusicPlayer> createState() => _ProfileMusicPlayerState();
}

class _ProfileMusicPlayerState extends State<ProfileMusicPlayer> {
  html.AudioElement? _audio;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  bool _playing = false;
  bool _loading = false;
  String? _error;
  double _progress = 0.0; // 0.0 – 1.0
  String _elapsed = '0:00';
  String _duration = '--:--';

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  @override
  void didUpdateWidget(ProfileMusicPlayer old) {
    super.didUpdateWidget(old);
    if (old.musicUrl != widget.musicUrl) {
      _cancelSubscriptions();
      _audio?.pause();
      _audio = null;
      setState(() {
        _playing = false;
        _progress = 0.0;
        _elapsed = '0:00';
        _duration = '--:--';
        _error = null;
      });
      _initAudio();
    }
  }

  void _initAudio() {
    if (widget.musicUrl.isEmpty) return;
    // Validate URL scheme to reduce XSS surface — only https permitted.
    final uri = Uri.tryParse(widget.musicUrl);
    if (uri == null || uri.scheme != 'https') {
      setState(() => _error = 'Music URL must use HTTPS.');
      return;
    }

    final audio = html.AudioElement()
      ..src = widget.musicUrl
      ..preload = 'metadata';

    _subscriptions.add(
      audio.onLoadedMetadata.listen((_) {
        if (!mounted) return;
        final dur = audio.duration;
        setState(() {
          _duration = (dur.isFinite && dur > 0) ? _fmt(dur.toInt()) : '--:--';
        });
      }),
    );

    _subscriptions.add(
      audio.onTimeUpdate.listen((_) {
        if (!mounted) return;
        final dur = audio.duration;
        final cur = audio.currentTime.toDouble();
        setState(() {
          _progress =
              (dur.isFinite && dur > 0) ? (cur / dur).clamp(0.0, 1.0) : 0.0;
          _elapsed = _fmt(cur.toInt());
        });
      }),
    );

    _subscriptions.add(
      audio.onEnded.listen((_) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _progress = 0.0;
          _elapsed = '0:00';
        });
      }),
    );

    _subscriptions.add(
      audio.onError.listen((_) {
        if (!mounted) return;
        setState(() {
          _error = 'Could not load audio. Check the URL and CORS settings.';
          _playing = false;
          _loading = false;
        });
      }),
    );

    _audio = audio;
  }

  void _cancelSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  String _fmt(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _togglePlay() {
    final audio = _audio;
    if (audio == null) return;
    setState(() => _loading = true);
    if (_playing) {
      audio.pause();
      setState(() {
        _playing = false;
        _loading = false;
      });
    } else {
      audio.play().then((_) {
        if (!mounted) return;
        setState(() {
          _playing = true;
          _loading = false;
          _error = null;
        });
      }).catchError((e) {
        if (!mounted) return;
        setState(() {
          _error = 'Playback blocked. Tap play to start.';
          _playing = false;
          _loading = false;
        });
      });
    }
  }

  void _seek(double value) {
    final audio = _audio;
    if (audio == null) return;
    final dur = audio.duration;
    audio.currentTime = (value * dur);
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    _audio?.pause();
    _audio = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title =
        widget.musicTitle.isNotEmpty ? widget.musicTitle : 'Profile music';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161A21),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Play / Pause button
              GestureDetector(
                onTap: _error == null ? _togglePlay : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.15),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                  child: _loading
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primary,
                          ),
                        )
                      : Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: scheme.primary,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Title + timestamps
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.music_note_rounded,
                          size: 13,
                          color: Color(0xFFD4A853),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_error == null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$_elapsed / $_duration',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7B7E87),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 2),
                      Text(
                        _error ?? 'Unknown error',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFFF6E84),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_error == null) ...[
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: scheme.primary,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                thumbColor: scheme.primary,
                overlayColor: scheme.primary.withValues(alpha: 0.2),
              ),
              child: Slider(value: _progress, min: 0, max: 1, onChanged: _seek),
            ),
          ],
        ],
      ),
    );
  }
}
