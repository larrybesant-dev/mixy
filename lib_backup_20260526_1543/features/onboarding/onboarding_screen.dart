import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mixvy/core/services/first_run_service.dart';
import 'package:mixvy/core/theme.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/presentation/providers/app_settings_provider.dart';
import 'package:mixvy/services/analytics_service.dart';
import 'package:mixvy/shared/widgets/app_page_scaffold.dart';
import 'package:mixvy/widgets/brand_ui_kit.dart';

class _OnboardScene {
  const _OnboardScene({
    required this.kicker,
    required this.title,
    required this.body,
    required this.highlight,
    required this.statValue,
    required this.statLabel,
    required this.perks,
    required this.icon,
    required this.accent,
  });

  final String kicker;
  final String title;
  final String body;
  final String highlight;
  final String statValue;
  final String statLabel;
  final List<String> perks;
  final IconData icon;
  final Color accent;
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  final Set<String> _selectedInterests = <String>{};

  int _index = 0;
  bool _acceptedLegal = false;
  bool _submitting = false;

  static const List<String> _interests = <String>[
    'music',
    'deep talks',
    'dating',
    'live rooms',
    'nightlife',
    'gaming',
    'comedy',
    'fitness',
    'travel',
    'karaoke',
    'art & design',
    'wellness',
    'afrobeats',
    'dancing',
    'photography',
    'self-growth',
  ];

