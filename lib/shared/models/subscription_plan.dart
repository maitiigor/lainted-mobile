import '../../core/utils/json_parsing.dart';

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.price,
    this.maxActiveListings,
    this.features = const [],
  });

  final int id;
  final String code;
  final String name;
  final double price;

  /// Null means unlimited (Pro/Elite today).
  final int? maxActiveListings;
  final List<String> features;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      price: parseDouble(json['price']),
      maxActiveListings: json['max_active_listings'] as int?,
      features: (json['features'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}

/// The seller's current subscription - only ever present for business
/// sellers (see User.remainingListingSlots() on the backend; personal
/// sellers have a flat hardcoded cap and no subscription row at all).
class ActiveSubscription {
  const ActiveSubscription({required this.plan});

  final SubscriptionPlan plan;

  factory ActiveSubscription.fromJson(Map<String, dynamic> json) {
    return ActiveSubscription(
      plan: SubscriptionPlan.fromJson(json['subscription_plan'] as Map<String, dynamic>),
    );
  }
}
