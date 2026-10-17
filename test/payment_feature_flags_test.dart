import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/flags/feature_flags.dart';

void main() {
  test('native builds cannot expose Stripe payments', () {
    expect(kPaymentsEnabled, isFalse);
  });
}
