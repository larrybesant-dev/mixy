import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/creator_subscription_service.dart';
import '../../../services/payment_api.dart';

final creatorSubscriptionServiceProvider =
    Provider<CreatorSubscriptionService>((ref) {
      return ref.watch(paymentApiProvider);
    });
