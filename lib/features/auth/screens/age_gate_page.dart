/// Age Gate Screen
/// Entry point before auth — confirms the user is 18+.
/// Flow: Onboarding → AgeGatePage → (if 18+) NeonSignupPage
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/neon_colors.dart';
import '../../../core/analytics/analytics_events.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/providers/auth_providers.dart';
import '../providers/age_gate_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
class AgeGatePage extends ConsumerStatefulWidget {
  const AgeGatePage({super.key});

  @override
  ConsumerState<AgeGatePage> createState() => _AgeGatePageState();
}

class _AgeGatePageState extends ConsumerState<AgeGatePage> {
  final _dayController   = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController  = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  // Focus nodes for auto-advancing focus on input
  final _dayFocus   = FocusNode();
  final _monthFocus = FocusNode();
  final _yearFocus  = FocusNode();

  @override
  void initState() {
    super.initState();
    // Log page view
    FirebaseAnalytics.instance.logEvent(name: AnalyticsEvents.ageGateViewed);
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _dayFocus.dispose();
    _monthFocus.dispose();
    _yearFocus.dispose();
    super.dispose();
  }

  void _onDayChanged(String value) {
    if (value.length == 2) {
      _monthFocus.requestFocus();
    }
  }

  void _onMonthChanged(String value) {
    if (value.length == 2) {
      _yearFocus.requestFocus();
    }
  }

  Future<void> _verify() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dayStr   = _dayController.text.trim();
    final monthStr = _monthController.text.trim();
    final yearStr  = _yearController.text.trim();

    // Basic format validation
    final day   = int.tryParse(dayStr);
    final month = int.tryParse(monthStr);
    final year  = int.tryParse(yearStr);

    if (day == null || day < 1 || day > 31 ||
        month == null || month < 1 || month > 12 ||
        year == null || year < 1900 || year > DateTime.now().year) {
      setState(() {
        _errorMessage = 'Please enter a valid date of birth.';
        _isLoading = false;
      });
      return;
    }

    // Construct and validate the actual date
    DateTime birthdate;
    try {
      birthdate = DateTime(year, month, day);
      // Guard against invalid dates like Feb 30
      if (birthdate.day != day || birthdate.month != month) {
        throw const FormatException('Invalid date');
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'Please enter a valid date of birth.';
        _isLoading = false;
      });
      return;
    }

    // Age check via provider
    final notifier = ref.read(ageGateProvider.notifier);
    final isAdult  = notifier.setAndVerifyBirthdate(birthdate);

    if (!isAdult) {
      // Log blocked event
      FirebaseAnalytics.instance.logEvent(
        name: AnalyticsEvents.ageGateBlockedUnderage,
      );
      setState(() {
        _errorMessage =
            'You must be at least 18 years old to use MixVy.\n'
            'MixVy is an 18+ only platform.';
        _isLoading = false;
      });
      return;
    }

    // Log pass event
    FirebaseAnalytics.instance.logEvent(name: AnalyticsEvents.ageGatePassedAdult);

    setState(() => _isLoading = false);

    if (mounted) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update Firestore user with ageVerified true if exists
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'ageVerified': true});
          // Force reload and verify ageVerified
          final updatedDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final updatedAgeVerified = updatedDoc.data()?['ageVerified'] == true;
          final _ = ref.refresh(currentUserProvider);
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          if (updatedAgeVerified) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.home);
          } else {
            setState(() {
              _errorMessage = 'Age verification failed. Please try again.';
              _isLoading = false;
            });
          }
        } else {
          if (mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.signup);
        }
      } else {
        if (mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.signup);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Prevent going back to land on incomplete onboarding state
      canPop: false,
      child: Scaffold(
        backgroundColor: NeonColors.darkBg,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                NeonColors.darkBg2.withValues(alpha: 0.9),
                NeonColors.darkBg,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // ── Icon ──────────────────────────────────────────────
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NeonColors.darkCard,
                      boxShadow: [
                        BoxShadow(
                          color: NeonColors.neonPink.withValues(alpha: 0.5),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                      border: Border.all(
                        color: NeonColors.neonPink.withValues(alpha: 0.7),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: NeonColors.neonPink,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Title ─────────────────────────────────────────────
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [NeonColors.neonPink, NeonColors.neonPurple],
                    ).createShader(bounds),
                    child: const Text(
                      'MixVy is 18+ Only',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Subtitle ──────────────────────────────────────────
                  Text(
                    'You must be at least 18 years old to join.\nPlease enter your date of birth to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Date of Birth label ───────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'DATE OF BIRTH',
                      style: TextStyle(
                        color: NeonColors.neonPink.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── DD / MM / YYYY Inputs ─────────────────────────────
                  Row(
                    children: [
                      // Day
                      Expanded(
                        flex: 2,
                        child: _DateField(
                          controller: _dayController,
                          focusNode: _dayFocus,
                          hint: 'DD',
                          maxLength: 2,
                          onChanged: _onDayChanged,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Month
                      Expanded(
                        flex: 2,
                        child: _DateField(
                          controller: _monthController,
                          focusNode: _monthFocus,
                          hint: 'MM',
                          maxLength: 2,
                          onChanged: _onMonthChanged,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Year
                      Expanded(
                        flex: 3,
                        child: _DateField(
                          controller: _yearController,
                          focusNode: _yearFocus,
                          hint: 'YYYY',
                          maxLength: 4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Format hint ───────────────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Day / Month / Year',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                  ),

                  // ── Error message ─────────────────────────────────────
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NeonColors.errorRed.withValues(alpha: 0.1),
                        border: Border.all(
                          color: NeonColors.errorRed.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.block,
                            color: NeonColors.errorRed,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: NeonColors.errorRed,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Continue Button ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NeonColors.neonPink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            NeonColors.neonPink.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 8,
                        shadowColor: NeonColors.neonPink.withValues(alpha: 0.5),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'VERIFY MY AGE',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Legal note ────────────────────────────────────────
                  Text(
                    'By continuing you confirm you are 18 or older and agree to '
                    'MixVy\'s Terms of Service. Your date of birth is stored '
                    'securely and never shared.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Reusable neon-styled date input field.
class _DateField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final int maxLength;
  final ValueChanged<String>? onChanged;

  const _DateField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.maxLength,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: maxLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
          fontSize: 16,
          letterSpacing: 1,
        ),
        counterText: '',
        filled: true,
        fillColor: NeonColors.darkCard,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: NeonColors.neonPink.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: NeonColors.neonPink,
            width: 2,
          ),
        ),
      ),
    );
  }
}
