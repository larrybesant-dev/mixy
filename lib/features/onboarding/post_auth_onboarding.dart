import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../../core/theme/enhanced_theme.dart';
import '../../core/utils/app_logger.dart';
import '../../shared/widgets/club_background.dart';
import '../../shared/widgets/glow_text.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/analytics_events.dart';
import 'onboarding_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Interest options (mirrors create_profile_page)
// ─────────────────────────────────────────────────────────────────────────────
const _kInterests = [
  'Music', 'Sports', 'Travel', 'Food', 'Movies',
  'Books', 'Gaming', 'Art', 'Fitness', 'Dancing',
  'Cooking', 'Technology', 'Nature', 'Pets', 'Fashion',
  'Photography', 'Nightlife', 'Volunteering',
];

const _kStepCount = 5;

// ─────────────────────────────────────────────────────────────────────────────
// PostAuthOnboarding — 5-step post-login onboarding gate.
//
// Steps:
//   0 → Welcome
//   1 → Permissions (informational, web-safe)
//   2 → Age Verification
//   3 → Interests quick-pick
//   4 → All Done / Tutorial hints
// ─────────────────────────────────────────────────────────────────────────────
class PostAuthOnboarding extends ConsumerStatefulWidget {
  const PostAuthOnboarding({super.key});

  @override
  ConsumerState<PostAuthOnboarding> createState() => _PostAuthOnboardingState();
}

