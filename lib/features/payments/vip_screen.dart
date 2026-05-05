import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/layout/app_layout.dart';
import 'premium_entitlement.dart';
import '../../shared/widgets/app_page_scaffold.dart';

// Velvet Noir brand tokens
const _vSurface = Color(0xFF0B0B0B);
const _vCard = Color(0xFF141414);
const _vPrimary = Color(0xFFD4AF37);
const _vSecondary = Color(0xFF781E2B);
const _vCream = Color(0xFFF7EDE2);
const _vOutline = Color(0x22D4AF37);

class VipScreen extends ConsumerStatefulWidget {
  const VipScreen({super.key});

  @override
  ConsumerState<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends ConsumerState<VipScreen> {
  bool _isYearly = false;
  bool _checkoutInProgress = false;
  // True while we are waiting for the webhook to confirm VIP after checkout.
  bool _awaitingWebhookConfirmation = false;
  String? _checkoutError;

  static const _webhookPollTimeout = Duration(seconds: 45);

  Future<void> _startVipCheckout({required String tier}) async {
    if (_checkoutInProgress) {
      return;
    }

    setState(() {
      _checkoutInProgress = true;
      _checkoutError = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createCheckoutSessionCallable',
      );
      final result = await callable.call<Map<String, dynamic>>(
        <String, dynamic>{'packageId': 'premium_access', 'tier': tier},
      );

      final data = Map<String, dynamic>.from(result.data);
      final rawUrl = data['url'];
      final checkoutUrl = rawUrl is String ? rawUrl.trim() : '';
      if (checkoutUrl.isEmpty) {
        throw Exception('No checkout URL returned.');
      }

      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open Stripe checkout.');
      }

      // User has been sent to Stripe. Show optimistic pending state while we
      // wait for the webhook to flip entitlements.vip.active. The Firestore
      // StreamBuilder in build() will automatically dismiss this view the
      // moment the entitlement lands; the timeout is a safety net for users
      // who abandon the checkout or experience a slow webhook delivery.
      if (mounted) {
        setState(() {
          _awaitingWebhookConfirmation = true;
        });
        Future.delayed(_webhookPollTimeout, () {
          if (mounted && _awaitingWebhookConfirmation) {
            setState(() {
              _awaitingWebhookConfirmation = false;
            });
          }
        });
      }
    } on FirebaseFunctionsException catch (error) {
      setState(() {
        _checkoutError = error.message ?? 'Unable to start checkout.';
      });
    } catch (error) {
      setState(() {
        _checkoutError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkoutInProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isVip = ref.watch(vipEntitlementProvider).valueOrNull ?? false;

    return AppPageScaffold(
      backgroundColor: _vSurface,
      appBar: AppBar(
        backgroundColor: _vSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _vCream),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              color: _vPrimary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'MIXVY VIP',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _vPrimary,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _vPrimary.withValues(alpha: 0.15)),
        ),
      ),
      body: uid == null
          ? _SignInRequiredView(error: _checkoutError)
          : Builder(
              builder: (context) {
                if (isVip) {
                  // Clear pending flag if webhook arrived.
                  if (_awaitingWebhookConfirmation) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _awaitingWebhookConfirmation = false);
                      }
                    });
                  }
                  return _VipUnlockedView();
                }

                if (_awaitingWebhookConfirmation) {
                  return _VipPendingView();
                }

                return ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildHeroHeader(),
                    _buildBillingToggle(),
                    if (_checkoutError != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          context.pageHorizontalPadding,
                          16,
                          context.pageHorizontalPadding,
                          0,
                        ),
                        child: Text(
                          _checkoutError!,
                          style: GoogleFonts.raleway(
                            fontSize: 12,
                            color: Colors.red.shade300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 24),
                    _TierCard(
                      tier: 'Silver',
                      tagline: 'Start the experience',
                      monthlyPrice: 4.99,
                      yearlyPrice: 49.99,
                      isYearly: _isYearly,
                      accentColor: const Color(0xFFB8C0C8),
                      gradientColors: const [
                        Color(0xFF1A1E22),
                        Color(0xFF0B0B0B),
                      ],
                      icon: Icons.star_outline_rounded,
                      isBusy: _checkoutInProgress,
                      onPressed: () => _startVipCheckout(tier: 'silver'),
                      features: const [
                        'Ad-free experience',
                        'Silver profile badge',
                        'Exclusive Silver rooms',
                        '10% bonus coins on purchase',
                        'Priority room joining',
                      ],
                    ),
                    const SizedBox(height: 16),
                    _TierCard(
                      tier: 'Gold',
                      tagline: 'Command the room',
                      monthlyPrice: 9.99,
                      yearlyPrice: 99.99,
                      isYearly: _isYearly,
                      accentColor: _vPrimary,
                      gradientColors: const [
                        Color(0xFF2A1E05),
                        Color(0xFF1A1200),
                      ],
                      icon: Icons.workspace_premium_rounded,
                      isRecommended: true,
                      isBusy: _checkoutInProgress,
                      onPressed: () => _startVipCheckout(tier: 'gold'),
                      features: const [
                        'Everything in Silver',
                        'Gold profile badge & crown',
                        'VIP-only Gold lounges',
                        '25% bonus coins on purchase',
                        'Gold-tier gifts & stickers',
                        'Custom profile theme',
                        'Whisper anyone (no restrictions)',
                      ],
                    ),
                    const SizedBox(height: 16),
                    _TierCard(
                      tier: 'Diamond',
                      tagline: 'Own the spotlight',
                      monthlyPrice: 19.99,
                      yearlyPrice: 199.99,
                      isYearly: _isYearly,
                      accentColor: const Color(0xFF9CD0FA),
                      gradientColors: const [
                        Color(0xFF0A1525),
                        Color(0xFF050C18),
                      ],
                      icon: Icons.diamond_outlined,
                      isBusy: _checkoutInProgress,
                      onPressed: () => _startVipCheckout(tier: 'diamond'),
                      features: const [
                        'Everything in Gold',
                        'Diamond profile badge & glow',
                        'Private Diamond-only rooms',
                        '50% bonus coins on purchase',
                        'Exclusive Diamond animations',
                        'Co-host any room',
                        'Monthly virtual gift pack',
                        'Direct creator support line',
                      ],
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.pageHorizontalPadding,
                      ),
                      child: Text(
                        'Access unlocks automatically after successful Stripe checkout. '
                        'No waitlist state is used for VIP entitlement.',
                        style: GoogleFonts.raleway(
                          fontSize: 11,
                          color: _vCream.withValues(alpha: 0.35),
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        32,
        context.pageHorizontalPadding,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1200), Color(0xFF0B0B0B)],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFD4AF37), Color(0xFF8C6020)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _vPrimary.withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Elevate Your Experience',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _vCream,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Stripe checkout unlocks VIP automatically after payment success.',
            style: GoogleFonts.raleway(
              fontSize: 13,
              color: _vCream.withValues(alpha: 0.55),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBillingToggle() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        24,
        context.pageHorizontalPadding,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ToggleChip(
            label: 'Monthly',
            isSelected: !_isYearly,
            onTap: () => setState(() => _isYearly = false),
          ),
          const SizedBox(width: 8),
          _ToggleChip(
            label: 'Yearly',
            isSelected: _isYearly,
            onTap: () => setState(() => _isYearly = true),
            badge: 'Save 17%',
          ),
        ],
      ),
    );
  }
}

