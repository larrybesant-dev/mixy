import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/app_layout.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../theme/after_dark_theme.dart';

/// Step 1 of After Dark setup — age confirmation + consent.
/// On pass → navigates to /after-dark/pin-setup.
class AfterDarkAgeGateScreen extends StatefulWidget {
  const AfterDarkAgeGateScreen({super.key});

  @override
  State<AfterDarkAgeGateScreen> createState() => _AfterDarkAgeGateScreenState();
}

class _AfterDarkAgeGateScreenState extends State<AfterDarkAgeGateScreen> {
  final _dobController = TextEditingController();
  bool _consentChecked = false;
  String? _error;

  @override
  void dispose() {
    _dobController.dispose();
    super.dispose();
  }

  void _proceed() {
    final text = _dobController.text.trim();
    // Parse YYYY-MM-DD or MM/DD/YYYY
    DateTime? dob;
    try {
      if (text.contains('/')) {
        final parts = text.split('/');
        if (parts.length == 3) {
          dob = DateTime(
            int.parse(parts[2]),
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }
      } else {
        dob = DateTime.parse(text);
      }
    } catch (_) {}

    if (dob == null) {
      setState(() => _error = 'Please enter a valid date (MM/DD/YYYY)');
      return;
    }

    final age = DateTime.now().difference(dob).inDays ~/ 365;
    if (age < 18) {
      setState(
        () => _error = 'You must be 18 or older to access MixVy After Dark.',
      );
      return;
    }

    if (!_consentChecked) {
      setState(
        () => _error = 'You must agree to the After Dark terms to proceed.',
      );
      return;
    }

    context.go('/after-dark/pin-setup');
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: afterDarkTheme,
      child: AppPageScaffold(
        backgroundColor: EmberDark.surface,
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.pageHorizontalPadding,
            20,
            context.pageHorizontalPadding,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: EmberDark.bannerGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: EmberDark.primary.withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [EmberDark.primary, EmberDark.secondary],
                      ).createShader(bounds),
                      child: const Text(
                        'MixVy After Dark',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adults only — 18+',
                      style: TextStyle(
                        color: EmberDark.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Confirm your age',
                style: TextStyle(
                  color: EmberDark.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'MixVy After Dark contains adult-oriented content and is intended for users 18 years of age or older.',
                style: TextStyle(
                  color: EmberDark.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _dobController,
                style: TextStyle(color: EmberDark.onSurface),
                decoration: InputDecoration(
                  hintText: 'Date of Birth (MM/DD/YYYY)',
                  hintStyle: TextStyle(color: EmberDark.onSurfaceVariant),
                  filled: true,
                  fillColor: EmberDark.surfaceHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: EmberDark.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: EmberDark.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: EmberDark.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.cake_outlined,
                    color: EmberDark.onSurfaceVariant,
                  ),
                ),
                keyboardType: TextInputType.datetime,
                onChanged: (_) => setState(() => _error = null),
              ),
              SizedBox(height: context.sectionSpacing + 12),
              Container(
                decoration: BoxDecoration(
                  color: EmberDark.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: EmberDark.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'After Dark Terms',
                      style: TextStyle(
                        color: EmberDark.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _termItem('You are 18 years of age or older'),
                    _termItem('You consent to viewing 18+ content'),
                    _termItem('You will not share content without consent'),
                    _termItem('You will report any content involving minors'),
                    _termItem('Content is for consenting adults only'),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _consentChecked,
                      onChanged: (v) =>
                          setState(() => _consentChecked = v ?? false),
                      title: Text(
                        'I confirm I am 18+ and agree to the After Dark terms',
                        style: TextStyle(
                          color: EmberDark.onSurface,
                          fontSize: 13,
                        ),
                      ),
                      activeColor: EmberDark.primary,
                      checkColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EmberDark.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: EmberDark.primary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: EmberDark.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: EmberDark.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: context.sectionSpacing + 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: EmberDark.primaryGradient,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: EmberDark.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _proceed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/settings'),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: EmberDark.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _termItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: EmberDark.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: EmberDark.onSurfaceVariant, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}



