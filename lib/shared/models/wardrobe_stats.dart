import '../../core/utils/json_parsing.dart';

/// "My Wardrobe" stats - items listed/sold and total earned, scoped
/// server-side to listing_source Wardrobe (a personal seller's own
/// selling activity, not just cleanout-flagged listings).
class WardrobeStats {
  const WardrobeStats({
    required this.itemsListed,
    required this.itemsSold,
    required this.totalEarned,
  });

  final int itemsListed;
  final int itemsSold;
  final double totalEarned;

  factory WardrobeStats.fromJson(Map<String, dynamic> json) {
    return WardrobeStats(
      itemsListed: json['items_listed'] as int? ?? 0,
      itemsSold: json['items_sold'] as int? ?? 0,
      totalEarned: parseDouble(json['total_earned']),
    );
  }
}
