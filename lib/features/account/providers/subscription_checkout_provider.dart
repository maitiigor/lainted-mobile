import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/subscription_plan.dart';
import '../../../shared/providers/dio_provider.dart';

class SubscriptionCheckoutResult {
  const SubscriptionCheckoutResult({required this.authorizationUrl, required this.reference});

  final String authorizationUrl;
  final String reference;
}

class SubscriptionCheckoutService {
  SubscriptionCheckoutService(this._ref);

  final Ref _ref;

  Future<SubscriptionCheckoutResult> checkout(SubscriptionPlan plan) async {
    final response = await _ref.read(dioProvider).post(
          ApiConstants.subscriptionCheckout,
          data: {'subscription_plan_id': plan.id},
        );
    final data = response.data['data'] as Map<String, dynamic>;

    return SubscriptionCheckoutResult(
      authorizationUrl: data['authorization_url'] as String,
      reference: data['reference'] as String,
    );
  }
}

final subscriptionCheckoutServiceProvider = Provider<SubscriptionCheckoutService>(
  (ref) => SubscriptionCheckoutService(ref),
);
