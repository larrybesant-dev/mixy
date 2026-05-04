import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaymentWidget extends ConsumerWidget {
  final String senderId;
  final String receiverId;

  const PaymentWidget({
    required this.senderId,
    required this.receiverId,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Semantics(
          label: 'Send Payment button',
          button: true,
          child: ElevatedButton(
            onPressed:
                null, // Payments not yet enabled — wire Stripe before activating
            child: Text(
              'Send Payment (Coming Soon)',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width > 400 ? 18 : 16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
