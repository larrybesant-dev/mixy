/// Membership Upgrade Screen
///
/// Premium subscription purchase screen (VIP/VIP+).
/// Features tier comparison, benefits list, and purchase flow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/membership_tier.dart';
import 'package:mixvy/services/payments/revenuecat_service.dart';
import '../services/membership_service.dart';
import '../../../core/theme/neon_colors.dart';
import '../../../core/design_system/design_constants.dart';
import '../../../shared/widgets/neon_components.dart';
import '../../../shared/widgets/club_background.dart';

/// Membership upgrade screen
class MembershipUpgradeScreen extends ConsumerStatefulWidget {
  const MembershipUpgradeScreen({super.key});

  @override
  ConsumerState<MembershipUpgradeScreen> createState() =>
      _MembershipUpgradeScreenState();
}

class _MembershipUpgradeScreenState
    extends ConsumerState<MembershipUpgradeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  MembershipTier _selectedTier = MembershipTier.vip;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTier = MembershipService.instance.currentTier;

    return Scaffold(
      backgroundColor: DesignColors.background,
      body: Stack(
        children: [
          // Background
          const ClubBackground(child: SizedBox.expand()),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Header
                  _buildHeader(context),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),

                          // Title
                          _buildTitle(),

                          const SizedBox(height: 8),

                          // Subtitle
                          _buildSubtitle(currentTier),

                          const SizedBox(height: 32),

                          // Tier cards
                          _buildTierCards(currentTier),

                          const SizedBox(height: 32),

                          // Benefits section
                          _buildBenefitsSection(),

                          const SizedBox(height: 32),

                          // Purchase button
                          _buildPurchaseButton(),

                          const SizedBox(height: 16),

                          // Terms
                          _buildTerms(),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isProcessing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: Colors.white.withAlpha(179),
            ),
          ),
          const Spacer(),
          Text(
            'Upgrade Membership',
            style: TextStyle(
              color: Colors.white.withAlpha(179),
              fontSize: 16,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const NeonText(
      'Unlock Premium Features',
      fontSize: 32,
      fontWeight: FontWeight.bold,
      glowColor: NeonColors.neonBlue,
    );
  }

  Widget _buildSubtitle(MembershipTier currentTier) {
    return Text(
      currentTier == MembershipTier.free
          ? 'Upgrade to VIP or VIP+ for exclusive benefits'
          : 'You\'re already a ${currentTier.displayName} member',
      style: TextStyle(
        color: Colors.white.withAlpha(179),
        fontSize: 16,
      ),
    );
  }

  Widget _buildTierCards(MembershipTier currentTier) {
    return Column(
      children: [
        // VIP card
        _buildTierCard(
          tier: MembershipTier.vip,
          isSelected: _selectedTier == MembershipTier.vip,
          isCurrent: currentTier == MembershipTier.vip,
          onTap: () => setState(() => _selectedTier = MembershipTier.vip),
        ),

        const SizedBox(height: 16),

        // VIP+ card
        _buildTierCard(
          tier: MembershipTier.vipPlus,
          isSelected: _selectedTier == MembershipTier.vipPlus,
          isCurrent: currentTier == MembershipTier.vipPlus,
          onTap: () => setState(() => _selectedTier = MembershipTier.vipPlus),
        ),
      ],
    );
  }

  Widget _buildTierCard({
    required MembershipTier tier,
    required bool isSelected,
    required bool isCurrent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isCurrent ? null : onTap,
      child: NeonGlowCard(
        glowColor: isSelected
            ? tier.primaryColor
            : DesignColors.accent.withValues(alpha: 0.2),
        borderRadius: 20,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Tier icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [tier.primaryColor, tier.secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    tier.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),

                const SizedBox(width: 16),

                // Tier name & price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getTierPrice(tier),
                        style: TextStyle(
                          color: tier.primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selection indicator or current badge
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: tier.primaryColor.withAlpha(51),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: tier.primaryColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'CURRENT',
                      style: TextStyle(
                        color: tier.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: tier.primaryColor,
                    size: 32,
                  )
                else
                  Icon(
                    Icons.circle_outlined,
                    color: Colors.white.withAlpha(77),
                    size: 32,
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              tier.description,
              style: TextStyle(
                color: Colors.white.withAlpha(179),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 16),

            // Key benefits (compact)
            ...tier.benefits.take(3).map((benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: tier.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          benefit.title,
                          style: TextStyle(
                            color: Colors.white.withAlpha(204),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

            if (tier.benefits.length > 3)
              Text(
                '+${tier.benefits.length - 3} more benefits',
                style: TextStyle(
                  color: tier.primaryColor,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeonText(
          'All ${_selectedTier.displayName} Benefits',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          glowColor: _selectedTier.primaryColor,
        ),
        const SizedBox(height: 16),
        ..._selectedTier.benefits.map((benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified,
                    color: _selectedTier.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      benefit.title,
                      style: TextStyle(
                        color: Colors.white.withAlpha(230),
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildPurchaseButton() {
    final currentTier = MembershipService.instance.currentTier;
    final isUpgradable = _selectedTier.isHigherThan(currentTier);

    return NeonButton(
      label: isUpgradable
          ? 'Upgrade to ${_selectedTier.displayName}'
          : 'Current Plan',
      onPressed: isUpgradable ? _handlePurchase : () {},
      glowColor: _selectedTier.primaryColor,
      isLoading: _isProcessing,
    );
  }

  Widget _buildTerms() {
    return Center(
      child: Text(
        'Auto-renews monthly. Cancel anytime in settings.\nSee Terms of Service for details.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withAlpha(128),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: DesignColors.background.withValues(alpha: 0.88),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(_selectedTier.primaryColor),
            ),
            const SizedBox(height: 16),
            const Text(
              'Processing purchase...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTierPrice(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.vip:
        return '\$9.99/month';
      case MembershipTier.vipPlus:
        return '\$19.99/month';
      default:
        return 'Free';
    }
  }

  Future<void> _handlePurchase() async {
    setState(() => _isProcessing = true);

    try {
      final revenueCat = RevenueCatService.instance;

      // Get offering for selected tier
      final result = await revenueCat.purchaseMembership(_selectedTier);

      if (result.success) {
        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('âœ… Upgraded to ${_selectedTier.displayName}!'),
            backgroundColor: _selectedTier.primaryColor,
          ),
        );

        // Navigate back after short delay
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Purchase failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}

