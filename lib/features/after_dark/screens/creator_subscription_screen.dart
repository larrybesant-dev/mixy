import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_env.dart';
import '../../../core/flags/feature_flags.dart';
import '../../../core/layout/app_layout.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../services/creator_subscription_service.dart';
import '../../../shared/widgets/app_page_scaffold.dart';
import '../providers/creator_subscription_provider.dart';
import '../theme/after_dark_theme.dart';

class CreatorSubscriptionScreen extends ConsumerStatefulWidget {
  const CreatorSubscriptionScreen({super.key, this.creatorId});

  final String? creatorId;

  @override
  ConsumerState<CreatorSubscriptionScreen> createState() =>
      _CreatorSubscriptionScreenState();
}

class _CreatorSubscriptionScreenState
    extends ConsumerState<CreatorSubscriptionScreen> {
  final _priceController = TextEditingController();
  final _benefitsController = TextEditingController();
  Future<CreatorSubscriptionOverview>? _overviewFuture;
  Future<List<CreatorSubscriberUpdate>>? _updatesFuture;
  String? _creatorId;
  bool _working = false;

  bool get _checkoutConfigured {
    final key = AppEnv.stripePublishableKey.trim();
    return kPaymentsEnabled && key.startsWith('pk_test_');
  }

  @override
  void initState() {
    super.initState();
    _creatorId =
        (widget.creatorId ??
                ref.read(firebaseAuthProvider).currentUser?.uid)
            ?.trim();
    if ((_creatorId ?? '').isNotEmpty) {
      _overviewFuture = _loadOverview();
    }
  }

  Future<CreatorSubscriptionOverview> _loadOverview() async {
    final overview = await ref
        .read(creatorSubscriptionServiceProvider)
        .getCreatorSubscriptionOverview(_creatorId!);
    if (overview.isOwner) {
      _priceController.text = (overview.offer.monthlyPriceCents / 100)
          .toStringAsFixed(2);
      _benefitsController.text = overview.offer.benefits.join('\n');
    }
    return overview;
  }

  void _refresh() {
    setState(() {
      _overviewFuture = _loadOverview();
      _updatesFuture = null;
    });
  }

  Future<List<CreatorSubscriberUpdate>> _loadUpdates() {
    return ref
        .read(creatorSubscriptionServiceProvider)
        .listCreatorSubscriberUpdates(_creatorId!);
  }

  Future<void> _publishUpdate() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New subscriber update'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'Share something with your subscribers...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    controller.dispose();
    if ((text ?? '').isEmpty || !mounted) return;

    setState(() => _working = true);
    try {
      await ref
          .read(creatorSubscriptionServiceProvider)
          .publishCreatorSubscriberUpdate(text!);
      if (!mounted) return;
      setState(() => _updatesFuture = _loadUpdates());
      _showMessage('Subscriber update published.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not publish the update: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _reportUpdate(CreatorSubscriberUpdate update) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report subscriber content?'),
        content: const Text(
          'Send this update to MixVy moderation for review. False reports may result in account restrictions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(creatorSubscriptionServiceProvider)
          .reportCreatorSubscriberUpdate(
            updateId: update.id,
            reason: 'inappropriate_content',
          );
      if (!mounted) return;
      _showMessage('Report submitted to moderation.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not submit the report: $error');
    }
  }

  Future<void> _saveOffer(bool enabled) async {
    final price = double.tryParse(_priceController.text.trim());
    final priceCents = price == null ? null : (price * 100).round();
    if (priceCents == null || priceCents < 299 || priceCents > 999) {
      _showMessage('Choose a monthly price from \$2.99 to \$9.99.');
      return;
    }
    final benefits = _benefitsController.text
        .split('\n')
        .map((benefit) => benefit.trim())
        .where((benefit) => benefit.isNotEmpty)
        .take(5)
        .toList(growable: false);
    if (enabled && benefits.isEmpty) {
      _showMessage('Add at least one subscriber benefit.');
      return;
    }

    setState(() => _working = true);
    try {
      final result = await ref
          .read(creatorSubscriptionServiceProvider)
          .saveCreatorSubscriptionOffer(
            enabled: enabled,
            monthlyPriceCents: priceCents,
            benefits: benefits,
          );
      if (!mounted) return;
      setState(() => _overviewFuture = Future.value(result));
      _showMessage(enabled ? 'Creator subscriptions enabled.' : 'Offer saved.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not save the offer: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openPayoutSetup() async {
    setState(() => _working = true);
    try {
      final url = await ref
          .read(creatorSubscriptionServiceProvider)
          .createStripeConnectOnboardingLink();
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Stripe onboarding did not open.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not open payout setup: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _subscribe() async {
    setState(() => _working = true);
    try {
      final url = await ref
          .read(creatorSubscriptionServiceProvider)
          .createCreatorSubscriptionCheckout(_creatorId!);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Stripe Checkout did not open.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not start the subscription: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancelMembership() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel creator membership?'),
        content: const Text(
          'Your access will continue through the current paid period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep membership'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel membership'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      final result = await ref
          .read(creatorSubscriptionServiceProvider)
          .cancelCreatorSubscription(_creatorId!);
      if (!mounted) return;
      setState(() => _overviewFuture = Future.value(result));
      _showMessage('Membership will end after the current paid period.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not cancel the membership: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    _benefitsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final future = _overviewFuture;
    return AppPageScaffold(
      backgroundColor: EmberDark.surface,
      appBar: AppBar(
        backgroundColor: EmberDark.surface,
        foregroundColor: EmberDark.onSurface,
        title: const Text('Creator Subscriptions'),
      ),
      body: (_creatorId ?? '').isEmpty || future == null
          ? const Center(child: Text('Sign in to manage subscriptions.'))
          : FutureBuilder<CreatorSubscriptionOverview>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || snapshot.data == null) {
                  return _ErrorState(onRetry: _refresh);
                }
                final overview = snapshot.data!;
                return SingleChildScrollView(
                  padding: EdgeInsets.all(context.pageHorizontalPadding),
                  child: Column(
                    children: [
                      if (overview.isOwner)
                        _buildCreatorView(overview)
                      else
                        _buildSubscriberView(overview),
                      if (overview.isOwner ||
                          overview.membership?.isActive == true) ...[
                        const SizedBox(height: 24),
                        _buildSubscriberUpdates(overview),
                      ],
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => context.go('/after-dark/safety'),
                        icon: const Icon(Icons.shield_outlined),
                        label: const Text('Safety and content rules'),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCreatorView(CreatorSubscriptionOverview overview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(
          icon: Icons.workspace_premium_rounded,
          title: 'Your membership offer',
          message:
              'Set a monthly price and benefits. You keep 85% before Stripe processing fees.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _priceController,
          enabled: !_working,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monthly price',
            prefixText: '\$',
            helperText: 'Allowed range: \$2.99-\$9.99 USD',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _benefitsController,
          enabled: !_working,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Subscriber benefits',
            helperText: 'One benefit per line, up to 5',
          ),
        ),
        const SizedBox(height: 18),
        _statusRow(
          !kCreatorPayoutsEnabled
              ? 'Creator payouts disabled during beta'
              : overview.connectOnboardingComplete
              ? 'Stripe payouts ready'
              : 'Stripe payout setup required',
          kCreatorPayoutsEnabled && overview.connectOnboardingComplete,
        ),
        const SizedBox(height: 8),
        Text(
          '${overview.subscriberCount} active subscriber${overview.subscriberCount == 1 ? '' : 's'}',
          style: const TextStyle(color: EmberDark.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        if (kCreatorPayoutsEnabled && !overview.connectOnboardingComplete)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _working ? null : _openPayoutSetup,
              icon: const Icon(Icons.account_balance_rounded),
              label: const Text('Set up Stripe payouts'),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _working || !overview.connectOnboardingComplete
                ? null
                : () => _saveOffer(true),
            icon: const Icon(Icons.publish_rounded),
            label: Text(
              overview.offer.enabled ? 'Update offer' : 'Enable subscriptions',
            ),
          ),
        ),
        if (overview.offer.enabled) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _working ? null : () => _saveOffer(false),
              child: const Text('Pause new subscriptions'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _buildAnalytics(overview),
      ],
    );
  }

  Widget _buildSubscriberView(CreatorSubscriptionOverview overview) {
    final offer = overview.offer;
    final membership = overview.membership;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(
          icon: Icons.favorite_rounded,
          title: 'Support this creator',
          message: offer.enabled
              ? '\$${(offer.monthlyPriceCents / 100).toStringAsFixed(2)} per month'
              : 'This creator is not accepting new subscribers right now.',
        ),
        if (offer.benefits.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Membership includes',
            style: TextStyle(
              color: EmberDark.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final benefit in offer.benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: EmberDark.secondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      benefit,
                      style: const TextStyle(
                        color: EmberDark.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 20),
        if (membership?.isActive == true) ...[
          _statusRow(
            membership!.cancelAtPeriodEnd
                ? 'Active until ${_dateLabel(membership.currentPeriodEnd)}'
                : 'Membership active',
            true,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _working || membership.cancelAtPeriodEnd
                  ? null
                  : _cancelMembership,
              child: Text(
                membership.cancelAtPeriodEnd
                    ? 'Cancellation scheduled'
                    : 'Cancel membership',
              ),
            ),
          ),
        ] else ...[
          if (!_checkoutConfigured)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Stripe test checkout is not configured in this build yet.',
                style: TextStyle(color: EmberDark.onSurfaceVariant),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _working || !offer.enabled || !_checkoutConfigured
                  ? null
                  : _subscribe,
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Subscribe securely'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalytics(CreatorSubscriptionOverview overview) {
    final analytics = overview.analytics;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EmberDark.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EmberDark.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Creator analytics',
            style: TextStyle(
              color: EmberDark.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 14,
            children: [
              _metric('Active', '${analytics.activeCount}'),
              _metric('Canceling', '${analytics.cancelingCount}'),
              _metric(
                'Monthly gross',
                _money(analytics.monthlyGrossCents),
              ),
              _metric(
                'Estimated creator share',
                _money(analytics.estimatedCreatorNetBeforeStripeCents),
              ),
            ],
          ),
          if (overview.recentActivity.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Recent subscribers',
              style: TextStyle(
                color: EmberDark.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final activity in overview.recentActivity)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: EmberDark.primaryDim,
                  child: Icon(Icons.person_outline, color: Colors.white),
                ),
                title: Text(
                  activity.displayName,
                  style: const TextStyle(color: EmberDark.onSurface),
                ),
                subtitle: Text(
                  activity.cancelAtPeriodEnd
                      ? 'Cancellation scheduled'
                      : activity.status,
                  style: const TextStyle(
                    color: EmberDark.onSurfaceVariant,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Estimates exclude Stripe processing fees and are not tax statements.',
            style: TextStyle(
              color: EmberDark.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: EmberDark.secondary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: EmberDark.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriberUpdates(CreatorSubscriptionOverview overview) {
    final future = _updatesFuture ??= _loadUpdates();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: EmberDark.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: EmberDark.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Subscriber-only updates',
                  style: TextStyle(
                    color: EmberDark.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (overview.isOwner)
                IconButton(
                  tooltip: 'Publish subscriber update',
                  onPressed: _working ? null : _publishUpdate,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<CreatorSubscriberUpdate>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Text(
                    'Updates are unavailable right now.',
                    style: TextStyle(color: EmberDark.onSurfaceVariant),
                  );
                }
                final updates =
                    snapshot.data ?? const <CreatorSubscriberUpdate>[];
                if (updates.isEmpty) {
                  return Text(
                    overview.isOwner
                        ? 'Publish your first subscriber-only update.'
                        : 'This creator has not posted an update yet.',
                    style: const TextStyle(
                      color: EmberDark.onSurfaceVariant,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final update in updates)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          update.text,
                          style: const TextStyle(
                            color: EmberDark.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          _dateLabel(update.createdAt),
                          style: const TextStyle(
                            color: EmberDark.onSurfaceVariant,
                          ),
                        ),
                        trailing: overview.isOwner
                            ? null
                            : IconButton(
                                tooltip: 'Report update',
                                onPressed: () => _reportUpdate(update),
                                icon: const Icon(
                                  Icons.flag_outlined,
                                  size: 19,
                                ),
                              ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';

  Widget _hero({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: EmberDark.bannerGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _statusRow(String label, bool ready) {
    return Row(
      children: [
        Icon(
          ready ? Icons.verified_rounded : Icons.info_outline_rounded,
          color: ready ? EmberDark.secondary : EmberDark.onSurfaceVariant,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: EmberDark.onSurface),
          ),
        ),
      ],
    );
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'the end of the billing period';
    final local = value.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Creator subscriptions are temporarily unavailable.',
              textAlign: TextAlign.center,
              style: TextStyle(color: EmberDark.onSurface),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
