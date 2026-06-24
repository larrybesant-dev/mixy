import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/services/payments/monetization_service.dart';

class WithdrawalPage extends ConsumerStatefulWidget {
  const WithdrawalPage({super.key});

  @override
  ConsumerState<WithdrawalPage> createState() => _WithdrawalPageState();
}

class _WithdrawalPageState extends ConsumerState<WithdrawalPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  final _monetizationService = MonetizationService();

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _monetizationService.submitWithdrawal(
        amount: int.parse(_amountController.text),
        email: _emailController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdrawal request submitted!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '\$',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter amount';
                        }
                        final amount = int.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'PayPal Email',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _submitWithdrawal,
                      child: const Text('Submit Withdrawal'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}

