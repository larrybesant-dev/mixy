import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/room_state.dart';

// ── Colour constants ──────────────────────────────────────────────────────────
const Color _kGold = Color(0xFFD4AF37);
const Color _kWineRed = Color(0xFF722F37);
const Color _kWineRedBright = Color(0xFF9B2535);
const Color _kGreen = Color(0xFF22C55E);
const Color _kRed = Color(0xFFFF3355);
const Color _kSurface = Color(0xFF0B0B0B);
const Color _kSurfaceHigh = Color(0xFF1C1617);
const Color _kOnVariant = Color(0xFFAD9585);

// ── Layout mode ───────────────────────────────────────────────────────────────
enum RoomUserTileLayout {
  /// Centred avatar column — used in featured host slot and speakers grid.
  grid,

  /// Compact horizontal row — used in audience list.
  list,
}

// ── RoomUserTile ──────────────────────────────────────────────────────────────
/// Reusable role-aware tile for live-room panels.
///
/// Supports two [layout] modes:
/// * [RoomUserTileLayout.grid] — vertical column with avatar, name, and badge.
/// * [RoomUserTileLayout.list] — compact horizontal row.
///
/// Set [compact] to `true` when rendering inside the on-mic panel so that
/// avatar sizes stay proportionate inside the small panel height.
class RoomUserTile extends StatefulWidget {
  const RoomUserTile({
    super.key,
    required this.displayName,
    required this.role,
    required this.isMe,
    this.avatarUrl,
    this.isMicOn = false,
    this.isMuted = false,
    this.micExpiresAt,
    this.layout = RoomUserTileLayout.grid,
    this.compact = false,
    this.onTap,
  });

  final String displayName;
  final String? avatarUrl;

  /// Participant role string: 'host', 'owner', 'cohost', 'stage',
  /// 'audience', 'moderator'.
  final String role;
  final bool isMe;
  final bool isMicOn;
  final bool isMuted;

  /// Expiry timestamp — renders a countdown badge for 'stage' users only.
  final DateTime? micExpiresAt;

  final RoomUserTileLayout layout;

  /// Smaller avatar sizes for use inside the compact on-mic panel row.
  final bool compact;

  final VoidCallback? onTap;

  @override
  State<RoomUserTile> createState() => _RoomUserTileState();
}