  static const List<_OnboardScene> _pages = <_OnboardScene>[
    _OnboardScene(
      kicker: 'Mix',
      title: 'Step into rooms with real chemistry.',
      body: 'Find live spaces that feel grown, magnetic, and worth staying in.',
      highlight: 'No cold start. The energy is already there when you arrive.',
      statValue: 'Live now',
      statLabel: 'rooms built around conversation, music, and chemistry',
      perks: <String>['Live hosts', 'Late-night rooms', 'Instant vibe check'],
      icon: Icons.graphic_eq_rounded,
      accent: VelvetNoir.primary,
    ),
    _OnboardScene(
      kicker: 'Connect',
      title: 'Meet people who match your energy fast.',
      body:
          'Move from browsing to conversation without awkward friction or empty noise.',
      highlight: 'The app should feel curated, not crowded.',
      statValue: 'Real time',
      statLabel: 'chat, reactions, and room momentum happening together',
      perks: <String>[
        'Friends in rooms',
        'Quick reactions',
        'Better discovery',
      ],
      icon: Icons.favorite_outline_rounded,
      accent: VelvetNoir.secondaryBright,
    ),
    _OnboardScene(
      kicker: 'Indulge',
      title: 'Host your own room when the mood is right.',
      body:
          'Open a room, shape the atmosphere, and bring people into your orbit.',
      highlight:
          'When you go live, it should feel premium from the first second.',
      statValue: 'Under a minute',
      statLabel: 'to open your first room and start setting the tone',
      perks: <String>['Quick setup', 'Premium identity', 'Host presence'],
      icon: Icons.mic_external_on_rounded,
      accent: VelvetNoir.secondary,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isInterestPage => _index == _pages.length;

  Future<void> _skipOnboarding() async {
    if (_submitting) return;
    await FirstRunService.markOnboardingSeen();
    await ref.read(appSettingsControllerProvider.notifier).acceptCurrentLegal();
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _continue() async {
    if (_submitting) return;
    if (_isInterestPage && !_acceptedLegal) return;

    if (!_isInterestPage) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await FirstRunService.markOnboardingSeen();
      await ref
          .read(appSettingsControllerProvider.notifier)
          .acceptCurrentLegal();

      if (_selectedInterests.isNotEmpty) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await ref.read(firestoreProvider).collection('users').doc(uid).update(
            <String, dynamic>{
              'interests': _selectedInterests.toList(growable: false),
            },
          );
        }
      }

      await AnalyticsService().logEvent('onboarding_complete');
      if (!mounted) return;
      context.go('/home');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isInterestPage ? VelvetNoir.primary : _pages[_index].accent;

    return AppPageScaffold(
      backgroundColor: VelvetNoir.surface,
      safeArea: false,
      body: Stack(
        children: <Widget>[
          const _VelvetBackdrop(),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: VelvetNoir.surfaceHigh.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: VelvetNoir.outlineVariant.withValues(
                              alpha: 0.9,
                            ),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            MixvyMonogram(size: 22),
                            SizedBox(width: 10),
                            MixvyAppBarLogo(fontSize: 14),
                          ],
                        ),
                      ),
                      const Spacer(),
                      MixvyGoldOutlineButton(
                        label: 'Skip',
                        width: 92,
                        height: 42,
                        onPressed: _skipOnboarding,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (int value) =>
                        setState(() => _index = value),
                    children: <Widget>[
                      ..._pages.map((scene) => _ScenePage(scene: scene)),
                      _InterestsPage(
                        selected: _selectedInterests,
                        acceptedLegal: _acceptedLegal,
                        onToggle: (String interest) {
                          setState(() {
                            if (_selectedInterests.contains(interest)) {
                              _selectedInterests.remove(interest);
                            } else {
                              _selectedInterests.add(interest);
                            }
                          });
                        },
                        onAcceptedLegalChanged: (bool value) {
                          setState(() => _acceptedLegal = value);
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(
                          _pages.length + 1,
                          (int dotIndex) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _index == dotIndex ? 26 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _index == dotIndex
                                  ? accent
                                  : VelvetNoir.onSurfaceVariant.withValues(
                                      alpha: 0.28,
                                    ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: _index == dotIndex
                                  ? <BoxShadow>[
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.45),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _PrimaryCta(
                        label: _isInterestPage ? 'ENTER MIXVY' : 'CONTINUE',
                        accent: accent,
                        enabled: !_isInterestPage || _acceptedLegal,
                        loading: _submitting,
                        onPressed: _continue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VelvetBackdrop extends StatelessWidget {
  const _VelvetBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  VelvetNoir.surface,
                  VelvetNoir.surfaceLow,
                  VelvetNoir.surfaceContainer,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -90,
          child: _GlowOrb(
            size: 280,
            color: VelvetNoir.primary.withValues(alpha: 0.14),
          ),
        ),
        Positioned(
          top: 160,
          right: -100,
          child: _GlowOrb(
            size: 220,
            color: VelvetNoir.secondary.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          bottom: -140,
          right: -80,
          child: _GlowOrb(
            size: 300,
            color: VelvetNoir.secondaryBright.withValues(alpha: 0.12),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.transparent,
                  VelvetNoir.surface.withValues(alpha: 0.16),
                  VelvetNoir.surface.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: <BoxShadow>[
          BoxShadow(color: color, blurRadius: 90, spreadRadius: 20),
        ],
      ),
    );
  }
}

class _ScenePage extends StatelessWidget {
  const _ScenePage({required this.scene});

  final _OnboardScene scene;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 250,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _KickerChip(label: scene.kicker, color: scene.accent),
            const SizedBox(height: 20),
            Text(
              scene.title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.onSurface,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              scene.body,
              style: GoogleFonts.raleway(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: VelvetNoir.onSurface.withValues(alpha: 0.9),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              scene.highlight,
              style: GoogleFonts.raleway(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scene.accent,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 26),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: VelvetNoir.surfaceHigh.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: VelvetNoir.outlineVariant.withValues(alpha: 0.9),
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: scene.accent.withValues(alpha: 0.18),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          scene.accent.withValues(alpha: 0.32),
                          VelvetNoir.surfaceHighest,
                        ],
                      ),
                      border: Border.all(
                        color: scene.accent.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Icon(scene.icon, color: scene.accent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          scene.statValue,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: VelvetNoir.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          scene.statLabel,
                          style: GoogleFonts.raleway(
                            fontSize: 12,
                            color: VelvetNoir.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: scene.perks
                  .map(
                    (String perk) =>
                        _PerkChip(label: perk, accent: scene.accent),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestsPage extends StatelessWidget {
  const _InterestsPage({
    required this.selected,
    required this.acceptedLegal,
    required this.onToggle,
    required this.onAcceptedLegalChanged,
  });

  final Set<String> selected;
  final bool acceptedLegal;
  final ValueChanged<String> onToggle;
  final ValueChanged<bool> onAcceptedLegalChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 250,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const _KickerChip(label: 'Your Vibe', color: VelvetNoir.primary),
            const SizedBox(height: 20),
            Text(
              'Choose the energy you want more of.',
              style: GoogleFonts.playfairDisplay(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: VelvetNoir.onSurface,
                height: 1.02,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We use this to shape discovery, room suggestions, and the people you see first.',
              style: GoogleFonts.raleway(
                fontSize: 15,
                color: VelvetNoir.onSurface.withValues(alpha: 0.88),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _OnboardingScreenState._interests
                  .map(
                    (String interest) => _InterestChip(
                      label: interest,
                      selected: selected.contains(interest),
                      onTap: () => onToggle(interest),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VelvetNoir.surfaceHigh.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: VelvetNoir.outlineVariant.withValues(alpha: 0.9),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Checkbox(
                    value: acceptedLegal,
                    activeColor: VelvetNoir.primary,
                    side: const BorderSide(color: VelvetNoir.onSurfaceVariant),
                    onChanged: (bool? value) =>
                        onAcceptedLegalChanged(value ?? false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'I agree to the Terms of Service and Privacy Policy.',
                          style: GoogleFonts.raleway(
                            color: VelvetNoir.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: <Widget>[
                            TextButton(
                              onPressed: () => context.go('/legal/terms'),
                              child: Text(
                                'Terms',
                                style: GoogleFonts.raleway(
                                  color: VelvetNoir.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/legal/privacy'),
                              child: Text(
                                'Privacy',
                                style: GoogleFonts.raleway(
                                  color: VelvetNoir.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KickerChip extends StatelessWidget {
  const _KickerChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.raleway(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _PerkChip extends StatelessWidget {
  const _PerkChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VelvetNoir.surfaceContainer.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.raleway(
          color: VelvetNoir.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? VelvetNoir.primaryGradient : null,
          color:
              selected ? null : VelvetNoir.surfaceHigh.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : VelvetNoir.outlineVariant.withValues(alpha: 0.85),
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: VelvetNoir.primary.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.raleway(
            color: selected ? VelvetNoir.surface : VelvetNoir.onSurface,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.label,
    required this.accent,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final Color accent;
  final bool enabled;
  final bool loading;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: enabled
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: MixvyGoldButton(
        label: label,
        loading: loading,
        onPressed: enabled ? () async => onPressed() : null,
      ),
    );
  }
}
