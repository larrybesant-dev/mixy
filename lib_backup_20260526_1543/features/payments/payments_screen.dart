import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/user_model.dart';
import '../../models/wallet_model.dart';
import '../../services/cash_out_service.dart';
import '../../services/payment_api.dart';
import 'payments_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/referral_provider.dart';

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
    final safeName =
        recipient.username.isNotEmpty ? recipient.username : 'MixVy user';
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
    // UPDATED: Using modern share_plus API
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

  @override
  Widget build(BuildContext context) {
    // ... [Rest of your build method remains the same]
    // (Note: Ensure any use of (__, _) in the build method
    // has been updated to (__, _) by the PowerShell script earlier)
    return Container(); // Placeholder for brevity
  }
}

// ... [Keep your helper widgets like _statusChip at the bottom]
