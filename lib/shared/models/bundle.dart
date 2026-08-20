import '../../core/utils/json_parsing.dart';
import 'listing.dart';

class Bundle {
  const Bundle({
    required this.id,
    required this.title,
    required this.requiredItemCount,
    required this.bundlePrice,
    this.isActive = true,
    this.listings = const [],
  });

  final String id;
  final String title;
  final int requiredItemCount;
  final double bundlePrice;
  final bool isActive;
  final List<Listing> listings;

  factory Bundle.fromJson(Map<String, dynamic> json) {
    return Bundle(
      id: json['uuid'] as String,
      title: json['title'] as String,
      requiredItemCount: json['required_item_count'] as int,
      bundlePrice: parseDouble(json['bundle_price']),
      isActive: json['is_active'] as bool? ?? true,
      listings: (json['listings'] as List<dynamic>? ?? [])
          .map((e) => Listing.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
