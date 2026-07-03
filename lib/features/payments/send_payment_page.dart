// ...existing code...
import 'package:flutter/material.dart';
import '../../services/payment_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import removed: '../../presentation/providers/payment_api_provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
// Unused import removed: 'package:firebase_auth/firebase_auth.dart';

import '../../core/layout/app_layout.dart';
import '../../shared/widgets/app_page_scaffold.dart';

class SendPaymentPage extends ConsumerStatefulWidget {
  final String recipientId;
  final String recipientName;
  const SendPaymentPage({
    super.key,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  ConsumerState<SendPaymentPage> createState() => _SendPaymentPageState();
}

class _SendPaymentPageState extends ConsumerState<SendPaymentPage> {
  final _amountController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _sendPayment() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        setState(() {
          _error = 'Enter a valid amount.';
          _loading = false;
        });
        return;
      }
      final paymentApi = ref.read(paymentApiProvider);
      // User is assumed to be logged in (null check handled in PaymentApi).
      final intent = await paymentApi.createIntent(
        amount: amount,
        currency: 'usd',
        recipientId: widget.recipientId,
      );
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent.clientSecret,
          merchantDisplayName: 'MixVy',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      // Notify backend of successful payment (senderId is authenticated user)
      await paymentApi.notifySuccess(
        recipientId: widget.recipientId,
        amount: amount,
        paymentIntentId: intent.paymentIntentId,
        idempotencyKey: intent.idempotencyKey,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment sent!')));
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      appBar: AppBar(title: Text('Send to ${widget.recipientName}')),
      body: Padding(
        padding: EdgeInsets.all(context.pageHorizontalPadding),
        child: Column(
          children: [
            Semantics(
              label: 'Amount input field',
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (USD)'),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Semantics(
                label: 'Error message',
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Semantics(
              label: 'Send Payment button',
              button: true,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendPayment,
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(
                        'Send Payment',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width > 400
                              ? 20
                              : 18,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