class _SignInRequiredView extends StatelessWidget {
  const _SignInRequiredView({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.pageHorizontalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: _vCream, size: 42),
            const SizedBox(height: 12),
            Text(
              'Sign in to unlock VIP.',
              style: GoogleFonts.playfairDisplay(
                color: _vCream,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: GoogleFonts.raleway(color: Colors.red.shade300),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VipPendingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(_vPrimary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Activating your VIP',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _vCream,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your payment was received. Access will unlock automatically — no action needed.',
              style: GoogleFonts.raleway(
                fontSize: 13,
                color: _vCream.withValues(alpha: 0.6),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _VipUnlockedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        context.pageHorizontalPadding,
        24,
        context.pageHorizontalPadding,
        40,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF2A1E05), Color(0xFF1A1200)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: _vPrimary.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: _vPrimary.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: _vPrimary),
                  const SizedBox(width: 8),
                  Text(
                    'VIP ACTIVE',
                    style: GoogleFonts.raleway(
                      color: _vPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Your entitlement is active.',
                style: GoogleFonts.playfairDisplay(
                  color: _vCream,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Premium features are now unlocked across the app in real time.',
                style: GoogleFonts.raleway(
                  color: _vCream.withValues(alpha: 0.8),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badge;

  const _ToggleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _vPrimary : _vCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? _vPrimary : _vOutline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.raleway(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.black : _vCream,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.black.withValues(alpha: 0.2)
                      : _vSecondary.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: GoogleFonts.raleway(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final String tier;
  final String tagline;
  final double monthlyPrice;
  final double yearlyPrice;
  final bool isYearly;
  final Color accentColor;
  final List<Color> gradientColors;
  final IconData icon;
  final bool isRecommended;
  final bool isBusy;
  final VoidCallback onPressed;
  final List<String> features;

  const _TierCard({
    required this.tier,
    required this.tagline,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.isYearly,
    required this.accentColor,
    required this.gradientColors,
    required this.icon,
    this.isRecommended = false,
    required this.isBusy,
    required this.onPressed,
    required this.features,
  });

  double get _price => isYearly ? yearlyPrice / 12 : monthlyPrice;
  String get _period => isYearly ? '/mo (billed yearly)' : '/month';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              border: Border.all(
                color: accentColor.withValues(
                  alpha: isRecommended ? 0.6 : 0.25,
                ),
                width: isRecommended ? 1.5 : 1,
              ),
              boxShadow: isRecommended
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.2),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(icon, color: accentColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tier,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                          Text(
                            tagline,
                            style: GoogleFonts.raleway(
                              fontSize: 12,
                              color: _vCream.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${_price.toStringAsFixed(2)}',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _vCream,
                          ),
                        ),
                        Text(
                          _period,
                          style: GoogleFonts.raleway(
                            fontSize: 10,
                            color: _vCream.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  color: accentColor.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 16),
                ...features.map((feature) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            Icons.check,
                            color: accentColor,
                            size: 11,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            feature,
                            style: GoogleFonts.raleway(
                              fontSize: 13,
                              color: _vCream.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isBusy ? null : onPressed,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: accentColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isBusy
                          ? 'OPENING CHECKOUT...'
                          : isRecommended
                          ? 'UNLOCK VIP - MOST POPULAR'
                          : 'UNLOCK VIP',
                      style: GoogleFonts.raleway(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isRecommended)
            Positioned(
              top: -12,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFF8C6020)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _vPrimary.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  'MOST POPULAR',
                  style: GoogleFonts.raleway(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
