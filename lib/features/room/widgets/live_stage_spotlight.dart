import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/room_participant_model.dart';
import '../controllers/live_room_controller.dart';
import '../providers/participant_providers.dart';

/// Left-side live stage widget.
///
/// Shows the active speakers as glowing avatar "spotlight" cards with an
/// animated ambient background. Falls back to an invitation card when nobody
/// is on stage yet. Designed to replace the empty black void in the cams
/// column when no video streams are active.
class LiveStageSpotlight extends ConsumerStatefulWidget {
  const LiveStageSpotlight({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.displayNameById,
    required this.avatarUrlById,
    required this.viewerCount,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  final String roomId;
  final String roomName;
  final Map<String, String> displayNameById;
  final Map<String, String?> avatarUrlById;
  final int viewerCount;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  @override
  ConsumerState<LiveStageSpotlight> createState() => _LiveStageSpotlightState();
}

class _LiveStageSpotlightState extends ConsumerState<LiveStageSpotlight>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _bgCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _bgAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speakerIds = ref.watch(
      liveRoomControllerProvider(widget.roomId).select((s) => s.speakerIds),
    );
    final participantsAsync = ref.watch(
      participantsStreamProvider(widget.roomId),
    );
    final participants = participantsAsync.valueOrNull ?? const [];
    final participantByUser = {
      for (final p in participants) p.userId.trim(): p,
    };
    final speakers = speakerIds
        .map((id) => participantByUser[id.trim()])
        .whereType<RoomParticipantModel>()
        .toList(growable: false);

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _bgAnim]),
      builder: (context, _) {
        return _StageBackground(
          bgAnim: _bgAnim,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Ambient radial glow in stage centre
              Positioned.fill(child: _AmbientGlow(pulse: _pulseAnim.value)),
              // Main content
              Column(
                children: [
                  const SizedBox(height: 16),
                  // ── Top bar: room name + LIVE badge ──────────────────
                  _TopBar(
                    roomName: widget.roomName,
                    viewerCount: widget.viewerCount,
                    pulse: _pulseAnim.value,
                  ),
                  // ── Stage area ───────────────────────────────────────
                  Expanded(
                    child: speakers.isEmpty
                        ? _EmptyStage(
                            actionLabel: widget.primaryActionLabel,
                            onAction: widget.onPrimaryAction,
                          )
                        : _SpeakerGrid(
                            speakers: speakers,
                            displayNameById: widget.displayNameById,
                            avatarUrlById: widget.avatarUrlById,
                            pulse: _pulseAnim.value,
                          ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Background ──────────────────────────────────────────────────────────────

class _StageBackground extends StatelessWidget {
  const _StageBackground({required this.bgAnim, required this.child});

  final Animation<double> bgAnim;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bgAnim,
      builder: (context, child) {
        final t = bgAnim.value;
        // Shift between deep purple-black and nightclub indigo
        final topColor = Color.lerp(
          const Color(0xFF0A0510),
          const Color(0xFF110820),
          t,
        )!;
        final bottomColor = Color.lerp(
          const Color(0xFF0D0A0C),
          const Color(0xFF150C18),
          t,
        )!;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topColor, bottomColor],
            ),
          ),
          child: child,
        );
      },
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.pulse});
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final opacity = 0.06 + pulse * 0.08;
    final radius = 0.35 + pulse * 0.12;
    return CustomPaint(
      painter: _GlowPainter(opacity: opacity, radius: radius),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({required this.opacity, required this.radius});
  final double opacity;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.max(size.width, size.height) * radius;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7C5FFF).withValues(alpha: opacity),
          const Color(0xFFD4A853).withValues(alpha: opacity * 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    canvas.drawCircle(Offset(cx, cy), r, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.radius != radius;
}

// ── Top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.roomName,
    required this.viewerCount,
    required this.pulse,
  });

  final String roomName;
  final int viewerCount;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final dotOpacity = 0.6 + pulse * 0.4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // LIVE badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xCC9B2535),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: dotOpacity),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: dotOpacity * 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Room name
          Expanded(
            child: Text(
              roomName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Viewer count
          if (viewerCount > 0) ...[
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  color: Color(0xFFD4A853),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '$viewerCount',
                  style: const TextStyle(
                    color: Color(0xFFD4A853),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Speaker grid ─────────────────────────────────────────────────────────────

class _SpeakerGrid extends StatelessWidget {
  const _SpeakerGrid({
    required this.speakers,
    required this.displayNameById,
    required this.avatarUrlById,
    required this.pulse,
  });

  final List<RoomParticipantModel> speakers;
  final Map<String, String> displayNameById;
  final Map<String, String?> avatarUrlById;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: speakers.take(6).map((p) {
            final name = displayNameById[p.userId] ?? p.userId;
            final avatarUrl = avatarUrlById[p.userId];
            final isHost = p.role == 'host';
            final isCohost = p.role == 'cohost';
            // Primary speaker (host) gets a larger card
            final cardSize = (isHost && speakers.length == 1) ? 160.0 : 110.0;
            return _SpeakerCard(
              name: name,
              role: p.role,
              avatarUrl: avatarUrl,
              isMicOn: p.micOn && !p.isMuted,
              isHost: isHost,
              isCohost: isCohost,
              size: cardSize,
              pulse: pulse,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SpeakerCard extends StatelessWidget {
  const _SpeakerCard({
    required this.name,
    required this.role,
    required this.avatarUrl,
    required this.isMicOn,
    required this.isHost,
    required this.isCohost,
    required this.size,
    required this.pulse,
  });

  final String name;
  final String role;
  final String? avatarUrl;
  final bool isMicOn;
  final bool isHost;
  final bool isCohost;
  final double size;
  final double pulse;

  Color get _glowColor {
    if (isHost) return const Color(0xFFD4A853); // gold for host
    if (isCohost) return const Color(0xFF7C5FFF); // purple for cohost
    return const Color(0xFF4EC9B0); // teal for stage
  }

  String get _roleBadge {
    if (isHost) return '👑';
    if (isCohost) return '⭐';
    return '🎤';
  }

  @override
  Widget build(BuildContext context) {
    final glowOpacity = 0.35 + pulse * 0.45;
    final glowRadius = 12.0 + pulse * 10.0;
    final avatarSize = size * 0.65;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glowing avatar circle
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _glowColor.withValues(alpha: glowOpacity),
                blurRadius: glowRadius,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Avatar border ring
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _glowColor.withValues(alpha: 0.7),
                    width: 2.5,
                  ),
                  color: const Color(0xFF1A1520),
                ),
              ),
              // Avatar image or initials
              ClipOval(
                child: SizedBox(
                  width: avatarSize,
                  height: avatarSize,
                  child: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? Image.network(
                          avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _InitialsAvatar(name: name, size: avatarSize),
                        )
                      : _InitialsAvatar(name: name, size: avatarSize),
                ),
              ),
              // Role badge (top-right)
              Positioned(
                top: 4,
                right: 4,
                child: Text(
                  _roleBadge,
                  style: TextStyle(fontSize: size * 0.18),
                ),
              ),
              // Mic-on indicator (bottom)
              if (isMicOn)
                Positioned(
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B2535),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic, color: Colors.white, size: 10),
                        SizedBox(width: 2),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Speaker name
        SizedBox(
          width: size + 16,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: size > 120 ? 14 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().length == 1
        ? name.trim().toUpperCase()
        : name.trim()[0].toUpperCase() +
              (name.trim().split(' ').length > 1
                  ? name.trim().split(' ').last[0].toUpperCase()
                  : name.trim()[1].toUpperCase());
    return ColoredBox(
      color: const Color(0xFF2A1F35),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: const Color(0xFFD4A853),
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Empty stage ──────────────────────────────────────────────────────────────

class _EmptyStage extends StatelessWidget {
  const _EmptyStage({this.actionLabel, this.onAction});
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stage icon with neon ring
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x40D4A853), width: 2),
              color: const Color(0xFF1A1225),
            ),
            child: const Center(
              child: Text('🎤', style: TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'The stage is open',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to take the mic\nand set the vibe',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFB09080), fontSize: 13),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            _GlowButton(label: actionLabel!, onPressed: onAction!),
          ],
        ],
      ),
    );
  }
}

class _GlowButton extends StatelessWidget {
  const _GlowButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C5FFF), Color(0xFF9B2535)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C5FFF).withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
