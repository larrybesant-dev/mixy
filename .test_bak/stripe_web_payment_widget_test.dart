import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/payments/stripe_web_payment_widget.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('StripeWebPaymentWidget renders and shows button', (
    WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StripeWebPaymentWidget())));
    expect(find.text('MixVy Premium'), findsOneWidget);
    expect(find.text('Upgrade Now — \$9.99 / month'), findsOneWidget);
  });
}










