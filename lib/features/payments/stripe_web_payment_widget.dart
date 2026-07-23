// lib/features/payments/stripe_web_payment_widget.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:url_launcher/url_launcher.dart';

class StripeWebPaymentWidget extends StatefulWidget {
  const StripeWebPaymentWidget({super.key});

  @override
  State<StripeWebPaymentWidget> createState() => _StripeWebPaymentWidgetState();
}

class _StripeWebPaymentWidgetState extends State<StripeWebPaymentWidget> {
  bool isLoading = false;
  String? error;

  String? _asNullableString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  Future<void> startCheckout() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("User not logged in");
      }

      // 🔥 CALL YOUR BACKEND / FIREBASE FUNCTION HERE
      // This should return a Stripe Checkout URL
      final checkoutUrl = await createCheckoutSession();

      if (checkoutUrl == null) {
        throw Exception("Failed to create checkout session");
      }

      // 🚀 REDIRECT TO STRIPE
      final uri = Uri.parse(checkoutUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch Stripe checkout');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<String?> createCheckoutSession() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createCheckoutSessionCallable',
      );
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{'packageId': 'premium_access'},
      );
      final data = Map<String, dynamic>.from(result.data);
      return _asNullableString(data['url']);
    } catch (e, stack) {
      // Integrate Crashlytics for error reporting (not on web)
      if (!kIsWeb) {
        try {
          await FirebaseCrashlytics.instance.recordError(
            e,
            stack,
            reason: 'Stripe checkout session creation failed',
          );
        } catch (_) {
          FlutterError.reportError(
            FlutterErrorDetails(exception: e, stack: stack),
          );
        }
      }
      return null;
    }
  }

  static const List<_PremiumPerk> _perks = [
    _PremiumPerk(
      icon: Icons.mic,
      title: 'Host Live Rooms',
      description:
          'Go live with up to 1,000 listeners and take the stage anytime.',
    ),
    _PremiumPerk(
      icon: Icons.videocam,
      title: 'HD Video & Audio',
      description:
          'Crystal-clear video and studio-quality audio in every session.',
    ),
    _PremiumPerk(
      icon: Icons.monetization_on,
      title: 'Earn Coins',
      description:
          'Receive coin gifts from your audience and cash out your earnings.',
    ),
    _PremiumPerk(
      icon: Icons.workspace_premium,
      title: 'Premium Badge',
      description:
          'Stand out with an exclusive badge shown on your profile and rooms.',
    ),
    _PremiumPerk(
      icon: Icons.people,
      title: 'Expanded Social Network',
      description:
          'Follow and connect with unlimited creators across the platform.',
    ),
    _PremiumPerk(
      icon: Icons.bar_chart,
      title: 'Audience Analytics',
      description:
          'See who\u2019s tuning in, peak times, and engagement stats for your rooms.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.workspace_premium,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'MixVy Premium',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Everything you need to create, connect, and earn on MixVy.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    '\$9.99 / month',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'What you get',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Perks list
          ...List.generate(_perks.length, (i) {
            final perk = _perks[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      perk.icon,
                      color: colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          perk.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          perk.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),

          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                error!,
                style: TextStyle(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // CTA button
          FilledButton(
            onPressed: isLoading ? null : startCheckout,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Upgrade Now — \$9.99 / month',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),

          const SizedBox(height: 12),

          Text(
            'Secure payment via Stripe. Cancel anytime.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumPerk {
  final IconData icon;
  final String title;
  final String description;
  const _PremiumPerk({
    required this.icon,
    required this.title,
    required this.description,
  });
}



