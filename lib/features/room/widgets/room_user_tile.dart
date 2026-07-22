import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/room_state.dart';
import 'room_rank_diamond_badge_row.dart';

const Color _kGold = Color(0xFFD4AF37);
const Color _kWineRed = Color(0xFF722F37);
const Color _kWineRedBright = Color(0xFF9B2535);
const Color _kGreen = Color(0xFF22C55E);
const Color _kRed = Color(0xFFFF3355);
const Color _kSurface = Color(0xFF0B0B0B);
const Color _kSurfaceHigh = Color(0xFF1C1617);
const Color _kOnVariant = Color(0xFFAD9585);

enum RoomUserTileLayout { grid, list }

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
    this.rankTier = 0,
    this.diamondLevel = 0,
    this.layout = RoomUserTileLayout.grid,
    this.compact = false,
    this.onTap,
  });

  final String displayName;
  final String? avatarUrl;
  final String role;
  final bool isMe;
  final bool isMicOn;
  final bool isMuted;
  final DateTime? micExpiresAt;
  final int rankTier;
  final int diamondLevel;
  final RoomUserTileLayout layout;
  final bool compact;
  final VoidCallback? onTap;

  @override
  State<RoomUserTile> createState() => _RoomUserTileState();
}

class _RoomUserTileState extends State<RoomUserTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _scaleAnim;
  Timer? _tickTimer;
  int _secondsLeft = 0;

  bool get _isSpeaking => widget.isMicOn && !widget.isMuted;
  String get _normalizedRole => normalizeRoomRole(widget.role, fallbackRole: '');
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
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (_isSpeaking) _pulseCtrl.repeat(reverse: true);
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant RoomUserTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isSpeaking && !_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    } else if (!_isSpeaking && _pulseCtrl.isAnimating) {
      _pulseCtrl.stop();
      _pulseCtrl.value = 0;
    }
    if (oldWidget.micExpiresAt != widget.micExpiresAt) {
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
    _secondsLeft = exp.difference(DateTime.now()).inSeconds;
    if (_secondsLeft < 0) _secondsLeft = 0;
    if (_secondsLeft > 0) {
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final next = exp.difference(DateTime.now()).inSeconds;
        setState(() => _secondsLeft = next < 0 ? 0 : next);
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
                color: widget.isMe ? _kGold : Colors.white.withValues(alpha: 0.9),
              ),
            ),
            if (widget.rankTier > 0 || widget.diamondLevel > 0) ...[
              const SizedBox(height: 2),
              RoomRankDiamondBadgeRow(
                rankTier: widget.rankTier,
                diamondLevel: widget.diamondLevel,
                compact: true,
              ),
            ],
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: _buildBadgeRow()),
          ],
        ),
      ),
    );
  }

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isMe ? '${widget.displayName} (you)' : widget.displayName,
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
                  if (widget.rankTier > 0 || widget.diamondLevel > 0)
                    RoomRankDiamondBadgeRow(
                      rankTier: widget.rankTier,
                      diamondLevel: widget.diamondLevel,
                      compact: true,
                    ),
                ],
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

  Widget _buildAvatar() {
    final r = _avatarRadius;
    final ringColor = _ringColor;

    final avatar = CircleAvatar(
      radius: r,
      backgroundColor: _kSurfaceHigh,
      backgroundImage:
          (widget.avatarUrl?.isNotEmpty == true) ? NetworkImage(widget.avatarUrl!) : null,
      child: (widget.avatarUrl == null || widget.avatarUrl!.isEmpty)
          ? Text(
              widget.displayName.isEmpty ? '?' : widget.displayName[0].toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontSize: r * 0.56,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );

    Widget? micOverlay;
    if (widget.layout == RoomUserTileLayout.grid && _hasRing) {
      micOverlay = Positioned(
        right: 0,
        bottom: 0,
        child: Container(
          width: r * 0.65,
          height: r * 0.65,
          decoration: const BoxDecoration(color: _kSurface, shape: BoxShape.circle),
          child: Icon(
            widget.isMuted || !widget.isMicOn ? Icons.mic_off : Icons.mic,
            size: r * 0.40,
            color: widget.isMuted || !widget.isMicOn ? _kRed : _kGreen,
          ),
        ),
      );
    }

    final decorated = DecoratedBox(
      decoration: ringColor == null
          ? const BoxDecoration()
          : BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: _isSpeaking ? 2.5 : 1.8),
            ),
      child: Padding(
        padding: EdgeInsets.all(ringColor != null ? 2.0 : 0.0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [avatar, if (micOverlay != null) micOverlay],
        ),
      ),
    );

    if (_isSpeaking) {
      return AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(scale: _scaleAnim.value, child: child),
        child: decorated,
      );
    }

    return decorated;
  }

  Widget _buildBadgeRow() {
    final label = _roleLabel;
    final showTimer = _isSpeaker && widget.micExpiresAt != null;

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
