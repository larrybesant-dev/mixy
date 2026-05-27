import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/mixvy_economy_config.dart';
import '../../core/layout/app_layout.dart';
import '../../models/cash_out_request_model.dart';
import '../../models/user_model.dart';
import '../../models/wallet_model.dart';
import '../../shared/widgets/app_page_scaffold.dart';
import '../../shared/widgets/async_state_view.dart';
import '../../services/cash_out_service.dart';
import '../../services/payment_api.dart';
import 'stripe_web_payment_widget.dart';
import 'payments_controller.dart';
import 'payment_recipient_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/coin_transaction_provider.dart';
import '../../presentation/providers/referral_provider.dart';
import '../../presentation/providers/wallet_provider.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController(text: '10');
  late CashOutService _cashOutService;
  UserModel? _selectedRecipient;
  late Future<StripeConnectStatus> _connectStatusFuture;

  @override
  void initState() {
    super.initState();
    _cashOutService = ref.read(cashOutServiceProvider);
    _connectStatusFuture = PaymentApi.getStripeConnectStatus();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool requestOnly}) async {
    final recipientId = _selectedRecipient?.id;
    final amount = double.tryParse(_amountController.text.trim());

    if (recipientId == null ||
        amount == null ||
        amount <= 0 ||
        amount > 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a recipient and enter a valid amount (max 100000).',
          ),
        ),
      );
      return;
    }

    final controller = ref.read(paymentControllerProvider.notifier);
    if (requestOnly) {
      await controller.requestCoins(targetId: recipientId, amount: amount);
    } else {
      await controller.sendCoins(receiverId: recipientId, amount: amount);
    }

    if (!mounted) {
      return;
    }

    final state = ref.read(paymentControllerProvider);
    final message = state.error ?? state.successmessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _selectRecipient(UserModel recipient) {
    final safeName = recipient.username.isNotEmpty
        ? recipient.username
        : 'MixVy user';
    setState(() {
      _selectedRecipient = recipient;
      _recipientController.text = safeName;
      _recipientController.selection = TextSelection.collapsed(
        offset: _recipientController.text.length,
      );
    });
  }

  void _clearRecipient() {
    setState(() {
      _selectedRecipient = null;
      _recipientController.clear();
    });
  }

  void _setQuickAmount(double amount) {
    setState(() {
      _amountController.text = amount.toStringAsFixed(
        amount.truncateToDouble() == amount ? 0 : 2,
      );
      _amountController.selection = TextSelection.collapsed(
        offset: _amountController.text.length,
      );
    });
  }

  Future<void> _generateReferralCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      final code = await ref
          .read(referralServiceProvider)
          .generateReferralCode(user.uid);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Referral code ready: $code')));
      await _shareReferralCode(code);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate referral code: $e')),
      );
    }
  }

  Future<void> _copyReferralCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Referral code copied.')));
  }

  Future<void> _shareReferralCode(String code) async {
    await Share.share(
      'Join me on MixVy and use my referral code: $code\nhttps://mixvy.app',
      subject: 'Join me on MixVy',
    );
  }

  Future<void> _requestCashOut(
    WalletModel wallet,
    double pendingCashOut,
  ) async {
    final amountController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Cash Out'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available cash: ${(wallet.cashBalance - pendingCashOut).toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Cash-out amount',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (submitted != true) {
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid cash-out amount.')),
      );
      return;
    }

    try {
      await _cashOutService.requestCashOut(amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash-out request submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not request cash-out: $e')));
    }
  }

  Future<void> _refreshConnectStatus() async {
    setState(() {
      _connectStatusFuture = PaymentApi.getStripeConnectStatus();
    });
  }

  Future<void> _launchPayoutSetup() async {
    try {
      final url = await PaymentApi.createStripeConnectOnboardingLink();
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not open Stripe onboarding.');
      }
      await _refreshConnectStatus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start payout setup: $e')),
      );
    }
  }

  Future<void> _openStripeDashboard() async {
    try {
      final url = await PaymentApi.createStripeConnectDashboardLink();
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Could not open Stripe dashboard.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Stripe dashboard: $e')),
      );
    }
  }

  Future<void> _requestRefundForTransaction(CoinTransaction tx) async {
    final reasonController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Refund'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction: ${tx.id}'),
            const SizedBox(height: 8),
            Text('Amount: ${tx.amount.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Describe the issue in at least 10 characters.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (submitted != true) {
      return;
    }

    try {
      await PaymentApi.requestRefund(
        transactionId: tx.id,
        reason: reasonController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund request submitted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not request refund: $error')),
      );
    }
  }

  Widget _statusChip(String label, bool enabled) {
    return Chip(
      avatar: Icon(
        enabled ? Icons.check_circle_outline : Icons.radio_button_unchecked,
        size: 18,
        color: enabled ? const Color(0xFFD4AF37) : const Color(0xFFAD9585),
      ),
      label: Text(
        label,
        style: TextStyle(
          color: enabled ? const Color(0xFFD4AF37) : const Color(0xFFAD9585),
          fontWeight: enabled ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      backgroundColor: const Color(0xFF1A1416),
      side: BorderSide(
        color: enabled
            ? const Color(0xFFD4AF37).withValues(alpha: 0.40)
            : const Color(0xFFAD9585).withValues(alpha: 0.25),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentPaymentUserIdProvider);
    final paymentState = ref.watch(paymentControllerProvider);
    final walletDetailsAsync = ref.watch(walletDetailsProvider);
    final referralCodeAsync = ref.watch(referralCodeProvider);
    final referralEarningsAsync = ref.watch(referralEarningsProvider);
    final cashOutRequestsAsync = _cashOutService.requestsForCurrentUser();
    final transactionsAsync = ref.watch(
      coinTransactionStreamProvider(currentUserId ?? ''),
    );
    final refundRequestsAsync = PaymentApi.getMyRefundRequests(
      currentUserId ?? '',
    );
    final recipientsAsync = ref.watch(
      paymentRecipientSearchProvider(
        _selectedRecipient == null ? _recipientController.text : '',
      ),
    );

    return AppPageScaffold(
      backgroundColor: const Color(0xFF0D0A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF110D0F),
        foregroundColor: const Color(0xFFF7EDE2),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFD4AF37).withValues(alpha: 0.20),
          ),
        ),
        title: Text(
          'Payments',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFFD4AF37),
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(context.pageHorizontalPadding),
        children: [
          if (kIsWeb) ...[
            const StripeWebPaymentWidget(),
            const SizedBox(height: 24),
          ],
          FutureBuilder<StripeConnectStatus>(
            future: _connectStatusFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AppLoadingView(label: 'Loading payout setup');
              }

              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Creator payouts',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text('Payout status unavailable: ${snapshot.error}'),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _refreshConnectStatus,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final status = snapshot.data ??
                  const StripeConnectStatus(
                    hasAccount: false,
                    chargesEnabled: false,
                    payoutsEnabled: false,
                    detailsSubmitted: false,
                    onboardingComplete: false,
                  );

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Creator payouts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status.onboardingComplete
                            ? 'Stripe payout setup is complete.'
                            : 'Connect a Stripe account to receive creator payouts.',
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _statusChip('Account', status.hasAccount),
                          _statusChip('Details', status.detailsSubmitted),
                          _statusChip('Charges', status.chargesEnabled),
                          _statusChip('Payouts', status.payoutsEnabled),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _launchPayoutSetup,
                            icon: const Icon(Icons.account_balance_outlined),
                            label: Text(
                              status.onboardingComplete
                                  ? 'Update Payout Setup'
                                  : 'Start Payout Setup',
                            ),
                          ),
                          if (status.hasAccount)
                            OutlinedButton.icon(
                              onPressed: _openStripeDashboard,
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('Open Stripe Dashboard'),
                            ),
                          OutlinedButton.icon(
                            onPressed: _refreshConnectStatus,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Status'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: const [
                  Icon(Icons.shield_outlined),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Send or request coins with trusted members only. Double-check recipient before confirming.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Wallet',
            style: GoogleFonts.playfairDisplay(
              color: const Color(0xFFD4AF37),
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          walletDetailsAsync.when(
            data: (wallet) {
              return StreamBuilder<List<CashOutRequestModel>>(
                stream: cashOutRequestsAsync,
                builder: (context, snapshot) {
                  final requests =
                      snapshot.data ?? const <CashOutRequestModel>[];
                  final pendingCashOut = requests
                      .where(
                        (request) =>
                            request.status == 'pending' ||
                            request.status == 'processing',
                      )
                      .fold<double>(
                        0,
                        (runningTotal, request) => runningTotal + request.amount,
                      );

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Coin balance: ${wallet.coinBalance.toStringAsFixed(0)}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Cash balance: ${wallet.cashBalance.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Referral earnings: ${wallet.referralEarnings.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Room earnings: ${wallet.roomEarnings.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Gift earnings: ${wallet.giftEarnings.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pending cash-out: ${pendingCashOut.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: (wallet.cashBalance - pendingCashOut) >=
                                    MixVyEconomyConfig.creatorPayoutMinimumCash
                                ? () => _requestCashOut(wallet, pendingCashOut)
                                : null,
                            icon: const Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                            label: Text(
                              'Request Cash Out (${MixVyEconomyConfig.creatorPayoutMinimumCash.toStringAsFixed(0)} min)',
                            ),
                          ),
                          if (requests.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Recent cash-out requests',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            ...requests.take(3).map(
                                  (request) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.payments_outlined,
                                    ),
                                    title: Text(
                                      request.amount.toStringAsFixed(2),
                                    ),
                                    subtitle: Text(request.status),
                                    trailing: Text(
                                      request.createdAt == null
                                          ? 'Pending'
                                          : '${request.createdAt!.month}/${request.createdAt!.day}',
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const AppLoadingView(label: 'Loading wallet'),
            error: (e, _) => AppErrorView(
                error: e, fallbackContext: 'Wallet unavailable.'),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Referrals',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  referralCodeAsync.when(
                    data: (code) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code == null
                              ? 'No active referral code yet.'
                              : 'Code: $code',
                        ),
                        if (code != null) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _copyReferralCode(code),
                                icon: const Icon(Icons.copy_rounded),
                                label: const Text('Copy Code'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _shareReferralCode(code),
                                icon: const Icon(Icons.share_outlined),
                                label: const Text('Share Code'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    loading: () => const AppLoadingView(
                        label: 'Loading referral code'),
                    error: (e, _) => AppErrorView(
                      error: e,
                      fallbackContext: 'Referral code unavailable.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  referralEarningsAsync.when(
                    data: (total) =>
                        Text('Referral earnings: ${total.toStringAsFixed(2)}'),
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Text('Referral earnings unavailable.'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _generateReferralCode,
                      icon: const Icon(Icons.qr_code_rounded),
                      label: const Text('Generate Referral Code'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          StreamBuilder<List<RefundRequest>>(
            stream: refundRequestsAsync,
            builder: (context, snapshot) {
              final requests = snapshot.data ?? const <RefundRequest>[];
              final openRequests = requests
                  .where(
                    (r) => r.status == 'pending' || r.status == 'under_review',
                  )
                  .length;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Support',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        openRequests == 0
                            ? 'No open refund requests.'
                            : '$openRequests refund request(s) are currently in review.',
                      ),
                      if (requests.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...requests.take(3).map(
                              (request) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.support_agent_outlined,
                                ),
                                title: Text(
                                  'Refund ${request.amount.toStringAsFixed(2)}',
                                ),
                                subtitle: Text('Status: ${request.status}'),
                                trailing: Text(
                                  request.createdAt == null
                                      ? 'Pending'
                                      : '${request.createdAt!.month}/${request.createdAt!.day}',
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recipientController,
            onChanged: (value) {
              if (_selectedRecipient == null) {
                setState(() {});
                return;
              }

              final selectedLabel = _selectedRecipient!.username.isNotEmpty
                  ? _selectedRecipient!.username
                  : 'MixVy user';
              if (value != selectedLabel) {
                setState(() {
                  _selectedRecipient = null;
                });
              }
            },
            decoration: const InputDecoration(
              labelText: 'Search recipient',
              hintText: 'Enter a username',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_selectedRecipient != null)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    _selectedRecipient!.username.isNotEmpty
                        ? _selectedRecipient!.username[0].toUpperCase()
                        : 'M',
                  ),
                ),
                title: Text(
                  _selectedRecipient!.username.isNotEmpty
                      ? _selectedRecipient!.username
                      : 'MixVy user',
                ),
                subtitle: const Text('Recipient selected'),
                trailing: IconButton(
                  onPressed: _clearRecipient,
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear recipient',
                ),
              ),
            )
          else
            recipientsAsync.when(
              data: (recipients) {
                if (recipients.isEmpty) {
                  if (_recipientController.text.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return const Text('No matching users found.');
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _recipientController.text.trim().isEmpty
                          ? 'Suggested recipients'
                          : 'Matching users',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...recipients.take(6).map(
                          (recipient) => Card(
                            child: ListTile(
                              onTap: () => _selectRecipient(recipient),
                              leading: CircleAvatar(
                                child: Text(
                                  recipient.username.isNotEmpty
                                      ? recipient.username[0].toUpperCase()
                                      : 'M',
                                ),
                              ),
                              title: Text(
                                recipient.username.isNotEmpty
                                    ? recipient.username
                                    : 'MixVy user',
                              ),
                              subtitle: const Text('Community member'),
                            ),
                          ),
                        ),
                  ],
                );
              },
              loading: () => const AppLoadingView(label: 'Loading recipients'),
              error: (e, _) => AppErrorView(
                error: e,
                fallbackContext: 'Unable to load recipients.',
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text(
                  '10',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: const Color(0xFF1A1416),
                side: const BorderSide(color: Color(0xFFD4AF37), width: 1.0),
                onPressed: () => _setQuickAmount(10),
              ),
              ActionChip(
                label: const Text(
                  '25',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: const Color(0xFF1A1416),
                side: const BorderSide(color: Color(0xFFD4AF37), width: 1.0),
                onPressed: () => _setQuickAmount(25),
              ),
              ActionChip(
                label: const Text(
                  '50',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: const Color(0xFF1A1416),
                side: const BorderSide(color: Color(0xFFD4AF37), width: 1.0),
                onPressed: () => _setQuickAmount(50),
              ),
              ActionChip(
                label: const Text(
                  '100',
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: const Color(0xFF1A1416),
                side: const BorderSide(color: Color(0xFFD4AF37), width: 1.0),
                onPressed: () => _setQuickAmount(100),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: paymentState.isLoading
                      ? null
                      : () => _submit(requestOnly: false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF0D0A0C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: paymentState.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0D0A0C),
                          ),
                        )
                      : const Text(
                          'Send Coins',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: paymentState.isLoading
                      ? null
                      : () => _submit(requestOnly: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD4AF37),
                    side: const BorderSide(
                      color: Color(0xFFD4AF37),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Request Coins',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (paymentState.error != null) ...[
            const SizedBox(height: 12),
            Text(
              paymentState.error!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'Recent Transactions',
            style: GoogleFonts.playfairDisplay(
              color: const Color(0xFFD4AF37),
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 12),
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return const AppEmptyView(
                  title: 'No transactions yet',
                  icon: Icons.receipt_long_outlined,
                );
              }

              return Column(
                children: transactions
                    .map((tx) {
                      final isSent = tx.senderId == currentUserId;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            isSent ? Icons.call_made : Icons.call_received,
                            color: isSent
                                ? const Color(0xFF9B2535)
                                : const Color(0xFFD4AF37),
                          ),
                          title: Text(
                            '${isSent ? '-' : '+'}${tx.amount.toStringAsFixed(2)}',
                          ),
                          subtitle: Text(
                            'To: ${tx.receiverId}\nStatus: ${tx.status}',
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Transaction actions',
                            onSelected: (value) {
                              if (value == 'refund') {
                                _requestRefundForTransaction(tx);
                              }
                            },
                            itemBuilder: (context) {
                              final canRequestRefund = isSent &&
                                  (tx.status == 'completed' ||
                                      tx.status == 'sent');
                              final items = <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  enabled: false,
                                  value: 'timestamp',
                                  child: Text(
                                    '${tx.timestamp.month}/${tx.timestamp.day} '
                                    '${tx.timestamp.hour.toString().padLeft(2, '0')}:'
                                    '${tx.timestamp.minute.toString().padLeft(2, '0')}',
                                  ),
                                ),
                              ];
                              if (canRequestRefund) {
                                items.add(
                                  const PopupMenuItem<String>(
                                    value: 'refund',
                                    child: Text('Request refund'),
                                  ),
                                );
                              }
                              return items;
                            },
                            child: const Icon(Icons.more_vert),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              );
            },
            loading: () => const AppLoadingView(label: 'Loading transactions'),
            error: (e, _) => AppErrorView(
              error: e,
              fallbackContext: 'Unable to load transactions.',
            ),
          ),
        ],
      ),
    );
  }
}