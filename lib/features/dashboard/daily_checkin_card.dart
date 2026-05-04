import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../services/daily_checkin_service.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final _checkinServiceProvider = Provider((_) => DailyCheckinService());

final dailyCheckinProvider = FutureProvider.autoDispose<DailyCheckinStatus>((
  ref,
) async {
  final uid = ref.watch(authControllerProvider).uid;
  if (uid == null) {
    return const DailyCheckinStatus(claimed: true, streak: 0, reward: 0);
  }
  return ref.read(_checkinServiceProvider).getStatus(uid);
});

// ─── Widget ───────────────────────────────────────────────────────────────────

class DailyCheckinCard extends ConsumerWidget {
  const DailyCheckinCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dailyCheckinProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (status) => _CheckinContent(status: status),
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _CheckinContent extends ConsumerStatefulWidget {
  const _CheckinContent({required this.status});
  final DailyCheckinStatus status;

  @override
  ConsumerState<_CheckinContent> createState() => _CheckinContentState();
}

class _CheckinContentState extends ConsumerState<_CheckinContent> {
  bool _claiming = false;
  bool _justClaimed = false;

  Future<void> _claim() async {
    final uid = ref.read(authControllerProvider).uid;
    if (uid == null) return;
    setState(() => _claiming = true);
    final ok = await ref.read(_checkinServiceProvider).claim(uid);
    if (!mounted) return;
    setState(() {
      _claiming = false;
      if (ok) _justClaimed = true;
    });
    if (ok) {
      ref.invalidate(dailyCheckinProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    final claimed = s.claimed || _justClaimed;
    final streak = s.streak.clamp(1, 7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [VelvetNoir.surfaceHigh, VelvetNoir.surfaceHighest],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VelvetNoir.outlineVariant, width: 0.8),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: VelvetNoir.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily Check-in',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: VelvetNoir.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                // Streak badge
                if (streak > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: VelvetNoir.primaryDim.withAlpha(80),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: VelvetNoir.primary.withAlpha(100),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      '$streak-day streak',
                      style: const TextStyle(
                        color: VelvetNoir.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // 7-day pip track
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = i + 1;
                final done = claimed ? day <= streak : day < streak;
                final isToday = day == streak && !claimed;
                final coins = day * 10;
                return _DayPip(
                  day: day,
                  coins: coins,
                  done: done,
                  isToday: isToday,
                );
              }),
            ),
            const SizedBox(height: 14),

            // Action button / claimed state
            if (claimed)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: VelvetNoir.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Claimed! Come back tomorrow',
                    style: TextStyle(
                      color: VelvetNoir.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: VelvetNoir.primary,
                    foregroundColor: VelvetNoir.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onPressed: _claiming ? null : _claim,
                  child: _claiming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: VelvetNoir.surface,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.monetization_on_rounded,
                              size: 16,
                              color: VelvetNoir.surface,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Claim ${s.reward} Coins',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Day pip ─────────────────────────────────────────────────────────────────

class _DayPip extends StatelessWidget {
  const _DayPip({
    required this.day,
    required this.coins,
    required this.done,
    required this.isToday,
  });

  final int day;
  final int coins;
  final bool done;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? VelvetNoir.primaryDim.withAlpha(180)
                : isToday
                ? VelvetNoir.primaryDim.withAlpha(60)
                : VelvetNoir.surfaceBright.withAlpha(120),
            border: Border.all(
              color: done || isToday
                  ? VelvetNoir.primary
                  : VelvetNoir.outlineVariant,
              width: isToday ? 2 : 1,
            ),
          ),
          child: Center(
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: VelvetNoir.primary,
                  )
                : Text(
                    'D$day',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isToday
                          ? VelvetNoir.primary
                          : VelvetNoir.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${coins}c',
          style: TextStyle(
            fontSize: 9,
            color: done || isToday
                ? VelvetNoir.primary
                : VelvetNoir.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