class _RoomUserTileState extends State<RoomUserTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _scaleAnim;
  Timer? _tickTimer;
  int _secondsLeft = 0;

  bool get _isSpeaking => widget.isMicOn && !widget.isMuted;
  String get _normalizedRole =>
      normalizeRoomRole(widget.role, fallbackRole: '');
  bool get _isHost => isHostLikeRole(_normalizedRole);
  bool get _isCohost => _normalizedRole == roomRoleCohost;
  bool get _isSpeaker => _normalizedRole == roomRoleStage;
  bool get _hasRing => _isHost || _isCohost || _isSpeaker;

  double get _avatarRadius {
    if (widget.layout == RoomUserTileLayout.list) return 14.0;
    if (widget.compact) {
      if (_isHost) return 24.0;
      if (_isCohost) return 22.0;
      return 20.0;
    }
    if (_isHost) return 36.0;
    if (_isCohost) return 30.0;
    if (_isSpeaker) return 28.0;
    return 22.0;
  }

  Color? get _ringColor {
    if (_isHost || _isCohost) return _kGold;
    if (_isSpeaker) return _kWineRed;
    return null;
  }

  List<BoxShadow> get _shadowLayers {
    if (!_isSpeaking || !_hasRing) return [];
    // Multi-layer shadow for luxury depth effect
    final pulseValue = _pulseCtrl.value;
    if (_isHost || _isCohost) {
      return [
        // Primary gold glow
        BoxShadow(
          color: _kGold.withValues(alpha: 0.35 + (pulseValue * 0.15)),
          blurRadius: 12 + (pulseValue * 4),
          spreadRadius: 2 + (pulseValue * 1),
        ),
        // Secondary wine-red outer layer for luxury feel
        BoxShadow(
          color: const Color(0xFF9B2535).withValues(alpha: 0.12 + (pulseValue * 0.08)),
          blurRadius: 8,
          spreadRadius: 3,
        ),
      ];
    } else if (_isSpeaker) {
      return [
        // Primary wine-red glow
        BoxShadow(
          color: _kWineRedBright.withValues(alpha: 0.45 + (pulseValue * 0.15)),
          blurRadius: 14 + (pulseValue * 6),
          spreadRadius: 2 + (pulseValue * 2),
        ),
        // Secondary outer glow for intensity
        BoxShadow(
          color: _kWineRed.withValues(alpha: 0.20 + (pulseValue * 0.10)),
          blurRadius: 6,
          spreadRadius: 3,
        ),
      ];
    }
    return [];
  }

  String get _roleLabel {
    switch (_normalizedRole) {
      case roomRoleHost:
      case roomRoleOwner:
        return 'HOST';
      case roomRoleCohost:
        return 'CO-HOST';
      case roomRoleStage:
        return 'MIC';
      case roomRoleModerator:
        return 'MOD';
      default:
        return '';
    }
  }

  Color get _roleBadgeColor {
    if (_isHost || _isCohost) return _kGold;
    if (_isSpeaker) return _kWineRedBright;
    return _kOnVariant;
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    if (_isSpeaking) _pulseCtrl.repeat(reverse: true);
    _startTimer();
  }

  @override
  void didUpdateWidget(RoomUserTile old) {
    super.didUpdateWidget(old);
    if (_isSpeaking && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!_isSpeaking && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
    if (old.micExpiresAt != widget.micExpiresAt) {
      _tickTimer?.cancel();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final exp = widget.micExpiresAt;
    if (exp == null || !_isSpeaker) {
      _secondsLeft = 0;
      return;
    }
    // Set the initial value directly — no setState needed here because build
    // hasn't been called yet (we're in initState or just after a param change
    // before the next build).
    final remaining = exp.difference(DateTime.now()).inSeconds;
    _secondsLeft = remaining < 0 ? 0 : remaining;
    if (_secondsLeft > 0) {
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final r = exp.difference(DateTime.now()).inSeconds;
        setState(() => _secondsLeft = r < 0 ? 0 : r);
        if (_secondsLeft <= 0) _tickTimer?.cancel();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.layout == RoomUserTileLayout.list
        ? _buildListRow()
        : _buildGridCell();
  }

  // ── Grid cell ──────────────────────────────────────────────────────────────
  Widget _buildGridCell() {
    final r = _avatarRadius;
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: r * 2 + 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(),
            const SizedBox(height: 4),
            Text(
              widget.isMe ? '${widget.displayName} (you)' : widget.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.raleway(
                fontSize: widget.compact ? 9 : 10,
                fontWeight: widget.isMe ? FontWeight.w700 : FontWeight.w500,
                color: widget.isMe
                    ? _kGold
                    : Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: _buildBadgeRow()),
          ],
        ),
      ),
    );
  }

  // ── List row ───────────────────────────────────────────────────────────────
  Widget _buildListRow() {
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
          ),
        ),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.isMe
                    ? '${widget.displayName} (you)'
                    : widget.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.raleway(
                  fontSize: 12,
                  fontWeight: widget.isMe ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isMe
                      ? _kGold
                      : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
            Icon(
              widget.isMuted || !widget.isMicOn ? Icons.mic_off : Icons.mic,
              size: 13,
              color: widget.isMuted || !widget.isMicOn
                  ? _kRed.withValues(alpha: 0.65)
                  : _kGreen.withValues(alpha: 0.65),
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────
  Widget _buildAvatar() {
    final r = _avatarRadius;
    final ringColor = _ringColor;

    final avatar = CircleAvatar(
      radius: r,
      backgroundColor: _kSurfaceHigh,
      backgroundImage: (widget.avatarUrl?.isNotEmpty == true)
          ? NetworkImage(widget.avatarUrl!)
          : null,
      child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
          ? Text(
              widget.displayName.isEmpty
                  ? '?'
                  : widget.displayName[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: r * 0.56,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );

    // Mic overlay — shown in grid mode for host/cohost/speaker only.
    Widget? micOverlay;
    if (widget.layout == RoomUserTileLayout.grid && _hasRing) {
      micOverlay = Positioned(
        right: 0,
        bottom: 0,
        child: Container(
          width: r * 0.65,
          height: r * 0.65,
          decoration: const BoxDecoration(
            color: _kSurface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.isMuted || !widget.isMicOn ? Icons.mic_off : Icons.mic,
            size: r * 0.40,
            color: widget.isMuted || !widget.isMicOn ? _kRed : _kGreen,
          ),
        ),
      );
    }

    final avatarDecoration = ringColor != null
        ? BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ringColor,
              width: _isSpeaking ? 2.5 : 1.8,
            ),
            boxShadow: _shadowLayers.isNotEmpty ? _shadowLayers : null,
          )
        : const BoxDecoration();

    Widget ringed = DecoratedBox(
      decoration: avatarDecoration,
      child: Padding(
        padding: EdgeInsets.all(ringColor != null ? 2.0 : 0.0),
        child: Stack(clipBehavior: Clip.none, children: [avatar, if (micOverlay != null) micOverlay]),
      ),
    );

    // Scale pulse animation when the user is actively speaking.
    if (_isSpeaking) {
      ringed = AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnim.value, child: child),
        child: ringed,
      );
    }

    return ringed;
  }

  // ── Badge row ──────────────────────────────────────────────────────────────
  Widget _buildBadgeRow() {
    final label = _roleLabel;
    final showTimer = _isSpeaker && widget.micExpiresAt != null;

    // Timer badge colour: green → orange → red as expiry approaches.
    Color timerColor = const Color(0xFF4CAF50);
    if (_secondsLeft <= 10) {
      timerColor = const Color(0xFFFF5252);
    } else if (_secondsLeft <= 20) {
      timerColor = const Color(0xFFFF9800);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _roleBadgeColor.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: _roleBadgeColor,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
        if (showTimer) ...[
          const SizedBox(width: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: timerColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 8, color: timerColor),
                const SizedBox(width: 2),
                Text(
                  _secondsLeft > 0
                      ? '${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}'
                      : '0:00',
                  style: TextStyle(
                    color: timerColor,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}