class _PostAuthOnboardingState extends ConsumerState<PostAuthOnboarding>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _fadeCtrl;
  late AnimationController _progressCtrl;

  bool _saving = false;
  String? _saveError;
  DateTime? _selectedBirthday;
  bool? _ageVerified;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logStep(0);
      AnalyticsService.instance.logEvent(
        name: AnalyticsEvents.onboardingStarted,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────
  void _advance() {
    final step = ref.read(onboardingStepProvider);
    if (step < _kStepCount - 1) {
      _logStepCompleted(step);
      ref.read(onboardingStepProvider.notifier).next();
      _pageController.nextPage(
        duration: EnhancedTheme.normalAnimation,
        curve: Curves.easeInOut,
      );
      _fadeCtrl.reset();
      _fadeCtrl.forward();
      _logStep(step + 1);
    } else {
      _finish();
    }
  }

  void _skip() {
    AnalyticsService.instance.logEvent(
      name: AnalyticsEvents.onboardingSkipped,
      parameters: {
        'step': ref.read(onboardingStepProvider),
      },
    );
    _finish();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final uid =
          fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
      final interests = ref.read(onboardingInterestsProvider);
      final saveFn = ref.read(onboardingSaveProvider);

      // Mark onboarding as complete locally (non-blocking on Firestore)
      ref.read(localOnboardingCompletionProvider.notifier).complete();

      AppLogger.info('[PostAuthOnboarding] Onboarding marked complete locally');

      AnalyticsService.instance.logEvent(
        name: AnalyticsEvents.onboardingCompleted,
        parameters: {
          'age_verified': _ageVerified ?? false,
          'interests_count': interests.length,
        },
      );

      // Try to save to Firestore in the background (non-blocking)
      unawaited(
        saveFn(
          OnboardingPayload(
            userId: uid,
            ageVerified: _ageVerified ?? false,
            interests: interests,
            birthday: _selectedBirthday,
          ),
        ).onError((e, st) {
          // Log the error but don't block onboarding
          AppLogger.info(
            '[PostAuthOnboarding] Firestore save failed (non-blocking): $e',
          );
        }),
      );
    } catch (e, st) {
      AppLogger.error('[PostAuthOnboarding] finish error', e, st);
      setState(() {
        _saving = false;
        _saveError = 'Could not save. Please retry.';
      });
    }
  }

  void _logStep(int index) {
    AnalyticsService.instance.logEvent(
      name: AnalyticsEvents.onboardingStepViewed,
      parameters: {'step': index, 'step_name': _stepName(index)},
    );
  }

  void _logStepCompleted(int index) {
    AnalyticsService.instance.logEvent(
      name: AnalyticsEvents.onboardingStepCompleted,
      parameters: {'step': index, 'step_name': _stepName(index)},
    );
  }

  static String _stepName(int index) {
    const names = [
      'welcome', 'permissions', 'age_verification', 'interests', 'tutorial',
    ];
    return index < names.length ? names[index] : 'unknown';
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final step = ref.watch(onboardingStepProvider);
    final theme = Theme.of(context);
    final progress = (step + 1) / _kStepCount;

    return ClubBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header bar ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12,
                ),
                child: Row(
                  children: [
                    // Progress indicator
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: EnhancedTheme.normalAnimation,
                        builder: (_, value, __) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                            backgroundColor: theme.colorScheme.surface
                                .withValues(alpha: 0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Step counter
                    Text(
                      '${step + 1} / $_kStepCount',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Skip
                    if (step < _kStepCount - 1)
                      TextButton(
                        onPressed: _skip,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Page content ────────────────────────────────
              Expanded(
                child: FadeTransition(
                  opacity: _fadeCtrl,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _WelcomeStep(onNext: _advance),
                      _PermissionsStep(onNext: _advance),
                      _AgeVerificationStep(
                        onNext: (birthday, verified) {
                          _selectedBirthday = birthday;
                          _ageVerified = verified;
                          if (verified) {
                            AnalyticsService.instance.logEvent(
                              name: AnalyticsEvents.ageVerified,
                            );
                          }
                          ref
                              .read(ageVerificationProvider.notifier)
                              .set(verified);
                          _advance();
                        },
                      ),
                      _InterestsStep(onNext: _advance),
                      _TutorialStep(
                        saving: _saving,
                        saveError: _saveError,
                        onFinish: _finish,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 0 — Welcome
// ─────────────────────────────────────────────────────────────────────────────
class _WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomeStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glow icon
          const _GlowIcon(
            icon: Icons.waving_hand_rounded,
            color: Color(0xFF8F00FF),
          ),
          const SizedBox(height: 40),
          const GlowText(
            text: "You're In! 🎉",
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to MIXVY.\nLet\'s get you set up in 60 seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 56),
          _NeonButton(
            label: "Let's Go  →",
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Permissions (informational, web-safe)
// ─────────────────────────────────────────────────────────────────────────────
class _PermissionsStep extends StatelessWidget {
  final VoidCallback onNext;
  const _PermissionsStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _GlowIcon(
            icon: Icons.security_rounded,
            color: Color(0xFF00E6FF),
          ),
          const SizedBox(height: 40),
          const GlowText(
            text: 'A Few Quick Permissions',
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
          const SizedBox(height: 16),
          Text(
            'Mix & Mingle needs access to these to work properly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 40),
          ..._permissionRows(theme),
          const SizedBox(height: 16),
          Text(
            kIsWeb
                ? 'Click "Allow" when your browser prompts you.'
                : 'Tap "Allow" when your device prompts you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 40),
          _NeonButton(label: 'Continue', onPressed: onNext),
        ],
      ),
    );
  }

  static List<Widget> _permissionRows(ThemeData theme) => [
        const _PermRow(
          icon: Icons.videocam_rounded,
          color: Color(0xFF8F00FF),
          title: 'Camera',
          description: 'Required for video chat and profile photo',
        ),
        const SizedBox(height: 16),
        const _PermRow(
          icon: Icons.mic_rounded,
          color: Color(0xFFFF006B),
          title: 'Microphone',
          description: 'Required for audio in video rooms',
        ),
        const SizedBox(height: 16),
        const _PermRow(
          icon: Icons.notifications_rounded,
          color: Color(0xFFFFB800),
          title: 'Notifications',
          description: 'Get alerts for messages and matches',
        ),
      ];
}

class _PermRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  const _PermRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Age Verification
// ─────────────────────────────────────────────────────────────────────────────
class _AgeVerificationStep extends StatefulWidget {
  final void Function(DateTime? birthday, bool verified) onNext;
  const _AgeVerificationStep({required this.onNext});

  @override
  State<_AgeVerificationStep> createState() => _AgeVerificationStepState();
}

class _AgeVerificationStepState extends State<_AgeVerificationStep> {
  DateTime? _birthday;
  String? _error;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ??
          DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: 'Select your date of birth',
      fieldLabelText: 'Date of birth',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _birthday = picked);
    }
  }

  void _confirm() {
    if (_birthday == null) {
      setState(() => _error = 'Please select your date of birth.');
      return;
    }
    final age = _calculateAge(_birthday!);
    final verified = age >= 18;
    widget.onNext(_birthday, verified);
  }

  void _skip() {
    widget.onNext(null, false);
  }

  static int _calculateAge(DateTime birthday) {
    final today = DateTime.now();
    int age = today.year - birthday.year;
    if (today.month < birthday.month ||
        (today.month == birthday.month && today.day < birthday.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final age = _birthday != null ? _calculateAge(_birthday!) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _GlowIcon(
            icon: Icons.verified_user_rounded,
            color: Color(0xFF00E6FF),
          ),
          const SizedBox(height: 40),
          const GlowText(
            text: 'Age Verification',
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          const SizedBox(height: 16),
          Text(
            'Some content on Mix & Mingle is age-restricted (18+).\nVerify your age to unlock the full experience.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 40),

          // Date picker tappable area
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 18,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _birthday != null
                      ? const Color(0xFF8F00FF)
                      : theme.colorScheme.outline.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.surface.withValues(alpha: 0.3),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: _birthday != null
                        ? const Color(0xFF8F00FF)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _birthday != null
                        ? '${_birthday!.day.toString().padLeft(2, '0')} / '
                            '${_birthday!.month.toString().padLeft(2, '0')} / '
                            '${_birthday!.year}'
                        : 'Tap to select your birthday',
                    style: TextStyle(
                      fontSize: 15,
                      color: _birthday != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (age != null) ...[
            const SizedBox(height: 12),
            Text(
              age >= 18
                  ? '✓ Age verified — 18+ content unlocked'
                  : 'Age: $age — 18+ content restricted',
              style: TextStyle(
                fontSize: 13,
                color: age >= 18 ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],

          const SizedBox(height: 40),

          _NeonButton(label: 'Confirm', onPressed: _confirm),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _skip,
            child: Text(
              'Skip for now',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3 — Interests quick-pick
// ─────────────────────────────────────────────────────────────────────────────
class _InterestsStep extends ConsumerWidget {
  final VoidCallback onNext;
  const _InterestsStep({required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingInterestsProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          const _GlowIcon(
            icon: Icons.interests_rounded,
            color: Color(0xFFFF006B),
          ),
          const SizedBox(height: 32),
          const GlowText(
            text: 'What Are You Into?',
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
          const SizedBox(height: 12),
          Text(
            'Pick 3 or more interests — we\'ll match you better.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kInterests.map((interest) {
              final active = selected.contains(interest);
              return GestureDetector(
                onTap: () => ref
                    .read(onboardingInterestsProvider.notifier)
                    .toggle(interest),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: active
                        ? const Color(0xFF8F00FF).withValues(alpha: 0.2)
                        : theme.colorScheme.surface.withValues(alpha: 0.3),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF8F00FF)
                          : theme.colorScheme.outline
                              .withValues(alpha: 0.3),
                      width: active ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    interest,
                    style: TextStyle(
                      fontSize: 14,
                      color: active
                          ? const Color(0xFFCF80FF)
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.8),
                      fontWeight: active
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
          Text(
            '${selected.length} selected${selected.length >= 3 ? ' ✓' : ' (minimum 3)'}',
            style: TextStyle(
              fontSize: 13,
              color: selected.length >= 3
                  ? Colors.greenAccent
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          _NeonButton(
            label: selected.isEmpty ? 'Skip for now' : 'Continue',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4 — Tutorial / All Done
// ─────────────────────────────────────────────────────────────────────────────
class _TutorialStep extends StatelessWidget {
  final bool saving;
  final String? saveError;
  final VoidCallback onFinish;
  const _TutorialStep({
    required this.saving,
    required this.saveError,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _GlowIcon(
            icon: Icons.celebration_rounded,
            color: Color(0xFFFFB800),
          ),
          const SizedBox(height: 40),
          const GlowText(
            text: "You're All Set! 🚀",
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
          const SizedBox(height: 16),
          Text(
            "Here's how to get started:",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),
          ..._hints(context),
          const SizedBox(height: 40),
          if (saveError != null) ...[
            Text(
              saveError!,
              style: const TextStyle(
                color: Colors.redAccent, fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
          saving
              ? const CircularProgressIndicator()
              : _NeonButton(
                  label: "Enter Mix & Mingle",
                  onPressed: onFinish,
                ),
        ],
      ),
    );
  }

  static List<Widget> _hints(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      (Icons.explore_rounded, const Color(0xFF8F00FF),
          'Discover', 'Browse rooms and people'),
      (Icons.videocam_rounded, const Color(0xFF00E6FF),
          'Go Live', 'Start your own video room'),
      (Icons.favorite_rounded, const Color(0xFFFF006B),
          'Match', 'Connect with people like you'),
    ];
    return items
        .map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.$2.withValues(alpha: 0.15),
                  ),
                  child: Icon(item.$1, color: item.$2, size: 22),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$3,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      item.$4,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared micro-widgets
// ─────────────────────────────────────────────────────────────────────────────
class _GlowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _GlowIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 80;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 32,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class _NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _NeonButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF8F00FF),
              scheme.primary,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
