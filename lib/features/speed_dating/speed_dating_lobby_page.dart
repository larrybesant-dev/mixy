import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/design_constants.dart';
import '../../shared/providers/service_providers.dart';
import '../../shared/providers/auth_providers.dart';
import 'speed_dating_session_page.dart';

// ── Queue status stream ───────────────────────────────────────────────────────
/// Streams the user's queue document from Firestore.
/// Returns null when the user is not in the queue.
final _queueStatusProvider =
    StreamProvider.autoDispose.family<Map<String, dynamic>?, String>(
  (ref, userId) => FirebaseFirestore.instance
      .collection('speed_dating_queue')
      .doc(userId)
      .snapshots()
      .map((snap) => snap.exists ? snap.data() : null),
);

// ── Page ──────────────────────────────────────────────────────────────────────

class SpeedDatingLobbyPage extends ConsumerStatefulWidget {
  const SpeedDatingLobbyPage({super.key});

  @override
  ConsumerState<SpeedDatingLobbyPage> createState() =>
      _SpeedDatingLobbyPageState();
}

class _SpeedDatingLobbyPageState extends ConsumerState<SpeedDatingLobbyPage> {
  bool _isJoining = false;
  bool _isCancelling = false;
  String? _error;
  bool _navigated = false;

  Future<void> _joinQueue() async {
    setState(() {
      _isJoining = true;
      _error = null;
    });
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        throw Exception('Not logged in');
      }
      await ref.read(speedDatingServiceProvider).joinQueue(currentUser.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _friendlyError(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _leaveQueue() async {
    setState(() => _isCancelling = true);
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser != null) {
        await ref.read(speedDatingServiceProvider).leaveQueue('queue', currentUser.id);
      }
    } catch (_) {
      // Ignore — user is leaving queue
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('already-exists')) return 'Already in queue — tap cancel first.';
    if (msg.contains('failed-precondition')) return 'Complete your profile before joining.';
    if (msg.contains('unauthenticated')) return 'Please sign in to use Speed Dating.';
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(
        child: Text(
          'Sign in to use Speed Dating.',
          style: TextStyle(color: DesignColors.textGray),
        ),
      );
    }

    final queueAsync = ref.watch(_queueStatusProvider(uid));

    // Navigate to session when matched
    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      _queueStatusProvider(uid),
      (_, next) {
        next.whenData((data) {
          if (data?['status'] == 'matched' && !_navigated) {
            final sessionId = data!['sessionId'] as String?;
            if (sessionId != null) {
              _navigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SpeedDatingSessionPage(sessionId: sessionId),
                  ),
                ).then((_) {
                  if (mounted) setState(() => _navigated = false);
                });
              });
            }
          }
        });
      },
    );

    return queueAsync.when(
      data: (queueData) => _buildBody(context, queueData),
      loading: () =>
          const Center(child: CircularProgressIndicator(color: DesignColors.gold)),
      error: (_, __) => _buildBody(context, null),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic>? queueData) {
    final isWaitingOrMatched = queueData?['status'] == 'waiting' ||
        queueData?['status'] == 'matched';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lightning icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DesignColors.gold.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: DesignColors.gold.withValues(alpha: 0.3),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Icon(
                Icons.bolt,
                size: 52,
                color: DesignColors.gold,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'SPEED DATING',
              style: TextStyle(
                color: DesignColors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                shadows: DesignColors.secondaryGlow,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Match. Connect. Vibe. — 5-minute video dates.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DesignColors.textGray, fontSize: 14),
            ),
            const SizedBox(height: 40),
            if (_isJoining)
              ..._buildJoiningUI()
            else if (isWaitingOrMatched || _navigated)
              ..._buildWaitingUI()
            else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              _GoldButton(
                label: 'START SPEED DATING',
                onTap: () => _joinQueue(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildJoiningUI() => [
        const CircularProgressIndicator(color: DesignColors.gold),
        const SizedBox(height: 16),
        const Text(
          'Joining queue…',
          style: TextStyle(color: DesignColors.textGray, fontSize: 14),
        ),
      ];

  List<Widget> _buildWaitingUI() => [
        const CircularProgressIndicator(color: DesignColors.gold),
        const SizedBox(height: 24),
        const Text(
          'Finding your match…',
          style: TextStyle(
            color: DesignColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This usually takes under a minute.',
          style: TextStyle(color: DesignColors.textGray, fontSize: 13),
        ),
        const SizedBox(height: 32),
        if (_isCancelling)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: DesignColors.textGray, strokeWidth: 2),
          )
        else
          TextButton(
            onPressed: _leaveQueue,
            child: const Text(
              'Cancel',
              style: TextStyle(color: DesignColors.textGray, fontSize: 14),
            ),
          ),
      ];
}

// ── Reusable gold gradient button ─────────────────────────────────────────────
class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [DesignColors.gold, Color(0xFFFF6B35)],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: DesignColors.gold.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
