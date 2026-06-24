import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/design_constants.dart';
import '../../shared/providers/service_providers.dart';
import '../../shared/providers/auth_providers.dart';

class SpeedDatingSessionPage extends ConsumerStatefulWidget {
  const SpeedDatingSessionPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SpeedDatingSessionPage> createState() =>
      _SpeedDatingSessionPageState();
}

class _SpeedDatingSessionPageState
    extends ConsumerState<SpeedDatingSessionPage> {
  // Timer
  Timer? _ticker;
  Duration _remaining = const Duration(minutes: 5);

  // Session state (driven by Firestore stream)
  Map<String, dynamic>? _session;
  bool _sessionLoading = true;
  StreamSubscription<Map<String, dynamic>?>? _sessionSub;

  // Decision state
  bool _decisionSubmitted = false;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _listenToSession();
  }

  void _listenToSession() {
    final service = ref.read(speedDatingServiceProvider);
    _sessionSub =
        service.listenToSession(widget.sessionId).listen((session) {
      if (!mounted) return;
      setState(() {
        _session = session;
        _sessionLoading = false;
      });

      if (session == null) return;

      // Start countdown once we have the endsAt timestamp
      final rawEndsAt = session['endsAt'];
      if (rawEndsAt != null && _ticker == null) {
        DateTime? endsAt;
        if (rawEndsAt is Timestamp) endsAt = rawEndsAt.toDate();
        if (endsAt != null) _startTimer(endsAt);
      }

      // Stop timer when session ends
      final status = session['status'] as String? ?? 'active';
      if (status != 'active' && _ticker != null) {
        _ticker!.cancel();
        _ticker = null;
      }
    });
  }

  void _startTimer(DateTime endsAt) {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = endsAt.difference(DateTime.now());
      setState(() {
        _remaining = remaining.isNegative ? Duration.zero : remaining;
      });
    });
  }

  Future<void> _submitDecision(String decision) async {
    if (_decisionSubmitted || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || _session == null) {
        throw Exception('User or session not found');
      }

      // Determine the other user's ID
      final user1Id = _session!['user1Id'] as String?;
      final user2Id = _session!['user2Id'] as String?;
      final matchedUserId = uid == user1Id ? user2Id : user1Id;

      if (matchedUserId == null || matchedUserId.isEmpty) {
        throw Exception('Matched user not found');
      }

      final liked = decision == 'like';
      await ref.read(speedDatingServiceProvider).submitDecision(
            widget.sessionId,
            uid,
            matchedUserId,
            liked,
          );
      if (mounted) setState(() => _decisionSubmitted = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitError = _friendlyError(e);
        });
      }
    }
  }

  Future<void> _leaveSession() async {
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser != null) {
        await ref.read(speedDatingServiceProvider).leaveSession(widget.sessionId, currentUser.id);
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('already-exists')) return 'Decision already submitted.';
    if (msg.contains('deadline-exceeded')) return 'Session has expired.';
    if (msg.contains('failed-precondition')) return 'Session is no longer active.';
    return 'Something went wrong. Please try again.';
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sessionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (_sessionLoading) {
      return const Scaffold(
        backgroundColor: DesignColors.background,
        body: Center(
            child: CircularProgressIndicator(color: DesignColors.gold),
        ),
      );
    }

    if (_session == null) {
      return Scaffold(
        backgroundColor: DesignColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Session not found.',
                style: TextStyle(color: DesignColors.textGray),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back',
                    style: TextStyle(color: DesignColors.gold)),
              ),
            ],
          ),
        ),
      );
    }

    final status = _session!['status'] as String? ?? 'active';
    final isEnded = status != 'active';

    return Scaffold(
      backgroundColor: DesignColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'SPEED DATE',
          style: TextStyle(
            color: DesignColors.gold,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: DesignColors.textGray),
          onPressed: isEnded
              ? () => Navigator.of(context).pop()
              : () => _showLeaveConfirmation(context),
        ),
      ),
      body: isEnded
          ? _buildResultScreen(context)
          : _buildActiveSession(context, uid),
    );
  }

  Widget _buildActiveSession(BuildContext context, String? uid) {
    final otherName = uid == _session!['user1Id']
        ? (_session!['user2Name'] as String? ?? 'Your Match')
        : (_session!['user1Name'] as String? ?? 'Your Match');
    final String? otherPhoto = uid == _session!['user1Id']
        ? _session!['user2Photo'] as String?
        : _session!['user1Photo'] as String?;

    final decisions =
        (_session!['decisions'] as Map?)?.cast<String, dynamic>() ?? {};
    final alreadyDecided =
        _decisionSubmitted || (uid != null && decisions[uid] != null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Countdown timer
          Text(
            _formatDuration(_remaining),
            style: TextStyle(
              color: _remaining.inSeconds < 60
                  ? Colors.redAccent
                  : DesignColors.gold,
              fontSize: 56,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'remaining',
            style: TextStyle(color: DesignColors.textGray, fontSize: 12),
          ),
          const SizedBox(height: 32),
          // Partner avatar
          CircleAvatar(
            radius: 72,
            backgroundColor: DesignColors.gold.withValues(alpha: 0.15),
            backgroundImage:
                otherPhoto != null ? NetworkImage(otherPhoto) : null,
            child: otherPhoto == null
                ? const Icon(Icons.person,
                    size: 72, color: DesignColors.textGray)
                : null,
          ),
          const SizedBox(height: 20),
          Text(
            otherName,
            style: const TextStyle(
              color: DesignColors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (_submitError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _submitError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          if (alreadyDecided)
            const Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Text(
                '✓ Decision submitted — waiting for your match…',
                textAlign: TextAlign.center,
                style: TextStyle(color: DesignColors.textGray, fontSize: 14),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _DecisionButton(
                    label: 'PASS',
                    icon: Icons.close_rounded,
                    color: Colors.redAccent,
                    isLoading: _isSubmitting,
                    onTap: () => _submitDecision('pass'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DecisionButton(
                    label: 'LIKE',
                    icon: Icons.favorite_rounded,
                    color: DesignColors.gold,
                    isLoading: _isSubmitting,
                    onTap: () => _submitDecision('like'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _buildResultScreen(BuildContext context) {
    final isMutual = _session!['status'] == 'completed' &&
        (_session!['isMutual'] as bool? ?? false);
    final isAbandoned = _session!['status'] == 'cancelled' ||
        _session!['status'] == 'abandoned';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMutual
                  ? Icons.favorite_rounded
                  : isAbandoned
                      ? Icons.exit_to_app_rounded
                      : Icons.hourglass_empty_rounded,
              size: 80,
              color: isMutual ? Colors.pinkAccent : DesignColors.textGray,
            ),
            const SizedBox(height: 24),
            Text(
              isMutual
                  ? "It's a Match! 🎉"
                  : isAbandoned
                      ? 'Session Ended'
                      : "Time's Up!",
              style: TextStyle(
                color: isMutual ? Colors.pinkAccent : DesignColors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isMutual
                  ? 'You both liked each other!\nCheck your chats to connect.'
                  : 'Better luck next time.\nTry again!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: DesignColors.textGray, fontSize: 15),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignColors.gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Back to Speed Dating',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DesignColors.cardBackground,
        title: const Text(
          'Leave Session?',
          style: TextStyle(color: DesignColors.white),
        ),
        content: const Text(
          'Leaving early will cancel this session.',
          style: TextStyle(color: DesignColors.textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stay',
                style: TextStyle(color: DesignColors.gold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _leaveSession();
            },
            child: const Text('Leave',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ── Decision button widget ────────────────────────────────────────────────────
class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: color, strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
