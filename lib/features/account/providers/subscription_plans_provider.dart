import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../shared/models/subscription_plan.dart';
import '../../../shared/providers/dio_provider.dart';

final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>((ref) async {
  final response = await ref.read(dioProvider).get(ApiConstants.subscriptionPlans);
  final data = response.data['data'] as List<dynamic>;

  return data.map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>)).toList();
});
